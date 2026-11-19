--!strict
-- The Warden's ranged decisions (docs/PROGRESSION.md > Index kit: the Warden): which phase
-- his health puts him in, which squad member is the straggler, and what he does when the
-- squad is out of his reach. Pure, unit-tested with Lune (tests/WardenBrain.spec.luau);
-- IndexService feeds it what it measures and Config.Index.Warden.
--
-- The boss pass (2026-11-18, docs/sprints/FUN_WARDEN.md) adds: the Quake and the Rampage
-- to the pick, a capped turn (no snapping round), the summon's head count, which cover his
-- charge smashes, the ring's hit test, and the camper (the leap's first choice).

local WardenBrain = {}

export type Point = { x: number, z: number }

-- Distance bands in studs (IndexService converts the reach-scaled ones).
export type Bands = {
	closeMax: number, -- inside this the melee kit owns the decision
	leapMin: number,
	leapMax: number,
	chargeMin: number,
	chargeMax: number,
	quakeCrowd: number?, -- this many on the ground in the Quake's rings: it fires even in reach
}

export type Far = {
	distance: number, -- flat distance to the nearest member (the hunt's target)
	leapDistance: number?, -- flat distance to the leap's target (nil: none to leap at)
	leapReady: boolean,
	chargeReady: boolean,
	chargeClear: boolean, -- no hard cover between him and the nearest member
	canisterReady: boolean,
	volleyReady: boolean,
	quakeReady: boolean?, -- its stage reached and off cooldown
	quakeCount: number?, -- living members on the ground inside the Quake's rings
	rampageReady: boolean?, -- its stage reached and off cooldown
}

export type Pick = "leap" | "charge" | "canister" | "volley" | "quake" | "rampage"

-- 1 above every threshold (Phases[i].Below, in order), else 1 + the deepest one his health
-- fraction reached.
function WardenBrain.phase(fraction: number, thresholds: { number }): number
	local phase = 1
	for index, below in thresholds do
		if fraction <= below then
			phase = math.max(phase, index + 1)
		end
	end
	return phase
end

-- The member furthest, on average, from everyone else on the ground (nil for nobody; a
-- lone member is the isolated one).
function WardenBrain.isolated(points: { Point }): number?
	if #points == 0 then
		return nil
	end
	local best, bestScore = 1, -1
	for i, a in points do
		local total = 0
		for j, b in points do
			if i ~= j then
				total += math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			end
		end
		local score = if #points > 1 then total / (#points - 1) else 0
		if score > bestScore then
			best, bestScore = i, score
		end
	end
	return best
end

-- After the melee kit passed (nothing ready, or the nearest member out of his limbs' reach):
-- close the distance or lob. A crowd round him (quakeCrowd on the ground in the rings) gets
-- the Quake even in reach. With a body in reach otherwise only the lob (`canisterReady`
-- means a member hangs back beyond the close band). Else the Quake at anyone inside its
-- rings, in the rage the Rampage (in the charge band) and the Volley, then the leap, the
-- charge down a clear line, the lob. Nil: walk at them.
function WardenBrain.farPick(state: Far, bands: Bands, rage: boolean): Pick?
	local quakeCount = state.quakeCount or 0
	local crowd = bands.quakeCrowd or math.huge
	if state.quakeReady and quakeCount >= crowd then
		return "quake"
	end
	if state.distance <= bands.closeMax then
		return if state.canisterReady then "canister" else nil
	end
	if state.quakeReady and quakeCount >= 1 then
		return "quake"
	end
	if
		rage
		and state.rampageReady
		and state.distance >= bands.chargeMin
		and state.distance <= bands.chargeMax
	then
		return "rampage"
	end
	if rage and state.volleyReady then
		return "volley"
	end
	local leap = state.leapDistance
	if state.leapReady and leap and leap >= bands.leapMin and leap <= bands.leapMax then
		return "leap"
	end
	if
		state.chargeReady
		and state.chargeClear
		and state.distance >= bands.chargeMin
		and state.distance <= bands.chargeMax
	then
		return "charge"
	end
	if state.canisterReady then
		return "canister"
	end
	return nil
end

-- One frame of a capped turn: from `yaw` toward `desired` (radians) by at most `maxStep`,
-- the short way round. The result is not wrapped (callers build a CFrame from it).
function WardenBrain.turnToward(yaw: number, desired: number, maxStep: number): number
	local delta = (desired - yaw + math.pi) % (2 * math.pi) - math.pi
	return yaw + math.clamp(delta, -maxStep, maxStep)
end

-- A stage's summon: each type's base count plus its per-extra-player rate times the extra
-- players, rounded down.
function WardenBrain.summon(
	base: { [string]: number },
	perExtra: { [string]: number }?,
	extraPlayers: number
): { [string]: number }
	local counts: { [string]: number } = {}
	for typeName, count in base do
		local rate = (perExtra and perExtra[typeName]) or 0
		counts[typeName] = count + math.floor(rate * extraPlayers)
	end
	return counts
end

-- Cover his charge goes through: something whose every side is at most `maxSize` studs.
function WardenBrain.smashable(x: number, y: number, z: number, maxSize: number): boolean
	local largest = math.max(x, y, z)
	return largest > 0 and largest <= maxSize
end

-- A ring growing from radius `before` to `now` this frame hits a body at `distance` when it
-- crossed it (the front itself counts).
function WardenBrain.crossed(before: number, now: number, distance: number): boolean
	return distance > before and distance <= now
end

-- The member who has stood still longest, once that is at least `threshold` seconds (nil:
-- everyone keeps moving). `still[i]` is member i's seconds without moving.
function WardenBrain.camper(still: { number }, threshold: number): number?
	local best: number? = nil
	local bestTime = threshold
	for index, seconds in still do
		if seconds >= bestTime then
			best, bestTime = index, seconds
		end
	end
	return best
end

return WardenBrain
