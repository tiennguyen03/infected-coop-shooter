--!strict
-- Turns a retargeted clip table (assets/animations/build/retarget.py -> Shared.AnimationClips)
-- into a KeyframeSequence for the R15 rig. Dev-time only: in Studio the sequence can be
-- registered for a temporary id (preview in a playtest) or saved to Roblox for a real
-- AnimationId; shipped code plays the published ids in Config.Animations.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Clip = {
	name: string,
	fps: number,
	loop: boolean,
	upperBody: boolean?,
	duration: number,
	keyframes: { { t: number, poses: { [string]: { number } } } },
}

local AnimationBuilder = {}

-- R15 part -> parent part: the Pose tree mirrors the rig.
local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
}
local ORDER = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- Parts an upper-body overlay leaves to the locomotion clip underneath.
local LOWER_BODY = {
	LowerTorso = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local function toCFrame(v: { number }): CFrame
	return CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7])
end

function AnimationBuilder.build(clip: Clip, priority: Enum.AnimationPriority?): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = clip.name
	sequence.Loop = clip.loop
	sequence.Priority = priority or Enum.AnimationPriority.Core
	for _, key in clip.keyframes do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.t
		local poses: { [string]: Pose } = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = keyframe
		poses.HumanoidRootPart = root
		for _, part in ORDER do
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.CFrame = toCFrame(key.poses[part])
			pose.Weight = if clip.upperBody and LOWER_BODY[part] then 0 else 1
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.Parent = poses[PARENT[part]]
			poses[part] = pose
		end
		keyframe.Parent = sequence
	end
	return sequence
end

-- Loads a clip table from Shared.AnimationClips (nil when the clips are not generated).
function AnimationBuilder.loadClip(name: string): Clip?
	local folder = ReplicatedStorage:FindFirstChild("Shared")
		and ReplicatedStorage.Shared:FindFirstChild("AnimationClips")
	local module = folder and folder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	return require(module) :: Clip
end

-- Studio only: a temporary animation id for previewing the clip in a playtest.
function AnimationBuilder.previewId(name: string, priority: Enum.AnimationPriority?): string?
	local clip = AnimationBuilder.loadClip(name)
	if not clip then
		return nil
	end
	local sequence = AnimationBuilder.build(clip, priority)
	return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
end

return AnimationBuilder
