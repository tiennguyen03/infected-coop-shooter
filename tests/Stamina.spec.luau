--!strict
local Stamina = require("../src/shared/Rules/Stamina")
local expect = require("./expect")

local S = {
	Max = 100,
	SprintDrain = 12,
	Regen = 22,
	RegenDelay = 1,
	WindedRecover = 25,
}

return {
	["starts full and able to sprint"] = function()
		local state = Stamina.new(S)
		expect.equal(state.value, 100)
		expect.equal(Stamina.canSprint(state), true)
		expect.equal(Stamina.fraction(state, S), 1)
	end,
	["sprinting drains at SprintDrain per second"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 2, true, S)
		expect.near(state.value, 76, 1e-9)
	end,
	["a full bar is about eight seconds of sprint, then winded"] = function()
		local state = Stamina.new(S)
		local seconds = 0
		while Stamina.canSprint(state) and seconds < 60 do
			Stamina.step(state, 0.1, true, S)
			seconds += 0.1
		end
		expect.near(seconds, 100 / 12, 0.11, "seconds")
		expect.equal(state.value, 0, "value")
		expect.equal(state.winded, true, "winded")
	end,
	["nothing comes back until RegenDelay after the last spend"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 1, true, S)
		Stamina.step(state, 0.9, false, S)
		expect.near(state.value, 88, 1e-9, "inside the delay")
		Stamina.step(state, 0.6, false, S)
		expect.near(state.value, 88 + 22 * 0.5, 1e-9, "only the time past the delay")
	end,
	["regen stops at Max"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 1, true, S)
		Stamina.step(state, 30, false, S)
		expect.equal(state.value, 100)
	end,
	["winded holds until WindedRecover, even with sprint held"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 9, true, S)
		expect.equal(state.winded, true, "winded at zero")
		-- Holding sprint while winded spends nothing, so the delay still runs out.
		Stamina.step(state, 1, true, S)
		Stamina.step(state, 1, true, S)
		expect.near(state.value, 22, 1e-9, "regen while held")
		expect.equal(Stamina.canSprint(state), false, "still winded under the mark")
		Stamina.step(state, 0.2, true, S)
		expect.equal(Stamina.canSprint(state), true, "back above the mark")
	end,
	["a spend takes its cost and restarts the regen delay"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 5, false, S)
		expect.equal(Stamina.spend(state, 20), true)
		expect.equal(state.value, 80)
		Stamina.step(state, 0.5, false, S)
		expect.equal(state.value, 80, "delay restarted")
	end,
	["a spend with too little left still goes, and leaves you winded"] = function()
		local state = Stamina.new(S)
		state.value = 8
		expect.equal(Stamina.spend(state, 20), true)
		expect.equal(state.value, 0, "floored")
		expect.equal(state.winded, true)
	end,
	["no spend while winded"] = function()
		local state = Stamina.new(S)
		state.value = 10
		state.winded = true
		expect.equal(Stamina.canSpend(state), false)
		expect.equal(Stamina.spend(state, 20), false)
		expect.equal(state.value, 10, "untouched")
	end,
	["a free action spends nothing and keeps the regen going"] = function()
		local state = Stamina.new(S)
		state.value = 50
		expect.equal(Stamina.spend(state, 0), true)
		Stamina.step(state, 0.5, false, S)
		expect.near(state.value, 61, 1e-9)
	end,
	["refill restores a full, rested bar"] = function()
		local state = Stamina.new(S)
		Stamina.step(state, 9, true, S)
		Stamina.refill(state, S)
		expect.equal(state.value, 100)
		expect.equal(state.winded, false)
		expect.equal(Stamina.canSprint(state), true)
	end,
}
