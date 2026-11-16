--!strict
-- The slide's speed: pure, no Roblox APIs, unit-tested with Lune (tests/Slide.spec.luau).
-- A slide carries the speed the body had going in, loses it to friction, gains it from a
-- downhill floor and loses it faster uphill; it ends when it is too slow (or at the time
-- cap). MovementController reads the floor and calls these each frame; numbers are
-- Config.Movement.Slide.

local Slide = {}

export type Settings = {
	EntryBoost: number, -- studs/s added to the speed going in
	MinEntrySpeed: number, -- a slide never starts slower than this
	Friction: number, -- studs/s lost per second on any floor
	SlopeAccel: number, -- studs/s gained per second on a sheer drop; scaled by the slope
	MaxSpeed: number,
	MinSpeed: number, -- at or under this the slide is over
	MaxDuration: number, -- seconds; the longest hill ends here
}

function Slide.entrySpeed(current: number, settings: Settings): number
	return math.min(
		math.max(current + settings.EntryBoost, settings.MinEntrySpeed),
		settings.MaxSpeed
	)
end

-- How steeply the floor falls away along the direction of travel: the sine of the slope
-- angle, positive downhill, negative uphill, 0 on the flat or across the hill. Takes the
-- horizontal unit direction and the horizontal part of the floor's unit normal (a normal
-- leaning the way the body travels means the ground drops ahead of it).
function Slide.slope(dirX: number, dirZ: number, normalX: number, normalZ: number): number
	return dirX * normalX + dirZ * normalZ
end

function Slide.step(speed: number, slope: number, dt: number, settings: Settings): number
	local gained = (settings.SlopeAccel * slope - settings.Friction) * dt
	return math.min(speed + gained, settings.MaxSpeed)
end

function Slide.isOver(speed: number, elapsed: number, settings: Settings): boolean
	return speed <= settings.MinSpeed or elapsed >= settings.MaxDuration
end

-- Seconds until the slide ends if the floor stays like this (the get-up clip is timed off it).
function Slide.timeLeft(speed: number, slope: number, elapsed: number, settings: Settings): number
	if Slide.isOver(speed, elapsed, settings) then
		return 0
	end
	local untilCap = settings.MaxDuration - elapsed
	local loss = settings.Friction - settings.SlopeAccel * slope
	if loss <= 0 then
		return untilCap
	end
	return math.min((speed - settings.MinSpeed) / loss, untilCap)
end

return Slide
