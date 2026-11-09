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
-- west wall; the board stands across the room in front of the hull.
FallowLayout.Plot = { x0 = 14, x1 = 33, z0 = -10, z1 = 30, doorZ0 = 6, doorZ1 = 14 }
FallowLayout.Board = {
	cframe = CFrame.new(29.5, FallowLayout.HangarY + 7, 10), -- centre of the panel
	size = Vector3.new(0.4, 10, 32), -- the lettering faces -X (Left)
	plotter = Vector3.new(31.5, FallowLayout.HangarY, 4),
}
FallowLayout.ChartTable = CFrame.new(21, FallowLayout.HangarY, 0)

-- The screening lane on the starboard quarter, where a recovered team walks off its bird
-- (scenery for now: nobody spawns there).
FallowLayout.Lane = { x0 = 19, x1 = 29, z0 = -172, z1 = -136 }

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
}

-- Hangar desks (LobbyDesks), between the spawn and the ramp's foot: the Arms Room cage on the
-- port side and the Engineers among the wire to starboard, facing each other across the
-- walk; the Loadmaster among the slung cases at the foot of the ramp, facing the spawn; Fires
-- at the Plot door, further aft past the ramp.
FallowLayout.Desks = {
	{
		id = "arms_room",
		feet = Vector3.new(-27, FallowLayout.HangarY, 105),
		facing = Vector3.new(1, 0, 0),
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
		feet = Vector3.new(10, FallowLayout.HangarY, 18),
		facing = Vector3.new(-1, 0, 0),
	},
} :: { DeskPlace }

-- The coast to the north and the Burn along it, past the bow (close enough that the fires
-- read through the haze).
FallowLayout.CoastZ = 900
-- Where the four burn sites sit along the shore (X).
FallowLayout.BurnSites = { -520, -210, 140, 470 }

return FallowLayout
