--!strict
-- The binoculars on a body, for everyone to see (docs/PROGRESSION.md > Binoculars). The
-- server marks a squad body (a player's or a bot's) with the Spotting attribute while its
-- binoculars are up (CallInService); each client then raises that body's arms and brings a
-- pair of binoculars up to its eyes, holds them, and lowers them when the attribute goes.
-- PLACEHOLDER, both of them: there is no authored clip yet, so the arms are posed here on
-- top of whatever clip is playing (Motor6D.Transform written after the Animator each
-- frame; angles in Config.CallIns.Binoculars.Pose), and the binoculars are a few Parts
-- built in code. The held gun is hidden on that body while they are up (slung). A real
-- raise / hold / lower clip in Config.Animations and a modelled prop replace this file's
-- pose and `buildProp`.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Spotting = require(Shared:WaitForChild("Rules"):WaitForChild("Spotting"))

local BOT_TAG = "SquadBot"
local BODY = Color3.fromRGB(48, 53, 59) -- polymer (docs/STYLES.md section 2)
local LENS = Color3.fromRGB(99, 109, 119) -- steel
local CARRIED = CFrame.new(0, -1.3, -0.7) -- where the prop starts and ends: at the chest
local GUN_HIDDEN_FROM = 0.3 -- how far up before the gun is out of the hands

type Arm = { shoulder: Motor6D?, elbow: Motor6D?, side: number } -- side: 1 right, -1 left
type Body = {
	character: Model,
	alpha: number, -- 0 down, 1 at the eyes
	prop: Model?,
	weld: Weld?,
	arms: { Arm },
	gunHidden: boolean,
}

local BinocularPose = {}

local bodies: { [Model]: Body } = {}

local function propPart(parent: Model, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = parent
	return part
end

-- A pair of binoculars from Parts: a bridge (the root, at the eyes' height), two barrels
-- pointing ahead (-Z) and their lenses. About 0.9 wide and 0.7 long.
local function buildProp(): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "Binoculars"
	local bridge = propPart(model, "Bridge", Vector3.new(0.3, 0.14, 0.3), BODY)
	model.PrimaryPart = bridge
	for _, side in { -1, 1 } do
		local barrel = propPart(model, "Barrel", Vector3.new(0.7, 0.3, 0.3), BODY)
		barrel.Shape = Enum.PartType.Cylinder
		local lens = propPart(model, "Lens", Vector3.new(0.04, 0.26, 0.26), LENS)
		lens.Shape = Enum.PartType.Cylinder
		lens.Material = Enum.Material.Glass
		-- A cylinder's axis is its X: turn it to lie along Z.
		local along = CFrame.new(side * 0.24, 0, -0.1) * CFrame.Angles(0, math.rad(90), 0)
		for _, piece in { barrel, lens } do
			local weld = Instance.new("Weld")
			weld.Part0 = bridge
			weld.Part1 = piece
			weld.C0 = if piece == lens then along * CFrame.new(0.36, 0, 0) else along
			weld.Parent = piece
		end
	end
	return model, bridge
end

-- The joint that carries `partName` (the Motor6D inside it).
local function jointOf(character: Model, partName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	return if part then part:FindFirstChildOfClass("Motor6D") else nil
end

local function newBody(character: Model): Body
	local body: Body = {
		character = character,
		alpha = 0,
		prop = nil,
		weld = nil,
		arms = {
			{
				shoulder = jointOf(character, "RightUpperArm"),
				elbow = jointOf(character, "RightLowerArm"),
				side = 1,
			},
			{
				shoulder = jointOf(character, "LeftUpperArm"),
				elbow = jointOf(character, "LeftLowerArm"),
				side = -1,
			},
		},
		gunHidden = false,
	}
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local prop, bridge = buildProp()
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = bridge
		weld.C0 = CARRIED
		weld.Parent = bridge
		prop.Parent = character
		body.prop, body.weld = prop, weld
	end
	return body
end

-- Hides or shows the gun in the body's hands, on this client only. Our own body's parts are
-- the camera's to hide (CameraController: the eye is on the Head whenever ours are up).
local function setGunHidden(body: Body, hidden: boolean)
	if body.gunHidden == hidden then
		return
	end
	body.gunHidden = hidden
	if body.character == Players.LocalPlayer.Character then
		return
	end
	local tool = body.character:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function release(body: Body)
	setGunHidden(body, false)
	if body.prop then
		body.prop:Destroy()
	end
	bodies[body.character] = nil
end

-- The pose `eased` of the way up, laid over this frame's clip.
local function pose(body: Body, eased: number)
	local angles = Config.CallIns.Binoculars.Pose
	local bend = CFrame.Angles(math.rad(angles.Bend), 0, 0)
	for _, arm in body.arms do
		local shoulder, elbow = arm.shoulder, arm.elbow
		if shoulder then
			-- Up and forward, then rolled about the arm so the forearm folds in to the face.
			local raise = CFrame.Angles(math.rad(angles.Raise), math.rad(angles.Roll) * arm.side, 0)
			shoulder.Transform = shoulder.Transform:Lerp(raise, eased)
		end
		if elbow then
			elbow.Transform = elbow.Transform:Lerp(bend, eased)
		end
	end
	local weld = body.weld
	if weld then
		weld.C0 = CARRIED:Lerp(Config.CallIns.Binoculars.PropOffset, eased)
	end
end

local function update(character: Model?, dt: number)
	if not character then
		return
	end
	local raised = character:GetAttribute(Attributes.Spotting) == true
	local body = bodies[character]
	if not body then
		if not raised then
			return
		end
		body = newBody(character)
		bodies[character] = body
	end
	local settings = Config.CallIns.Binoculars
	body.alpha = Spotting.blend(body.alpha, raised, dt, settings.Raise, settings.Lower)
	if body.alpha <= 0 and not raised then
		release(body)
		return
	end
	-- Smoothstep: the hands leave and arrive gently.
	local eased = body.alpha * body.alpha * (3 - 2 * body.alpha)
	pose(body, eased)
	setGunHidden(body, body.alpha >= GUN_HIDDEN_FROM)
end

-- After the Animator has written this frame's clip (Stepped), so the pose sits on top.
local function step(_time: number, dt: number)
	for character, body in bodies do
		if not character.Parent then
			release(body)
		end
	end
	for _, player in Players:GetPlayers() do
		update(player.Character, dt)
	end
	for _, bot in CollectionService:GetTagged(BOT_TAG) do
		if bot:IsA("Model") then
			update(bot, dt)
		end
	end
end

function BinocularPose.init()
	RunService.Stepped:Connect(step)
end

return BinocularPose
