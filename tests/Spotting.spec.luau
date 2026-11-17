--!strict
local Spotting = require("../src/shared/Rules/Spotting")
local expect = require("./expect")

local DEFAULTS = {
	MaxRange = 300,
	MinRange = 0,
	FieldOfView = 16,
	Raise = 0.4,
	Lower = 0.25,
	MinSlope = 0.6,
	Slack = { Range = 8, Sight = 4, Ground = 3, Raise = 0.15 },
}

local function settings(overrides: { [string]: any }?): Spotting.Settings
	return Spotting.resolve(DEFAULTS, overrides)
end

-- A clear view of flat ground `distance` studs off.
local function seen(distance: number): Spotting.Measured
	return { distance = distance, blocked = nil, ground = 0, slope = 1 }
end

return {
	["a call-in is thrown unless its row says binoculars"] = function()
		expect.equal(Spotting.mode({}), "Throw", "no AimMode")
		expect.equal(Spotting.mode({ AimMode = "Throw" }), "Throw", "named")
		expect.equal(Spotting.mode({ AimMode = "Binoculars" }), "Binoculars", "binoculars")
		expect.equal(Spotting.mode({ AimMode = "Laser" }), "Throw", "an unknown mode is thrown")
		expect.equal(Spotting.mode(nil), "Throw", "no row")
	end,
	["a row's Binoculars block overrides the shared defaults and leaves them alone"] = function()
		local resolved = settings({ MaxRange = 400 })
		expect.equal(resolved.MaxRange, 400, "the row's range")
		expect.equal(resolved.FieldOfView, 16, "the default view")
		expect.equal(DEFAULTS.MaxRange, 300, "defaults untouched")
		expect.equal(settings(nil).MaxRange, 300, "no block")
	end,
	["flat ground in view inside the range is accepted"] = function()
		local ok, reason = Spotting.check(settings(), seen(250), false)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "no reason")
	end,
	["a point past the range is refused; the server allows its slack"] = function()
		local ok, reason = Spotting.check(settings(), seen(305), false)
		expect.equal(ok, false, "client")
		expect.equal(reason, "range", "reason")
		expect.equal(
			(Spotting.check(settings(), seen(305), true)),
			true,
			"server, inside the slack"
		)
		expect.equal((Spotting.check(settings(), seen(309), true)), false, "server, past it")
	end,
	["a point closer than the minimum range is refused"] = function()
		local ok, reason = Spotting.check(settings({ MinRange = 30 }), seen(20), false)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "close", "reason")
		expect.equal((Spotting.check(settings({ MinRange = 30 }), seen(30), false)), true, "on it")
	end,
	["a point behind cover is refused; the server forgives a few studs"] = function()
		local hidden: Spotting.Measured = { distance = 100, blocked = 2, ground = 0, slope = 1 }
		local ok, reason = Spotting.check(settings(), hidden, false)
		expect.equal(ok, false, "client")
		expect.equal(reason, "sight", "reason")
		expect.equal((Spotting.check(settings(), hidden, true)), true, "server, inside the slack")
		hidden.blocked = 40
		expect.equal((Spotting.check(settings(), hidden, true)), false, "server, behind a wall")
	end,
	["a point in the air, or on a wall, is refused"] = function()
		local air: Spotting.Measured = { distance = 100, blocked = nil, ground = nil, slope = nil }
		local ok, reason = Spotting.check(settings(), air, false)
		expect.equal(ok, false, "nothing under it")
		expect.equal(reason, "ground", "reason")
		local high: Spotting.Measured = { distance = 100, blocked = nil, ground = 2, slope = 1 }
		expect.equal((Spotting.check(settings(), high, false)), false, "client: off the ground")
		expect.equal((Spotting.check(settings(), high, true)), true, "server: inside the slack")
		high.ground = 9
		expect.equal((Spotting.check(settings(), high, true)), false, "server: far off it")
		local wall: Spotting.Measured = { distance = 100, blocked = nil, ground = 0, slope = 0.1 }
		expect.equal((Spotting.check(settings(), wall, true)), false, "a wall face")
	end,
	["range is checked before sight"] = function()
		local far: Spotting.Measured = { distance = 900, blocked = 50, ground = 0, slope = 1 }
		local _, reason = Spotting.check(settings(), far, false)
		expect.equal(reason, "range", "reason")
	end,
	["the slot's key raises the binoculars and lowers them again"] = function()
		local state, action = Spotting.next("Lowered", "key", false)
		expect.equal(state, "Raised", "raised")
		expect.equal(action, "raise", "action")
		state, action = Spotting.next("Raised", "key", true)
		expect.equal(state, "Lowered", "lowered")
		expect.equal(action, "lower", "action")
	end,
	["fire confirms only once they are up and the mark is good"] = function()
		local state, action = Spotting.next("Raised", "fire", false)
		expect.equal(state, "Raised", "still up")
		expect.equal(action, nil, "nothing happens")
		state, action = Spotting.next("Raised", "fire", true)
		expect.equal(state, "Lowered", "lowered")
		expect.equal(action, "fire", "the mission goes")
	end,
	["cancel lowers them; lowered binoculars ignore fire and cancel"] = function()
		local state, action = Spotting.next("Raised", "cancel", true)
		expect.equal(state, "Lowered", "lowered")
		expect.equal(action, "lower", "action")
		state, action = Spotting.next("Lowered", "fire", true)
		expect.equal(state, "Lowered", "fire")
		expect.equal(action, nil, "no action")
		state, action = Spotting.next("Lowered", "cancel", true)
		expect.equal(state, "Lowered", "cancel")
		expect.equal(action, nil, "no action")
	end,
	["the server accepts a mark only after the raise, less its slack"] = function()
		local s = settings()
		expect.equal(Spotting.canConfirm(nil, s), false, "never raised")
		expect.equal(Spotting.canConfirm(0.1, s), false, "too soon")
		expect.equal(Spotting.canConfirm(0.25, s), true, "inside the slack")
		expect.equal(Spotting.canConfirm(3, s), true, "held")
	end,
	["the raise blends in over Raise and out over Lower"] = function()
		expect.near(Spotting.blend(0, true, 0.2, 0.4, 0.25), 0.5, 1e-6, "half way up")
		expect.equal(Spotting.blend(0.9, true, 0.2, 0.4, 0.25), 1, "capped")
		expect.near(Spotting.blend(1, false, 0.05, 0.4, 0.25), 0.8, 1e-6, "coming down")
		expect.equal(Spotting.blend(0.1, false, 0.2, 0.4, 0.25), 0, "floored")
		expect.equal(Spotting.blend(0, true, 0.1, 0, 0), 1, "no time: at once")
	end,
	["the view narrows with the blend"] = function()
		expect.equal(Spotting.fov(70, 16, 0), 70, "down")
		expect.equal(Spotting.fov(70, 16, 1), 16, "up")
		expect.equal(Spotting.fov(70, 16, 0.5), 43, "half")
	end,
	["the range readout is whole metres"] = function()
		expect.equal(Spotting.rangeText(100, 0.28), "28 M", "100 studs")
		expect.equal(Spotting.rangeText(0, 0.28), "0 M", "at the feet")
		expect.equal(Spotting.rangeText(401.9, 0.28), "113 M", "rounded")
	end,
}
