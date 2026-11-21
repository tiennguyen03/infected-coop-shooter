--!strict
-- Mile 14's v2 layout as plain numbers (owner 2026-11-20: "obviously the Blender v2"): the
-- frame, pads, boss route, earthworks, blocks and the convoy, transcribed from
-- assets/3d/build/mile14_v2.py (HILLS, PARTS, _jam_vehicles, _toll, _rest_stop,
-- _weigh_station) in grey blocks. Plain data so tests/Mile14.spec.luau can check it outside
-- Studio; Mile14.luau turns it into a MissionTypes.Mission. Positions are { x, y, z } studs,
-- the deck ("the Jam") at 12, the county road and the Overpass span at 26.
-- Left out for the grey frame: the dressing kit not uploaded yet (toll booths and canopies,
-- gantries, signs, the fuel canopy, sound walls, the skyline), the cars, and everything past
-- the frame. Those come with the art pass (loop sprint 5).

local DECK = 12
local SPAN = 26
local OVER_Z = 80 -- the Overpass centre line
local TOLL_Z = 310 -- the booth row

type Vec = { number }
export type HillData = {
	name: string,
	x: number,
	z: number,
	top: { number },
	height: number,
	open: { [string]: boolean }?,
}
export type PartData = { name: string, kind: string, at: Vec, size: Vec, yaw: number? }
export type DressingData = {
	name: string,
	x: number,
	z: number,
	yaw: number,
	burning: boolean?,
	floor: number?,
}
-- The road's top on the deck: buses under the span or a toll canopy would raycast onto the roof.
local ROAD_TOP = DECK + 0.1

local NS = { north = true, south = true }
local EW = { east = true, west = true }

local HILLS: { HillData } = {
	{ name = "JamS", x = 0, z = -263, top = { 110, 374 }, height = DECK, open = NS }, -- z -450..-76
	{ name = "JamN", x = 0, z = 83, top = { 110, 294 }, height = DECK, open = NS }, -- z -64..230
	{ name = "TollApron", x = 0, z = TOLL_Z, top = { 170, 160 }, height = DECK },
	{
		name = "AdminLot",
		x = 125,
		z = TOLL_Z,
		top = { 80, 100 },
		height = DECK,
		open = { west = true },
	},
	{ name = "JamNN", x = 0, z = 420, top = { 110, 60 }, height = DECK, open = NS },
	-- The county road's embankments, cut at the frame (the generator runs them on to 420).
	{ name = "OverpassW", x = -191.5, z = OVER_Z, top = { 257, 36 }, height = SPAN, open = EW },
	{ name = "OverpassE", x = 191.5, z = OVER_Z, top = { 257, 36 }, height = SPAN, open = EW },
	{ name = "TowerKnoll", x = 225, z = -370, top = { 50, 50 }, height = 8 },
}

local PARTS: { PartData } = {
	{ name = "CulvertRoof", kind = "concrete", at = { 0, 9.5, -70 }, size = { 110, 5, 12 } }, -- 7 clear under it
	{ name = "JamRoad", kind = "road", at = { 0, DECK + 0.05, 0 }, size = { 108, 0.1, 900 } },
	{ name = "MedianS", kind = "grass", at = { 0, DECK + 0.12, -111 }, size = { 19, 0.14, 678 } },
	{ name = "MedianN", kind = "grass", at = { 0, DECK + 0.12, 420 }, size = { 19, 0.14, 58 } },
	{
		name = "CountyRoadW",
		kind = "road",
		at = { -191.5, SPAN + 0.05, OVER_Z },
		size = { 257, 0.1, 30 },
	},
	{
		name = "CountyRoadE",
		kind = "road",
		at = { 191.5, SPAN + 0.05, OVER_Z },
		size = { 257, 0.1, 30 },
	},
	-- The Overpass span over the deck (the generator's env_overpass_span mesh, as a slab) and
	-- its parapets; the bents under it.
	{
		name = "OverpassSpan",
		kind = "concrete",
		at = { 0, SPAN - 0.75, OVER_Z },
		size = { 126, 1.5, 34 },
	},
	{
		name = "SpanParapetN",
		kind = "concrete",
		at = { 0, SPAN + 1.5, OVER_Z + 16.8 },
		size = { 126, 3, 1 },
	},
	{
		name = "SpanParapetS",
		kind = "concrete",
		at = { 0, SPAN + 1.5, OVER_Z - 16.8 },
		size = { 126, 3, 1 },
	},
	{
		name = "BentW",
		kind = "concrete",
		at = { -50, (DECK + SPAN - 1.5) / 2, OVER_Z },
		size = { 3, SPAN - 1.5 - DECK, 24 },
	},
	{
		name = "BentM",
		kind = "concrete",
		at = { 0, (DECK + SPAN - 1.5) / 2, OVER_Z },
		size = { 3, SPAN - 1.5 - DECK, 24 },
	},
	{
		name = "BentE",
		kind = "concrete",
		at = { 50, (DECK + SPAN - 1.5) / 2, OVER_Z },
		size = { 3, SPAN - 1.5 - DECK, 24 },
	},
	-- Toll Plaza and the admin lot beside it (the insert pad)
	{
		name = "TollPaving",
		kind = "concrete",
		at = { 0, DECK + 0.1, TOLL_Z },
		size = { 168, 0.2, 158 },
	},
	{
		name = "AdminPaving",
		kind = "road",
		at = { 125, DECK + 0.1, TOLL_Z },
		size = { 78, 0.2, 98 },
	},
	{
		name = "TollOffice",
		kind = "building",
		at = { 142, DECK + 6, TOLL_Z + 40 },
		size = { 36, 12, 14 },
	},
	{
		name = "TollOfficeRoof",
		kind = "steel",
		at = { 142, DECK + 12.3, TOLL_Z + 40 },
		size = { 37.6, 0.6, 15.6 },
	},
	{
		name = "TollOfficeWindows",
		kind = "glass",
		at = { 136, DECK + 7, TOLL_Z + 32.9 },
		size = { 22, 3.2, 0.2 },
	},
	{
		name = "TollOfficeDoor",
		kind = "steel",
		at = { 154, DECK + 3.6, TOLL_Z + 32.9 },
		size = { 4, 7.2, 0.2 },
	},
	-- Rest Stop (west, ground level)
	{
		name = "RestLot",
		kind = "concrete",
		at = { -172.5, 0.05, -252.5 },
		size = { 235, 0.1, 165 },
	},
	{
		name = "RestExit_wedge",
		kind = "road",
		at = { -63, DECK / 2, -195 },
		size = { 16, DECK, 70 },
	},
	{
		name = "RestExitLanding",
		kind = "road",
		at = { -63, DECK / 2, -150 },
		size = { 16, DECK, 20 },
	},
	{
		name = "RestEntry_wedge",
		kind = "road",
		at = { -63, DECK / 2, -365 },
		size = { 16, DECK, 70 },
		yaw = 180,
	},
	{
		name = "RestEntryLanding",
		kind = "road",
		at = { -63, DECK / 2, -410 },
		size = { 16, DECK, 20 },
	},
	{ name = "Diner", kind = "building", at = { -240, 5, -312 }, size = { 48, 10, 22 } },
	{ name = "DinerRoofTrim", kind = "red", at = { -240, 10.3, -312 }, size = { 49.6, 0.6, 23.6 } },
	{ name = "DinerWindows", kind = "glass", at = { -240, 5.4, -300.9 }, size = { 38, 3.4, 0.2 } },
	{ name = "DinerAwning", kind = "red", at = { -240, 8.4, -298 }, size = { 40, 0.4, 6 } },
	{ name = "FuelCanopy", kind = "steel", at = { -150, 9, -225 }, size = { 40, 0.8, 26 } },
	{ name = "IslandW", kind = "concrete", at = { -157, 0.35, -225 }, size = { 4, 0.6, 18 } },
	{ name = "IslandE", kind = "concrete", at = { -143, 0.35, -225 }, size = { 4, 0.6, 18 } },
	{ name = "TruckBays", kind = "road", at = { -272, 0.12, -265 }, size = { 30, 0.1, 70 } },
	{ name = "RestDriveE", kind = "road", at = { -80, 0.12, -280 }, size = { 30, 0.1, 110 } },
	{ name = "RestDriveFuel", kind = "road", at = { -150, 0.12, -225 }, size = { 110, 0.1, 36 } },
	-- Weigh Station (east, ground level)
	{ name = "WeighLot", kind = "concrete", at = { 150, 0.05, -185 }, size = { 190, 0.1, 120 } },
	{
		name = "WeighExit_wedge",
		kind = "road",
		at = { 63, DECK / 2, -275 },
		size = { 16, DECK, 70 },
		yaw = 180,
	},
	{
		name = "WeighExitLanding",
		kind = "road",
		at = { 63, DECK / 2, -320 },
		size = { 16, DECK, 20 },
	},
	{
		name = "WeighEntry_wedge",
		kind = "road",
		at = { 63, DECK / 2, -112.5 },
		size = { 16, DECK, 45 },
	},
	{
		name = "WeighEntryLanding",
		kind = "road",
		at = { 63, DECK / 2, -83 },
		size = { 16, DECK, 14 },
	},
	{ name = "ScaleHouse", kind = "building", at = { 120, 4, -186 }, size = { 14, 8, 10 } },
	{ name = "ScalePlate", kind = "steel", at = { 120, 0.2, -205 }, size = { 70, 0.2, 12 } },
	{ name = "ScaleLane", kind = "road", at = { 150, 0.12, -205 }, size = { 188, 0.1, 18 } },
	-- the Halt (north-west): trodden ground under the tents
	{ name = "HaltGround", kind = "patch", at = { -200, 0.05, 250 }, size = { 130, 0.1, 90 } },
	-- The jackknife (z -20): a fuel tanker across the west carriageway, a box trailer over the
	-- east lanes (blocks until the kit is uploaded). Gaps: both shoulders.
	{
		name = "TankerTrailer",
		kind = "steel",
		at = { -27, DECK + 4, -20 },
		size = { 8, 8, 40 },
		yaw = 16,
	},
	{
		name = "BoxTrailer",
		kind = "steel",
		at = { 24, DECK + 4.5, -24 },
		size = { 8, 9, 40 },
		yaw = -22,
	},
	-- The stuck horn on the first bus south of the apron (Kill the Horn; the noise's source).
	{ name = "Horn", kind = "steel", at = { 16, DECK + 9.5, 176 }, size = { 1, 1, 1 } },
}

-- The interchange: four ramps from the county road down to the deck.
for _, ew in { { sign = -1, tag = "W" }, { sign = 1, tag = "E" } } do
	for _, ns in { { sign = -1, tag = "S" }, { sign = 1, tag = "N" } } do
		local sx, sz = ew.sign, ns.sign
		local name = `{ns.tag}{ew.tag}`
		local z = OVER_Z + sz * 50
		table.insert(PARTS, {
			name = `Ramp{name}_wedge`,
			kind = "road",
			at = { sx * 71, (DECK + SPAN) / 2, z },
			size = { 14, SPAN - DECK, 64 },
			yaw = if sz > 0 then 180 else 0,
		})
		table.insert(PARTS, {
			name = `Ramp{name}Fill`,
			kind = "slope",
			at = { sx * 71, DECK / 2 - 0.05, z },
			size = { 14, DECK - 0.1, 64 },
		})
		table.insert(PARTS, {
			name = `Ramp{name}Landing`,
			kind = "road",
			at = { sx * 66.5, DECK / 2, OVER_Z + sz * 89 },
			size = { 23, DECK, 14 },
		})
	end
end

-- Toll booths: four a carriageway, as blocks.
for _, cx in { -33.2, 33.2 } do
	for _, dx in { -24, -8, 8, 24 } do
		table.insert(PARTS, {
			name = "TollBooth",
			kind = "building",
			at = { cx + dx, DECK + 4.5, TOLL_Z },
			size = { 4, 9, 8 },
		})
	end
	table.insert(PARTS, {
		name = "TollCanopy",
		kind = "steel",
		at = { cx, DECK + 10, TOLL_Z },
		size = { 64, 0.8, 18 },
	})
end

local SOUTH = -90 -- every vehicle left Harlan heading south: nose toward -Z
local LANE = 16 -- the inner lanes' centre either side of the median

local DRESSING: { DressingData } = {}
-- The convoy: 20 buses in the inner lanes (6 burnt), two at the booths, one down the Rest
-- Stop's ramp, one on its side at the Drop: Control's 24.
local WEST = { -418, -366, -312, -262, -212, -160, -110, 34, 92, 142 }
local EAST = { -410, -356, -300, -246, -190, -132, 30, 84, 136, 186 }
local BURNT = {
	["-1:-312"] = true,
	["-1:-110"] = true,
	["-1:142"] = true,
	["1:-410"] = true,
	["1:-190"] = true,
	["1:84"] = true,
}
for _, lane in { { side = -1, zs = WEST }, { side = 1, zs = EAST } } do
	local side = lane.side
	for _, z in lane.zs do
		table.insert(DRESSING, {
			name = "env_bus",
			x = side * LANE,
			z = z,
			yaw = SOUTH,
			burning = BURNT[`{side}:{z}`] == true,
			floor = ROAD_TOP,
		})
	end
end
type Bus = { x: number, z: number, yaw: number, burning: boolean?, floor: number? }
local BUSES: { Bus } = {
	{ x = -17.2, z = TOLL_Z + 4, yaw = SOUTH, floor = ROAD_TOP },
	{ x = 17.2, z = TOLL_Z - 30, yaw = SOUTH - 5, burning = true, floor = ROAD_TOP },
	{ x = -128, z = -310, yaw = 8 }, -- made it down the ramp
	{ x = -150, z = -44, yaw = 100 }, -- the Drop: over the rail
}
for _, bus in BUSES do
	table.insert(DRESSING, {
		name = "env_bus",
		x = bus.x,
		z = bus.z,
		yaw = bus.yaw,
		burning = bus.burning,
		floor = bus.floor,
	})
end
-- Lamp posts the Weigh Station's generator lights (Lights On) and the Rest Stop's.
for _, lamp in
	{
		{ 78, -200, 0 },
		{ 160, -128, -90 },
		{ 240, -190, 180 },
		{ -96, -190, 180 },
		{ -96, -300, 180 },
		{ -200, -172, 90 },
		{ -200, -333, -90 },
		{ -288, -235, 0 },
	}
do
	table.insert(DRESSING, { name = "env_lamp_post", x = lamp[1], z = lamp[2], yaw = lamp[3] })
end
table.insert(DRESSING, { name = "prop_generator", x = 142, z = -176, yaw = 0 })
-- The south barricade the lead bus stopped against.
for x = -51, 51, 6 do
	if math.abs(x) > 9 then
		table.insert(DRESSING, { name = "env_barrier_jersey", x = x, z = -440, yaw = 0 })
	end
end

-- Cover in the four fields (loop sprint 5; Nova's v1 woods idea on the v2 frame): pines in
-- clumps and brush between them, so a quiet squad can go round the Jam unseen. Seeded, so the
-- map is the same every time; nothing on the roads, lots, pads or objective sites
-- (tests/Mile14.spec checks the same boxes).
local CLEAR = {
	{ 0, 0, 82, 450 }, -- the deck, its slopes and ramps
	{ 0, 80, 320, 28 }, -- the county road and the Overpass
	{ 0, 310, 92, 87 }, -- the toll apron
	{ 125, 310, 52, 62 }, -- the admin lot (insert pad)
	{ -172.5, -252.5, 127, 92 }, -- the Rest Stop lot (extract pad)
	{ 150, -185, 105, 70 }, -- the Weigh Station lot
	{ -200, 250, 72, 52 }, -- the Halt
	{ 225, -370, 37, 37 }, -- the water tower knoll
}
-- Every objective site, x and z (ObjectiveDefinitions.Maps.mile14; the spec checks the pair).
local SITES: { { number } } = {
	{ 16, -246 },
	{ -8.5, -160 },
	{ 23.5, -246 },
	{ -8.5, -366 }, -- Burn the Buses
	{ 0, 80 },
	{ 0, 260 },
	{ -190, -255 }, -- Secure the Site
	{ 225, -350 },
	{ 150, -185 },
	{ 154, 341 }, -- Comms, Casualties, Record
	{ 23.5, 168 },
	{ 142, -172.8 }, -- the horn, Lights On
	{ -200, 250 },
	{ 230, 10 },
	{ -250, 80 }, -- Misdrop
	{ 0, -425 },
	{ -110, -50 }, -- Clear the Spitters
}
local seed = 14
local function roll(): number -- 0..1, a small LCG (the map must not change between servers)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function blocked(x: number, z: number): boolean
	if math.abs(x) > 312 or math.abs(z) > 442 then
		return true
	end
	for _, box in CLEAR do
		if math.abs(x - box[1]) < box[3] and math.abs(z - box[2]) < box[4] then
			return true
		end
	end
	for _, site in SITES do
		local dx, dz = x - site[1], z - site[2]
		if dx * dx + dz * dz < 20 * 20 then
			return true
		end
	end
	return false
end
-- Clump centres, two or three per field, then trees round each and brush between.
local CLUMPS = {
	{ -150, 330 },
	{ -260, 170 },
	{ -230, 10 },
	{ -120, -90 },
	{ -270, -120 },
	{ -150, -400 },
	{ 160, 400 },
	{ 250, 200 },
	{ 160, 10 },
	{ 270, -60 },
	{ 110, -300 },
	{ 260, -280 },
}
for _, clump in CLUMPS do
	local placed = 0
	for _ = 1, 30 do
		if placed >= 8 then
			break
		end
		local x = clump[1] + (roll() - 0.5) * 70
		local z = clump[2] + (roll() - 0.5) * 70
		if not blocked(x, z) then
			placed += 1
			table.insert(DRESSING, {
				name = if roll() < 0.6 then "env_pine_tall" else "env_pine_small",
				x = math.floor(x),
				z = math.floor(z),
				yaw = math.floor(roll() * 360),
			})
		end
	end
end
local shrubs = 0
for _ = 1, 400 do
	if shrubs >= 60 then
		break
	end
	local x = (roll() - 0.5) * 624
	local z = (roll() - 0.5) * 884
	if not blocked(x, z) then
		shrubs += 1
		table.insert(
			DRESSING,
			{
				name = "env_shrub",
				x = math.floor(x),
				z = math.floor(z),
				yaw = math.floor(roll() * 360),
			}
		)
	end
end

return {
	Size = { 640, 900 },
	Landing = { 130, DECK + 0.6, TOLL_Z }, -- the admin lot
	Extract = { -262, 0.6, -195 }, -- the Rest Stop's pad: one way, south (owner 2026-11-20)
	-- The Warden stand-in walks north up the lane from beyond the south barricade.
	Boss = {
		Spawn = { 0, DECK, -445 },
		Waypoints = { { 0, DECK, -400 }, { 0, DECK, -246 }, { 0, DECK, -120 } },
	},
	Hold = { 0, DECK + 0.5, 260 }, -- the Toll Plaza (only with the objective pools off)
	Hills = HILLS,
	Parts = PARTS,
	Dressing = DRESSING,
	-- The fence round the frame stands this far in from each edge, open across the deck at
	-- both ends (the road runs on past it).
	FenceInset = 0.4,
	DeckGap = 56,
}
