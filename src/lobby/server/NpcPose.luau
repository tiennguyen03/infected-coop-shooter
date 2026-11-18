--!strict
-- The Carrier v2 sellers' poses (docs/sprints/CARRIER_V2.md > Poses and idle animations; owner
-- 2026-11-17: "the regular R15... but put them in the same pose"). Each seller's R15 figure
-- (NpcBody) keeps its look; its Motor6Ds are turned once into the corner's pose: the Quartermaster
-- perched on his stool leaning on the glass, the call-ins sergeant on his crate with a mug and a
-- wave, the Loadmaster sitting back in his hammock, the motor sergeant bent over the part in her
-- lap, Control's watch officer tipped back with her boots on the map table. The idle clip
-- NpcBody plays still breathes on top. Idle loops per seller are the follow-up (the doc).
--
-- Angles are degrees about each joint's own axes (R15 rest: limbs down, facing -Z): +X swings a
-- limb forward and up, a negative Waist X leans forward. `root` moves the body against its
-- anchored root, in the figure's frame: +Y up (onto a seat), +Z back (over the seat).

local NpcPose = {}

type Pose = { root: Vector3, joints: { [string]: Vector3 } }

local SEATED_LEGS = {
	LeftHip = Vector3.new(90, 0, 0),
	RightHip = Vector3.new(90, 0, 0),
	LeftKnee = Vector3.new(-90, 0, 0),
	RightKnee = Vector3.new(-90, 0, 0),
}

local function seated(extra: { [string]: Vector3 }): { [string]: Vector3 }
	local joints = table.clone(SEATED_LEGS)
	for name, angles in extra do
		joints[name] = angles
	end
	return joints
end

local POSES: { [string]: Pose } = {
	arms_room = { -- perched on the high stool, both elbows on the glass
		root = Vector3.new(0, 1.0, 0.6),
		joints = seated({
			Waist = Vector3.new(-30, 0, 0),
			Neck = Vector3.new(15, 0, 0),
			LeftShoulder = Vector3.new(60, 0, 0),
			RightShoulder = Vector3.new(60, 0, 0),
			LeftElbow = Vector3.new(45, 0, 0),
			RightElbow = Vector3.new(45, 0, 0),
			LeftKnee = Vector3.new(-80, 0, 0),
			RightKnee = Vector3.new(-80, 0, 0),
		}),
	},
	callins = { -- on the crate, forearms on his knees, a mug in one hand, waving with the other
		root = Vector3.new(0, 0, 0),
		joints = seated({
			Waist = Vector3.new(-20, 0, 0),
			Neck = Vector3.new(10, 0, 0),
			RightShoulder = Vector3.new(45, 0, 0),
			RightElbow = Vector3.new(55, 0, 0),
			LeftShoulder = Vector3.new(135, 0, -10),
			LeftElbow = Vector3.new(35, 0, 0),
			LeftKnee = Vector3.new(-100, 0, 0),
			RightKnee = Vector3.new(-100, 0, 0),
		}),
	},
	loadmaster = { -- sitting back in the hammock, one arm behind his head, one boot down
		root = Vector3.new(0, 0.1, 0.3),
		joints = seated({
			Waist = Vector3.new(20, 0, 0),
			LeftShoulder = Vector3.new(165, 0, -10),
			LeftElbow = Vector3.new(110, 0, 0),
			RightShoulder = Vector3.new(60, 0, 0),
			RightElbow = Vector3.new(20, 0, 0),
			RightHip = Vector3.new(60, 0, 0),
			RightKnee = Vector3.new(-35, 0, 0),
		}),
	},
	vehicles = { -- on her tyres, bent over the part in her lap, looking up
		root = Vector3.new(0, 0.4, 0.2),
		joints = seated({
			Waist = Vector3.new(-30, 0, 0),
			Neck = Vector3.new(25, 0, 0),
			LeftShoulder = Vector3.new(45, 0, 0),
			RightShoulder = Vector3.new(45, 0, 0),
			LeftElbow = Vector3.new(60, 0, 0),
			RightElbow = Vector3.new(60, 0, 0),
		}),
	},
	plot = { -- tipped back in the chair, boots on the map table's end, mug on her chest
		root = Vector3.new(0, -0.2, 0.2),
		joints = {
			Waist = Vector3.new(25, 0, 0),
			Neck = Vector3.new(-10, 0, 0),
			LeftHip = Vector3.new(100, 0, 0),
			RightHip = Vector3.new(100, 0, 0),
			LeftKnee = Vector3.new(-5, 0, 0),
			RightKnee = Vector3.new(-5, 0, 0),
			LeftShoulder = Vector3.new(40, 0, 0),
			LeftElbow = Vector3.new(100, 0, 0),
			RightShoulder = Vector3.new(-20, 0, 0),
		},
	},
}

local function turn(motor: Motor6D, angles: Vector3)
	motor.C0 = motor.C0 * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
end

-- Poses one seller's figure; the joints are made after its look loads (NpcBody), so this waits
-- for them (a stand-in with no rig is left as it is).
function NpcPose.apply(body: Model, id: string)
	local pose = POSES[id]
	if not pose then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 30
		local lower = body:FindFirstChild("LowerTorso")
		while not (lower and lower:FindFirstChild("Root")) and os.clock() < deadline do
			task.wait(0.25)
			lower = body:FindFirstChild("LowerTorso")
		end
		if not (lower and lower:FindFirstChild("Root")) then
			return
		end
		for _, motor in body:GetDescendants() do
			if not motor:IsA("Motor6D") then
				continue
			end
			if motor.Name == "Root" then
				motor.C0 = motor.C0 * CFrame.new(pose.root)
			end
			local angles = pose.joints[motor.Name]
			if angles then
				turn(motor, angles)
			end
		end
	end)
end

return NpcPose
