--!strict
-- The Warden's ranged decisions (docs/PROGRESSION.md > Index kit: the Warden): which phase
-- his health puts him in, which squad member is the straggler, and what he does when the
-- squad is out of his reach. Pure, unit-tested with Lune (tests/WardenBrain.spec.luau);
-- IndexService feeds it what it measures and Config.Index.Warden.

local WardenBrain = {}

export type Point = { x: number, z: number }

-- Distance bands in studs (IndexService converts the reach-scaled ones).
export type Bands = {
	closeMax: number, -- inside this the melee kit owns the decision
	leapMin: number,
	leapMax: number,
	chargeMin: number,
	chargeMax: number,
}

export type Far = {
	distance: number, -- flat distance to the nearest member (the hunt's target)
	leapDistance: number?, -- flat distance to the isolated member (nil: none to leap at)
	leapReady: boolean,
	chargeReady: boolean,
	chargeClear: boolean, -- no hard cover between him and the nearest member
	canisterReady: boolean,
	volleyReady: boolean,
}

export type Pick = "leap" | "charge" | "canister" | "volley"

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
-- close the distance or lob. With a body in reach only the lob (`canisterReady` means a
-- member hangs back beyond the close band). Else in the rage the volley (a canister at
-- everyone) first, then the leap at the straggler, the charge down a clear line, the lob.
-- Nil: walk at them.
function WardenBrain.farPick(state: Far, bands: Bands, rage: boolean): Pick?
	if state.distance <= bands.closeMax then
		return if state.canisterReady then "canister" else nil
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

return WardenBrain
