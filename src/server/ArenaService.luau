--!strict
-- Stage 1: "Checkpoint Delta". An overrun quarantine checkpoint laid out like a Risk of
-- Rain 2 stage: open ground with two raised hills (walkable embankments on every side, so
-- the Infected, who have no pathfinding, can always climb to the player), a landmark comm
-- tower on the high ground, roads for orientation, and the objective on the hill.
-- Terrain is plain Parts (exact collision, no mesh cost); dressing is MeshAssets templates
-- placed by raycast onto whatever ground is under them. Every piece is built against the
-- 5-stud character (assets/3d/build/build_assets.py scale constants).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local ArenaService = {}

local HALF = 150 -- half-extent: arena spans -150..+150 on X/Z (300 studs)
local WALL_HEIGHT = 24
local WALL_THICKNESS = 3

-- Dusty ground, asphalt roads, concrete pads: the muted "field-kit" palette (docs/STYLES.md).
local GROUND_COLOR = Color3.fromRGB(94, 88, 76)
local ROAD_COLOR = Color3.fromRGB(58, 60, 64)
local CONCRETE_COLOR = Color3.fromRGB(122, 120, 114)
local HILL_COLOR = Color3.fromRGB(102, 96, 78)
local SLOPE_COLOR = Color3.fromRGB(82, 74, 60)
local WALL_COLOR = Color3.fromRGB(104, 100, 92)
local PAINT_COLOR = Color3.fromRGB(214, 214, 208)

-- Raised plateaus. `top` is the flat size (X, Z), `height` the rise above `base` (default
-- y=0, so tiers stack). Each side gets a wedge embankment `height * 1.2` studs deep (~40
-- degrees, easy for Humanoids) unless listed in `open` (a vertical face: an arena wall or a
-- bridge abutment); corners next to a closed side get solid blocks.
-- Levels in play: ground 0, Ridge/Compound 8, highway 12, Overlook 14, Compound upper 16.
type Hill = {
	name: string,
	x: number,
	z: number,
	top: Vector2,
	height: number,
	base: number?,
	open: { [string]: boolean }?,
}
local HILLS: { Hill } = {
	-- The Compound: the objective zone (Config.Objective.ZonePosition) sits on the lower
	-- tier; the comm tower on the upper tier in its north-east corner.
	{ name = "Compound", x = 70, z = 70, top = Vector2.new(90, 90), height = 8 },
	{ name = "CompoundUpper", x = 94, z = 94, top = Vector2.new(24, 24), height = 8, base = 8 },
	-- The Ridge: the ruined barracks and a watchtower overlook the main road.
	{ name = "Ridge", x = -100, z = 45, top = Vector2.new(60, 44), height = 8 },
	-- The Overlook: a tall knoll in the south-east with a watchtower on top.
	{ name = "Overlook", x = 105, z = -105, top = Vector2.new(40, 40), height = 14 },
	-- The highway: a raised east-west embankment across the map at z = -45, broken by a
	-- bridge over the main road (x -46..-14). Vertical ends at the walls and the bridge.
	{
		name = "HighwayWest",
		x = -98,
		z = -45,
		top = Vector2.new(104, 18),
		height = 12,
		open = { east = true, west = true },
	},
	{
		name = "HighwayEast",
		x = 68,
		z = -45,
		top = Vector2.new(164, 18),
		height = 12,
		open = { east = true, west = true },
	},
}

-- Set dressing: `name` is a MeshAssets template; x/z are the piece's bounds centre; `yaw` in
-- degrees. Ground height is found by raycast, so pieces can sit on hills. Keep everything
-- clear of the spawn pad (origin), the objective hill top centre and the helipad (-90,-90),
-- and off the embankments (a piece straddling a slope floats on one side).
type Dressing = { name: string, x: number, z: number, yaw: number }
local DRESSING: { Dressing } = {
	-- The Compound lower tier (top x 25..115, z 25..115; zone 27..73; the upper tier's
	-- slopes cover x,z >= 72) and upper tier (top 82..106)
	{ name = "env_comm_tower", x = 94, z = 94, yaw = 0 },
	{ name = "env_twall", x = 84, z = 100, yaw = 90 },
	{ name = "env_twall", x = 84, z = 92, yaw = 90 },
	{ name = "env_hesco", x = 100, z = 84, yaw = 0 },
	{ name = "env_tent", x = 42, z = 104, yaw = 0 },
	{ name = "env_tent", x = 42, z = 88, yaw = 0 },
	{ name = "env_container_olive", x = 100, z = 44, yaw = 0 },
	{ name = "env_container_rust", x = 100, z = 55, yaw = 8 },
	{ name = "env_wreck_humvee", x = 62, z = 104, yaw = -30 },
	{ name = "env_sandbag_bunker", x = 86, z = 34, yaw = 180 },
	{ name = "env_hesco", x = 34, z = 40, yaw = 0 },
	{ name = "env_hesco", x = 34, z = 47, yaw = 0 },
	{ name = "env_hesco", x = 34, z = 54, yaw = 0 },
	{ name = "env_twall", x = 55, z = 34, yaw = 0 },
	{ name = "env_twall", x = 63, z = 34, yaw = 0 },
	-- The Ridge (hill top x -130..-70, z 23..67)
	{ name = "env_ruin_building", x = -104, z = 48, yaw = 0 },
	{ name = "env_guard_tower", x = -78, z = 30, yaw = 0 },
	{ name = "env_barrier_jersey", x = -82, z = 60, yaw = 20 },
	-- Main road (x = -30, north-south) and the checkpoint at its south end
	{ name = "env_checkpoint", x = -30, z = -112, yaw = 0 },
	{ name = "env_twall", x = -46, z = -112, yaw = 0 },
	{ name = "env_twall", x = -54, z = -112, yaw = 0 },
	{ name = "env_twall", x = -14, z = -112, yaw = 0 },
	{ name = "env_twall", x = -6, z = -112, yaw = 0 },
	{ name = "env_sandbag_bunker", x = -52, z = -98, yaw = 0 },
	{ name = "env_wreck_humvee", x = -27, z = 28, yaw = 15 },
	{ name = "env_container_rust", x = -8, z = -84, yaw = 70 },
	{ name = "env_container_olive", x = 30, z = -10, yaw = -15 },
	-- On the highway (ground height is found by raycast, so these sit on the deck)
	{ name = "env_wreck_humvee", x = 100, z = -45, yaw = -80 },
	{ name = "env_barrier_jersey", x = 20, z = -44, yaw = 5 },
	{ name = "env_barrier_jersey", x = -120, z = -46, yaw = -8 },
	{ name = "env_lamp_post", x = -42, z = -80, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = -20, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = 60, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = 120, yaw = 0 },
	{ name = "env_barrier_jersey", x = -24, z = 70, yaw = 10 },
	{ name = "env_barrier_jersey", x = -36, z = 100, yaw = -25 },
	{ name = "env_barrier_jersey", x = 10, z = -78, yaw = 80 },
	-- Helipad (extraction, -90,-90) and the south-west
	{ name = "env_lamp_post", x = -114, z = -114, yaw = 45 },
	{ name = "env_lamp_post", x = -66, z = -114, yaw = 135 },
	{ name = "env_lamp_post", x = -114, z = -66, yaw = -45 },
	{ name = "env_barrier_jersey", x = -60, z = -70, yaw = 45 },
	{ name = "env_hesco", x = -120, z = -40, yaw = 20 },
	{ name = "env_hesco", x = -113, z = -40, yaw = 20 },
	-- South-east corner and the eastern edge
	-- The Overlook (top x 85..125, z -125..-85)
	{ name = "env_guard_tower", x = 116, z = -116, yaw = 45 },
	{ name = "env_sandbag_bunker", x = 96, z = -96, yaw = 90 },
	{ name = "env_barrier_jersey", x = 60, z = -80, yaw = 30 },
	{ name = "env_container_olive", x = 128, z = 10, yaw = 90 },
	{ name = "env_barrier_jersey", x = 60, z = -110, yaw = 30 },
	-- Dead trees around the edges
	{ name = "env_dead_tree", x = -136, z = 110, yaw = 0 },
	{ name = "env_dead_tree", x = -60, z = 132, yaw = 70 },
	{ name = "env_dead_tree", x = 20, z = 136, yaw = 140 },
	{ name = "env_dead_tree", x = 136, z = -20, yaw = 200 },
	{ name = "env_dead_tree", x = 40, z = -136, yaw = 260 },
	{ name = "env_dead_tree", x = -136, z = -10, yaw = 320 },
	{ name = "env_dead_tree", x = 128, z = 130, yaw = 30 },
}

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
	part.Material = Enum.Material.SmoothPlastic
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
	local sides = {
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
	makePart("Road", Vector3.new(300, 0.2, 14), CFrame.new(0, HIGHWAY_Y + 0.1, -45), ROAD_COLOR).Parent =
		model
	for x = -140, 140, 20 do
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
local function buildHelipad(parent: Instance)
	local zone = Config.Extraction.ZonePosition
	local model = Instance.new("Model")
	model.Name = "Helipad"
	local base = CFrame.new(zone.X, 0, zone.Z)
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
	-- Main road north-south at x = -30, a cross road east-west at z = -45. Both stop short of
	-- the hills' embankments.
	makePart("MainRoad", Vector3.new(16, 0.2, 300), CFrame.new(-30, 0.1, 0), ROAD_COLOR).Parent =
		model
	makePart("CrossRoad", Vector3.new(300, 0.2, 16), CFrame.new(0, 0.1, -45), ROAD_COLOR).Parent =
		model
	-- Dashed centre line on the main road.
	for z = -140, 140, 20 do
		makePart("Dash", Vector3.new(0.6, 0.1, 8), CFrame.new(-30, 0.25, z), PAINT_COLOR).Parent =
			model
	end
	-- Concrete apron under the spawn pad.
	makePart("Apron", Vector3.new(44, 0.3, 44), CFrame.new(0, 0.15, 0), CONCRETE_COLOR).Parent =
		model
	model.Parent = parent
end

local function placeDressing(arena: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	folder.Parent = arena
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	for _, entry in DRESSING do
		local name, x, z, yaw = entry.name, entry.x, entry.z, entry.yaw
		-- Templates build asynchronously at boot; wait for each (nil = skip, ground stays bare).
		local part = MeshAssets.waitFor(name, 20)
		if part then
			local hit = workspace:Raycast(Vector3.new(x, 100, z), Vector3.new(0, -200, 0), params)
			local groundY = if hit then hit.Position.Y else 0
			part.Name = name
			part.CFrame = CFrame.new(x, groundY + part.Size.Y / 2, z)
				* CFrame.Angles(0, math.rad(yaw), 0)
			part.Parent = folder
		end
	end
end

function ArenaService.init()
	if workspace:FindFirstChild("TestArena") then
		return
	end

	-- Remove the default Baseplate so it can't z-fight (flash) with our floor.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "TestArena"

	-- Floor: top surface at y=0 (ground raycasts and spawns assume it).
	makePart("Floor", Vector3.new(HALF * 2, 1, HALF * 2), CFrame.new(0, -0.5, 0), GROUND_COLOR).Parent =
		arena

	buildRoads(arena)
	for _, hill in HILLS do
		buildHill(arena, hill)
	end
	buildHighway(arena)
	buildHelipad(arena)

	-- Raised spawn pad at the origin.
	makePart(
		"SpawnPad",
		Vector3.new(20, 1, 20),
		CFrame.new(0, 1.5, 0),
		Color3.fromRGB(132, 128, 120)
	).Parent =
		arena

	-- Put the player spawn on top of the pad (move existing SpawnLocation or create one).
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Neutral = true
	end
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 0.4
	spawn.Color = Color3.fromRGB(150, 200, 160)
	spawn.Position = Vector3.new(0, 2.5, 0)
	spawn.Parent = arena

	local wy = WALL_HEIGHT / 2
	local span = HALF * 2 + WALL_THICKNESS
	makePart(
		"WallPosX",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
		CFrame.new(HALF, wy, 0),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallNegX",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
		CFrame.new(-HALF, wy, 0),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallPosZ",
		Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(0, wy, HALF),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallNegZ",
		Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(0, wy, -HALF),
		WALL_COLOR
	).Parent =
		arena

	arena.Parent = workspace
	task.spawn(placeDressing, arena)
end

return ArenaService
