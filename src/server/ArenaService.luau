--!strict
-- Simple test arena: a soft slate floor with containing walls, sized to hold
-- the objective (+60,+60) and extraction (-90,-90) zones with room to kite.
-- Easy-on-the-eyes muted blue-grey for long testing sessions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local ArenaService = {}

-- Set dressing: low-poly buildings/barriers from assets/3d, placed clear of the spawn pad
-- (origin), the objective zone (+60,+60) and the extraction zone (-90,-90). All are solid
-- Box-collision obstacles (the Infected have no pathfinding, so no enterable interiors yet).
type Dressing = { name: string, x: number, z: number, yaw: number }
local DRESSING: { Dressing } = {
	{ name = "env_ruin_building", x = -70, z = 50, yaw = 20 },
	{ name = "env_ruin_building", x = 100, z = -45, yaw = -100 },
	{ name = "env_guard_tower", x = -35, z = -115, yaw = 0 },
	{ name = "env_guard_tower", x = 115, z = 100, yaw = 45 },
	{ name = "env_sandbag_bunker", x = 30, z = -60, yaw = 180 },
	{ name = "env_sandbag_bunker", x = -115, z = 15, yaw = 90 },
	{ name = "env_barrier_jersey", x = -40, z = -22, yaw = 30 },
	{ name = "env_barrier_jersey", x = 45, z = 12, yaw = -60 },
	{ name = "env_barrier_jersey", x = -95, z = -40, yaw = 10 },
	{ name = "env_barrier_jersey", x = 20, z = 105, yaw = 80 },
	{ name = "env_barrier_jersey", x = 95, z = 30, yaw = 45 },
	{ name = "env_barrier_jersey", x = -130, z = 115, yaw = 0 },
	{ name = "env_barrier_jersey", x = 60, z = -120, yaw = 120 },
}

local function placeDressing(arena: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	folder.Parent = arena
	for _, entry in DRESSING do
		local name, x, z, yaw = entry.name, entry.x, entry.z, entry.yaw
		-- Templates build asynchronously at boot; wait for each (nil = skip, floor stays bare).
		local part = MeshAssets.waitFor(name, 20)
		if part then
			part.Name = name
			part.CFrame = CFrame.new(x, part.Size.Y / 2, z) * CFrame.Angles(0, math.rad(yaw), 0)
			part.Parent = folder
		end
	end
end

local HALF = 150 -- half-extent: arena spans -150..+150 on X/Z (300 studs)
local WALL_HEIGHT = 24
local WALL_THICKNESS = 3
local FLOOR_COLOR = Color3.fromRGB(82, 92, 104)
local WALL_COLOR = Color3.fromRGB(104, 116, 130)

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
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

	-- Floor: top surface at y=0 (matches the ground raycasts/spawns assume).
	makePart("Floor", Vector3.new(HALF * 2, 1, HALF * 2), Vector3.new(0, -0.5, 0), FLOOR_COLOR).Parent =
		arena

	-- Raised spawn pad at the origin, floor sits right below it.
	local pad = makePart(
		"SpawnPad",
		Vector3.new(20, 1, 20),
		Vector3.new(0, 1.5, 0),
		Color3.fromRGB(120, 134, 150)
	)
	pad.Parent = arena

	-- Put the player spawn on top of the pad (move existing SpawnLocation or
	-- create one).
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Neutral = true
	end
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 0.4
	spawn.Color = Color3.fromRGB(150, 200, 160)
	spawn.Position = Vector3.new(0, 2.5, 0)
	spawn.Parent = arena

	local wy = WALL_HEIGHT / 2
	local span = HALF * 2 + WALL_THICKNESS
	makePart(
		"WallPosX",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
		Vector3.new(HALF, wy, 0),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallNegX",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, span),
		Vector3.new(-HALF, wy, 0),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallPosZ",
		Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, wy, HALF),
		WALL_COLOR
	).Parent =
		arena
	makePart(
		"WallNegZ",
		Vector3.new(span, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, wy, -HALF),
		WALL_COLOR
	).Parent =
		arena

	arena.Parent = workspace
	task.spawn(placeDressing, arena)
end

return ArenaService
