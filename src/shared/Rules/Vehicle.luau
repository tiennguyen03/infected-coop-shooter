--!strict
-- Vehicles, the pure rules (docs/PROGRESSION.md > The ATV; tests/Vehicle.spec.luau). Plain
-- numbers in and out, so Lune can test them: VehiclePhysics drives with them on the driver's
-- client (and on the server while nobody drives), VehicleService checks seats, rams, health
-- and the call limit with them. Tuning lives on the call-in's row, Config.CallIns.<Key>.Vehicle.

local Vehicle = {}

export type Drive = {
	TopSpeed: number, -- studs/s forward
	Reverse: number, -- studs/s backward
	Accel: number, -- studs/s² from a standstill (tapers to 0 at TopSpeed)
	Brake: number, -- studs/s² with the opposite pedal down
	Coast: number, -- studs/s² slowing off the pedals
}

export type Stage = "ok" | "smoke" | "fire" | "wreck"
export type Seat = "driver" | "gunner"
export type Call = "new" | "replace" | "refuse"

-- Moving slower than this (studs/s) counts as stopped: the opposite pedal reverses.
local STOPPED = 0.5

-- Degrees the front wheels turn at `speed`: `low` standing still, `high` at `top` and above.
function Vehicle.steerAngle(speed: number, top: number, low: number, high: number): number
	local share = math.clamp(math.abs(speed) / math.max(top, 1e-6), 0, 1)
	return low + (high - low) * share
end

-- Acceleration (studs/s², along the vehicle's forward) for `throttle` (-1..1) at
-- `forwardSpeed`. The opposite pedal brakes until stopped, then reverses; off the pedals it
-- coasts down and never past zero within one step of `dt` seconds.
function Vehicle.driveAccel(
	throttle: number,
	forwardSpeed: number,
	drive: Drive,
	dt: number
): number
	local v = forwardSpeed
	if throttle > 0 then
		if v < -STOPPED then
			return drive.Brake * throttle
		end
		return drive.Accel * throttle * math.max(0, 1 - v / drive.TopSpeed)
	elseif throttle < 0 then
		if v > STOPPED then
			return drive.Brake * throttle
		end
		return drive.Accel * throttle * math.max(0, 1 - -v / drive.Reverse)
	end
	if v == 0 then
		return 0
	end
	local stop = math.abs(v) / math.max(dt, 1e-6) -- what brings it to rest in this step
	return -math.sign(v) * math.min(drive.Coast, stop)
end

-- A wheel's spring push (force) from its `compression` (studs) and how fast it is
-- compressing (studs/s; negative = extending). It pushes the body up, never pulls it down.
function Vehicle.spring(
	compression: number,
	compressionSpeed: number,
	stiffness: number,
	damping: number
): number
	if compression <= 0 then
		return 0
	end
	return math.max(0, stiffness * compression + damping * compressionSpeed)
end

-- Damage to an Infected hit at `speed` (studs/s, either way): none under `minSpeed`.
function Vehicle.ramDamage(speed: number, minSpeed: number, perSpeed: number): number
	local s = math.abs(speed)
	if s < minSpeed then
		return 0
	end
	return s * perSpeed
end

-- Whether the back-seat gunner may fire along (aimX, aimZ) with the vehicle facing
-- (forwardX, forwardZ): not within `blockedDegrees` of straight ahead (the driver is there).
-- A shot straight up or down (no flat part) passes.
function Vehicle.gunnerCanFire(
	forwardX: number,
	forwardZ: number,
	aimX: number,
	aimZ: number,
	blockedDegrees: number
): boolean
	local aimLength = math.sqrt(aimX * aimX + aimZ * aimZ)
	local forwardLength = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
	if aimLength < 1e-6 or forwardLength < 1e-6 then
		return true
	end
	local cosine = (forwardX * aimX + forwardZ * aimZ) / (aimLength * forwardLength)
	return cosine < math.cos(math.rad(blockedDegrees))
end

-- Tipped past `tiltDegrees` (its up vector's Y below their cosine) and slower than
-- `slowSpeed`: on its side or roof and done tumbling, so it can be put back on its wheels.
function Vehicle.needsRighting(
	upY: number,
	speed: number,
	tiltDegrees: number,
	slowSpeed: number
): boolean
	return upY < math.cos(math.rad(tiltDegrees)) and math.abs(speed) < slowSpeed
end

-- How hurt it looks: smoke at or under `smokeAt` of max, fire at or under `fireAt`, the
-- wreck at 0.
function Vehicle.stage(health: number, maxHealth: number, smokeAt: number, fireAt: number): Stage
	if health <= 0 then
		return "wreck"
	end
	local share = health / maxHealth
	if share <= fireAt then
		return "fire"
	elseif share <= smokeAt then
		return "smoke"
	end
	return "ok"
end

-- Which seat a soldier getting on takes: the driver's first, then the back; nil when full.
function Vehicle.seatFor(driverTaken: boolean, gunnerTaken: boolean): Seat?
	if not driverTaken then
		return "driver"
	elseif not gunnerTaken then
		return "gunner"
	end
	return nil
end

-- Whether a soldier may call one in: `mine` of theirs and `squad` in all are on the map.
-- At their own cap, a new one replaces their old one unless someone is on it; otherwise the
-- squad's cap decides.
function Vehicle.callCheck(
	mine: number,
	squad: number,
	perPlayer: number,
	perSquad: number,
	mineOccupied: boolean
): Call
	if mine >= perPlayer then
		return if mineOccupied then "refuse" else "replace"
	end
	if squad >= perSquad then
		return "refuse"
	end
	return "new"
end

-- The server's check on the driver's client: faster than `slack` times top speed is not
-- an honest drive.
function Vehicle.overSpeed(speed: number, top: number, slack: number): boolean
	return math.abs(speed) > top * slack
end

return Vehicle
