--!strict
-- Hands on the slung gun (owner, 2026-11-11: "if you are holding the smg then one of your
-- hands is just floating in the air"). Every soldier on the ship carries the gun across the
-- chest (PikeBody moves the grip weld onto the upper torso); each frame, on every client, after
-- the Animator has posed the body, both arms are solved onto it: the right palm on the grip,
-- the left on the handguard part-way to the muzzle (Config.Lobby.Soldier.Hands). The points
-- come from the gun actually carried, so a short SMG and a long rifle both fit; the legs and
-- the rest of the body keep the Rthro clips (SoldierMoves).
--
-- Two-bone IK written to the joints' Transform, the same method as Tien's revive arms
-- (Shared.ReviveAnimation), kept separate so the revive is untouched. Works on Motor6Ds and on
-- the AnimationConstraints a physics rig has in their place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SlingHands = {}

local HANDS = Config.Lobby.Soldier.Hands

-- Part1 = Part0 * c0 * Transform * c1^-1, for a Motor6D or an AnimationConstraint.
type Joint = {
	motor: Motor6D?,
	constraint: AnimationConstraint?,
	part0: BasePart,
	c0: CFrame,
	c1: CFrame,
}

type Arm = {
	shoulder: Joint,
	elbow: Joint,
	wrist: Joint?,
	upperLength: number,
	lowerLength: number,
	upperFix: CFrame,
	lowerFix: CFrame,
}

type Body = {
	character: Model,
	torso: BasePart,
	grip: Weld,
	left: Arm,
	right: Arm,
	weight: number, -- 0..1, eases the hands onto the gun
}

local bodies: { [Model]: Body } = {}

local function readJoint(part: Instance?, name: string): Joint?
	local joint = part and part:FindFirstChild(name)
	if not joint then
		return nil
	end
	if joint:IsA("Motor6D") then
		local part0 = joint.Part0
		if part0 then
			return { motor = joint, part0 = part0, c0 = joint.C0, c1 = joint.C1 }
		end
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local part0 = a0 and a0.Parent
		if a0 and a1 and part0 and part0:IsA("BasePart") then
			return { constraint = joint, part0 = part0, c0 = a0.CFrame, c1 = a1.CFrame }
		end
	end
	return nil
end

local function getTransform(joint: Joint): CFrame
	if joint.motor then
		return joint.motor.Transform
	elseif joint.constraint then
		return joint.constraint.Transform
	end
	return CFrame.identity
end

local function setTransform(joint: Joint, transform: CFrame)
	if joint.motor then
		joint.motor.Transform = transform
	elseif joint.constraint then
		joint.constraint.Transform = transform
	end
end

local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, from:Dot(to)))
end

local function readArm(character: Model, prefix: string): Arm?
	local shoulder = readJoint(character:FindFirstChild(prefix .. "UpperArm"), prefix .. "Shoulder")
	local elbow = readJoint(character:FindFirstChild(prefix .. "LowerArm"), prefix .. "Elbow")
	local wrist = readJoint(character:FindFirstChild(prefix .. "Hand"), prefix .. "Wrist")
	if not shoulder or not elbow then
		return nil
	end
	local down = -Vector3.yAxis
	local upperBone = elbow.c0.Position - shoulder.c1.Position
	local lowerBone = if wrist then wrist.c0.Position - elbow.c1.Position else down * 0.8
	if upperBone.Magnitude < 0.05 or lowerBone.Magnitude < 0.05 then
		return nil
	end
	return {
		shoulder = shoulder,
		elbow = elbow,
		wrist = wrist,
		upperLength = upperBone.Magnitude,
		lowerLength = lowerBone.Magnitude + HANDS.HandLength,
		upperFix = rotationBetween(upperBone.Unit, down),
		lowerFix = rotationBetween(lowerBone.Unit, down),
	}
end

-- A limb's rotation: it hangs along -Y, its front is -Z.
local function limbRotation(along: Vector3, front: Vector3): CFrame
	local y = -along
	local z = -front
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end

local function perpendicular(vector: Vector3, to: Vector3, fallback: Vector3): Vector3
	local across = vector - to * vector:Dot(to)
	if across.Magnitude < 1e-3 then
		across = fallback - to * fallback:Dot(to)
	end
	if across.Magnitude < 1e-3 then
		across = to:Cross(Vector3.xAxis)
	end
	return across.Unit
end

-- Puts the palm of `arm` on `target` (as far as it reaches), the elbow toward `pole`,
-- blended over the clip's pose by `weight`.
local function solveArm(arm: Arm, target: Vector3, pole: Vector3, weight: number)
	local shoulder, elbow = arm.shoulder, arm.elbow
	local socket = shoulder.part0.CFrame * shoulder.c0
	local upper, lower = arm.upperLength, arm.lowerLength
	local toTarget = target - socket.Position
	local direction = if toTarget.Magnitude > 1e-3 then toTarget.Unit else -Vector3.yAxis
	local distance =
		math.clamp(toTarget.Magnitude, math.abs(upper - lower) + 0.05, upper + lower - 0.01)
	local cosine = math.clamp(
		(upper * upper + distance * distance - lower * lower) / (2 * upper * distance),
		-1,
		1
	)
	local out = perpendicular(pole, direction, Vector3.yAxis)
	local elbowAt = direction * (upper * cosine) + out * (upper * math.sqrt(1 - cosine * cosine))
	local upperAlong = elbowAt.Unit
	local lowerAlong = (direction * distance - elbowAt).Unit
	local upperFront = -perpendicular(out, upperAlong, direction)
	local upperRotation = limbRotation(upperAlong, upperFront) * arm.upperFix
	local lowerRotation = limbRotation(
		lowerAlong,
		perpendicular(upperFront, lowerAlong, upperAlong)
	) * arm.lowerFix
	local shoulderGoal = socket.Rotation:Inverse() * upperRotation * shoulder.c1.Rotation
	local elbowGoal = (upperRotation * elbow.c0.Rotation):Inverse()
		* lowerRotation
		* elbow.c1.Rotation
	local shoulderClip, elbowClip = getTransform(shoulder), getTransform(elbow)
	setTransform(shoulder, shoulderClip:Lerp(shoulderGoal + shoulderClip.Position, weight))
	setTransform(elbow, elbowClip:Lerp(elbowGoal + elbowClip.Position, weight))
	local wrist = arm.wrist
	if wrist then
		local wristClip = getTransform(wrist)
		setTransform(wrist, wristClip:Lerp(CFrame.new(wristClip.Position), weight))
	end
end

-- The slung gun's grip weld (PikeBody), or nil while the gun is in the hand or absent.
local function slungGrip(character: Model, torso: BasePart): Weld?
	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if grip and grip:IsA("Weld") and grip.Part0 == torso and grip.Part1 then
		return grip
	end
	return nil
end

local function bodyOf(character: Model): Body?
	local known = bodies[character]
	if known then
		return known
	end
	local torso = character:FindFirstChild("UpperTorso")
	if not (torso and torso:IsA("BasePart")) then
		return nil
	end
	local grip = slungGrip(character, torso)
	local left, right = readArm(character, "Left"), readArm(character, "Right")
	if not (grip and left and right) then
		return nil
	end
	local body = {
		character = character,
		torso = torso,
		grip = grip,
		left = left,
		right = right,
		weight = 0,
	}
	bodies[character] = body
	return body
end

-- The left hand's point on the handguard, in the grip's space: part-way to the muzzle.
local function handguard(handle: BasePart): Vector3
	local tool = handle.Parent
	local muzzle = tool and tool:FindFirstChild("Muzzle")
	local reach = 1.6
	if muzzle and muzzle:IsA("BasePart") then
		reach = math.abs(handle.CFrame:PointToObjectSpace(muzzle.Position).Z)
	end
	local along = math.clamp(reach * HANDS.LeftShare, HANDS.LeftAlong[1], HANDS.LeftAlong[2])
	return Vector3.new(0, HANDS.LeftUp, -along)
end

local function step(deltaTime: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local body = bodyOf(character)
		if not body then
			continue
		end
		local grip = body.grip
		local handle = grip.Part1
		if not (grip.Parent and handle and grip.Part0 == body.torso) then
			bodies[character] = nil -- re-read next frame (a new weld, a respawn)
			continue
		end
		body.weight = math.min(1, body.weight + deltaTime / math.max(HANDS.BlendSeconds, 0.01))
		-- The grip as the weld seats it (the handle's own CFrame lags the torso by a frame).
		local seat = body.torso.CFrame * grip.C0 * grip.C1:Inverse()
		local poleRight = body.torso.CFrame:VectorToWorldSpace(HANDS.RightPole)
		local poleLeft = body.torso.CFrame:VectorToWorldSpace(HANDS.LeftPole)
		solveArm(body.right, seat.Position, poleRight, body.weight)
		solveArm(body.left, seat:PointToWorldSpace(handguard(handle)), poleLeft, body.weight)
	end
	for character in bodies do
		if not character.Parent then
			bodies[character] = nil
		end
	end
end

function SlingHands.init()
	if not (Config.Lobby.Soldier.Enabled and Config.Lobby.Soldier.CarryRifle) then
		return
	end
	-- After the Animator has written this frame's pose (Tien's revive arms use the same step).
	RunService.Stepped:Connect(function(_, deltaTime)
		step(deltaTime)
	end)
end

return SlingHands
