--!strict
-- Tracks run time and derives the spawn pressure from it. Stateless beyond
-- the run start timestamp: every getter computes from elapsed time, so
-- there is no scaling loop to keep in sync. The start time is published as
-- a workspace attribute for client UI (run timer). The threat curve is flat
-- (Config.Difficulty health/damage at 1x since the loadout rework): pressure comes from
-- the spawn interval decay, the max-alive schedule and the player count
-- (Config.PlayerCountScaling: more Infected, never tougher ones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)

local DifficultyService = {}

local startClock = 0

-- Starts (or restarts) the run clock; scaling and the run timer both derive
-- from it.
function DifficultyService.restart()
	startClock = workspace:GetServerTimeNow()
	workspace:SetAttribute("RunStartTime", startClock)
end

function DifficultyService.init()
	Lifecycle.register("DifficultyService", {
		onRunStart = DifficultyService.restart,
	})
	DifficultyService.restart()
end

function DifficultyService.getElapsed(): number
	return workspace:GetServerTimeNow() - startClock
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
	local interval = Config.Spawning.SpawnInterval
		* Config.Difficulty.SpawnIntervalDecayPerMinute ^ elapsedMinutes()
	interval = math.max(interval, Config.Difficulty.MinSpawnInterval)
	return interval
		* Config.PlayerCountScaling.SpawnIntervalPerExtraPlayer
			^ DifficultyService.getExtraPlayers()
end

function DifficultyService.getMaxAlive(): number
	local elapsed = DifficultyService.getElapsed()
	local base = Config.Difficulty.MaxAliveLate
	for _, entry in Config.Difficulty.MaxAliveSchedule do
		if elapsed <= entry[1] then
			base = entry[2]
			break
		end
	end
	local scaling = Config.PlayerCountScaling
	return math.min(
		base + scaling.MaxAlivePerExtraPlayer * DifficultyService.getExtraPlayers(),
		scaling.MaxAliveHardCap
	)
end

return DifficultyService
