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
		local left, dealt, body = Plates.hit(10, 40, nil, false)
		expect.equal(left, 0, "left")
		expect.equal(dealt, 40, "dealt")
		expect.equal(body, 0, "body")
	end,
	["the weak spot passes its share of the round to the body"] = function()
		local left, dealt, body = Plates.hit(400, 20, nil, true, 0.5)
		expect.equal(left, 380, "left")
		expect.equal(dealt, 20, "dealt")
		expect.equal(body, 10, "body")
	end,
	["the weak spot ignores the guard too"] = function()
		local _, dealt, body = Plates.hit(400, 20, 0.25, true, 0.5)
		expect.equal(dealt, 20, "dealt")
		expect.equal(body, 10, "body")
	end,
}
