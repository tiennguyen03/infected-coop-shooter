--!strict
-- How an Infected spit reads over time (client SpitFX; owner, 2026-11-11: the spit was "just
-- a yellow circle"). Pure, unit-tested with Lune (tests/SpitShape.spec.luau). Three curves:
-- the glob in flight (stretched along its path, wobbling, constant volume), the pool it
-- leaves (spreads in, holds, fades out with its damage), and the spitter's head through the
-- windup (rears back, snaps forward on the spit, settles).

local SpitShape = {}

export type GlobSettings = {
	stretch: number, -- length over width at rest
	speedStretch: number, -- extra stretch per stud/s of speed
	maxStretch: number, -- cap on length over width before the wobble
	wobble: number, -- the wobble swings the stretch by +/- this share
	wobbleRate: number, -- wobbles per second
}

export type PoolSettings = {
	grow: number, -- seconds the pool takes to spread to full size
	startSize: number, -- share of full size it lands at
	fade: number, -- seconds at the end of its life it fades over
}

export type RearSettings = {
	back: number, -- degrees the head is thrown back at the end of the windup
	lunge: number, -- degrees it snaps forward on the spit
	recover: number, -- seconds from the lunge back to level
}

-- Smoothstep: slow in, slow out.
local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- (length, width) multipliers of a glob `age` seconds into its flight at `speed` studs/s.
-- length x width x width stays 1, so a longer glob is a thinner one.
function SpitShape.glob(age: number, speed: number, settings: GlobSettings): (number, number)
	local stretch = math.min(settings.stretch + speed * settings.speedStretch, settings.maxStretch)
	stretch *= 1 + settings.wobble * math.sin(age * settings.wobbleRate * 2 * math.pi)
	local width = stretch ^ (-1 / 3)
	return stretch * width, width
end

-- (size share, fade) of a pool `age` seconds old that lives `duration` seconds. Fade 0 is
-- solid, 1 is gone.
function SpitShape.pool(age: number, duration: number, settings: PoolSettings): (number, number)
	local grown = if settings.grow > 0 then math.clamp(age / settings.grow, 0, 1) else 1
	local size = settings.startSize + (1 - settings.startSize) * ease(grown)
	local fadeTime = math.min(settings.fade, duration)
	local fade = if age >= duration
		then 1
		elseif fadeTime > 0 then math.clamp((age - (duration - fadeTime)) / fadeTime, 0, 1)
		else 0
	return size, fade
end

-- Degrees the spitter's head is tilted back (negative: forward) `age` seconds after a windup
-- of `windup` seconds began.
function SpitShape.rear(age: number, windup: number, settings: RearSettings): number
	if age < windup then
		return settings.back * ease(math.clamp(age / windup, 0, 1))
	end
	local after = age - windup
	if settings.recover <= 0 or after >= settings.recover then
		return 0
	end
	return -settings.lunge * (1 - ease(after / settings.recover))
end

return SpitShape
