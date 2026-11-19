--!strict
local DropPickup = require("../src/shared/Rules/DropPickup")
local expect = require("./expect")

type Point = DropPickup.Point

-- The four corners of the big map (docs/sprints/DELTA_XL.md > Points).
local CORNERS: { Point } = {
	{ x = -650, z = 700 },
	{ x = 650, z = 700 },
	{ x = -650, z = -650 },
	{ x = 650, z = -650 },
}

local SIDES: DropPickup.SideRules =
	{ FirstMin = 150, FirstMax = 450, SecondFromFirst = 300, SecondFromLine = 350 }

local PICKUP: DropPickup.PickupRules = {
	HalfwayShare = 0.5,
	HalfwayMin = 400,
	HalfwayMax = 700,
	BackMin = 800,
	AvoidDrop = 300,
	AvoidRadius = 200,
}

local function distance(a: Point, b: Point): number
	return DropPickup.distance(a, b)
end

return {
	["distance is flat (x and z only)"] = function()
		expect.near(DropPickup.distance({ x = 0, z = 0 }, { x = 3, z = 4 }), 5, 1e-9)
	end,
	["distance to a segment: beside it, past its end, on it"] = function()
		local a, b = { x = 0, z = 0 }, { x = 100, z = 0 }
		expect.near(DropPickup.toSegment({ x = 50, z = 30 }, a, b), 30, 1e-9, "beside")
		expect.near(DropPickup.toSegment({ x = 130, z = 40 }, a, b), 50, 1e-9, "past the end")
		expect.near(DropPickup.toSegment({ x = 20, z = 0 }, a, b), 0, 1e-9, "on it")
		expect.near(DropPickup.toSegment({ x = 3, z = 4 }, a, a), 5, 1e-9, "a point segment")
	end,

	-- (2) the drop: a corner at least 900 from the main objective's site, at random.
	["the drop is always a corner at least the minimum from the main site"] = function()
		local main = { x = -254, z = 120 } -- the Pens
		for roll = 0, 0.99, 0.11 do
			local index = DropPickup.drop(main, CORNERS, 900, roll)
			expect.equal(distance(CORNERS[index], main) >= 900, true, `roll {roll}`)
		end
	end,
	["the drop roll spreads over every corner far enough"] = function()
		local main = { x = 0, z = 0 }
		local seen = {}
		for roll = 0, 0.99, 0.05 do
			seen[DropPickup.drop(main, CORNERS, 900, roll)] = true
		end
		for index = 1, 4 do
			expect.equal(seen[index], true, `corner {index}`)
		end
	end,
	["no corner far enough: the farthest one"] = function()
		local main = { x = 600, z = 650 }
		expect.equal(DropPickup.drop(main, CORNERS, 5000, 0.3), 3)
	end,
	["a roll of 1 stays in range"] = function()
		local index = DropPickup.drop({ x = 0, z = 0 }, CORNERS, 900, 1)
		expect.equal(index >= 1 and index <= 4, true)
	end,

	-- (3) and (4) the side objectives.
	["side 1 lands 150-450 from the drop and side 2 by the road to the main"] = function()
		local drop = { x = -650, z = -650 }
		local main = { x = 211, z = 32 } -- the Depot
		local options: { { Point } } = {
			-- a misdrop: one spot per area
			{ { x = -700, z = 600 }, { x = -600, z = -400 }, { x = 600, z = 600 } },
			-- lights on: three generators
			{ { x = 620, z = -600 }, { x = 700, z = 640 }, { x = -300, z = -250 } },
		}
		local plan = DropPickup.sides(drop, main, options, SIDES, 0.5)
		local first = options[plan.first][plan.sites[plan.first]]
		local secondOption = if plan.first == 1 then 2 else 1
		local second = options[secondOption][plan.sites[secondOption]]
		local fromDrop = distance(first, drop)
		expect.equal(fromDrop >= 150 and fromDrop <= 450, true, `side 1 is {fromDrop} out`)
		expect.equal(distance(second, first) >= 300, true, "side 2 spacing")
		expect.equal(DropPickup.toSegment(second, drop, main) <= 350, true, "side 2 on the way")
		expect.equal(plan.misses, 0, "a clean plan")
	end,
	["either drawn side may be side 1"] = function()
		local drop = { x = 650, z = 700 }
		local main = { x = -254, z = 120 }
		-- Only the second option has a site near the drop.
		local options: { { Point } } = {
			{ { x = 200, z = 400 } },
			{ { x = 700, z = 400 } },
		}
		local plan = DropPickup.sides(drop, main, options, SIDES, 0.2)
		expect.equal(plan.first, 2)
		expect.equal(plan.misses, 0)
	end,
	["nothing fits: the plan that misses by least, and it says so"] = function()
		local drop = { x = -650, z = -650 }
		local main = { x = 600, z = 600 }
		local options: { { Point } } = {
			{ { x = 650, z = 700 }, { x = -400, z = -650 } },
		}
		local plan = DropPickup.sides(drop, main, options, SIDES, 0.7)
		expect.equal(plan.sites[1], 2, "the nearer one")
		expect.equal(plan.misses, 0, "250 out is inside the band")
		local far = DropPickup.sides(drop, main, { { { x = 650, z = 700 } } }, SIDES, 0.7)
		expect.equal(far.sites[1], 1, "the only site")
		expect.equal(far.misses > 0, true, "and it is out of band")
	end,
	["ties are broken by the roll, and every tie can come up"] = function()
		local drop = { x = 0, z = 0 }
		local main = { x = 0, z = 1000 }
		local options: { { Point } } = {
			{ { x = 300, z = 0 }, { x = -300, z = 0 }, { x = 0, z = 300 } },
		}
		local seen = {}
		for roll = 0, 0.99, 0.1 do
			seen[DropPickup.sides(drop, main, options, SIDES, roll).sites[1]] = true
		end
		expect.equal(seen[1] and seen[2] and seen[3], true)
	end,
	["no side objectives: an empty plan"] = function()
		local plan = DropPickup.sides({ x = 0, z = 0 }, { x = 1, z = 1 }, {}, SIDES, 0.5)
		expect.equal(plan.first, 0)
		expect.equal(next(plan.sites), nil)
	end,

	-- (5) the pickup, chosen when the main objective is done.
	["halfway: a pickup 400-700 from the main, the one nearest the drop"] = function()
		local main = { x = 650, z = -60 } -- the Sidings
		local drop = { x = -650, z = 700 }
		local pickups: { Point } = {
			{ x = -90, z = -90 }, -- the base pad: 740 out
			{ x = 10, z = -560 }, -- the flyover: 813
			{ x = -40, z = 800 }, -- the truck stop: 1102
			{ x = 300, z = 200 }, -- 437 out
			{ x = 400, z = -500 }, -- 506 out
		}
		local index, mode = DropPickup.pickup(main, drop, pickups, PICKUP, 0.2, nil)
		expect.equal(mode, "halfway")
		expect.equal(index, 4)
	end,
	["all the way back: 800+ from the main, never by the drop, nearest the drop"] = function()
		local main = { x = 650, z = -60 }
		local drop = { x = -650, z = 700 }
		local pickups: { Point } = {
			{ x = -700, z = 650 }, -- on the drop: never
			{ x = -40, z = 800 }, -- the truck stop: 1102 from the main, 618 from the drop
			{ x = -700, z = 0 }, -- the ball field: 1351 from the main, 702 from the drop
			{ x = 300, z = 200 }, -- too close to the main
		}
		local index, mode = DropPickup.pickup(main, drop, pickups, PICKUP, 0.8, nil)
		expect.equal(mode, "back")
		expect.equal(index, 2)
	end,
	["no halfway pickup: all the way back instead"] = function()
		local main = { x = -254, z = 120 }
		local drop = { x = 650, z = -650 }
		local pickups: { Point } = { { x = -90, z = -90 }, { x = 700, z = 50 } }
		local index, mode = DropPickup.pickup(main, drop, pickups, PICKUP, 0.1, nil)
		expect.equal(mode, "back")
		expect.equal(index, 2)
	end,
	["a pickup near the Warden is skipped"] = function()
		local main = { x = 650, z = -60 }
		local drop = { x = -650, z = 700 }
		local pickups: { Point } = { { x = -40, z = 800 }, { x = -700, z = 0 } }
		local index = DropPickup.pickup(main, drop, pickups, PICKUP, 0.8, { x = -60, z = 760 })
		expect.equal(index, 2)
	end,
	["nothing qualifies: the usable pickup farthest from the main"] = function()
		local main = { x = 0, z = 0 }
		local drop = { x = 0, z = 50 }
		local pickups: { Point } = { { x = 100, z = 0 }, { x = 0, z = -250 } }
		local index, mode = DropPickup.pickup(main, drop, pickups, PICKUP, 0.9, nil)
		expect.equal(mode, "fallback")
		expect.equal(index, 2)
	end,
	["every pickup by the Warden: still one, the farthest from the main"] = function()
		local main = { x = 0, z = 0 }
		local drop = { x = 0, z = 900 }
		local pickups: { Point } = { { x = 900, z = 0 }, { x = 950, z = 0 } }
		local index, mode = DropPickup.pickup(main, drop, pickups, PICKUP, 0.9, { x = 920, z = 0 })
		expect.equal(mode, "fallback")
		expect.equal(index, 2)
	end,
}
