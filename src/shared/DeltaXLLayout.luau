--!strict
-- Checkpoint Delta XL, the grey test map (docs/sprints/DELTA_XL.md, docs/LEVELS.md > E):
-- today's Delta (600 x 600) in the middle of a 1,800 x 1,800 map with eight areas round it.
-- Plain data, studs, +X east, +Z north, centre (0, 0); the server builds it (DeltaXL) and
-- assets/maps/build/delta_xl_topdown.luau draws it from above. Every block here is a grey
-- stand-in for real art (plan step 5); sizes are what the real piece should take up.
--
-- Shapes:
--   Road     axis-aligned strip from (x0, z0) to (x1, z1); N-S roads are cut where an E-W
--            road crosses them (no two road faces ever overlap) and where `skip` says
--   Block    solid grey Part, bottom on y (default 0), `h` tall, w x d before its yaw (so a
--            ramp is w wide and d long); `shape` "cylinder" stands a
--            round tank or silo; `landmark` blocks never stream out; `burning` sets it alight
--   House    an enterable kit building (ArenaService.buildBuilding): a door in every wall,
--            windows, stairs and a roof ladder when it has two storeys
--   Spot     an environmental-story spot (an amber marker in the grey pass)

export type Road = {
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	width: number,
	surface: string, -- "asphalt" | "dirt"
	skip: { { number } }?, -- N-S roads: z ranges with no road (a bridge deck, the ford)
}

export type Block = {
	name: string,
	x: number,
	z: number,
	w: number, -- along x
	d: number, -- along z
	h: number,
	y: number?, -- bottom (default 0)
	yaw: number?,
	look: string?, -- "concrete" | "metal" | "wood" | "dark" | "rust" | "canvas" | "earth"
	shape: string?, -- "block" (default) | "cylinder" (w is the diameter)
	landmark: boolean?,
	burning: boolean?,
	ramp: boolean?, -- a WedgePart rising toward +z of its yaw
}

export type House = {
	name: string,
	x: number,
	z: number,
	w: number,
	d: number,
	storeys: number,
	storeyHeight: number?,
	yaw: number?,
	material: string, -- Config.Arena.Materials key
	wide: boolean?, -- a 10-wide opening on the south wall (barn, gym, warehouse)
}

export type Bridge = {
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	rail: number, -- height of the side walls (parapet or truss)
	towers: number?, -- portal towers this tall at both ends (a landmark)
}
export type Spot = { name: string, x: number, z: number, area: string }
export type Point = { name: string, x: number, y: number, z: number }
export type Area = {
	id: string,
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	landmark: string,
}

local L = {}

L.Half = 900 -- the map spans -900..900 on both axes
L.BaseHalf = 300 -- today's Delta in the middle

-- The nine squares (the middle one is today's base).
L.Areas = {
	{
		id = "farms",
		name = "the farms",
		x0 = -900,
		z0 = 300,
		x1 = -300,
		z1 = 900,
		landmark = "grain silos",
	},
	{
		id = "truckstop",
		name = "the truck stop",
		x0 = -300,
		z0 = 300,
		x1 = 300,
		z1 = 900,
		landmark = "bridge towers, truck stop sign",
	},
	{
		id = "waterworks",
		name = "the water works",
		x0 = 300,
		z0 = 300,
		x1 = 900,
		z1 = 900,
		landmark = "water tower",
	},
	{
		id = "camp",
		name = "the camp",
		x0 = -900,
		z0 = -300,
		x1 = -300,
		z1 = 300,
		landmark = "ball field floodlights",
	},
	{
		id = "base",
		name = "the checkpoint",
		x0 = -300,
		z0 = -300,
		x1 = 300,
		z1 = 300,
		landmark = "the comm tower",
	},
	{
		id = "sidings",
		name = "the rail yard",
		x0 = 300,
		z0 = -300,
		x1 = 900,
		z1 = 300,
		landmark = "gantry cranes",
	},
	{
		id = "outskirts",
		name = "the houses",
		x0 = -900,
		z0 = -900,
		x1 = -300,
		z1 = -300,
		landmark = "school chimney",
	},
	{
		id = "interchange",
		name = "the interchange",
		x0 = -300,
		z0 = -900,
		x1 = 300,
		z1 = -300,
		landmark = "the flyover",
	},
	{
		id = "fuelfarm",
		name = "the fuel farm",
		x0 = 300,
		z0 = -900,
		x1 = 900,
		z1 = -300,
		landmark = "burning tank and its smoke",
	},
} :: { Area }

-- The river: a channel across the whole map, 12 deep with steep banks nobody climbs out of.
-- Crossings: the ford (on foot, a shallow bed), the highway bridge and the rail bridge. Anyone
-- who falls in walks out at the ford or up a boat ramp (`ramps`: along the channel against
-- one bank, rising toward x1).
L.River = {
	z0 = 446, -- the south bank's edge (the ground stops here)
	z1 = 514, -- the north bank's edge
	bank = 4, -- the bank walls' depth into the channel
	bed = -12, -- top of the bed
	water = -11, -- top of the water (ankle deep: a dry-season river)
	ford = { x0 = -690, x1 = -610, bed = -2, approach = 20 },
	ramps = {
		{ x0 = 250, x1 = 280, bank = "south" },
		{ x0 = -330, x1 = -300, bank = "north" },
		{ x0 = 760, x1 = 790, bank = "north" },
	},
}

-- Decks over the river: top 0.2 (level with the roads), from z 440 to 520.
L.Bridges = {
	{ name = "HighwayBridge", x0 = -46, x1 = -14, z0 = 440, z1 = 520, rail = 3, towers = 56 },
	{ name = "RailBridge", x0 = 640, x1 = 696, z0 = 440, z1 = 520, rail = 10 },
} :: { Bridge }

-- The ring road rises over the highway on a flyover: deck top 24.2, ramps either side.
L.Flyover =
	{ z = -560, width = 40, x0 = -150, x1 = 90, ramp = 120, height = 24, pillars = { -80, 20 } }

local FORD = { 446, 514 }
local BRIDGE = { 440, 520 }
L.Roads = {
	-- The highway (Route 9) through the Gate lane: north to the bridge, south to the coast.
	{
		name = "HighwayNorth",
		x0 = -30,
		z0 = 300,
		x1 = -30,
		z1 = 900,
		width = 24,
		surface = "asphalt",
		skip = { BRIDGE },
	},
	{
		name = "HighwaySouth",
		x0 = -30,
		z0 = -900,
		x1 = -30,
		z1 = -300,
		width = 24,
		surface = "asphalt",
	},
	-- E-W: the farm road south of the river, the base's north road carried out, the ring road.
	{ name = "FarmRoad", x0 = -900, z0 = 420, x1 = 900, z1 = 420, width = 16, surface = "asphalt" },
	{
		name = "NorthRoadWest",
		x0 = -900,
		z0 = 200,
		x1 = -300,
		z1 = 200,
		width = 16,
		surface = "asphalt",
	},
	{
		name = "NorthRoadEast",
		x0 = 300,
		z0 = 200,
		x1 = 900,
		z1 = 200,
		width = 16,
		surface = "asphalt",
	},
	{
		name = "RingRoadWest",
		x0 = -900,
		z0 = -560,
		x1 = -270,
		z1 = -560,
		width = 20,
		surface = "asphalt",
	},
	{
		name = "RingRoadEast",
		x0 = 210,
		z0 = -560,
		x1 = 900,
		z1 = -560,
		width = 20,
		surface = "asphalt",
	},
	-- N-S: the dirt track (crosses at the ford) and the rail service road (over the rail bridge).
	{
		name = "DirtTrack",
		x0 = -650,
		z0 = -900,
		x1 = -650,
		z1 = 900,
		width = 12,
		surface = "dirt",
		skip = { FORD },
	},
	{
		name = "ServiceRoad",
		x0 = 684,
		z0 = -550,
		x1 = 684,
		z1 = 900,
		width = 14,
		surface = "asphalt",
		skip = { BRIDGE },
	},
} :: { Road }

-- The rail line (east side) and the yard's two sidings. Bed top 0.15, rails 0.4 on it.
L.Rail = {
	x = 650,
	gauge = 5,
	bed = 10,
	skip = BRIDGE, -- the bed stops at the bridge (the rails run on over the deck)
	sidings = { { x = 620, z0 = -220, z1 = 180 }, { x = 595, z0 = -220, z1 = 180 } },
}

-- Where the base's fence opens: roads out, and breaches the crowd cut when the checkpoint
-- fell. `at` is along the side (x on north / south, z on east / west).
L.FenceGaps = {
	{ side = "north", at = -30, width = 36 },
	{ side = "north", at = -210, width = 24 },
	{ side = "north", at = 150, width = 24 },
	{ side = "south", at = -30, width = 36 },
	{ side = "south", at = -200, width = 24 },
	{ side = "south", at = 186, width = 24 },
	{ side = "east", at = 200, width = 36 },
	{ side = "east", at = 60, width = 24 },
	{ side = "east", at = -180, width = 24 },
	{ side = "west", at = 200, width = 36 },
	{ side = "west", at = 0, width = 24 },
	{ side = "west", at = -180, width = 24 },
}

-- True when a base fence panel at (x, z) stands in a gap (12-stud panels: a panel whose
-- centre is within half the gap plus half a panel goes).
function L.inFenceGap(x: number, z: number): boolean
	local edge = L.BaseHalf - 1
	for _, gap in L.FenceGaps do
		local along, onSide
		if gap.side == "north" then
			along, onSide = x, z > edge
		elseif gap.side == "south" then
			along, onSide = x, z < -edge
		elseif gap.side == "east" then
			along, onSide = z, x > edge
		else
			along, onSide = z, x < -edge
		end
		if onSide and math.abs(along - gap.at) < gap.width / 2 + 6 then
			return true
		end
	end
	return false
end

-- Drops (the four corners, plan point 2): NW, NE, SW, SE. The squad lands round the point.
L.Drops = {
	{ name = "the farms", x = -690, y = 0.6, z = 700 },
	{ name = "the water works", x = 610, y = 0.6, z = 800 },
	{ name = "the houses", x = -610, y = 0.6, z = -720 },
	{ name = "the fuel farm", x = 560, y = 0.6, z = -720 },
} :: { Point }

-- Pickups: the base pad (today's landing pad, "halfway back") and four outer ones.
L.Pickups = {
	{ name = "the landing pad", x = -90, y = 0.6, z = -90 },
	{ name = "the truck stop", x = -80, y = 0.6, z = 800 },
	{ name = "the ball field", x = -740, y = 0.6, z = 0 },
	{ name = "the rail yard field", x = 790, y = 0.6, z = 80 },
	{ name = "the flyover", x = 30, y = 24.8, z = -560 },
} :: { Point }

-- Lamp posts (grey stand-ins named env_lamp_post so Lights On finds them) by each generator.
L.Lamps = {
	{ 500, -600 },
	{ 580, -600 },
	{ 620, -700 },
	{ 480, -650 },
	{ 500, -760 },
	{ 700, 620 },
	{ 760, 640 },
	{ 700, 740 },
	{ 780, 700 },
	{ -500, 0 },
	{ -420, 60 },
	{ -560, 60 },
	{ -480, -40 },
	{ -400, -30 },
}

local blocks: { Block } = {}
local houses: { House } = {}
local spots: { Spot } = {}
local function block(entry: Block)
	table.insert(blocks, entry)
end
local function house(entry: House)
	table.insert(houses, entry)
end
local function spot(area: string, name: string, x: number, z: number)
	table.insert(spots, { name = name, x = x, z = z, area = area })
end

-- The Pens' terrace (6) meets the west edge of the base: a slope down to the camp.
block({
	name = "PensShoulder",
	x = -303.6,
	z = 120,
	w = 60,
	d = 7.2,
	h = 6,
	yaw = 90,
	ramp = true,
	look = "earth",
})

---------------------------------------------------------------------------- the farms (NW)
-- Landmark: three grain silos and the elevator leg beside them.
block({
	name = "Silo",
	x = -520,
	z = 780,
	w = 22,
	d = 22,
	h = 70,
	shape = "cylinder",
	landmark = true,
	look = "metal",
})
block({
	name = "Silo",
	x = -490,
	z = 780,
	w = 22,
	d = 22,
	h = 70,
	shape = "cylinder",
	landmark = true,
	look = "metal",
})
block({
	name = "Silo",
	x = -505,
	z = 806,
	w = 22,
	d = 22,
	h = 70,
	shape = "cylinder",
	landmark = true,
	look = "metal",
})
block({
	name = "SiloElevator",
	x = -540,
	z = 770,
	w = 6,
	d = 6,
	h = 80,
	landmark = true,
	look = "rust",
})
house({ name = "Farmhouse", x = -760, z = 620, w = 20, d = 14, storeys = 2, material = "brick" })
house({
	name = "Barn",
	x = -560,
	z = 640,
	w = 30,
	d = 20,
	storeys = 1,
	storeyHeight = 14,
	material = "wood",
	wide = true,
})
block({ name = "Tractor", x = -640, z = 528, w = 6, d = 10, h = 7, look = "rust" })
block({ name = "HayTrailer", x = -640, z = 545, w = 7, d = 16, h = 5, look = "wood" })
block({ name = "FamilyCar", x = -700, z = 560, w = 6, d = 12, h = 5, yaw = 25, look = "metal" })
block({ name = "HayBale", x = -800, z = 760, w = 4, d = 4, h = 4, look = "wood" })
block({ name = "HayBale", x = -806, z = 770, w = 4, d = 4, h = 4, look = "wood" })
block({ name = "HayBale", x = -790, z = 800, w = 4, d = 4, h = 4, look = "wood" })
block({ name = "FarmStand", x = -450, z = 380, w = 10, d = 8, h = 6, look = "wood" })
spot("farms", "the barn's cots under a red cross on the roof", -565, 655)
spot("farms", "the tractor's trailer stacked with suitcases, stuck at the ford", -632, 545)
spot("farms", "screening wristbands on the family car's dashboard", -690, 568)

------------------------------------------------------------------------ the truck stop (N)
-- Landmarks: the highway bridge's towers (built with the bridge) and the truck stop sign.
block({ name = "TruckStopLot", x = 75, z = 760, w = 170, d = 120, h = 0.3, look = "concrete" })
house({ name = "Diner", x = 40, z = 806, w = 30, d = 16, storeys = 1, material = "render" })
block({ name = "CanopyPost", x = 106, z = 750, w = 1, d = 1, h = 10, y = 0.3, look = "metal" })
block({ name = "CanopyPost", x = 144, z = 750, w = 1, d = 1, h = 10, y = 0.3, look = "metal" })
block({ name = "CanopyPost", x = 106, z = 770, w = 1, d = 1, h = 10, y = 0.3, look = "metal" })
block({ name = "CanopyPost", x = 144, z = 770, w = 1, d = 1, h = 10, y = 0.3, look = "metal" })
block({ name = "Canopy", x = 125, z = 760, w = 40, d = 22, h = 1.2, y = 10.3, look = "concrete" })
block({ name = "SignPole", x = 150, z = 840, w = 3, d = 3, h = 70, landmark = true, look = "metal" })
block({
	name = "SignBoard",
	x = 150,
	z = 842.5,
	w = 22,
	d = 2,
	h = 10,
	y = 62,
	landmark = true,
	look = "dark",
})
block({
	name = "Tanker",
	x = 100,
	z = 720,
	w = 8,
	d = 30,
	h = 10,
	y = 0.3,
	yaw = 90,
	look = "metal",
})
-- The army convoy that never went north, stalled on the highway.
block({ name = "ArmyTruck", x = -36, z = 580, w = 8, d = 26, h = 9, look = "dark" })
block({ name = "ArmyTruck", x = -24, z = 612, w = 8, d = 26, h = 9, look = "dark" })
block({ name = "ArmyTruck", x = -36, z = 644, w = 8, d = 26, h = 9, look = "dark" })
block({ name = "ArmyTruck", x = -24, z = 676, w = 8, d = 26, h = 9, look = "dark" })
spot("truckstop", "the diner's windows boarded from the inside", 40, 796)
spot("truckstop", "the last convoy truck, tailgate down, nobody in it", -24, 692)
spot("truckstop", "a tanker with its hose still in the ground tank", 100, 740)

---------------------------------------------------------------------- the water works (NE)
-- Landmark: the water tower (four legs and the tank).
for _, leg in { { 808, 788 }, { 832, 788 }, { 808, 812 }, { 832, 812 } } do
	block({
		name = "TowerLeg",
		x = leg[1],
		z = leg[2],
		w = 2,
		d = 2,
		h = 60,
		landmark = true,
		look = "metal",
	})
end
block({
	name = "TowerTank",
	x = 820,
	z = 800,
	w = 34,
	d = 34,
	h = 22,
	y = 60,
	shape = "cylinder",
	landmark = true,
	look = "metal",
})
house({ name = "PumpHouse", x = 740, z = 700, w = 28, d = 16, storeys = 2, material = "brick" })
block({ name = "Generator", x = 720, z = 655, w = 8, d = 4.5, h = 5, look = "dark" })
block({
	name = "SettlingTank",
	x = 780,
	z = 560,
	w = 36,
	d = 36,
	h = 6,
	shape = "cylinder",
	look = "concrete",
})
block({
	name = "SettlingTank",
	x = 840,
	z = 560,
	w = 36,
	d = 36,
	h = 6,
	shape = "cylinder",
	look = "concrete",
})
block({ name = "Drums", x = 700, z = 742, w = 6, d = 6, h = 4, look = "rust" })
block({ name = "Drums", x = 708, z = 742, w = 6, d = 6, h = 4, look = "rust" })
spot("waterworks", "chlorine drums with army stencils, for the camp's water", 704, 750)
spot("waterworks", "a bunk room in the pump house: the crew never left", 740, 690)
spot("waterworks", "a rope hanging from the water tower's rail", 820, 786)

------------------------------------------------------------------------------ the camp (W)
-- Landmark: the ball field's four floodlights.
block({ name = "BallField", x = -740, z = 0, w = 140, d = 140, h = 0.12, look = "earth" })
for _, corner in { { -815, -75 }, { -815, 75 }, { -665, -75 }, { -665, 75 } } do
	block({
		name = "Floodlight",
		x = corner[1],
		z = corner[2],
		w = 2,
		d = 2,
		h = 60,
		landmark = true,
		look = "metal",
	})
	block({
		name = "FloodlightHead",
		x = corner[1],
		z = corner[2],
		w = 10,
		d = 2,
		h = 4,
		y = 60,
		landmark = true,
		look = "dark",
	})
end
block({ name = "Bleachers", x = -740, z = -90, w = 40, d = 8, h = 6, look = "metal" })
for _, z in { -150, -110, -70, 80, 120 } do
	for _, x in { -560, -525, -490, -455, -420, -385 } do
		block({ name = "Tent", x = x, z = z, w = 10, d = 16, h = 6, look = "canvas" })
	end
end
house({ name = "AidTent", x = -470, z = 20, w = 24, d = 14, storeys = 1, material = "panel" })
block({ name = "Generator", x = -440, z = 40, w = 8, d = 4.5, h = 5, look = "dark" })
block({ name = "FoodTable", x = -560, z = 30, w = 12, d = 2, h = 3, look = "wood" })
block({ name = "FoodTable", x = -560, z = 42, w = 12, d = 2, h = 3, look = "wood" })
spot("camp", "the aid tent, where it started inside the wire", -470, 8)
spot("camp", "suitcases stacked on the bleachers, names chalked on them", -740, -82)
spot("camp", "the food line's tables, trays still out", -545, 36)

-------------------------------------------------------------------------- the rail yard (E)
-- Landmark: two gantry cranes over the tracks.
for _, z in { -230, 230 } do
	block({
		name = "CraneLeg",
		x = 575,
		z = z,
		w = 3,
		d = 3,
		h = 70,
		landmark = true,
		look = "rust",
	})
	block({
		name = "CraneLeg",
		x = 705,
		z = z,
		w = 3,
		d = 3,
		h = 70,
		landmark = true,
		look = "rust",
	})
	block({
		name = "CraneBeam",
		x = 640,
		z = z,
		w = 136,
		d = 6,
		h = 6,
		y = 70,
		landmark = true,
		look = "rust",
	})
end
for _, wagon in
	{
		{ 620, -170 },
		{ 620, -120 },
		{ 620, -20 },
		{ 620, 30 },
		{ 595, -150 },
		{ 595, -60 },
		{ 595, 80 },
	}
do
	block({
		name = "Wagon",
		x = wagon[1],
		z = wagon[2],
		w = 8,
		d = 40,
		h = 10,
		y = 0.15,
		look = "rust",
	})
end
block({ name = "Locomotive", x = 650, z = -262, w = 10, d = 50, h = 14, y = 0.15, look = "dark" })
block({ name = "Platform", x = 570, z = -60, w = 14, d = 120, h = 4, look = "concrete" })
house({
	name = "Warehouse",
	x = 780,
	z = -100,
	w = 40,
	d = 24,
	storeys = 1,
	storeyHeight = 12,
	material = "metal",
	wide = true,
})
spot("sidings", "the hospital train: cots in the open wagons", 612, -120)
spot("sidings", "stretchers lined up on the loading platform", 578, -60)
spot("sidings", "the locomotive's cab door open, the engine cold", 657, -236)

-------------------------------------------------------------------------- the houses (SW)
-- Landmark: the school's boiler chimney.
house({ name = "School", x = -760, z = -700, w = 60, d = 20, storeys = 2, material = "cinder" })
house({
	name = "Gym",
	x = -760,
	z = -760,
	w = 36,
	d = 30,
	storeys = 1,
	storeyHeight = 14,
	material = "cinder",
	wide = true,
})
block({ name = "Chimney", x = -722, z = -727, w = 6, d = 6, h = 55, landmark = true, look = "dark" })
house({ name = "House", x = -820, z = -525, w = 16, d = 12, storeys = 2, material = "render" })
house({ name = "House", x = -560, z = -525, w = 16, d = 12, storeys = 2, material = "brick" })
house({ name = "House", x = -500, z = -595, w = 16, d = 12, storeys = 2, material = "render" })
house({ name = "House", x = -380, z = -595, w = 16, d = 12, storeys = 2, material = "brick" })
for _, at in { { -760, -525 }, { -440, -525 }, { -820, -595 }, { -760, -595 }, { -560, -595 } } do
	block({ name = "HouseBlock", x = at[1], z = at[2], w = 16, d = 12, h = 9, look = "concrete" })
end
block({ name = "SchoolBus", x = -700, z = -640, w = 8, d = 36, h = 10, yaw = 20, look = "rust" })
spot("outskirts", "WAITING FOR BUSES painted on a sheet in the gym", -760, -742)
spot("outskirts", "a red X on a front door: the search team's mark", -560, -517)
spot("outskirts", "the school bus that came for them, on its side", -690, -628)

---------------------------------------------------------------------- the interchange (S)
-- Landmark: the flyover (built from L.Flyover). The jam heading for the coast.
for _, car in
	{ { -36, -330 }, { -24, -352 }, { -35, -380 }, { -22, -410 }, { -37, -440 }, { -25, -470 } }
do
	block({ name = "Car", x = car[1], z = car[2], w = 6, d = 12, h = 5, look = "metal" })
end
block({ name = "Bus", x = -24, z = -500, w = 8, d = 36, h = 10, look = "rust" })
block({ name = "GantryPost", x = -48, z = -460, w = 2, d = 2, h = 22, look = "metal" })
block({ name = "GantryPost", x = -12, z = -460, w = 2, d = 2, h = 22, look = "metal" })
block({ name = "GantryBeam", x = -30, z = -460, w = 38, d = 2, h = 3, y = 19, look = "metal" })
-- The army's roadblock, turned to face the city.
block({ name = "Jersey", x = -40, z = -700, w = 10, d = 2, h = 3, look = "concrete" })
block({ name = "Jersey", x = -20, z = -700, w = 10, d = 2, h = 3, look = "concrete" })
block({
	name = "BurnedBus",
	x = 120,
	z = -500,
	w = 8,
	d = 36,
	h = 10,
	yaw = 75,
	look = "dark",
	burning = true,
})
spot("interchange", "the roadblock faces the city, not the checkpoint", -30, -708)
spot("interchange", "cars with every door open, keys in", -29, -380)
spot("interchange", "the burned bus that tried the slip road", 120, -520)

------------------------------------------------------------------------ the fuel farm (SE)
-- Landmark: the burning tank and its smoke; a flare stack beside it.
block({
	name = "FuelTank",
	x = 720,
	z = -760,
	w = 40,
	d = 40,
	h = 24,
	shape = "cylinder",
	landmark = true,
	look = "metal",
	burning = true,
})
block({
	name = "FuelTank",
	x = 800,
	z = -680,
	w = 36,
	d = 36,
	h = 24,
	shape = "cylinder",
	look = "metal",
})
block({
	name = "FuelTank",
	x = 800,
	z = -830,
	w = 36,
	d = 36,
	h = 24,
	shape = "cylinder",
	look = "metal",
})
block({
	name = "FuelTank",
	x = 590,
	z = -820,
	w = 30,
	d = 30,
	h = 20,
	shape = "cylinder",
	look = "metal",
})
block({
	name = "FlareStack",
	x = 850,
	z = -760,
	w = 4,
	d = 4,
	h = 60,
	landmark = true,
	look = "rust",
})
house({ name = "SiteOffice", x = 520, z = -620, w = 18, d = 12, storeys = 1, material = "panel" })
block({ name = "Generator", x = 540, z = -645, w = 8, d = 4.5, h = 5, look = "dark" })
block({ name = "Tanker", x = 470, z = -700, w = 8, d = 30, h = 10, yaw = 10, look = "metal" })
block({ name = "Tanker", x = 460, z = -760, w = 8, d = 30, h = 10, yaw = -5, look = "metal" })
block({ name = "FoamTruck", x = 740, z = -700, w = 8, d = 26, h = 10, yaw = 30, look = "rust" })
spot("fuelfarm", "an evacuation map drawn by hand on the site office wall", 520, -630)
spot("fuelfarm", "the foam truck, hoses out, abandoned mid-fight", 752, -690)
spot("fuelfarm", "the tank that burns: someone lit it to stop them", 720, -736)

L.Blocks = blocks
L.Houses = houses
L.Spots = spots

return L
