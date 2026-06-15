--!strict
-- Enemy system (Sprint 9): three archetypes share one chase-and-melee
-- behavior, differing only by stats/scale/color from EnemyDefinitions.
-- A phase-based spawn director picks types by run time with fairness caps
-- (Brute count schedule, Runner share of the horde). Enemies pass through
-- each other (Enemy collision group) but still hit players and the world.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local DifficultyService = require(script.Parent.DifficultyService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local PauseService = require(script.Parent.PauseService)
local XPOrbService = require(script.Parent.XPOrbService)

local ENEMY_TAG = "Enemy"
local ENEMY_COLLISION_GROUP = "Enemy"
local WALK_ANIMATION_ID = "rbxassetid://507777826" -- default R15 walk
local REPATH_INTERVAL = 0.25
local SPAWN_HIP_HEIGHT = 3.5 -- root height above ground at scale 1

type Zombie = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	typeName: string,
	walkSpeed: number,
	damage: number,
	attackRange: number,
	attackCooldown: number,
	xpReward: number,
	lastAttackTime: number,
	nextRepathTime: number,
}

local EnemyService = {}

local zombieTemplate: Model?
local zombies: { Zombie } = {}
local wasPaused = false

local function buildTemplate(): Model?
	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok then
		return result
	end
	warn("[EnemyService] Could not build enemy rig (offline?):", result)
	return nil
end

local function nearestPlayerRoot(fromPosition: Vector3): BasePart?
	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - fromPosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = root
			end
		end
	end
	return nearest
end

local function countOfType(typeName: string): number
	local count = 0
	for _, zombie in zombies do
		if zombie.typeName == typeName then
			count += 1
		end
	end
	return count
end

local function scheduleLookup(schedule: { { number } }, late: number, elapsed: number): number
	for _, entry in schedule do
		if elapsed <= entry[1] then
			return entry[2]
		end
	end
	return late
end

local function attachHealthBar(humanoid: Humanoid, root: BasePart, scale: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromScale(3.5 * scale, 0.35)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * scale, 0)
	billboard.MaxDistance = 150
	billboard.Enabled = false -- shown once the enemy first takes damage

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(45, 14, 14)
	background.BackgroundTransparency = 0.25
	background.BorderSizePixel = 0
	background.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(96, 205, 72)
	fill.BorderSizePixel = 0
	fill.Parent = background

	humanoid.HealthChanged:Connect(function(health)
		local fraction = math.clamp(health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
		billboard.Enabled = health > 0 and health < humanoid.MaxHealth
	end)

	billboard.Parent = root
end

local function onZombieDied(zombie: Zombie)
	CollectionService:RemoveTag(zombie.model, ENEMY_TAG)
	XPOrbService.spawnOrb(zombie.root.Position, zombie.xpReward)
	ItemEffectService.onEnemyKilled(zombie.humanoid)
	task.delay(Config.Zombies.CorpseLifetime, function()
		zombie.model:Destroy()
	end)
end

-- `groundPosition` is at ground level; the rig is pivoted up by hip height.
local function spawnZombie(groundPosition: Vector3, typeName: string)
	local template = zombieTemplate
	local definition = EnemyDefinitions[typeName]
	if not template or not definition then
		return
	end

	local model = template:Clone()
	model.Name = definition.DisplayName
	if definition.Scale ~= 1 then
		model:ScaleTo(definition.Scale)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local health = definition.MaxHealth * DifficultyService.getHealthMultiplier()
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = definition.WalkSpeed
	-- Shock Coil reads this to restore speed after a slow without corrupting it.
	humanoid:SetAttribute("BaseWalkSpeed", definition.WalkSpeed)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	attachHealthBar(humanoid, root, definition.Scale)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = ENEMY_COLLISION_GROUP
			part.Color = definition.Color
		end
	end

	CollectionService:AddTag(model, ENEMY_TAG)
	model:PivotTo(
		CFrame.new(groundPosition + Vector3.new(0, SPAWN_HIP_HEIGHT * definition.Scale, 0))
	)
	model.Parent = workspace

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
		local animation = Instance.new("Animation")
		animation.AnimationId = WALK_ANIMATION_ID
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play()
	end)

	local zombie: Zombie = {
		model = model,
		humanoid = humanoid,
		root = root,
		typeName = typeName,
		walkSpeed = definition.WalkSpeed,
		damage = definition.Damage,
		attackRange = definition.AttackRange,
		attackCooldown = definition.AttackCooldown,
		xpReward = definition.XPReward,
		lastAttackTime = 0,
		nextRepathTime = 0,
	}
	table.insert(zombies, zombie)

	humanoid.Died:Connect(function()
		onZombieDied(zombie)
	end)
end

local function removeZombie(index: number)
	zombies[index] = zombies[#zombies]
	zombies[#zombies] = nil
end

local function attackIfTouching(zombie: Zombie, now: number)
	if now - zombie.lastAttackTime < zombie.attackCooldown then
		return
	end
	local targetRoot = nearestPlayerRoot(zombie.root.Position)
	if not targetRoot then
		return
	end
	if (targetRoot.Position - zombie.root.Position).Magnitude <= zombie.attackRange then
		local character = targetRoot.Parent :: Model
		local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			targetHumanoid:TakeDamage(zombie.damage * DifficultyService.getDamageMultiplier())
			zombie.lastAttackTime = now
		end
	end
end

local function stepZombies()
	-- Soft pause: stop everything in place and skip AI/attacks.
	local paused = PauseService.isPaused()
	if paused ~= wasPaused then
		wasPaused = paused
		for _, zombie in zombies do
			zombie.humanoid.WalkSpeed = if paused then 0 else zombie.walkSpeed
		end
	end
	if paused then
		return
	end

	local now = os.clock()
	for index = #zombies, 1, -1 do
		local zombie = zombies[index]
		if not zombie.model.Parent or zombie.humanoid.Health <= 0 then
			removeZombie(index)
			continue
		end

		if now >= zombie.nextRepathTime then
			zombie.nextRepathTime = now + REPATH_INTERVAL
			local targetRoot = nearestPlayerRoot(zombie.root.Position)
			if targetRoot then
				zombie.humanoid:MoveTo(targetRoot.Position)
			end
		end

		attackIfTouching(zombie, now)
	end
end

local function groundPositionNear(
	center: Vector3,
	minDistance: number,
	maxDistance: number
): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.random(minDistance, maxDistance)
	local x = center.X + math.cos(angle) * distance
	local z = center.Z + math.sin(angle) * distance
	local result = workspace:Raycast(Vector3.new(x, center.Y + 50, z), Vector3.new(0, -200, 0))
	local groundY = if result then result.Position.Y else 0
	return Vector3.new(x, groundY, z)
end

local function randomSpawnPosition(): Vector3?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local player = players[math.random(#players)]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return groundPositionNear(
		root.Position,
		Config.Zombies.MinSpawnDistance,
		Config.Zombies.MaxSpawnDistance
	)
end

local function phaseWeights(elapsed: number): { [string]: number }
	for _, phase in Config.Spawning.Phases do
		if elapsed <= phase.Until then
			return phase.Weights
		end
	end
	return Config.Spawning.Phases[#Config.Spawning.Phases].Weights
end

-- Weighted pick honoring first-spawn times, the Brute schedule, and the
-- Runner share cap. Falls back to Walker.
local function pickSpawnType(): string
	local elapsed = DifficultyService.getElapsed()
	local weights = phaseWeights(elapsed)
	local aliveTotal = #zombies

	local candidates: { { name: string, weight: number } } = {}
	local totalWeight = 0
	for typeName, weight in weights do
		local definition = EnemyDefinitions[typeName]
		if not definition or weight <= 0 or elapsed < definition.FirstSpawnTime then
			continue
		end
		if typeName == "Brute" then
			local cap = scheduleLookup(
				Config.Spawning.BruteCapSchedule,
				Config.Spawning.BruteCapLate,
				elapsed
			)
			if countOfType("Brute") >= cap then
				continue
			end
		elseif typeName == "Runner" then
			local share = (countOfType("Runner") + 1) / (aliveTotal + 1)
			if share > Config.Spawning.MaxRunnerRatio then
				continue
			end
		end
		table.insert(candidates, { name = typeName, weight = weight })
		totalWeight += weight
	end

	if totalWeight <= 0 then
		return "Walker"
	end
	local roll = math.random() * totalWeight
	for _, candidate in candidates do
		roll -= candidate.weight
		if roll <= 0 then
			return candidate.name
		end
	end
	return candidates[#candidates].name
end

-- Spawns `count` of a type in a ring: around `center` if given (objective
-- pressure waves), otherwise around a random player.
function EnemyService.spawnWave(typeName: string, count: number, center: Vector3?)
	for _ = 1, count do
		local position: Vector3?
		if center then
			position = groundPositionNear(center, 25, 35)
		else
			position = randomSpawnPosition()
		end
		if position then
			spawnZombie(position, typeName)
		end
	end
end

local function spawnLoop()
	while true do
		local interval = DifficultyService.getSpawnInterval()
		-- Extra pressure while the objective is being held.
		if workspace:GetAttribute("ObjectiveActive") == true then
			interval *= Config.Difficulty.ObjectiveSpawnFactor
		end
		task.wait(interval)
		if not PauseService.isPaused() and #zombies < DifficultyService.getMaxAlive() then
			local position = randomSpawnPosition()
			if position then
				spawnZombie(position, pickSpawnType())
			end
		end
	end
end

local function scheduleInitialWave()
	-- First contact within seconds of the run starting (Sprint 8 pacing).
	task.delay(1.5, function()
		EnemyService.spawnWave("Walker", Config.Zombies.InitialCount)
	end)
end

-- Destroys all enemies without scheduling a new wave (dev ClearEnemies).
function EnemyService.clearAll()
	for _, zombie in zombies do
		zombie.model:Destroy()
	end
	table.clear(zombies)
end

-- Count of currently alive enemies, optionally of one type (dev tools).
function EnemyService.count(typeName: string?): number
	if not typeName then
		return #zombies
	end
	return countOfType(typeName)
end

-- Clears all enemies for a fresh run.
function EnemyService.reset()
	EnemyService.clearAll()
	scheduleInitialWave()
end

function EnemyService.init()
	-- Idempotent: registering an existing group throws, which is fine.
	pcall(function()
		PhysicsService:RegisterCollisionGroup(ENEMY_COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(ENEMY_COLLISION_GROUP, ENEMY_COLLISION_GROUP, false)

	zombieTemplate = buildTemplate()
	if not zombieTemplate then
		warn("[EnemyService] Enemy spawning disabled - no rig template")
		return
	end
	RunService.Heartbeat:Connect(stepZombies)
	task.spawn(spawnLoop)
	scheduleInitialWave()
end

return EnemyService
