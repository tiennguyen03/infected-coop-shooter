--!strict
local MoveBlend = require("../src/shared/Rules/MoveBlend")
local expect = require("./expect")

local ALL = { forward = true, back = true, left = true, right = true }

return {
	["straight ahead (the body faces -Z) is all forward"] = function()
		local w = MoveBlend.weights(0, -16, ALL)
		expect.equal(w.forward, 1, "forward")
		expect.equal(w.back + w.left + w.right, 0, "the rest")
	end,
	["a strafe to +X is all right, to -X all left"] = function()
		expect.equal(MoveBlend.weights(16, 0, ALL).right, 1, "right")
		expect.equal(MoveBlend.weights(-16, 0, ALL).left, 1, "left")
	end,
	["a diagonal splits between two clips and the weights sum to 1"] = function()
		local w = MoveBlend.weights(8, 8, ALL)
		expect.near(w.back, 0.5, 1e-9, "back")
		expect.near(w.right, 0.5, 1e-9, "right")
		expect.near(w.forward + w.back + w.left + w.right, 1, 1e-9, "sum")
	end,
	["a direction the set lacks folds into forward"] = function()
		local w = MoveBlend.weights(8, 8, { forward = true, back = true })
		expect.near(w.forward, 0.5, 1e-9, "forward takes the sideways share")
		expect.near(w.back, 0.5, 1e-9, "back")
		expect.equal(w.right, 0, "right")
	end,
	["standing still is forward"] = function()
		expect.equal(MoveBlend.weights(0, 0, ALL).forward, 1, "forward")
	end,
	["the clip rate follows ground speed and is clamped"] = function()
		expect.near(MoveBlend.rate(13.3, 13.3), 1, 1e-9, "at the clip's own speed")
		expect.near(MoveBlend.rate(16, 13.3), 16 / 13.3, 1e-9, "faster")
		expect.equal(MoveBlend.rate(1, 13.3), MoveBlend.MIN_RATE, "floor")
		expect.equal(MoveBlend.rate(100, 13.3), MoveBlend.MAX_RATE, "ceiling")
	end,
	["a clip with no measured speed plays at rate 1"] = function()
		expect.equal(MoveBlend.rate(16, nil), 1, "rate")
	end,
}
