--!strict
-- The run clock as text: pure, unit-tested with Lune (tests/RunClock.spec.luau).
-- RunTimerUI shows it top centre from the server's RunStartTime.

local RunClock = {}

-- Whole seconds as "MM:SS" (minutes keep counting past 59; part seconds round down).
function RunClock.format(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

return RunClock
