--!strict
-- Enemy system (behaviour hooks): every Infected form is a row in
-- EnemyDefinitions. Melee forms chase and hit on contact; projectile forms (Hocker) close to
-- throw range, plant, wind up and lob through EnemyProjectileService. A phase-based spawn
-- director picks types by run time with fairness caps from Config.Spawning (count
-- schedules and share caps keyed by type). Enemies pass through each other (Enemy collision
-- group) but still hit players and the world. Player damage: EnemyProjectileService.damagePlayer.
-- Climbing: a melee form pressed against cover no taller than its
-- EnemyDefinitions.ClimbHeight goes over it (Shared.Ledge; the root is anchored and driven
-- along the ledge path for Config.Movement.Infected.Duration seconds while its climb clip
-- plays); taller cover falls through to the nudge rule.
-- Vertical chase (EQ-B1): a target more than Config.Enemies.PathfindVerticalGap
-- above a melee form near a kit building (ArenaService footprints) is followed on a
-- PathfindingService path (doors, stairs, ramps) by up to PathfindingMax bodies at once;
-- a failed path, or no slot, falls back to the straight chase.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Animations = require(ReplicatedStorage.Shared.Animations)
local Ledge = require(ReplicatedStorage.Shared.Ledge)
local Feel = require(ReplicatedStorage.Shared.Rules.Feel)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local ArenaService = require(script.Parent.ArenaService)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)
local WorldSounds = require(script.Parent.WorldSounds)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)

local ENEMY_TAG = "Enemy"
local ENEMY_COLLISION_GROUP = "Enemy"
local WALK_ANIMATION_ID = "rbxassetid://507777826" -- default R15 walk
local REPATH_INTERVAL = 0.25
local SPAWN_HIP_HEIGHT = 3.5 -- root height above ground at scale 1
local BACK_OFF_DISTANCE = 8 -- studs a projectile form retreats when a player gets inside half its stand-off
-- Nudge rule (docs/LEVELS.md): no pathfinding, so a melee form that moved less than
-- NUDGE_STUCK_DISTANCE since its last repath while still out of reach is pressed against
-- cover; it sidesteps NUDGE_DISTANCE perpendicular to its target, alternating sides.
local NUDGE_STUCK_DISTANCE = 1
local NUDGE_DISTANCE = 8
local SAC_OFFSET = CFrame.new(0, 0.95, -0.5) -- throat sac relative to UpperTorso (the rig faces -Z)
local SAC_SIZE = 0.9
-- Vocals: each form has a bank named after it (SoundBanks) with
-- <form>_idle / _attack / _hurt / _death groups (the Hocker adds _windup and _spit); lines
-- play 3D from the head through WorldSounds. Ambient lines are spaced per body and across
-- the horde (Config.Audio.Voice).
local lastIdleVoiceAt = 0

type Zombie = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	typeName: string,
	walkSpeed: number,
	damage: number,
	attackRange: number,
	attackCooldown: number,
	supplyValue: number,
	lastAttackTime: number,
	attackTrack: AnimationTrack?,
	deathTrack: AnimationTrack?,
	moveTrack: AnimationTrack?,
	-- The killing push (satisfying pass): set by the killing hit or a blast, read on death.
	push: { direction: Vector3, speed: number, blast: boolean }?,
	hitTrack: AnimationTrack?, -- the flinch (Config.Enemies.Flinch); loaded on the first one
	lastFlinchAt: number?,
	nextRepathTime: number,
	lastRepathPosition: Vector3,
	nudgeSign: number,
	behaviour: EnemyDefinitions.Behaviour,
	-- Projectile forms: the windup in progress and whether the last check had a clear throw.
	windupUntil: number?,
	throwClear: boolean,
	sac: BasePart?,
	voicePart: BasePart,
	nextIdleVoiceAt: number,
	lastHurtVoiceAt: number,
	climb: Climb?,
	climbTracks: { low: AnimationTrack?, high: AnimationTrack? },
	-- Vertical chase: holds one of the PathfindingMax slots; the path being followed; a
	-- ComputeAsync in flight; when the last one was requested.
	pathing: boolean,
	path: Path?,
	pathPending: boolean,
	pathObject: PathInstance?, -- one engine Path per body, reused across ComputeAsync calls
	pathRequestedAt: number,
	crippled: boolean?, -- a leg is gone (GoreService): crawl speed, never climbs
}

type Path = { waypoints: { PathWaypoint }, index: number }
-- The engine's Path instance (the module's own `Path` type is the waypoint list above).
type PathInstance = typeof(game:GetService("PathfindingService"):CreatePath())

-- A climb in progress: the root is anchored and carried from `start` over the ledge.
type Climb = {
	ledge: Ledge.Ledge,
	start: Vector3,
	yaw: CFrame,
	startedAt: number,
	duration: number,
	track: AnimationTrack?,
}

local EnemyService = {}

-- A boss body for IndexService (spawnBoss): the rig, the body clips; the service steers it.
export type BossHandle = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	attackTrack: AnimationTrack?,
}

local zombieTemplate: Model?
-- Per-type rigs with the Blender limb meshes (MeshAssets.dressInfected); falls back to the
-- bare R15 template until a type's limb set has loaded.
local dressedTemplates: { [string]: Model } = {}
local zombies: { Zombie } = {}
local wasPaused = false
-- Lures (the Resupply flare, a Bait Charge): melee forms inside a lure's radius walk to it
-- instead of a player. The newest lure that reaches a body wins.
type Lure = { position: Vector3, radius: number, expiresAt: number }
local lures: { Lure } = {}
-- Slows (Pen Coil, Hollow Point stagger): per-humanoid generation so overlapping slows never
-- strand a body at reduced speed.
local slowGeneration: { [Humanoid]: number } = {}
-- Limp bodies alive now (Config.Enemies.Ragdoll.MaxBodies).
local limpBodies = 0
-- Kill listeners (RequisitionService): every death credits its SupplyValue to the squad.
local killListeners: { (supplyValue: number, position: Vector3) -> () } = {}

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

-- The nearest living squad member's root: players and bots alike (Squad).
local function nearestPlayerRoot(fromPosition: Vector3): BasePart?
	local member = Squad.nearestLiving(fromPosition)
	return member and member.root
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

local function voice(zombie: Zombie, line: string)
	local bank = string.lower(zombie.typeName)
	WorldSounds.voice(zombie.voicePart, bank, bank .. "_" .. line)
end

local function randomIdleDelay(): number
	local range = Config.Audio.Voice.IdleInterval
	return range[1] + math.random() * (range[2] - range[1])
end

local function zombieOfHumanoid(humanoid: Humanoid): Zombie?
	for _, zombie in zombies do
		if zombie.humanoid == humanoid then
			return zombie
		end
	end
	return nil
end

local function flatDirection(away: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(away.X, 0, away.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else fallback
end

-- Loosens a dead body and throws it along its push. False when the rig has no ball sockets
-- to hold it together (then the death clip plays instead).
local function goLimp(zombie: Zombie): boolean
	local model = zombie.model
	if not model:FindFirstChildWhichIsA("BallSocketConstraint", true) then
		return false
	end
	local cfg = Config.Enemies.Ragdoll
	local push = zombie.push
	local direction = if push then push.direction else -zombie.root.CFrame.LookVector
	local speed = if push then push.speed else cfg.Push.PerDamage * 20
	local up = math.min(speed * cfg.UpShare, cfg.MaxUp)
	local velocity = direction * speed + Vector3.new(0, up, 0)
	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") or item:IsA("Motor6D") then
			(item :: any).Enabled = false
		elseif item:IsA("BallSocketConstraint") then
			item.Enabled = true
		elseif item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	-- The invisible root leaves the body (its joint is off): pinned where it stood, so it
	-- does not fall through the world.
	zombie.root.Anchored = true
	zombie.root.CanCollide = false
	for _, part in parts do
		if part == zombie.root then
			continue
		end
		part.Anchored = false
		part.CanCollide = true
		part.CollisionGroup = "Gore" -- GoreService: never collides with the living Infected
		part.AssemblyLinearVelocity = velocity
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end
	task.delay(cfg.Settle, function()
		for _, part in parts do
			if part.Parent then
				part.Anchored = true
			end
		end
	end)
	return true
end

-- GoreService.blast: a blast killed this body; it is thrown away from `center`.
function EnemyService.noteBlast(humanoid: Humanoid, center: Vector3)
	local zombie = zombieOfHumanoid(humanoid)
	if not zombie then
		return
	end
	local fallback = -zombie.root.CFrame.LookVector
	zombie.push = {
		direction = flatDirection(zombie.root.Position - center, fallback),
		speed = Feel.knockback("Blast", 0, Config.Enemies.Ragdoll.Push),
		blast = true,
	}
end

-- A hit that did not kill: a flinch, unless one played inside the cooldown.
local function flinch(zombie: Zombie, info: DamageService.HitInfo)
	local cfg = Config.Enemies.Flinch
	local now = os.clock()
	if not Feel.canFlinch(now, zombie.lastFlinchAt, cfg.Cooldown) then
		return
	end
	if (cfg.HeavyOnly :: { [string]: boolean })[zombie.typeName] then
		local weapon = info.attacker and info.attacker:GetAttribute(Attributes.Weapon)
		local heavy = typeof(weapon) == "string" and WeaponDefinitions.get(weapon).Heavy == true
		if not heavy then
			return
		end
	end
	if not zombie.hitTrack then
		local clips = (Config.Animations.Infected :: any)[zombie.typeName]
		local clip: string? = clips and clips.hit
		local animator = zombie.humanoid:FindFirstChildOfClass("Animator")
		zombie.hitTrack = clip
				and animator
				and Animations.load(animator, clip, Enum.AnimationPriority.Action2)
			or nil
	end
	local track = zombie.hitTrack
	if not track then
		return
	end
	zombie.lastFlinchAt = now
	local headshot = info.kind == "headshot"
	track:Play(0.05, 1, if headshot then cfg.HeadshotSpeed else 1)
	if headshot then
		EnemyService.slow(zombie.humanoid, cfg.HeadshotSlow, cfg.HeadshotSlowTime)
	end
end

-- A killing round: the body goes over away from whoever fired it. Any other hit: a flinch.
local function onHit(info: DamageService.HitInfo)
	if not info.killed then
		local zombie = zombieOfHumanoid(info.humanoid)
		if zombie and not zombie.climb then
			flinch(zombie, info)
		end
		return
	end
	local zombie = zombieOfHumanoid(info.humanoid)
	if not zombie or (zombie.push and zombie.push.blast) then
		return
	end
	local fallback = -zombie.root.CFrame.LookVector
	local character = info.attacker and info.attacker.Character
	local from = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	zombie.push = {
		direction = if from
			then flatDirection(zombie.root.Position - from.Position, fallback)
			else fallback,
		speed = Feel.knockback(info.kind, info.amount, Config.Enemies.Ragdoll.Push),
		blast = false,
	}
end

local function onZombieDied(zombie: Zombie)
	CollectionService:RemoveTag(zombie.model, ENEMY_TAG)
	voice(zombie, "death")
	-- Shot mid-climb: the corpse falls instead of hanging in the air.
	if zombie.climb then
		zombie.climb = nil
		zombie.root.Anchored = false
	end
	local animator = zombie.humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
	local definition = EnemyDefinitions[zombie.typeName]
	local boss = definition and definition.Boss
	local limp = false
	if not boss and limpBodies < Config.Enemies.Ragdoll.MaxBodies then
		limp = goLimp(zombie)
	end
	if limp then
		limpBodies += 1
	elseif zombie.deathTrack then
		zombie.deathTrack:Play(0.1)
	end
	for _, listener in killListeners do
		listener(zombie.supplyValue, zombie.root.Position)
	end
	DamageService.onEnemyKilled(zombie.humanoid)
	local lifetime = if boss
		then Config.Enemies.BossCorpseLifetime
		else Config.Enemies.CorpseLifetime
	task.delay(lifetime, function()
		if limp then
			limpBodies -= 1
		end
		zombie.model:Destroy()
	end)
end

-- `groundPosition` is at ground level; the rig is pivoted up by hip height. `prepare` runs
-- on the clone before it is scaled (a boss's plates go on at scale 1 and scale with it).
local function spawnZombie(
	groundPosition: Vector3,
	typeName: string,
	prepare: ((Model) -> ())?
): Zombie?
	local definition = EnemyDefinitions[typeName]
	if not definition then
		return nil
	end
	local template = dressedTemplates[definition.BodySet or typeName] or zombieTemplate
	if not template then
		return nil
	end

	local model = template:Clone()
	model.Name = definition.DisplayName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a rig never half-streams
	model:SetAttribute(Attributes.EnemyType, typeName)
	if prepare then
		prepare(model)
	end
	if definition.Scale ~= 1 then
		model:ScaleTo(definition.Scale)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local health = definition.MaxHealth * DifficultyService.getHealthMultiplier()
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = definition.WalkSpeed
	-- EnemyService.slow restores this after a slow without corrupting it.
	humanoid:SetAttribute(Attributes.BaseWalkSpeed, definition.WalkSpeed)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if not definition.Boss then
		attachHealthBar(humanoid, root, definition.Scale) -- a boss has the boss bar (BossBarUI)
	end

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
	local movingTrack: AnimationTrack? = nil
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
			movingTrack = moveTrack
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
		supplyValue = definition.SupplyValue,
		lastAttackTime = 0,
		attackTrack = attackTrack,
		deathTrack = deathTrack,
		moveTrack = movingTrack,
		nextRepathTime = 0,
		lastRepathPosition = Vector3.new(1e9, 0, 0),
		nudgeSign = 1,
		behaviour = definition.Behaviour,
		windupUntil = nil,
		throwClear = false,
		sac = sac,
		voicePart = (model:FindFirstChild("Head") :: BasePart?) or root,
		nextIdleVoiceAt = os.clock() + randomIdleDelay() * 0.5,
		lastHurtVoiceAt = 0,
		climb = nil,
		climbTracks = {},
		pathing = false,
		path = nil,
		pathPending = false,
		pathRequestedAt = 0,
	}
	if definition.ClimbHeight then
		pcall(function()
			local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
			local clips = Config.Animations.Infected[typeName]
			if clips and clips.climb then
				zombie.climbTracks.low =
					Animations.load(animator, clips.climb, Enum.AnimationPriority.Action3)
			end
			if clips and clips.climbHigh then
				zombie.climbTracks.high =
					Animations.load(animator, clips.climbHigh, Enum.AnimationPriority.Action3)
			end
		end)
	end
	table.insert(zombies, zombie)

	humanoid.HealthChanged:Connect(function(newHealth)
		-- One pain grunt per burst of hits, not one per bullet.
		local now = os.clock()
		if newHealth > 0 and now - zombie.lastHurtVoiceAt >= Config.Audio.Voice.HurtCooldown then
			zombie.lastHurtVoiceAt = now
			zombie.nextIdleVoiceAt = math.max(zombie.nextIdleVoiceAt, now + 1.5)
			voice(zombie, "hurt")
		end
	end)
	humanoid.Died:Connect(function()
		onZombieDied(zombie)
	end)
	return zombie
end

-- Ambient lines: one body at a time, spaced out, only near someone who can hear them.
local function idleVoice(zombie: Zombie, now: number)
	if now < zombie.nextIdleVoiceAt then
		return
	end
	local settings = Config.Audio.Voice
	if now - lastIdleVoiceAt < settings.IdleGlobalGap then
		return
	end
	zombie.nextIdleVoiceAt = now + randomIdleDelay()
	local targetRoot = nearestPlayerRoot(zombie.root.Position)
	if
		not targetRoot
		or (targetRoot.Position - zombie.root.Position).Magnitude > settings.IdleMaxDistance
	then
		return
	end
	lastIdleVoiceAt = now
	voice(zombie, "idle")
end

local function removeZombie(index: number)
	zombies[index] = zombies[#zombies]
	zombies[#zombies] = nil
end

-- Pressed against cover it can take: starts the climb. Returns true when one started.
local function tryClimb(zombie: Zombie, toward: Vector3, now: number): boolean
	local definition = EnemyDefinitions[zombie.typeName]
	local maxHeight = definition.ClimbHeight
	local duration = Config.Movement.Infected.Duration[zombie.typeName]
	if not maxHeight or not duration or zombie.crippled then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { zombie.model }
	params.CollisionGroup = ENEMY_COLLISION_GROUP -- other Infected never block
	local ledge = Ledge.find(zombie.root, zombie.humanoid, toward, maxHeight, params)
	if not ledge then
		return false
	end
	local track = if ledge.height > Config.Movement.Infected.LowHeight
		then zombie.climbTracks.high
		else zombie.climbTracks.low
	local yaw = CFrame.lookAlong(Vector3.zero, ledge.forward)
	zombie.humanoid:MoveTo(zombie.root.Position)
	zombie.root.CFrame = CFrame.new(zombie.root.Position) * yaw
	zombie.root.AssemblyLinearVelocity = Vector3.zero
	zombie.root.Anchored = true
	if track then
		track:Play(0.1)
		track:AdjustSpeed(math.max(track.Length, 0.01) / duration)
	end
	zombie.climb = {
		ledge = ledge,
		start = zombie.root.Position,
		yaw = yaw,
		startedAt = now,
		duration = duration,
		track = track,
	}
	return true
end

local function stepClimb(zombie: Zombie, climb: Climb, now: number)
	local alpha = (now - climb.startedAt) / climb.duration
	if alpha >= 1 then
		zombie.root.CFrame = CFrame.new(climb.ledge.landing) * climb.yaw
		zombie.root.Anchored = false
		zombie.root.AssemblyLinearVelocity = Vector3.zero
		if climb.track and climb.track.IsPlaying then
			climb.track:Stop(0.2)
		end
		zombie.climb = nil
		zombie.nextRepathTime = now
		zombie.lastRepathPosition = Vector3.new(1e9, 0, 0)
		return
	end
	zombie.root.CFrame = CFrame.new(Ledge.position(climb.start, climb.ledge, alpha)) * climb.yaw
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
		-- A body going over cover can't be clawed (CoverMoveService): the claw is "melee",
		-- which damagePlayer skips inside the window. The swing still plays.
		local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			EnemyProjectileService.damagePlayer(targetHumanoid, zombie.damage, "melee")
			zombie.lastAttackTime = now
			zombie.nextIdleVoiceAt = math.max(zombie.nextIdleVoiceAt, now + 2)
			voice(zombie, "attack")
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
		setSacScale(zombie, 1 + (Config.Enemies.ThroatSacSwell - 1) * progress)
		if now >= windupUntil then
			zombie.windupUntil = nil
			zombie.lastAttackTime = now
			setSacScale(zombie, 1)
			local head = zombie.model:FindFirstChild("Head") :: BasePart?
			local origin = if head then head.Position else zombie.root.Position
			voice(zombie, "spit")
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
			zombie.nextIdleVoiceAt = math.max(zombie.nextIdleVoiceAt, now + 3)
			voice(zombie, "windup")
			if zombie.attackTrack then
				zombie.attackTrack:Play(0.1)
			end
		end
	end
end

-- Vertical chase helpers. A body wants a path when its target is well above it near a kit
-- building (a floor, a roof, a perch reached by stairs or a ramp the straight chase and the
-- nudge rule never find).
local function wantsPath(here: Vector3, goal: Vector3): boolean
	local settings = Config.Enemies
	return goal.Y - here.Y > settings.PathfindVerticalGap
		and ArenaService.buildingDistance(goal) <= settings.PathfindBuildingRadius
end

local function requestPath(zombie: Zombie, here: Vector3, goal: Vector3, now: number)
	zombie.pathPending = true
	zombie.pathRequestedAt = now
	local settings = Config.Enemies
	local path = zombie.pathObject
	if not path then
		path = PathfindingService:CreatePath({
			AgentRadius = settings.PathAgentRadius,
			AgentHeight = settings.PathAgentHeight,
			AgentCanJump = false,
			AgentCanClimb = false, -- ladders are the squad's (Ladder collision group)
			WaypointSpacing = settings.PathWaypointSpacing,
		})
		zombie.pathObject = path
	end
	local enginePath: PathInstance = path
	task.spawn(function()
		local ok = pcall(enginePath.ComputeAsync, enginePath, here, goal)
		zombie.pathPending = false
		if ok and enginePath.Status == Enum.PathStatus.Success and zombie.model.Parent then
			zombie.path = { waypoints = enginePath:GetWaypoints(), index = 2 }
		else
			zombie.path = nil
		end
	end)
end

-- Moves toward the next waypoint; false when there is no usable path (chase straight).
local function followPath(zombie: Zombie, here: Vector3): boolean
	local path = zombie.path
	if not path then
		return false
	end
	local reach = Config.Enemies.PathWaypointReach
	while path.index <= #path.waypoints do
		local waypoint = path.waypoints[path.index].Position
		if Vector3.new(waypoint.X - here.X, 0, waypoint.Z - here.Z).Magnitude > reach then
			break
		end
		path.index += 1
	end
	local target = path.waypoints[path.index]
	if not target then
		zombie.path = nil
		return false
	end
	zombie.humanoid:MoveTo(target.Position)
	return true
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
	local pathingCount = 0
	for _, zombie in zombies do
		if zombie.pathing then
			pathingCount += 1
		end
	end
	for index = #zombies, 1, -1 do
		local zombie = zombies[index]
		if not zombie.model.Parent or zombie.humanoid.Health <= 0 then
			removeZombie(index)
			continue
		end
		idleVoice(zombie, now)

		local climb = zombie.climb
		if climb then
			stepClimb(zombie, climb, now)
			continue
		end

		if zombie.behaviour.Attack == "projectile" then
			stepProjectileZombie(zombie, now)
			continue
		end
		if zombie.behaviour.Attack == "boss" then
			continue -- IndexService steers the Index hosts
		end

		if now >= zombie.nextRepathTime then
			zombie.nextRepathTime = now + REPATH_INTERVAL
			local activeLure: Lure? = nil
			for lureIndex = #lures, 1, -1 do
				local candidate = lures[lureIndex]
				if now >= candidate.expiresAt then
					table.remove(lures, lureIndex)
				elseif
					not activeLure
					and (zombie.root.Position - candidate.position).Magnitude
						<= candidate.radius
				then
					activeLure = candidate
				end
			end
			if activeLure then
				zombie.humanoid:MoveTo(activeLure.position)
			else
				local targetRoot = nearestPlayerRoot(zombie.root.Position)
				if targetRoot then
					local here = zombie.root.Position
					local goal = targetRoot.Position
					-- Vertical chase: take or give back a pathing slot, follow the path.
					local wants = wantsPath(here, goal)
					if
						wants
						and not zombie.pathing
						and pathingCount < Config.Enemies.PathfindingMax
					then
						zombie.pathing = true
						pathingCount += 1
					elseif not wants and zombie.pathing then
						zombie.pathing = false
						zombie.path = nil
						pathingCount -= 1
					end
					if zombie.pathing then
						if
							not zombie.pathPending
							and now - zombie.pathRequestedAt >= Config.Enemies.PathfindInterval
						then
							requestPath(zombie, here, goal, now)
						end
						if followPath(zombie, here) then
							zombie.lastRepathPosition = here
							attackIfTouching(zombie, now)
							continue
						end
					end
					local stuck = (here - zombie.lastRepathPosition).Magnitude
						< NUDGE_STUCK_DISTANCE
					if stuck and (goal - here).Magnitude > zombie.attackRange then
						local toTarget = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
						if toTarget.Magnitude > 0.1 and tryClimb(zombie, toTarget, now) then
							continue
						end
						if toTarget.Magnitude > 0.1 then
							local side = Vector3.new(-toTarget.Z, 0, toTarget.X).Unit
								* zombie.nudgeSign
							zombie.nudgeSign = -zombie.nudgeSign
							goal = here + side * NUDGE_DISTANCE
						end
					end
					zombie.lastRepathPosition = here
					zombie.humanoid:MoveTo(goal)
				end
			end
		end

		attackIfTouching(zombie, now)
	end
end

-- Open ground: not a dressing piece, a perch, a gantry or a kit building (the Infected
-- never appear on a roof or a container, and never inside a room). Terrain, roads, hills
-- and the highway qualify.
local BLOCKED_SPAWN_PARENTS = { "Dressing", "Buildings", "Perches", "DeckGantry", "Landmarks" }
local function isOpenGround(hit: RaycastResult?): boolean
	if not hit then
		return false
	end
	local ancestor: Instance? = hit.Instance
	while ancestor and ancestor ~= workspace do
		if table.find(BLOCKED_SPAWN_PARENTS, ancestor.Name) then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

-- A ring around `center`; retries (Config.Spawning.SpawnAttempts) until the candidate is open
-- ground outside every building footprint, then settles for the last one.
local function groundPositionNear(
	center: Vector3,
	minDistance: number,
	maxDistance: number
): Vector3
	local candidate = center
	-- Bodies are not ground: a spawn must not land on an Infected, a bot or a player.
	local exclude: { Instance } = {}
	for _, zombie in zombies do
		table.insert(exclude, zombie.model)
	end
	for _, member in Squad.living() do
		local root = member.root
		local body = root and root.Parent
		if body then
			table.insert(exclude, body)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for _ = 1, Config.Spawning.SpawnAttempts do
		local angle = math.random() * math.pi * 2
		local distance = math.random(minDistance, maxDistance)
		-- Inside the perimeter (Config.Arena.SpawnInset): no spawn in the fence band or past it.
		local inset = Config.Arena.SpawnInset
		local x = math.clamp(center.X + math.cos(angle) * distance, -inset, inset)
		local z = math.clamp(center.Z + math.sin(angle) * distance, -inset, inset)
		local result =
			workspace:Raycast(Vector3.new(x, center.Y + 50, z), Vector3.new(0, -200, 0), params)
		local groundY = if result then result.Position.Y else 0
		candidate = Vector3.new(x, groundY, z)
		if
			isOpenGround(result)
			and not ArenaService.insideBuilding(candidate, Config.Spawning.SpawnBuildingMargin)
		then
			return candidate
		end
	end
	return candidate
end

-- Spawns ring a random living squad member (#6): never a dead body or an empty pad.
local function randomSpawnPosition(): Vector3?
	local living = Squad.living()
	if #living == 0 then
		return nil
	end
	local root = living[math.random(#living)].root
	if not root then
		return nil
	end
	return groundPositionNear(
		root.Position,
		Config.Spawning.MinSpawnDistance,
		Config.Spawning.MaxSpawnDistance
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

-- Living players beyond the first: heavy caps grow with people (Config.PlayerCountScaling).
local function extraPlayers(): number
	return math.max(#Squad.livingOwners() - 1, 0)
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
			local cap = scheduleLookup(capSchedule, late, elapsed)
				+ Config.PlayerCountScaling.HeavyCapPerExtraPlayer * extraPlayers()
			if countOfType(typeName) >= cap then
				continue
			end
		end
		-- While the Index is up: his pressure caps (no Brutes).
		local indexCap = if workspace:GetAttribute(Attributes.IndexActive) == true
			then Config.Index.Warden.Pressure.Caps[typeName]
			else nil
		if indexCap and countOfType(typeName) >= indexCap then
			continue
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

-- IndexService: spawns a boss form at `groundPosition` and hands its body back. The chase
-- loop leaves it alone (Behaviour.Attack "boss"); death still credits SupplyValue.
function EnemyService.spawnBoss(
	typeName: string,
	groundPosition: Vector3,
	prepare: ((Model) -> ())?
): BossHandle?
	local zombie = spawnZombie(groundPosition, typeName, prepare)
	if not zombie then
		return nil
	end
	return {
		model = zombie.model,
		humanoid = zombie.humanoid,
		root = zombie.root,
		attackTrack = zombie.attackTrack,
	}
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
-- Resupply flare, a Bait Charge). Lures stack; nil clears them all.
function EnemyService.setLure(position: Vector3?, radius: number?, duration: number?)
	if position then
		table.insert(lures, {
			position = position,
			radius = radius or 0,
			expiresAt = os.clock() + (duration or 0),
		})
	else
		table.clear(lures)
	end
end

-- Multiplies an Infected's speed by `factor` for `duration` seconds, then restores its
-- BaseWalkSpeed. A newer slow replaces an older one (generation guard).
function EnemyService.slow(humanoid: Humanoid, factor: number, duration: number)
	if humanoid.Health <= 0 then
		return
	end
	local base = (humanoid:GetAttribute(Attributes.BaseWalkSpeed) :: number?) or humanoid.WalkSpeed
	local generation = (slowGeneration[humanoid] or 0) + 1
	slowGeneration[humanoid] = generation
	humanoid.WalkSpeed = base * factor
	task.delay(duration, function()
		if humanoid.Parent and slowGeneration[humanoid] == generation then
			if not PauseService.isPaused() then
				humanoid.WalkSpeed = base
			end
			slowGeneration[humanoid] = nil
		end
	end)
end

local function zombieOf(model: Model): Zombie?
	for _, zombie in zombies do
		if zombie.model == model then
			return zombie
		end
	end
	return nil
end

-- GoreService: an arm came off. Melee damage scales by `factor` (per arm lost).
function EnemyService.disarm(model: Model, factor: number)
	local zombie = zombieOf(model)
	if zombie then
		zombie.damage *= factor
	end
end

-- GoreService: a leg came off. The body crawls at `factor` of its speed for good (slows and
-- staggers restore to the crawl, not the walk) and never climbs again.
function EnemyService.cripple(model: Model, factor: number)
	local zombie = zombieOf(model)
	if not zombie or zombie.crippled then
		return
	end
	zombie.crippled = true
	zombie.walkSpeed *= factor
	zombie.humanoid:SetAttribute(Attributes.BaseWalkSpeed, zombie.walkSpeed)
	if not PauseService.isPaused() then
		zombie.humanoid.WalkSpeed = zombie.walkSpeed
	end
	-- On its hands now: the crawl clip replaces the walk (Config.Animations.Infected.crawl).
	local clips = (Config.Animations.Infected :: any)[zombie.typeName]
	local crawl: string? = clips and clips.crawl
	local animator = zombie.humanoid:FindFirstChildOfClass("Animator")
	if crawl and animator then
		local track = Animations.load(animator, crawl, Enum.AnimationPriority.Core)
		if track then
			if zombie.moveTrack then
				zombie.moveTrack:Stop(0.3)
			end
			local reference = (Config.Animations.MoveClipSpeed :: any)[crawl] or zombie.walkSpeed
			track.Looped = true
			track:Play(0.3)
			track:AdjustSpeed(zombie.walkSpeed / reference)
			zombie.moveTrack = track
		end
	end
end

-- Hollow Point: the body stops for `seconds`.
function EnemyService.stagger(humanoid: Humanoid, seconds: number)
	EnemyService.slow(humanoid, 0, seconds)
end

-- RequisitionService: fired on every death with the form's SupplyValue and where it fell.
function EnemyService.addKillListener(listener: (supplyValue: number, position: Vector3) -> ())
	table.insert(killListeners, listener)
end

local function spawnLoop()
	while true do
		local interval = DifficultyService.getSpawnInterval()
		-- Extra pressure while the objective is being held.
		if workspace:GetAttribute(Attributes.ObjectiveActive) == true then
			interval *= Config.Difficulty.ObjectiveSpawnFactor
		end
		-- And during extraction.
		if workspace:GetAttribute(Attributes.ExtractionActive) == true then
			interval *= Config.Extraction.SpawnFactor
		end
		-- And for a while after a Resupply pallet lands.
		if workspace:GetAttribute(Attributes.ResupplyActive) == true then
			interval *= Config.Requisition.Lure.SpawnFactor
		end
		-- Less while the Index is up: the fight is the pressure (Config.Index.Warden.Pressure).
		local maxAlive = DifficultyService.getMaxAlive()
		if workspace:GetAttribute(Attributes.IndexActive) == true then
			local pressure = Config.Index.Warden.Pressure
			interval *= pressure.SpawnFactor
			maxAlive = math.max(4, maxAlive - pressure.MaxAliveReduction)
		end
		task.wait(interval)
		if
			RunStates.isLive()
			and workspace:GetAttribute(Attributes.DevSpawnsOff) ~= true
			and not PauseService.isPaused()
			and #zombies < maxAlive
		then
			local position = randomSpawnPosition()
			if position then
				spawnZombie(position, pickSpawnType())
			end
		end
	end
end

-- Bumped on every reset so a pending first wave never lands in the next run.
local missionGeneration = 0

-- RunManager, on Explore: first contact within seconds (Sprint 8 pacing).
function EnemyService.startMission()
	missionGeneration += 1
	local generation = missionGeneration
	task.delay(1.5, function()
		if generation == missionGeneration and RunStates.isLive() then
			EnemyService.spawnWave("Walker", Config.Spawning.InitialCount)
		end
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
	table.clear(lures)
	table.clear(slowGeneration)
	missionGeneration += 1
	EnemyService.clearAll()
end

function EnemyService.init()
	Lifecycle.register("EnemyService", {
		onRunStart = EnemyService.reset,
	})
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
	DamageService.addHitListener(onHit)
	RunService.Heartbeat:Connect(stepZombies)
	task.spawn(spawnLoop)
end

return EnemyService
