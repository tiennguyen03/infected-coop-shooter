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

-- Builds the figure standing at `feet`, facing `facing` (flat). Returns the model and its
-- torso (prompts and signs hang off the torso).
function NpcBody.build(
	parent: Instance,
	name: string,
	feet: Vector3,
	facing: Vector3,
	dress: Dress
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = CFrame.lookAt(feet, feet + Vector3.new(facing.X, 0, facing.Z))
	local function limb(partName: string, size: Vector3, offset: Vector3, color: Color3): BasePart
		return Build.part(
			model,
			partName,
			size,
			root * CFrame.new(offset),
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
	model.PrimaryPart = torso
	model.Parent = parent
	return model, torso
end

return NpcBody
