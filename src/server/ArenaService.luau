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

local PhysicsService = game:GetService("PhysicsService")
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
	-- The Pens' terrace runs to the west arena wall (vertical there), so the hesco ring has
	-- no open west side.
	{
		name = "ParadeTerrace",
		x = -257.5,
		z = 120,
		top = Vector2.new(85, 60),
		height = 6,
		open = { west = true },
	},
}

-- Set dressing: `name` is a MeshAssets template; x/z are the piece's bounds centre; `yaw` in
-- degrees. Ground height is found by raycast, so pieces can sit on hills. Keep everything
-- clear of the LZ helipad (-90,-90: insert and extract), the objective hill top centre, the
-- Apron (origin: boss ground) and the main road lane (x -42..-18: the Warden walks it), and
-- off the embankments (a piece straddling a slope floats on one side).
-- `lift` raises the piece off the ground (a T-wall on cribbing, a stacked container);
-- `shell` picks the mesh's sealed collider set (every ruin but the Ridge one); `shadow` overrides the
-- template's CastShadow (most Gate T-walls cast none).
type Dressing = {
	name: string,
	x: number,
	z: number,
	yaw: number,
	burning: boolean?,
	lift: number?,
	shell: boolean?,
	shadow: boolean?,
	floor: number?, -- ground height to use instead of the raycast (a piece inside a building)
}
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
	{ name = "env_barrier_jersey", x = -100, z = -46, yaw = -8 }, -- was x -120: the deck container's spot
	{ name = "env_lamp_post", x = -42, z = -80, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = -20, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = 60, yaw = 0 },
	{ name = "env_lamp_post", x = -42, z = 120, yaw = 0 },
	{ name = "env_barrier_jersey", x = -16, z = 52, yaw = 10 }, -- was (-24,70): the lane / B-1
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
	{ name = "env_ruin_building", x = -120, z = 240, yaw = 0, burning = true, shell = true },
	{ name = "env_ruin_building", x = 20, z = 250, yaw = 180, shell = true },
	{ name = "env_ruin_building", x = 160, z = 236, yaw = 15, shell = true },
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
	{ name = "env_container_rust", x = 174, z = 86, yaw = 90 }, -- against the Shed's west wall: its roof route
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
	{ name = "env_ruin_building", x = -250, z = 30, yaw = 90, shell = true },
	{ name = "env_ruin_building", x = -250, z = -60, yaw = 90, burning = true, shell = true },
	{ name = "env_tent", x = -266, z = 102, yaw = 0 },
	{ name = "env_tent", x = -266, z = 120, yaw = 0 },
	{ name = "env_tent", x = -266, z = 138, yaw = 0 },
	{ name = "env_lamp_post", x = -218, z = 160, yaw = 0 },
	{ name = "env_lamp_post", x = -200, z = 120, yaw = 0 },
	{ name = "env_sandbag_bunker", x = -200, z = -120, yaw = 0 },
	{ name = "env_wreck_humvee", x = -180, z = 20, yaw = 80 },
	{ name = "env_lamp_post", x = -170, z = 60, yaw = 0 },
	{ name = "env_lamp_post", x = -170, z = -100, yaw = 0 },
	{ name = "env_barrier_jersey", x = -200, z = 80, yaw = 50 },
	{ name = "env_dead_tree", x = -292, z = 75, yaw = 130 },
	{ name = "env_dead_tree", x = -170, z = 150, yaw = 220 },
	{ name = "env_dead_tree", x = -290, z = -120, yaw = 70 },
}

-- The Gate: T-walls every 8 studs across the whole map at z = -274, skipping the lane
-- (x -42..-18) the main road runs through. "Walls face out": the Index walks in through here.
-- Only every ninth T-wall casts a shadow (72 walls in a row: the rest share theirs,
-- docs/STYLES.md §6 budgets). Two stand on cribbing with a crawl gap under them, the
-- Scrapes (A8): x -150 and x 114, cribs from buildPerches.
for k = 0, 74 do
	if k < 32 or k > 34 then
		table.insert(DRESSING, {
			name = "env_twall",
			x = -294 + 8 * k,
			z = -274,
			yaw = 0,
			shadow = k % 9 == 0,
			lift = if k == 18 or k == 51 then 2.8 else nil,
		})
	end
end
-- The Pens' hesco ring (docs/LEVELS.md A3): tall hesco (8.88: Walkers never climb it,
-- Runners do) in north and south rows with a 20-wide mouth, an east column with a mouth,
-- the west closed by the arena wall. Infected climb the slope, meet hesco and nudge
-- sideways into a mouth.
for _, x in { -295.5, -289.6, -283, -276.4, -269.8, -263.2, -236.8, -230.2, -223.6, -217 } do
	table.insert(DRESSING, { name = "env_hesco_tall", x = x, z = 147, yaw = 0 })
	table.insert(DRESSING, { name = "env_hesco_tall", x = x, z = 93, yaw = 0 })
end
for _, z in { 100, 106.5, 133.5, 140 } do
	table.insert(DRESSING, { name = "env_hesco_tall", x = -218, z = z, yaw = 90 })
end
-- Perches (A9): containers the squad can hold, each with a pallet ramp (buildPerches).
table.insert(DRESSING, { name = "env_container_olive", x = -124, z = -82, yaw = 0 }) -- LZ north-west
table.insert(DRESSING, { name = "env_container_rust", x = -130, z = -45, yaw = 0 }) -- on the highway deck
table.insert(DRESSING, { name = "env_container_rust", x = -10, z = -10, yaw = 90 }) -- Apron, 40 from (30,-10)
-- The Stack: a third container across the two of Depot column D (lands in the 2-stud gap
-- between them at z 32, so its raycast finds the pad, then `lift` puts it on their tops).
table.insert(DRESSING, { name = "env_container_rust", x = 250, z = 32, yaw = 90, lift = 9.55 })
table.insert(DRESSING, { name = "env_container_olive", x = 56, z = -45, yaw = 0 }) -- deck gantry step

-- Props (A11; assets/3d/README.md prop table). Registered meshes without an asset id yet are
-- skipped at boot, so these placements are live the moment the ids land in MeshAssets.
-- `floor` pins pieces inside a building to its floor (the raycast would find the roof).
local PROPS: { Dressing } = {
	-- The LZ
	{ name = "prop_light_tower", x = -70, z = -116, yaw = 30 },
	{ name = "prop_generator", x = -66, z = -108, yaw = 0 },
	{ name = "prop_pallet", x = -110, z = -66, yaw = 0 },
	{ name = "prop_pallet", x = -106, z = -66, yaw = 12 },
	{ name = "prop_pallet", x = -110, z = -62, yaw = -8 },
	{ name = "prop_body_bag", x = -74, z = -70, yaw = 0 },
	{ name = "prop_body_bag", x = -74, z = -66, yaw = 4 },
	{ name = "prop_portable_toilet", x = -118, z = -100, yaw = 90 },
	{ name = "prop_fuel_bladder", x = -126, z = -100, yaw = 0 },
	-- The Apron and the Screening Block
	{ name = "prop_body_bag", x = -8, z = 56, yaw = 90 },
	{ name = "prop_body_bag", x = -4, z = 56, yaw = 90 },
	{ name = "prop_body_bag", x = 0, z = 56, yaw = 90 },
	{ name = "prop_body_bag", x = 4, z = 56, yaw = 90 },
	{ name = "prop_concertina", x = -2, z = 84, yaw = 0 },
	{ name = "prop_light_tower", x = 16, z = 56, yaw = 0 },
	{ name = "prop_portable_toilet", x = 10, z = 84, yaw = 180 },
	{ name = "prop_portable_toilet", x = 14, z = 84, yaw = 180 },
	{ name = "prop_generator", x = -10, z = 84, yaw = 0 },
	{ name = "prop_civilian_car", x = 14, z = -30, yaw = 100 },
	{ name = "prop_dumpster", x = -8, z = 30, yaw = 20 },
	-- The Compound (hill top y 8)
	{ name = "prop_generator", x = 106, z = 30, yaw = 0 },
	{ name = "prop_pallet", x = 36, z = 66, yaw = 0 },
	{ name = "prop_pallet", x = 36, z = 70, yaw = 15 },
	{ name = "prop_cot", x = 54, z = 100, yaw = 0 },
	{ name = "prop_cot", x = 54, z = 106, yaw = 0 },
	{ name = "prop_light_tower", x = 60, z = 40, yaw = 0 },
	{ name = "prop_body_bag", x = 70, z = 90, yaw = 0 },
	{ name = "prop_body_bag", x = 70, z = 93, yaw = 0 },
	{ name = "prop_body_bag", x = 70, z = 96, yaw = 0 },
	-- The Ridge (hill top y 8; the ruin's ground floor)
	{ name = "prop_cot", x = -96, z = 42, yaw = 0, floor = 8 },
	{ name = "prop_cot", x = -96, z = 46, yaw = 0, floor = 8 },
	{ name = "prop_generator", x = -76, z = 44, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -126, z = 40, yaw = 90 },
	{ name = "prop_chainlink_panel", x = -126, z = 52, yaw = 90 },
	{ name = "prop_pallet", x = -84, z = 58, yaw = 0 },
	-- The Inner Gate (z -112)
	{ name = "prop_concertina", x = -80, z = -106, yaw = 0 },
	{ name = "prop_concertina", x = 6, z = -106, yaw = 0 },
	{ name = "prop_light_tower", x = -70, z = -132, yaw = 0 },
	{ name = "prop_generator", x = -4, z = -126, yaw = 0 },
	{ name = "prop_body_bag", x = -72, z = -122, yaw = 0 },
	{ name = "prop_body_bag", x = -72, z = -125, yaw = 0 },
	-- The highway deck (y 12)
	{ name = "prop_civilian_car", x = -200, z = -43, yaw = 10 },
	{ name = "prop_civilian_car", x = -70, z = -47, yaw = -8 },
	{ name = "prop_civilian_car", x = 160, z = -43, yaw = 5 },
	{ name = "prop_civilian_car", x = 240, z = -47, yaw = -12 },
	-- The Overlook (y 14)
	{ name = "prop_generator", x = 116, z = -116, yaw = 0 },
	{ name = "prop_pallet", x = 92, z = -92, yaw = 0 },
	{ name = "prop_pallet", x = 96, z = -92, yaw = 20 },
	{ name = "prop_light_tower", x = 118, z = -92, yaw = 0 },
	-- The Suburb: the Parade, the church, the north road
	{ name = "prop_civilian_car", x = -100, z = 192, yaw = 80 },
	{ name = "prop_civilian_car", x = 0, z = 208, yaw = -5 },
	{ name = "prop_civilian_car", x = 140, z = 192, yaw = 100 },
	{ name = "prop_civilian_car", x = 220, z = 208, yaw = 3 },
	{ name = "prop_dumpster", x = 108, z = 167, yaw = 0 }, -- the Walker step to the Parade roof
	{ name = "prop_dumpster", x = 70, z = 196, yaw = 15 },
	{ name = "prop_body_bag", x = 56, z = 240, yaw = 0 },
	{ name = "prop_body_bag", x = 60, z = 240, yaw = 0 },
	{ name = "prop_body_bag", x = 64, z = 240, yaw = 0 },
	{ name = "prop_plank", x = 30, z = 270, yaw = 20 },
	{ name = "prop_plank", x = -60, z = 230, yaw = 70 },
	{ name = "prop_portable_toilet", x = 100, z = 164, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -180, z = 165, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -168, z = 165, yaw = 0 },
	{ name = "prop_concertina", x = -10, z = 268, yaw = 0 },
	-- The Depot (pad y 0.3)
	{ name = "prop_pallet", x = 162, z = 24, yaw = 0 },
	{ name = "prop_pallet", x = 162, z = 30, yaw = 0 },
	{ name = "prop_pallet", x = 162, z = 36, yaw = 10 },
	{ name = "prop_pallet", x = 162, z = 42, yaw = 0 },
	{ name = "prop_pallet", x = 240, z = 70, yaw = 0 },
	{ name = "prop_pallet", x = 246, z = 70, yaw = 5 },
	{ name = "prop_generator", x = 230, z = 100, yaw = 0 },
	{ name = "prop_light_tower", x = 266, z = 96, yaw = 0 },
	{ name = "prop_light_tower", x = 166, z = 0, yaw = 0 },
	{ name = "prop_dumpster", x = 176, z = 104, yaw = 0 },
	{ name = "prop_fuel_bladder", x = 264, z = 70, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 200, z = -8, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 212, z = -8, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 224, z = -8, yaw = 0 },
	{ name = "prop_plank", x = 226, z = 60, yaw = 40 },
	-- The Pumps
	{ name = "prop_fuel_bladder", x = 100, z = -168, yaw = 0 },
	{ name = "prop_fuel_bladder", x = 112, z = -170, yaw = 0 },
	{ name = "prop_civilian_car", x = 130, z = -174, yaw = 95 },
	{ name = "prop_generator", x = 158, z = -168, yaw = 0 },
	-- The Scrapyard and the Gate
	{ name = "prop_civilian_car", x = -120, z = -230, yaw = 40 },
	{ name = "prop_civilian_car", x = -80, z = -250, yaw = -30 },
	{ name = "prop_civilian_car", x = 16, z = -258, yaw = 20 },
	{ name = "prop_civilian_car", x = 130, z = -220, yaw = 70 },
	{ name = "prop_dumpster", x = -150, z = -200, yaw = 0 },
	{ name = "prop_dumpster", x = 70, z = -200, yaw = 30 },
	{ name = "prop_concertina", x = -200, z = -268, yaw = 0 },
	{ name = "prop_concertina", x = -120, z = -268, yaw = 0 },
	{ name = "prop_concertina", x = 60, z = -268, yaw = 0 },
	{ name = "prop_concertina", x = 140, z = -268, yaw = 0 },
	{ name = "prop_plank", x = -160, z = -220, yaw = 30 },
	{ name = "prop_plank", x = 90, z = -240, yaw = 60 },
	{ name = "prop_light_tower", x = -70, z = -252, yaw = 0 },
	-- The Lines (hut floors at ground), the Pens, the Armoury
	{ name = "prop_cot", x = -280, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -274, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -262, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -250, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -244, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -232, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -220, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -214, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_cot", x = -202, z = 64, yaw = 0, floor = 0 },
	{ name = "prop_portable_toilet", x = -280, z = 78, yaw = 180 },
	{ name = "prop_portable_toilet", x = -276, z = 78, yaw = 180 },
	{ name = "prop_portable_toilet", x = -272, z = 78, yaw = 180 },
	{ name = "prop_generator", x = -226, z = 78, yaw = 0 },
	{ name = "prop_light_tower", x = -240, z = 44, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -190, z = 100, yaw = 90 },
	{ name = "prop_chainlink_panel", x = -190, z = 112, yaw = 90 },
	{ name = "prop_concertina", x = -250, z = 160, yaw = 0 },
	{ name = "prop_body_bag", x = -240, z = 100, yaw = 0 },
	{ name = "prop_body_bag", x = -240, z = 103, yaw = 0 },
	{ name = "prop_body_bag", x = -236, z = 100, yaw = 0 },
	{ name = "prop_body_bag", x = -236, z = 103, yaw = 0 },
	{ name = "prop_pallet", x = -224, z = 2, yaw = 0 },
	{ name = "prop_pallet", x = -224, z = 6, yaw = 0 },
	{ name = "prop_generator", x = -196, z = 4, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -230, z = -12, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -218, z = -12, yaw = 0 },
	-- Outer hills
	{ name = "prop_light_tower", x = -172, z = -224, yaw = 0 }, -- SouthRise
	{ name = "prop_pallet", x = -210, z = -245, yaw = 0 },
	{ name = "prop_pallet", x = -204, z = -245, yaw = 0 },
	{ name = "prop_generator", x = 250, z = -220, yaw = 0 }, -- Depot mound
	{ name = "prop_pallet", x = 222, z = -190, yaw = 0 },
	{ name = "prop_generator", x = -216, z = 248, yaw = 0 }, -- NorthBluff
	{ name = "prop_pallet", x = -244, z = 248, yaw = 0 },
}
for _, prop in PROPS do
	table.insert(DRESSING, prop)
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

-- Ground patches (docs/LEVELS.md A12, 2026-11-07): thin Mud / Rock / darker-Ground sheets on
-- the floor at hill feet, along the roads and in the yards, so the ground reads as used.
-- Decoration only: no collision, no query (dressing raycasts land on the floor under them).
type Patch = { x: number, z: number, w: number, d: number, kind: string, yaw: number? }
local PATCH_LOOKS: { [string]: { Material: Enum.Material, Color: Color3 } } = {
	mud = { Material = Enum.Material.Mud, Color = Color3.fromRGB(70, 60, 48) },
	rock = { Material = Enum.Material.Rock, Color = Color3.fromRGB(96, 92, 86) },
	dark = { Material = Enum.Material.Ground, Color = Color3.fromRGB(74, 68, 58) },
}
local PATCHES: { Patch } = {
	-- Darker verges along both roads (the main road is x -38..-22, the north road z 192..208).
	{ x = -42, z = 0, w = 8, d = 600, kind = "dark" },
	{ x = -18, z = 0, w = 8, d = 600, kind = "dark" },
	{ x = 0, z = 188, w = 600, d = 8, kind = "dark" },
	{ x = 0, z = 212, w = 600, d = 8, kind = "dark" },
	-- Hill feet
	{ x = 18, z = 30, w = 8, d = 30, kind = "mud" }, -- Compound west foot
	{ x = 70, z = 18, w = 40, d = 8, kind = "mud" }, -- Compound south foot
	{ x = -100, z = 18, w = 30, d = 8, kind = "mud" }, -- Ridge south foot
	{ x = 105, z = -80, w = 30, d = 8, kind = "mud" }, -- Overlook north foot
	{ x = -250, z = 80, w = 50, d = 6, kind = "mud" }, -- the Pens' terrace foot
	{ x = 235, z = -178, w = 40, d = 8, kind = "rock" }, -- Depot mound foot
	{ x = -190, z = -211, w = 50, d = 8, kind = "rock" }, -- SouthRise north foot
	-- Yards and puddles
	{ x = -90, z = -60, w = 24, d = 12, kind = "mud" }, -- LZ approach
	{ x = -50, z = -200, w = 10, d = 16, kind = "mud", yaw = 15 },
	{ x = -8, z = -40, w = 12, d = 10, kind = "mud", yaw = -20 },
	{ x = -48, z = 150, w = 10, d = 20, kind = "mud", yaw = 8 },
	{ x = -12, z = 230, w = 12, d = 14, kind = "mud", yaw = 30 },
	{ x = -240, z = 40, w = 40, d = 8, kind = "mud" }, -- in front of the Lines
	{ x = 130, z = -172, w = 24, d = 10, kind = "mud" }, -- the Pumps' forecourt
	{ x = 60, z = 236, w = 24, d = 12, kind = "mud" }, -- churchyard
	{ x = 196, z = 108, w = 32, d = 10, kind = "mud" }, -- the Shed's yard
	{ x = -120, z = -200, w = 30, d = 20, kind = "rock", yaw = 20 }, -- Scrapyard
	{ x = 60, z = -270, w = 20, d = 14, kind = "rock", yaw = -10 },
	{ x = 280, z = -140, w = 20, d = 20, kind = "rock", yaw = 35 },
	{ x = -200, z = 270, w = 24, d = 16, kind = "rock", yaw = 50 }, -- Suburb
	{ x = 250, z = 280, w = 30, d = 20, kind = "rock", yaw = -25 },
}

local function buildGroundPatches(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "GroundPatches"
	for _, patch in PATCHES do
		local look = PATCH_LOOKS[patch.kind]
		local part = Instance.new("Part")
		part.Name = "Patch"
		part.Size = Vector3.new(patch.w, 0.24, patch.d)
		part.CFrame = CFrame.new(patch.x, 0, patch.z)
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

-- Perches (docs/LEVELS.md A9): every high spot the squad can hold has a pallet ramp up to
-- it, so a Walker (climb 5) gets there too and no perch is a free camp. A ramp is a
-- WedgePart that rises toward its yaw direction from `base` by `rise`; `length` defaults
-- to the kit's stair angle. Bases are known levels (ground 0, Depot pad 0.3, Compound 8,
-- highway deck 12), not raycast: the ramps go in before the dressing they lean on.
type Ramp = { x: number, z: number, yaw: number, rise: number, base: number, length: number? }
local RAMP_COLOR = Color3.fromRGB(110, 88, 60)
local RAMPS: { Ramp } = {
	{ x = -124, z = -93.95, yaw = 0, rise = 9.55, base = 0 }, -- LZ north-west container
	{ x = -148.35, z = -45, yaw = 90, rise = 9.55, base = 12 }, -- deck container (-130,-45)
	{ x = 86.62, z = 52, yaw = -90, rise = 6, base = 8 }, -- the Shelf
	{ x = 26.9, z = 1.54, yaw = 165, rise = 9.55, base = 0.3, length = 14.7 }, -- Apron container (30,-10)
	{ x = 1.95, z = -10, yaw = -90, rise = 9.55, base = 0.3, length = 14.7 }, -- Apron container (-10,-10)
	-- The Stack: up the south end of column D's south container, then on up its top onto
	-- the third container laid across the pair (top 19.4).
	{ x = 250, z = 1.65, yaw = 0, rise = 9.55, base = 0.3 },
	{ x = 250, z = 15, yaw = 0, rise = 9.55, base = 9.85, length = 12 },
	{ x = 74.4, z = -45, yaw = -90, rise = 9.55, base = 12 }, -- deck gantry container (56,-45)
}

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
				CFrame.new(40 + sx * 4.4, (floorY + HIGHWAY_Y) / 2, -45 + sz * 9.4)
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
	end
	part.Name = name
	part.CFrame = CFrame.new(x, groundY + part.Size.Y / 2 + (entry.lift or 0), z)
		* CFrame.Angles(0, math.rad(yaw), 0)
	if entry.shadow ~= nil then
		part.CastShadow = entry.shadow
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
-- buildBuilding(spec) (docs/LEVELS.md section B, 2026-11-07): enterable buildings from plain
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
type Side = string -- "south" | "north" | "east" | "west"
type Opening = {
	kind: string, -- "door" | "window" | "breach" | "gap"
	at: number, -- along the wall, from its centre (south/north: +x, east/west: +z)
	width: number?,
	sill: number?, -- window only (0 = an arch from the floor)
	head: number?, -- top of the opening (door / window / breach)
}
-- A straight flight against `side`, bottom end at `at` along that wall, rising toward
-- `dir` (+1 / -1 along the wall) from the floor of `storey` by `rise` (default one storey).
type StairSpec = { side: Side, at: number, dir: number, storey: number, rise: number? }
-- A TrussPart against `side` at `at`, from `bottom` (default the ground) to `top`; `inside`
-- puts it inside the wall (the slabs above get a hole for the climber).
type LadderSpec = { side: Side, at: number, top: number, bottom: number?, inside: boolean? }
-- A wall inside the footprint along x or z at `at`, between `from` and `to` on the other axis.
type InteriorWall = {
	along: string, -- "x" | "z"
	at: number,
	from: number,
	to: number,
	storey: number,
	openings: { Opening }?,
}
-- A partial slab (choir loft, workshop mezzanine) with an optional rail on one edge.
type Mezzanine = { x0: number, x1: number, z0: number, z1: number, level: number, rail: Side? }
-- A plain Part in the building's frame (catwalk, canopy, columns): `at` is its centre.
type Extra = {
	name: string,
	size: Vector3,
	at: Vector3,
	material: string?,
	class: string?,
	yaw: number?,
}
type BuildingSpec = {
	name: string,
	x: number,
	z: number,
	yaw: number?,
	width: number,
	depth: number,
	storeys: number,
	storeyHeight: number?, -- default Config.Arena.Kit.Storey
	material: string, -- Config.Arena.Materials key
	walls: { { [string]: { Opening } } }, -- [storey][side]
	interior: { InteriorWall }?,
	stairs: { StairSpec }?,
	ladders: { LadderSpec }?,
	mezzanines: { Mezzanine }?,
	extras: { Extra }?,
	roof: boolean?, -- default true
	parapet: boolean?, -- default true
	lips: boolean?, -- default true
}
type Rect = { x0: number, x1: number, z0: number, z1: number }
type Footprint = { name: string, frame: CFrame, halfWidth: number, halfDepth: number, top: number }
type Look = { Material: Enum.Material, Color: Color3 }

-- The seven enterable buildings (docs/LEVELS.md section B, 2026-11-07). Coordinates are
-- the footprint centre; `at` values are local to the building (x along south/north walls,
-- z along east/west). Nothing here sits in the Warden lane (x -42..-18) or on a hold zone.
local BUILDINGS: { BuildingSpec } = {
	-- B-1 Screening Block: two storeys at the foot of the Compound, west windows over the
	-- main road (overwatch on the Warden walk), stairs along the north wall, a roof hatch
	-- ladder, and a catwalk from the first-floor east door onto the Compound's lower tier.
	{
		name = "ScreeningBlock",
		x = -2,
		z = 70,
		width = 24,
		depth = 18,
		storeys = 2,
		material = "cinder",
		walls = {
			{
				south = { { kind = "door", at = 0 } },
				west = {
					{ kind = "door", at = 0 },
					{ kind = "window", at = -5.5, width = 4 },
					{ kind = "window", at = 5.5, width = 4 },
				},
				north = { { kind = "window", at = -8 }, { kind = "window", at = 8 } },
				east = {
					{ kind = "window", at = -5.5, width = 4 },
					{ kind = "window", at = 5.5, width = 4 },
				},
			},
			{
				west = {
					{ kind = "window", at = -5.5, width = 4 },
					{ kind = "window", at = 0, width = 4 },
					{ kind = "window", at = 5.5, width = 4 },
				},
				east = { { kind = "door", at = 0 } },
				south = { { kind = "window", at = -8 }, { kind = "window", at = 2 } },
				north = { { kind = "window", at = -8 }, { kind = "window", at = 8 } },
			},
		},
		stairs = { { side = "north", at = -10, dir = 1, storey = 1 } },
		ladders = { { side = "south", at = 8.5, bottom = 9, top = 18, inside = true } },
		extras = {
			-- Catwalk: first floor (9) east to the Compound top (8); the slope under its far end.
			{
				name = "Catwalk",
				size = Vector3.new(16, 0.6, Config.Arena.Kit.CorridorMin),
				at = Vector3.new(20, 8.7, 0),
				material = "catwalk",
			},
			{
				name = "CatwalkRail",
				size = Vector3.new(16, 1.2, 0.3),
				at = Vector3.new(20, 9.6, 2.85),
				material = "ladder",
			},
			{
				name = "CatwalkRail",
				size = Vector3.new(16, 1.2, 0.3),
				at = Vector3.new(20, 9.6, -2.85),
				material = "ladder",
			},
			-- The Recover Logs desk, ground floor north-west corner.
			{
				name = "Desk",
				size = Vector3.new(6, 2.6, 2.4),
				at = Vector3.new(-8, 1.3, 5.5),
				material = "wood",
			},
		},
	},
	-- B-2 the Lines: three barracks huts shoulder to shoulder at z 60 with their end doors in
	-- line (a 90-stud walk-through tube), no parapets, one ladder to the rooftop route.
	{
		name = "LinesHutWest",
		x = -270,
		z = 60,
		width = 30,
		depth = 16,
		storeys = 1,
		material = "wood",
		parapet = false,
		walls = {
			{
				east = { { kind = "door", at = 0 } },
				west = { { kind = "door", at = 0 } },
				south = {
					{ kind = "window", at = -9 },
					{ kind = "window", at = 0 },
					{ kind = "window", at = 9 },
				},
				north = { { kind = "window", at = -9 }, { kind = "window", at = 9 } },
			},
		},
	},
	{
		name = "LinesHutMid",
		x = -240,
		z = 60,
		width = 30,
		depth = 16,
		storeys = 1,
		material = "wood",
		parapet = false,
		walls = {
			{
				east = { { kind = "door", at = 0 } },
				west = { { kind = "door", at = 0 } },
				south = {
					{ kind = "window", at = -9 },
					{ kind = "window", at = 0 },
					{ kind = "window", at = 9 },
				},
				north = { { kind = "window", at = -9 }, { kind = "window", at = 9 } },
			},
		},
		ladders = { { side = "north", at = 0, top = 9 } },
	},
	{
		name = "LinesHutEast",
		x = -210,
		z = 60,
		width = 30,
		depth = 16,
		storeys = 1,
		material = "wood",
		parapet = false,
		walls = {
			{
				east = { { kind = "door", at = 0 } },
				west = { { kind = "door", at = 0 } },
				south = {
					{ kind = "window", at = -9 },
					{ kind = "window", at = 0 },
					{ kind = "window", at = 9 },
				},
				north = { { kind = "window", at = -9 }, { kind = "window", at = 9 } },
			},
		},
	},
	-- B-3 the Shed: the Depot's vehicle workshop, 12.5 clear (a Brute room), a vehicle door
	-- in the south wall, a mezzanine up a flight along the west wall, the roof reached from
	-- the container parked against its east wall (DRESSING).
	{
		name = "Shed",
		x = 196,
		z = 86,
		width = 32,
		depth = 24,
		storeys = 1,
		storeyHeight = 12.5,
		material = "metal",
		walls = {
			{
				south = { { kind = "breach", at = 8, width = 12, head = 10 } },
				north = {
					{ kind = "door", at = 0 },
					{ kind = "window", at = -10, sill = 7, head = 11 },
					{ kind = "window", at = 10, sill = 7, head = 11 },
				},
				east = {
					{ kind = "door", at = 6 },
					{ kind = "window", at = -6, sill = 7, head = 11 },
				},
				west = {
					{ kind = "window", at = -6, sill = 7, head = 11 },
					{ kind = "window", at = 6, sill = 7, head = 11 },
				},
			},
		},
		mezzanines = { { x0 = -15.4, x1 = -4, z0 = -11.4, z1 = 11.4, level = 6.5, rail = "east" } },
		stairs = { { side = "west", at = -11, dir = 1, storey = 1, rise = 6.5 } },
		extras = {
			{
				name = "Bench",
				size = Vector3.new(2.4, 3, 14),
				at = Vector3.new(14, 1.5, 0),
				material = "metal",
			},
		},
	},
	-- B-4 the church: a 14-stud nave, a choir loft over the south end up an east-wall flight,
	-- an inside ladder from the loft to the roof, and the belfry on top (next spec).
	{
		name = "Church",
		x = 60,
		z = 262,
		width = 20,
		depth = 32,
		storeys = 1,
		storeyHeight = 14,
		material = "brick",
		walls = {
			{
				south = { { kind = "door", at = 0, width = 6, head = 10 } },
				north = { { kind = "window", at = 0, width = 6, sill = 6, head = 12 } },
				east = {
					{ kind = "window", at = -10, width = 4, sill = 4.5, head = 11 },
					{ kind = "window", at = 0, width = 4, sill = 4.5, head = 11 },
					{ kind = "window", at = 10, width = 4, sill = 4.5, head = 11 },
				},
				west = {
					{ kind = "window", at = -10, width = 4, sill = 4.5, head = 11 },
					{ kind = "window", at = 0, width = 4, sill = 4.5, head = 11 },
					{ kind = "window", at = 10, width = 4, sill = 4.5, head = 11 },
				},
			},
		},
		mezzanines = { { x0 = -9.4, x1 = 9.4, z0 = -15.4, z1 = -6, level = 7 } },
		stairs = { { side = "east", at = 5, dir = -1, storey = 1, rise = 7 } },
		ladders = { { side = "west", at = -12, bottom = 7, top = 14, inside = true } },
		extras = {
			-- Loft rail, stopping short of the east wall where the flight arrives.
			{
				name = "Rail",
				size = Vector3.new(13.3, 1.2, 0.3),
				at = Vector3.new(-2.75, 7.6, -6.15),
				material = "wood",
			},
		},
	},
	-- The belfry: stands on the church roof (its ground raycast lands on the roof slab),
	-- open arches on all four sides, its own roof at 20 up an outside ladder.
	{
		name = "ChurchBelfry",
		x = 60,
		z = 252,
		width = 8,
		depth = 8,
		storeys = 1,
		storeyHeight = 6,
		material = "brick",
		walls = {
			{
				south = { { kind = "window", at = 0, sill = 0, head = 5 } },
				north = { { kind = "window", at = 0, sill = 0, head = 5 } },
				east = { { kind = "window", at = 0, sill = 0, head = 5 } },
				west = { { kind = "window", at = 0, sill = 0, head = 5 } },
			},
		},
		ladders = { { side = "north", at = 0, top = 6 } },
	},
	-- B-5 the Parade: a row of four shops facing the north road, every shop a front door, a
	-- broken shopfront (sill 1) and a back door, party walls with a door each (run-through),
	-- one 48-stud roof.
	{
		name = "ParadeShops",
		x = 124,
		z = 178,
		width = 48,
		depth = 16,
		storeys = 1,
		material = "render",
		walls = {
			{
				north = {
					{ kind = "door", at = -21.5 },
					{ kind = "window", at = -15.5, sill = 1, head = 8 },
					{ kind = "door", at = -9.5 },
					{ kind = "window", at = -3.5, sill = 1, head = 8 },
					{ kind = "door", at = 2.5 },
					{ kind = "window", at = 8.5, sill = 1, head = 8 },
					{ kind = "door", at = 14.5 },
					{ kind = "window", at = 20.5, sill = 1, head = 8 },
				},
				south = {
					{ kind = "door", at = -18 },
					{ kind = "door", at = -6 },
					{ kind = "door", at = 6 },
					{ kind = "door", at = 18 },
				},
				east = { { kind = "window", at = 0 } },
				west = { { kind = "window", at = 0 } },
			},
		},
		interior = {
			{
				along = "z",
				at = -12,
				from = -7.4,
				to = 7.4,
				storey = 1,
				openings = { { kind = "door", at = -4 } },
			},
			{
				along = "z",
				at = 0,
				from = -7.4,
				to = 7.4,
				storey = 1,
				openings = { { kind = "door", at = -4 } },
			},
			{
				along = "z",
				at = 12,
				from = -7.4,
				to = 7.4,
				storey = 1,
				openings = { { kind = "door", at = -4 } },
			},
		},
	},
	-- B-6 the Pumps: the fuel station kiosk with the canopy (walkable, 10.5) over the pump
	-- islands west of it; the kiosk roof (9, no parapet) is the step up to the canopy.
	{
		name = "PumpsKiosk",
		x = 150,
		z = -155,
		width = 12,
		depth = 10,
		storeys = 1,
		material = "panel",
		parapet = false,
		walls = {
			{
				west = { { kind = "door", at = 0 } },
				north = { { kind = "window", at = 0, width = 6 } },
				south = { { kind = "window", at = 0, width = 6 } },
			},
		},
		ladders = { { side = "east", at = 0, top = 9 } },
		extras = {
			{
				name = "Canopy",
				size = Vector3.new(28, 0.6, 16),
				at = Vector3.new(-20, 10.2, 0),
				material = "panel",
			},
			{
				name = "CanopyColumn",
				size = Vector3.new(1.2, 9.9, 1.2),
				at = Vector3.new(-9, 4.95, 6.5),
				material = "ladder",
			},
			{
				name = "CanopyColumn",
				size = Vector3.new(1.2, 9.9, 1.2),
				at = Vector3.new(-9, 4.95, -6.5),
				material = "ladder",
			},
			{
				name = "CanopyColumn",
				size = Vector3.new(1.2, 9.9, 1.2),
				at = Vector3.new(-31, 4.95, 6.5),
				material = "ladder",
			},
			{
				name = "CanopyColumn",
				size = Vector3.new(1.2, 9.9, 1.2),
				at = Vector3.new(-31, 4.95, -6.5),
				material = "ladder",
			},
			{
				name = "PumpIsland",
				size = Vector3.new(6, 0.8, 2.4),
				at = Vector3.new(-14, 0.4, 0),
				material = "concrete",
			},
			{
				name = "PumpIsland",
				size = Vector3.new(6, 0.8, 2.4),
				at = Vector3.new(-26, 0.4, 0),
				material = "concrete",
			},
			{
				name = "Pump",
				size = Vector3.new(2, 5, 1.6),
				at = Vector3.new(-14, 3.3, 0),
				material = "panel",
			},
			{
				name = "Pump",
				size = Vector3.new(2, 5, 1.6),
				at = Vector3.new(-26, 3.3, 0),
				material = "panel",
			},
		},
	},
	-- The Armoury: a windowless-looking concrete box in the Barracks row, one door, high
	-- slits, a roof ladder round the back.
	{
		name = "Armoury",
		x = -210,
		z = 0,
		width = 16,
		depth = 12,
		storeys = 1,
		material = "concrete",
		walls = {
			{
				south = { { kind = "door", at = 0 } },
				north = {
					{ kind = "window", at = -4, width = 3, sill = 6 },
					{ kind = "window", at = 4, width = 3, sill = 6 },
				},
				east = { { kind = "window", at = 0, width = 3, sill = 6 } },
				west = { { kind = "window", at = 0, width = 3, sill = 6 } },
			},
		},
		ladders = { { side = "north", at = 0, top = 9 } },
	},
}

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

	local footprint: Rect = { x0 = -hw, x1 = hw, z0 = -hd, z1 = hd }
	for storey = 2, spec.storeys do
		slab("Floor", footprint, (storey - 1) * H, slabMaterial)
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
		slab("Roof", footprint, top, roofMaterial)
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

	-- Remove the default Baseplate so it can't z-fight (flash) with our floor.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
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
	buildBuildings() -- after parenting: the kit raycasts the hills (and the church roof)
	task.spawn(placeDressing)
end

return ArenaService
