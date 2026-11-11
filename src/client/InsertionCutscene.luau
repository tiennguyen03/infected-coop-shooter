--!strict
-- The insertion cutscene (Nova, 2026-11-11: "a cutscene of the lantern dropping the squad off at
-- the landing zone"; Config.Insertion). When the run enters Insert this client flies its own copy
-- of the Lantern (the server's ReplicatedStorage.InsertLantern) and holds the camera for three
-- shots:
--   1. Approach: from a spot on the ground beside the LZ, the helicopter comes in low over the
--      city from the map's edge and slows over the pad.
--   2. Flare and hover: from its door side, it noses up, settles a few studs over the pad and
--      hovers in its own dust.
--   3. The drop: a blink, and from behind the squad, now standing on the pad, it climbs away
--      over their heads.
-- Letterbox bars; the HUD hidden; the soldier held (no moving, firing or kit: Attributes
-- .Cinematic); the squad's bodies hidden until the drop. SkipKeys end it for this player. It
-- ends on a short fade back to the follow camera (CameraController.setCinematic).

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

local playing = false
local skipRequested = false

-- Smoothstep easing.
local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, u: number): Vector3
	local ab = a:Lerp(b, u)
	local bc = b:Lerp(c, u)
	return ab:Lerp(bc, u)
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

local function setSquadHidden(hidden: boolean)
	local value = if hidden then 1 else 0
	for _, model in squadModels() do
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = value
			elseif part:IsA("Decal") then
				part.LocalTransparencyModifier = value
			end
		end
	end
end

-- The bars, and a black frame for the blink and the fades, over everything.
local function buildScreen(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "InsertionCutscene"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.Size = UDim2.fromScale(1, CUT.Letterbox)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1 - CUT.Letterbox)
		bar.Parent = gui
	end
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.BorderSizePixel = 0
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = gui
	return gui, black
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
	dust.LockedToPart = false
	dust.Parent = anchor
	anchor.Parent = Workspace
	return anchor, dust
end

-- Hides every HUD screen but ours; returns the ones it hid.
local function hideHud(keep: ScreenGui): { ScreenGui }
	local hidden = {}
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if gui then
		for _, screen in gui:GetChildren() do
			if screen:IsA("ScreenGui") and screen ~= keep and screen.Enabled then
				screen.Enabled = false
				table.insert(hidden, screen)
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

local function play()
	if playing then
		return
	end
	playing = true
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
		return
	end

	skipRequested = false
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

	local screen, black = buildScreen()
	screen.Parent = player:WaitForChild("PlayerGui")
	local hidden = hideHud(screen)
	local dustPart, dust = buildDust(pad + UP * 0.5)
	player:SetAttribute(Attributes.Cinematic, true)
	holdControls(true)
	CameraController.setCinematic(true)
	camera.CameraType = Enum.CameraType.Scriptable

	-- The flight, as frames of the helicopter over time.
	local start = pad + outward * CUT.StartDistance + UP * CUT.StartHeight
	local bend = pad + outward * CUT.StartDistance * 0.35 + UP * (CUT.CruiseHeight + 12)
	local over = pad + UP * CUT.CruiseHeight
	local hover = pad + UP * CUT.HoverHeight
	local away = hover + facing * 190 + UP * 70
	local tFlare = CUT.Approach
	local tDrop = tFlare + CUT.Flare
	local tReveal = tDrop + CUT.Drop / 2
	local tDepart = tDrop + CUT.Drop
	local tEnd = CUT.Seconds

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
			position = hover + UP * (0.4 * math.sin(u * math.pi * 3))
		else
			local u = math.clamp((t - tDepart) / CUT.Depart, 0, 1)
			position = hover:Lerp(away, u * u) -- gathering speed
			pitch = -10 * math.min(u * 3, 1)
		end
		-- The Lantern's nose is +Z in its own frame (the tail rotor sits at -Z, Config.Insertion
		-- .TailHub): look along -facing so the nose leads; a positive pitch raises the nose.
		return CFrame.lookAlong(position, -facing) * CFrame.Angles(-math.rad(pitch), 0, 0)
	end

	local function shot(t: number, frame: CFrame): Shot
		-- Every camera stands over the pad itself: the LZ sits in a cutting whose walls hid a
		-- camera placed off the pad (Nova, first look).
		local centre = (frame * CFrame.new(0, 6, 4)).Position
		if t < tFlare then
			local from = pad + facing * 12 + side * 6 + UP * 8
			return { from = from, look = centre, fov = CUT.Fov - 10 * (t / tFlare) }
		elseif t < tReveal then
			local u = (t - tFlare) / (tReveal - tFlare)
			local door = (hover - pad) + frame.RightVector * (20 - 4 * u) + facing * 4 + UP * 5
			return { from = pad + door, look = centre, fov = CUT.Fov }
		end
		local from = pad + outward * 9 + side * 3 + UP * 4
		return { from = from, look = pad + facing * 30 + UP * 10, fov = CUT.Fov + 8 }
	end

	local function blinkAt(t: number): number
		-- Black for a moment at the cut to the drop, and fading out at the end.
		local cut = math.abs(t - tReveal)
		local cutBlack = if cut < 0.18 then 1 - cut / 0.18 else 0
		local endBlack = math.clamp((t - (tEnd - 0.4)) / 0.4, 0, 1)
		return math.max(cutBlack, endBlack)
	end

	-- Every client starts together: black, the squad unseen, until the server's start time.
	local wait = startsAt - Workspace:GetServerTimeNow()
	if wait > 0 then
		black.BackgroundTransparency = 0
		local untilAt = os.clock() + wait
		while os.clock() < untilAt and not skipRequested do
			setSquadHidden(true)
			task.wait()
		end
	end
	local began = os.clock() - math.max(Workspace:GetServerTimeNow() - startsAt, 0)
	local dustOn = false
	local revealed = false
	local angle = 0
	setSquadHidden(true)
	local connection: RBXScriptConnection
	local function finish()
		connection:Disconnect()
		rotor:Stop()
		lantern:Destroy()
		dustPart:Destroy()
		setSquadHidden(false)
		for _, gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		CameraController.setCinematic(false)
		holdControls(false)
		player:SetAttribute(Attributes.Cinematic, nil)
		black.BackgroundTransparency = 0
		local out = TweenService:Create(black, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		out.Completed:Once(function()
			screen:Destroy()
		end)
		out:Play()
		playing = false
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

		-- Dust once it is low over the pad, thinning as it climbs away.
		local low = t > tDrop - 0.8 and t < tDepart + 1.2
		if low ~= dustOn then
			dustOn = low
			dust.Rate = if low then 45 else 0
		end
		if not revealed and t >= tReveal then
			revealed = true
			setSquadHidden(false)
		elseif not revealed then
			setSquadHidden(true) -- a body that spawned late, an accessory that loaded
		end

		local view = shot(t, frame)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = view.fov
		camera.CFrame = CFrame.lookAt(view.from, view.look)
		black.BackgroundTransparency = 1 - blinkAt(t)
	end)
end

function InsertionCutscene.isPlaying(): boolean
	return playing
end

function InsertionCutscene.init()
	if not CUT.Enabled then
		return
	end
	UserInputService.InputBegan:Connect(function(input)
		if playing and table.find(CUT.SkipKeys, input.KeyCode) then
			skipRequested = true
		end
	end)
	local function check()
		if Workspace:GetAttribute(Attributes.RunState) == "Insert" then
			task.spawn(play)
		end
	end
	Workspace:GetAttributeChangedSignal(Attributes.RunState):Connect(check)
	check()
end

return InsertionCutscene
