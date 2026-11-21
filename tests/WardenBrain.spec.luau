--!strict
local WardenBrain = require("../src/shared/Rules/WardenBrain")
local expect = require("./expect")

local PHASES = { 0.6, 0.3 }

local BANDS: WardenBrain.Bands = {
	closeMax = 19,
	leapMin = 22,
	leapMax = 70,
	chargeMin = 19,
	chargeMax = 60,
	quakeCrowd = 2,
}

local function far(overrides: { [string]: any }): WardenBrain.Far
	local state: { [string]: any } = {
		distance = 40,
		leapDistance = 40,
		leapReady = false,
		chargeReady = false,
		chargeClear = true,
		canisterReady = false,
		volleyReady = false,
		quakeReady = false,
		quakeCount = 0,
		rampageReady = false,
	}
	for key, value in overrides do
		state[key] = value
	end
	return state :: any
end

return {
	["phase 1 above every threshold"] = function()
		expect.equal(WardenBrain.phase(1, PHASES), 1, "full")
		expect.equal(WardenBrain.phase(0.61, PHASES), 1, "just above")
	end,
	["each threshold crossed adds a phase, the deepest wins"] = function()
		expect.equal(WardenBrain.phase(0.6, PHASES), 2, "at the first")
		expect.equal(WardenBrain.phase(0.3, PHASES), 3, "at the rage")
		expect.equal(WardenBrain.phase(0, PHASES), 3, "dead")
	end,
	["the isolated member is the one furthest from the rest"] = function()
		local positions = {
			{ x = 0, z = 0 },
			{ x = 4, z = 0 },
			{ x = 0, z = 4 },
			{ x = 60, z = 0 },
		}
		expect.equal(WardenBrain.isolated(positions), 4, "the straggler")
	end,
	["a lone member is the isolated one; nobody is nil"] = function()
		expect.equal(WardenBrain.isolated({ { x = 5, z = 5 } }), 1, "solo")
		expect.equal(WardenBrain.isolated({}), nil, "empty")
	end,
	["three in a line: the far end is isolated"] = function()
		local positions = { { x = 0, z = 0 }, { x = 0, z = 2 }, { x = 10, z = 0 } }
		expect.equal(WardenBrain.isolated(positions), 3, "flat distance only")
	end,
	["the leap goes for the isolated member in its band first"] = function()
		local pick = WardenBrain.farPick(
			far({ leapReady = true, chargeReady = true, canisterReady = true }),
			BANDS,
			false
		)
		expect.equal(pick, "leap", "leap first")
	end,
	["no leap when the isolated member is out of its band"] = function()
		local pick = WardenBrain.farPick(
			far({ leapReady = true, leapDistance = 90, chargeReady = true }),
			BANDS,
			false
		)
		expect.equal(pick, "charge", "falls to the charge")
		local tooClose =
			WardenBrain.farPick(far({ leapReady = true, leapDistance = 10 }), BANDS, false)
		expect.equal(tooClose, nil, "inside the leap's minimum: nothing")
	end,
	["the charge needs a clear line"] = function()
		local pick = WardenBrain.farPick(
			far({ chargeReady = true, chargeClear = false, canisterReady = true }),
			BANDS,
			false
		)
		expect.equal(pick, "canister", "the lob instead")
	end,
	["inside the close band only the lob at a far member"] = function()
		local pick = WardenBrain.farPick(
			far({
				distance = 12,
				leapDistance = 30,
				leapReady = true,
				chargeReady = true,
				volleyReady = true,
			}),
			BANDS,
			true
		)
		expect.equal(pick, nil, "no leap, charge or volley with a body in reach")
		local lob = WardenBrain.farPick(far({ distance = 12, canisterReady = true }), BANDS, false)
		expect.equal(lob, "canister", "the lob at whoever hangs back")
	end,
	["the volley only in the rage"] = function()
		local calm = WardenBrain.farPick(far({ volleyReady = true }), BANDS, false)
		expect.equal(calm, nil, "no volley before the rage")
		local rage = WardenBrain.farPick(far({ volleyReady = true, leapReady = true }), BANDS, true)
		expect.equal(rage, "volley", "the rage opens with the volley")
	end,
	["nothing ready is nothing"] = function()
		expect.equal(WardenBrain.farPick(far({}), BANDS, true), nil, "idle pick")
	end,
	-- The boss pass (2026-11-18, docs/sprints/FUN_WARDEN.md).
	["the quake hits a crowd round him even inside his reach"] = function()
		local crowd = WardenBrain.farPick(
			far({ distance = 8, quakeReady = true, quakeCount = 2, canisterReady = true }),
			BANDS,
			false
		)
		expect.equal(crowd, "quake", "two on the ground round him")
		local one = WardenBrain.farPick(
			far({ distance = 8, quakeReady = true, quakeCount = 1 }),
			BANDS,
			false
		)
		expect.equal(one, nil, "one body in reach is the melee kit's")
	end,
	["out of reach the quake comes before the leap"] = function()
		local pick = WardenBrain.farPick(
			far({ distance = 30, quakeReady = true, quakeCount = 1, leapReady = true }),
			BANDS,
			false
		)
		expect.equal(pick, "quake", "someone inside the rings")
		local nobody = WardenBrain.farPick(
			far({ distance = 30, quakeReady = true, quakeCount = 0, leapReady = true }),
			BANDS,
			false
		)
		expect.equal(nobody, "leap", "no one in the rings: the leap")
	end,
	["the rampage opens the rage, in the charge band"] = function()
		local pick = WardenBrain.farPick(
			far({ rampageReady = true, volleyReady = true, leapReady = true }),
			BANDS,
			true
		)
		expect.equal(pick, "rampage", "before the volley")
		local tooFar = WardenBrain.farPick(
			far({ distance = 90, rampageReady = true, volleyReady = true }),
			BANDS,
			true
		)
		expect.equal(tooFar, "volley", "out of the charge band")
		local calm = WardenBrain.farPick(far({ rampageReady = true }), BANDS, false)
		expect.equal(calm, nil, "never before the rage")
	end,
	["turning is capped and takes the short way round"] = function()
		expect.near(
			WardenBrain.turnToward(0, math.rad(90), math.rad(30)),
			math.rad(30),
			1e-6,
			"capped"
		)
		expect.near(
			WardenBrain.turnToward(0, math.rad(10), math.rad(30)),
			math.rad(10),
			1e-6,
			"arrives"
		)
		local wrap = WardenBrain.turnToward(math.rad(170), math.rad(-170), math.rad(30))
		expect.near(wrap, math.rad(190), 1e-6, "through 180, not back through 0")
	end,
	["the summon adds bodies per extra player, rounded down"] = function()
		local counts = WardenBrain.summon(
			{ Walker = 6, Runner = 2, Brute = 1 },
			{ Walker = 3, Brute = 0.5 },
			3
		)
		expect.equal(counts.Walker, 15, "6 + 3 x 3")
		expect.equal(counts.Runner, 2, "no per-player row")
		expect.equal(counts.Brute, 2, "1 + floor(1.5)")
		local solo = WardenBrain.summon({ Brute = 1 }, { Brute = 0.5 }, 0)
		expect.equal(solo.Brute, 1, "solo")
	end,
	["only small cover is smashable"] = function()
		expect.equal(WardenBrain.smashable(4, 3, 6, 10), true, "a crate")
		expect.equal(WardenBrain.smashable(40, 12, 1, 10), false, "a wall")
		expect.equal(WardenBrain.smashable(0, 0, 0, 10), false, "nothing")
	end,
	["a ring hits what it crossed this frame"] = function()
		expect.equal(WardenBrain.crossed(4, 6, 5), true, "inside the step")
		expect.equal(WardenBrain.crossed(4, 6, 6), true, "on the front")
		expect.equal(WardenBrain.crossed(4, 6, 4), false, "already behind it")
		expect.equal(WardenBrain.crossed(4, 6, 7), false, "not there yet")
	end,
	["the camper is the stillest member past the threshold"] = function()
		expect.equal(WardenBrain.camper({ 1, 5, 7, 2 }, 4), 3, "the stillest")
		expect.equal(WardenBrain.camper({ 1, 2 }, 4), nil, "everyone moving")
		expect.equal(WardenBrain.camper({}, 4), nil, "nobody")
	end,
}
