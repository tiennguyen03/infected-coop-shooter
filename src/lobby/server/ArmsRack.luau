--!strict
-- The Arms Room's displays (owner, 2026-11-09: "somewhere to store the guns"; Nova, 2026-11-10:
-- the whole port fore corner, a wall for long guns, a glass counter for the rest;
-- FallowLayout.ArmsRoom): every gun, sidearm and grenade the Arms Room catalog lists, in
-- catalog order (ArmsRoom.catalog), and the corner's fence. Each piece is a Model named by its
-- weapon id with the attributes RackDisplay ("wall" or "counter"), RackFace (the way it faces,
-- toward whoever looks at it) and RackSpan (its length and height, studs). Each place also has
-- an invisible box of the same name in the Hits folder, the size of the whole place: ArmsRackUI
-- (client) aims the cursor at those, so what the cursor picks never shifts as a gun slides out.
--
-- Gun models: every gun hangs as the same mesh it is held as in the match (its row's `Model`,
-- Config.Weapons.<id>.Model, read through WeaponDefinitions), swapped in once loaded; until
-- then, and for the grenades, a block silhouette (SILHOUETTES) stands in. A new gun needs no
-- change here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local ArmsRack = {}

local BOARD = Color3.fromRGB(96, 100, 98)
local PEG = Color3.fromRGB(99, 109, 119)
local DARK = Color3.fromRGB(48, 53, 59)
local GREY = Color3.fromRGB(75, 81, 89)
local OLIVE = Color3.fromRGB(99, 110, 66)
local WOOD = Color3.fromRGB(110, 90, 60)

-- Each gun hangs its own held mesh (its row's Model, the one the match puts in the hands);
-- the silhouette shows until that mesh loads, or for good if it is not uploaded (grenades).
local function meshFor(id: string): string?
	if not WeaponDefinitions.exists(id) then
		return nil
	end
	return WeaponDefinitions.get(id).Model
end

type Block = { size: Vector3, at: Vector3, color: Color3, ball: boolean? }

local function b(sx: number, sy: number, x: number, y: number, color: Color3, sz: number?): Block
	return { size = Vector3.new(sx, sy, sz or 0.2), at = Vector3.new(x, y, 0), color = color }
end

-- Silhouettes in the gun's own frame: +X the muzzle, +Y up, Z the gun's thickness.
local SILHOUETTES: { [string]: { Block } } = {
	service_rifle = {
		b(1.0, 0.35, 0, 0, DARK),
		b(0.7, 0.25, 0.75, 0, GREY, 0.22),
		b(0.9, 0.09, 1.1, 0.05, DARK, 0.09),
		b(0.75, 0.3, -0.85, -0.05, DARK, 0.18),
		b(0.18, 0.5, 0.15, -0.4, GREY, 0.15),
		b(0.15, 0.35, -0.3, -0.3, DARK, 0.15),
		b(0.5, 0.1, 0, 0.25, DARK, 0.1),
		b(0.06, 0.25, 1.05, 0.2, DARK, 0.06),
	},
	smg = {
		b(0.8, 0.3, 0, 0, DARK),
		b(0.35, 0.08, 0.55, 0.05, DARK, 0.08),
		b(0.5, 0.12, -0.62, 0, GREY, 0.12),
		b(0.15, 0.45, 0.22, -0.35, GREY, 0.14),
		b(0.15, 0.3, -0.15, -0.28, DARK, 0.15),
	},
	lmg = {
		b(1.1, 0.42, 0, 0, OLIVE, 0.26),
		b(0.6, 0.28, 0.85, 0, DARK, 0.24),
		b(1.3, 0.1, 1.45, 0.05, DARK, 0.1),
		b(0.8, 0.32, -0.95, -0.05, OLIVE, 0.2),
		b(0.4, 0.4, 0.1, -0.4, OLIVE, 0.3),
		b(0.8, 0.05, 1.4, -0.15, GREY, 0.05),
		b(0.5, 0.1, 0, 0.3, DARK, 0.1),
	},
	shotgun = {
		b(0.8, 0.3, 0, 0, DARK),
		b(1.5, 0.1, 1.15, 0.07, DARK, 0.1),
		b(1.3, 0.09, 1.05, -0.07, GREY, 0.09),
		b(0.5, 0.18, 0.85, -0.07, WOOD, 0.18),
		b(0.9, 0.3, -0.85, -0.05, WOOD, 0.18),
		b(0.15, 0.3, -0.25, -0.25, DARK, 0.15),
	},
	dmr = {
		b(1.0, 0.35, 0, 0, DARK),
		b(0.8, 0.26, 0.85, 0, GREY, 0.22),
		b(1.3, 0.09, 1.3, 0.05, DARK, 0.09),
		b(0.85, 0.32, -0.9, -0.03, DARK, 0.18),
		b(0.8, 0.16, 0, 0.35, DARK, 0.16),
		b(0.18, 0.3, 0.15, -0.3, GREY, 0.15),
		b(0.15, 0.35, -0.3, -0.3, DARK, 0.15),
	},
	pistol = {
		b(0.7, 0.18, 0.05, 0.08, DARK, 0.12),
		b(0.55, 0.1, 0.02, -0.05, GREY, 0.11),
		b(0.18, 0.42, -0.2, -0.27, DARK, 0.12),
	},
	frag = {
		{ size = Vector3.new(0.4, 0.4, 0.4), at = Vector3.zero, color = OLIVE, ball = true },
		b(0.14, 0.1, 0, 0.24, GREY, 0.14),
		b(0.08, 0.32, 0.13, 0.12, GREY, 0.05),
	},
}

local UP = Vector3.new(0, 1, 0)
local WIRE = Color3.fromRGB(120, 124, 126)
local STEEL = Color3.fromRGB(70, 74, 80)
local FELT = Color3.fromRGB(72, 80, 66)
local GLASS = Color3.fromRGB(200, 220, 225)

-- A piece on the wall: its +X (the muzzle) along the wall, +Y up, its side toward `face`.
-- Muzzles point left as you look at either display.
local function frameAt(position: Vector3, face: Vector3): CFrame
	return CFrame.fromMatrix(position, face:Cross(UP), UP)
end

local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false -- the cursor aims at the Hits boxes, never the guns
	part.CastShadow = false
end

-- The silhouette's length and height, studs (until the mesh replaces it).
local function silhouetteSpan(id: string): Vector2
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, block in SILHOUETTES[id] or SILHOUETTES.service_rifle do
		x0 = math.min(x0, block.at.X - block.size.X / 2)
		x1 = math.max(x1, block.at.X + block.size.X / 2)
		y0 = math.min(y0, block.at.Y - block.size.Y / 2)
		y1 = math.max(y1, block.at.Y + block.size.Y / 2)
	end
	return Vector2.new(x1 - x0, y1 - y0)
end

local function buildSilhouette(model: Model, id: string, frame: CFrame)
	for index, block in SILHOUETTES[id] or SILHOUETTES.service_rifle do
		local part =
			Build.part(model, "Piece", block.size, frame * CFrame.new(block.at), block.color, {
				material = Enum.Material.SmoothPlastic,
				shape = if block.ball then Enum.PartType.Ball else nil,
			})
		quiet(part)
		if index == 1 then
			model.PrimaryPart = part
		end
	end
	model:SetAttribute(Attributes.RackSpan, silhouetteSpan(id))
end

-- Swaps the silhouette for the real mesh once its template has loaded.
local function useMesh(model: Model, meshName: string, frame: CFrame)
	task.spawn(function()
		local mesh = MeshAssets.waitFor(meshName, Config.Lobby.Ship.TemplateWait)
		if not mesh then
			return
		end
		for _, child in model:GetChildren() do
			child:Destroy()
		end
		-- A held gun's mesh runs along its Z, muzzle to -Z: turn it so the muzzle points
		-- along the frame's +X, like the silhouettes.
		mesh.CFrame = frame * CFrame.Angles(0, -math.pi / 2, 0)
		quiet(mesh)
		mesh.Parent = model
		model.PrimaryPart = mesh
		model:SetAttribute(Attributes.RackSpan, Vector2.new(mesh.Size.Z, mesh.Size.Y))
	end)
end

-- A part of the corner the cursor's ray never stops on.
local function fixture(
	folder: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	options: Build.PartOptions?
): BasePart
	local part = Build.box(folder, name, min, max, color, options)
	part.CanQuery = false
	return part
end

-- One piece on a display at `frame` (+X the muzzle, +Y the gun's top), its side toward
-- `face`, and its hit box (`cell`: length, height, depth).
local function place(
	folder: Instance,
	hits: Instance,
	id: string,
	display: string,
	frame: CFrame,
	face: Vector3,
	cell: Vector3
)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute(Attributes.RackDisplay, display)
	model:SetAttribute(Attributes.RackFace, face)
	buildSilhouette(model, id, frame)
	model.Parent = folder
	local meshName = meshFor(id)
	if meshName and MeshAssets.isUploaded(meshName) then
		useMesh(model, meshName, frame)
	end
	local hit = Build.part(
		hits,
		id,
		cell,
		frame,
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	hit.CanQuery = true
end

-- The long-gun wall on the hull: a board, a lamp over it, a rail under every row, the long
-- guns in the first cells (row by row from the top).
local function buildWall(folder: Instance, hits: Instance, ids: { string })
	local wall = Layout.ArmsRoom.wall
	local board = fixture(
		folder,
		"RackBoard",
		Vector3.new(wall.x - 0.2, wall.y0, wall.z0),
		Vector3.new(wall.x, wall.y1, wall.z1),
		BOARD,
		{ material = Enum.Material.DiamondPlate }
	)
	board:SetAttribute(Attributes.RackDisplay, "wall")
	board:SetAttribute(Attributes.RackFace, Vector3.new(1, 0, 0))
	board:SetAttribute(Attributes.RackSpan, Vector2.new(wall.z1 - wall.z0, wall.y1 - wall.y0))
	local lamp = fixture(
		folder,
		"RackLamp",
		Vector3.new(wall.x - 0.2, wall.y1 + 0.2, wall.z0),
		Vector3.new(wall.x + 0.5, wall.y1 + 0.4, wall.z1),
		STEEL,
		{ collide = false }
	)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 70
	light.Range = 12
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Parent = lamp

	local width = (wall.z1 - wall.z0) / wall.columns
	local height = (wall.y1 - wall.y0) / wall.rows
	local face = Vector3.new(1, 0, 0)
	-- A gun rail along each row, the guns resting on it.
	for row = 1, wall.rows do
		local y = wall.y1 - height * (row - 0.5) - 0.34
		fixture(
			folder,
			"GunRail",
			Vector3.new(wall.x, y - 0.05, wall.z0 + 0.2),
			Vector3.new(wall.x + wall.out + 0.08, y + 0.05, wall.z1 - 0.2),
			PEG,
			{ collide = false, shadow = false }
		)
	end
	local index = 0
	for row = 1, wall.rows do
		for column = 1, wall.columns do
			index += 1
			local y = wall.y1 - height * (row - 0.5)
			local z = wall.z0 + width * (column - 0.5)
			local id = ids[index]
			if id then
				local frame = frameAt(Vector3.new(wall.x + wall.out, y, z), face)
				place(
					folder,
					hits,
					id,
					"wall",
					frame,
					face,
					Vector3.new(width - 0.1, height - 0.05, 1)
				)
			end
		end
	end
	if #ids > index then
		warn(`[ArmsRack] {#ids - index} long guns have no place on the wall`)
	end
end

-- The glass counter the Quartermaster stands behind (Nova: "like in GTA"): a steel plinth and
-- back, a felt bed inside tilted toward the soldier, glass on the front and top, a light under
-- the glass. Sections from the soldier's left, each piece lying on the bed on its side, two
-- rows deep, muzzles to the soldier's left; a label plate under each section on the front.
local function buildCounter(folder: Instance, hits: Instance, holds: { [string]: { string } })
	local c = Layout.ArmsRoom.counter
	local y0 = Layout.HangarY
	local midX = (c.x0 + c.x1) / 2
	local glass: Build.PartOptions = {
		material = Enum.Material.Glass,
		transparency = 0.75,
		collide = false,
		shadow = false,
	}
	-- The frame and the case.
	local plinthTop = y0 + 1.2
	fixture(
		folder,
		"CounterPlinth",
		Vector3.new(c.x0, y0, c.z0),
		Vector3.new(c.x1, plinthTop, c.z1),
		STEEL
	)
	fixture(
		folder,
		"CounterBack",
		Vector3.new(c.x0, plinthTop, c.z0),
		Vector3.new(c.x0 + 0.15, c.top, c.z1),
		STEEL
	)
	for _, z in { c.z0, c.z1 - 0.15 } do
		fixture(
			folder,
			"CounterEnd",
			Vector3.new(c.x0, plinthTop, z),
			Vector3.new(c.x1, c.top, z + 0.15),
			STEEL
		)
	end
	fixture(
		folder,
		"CounterFront",
		Vector3.new(c.x1 - 0.06, plinthTop, c.z0 + 0.15),
		Vector3.new(c.x1, c.top - 0.1, c.z1 - 0.15),
		GLASS,
		glass
	)
	fixture(
		folder,
		"CounterGlass",
		Vector3.new(c.x0 + 0.15, c.top - 0.1, c.z0 + 0.15),
		Vector3.new(c.x1, c.top, c.z1 - 0.15),
		GLASS,
		glass
	)
	-- A steel rim round the top, the edge you lean on.
	fixture(
		folder,
		"CounterRim",
		Vector3.new(c.x1 - 0.12, c.top - 0.12, c.z0),
		Vector3.new(c.x1 + 0.04, c.top + 0.04, c.z1),
		PEG
	)
	local lamp = fixture(
		folder,
		"CounterLamp",
		Vector3.new(c.x0 + 0.15, c.top - 0.25, c.z0 + 0.15),
		Vector3.new(c.x0 + 0.35, c.top - 0.1, c.z1 - 0.15),
		STEEL,
		{ collide = false, shadow = false }
	)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 90
	light.Range = 4
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 240, 220)
	light.Parent = lamp

	-- The bed: tilted toward the soldier (+X) about the counter's length.
	local tilt = math.rad(c.tilt)
	local face = Vector3.new(math.sin(tilt), math.cos(tilt), 0) -- the bed's normal
	local slope = Vector3.new(-math.cos(tilt), math.sin(tilt), 0) -- up the bed, away from the soldier
	local depth = (c.x1 - c.x0 - 0.3) / math.cos(tilt)
	local bedCentre = Vector3.new(midX + 0.05, c.bedY, (c.z0 + c.z1) / 2)
	local bed = Build.part(
		folder,
		"CounterBed",
		Vector3.new(0.1, depth, c.z1 - c.z0 - 0.3),
		CFrame.fromMatrix(bedCentre - face * 0.05, face, slope),
		FELT,
		{ material = Enum.Material.Fabric, collide = false }
	)
	bed.CanQuery = false
	bed:SetAttribute(Attributes.RackDisplay, "counter")
	-- The overview looks down through the glass top from over the soldier's side.
	bed:SetAttribute(Attributes.RackFace, (face + Vector3.new(0.15, 0, 0)).Unit)
	bed:SetAttribute(Attributes.RackSpan, Vector2.new(c.z1 - c.z0, c.top - y0))

	local muzzle = Vector3.new(0, 0, 1) -- the soldier's left
	local z = c.z1 - 0.15
	for _, section in c.sections do
		local ids = holds[section.holds] or {}
		local places = math.floor(section.length / section.pitch)
		local rowDepth = depth / 2
		-- A label plate on the front, under the glass, and a steel divider after the section.
		local label = fixture(
			folder,
			"SectionLabel",
			Vector3.new(c.x1, y0 + 0.75, z - section.length + 0.3),
			Vector3.new(c.x1 + 0.04, y0 + 1.05, z - 0.3),
			PEG,
			{ collide = false, shadow = false }
		)
		Build.text(
			label,
			Enum.NormalId.Right,
			string.upper(section.holds),
			{ size = 40, pixelsPerStud = 40, color = Color3.fromRGB(30, 32, 34) }
		)
		for slot = 1, places * 2 do
			local id = ids[slot]
			if not id then
				break
			end
			local column = (slot - 1) % places
			local row = (slot - 1) // places -- 0 the back row, 1 the front
			local along = (row - 0.5) * rowDepth -- toward the soldier is negative slope
			local position = bedCentre
				- slope * along
				+ muzzle * (z - section.pitch * (column + 0.5) - bedCentre.Z)
				+ face * 0.16
			place(
				folder,
				hits,
				id,
				"counter",
				CFrame.fromMatrix(position, muzzle, slope),
				face,
				Vector3.new(section.pitch - 0.05, rowDepth - 0.05, 0.6)
			)
		end
		if #ids > places * 2 then
			warn(`[ArmsRack] {#ids - places * 2} {section.holds} have no place on the counter`)
		end
		z -= section.length
		if z > c.z0 + 0.5 then
			fixture(
				folder,
				"Divider",
				Vector3.new(c.x0 + 0.15, plinthTop, z - 0.05),
				Vector3.new(c.x1 - 0.06, c.bedY + 0.3, z + 0.05),
				STEEL,
				{ collide = false, shadow = false }
			)
		end
	end
end

-- The wire fence closing the corner off at the counter's ends, and a barrier along the
-- counter so nobody climbs over it.
local function buildFence(folder: Instance)
	local room = Layout.ArmsRoom
	local c = room.counter
	local hullX = room.wall.x - 0.2
	local y = Layout.HangarY + 4.5
	local function bar(x: number, z: number)
		local part =
			Build.part(folder, "CageBar", Vector3.new(0.15, 9, 0.15), CFrame.new(x, y, z), WIRE)
		part.CanQuery = false
	end
	for x = hullX + 0.6, room.fenceX, 1.25 do
		bar(x, room.aftZ)
	end
	for z = room.aftZ, c.z0 - 0.4, 1.25 do
		bar(room.fenceX, z)
	end
	for z = c.z1 + 0.4, Layout.HangarFore - 0.3, 1.25 do
		bar(room.fenceX, z)
	end
	local top = Layout.HangarY + 9
	fixture(
		folder,
		"CageRail",
		Vector3.new(hullX, top - 0.2, room.aftZ - 0.1),
		Vector3.new(room.fenceX + 0.1, top, room.aftZ + 0.1),
		WIRE
	)
	fixture(
		folder,
		"CageRail",
		Vector3.new(room.fenceX - 0.1, top - 0.2, room.aftZ),
		Vector3.new(room.fenceX + 0.1, top, Layout.HangarFore),
		WIRE
	)
	local barrier = Build.barrier(
		folder,
		Vector3.new(c.x0, Layout.HangarY, c.z0),
		Vector3.new(c.x1, Layout.HangarY + 12, c.z1)
	)
	barrier.CanQuery = false
end

-- Builds the corner (FallowLayout.ArmsRoom); DeskService stands the Quartermaster in it.
function ArmsRack.build(parent: Instance)
	local folder = Build.folder(parent, "ArmsRack")
	local hits = Build.folder(folder, "Hits")
	local catalog = ArmsRoom.catalog()
	buildWall(folder, hits, catalog.primaries)
	buildCounter(folder, hits, {
		sidearms = catalog.secondaries,
		melee = {}, -- no melee weapons in the game yet: their section waits for them
		grenades = catalog.grenades,
	})
	buildFence(folder)
end

return ArmsRack
