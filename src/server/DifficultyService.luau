--!strict
-- Tracks run time and derives difficulty scaling from it. Stateless beyond
-- the run start timestamp: every getter computes from elapsed time, so
-- there is no scaling loop to keep in sync. The start time is published as
-- a workspace attribute for client UI (run timer).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DifficultyService = {}

local startClock = 0

-- Starts (or restarts) the run clock; scaling and the run timer both derive
-- from it.
function DifficultyService.restart()
	startClock = workspace:GetServerTimeNow()
	workspace:SetAttribute("RunStartTime", startClock)
end

function DifficultyService.init()
	DifficultyService.restart()
end

function DifficultyService.getElapsed(): number
	return workspace:GetServerTimeNow() - startClock
end

local function elapsedMinutes(): number
	return DifficultyService.getElapsed() / 60
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
	local interval = Config.Zombies.SpawnInterval
		* Config.Difficulty.SpawnIntervalDecayPerMinute ^ elapsedMinutes()
	return math.max(interval, Config.Difficulty.MinSpawnInterval)
end

function DifficultyService.getMaxAlive(): number
	local elapsed = DifficultyService.getElapsed()
	for _, entry in Config.Difficulty.MaxAliveSchedule do
		if elapsed <= entry[1] then
			return entry[2]
		end
	end
	return Config.Difficulty.MaxAliveLate
end

return DifficultyService
