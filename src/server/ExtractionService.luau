--!strict
-- Extraction phase (Sprint 12): RunManager starts it when the objective completes
-- (Extract state). Spawns a glowing zone far from the objective; the squad must
-- accumulate HoldDuration seconds inside it (pauses outside, never resets). On completion
-- the onComplete listeners fire and RunManager ends the run as Extracted. Same hold-zone
-- style as the objective.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local PauseService = require(script.Parent.PauseService)

local ExtractionService = {}

local extractionRemote: RemoteEvent
local completionListeners: { () -> () } = {}

local zonePart: BasePart?
local progress = 0
local active = false
local completed = false
local timeSinceSync = 0
local heartbeatConnection: RBXScriptConnection?

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function isAnyPlayerInZone(zone: BasePart): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
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
	part.Name = "ExtractionZone"
	part.Size = Config.Extraction.ZoneSize
	part.Position = Config.Extraction.ZonePosition
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 0.45
	part.Color = Color3.fromRGB(60, 220, 130)
	part.Material = Enum.Material.Neon

	local marker = Instance.new("BillboardGui")
	marker.Name = "ExtractionMarker"
	marker.Size = UDim2.fromOffset(240, 50)
	marker.StudsOffset = Vector3.new(0, 12, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 2000

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "EXTRACTION"
	label.TextColor3 = Color3.fromRGB(120, 255, 170)
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
	active = false
	workspace:SetAttribute("ExtractionActive", false)

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end

	extractionRemote:FireAllClients("complete", Config.Extraction.HoldDuration)
	print("[ExtractionService] Extraction complete -> mission success")
	-- RunManager ends the run (Ended / Extracted): freezes the field, clears the horde.
	for _, listener in completionListeners do
		listener()
	end
end

function ExtractionService.onComplete(listener: () -> ())
	table.insert(completionListeners, listener)
end

local function onHeartbeat(deltaTime: number)
	local zone = zonePart
	if not active or completed or not zone or PauseService.isPaused() then
		return
	end

	local inside = isAnyPlayerInZone(zone)
	if inside then
		progress += deltaTime
	end

	timeSinceSync += deltaTime
	if timeSinceSync >= Config.Extraction.SyncInterval then
		timeSinceSync = 0
		local kind = if inside then "progress" else "returning"
		extractionRemote:FireAllClients(kind, math.min(progress, Config.Extraction.HoldDuration))
	end

	if progress >= Config.Extraction.HoldDuration then
		complete()
	end
end

function ExtractionService.start()
	if active or completed then
		return
	end
	active = true
	progress = 0
	timeSinceSync = 0
	workspace:SetAttribute("ExtractionActive", true)
	zonePart = createZone()
	extractionRemote:FireAllClients("available", 0)

	for typeName, count in Config.Extraction.PressureWave :: { [string]: number } do
		EnemyService.spawnWave(typeName, count, Config.Extraction.ZonePosition)
	end

	heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	print("[ExtractionService] Extraction available")
end

-- Dev shortcut: jump straight to mission success.
function ExtractionService.forceComplete()
	if not active then
		ExtractionService.start()
	end
	complete()
end

function ExtractionService.reset()
	active = false
	completed = false
	progress = 0
	timeSinceSync = 0
	workspace:SetAttribute("ExtractionActive", false)
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end
	extractionRemote:FireAllClients("hide", 0)
end

function ExtractionService.init()
	extractionRemote = Remotes.get("ExtractionUpdate")
	workspace:SetAttribute("ExtractionActive", false)
end

return ExtractionService
