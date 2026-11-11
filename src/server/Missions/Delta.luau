--!strict
-- Checkpoint Delta's layout (docs/LEVELS.md section A; moved out of ArenaService for the
-- mission data split, docs/ARCHITECTURE.md F6). Pure data plus the loops that generate the
-- Gate line, the Pens ring and the fence. assets/3d/build/delta_map.py reads these tables
-- by name (HILLS, DRESSING, PROPS, RAMPS, PATCHES, BUILDINGS, PERIMETER): keep the names.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MissionTypes = require(script.Parent.MissionTypes)

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

-- Raised plateaus. `top` is the flat size (X, Z), `height` the rise above `base` (default
-- y=0, so tiers stack). Each side gets a wedge embankment `height * 1.2` studs deep (~40
-- degrees, easy for Humanoids) unless listed in `open` (a vertical face: an arena wall or a
-- bridge abutment); corners next to a closed side get solid blocks.
-- Levels in play: ground 0, Ridge/Compound 8, highway 12, Overlook 14, Compound upper 16.
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
	-- The Pens' terrace runs to the west edge (vertical there, the perimeter fence and the
	-- boundary collider close it: docs/LEVELS.md A15), so the hesco ring has
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
local DRESSING: { Dressing } = {
	-- The Compound lower tier (top x 25..115, z 25..115; zone 27..73; the upper tier's
	-- slopes cover x,z >= 72) and upper tier (top 82..106)
	{ name = "env_comm_tower", x = 94, z = 94, yaw = 0 },
	{ name = "env_twall", x = 86, z = 100, yaw = 90 },
	{ name = "env_twall", x = 86, z = 92, yaw = 90 },
	{ name = "env_hesco", x = 100, z = 86, yaw = 0 },
	{ name = "env_tent", x = 42, z = 104, yaw = 0 },
	{ name = "env_tent", x = 42, z = 88, yaw = 0 },
	{ name = "env_container_olive", x = 100, z = 44, yaw = 0 },
	{ name = "env_container_rust", x = 106, z = 60, yaw = 90 },
	{ name = "env_wreck_humvee", x = 61, z = 107.5, yaw = -10 },
	{ name = "env_sandbag_bunker", x = 86, z = 34, yaw = 180 },
	{ name = "env_hesco", x = 34, z = 40, yaw = 0 },
	{ name = "env_hesco", x = 34, z = 47, yaw = 0 },
	{ name = "env_hesco", x = 34, z = 54, yaw = 0 },
	{ name = "env_twall", x = 55, z = 34, yaw = 0 },
	{ name = "env_twall", x = 63, z = 34, yaw = 0 },
	-- The Ridge (hill top x -130..-70, z 23..67)
	{ name = "env_ruin_building", x = -104, z = 48, yaw = 0, burning = true },
	{ name = "env_guard_tower", x = -78, z = 31, yaw = 0 },
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
	{ name = "env_wreck_humvee", x = 100, z = -45, yaw = -10 },
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
	{ name = "env_lamp_post", x = -115, z = -72, yaw = -45 },
	{ name = "env_barrier_jersey", x = -60, z = -74, yaw = 45 },
	{ name = "env_barrier_jersey", x = -100, z = -116, yaw = 0 },
	{ name = "env_barrier_jersey", x = -80, z = -116, yaw = 0 },
	{ name = "env_hesco", x = -108, z = -40, yaw = 0 },
	{ name = "env_hesco", x = -101, z = -40, yaw = 0 },
	-- South-east corner and the eastern edge
	-- The Overlook (top x 85..125, z -125..-85)
	{ name = "env_guard_tower", x = 150, z = -100, yaw = 45 },
	{ name = "env_sandbag_bunker", x = 104, z = -108, yaw = 180 },
	{ name = "env_barrier_jersey", x = 60, z = -80, yaw = 30 },
	{ name = "env_container_olive", x = 134, z = 10, yaw = 90 },
	{ name = "env_barrier_jersey", x = 60, z = -110, yaw = 30 },
	-- Dead trees around the core
	{ name = "env_dead_tree", x = -136, z = 110, yaw = 0 },
	{ name = "env_dead_tree", x = -60, z = 132, yaw = 70 },
	{ name = "env_dead_tree", x = 20, z = 136, yaw = 140 },
	{ name = "env_dead_tree", x = 136, z = -16, yaw = 200 },
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
	{ name = "env_container_rust", x = 250, z = 20, yaw = 90, perch = true, floor = 0.28 }, -- floor: the raycast lands on the Stack's ramp
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
	{ name = "env_dead_tree", x = 285, z = -74, yaw = 20 },
	{ name = "env_dead_tree", x = 170, z = -260, yaw = 120 },
	-- South: the Scrapyard (z -150..-300) and the Gate: a T-wall line across z = -274 (added
	-- in code below) with one lane at x -42..-18, the booth beside it, a siren on a lamp post,
	-- and the bus line queued inside the wire (Hocker-proof cover on the Gate approach).
	{ name = "env_checkpoint", x = -54, z = -262, yaw = 0 },
	{ name = "env_lamp_post", x = -14, z = -264, yaw = 0, floor = 0 }, -- floor: the raycast would land on its own siren head
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
	{ name = "env_ruin_building", x = -250, z = -100, yaw = 90, burning = true, shell = true },
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
for k = 0, 73 do -- k = 74 (x 298) would stand inside the east wall
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
-- the west closed by the perimeter fence (A15). Infected climb the slope, meet hesco and nudge
-- sideways into a mouth.
for _, x in { -295.5, -289.6, -283, -276.4, -269.8, -263.2, -238.3, -231.7, -225.1, -218.5 } do
	table.insert(DRESSING, { name = "env_hesco_tall", x = x, z = 146, yaw = 0 })
	table.insert(DRESSING, { name = "env_hesco_tall", x = x, z = 94, yaw = 0 })
end
for _, z in { 100, 106.5, 133.5, 140 } do
	table.insert(DRESSING, { name = "env_hesco_tall", x = -219, z = z, yaw = 90 })
end
-- Perches (A9): containers the squad can hold, each with a pallet ramp (buildPerches).
table.insert(DRESSING, { name = "env_container_olive", x = -124, z = -82, yaw = 0 }) -- LZ north-west
table.insert(DRESSING, { name = "env_container_rust", x = -130, z = -45, yaw = 0 }) -- on the highway deck
table.insert(DRESSING, { name = "env_container_rust", x = -10, z = -10, yaw = 90, perch = true }) -- Apron, 40 from (30,-10)
-- The Stack: a third container across the two of Depot column D (lands in the 2-stud gap
-- between them at z 32, so its raycast finds the pad, then `lift` puts it on their tops).
table.insert(DRESSING, { name = "env_container_rust", x = 250, z = 32, yaw = 90, lift = 9.55 })
table.insert(DRESSING, { name = "env_container_olive", x = 56, z = -45, yaw = 0, perch = true }) -- deck gantry step

-- Props (A11; assets/3d/README.md prop table). Registered meshes without an asset id yet are
-- skipped at boot, so these placements are live the moment the ids land in MeshAssets.
-- `floor` pins pieces inside a building to its floor (the raycast would find the roof).
local PROPS: { Dressing } = {
	-- The LZ
	{ name = "prop_light_tower", x = -74, z = -104, yaw = 30 }, -- beside its generator, clear of the checkpoint
	{ name = "prop_generator", x = -63, z = -108, yaw = 0 },
	{ name = "prop_pallet", x = -125, z = -118, yaw = 0, lift = 0 }, -- pallets stack beside their source, never singles (LEVELS A12b)
	{ name = "prop_pallet", x = -125, z = -118, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = -125, z = -118, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = -125, z = -118, yaw = 2, lift = 1.71 },
	{ name = "prop_pallet", x = -120.5, z = -118, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = -120.5, z = -118, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = -120.5, z = -118, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = -120.5, z = -118, yaw = 2, lift = 1.71 },
	{ name = "prop_body_bag", x = -64, z = -96, yaw = 90 },
	{ name = "prop_body_bag", x = -61, z = -96, yaw = 86 },
	{ name = "prop_portable_toilet", x = -116, z = -106, yaw = 90 },
	{ name = "prop_fuel_bladder", x = -136, z = -100, yaw = 0 },
	-- The Apron and the Screening Block
	{ name = "prop_body_bag", x = -8, z = 53, yaw = 90 },
	{ name = "prop_body_bag", x = -4, z = 53, yaw = 90 },
	{ name = "prop_body_bag", x = 0, z = 53, yaw = 90 },
	{ name = "prop_body_bag", x = 4, z = 53, yaw = 90 },
	{ name = "prop_concertina", x = -2, z = 84, yaw = 0 },
	{ name = "prop_light_tower", x = 12, z = 50, yaw = 0 },
	{ name = "prop_portable_toilet", x = 7, z = 84, yaw = 180 },
	{ name = "prop_portable_toilet", x = 11.6, z = 84, yaw = 180 },
	{ name = "prop_generator", x = -16, z = 84, yaw = 0 },
	{ name = "prop_car_sedan", x = 52, z = -4, yaw = 100 },
	{ name = "prop_dumpster", x = -8, z = 30, yaw = 20 },
	-- The Compound (hill top y 8)
	{ name = "prop_generator", x = 106, z = 30, yaw = 0 },
	{ name = "prop_pallet", x = 30, z = 98, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = 30, z = 98, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = 30, z = 98, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = 30, z = 98, yaw = 2, lift = 1.71 },
	{ name = "prop_cot", x = 56, z = 92, yaw = 0 },
	{ name = "prop_cot", x = 56, z = 96, yaw = 0 },
	{ name = "prop_light_tower", x = 60, z = 40, yaw = 0 },
	{ name = "prop_body_bag", x = 66, z = 90, yaw = 0 },
	{ name = "prop_body_bag", x = 66, z = 93, yaw = 0 },
	{ name = "prop_body_bag", x = 66, z = 96, yaw = 0 },
	-- The Ridge (hill top y 8; the ruin's ground floor)
	{ name = "prop_cot", x = -96, z = 42, yaw = 0, floor = 8 },
	{ name = "prop_cot", x = -96, z = 46, yaw = 0, floor = 8 },
	{ name = "prop_generator", x = -76, z = 44, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -126, z = 40, yaw = 90 },
	{ name = "prop_chainlink_panel", x = -126, z = 52, yaw = 90 },
	-- The Inner Gate (z -112)
	{ name = "prop_concertina", x = -44, z = -107, yaw = 0 }, -- clear of the generator (ends x -59)
	{ name = "prop_concertina", x = 6, z = -106, yaw = 0 },
	{ name = "prop_light_tower", x = -70, z = -132, yaw = 0 },
	{ name = "prop_generator", x = -4, z = -126, yaw = 0 },
	{ name = "prop_body_bag", x = -75, z = -121, yaw = 0 },
	{ name = "prop_body_bag", x = -75, z = -124, yaw = 0 },
	-- The highway deck (y 12)
	{ name = "prop_car_hatch", x = -200, z = -43, yaw = 10 },
	{ name = "prop_car_sedan", x = -70, z = -47, yaw = -8 },
	{ name = "prop_car_pickup", x = 160, z = -43, yaw = 5 },
	{ name = "prop_car_hatch", x = 240, z = -47, yaw = -12 },
	-- The Overlook (y 14)
	{ name = "prop_generator", x = 116, z = -116, yaw = 0 },
	{ name = "prop_light_tower", x = 120, z = -90, yaw = 0 },
	{ name = "env_barrier_jersey", x = 64, z = -38.5, yaw = 0 }, -- Deck jersey line (LEVELS D3)
	{ name = "env_barrier_jersey", x = 72, z = -38.5, yaw = 0 },
	{ name = "env_barrier_jersey", x = 84, z = -38.5, yaw = 0 },
	{ name = "env_barrier_jersey", x = 118, z = -38.5, yaw = 0 },
	{ name = "env_barrier_jersey", x = 126, z = -38.5, yaw = 0 },
	-- The Suburb: the Parade, the church, the north road
	{ name = "prop_car_sedan", x = -100, z = 192, yaw = 80 },
	{ name = "prop_car_hatch", x = 0, z = 208, yaw = -5 },
	{ name = "prop_car_pickup", x = 156, z = 196, yaw = 100 },
	{ name = "prop_car_sedan", x = 220, z = 208, yaw = 3 },
	{ name = "prop_car_sedan", x = -160, z = 204, yaw = 178 },
	{ name = "prop_car_hatch", x = 180, z = 196, yaw = -4 },
	{ name = "prop_dumpster", x = 108, z = 167, yaw = 0 }, -- the Walker step to the Parade roof
	{ name = "prop_dumpster", x = 70, z = 196, yaw = 15 },
	{ name = "prop_body_bag", x = 56, z = 240, yaw = 90 }, -- side by side (a bag is 6.6 long)
	{ name = "prop_body_bag", x = 60, z = 240, yaw = 90 },
	{ name = "prop_body_bag", x = 64, z = 240, yaw = 90 },
	{ name = "prop_plank", x = 30, z = 270, yaw = 20 },
	{ name = "prop_plank", x = -60, z = 230, yaw = 70 },
	{ name = "prop_portable_toilet", x = 100, z = 164, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -180, z = 165, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -168, z = 165, yaw = 0 },
	{ name = "prop_concertina", x = -10, z = 268, yaw = 0 },
	-- The Depot (pad y 0.3)
	{ name = "prop_pallet", x = 162, z = 26, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = 162, z = 26, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = 162, z = 26, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = 162, z = 26, yaw = 2, lift = 1.71 },
	{ name = "prop_pallet", x = 162, z = 38, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = 162, z = 38, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = 162, z = 38, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = 162, z = 38, yaw = 2, lift = 1.71 },
	{ name = "prop_pallet", x = 229, z = 70, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = 229, z = 70, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = 229, z = 70, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = 229, z = 70, yaw = 2, lift = 1.71 },
	{ name = "prop_generator", x = 228, z = 100, yaw = 0 },
	{ name = "prop_light_tower", x = 282, z = 110, yaw = 0 },
	{ name = "prop_light_tower", x = 166, z = 0, yaw = 0 },
	{ name = "prop_dumpster", x = 176, z = 104, yaw = 0 },
	{ name = "prop_fuel_bladder", x = 282, z = 58, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 200, z = -8, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 212, z = -8, yaw = 0 },
	{ name = "prop_chainlink_panel", x = 224, z = -8, yaw = 0 },
	{ name = "prop_plank", x = 226, z = 60, yaw = 40 },
	-- The Pumps
	{ name = "prop_fuel_bladder", x = 100, z = -168, yaw = 0 },
	{ name = "prop_fuel_bladder", x = 112, z = -170, yaw = 0 },
	{ name = "prop_car_hatch", x = 130, z = -174, yaw = 95 },
	{ name = "prop_generator", x = 158, z = -168, yaw = 0 },
	-- The Scrapyard and the Gate
	{ name = "prop_car_van", x = -120, z = -230, yaw = 40 },
	{ name = "prop_car_van", x = -80, z = -250, yaw = -30 },
	{ name = "prop_cargo_truck", x = -143, z = -120, yaw = 0 }, -- LZ supply truck: the pallet stacks sit at its tail (LEVELS D1)
	{ name = "prop_cargo_truck", x = 242, z = -10, yaw = 0 }, -- closes the Depot south line: crawl under the bed into the yard
	{ name = "prop_car_sedan", x = 16, z = -258, yaw = 20 },
	{ name = "prop_car_hatch", x = 130, z = -220, yaw = 70 },
	{ name = "prop_dumpster", x = -150, z = -198, yaw = 0 },
	{ name = "prop_dumpster", x = 70, z = -200, yaw = 30 },
	{ name = "prop_concertina", x = -200, z = -270, yaw = 0 },
	{ name = "prop_concertina", x = -120, z = -268, yaw = 0 },
	{ name = "prop_concertina", x = 60, z = -268, yaw = 0 },
	{ name = "prop_concertina", x = 140, z = -268, yaw = 0 },
	{ name = "prop_plank", x = -164, z = -220, yaw = 30 },
	{ name = "prop_plank", x = 90, z = -240, yaw = 60 },
	{ name = "prop_light_tower", x = -64, z = -244, yaw = 0 },
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
	{ name = "prop_portable_toilet", x = -280.6, z = 78, yaw = 180 },
	{ name = "prop_portable_toilet", x = -276, z = 78, yaw = 180 },
	{ name = "prop_portable_toilet", x = -271.4, z = 78, yaw = 180 },
	{ name = "prop_generator", x = -226, z = 78, yaw = 0 },
	{ name = "prop_light_tower", x = -232, z = 46, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -184, z = 100, yaw = 90 },
	{ name = "prop_chainlink_panel", x = -184, z = 112, yaw = 90 },
	{ name = "prop_concertina", x = -250, z = 160, yaw = 0 },
	{ name = "prop_body_bag", x = -240, z = 100, yaw = 0 },
	{ name = "prop_body_bag", x = -240, z = 103.5, yaw = 0 },
	{ name = "prop_body_bag", x = -232, z = 100, yaw = 0 }, -- 8 apart: a bag is 6.6 long
	{ name = "prop_body_bag", x = -232, z = 103.5, yaw = 0 },
	{ name = "prop_pallet", x = -224, z = 4, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = -224, z = 4, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = -224, z = 4, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = -224, z = 4, yaw = 2, lift = 1.71 },
	{ name = "prop_generator", x = -196, z = 4, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -236, z = -12, yaw = 0 },
	{ name = "prop_chainlink_panel", x = -224, z = -12, yaw = 0 },
	-- Outer hills
	{ name = "prop_light_tower", x = -172, z = -224, yaw = 0 }, -- SouthRise
	{ name = "prop_pallet", x = -207, z = -245, yaw = 0, lift = 0 },
	{ name = "prop_pallet", x = -207, z = -245, yaw = 4, lift = 0.57 },
	{ name = "prop_pallet", x = -207, z = -245, yaw = -3, lift = 1.14 },
	{ name = "prop_pallet", x = -207, z = -245, yaw = 2, lift = 1.71 },
	{ name = "prop_generator", x = 250, z = -220, yaw = 0 }, -- Depot mound
	{ name = "prop_generator", x = -216, z = 248, yaw = 0 }, -- NorthBluff
}
for _, prop in PROPS do
	table.insert(DRESSING, prop)
end

-- Ground patches (docs/LEVELS.md A12): thin Mud / Rock / darker-Ground sheets on
-- the floor at hill feet, along the roads and in the yards, so the ground reads as used.
-- Decoration only: no collision, no query (dressing raycasts land on the floor under them).
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

-- Perches (docs/LEVELS.md A9): every high spot the squad can hold has a pallet ramp up to
-- it, so a Walker (climb 5) gets there too and no perch is a free camp. A ramp is a
-- WedgePart that rises toward its yaw direction from `base` by `rise`; `length` defaults
-- to the kit's stair angle. Bases are known levels (ground 0, Depot pad 0.3, Compound 8,
-- highway deck 12), not raycast: the ramps go in before the dressing they lean on.
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
	{ x = 81.9, z = 44, yaw = 90, rise = 9.55, base = 8 }, -- Compound E container (100,44): no Walker-proof camp beside Site 1
}

local FENCE_LINE = 299.6 -- the fence stands just inside the boundary collider (inner face 300)
local FENCE_STEP = 12 -- one chain-link panel (12.06 wide) every 12 studs
local HIGHWAY_GAP = { -73, -17 } -- z band on the east / west edges: the highway embankment (slopes included) runs out here
local PERIMETER: { Dressing } = {
	-- North: towers past the fence, the Suburb running on as shell ruins and dead trees.
	{ name = "env_guard_tower", x = -180, z = 312, yaw = 180, decor = true },
	{ name = "env_guard_tower", x = -60, z = 312, yaw = 180, decor = true },
	{ name = "env_guard_tower", x = 60, z = 312, yaw = 180, decor = true },
	{ name = "env_guard_tower", x = 180, z = 312, yaw = 180, decor = true },
	{ name = "env_ruin_building", x = -150, z = 360, yaw = 10, shell = true, decor = true },
	{ name = "env_ruin_building", x = 40, z = 380, yaw = 185, shell = true, decor = true },
	{ name = "env_ruin_building", x = 200, z = 350, yaw = -15, shell = true, decor = true },
	{ name = "env_dead_tree", x = -240, z = 340, yaw = 30, decor = true },
	{ name = "env_dead_tree", x = -90, z = 410, yaw = 110, decor = true },
	{ name = "env_dead_tree", x = -20, z = 345, yaw = 200, decor = true },
	{ name = "env_dead_tree", x = 110, z = 420, yaw = 290, decor = true },
	{ name = "env_dead_tree", x = 150, z = 335, yaw = 60, decor = true },
	{ name = "env_dead_tree", x = 270, z = 390, yaw = 150, decor = true },
	-- East: towers, the field, the highway running on (built below) to a broken end.
	{ name = "env_guard_tower", x = 312, z = 180, yaw = -90, decor = true },
	{ name = "env_guard_tower", x = 312, z = 60, yaw = -90, decor = true },
	{ name = "env_guard_tower", x = 312, z = -150, yaw = -90, decor = true },
	{ name = "env_container_rust", x = 360, z = 120, yaw = 35, decor = true },
	{ name = "env_container_olive", x = 400, z = -200, yaw = -20, decor = true },
	{ name = "env_container_rust", x = 404, z = -45, yaw = 12, floor = 0, decor = true }, -- under the broken deck
	{ name = "env_dead_tree", x = 345, z = 250, yaw = 20, decor = true },
	{ name = "env_dead_tree", x = 420, z = 40, yaw = 140, decor = true },
	{ name = "env_dead_tree", x = 350, z = -110, yaw = 260, decor = true },
	{ name = "env_dead_tree", x = 380, z = -280, yaw = 80, decor = true },
	-- West: towers on the berm crest (top 10); the z 60 one lines up with the Lines' huts.
	{ name = "env_guard_tower", x = -327, z = 180, yaw = 90, floor = 10, decor = true },
	{ name = "env_guard_tower", x = -327, z = 60, yaw = 90, floor = 10, decor = true },
	{ name = "env_guard_tower", x = -327, z = -150, yaw = 90, floor = 10, decor = true },
	{ name = "env_container_olive", x = -404, z = -45, yaw = -12, floor = 0, decor = true },
	-- South: the outer wire past the Gate, unlit light towers, the road to the city and the
	-- traffic that never got through.
	{ name = "prop_light_tower", x = -150, z = -308, yaw = 0, decor = true },
	{ name = "prop_light_tower", x = -90, z = -308, yaw = 0, decor = true },
	{ name = "prop_light_tower", x = 30, z = -308, yaw = 0, decor = true },
	{ name = "prop_light_tower", x = 114, z = -308, yaw = 0, decor = true },
	{ name = "env_bus", x = -36, z = -345, yaw = 92, decor = true },
	{ name = "env_bus", x = -23, z = -392, yaw = 85, decor = true },
	{ name = "env_wreck_humvee", x = -37, z = -420, yaw = 70, decor = true },
	{ name = "env_container_olive", x = 10, z = -360, yaw = 60, decor = true },
	{ name = "env_container_rust", x = -80, z = -410, yaw = -30, decor = true },
	{ name = "env_dead_tree", x = -200, z = -350, yaw = 45, decor = true },
	{ name = "env_dead_tree", x = 160, z = -380, yaw = 170, decor = true },
	-- Corners
	{ name = "env_guard_tower", x = 312, z = 312, yaw = 225, decor = true },
	{ name = "env_guard_tower", x = -312, z = 312, yaw = 135, floor = 10, decor = true },
	{ name = "env_guard_tower", x = 312, z = -312, yaw = -45, decor = true },
	{ name = "env_guard_tower", x = -312, z = -312, yaw = 45, floor = 10, decor = true },
	-- The Gate's T-wall line carries on outside the fence (decor).
	{ name = "env_twall", x = -306, z = -274, yaw = 0, decor = true },
	{ name = "env_twall", x = -314, z = -274, yaw = 0, decor = true },
	{ name = "env_twall", x = -322, z = -274, yaw = 0, decor = true },
	{ name = "env_twall", x = 306, z = -274, yaw = 0, decor = true },
	{ name = "env_twall", x = 314, z = -274, yaw = 0, decor = true },
	{ name = "env_twall", x = 322, z = -274, yaw = 0, decor = true },
	-- Roadblocks where the highway deck meets the boundary (inside: real cover).
	{ name = "env_barrier_jersey", x = 296, z = -51, yaw = 90 },
	{ name = "env_barrier_jersey", x = 296, z = -45, yaw = 90 },
	{ name = "env_barrier_jersey", x = 296, z = -39, yaw = 90 },
	{ name = "env_barrier_jersey", x = -296, z = -51, yaw = 90 },
	{ name = "env_barrier_jersey", x = -296, z = -45, yaw = 90 },
	{ name = "env_barrier_jersey", x = -296, z = -39, yaw = 90 },
	{ name = "prop_concertina", x = 297, z = -48, yaw = 90, lift = 2.75 },
	{ name = "prop_concertina", x = -297, z = -48, yaw = 90, lift = 2.75 },
}
-- The fence: a chain-link panel every FENCE_STEP along each edge (yaw 0 north / south, 90
-- east / west) with a coil of wire on top, skipping the highway deck's ends (the roadblocks
-- close those) . Raycast-placed, so it rides the Pens terrace (6) on the west.
-- The fence line: one entry per panel. `placeFence` stands each panel on the lowest ground
-- under its two ends (its posts sink into a slope rather than one end floating) and puts a
-- coil of wire on top.
local FENCE: { FencePanel } = {}
for k = 0, 49 do
	local along = -294 + FENCE_STEP * k
	for _, edge in
		{
			{ x = along, z = FENCE_LINE, yaw = 0 },
			{ x = along, z = -FENCE_LINE, yaw = 0 },
			{ x = FENCE_LINE, z = along, yaw = 90 },
			{ x = -FENCE_LINE, z = along, yaw = 90 },
		}
	do
		local onSide = edge.yaw == 90
		if not (onSide and along > HIGHWAY_GAP[1] and along < HIGHWAY_GAP[2]) then
			table.insert(FENCE, edge)
		end
	end
end

-- The seven enterable buildings (docs/LEVELS.md section B). Coordinates are
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
				size = Vector3.new(16, 0.5, Config.Arena.Kit.CorridorMin),
				at = Vector3.new(20, 8.77, 0), -- 0.02 proud of the floor and the lip it crosses
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
			-- The Recover Logs desk, ground floor south-west corner under the window (the
			-- north-west corner is the stair run).
			{
				name = "Desk",
				size = Vector3.new(6, 2.6, 2.4),
				at = Vector3.new(-8, 1.3, -5.5),
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

local mission: MissionTypes.Mission = {
	Id = "delta",
	Name = "Checkpoint Delta",
	Hills = HILLS,
	Dressing = DRESSING,
	Patches = PATCHES,
	Ramps = RAMPS,
	Perimeter = PERIMETER,
	Fence = FENCE,
	Buildings = BUILDINGS,
}

return mission
