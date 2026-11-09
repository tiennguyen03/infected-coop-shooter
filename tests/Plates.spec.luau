--!strict
local Plates = require("../src/shared/Rules/Plates")
local expect = require("./expect")

return {
	["a plate takes the full round when he is not guarding"] = function()
		local left, dealt = Plates.hit(500, 20, nil, false)
		expect.equal(left, 480, "left")
		expect.equal(dealt, 20, "dealt")
	end,
	["a guarded plate takes the round scaled by the guard factor"] = function()
		local left, dealt = Plates.hit(500, 20, 0.25, false)
		expect.equal(left, 495, "left")
		expect.equal(dealt, 5, "dealt")
	end,
	["the flank plate ignores the guard"] = function()
		local left, dealt = Plates.hit(500, 20, 0.25, true)
		expect.equal(left, 480, "left")
		expect.equal(dealt, 20, "dealt")
	end,
	["a plate never goes below zero and nothing spills to the body"] = function()
		local left, dealt = Plates.hit(10, 40, nil, false)
		expect.equal(left, 0, "left")
		expect.equal(dealt, 40, "dealt")
	end,
}
