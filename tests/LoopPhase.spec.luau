--!strict
local LoopPhase = require("../src/shared/Rules/LoopPhase")
local expect = require("./expect")

return {
	["a mark between the two phases was crossed"] = function()
		expect.equal(LoopPhase.crossed(0.4, 0.6, 0.5), true, "inside")
		expect.equal(LoopPhase.crossed(0.4, 0.6, 0.7), false, "ahead")
		expect.equal(LoopPhase.crossed(0.4, 0.6, 0.3), false, "behind")
	end,
	["landing exactly on a mark counts, starting on it does not"] = function()
		expect.equal(LoopPhase.crossed(0.4, 0.5, 0.5), true, "lands on it")
		expect.equal(LoopPhase.crossed(0.5, 0.6, 0.5), false, "starts on it")
	end,
	["a frame that did not move crosses nothing"] = function()
		expect.equal(LoopPhase.crossed(0.5, 0.5, 0.5), false, "same phase")
	end,
	["a loop that wrapped crosses the marks either side of the seam"] = function()
		expect.equal(LoopPhase.crossed(0.95, 0.05, 0), true, "the start of the loop")
		expect.equal(LoopPhase.crossed(0.95, 0.05, 0.98), true, "before the seam")
		expect.equal(LoopPhase.crossed(0.95, 0.05, 0.03), true, "after the seam")
		expect.equal(LoopPhase.crossed(0.95, 0.05, 0.5), false, "the far side")
		expect.equal(LoopPhase.crossed(0.95, 0.05, 0.95), false, "starts on it")
	end,
}
