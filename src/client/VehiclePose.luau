--!strict
-- How a soldier sits on a vehicle, for everyone to see (docs/PROGRESSION.md > The ATV). The
-- match's clips have no seated pose, so a rider kept standing with the gun up (Nova
-- 2026-11-17). Every client lays a pose over each riding player's clip after the Animator
-- (Motor6D.Transform on Stepped, as BinocularPose does), angles from the vehicle row's
-- `Pose` (Config.CallIns.<Key>.Vehicle.Pose):
--   * both seats: hips and knees bent, sitting;
--   * the driver: both arms forward onto the handlebars, the gun hidden (put away);
--   * the back seat keeps its arms on the gun (it shoots).
-- Bots get the stock sit clip from the server (BotService) instead. PLACEHOLDER until an
-- authored riding clip exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))

local VehiclePose = {}

-- Characters whose gun this client hid (shown again when they get off).
local gunHidden: { [Model]: boolean? } = setmetatable({}, { __mode = "k" }) :: any

local function joint(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function setGunHidden(character: Model, hidden: boolean)
	if (gunHidden[character] == true) == hidden then
		return
	end
	gunHidden[character] = if hidden then true else nil
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- The Pose of the vehicle `character` sits in, or nil.
local function poseOf(character: Model): any
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	local id = model and model:GetAttribute(Attributes.VehicleId)
	local definition = if typeof(id) == "string" then CallInDefinitions.get(id) else nil
	local row = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	return row and row.Vehicle and row.Vehicle.Pose
end

local function pose(character: Model, seat: string)
	local angles = poseOf(character)
	if not angles then
		return
	end
	local hip = CFrame.Angles(math.rad(angles.Hip), 0, 0)
	local knee = CFrame.Angles(-math.rad(angles.Knee), 0, 0)
	for _, side in { "Left", "Right" } do
		local hipJoint = joint(character, side .. "UpperLeg", side .. "Hip")
		local kneeJoint = joint(character, side .. "LowerLeg", side .. "Knee")
		if hipJoint then
			hipJoint.Transform = hip
		end
		if kneeJoint then
			kneeJoint.Transform = knee
		end
	end
	if seat ~= "driver" then
		return
	end
	-- Hands on the bars: upper arms forward, turned in a little, forearms on toward the grips.
	local elbow = CFrame.Angles(math.rad(angles.ElbowBend), 0, 0)
	for _, arm in { { name = "Right", side = 1 }, { name = "Left", side = -1 } } do
		local shoulder = joint(character, arm.name .. "UpperArm", arm.name .. "Shoulder")
		local elbowJoint = joint(character, arm.name .. "LowerArm", arm.name .. "Elbow")
		local wrist = joint(character, arm.name .. "Hand", arm.name .. "Wrist")
		if shoulder then
			shoulder.Transform =
				CFrame.Angles(math.rad(angles.ArmRaise), math.rad(angles.ArmIn) * arm.side, 0)
		end
		if elbowJoint then
			elbowJoint.Transform = elbow
		end
		if wrist then
			wrist.Transform = CFrame.identity
		end
	end
end

-- After the Animator has written this frame's clips, so the pose sits on top.
local function step()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local seat = character:GetAttribute(Attributes.Riding)
			if typeof(seat) == "string" then
				pose(character, seat)
				setGunHidden(character, seat == "driver")
			elseif gunHidden[character] then
				setGunHidden(character, false)
			end
		end
	end
end

function VehiclePose.init()
	RunService.Stepped:Connect(step)
end

return VehiclePose
