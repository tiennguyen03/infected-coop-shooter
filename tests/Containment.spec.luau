--!strict
local Containment = require("../src/shared/Rules/Containment")
local expect = require("./expect")

-- docs/PROGRESSION.md > The Containment Board
local BANDS: { Containment.Band } = {
	{ name = "Lost", min = 0 },
	{ name = "Contested", min = 25 },
	{ name = "Held", min = 50 },
	{ name = "Contained", min = 75 },
	{ name = "Secured", min = 100 },
}

return {
	["0 is Lost"] = function()
		expect.equal(Containment.band(0, BANDS), "Lost", "band")
	end,
	["24 is still Lost"] = function()
		expect.equal(Containment.band(24, BANDS), "Lost", "band")
	end,
	["25 is Contested, Delta's starting value"] = function()
		expect.equal(Containment.band(25, BANDS), "Contested", "band")
	end,
	["each band starts at its minimum"] = function()
		expect.equal(Containment.band(50, BANDS), "Held", "50")
		expect.equal(Containment.band(75, BANDS), "Contained", "75")
		expect.equal(Containment.band(100, BANDS), "Secured", "100")
	end,
	["fractions round down into the lower band"] = function()
		expect.equal(Containment.band(74.9, BANDS), "Held", "band")
	end,
	["out-of-range values clamp"] = function()
		expect.equal(Containment.band(-5, BANDS), "Lost", "below")
		expect.equal(Containment.band(140, BANDS), "Secured", "above")
	end,
	["the shown percent is a clamped whole number"] = function()
		expect.equal(Containment.percent(37.6), 37, "floor")
		expect.equal(Containment.percent(-2), 0, "below")
		expect.equal(Containment.percent(101), 100, "above")
	end,
	["bands given out of order still work"] = function()
		local shuffled = { BANDS[3], BANDS[1], BANDS[5], BANDS[2], BANDS[4] }
		expect.equal(Containment.band(60, shuffled), "Held", "band")
	end,
}
