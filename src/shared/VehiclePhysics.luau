--!strict
-- How a vehicle drives (docs/PROGRESSION.md > The ATV): ray suspension and arcade tyres on
-- the one chassis part, pushed with impulses each physics step by whoever simulates it: the
-- driver's client while a soldier drives (VehicleController; the server gives them the
-- chassis), the server while nobody does (VehicleService). The numbers are the call-in's
-- Config.CallIns.<Key>.Vehicle block; the arithmetic is Rules/Vehicle (Lune-tested).
--
-- Per wheel: a ray down from its spring mount, as long as the travel plus the wheel. A hit
-- pushes the chassis up at the mount (Vehicle.spring), the tyre stops a sideways slide
-- (Grip) and drives along the ground (Vehicle.driveAccel) unless the ground is steeper than
-- MaxClimb. Grip and drive push at the centre of mass' height, so a hard turn leans it
-- without flipping it. In the air it levels itself (Upright), so it lands on its wheels.

local Workspace = game:GetService("Workspace")

local Vehicle = require(script.Parent.Rules.Vehicle)
local VehicleBody = require(script.Parent.VehicleBody)

local VehiclePhysics = {}

-- The collision groups (VehicleService registers them): the chassis, and the wheel rays,
-- which pass through the Infected and gore (a ram is the server's, not a bump to ride on).
VehiclePhysics.Group = "Vehicle"
VehiclePhysics.RayGroup = "VehicleRay"

local MAX_SIDE_ACCEL = 140 -- studs/s²: the most a tyre can stop a slide (no snap on landing)
local SPIN_DAMP = 2 -- airborne: how fast a tumble's spin bleeds off

export type Input = { throttle: number, steer: number }

-- The ray filter for `model`'s wheels: the vehicle and anything in `exclude` (the riders,
-- every soldier) pass through, and so does anything in a group the ray group ignores.
function VehiclePhysics.params(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.CollisionGroup = VehiclePhysics.RayGroup
	params.IgnoreWater = false
	return params
end

-- One physics step of `dt` seconds for `model` (built by VehicleBody from `bodyId`) with
-- `input` (throttle and steer, -1..1). Returns how many wheels touched the ground.
function VehiclePhysics.step(
	model: Model,
	bodyId: string,
	cfg: any,
	input: Input,
	dt: number,
	params: RaycastParams
): number
	local root = model.PrimaryPart
	local body = VehicleBody.get(bodyId)
	if not root or not body or root.Anchored then
		return 0
	end
	local frame = root.CFrame
	local up = frame.UpVector
	local look = frame.LookVector
	local mass = root.AssemblyMass
	local velocity = root.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(look)
	local throttle = math.clamp(input.throttle, -1, 1)
	local steer = math.clamp(input.steer, -1, 1)

	local accel = Vehicle.driveAccel(throttle, forwardSpeed, cfg, dt)
	-- Off the pedals and nearly stopped: the brake holds it (no creeping down a kerb).
	if throttle == 0 and math.abs(forwardSpeed) < 2 then
		accel = math.clamp(-forwardSpeed / math.max(dt, 1e-3), -cfg.Brake, cfg.Brake)
	end
	local steerDegrees = Vehicle.steerAngle(
		forwardSpeed,
		cfg.TopSpeed,
		cfg.SteerAngle,
		cfg.SteerAtTop
	) * steer
	-- A right turn (steer > 0) turns the wheel's look clockwise seen from above.
	local steered = CFrame.fromAxisAngle(up, -math.rad(steerDegrees)):VectorToWorldSpace(look)

	local suspension = cfg.Suspension
	local length = suspension.Travel + body.wheelRadius
	local share = mass / #body.wheels
	local centre = root.AssemblyCenterOfMass
	local climb = math.cos(math.rad(cfg.MaxClimb))
	local grounded = 0
	for _, wheel in body.wheels do
		local mount = frame:PointToWorldSpace(wheel.mount)
		local hit = Workspace:Raycast(mount, -up * length, params)
		if hit then
			grounded += 1
			local compression = math.min(length - hit.Distance, suspension.Travel)
			local pointVelocity = root:GetVelocityAtPosition(mount)
			local push = Vehicle.spring(
				compression,
				-pointVelocity:Dot(up),
				suspension.Stiffness,
				suspension.Damping
			)
			root:ApplyImpulseAtPosition(up * push * share * dt, mount)

			-- The tyre, on the ground's plane, pushing at the centre of mass' height.
			local normal = hit.Normal
			local wheelLook = if wheel.front then steered else look
			local along = wheelLook - normal * wheelLook:Dot(normal)
			if along.Magnitude > 1e-3 then
				along = along.Unit
				local across = along:Cross(normal)
				local at = mount + up * (centre - mount):Dot(up)
				local slide = pointVelocity:Dot(across)
				local grip = math.clamp(-slide * cfg.Grip, -MAX_SIDE_ACCEL, MAX_SIDE_ACCEL)
				local drive = if normal.Y >= climb then accel else 0
				root:ApplyImpulseAtPosition((across * grip + along * drive) * share * dt, at)
			end
		end
	end

	if grounded < 2 then
		-- In the air or balanced on two wheels: level it, and bleed off a tumble.
		local tilt = up:Cross(Vector3.yAxis)
		local spin = root.AssemblyAngularVelocity
		root:ApplyAngularImpulse((tilt * cfg.Upright - spin * SPIN_DAMP) * mass * dt)
	end
	return grounded
end

return VehiclePhysics
