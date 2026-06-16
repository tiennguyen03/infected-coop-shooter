--!strict
-- Simple test arena: a soft slate floor with containing walls, sized to hold
-- the objective (+60,+60) and extraction (-90,-90) zones with room to kite.
-- Easy-on-the-eyes muted blue-grey for long testing sessions.

local ArenaService = {}

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
end

return ArenaService
