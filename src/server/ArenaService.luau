--!strict
-- Stage 1: "Checkpoint Delta". An overrun quarantine checkpoint laid out like a Risk of
-- Rain 2 stage: open ground with raised hills (walkable embankments on every side, so the
-- Infected, who have no pathfinding, can always climb to the player), a landmark comm
-- tower on the high ground, roads for orientation, and the objective on the hill. Layout
-- per docs/LEVELS.md section A: insert and extract at the LZ helipad, the
-- main road south to the Gate (a T-wall line across the map with one lane, buses queued
-- inside it), the Pens as a hesco-ringed funnel site, the Overlook summit kept open.
-- Terrain is plain Parts (exact collision, no mesh cost); dressing is MeshAssets templates
-- placed by raycast onto whatever ground is under them. Every piece is built against the
-- 5-stud character (assets/3d/build/build_assets.py scale constants).

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local SkyService = require(script.Parent.SkyService)

local Missions = require(script.Parent.Missions)
local MissionTypes = require(script.Parent.Missions.MissionTypes)

type Hill = MissionTypes.Hill
type Dressing = MissionTypes.Dressing
type Patch = MissionTypes.Patch
type Ramp = MissionTypes.Ramp
type FencePanel = MissionTypes.FencePanel
type Side = MissionTypes.Side
type Opening = MissionTypes.Opening
type StairSpec = MissionTypes.StairSpec
type LadderSpec = MissionTypes.LadderSpec
type InteriorWall = MissionTypes.InteriorWall
type Mezzanine = MissionTypes.Mezzanine
type Extra = MissionTypes.Extra
type BuildingSpec = MissionTypes.BuildingSpec

local ArenaService = {}

local FENCE_STEP = 12 -- one chain-link panel (12.06 wide) every 12 studs

local HALF = 300 -- half-extent: arena spans -300..+300 on X/Z (600 studs)
local BASEPLATE_GRACE = 5 -- seconds the hidden Studio baseplate stays solid at boot

-- Dusty ground, asphalt roads, concrete pads: the muted "field-kit" palette (docs/STYLES.md).
local GROUND_COLOR = Color3.fromRGB(94, 88, 76)
local ROAD_COLOR = Color3.fromRGB(58, 60, 64)
local CONCRETE_COLOR = Color3.fromRGB(122, 120, 114)
local HILL_COLOR = Color3.fromRGB(102, 96, 78)
local SLOPE_COLOR = Color3.fromRGB(82, 74, 60)
local WALL_COLOR = Color3.fromRGB(104, 100, 92)
local PAINT_COLOR = Color3.fromRGB(214, 214, 208)
local METAL_COLORS = {
	Color3.fromRGB(48, 50, 54),
	Color3.fromRGB(52, 56, 60),
	Color3.fromRGB(40, 42, 46),
}

-- Roblox built-in materials give the flat ground parts surface texture for free (engine
-- textures, no upload, scaled down on low graphics settings) and drive the footstep surface
-- in FootstepController. Road paint stays SmoothPlastic. docs/STYLES.md §6 "Color and texture".
local function surfaceMaterial(color: Color3): Enum.Material
	if color == GROUND_COLOR or color == HILL_COLOR or color == SLOPE_COLOR then
		return Enum.Material.Ground
	elseif color == ROAD_COLOR then
		return Enum.Material.Asphalt
	elseif color == CONCRETE_COLOR or color == WALL_COLOR then
		return Enum.Material.Concrete
	end
	for _, metal in METAL_COLORS do
		if color == metal then
			return Enum.Material.Metal
		end
	end
	return Enum.Material.SmoothPlastic
end

-- The mission being built and its layout tables (src/server/Missions; one data file
-- per mission, docs/ARCHITECTURE.md F6). This file is the builder.
local mission = Missions.current()
local HILLS = mission.Hills
local DRESSING = mission.Dressing
local PATCHES = mission.Patches
local RAMPS = mission.Ramps
local PERIMETER = mission.Perimeter
local FENCE = mission.Fence
local BUILDINGS = mission.Buildings

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	class: string?
): BasePart
	local part = Instance.new(class or "Part") :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Material = surfaceMaterial(color)
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function buildHill(parent: Instance, hill: Hill)
	local model = Instance.new("Model")
	model.Name = hill.name
	local h = hill.height
	local base = hill.base or 0
	local cy = base + h / 2
	local slope = h * 1.2
	local open = hill.open or {}
	local hx, hz = hill.top.X / 2, hill.top.Y / 2
	makePart(
		"Top",
		Vector3.new(hill.top.X, h, hill.top.Y),
		CFrame.new(hill.x, cy, hill.z),
		HILL_COLOR
	).Parent =
		model
	-- A WedgePart rises from its -Z edge to its +Z face, so each embankment is yawed to put
	-- the tall face against the plateau.
	type Side = { x: number, z: number, yaw: number, w: number }
	local sides: { [string]: Side } = {
		south = { x = 0, z = -(hz + slope / 2), yaw = 0, w = hill.top.X },
		north = { x = 0, z = hz + slope / 2, yaw = 180, w = hill.top.X },
		east = { x = hx + slope / 2, z = 0, yaw = -90, w = hill.top.Y },
		west = { x = -(hx + slope / 2), z = 0, yaw = 90, w = hill.top.Y },
	}
	for name, side in sides do
		if open[name] then
			continue
		end
		makePart(
			"Slope",
			Vector3.new(side.w, h, slope),
			CFrame.new(hill.x + side.x, cy, hill.z + side.z)
				* CFrame.Angles(0, math.rad(side.yaw), 0),
			SLOPE_COLOR,
			"WedgePart"
		).Parent =
			model
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local xSide = if sx > 0 then "east" else "west"
			local zSide = if sz > 0 then "north" else "south"
			if open[xSide] or open[zSide] then
				continue
			end
			makePart(
				"Corner",
				Vector3.new(slope, h, slope),
				CFrame.new(hill.x + sx * (hx + slope / 2), cy, hill.z + sz * (hz + slope / 2)),
				SLOPE_COLOR
			).Parent =
				model
		end
	end
	model.Parent = parent
end

local HIGHWAY_Y = 12 -- top of the highway embankment (HILLS HighwayWest/East height)

local function buildHighway(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Highway"
	-- Asphalt along the whole embankment, bridge included.
	makePart("Road", Vector3.new(600, 0.2, 14), CFrame.new(0, HIGHWAY_Y + 0.1, -45), ROAD_COLOR).Parent =
		model
	for x = -290, 290, 20 do
		makePart(
			"Dash",
			Vector3.new(8, 0.1, 0.6),
			CFrame.new(x, HIGHWAY_Y + 0.25, -45),
			PAINT_COLOR
		).Parent =
			model
	end
	-- Bridge deck over the main road (x -46..-14): 32 long, underside at 10.5 so a 2x Brute
	-- fits under it. Concrete parapets on both edges, piers either side of the road below.
	makePart(
		"Deck",
		Vector3.new(32, 1.5, 18),
		CFrame.new(-30, HIGHWAY_Y - 0.75, -45),
		CONCRETE_COLOR
	).Parent =
		model
	for _, sz in { -1, 1 } do
		makePart(
			"Parapet",
			Vector3.new(32, 2.5, 0.6),
			CFrame.new(-30, HIGHWAY_Y + 1.25, -45 + sz * 8.7),
			CONCRETE_COLOR
		).Parent =
			model
	end
	for _, sx in { -1, 1 } do
		makePart(
			"Pier",
			Vector3.new(2, HIGHWAY_Y - 1.5, 14),
			CFrame.new(-30 + sx * 11, (HIGHWAY_Y - 1.5) / 2, -45),
			CONCRETE_COLOR
		).Parent =
			model
	end
	model.Parent = parent
end
local function buildHelipad(parent: Instance, name: string, x: number, z: number, baseY: number)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(x, baseY, z)
	makePart("Pad", Vector3.new(40, 0.4, 40), base * CFrame.new(0, 0.2, 0), CONCRETE_COLOR).Parent =
		model
	-- Painted H: two uprights and a crossbar, a hair above the pad so they never z-fight.
	makePart("H", Vector3.new(3, 0.1, 20), base * CFrame.new(-8, 0.45, 0), PAINT_COLOR).Parent =
		model
	makePart("H", Vector3.new(3, 0.1, 20), base * CFrame.new(8, 0.45, 0), PAINT_COLOR).Parent =
		model
	makePart("H", Vector3.new(13, 0.1, 3), base * CFrame.new(0, 0.45, 0), PAINT_COLOR).Parent =
		model
	makePart("Ring", Vector3.new(44, 0.1, 2), base * CFrame.new(0, 0.45, 21), PAINT_COLOR).Parent =
		model
	makePart("Ring", Vector3.new(44, 0.1, 2), base * CFrame.new(0, 0.45, -21), PAINT_COLOR).Parent =
		model
	makePart("Ring", Vector3.new(2, 0.1, 44), base * CFrame.new(21, 0.45, 0), PAINT_COLOR).Parent =
		model
	makePart("Ring", Vector3.new(2, 0.1, 44), base * CFrame.new(-21, 0.45, 0), PAINT_COLOR).Parent =
		model
	model.Parent = parent
end

local function buildRoads(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Roads"
	-- Main road north-south at x = -30 (under the highway bridge), the north road east-west
	-- at z = 200 through the Suburb. Concrete pads: the spawn apron, the Depot yard, the
	-- parade ground on its terrace.
	makePart("MainRoad", Vector3.new(16, 0.2, 600), CFrame.new(-30, 0.1, 0), ROAD_COLOR).Parent =
		model
	makePart("NorthRoad", Vector3.new(600, 0.2, 16), CFrame.new(0, 0.1, 200), ROAD_COLOR).Parent =
		model
	for z = -290, 290, 20 do
		makePart("Dash", Vector3.new(0.6, 0.1, 8), CFrame.new(-30, 0.25, z), PAINT_COLOR).Parent =
			model
	end
	for x = -290, 290, 20 do
		if math.abs(x + 30) > 12 then
			makePart("Dash", Vector3.new(8, 0.1, 0.6), CFrame.new(x, 0.25, 200), PAINT_COLOR).Parent =
				model
		end
	end
	makePart("Apron", Vector3.new(44, 0.3, 44), CFrame.new(0, 0.15, 0), CONCRETE_COLOR).Parent =
		model
	makePart("DepotPad", Vector3.new(130, 0.3, 110), CFrame.new(220, 0.15, 50), CONCRETE_COLOR).Parent =
		model
	makePart("ParadePad", Vector3.new(56, 0.3, 46), CFrame.new(-250, 6.15, 120), CONCRETE_COLOR).Parent =
		model
	model.Parent = parent
end

-- Plain-Part landmarks that need no mesh (docs/LEVELS.md): the Ridge whiteboard (story spot
-- 1), the Depot generator (Lights On prop) and the siren head on the Gate's lamp post.
local function buildLandmarks(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Landmarks"
	makePart("Whiteboard", Vector3.new(0.3, 4, 6), CFrame.new(-87, 10, 48), PAINT_COLOR).Parent =
		model
	makePart(
		"WhiteboardLegs",
		Vector3.new(0.2, 2, 4.8),
		CFrame.new(-87, 9, 48),
		Color3.fromRGB(48, 50, 54)
	).Parent =
		model
	makePart(
		"Generator",
		Vector3.new(8, 5, 4.5),
		CFrame.new(178, 2.8, -2),
		Color3.fromRGB(52, 56, 60)
	).Parent =
		model
	makePart(
		"GeneratorStack",
		Vector3.new(0.8, 3, 0.8),
		CFrame.new(175.5, 6.8, -2),
		Color3.fromRGB(40, 42, 46)
	).Parent =
		model
	local siren = makePart(
		"Siren",
		Vector3.new(1.5, 1.5, 1),
		CFrame.new(-14, 11, -264),
		Color3.fromRGB(185, 52, 52)
	)
	siren.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = siren.Color
	light.Range = 40
	light.Brightness = 2
	light.Parent = siren
	siren.Parent = model
	model.Parent = parent
end

local PATCH_LOOKS: { [string]: { Material: Enum.Material, Color: Color3 } } = {
	mud = { Material = Enum.Material.Mud, Color = Color3.fromRGB(70, 60, 48) },
	rock = { Material = Enum.Material.Rock, Color = Color3.fromRGB(96, 92, 86) },
	dark = { Material = Enum.Material.Ground, Color = Color3.fromRGB(74, 68, 58) },
}

local function buildGroundPatches(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "GroundPatches"
	for index, patch in PATCHES do
		local look = PATCH_LOOKS[patch.kind]
		local part = Instance.new("Part")
		part.Name = "Patch"
		part.Size = Vector3.new(patch.w, 0.24, patch.d)
		-- Each patch a hair higher than the last, so two that overlap never share a top face.
		part.CFrame = CFrame.new(patch.x, -0.04 + index * 0.003, patch.z)
			* CFrame.Angles(0, math.rad(patch.yaw or 0), 0)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = look.Material
		part.Color = look.Color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	model.Parent = parent
end

local RAMP_COLOR = Color3.fromRGB(110, 88, 60)

local function buildPerches(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Perches"
	local tanStair = math.tan(math.rad(Config.Arena.Kit.StairAngle))
	for _, ramp in RAMPS do
		local length = ramp.length or ramp.rise / tanStair
		local part = makePart(
			"PalletRamp",
			Vector3.new(6, ramp.rise, length),
			CFrame.new(ramp.x, ramp.base + ramp.rise / 2, ramp.z)
				* CFrame.Angles(0, math.rad(ramp.yaw), 0),
			RAMP_COLOR,
			"WedgePart"
		)
		part.Material = Enum.Material.WoodPlanks
		part.CastShadow = false
		part.Parent = model
	end
	-- The Shelf: a concrete block on the Compound's lower tier east of the hold zone, top 14.
	makePart("Shelf", Vector3.new(8, 6, 8), CFrame.new(78, 11, 52), CONCRETE_COLOR).Parent = model
	-- The Scrapes (A8): two Gate T-walls stand on cribbing with a 2.8 crawl gap under them
	-- (DRESSING `lift`); the cribs are plain blocks until the crib mesh is uploaded.
	for _, x in { -150, 114 } do
		for _, sx in { -1, 1 } do
			local crib = makePart(
				"Crib",
				Vector3.new(1.2, 2.8, 2.6),
				CFrame.new(x + sx * 3.2, 1.4, -274),
				RAMP_COLOR
			)
			crib.Material = Enum.Material.WoodPlanks
			crib.CastShadow = false
			crib.Parent = model
		end
	end
	model.Parent = parent
end

-- The deck gantry (A10): a steel platform over the highway deck at x 40, floor 23.5,
-- reached from the container parked beside it on the deck (its top 21.55, a Walker-high
-- step) or the truss on its west face (players). Rails on three sides, open to the container.
local GANTRY_COLOR = Color3.fromRGB(64, 66, 70)
local function buildGantry(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "DeckGantry"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local floorY = HIGHWAY_Y + 11.5
	local function steel(name: string, size: Vector3, cframe: CFrame, class: string?): BasePart
		local part = makePart(name, size, cframe, GANTRY_COLOR, class)
		part.Material = Enum.Material.DiamondPlate
		part.Parent = model
		return part
	end
	steel("Floor", Vector3.new(10, 0.6, 20), CFrame.new(40, floorY - 0.3, -45))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local leg = steel(
				"Leg",
				Vector3.new(1.2, floorY - HIGHWAY_Y, 1.2),
				CFrame.new(40 + sx * 4.3, (floorY + HIGHWAY_Y) / 2, -45 + sz * 9.3) -- inset: no face shared with the floor
			)
			leg.Material = Enum.Material.Metal
		end
	end
	steel("Rail", Vector3.new(0.3, 1.2, 20), CFrame.new(35.15, floorY + 0.6, -45))
	steel("Rail", Vector3.new(10, 1.2, 0.3), CFrame.new(40, floorY + 0.6, -54.85))
	steel("Rail", Vector3.new(10, 1.2, 0.3), CFrame.new(40, floorY + 0.6, -35.15))
	local truss =
		steel("Ladder", Vector3.new(2, 14, 2), CFrame.new(34, HIGHWAY_Y + 7, -45), "TrussPart")
	truss.Material = Enum.Material.Metal
	truss.CollisionGroup = "Ladder"
	model.Parent = parent
end

-- ---------------------------------------------------------------- the perimeter
-- docs/LEVELS.md A15 (level designer). The owner: "get rid of the sense of the
-- map being walled off and closed in." The four 24-stud concrete walls are gone. What the
-- squad sees at the edge is the quarantine fence (chain-link with wire on top) and its
-- towers, and the world carries on past it: dust ground to 700 out, an earth berm on the
-- west, the highway running on and breaking off to the east and west, the road south to the
-- burning city with a queue of abandoned traffic, sparse ruins to the north, then fog and
-- the DistantCity ring. What stops them is an invisible collider just behind the fence
-- (BoundaryHeight tall; bullets, the camera and the vault/climb checks pass through it).
-- Everything past the fence is `decor` (no collision, no queries, no shadow) and lives in
-- the Persistent "Perimeter" model so the far fence never streams out.

local DECOR_DUST = Color3.fromRGB(94, 88, 76)

-- A plain Part with no collision, no queries and no shadow: scenery past the fence.
local function decorPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	class: string?
)
	local part = makePart(name, size, cframe, color, class)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function buildPerimeter(arena: Instance)
	-- The scenery is its own Persistent model beside TestArena, not inside it: it is a few
	-- hundred meshes placed after boot, and inside TestArena it held back the floor's
	-- replication, so the first character spawned with no ground under it and fell.
	local model = Instance.new("Model")
	model.Name = "Perimeter"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- What stops the squad: invisible walls just behind the fence (inner face at 300).
	local height = Config.Arena.BoundaryHeight
	for _, side in
		{
			{
				name = "BoundaryPosX",
				size = Vector3.new(2, height, 640),
				at = Vector3.new(HALF + 1, height / 2, 0),
			},
			{
				name = "BoundaryNegX",
				size = Vector3.new(2, height, 640),
				at = Vector3.new(-HALF - 1, height / 2, 0),
			},
			{
				name = "BoundaryPosZ",
				size = Vector3.new(640, height, 2),
				at = Vector3.new(0, height / 2, HALF + 1),
			},
			{
				name = "BoundaryNegZ",
				size = Vector3.new(640, height, 2),
				at = Vector3.new(0, height / 2, -HALF - 1),
			},
		}
	do
		local wall = makePart(side.name, side.size, CFrame.new(side.at), WALL_COLOR)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Parent = arena -- the boundary is part of the arena itself
	end
	-- The ground carries on to 700 out (the play floor is 600 x 600).
	decorPart(
		model,
		"OuterGroundN",
		Vector3.new(1400, 1, 400),
		CFrame.new(0, -0.5, 500),
		DECOR_DUST
	)
	decorPart(
		model,
		"OuterGroundS",
		Vector3.new(1400, 1, 400),
		CFrame.new(0, -0.5, -500),
		DECOR_DUST
	)
	decorPart(model, "OuterGroundE", Vector3.new(400, 1, 600), CFrame.new(500, -0.5, 0), DECOR_DUST)
	decorPart(
		model,
		"OuterGroundW",
		Vector3.new(400, 1, 600),
		CFrame.new(-500, -0.5, 0),
		DECOR_DUST
	)
	-- The road south out of the Gate to the city.
	decorPart(model, "CityRoad", Vector3.new(24, 0.2, 400), CFrame.new(-30, 0.1, -500), ROAD_COLOR)
	-- West: an earth berm behind the fence (up 0 -> 10 over x -304..-324, crest to -330,
	-- down to -350), in two runs with a gap where the highway runs out; a fill block levels
	-- the Pens terrace (6) out to the berm.
	for _, run in { { z0 = -30, z1 = 300 }, { z0 = -300, z1 = -60 } } do
		local length = run.z1 - run.z0
		local zc = (run.z0 + run.z1) / 2
		decorPart(
			model,
			"BermFace",
			Vector3.new(length, 10, 20),
			CFrame.new(-314, 5, zc) * CFrame.Angles(0, math.rad(90), 0),
			HILL_COLOR,
			"WedgePart"
		)
		decorPart(
			model,
			"BermCrest",
			Vector3.new(6, 10, length),
			CFrame.new(-327, 5, zc),
			HILL_COLOR
		)
		decorPart(
			model,
			"BermBack",
			Vector3.new(length, 10, 20),
			CFrame.new(-340, 5, zc) * CFrame.Angles(0, math.rad(-90), 0),
			SLOPE_COLOR,
			"WedgePart"
		)
	end
	decorPart(model, "PensFill", Vector3.new(12, 6, 74), CFrame.new(-306, 3, 120), HILL_COLOR)
	-- The highway runs on past the fence both ways and breaks off: embankment, asphalt and
	-- one fallen deck slab at each end.
	for _, sx in { -1, 1 } do
		local cx = sx * 350
		decorPart(
			model,
			"HighwayRunOn",
			Vector3.new(100, 12, 18),
			CFrame.new(cx, 6, -45),
			HILL_COLOR
		)
		-- its embankment slopes (14.4 deep, as HighwayWest / HighwayEast)
		decorPart(
			model,
			"HighwayRunOnSlopeS",
			Vector3.new(100, 12, 14.4),
			CFrame.new(cx, 6, -61.2),
			SLOPE_COLOR,
			"WedgePart"
		)
		decorPart(
			model,
			"HighwayRunOnSlopeN",
			Vector3.new(100, 12, 14.4),
			CFrame.new(cx, 6, -28.8) * CFrame.Angles(0, math.rad(180), 0),
			SLOPE_COLOR,
			"WedgePart"
		)
		decorPart(
			model,
			"HighwayRunOnRoad",
			Vector3.new(100, 0.2, 14),
			CFrame.new(cx, 12.1, -45),
			ROAD_COLOR
		)
		decorPart(
			model,
			"HighwayFallenSlab",
			Vector3.new(30, 1.5, 18),
			CFrame.new(sx * 413, 6, -45) * CFrame.Angles(0, 0, math.rad(sx * 24)),
			CONCRETE_COLOR
		)
	end
	model.Parent = workspace
	return model
end

local colliderCount = 0 -- invisible collider Parts placed (Config.Arena.ColliderBudget)
local skippedMeshes: { string } = {} -- registered pieces without an asset id yet

-- Places one dressing piece on whatever ground is under it. A piece with composite colliders
-- becomes an atomic Model (mesh + its collider Parts stream together). The folder sits
-- beside TestArena in the workspace, not inside it: a Persistent model's descendants never
-- stream out, and these are the pieces streaming is for.
local function placePiece(folder: Folder, params: RaycastParams, entry: Dressing): BasePart?
	local name, x, z, yaw = entry.name, entry.x, entry.z, entry.yaw
	if not MeshAssets.isUploaded(name) then
		if not table.find(skippedMeshes, name) then
			table.insert(skippedMeshes, name)
		end
		return nil
	end
	-- Templates build asynchronously at boot; wait for each (nil = skip, ground stays bare).
	local part = MeshAssets.waitFor(name, 20)
	if not part then
		return nil
	end
	local groundY: number
	if entry.floor ~= nil then
		groundY = entry.floor
	else
		local hit = workspace:Raycast(Vector3.new(x, 100, z), Vector3.new(0, -200, 0), params)
		groundY = if hit then hit.Position.Y else 0
		-- A piece is placed from one raycast at its centre, so one whose footprint crosses
		-- a hill embankment sinks on the uphill side or floats on the downhill side. Check
		-- the four corners and say so at boot (the Blender view, assets/3d/build/delta_map.py,
		-- paints the same pieces red): the fix is always to move the entry.
		local rotation = CFrame.Angles(0, math.rad(yaw), 0)
		local low, high = groundY, groundY
		for _, corner in
			{
				Vector3.new(-1, 0, -1),
				Vector3.new(1, 0, -1),
				Vector3.new(1, 0, 1),
				Vector3.new(-1, 0, 1),
			}
		do
			local offset = rotation:VectorToWorldSpace(corner * part.Size / 2)
			local cornerHit = workspace:Raycast(
				Vector3.new(x + offset.X, 100, z + offset.Z),
				Vector3.new(0, -200, 0),
				params
			)
			local y = if cornerHit then cornerHit.Position.Y else 0
			low, high = math.min(low, y), math.max(high, y)
		end
		if high - low > Config.Arena.StraddleTolerance and not entry.decor and not entry.perch then
			warn(
				`[ArenaService] {name} at ({x}, {z}) straddles a slope (ground {low} .. {high}): move it`
			)
		end
	end
	part.Name = name
	part.CFrame = CFrame.new(x, groundY + part.Size.Y / 2 + (entry.lift or 0), z)
		* CFrame.Angles(0, math.rad(yaw), 0)
	if entry.shadow ~= nil then
		part.CastShadow = entry.shadow
	end
	if entry.decor then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		return part
	end
	local added = MeshAssets.addColliders(part, name, entry.shell)
	if added > 0 then
		colliderCount += added
		local model = Instance.new("Model")
		model.Name = name
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = folder
	else
		part.Parent = folder
	end
	if entry.burning then
		SkyService.burn(part)
	end
	return part
end

local function placeFence(folder: Instance, params: RaycastParams, panel: FencePanel)
	local rotation = CFrame.Angles(0, math.rad(panel.yaw), 0)
	local half = rotation:VectorToWorldSpace(Vector3.new(FENCE_STEP / 2, 0, 0))
	local ground = math.huge
	for _, offset in { -half, Vector3.zero, half } do
		local hit = workspace:Raycast(
			Vector3.new(panel.x + offset.X, 100, panel.z + offset.Z),
			Vector3.new(0, -200, 0),
			params
		)
		ground = math.min(ground, if hit then hit.Position.Y else 0)
	end
	local fence = MeshAssets.waitFor("prop_chainlink_panel", 20)
	local wire = MeshAssets.waitFor("prop_concertina", 20)
	if fence then
		fence.CFrame = CFrame.new(panel.x, ground + fence.Size.Y / 2, panel.z) * rotation
		fence.Parent = folder
	end
	if wire then
		local top = ground + (if fence then fence.Size.Y else 7)
		wire.CFrame = CFrame.new(panel.x, top + wire.Size.Y / 2, panel.z) * rotation
		wire.CastShadow = false
		wire.Parent = folder
	end
end

local function placeDressing()
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	for _, entry in DRESSING do
		placePiece(folder, params, entry)
	end
	-- The perimeter (A15): fence, roadblocks and the scenery past it, always loaded.
	local perimeter = workspace:FindFirstChild("Perimeter")
	if perimeter then
		local perimeterParams = RaycastParams.new()
		perimeterParams.FilterType = Enum.RaycastFilterType.Exclude
		perimeterParams.FilterDescendantsInstances = { folder, perimeter }
		for _, entry in PERIMETER do
			placePiece(perimeter :: any, perimeterParams, entry)
		end
		for _, panel in FENCE do
			placeFence(perimeter, perimeterParams, panel)
		end
	end
	if #skippedMeshes > 0 then
		print(
			`[ArenaService] {#skippedMeshes} dressing meshes await upload (skipped): {table.concat(
				skippedMeshes,
				", "
			)}`
		)
	end
	print(
		`[ArenaService] dressing placed: {#folder:GetChildren()} pieces, {colliderCount} colliders`
	)
	if colliderCount > Config.Arena.ColliderBudget then
		warn(
			`[ArenaService] {colliderCount} composite colliders exceed the budget of {Config.Arena.ColliderBudget} (docs/LEVELS.md A8)`
		)
	end
end

local spawnPads: { [number]: SpawnLocation } = {}

-- ---------------------------------------------------------------- building kit
-- buildBuilding(spec) (docs/LEVELS.md section B): enterable buildings from plain
-- anchored Parts on the Config.Arena.Kit grid (storey 9, slab 0.6: 8.4 clear, so a 2x Brute
-- fits only in rooms built taller). Walls are solid spans between openings (door 4 x 8,
-- window 5 wide at sill 3.2 / head 8.6, breach, gap); every upper floor gets a slab; a
-- WedgePart stair flight (~33 degrees) cuts a head-clearance hole in the slab it reaches; a
-- flat roof with a 1.2 parapet; a climb lip (cornice) outside every upper floor no higher
-- than ClimbMaxHeight so the floor is mantled from the street and entered by a window;
-- TrussPart ladders (Ladder collision group: players only) with a gap in the parapet and
-- the lips where they land. Each building is one atomic Model; its footprint is kept for
-- the spawn filter and the Infected's vertical chase (EnemyService).
-- Literal strings (not literal types: nested table literals infer `string` in the old solver).
type Rect = { x0: number, x1: number, z0: number, z1: number }
type Footprint = { name: string, frame: CFrame, halfWidth: number, halfDepth: number, top: number }
type Look = { Material: Enum.Material, Color: Color3 }

local footprints: { Footprint } = {}
local buildingPartCount = 0

local function kitMaterial(key: string): Look
	local materials = Config.Arena.Materials :: { [string]: Look }
	return materials[key] or materials.concrete
end

-- Cuts `hole` out of every rect in `pieces` (up to four strips each).
local function subtractRect(pieces: { Rect }, hole: Rect): { Rect }
	local result: { Rect } = {}
	for _, piece in pieces do
		local x0, x1 = math.max(piece.x0, hole.x0), math.min(piece.x1, hole.x1)
		local z0, z1 = math.max(piece.z0, hole.z0), math.min(piece.z1, hole.z1)
		if x0 >= x1 or z0 >= z1 then
			table.insert(result, piece)
			continue
		end
		if piece.x0 < x0 then
			table.insert(result, { x0 = piece.x0, x1 = x0, z0 = piece.z0, z1 = piece.z1 })
		end
		if x1 < piece.x1 then
			table.insert(result, { x0 = x1, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1 })
		end
		if piece.z0 < z0 then
			table.insert(result, { x0 = x0, x1 = x1, z0 = piece.z0, z1 = z0 })
		end
		if z1 < piece.z1 then
			table.insert(result, { x0 = x0, x1 = x1, z0 = z1, z1 = piece.z1 })
		end
	end
	return result
end

local function isAlongX(side: Side): boolean
	return side == "south" or side == "north"
end

local function buildBuilding(parent: Instance, spec: BuildingSpec): Model
	local kit = Config.Arena.Kit
	local H = spec.storeyHeight or kit.Storey
	local T = kit.WallThickness
	local hw, hd = spec.width / 2, spec.depth / 2
	local material = kitMaterial(spec.material)
	local slabMaterial = kitMaterial("slab")
	local roofMaterial = kitMaterial("roof")
	-- Built after the arena is in the workspace, so the raycast finds hills and roofs.
	local hit = workspace:Raycast(Vector3.new(spec.x, 100, spec.z), Vector3.new(0, -200, 0))
	local baseY = if hit then hit.Position.Y else 0
	local frame = CFrame.new(spec.x, baseY, spec.z) * CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
	local model = Instance.new("Model")
	model.Name = spec.name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local count = 0

	local function place(
		name: string,
		size: Vector3,
		localCFrame: CFrame,
		look: Look,
		class: string?,
		shadow: boolean?
	): BasePart
		local part = Instance.new((class or "Part") :: any) :: BasePart
		part.Name = name
		part.Size = size
		part.CFrame = frame * localCFrame
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.Material = look.Material
		part.Color = look.Color
		part.CastShadow = shadow ~= false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		count += 1
		return part
	end

	-- The inner face of an outer wall, and the direction out of the building from it.
	local function wallInner(side: Side): number
		if side == "south" then
			return -hd + T
		elseif side == "north" then
			return hd - T
		elseif side == "east" then
			return hw - T
		end
		return -hw + T
	end
	local function outward(side: Side): number
		return if side == "south" or side == "west" then -1 else 1
	end

	-- One horizontal run: `axis` is its along direction, `pos` its centre on the other axis,
	-- `centre` the along-centre, `length` its span, `thick` its size across. Solid spans
	-- between the openings (a wall, a parapet, a climb lip).
	local function run(
		name: string,
		axis: "x" | "z",
		pos: number,
		centre: number,
		length: number,
		y0: number,
		height: number,
		thick: number,
		openings: { Opening },
		look: Look,
		shadow: boolean?
	)
		local function segment(u0: number, u1: number, yb: number, yt: number)
			if u1 - u0 < 0.05 or yt - yb < 0.05 then
				return
			end
			local uc, yc, h = (u0 + u1) / 2, (yb + yt) / 2, yt - yb
			if axis == "x" then
				place(
					name,
					Vector3.new(u1 - u0, h, thick),
					CFrame.new(uc, yc, pos),
					look,
					nil,
					shadow
				)
			else
				place(
					name,
					Vector3.new(thick, h, u1 - u0),
					CFrame.new(pos, yc, uc),
					look,
					nil,
					shadow
				)
			end
		end
		local sorted = table.clone(openings)
		table.sort(sorted, function(a, b)
			return a.at < b.at
		end)
		local cursor = centre - length / 2
		for _, opening in sorted do
			local width = opening.width
				or (if opening.kind == "door" then kit.Door.Width else kit.Window.Width)
			local u0, u1 = centre + opening.at - width / 2, centre + opening.at + width / 2
			segment(cursor, u0, y0, y0 + height)
			if opening.kind == "door" then
				segment(u0, u1, y0 + (opening.head or kit.Door.Height), y0 + height)
			elseif opening.kind == "window" then
				segment(u0, u1, y0, y0 + (opening.sill or kit.Window.Sill))
				segment(u0, u1, y0 + (opening.head or kit.Window.Head), y0 + height)
			elseif opening.kind == "breach" then
				segment(u0, u1, y0 + (opening.head or kit.Breach.Height), y0 + height)
			end
			cursor = math.max(cursor, u1)
		end
		segment(cursor, centre + length / 2, y0, y0 + height)
	end
	local function wall(
		axis: "x" | "z",
		pos: number,
		centre: number,
		length: number,
		y0: number,
		openings: { Opening }
	)
		run("Wall", axis, pos, centre, length, y0, H, T, openings, material)
	end

	-- Outer walls per storey. Side walls stop short of the corners the end walls fill.
	for storey = 1, spec.storeys do
		local y0 = (storey - 1) * H
		local openings: { [string]: { Opening } } = spec.walls[storey] or {}
		wall("x", -hd + T / 2, 0, spec.width, y0, openings.south or {})
		wall("x", hd - T / 2, 0, spec.width, y0, openings.north or {})
		wall("z", hw - T / 2, 0, spec.depth - 2 * T, y0, openings.east or {})
		wall("z", -hw + T / 2, 0, spec.depth - 2 * T, y0, openings.west or {})
	end
	local interior: { InteriorWall } = spec.interior or {}
	for _, inner in interior do
		wall(
			if inner.along == "x" then "x" else "z",
			inner.at,
			(inner.from + inner.to) / 2,
			inner.to - inner.from,
			(inner.storey - 1) * H,
			inner.openings or {}
		)
	end

	-- Holes the slabs must leave open (stair head clearance, inside ladders), and the gaps
	-- the parapet and the lips leave where an outside ladder lands.
	local holes: { { rect: Rect, level: number } } = {}
	local gaps: { [string]: { Opening } } = { south = {}, north = {}, east = {}, west = {} }
	local tanStair = math.tan(math.rad(kit.StairAngle))
	local stairs: { StairSpec } = spec.stairs or {}
	for _, stair in stairs do
		local y0 = (stair.storey - 1) * H
		local rise = stair.rise or H
		local length = rise / tanStair
		local inner = wallInner(stair.side)
		local across = inner - outward(stair.side) * kit.StairWidth / 2
		local along = stair.at + stair.dir * length / 2
		-- A WedgePart rises from its -Z edge to its +Z face: yaw it so +Z points along `dir`.
		local yaw: number
		if isAlongX(stair.side) then
			yaw = if stair.dir > 0 then 90 else -90
		else
			yaw = if stair.dir > 0 then 0 else 180
		end
		local centre = if isAlongX(stair.side)
			then CFrame.new(along, y0 + rise / 2, across)
			else CFrame.new(across, y0 + rise / 2, along)
		place(
			"Stairs",
			Vector3.new(kit.StairWidth, rise, length),
			centre * CFrame.Angles(0, math.rad(yaw), 0),
			slabMaterial,
			"WedgePart"
		)
		-- Head clearance: from where the climber's head would meet the slab to the top edge.
		local clearStart = math.max((rise - kit.Slab - Config.Movement.Headroom) / tanStair, 0)
		local u0 = stair.at + stair.dir * clearStart
		local u1 = stair.at + stair.dir * (length + 0.2)
		local v0 = inner - outward(stair.side) * (kit.StairWidth + 0.5)
		local rect: Rect = if isAlongX(stair.side)
			then {
				x0 = math.min(u0, u1),
				x1 = math.max(u0, u1),
				z0 = math.min(inner, v0),
				z1 = math.max(inner, v0),
			}
			else {
				x0 = math.min(inner, v0),
				x1 = math.max(inner, v0),
				z0 = math.min(u0, u1),
				z1 = math.max(u0, u1),
			}
		table.insert(holes, { rect = rect, level = y0 + rise })
	end
	local ladders: { LadderSpec } = spec.ladders or {}
	for _, ladder in ladders do
		local bottom = ladder.bottom or 0
		-- Truss sizes are multiples of 2; it pokes above the roof (and parapet) so the
		-- climber tops out standing.
		local length = math.ceil((ladder.top + kit.Parapet - bottom) / 2) * 2
		local inner = wallInner(ladder.side)
		local out = outward(ladder.side)
		local across = if ladder.inside then inner - out * 1 else inner + out * (T + 1)
		local centre = if isAlongX(ladder.side)
			then CFrame.new(ladder.at, bottom + length / 2, across)
			else CFrame.new(across, bottom + length / 2, ladder.at)
		local truss = place(
			"Ladder",
			Vector3.new(2, length, 2),
			centre,
			kitMaterial("ladder"),
			"TrussPart",
			false
		)
		truss.CollisionGroup = "Ladder"
		if ladder.inside then
			-- The climber's column next to the truss, open through every slab it passes.
			local c0, c1 = inner - out * 2, inner - out * 4.6
			local rect: Rect = if isAlongX(ladder.side)
				then {
					x0 = ladder.at - 1.3,
					x1 = ladder.at + 1.3,
					z0 = math.min(c0, c1),
					z1 = math.max(c0, c1),
				}
				else {
					x0 = math.min(c0, c1),
					x1 = math.max(c0, c1),
					z0 = ladder.at - 1.3,
					z1 = ladder.at + 1.3,
				}
			for level = H, ladder.top + 0.01, H do
				if level > bottom then
					table.insert(holes, { rect = rect, level = level })
				end
			end
		else
			table.insert(gaps[ladder.side], { kind = "gap", at = ladder.at, width = kit.LadderGap })
		end
	end

	local function slab(name: string, rect: Rect, top: number, look: Look)
		local pieces: { Rect } = { rect }
		for _, hole in holes do
			if math.abs(hole.level - top) < 0.01 then
				pieces = subtractRect(pieces, hole.rect)
			end
		end
		for _, piece in pieces do
			place(
				name,
				Vector3.new(piece.x1 - piece.x0, kit.Slab, piece.z1 - piece.z0),
				CFrame.new((piece.x0 + piece.x1) / 2, top - kit.Slab / 2, (piece.z0 + piece.z1) / 2),
				look
			)
		end
	end

	-- Slab edges never sit flush with the wall faces (a shared face flickers): floors stop
	-- just inside the walls, the roof overhangs them as an eave.
	local inset: Rect = { x0 = -hw + 0.05, x1 = hw - 0.05, z0 = -hd + 0.05, z1 = hd - 0.05 }
	local EAVE = 0.3
	local eaves: Rect = { x0 = -hw - EAVE, x1 = hw + EAVE, z0 = -hd - EAVE, z1 = hd + EAVE }
	for storey = 2, spec.storeys do
		slab("Floor", inset, (storey - 1) * H, slabMaterial)
	end
	local mezzanines: { Mezzanine } = spec.mezzanines or {}
	for _, mezzanine in mezzanines do
		slab(
			"Mezzanine",
			{ x0 = mezzanine.x0, x1 = mezzanine.x1, z0 = mezzanine.z0, z1 = mezzanine.z1 },
			mezzanine.level,
			slabMaterial
		)
		local rail = mezzanine.rail
		if rail then
			local y = mezzanine.level + kit.Parapet / 2
			if isAlongX(rail) then
				local z = if rail == "north" then mezzanine.z1 - 0.15 else mezzanine.z0 + 0.15
				place(
					"Rail",
					Vector3.new(mezzanine.x1 - mezzanine.x0, kit.Parapet, 0.3),
					CFrame.new((mezzanine.x0 + mezzanine.x1) / 2, y, z),
					material,
					nil,
					false
				)
			else
				local x = if rail == "east" then mezzanine.x1 - 0.15 else mezzanine.x0 + 0.15
				place(
					"Rail",
					Vector3.new(0.3, kit.Parapet, mezzanine.z1 - mezzanine.z0),
					CFrame.new(x, y, (mezzanine.z0 + mezzanine.z1) / 2),
					material,
					nil,
					false
				)
			end
		end
	end
	local top = spec.storeys * H
	if spec.roof ~= false then
		slab("Roof", eaves, top, roofMaterial)
		if spec.parapet ~= false then
			local p = kit.Parapet
			run("Parapet", "x", -hd + T / 2, 0, spec.width, top, p, T, gaps.south, material, false)
			run("Parapet", "x", hd - T / 2, 0, spec.width, top, p, T, gaps.north, material, false)
			run(
				"Parapet",
				"z",
				hw - T / 2,
				0,
				spec.depth - 2 * T,
				top,
				p,
				T,
				gaps.east,
				material,
				false
			)
			run(
				"Parapet",
				"z",
				-hw + T / 2,
				0,
				spec.depth - 2 * T,
				top,
				p,
				T,
				gaps.west,
				material,
				false
			)
		end
	end
	-- Climb lips: a cornice outside each upper floor the body can mantle from the street.
	if spec.lips ~= false then
		for storey = 2, spec.storeys do
			local level = (storey - 1) * H
			if level > kit.LipMaxHeight then
				break
			end
			local d = kit.LipDepth
			local y0 = level - kit.Slab
			run(
				"Lip",
				"x",
				-hd - d / 2,
				0,
				spec.width + 2 * d,
				y0,
				kit.Slab,
				d,
				gaps.south,
				material,
				false
			)
			run(
				"Lip",
				"x",
				hd + d / 2,
				0,
				spec.width + 2 * d,
				y0,
				kit.Slab,
				d,
				gaps.north,
				material,
				false
			)
			run("Lip", "z", hw + d / 2, 0, spec.depth, y0, kit.Slab, d, gaps.east, material, false)
			run("Lip", "z", -hw - d / 2, 0, spec.depth, y0, kit.Slab, d, gaps.west, material, false)
		end
	end
	local extras: { Extra } = spec.extras or {}
	for _, extra in extras do
		place(
			extra.name,
			extra.size,
			CFrame.new(extra.at) * CFrame.Angles(0, math.rad(extra.yaw or 0), 0),
			kitMaterial(extra.material or spec.material),
			extra.class
		)
	end

	model.Parent = parent
	buildingPartCount += count
	table.insert(footprints, {
		name = spec.name,
		frame = frame,
		halfWidth = hw + kit.LipDepth,
		halfDepth = hd + kit.LipDepth,
		top = baseY + top + kit.Parapet,
	})
	return model
end

-- True when `position` lies within `margin` studs of a building footprint (any height).
function ArenaService.insideBuilding(position: Vector3, margin: number?): boolean
	local pad = margin or 0
	for _, footprint in footprints do
		local localPosition = footprint.frame:PointToObjectSpace(position)
		if
			math.abs(localPosition.X) <= footprint.halfWidth + pad
			and math.abs(localPosition.Z) <= footprint.halfDepth + pad
		then
			return true
		end
	end
	return false
end

-- Flat distance from `position` to the nearest building footprint (0 inside one).
function ArenaService.buildingDistance(position: Vector3): number
	local best = math.huge
	for _, footprint in footprints do
		local localPosition = footprint.frame:PointToObjectSpace(position)
		local dx = math.max(math.abs(localPosition.X) - footprint.halfWidth, 0)
		local dz = math.max(math.abs(localPosition.Z) - footprint.halfDepth, 0)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- Kit buildings go in workspace.Buildings, beside the arena (same reason as Dressing).
local function buildBuildings()
	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = workspace
	for _, spec in BUILDINGS do
		buildBuilding(folder, spec)
	end
	print(`[ArenaService] buildings: {#BUILDINGS} models, {buildingPartCount} parts`)
end

-- The SpawnLocation for squad slot `index` (players' RespawnLocation).
function ArenaService.getSpawnLocation(index: number): SpawnLocation?
	return spawnPads[((index - 1) % #Config.Run.SpawnPads) + 1]
end

-- The landing pad for squad slot `index` (1..4): a standing CFrame on the LZ helipad,
-- facing the middle of the arena.
function ArenaService.getSpawnPad(index: number): CFrame
	local pads = Config.Run.SpawnPads
	local offset = pads[((index - 1) % #pads) + 1]
	local lz = Config.Extraction.ZonePosition
	local position = Vector3.new(lz.X + offset.X, 3.5, lz.Z + offset.Z)
	local toward = Vector3.new(-position.X, 0, -position.Z)
	if toward.Magnitude < 0.01 then
		toward = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAlong(position, toward.Unit)
end

function ArenaService.init()
	if workspace:FindFirstChild("TestArena") then
		return
	end
	-- Ladders (TrussPart colliders) are climbable by players only: the Infected pass
	-- through them. Both groups are registered here (EnemyService registers Enemy too).
	for _, group in { "Enemy", "Ladder" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("Ladder", "Enemy", false)

	-- The default Baseplate would z-fight (flash) with our floor, so it goes, but not at
	-- once: in Studio the first player is already standing on it when scripts start, and
	-- its removal reached the client before the much larger arena did, so that body fell
	-- through the world and the run began wiped. Hidden now, solid for BaseplateGrace
	-- seconds while the arena replicates, then destroyed.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanQuery = false
		baseplate.CastShadow = false
		local textures = baseplate:FindFirstChildWhichIsA("Texture")
		if textures then
			textures:Destroy()
		end
		task.delay(BASEPLATE_GRACE, function()
			baseplate:Destroy()
		end)
	elseif baseplate then
		baseplate:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "TestArena"
	-- Streaming (default.project.json Workspace): the terrain, roads, hills, perches and
	-- spawn pads in here are always present on every client. Buildings and dressing live
	-- in workspace.Buildings / workspace.Dressing beside this model (a Persistent model's
	-- descendants never stream out); their atomic Models stream as wholes by distance.
	arena.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- Floor: top surface at y=0 (ground raycasts and spawns assume it).
	makePart("Floor", Vector3.new(HALF * 2, 1, HALF * 2), CFrame.new(0, -0.5, 0), GROUND_COLOR).Parent =
		arena

	buildRoads(arena)
	for _, hill in HILLS do
		buildHill(arena, hill)
	end
	buildHighway(arena)
	-- The LZ: insert and extract (Config.Extraction.ZonePosition). The Depot's alternate pad
	-- sits on the DepotPad concrete (top 0.3).
	local lz = Config.Extraction.ZonePosition
	buildHelipad(arena, "Helipad", lz.X, lz.Z, 0)
	buildHelipad(arena, "AltHelipad", 255, 85, 0.3)
	buildLandmarks(arena)
	buildGroundPatches(arena)
	buildPerches(arena)
	buildGantry(arena)

	-- Four invisible SpawnLocations on the LZ, one per squad slot (Config.Run.SpawnPads).
	-- Squad points each player's RespawnLocation at their own pad, so the engine lands them
	-- there; a stray SpawnLocation from the place file is disabled.
	for _, stray in workspace:GetDescendants() do
		if stray:IsA("SpawnLocation") then
			stray.Enabled = false
		end
	end
	for index = 1, #Config.Run.SpawnPads do
		local pad = Instance.new("SpawnLocation")
		pad.Name = "SpawnPad" .. index
		pad.Neutral = true
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.Transparency = 1
		pad.Duration = 0 -- no spawn forcefield
		pad.Size = Vector3.new(4, 0.2, 4)
		pad.CFrame = ArenaService.getSpawnPad(index) - Vector3.new(0, 2.9, 0)
		pad.Parent = arena
		spawnPads[index] = pad
	end

	buildPerimeter(arena)

	arena.Parent = workspace
	buildBuildings() -- after parenting: the kit raycasts the hills (and the church roof)
	task.spawn(placeDressing)
end

return ArenaService
