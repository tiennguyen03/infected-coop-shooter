--!strict
local CoverWindow = require("../src/shared/Rules/CoverWindow")
local expect = require("./expect")

return {
	["the first move opens a window for the move plus the grace"] = function()
		expect.near(CoverWindow.open(100, nil, 0.6, 0.45, 0.1) :: number, 100.55, 1e-9)
	end,
	["a move during the last window buys nothing"] = function()
		expect.equal(CoverWindow.open(100.3, 100.55, 0.6, 0.45, 0.1), nil, "inside the window")
	end,
	["a move inside the cooldown after the last window buys nothing"] = function()
		expect.equal(CoverWindow.open(101.1, 100.55, 0.6, 0.45, 0.1), nil, "cooling down")
	end,
	["a move once the cooldown has passed opens a new window"] = function()
		expect.near(CoverWindow.open(101.15, 100.55, 0.6, 0.45, 0.1) :: number, 101.7, 1e-9)
		expect.near(CoverWindow.open(102, 100.55, 0.6, 0.45, 0.1) :: number, 102.55, 1e-9)
	end,
}
