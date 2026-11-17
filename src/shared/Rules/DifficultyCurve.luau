--!strict
-- The threat curve (docs/ARCHITECTURE.md F5): pure, unit-tested with Lune
-- (tests/DifficultyCurve.spec.luau). DifficultyService feeds it Config and the unpaused
-- threat clock. Pressure comes from spawn pacing, the max-alive schedule and the number of
-- living players beyond the first; never from tougher Infected.

local DifficultyCurve = {}

-- Seconds between spawns after `seconds` of unpaused run time.
function DifficultyCurve.spawnInterval(
	base: number,
	decayPerMinute: number,
	minInterval: number,
	seconds: number,
	perExtraPlayer: number,
	extraPlayers: number
): number
	local interval = math.max(base * decayPerMinute ^ (seconds / 60), minInterval)
	return interval * perExtraPlayer ^ extraPlayers
end

-- Infected alive at once: the schedule's first entry whose time is not yet past, else the
-- late value, plus a share per extra player, never above the hard cap.
function DifficultyCurve.maxAlive(
	schedule: { { number } },
	late: number,
	seconds: number,
	perExtraPlayer: number,
	hardCap: number,
	extraPlayers: number
): number
	local base = late
	for _, entry in schedule do
		if seconds <= entry[1] then
			base = entry[2]
			break
		end
	end
	return math.min(base + perExtraPlayer * extraPlayers, hardCap)
end

-- Infected health or damage multiplier after `seconds` of unpaused run time: 1 at the
-- start, growing by `perMinute` each minute, never above `cap`. Flat (0 per minute, cap 1)
-- since the loadout rework.
function DifficultyCurve.multiplier(perMinute: number, cap: number, seconds: number): number
	return math.min(1 + seconds / 60 * perMinute, cap)
end

return DifficultyCurve
