--!strict
-- Where everything on the Fallow sits (docs/sprints/LOBBY_V1_FALLOW.md has the plan view).
-- Studs, built against the 5-stud character. +Z is the bow (the coast lies that way), +X is
-- starboard (the island side). The flight deck is 70 x 360; the hangar deck runs under it
-- from Z -100 to 140, the Plot under the island, and a ramp climbs from the hangar floor to
-- the deck through an open well aft of the island.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local FallowLayout = {}

FallowLayout.HalfWidth = 35
FallowLayout.HalfLength = 180
FallowLayout.DeckY = 40 -- flight deck surface
FallowLayout.DeckThickness = 2
FallowLayout.HangarY = 20 -- hangar floor surface
FallowLayout.HangarAft = -100
FallowLayout.HangarFore = 140

-- The open well and the ramp inside it (X min/max, Z low end/high end).
FallowLayout.Well = { x0 = -30, x1 = -10, z0 = 70, z1 = 130 }

-- The island: a block on the starboard edge.
FallowLayout.Island = { x0 = 22, x1 = 34, z0 = -10, z1 = 50, top = 80 }

-- The Plot: Control's map room under the island, on the hangar deck. The door is in its
-- west wall; the board stands across the room in front of the hull.
FallowLayout.Plot = { x0 = 14, x1 = 33, z0 = -10, z1 = 30, doorZ0 = 6, doorZ1 = 14 }
FallowLayout.Board = {
	cframe = CFrame.new(29.5, FallowLayout.HangarY + 7, 10), -- centre of the panel
	size = Vector3.new(0.4, 10, 32), -- the lettering faces -X (Left)
	plotter = Vector3.new(31.5, FallowLayout.HangarY, 4),
}
FallowLayout.ChartTable = CFrame.new(21, FallowLayout.HangarY, 0)

-- Arrival: the screening lane on the starboard quarter. Soldiers spawn at its aft end.
FallowLayout.Lane = { x0 = 19, x1 = 29, z0 = -172, z1 = -136 }
FallowLayout.Spawn = CFrame.new(24, FallowLayout.DeckY + 0.5, -168)

export type Spot = {
	index: number,
	helo: Vector3, -- the bird, on the spot's centre
	board: Vector3, -- the boarding box beside its door, on the deck surface
}

-- Numbered Lantern spots down the deck, forward of the lane.
local spots: { Spot } = {}
for index = 1, Config.Lobby.Launch.Spots do
	local z = -150 + (index - 1) * 50
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
}

-- Hangar desks (LobbyDesks): the Arms Room cage on the port side, the Loadmaster at the foot
-- of the ramp among the slung cases, Fires at the Plot door, the Engineers among the wire.
FallowLayout.Desks = {
	{
		id = "arms_room",
		feet = Vector3.new(-27, FallowLayout.HangarY, -50),
		facing = Vector3.new(1, 0, 0),
	},
	{
		id = "loadmaster",
		feet = Vector3.new(-2, FallowLayout.HangarY, 58),
		facing = Vector3.new(0, 0, -1),
	},
	{
		id = "fires",
		feet = Vector3.new(10, FallowLayout.HangarY, 18),
		facing = Vector3.new(-1, 0, 0),
	},
	{
		id = "engineers",
		feet = Vector3.new(-27, FallowLayout.HangarY, 20),
		facing = Vector3.new(1, 0, 0),
	},
} :: { DeskPlace }

-- The coast to the north and the Burn along it, far past the bow.
FallowLayout.CoastZ = 1400

return FallowLayout
