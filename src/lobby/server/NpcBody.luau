--!strict
-- A crew figure on the Carrier: Roblox's default R15 avatar (Nova, 2026-11-11: "just make them
-- default r15 models and then we can just change clothing/attributes as needed on each"). Each
-- figure's look is a Dress: body colours (skin by name, shirt, trousers) and a list of Roblox
-- catalog items (layered clothing, hats, vests, glasses...), applied through the Humanoid's own
-- avatar description (Shared.AvatarLook). The rig is joined with rigid Motor6Ds and its root anchored where
-- the figure stands; desk figures breathe with Config.Lobby.Crew.Animations.Idle, walkers are
-- moved and animated on each client (CrewWalk). Nothing collides and no Humanoid is tagged
-- Enemy. Ship's company and Army staff wear working dress, never Pike grey (docs/LORE.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local AvatarLook = require(ReplicatedStorage.Shared.AvatarLook)
local Config = require(ReplicatedStorage.Shared.Config)

local NpcBody = {}

-- A figure's look. Colours are body colours (arms and head are skin, picked by the figure's
-- name; torso and legs show only where no clothing covers them); `items` are Roblox catalog
-- asset ids of any kind a body wears (AvatarLook sorts them into place).
export type Dress = {
	shirt: Color3,
	trousers: Color3,
	skin: Color3?, -- instead of the one picked by name
	items: { number }?,
}

NpcBody.Ship = {
	shirt = Color3.fromRGB(58, 70, 96),
	trousers = Color3.fromRGB(40, 44, 54),
} :: Dress
NpcBody.Army =
	{ shirt = Color3.fromRGB(92, 96, 70), trousers = Color3.fromRGB(78, 80, 60) } :: Dress
-- Lantern's crew chief (docs/LORE.md > Lantern): a green flight suit and a helmet with a comms
-- headset (picks F1 H6).
NpcBody.Aircrew = {
	shirt = Color3.fromRGB(110, 112, 90),
	trousers = Color3.fromRGB(110, 112, 90),
	items = { 105079389547650, 80718108109770 },
} :: Dress

-- Skin, picked by the figure's name so a figure looks the same every visit.
local SKINS = {
	Color3.fromRGB(176, 140, 112),
	Color3.fromRGB(141, 103, 76),
	Color3.fromRGB(214, 176, 146),
	Color3.fromRGB(102, 72, 52),
}

-- The R15 joints: name, the part nearer the root, the part it moves, the rig attachment
-- both carry (the stock rig's names, so the stock clips drive them).
local JOINTS: { { string } } = {
	{ "Root", "HumanoidRootPart", "LowerTorso", "RootRigAttachment" },
	{ "Waist", "LowerTorso", "UpperTorso", "WaistRigAttachment" },
	{ "Neck", "UpperTorso", "Head", "NeckRigAttachment" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", "LeftShoulderRigAttachment" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", "LeftElbowRigAttachment" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", "LeftWristRigAttachment" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", "RightShoulderRigAttachment" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", "RightElbowRigAttachment" },
	{ "RightWrist", "RightLowerArm", "RightHand", "RightWristRigAttachment" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", "LeftHipRigAttachment" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "LeftKneeRigAttachment" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", "LeftAnkleRigAttachment" },
	{ "RightHip", "LowerTorso", "RightUpperLeg", "RightHipRigAttachment" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", "RightKneeRigAttachment" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", "RightAnkleRigAttachment" },
}

-- Joins the limbs with rigid Motor6Ds from their rig attachments. Today's stock rig comes
-- with physics joints instead (AnimationConstraint + BallSocketConstraint per joint): those
-- leave every limb a separate body the server simulates, so a walker whose root only its
-- client moves had its limbs dragged after it and corrected over the network every frame
-- (the lag Nova saw, 2026-11-10). With Motor6Ds the whole figure is one anchored assembly:
-- no physics, the client moves it whole, and the clips drive the motors.
local function joint(model: Model)
	for _, thing in model:GetDescendants() do
		if
			thing:IsA("AnimationConstraint")
			or thing:IsA("BallSocketConstraint")
			or thing:IsA("NoCollisionConstraint")
		then
			thing:Destroy()
		end
	end
	for _, spec in JOINTS do
		local part0 = model:FindFirstChild(spec[2])
		local part1 = model:FindFirstChild(spec[3])
		local a0 = part0 and part0:FindFirstChild(spec[4])
		local a1 = part1 and part1:FindFirstChild(spec[4])
		if
			not (part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart"))
			or not (a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment"))
			or part1:FindFirstChild(spec[1])
		then
			continue
		end
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = a0.CFrame
		motor.C1 = a1.CFrame
		motor.Parent = part1
	end
end

-- One stock R15 rig, cloned for every figure (building one asks the avatar service).
local template: Model? = nil
local function rig(): Model?
	if not template then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R15
			)
		end)
		if not ok or typeof(result) ~= "Instance" then
			warn(`[NpcBody] no R15 rig: {result}`)
			return nil
		end
		local model = result :: Model
		for _, thing in model:GetDescendants() do
			if thing:IsA("LuaSourceContainer") then
				thing:Destroy()
			end
		end
		joint(model)
		template = model
	end
	return (template :: Model):Clone()
end

local function pick<T>(list: { T }, name: string, salt: number): T
	local hash = salt
	for i = 1, #name do
		hash = (hash * 31 + string.byte(name, i)) % 1000003
	end
	return list[hash % #list + 1]
end

-- Puts on the look, then breathes (`idle`). Applying a description can rebuild joints, so the
-- limbs are joined again after it.
local function finish(model: Model, dress: Dress, idle: boolean)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	AvatarLook.apply(humanoid, {
		items = dress.items,
		skin = dress.skin or pick(SKINS, model.Name, 7),
		shirt = dress.shirt,
		trousers = dress.trousers,
	})
	joint(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
		end
	end
	model:SetAttribute(Attributes.CrewReady, true)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if idle and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.Lobby.Crew.Animations.Idle
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play(0)
		-- Not all in step.
		track.TimePosition = (#model.Name % 10) / 10 * math.max(track.Length, 1)
	end
end

-- Builds the figure standing at `feet`, facing `facing` (flat). Returns the model and its
-- root (prompts and signs hang off the root, at chest height). The look goes on a moment
-- later; `idle` false leaves its animation to the client (walkers).
function NpcBody.build(
	parent: Instance,
	name: string,
	feet: Vector3,
	facing: Vector3,
	dress: Dress,
	idle: boolean?
): (Model, BasePart)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local model = rig()
	if not model then
		-- No avatar service: an invisible stand-in keeps the prompt and the sign working.
		local stand = Instance.new("Model")
		stand.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Transparency = 1
		root.CanCollide = false
		root.Size = Vector3.new(2, 2, 1)
		local chest = feet + Vector3.new(0, 3.2, 0)
		root.CFrame = CFrame.lookAt(chest, chest + flat)
		root.Parent = stand
		stand.PrimaryPart = root
		stand.Parent = parent
		return stand, root
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	-- A figure only plays clips: no falling, climbing or getting up to work out every frame.
	humanoid.EvaluateStateMachine = false
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	root.CanCollide = false
	local chest = feet + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	model:PivotTo(CFrame.lookAt(chest, chest + flat))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	model.PrimaryPart = root
	model.Parent = parent
	task.spawn(finish, model, dress, idle ~= false)
	return model, root
end

return NpcBody
