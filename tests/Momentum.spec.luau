--!strict
-- Rules/Momentum: the walk's weight (MomentumController). Vectors are Lune's Roblox Vector3.

local roblox = require("@lune/roblox")

local Momentum = require("../src/shared/Rules/Momentum")
local expect = require("./expect")

local Vector3 = (roblox :: any).Vector3
local ZERO = Vector3.new(0, 0, 0)

-- Acceleration 60, Deceleration 75 (Config.Movement.Momentum), walk speed 16.
local function step(velocity: any, target: any, dt: number): any
	return Momentum.step(velocity, target, 16, 60, 75, dt)
end

return {
	["move toward stops at the target instead of passing it"] = function()
		local result = Momentum.moveToward(Vector3.new(15, 0, 0), Vector3.new(16, 0, 0), 5)
		expect.near(result.X, 16, 1e-9)
	end,
	["move toward moves at most the step, along the line to the target"] = function()
		local result = Momentum.moveToward(ZERO, Vector3.new(3, 0, 4), 1)
		expect.near(result.X, 0.6, 1e-6, "x")
		expect.near(result.Z, 0.8, 1e-6, "z")
	end,
	["speeding up uses the acceleration"] = function()
		local result = step(ZERO, Vector3.new(16, 0, 0), 0.1)
		expect.near(result.X, 6, 1e-6)
	end,
	["slowing down uses the deceleration"] = function()
		local result = step(Vector3.new(16, 0, 0), ZERO, 0.1)
		expect.near(result.X, 8.5, 1e-6)
	end,
	["turning against the heading uses the deceleration"] = function()
		local result = step(Vector3.new(16, 0, 0), Vector3.new(-16, 0, 0), 0.1)
		expect.near(result.X, 8.5, 1e-6)
	end,
	["a lower speed caps the carried velocity at once"] = function()
		-- Sprint (24) into a walk speed of 16 with the input still held forward.
		local result = step(Vector3.new(24, 0, 0), Vector3.new(16, 0, 0), 0.01)
		expect.near(result.Magnitude, 16, 1e-6)
	end,
	["standing still stays still"] = function()
		local result = step(ZERO, ZERO, 0.1)
		expect.near(result.Magnitude, 0, 1e-9)
	end,
}
