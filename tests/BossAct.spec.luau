--!strict
local BossAct = require("../src/shared/Rules/BossAct")
local expect = require("./expect")

local DEFAULTS = {
	At = 0.5,
	Contest = 0,
	Target = "nearest",
	EnterMin = 55,
	EnterMax = 70,
	HealthFactor = 1,
	Arrive = "default arrive",
}

return {
	["a row's block overrides the defaults field by field"] = function()
		local settings = BossAct.resolve({ At = 0.6, Contest = 16 }, DEFAULTS)
		expect.equal(settings.At, 0.6, "At")
		expect.equal(settings.Contest, 16, "Contest")
		expect.equal(settings.Target, "nearest", "Target from the defaults")
		expect.equal(settings.Arrive, "default arrive", "Arrive from the defaults")
	end,
	["a row with no block plays the defaults"] = function()
		local settings = BossAct.resolve(nil, DEFAULTS)
		expect.equal(settings.At, 0.5, "At")
		expect.equal(settings.EnterMax, 70, "EnterMax")
	end,
	["resolving never changes the defaults"] = function()
		BossAct.resolve({ At = 0.9 }, DEFAULTS)
		expect.equal(DEFAULTS.At, 0.5, "defaults kept")
	end,
	["share is progress over total, clamped"] = function()
		expect.equal(BossAct.share(1, 3), 1 / 3, "1 of 3")
		expect.equal(BossAct.share(5, 3), 1, "past the end")
		expect.equal(BossAct.share(-1, 3), 0, "below zero")
	end,
	["nothing to count is no progress yet"] = function()
		expect.equal(BossAct.share(4, 0), 0, "total 0")
	end,
	["he comes when the share reaches At"] = function()
		expect.equal(BossAct.shouldCome(0.5, 0.49, false, false), false, "short of At")
		expect.equal(BossAct.shouldCome(0.5, 0.5, false, false), true, "at At")
		expect.equal(BossAct.shouldCome(0.6, 2 / 3, false, false), true, "the second tent of three")
	end,
	["he comes at the latest when the work is done"] = function()
		expect.equal(BossAct.shouldCome(0.9, 0.2, true, false), true, "work done early")
	end,
	["he comes once"] = function()
		expect.equal(BossAct.shouldCome(0.5, 1, true, true), false, "already came")
	end,
	["At 0 brings him the moment it starts"] = function()
		expect.equal(BossAct.shouldCome(0, 0, false, false), true, "at once")
	end,
	["the mission is done only when the work is done and he is down"] = function()
		expect.equal(BossAct.complete(true, true), true, "both")
		expect.equal(BossAct.complete(true, false), false, "he still stands")
		expect.equal(BossAct.complete(false, true), false, "work left")
	end,
	["the step reads what is left"] = function()
		expect.equal(BossAct.step(false, false, false), "work", "work, no contest")
		expect.equal(BossAct.step(false, false, true), "blocked", "he stands on it")
		expect.equal(BossAct.step(true, false, false), "kill", "only he is left")
		expect.equal(BossAct.step(false, true, true), "work", "dead, so no contest")
	end,
	["inside is a flat distance"] = function()
		expect.equal(BossAct.inside(0, 0, 3, 4, 5), true, "on the edge")
		expect.equal(BossAct.inside(0, 0, 3, 4, 4.9), false, "just out")
		expect.equal(BossAct.inside(0, 0, 0, 0, 0), false, "radius 0 never blocks")
	end,
	["the record's share is the way carried"] = function()
		expect.equal(BossAct.carried(100, 100), 0, "at the start")
		expect.near(BossAct.carried(100, 70), 0.3, 1e-9, "30 of 100 carried")
		expect.equal(BossAct.carried(100, 130), 0, "carried the wrong way")
		expect.equal(BossAct.carried(0, 0), 1, "no way to go")
	end,
	["a contest shows for a moment after he leaves"] = function()
		expect.equal(BossAct.recently(10, 9.7, 0.5), true, "0.3 s ago")
		expect.equal(BossAct.recently(10, 9.4, 0.5), false, "0.6 s ago")
		expect.equal(BossAct.recently(10, 0, 0.5), false, "never")
	end,
}
