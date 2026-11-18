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
}
