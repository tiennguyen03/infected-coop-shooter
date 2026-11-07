--!strict
-- Enemy system (Sprint 9; behaviour hooks 2026-11-06): every Infected form is a row in
-- EnemyDefinitions. Melee forms chase and hit on contact; projectile forms (Hocker) close to
-- throw range, plant, wind up and lob through EnemyProjectileService. A phase-based spawn
-- director picks types by run time with fairness caps from Config.Spawning (count
-- schedules and share caps keyed by type). Enemies pass through each other (Enemy collision
-- group) but still hit players and the world. Player damage: EnemyProjectileService.damagePlayer.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Animations = require(ReplicatedStorage.Shared.Animations)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local PauseService = require(script.Parent.PauseService)
local XPOrbService = require(script.Parent.XPOrbService)

local ENEMY_TAG = "Enemy"
local ENEMY_COLLISION_GROUP = "Enemy"
local WALK_ANIMATION_ID = "rbxassetid://507777826" -- default R15 walk
local REPATH_INTERVAL = 0.25
local SPAWN_HIP_HEIGHT = 3.5 -- root height above ground at scale 1
local BACK_OFF_DISTANCE = 8 -- studs a projectile form retreats when a player gets inside half its stand-off
local SAC_OFFSET = CFrame.new(0, 0.95, -0.5) -- throat sac relative to UpperTorso (the rig faces -Z)
local SAC_SIZE = 0.9

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
	attackTrack: AnimationTrack?,
	deathTrack: AnimationTrack?,
	nextRepathTime: number,
	behaviour: EnemyDefinitions.Behaviour,
	-- Projectile forms: the windup in progress and whether the last check had a clear throw.
	windupUntil: number?,
	throwClear: boolean,
	sac: BasePart?,
}

local EnemyService = {}

local zombieTemplate: Model?
-- Per-type rigs with the Blender limb meshes (MeshAssets.dressInfected); falls back to the
-- bare R15 template until a type's limb set has loaded.
local dressedTemplates: { [string]: Model } = {}
local zombies: { Zombie } = {}
local wasPaused = false
-- Resupply lure: melee forms inside the radius walk to this point instead of a player.
local lure: { position: Vector3, radius: number, expiresAt: number }? = nil

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
	local animator = zombie.humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
	if zombie.deathTrack then
		zombie.deathTrack:Play(0.1)
	end
	XPOrbService.spawnOrb(zombie.root.Position, zombie.xpReward)
	ItemEffectService.onEnemyKilled(zombie.humanoid)
	task.delay(Config.Zombies.CorpseLifetime, function()
		zombie.model:Destroy()
	end)
end

-- `groundPosition` is at ground level; the rig is pivoted up by hip height.
local function spawnZombie(groundPosition: Vector3, typeName: string)
	local definition = EnemyDefinitions[typeName]
	if not definition then
		return
	end
	local template = dressedTemplates[definition.BodySet or typeName] or zombieTemplate
	if not template then
		return
	end

	local model = template:Clone()
	model.Name = definition.DisplayName
	model:SetAttribute("EnemyType", typeName)
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

	local sac: BasePart? = nil
	if definition.ThroatSac then
		local torso = model:FindFirstChild("UpperTorso") :: BasePart?
		if torso then
			local ball = Instance.new("Part")
			ball.Name = "ThroatSac"
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.one * SAC_SIZE * definition.Scale
			ball.Massless = true
			ball.CanCollide = false
			ball.CanQuery = false
			ball.CanTouch = false
			ball.CastShadow = false
			ball.CollisionGroup = ENEMY_COLLISION_GROUP
			ball.Material = Enum.Material.SmoothPlastic
			local projectile = definition.Behaviour.Projectile
			ball.Color = if projectile then projectile.Color else definition.Color
			ball.Transparency = 0.15
			ball.CFrame = torso.CFrame * SAC_OFFSET
			local weld = Instance.new("Weld")
			weld.Part0 = torso
			weld.Part1 = ball
			weld.C0 = SAC_OFFSET
			weld.Parent = ball
			ball.Parent = model
			sac = ball
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

	-- Body clips per type (Config.Animations.Infected); the stock R15 walk until a type's
	-- clips are published. The rig stays jointed on death so the death clip can play.
	humanoid.BreakJointsOnDeath = false
	local attackTrack: AnimationTrack? = nil
	local deathTrack: AnimationTrack? = nil
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
		local clips = Config.Animations.Infected[typeName]
		local moveTrack = clips
			and Animations.load(animator, clips.move, Enum.AnimationPriority.Core)
		if moveTrack then
			local reference = Config.Animations.MoveClipSpeed[clips.move] or definition.WalkSpeed
			moveTrack.Looped = true
			moveTrack:Play()
			moveTrack:AdjustSpeed(definition.WalkSpeed / reference)
			attackTrack = Animations.load(animator, clips.attack, Enum.AnimationPriority.Action)
			deathTrack = Animations.load(animator, clips.death, Enum.AnimationPriority.Action4)
		else
			local animation = Instance.new("Animation")
			animation.AnimationId = WALK_ANIMATION_ID
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
		end
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
		attackTrack = attackTrack,
		deathTrack = deathTrack,
		nextRepathTime = 0,
		behaviour = definition.Behaviour,
		windupUntil = nil,
		throwClear = false,
		sac = sac,
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
			EnemyProjectileService.damagePlayer(targetHumanoid, zombie.damage)
			zombie.lastAttackTime = now
			if zombie.attackTrack then
				zombie.attackTrack:Play(0.1)
			end
		end
	end
end

-- A throw is clear when a ray from the mouth, or the lob's higher line, reaches the target.
local function throwIsClear(zombie: Zombie, targetRoot: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { zombie.model }
	params.CollisionGroup = ENEMY_COLLISION_GROUP -- other Infected never block
	local character = targetRoot.Parent
	local function clear(from: Vector3, to: Vector3): boolean
		local hit = workspace:Raycast(from, to - from, params)
		return hit == nil or (character ~= nil and hit.Instance:IsDescendantOf(character))
	end
	local origin = zombie.root.Position + Vector3.new(0, 1.5, 0)
	return clear(origin, targetRoot.Position)
		or clear(origin + Vector3.new(0, 7, 0), targetRoot.Position + Vector3.new(0, 1, 0))
end

local function setSacScale(zombie: Zombie, scale: number)
	local sac = zombie.sac
	if sac then
		local definition = EnemyDefinitions[zombie.typeName]
		sac.Size = Vector3.one * SAC_SIZE * definition.Scale * scale
	end
end

local function stepProjectileZombie(zombie: Zombie, now: number)
	local targetRoot = nearestPlayerRoot(zombie.root.Position)
	if not targetRoot then
		return
	end
	local behaviour = zombie.behaviour
	local spec = behaviour.Projectile
	local windupUntil = zombie.windupUntil
	if windupUntil and spec then
		-- Planted: hold still, swell the sac, then throw.
		zombie.humanoid:MoveTo(zombie.root.Position)
		local windup = behaviour.Windup or 0
		local progress = if windup > 0
			then math.clamp(1 - (windupUntil - now) / windup, 0, 1)
			else 1
		setSacScale(zombie, 1 + (Config.Zombies.ThroatSacSwell - 1) * progress)
		if now >= windupUntil then
			zombie.windupUntil = nil
			zombie.lastAttackTime = now
			setSacScale(zombie, 1)
			local head = zombie.model:FindFirstChild("Head") :: BasePart?
			local origin = if head then head.Position else zombie.root.Position
			EnemyProjectileService.fire(
				origin,
				targetRoot.Position,
				targetRoot.AssemblyLinearVelocity,
				spec,
				zombie.damage
			)
		end
		return
	end

	if now < zombie.nextRepathTime then
		return
	end
	zombie.nextRepathTime = now + REPATH_INTERVAL
	local offset = targetRoot.Position - zombie.root.Position
	local distance = offset.Magnitude
	local standOff = behaviour.StandOff or 0
	zombie.throwClear = distance <= zombie.attackRange and throwIsClear(zombie, targetRoot)
	if not zombie.throwClear then
		zombie.humanoid:MoveTo(targetRoot.Position)
	elseif distance < standOff * 0.5 then
		-- Too close: scuttle back so the lob has room (and the player has a chase).
		local away = Vector3.new(-offset.X, 0, -offset.Z)
		if away.Magnitude > 0.1 then
			zombie.humanoid:MoveTo(zombie.root.Position + away.Unit * BACK_OFF_DISTANCE)
		end
	else
		zombie.humanoid:MoveTo(zombie.root.Position) -- plant
		if spec and now - zombie.lastAttackTime >= zombie.attackCooldown then
			local flat =
				Vector3.new(targetRoot.Position.X, zombie.root.Position.Y, targetRoot.Position.Z)
			zombie.root.CFrame = CFrame.lookAt(zombie.root.Position, flat)
			zombie.windupUntil = now + (behaviour.Windup or 0)
			if zombie.attackTrack then
				zombie.attackTrack:Play(0.1)
			end
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

		if zombie.behaviour.Attack == "projectile" then
			stepProjectileZombie(zombie, now)
			continue
		end

		if now >= zombie.nextRepathTime then
			zombie.nextRepathTime = now + REPATH_INTERVAL
			local activeLure = lure
			if activeLure and now >= activeLure.expiresAt then
				lure = nil
				activeLure = nil
			end
			if
				activeLure
				and (zombie.root.Position - activeLure.position).Magnitude <= activeLure.radius
			then
				zombie.humanoid:MoveTo(activeLure.position)
			else
				local targetRoot = nearestPlayerRoot(zombie.root.Position)
				if targetRoot then
					zombie.humanoid:MoveTo(targetRoot.Position)
				end
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

-- Weighted pick honoring first-spawn times and the per-type caps in Config.Spawning
-- (count schedules, share of the horde). Falls back to Walker.
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
		local capSchedule = Config.Spawning.CapSchedule[typeName]
		if capSchedule then
			local late = Config.Spawning.CapLate[typeName] or math.huge
			if countOfType(typeName) >= scheduleLookup(capSchedule, late, elapsed) then
				continue
			end
		end
		local maxShare = Config.Spawning.MaxShare[typeName]
		if maxShare then
			local share = (countOfType(typeName) + 1) / (aliveTotal + 1)
			if share > maxShare then
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

-- Spawns `count` phase-weighted Infected in a ring around `center` (a pallet landing).
function EnemyService.spawnMixedWave(count: number, center: Vector3)
	for _ = 1, count do
		spawnZombie(groundPositionNear(center, 25, 35), pickSpawnType())
	end
end

-- Melee forms within `radius` of `position` walk to it for `duration` seconds (the
-- Resupply flare). nil clears the lure.
function EnemyService.setLure(position: Vector3?, radius: number?, duration: number?)
	if position then
		lure = {
			position = position,
			radius = radius or 0,
			expiresAt = os.clock() + (duration or 0),
		}
	else
		lure = nil
	end
end

local function spawnLoop()
	while true do
		local interval = DifficultyService.getSpawnInterval()
		-- Extra pressure while the objective is being held.
		if workspace:GetAttribute("ObjectiveActive") == true then
			interval *= Config.Difficulty.ObjectiveSpawnFactor
		end
		-- And during extraction.
		if workspace:GetAttribute("ExtractionActive") == true then
			interval *= Config.Extraction.SpawnFactor
		end
		-- And for a while after a Resupply pallet lands.
		if workspace:GetAttribute("ResupplyActive") == true then
			interval *= Config.Requisition.Lure.SpawnFactor
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
	lure = nil
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
	-- Dress one template per body set once its limb meshes exist (they build asynchronously).
	-- A form without its own set (Definition.BodySet) wears another form's.
	local bodySets: { [string]: boolean } = {}
	for typeName, definition in EnemyDefinitions do
		bodySets[definition.BodySet or typeName] = true
	end
	for setName in bodySets do
		task.spawn(function()
			local deadline = os.clock() + 30
			while not MeshAssets.hasInfectedSet(setName) and os.clock() < deadline do
				task.wait(0.5)
			end
			local base = zombieTemplate
			if not base or not MeshAssets.hasInfectedSet(setName) then
				warn(`[EnemyService] {setName} keeps the bare rig: limb meshes not loaded`)
				return
			end
			local dressed = base:Clone()
			if MeshAssets.dressInfected(dressed, setName) then
				dressedTemplates[setName] = dressed
			else
				dressed:Destroy()
			end
		end)
	end
	RunService.Heartbeat:Connect(stepZombies)
	task.spawn(spawnLoop)
	scheduleInitialWave()
end

return EnemyService
