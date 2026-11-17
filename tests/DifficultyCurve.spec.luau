--!strict
local DifficultyCurve = require("../src/shared/Rules/DifficultyCurve")
local expect = require("./expect")

return {
	["the spawn interval starts at the base"] = function()
		expect.near(DifficultyCurve.spawnInterval(3, 0.95, 1.5, 0, 0.8, 0), 3, 1e-9)
	end,
	["the spawn interval decays per unpaused minute"] = function()
		expect.near(DifficultyCurve.spawnInterval(3, 0.95, 1.5, 600, 0.8, 0), 3 * 0.95 ^ 10, 1e-9)
	end,
	["the spawn interval never drops below the floor"] = function()
		expect.near(DifficultyCurve.spawnInterval(3, 0.95, 1.5, 3600, 0.8, 0), 1.5, 1e-9)
	end,
	["extra players shorten the interval after the floor"] = function()
		expect.near(DifficultyCurve.spawnInterval(3, 0.95, 1.5, 3600, 0.8, 2), 1.5 * 0.8 ^ 2, 1e-9)
	end,
	["max alive follows the schedule then the late value"] = function()
		local schedule = { { 75, 10 }, { 180, 14 }, { 300, 20 }, { 480, 26 } }
		expect.equal(DifficultyCurve.maxAlive(schedule, 30, 0, 3, 44, 0), 10, "insert")
		expect.equal(DifficultyCurve.maxAlive(schedule, 30, 200, 3, 44, 0), 20, "minute 3")
		expect.equal(DifficultyCurve.maxAlive(schedule, 30, 900, 3, 44, 0), 30, "late")
	end,
	["max alive grows per extra player up to the hard cap"] = function()
		local schedule = { { 75, 10 } }
		expect.equal(DifficultyCurve.maxAlive(schedule, 30, 900, 3, 44, 2), 36, "two extra")
		expect.equal(DifficultyCurve.maxAlive(schedule, 30, 900, 3, 44, 9), 44, "capped")
	end,
	["a flat multiplier stays at 1 for the whole run"] = function()
		expect.equal(DifficultyCurve.multiplier(0, 1, 0), 1, "insert")
		expect.equal(DifficultyCurve.multiplier(0, 1, 3600), 1, "an hour in")
	end,
	["a multiplier grows per unpaused minute up to its cap"] = function()
		expect.near(DifficultyCurve.multiplier(0.1, 2, 0), 1, 1e-9)
		expect.near(DifficultyCurve.multiplier(0.1, 2, 300), 1.5, 1e-9)
		expect.near(DifficultyCurve.multiplier(0.1, 2, 3600), 2, 1e-9)
	end,
}
