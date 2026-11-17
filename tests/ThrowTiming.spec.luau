--!strict
local ThrowTiming = require("../src/shared/Rules/ThrowTiming")
local expect = require("./expect")

local ROWS = {
	Default = { Start = 0, Release = 0.3, Speed = 1 },
	grenade_throw = { Start = 1.3, Release = 2, Speed = 1.4 },
	half_row = { Release = 0.9 },
}

return {
	["a clip with its own row uses it"] = function()
		local timing = ThrowTiming.resolve(ROWS, "grenade_throw")
		expect.equal(timing.Start, 1.3, "start")
		expect.equal(timing.Release, 2, "release")
		expect.equal(timing.Speed, 1.4, "speed")
	end,
	["a clip without a row, or no clip, gets the default"] = function()
		expect.equal(ThrowTiming.resolve(ROWS, "some_new_clip").Release, 0.3, "unknown clip")
		expect.equal(ThrowTiming.resolve(ROWS, nil).Release, 0.3, "no clip")
	end,
	["a row that names only some values keeps the default for the rest"] = function()
		local timing = ThrowTiming.resolve(ROWS, "half_row")
		expect.equal(timing.Release, 0.9, "its own release")
		expect.equal(timing.Start, 0, "default start")
		expect.equal(timing.Speed, 1, "default speed")
		expect.equal(ROWS.Default.Release, 0.3, "defaults untouched")
	end,
	["the wind-up is the clip time from Start to Release at the play speed"] = function()
		expect.near(ThrowTiming.windUp(ThrowTiming.resolve(ROWS, "grenade_throw")), 0.5, 0.001)
		expect.near(ThrowTiming.windUp({ Start = 0, Release = 0.3, Speed = 1 }), 0.3, 0.001)
	end,
	["a release before the start or a dead speed never gives a negative or endless wind-up"] = function()
		expect.equal(ThrowTiming.windUp({ Start = 2, Release = 1, Speed = 1 }), 0, "release first")
		expect.near(ThrowTiming.windUp({ Start = 0, Release = 1, Speed = 0 }), 1, 0.001, "speed 0")
	end,
	["the server waits the wind-up less the thrower's lag, up to the cap"] = function()
		expect.near(ThrowTiming.serverWait(0.5, 0.04, 0.1), 0.46, 0.001, "small lag")
		expect.near(ThrowTiming.serverWait(0.5, 0.4, 0.1), 0.4, 0.001, "capped")
		expect.near(ThrowTiming.serverWait(0.5, 0, 0.1), 0.5, 0.001, "no lag")
		expect.near(ThrowTiming.serverWait(0.5, -3, 0.1), 0.5, 0.001, "nonsense lag")
		expect.near(ThrowTiming.serverWait(0.5, 9, 0), 0.5, 0.001, "compensation off")
		expect.equal(ThrowTiming.serverWait(0.05, 0.4, 0.1), 0, "never negative")
	end,
}
