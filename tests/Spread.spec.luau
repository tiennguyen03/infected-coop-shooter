--!strict
local Spread = require("../src/shared/Rules/Spread")
local expect = require("./expect")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return {
	["no cone means straight down the barrel"] = function()
		local angle, roll = Spread.sample(0, 0.7, 0.3)
		expect.equal(angle, 0, "angle")
		expect.equal(roll, 0, "roll")
	end,
	["a sample never leaves the cone"] = function()
		for i = 0, 20 do
			local angle = Spread.sample(5, i / 20, 0.5)
			expect.equal(angle <= math.rad(5) + 1e-9, true, `u1 {i / 20}`)
		end
	end,
	["the edge of the cone is the full half-angle"] = function()
		local angle, roll = Spread.sample(4, 1, 0.25)
		expect.equal(near(angle, math.rad(4)), true, "angle")
		expect.equal(near(roll, math.pi / 2), true, "roll")
	end,
	["pellets uniform over the disc: half the area is inside 1/sqrt(2) of the radius"] = function()
		local angle = Spread.sample(10, 0.5, 0)
		expect.equal(near(angle, math.rad(10) * math.sqrt(0.5)), true)
	end,
	["a pellet the client sends is allowed inside the cone plus tolerance only"] = function()
		expect.equal(Spread.allowed(4.9, 5, 0.5), true, "inside")
		expect.equal(Spread.allowed(5.4, 5, 0.5), true, "within tolerance")
		expect.equal(Spread.allowed(6, 5, 0.5), false, "outside")
		expect.equal(Spread.allowed(0.2, 0, 0.5), true, "no cone, tiny wobble")
	end,
}
