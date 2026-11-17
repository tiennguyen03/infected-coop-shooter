--!strict
-- The Call-ins display (owner, 2026-11-16: "similar to how the Quartermaster is right now, where
-- you can see the guns behind him... the Doorman laying on the floor or something like that"):
-- every call-in the desk sells (KitPrices.soldAt), each laid out on its own pallet in a row
-- behind the sapper sergeant (FallowLayout.CallInDisplay), in call-in order from the soldier's
-- left, with a plate on the hull board over it carrying its name and designation.
--
-- How a call-in shows is its own Config row: `Display = { Prop, Width }` (Prop one of PROPS
-- below, Width the studs of row it takes); a row with no Display gets
-- Config.Lobby.CallInDisplay.DefaultProp, a crate with its name stencilled on, so a new call-in
-- shows up by having a row. Existing meshes are used where they exist (the Doorman, the ammo
-- crate, the mine, the Shrike as a scale model), swapped in once loaded; Parts stand in until
-- then.
--
-- Like the Arms Room's rack (ArmsRack): each piece is a Model named by its call-in id with the
-- attributes RackDisplay ("callins"), RackFace (toward the soldier) and RackSpan (width and
-- height, studs); each has an invisible box of the same name in the Hits folder, the size of
-- its bay, which CallInDisplayUI (client) aims the cursor at. Each plate has a Status part
-- under it where the client writes ON YOUR RECORD or the price (per soldier).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local CallInDisplay = {}

local TUNING = Config.Lobby.CallInDisplay

local OLIVE = Color3.fromRGB(86, 92, 66)
local OLIVE_DARK = Color3.fromRGB(60, 64, 50)
local WOOD = Color3.fromRGB(110, 90, 60)
local STEEL = Color3.fromRGB(70, 74, 80)
local GREY = Color3.fromRGB(120, 124, 126)
local DARK = Color3.fromRGB(40, 42, 44)
local BRASS = Color3.fromRGB(170, 140, 70)
local PAPER = Color3.fromRGB(214, 206, 180)
local RED = Color3.fromRGB(150, 40, 36)
local WHITE = Color3.fromRGB(226, 224, 216)
local PALLET = Color3.fromRGB(96, 84, 62)
local PLATE = Color3.fromRGB(99, 109, 119)

local CYLINDER = Enum.PartType.Cylinder

-- Look only: the cursor aims at the Hits boxes, nobody walks into the row (a barrier does it).
local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

type Piece = (
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	options: Build.PartOptions?
) -> BasePart

-- A prop builder: `piece` places a Part relative to the pallet top (X along the row toward
-- the soldier's left, -Z toward the soldier); `frame` is the pallet top's world frame, `width`
-- and `depth` the bay. Returns the prop's height, studs (the camera frames it).
type Builder = (
	model: Model,
	piece: Piece,
	frame: CFrame,
	width: number,
	depth: number,
	def: CallInDefinitions.CallInDefinition
) -> number

-- Swaps the Part stand-in for a loaded mesh: `place` positions the clone(s) and returns true.
local function withMeshes(model: Model, names: { string }, place: ({ MeshPart }) -> ())
	for _, name in names do
		if not MeshAssets.isUploaded(name) then
			return
		end
	end
	task.spawn(function()
		local parts: { MeshPart } = {}
		for _, name in names do
			local mesh = MeshAssets.waitFor(name, Config.Lobby.Ship.TemplateWait)
			if not mesh then
				return
			end
			table.insert(parts, mesh)
		end
		for _, child in model:GetChildren() do
			if child:GetAttribute("StandIn") then
				child:Destroy()
			end
		end
		place(parts)
		for _, part in parts do
			quiet(part)
			part.Parent = model
		end
	end)
end

local function standIn(part: BasePart): BasePart
	part:SetAttribute("StandIn", true)
	return part
end

local PROPS: { [string]: Builder } = {}

-- Hammer: an open crate of 81 mm mortar shells, the lid leant on its back.
PROPS.shells = function(_model, piece)
	piece(
		"Crate",
		Vector3.new(2.4, 0.8, 1.4),
		CFrame.new(0, 0.4, 0),
		WOOD,
		{ material = Enum.Material.WoodPlanks }
	)
	piece("Inside", Vector3.new(2.2, 0.05, 1.2), CFrame.new(0, 0.78, 0), DARK)
	for row = 0, 1 do
		for index = 0, 2 do
			local z = -0.3 + row * 0.6
			local x = -0.45 + index * 0.45
			-- Shells lie across the crate, nose toward the soldier.
			piece(
				"Shell",
				Vector3.new(1.0, 0.32, 0.32),
				CFrame.new(x, 0.95, z) * CFrame.Angles(0, math.pi / 2, 0),
				OLIVE_DARK,
				{ shape = CYLINDER }
			)
			piece(
				"Fins",
				Vector3.new(0.25, 0.3, 0.3),
				CFrame.new(x, 0.95, z + 0.6) * CFrame.Angles(0, math.pi / 2, 0),
				BRASS,
				{ shape = CYLINDER }
			)
		end
	end
	piece(
		"Lid",
		Vector3.new(2.4, 1.3, 0.1),
		CFrame.new(0, 0.75, 0.85) * CFrame.Angles(math.rad(-15), 0, 0),
		WOOD,
		{ material = Enum.Material.WoodPlanks }
	)
	return 1.5
end

-- Anvil: a folding map table, a map sheet on it and the binoculars you mark it with.
PROPS.maptable = function(_model, piece)
	local top = 2.6
	piece("Top", Vector3.new(3.2, 0.12, 2.2), CFrame.new(0, top, 0), OLIVE_DARK)
	for _, x in { -1.45, 1.45 } do
		for _, z in { -0.95, 0.95 } do
			piece("Leg", Vector3.new(0.12, top, 0.12), CFrame.new(x, top / 2, z), STEEL)
		end
	end
	piece(
		"Map",
		Vector3.new(2.6, 0.02, 1.7),
		CFrame.new(0, top + 0.07, 0) * CFrame.Angles(0, math.rad(4), 0),
		PAPER,
		{ material = Enum.Material.SmoothPlastic }
	)
	piece(
		"Grid",
		Vector3.new(0.04, 0.025, 1.6),
		CFrame.new(-0.4, top + 0.08, 0),
		Color3.fromRGB(90, 110, 120)
	)
	piece(
		"Grid",
		Vector3.new(2.5, 0.025, 0.04),
		CFrame.new(0, top + 0.08, 0.3),
		Color3.fromRGB(90, 110, 120)
	)
	piece(
		"Mark",
		Vector3.new(0.2, 0.03, 0.2),
		CFrame.new(0.6, top + 0.09, -0.2),
		RED,
		{ material = Enum.Material.SmoothPlastic }
	)
	-- The binoculars, lying on the map.
	local glasses = CFrame.new(-0.2, top + 0.22, -0.35) * CFrame.Angles(0, math.rad(25), 0)
	for _, x in { -0.2, 0.2 } do
		piece(
			"Barrel",
			Vector3.new(0.55, 0.3, 0.3),
			glasses * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			DARK,
			{ shape = CYLINDER }
		)
	end
	piece("Bridge", Vector3.new(0.3, 0.12, 0.2), glasses, DARK)
	return top + 0.4
end

-- Shrike: a scale model of the gunship on a stand (the real mesh, shrunk).
PROPS.gunship = function(model, piece, frame, _width, _depth, def)
	local height = 2.4
	piece("StandBase", Vector3.new(1.4, 0.12, 1.4), CFrame.new(0, 0.06, 0), STEEL)
	piece("StandPost", Vector3.new(0.12, height, 0.12), CFrame.new(0, height / 2, 0), STEEL)
	-- The model flies along the row, nose to the soldier's left, banked a little.
	local hold = CFrame.new(0, height + 0.5, 0) * CFrame.Angles(0, -math.pi / 2, math.rad(8))
	standIn(piece("Hull", Vector3.new(0.9, 0.8, 2.2), hold, OLIVE_DARK))
	standIn(
		piece("Boom", Vector3.new(0.25, 0.25, 1.8), hold * CFrame.new(0, 0.15, 1.8), OLIVE_DARK)
	)
	local scale = TUNING.ModelScale
	withMeshes(model, { "veh_shrike_hull", "veh_shrike_rotor" }, function(parts)
		local hull, rotor = parts[1], parts[2]
		hull.Size *= scale
		hull.CFrame = frame * hold * CFrame.new(MeshAssets.getOffset("veh_shrike_hull") * scale)
		rotor.Size *= scale
		local row = (Config.CallIns :: any)[def.ConfigKey] or {}
		local hub = row.RotorHub or Vector3.new(0, 3.35, -1.5)
		rotor.CFrame = frame * hold * CFrame.new(hub * scale)
	end)
	return height + 1.2
end

-- Doorman: the tripod gun itself, standing on the floor, turned off the walk.
PROPS.doorman = function(model, piece, frame, _width, _depth, def)
	local row = (Config.CallIns :: any)[def.ConfigKey] or {}
	local yawHeight = row.YawHeight or 1.9
	local pitchHeight = row.PitchHeight or 2.6
	local stand = CFrame.Angles(0, math.rad(30), 0) -- points off to the side, never at you
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		standIn(
			piece(
				"Leg",
				Vector3.new(0.12, 2.2, 0.12),
				stand
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 1.0, -0.8)
					* CFrame.Angles(math.rad(-35), 0, 0),
				STEEL
			)
		)
	end
	standIn(piece("Head", Vector3.new(0.6, 0.4, 0.6), stand * CFrame.new(0, yawHeight, 0), STEEL))
	standIn(
		piece("Gun", Vector3.new(0.45, 0.45, 2.6), stand * CFrame.new(0, pitchHeight, -0.6), DARK)
	)
	withMeshes(
		model,
		{ "dep_doorman_base", "dep_doorman_cradle", "dep_doorman_gun" },
		function(parts)
			local at = frame * stand
			parts[1].CFrame = at * CFrame.new(MeshAssets.getOffset("dep_doorman_base"))
			parts[2].CFrame = (at + Vector3.new(0, yawHeight, 0))
				* CFrame.new(MeshAssets.getOffset("dep_doorman_cradle"))
			parts[3].CFrame = (at + Vector3.new(0, pitchHeight, 0))
				* CFrame.new(MeshAssets.getOffset("dep_doorman_gun"))
		end
	)
	return pitchHeight + 0.8
end

-- Tripline: the six charges laid out in their arc in front of the satchel they come in.
PROPS.mines = function(model, piece, frame)
	piece(
		"Satchel",
		Vector3.new(1.2, 0.6, 0.9),
		CFrame.new(0, 0.3, 0.9),
		OLIVE,
		{ material = Enum.Material.Fabric }
	)
	local spots: { CFrame } = {}
	for index = 0, 5 do
		local angle = math.rad(-75 + index * 30)
		local at = CFrame.new(math.sin(angle) * 1.25, 0.15, 0.6 - math.cos(angle) * 1.25)
			* CFrame.Angles(0, angle, 0)
		table.insert(spots, at)
		standIn(piece("Mine", Vector3.new(0.7, 0.3, 0.7), at, OLIVE_DARK, { shape = CYLINDER }))
	end
	local names = {}
	for _ = 1, #spots do
		table.insert(names, "prop_repulsor_mine")
	end
	withMeshes(model, names, function(parts)
		for index, part in parts do
			part.Size *= 0.45
			part.CFrame = frame * spots[index] * CFrame.new(0, part.Size.Y / 2 - 0.15, 0)
		end
	end)
	return 0.8
end

-- Concertina: a coil of wire on its side and the pickets it is staked with.
PROPS.wire = function(_model, piece)
	local coil = CFrame.new(0, 0.95, 0) -- the coil's axis runs along the row
	piece(
		"Coil",
		Vector3.new(2.4, 1.9, 1.9),
		coil,
		GREY,
		{ shape = CYLINDER, material = Enum.Material.DiamondPlate }
	)
	piece("Hollow", Vector3.new(2.42, 1.3, 1.3), coil, DARK, { shape = CYLINDER })
	for index = -2, 2 do
		piece(
			"Turn",
			Vector3.new(0.06, 2.0, 2.0),
			coil * CFrame.new(index * 0.5, 0, 0),
			Color3.fromRGB(150, 154, 156),
			{ shape = CYLINDER }
		)
	end
	for index, x in { -1.1, 1.1 } do
		piece(
			"Picket",
			Vector3.new(0.12, 2.6, 0.12),
			CFrame.new(x, 1.2, 0.9) * CFrame.Angles(0, 0, math.rad(if index == 1 then 8 else -8)),
			OLIVE_DARK
		)
	end
	return 2.0
end

-- Speedball: the ammo bundle (the match's crate) with its yellow smoke on top.
PROPS.ammo = function(model, piece, frame)
	local size = Vector3.new(2.86, 1.68, 1.92)
	standIn(piece("Crate", size, CFrame.new(0, size.Y / 2, 0), OLIVE))
	piece(
		"Smoke",
		Vector3.new(0.6, 0.3, 0.3),
		CFrame.new(0.6, size.Y + 0.15, -0.2) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(232, 181, 75),
		{ shape = CYLINDER, material = Enum.Material.SmoothPlastic }
	)
	withMeshes(model, { "prop_ammo_crate" }, function(parts)
		parts[1].CFrame = frame * CFrame.new(0, size.Y / 2, 0)
	end)
	return size.Y + 0.3
end

-- Aid Bag: the medical bag, a white panel and red cross on its flap, its pink smoke beside it.
PROPS.medbag = function(_model, piece)
	piece(
		"Bag",
		Vector3.new(1.9, 0.9, 1.1),
		CFrame.new(0, 0.45, 0),
		Color3.fromRGB(96, 70, 60),
		{ material = Enum.Material.Fabric }
	)
	piece(
		"Panel",
		Vector3.new(0.8, 0.03, 0.7),
		CFrame.new(0, 0.915, 0),
		WHITE,
		{ material = Enum.Material.SmoothPlastic }
	)
	piece(
		"Cross",
		Vector3.new(0.55, 0.04, 0.16),
		CFrame.new(0, 0.93, 0),
		RED,
		{ material = Enum.Material.SmoothPlastic }
	)
	piece(
		"Cross",
		Vector3.new(0.16, 0.04, 0.55),
		CFrame.new(0, 0.93, 0),
		RED,
		{ material = Enum.Material.SmoothPlastic }
	)
	piece("Handle", Vector3.new(1.0, 0.25, 0.1), CFrame.new(0, 1.0, 0), DARK)
	piece(
		"Smoke",
		Vector3.new(0.6, 0.3, 0.3),
		CFrame.new(-1.1, 0.3, -0.3) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(210, 130, 130),
		{ shape = CYLINDER, material = Enum.Material.SmoothPlastic }
	)
	return 1.2
end

-- The default: a crate with the call-in's name stencilled on its front.
PROPS.crate = function(_model, piece, _frame, _width, _depth, def)
	local crate = piece("Crate", Vector3.new(2.2, 1.4, 1.6), CFrame.new(0, 0.7, 0), OLIVE)
	Build.text(crate, Enum.NormalId.Front, string.upper(def.Name), { size = 60, color = WHITE })
	return 1.4
end

local function displayOf(def: CallInDefinitions.CallInDefinition): (string, number)
	local row = (Config.CallIns :: any)[def.ConfigKey]
	local display = row and row.Display
	local prop = display and display.Prop
	if type(prop) ~= "string" or not PROPS[prop] then
		if prop ~= nil then
			warn(`[CallInDisplay] {def.Id}: no prop "{prop}", showing a crate`)
		end
		prop = TUNING.DefaultProp
	end
	local width = display and display.Width
	return prop, if type(width) == "number" then width else TUNING.DefaultWidth
end

-- Builds the row for `deskId` (what that desk sells) into `parent`.
function CallInDisplay.build(parent: Instance, deskId: string)
	local layout = Layout.CallInDisplay
	local folder = Build.folder(parent, "CallInDisplay")
	local hits = Build.folder(folder, "Hits")
	local plates = Build.folder(folder, "Plates")
	local origin = layout.origin
	local face = origin.LookVector
	local depth = layout.depth

	-- The back board on the hull, a lamp over it; the overview frames the board.
	local boardHeight = 2.2
	local board = Build.part(
		folder,
		"DisplayBoard",
		Vector3.new(layout.length, boardHeight, 0.2),
		origin * CFrame.new(0, layout.boardY, depth / 2 + 0.1),
		Color3.fromRGB(96, 100, 98),
		{ material = Enum.Material.DiamondPlate, collide = false }
	)
	board.CanQuery = false
	board:SetAttribute(Attributes.RackDisplay, "callins")
	board:SetAttribute(Attributes.RackFace, face)
	board:SetAttribute(
		Attributes.RackSpan,
		Vector2.new(layout.length, layout.boardY + boardHeight / 2)
	)
	local lamp = Build.part(
		folder,
		"DisplayLamp",
		Vector3.new(layout.length, 0.2, 0.7),
		origin * CFrame.new(0, layout.boardY + boardHeight / 2 + 0.3, depth / 2 - 0.2),
		STEEL,
		{ collide = false, shadow = false }
	)
	lamp.CanQuery = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 80
	light.Range = 10
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Parent = lamp

	-- Nobody walks into the row; the cursor goes through.
	local barrier = Build.part(
		folder,
		"DisplayBarrier",
		Vector3.new(layout.length, 12, depth),
		origin * CFrame.new(0, 6, 0),
		Color3.new(),
		{ transparency = 1, shadow = false }
	)
	barrier.CanQuery = false

	-- Pallets from the soldier's left (the origin's +X), packed along the row.
	local x = layout.length / 2
	for _, id in KitPrices.soldAt(deskId) do
		local def = CallInDefinitions.get(id)
		if not def then
			continue
		end
		local prop, width = displayOf(def)
		if x - width < -layout.length / 2 - 0.01 then
			warn(`[CallInDisplay] no room left on the row for {id}`)
			break
		end
		local centre = x - width / 2
		x -= width + TUNING.Gap
		local bay = origin * CFrame.new(centre, 0, 0)
		local pallet = Build.part(
			folder,
			"Pallet",
			Vector3.new(width, 0.35, depth),
			bay * CFrame.new(0, 0.175, 0),
			PALLET,
			{ material = Enum.Material.WoodPlanks, shadow = false }
		)
		pallet.CanQuery = false
		local frame = bay * CFrame.new(0, 0.35, 0)

		local model = Instance.new("Model")
		model.Name = id
		model:SetAttribute(Attributes.RackDisplay, "callins")
		model:SetAttribute(Attributes.RackFace, face)
		local function piece(
			name: string,
			size: Vector3,
			at: CFrame,
			color: Color3,
			options: Build.PartOptions?
		): BasePart
			local part = Build.part(model, name, size, frame * at, color, options)
			quiet(part)
			return part
		end
		local height = PROPS[prop](model, piece, frame, width, depth, def)
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
		model:SetAttribute(Attributes.RackSpan, Vector2.new(width, height + 0.35))
		model.Parent = folder

		local hit = Build.part(
			hits,
			id,
			Vector3.new(width - 0.1, height + 0.6, depth),
			frame * CFrame.new(0, height / 2, 0),
			Color3.new(),
			{ transparency = 1, collide = false, shadow = false }
		)
		hit.CanQuery = true

		-- The plate on the board: its name and designation (per-soldier status under it).
		local plateAt = origin * CFrame.new(centre, layout.boardY + 0.35, depth / 2 - 0.02)
		local plate = Build.part(
			plates,
			id,
			Vector3.new(width - 0.4, 1.0, 0.06),
			plateAt,
			PLATE,
			{ collide = false, shadow = false }
		)
		plate.CanQuery = false
		Build.text(
			plate,
			Enum.NormalId.Front,
			string.upper(def.Name),
			{ size = 70, color = Color3.fromRGB(30, 32, 34) }
		)
		local status = Build.part(
			plates,
			"Status",
			Vector3.new(width - 0.4, 0.55, 0.06),
			plateAt * CFrame.new(0, -0.85, 0),
			Color3.new(),
			{ transparency = 1, collide = false, shadow = false }
		)
		status.CanQuery = false
		status:SetAttribute(Attributes.RackDisplay, id) -- which call-in it reports on
	end
end

return CallInDisplay
