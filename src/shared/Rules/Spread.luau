--!strict
-- The shot cone (Config.Weapons.<id>.HipSpread / AdsSpread + bloom): where a round goes off
-- the aim. Pure numbers so the client (pellet tracers it draws) and the server (the hits it
-- deals) agree; the caller turns (angle, roll) into a direction with a CFrame.

local Spread = {}

-- A point uniform over the cone's disc from two uniforms in [0, 1]: the angle off the aim
-- (radians, at most the half-angle) and the roll around it (radians).
function Spread.sample(halfAngleDegrees: number, u1: number, u2: number): (number, number)
	if halfAngleDegrees <= 0 then
		return 0, 0
	end
	return math.rad(halfAngleDegrees) * math.sqrt(u1), u2 * math.pi * 2
end

-- True when a round `angleDegrees` off the aim may be taken as fired inside a cone of
-- `halfAngleDegrees` (the server checking pellets a client drew; `tolerance` covers float
-- and aim drift between the two).
function Spread.allowed(angleDegrees: number, halfAngleDegrees: number, tolerance: number): boolean
	return angleDegrees <= math.max(halfAngleDegrees, 0) + tolerance
end

-- Bloom for one shot (the gun's Bloom* numbers, degrees). `current` is the bloom left by
-- the previous shot (it may come from another gun: capped at this gun's `max`); `idle` is
-- the seconds since that shot beyond the recovery delay (zero or less: none), each of which
-- takes `recovery` off. Returns the bloom this shot is fired with and the bloom it leaves
-- (one `perShot` more, never above `max`).
function Spread.bloom(
	current: number,
	max: number,
	idle: number,
	recovery: number,
	perShot: number
): (number, number)
	local carried = math.min(current, max)
	if idle > 0 then
		carried = math.max(carried - idle * recovery, 0)
	end
	return carried, math.min(carried + perShot, max)
end

return Spread
