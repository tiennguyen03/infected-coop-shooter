--!strict
-- Mile 14 (docs/LEVELS.md > Mile 14; owner 2026-11-20: the v2 layout, one-way, at night,
-- played quiet with Nova's awareness system, Config.Awareness.Missions.mile14). The stalled
-- evacuation convoy on the interstate: land on the Toll Plaza's admin lot with Harlan burning
-- behind you, get to the Rest Stop's pad about 640 studs south past 24 sealed buses. Every
-- number is in Mile14Data (the v2 generator's layout, plain data for tests/Mile14.spec);
-- this file turns it into a MissionTypes.Mission. Grey blocks for now; the art pass and the
-- woods and brush in the fields come with loop sprint 5.

local Data = require(script.Parent.Mile14Data)
local MissionTypes = require(script.Parent.MissionTypes)

type Vec = { number }

local function v3(vec: Vec): Vector3
	return Vector3.new(vec[1], vec[2], vec[3])
end

local hills: { MissionTypes.Hill } = {}
for _, hill in Data.Hills do
	table.insert(hills, {
		name = hill.name,
		x = hill.x,
		z = hill.z,
		top = Vector2.new(hill.top[1], hill.top[2]),
		height = hill.height,
		open = hill.open,
	})
end

local parts: { MissionTypes.Part } = {}
for _, part in Data.Parts do
	table.insert(parts, {
		name = part.name,
		kind = part.kind,
		at = v3(part.at),
		size = v3(part.size),
		yaw = part.yaw,
	})
end

local dressing: { MissionTypes.Dressing } = {}
for _, piece in Data.Dressing do
	table.insert(dressing, {
		name = piece.name,
		x = piece.x,
		z = piece.z,
		yaw = piece.yaw,
		burning = piece.burning,
		floor = piece.floor,
	})
end

-- The fence round the frame, open where the deck runs out at the north and south edges.
local halfX, halfZ = Data.Size[1] / 2, Data.Size[2] / 2
local fence: { MissionTypes.FencePanel } = {}
for along = -halfX + 6, halfX - 6, 12 do
	for _, z in { halfZ - Data.FenceInset, -halfZ + Data.FenceInset } do
		if math.abs(along) >= Data.DeckGap then
			table.insert(fence, { x = along, z = z, yaw = 0 })
		end
	end
end
for along = -halfZ + 6, halfZ - 6, 12 do
	for _, x in { halfX - Data.FenceInset, -halfX + Data.FenceInset } do
		table.insert(fence, { x = x, z = along, yaw = 90 })
	end
end

local waypoints: { Vector3 } = {}
for _, point in Data.Boss.Waypoints do
	table.insert(waypoints, v3(point))
end

local mission: MissionTypes.Mission = {
	Id = "mile14",
	Name = "Mile 14",
	Size = Vector2.new(Data.Size[1], Data.Size[2]),
	Landing = v3(Data.Landing),
	Extract = v3(Data.Extract),
	Boss = {
		Spawn = v3(Data.Boss.Spawn),
		Waypoints = waypoints,
		WaypointRadio = {},
		GateRadio = false,
	},
	Hold = v3(Data.Hold),
	Parts = parts,
	Features = {},
	Hills = hills,
	Dressing = dressing,
	Patches = {},
	Ramps = {},
	Perimeter = {},
	Fence = fence,
	Buildings = {},
}

return mission
