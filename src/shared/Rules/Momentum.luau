--!strict
-- The walk's weight: pure, unit-tested with Lune (tests/Momentum.spec.luau).
-- MomentumController feeds it the carried horizontal velocity, the input direction times
-- WalkSpeed and Config.Movement.Momentum each frame.

local Momentum = {}

-- `current` moved toward `target` by at most `maxDelta`; it lands on the target rather than
-- passing it.
function Momentum.moveToward(current: Vector3, target: Vector3, maxDelta: number): Vector3
	local delta = target - current
	local distance = delta.Magnitude
	if distance <= maxDelta or distance < 1e-4 then
		return target
	end
	return current + delta / distance * maxDelta
end

-- One frame of the walk: the carried `velocity` eased toward `target` (studs/s). Speeding up
-- uses `acceleration`; slowing down, stopping or turning against the current heading uses
-- `deceleration`. A lower `speed` (stance, ADS, end of sprint) caps the result at once.
function Momentum.step(
	velocity: Vector3,
	target: Vector3,
	speed: number,
	acceleration: number,
	deceleration: number,
	dt: number
): Vector3
	local braking = target.Magnitude < velocity.Magnitude - 0.01 or target:Dot(velocity) < 0
	local rate = if braking then deceleration else acceleration
	local result = Momentum.moveToward(velocity, target, rate * dt)
	if result.Magnitude > speed then
		result = result.Unit * speed
	end
	return result
end

return Momentum
