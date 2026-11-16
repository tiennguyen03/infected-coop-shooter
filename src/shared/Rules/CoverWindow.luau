--!strict
-- The cover-move immunity window (vault, climb, roll): pure, unit-tested with Lune
-- (tests/CoverWindow.spec.luau). CoverMoveService feeds it the server clock, the player's
-- last window and Config.Movement. A window lasts the move plus a grace; a move made before
-- the last window has ended and cooled down buys nothing, so moves can't be chained into
-- standing immunity.

local CoverWindow = {}

-- When the window opened by a move at `now` ends, or nil when the move buys none.
-- `lastEnd` is when this player's previous window ended (nil: no window yet).
function CoverWindow.open(
	now: number,
	lastEnd: number?,
	cooldown: number,
	duration: number,
	grace: number
): number?
	if lastEnd and now < lastEnd + cooldown then
		return nil
	end
	return now + duration + grace
end

return CoverWindow
