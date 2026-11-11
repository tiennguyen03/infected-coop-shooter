--!strict
local Spacing = require("../src/shared/Rules/Spacing")
local expect = require("./expect")

local SETTINGS: Spacing.Settings = {
	Lookahead = 8,
	Strength = 0.5,
	BehindWeight = 0.3,
	MaxPush = 3,
	BlockSlack = 0.15,
	TravelMinPull = 0.4,
	RingFraction = 0.8,
	EngageDistance = 24,
	RingSpread = 50,
	RingPeriod = 9,
	SwayAngle = 10,
	SwayPeriod = 5,
	Deadzone = 0.3,
	WaitStep = 2,
}
local STILL: Spacing.Settings = table.clone(SETTINGS) -- no drift: straight lines to check
STILL.RingSpread = 0
STILL.SwayAngle = 0

local NONE: { number } = {}

-- The target stands at the origin; attack range 4 puts the ring at 3.2. Neighbours are
-- { x, z } with the same 1.6 radius as the body.
local function steer(
	settings: Spacing.Settings,
	hereX: number,
	hereZ: number,
	neighbours: { { number } }?,
	seed: number?,
	now: number?
): (number, number, boolean)
	local xs, zs, radii = {}, {}, {}
	for index, neighbour in neighbours or {} do
		xs[index], zs[index], radii[index] = neighbour[1], neighbour[2], 1.6
	end
	return Spacing.steer(
		settings,
		hereX,
		hereZ,
		0,
		0,
		4,
		1.6,
		seed or 0.3,
		now or 0,
		xs,
		zs,
		radii,
		#xs
	)
end

return {
	["a personal radius varies round its base by the share given"] = function()
		expect.near(Spacing.radius(2, 0.25, 0), 1.5, 1e-9, "smallest")
		expect.near(Spacing.radius(2, 0.25, 0.5), 2, 1e-9, "middle")
		expect.near(Spacing.radius(2, 0.25, 1), 2.5, 1e-9, "largest")
	end,
	["the drift stays inside -1..1 and never jumps"] = function()
		for seedStep = 0, 10 do
			local last = Spacing.wander(seedStep / 10, 0, 9)
			for tick = 1, 400 do
				local value = Spacing.wander(seedStep / 10, tick * 0.25, 9)
				expect.equal(math.abs(value) <= 1, true, "range")
				expect.equal(math.abs(value - last) < 0.35, true, "smooth")
				last = value
			end
		end
	end,
	["cells: neighbours share a key, far points do not, negatives are their own cells"] = function()
		expect.equal(Spacing.cellKey(1, 1, 6), Spacing.cellKey(5, 5, 6), "same cell")
		expect.equal(Spacing.cellKey(1, 1, 6) ~= Spacing.cellKey(7, 1, 6), true, "next in x")
		expect.equal(Spacing.cellKey(1, 1, 6) ~= Spacing.cellKey(1, 7, 6), true, "next in z")
		expect.equal(Spacing.cellKey(-1, 1, 6) ~= Spacing.cellKey(1, 1, 6), true, "negative x")
	end,
	["alone and far away, a body walks straight at its target, one lookahead at a time"] = function()
		local x, z, waiting = steer(STILL, 50, 0)
		expect.near(x, 42, 1e-6, "x")
		expect.near(z, 0, 1e-6, "z")
		expect.equal(waiting, false, "waiting")
	end,
	["alone and close, a body stops on the attack ring, inside its reach"] = function()
		local x, z = steer(STILL, 6, 0)
		expect.near(x, 3.2, 1e-6, "x")
		expect.near(z, 0, 1e-6, "z")
		local heldX, heldZ = steer(STILL, 3.2, 0)
		expect.near(heldX, 3.2, 1e-6, "holds x")
		expect.near(heldZ, 0, 1e-6, "holds z")
	end,
	["a body inside the ring stays where it is rather than backing off"] = function()
		local x, z = steer(SETTINGS, 1.5, 0.5)
		expect.near(x, 1.5, 1e-6, "x")
		expect.near(z, 0.5, 1e-6, "z")
	end,
	["a neighbour overlapping a body pushes it away, by a share of the overlap"] = function()
		-- On the ring (nothing to walk to), a neighbour 1 stud to the +z side and a touch
		-- nearer the target: overlap 2.18 of 3.2, half of it given way.
		local x, z = steer(STILL, 3.2, 0, { { 3, 1 } })
		local moved = math.sqrt((x - 3.2) ^ 2 + z ^ 2)
		expect.near(moved, (3.2 - math.sqrt(1.04)) * 0.5, 1e-6, "distance")
		expect.equal(z < -1, true, "away from the neighbour")
	end,
	["a body gives way less to a neighbour behind it than to one in front"] = function()
		local _, front = steer(STILL, 3.2, 0, { { 3, 1 } })
		local _, behind = steer(STILL, 3.2, 0, { { 3.4, 1 } })
		expect.near(behind / front, 0.3, 1e-6)
	end,
	["a neighbour beside a body on the way in turns it aside without stopping it"] = function()
		local x, z = steer(STILL, 50, 0, { { 49.5, 2 } })
		expect.equal(z < -0.5, true, "sideways")
		expect.equal(x < 46, true, "still advancing")
	end,
	["a neighbour outside both radii does nothing"] = function()
		local x, z = steer(STILL, 50, 0, { { 50, 3.3 } })
		expect.near(x, 42, 1e-6, "x")
		expect.near(z, 0, 1e-6, "z")
	end,
	["a body does not walk into a neighbour standing in its way: it stops short"] = function()
		-- 5 studs behind a body on the ring: it may close to the two radii less the slack.
		local x, z, waiting = steer(STILL, 8.2, 0, { { 3.2, 0 } })
		expect.near(x, 3.2 + 3.2 * 0.85, 1e-6, "x")
		expect.near(z, 0, 1e-6, "z")
		expect.equal(waiting, false, "a 2.28 stud step is not waiting")
	end,
	["on the way in, a crowd never stops or turns a body back"] = function()
		-- Hemmed in ahead and to both sides, at many depths.
		for depth = 1, 30 do
			local gap = depth / 10
			local neighbours = {
				{ 50 - gap, 0 },
				{ 50 - gap, gap },
				{ 50 - gap, -gap },
				{ 50, gap },
				{ 50, -gap },
			}
			local x, _, waiting = steer(SETTINGS, 50, 0, neighbours, 0.7, depth)
			expect.equal(x < 50 - 0.3, true, `advances at gap {gap}`)
			expect.equal(waiting, false, `not waiting at gap {gap}`)
		end
	end,
	["near the target, a body behind another waits instead of shoving through"] = function()
		-- One body on the ring, this one right behind it.
		local x, z, waiting = steer(STILL, 5.2, 0, { { 3.2, 0 } })
		expect.equal(x >= 5.2, true, "does not advance")
		expect.near(z, 0, 1e-6, "z")
		expect.equal(waiting, true, "waiting")
	end,
	["near the target, a clear way in is taken"] = function()
		local x, _, waiting = steer(STILL, 7, 0, { { 3.2, 5 } })
		expect.near(x, 3.2, 1e-6, "walks to the ring")
		expect.equal(waiting, false, "waiting")
	end,
	["a short step with nobody near is not waiting (cover: the nudge rule still runs)"] = function()
		local _, _, waiting = steer(STILL, 4.2, 0)
		expect.equal(waiting, false)
	end,
	["bodies stacked on one point leave in different directions"] = function()
		local ax, az = steer(STILL, 3.2, 0, { { 3.2, 0 } }, 0.1)
		local bx, bz = steer(STILL, 3.2, 0, { { 3.2, 0 } }, 0.6)
		local apart = math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
		expect.equal(apart > 1, true, `apart {apart}`)
	end,
	["the push is capped however many bodies overlap"] = function()
		local neighbours = {}
		for index = 1, 12 do
			neighbours[index] = { 3.2, 0.05 * index }
		end
		local x, z = steer(STILL, 3.2, 0, neighbours)
		local moved = math.sqrt((x - 3.2) ^ 2 + z ^ 2)
		expect.equal(moved <= SETTINGS.MaxPush + 1e-6, true, `moved {moved}`)
		expect.equal(moved > 1, true, "but it does move")
	end,
	["a tiny step is not taken"] = function()
		-- Overlap 0.2 deep: a 0.1 stud push, under the deadzone.
		local x, z = steer(STILL, 3.2, 0, { { 3.2, 3 } })
		expect.near(x, 3.2, 1e-9, "x")
		expect.near(z, 0, 1e-9, "z")
	end,
	["bodies approach on different curves, and settle once on the ring"] = function()
		local _, z1 = steer(SETTINGS, 10, 0, nil, 0.1, 3)
		local _, z2 = steer(SETTINGS, 10, 0, nil, 0.8, 3)
		expect.equal(math.abs(z1 - z2) > 0.2, true, "curves differ")
		for tick = 0, 40 do
			local x, z = steer(SETTINGS, 3.2, 0, nil, 0.8, tick)
			expect.near(x, 3.2, 1e-6, "ring x")
			expect.near(z, 0, 1e-6, "ring z")
		end
	end,
	["a goal is never further than the lookahead plus the push"] = function()
		for tick = 0, 60 do
			local x, z = steer(SETTINGS, 40, 10, { { 40, 11 }, { 39, 10 } }, 0.45, tick * 0.5)
			local step = math.sqrt((x - 40) ^ 2 + (z - 10) ^ 2)
			expect.equal(step <= SETTINGS.Lookahead + SETTINGS.MaxPush + 1e-6, true, `{step}`)
		end
	end,
	["a crowd let loose on one point spreads out round the target"] = function()
		-- 24 bodies start stacked 30 studs out and walk in (2.4 studs a repath, like a
		-- Walker). After 20 seconds no two stand on top of each other and the crowd is a
		-- few ranks deep, not a column.
		local count = 24
		local xs, zs, radii, seeds = {}, {}, {}, {}
		for index = 1, count do
			xs[index], zs[index] = 30 + (index % 5) * 0.2, (index % 7) * 0.2
			radii[index] = 1.6
			seeds[index] = (index * 0.618) % 1
		end
		local nx, nz, nr = {}, {}, {}
		for tick = 1, 80 do
			local now = tick * 0.25
			local nextX, nextZ = {}, {}
			for index = 1, count do
				local found = 0
				for other = 1, count do
					if other ~= index then
						found += 1
						nx[found], nz[found], nr[found] = xs[other], zs[other], radii[other]
					end
				end
				local goalX, goalZ = Spacing.steer(
					SETTINGS,
					xs[index],
					zs[index],
					0,
					0,
					4,
					radii[index],
					seeds[index],
					now,
					nx,
					nz,
					nr,
					found
				)
				local stepX, stepZ = goalX - xs[index], goalZ - zs[index]
				local step = math.sqrt(stepX * stepX + stepZ * stepZ)
				local scale = if step > 2.4 then 2.4 / step else 1
				nextX[index], nextZ[index] = xs[index] + stepX * scale, zs[index] + stepZ * scale
			end
			xs, zs = nextX, nextZ
		end
		local closest, furthest = math.huge, 0
		for index = 1, count do
			furthest = math.max(furthest, math.sqrt(xs[index] ^ 2 + zs[index] ^ 2))
			for other = index + 1, count do
				local gap = math.sqrt((xs[index] - xs[other]) ^ 2 + (zs[index] - zs[other]) ^ 2)
				closest = math.min(closest, gap)
			end
		end
		expect.equal(closest > 1, true, `closest pair {closest}`)
		expect.equal(furthest < 14, true, `furthest body {furthest}`)
	end,
	["no neighbours passed means none read"] = function()
		local x = Spacing.steer(STILL, 50, 0, 0, 0, 4, 1.6, 0.3, 0, NONE, NONE, NONE, 0)
		expect.near(x, 42, 1e-6)
	end,
}
