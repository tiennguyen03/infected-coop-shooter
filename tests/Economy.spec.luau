--!strict
local Economy = require("../src/shared/Rules/Economy")
local expect = require("./expect")

-- The pay table as Config.Merits gives it.
local PAY = { Win = 120, Partial = 60, Loss = 0, Secondary = 30 }
local PACKS = {
	{ ProductId = 0, Tabs = 100 },
	{ ProductId = 111, Tabs = 500 },
	{ ProductId = 222, Tabs = 1200 },
}

return {
	["a win, a partial and a loss pay their own amount"] = function()
		expect.equal(Economy.missionMerits("win", 0, PAY), 120, "win")
		expect.equal(Economy.missionMerits("partial", 0, PAY), 60, "partial")
		expect.equal(Economy.missionMerits("loss", 0, PAY), 0, "loss")
	end,
	["each Secondary adds its bonus"] = function()
		expect.equal(Economy.missionMerits("win", 1, PAY), 150, "one")
		expect.equal(Economy.missionMerits("partial", 2, PAY), 120, "two on a partial")
		expect.equal(Economy.missionMerits("loss", 1, PAY), 30, "kept on a loss")
	end,
	["an unknown outcome pays as a loss"] = function()
		expect.equal(Economy.missionMerits("draw", 0, PAY), 0, "unknown")
	end,
	["junk secondaries pay nothing extra"] = function()
		expect.equal(Economy.missionMerits("win", -2, PAY), 120, "negative")
		expect.equal(Economy.missionMerits("win", 1.9, PAY), 150, "floored")
		expect.equal(Economy.missionMerits("win", 0 / 0, PAY), 120, "not a number")
	end,
	["the pay is never negative"] = function()
		local odd = { Win = -50, Partial = 0, Loss = 0, Secondary = 0 }
		expect.equal(Economy.missionMerits("win", 0, odd), 0, "floor at zero")
	end,
	["a product pays the tabs on its own row"] = function()
		expect.equal(Economy.tabsFor(111, PACKS), 500, "first real pack")
		expect.equal(Economy.tabsFor(222, PACKS), 1200, "second")
	end,
	["an unknown product, or one not created yet, pays nothing"] = function()
		expect.equal(Economy.tabsFor(999, PACKS), nil, "unknown")
		expect.equal(Economy.tabsFor(0, PACKS), nil, "id 0 is a placeholder")
	end,
	["a pack with a bad amount pays nothing"] = function()
		local bad = { { ProductId = 5, Tabs = 0 }, { ProductId = 6, Tabs = 2.5 } }
		expect.equal(Economy.tabsFor(5, bad), nil, "zero")
		expect.equal(Economy.tabsFor(6, bad), nil, "fraction")
	end,
}
