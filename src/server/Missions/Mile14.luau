--!strict
-- Mile 14's layout (docs/LEVELS.md C1; Nova, 2026-11-11: the night map, played quiet, "mainly
-- a highway" with "some wooded areas in it"). The stalled evacuation convoy on Route 9: the
-- highway deck runs the map south to north at 12, jammed with sealed buses in both lanes and
-- broken by the Culvert, the one crossing under it. West of the deck the Rest Stop, east the
-- Toll Plaza, woods on both shoulders to go round the Jam unseen.
-- First pass (built with the stealth Infected as the test bed): the deck, the Jam, the Toll
-- booths, the Rest Stop's diner and the woods (pines, some broadleaf, brush: build/trees.py). Still to come from C1: the Overpass span, the off-ramp, pumps and canopy, the
-- water tower, the sleepers' places and the objectives.

local MissionTypes = require(script.Parent.MissionTypes)

type Hill = MissionTypes.Hill
type Dressing = MissionTypes.Dressing
type Patch = MissionTypes.Patch
type Ramp = MissionTypes.Ramp
type FencePanel = MissionTypes.FencePanel
type BuildingSpec = MissionTypes.BuildingSpec

local DECK = 12 -- the highway deck's height
local CULVERT = { -60, -20 } -- z band of the gap under the deck (the Culvert)

local HILLS: { Hill } = {
	-- The deck, x -30..30, in two halves with vertical abutments at the Culvert and open ends
	-- at the map's edges (the road runs on past the fence).
	{
		name = "HighwayS",
		x = 0,
		z = (-300 + CULVERT[1]) / 2,
		top = Vector2.new(60, CULVERT[1] + 300),
		height = DECK,
		open = { north = true, south = true },
	},
	{
		name = "HighwayN",
		x = 0,
		z = (CULVERT[2] + 300) / 2,
		top = Vector2.new(60, 300 - CULVERT[2]),
		height = DECK,
		open = { north = true, south = true },
	},
	-- The Toll Plaza's raised lot east of the deck.
	{ name = "TollPlaza", x = 160, z = 60, top = Vector2.new(120, 80), height = 6 },
}

local DRESSING: { Dressing } = {
	-- The Rest Stop's diner, west of the deck.
	{ name = "env_ruin_building", x = -170, z = -200, yaw = 0 },
	-- The Toll Plaza: four booths across the lanes, jersey pairs at the lane mouths.
	{ name = "env_checkpoint", x = 160, z = 32, yaw = 90 },
	{ name = "env_checkpoint", x = 160, z = 48, yaw = 90 },
	{ name = "env_checkpoint", x = 160, z = 64, yaw = 90 },
	{ name = "env_checkpoint", x = 160, z = 80, yaw = 90 },
	{ name = "env_barrier_jersey", x = 132, z = 40, yaw = 90 },
	{ name = "env_barrier_jersey", x = 132, z = 72, yaw = 90 },
	{ name = "env_barrier_jersey", x = 188, z = 40, yaw = 90 },
	{ name = "env_barrier_jersey", x = 188, z = 72, yaw = 90 },
}

-- The Jam: sealed buses nose to tail in both lanes, every 48 studs, none over the Culvert.
for k = 0, 11 do
	local z = -276 + 48 * k
	if z > CULVERT[1] - 10 and z < CULVERT[2] + 10 then
		continue
	end
	table.insert(DRESSING, { name = "env_bus", x = -14, z = z, yaw = 90 })
	table.insert(DRESSING, { name = "env_bus", x = 14, z = z + 20, yaw = 90 })
end

-- The woods: stands of trees on both shoulders and round the Rest Stop, scattered from a
-- fixed seed so the map is the same every run. Clear of the deck's embankments (x -45..45).
local WOODS = {
	{ x0 = 60, x1 = 130, z0 = -270, z1 = -90, count = 34 }, -- east shoulder, south
	{ x0 = -140, x1 = -60, z0 = 60, z1 = 270, count = 40 }, -- west shoulder, north
	{ x0 = 235, x1 = 285, z0 = 110, z1 = 270, count = 24 }, -- east edge behind the Toll Plaza (clear of its lot and the edge stub at z -45)
	{ x0 = -285, x1 = -110, z0 = -285, z1 = -245, count = 24 }, -- behind the Rest Stop
}
local scatter = Random.new(14)
-- Mostly tall pines, young ones between, a broadleaf now and then; a shrub for every third tree.
local function treeKind(): string
	local roll = scatter:NextNumber()
	return if roll < 0.6
		then "env_pine_tall"
		elseif roll < 0.82 then "env_pine_small"
		else "env_tree_leafy"
end
for _, wood in WOODS do
	for k = 1, wood.count do
		table.insert(DRESSING, {
			name = treeKind(),
			x = math.floor(scatter:NextNumber(wood.x0, wood.x1)),
			z = math.floor(scatter:NextNumber(wood.z0, wood.z1)),
			yaw = scatter:NextInteger(0, 359),
		})
		if k % 3 == 0 then
			table.insert(DRESSING, {
				name = "env_shrub",
				x = math.floor(scatter:NextNumber(wood.x0, wood.x1)),
				z = math.floor(scatter:NextNumber(wood.z0, wood.z1)),
				yaw = scatter:NextInteger(0, 359),
			})
		end
	end
end
-- Brush along both foots of the deck's embankments: cover to creep past the Jam.
for k = 0, 17 do
	local z = -285 + k * 33
	for _, x in { -52, 52 } do
		if z > CULVERT[1] - 12 and z < CULVERT[2] + 12 then
			continue -- the abutments' corners
		end
		table.insert(DRESSING, {
			name = "env_shrub",
			x = x + scatter:NextInteger(-4, 4),
			z = z + scatter:NextInteger(-6, 6),
			yaw = scatter:NextInteger(0, 359),
		})
	end
end

local PATCHES: { Patch } = {
	{ x = -170, z = -170, w = 120, d = 100, kind = "rock" }, -- the Rest Stop's lot
}

local RAMPS: { Ramp } = {}

-- The fence round the map, open where the deck runs out at the north and south edges.
local FENCE_LINE = 299.6
local FENCE: { FencePanel } = {}
for k = 0, 49 do
	local along = -294 + 12 * k
	for _, edge in
		{
			{ x = along, z = FENCE_LINE, yaw = 0 },
			{ x = along, z = -FENCE_LINE, yaw = 0 },
			{ x = FENCE_LINE, z = along, yaw = 90 },
			{ x = -FENCE_LINE, z = along, yaw = 90 },
		}
	do
		local acrossDeck = edge.yaw == 0 and math.abs(along) < 46
		if not acrossDeck then
			table.insert(FENCE, edge)
		end
	end
end

local BUILDINGS: { BuildingSpec } = {}

local mission: MissionTypes.Mission = {
	Id = "mile14",
	Name = "Mile 14",
	Hills = HILLS,
	Dressing = DRESSING,
	Patches = PATCHES,
	Ramps = RAMPS,
	Perimeter = {},
	Fence = FENCE,
	Buildings = BUILDINGS,
}

return mission
