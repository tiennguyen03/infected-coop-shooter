--!strict
-- Walks the Carrier's crew (CrewService places them, tagged) back and forth along their
-- routes on this client only, with a plain leg and arm swing, a pause at each end, and a
-- line over their head when you come close (LobbyCrew). One BulkMoveTo a frame for all of
-- them; nothing replicates (the server never moves them again).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyCrew = require(ReplicatedStorage.Lobby.LobbyCrew)

local CrewWalk = {}

local CREW = Config.Lobby.Crew
local SWINGS = { LeftLeg = 1, RightLeg = -1, LeftArm = -1, RightArm = 1 }
local HIP_Y, SHOULDER_Y = 2.2, 4.2 -- above the feet: where legs and arms pivot

type Walker = {
	model: Model,
	route: { Vector3 },
	leg: number, -- heading from route[leg] to route[leg + dir]
	dir: number,
	along: number, -- studs walked along the current leg
	waitUntil: number,
	parts: { BasePart },
	rest: { CFrame }, -- each part relative to the feet, facing -Z
	swing: { number }, -- each part's swing sign (0: none)
	pivotY: { number },
	bubble: TextLabel,
	hideAt: number,
	nextLine: number,
	lines: { string },
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

local function bubbleOn(head: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrewLine"
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
	gui.Parent = head
	return text
end

local function add(model: Model)
	local id = model:GetAttribute(Attributes.CrewId)
	local routeText = model:GetAttribute(Attributes.CrewRoute)
	if type(id) ~= "string" or type(routeText) ~= "string" then
		return
	end
	local route = decode(routeText)
	local head = model:FindFirstChild("Head")
	if #route < 2 or not (head and head:IsA("BasePart")) then
		return
	end
	local lines = {}
	for _, crew in LobbyCrew do
		if crew.id == id then
			lines = crew.lines
		end
	end
	-- Each part's place relative to the feet, read from how the server stood them up.
	local feet = CFrame.lookAt(route[1], route[1] + (route[2] - route[1]) * Vector3.new(1, 0, 1))
	local walker: Walker = {
		model = model,
		route = route,
		leg = 1,
		dir = 1,
		along = 0,
		waitUntil = os.clock() + random:NextNumber(0, CREW.Pause),
		parts = {},
		rest = {},
		swing = {},
		pivotY = {},
		bubble = bubbleOn(head),
		hideAt = 0,
		nextLine = 0,
		lines = lines,
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(walker.parts, part)
			table.insert(walker.rest, feet:ToObjectSpace(part.CFrame))
			table.insert(walker.swing, SWINGS[part.Name] or 0)
			table.insert(walker.pivotY, if string.find(part.Name, "Leg") then HIP_Y else SHOULDER_Y)
		end
	end
	table.insert(walkers, walker)
end

-- Where the walker is now and which way it faces; advances it by dt. Returns the feet and
-- the stride phase (0 when standing).
local function step(w: Walker, dt: number, now: number): (CFrame, number)
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
	return feet, if walking then w.along / CREW.Stride * math.pi else 0
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
			table.remove(walkers, i)
			continue
		end
		local feet, phase = step(w, dt, now)
		local angle = math.sin(phase) * math.rad(CREW.SwingDegrees)
		for j, part in w.parts do
			local rest = w.rest[j]
			local sign = w.swing[j]
			if sign ~= 0 and angle ~= 0 then
				-- Swing about the hip or shoulder, front to back.
				local pivot = CFrame.new(0, w.pivotY[j], rest.Position.Z)
				rest = pivot * CFrame.Angles(angle * sign, 0, 0) * pivot:Inverse() * rest
			end
			table.insert(parts, part)
			table.insert(cframes, feet * rest)
		end
		-- A line when a soldier walks close, then quiet for a while.
		if
			me
			and #w.lines > 0
			and now >= w.nextLine
			and (feet.Position - me).Magnitude <= CREW.BubbleDistance
		then
			w.bubble.Text = w.lines[random:NextInteger(1, #w.lines)]
			local gui = w.bubble.Parent :: BillboardGui
			gui.Enabled = true
			w.hideAt = now + CREW.BubbleSeconds
			w.nextLine = now + CREW.BubbleCooldown
		elseif w.hideAt > 0 and now >= w.hideAt then
			w.hideAt = 0
			local gui = w.bubble.Parent :: BillboardGui
			gui.Enabled = false
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
