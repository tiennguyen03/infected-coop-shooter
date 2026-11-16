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
	["the first shot has no bloom and leaves one shot's worth"] = function()
		local carried, after = Spread.bloom(0, 3, 0, 6, 0.5)
		expect.equal(carried, 0, "carried")
		expect.equal(after, 0.5, "after")
	end,
	["held fire stacks bloom up to the gun's max"] = function()
		local carried, after = Spread.bloom(1, 3, -0.1, 6, 0.5)
		expect.equal(carried, 1, "no recovery inside the delay")
		expect.equal(after, 1.5, "one more shot")
		carried, after = Spread.bloom(2.8, 3, 0, 6, 0.5)
		expect.equal(carried, 2.8, "carried")
		expect.equal(after, 3, "capped")
	end,
	["a pause past the delay recovers bloom, never below none"] = function()
		local carried, after = Spread.bloom(2, 3, 0.25, 6, 0.5)
		expect.equal(near(carried, 0.5), true, "a quarter second at 6 a second")
		expect.equal(near(after, 1), true, "after")
		carried, after = Spread.bloom(2, 3, 10, 6, 0.5)
		expect.equal(carried, 0, "fully recovered")
		expect.equal(after, 0.5, "after")
	end,
	["a swap to a tighter gun caps the carried bloom at its max"] = function()
		local carried, after = Spread.bloom(3, 1, 0, 6, 0.5)
		expect.equal(carried, 1, "carried")
		expect.equal(after, 1, "after")
	end,
}
