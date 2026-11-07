--!strict
-- Stage 1: "Checkpoint Delta". An overrun quarantine checkpoint laid out like a Risk of
-- Rain 2 stage: open ground with raised hills (walkable embankments on every side, so the
-- Infected, who have no pathfinding, can always climb to the player), a landmark comm
-- tower on the high ground, roads for orientation, and the objective on the hill. Layout
-- per docs/LEVELS.md section A (2026-11-07): insert and extract at the LZ helipad, the
-- main road south to the Gate (a T-wall line across the map with one lane, buses queued
-- inside it), the Pens as a hesco-ringed funnel site, the Overlook summit kept open.
-- Terrain is plain Parts (exact collision, no mesh cost); dressing is MeshAssets templates
-- placed by raycast onto whatever ground is under them. Every piece is built against the
-- 5-stud character (assets/3d/build/build_assets.py scale constants).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local SkyService = require(script.Parent.SkyService)

local ArenaService = {}

local HALF = 300 -- half-extent: arena spans -300..+300 on X/Z (600 studs)
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
		x = -173,
		z = -45,
		top = Vector2.new(254, 18),
		height = 12,
		open = { east = true, west = true },
	},
	{
		name = "HighwayEast",
		x = 143,
		z = -45,
		top = Vector2.new(314, 18),
		height = 12,
		open = { east = true, west = true },
	},
	-- Outer districts (the map is 600 x 600; the core above is the central 300).
	{ name = "NorthBluff", x = -230, z = 235, top = Vector2.new(56, 56), height = 10 }, -- Suburb
	{ name = "DepotMound", x = 235, z = -205, top = Vector2.new(50, 50), height = 12 }, -- Depot
	{ name = "SouthRise", x = -190, z = -235, top = Vector2.new(70, 44), height = 8 }, -- Scrapyard
	{ name = "ParadeTerrace", x = -250, z = 120, top = Vector2.new(70, 60), height = 6 }, -- the Pens
}

-- Set dressing: `name` is a MeshAssets template; x/z are the piece's bounds centre; `yaw` in
-- degrees. Ground height is found by raycast, so pieces can sit on hills. Keep everything
-- clear of the LZ helipad (-90,-90: insert and extract), the objective hill top centre, the
-- Apron (origin: boss ground) and the main road lane (x -42..-18: the Warden walks it), and
-- off the embankments (a piece straddling a slope floats on one side).
type Dressing = { name: string, x: number, z: number, yaw: number, burning: boolean? }
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
	{ name = "env_ruin_building", x = -104, z = 48, yaw = 0, burning = true },
	{ name = "env_guard_tower", x = -78, z = 30, yaw = 0 },
	{ name = "env_barrier_jersey", x = -82, z = 60, yaw = 20 },
	-- Main road (x = -30, north-south) and the Inner Gate across it at z = -112 (lane x -42..-18)
	{ name = "env_checkpoint", x = -58, z = -120, yaw = 0 },
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
	{ name = "env_barrier_jersey", x = -100, z = -116, yaw = 0 },
	{ name = "env_barrier_jersey", x = -80, z = -116, yaw = 0 },
	{ name = "env_hesco", x = -120, z = -40, yaw = 20 },
	{ name = "env_hesco", x = -113, z = -40, yaw = 20 },
	-- South-east corner and the eastern edge
	-- The Overlook (top x 85..125, z -125..-85)
	{ name = "env_guard_tower", x = 142, z = -100, yaw = 45 },
	{ name = "env_sandbag_bunker", x = 104, z = -108, yaw = 180 },
	{ name = "env_barrier_jersey", x = 60, z = -80, yaw = 30 },
	{ name = "env_container_olive", x = 128, z = 10, yaw = 90 },
	{ name = "env_barrier_jersey", x = 60, z = -110, yaw = 30 },
	-- Dead trees around the core
	{ name = "env_dead_tree", x = -136, z = 110, yaw = 0 },
	{ name = "env_dead_tree", x = -60, z = 132, yaw = 70 },
	{ name = "env_dead_tree", x = 20, z = 136, yaw = 140 },
	{ name = "env_dead_tree", x = 136, z = -20, yaw = 200 },
	{ name = "env_dead_tree", x = 40, z = -136, yaw = 260 },
	{ name = "env_dead_tree", x = -136, z = -10, yaw = 320 },
	{ name = "env_dead_tree", x = 128, z = 130, yaw = 30 },
	-- North: the Suburb (z 150..300). Ruined blocks along the north road (z = 200), one burning.
	{ name = "env_ruin_building", x = -120, z = 240, yaw = 0, burning = true },
	{ name = "env_ruin_building", x = 20, z = 250, yaw = 180 },
	{ name = "env_ruin_building", x = 160, z = 236, yaw = 15 },
	{ name = "env_guard_tower", x = -230, z = 235, yaw = 0 },
	{ name = "env_wreck_humvee", x = -60, z = 196, yaw = 100 },
	{ name = "env_wreck_humvee", x = 90, z = 204, yaw = -10 },
	{ name = "env_container_rust", x = 230, z = 250, yaw = 60 },
	{ name = "env_lamp_post", x = -42, z = 180, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = 240, yaw = 0 },
	{ name = "env_lamp_post", x = 60, z = 210, yaw = 90 },
	{ name = "env_lamp_post", x = 200, z = 210, yaw = 90 },
	{ name = "env_barrier_jersey", x = -90, z = 206, yaw = 15 },
	{ name = "env_barrier_jersey", x = 120, z = 194, yaw = -20 },
	{ name = "env_barrier_jersey", x = -10, z = 280, yaw = 60 },
	{ name = "env_sandbag_bunker", x = -170, z = 180, yaw = 90 },
	{ name = "env_dead_tree", x = -280, z = 170, yaw = 10 },
	{ name = "env_dead_tree", x = -150, z = 280, yaw = 90 },
	{ name = "env_dead_tree", x = 80, z = 285, yaw = 170 },
	{ name = "env_dead_tree", x = 270, z = 190, yaw = 250 },
	{ name = "env_dead_tree", x = 120, z = 160, yaw = 330 },
	-- East: the Depot (x 150..300). Container yard on a concrete pad, hesco walls, a mound.
	-- columns A-D (x 172/198/224/250, two containers each along z); aisles 16 wide between
	{ name = "env_container_olive", x = 172, z = 20, yaw = 90 },
	{ name = "env_container_rust", x = 172, z = 44, yaw = 90 },
	{ name = "env_container_olive", x = 198, z = 20, yaw = 90 },
	{ name = "env_container_rust", x = 198, z = 44, yaw = 90 },
	{ name = "env_container_olive", x = 224, z = 20, yaw = 90 },
	{ name = "env_container_rust", x = 224, z = 44, yaw = 90 },
	{ name = "env_container_rust", x = 250, z = 20, yaw = 90 },
	{ name = "env_container_olive", x = 250, z = 44, yaw = 90 },
	{ name = "env_container_rust", x = 214, z = 100, yaw = 0 },
	{ name = "env_hesco", x = 170, z = 70, yaw = 0 },
	{ name = "env_hesco", x = 177, z = 70, yaw = 0 },
	{ name = "env_hesco", x = 184, z = 70, yaw = 0 },
	{ name = "env_hesco", x = 191, z = 70, yaw = 0 },
	{ name = "env_twall", x = 170, z = -10, yaw = 0 },
	{ name = "env_twall", x = 178, z = -10, yaw = 0 },
	{ name = "env_twall", x = 186, z = -10, yaw = 0 },
	{ name = "env_guard_tower", x = 280, z = 40, yaw = -45 },
	{ name = "env_checkpoint", x = 160, z = 120, yaw = 90 },
	{ name = "env_tent", x = 215, z = 140, yaw = 0 },
	{ name = "env_tent", x = 240, z = 140, yaw = 0 },
	{ name = "env_sandbag_bunker", x = 235, z = -205, yaw = 0 },
	{ name = "env_wreck_humvee", x = 180, z = -150, yaw = 40 },
	{ name = "env_lamp_post", x = 160, z = 90, yaw = 180 },
	{ name = "env_lamp_post", x = 260, z = -120, yaw = 0 },
	{ name = "env_dead_tree", x = 285, z = -70, yaw = 20 },
	{ name = "env_dead_tree", x = 170, z = -260, yaw = 120 },
	-- South: the Scrapyard (z -150..-300) and the Gate: a T-wall line across z = -274 (added
	-- in code below) with one lane at x -42..-18, the booth beside it, a siren on a lamp post,
	-- and the bus line queued inside the wire (Hocker-proof cover on the Gate approach).
	{ name = "env_checkpoint", x = -54, z = -262, yaw = 0 },
	{ name = "env_lamp_post", x = -10, z = -264, yaw = 0 },
	{ name = "env_bus", x = -4, z = -150, yaw = 90 },
	{ name = "env_bus", x = -4, z = -196, yaw = 90 },
	{ name = "env_bus", x = -4, z = -242, yaw = 90 },
	{ name = "env_bus", x = 40, z = -205, yaw = 60 },
	{ name = "env_wreck_humvee", x = 60, z = -230, yaw = -120 },
	{ name = "env_wreck_humvee", x = -100, z = -180, yaw = 160 },
	{ name = "env_container_rust", x = 100, z = -190, yaw = 30 },
	{ name = "env_container_olive", x = 44, z = -250, yaw = -50 },
	{ name = "env_barrier_jersey", x = -70, z = -210, yaw = 40 },
	{ name = "env_barrier_jersey", x = 110, z = -250, yaw = 80 },
	{ name = "env_barrier_jersey", x = -140, z = -160, yaw = 10 },
	{ name = "env_guard_tower", x = -190, z = -235, yaw = 0 },
	{ name = "env_hesco", x = -250, z = -170, yaw = 30 },
	{ name = "env_hesco", x = -243, z = -170, yaw = 30 },
	{ name = "env_lamp_post", x = -42, z = -180, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = -230, yaw = 0 },
	{ name = "env_dead_tree", x = -270, z = -280, yaw = 40 },
	{ name = "env_dead_tree", x = 140, z = -285, yaw = 200 },
	{ name = "env_dead_tree", x = -200, z = -290, yaw = 300 },
	-- West: the Barracks row (x -300..-150). Two more blocks, and the Pens: the holding
	-- tents on the terrace, ringed in hesco with three mouths (ring added in code below).
	{ name = "env_ruin_building", x = -250, z = 30, yaw = 90 },
	{ name = "env_ruin_building", x = -250, z = -60, yaw = 90, burning = true },
	{ name = "env_tent", x = -266, z = 102, yaw = 0 },
	{ name = "env_tent", x = -266, z = 120, yaw = 0 },
	{ name = "env_tent", x = -266, z = 138, yaw = 0 },
	{ name = "env_lamp_post", x = -218, z = 160, yaw = 0 },
	{ name = "env_lamp_post", x = -200, z = 120, yaw = 0 },
	{ name = "env_sandbag_bunker", x = -200, z = -120, yaw = 0 },
	{ name = "env_wreck_humvee", x = -180, z = 20, yaw = 80 },
	{ name = "env_lamp_post", x = -170, z = 60, yaw = 0 },
	{ name = "env_lamp_post", x = -170, z = -100, yaw = 0 },
	{ name = "env_barrier_jersey", x = -200, z = 70, yaw = 50 },
	{ name = "env_dead_tree", x = -285, z = 60, yaw = 130 },
	{ name = "env_dead_tree", x = -170, z = 150, yaw = 220 },
	{ name = "env_dead_tree", x = -290, z = -120, yaw = 70 },
}

-- The Gate: T-walls every 8 studs across the whole map at z = -274, skipping the lane
-- (x -42..-18) the main road runs through. "Walls face out": the Index walks in through here.
for k = 0, 74 do
	if k < 32 or k > 34 then
		table.insert(DRESSING, { name = "env_twall", x = -294 + 8 * k, z = -274, yaw = 0 })
	end
end
-- The Pens' hesco ring (docs/LEVELS.md A3): north and south rows with a 20-wide mouth, an
-- east column with a mouth, the arena wall closing the west. Infected climb the slope,
-- meet hesco and nudge sideways into a mouth.
for _, x in { -283, -276.4, -269.8, -263.2, -236.8, -230.2, -223.6, -217 } do
	table.insert(DRESSING, { name = "env_hesco", x = x, z = 147, yaw = 0 })
	table.insert(DRESSING, { name = "env_hesco", x = x, z = 93, yaw = 0 })
end
for _, z in { 100, 106.5, 133.5, 140 } do
	table.insert(DRESSING, { name = "env_hesco", x = -218, z = z, yaw = 90 })
end

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
		Vector3.new(0.3, 2, 5),
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
		CFrame.new(-10, 11, -264),
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
			if entry.burning then
				SkyService.burn(part)
			end
		end
	end
end

local spawnPads: { [number]: SpawnLocation } = {}

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
	-- The LZ: insert and extract (Config.Extraction.ZonePosition). The Depot's alternate pad
	-- sits on the DepotPad concrete (top 0.3).
	local lz = Config.Extraction.ZonePosition
	buildHelipad(arena, "Helipad", lz.X, lz.Z, 0)
	buildHelipad(arena, "AltHelipad", 255, 85, 0.3)
	buildLandmarks(arena)

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
