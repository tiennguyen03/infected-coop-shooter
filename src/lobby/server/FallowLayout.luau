--!strict
-- Where everything on the Fallow sits (docs/sprints/LOBBY_V1_FALLOW.md has the plan view).
-- Studs, built against the 5-stud character. +Z is the bow (the coast lies that way), +X is
-- starboard (the island side). The flight deck is 70 x 360; the hangar deck runs under it
-- from Z -100 to 140, the Plot under the island.
--
-- The loop (Nova, 2026-11-09): soldiers spawn at the fore end of the hangar, pass the desks,
-- climb the ramp, which rises aft through an open well, and come up facing the Lantern
-- spots. Desks and birds are one short walk apart, never a walk past the birds and back.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local FallowLayout = {}

FallowLayout.HalfWidth = 35
FallowLayout.HalfLength = 180
FallowLayout.DeckY = 40 -- flight deck surface
FallowLayout.DeckThickness = 2
FallowLayout.HangarY = 20 -- hangar floor surface
FallowLayout.HangarAft = -100
FallowLayout.HangarFore = 140

-- The open well and the ramp inside it (X min/max, Z aft/fore). The ramp's foot is on the
-- hangar floor at the fore end (z1); it rises aft and meets the deck at z0.
FallowLayout.Well = { x0 = -30, x1 = -10, z0 = 20, z1 = 80 }

-- The island: a block on the starboard edge.
FallowLayout.Island = { x0 = 22, x1 = 34, z0 = -10, z1 = 50, top = 80 }

-- The Plot: Control's map room under the island, on the hangar deck. The door is in its
-- west wall; the board stands across the room in front of the hull. Its west wall moved out
-- from X 14 (Nova, 2026-11-10: "way too cramped", the player should stand in front of the map):
-- the map table sits mid-room with open floor between it and the door.
FallowLayout.Plot = { x0 = 4, x1 = 33, z0 = -10, z1 = 30, doorZ0 = 6, doorZ1 = 14 }
FallowLayout.Board = {
	cframe = CFrame.new(29.5, FallowLayout.HangarY + 7, 10), -- centre of the panel
	size = Vector3.new(0.4, 10, 32), -- the lettering faces -X (Left)
	plotter = Vector3.new(31.5, FallowLayout.HangarY, 4),
}
FallowLayout.ChartTable = CFrame.new(19, FallowLayout.HangarY, 0) -- the paper map (WorldMap)

-- The screening lane on the starboard quarter, where a recovered team walks off its bird
-- (scenery for now: nobody spawns there).
FallowLayout.Lane = { x0 = 19, x1 = 29, z0 = -172, z1 = -136 }

-- Where the walking crew walk (LobbyCrew ids; CrewService, CrewWalk): there and back along
-- the points, pausing at each end. Flight deck crew stay clear of the spots' rotor discs.
local D, H = FallowLayout.DeckY, FallowLayout.HangarY
FallowLayout.Crew = {
	director = { Vector3.new(8, D, -140), Vector3.new(8, D, -20) }, -- along the spots' safe line
	deckhand = { Vector3.new(-28, D, -160), Vector3.new(-28, D, -100), Vector3.new(-28, D, -30) },
	mechanic = { Vector3.new(14, H, 35), Vector3.new(14, H, 95) }, -- the hangar's starboard side
	runner = {
		Vector3.new(2, H, 10),
		Vector3.new(-4, H, 12),
		Vector3.new(-4, H, 40),
		Vector3.new(-6, H, 78),
	}, -- Plot door to the ramp, outside the Fires counter
	medic = { Vector3.new(24, D, -166), Vector3.new(24, D, -142) }, -- up and down the screening lane
	sentry = { Vector3.new(32, D, -170), Vector3.new(32, D, -136) }, -- the deck edge over the lane
} :: { [string]: { Vector3 } }

-- Soldiers spawn at the fore end of the hangar, facing aft down the desks to the ramp.
local spawnAt = Vector3.new(0, FallowLayout.HangarY + 0.5, 125)
FallowLayout.Spawn = CFrame.lookAt(spawnAt, spawnAt - Vector3.new(0, 0, 1))

export type Spot = {
	index: number,
	helo: Vector3, -- the bird, on the spot's centre
	board: Vector3, -- the boarding box beside its door, on the deck surface
}

-- Numbered Lantern spots down the deck aft of the ramp's top, spot 4 nearest it.
local spots: { Spot } = {}
for index = 1, Config.Lobby.Launch.Spots do
	local z = -150 + (index - 1) * 45
	table.insert(spots, {
		index = index,
		helo = Vector3.new(-12, FallowLayout.DeckY, z),
		board = Vector3.new(1, FallowLayout.DeckY, z),
	})
end
FallowLayout.Spots = spots

export type DeskPlace = {
	id: string, -- LobbyDesks id
	feet: Vector3, -- where the person stands
	facing: Vector3, -- the way they face (flat)
	counter: boolean?, -- false: no stock counter, the sign floats over them
	reach: number?, -- studs a soldier can talk from (default Config.Lobby.DeskPromptDistance)
}

-- Hangar desks (LobbyDesks), between the spawn and the ramp's foot: the Arms Room cage on the
-- port side and the Engineers among the wire to starboard, facing each other across the
-- walk; the Loadmaster among the slung cases at the foot of the ramp, facing the spawn; Fires
-- at the Plot door, further aft past the ramp.
FallowLayout.Desks = {
	{
		id = "arms_room",
		feet = Vector3.new(-26, FallowLayout.HangarY, 124),
		facing = Vector3.new(1, 0, 0),
		counter = false, -- his counter is the glass case (ArmsRack, FallowLayout.ArmsRoom)
	},
	{
		id = "engineers",
		feet = Vector3.new(27, FallowLayout.HangarY, 105),
		facing = Vector3.new(-1, 0, 0),
	},
	{
		id = "loadmaster",
		feet = Vector3.new(-2, FallowLayout.HangarY, 88),
		facing = Vector3.new(0, 0, 1),
	},
	{
		id = "fires",
		feet = Vector3.new(1, FallowLayout.HangarY, 18),
		facing = Vector3.new(-1, 0, 0),
	},
	-- Control's watch officer at the map table in the Plot, between the table and the board,
	-- facing the door (owner 2026-11-10: someone real in the Plot).
	{
		id = "plot",
		feet = Vector3.new(26.8, FallowLayout.HangarY, -3),
		reach = 18, -- across the map table, from anywhere you stand to read it
		facing = Vector3.new(-1, 0, 0),
		counter = false,
	},
} :: { DeskPlace }

-- The Arms Room fills the hangar's port fore corner (Nova, 2026-11-10: "use that entire corner
-- for him"; ArmsRack builds it, ArmsRackUI looks at it). The Quartermaster stands behind a glass
-- counter (Nova: "the glass case would act as the desk, like in GTA") holding sidearms, melee and
-- grenades; the long guns hang on a wall along the hull behind him. Wire fence closes the corner
-- off at the counter's ends. Every display has empty places to grow into.
FallowLayout.ArmsRoom = {
	fenceX = -23.6, -- the counter's line: the corner is X < this, Z > aftZ
	aftZ = 111,
	-- The long-gun wall: a board on the hull, guns hung in cells, muzzles toward the bow.
	wall = {
		x = -32.75, -- the board's face
		z0 = 112.5,
		z1 = 138.5,
		y0 = 21,
		y1 = 30.6,
		columns = 4,
		rows = 8,
		out = 0.45, -- studs the guns hang off the board
	},
	-- The glass counter: its front (the soldier's side) at x1, the pieces on a felt bed tilted
	-- toward the soldier, two rows deep. Sections from the soldier's left (+Z) to right.
	counter = {
		x0 = -24.8,
		x1 = -22.4,
		z0 = 116,
		z1 = 132,
		top = 23.4,
		bedY = 22.25, -- the bed's centre
		tilt = 22, -- degrees the bed leans toward the soldier
		sections = {
			{ holds = "sidearms", length = 7, pitch = 1.4 },
			{ holds = "melee", length = 4.5, pitch = 2.2 },
			{ holds = "grenades", length = 4.5, pitch = 0.9 },
		},
	},
}

-- Ship art (assets/3d/build/fallow.py, placed by FallowArt).
-- The port side lift lowered to hangar level as a walkable balcony (owner, 2026-11-09).
-- Fills the port side-lift opening wall to wall: the hull mesh frames it with posts at Z -40
-- and 0 (0.4 thick), so the clear opening is -39.6..-0.4 (Nova: no gap at the rail ends).
FallowLayout.Balcony = { x0 = -47, x1 = -35, z0 = -39.6, z1 = -0.4 }

-- Catwalk bays (24 studs) along the deck edge, hung off the hull face: clear of the sponsons,
-- the island, the balcony and the tapering bow. `side` +1 starboard, -1 port; one bay in
-- three carries the life-raft canisters.
export type Bay = { side: number, z: number, rafts: boolean }
FallowLayout.Catwalks = {
	{ side = 1, z = -124, rafts = false },
	{ side = 1, z = -100, rafts = true },
	{ side = 1, z = -76, rafts = false },
	{ side = 1, z = -52, rafts = false },
	{ side = 1, z = -28, rafts = true },
	{ side = 1, z = 66, rafts = false },
	{ side = 1, z = 90, rafts = false },
	{ side = 1, z = 114, rafts = true },
	{ side = -1, z = -133, rafts = false },
	{ side = -1, z = -109, rafts = true },
	{ side = -1, z = -85, rafts = false },
	{ side = -1, z = -61, rafts = false },
	{ side = -1, z = 12, rafts = true },
	{ side = -1, z = 36, rafts = false },
	{ side = -1, z = 60, rafts = false },
	{ side = -1, z = 84, rafts = true },
	{ side = -1, z = 108, rafts = false },
	{ side = -1, z = 132, rafts = false },
} :: { Bay }
FallowLayout.CatwalkHullX = 35 -- the bays' pivot: the hull face, at deck height

-- The radar's turning axis, on the mast platform forward of the pole.
FallowLayout.Radar = Vector3.new(31, 92, 44.5)

-- The bow's flat facet above the knuckle (fallow.py BOW, stations 165 -> 185, starboard):
-- the painted-out hull number lies on it, mirrored to port.
FallowLayout.BowFacet = {
	knuckle165 = Vector3.new(31, 17, 165),
	top165 = Vector3.new(34.5, 38, 165),
	knuckle185 = Vector3.new(26.5, 17, 185),
}

-- The coast to the north and the Burn along it, past the bow (close enough that the fires
-- read through the haze).
FallowLayout.CoastZ = 900
-- Where the four burn sites sit along the shore (X).
FallowLayout.BurnSites = { -900, -560, -230, 120, 450, 820 }

return FallowLayout
