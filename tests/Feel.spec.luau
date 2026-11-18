--!strict
local Feel = require("../src/shared/Rules/Feel")
local expect = require("./expect")

local KNOCK = { Blast = 60, PerDamage = 0.5, Max = 30 }

return {
	["a blast shakes hardest at its centre and not at all past its radius"] = function()
		expect.near(Feel.shake(10, 0, 40), 10, 1e-9, "centre")
		expect.near(Feel.shake(10, 20, 40), 5, 1e-9, "half way")
		expect.equal(Feel.shake(10, 50, 40), 0, "outside")
	end,
	["shakes add up to a cap"] = function()
		expect.equal(Feel.addShake(4, 5, 6), 6, "capped")
		expect.equal(Feel.addShake(1, 2, 6), 3, "sum")
	end,
	["low health starts below the threshold and is full at zero"] = function()
		expect.equal(Feel.lowHealth(0.5, 0.35), 0, "healthy")
		expect.near(Feel.lowHealth(0.175, 0.35), 0.5, 1e-9, "half way")
		expect.equal(Feel.lowHealth(0, 0.35), 1, "zero")
		expect.equal(Feel.lowHealth(-1, 0.35), 1, "below zero")
		expect.equal(Feel.lowHealth(2, 0.35), 0, "above one")
	end,
	["a blast kill throws harder than any bullet, bullets scale with damage to a cap"] = function()
		expect.equal(Feel.knockback("Blast", 5, KNOCK), 60, "blast")
		expect.equal(Feel.knockback("Bullet", 100, KNOCK), 30, "capped")
		expect.equal(Feel.knockback("Bullet", 20, KNOCK), 10, "rifle")
	end,
	["a flinch waits out its cooldown"] = function()
		expect.equal(Feel.canFlinch(1.0, 0.5, 0.6), false, "too soon")
		expect.equal(Feel.canFlinch(1.2, 0.5, 0.6), true, "after")
		expect.equal(Feel.canFlinch(0, nil, 0.6), true, "first")
	end,
	["kills in the same instant tick once, spaced kills each tick"] = function()
		expect.equal(Feel.canKillConfirm(5, nil, 0.07), true, "first kill")
		expect.equal(Feel.canKillConfirm(5.02, 5, 0.07), false, "same blast")
		expect.equal(Feel.canKillConfirm(5.07, 5, 0.07), true, "at the gap")
		expect.equal(Feel.canKillConfirm(5.02, 5, 0), true, "no gap set")
	end,
	["the low-health effect eases up by dt over the ease time"] = function()
		expect.near(Feel.easeToward(0, 1, 0.1, 0.5, 0.002), 0.2, 1e-9, "rising")
		expect.near(Feel.easeToward(0.9, 1, 0.5, 0.5, 0.002), 1, 1e-9, "stops at the goal")
	end,
	["the low-health effect eases down without passing the goal"] = function()
		expect.near(Feel.easeToward(1, 0.5, 0.1, 0.5, 0.002), 0.8, 1e-9, "falling")
		expect.near(Feel.easeToward(0.6, 0.5, 0.5, 0.5, 0.002), 0.5, 1e-9, "stops at the goal")
	end,
	["no ease time jumps straight to the goal"] = function()
		expect.near(Feel.easeToward(0, 1, 0.01, 0, 0.002), 1, 1e-9)
	end,
	["fading out snaps to zero under the off threshold"] = function()
		expect.equal(Feel.easeToward(0.003, 0, 0.0005, 0.5, 0.002), 0, "snapped")
		expect.near(Feel.easeToward(0.3, 0, 0.0005, 0.5, 0.002), 0.299, 1e-9, "still fading")
	end,
	["a small goal above zero does not snap"] = function()
		expect.near(Feel.easeToward(0.003, 0.001, 0.0005, 0.5, 0.002), 0.002, 1e-9)
	end,
}
