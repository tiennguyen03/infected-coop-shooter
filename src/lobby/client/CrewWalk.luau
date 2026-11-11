--!strict
-- Walks the Carrier's crew (CrewService places them, tagged) back and forth along their
-- routes on this client only, with the stock R15 walk and idle (their joints swing the
-- limbs; only the anchored root moves), a pause at each end, and a line over their head when
-- you come close (LobbyCrew). One BulkMoveTo a frame for all the roots; nothing replicates
-- (the server never moves them again). Walking, their boots sound on the deck: the match's
-- Footsteps bank, one step every Config.Lobby.Ambience.CrewStepLength studs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyCrew = require(ReplicatedStorage.Lobby.LobbyCrew)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)

local CrewWalk = {}

local CREW = Config.Lobby.Crew
local AMB = Config.Lobby.Ambience

type Walker = {
	model: Model,
	root: BasePart,
	height: number, -- the root's centre above the feet
	route: { Vector3 },
	leg: number, -- heading from route[leg] to route[leg + dir]
	dir: number,
	along: number, -- studs walked along the current leg
	waitUntil: number,
	walk: AnimationTrack?,
	idle: AnimationTrack?,
	walking: boolean,
	bubble: TextLabel,
	hideAt: number,
	nextLine: number,
	lines: { string },
	steps: Sound,
	stepDist: number, -- studs walked since the last footstep
}

local walkers: { Walker } = {}
local random = Random.new()

local function decode(text: string): { Vector3 }
	local route = {}
	for _, point in string.split(text, ";") do
		local xyz = string.split(point, ",")
		local x, y, z = tonumber(xyz[1]), tonumber(xyz[2]), tonumber(xyz[3])
		if x and y and z then
			table.insert(route, Vector3.new(x, y, z))
		end
	end
	return route
end

-- The line over a crew member's head. It lives in the PlayerGui, pointed at the head: dressing
-- the body (NpcBody) replaces the head after CrewWalk first sees it, and a bubble parented to
-- the old head went with it (every frame near that figure then raised: the lobby's lag,
-- 2026-11-11). bubbleOf finds the current head again.
local function bubbleOn(head: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrewLine"
	gui.ResetOnSpawn = false
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = CREW.BubbleDistance * 2
	gui.LightInfluence = 0
	gui.Enabled = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	text.BackgroundTransparency = 0.25
	text.TextColor3 = Color3.fromRGB(236, 232, 220)
	text.Font = Enum.Font.Gotham
	text.TextSize = 15
	text.TextWrapped = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = text
	text.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return text
end

local function bubbleOf(w: Walker): BillboardGui?
	local gui = w.bubble.Parent
	if not (gui and gui:IsA("BillboardGui")) then
		return nil
	end
	local head = gui.Adornee
	if not (head and head:IsDescendantOf(w.model)) then
		local fresh = w.model:FindFirstChild("Head")
		gui.Adornee = if fresh and fresh:IsA("BasePart") then fresh else nil :: any
	end
	return gui
end

local function add(model: Model)
	local id = model:GetAttribute(Attributes.CrewId)
	local routeText = model:GetAttribute(Attributes.CrewRoute)
	if type(id) ~= "string" or type(routeText) ~= "string" then
		return
	end
	local route = decode(routeText)
	local head = model:WaitForChild("Head", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if #route < 2 or not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	local lines = {}
	for _, crew in LobbyCrew do
		if crew.id == id then
			lines = crew.lines
		end
	end
	local steps = SoundBanks.create("CrewSteps", 6, AMB.CrewStepFar)
	steps.Parent = root
	table.insert(walkers, {
		model = model,
		root = root,
		height = (if humanoid then humanoid.HipHeight else 2.19) + root.Size.Y / 2,
		route = route,
		leg = 1,
		dir = 1,
		along = 0,
		waitUntil = os.clock() + random:NextNumber(0, CREW.Pause),
		walk = nil,
		idle = nil,
		walking = false,
		bubble = bubbleOn(head),
		hideAt = 0,
		nextLine = 0,
		lines = lines,
		steps = steps,
		stepDist = random:NextNumber(0, AMB.CrewStepLength),
	})
end

-- The walk and idle clips, loaded on this client once the body is dressed (dressing rebuilds
-- the joints the clips drive).
local function tracks(w: Walker): boolean
	if w.walk then
		return true
	end
	if not w.model:GetAttribute(Attributes.CrewReady) then
		return false
	end
	local humanoid = w.model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local function load(id: string): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		return track
	end
	w.walk = load(CREW.Animations.Walk)
	w.idle = load(CREW.Animations.Idle);
	(w.idle :: AnimationTrack):Play()
	w.walking = false
	return true
end

-- Where the walker is now and which way it faces; advances it by dt. Returns the feet and
-- whether it is walking.
local function step(w: Walker, dt: number, now: number): (CFrame, boolean)
	local from = w.route[w.leg]
	local to = w.route[w.leg + w.dir]
	local legLength = (to - from).Magnitude
	if now >= w.waitUntil then
		w.along += CREW.WalkSpeed * dt
		if w.along >= legLength then
			-- Next leg; at either end, turn round and stand a while.
			w.leg += w.dir
			w.along = 0
			local nextIndex = w.leg + w.dir
			if nextIndex < 1 or nextIndex > #w.route then
				w.dir = -w.dir
				w.waitUntil = now + CREW.Pause
			end
			from = w.route[w.leg]
			to = w.route[w.leg + w.dir]
			legLength = (to - from).Magnitude
		end
	end
	local walking = now >= w.waitUntil
	local position = from:Lerp(to, if legLength > 0 then math.min(w.along / legLength, 1) else 1)
	local flat = (to - from) * Vector3.new(1, 0, 1)
	local feet = if flat.Magnitude > 0.01
		then CFrame.lookAt(position, position + flat)
		else CFrame.new(position)
	return feet, walking
end

local function frame(dt: number)
	local now = os.clock()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local me = if root and root:IsA("BasePart") then root.Position else nil
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for i = #walkers, 1, -1 do
		local w = walkers[i]
		if not w.model.Parent then
			local gui = w.bubble.Parent
			if gui then
				gui:Destroy()
			end
			table.remove(walkers, i)
			continue
		end
		local feet, walking = step(w, dt, now)
		table.insert(parts, w.root)
		table.insert(cframes, feet + Vector3.new(0, w.height, 0))
		if tracks(w) and walking ~= w.walking then
			w.walking = walking
			local walk, idle = w.walk :: AnimationTrack, w.idle :: AnimationTrack
			if walking then
				walk:Play(0.25, 1, CREW.WalkClipSpeed)
				idle:Stop(0.25)
			else
				idle:Play(0.25)
				walk:Stop(0.25)
			end
		end
		if walking then
			w.stepDist += CREW.WalkSpeed * dt
			if w.stepDist >= AMB.CrewStepLength then
				w.stepDist -= AMB.CrewStepLength
				SoundBanks.play(w.steps, "Footsteps", "step_hard", AMB.CrewStepVolume)
			end
		end
		-- A line when a soldier walks close, then quiet for a while.
		if
			me
			and #w.lines > 0
			and now >= w.nextLine
			and (feet.Position - me).Magnitude <= CREW.BubbleDistance
		then
			w.hideAt = now + CREW.BubbleSeconds
			w.nextLine = now + CREW.BubbleCooldown
			local gui = bubbleOf(w)
			if gui then
				w.bubble.Text = w.lines[random:NextInteger(1, #w.lines)]
				gui.Enabled = true
			end
		elseif w.hideAt > 0 and now >= w.hideAt then
			w.hideAt = 0
			local gui = bubbleOf(w)
			if gui then
				gui.Enabled = false
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function CrewWalk.init()
	CollectionService:GetInstanceAddedSignal(Attributes.CrewTag):Connect(function(instance)
		if instance:IsA("Model") then
			add(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(Attributes.CrewTag) do
		if instance:IsA("Model") then
			add(instance)
		end
	end
	RunService.Heartbeat:Connect(frame)
end

return CrewWalk
