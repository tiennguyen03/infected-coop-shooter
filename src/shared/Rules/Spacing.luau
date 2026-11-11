--!strict
-- Infected spacing (Config.Enemies.Spacing; server: EnemySpacing): where a chasing body
-- should walk so the horde surrounds its target instead of stacking on one point. Bodies
-- pass through each other physically (Enemy collision group), so this is the only thing
-- that keeps them apart. Pure numbers on the ground plane (x, z), no Roblox APIs, so
-- tests/Spacing.spec.luau runs it in Lune.
--
-- Three soft rules, summed into one step each repath:
--   1. Ring: near the target a body aims at the point of the attack ring on its own side of
--      the target (not the centre), approached on a curve that differs per body.
--   2. Push: a neighbour inside the two personal radii pushes the body away, by a share of
--      how deep the overlap is (so two bodies drift apart instead of snapping).
--   3. Yield: the part of the advance that would walk into a neighbour is taken out, so a
--      body slides past it or waits behind it instead of shoving through. Far from the
--      target the yield and the push are both limited so a body always makes ground
--      (doorways never lock).

local Spacing = {}

export type Settings = {
	Lookahead: number, -- studs: the longest step a goal is placed ahead of the body
	Strength: number, -- share of an overlap's depth each body gives way per repath
	MaxPush: number, -- studs: the most the neighbours move a goal
	BehindWeight: number, -- share of that given way to a neighbour further from the target
	BlockSlack: number, -- share of the two radii an advance may overlap a neighbour by
	TravelMinPull: number, -- share of the advance kept however crowded, beyond EngageDistance
	RingFraction: number, -- the attack ring's radius as a share of the body's AttackRange
	EngageDistance: number, -- studs from the target inside which bodies hold rank
	RingSpread: number, -- degrees: the most a body's approach curves round the target
	RingPeriod: number, -- seconds over which a body's curve drifts
	SwayAngle: number, -- degrees: the weave of a body far from its target
	SwayPeriod: number,
	Deadzone: number, -- studs: a smaller step is not taken (no shuffling on the spot)
	WaitStep: number, -- studs: a crowded body stepping less than this is waiting, not stuck
}

-- A body's personal radius: `base` varied by up to +-`variation` (a share) from its seed in
-- [0, 1], so a crowd is not evenly spaced.
function Spacing.radius(base: number, variation: number, seed: number): number
	return base * (1 + variation * (seed * 2 - 1))
end

-- A slow, smooth, per-body drift in [-1, 1]: two sines out of step, so it never repeats
-- neatly and never jumps. `seed` in [0, 1] sets the phase and stretches the period.
function Spacing.wander(seed: number, now: number, period: number): number
	if period <= 0 then
		return 0
	end
	local angle = now * (2 * math.pi) / (period * (0.75 + seed * 0.5)) + seed * 40
	return math.sin(angle) * 0.65 + math.sin(angle * 0.37 + seed * 17) * 0.35
end

-- The cell a point falls in (EnemySpacing's grid): one number per cell.
function Spacing.cellKey(x: number, z: number, cellSize: number): number
	return math.floor(x / cellSize) * 65536 + math.floor(z / cellSize)
end

-- The move goal for one body, and whether its neighbours are holding it (waiting).
-- `xs`, `zs`, `radii` hold `count` neighbours (the body itself left out).
function Spacing.steer(
	settings: Settings,
	hereX: number,
	hereZ: number,
	targetX: number,
	targetZ: number,
	attackRange: number,
	radius: number,
	seed: number,
	now: number,
	xs: { number },
	zs: { number },
	radii: { number },
	count: number
): (number, number, boolean)
	local toX, toZ = targetX - hereX, targetZ - hereZ
	local distance = math.sqrt(toX * toX + toZ * toZ)
	local towardX, towardZ = 1, 0
	if distance > 1e-3 then
		towardX, towardZ = toX / distance, toZ / distance
	end

	local ring = attackRange * settings.RingFraction
	local engage = math.max(settings.EngageDistance, ring + 1)
	local travelling = distance > engage

	-- 1. The aim: the ring point on this body's side of the target, turned round the target
	-- by its drift; the turn fades to nothing as the body reaches the ring (so it settles).
	-- A body already inside the ring has nowhere to go.
	local aimX, aimZ = 0, 0 -- relative to the body
	if distance > ring then
		local fade = math.clamp((distance - ring) / (engage - ring), 0, 1)
		local turn = Spacing.wander(seed, now, settings.RingPeriod)
			* math.rad(settings.RingSpread)
			* fade
		local cos, sin = math.cos(turn), math.sin(turn)
		local bearingX, bearingZ = -towardX, -towardZ -- from the target to the body
		aimX = toX + (bearingX * cos - bearingZ * sin) * ring
		aimZ = toZ + (bearingX * sin + bearingZ * cos) * ring
	end
	local aimLength = math.sqrt(aimX * aimX + aimZ * aimZ)
	local aheadX, aheadZ = towardX, towardZ
	if aimLength > 1e-3 then
		aheadX, aheadZ = aimX / aimLength, aimZ / aimLength
	end
	if travelling and settings.SwayAngle > 0 then
		local weave = Spacing.wander((seed + 0.5) % 1, now, settings.SwayPeriod)
			* math.rad(settings.SwayAngle)
			* math.clamp((distance - engage) / engage, 0, 1)
		local cos, sin = math.cos(weave), math.sin(weave)
		aheadX, aheadZ = aheadX * cos - aheadZ * sin, aheadX * sin + aheadZ * cos
	end
	local pull = math.min(aimLength, settings.Lookahead)
	local pullX, pullZ = aheadX * pull, aheadZ * pull

	-- 2 and 3. Neighbours. Push: away from each one overlapping, by a share of the overlap's
	-- depth; fully from a neighbour nearer the target and only BehindWeight of that from one
	-- behind (the front keeps its place, the back makes room). Yield: below.
	local pushX, pushZ, deepest = 0, 0, 0
	local crowded = false
	for index = 1, count do
		local awayX, awayZ = hereX - xs[index], hereZ - zs[index]
		local reach = radius + radii[index]
		local gap = math.sqrt(awayX * awayX + awayZ * awayZ)
		if gap < 1e-3 then
			-- Exactly stacked: each body leaves along its own direction.
			local angle = seed * 2 * math.pi
			awayX, awayZ, gap = math.cos(angle), math.sin(angle), 0
		else
			awayX, awayZ = awayX / gap, awayZ / gap
		end
		if gap < reach then
			crowded = true
			local depth = reach - gap
			local theirX, theirZ = targetX - xs[index], targetZ - zs[index]
			local weight = settings.Strength
			if theirX * theirX + theirZ * theirZ > distance * distance then
				weight *= settings.BehindWeight
			end
			pushX += awayX * depth * weight
			pushZ += awayZ * depth * weight
			deepest = math.max(deepest, depth)
		end
		-- The advance may close on a neighbour only until the two radii (less the slack)
		-- touch; the rest of it in that direction is taken out.
		local into = -(pullX * awayX + pullZ * awayZ)
		local room = math.max(gap - reach * (1 - settings.BlockSlack), 0)
		if into > room then
			pullX += awayX * (into - room)
			pullZ += awayZ * (into - room)
			crowded = true
		end
	end

	local forward = pullX * aheadX + pullZ * aheadZ
	if travelling then
		-- On the way in a body always makes ground, however crowded.
		local least = pull * settings.TravelMinPull
		if forward < least then
			pullX += aheadX * (least - forward)
			pullZ += aheadZ * (least - forward)
		end
	end

	-- The push never beats the advance on the way in; near the target it may (ranks hold).
	-- Nor does a crowd push further than its deepest overlap (no overshoot, no jitter).
	local maxPush = math.min(settings.MaxPush, deepest)
	if travelling then
		maxPush = math.min(maxPush, pull * settings.TravelMinPull * 0.9)
	end
	local pushLength = math.sqrt(pushX * pushX + pushZ * pushZ)
	if pushLength > maxPush and pushLength > 0 then
		pushX, pushZ = pushX / pushLength * maxPush, pushZ / pushLength * maxPush
	end

	local stepX, stepZ = pullX + pushX, pullZ + pushZ
	local step = math.sqrt(stepX * stepX + stepZ * stepZ)
	local waiting = crowded and not travelling and step < settings.WaitStep
	if step < settings.Deadzone then
		return hereX, hereZ, waiting
	end
	return hereX + stepX, hereZ + stepZ, waiting
end

return Spacing
