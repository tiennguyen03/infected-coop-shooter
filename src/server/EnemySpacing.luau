--!strict
-- Infected spacing (Config.Enemies.Spacing; the maths is Shared.Rules.Spacing): turns a
-- chasing body's straight-line goal into one that keeps it off its neighbours and puts it
-- on the attack ring round its target. Bodies still pass through each other physically
-- (Enemy collision group); this steers them so they rarely need to.
-- Cost: every living body sits in a grid of CellSize cells, refilled at most every
-- RebuildInterval seconds (one position read per body); a goal reads the 3x3 cells round the
-- body, on that body's own repath tick. No body is compared with the whole horde.
-- Only EnemyService's straight chase asks for a goal: the pathfinding branch, the nudge
-- rule, climbs, lures, projectile forms and the bosses move as before, but every body is in
-- the grid, so chasers keep off them too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local Spacing = require(ReplicatedStorage.Shared.Rules.Spacing)

local EnemySpacing = {}

type Body = {
	root: BasePart,
	humanoid: Humanoid,
	radius: number,
	seed: number, -- [0, 1): this body's own radius, approach curve and sway
	x: number,
	y: number,
	z: number,
}

local bodies: { [BasePart]: Body } = {}
local cells: { [number]: { Body } } = {}
local lastRebuild = 0
-- Scratch lists for one goal's neighbours (reused; the rule reads `count` entries).
local neighbourX: { number } = {}
local neighbourZ: { number } = {}
local neighbourRadius: { number } = {}

local function rebuild(now: number)
	lastRebuild = now
	table.clear(cells)
	local cellSize = Config.Enemies.Spacing.CellSize
	for root, body in bodies do
		if not root.Parent or body.humanoid.Health <= 0 then
			bodies[root] = nil
			continue
		end
		local position = root.Position
		body.x, body.y, body.z = position.X, position.Y, position.Z
		local key = Spacing.cellKey(position.X, position.Z, cellSize)
		local cell = cells[key]
		if not cell then
			cell = {}
			cells[key] = cell
		end
		table.insert(cell, body)
	end
end

-- Every Infected (bosses too) at spawn; it leaves by dying or being removed.
function EnemySpacing.add(root: BasePart, humanoid: Humanoid, typeName: string)
	local settings = Config.Enemies.Spacing
	local definition = EnemyDefinitions[typeName]
	local seed = math.random()
	local base = definition.SpacingRadius or settings.Radius * definition.Scale
	local position = root.Position
	bodies[root] = {
		root = root,
		humanoid = humanoid,
		radius = Spacing.radius(base, settings.RadiusVariation, seed),
		seed = seed,
		x = position.X,
		y = position.Y,
		z = position.Z,
	}
end

-- Where a body at `here` chasing `target` should walk this repath, and whether the crowd
-- is holding it there (waiting: not stuck on cover, so no nudge or climb). With spacing off
-- it is `target`, as before.
function EnemySpacing.goal(
	root: BasePart,
	here: Vector3,
	target: Vector3,
	attackRange: number,
	now: number
): (Vector3, boolean)
	local settings = Config.Enemies.Spacing
	local body = bodies[root]
	if not settings.Enabled or not body then
		return target, false
	end
	if now - lastRebuild >= settings.RebuildInterval then
		rebuild(now)
	end

	local cellSize = settings.CellSize
	local count = 0
	for cellX = -1, 1 do
		for cellZ = -1, 1 do
			local cell = cells[Spacing.cellKey(
				here.X + cellX * cellSize,
				here.Z + cellZ * cellSize,
				cellSize
			)]
			if cell then
				for _, other in cell do
					if
						other ~= body
						and count < settings.MaxNeighbours
						and math.abs(other.y - here.Y) <= settings.HeightGap
					then
						count += 1
						neighbourX[count] = other.x
						neighbourZ[count] = other.z
						neighbourRadius[count] = other.radius
					end
				end
			end
		end
	end

	local goalX, goalZ, waiting = Spacing.steer(
		settings.Steer,
		here.X,
		here.Z,
		target.X,
		target.Z,
		attackRange,
		body.radius,
		body.seed,
		now,
		neighbourX,
		neighbourZ,
		neighbourRadius,
		count
	)
	return Vector3.new(goalX, target.Y, goalZ), waiting
end

return EnemySpacing
