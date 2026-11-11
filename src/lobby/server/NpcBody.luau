--!strict
-- A crew figure for the Fallow (Nova, 2026-11-10: "all the npcs to have r15 models like the
-- player instead of just being regular blocks"): a real R15 rig (Humanoid, Animator, Motor6Ds)
-- wearing the crew body (`npc_crew_` limbs, assets/3d/build/crew.py, the same limb boxes and
-- joints as the player's Pike body), untextured and coloured per figure: shirt, trousers,
-- skin, boots. The face, hair and headgear are meshes built around the head's own origin
-- (crew.py npc_gear_*, 2026-11-11: the block eyes "dont look right"), coloured per figure; a
-- belt and the lore's hand-held kit are small parts. All welded to the limbs, so they move with
-- the animation. The root is anchored where the figure stands; it
-- breathes with the stock R15 idle (`Config.Lobby.Crew.Animations`), and walkers are moved and
-- animated on each client (CrewWalk). Nothing collides and no Humanoid is tagged Enemy.
-- Ship's company and Army staff wear working dress, never Pike grey (docs/LORE.md > The Fallow).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local NpcBody = {}

local BODY = "npc_crew_"

export type Dress = {
	shirt: Color3,
	trousers: Color3,
	cover: Color3?, -- a cap, if any
	helmet: Color3?, -- a flight helmet with its visor down, if any (instead of a cap)
}

NpcBody.Ship = {
	shirt = Color3.fromRGB(58, 70, 96),
	trousers = Color3.fromRGB(40, 44, 54),
	cover = Color3.fromRGB(36, 40, 50),
} :: Dress
NpcBody.Army =
	{ shirt = Color3.fromRGB(92, 96, 70), trousers = Color3.fromRGB(78, 80, 60) } :: Dress
-- Lantern's crew chief (docs/LORE.md > Lantern): a sage flight suit, helmet, visor down.
NpcBody.Aircrew = {
	shirt = Color3.fromRGB(110, 112, 90),
	trousers = Color3.fromRGB(110, 112, 90),
	helmet = Color3.fromRGB(48, 53, 59),
} :: Dress

-- Skin and hair, picked by the figure's name so a figure looks the same every visit.
local SKINS = {
	Color3.fromRGB(176, 140, 112),
	Color3.fromRGB(141, 103, 76),
	Color3.fromRGB(214, 176, 146),
	Color3.fromRGB(102, 72, 52),
}
local HAIRS = {
	Color3.fromRGB(40, 32, 26),
	Color3.fromRGB(78, 56, 36),
	Color3.fromRGB(26, 24, 24),
	Color3.fromRGB(120, 116, 110), -- grey
}
local BOOT = Color3.fromRGB(30, 30, 32)
local BLACK = Color3.fromRGB(26, 26, 28)
local STEEL = Color3.fromRGB(150, 154, 158)
local WEBBING = Color3.fromRGB(44, 46, 40)
local BRASS = Color3.fromRGB(176, 146, 70)

-- What a figure carries or wears beyond its dress (Nova, 2026-11-10: "give them personality";
-- the details are the lore developer's, docs/lore/desk_crew.md and ship_company.md). Each
-- piece hangs on one limb, in that limb's own space: the R15 limb centre (the crew body's
-- design origin, before MeshAssets' bounds offset), +X the figure's right, +Y up, -Z its
-- front. Head front face at Z -0.56, top at Y 0.59; upper torso front at Z -0.5, its top
-- (the neck) at Y 0.85; a hand's outer face at X ±0.41.
export type Kit = { string }

type Wear = (
	limb: string,
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3,
	turn: CFrame?
) -> BasePart
-- A crew gear mesh (`npc_gear_<name>`) on the head, where it was designed; `turn` moves it
-- in the head's space first (a visor raised about its hinge).
type WearMesh = (name: string, color: Color3, turn: CFrame?) -> BasePart?

local FACE = Color3.fromRGB(34, 26, 24) -- eyes and mouth
local VISOR = Color3.fromRGB(90, 100, 110)
-- Hair styles, picked by name; under any headgear the hair is clipped close (it would show
-- through the sides of a cap or helmet). The kit item "bun" asks for the bun.
local HAIR_STYLES = { "crop", "parted", "buzz", "crop" }
local HEADGEAR: { [string]: boolean } =
	{ visorUp = true, earDefenders = true, helmet = true, headsetOneEar = true }
-- The flight helmet's visor hinge, in the head's space (crew.py helmet_flight's housing).
local VISOR_HINGE = Vector3.new(0, 0.66, -0.64)

-- Gloves are the hands' own colour, not parts.
local GLOVES: { [string]: Color3 } = {
	gloves = BLACK,
	blueGloves = Color3.fromRGB(70, 120, 200),
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local KIT: { [string]: (wear: Wear, wearMesh: WearMesh) -> () } = {
	-- The Quartermaster: reading glasses, a clipboard, keys.
	glasses = function(_, wearMesh)
		wearMesh("glasses", BLACK)
	end,
	-- Fires wears her hair tied back (finish reads it; nothing to add here).
	bun = function() end,
	clipboard = function(wear)
		wear(
			"RightHand",
			"Clipboard",
			v(0.08, 1.1, 0.8),
			v(0.47, -0.3, 0),
			Color3.fromRGB(120, 90, 56)
		)
		wear(
			"RightHand",
			"ClipboardPaper",
			v(0.02, 0.9, 0.66),
			v(0.52, -0.32, 0),
			Color3.fromRGB(232, 228, 214)
		)
		wear("RightHand", "ClipboardClip", v(0.06, 0.12, 0.3), v(0.53, 0.2, 0), STEEL)
	end,
	keyring = function(wear)
		wear("LowerTorso", "KeyRing", v(0.06, 0.4, 0.3), v(1.02, -0.12, -0.25), STEEL)
	end,
	-- Fires: a headset round her neck, a notebook.
	headsetNeck = function(wear)
		wear("UpperTorso", "HeadsetBand", v(1.1, 0.1, 0.12), v(0, 0.84, 0.3), BLACK)
		for _, x in { -0.5, 0.5 } do
			wear("UpperTorso", "HeadsetCup", v(0.26, 0.42, 0.42), v(x, 0.82, -0.18), BLACK)
		end
		wear("UpperTorso", "HeadsetCord", v(0.05, 1.0, 0.05), v(-0.42, 0.2, -0.54), BLACK)
	end,
	notebook = function(wear)
		wear(
			"LeftHand",
			"Notebook",
			v(0.1, 0.75, 0.56),
			v(-0.47, -0.3, 0),
			Color3.fromRGB(46, 66, 50)
		)
	end,
	-- The watch officer: a headset with one earcup on, a steel mug, a rank tab.
	headsetOneEar = function(_, wearMesh)
		wearMesh("headset_one_ear", BLACK)
	end,
	mug = function(wear)
		local mug: Part = wear(
			"RightHand",
			"Mug",
			v(0.5, 0.44, 0.44),
			v(0, -0.1, -0.5),
			STEEL,
			CFrame.Angles(0, 0, math.pi / 2)
		) :: any
		mug.Shape = Enum.PartType.Cylinder
	end,
	rankTab = function(wear)
		wear("UpperTorso", "RankTab", v(0.3, 0.42, 0.05), v(0, 0.2, -0.58), WEBBING)
		wear(
			"UpperTorso",
			"RankMark",
			v(0.2, 0.07, 0.05),
			v(0, 0.3, -0.6),
			Color3.fromRGB(200, 170, 80)
		)
	end,
	-- The Engineers' sergeant: gloves in his belt, wire cutters, a coil of wire on his shoulder.
	beltGloves = function(wear)
		wear(
			"LowerTorso",
			"BeltGloves",
			v(0.36, 0.55, 0.1),
			v(0.55, -0.2, -0.56),
			Color3.fromRGB(150, 120, 80)
		)
	end,
	cutters = function(wear)
		wear(
			"LowerTorso",
			"Cutters",
			v(0.16, 0.7, 0.16),
			v(1.04, -0.25, 0),
			Color3.fromRGB(170, 40, 34)
		)
	end,
	wireCoil = function(wear)
		local coil: Part = wear(
			"UpperTorso",
			"WireCoil",
			v(0.28, 1.4, 1.4),
			v(-0.6, 0.55, 0.25),
			STEEL,
			CFrame.Angles(0, 0, math.rad(60))
		) :: any
		coil.Shape = Enum.PartType.Cylinder
	end,
	-- The Loadmaster: flight helmet pushed up with the visor up, a monkey harness and tether, a
	-- grease pencil.
	visorUp = function(_, wearMesh)
		wearMesh("helmet_flight", Color3.fromRGB(48, 53, 59))
		local up = CFrame.new(VISOR_HINGE)
			* CFrame.Angles(math.rad(75), 0, 0)
			* CFrame.new(-VISOR_HINGE)
		local visor = wearMesh("visor", VISOR, up)
		if visor then
			visor.Material = Enum.Material.Glass
		end
	end,
	harness = function(wear)
		for _, lean in { 28, -28 } do
			wear(
				"UpperTorso",
				"Harness",
				v(0.24, 1.8, 0.06),
				v(0, 0, -0.56),
				WEBBING,
				CFrame.Angles(0, 0, math.rad(lean))
			)
		end
		wear("LowerTorso", "HarnessBelt", v(2.05, 0.3, 1.06), v(0, 0.02, 0), WEBBING)
		wear(
			"LowerTorso",
			"Tether",
			v(0.12, 1.3, 0.12),
			v(0.5, -0.6, 0.56),
			Color3.fromRGB(214, 170, 40)
		)
	end,
	greasePencil = function(wear)
		wear(
			"UpperTorso",
			"GreasePencil",
			v(0.07, 0.5, 0.07),
			v(0.4, 0.42, -0.58),
			Color3.fromRGB(214, 170, 40)
		)
	end,
	-- Aircrew and medics: gloved hands (GLOVES colours the hands); the medic's mask.
	gloves = function() end,
	blueGloves = function() end,
	mask = function(wear)
		wear("Head", "Mask", v(0.8, 0.42, 0.06), v(0, -0.2, -0.62), Color3.fromRGB(226, 232, 230))
	end,
	-- Flight deck crew: ear defenders over the cloth helmet; chocks and chains; a rag.
	earDefenders = function(_, wearMesh)
		wearMesh("ear_defenders", Color3.fromRGB(200, 60, 40))
	end,
	chocks = function(wear)
		wear(
			"RightHand",
			"Chock",
			v(0.55, 0.45, 1.0),
			v(0, -0.4, -0.1),
			Color3.fromRGB(214, 176, 40)
		)
		wear(
			"UpperTorso",
			"Chain",
			v(0.16, 2.0, 0.08),
			v(0, 0, -0.56),
			STEEL,
			CFrame.Angles(0, 0, math.rad(-35))
		)
	end,
	rag = function(wear)
		wear(
			"LowerTorso",
			"Rag",
			v(0.4, 0.6, 0.06),
			v(0.45, -0.3, 0.54),
			Color3.fromRGB(170, 46, 38)
		)
	end,
	-- The lane sentry: helmet, a slung rifle, a white MP brassard.
	helmet = function(_, wearMesh)
		wearMesh("helmet_combat", Color3.fromRGB(66, 70, 52))
	end,
	slungRifle = function(wear)
		wear(
			"UpperTorso",
			"SlungRifle",
			v(0.25, 3.0, 0.35),
			v(0, -0.1, 0.72),
			BLACK,
			CFrame.Angles(0, 0, math.rad(35))
		)
		wear(
			"UpperTorso",
			"Sling",
			v(0.12, 2.0, 0.06),
			v(0, 0, -0.56),
			WEBBING,
			CFrame.Angles(0, 0, math.rad(-35))
		)
	end,
	brassard = function(wear)
		wear(
			"LeftUpperArm",
			"Brassard",
			v(1.08, 0.4, 1.08),
			v(0, -0.1, 0),
			Color3.fromRGB(232, 232, 228)
		)
	end,
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
			if
				thing:IsA("LuaSourceContainer")
				or thing:IsA("Accoutrement")
				or thing:IsA("Clothing")
				or thing:IsA("Decal")
				or thing:IsA("WrapTarget")
			then
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

-- Each limb's colour from the dress (gloves and boots aside).
local function limbColor(partName: string, dress: Dress, skin: Color3, hands: Color3): Color3?
	if partName == "Head" then
		return skin
	elseif string.find(partName, "Hand") then
		return hands
	elseif string.find(partName, "Foot") then
		return BOOT
	elseif partName == "UpperTorso" or string.find(partName, "Arm") then
		return dress.shirt
	elseif partName == "LowerTorso" or string.find(partName, "Leg") then
		return dress.trousers
	end
	return nil
end

-- The limb's design origin (the R15 limb centre), whatever body it wears.
local function origin(part: BasePart, dressed: boolean): CFrame
	local limb = MeshAssets.limbOf(part.Name)
	if not (dressed and limb) then
		return part.CFrame
	end
	local offset = MeshAssets.offsetOf(BODY .. limb) or Vector3.zero
	return part.CFrame * CFrame.new(-offset)
end

-- Dresses, colours and kits the rig (once the crew meshes load, else on the stock body).
local function finish(model: Model, dress: Dress, kit: Kit?, idle: boolean)
	local dressed = MeshAssets.waitFor(BODY .. "head", Config.Lobby.Ship.TemplateWait) ~= nil
		and MeshAssets.dressModel(model, BODY)
	-- dressModel's joint rebuild runs a step later and clears any joint made before it: let it
	-- pass, join the limbs, and check once more in case it ran late.
	task.wait(0.2)
	joint(model)
	task.delay(1, function()
		local waist = model:FindFirstChild("Waist", true)
		if model.Parent and not (waist and waist:IsA("Motor6D")) then
			joint(model)
		end
	end)
	local name = model.Name
	local skin = pick(SKINS, name, 7)
	local hair = pick(HAIRS, name, 13)
	local hands = skin
	for _, item in (kit or {}) :: Kit do
		hands = GLOVES[item] or hands
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CastShadow = false
			local color = limbColor(part.Name, dress, skin, hands)
			if color then
				part.Color = color
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	local function wear(
		limbName: string,
		partName: string,
		size: Vector3,
		at: Vector3,
		color: Color3,
		turn: CFrame?
	): BasePart
		local limb = model:FindFirstChild(limbName) :: BasePart
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.CFrame = origin(limb, dressed) * CFrame.new(at) * (turn or CFrame.identity)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	local head = model:FindFirstChild("Head")
	local function wearMesh(gear: string, color: Color3, turn: CFrame?): BasePart?
		local meshName = "npc_gear_" .. gear
		local part = MeshAssets.clone(meshName)
		if not (part and head and head:IsA("BasePart")) then
			return nil
		end
		part.Name = gear
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.CFrame = origin(head, dressed)
			* (turn or CFrame.identity)
			* CFrame.new(MeshAssets.getOffset(meshName))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	-- The face, hair and belt everyone has; hair clipped close under any headgear.
	local covered = dress.cover ~= nil or dress.helmet ~= nil
	local bun = false
	for _, item in (kit or {}) :: Kit do
		covered = covered or HEADGEAR[item] == true
		bun = bun or item == "bun"
	end
	local style = if covered then "buzz" elseif bun then "bun" else pick(HAIR_STYLES, name, 5)
	wearMesh("face", FACE)
	wearMesh("hair_" .. style, hair)
	wear("LowerTorso", "Belt", v(2.03, 0.16, 1.04), v(0, 0.06, 0), BLACK)
	wear("LowerTorso", "Buckle", v(0.3, 0.16, 0.06), v(0, 0.06, -0.53), BRASS)
	if dress.cover then
		wearMesh("cap", dress.cover)
	end
	if dress.helmet then
		wearMesh("helmet_flight", dress.helmet)
		local visor = wearMesh("visor", VISOR)
		if visor then
			visor.Material = Enum.Material.Glass
		end
	end
	for _, item in (kit or {}) :: Kit do
		local add = KIT[item]
		if add then
			add(wear, wearMesh)
		else
			warn(`[NpcBody] no kit item "{item}"`)
		end
	end

	model:SetAttribute(Attributes.CrewReady, true)
	-- Breathing: the stock R15 idle (walkers are animated by each client instead).
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if idle and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.Lobby.Crew.Animations.Idle
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play(0)
		-- Not all in step.
		track.TimePosition = (#name % 10) / 10 * math.max(track.Length, 1)
	end
end

-- Builds the figure standing at `feet`, facing `facing` (flat). Returns the model and its
-- root (prompts and signs hang off the root, at chest height). The body dresses itself once
-- the crew meshes load; `idle` false leaves its animation to the client (walkers).
function NpcBody.build(
	parent: Instance,
	name: string,
	feet: Vector3,
	facing: Vector3,
	dress: Dress,
	kit: Kit?,
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
	task.spawn(finish, model, dress, kit, idle ~= false)
	return model, root
end

return NpcBody
