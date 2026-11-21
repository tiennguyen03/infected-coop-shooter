--!strict
-- Where the squad lands, where its side objectives are and where the helicopter picks it up
-- on the big map (docs/sprints/DELTA_XL.md > Picking). Pure, unit-tested with Lune
-- (tests/DropPickup.spec.luau). Points are flat: { x, z } in studs.
--
--   (1) the main objective and its site are drawn as on any map (ObjectiveService)
--   (2) drop: a corner at least `minDistance` from that site, at random
--   (3) side 1: FirstMin..FirstMax from the drop
--   (4) side 2: SecondFromFirst or more from side 1, within SecondFromLine of the straight
--       line drop -> main (on the way)
--   (5) pickup, chosen only when the main objective is done: HalfwayShare of the time a point
--       HalfwayMin..HalfwayMax from the main (the one nearest the drop), else all the way back:
--       BackMin or more from the main and AvoidDrop or more from the drop (nearest the drop);
--       a point within AvoidRadius of the Warden is never chosen while another is left.

local DropPickup = {}

export type Point = { x: number, z: number }

export type SideRules = {
	FirstMin: number,
	FirstMax: number,
	SecondFromFirst: number,
	SecondFromLine: number,
}

export type PickupRules = {
	HalfwayShare: number,
	HalfwayMin: number,
	HalfwayMax: number,
	BackMin: number,
	AvoidDrop: number,
	AvoidRadius: number,
}

-- `first`: which option (drawn side objective) is side 1 (0 = none); `sites[option]`: the
-- site index chosen for each option; `misses`: studs the plan falls outside the rules
-- (0 = clean; above 0 = the least bad plan there was).
export type SidePlan = { first: number, sites: { [number]: number }, misses: number }

function DropPickup.distance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Flat distance from `p` to the segment a-b.
function DropPickup.toSegment(p: Point, a: Point, b: Point): number
	local abx, abz = b.x - a.x, b.z - a.z
	local lengthSq = abx * abx + abz * abz
	if lengthSq <= 0 then
		return DropPickup.distance(p, a)
	end
	local t = math.clamp(((p.x - a.x) * abx + (p.z - a.z) * abz) / lengthSq, 0, 1)
	return DropPickup.distance(p, { x = a.x + abx * t, z = a.z + abz * t })
end

-- One of `count` items for a roll in [0, 1].
local function byRoll(count: number, roll: number): number
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

-- (2) The drop corner's index.
function DropPickup.drop(main: Point, corners: { Point }, minDistance: number, roll: number): number
	local far: { number } = {}
	local farthest, best = 1, -1
	for index, corner in corners do
		local distance = DropPickup.distance(corner, main)
		if distance >= minDistance then
			table.insert(far, index)
		end
		if distance > best then
			farthest, best = index, distance
		end
	end
	if #far == 0 then
		return farthest
	end
	return far[byRoll(#far, roll)]
end

local function band(value: number, low: number, high: number): number
	return math.max(low - value, 0) + math.max(value - high, 0)
end

-- (3) and (4) The sites of the drawn side objectives. `options[i]` is the list of sites of
-- the i-th drawn side objective. The first two options are placed by the rules (either may
-- be side 1); any further option takes its site by the roll.
function DropPickup.sides(
	drop: Point,
	main: Point,
	options: { { Point } },
	rules: SideRules,
	roll: number
): SidePlan
	local plan: SidePlan = { first = 0, sites = {}, misses = 0 }
	if #options == 0 then
		return plan
	end
	type Candidate = { first: number, sites: { [number]: number }, misses: number }
	local candidates: { Candidate } = {}
	local function firstMiss(site: Point): number
		return band(DropPickup.distance(site, drop), rules.FirstMin, rules.FirstMax)
	end
	if #options == 1 then
		for index, site in options[1] do
			table.insert(
				candidates,
				{ first = 1, sites = { [1] = index }, misses = firstMiss(site) }
			)
		end
	else
		for _, order in { { 1, 2 }, { 2, 1 } } do
			local a, b = order[1], order[2]
			for ia, siteA in options[a] do
				for ib, siteB in options[b] do
					local misses = firstMiss(siteA)
						+ math.max(rules.SecondFromFirst - DropPickup.distance(siteB, siteA), 0)
						+ math.max(
							DropPickup.toSegment(siteB, drop, main) - rules.SecondFromLine,
							0
						)
					table.insert(
						candidates,
						{ first = a, sites = { [a] = ia, [b] = ib }, misses = misses }
					)
				end
			end
		end
	end
	local least = math.huge
	for _, candidate in candidates do
		least = math.min(least, candidate.misses)
	end
	local best: { Candidate } = {}
	for _, candidate in candidates do
		if candidate.misses <= least + 1e-6 then
			table.insert(best, candidate)
		end
	end
	local chosen = best[byRoll(#best, roll)]
	plan.first, plan.misses = chosen.first, chosen.misses
	for option, site in chosen.sites do
		plan.sites[option] = site
	end
	for option = 3, #options do
		plan.sites[option] = byRoll(#options[option], roll)
	end
	return plan
end

-- (5) The pickup's index and how it was chosen: "halfway", "back" or "fallback". `modeRoll`
-- in [0, 1] picks halfway (below HalfwayShare) or back; `warden` is where he stands, if he is up.
function DropPickup.pickup(
	main: Point,
	drop: Point,
	pickups: { Point },
	rules: PickupRules,
	modeRoll: number,
	warden: Point?
): (number, string)
	local function usable(point: Point): boolean
		return warden == nil or DropPickup.distance(point, warden) > rules.AvoidRadius
	end
	local function nearestDrop(test: (Point) -> boolean): number?
		local found, best = nil, math.huge
		for index, point in pickups do
			if usable(point) and test(point) then
				local distance = DropPickup.distance(point, drop)
				if distance < best then
					found, best = index, distance
				end
			end
		end
		return found
	end
	local function halfway(point: Point): boolean
		local distance = DropPickup.distance(point, main)
		return distance >= rules.HalfwayMin and distance <= rules.HalfwayMax
	end
	local function back(point: Point): boolean
		return DropPickup.distance(point, main) >= rules.BackMin
			and DropPickup.distance(point, drop) >= rules.AvoidDrop
	end
	local wantHalfway = modeRoll < rules.HalfwayShare
	type Mode = { name: string, test: (Point) -> boolean }
	local halfwayMode: Mode = { name = "halfway", test = halfway }
	local backMode: Mode = { name = "back", test = back }
	local order: { Mode } = if wantHalfway
		then { halfwayMode, backMode }
		else { backMode, halfwayMode }
	for _, mode in order do
		local found = nearestDrop(mode.test)
		if found then
			return found, mode.name
		end
	end
	-- Nothing fits: the usable point farthest from the main, else any point farthest from it.
	local function farthest(onlyUsable: boolean): number?
		local found, best = nil, -1
		for index, point in pickups do
			if not onlyUsable or usable(point) then
				local distance = DropPickup.distance(point, main)
				if distance > best then
					found, best = index, distance
				end
			end
		end
		return found
	end
	return farthest(true) or farthest(false) or 1, "fallback"
end

return DropPickup
