--!strict
-- The insertion cutscene (Nova, 2026-11-11: "a cutscene of the lantern dropping the squad off at
-- the landing zone"; "see the squad sitting in the heli and then see them jumping out";
-- Config.Insertion). When the run enters Insert this client flies its own copy of the Lantern
-- (the server's ReplicatedStorage.InsertLantern) with the squad aboard and holds the camera:
--   1. Approach: from over the LZ pad, the helicopter comes in low over the city and slows.
--   2. Flare, hover and the drop: from its door side, it noses up, settles over the pad in its
--      own dust, and the squad, seated on the bench facing the door, jump out one by one.
--   3. Departure: from behind the squad on the pad, it climbs away over their heads.
-- The squad aboard are local stand-ins (clones of each player's and bot's body): the real
-- bodies stand on the pad, hidden, and each shows the moment its stand-in lands on its spot.
-- A black cover is up from the moment this client starts while the run waits for the squad or
-- for the cutscene, so nobody sees the squad on the pad before they arrive. Letterbox bars; the
-- HUD hidden; the soldier held (Attributes.Cinematic). SkipKeys end it for this player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)
local CameraController = require(script.Parent.CameraController)

local InsertionCutscene = {}

local CUT = Config.Insertion
local UP = Vector3.yAxis
local BOT_TAG = "SquadBot"

type Shot = { from: Vector3, look: Vector3, fov: number }
type Jumper = {
	member: Instance?, -- its SquadRoster entry
	source: Model?, -- the real body on the pad (nil until a bot's is built)
	model: Model, -- its stand-in
	root: BasePart,
	seat: CFrame, -- the seated root, in the helicopter's frame
	height: number, -- root above the feet
	sit: AnimationTrack?,
	fall: AnimationTrack?,
	starts: number, -- cutscene time the jump begins
	from: CFrame?, -- the door, in the world, once it steps off
	land: CFrame?, -- where the real body stands
	landed: boolean,
	waiting: boolean, -- landed before its real body was built: stands there until it is
	idle: AnimationTrack?,
}

local playing = false
local skipRequested = false
local screen: ScreenGui
local black: Frame
local bars: { Frame } = {}

-- Smoothstep easing.
local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, u: number): Vector3
	return a:Lerp(b, u):Lerp(b:Lerp(c, u), u)
end

-- Every body of the squad (players and bots).
local function squadModels(): { Model }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, bot in CollectionService:GetTagged(BOT_TAG) do
		if bot:IsA("Model") then
			table.insert(list, bot)
		end
	end
	return list
end

local function setHidden(model: Model, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			(part :: any).LocalTransparencyModifier = value
		end
	end
end

-- The black cover and the letterbox bars, over everything but the staging notice.
local function buildScreen()
	screen = Instance.new("ScreenGui")
	screen.Name = "InsertionCutscene"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 100
	screen.Enabled = false
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.Size = UDim2.fromScale(1, CUT.Letterbox)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1 - CUT.Letterbox)
		bar.Visible = false
		bar.Parent = screen
		table.insert(bars, bar)
	end
	black = Instance.new("Frame")
	black.Name = "Black"
	black.BorderSizePixel = 0
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = screen
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function cover(on: boolean)
	if on then
		screen.Enabled = true
		black.BackgroundTransparency = 0
	elseif screen.Enabled and not playing then
		local out = TweenService:Create(black, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		out.Completed:Once(function()
			if not playing then
				screen.Enabled = false
			end
		end)
		out:Play()
	end
end

-- The dust the rotor throws up over the pad.
local function buildDust(at: Vector3): (Part, ParticleEmitter)
	local anchor = Instance.new("Part")
	anchor.Name = "InsertDust"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(30, 1, 30)
	anchor.CFrame = CFrame.new(at)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 138, 118), Color3.fromRGB(110, 102, 90))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 12),
	})
	dust.Lifetime = NumberRange.new(1.6, 2.6)
	dust.Speed = NumberRange.new(14, 26)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -2, 0)
	dust.Drag = 1.5
	dust.Rate = 0
	dust.Parent = anchor
	anchor.Parent = Workspace
	return anchor, dust
end

-- Hides every HUD screen but ours (and the staging notice); returns the ones it hid.
local function hideHud(): { ScreenGui }
	local hidden = {}
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if gui then
		for _, other in gui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= screen and other.Enabled then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
	end
	return hidden
end

local function holdControls(on: boolean)
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	pcall(function()
		local controls = (require(module) :: any):GetControls()
		if on then
			controls:Disable()
		else
			controls:Enable()
		end
	end)
end

local function loadTrack(animator: Animator, id: string, looped: boolean): AnimationTrack?
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = looped
		track.Priority = Enum.AnimationPriority.Action
		return track
	end
	return nil
end

-- A local stand-in of `source` for the ride: a clone with no scripts, the root anchored (the
-- cutscene moves it), nothing colliding, seated.
local function standIn(source: Model, seat: CFrame, starts: number): Jumper?
	local sourceRoot = source:FindFirstChild("HumanoidRootPart")
	local humanoid = source:FindFirstChildOfClass("Humanoid")
	if not (sourceRoot and sourceRoot:IsA("BasePart") and humanoid) then
		return nil
	end
	local was = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	source.Archivable = was
	if not ok or not copy then
		return nil
	end
	local model = copy :: Model
	model.Name = source.Name .. "_Ride"
	-- A clone keeps its source's tags: a bot's stand-in would count as a squad body (and be
	-- hidden with them) unless they go.
	for _, tag in model:GetTags() do
		model:RemoveTag(tag)
	end
	for _, thing in model:GetDescendants() do
		if thing:IsA("LuaSourceContainer") or thing:IsA("ForceField") or thing:IsA("Highlight") then
			thing:Destroy()
		elseif thing:IsA("BasePart") then
			thing.CanCollide = false
			thing.CanQuery = false
			thing.CanTouch = false
			thing.LocalTransparencyModifier = 0
		elseif thing:IsA("Decal") then
			thing.LocalTransparencyModifier = 0
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	local copyHumanoid = model:FindFirstChildOfClass("Humanoid")
	if copyHumanoid then
		copyHumanoid.EvaluateStateMachine = false
		copyHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model.Parent = Workspace
	local animator = copyHumanoid and copyHumanoid:FindFirstChildOfClass("Animator")
	if copyHumanoid and not animator then
		local made = Instance.new("Animator")
		made.Parent = copyHumanoid
		animator = made
	end
	local sit = animator and loadTrack(animator, CUT.Animations.Sit, true)
	local fall = animator and loadTrack(animator, CUT.Animations.Fall, true)
	local idle = animator and loadTrack(animator, CUT.Animations.Idle, true)
	if sit then
		sit:Play(0)
	end
	return {
		member = nil,
		source = source,
		model = model,
		root = root,
		seat = seat,
		height = humanoid.HipHeight + sourceRoot.Size.Y / 2,
		sit = sit,
		fall = fall,
		starts = starts,
		from = nil,
		land = nil,
		landed = false,
		waiting = false,
		idle = idle,
	}
end

-- A roster entry's body: the player's character, or the bot named by its callsign.
local function bodyOf(member: Instance): Model?
	local userId = member:GetAttribute(Attributes.SquadUserId)
	if typeof(userId) == "number" and userId > 0 then
		local player = Players:GetPlayerByUserId(userId)
		return player and player.Character
	end
	local callsign = member:GetAttribute(Attributes.Callsign)
	for _, bot in CollectionService:GetTagged(BOT_TAG) do
		if bot:IsA("Model") and bot.Name == callsign then
			return bot
		end
	end
	return nil
end

-- The squad, in roster order (players first, then the bots); empty without a roster.
local function rosterMembers(): { Instance }
	local roster = ReplicatedStorage:FindFirstChild(Attributes.SquadRoster)
	local list = if roster then roster:GetChildren() else {}
	-- Players first (they take the seats nearest the door's middle), then the bots by slot.
	local function rank(member: Instance): number
		local userId = member:GetAttribute(Attributes.SquadUserId)
		return if typeof(userId) == "number" and userId > 0 then 0 else 1
	end
	table.sort(list, function(a, b)
		if rank(a) ~= rank(b) then
			return rank(a) < rank(b)
		end
		return a.Name < b.Name
	end)
	return list
end

-- The squad's landing pads (Config.Run.SpawnPads round the LZ; ArenaService.getSpawnPad's
-- standing CFrames), for a stand-in whose bot has no body yet.
local function padFrames(): { CFrame }
	local lz = Config.Extraction.ZonePosition
	local list = {}
	for _, offset in Config.Run.SpawnPads do
		local position = Vector3.new(lz.X + offset.X, 3.5, lz.Z + offset.Z)
		local toward = Vector3.new(-position.X, 0, -position.Z)
		if toward.Magnitude < 0.01 then
			toward = Vector3.new(0, 0, -1)
		end
		table.insert(list, CFrame.lookAlong(position, toward.Unit))
	end
	return list
end

local function play()
	if playing then
		return
	end
	playing = true
	skipRequested = false
	cover(true)
	-- The server's start time for this run's cutscene; a client that is late (slow to load)
	-- joins it where it has got to, and one that missed nearly all of it skips it.
	local startsAt = (Workspace:GetAttribute(Attributes.InsertStartsAt) :: number?) or 0
	local template = ReplicatedStorage:WaitForChild("InsertLantern", 10)
	local late = Workspace:GetServerTimeNow() - startsAt
	if
		not (template and template:IsA("Model"))
		or late > CUT.Seconds - 1.5
		or Workspace:GetAttribute(Attributes.RunState) ~= "Insert"
	then
		if not template then
			warn("[InsertionCutscene] no InsertLantern from the server; skipping the cutscene")
		end
		playing = false
		cover(false)
		return
	end
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera

	-- The scene's frame: the pad, out toward the map's edge, and across.
	local pad = Config.Extraction.ZonePosition
	local flatOut = Vector3.new(pad.X, 0, pad.Z)
	local outward = if flatOut.Magnitude > 1 then flatOut.Unit else Vector3.new(0, 0, 1)
	local facing = -outward -- the squad faces the middle of the map
	local side = outward:Cross(UP).Unit

	-- The helicopter: a local copy; every part placed from its frame each step.
	local lantern = template:Clone()
	local bench = Instance.new("Part")
	bench.Name = "Bench"
	bench.Anchored = true
	bench.CanCollide = false
	bench.CanQuery = false
	bench.CanTouch = false
	bench.Size = CUT.Bench.Size
	bench.CFrame = CFrame.new(CUT.Bench.At)
	bench.Color = Color3.fromRGB(52, 56, 48)
	bench.Material = Enum.Material.Metal
	bench.Parent = lantern
	local parts: { BasePart } = {}
	local rest: { CFrame } = {}
	local spin: { string } = {}
	for _, part in lantern:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(rest, part.CFrame) -- built around the identity frame
			table.insert(spin, part.Name)
		end
	end
	lantern.Parent = Workspace
	local body = lantern:FindFirstChild("Body")
	local rotor = SoundBanks.create("InsertRotor", 30, 600)
	rotor.Parent = if body and body:IsA("BasePart") then body else Workspace
	SoundBanks.loop(rotor, "ambience", "lantern_rotor", CUT.RotorVolume)

	local hidden = hideHud()
	local dustPart, dust = buildDust(pad + UP * 0.5)
	player:SetAttribute(Attributes.Cinematic, true)
	holdControls(true)
	CameraController.setCinematic(true)
	camera.CameraType = Enum.CameraType.Scriptable

	-- The timeline.
	local tFlare = CUT.Approach
	local tDrop = tFlare + CUT.Flare
	local tDepart = tDrop + CUT.Drop
	local tEnd = CUT.Seconds

	-- The flight, as frames of the helicopter over time. The Lantern's nose is +Z in its own
	-- frame: it looks along -facing so the nose leads; a positive pitch raises the nose.
	local start = pad + outward * CUT.StartDistance + UP * CUT.StartHeight
	local bend = pad + outward * CUT.StartDistance * 0.35 + UP * (CUT.CruiseHeight + 12)
	local over = pad + UP * CUT.CruiseHeight
	local hover = pad + UP * CUT.HoverHeight
	local away = hover + facing * 190 + UP * 70
	local function heli(t: number): CFrame
		local position: Vector3
		local pitch = 0
		if t < tFlare then
			local u = t / tFlare
			position = bezier(start, bend, over, 1 - (1 - u) * (1 - u)) -- slowing in
			pitch = -8 * (1 - u) -- nose down at speed
		elseif t < tDrop then
			local u = (t - tFlare) / CUT.Flare
			position = over:Lerp(hover, ease(u))
			pitch = CUT.FlarePitch * math.sin(math.pi * u)
		elseif t < tDepart then
			local u = (t - tDrop) / CUT.Drop
			position = hover + UP * (0.3 * math.sin(u * math.pi * 3))
		else
			local u = math.clamp((t - tDepart) / CUT.Depart, 0, 1)
			position = hover:Lerp(away, u * u) -- gathering speed
			pitch = -10 * math.min(u * 3, 1)
		end
		return CFrame.lookAlong(position, -facing) * CFrame.Angles(-math.rad(pitch), 0, 0)
	end

	-- Every camera stands over the pad: the LZ sits in a cutting whose walls hid a camera
	-- placed off the pad (Nova, first look).
	local function shot(t: number, frame: CFrame): Shot
		if t < tFlare then
			local centre = (frame * CFrame.new(0, 6, 4)).Position
			local from = pad + facing * 12 + side * 6 + UP * 8
			return { from = from, look = centre, fov = CUT.Fov - 10 * (t / tFlare) }
		elseif t < tDepart then
			-- The door side: the squad on the bench, then the jumps to the pad below.
			local u = math.clamp((t - tFlare) / (tDepart - tFlare), 0, 1)
			local doorSide = frame.RightVector
			local from = hover + doorSide * (22 - 4 * u) + facing * 3 + UP * 3
			local look = (frame * CFrame.new(1.5, 1.5, -1.4)).Position:Lerp(pad + UP * 3, 0.35 * u)
			return { from = from, look = look, fov = CUT.Fov + 4 }
		end
		local from = pad + outward * 9 + side * 3 + UP * 4
		return { from = from, look = pad + facing * 30 + UP * 10, fov = CUT.Fov + 8 }
	end

	-- Every client starts together: black, the squad unseen, until the server's start time.
	local wait = startsAt - Workspace:GetServerTimeNow()
	if wait > 0 then
		local untilAt = os.clock() + wait
		while os.clock() < untilAt and not skipRequested do
			for _, model in squadModels() do
				setHidden(model, true)
			end
			task.wait()
		end
	end
	-- The squad aboard: one seat per roster entry, filled at once. A bot's body is built while
	-- the cutscene plays (its outfit loads), so until it exists its stand-in is a copy of this
	-- soldier's (the same uniform), and lands on a free pad; it waits there for the real body.
	local jumpers: { Jumper } = {}
	local stood: { [Model]: boolean } = {}
	local seated: { [Instance]: boolean } = {}
	local seatedBody: { [Model]: boolean } = {}
	local function seatSquad(now: number)
		local members = rosterMembers()
		local entries: { { member: Instance?, body: Model? } } = {}
		if #members > 0 then
			for _, member in members do
				if not seated[member] then
					table.insert(entries, { member = member, body = bodyOf(member) })
				end
			end
		else
			for _, model in squadModels() do
				if not seatedBody[model] then
					table.insert(entries, { member = nil, body = model })
				end
			end
		end
		for _, entry in entries do
			local index = #jumpers + 1
			local seatAt = CUT.Seats[index]
			if not seatAt then
				return
			end
			local starts = tDrop + CUT.JumpStart + (index - 1) * CUT.JumpStagger
			local look = entry.body or player.Character
			if look and now < starts - CUT.StepSeconds then
				local jumper = standIn(look, CFrame.lookAlong(seatAt, Vector3.xAxis), starts)
				if jumper then
					jumper.member = entry.member
					jumper.source = entry.body
					if entry.member then
						seated[entry.member :: Instance] = true
					end
					if entry.body then
						seatedBody[entry.body :: Model] = true
					end
					table.insert(jumpers, jumper)
				end
			end
		end
	end
	seatSquad(0)

	for _, bar in bars do
		bar.Visible = true
	end
	local began = os.clock() - math.max(Workspace:GetServerTimeNow() - startsAt, 0)
	local fadeIn = TweenService:Create(black, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	fadeIn:Play()

	-- A jumper's root over time: seated, up to the door, then an arc down onto its spot.
	local function jumperAt(j: Jumper, t: number, frame: CFrame): CFrame?
		local into = t - j.starts
		if into < 0 then
			return frame * j.seat
		end
		local door = frame
			* CFrame.lookAlong(
				Vector3.new(CUT.DoorX, CUT.DeckY + j.height, j.seat.Position.Z),
				Vector3.xAxis
			)
		if into < CUT.StepSeconds then
			if j.sit and j.sit.IsPlaying then
				j.sit:Stop(0.15)
			end
			return (frame * j.seat):Lerp(door, ease(into / CUT.StepSeconds))
		end
		if not j.from then
			j.from = door
			local source = j.source
			local real = source and source:FindFirstChild("HumanoidRootPart")
			if real and real:IsA("BasePart") then
				j.land = real.CFrame
			else
				-- No body yet: the free pad nearest its seat order, away from every body there.
				local taken: { Vector3 } = {}
				for _, model in squadModels() do
					local root = model:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						table.insert(taken, root.Position)
					end
				end
				for _, other in jumpers do
					if other ~= j and other.land then
						table.insert(taken, (other.land :: CFrame).Position)
					end
				end
				for _, padFrame in padFrames() do
					local free = true
					for _, at in taken do
						if (at - padFrame.Position).Magnitude < 3 then
							free = false
						end
					end
					if free then
						j.land = padFrame
						break
					end
				end
				j.land = j.land or CFrame.lookAlong(pad + UP * 3.5, facing)
			end
			if j.fall then
				j.fall:Play(0.1)
			end
		end
		local u = math.clamp((into - CUT.StepSeconds) / CUT.FallSeconds, 0, 1)
		local a, b = j.from :: CFrame, j.land :: CFrame
		local position = a.Position:Lerp(b.Position, u) + UP * (CUT.JumpArc * 4 * u * (1 - u))
		local turn = a.Rotation:Lerp(b.Rotation, ease(u))
		if u >= 1 then
			return nil -- landed
		end
		return CFrame.new(position) * turn
	end

	local dustOn = false
	local angle = 0
	local connection: RBXScriptConnection
	local function finish()
		connection:Disconnect()
		rotor:Stop()
		lantern:Destroy()
		dustPart:Destroy()
		-- A stand-in whose bot is still being built keeps its place a little longer.
		local waiting: { Jumper } = {}
		for _, j in jumpers do
			if j.waiting and not j.source and j.model.Parent then
				table.insert(waiting, j)
			elseif j.model.Parent then
				j.model:Destroy()
			end
		end
		if #waiting > 0 then
			task.spawn(function()
				local deadline = os.clock() + 15
				while #waiting > 0 and os.clock() < deadline do
					for i = #waiting, 1, -1 do
						local j = waiting[i]
						if j.member and bodyOf(j.member :: Instance) then
							j.model:Destroy()
							table.remove(waiting, i)
						end
					end
					task.wait(0.1)
				end
				for _, j in waiting do
					j.model:Destroy()
				end
			end)
		end
		for _, model in squadModels() do
			setHidden(model, false)
		end
		for _, gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		for _, bar in bars do
			bar.Visible = false
		end
		CameraController.setCinematic(false)
		holdControls(false)
		player:SetAttribute(Attributes.Cinematic, nil)
		playing = false
		black.BackgroundTransparency = 0
		cover(false)
	end
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		local t = os.clock() - began
		if skipRequested or t >= tEnd then
			finish()
			return
		end
		local frame = heli(t)
		angle += math.rad(CUT.RotorSpin) * deltaTime
		local hub = frame * CFrame.new(CUT.Hub)
		local tail = frame * CFrame.new(CUT.TailHub)
		local cframes = table.create(#parts) :: { CFrame }
		for i in parts do
			local name = spin[i]
			if name == "Rotor" then
				cframes[i] = hub * CFrame.Angles(0, angle, 0) * CFrame.new(-CUT.Hub) * rest[i]
			elseif name == "TailRotor" then
				cframes[i] = tail
					* CFrame.Angles(angle * 3, 0, 0)
					* CFrame.new(-CUT.TailHub)
					* rest[i]
			else
				cframes[i] = frame * rest[i]
			end
		end
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

		if t < tDrop then
			seatSquad(t)
		end
		-- The squad: stand-ins ride and jump; each real body shows when its stand-in lands (a
		-- bot built late swaps in when it appears).
		for _, j in jumpers do
			if not j.source and j.member then
				local built = bodyOf(j.member :: Instance)
				if built then
					j.source = built
					seatedBody[built] = true
				end
			end
			if not j.landed then
				local at = jumperAt(j, t, frame)
				if at then
					j.root.CFrame = at
				else
					j.landed = true
					j.root.CFrame = j.land :: CFrame
					if j.fall then
						j.fall:Stop(0.1)
					end
					j.waiting = true
					if j.idle then
						j.idle:Play(0.2)
					end
				end
			end
			local source = j.source
			if j.waiting and source then
				j.waiting = false
				stood[source] = true
				j.model:Destroy()
				setHidden(source, false)
			end
		end
		local everyoneDown = t > tDepart - 0.2
		for _, model in squadModels() do
			if not stood[model] then
				if everyoneDown then
					stood[model] = true
					setHidden(model, false) -- a body with no seat (late, or a fifth)
				else
					setHidden(model, true)
				end
			end
		end

		-- Dust once it is low over the pad, thinning as it climbs away.
		local low = t > tDrop - 0.8 and t < tDepart + 1.2
		if low ~= dustOn then
			dustOn = low
			dust.Rate = if low then 45 else 0
		end

		local view = shot(t, frame)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = view.fov
		camera.CFrame = CFrame.lookAt(view.from, view.look)
		-- Fade to black over the last moment, back to the game.
		if t > tEnd - 0.4 then
			black.BackgroundTransparency = 1 - math.clamp((t - (tEnd - 0.4)) / 0.4, 0, 1)
		end
	end)
end

function InsertionCutscene.isPlaying(): boolean
	return playing
end

function InsertionCutscene.init()
	if not CUT.Enabled then
		return
	end
	buildScreen()
	UserInputService.InputBegan:Connect(function(input)
		if playing and table.find(CUT.SkipKeys, input.KeyCode) then
			skipRequested = true
		end
	end)
	-- Black while the run waits for the squad (Lobby) or for the cutscene (Insert), from the
	-- first frame this client draws; the cutscene lifts it, and so does any later state.
	local function check()
		local state = Workspace:GetAttribute(Attributes.RunState)
		if state == "Lobby" then
			cover(true)
		elseif state == "Insert" then
			task.spawn(play)
		else
			cover(false)
		end
	end
	Workspace:GetAttributeChangedSignal(Attributes.RunState):Connect(check)
	check()
end

return InsertionCutscene
