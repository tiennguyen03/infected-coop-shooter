--!strict
-- Lantern, the lift bird on each deck spot (docs/LORE.md > Lantern; meshes in
-- assets/3d/build/lantern.py, sheet in docs/sprints/LOBBY_V1_FALLOW.md > Lantern). Nose to
-- the bow (+Z), the open door to starboard (+X) facing the boarding box.
--
-- The v1 block bird is built first and stays until the four meshes have loaded; then the
-- blocks give way to the meshes, invisible colliders, the amber lamp (off until the rotor
-- turns), the stencilled bird number, HRD over the painted-out marks, the hidden blur discs
-- and the crew chief in the door. LanternSpool (client) turns the rotors and lights the lamp
-- while the spot counts down (Attributes.LiftAt, written by LaunchService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Build = require(script.Parent.Build)
local NpcBody = require(script.Parent.NpcBody)

local LanternBird = {}

local OLIVE = Color3.fromRGB(62, 66, 56)
local OLIVE_DARK = Color3.fromRGB(44, 48, 40)
local LAMP_OFF = Color3.fromRGB(132, 95, 32) -- the palette's brass_d
local STENCIL = Color3.fromRGB(232, 232, 226)
local SPRAY = Color3.fromRGB(226, 224, 216)
local DISC = Color3.fromRGB(48, 52, 56)

-- Hubs in the helo frame (origin on the deck at the mast foot): lantern.py HUB / TAIL_HUB.
local HUB = Vector3.new(0, 11.9, 0)
local TAIL_HUB = Vector3.new(-0.6, 11.5, -26.6)
local ROTOR_REST = math.rad(20) -- the blades sit off the boom's line at rest

local MESHES =
	{ "veh_lantern_body", "veh_lantern_trim", "veh_lantern_rotor", "veh_lantern_tail_rotor" }

-- The v1 bird in blocks: the fallback until the meshes are uploaded.
local function buildBlocks(model: Model, base: CFrame)
	local function piece(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		options: Build.PartOptions?
	): BasePart
		return Build.part(model, name, size, base * CFrame.new(offset), color, options)
	end
	model.PrimaryPart = piece("Cabin", Vector3.new(7, 6, 14), Vector3.new(0, 4.5, 0), OLIVE)
	piece("Nose", Vector3.new(6, 4.5, 4), Vector3.new(0, 4, 9), OLIVE)
	piece(
		"Windscreen",
		Vector3.new(5.6, 2, 0.3),
		Vector3.new(0, 5.6, 11),
		Color3.fromRGB(24, 30, 34)
	)
	piece("Door", Vector3.new(0.2, 4.5, 5), Vector3.new(3.55, 4, 1), Color3.fromRGB(20, 22, 20))
	piece("Boom", Vector3.new(2, 2, 16), Vector3.new(0, 6, -15), OLIVE)
	piece("Fin", Vector3.new(0.6, 5, 3), Vector3.new(0, 8.5, -22), OLIVE)
	piece("TailRotorBlock", Vector3.new(0.2, 4.5, 0.6), Vector3.new(0.6, 9, -22), OLIVE_DARK)
	piece("Mast", Vector3.new(1, 1.5, 1), Vector3.new(0, 8.2, 0), OLIVE_DARK)
	for index = 0, 3 do
		Build.part(
			model,
			"Blade",
			Vector3.new(0.9, 0.2, 13),
			base
				* CFrame.new(0, 9, 0)
				* CFrame.Angles(0, index * math.pi / 2 + ROTOR_REST, 0)
				* CFrame.new(0, 0, 6.5),
			OLIVE_DARK,
			{ collide = false }
		)
	end
	for _, x in { -3, 3 } do
		piece("Skid", Vector3.new(0.5, 0.4, 14), Vector3.new(x, 0.2, 1), OLIVE_DARK)
		piece("Strut", Vector3.new(0.3, 1.5, 0.3), Vector3.new(x, 1, 4), OLIVE_DARK)
		piece("Strut", Vector3.new(0.3, 1.5, 0.3), Vector3.new(x, 1, -2), OLIVE_DARK)
	end
end

-- A transparent Part carrying lettering on the given faces.
local function lettering(
	model: Model,
	cframe: CFrame,
	size: Vector3,
	faces: { Enum.NormalId },
	text: string,
	options: Build.TextOptions
)
	local part = Build.part(
		model,
		"Lettering",
		size,
		cframe,
		Color3.new(),
		{ transparency = 1, collide = false }
	)
	part.CanQuery = false
	for _, face in faces do
		Build.text(part, face, text, options)
	end
end

local function dressMeshes(
	model: Model,
	base: CFrame,
	number: number,
	parts: { [string]: MeshPart }
)
	for _, child in model:GetChildren() do
		child:Destroy()
	end
	local function at(name: string, cframe: CFrame)
		local part = parts[name]
		part.CFrame = cframe * CFrame.new(MeshAssets.getOffset(name))
		part.Parent = model
	end
	at("veh_lantern_body", base)
	at("veh_lantern_trim", base)
	at("veh_lantern_rotor", base * CFrame.new(HUB) * CFrame.Angles(0, ROTOR_REST, 0))
	parts.veh_lantern_rotor.Name = "Rotor"
	at("veh_lantern_tail_rotor", base * CFrame.new(TAIL_HUB))
	parts.veh_lantern_tail_rotor.Name = "TailRotor"

	-- What the soldiers bump into: the cabin (skids included), the tail, the fin.
	local function collider(size: Vector3, offset: Vector3)
		local part = Build.part(
			model,
			"Collider",
			size,
			base * CFrame.new(offset),
			Color3.new(),
			{ transparency = 1 }
		)
		part.CastShadow = false
		return part
	end
	model.PrimaryPart = collider(Vector3.new(8, 9.2, 20), Vector3.new(0, 4.6, 3))
	collider(Vector3.new(2.4, 2.4, 17), Vector3.new(0, 6.8, -15.5))
	collider(Vector3.new(0.8, 7, 3.5), Vector3.new(0, 9.5, -25.8))

	-- The amber lamp behind the mast: off until the rotor turns (LanternSpool lights it).
	local lantern = Config.Lobby.Lantern
	local lamp = Build.part(
		model,
		"Lamp",
		Vector3.new(0.6, 0.5, 0.6),
		base * CFrame.new(0, 11.25, -2.2),
		LAMP_OFF,
		{ material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
	)
	local light = Instance.new("PointLight")
	light.Color = lantern.LampColor
	light.Range = lantern.LampRange
	light.Brightness = lantern.LampBrightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = lamp

	-- Blur discs, hidden until the last seconds of the spool (a VFX exception, STYLES §6).
	local function disc(name: string, diameter: number, cframe: CFrame)
		local part = Build.part(
			model,
			name,
			Vector3.new(0.05, diameter, diameter),
			cframe,
			DISC,
			{
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.SmoothPlastic,
				transparency = 1,
				collide = false,
				shadow = false,
			}
		)
		part.CanQuery = false
	end
	disc("RotorDisc", 38, base * CFrame.new(HUB) * CFrame.Angles(0, 0, math.pi / 2))
	disc("TailDisc", 5.2, base * CFrame.new(TAIL_HUB))

	-- The stencilled number on both nose doors and the fin; HRD over the painted-out marks.
	local stencil = { size = 120, color = STENCIL, font = Enum.Font.GothamBlack }
	local spray = { size = 120, color = SPRAY, font = Enum.Font.PermanentMarker }
	local label = tostring(number)
	local sides = { Enum.NormalId.Left, Enum.NormalId.Right }
	lettering(
		model,
		base * CFrame.new(0, 3.9, 8.25),
		Vector3.new(7.2, 1.4, 2.5),
		sides,
		label,
		stencil
	)
	lettering(
		model,
		base * CFrame.new(0, 9.0, -25.3) * CFrame.Angles(math.rad(-20), 0, 0),
		Vector3.new(0.6, 2.4, 2.4),
		sides,
		label,
		stencil
	)
	lettering(model, base * CFrame.new(0, 6.6, -15), Vector3.new(1.95, 1.2, 4), sides, "HRD", spray)
	lettering(
		model,
		base * CFrame.new(-3.84, 6, -3),
		Vector3.new(0.08, 3, 4),
		{ Enum.NormalId.Left },
		"HRD",
		spray
	)

	-- The crew chief at the aft edge of the door, strapped in, facing the boarding box.
	local chief = NpcBody.build(
		model,
		"CrewChief",
		(base * CFrame.new(2.6, 2.45, -1.2)).Position,
		base:VectorToWorldSpace(Vector3.new(1, 0, 0)),
		NpcBody.Aircrew
	)
	for _, part in chief:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

-- Loads the four meshes; all or none.
local function loadMeshes(): { [string]: MeshPart }?
	local parts: { [string]: MeshPart } = {}
	for _, name in MESHES do
		if not MeshAssets.isUploaded(name) then
			return nil
		end
		local part = MeshAssets.waitFor(name, Config.Lobby.Ship.TemplateWait)
		if not part then
			return nil
		end
		parts[name] = part
	end
	return parts
end

-- Builds the bird standing on `at` (the spot's centre on the deck) and returns its model.
function LanternBird.build(parent: Instance, at: Vector3, number: number): Model
	local model = Instance.new("Model")
	model.Name = "Lantern"
	local base = CFrame.new(at)
	buildBlocks(model, base)
	model.Parent = parent
	task.spawn(function()
		local parts = loadMeshes()
		if parts then
			dressMeshes(model, base, number, parts)
		end
	end)
	return model
end

return LanternBird
