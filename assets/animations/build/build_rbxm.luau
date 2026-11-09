--!nocheck
-- Builds a publishable .rbxm per retargeted clip without Studio (mirrors
-- src/shared/AnimationBuilder.build; keep the two in step):
--   lune run assets/animations/build/build_rbxm.luau [outDir]
-- Reads src/shared/AnimationClips/*.json (git-ignored, from retarget.py), writes
-- <outDir>/<clip>.rbxm (default assets/animations/build/out, git-ignored). Upload each with the
-- Studio MCP upload_asset (assetType Animation, groupId 270506601: the group owns every asset).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local process = require("@lune/process")
local SRC = "src/shared/AnimationClips"
local OUT = process.args[1] or "assets/animations/build/out"
if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end

local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
}
local ORDER = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot" }
local LOWER = { LowerTorso = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }

local n = 0
for _, file in fs.readDir(SRC) do
	if string.sub(file, -5) ~= ".json" then
		continue
	end
	local clip = serde.decode("json", fs.readFile(SRC .. "/" .. file))
	local seq = Instance.new("KeyframeSequence")
	seq.Name = clip.name
	seq.Loop = clip.loop
	seq.Priority = Enum.AnimationPriority.Core
	for _, key in clip.keyframes do
		local kf = Instance.new("Keyframe")
		kf.Time = key.t
		local poses = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		poses.HumanoidRootPart = root
		for _, part in ORDER do
			local v = key.poses[part]
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.CFrame = CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7])
			pose.Weight = if clip.upperBody and LOWER[part] then 0 else 1
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.Parent = poses[PARENT[part]]
			poses[part] = pose
		end
		kf.Parent = seq
	end
	fs.writeFile(OUT .. "/" .. clip.name .. ".rbxm", roblox.serializeModel({ seq }))
	n += 1
end
print("built", n)
