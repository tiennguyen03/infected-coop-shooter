--!strict
local RunClock = require("../src/shared/Rules/RunClock")
local expect = require("./expect")

return {
	["a run starts at 00:00"] = function()
		expect.equal(RunClock.format(0), "00:00")
	end,
	["part seconds round down"] = function()
		expect.equal(RunClock.format(0.9), "00:00", "under a second")
		expect.equal(RunClock.format(59.99), "00:59", "just under a minute")
	end,
	["minutes and seconds are two digits each"] = function()
		expect.equal(RunClock.format(60), "01:00", "one minute")
		expect.equal(RunClock.format(75), "01:15", "a minute and a quarter")
		expect.equal(RunClock.format(600), "10:00", "ten minutes")
	end,
	["a long run keeps counting minutes past an hour"] = function()
		expect.equal(RunClock.format(3725), "62:05")
	end,
}
