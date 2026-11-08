--!strict
-- Tracks run time and derives the spawn pressure from it. The threat clock is accumulated
-- unpaused time (MULTIPLAYER_READINESS #5): a paused field (PauseService, the run-end
-- freeze) does not advance the spawn ramp or the max-alive schedule. Every getter computes
-- from that clock, so there is no scaling loop to keep in sync. The wall-clock start is
-- published as a workspace attribute for the HUD run timer. The threat curve is flat
-- (Config.Difficulty health/damage at 1x since the loadout rework): pressure comes from
-- the spawn interval decay, the max-alive schedule and the player count
-- (Config.PlayerCountScaling: more Infected, never tougher ones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local DifficultyCurve = require(ReplicatedStorage.Shared.Rules.DifficultyCurve)
local Squad = require(script.Parent.Squad)
local PauseService = require(script.Parent.PauseService)
local RunService = game:GetService("RunService")
local Lifecycle = require(script.Parent.Lifecycle)

local DifficultyService = {}

local startClock = 0
local elapsed = 0 -- unpaused seconds since the run started
local lastStep = os.clock()

-- Starts (or restarts) the run clock; scaling and the run timer both derive
-- from it.
function DifficultyService.restart()
	startClock = workspace:GetServerTimeNow()
	elapsed = 0
	lastStep = os.clock()
	workspace:SetAttribute(Attributes.RunStartTime, startClock)
end

function DifficultyService.init()
	Lifecycle.register("DifficultyService", {
		onRunStart = DifficultyService.restart,
	})
	DifficultyService.restart()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if not PauseService.isPaused() then
			elapsed += now - lastStep
		end
		lastStep = now
	end)
end

-- Unpaused seconds since the run started (the threat clock).
function DifficultyService.getElapsed(): number
	return elapsed
end

local function elapsedMinutes(): number
	return DifficultyService.getElapsed() / 60
end

-- Living players beyond the first (the Infected scale with people, not with bots).
function DifficultyService.getExtraPlayers(): number
	return math.max(#Squad.livingOwners() - 1, 0)
end

function DifficultyService.getHealthMultiplier(): number
	return math.min(
		1 + elapsedMinutes() * Config.Difficulty.HealthPerMinute,
		Config.Difficulty.HealthCap
	)
end

function DifficultyService.getDamageMultiplier(): number
	return math.min(
		1 + elapsedMinutes() * Config.Difficulty.DamagePerMinute,
		Config.Difficulty.DamageCap
	)
end

function DifficultyService.getSpawnInterval(): number
	return DifficultyCurve.spawnInterval(
		Config.Spawning.SpawnInterval,
		Config.Difficulty.SpawnIntervalDecayPerMinute,
		Config.Difficulty.MinSpawnInterval,
		DifficultyService.getElapsed(),
		Config.PlayerCountScaling.SpawnIntervalPerExtraPlayer,
		DifficultyService.getExtraPlayers()
	)
end

function DifficultyService.getMaxAlive(): number
	local scaling = Config.PlayerCountScaling
	return DifficultyCurve.maxAlive(
		Config.Difficulty.MaxAliveSchedule,
		Config.Difficulty.MaxAliveLate,
		DifficultyService.getElapsed(),
		scaling.MaxAlivePerExtraPlayer,
		scaling.MaxAliveHardCap,
		DifficultyService.getExtraPlayers()
	)
end

return DifficultyService
