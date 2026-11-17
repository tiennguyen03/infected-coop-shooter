--!strict
-- The outline of a spit pool (client SpitFX; owner, 2026-11-17: the pool was "a little too
-- perfect" a circle, "it should look like a puddle of liquid"). Pure, unit-tested with Lune
-- (tests/PuddleShape.spec.luau). A puddle is a core ellipse in the middle and a ring of
-- smaller lobes of varied size and turn round it, laid out from a seed. Every blob stays
-- inside the damage radius (reachMax), and together they cover most of it in every
-- direction, so the puddle still shows honestly where it hurts. Units are shares of the
-- damage radius, on the ground plane (x, z).

local PuddleShape = {}

export type Settings = {
	lobes: number, -- blobs round the edge
	coreSize: number, -- the core's longer half-axis
	coreSquash: number, -- the core's shorter half-axis over its longer
	lobeMin: number, -- a lobe's longer half-axis, from this
	lobeMax: number, -- to this
	lobeSquash: number, -- a lobe's shorter half-axis over its longer, from this to 1
	reachMin: number, -- the furthest point of each lobe from the middle, from this
	reachMax: number, -- to this (1: the damage radius)
	spreadLag: number, -- seconds a lobe may lag the core as the puddle spreads
}

-- An ellipse centred at (x, z), its longer half-axis along (cos angle, sin angle).
export type Blob = {
	x: number,
	z: number,
	long: number,
	short: number,
	angle: number,
	delay: number, -- seconds after the core it starts to spread
}

local MODULUS = 2147483647

-- A small seeded generator (Park-Miller), so the same seed lays the same puddle anywhere.
local function generator(seed: number): () -> number
	local state = math.floor(math.abs(seed)) % (MODULUS - 1) + 1
	return function(): number
		state = (state * 16807) % MODULUS
		return state / MODULUS
	end
end

local function lerp(from: number, to: number, t: number): number
	return from + (to - from) * t
end

-- The core first, then the lobes round it.
function PuddleShape.layout(seed: number, settings: Settings): { Blob }
	local random = generator(seed)
	local blobs: { Blob } = {
		{
			x = 0,
			z = 0,
			long = settings.coreSize,
			short = settings.coreSize * settings.coreSquash,
			angle = random() * math.pi,
			delay = 0,
		},
	}
	local count = settings.lobes
	local turn = random() * math.pi * 2
	local spacing = math.pi * 2 / math.max(count, 1)
	for index = 1, count do
		-- Evenly round, nudged by up to a quarter of the spacing either way.
		local around = turn + (index - 1) * spacing + (random() - 0.5) * spacing * 0.5
		local long = lerp(settings.lobeMin, settings.lobeMax, random())
		local reach = lerp(settings.reachMin, settings.reachMax, random())
		local out = math.max(reach - long, 0)
		table.insert(blobs, {
			x = math.cos(around) * out,
			z = math.sin(around) * out,
			long = long,
			short = long * lerp(settings.lobeSquash, 1, random()),
			angle = random() * math.pi,
			delay = settings.spreadLag * random(),
		})
	end
	return blobs
end

-- Whether the point (x, z) lies inside any of `blobs`.
function PuddleShape.covers(blobs: { Blob }, x: number, z: number): boolean
	for _, blob in blobs do
		local dx, dz = x - blob.x, z - blob.z
		local c, s = math.cos(blob.angle), math.sin(blob.angle)
		local along = (dx * c + dz * s) / blob.long
		local across = (-dx * s + dz * c) / blob.short
		if along * along + across * across <= 1 then
			return true
		end
	end
	return false
end

return PuddleShape
