--!strict
-- A standing crew figure for the Fallow: anchored blocks, no Humanoid (nothing to path or
-- animate, nothing tagged Enemy). Ship's company and Army staff wear working dress, never Pike
-- grey (docs/LORE.md > The Fallow). The art director's desk NPC sheet replaces the blocks.

local Build = require(script.Parent.Build)

local NpcBody = {}

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

local SKIN = Color3.fromRGB(176, 140, 112)

-- What a figure carries or wears beyond its dress (Nova, 2026-11-10: "give them personality";
-- the details are the lore developer's, docs/lore/desk_crew.md and ship_company.md). Plain
-- blocks hung on the body, built in the figure's own space: -Z is the front, +X its right,
-- feet at 0. A part on an arm is named "LeftArm_..." / "RightArm_..." so CrewWalk swings it
-- with the arm.
export type Kit = { string }

type Limb = (name: string, size: Vector3, offset: Vector3, color: Color3, turn: CFrame?) -> BasePart

local BLACK = Color3.fromRGB(26, 26, 28)
local STEEL = Color3.fromRGB(150, 154, 158)
local WEBBING = Color3.fromRGB(44, 46, 40)

local KIT: { [string]: (limb: Limb) -> () } = {
	-- The Quartermaster: glasses on a cord, a clipboard, a key ring.
	glasses = function(limb)
		limb("Glasses", Vector3.new(0.95, 0.16, 0.06), Vector3.new(0, 5.0, -0.58), BLACK)
		limb("GlassesCord", Vector3.new(0.05, 0.9, 0.05), Vector3.new(0.45, 4.4, -0.57), BLACK)
	end,
	clipboard = function(limb)
		limb(
			"RightArm_Clipboard",
			Vector3.new(0.1, 1.2, 0.9),
			Vector3.new(1.85, 2.6, -0.3),
			Color3.fromRGB(120, 90, 56)
		)
		limb(
			"RightArm_Paper",
			Vector3.new(0.02, 0.95, 0.75),
			Vector3.new(1.91, 2.6, -0.3),
			Color3.fromRGB(232, 228, 214)
		)
	end,
	keyring = function(limb)
		limb("KeyRing", Vector3.new(0.3, 0.45, 0.08), Vector3.new(-0.75, 2.2, -0.58), STEEL)
	end,
	-- Fires: a headset round her neck, a notebook.
	headsetNeck = function(limb)
		limb("HeadsetBand", Vector3.new(1.3, 0.14, 1.2), Vector3.new(0, 4.28, 0.05), BLACK)
		limb("HeadsetCup", Vector3.new(0.3, 0.45, 0.45), Vector3.new(-0.6, 4.2, -0.3), BLACK)
		limb("HeadsetCup", Vector3.new(0.3, 0.45, 0.45), Vector3.new(0.6, 4.2, -0.3), BLACK)
		limb("HeadsetCord", Vector3.new(0.06, 1.3, 0.06), Vector3.new(-0.55, 3.4, -0.58), BLACK)
	end,
	notebook = function(limb)
		limb(
			"LeftArm_Notebook",
			Vector3.new(0.12, 0.85, 0.65),
			Vector3.new(-1.85, 2.5, -0.3),
			Color3.fromRGB(46, 66, 50)
		)
	end,
	-- The watch officer: a headset with one earcup on, a steel mug, a rank tab.
	headsetOneEar = function(limb)
		limb("HeadsetBand", Vector3.new(1.25, 0.12, 0.25), Vector3.new(0, 5.5, 0), BLACK)
		limb("HeadsetCup", Vector3.new(0.25, 0.55, 0.55), Vector3.new(-0.65, 4.9, 0), BLACK)
		limb("HeadsetCup", Vector3.new(0.25, 0.5, 0.5), Vector3.new(0.66, 5.05, 0.35), BLACK)
		limb("HeadsetMic", Vector3.new(0.06, 0.06, 0.6), Vector3.new(-0.6, 4.6, -0.45), BLACK)
	end,
	mug = function(limb)
		local round: Part = limb(
			"RightArm_Mug",
			Vector3.new(0.55, 0.5, 0.5),
			Vector3.new(1.4, 1.95, -0.55),
			STEEL,
			CFrame.Angles(0, 0, math.pi / 2)
		) :: any
		round.Shape = Enum.PartType.Cylinder
	end,
	rankTab = function(limb)
		limb("RankTab", Vector3.new(0.35, 0.5, 0.05), Vector3.new(0, 3.65, -0.58), WEBBING)
		limb(
			"RankMark",
			Vector3.new(0.2, 0.08, 0.05),
			Vector3.new(0, 3.75, -0.6),
			Color3.fromRGB(200, 170, 80)
		)
	end,
	-- The Engineers' sergeant: gloves in his belt, wire cutters, a coil of wire on his shoulder.
	beltGloves = function(limb)
		limb(
			"BeltGloves",
			Vector3.new(0.4, 0.6, 0.12),
			Vector3.new(0.7, 2.0, -0.6),
			Color3.fromRGB(150, 120, 80)
		)
	end,
	cutters = function(limb)
		limb(
			"Cutters",
			Vector3.new(0.18, 0.75, 0.18),
			Vector3.new(1.08, 2.15, -0.25),
			Color3.fromRGB(170, 40, 34)
		)
	end,
	wireCoil = function(limb)
		local round: Part = limb(
			"WireCoil",
			Vector3.new(0.3, 1.5, 1.5),
			Vector3.new(-0.55, 3.6, 0.3),
			STEEL,
			CFrame.Angles(0, 0, math.rad(60))
		) :: any
		round.Shape = Enum.PartType.Cylinder
	end,
	-- The Loadmaster: flight helmet pushed up with the visor up, a monkey harness and tether, a
	-- grease pencil.
	visorUp = function(limb)
		limb(
			"Helmet",
			Vector3.new(1.3, 0.75, 1.35),
			Vector3.new(0, 5.4, 0.12),
			Color3.fromRGB(48, 53, 59)
		)
		limb(
			"Visor",
			Vector3.new(1.0, 0.4, 0.1),
			Vector3.new(0, 5.65, -0.55),
			Color3.fromRGB(154, 164, 174),
			CFrame.Angles(math.rad(-30), 0, 0)
		)
	end,
	harness = function(limb)
		limb(
			"Harness",
			Vector3.new(0.28, 2.3, 0.06),
			Vector3.new(0, 3.2, -0.58),
			WEBBING,
			CFrame.Angles(0, 0, math.rad(28))
		)
		limb(
			"Harness",
			Vector3.new(0.28, 2.3, 0.06),
			Vector3.new(0, 3.2, -0.58),
			WEBBING,
			CFrame.Angles(0, 0, math.rad(-28))
		)
		limb("HarnessBelt", Vector3.new(2.05, 0.3, 1.15), Vector3.new(0, 2.35, 0), WEBBING)
		limb(
			"Tether",
			Vector3.new(0.12, 1.4, 0.12),
			Vector3.new(0.5, 1.75, 0.62),
			Color3.fromRGB(214, 170, 40)
		)
	end,
	greasePencil = function(limb)
		limb(
			"GreasePencil",
			Vector3.new(0.08, 0.55, 0.08),
			Vector3.new(0.55, 3.85, -0.6),
			Color3.fromRGB(214, 170, 40)
		)
	end,
	-- Aircrew and medics: gloved hands.
	gloves = function(limb)
		limb("LeftArm_Glove", Vector3.new(0.85, 0.45, 0.85), Vector3.new(-1.4, 2.35, 0), BLACK)
		limb("RightArm_Glove", Vector3.new(0.85, 0.45, 0.85), Vector3.new(1.4, 2.35, 0), BLACK)
	end,
	blueGloves = function(limb)
		limb(
			"LeftArm_Glove",
			Vector3.new(0.85, 0.45, 0.85),
			Vector3.new(-1.4, 2.35, 0),
			Color3.fromRGB(70, 120, 200)
		)
		limb(
			"RightArm_Glove",
			Vector3.new(0.85, 0.45, 0.85),
			Vector3.new(1.4, 2.35, 0),
			Color3.fromRGB(70, 120, 200)
		)
	end,
	mask = function(limb)
		limb(
			"Mask",
			Vector3.new(0.85, 0.45, 0.06),
			Vector3.new(0, 4.62, -0.58),
			Color3.fromRGB(226, 232, 230)
		)
	end,
	-- Flight deck crew: ear defenders over the cloth helmet; chocks and chains; a rag.
	earDefenders = function(limb)
		limb(
			"EarCup",
			Vector3.new(0.3, 0.6, 0.6),
			Vector3.new(-0.66, 4.9, 0),
			Color3.fromRGB(200, 60, 40)
		)
		limb(
			"EarCup",
			Vector3.new(0.3, 0.6, 0.6),
			Vector3.new(0.66, 4.9, 0),
			Color3.fromRGB(200, 60, 40)
		)
	end,
	chocks = function(limb)
		limb(
			"RightArm_Chock",
			Vector3.new(0.6, 0.5, 1.1),
			Vector3.new(1.4, 1.95, -0.3),
			Color3.fromRGB(214, 176, 40)
		)
		limb(
			"Chain",
			Vector3.new(0.18, 2.4, 0.1),
			Vector3.new(0, 3.2, -0.6),
			STEEL,
			CFrame.Angles(0, 0, math.rad(-35))
		)
	end,
	rag = function(limb)
		limb(
			"Rag",
			Vector3.new(0.45, 0.65, 0.06),
			Vector3.new(0.5, 2.0, 0.6),
			Color3.fromRGB(170, 46, 38)
		)
	end,
	-- The lane sentry: helmet, a slung rifle, a white MP brassard.
	helmet = function(limb)
		limb(
			"CombatHelmet",
			Vector3.new(1.35, 0.6, 1.4),
			Vector3.new(0, 5.6, 0.02),
			Color3.fromRGB(66, 70, 52)
		)
	end,
	slungRifle = function(limb)
		limb(
			"SlungRifle",
			Vector3.new(0.25, 3.2, 0.35),
			Vector3.new(0, 3.2, 0.75),
			BLACK,
			CFrame.Angles(0, 0, math.rad(35))
		)
		limb(
			"Sling",
			Vector3.new(0.12, 2.5, 0.06),
			Vector3.new(0, 3.3, -0.58),
			WEBBING,
			CFrame.Angles(0, 0, math.rad(-35))
		)
	end,
	brassard = function(limb)
		limb(
			"LeftArm_Brassard",
			Vector3.new(0.86, 0.45, 0.86),
			Vector3.new(-1.4, 3.6, 0),
			Color3.fromRGB(232, 232, 228)
		)
	end,
}

-- Builds the figure standing at `feet`, facing `facing` (flat). Returns the model and its
-- torso (prompts and signs hang off the torso).
function NpcBody.build(
	parent: Instance,
	name: string,
	feet: Vector3,
	facing: Vector3,
	dress: Dress,
	kit: Kit?
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = CFrame.lookAt(feet, feet + Vector3.new(facing.X, 0, facing.Z))
	local function limb(
		partName: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		turn: CFrame?
	): BasePart
		return Build.part(
			model,
			partName,
			size,
			root * CFrame.new(offset) * (turn or CFrame.identity),
			color,
			{ material = Enum.Material.SmoothPlastic }
		)
	end
	limb("LeftLeg", Vector3.new(0.9, 2.2, 0.9), Vector3.new(-0.5, 1.1, 0), dress.trousers)
	limb("RightLeg", Vector3.new(0.9, 2.2, 0.9), Vector3.new(0.5, 1.1, 0), dress.trousers)
	local torso = limb("Torso", Vector3.new(2, 2, 1.1), Vector3.new(0, 3.2, 0), dress.shirt)
	limb("LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 3.2, 0), dress.shirt)
	limb("RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 3.2, 0), dress.shirt)
	limb("Head", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 4.85, 0), SKIN)
	if dress.cover then
		limb("Cover", Vector3.new(1.2, 0.35, 1.3), Vector3.new(0, 5.5, -0.1), dress.cover)
	end
	if dress.helmet then
		limb("Helmet", Vector3.new(1.3, 0.9, 1.35), Vector3.new(0, 5.15, 0.05), dress.helmet)
		limb(
			"Visor",
			Vector3.new(1.0, 0.4, 0.1),
			Vector3.new(0, 4.95, -0.65),
			Color3.fromRGB(154, 164, 174)
		)
	end
	local bodyParts = #model:GetChildren()
	for _, item in (kit or {}) :: Kit do
		local add = KIT[item]
		if add then
			add(limb)
		else
			warn(`[NpcBody] no kit item "{item}"`)
		end
	end
	-- Kit is dressing: nothing on it stops a soldier.
	for index, part in model:GetChildren() do
		if index > bodyParts and part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	model.PrimaryPart = torso
	model.Parent = parent
	return model, torso
end

return NpcBody
