--!strict
-- Hold Position objective V1: one zone appears mid-run, progress accumulates
-- while any player stands inside (pauses outside, never resets), pays out XP
-- once on completion, and never repeats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyService = require(script.Parent.EnemyService)
local PauseService = require(script.Parent.PauseService)
local RequisitionService = require(script.Parent.RequisitionService)
local XPService = require(script.Parent.XPService)
local Squad = require(script.Parent.Squad)

local ObjectiveService = {}

local objectiveRemote: RemoteEvent
-- ExtractionService registers here to start extraction on completion.
local completionListeners: { () -> () } = {}
local activationListeners: { () -> () } = {}

local zonePart: BasePart?
local progress = 0
local completed = false
local heartbeatConnection: RBXScriptConnection?
local timeSinceSync = 0
-- Bumped on every run reset so a pending activation timer from a previous
-- run never fires into the new one.
local runGeneration = 0

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function isAnyPlayerInZone(zone: BasePart): boolean
	-- Any living squad member (player or bot) holds the zone.
	for _, member in Squad.living() do
		local character = member.character
		if character then
			overlapParams.FilterDescendantsInstances = { character }
			if #workspace:GetPartsInPart(zone, overlapParams) > 0 then
				return true
			end
		end
	end
	return false
end

local function createZone(): BasePart
	local part = Instance.new("Part")
	part.Name = "ObjectiveZone"
	part.Size = Config.Objective.ZoneSize
	part.Position = Config.Objective.ZonePosition
	part.Anchored = true
	part.CanCollide = false
	-- CanQuery off so weapon raycasts pass through the zone; GetPartsInPart
	-- still works with the zone itself as the query region.
	part.CanQuery = false
	part.Transparency = 0.5
	part.Color = Color3.fromRGB(255, 220, 0)
	part.Material = Enum.Material.Neon

	local marker = Instance.new("BillboardGui")
	marker.Name = "ObjectiveMarker"
	marker.Size = UDim2.fromOffset(220, 50)
	marker.StudsOffset = Vector3.new(0, 10, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 1000

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "OBJECTIVE"
	label.TextColor3 = Color3.fromRGB(255, 220, 0)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = marker

	marker.Parent = part
	part.Parent = workspace
	return part
end

local function complete()
	if completed then
		return
	end
	completed = true
	workspace:SetAttribute("ObjectiveActive", false)
	workspace:SetAttribute("ObjectiveCompleted", true)
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end

	for _, player in Players:GetPlayers() do
		XPService.addXP(player, Config.Objective.XPReward)
	end
	RequisitionService.addRequisition(Config.Objective.XPReward)

	objectiveRemote:FireAllClients("completed", Config.Objective.RequiredSeconds)
	print("[ObjectiveService] Objective complete -> extraction")
	for _, listener in completionListeners do
		listener()
	end
end

-- RunManager subscribes: Primary -> Index -> Extract when the hold is done.
function ObjectiveService.onComplete(listener: () -> ())
	table.insert(completionListeners, listener)
end

-- Dev shortcut: complete the objective immediately (works even before it spawns).
function ObjectiveService.forceComplete()
	complete()
end

local function onHeartbeat(deltaTime: number)
	local zone = zonePart
	if completed or not zone or PauseService.isPaused() then
		return
	end

	if isAnyPlayerInZone(zone) then
		progress += deltaTime
	end

	timeSinceSync += deltaTime
	if timeSinceSync >= Config.Objective.SyncInterval then
		timeSinceSync = 0
		objectiveRemote:FireAllClients(
			"progress",
			math.min(progress, Config.Objective.RequiredSeconds)
		)
	end

	if progress >= Config.Objective.RequiredSeconds then
		complete()
	end
end

local function activate()
	if completed then
		return
	end
	zonePart = createZone()
	objectiveRemote:FireAllClients("started", 0)
	heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	-- Pressure: faster spawns while active + a typed wave around the zone.
	workspace:SetAttribute("ObjectiveActive", true)
	for typeName, count in Config.Objective.PressureWave :: { [string]: number } do
		EnemyService.spawnWave(typeName, count, Config.Objective.ZonePosition)
	end
	if DifficultyService.getElapsed() >= Config.Objective.PressureBruteAfter then
		EnemyService.spawnWave("Brute", 1, Config.Objective.ZonePosition)
	end
	print("[ObjectiveService] Objective active")
	for _, listener in activationListeners do
		listener()
	end
end

-- RunManager: Explore -> Primary when the hold zone appears.
function ObjectiveService.onActivated(listener: () -> ())
	table.insert(activationListeners, listener)
end

local function scheduleActivation()
	runGeneration += 1
	local generation = runGeneration
	task.delay(Config.Objective.AppearDelay, function()
		if generation == runGeneration then
			activate()
		end
	end)
end

function ObjectiveService.reset()
	completed = false
	progress = 0
	timeSinceSync = 0
	workspace:SetAttribute("ObjectiveActive", false)
	workspace:SetAttribute("ObjectiveCompleted", false)
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end
	objectiveRemote:FireAllClients("completed", 0) -- hides any open objective UI
	runGeneration += 1 -- cancels a pending activation from the previous run
end

-- Dev: bring the hold zone in now instead of after Config.Objective.AppearDelay.
function ObjectiveService.activateNow()
	runGeneration += 1
	activate()
end

-- RunManager, on Explore: start the timer that brings the hold zone in.
function ObjectiveService.arm()
	scheduleActivation()
end

function ObjectiveService.init()
	objectiveRemote = Remotes.get("ObjectiveUpdate")
end

return ObjectiveService
