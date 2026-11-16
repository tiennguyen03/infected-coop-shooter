--!strict
-- Throw timing (docs/PROGRESSION.md > Throwing): the thing leaves the hand when the throw
-- clip says so, not when the key comes up. Pure, unit-tested with Lune
-- (tests/ThrowTiming.spec.luau). Config.Animations.Throws has one row per throw clip (and a
-- Default): the clip plays from `Start` seconds in at `Speed`, and the hand lets go when the
-- clip reaches `Release`. The client plays the clip that way at once (AnimationController);
-- the server holds the real throw back for the same wind-up (ThrowWindUp).

local ThrowTiming = {}

export type Timing = {
	Start: number, -- seconds into the clip where it starts playing (skips a long lead-in)
	Release: number, -- seconds into the clip where the hand lets go
	Speed: number, -- play speed
}

-- The row for `clip` over `rows.Default`. Neither table is changed.
function ThrowTiming.resolve(rows: { [string]: any }, clip: string?): Timing
	local resolved = table.clone(rows.Default)
	local row = if clip then rows[clip] else nil
	if row then
		for key, value in row do
			resolved[key] = value
		end
	end
	return resolved :: any
end

-- Seconds from the clip starting until the hand lets go.
function ThrowTiming.windUp(timing: Timing): number
	local speed = if timing.Speed > 0 then timing.Speed else 1
	return math.max(timing.Release - timing.Start, 0) / speed
end

-- Seconds the server waits before the throw happens. The thrower's clip started `lag`
-- seconds before the server heard of it, so up to `maxCompensation` of that comes off.
function ThrowTiming.serverWait(windUp: number, lag: number, maxCompensation: number): number
	return math.max(windUp - math.clamp(lag, 0, math.max(maxCompensation, 0)), 0)
end

return ThrowTiming
