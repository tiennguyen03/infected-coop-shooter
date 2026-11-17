--!strict
local Vehicle = require("../src/shared/Rules/Vehicle")
local expect = require("./expect")

local DRIVE: Vehicle.Drive = {
	TopSpeed = 40,
	Reverse = 12,
	Accel = 16,
	Brake = 40,
	Coast = 6,
}

return {
	["steering is widest standing still and narrows to SteerAtTop at full speed"] = function()
		expect.equal(Vehicle.steerAngle(0, 40, 35, 15), 35, "standing")
		expect.equal(Vehicle.steerAngle(40, 40, 35, 15), 15, "full speed")
		expect.equal(Vehicle.steerAngle(20, 40, 35, 15), 25, "half speed")
		expect.equal(Vehicle.steerAngle(-20, 40, 35, 15), 25, "reversing counts its speed")
		expect.equal(Vehicle.steerAngle(80, 40, 35, 15), 15, "past top speed stays at the top")
	end,
	["throttle accelerates and tapers to nothing at top speed"] = function()
		expect.equal(Vehicle.driveAccel(1, 0, DRIVE, 1 / 60), 16, "from a standstill")
		expect.near(Vehicle.driveAccel(1, 20, DRIVE, 1 / 60), 8, 1e-9, "half way")
		expect.equal(Vehicle.driveAccel(1, 40, DRIVE, 1 / 60), 0, "at the top")
		expect.equal(Vehicle.driveAccel(1, 45, DRIVE, 1 / 60), 0, "never past it")
	end,
	["the opposite pedal brakes before it reverses"] = function()
		expect.equal(Vehicle.driveAccel(-1, 20, DRIVE, 1 / 60), -40, "brake going forward")
		expect.equal(Vehicle.driveAccel(1, -10, DRIVE, 1 / 60), 40, "brake going backward")
		expect.equal(Vehicle.driveAccel(-1, 0, DRIVE, 1 / 60), -16, "reverse from a stop")
		expect.equal(Vehicle.driveAccel(-1, -12, DRIVE, 1 / 60), 0, "reverse is capped")
	end,
	["off the pedals it coasts down without rolling back the other way"] = function()
		expect.equal(Vehicle.driveAccel(0, 20, DRIVE, 1 / 60), -6, "rolling forward")
		expect.equal(Vehicle.driveAccel(0, -20, DRIVE, 1 / 60), 6, "rolling backward")
		expect.near(Vehicle.driveAccel(0, 0.05, DRIVE, 1 / 60), -3, 1e-9, "stops, no overshoot")
		expect.equal(Vehicle.driveAccel(0, 0, DRIVE, 1 / 60), 0, "standing still")
	end,
	["the spring pushes on compression and never pulls the wheel to the ground"] = function()
		expect.equal(Vehicle.spring(0.5, 0, 100, 10), 50, "compressed, still")
		expect.equal(Vehicle.spring(0.5, 2, 100, 10), 70, "compressing: damper adds")
		expect.equal(Vehicle.spring(0.5, -2, 100, 10), 30, "extending: damper takes away")
		expect.equal(Vehicle.spring(0.1, -5, 100, 10), 0, "never a pull")
		expect.equal(Vehicle.spring(0, 0, 100, 10), 0, "off the ground")
	end,
	["a ram hurts by speed above the minimum and nothing below"] = function()
		expect.equal(Vehicle.ramDamage(11.9, 12, 2.5), 0, "too slow")
		expect.equal(Vehicle.ramDamage(12, 12, 2.5), 30, "at the minimum")
		expect.equal(Vehicle.ramDamage(40, 12, 2.5), 100, "full speed")
		expect.equal(Vehicle.ramDamage(-40, 12, 2.5), 100, "reversing into one counts too")
	end,
	["the gunner fires all round except through the driver"] = function()
		-- forward is +Z; the blocked cone is 25 degrees either side of straight ahead
		expect.equal(Vehicle.gunnerCanFire(0, 1, 0, 1, 25), false, "straight ahead")
		expect.equal(Vehicle.gunnerCanFire(0, 1, 0.3, 1, 25), false, "17 degrees off")
		expect.equal(Vehicle.gunnerCanFire(0, 1, 0.6, 1, 25), true, "31 degrees off")
		expect.equal(Vehicle.gunnerCanFire(0, 1, 1, 0, 25), true, "to the side")
		expect.equal(Vehicle.gunnerCanFire(0, 1, 0, -1, 25), true, "behind")
		expect.equal(Vehicle.gunnerCanFire(0, 1, 0, 0, 25), true, "straight up or down")
	end,
	["it needs righting only when tipped past the limit and nearly stopped"] = function()
		local cos70 = math.cos(math.rad(70))
		expect.equal(Vehicle.needsRighting(1, 0, 70, 2), false, "upright")
		expect.equal(Vehicle.needsRighting(cos70 - 0.01, 0, 70, 2), true, "on its side")
		expect.equal(Vehicle.needsRighting(-1, 0, 70, 2), true, "upside down")
		expect.equal(Vehicle.needsRighting(-1, 5, 70, 2), false, "still tumbling")
	end,
	["health shows as smoke, then fire, then the wreck"] = function()
		expect.equal(Vehicle.stage(400, 400, 0.5, 0.25), "ok")
		expect.equal(Vehicle.stage(201, 400, 0.5, 0.25), "ok")
		expect.equal(Vehicle.stage(200, 400, 0.5, 0.25), "smoke")
		expect.equal(Vehicle.stage(100, 400, 0.5, 0.25), "fire")
		expect.equal(Vehicle.stage(0, 400, 0.5, 0.25), "wreck")
		expect.equal(Vehicle.stage(-5, 400, 0.5, 0.25), "wreck")
	end,
	["getting on fills the driver's seat first, then the back"] = function()
		expect.equal(Vehicle.seatFor(false, false), "driver")
		expect.equal(Vehicle.seatFor(true, false), "gunner")
		expect.equal(Vehicle.seatFor(false, true), "driver")
		expect.equal(Vehicle.seatFor(true, true), nil)
	end,
	["a new call replaces your empty ATV, never an occupied one, within the squad's cap"] = function()
		expect.equal(Vehicle.callCheck(0, 0, 1, 2, false), "new", "first one")
		expect.equal(Vehicle.callCheck(0, 1, 1, 2, false), "new", "a squadmate has one")
		expect.equal(Vehicle.callCheck(0, 2, 1, 2, false), "refuse", "squad at its cap")
		expect.equal(Vehicle.callCheck(1, 1, 1, 2, false), "replace", "my empty one goes")
		expect.equal(Vehicle.callCheck(1, 2, 1, 2, false), "replace", "replacing keeps the count")
		expect.equal(Vehicle.callCheck(1, 1, 1, 2, true), "refuse", "someone is on mine")
	end,
	["the server takes the vehicle back past the speed slack"] = function()
		expect.equal(Vehicle.overSpeed(49, 40, 1.25), false)
		expect.equal(Vehicle.overSpeed(51, 40, 1.25), true)
	end,
}
