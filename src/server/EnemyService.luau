--!strict
-- Enemy system (behaviour hooks): every Infected form is a row in
-- EnemyDefinitions. Melee forms chase and hit on contact; projectile forms (Hocker) close to
-- throw range, plant, wind up and lob through EnemyProjectileService. A phase-based spawn
-- director picks types by run time with fairness caps from Config.Spawning (count
-- schedules and share caps keyed by type). Enemies pass through each other (Enemy collision
-- group; EnemySpacing steers the chase so they rarely do) but still hit players and the
-- world. Player damage: EnemyProjectileService.damagePlayer.
-- Climbing: a melee form pressed against cover no taller than its
-- EnemyDefinitions.ClimbHeight goes over it (Shared.Ledge; the root is anchored and driven
-- along the ledge path for Config.Movement.Infected.Duration seconds while its climb clip
-- plays); taller cover falls through to the nudge rule.
-- Vertical chase (EQ-B1): a target more than Config.Enemies.PathfindVerticalGap
-- above a melee form near a kit building (ArenaService footprints) is followed on a
-- PathfindingService path (doors, stairs, ramps) by up to PathfindingMax bodies at once;
-- a failed path, or no slot, falls back to the straight chase.
-- Awareness (Config.Awareness, Shared.Rules.Awareness; Nova 2026-11-11, the night map): on a
-- mission listed there every body is Sleeping, Idle, Wandering, Alerted or in Chase. Only a
-- Chase runs the straight chase below; the rest hold, shuffle or go to look, and notice by
-- sight (a cone, raycast) and by noise (EnemyService.noise: shots, blasts, running feet).

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
local Awareness = require(ReplicatedStorage.Shared.Rules.Awareness)
local ArenaService = require(script.Parent.ArenaService)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local EnemySpacing = require(script.Parent.EnemySpacing)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)
local WorldSounds = require(script.Parent.WorldSounds)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local Missions = require(script.Parent.Missions)
local InfectedMoves = require(ReplicatedStorage.Shared.Rules.InfectedMoves)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

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
local SAC_OFFSET = CFrame.new(0, 0.95, -0.5) -- throat sac from the UpperTorso limb centre (the rig faces -Z)
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
	lob: boolean?, -- the clear throw is a high lob over cover (Config.InfectedMoves.Hocker.Lob)
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
	moveReference: number, -- the move clip's own speed (its rate is pace / this)
	aware: Aware?, -- on an awareness mission (Config.Awareness); nil = always chase
	-- A big move in progress (Config.InfectedMoves: the Brute's charge, the Runner's pounce
	-- and pin) and when the next may start.
	move: Move?,
	nextMoveAt: number,
	ghosted: { BasePart }?, -- parts made non-solid for a pounce and pin (setSolid)
}

-- A big move (Config.InfectedMoves). The root is anchored and driven through every stage
-- but a pin's end; `target` is the soldier it is for.
type Move = {
	kind: "chargeWindup" | "charge" | "pounceWindup" | "pounce" | "pin",
	startedAt: number,
	untilAt: number,
	target: Squad.Member,
	yaw: CFrame, -- facing, at the root's position (windups turn it toward the target)
	from: Vector3,
	to: Vector3, -- the charge's end or the pounce's landing
	direction: Vector3, -- flat unit, the charge
	hit: { [Humanoid]: boolean }, -- the charge: each body once
	nextTickAt: number, -- the pin's next claw
	nextVoiceAt: number,
}

-- What a body on an awareness mission is doing (Rules/Awareness).
type Aware = {
	state: Awareness.State,
	post: Vector3, -- where it was placed; a wanderer strays round it
	spot: Vector3?, -- Alerted: where it heard or saw something
	goal: Vector3?, -- where it is walking now (a wander or a search point)
	untilAt: number, -- Wandering: stands till then; Alerted: searches till then
	searching: boolean, -- Alerted and at the spot
	notice: number, -- 0..1, built by seeing a soldier (1 = Chase)
	nextLookAt: number,
	lastSeenAt: number, -- Chase: the last time a soldier was in sight
	lastSeen: Vector3?,
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
	-- The walk clip and its 1x ground speed: IndexService sets its rate from his real speed.
	moveTrack: AnimationTrack?,
	moveReference: number,
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
-- Awareness on this mission (Config.Awareness.Missions; the place's mission never changes).
local AW = Config.Awareness
local awareOn = AW.Missions[Missions.current().Id] == true
local awareNight = AW.Night[Missions.current().Id] == true
local lookParams = RaycastParams.new() -- sight lines: every Infected body excluded
lookParams.FilterType = Enum.RaycastFilterType.Exclude
local nextFootstepsAt = 0
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

-- --- Big moves (Config.InfectedMoves; Rules/InfectedMoves; docs/sprints/FUN_ENEMIES.md).
-- The Brute's charge and the Runner's pounce run as a small state machine on the body
-- (zombie.move): a windup (the tell: a sound and a pose, the root anchored and turning to
-- follow), then the move itself, then a recovery or a stun. A pounce that lands becomes a
-- pin until the Runner is shot, shoved or times out. The Walker's grab and the Hocker's lob
-- and barrage hang off their normal attacks.

local MOVES = Config.InfectedMoves
local moveParams = RaycastParams.new() -- walls between a body and its target: other Infected never block
moveParams.FilterType = Enum.RaycastFilterType.Exclude
moveParams.CollisionGroup = ENEMY_COLLISION_GROUP
local grabTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Control's lines (Config.InfectedMoves.Radio): which first-time lines this run has had.
local toldThisRun: { [string]: boolean } = {}
local lastPinRadioAt = -math.huge

local function radio(text: string)
	Remotes.get("BuffNotice"):FireAllClients(text, Messages.Notice.Radio)
end

-- A first-time line (FirstCharge, FirstLob), once a run.
local function radioOnce(key: string)
	if toldThisRun[key] then
		return
	end
	toldThisRun[key] = true
	radio((MOVES.Radio :: any)[key])
end

-- The form's Config.InfectedMoves row, or nil while the moves are off.
local function movesRow(typeName: string): any
	if not MOVES.Enabled or workspace:GetAttribute(Attributes.DevMovesOff) == true then
		return nil
	end
	return (MOVES :: any)[typeName]
end

-- The form's big move ("charge" | "pounce") and its settings, when it has one on.
local function bigMove(typeName: string): (string?, any)
	local row = movesRow(typeName)
	if row and row.Charge and row.Charge.Enabled then
		return "charge", row.Charge
	elseif row and row.Pounce and row.Pounce.Enabled then
		return "pounce", row.Pounce
	end
	return nil, nil
end

local function firstMoveDelay(typeName: string): number
	local _, settings = bigMove(typeName)
	return if settings then settings.FirstDelay or 0 else 0
end

-- Nothing but the target (or open air) between `from` and the target's root.
local function lineClear(zombie: Zombie, from: Vector3, targetRoot: BasePart): boolean
	moveParams.FilterDescendantsInstances = { zombie.model }
	local hit = workspace:Raycast(from, targetRoot.Position - from, moveParams)
	local character = targetRoot.Parent
	return hit == nil or (character ~= nil and hit.Instance:IsDescendantOf(character))
end

-- A soldier a big move may go for: alive, on their feet, not riding, not already pinned.
local function canBeTaken(member: Squad.Member): boolean
	local character = member.character
	return Squad.isAlive(member)
		and character ~= nil
		and member.root ~= nil
		and member.humanoid ~= nil
		and character:GetAttribute(Attributes.KnockedUntil) == nil
		and character:GetAttribute(Attributes.Pinned) == nil
		and character:GetAttribute(Attributes.Riding) == nil
end

-- A pouncing or pinning Runner is not solid: an anchored body on a soldier would shove
-- their physics about. Solid again when the move ends.
local function setSolid(zombie: Zombie, solid: boolean)
	local ghosted = zombie.ghosted
	if solid then
		if ghosted then
			for _, part in ghosted do
				part.CanCollide = true
			end
		end
		zombie.ghosted = nil
	elseif not ghosted then
		local parts: { BasePart } = {}
		for _, part in zombie.model:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
				table.insert(parts, part)
			end
		end
		zombie.ghosted = parts
	end
end

local function moveTrackSpeed(zombie: Zombie, speed: number)
	local track = zombie.moveTrack
	if track then
		track:AdjustSpeed(math.clamp(speed / zombie.moveReference, 0, 3))
	end
end

-- Ends the body's big move: a pin lets go (the soldier gets up), the root is free again,
-- the next move waits its cooldown, and `stun` seconds of stagger follow (a wall, a miss,
-- a shove). Safe to call on a dead body (the death hands its limp body back the same way).
local function endMove(zombie: Zombie, now: number, stun: number)
	local move = zombie.move
	if not move then
		return
	end
	zombie.move = nil
	local root = zombie.root
	local alive = zombie.humanoid.Health > 0
	if move.kind == "pin" then
		zombie.model:SetAttribute(Attributes.Pinning, nil)
		local character = move.target.character
		if character and character.Parent then
			character:SetAttribute(Attributes.Pinned, nil)
		end
		Squad.standUp(move.target, Config.Knockdown.GetUp)
		local _, settings = bigMove(zombie.typeName)
		if alive and settings then
			-- Thrown clear of the body, short of any wall behind.
			local back = -move.yaw.LookVector
			moveParams.FilterDescendantsInstances = { zombie.model }
			local hop = settings.HopOff or 0
			local hit = workspace:Raycast(root.Position, back * hop, moveParams)
			local distance = if hit then math.max(hit.Distance - 1.5, 0) else hop
			root.CFrame = CFrame.new(root.Position + back * distance) * move.yaw.Rotation
		end
	else
		root.CFrame = CFrame.new(root.Position) * move.yaw.Rotation -- upright again
	end
	setSolid(zombie, true) -- a limp body needs its collisions too
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	moveTrackSpeed(zombie, zombie.walkSpeed)
	local _, settings = bigMove(zombie.typeName)
	zombie.nextMoveAt = now + (if settings then settings.Cooldown else 5)
	zombie.nextRepathTime = now
	zombie.lastRepathPosition = Vector3.new(1e9, 0, 0)
	if stun > 0 and alive then
		EnemyService.stagger(zombie.humanoid, stun)
	end
end

-- A Brute or Runner with its move ready and a soldier in its band in the open: the windup
-- starts (the tell). True when it did.
local function tryStartMove(zombie: Zombie, now: number): boolean
	if now < zombie.nextMoveAt or zombie.crippled or slowGeneration[zombie.humanoid] then
		return false
	end
	local kind, settings = bigMove(zombie.typeName)
	if not kind then
		zombie.nextMoveAt = now + 1
		return false
	end
	zombie.nextMoveAt = now + 0.25 -- not now: look again shortly
	local root = zombie.root
	local member, distance = Squad.nearestLiving(root.Position)
	if not member or not canBeTaken(member) then
		return false
	end
	local targetRoot = member.root :: BasePart
	if
		not InfectedMoves.inBand(distance, settings.MinRange, settings.MaxRange)
		or math.abs(targetRoot.Position.Y - root.Position.Y) > 6
		or not lineClear(zombie, root.Position, targetRoot)
	then
		return false
	end
	local here = root.Position
	local direction = flatDirection(targetRoot.Position - here, root.CFrame.LookVector)
	zombie.humanoid:MoveTo(here)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	zombie.move = {
		kind = if kind == "charge" then "chargeWindup" else "pounceWindup",
		startedAt = now,
		untilAt = now + settings.Windup,
		target = member,
		yaw = CFrame.lookAt(here, here + direction),
		from = here,
		to = here,
		direction = direction,
		hit = {},
		nextTickAt = 0,
		nextVoiceAt = 0,
	}
	moveTrackSpeed(zombie, 0)
	-- The tell's sound: the Brute bellows, the Runner shrieks.
	voice(zombie, if kind == "charge" then "idle" else "attack")
	zombie.nextIdleVoiceAt = math.max(zombie.nextIdleVoiceAt, now + 3)
	return true
end

-- Thrown off the side of the charge's line it stands on (the squad scatters).
local function scatter(member: Squad.Member, direction: Vector3, offset: Vector3, settings: any)
	local targetRoot = member.root
	if not targetRoot then
		return
	end
	local right = Vector3.new(direction.Z, 0, -direction.X)
	local x, z =
		InfectedMoves.scatter(direction.X, direction.Z, offset:Dot(right), settings.ThrowAlong)
	local velocity = Vector3.new(x, 0, z) * settings.Throw
		+ Vector3.new(0, settings.Throw * 0.25, 0)
	if member.owner then
		Remotes.get("Impact"):FireClient(member.owner, Messages.Impact.Push, velocity)
	else
		targetRoot.AssemblyLinearVelocity = velocity
	end
end

-- The feet's height under a root.
local function feetY(zombie: Zombie): number
	return zombie.root.Position.Y - zombie.humanoid.HipHeight - zombie.root.Size.Y / 2
end

local function stepCharge(zombie: Zombie, move: Move, settings: any, now: number)
	local root = zombie.root
	local length = (move.to - move.from).Magnitude
	local travelled = math.min((now - move.startedAt) * settings.Speed, length)
	local nextPosition = move.from + move.direction * travelled
	-- Hard cover ahead (at the chest and at the knee) stops him dead: stunned, open to a flank.
	moveParams.FilterDescendantsInstances = { zombie.model }
	local probe = move.direction * ((nextPosition - root.Position).Magnitude + settings.Probe)
	local knee = Vector3.new(root.Position.X, feetY(zombie) + 1.5, root.Position.Z)
	for _, from in { root.Position, knee } do
		local hit = workspace:Raycast(from, probe, moveParams)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) then
				voice(zombie, "hurt")
				endMove(zombie, now, settings.WallStun)
				return
			end
		end
	end
	root.CFrame = CFrame.new(nextPosition) * move.yaw.Rotation
	-- Everyone inside the width is hit once: knocked down and thrown aside.
	local vehicleDamage = EnemyDefinitions[zombie.typeName].VehicleDamage
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot or move.hit[humanoid] then
			continue
		end
		local offset = targetRoot.Position - nextPosition
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude <= settings.Width and math.abs(offset.Y) <= settings.HitHeight then
			move.hit[humanoid] = true
			EnemyProjectileService.damagePlayer(humanoid, settings.Damage, nil, vehicleDamage)
			scatter(member, move.direction, flat, settings)
			Squad.knock(member, settings.Knockdown)
		end
	end
	if travelled >= length then
		endMove(zombie, now, settings.Recovery)
	end
end

local function startPin(zombie: Zombie, move: Move, settings: any, now: number)
	move.kind = "pin"
	move.startedAt = now
	move.untilAt = now + settings.PinSeconds
	move.nextTickAt = now + settings.PinTick
	move.nextVoiceAt = now + 1.2
	zombie.model:SetAttribute(Attributes.Pinning, true)
	local character = move.target.character
	if character then
		character:SetAttribute(Attributes.Pinned, true)
	end
	if zombie.attackTrack then
		zombie.attackTrack:Play(0.05)
	end
	local lines = MOVES.Radio
	if now - lastPinRadioAt >= lines.PinGap then
		lastPinRadioAt = now
		radio((string.gsub(lines.Pinned, "{name}", move.target.name)))
	end
end

local function stepPounce(zombie: Zombie, move: Move, settings: any, now: number)
	local t = math.clamp((now - move.startedAt) / settings.Flight, 0, 1)
	local from, to = move.from, move.to
	local x, y, z = InfectedMoves.arc(from.X, from.Y, from.Z, to.X, to.Y, to.Z, settings.Arc, t)
	zombie.root.CFrame = CFrame.new(x, y, z) * move.yaw.Rotation
	if t < 1 then
		return
	end
	-- Landed: on the soldier still standing there (not mid-roll), or on nothing.
	local target = move.target
	local targetRoot, humanoid, character = target.root, target.humanoid, target.character
	if targetRoot and humanoid and character and canBeTaken(target) then
		local offset = targetRoot.Position - to
		local coverUntil = character:GetAttribute(Attributes.CoverMoveUntil) :: number?
		local rolling = coverUntil ~= nil and os.clock() < coverUntil
		if
			not rolling
			and Vector3.new(offset.X, 0, offset.Z).Magnitude <= settings.LandRadius
			and math.abs(offset.Y) <= 5
		then
			EnemyProjectileService.damagePlayer(
				humanoid,
				settings.Damage,
				nil,
				EnemyDefinitions[zombie.typeName].VehicleDamage
			)
			if Squad.isAlive(target) and Squad.knock(target, settings.PinSeconds) then
				startPin(zombie, move, settings, now)
				return
			end
		end
	end
	endMove(zombie, now, settings.Miss)
end

local function stepPin(zombie: Zombie, move: Move, settings: any, now: number)
	local target = move.target
	local targetRoot, humanoid, character = target.root, target.humanoid, target.character
	if
		not targetRoot
		or not humanoid
		or not character
		or not Squad.isAlive(target)
		or character:GetAttribute(Attributes.KnockedUntil) == nil
		or now >= move.untilAt
	then
		endMove(zombie, now, settings.ThrownOff)
		return
	end
	-- On top of the body, clawing.
	zombie.root.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, settings.Lift, 0))
		* move.yaw.Rotation
	if now >= move.nextTickAt then
		move.nextTickAt = now + settings.PinTick
		EnemyProjectileService.damagePlayer(humanoid, settings.PinDamage)
		if zombie.attackTrack then
			zombie.attackTrack:Play(0.05)
		end
	end
	if now >= move.nextVoiceAt then
		move.nextVoiceAt = now + 1.5
		voice(zombie, "attack")
	end
end

-- One frame of the body's big move.
local function stepMove(zombie: Zombie, move: Move, now: number)
	local _, settings = bigMove(zombie.typeName)
	if not settings then
		endMove(zombie, now, 0) -- the moves were turned off mid-move
		return
	end
	local root = zombie.root
	if move.kind == "chargeWindup" or move.kind == "pounceWindup" then
		local targetRoot = move.target.root
		if not targetRoot or not Squad.isAlive(move.target) then
			endMove(zombie, now, 0)
			return
		end
		-- The tell's pose: he rears back / it drops into a crouch, turning to follow.
		move.direction = flatDirection(targetRoot.Position - move.from, move.direction)
		move.yaw = CFrame.lookAt(move.from, move.from + move.direction)
		local progress = math.clamp((now - move.startedAt) / settings.Windup, 0, 1)
		local tilt = if move.kind == "chargeWindup"
			then settings.RearTilt * progress
			else -settings.CrouchTilt * progress
		root.CFrame = move.yaw * CFrame.Angles(math.rad(tilt), 0, 0)
		if now < move.untilAt then
			return
		end
		root.CFrame = move.yaw
		move.startedAt = now
		if move.kind == "chargeWindup" then
			local offset = targetRoot.Position - move.from
			local length = InfectedMoves.chargeLength(
				Vector3.new(offset.X, 0, offset.Z).Magnitude,
				settings.Overrun,
				settings.Distance
			)
			move.kind = "charge"
			move.to = move.from + move.direction * length
			move.untilAt = now + length / settings.Speed
			moveTrackSpeed(zombie, settings.Speed)
			voice(zombie, "attack")
			radioOnce("FirstCharge")
		else
			-- At where they stand now: moving or rolling as it leaves beats it.
			move.kind = "pounce"
			setSolid(zombie, false)
			move.to = targetRoot.Position
			move.yaw = CFrame.lookAt(move.from, move.from + move.direction)
			move.untilAt = now + settings.Flight
			if zombie.attackTrack then
				zombie.attackTrack:Play(0.05)
			end
		end
		return
	end
	if move.kind == "charge" then
		stepCharge(zombie, move, settings, now)
	elseif move.kind == "pounce" then
		stepPounce(zombie, move, settings, now)
	elseif move.kind == "pin" then
		stepPin(zombie, move, settings, now)
	end
end

-- A Walker's claw landed on `character`: with a crowd round them it holds them, slower for
-- a moment (Attributes.Grabbed; SprintController and BotService read it).
local function grab(zombie: Zombie, character: Model, at: Vector3)
	local row = movesRow(zombie.typeName)
	local settings = row and row.Grab
	if not settings or not settings.Enabled then
		return
	end
	local crowd = 0
	for _, other in zombies do
		if
			other.humanoid.Health > 0
			and other.behaviour.Attack == "melee"
			and (other.root.Position - at).Magnitude <= settings.Radius
		then
			crowd += 1
		end
	end
	local factor = InfectedMoves.grabFactor(crowd, {
		crowd = settings.Crowd,
		slow = settings.Slow,
		slowPerExtra = settings.SlowPerExtra,
		minFactor = settings.MinFactor,
	})
	if factor >= 1 then
		return
	end
	local token = (grabTokens[character] or 0) + 1
	grabTokens[character] = token
	character:SetAttribute(Attributes.Grabbed, factor)
	task.delay(settings.Seconds, function()
		if grabTokens[character] == token and character.Parent then
			character:SetAttribute(Attributes.Grabbed, nil)
		end
	end)
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
	-- Tumble: a small random spin so the body rolls over instead of sliding as one piece.
	local chest = model:FindFirstChild("UpperTorso") :: BasePart?
	if chest then
		chest.AssemblyAngularVelocity =
			Vector3.new(math.random() * 6 - 3, math.random() * 6 - 3, math.random() * 6 - 3)
	end
	-- Settle: parts that have stopped are anchored and stop colliding (no more physics, no
	-- bumping the squad); one still falling keeps falling until the body is removed.
	task.delay(cfg.Settle, function()
		for _, part in parts do
			if part.Parent and part.AssemblyLinearVelocity.Magnitude < cfg.SettleSpeed then
				part.Anchored = true
				part.CanCollide = false
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
	-- A boss never flinches from rounds (Config.Index.Warden.Weight.NoFlinch, the boss
	-- pass): only his plates coming off stagger him (IndexService).
	local definition = EnemyDefinitions[zombie.typeName]
	if definition and definition.Boss and Config.Index.Warden.Weight.NoFlinch then
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

local setAware: (zombie: Zombie, state: Awareness.State, now: number, spot: Vector3?) -> ()

-- A killing round: the body goes over away from whoever fired it. Any other hit: a flinch
-- (and on an awareness mission it knows now: Chase).
local function onHit(info: DamageService.HitInfo)
	if not info.killed then
		local zombie = zombieOfHumanoid(info.humanoid)
		if zombie and zombie.aware and zombie.aware.state ~= "Chase" then
			setAware(zombie, "Chase", os.clock())
		end
		-- A pinning Runner hit by a squadmate lets go (Config.InfectedMoves.Runner.Pounce).
		local move = zombie and zombie.move
		if zombie and move and move.kind == "pin" then
			local _, settings = bigMove(zombie.typeName)
			endMove(zombie, os.clock(), if settings then settings.ThrownOff else 0)
		end
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
	-- Killed mid-move: a pin lets go, the root falls free.
	endMove(zombie, os.clock(), 0)
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
	-- Rounds pass through the dead (a hitscan stops at the first body it meets).
	for _, item in zombie.model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanQuery = false
		end
	end
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
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- No floating health bars (owner 2026-11-11); Config.SquadPanel.OverheadBars restores it.
	if Config.SquadPanel.OverheadBars and not definition.Boss then
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
			-- The torso part is centred on its mesh bounds, which a hump or a soaked front
			-- moves off the limb centre: take that shift out so the sac stays on the throat.
			local bodySet = definition.BodySet or typeName
			local sacOffset = if dressedTemplates[bodySet]
				then SAC_OFFSET
					- MeshAssets.infectedLimbOffset(bodySet, "upper_torso") * definition.Scale
				else SAC_OFFSET -- the bare rig: the part is the limb
			ball.CFrame = torso.CFrame * sacOffset
			local weld = Instance.new("Weld")
			weld.Part0 = torso
			weld.Part1 = ball
			weld.C0 = sacOffset
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
	local moveReference = definition.WalkSpeed
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
		local clips = Config.Animations.Infected[typeName]
		local moveTrack = clips
			and Animations.load(animator, clips.move, Enum.AnimationPriority.Core)
		if moveTrack then
			local reference = Config.Animations.MoveClipSpeed[clips.move] or definition.WalkSpeed
			moveReference = reference
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
		move = nil,
		nextMoveAt = os.clock() + firstMoveDelay(typeName),
		pathing = false,
		path = nil,
		pathPending = false,
		pathRequestedAt = 0,
		moveReference = moveReference,
		-- On an awareness mission a body spawned by anything but the start's population (an
		-- objective's wave, a pallet's ring) comes knowing: in Chase.
		aware = if awareOn and not definition.Boss
			then {
				state = "Chase",
				post = groundPosition,
				spot = nil,
				goal = nil,
				untilAt = 0,
				searching = false,
				notice = 0,
				nextLookAt = os.clock() + math.random() * AW.SightInterval,
				lastSeenAt = os.clock(),
				lastSeen = nil,
			}
			else nil,
	}
	-- Only awareness missions look; the list is emptied with every run (clearAll).
	if awareOn then
		lookParams:AddToFilter(model)
	end
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
	EnemySpacing.add(root, humanoid, typeName)

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
			EnemyProjectileService.damagePlayer(
				targetHumanoid,
				zombie.damage,
				"melee",
				EnemyDefinitions[zombie.typeName].VehicleDamage
			)
			zombie.lastAttackTime = now
			zombie.nextIdleVoiceAt = math.max(zombie.nextIdleVoiceAt, now + 2)
			voice(zombie, "attack")
			if zombie.attackTrack then
				zombie.attackTrack:Play(0.1)
			end
			-- In a crowd the claw holds (the Walker's grab); a rolling body slipped it.
			local coverUntil = character:GetAttribute(Attributes.CoverMoveUntil) :: number?
			if targetHumanoid.Health > 0 and not (coverUntil and os.clock() < coverUntil) then
				grab(zombie, character, targetRoot.Position)
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

-- Open sky `height` studs over the spitter and over the target: room for a high lob.
local function skyOpen(zombie: Zombie, targetRoot: BasePart, height: number): boolean
	local up = Vector3.new(0, height, 0)
	moveParams.FilterDescendantsInstances = { zombie.model, targetRoot.Parent :: Instance }
	return workspace:Raycast(zombie.root.Position, up, moveParams) == nil
		and workspace:Raycast(targetRoot.Position, up, moveParams) == nil
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
			-- The barrage (Config.InfectedMoves.Hocker): one glob on the mark, the rest either
			-- side across the line; over cover, a high lob.
			local row = movesRow(zombie.typeName)
			local barrage = row and row.Barrage
			local count = if barrage and barrage.Enabled then barrage.Globs else 1
			local flight = if zombie.lob and row and row.Lob then row.Lob.Flight else nil
			if flight then
				radioOnce("FirstLob")
			end
			local line = flatDirection(targetRoot.Position - origin, zombie.root.CFrame.LookVector)
			local spots =
				InfectedMoves.barrage(count, if barrage then barrage.Spread else 0, line.X, line.Z)
			for index, spot in spots do
				EnemyProjectileService.fire(
					origin,
					targetRoot.Position + Vector3.new(spot.x, 0, spot.z),
					if index == 1 then targetRoot.AssemblyLinearVelocity else nil,
					spec,
					zombie.damage,
					EnemyDefinitions[zombie.typeName].VehicleDamage,
					flight
				)
			end
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
	-- No clear line but open sky over both ends: it lobs high over the cover instead.
	local row = movesRow(zombie.typeName)
	local lob = row and row.Lob
	zombie.lob = false
	if
		not zombie.throwClear
		and lob
		and lob.Enabled
		and distance <= zombie.attackRange
		and skyOpen(zombie, targetRoot, lob.SkyCheck)
	then
		zombie.throwClear = true
		zombie.lob = true
	end
	local backOff = if row and row.BackOffShare then row.BackOffShare else 0.5
	if not zombie.throwClear then
		zombie.humanoid:MoveTo(targetRoot.Position)
	elseif distance < standOff * backOff then
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
			EnemyProjectileService.windup(zombie.model, behaviour.Windup or 0)
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

local groundPositionNear: (center: Vector3, minDistance: number, maxDistance: number) -> Vector3

-- A body's walking pace: `factor` of its form's speed, the move clip matched (stopped at 0).
local function setPace(zombie: Zombie, factor: number)
	local base = zombie.walkSpeed * factor
	zombie.humanoid:SetAttribute(Attributes.BaseWalkSpeed, base)
	if not slowGeneration[zombie.humanoid] and not PauseService.isPaused() then
		zombie.humanoid.WalkSpeed = base
	end
	local track = zombie.moveTrack
	if track then
		if factor <= 0 then
			track:AdjustSpeed(0)
		else
			track:AdjustSpeed(base / zombie.moveReference)
		end
	end
end

-- Moves a body into `state` (Rules/Awareness), with its pace, its timers and, for a Chase,
-- the scream that sets the bodies round it looking.
setAware = function(zombie: Zombie, state: Awareness.State, now: number, spot: Vector3?)
	local aware = zombie.aware
	if not aware then
		return
	end
	local was = aware.state
	aware.state = state
	aware.goal = nil
	aware.searching = false
	setPace(zombie, (AW.Pace :: { [string]: number })[state] or 1)
	if state == "Chase" then
		aware.notice = 1
		aware.lastSeenAt = now
		zombie.nextRepathTime = 0
		if was ~= "Chase" then
			voice(zombie, "attack")
			local here = zombie.root.Position
			for _, other in zombies do
				local otherAware = other.aware
				if
					other ~= zombie
					and otherAware
					and (otherAware.state == "Sleeping" or otherAware.state == "Idle" or otherAware.state == "Wandering")
					and (other.root.Position - here).Magnitude <= AW.Scream
				then
					setAware(other, "Alerted", now, here)
				end
			end
		end
	elseif state == "Alerted" then
		aware.spot = spot or aware.spot or zombie.root.Position
		aware.untilAt = now + AW.SearchSeconds
	elseif state == "Wandering" then
		aware.untilAt = now + math.random(AW.WanderPause[1], AW.WanderPause[2])
	else
		zombie.humanoid:MoveTo(zombie.root.Position)
	end
end

-- The soldier a body can see now and how well (Rules/Awareness), or nil. `chasing` looks all
-- round (it knows they are there) at its Chase range.
local function lookFor(zombie: Zombie, state: Awareness.State, chasing: boolean): (Vector3?, number)
	local head = zombie.voicePart
	local from = head.Position
	local facing = zombie.root.CFrame.LookVector
	local bestSpot: Vector3? = nil
	local bestRate = 0
	for _, member in Squad.living() do
		local root = member.root
		local body = member.character
		if not root or not body then
			continue
		end
		local offset = root.Position - from
		local distance = offset.Magnitude
		if not chasing and Awareness.touched(AW, distance) then
			return root.Position, math.huge
		end
		local drop = body:GetAttribute(Attributes.RootDrop)
		local stance = if typeof(drop) == "number" and drop > 0
			then "prone"
			elseif body:GetAttribute(Attributes.Crouching) == true then "crouch"
			else "stand"
		local range = Awareness.sightRange(AW, state, stance, awareNight)
		if
			not chasing
			and not Awareness.inCone(AW, facing.X, facing.Z, offset.X, offset.Z, distance, range)
		then
			continue
		end
		if chasing and distance > range then
			continue
		end
		local hit = workspace:Raycast(from, offset, lookParams)
		if hit and not hit.Instance:IsDescendantOf(body) then
			continue -- something in the way
		end
		local rate = Awareness.noticeRate(AW, distance, range)
		if rate > bestRate then
			bestRate = rate
			bestSpot = root.Position
		end
	end
	return bestSpot, bestRate
end

-- One body not in Chase (or a Chase checking it still has someone): look, then do the state.
-- True when the body is in Chase after it (the straight chase runs).
local function stepAware(zombie: Zombie, aware: Aware, now: number): boolean
	if now >= aware.nextLookAt then
		aware.nextLookAt = now + AW.SightInterval
		if aware.state == "Chase" then
			local seen = lookFor(zombie, "Chase", true)
			if seen then
				aware.lastSeenAt = now
				aware.lastSeen = seen
			elseif now - aware.lastSeenAt >= AW.LoseSeconds then
				setAware(zombie, "Alerted", now, aware.lastSeen)
			end
		else
			local seen, rate = lookFor(zombie, aware.state, false)
			if seen then
				aware.notice += rate * AW.SightInterval
				if aware.notice >= 1 then
					setAware(zombie, "Chase", now)
					aware.lastSeen = seen
				elseif aware.state ~= "Sleeping" then
					if aware.state ~= "Alerted" then
						setAware(zombie, "Alerted", now, seen)
					else
						aware.spot = seen
						aware.searching = false
						aware.untilAt = now + AW.SearchSeconds
					end
				end
			else
				aware.notice = math.max(0, aware.notice - AW.SightInterval * 0.2)
			end
		end
	end
	if aware.state == "Chase" then
		return true
	end
	if now < zombie.nextRepathTime then
		return false
	end
	zombie.nextRepathTime = now + REPATH_INTERVAL
	local here = zombie.root.Position
	if aware.state == "Wandering" then
		local goal = aware.goal
		if goal and Vector3.new(goal.X - here.X, 0, goal.Z - here.Z).Magnitude > 3 then
			zombie.humanoid:MoveTo(goal)
		elseif goal then
			aware.goal = nil
			aware.untilAt = now + math.random(AW.WanderPause[1], AW.WanderPause[2])
			zombie.humanoid:MoveTo(here)
		elseif now >= aware.untilAt then
			aware.goal = groundPositionNear(aware.post, 4, AW.WanderRadius)
		end
	elseif aware.state == "Alerted" then
		local spot = aware.spot or here
		if not aware.searching then
			if Vector3.new(spot.X - here.X, 0, spot.Z - here.Z).Magnitude > 4 then
				zombie.humanoid:MoveTo(spot)
			else
				aware.searching = true
				aware.untilAt = now + AW.SearchSeconds
			end
		else
			local goal = aware.goal
			if not goal or Vector3.new(goal.X - here.X, 0, goal.Z - here.Z).Magnitude <= 3 then
				aware.goal = groundPositionNear(spot, 2, AW.SearchRadius)
			end
			zombie.humanoid:MoveTo(aware.goal or spot)
			if now >= aware.untilAt then
				aware.post = spot
				setAware(zombie, "Wandering", now)
			end
		end
	end
	return false
end

-- Soldiers running: footsteps the Infected hear (Config.Awareness.Footsteps).
local function stepFootsteps(now: number)
	if now < nextFootstepsAt then
		return
	end
	local steps = AW.Footsteps
	nextFootstepsAt = now + steps.Every
	for _, member in Squad.living() do
		local root = member.root
		if root then
			local velocity = root.AssemblyLinearVelocity
			if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > steps.Speed then
				EnemyService.noise(root.Position, steps.Reach)
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
			local base = zombie.humanoid:GetAttribute(Attributes.BaseWalkSpeed)
			zombie.humanoid.WalkSpeed = if paused
				then 0
				else (if typeof(base) == "number" then base else zombie.walkSpeed)
		end
	end
	if paused then
		return
	end

	local now = os.clock()
	if awareOn then
		stepFootsteps(now)
	end
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

		local aware = zombie.aware
		if aware and not stepAware(zombie, aware, now) then
			continue -- asleep, standing, wandering or looking: no chase this frame
		end

		if zombie.behaviour.Attack == "projectile" then
			stepProjectileZombie(zombie, now)
			continue
		end
		if zombie.behaviour.Attack == "boss" then
			continue -- IndexService steers the Index hosts
		end

		-- A big move owns the body while it runs (Config.InfectedMoves).
		local move = zombie.move
		if move then
			stepMove(zombie, move, now)
			continue
		end
		if now >= zombie.nextMoveAt and tryStartMove(zombie, now) then
			continue
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
					-- Spacing: a goal that keeps off the neighbours and on the attack ring;
					-- a body the crowd is holding is not stuck (no nudge, no climb).
					local spaced, waiting =
						EnemySpacing.goal(zombie.root, here, goal, zombie.attackRange, now)
					local stuck = not waiting
						and (here - zombie.lastRepathPosition).Magnitude < NUDGE_STUCK_DISTANCE
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
					else
						goal = spaced
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
groundPositionNear = function(center: Vector3, minDistance: number, maxDistance: number): Vector3
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
		-- Inside the perimeter (Config.Arena.SpawnInset, the big map's edge on Delta XL): no
		-- spawn in the fence band or past it.
		local inset = ArenaService.spawnInset()
		local x = math.clamp(center.X + math.cos(angle) * distance, -inset, inset)
		local z = math.clamp(center.Z + math.sin(angle) * distance, -inset, inset)
		local result =
			workspace:Raycast(Vector3.new(x, center.Y + 50, z), Vector3.new(0, -200, 0), params)
		local groundY = if result then result.Position.Y else 0
		candidate = Vector3.new(x, groundY, z)
		if
			isOpenGround(result)
			-- never in the big map's river channel (no map has ground this low elsewhere)
			and groundY >= Config.DeltaXL.LowGround
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
		moveTrack = zombie.moveTrack,
		moveReference = zombie.moveReference,
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

-- An objective's own body (Confirm Casualties, Clear the Spitters): one `typeName` at
-- `groundPosition`, handed back so the objective can outline it and count its death.
function EnemyService.spawnAt(typeName: string, groundPosition: Vector3): (Model?, Humanoid?)
	local zombie = spawnZombie(groundPosition, typeName)
	if not zombie then
		return nil, nil
	end
	return zombie.model, zombie.humanoid
end

-- A spot in a ring round `center` on open ground (an objective placing its own bodies).
function EnemyService.groundNear(center: Vector3, minDistance: number, maxDistance: number): Vector3
	return groundPositionNear(center, minDistance, maxDistance)
end

-- BreachService: one phase-weighted Infected (the run's mix and caps) at `groundPosition`.
function EnemyService.spawnPicked(groundPosition: Vector3): Model?
	local zombie = spawnZombie(groundPosition, pickSpawnType())
	return zombie and zombie.model
end

-- Noise listeners (BreachService): (position, reach, kind, heard) for every tagged noise, on
-- every mission; `heard` = living Infected within `reach`.
local noiseListeners: { (Vector3, number, string, number) -> () } = {}
function EnemyService.addNoiseListener(listener: (Vector3, number, string, number) -> ())
	table.insert(noiseListeners, listener)
end

-- A noise at `position` that carries `reach` studs (a shot: the gun's Noise; a blast; running
-- feet): on an awareness mission each body that hears it comes for it (inside half the
-- reach) or goes to look (Rules/Awareness.hear). `kind` ("shot", "blast") also tells the
-- breach director (addNoiseListener) on every mission; untagged noise (feet, an engine)
-- does not.
function EnemyService.noise(position: Vector3, reach: number, kind: string?)
	if kind and reach > 0 and #noiseListeners > 0 then
		local heard = 0
		for _, zombie in zombies do
			if
				zombie.humanoid.Health > 0
				and (zombie.root.Position - position).Magnitude <= reach
			then
				heard += 1
			end
		end
		for _, listener in noiseListeners do
			listener(position, reach, kind, heard)
		end
	end
	if not awareOn or reach <= 0 then
		return
	end
	local now = os.clock()
	for _, zombie in zombies do
		local aware = zombie.aware
		if aware and zombie.humanoid.Health > 0 then
			local distance = (zombie.root.Position - position).Magnitude
			local reaction = Awareness.hear(AW, aware.state, distance, reach)
			if reaction == "Chase" then
				setAware(zombie, "Chase", now)
				aware.lastSeen = position
			elseif reaction == "Alerted" then
				if aware.state == "Alerted" then
					aware.spot = position
					aware.searching = false
					aware.untilAt = now + AW.SearchSeconds
				else
					setAware(zombie, "Alerted", now, position)
				end
			end
		end
	end
end

-- Whether this mission plays the Infected's awareness (Config.Awareness.Missions).
function EnemyService.aware(): boolean
	return awareOn
end

-- Bumped on every reset so a pending first wave (or the start population) never lands in the
-- next run.
local missionGeneration = 0

-- The start of an awareness mission: the population placed round the map, asleep, standing
-- or wandering (Config.Awareness.Population), none near the LZ. Never more alive than
-- Config.PlayerCountScaling.MaxAliveHardCap (the waves still get the room the cap leaves), and a few
-- a frame (PerFrame), not all in one.
local function populate()
	local settings = AW.Population
	local lz = Config.Extraction.ZonePosition
	local total = 0
	for _, weight in settings.Types do
		total += weight
	end
	local generation = missionGeneration
	for index = 1, settings.Count do
		if #zombies >= Config.PlayerCountScaling.MaxAliveHardCap then
			break
		end
		if index % settings.PerFrame == 0 then
			task.wait()
			if generation ~= missionGeneration or not RunStates.isLive() then
				return
			end
		end
		local roll = math.random() * total
		local typeName = "Walker"
		for name, weight in settings.Types do
			roll -= weight
			if roll <= 0 then
				typeName = name
				break
			end
		end
		local position = groundPositionNear(Vector3.new(0, lz.Y, 0), 0, 300)
		if
			Vector3.new(position.X - lz.X, 0, position.Z - lz.Z).Magnitude < settings.MinDistance
		then
			continue
		end
		local zombie = spawnZombie(position, typeName)
		local aware = zombie and zombie.aware
		if zombie and aware then
			aware.post = position
			local kind = math.random()
			local state: Awareness.State = if kind < settings.Sleeping
				then "Sleeping"
				elseif kind < settings.Sleeping + settings.Wandering then "Wandering"
				else "Idle"
			zombie.root.CFrame = CFrame.new(zombie.root.Position)
				* CFrame.Angles(0, math.random() * math.pi * 2, 0)
			setAware(zombie, state, os.clock())
		end
	end
end

-- Silence the Alarm: a roaming spawn picked within `radius` of `position` happens only
-- `factor` of the time (0..1). nil clears it; a fresh run clears it too.
local quiet: { position: Vector3, radius: number, factor: number }? = nil
function EnemyService.setQuiet(position: Vector3?, radius: number?, factor: number?)
	if position then
		quiet = { position = position, radius = radius or 0, factor = factor or 1 }
	else
		quiet = nil
	end
end

local function quietSkips(position: Vector3): boolean
	local zone = quiet
	return zone ~= nil
		and (position - zone.position).Magnitude <= zone.radius
		and math.random() > zone.factor
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
				local now = (humanoid:GetAttribute(Attributes.BaseWalkSpeed) :: number?) or base
				humanoid.WalkSpeed = now
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
-- A pinning Runner staggered (a shove, Hollow Point) is knocked off the soldier first.
function EnemyService.stagger(humanoid: Humanoid, seconds: number)
	local zombie = zombieOfHumanoid(humanoid)
	local move = zombie and zombie.move
	if zombie and move and move.kind == "pin" then
		local _, settings = bigMove(zombie.typeName)
		endMove(zombie, os.clock(), 0)
		seconds = math.max(seconds, if settings then settings.ThrownOff else 0)
	end
	EnemyService.slow(humanoid, 0, seconds)
end

-- RequisitionService: fired on every death with the form's SupplyValue and where it fell.
function EnemyService.addKillListener(listener: (supplyValue: number, position: Vector3) -> ())
	table.insert(killListeners, listener)
end

-- BreachService: the roaming spawn interval's multiplier for the breach rhythm (1 = as before).
local trickleFactor = 1
function EnemyService.setTrickle(factor: number)
	trickleFactor = math.max(factor, 0.1)
end

-- The director's pick at `position`; a pack form (Config.InfectedMoves.<form>.Pack, the
-- Runner) brings its pack-mates beside it.
local function spawnDirected(position: Vector3, typeName: string)
	spawnZombie(position, typeName)
	local row = movesRow(typeName)
	local pack = row and row.Pack
	if pack and pack.Enabled then
		for _ = 1, math.random(pack.Extra[1], pack.Extra[2]) do
			spawnZombie(groundPositionNear(position, 1, pack.Spread), typeName)
		end
	end
end

local function spawnLoop()
	while true do
		local interval = DifficultyService.getSpawnInterval()
		-- The breach rhythm: fewer in the calm and the relief, most in the tension.
		interval *= trickleFactor
		-- Extra pressure while the objective is being held.
		if workspace:GetAttribute(Attributes.ObjectiveActive) == true then
			interval *= Config.Difficulty.ObjectiveSpawnFactor
		end
		-- And during extraction (harder again once a wave has hit the pad).
		if workspace:GetAttribute(Attributes.ExtractionActive) == true then
			interval *= (workspace:GetAttribute(Attributes.ExtractionSpawnFactor) :: number?) or Config.Extraction.SpawnFactor
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
			not awareOn
			and RunStates.isLive()
			and workspace:GetAttribute(Attributes.DevSpawnsOff) ~= true
			and not PauseService.isPaused()
			and #zombies < maxAlive
		then
			local position = randomSpawnPosition()
			if position and not quietSkips(position) then
				spawnDirected(position, pickSpawnType())
			end
		end
	end
end

-- RunManager, on Explore: first contact within seconds (Sprint 8 pacing).
function EnemyService.startMission()
	missionGeneration += 1
	local generation = missionGeneration
	task.delay(1.5, function()
		if generation == missionGeneration and RunStates.isLive() then
			if awareOn then
				populate()
			else
				EnemyService.spawnWave("Walker", Config.Spawning.InitialCount)
			end
		end
	end)
end

-- Destroys all enemies without scheduling a new wave (dev ClearEnemies).
function EnemyService.clearAll()
	for _, zombie in zombies do
		-- A pinned soldier is let go before the Runner on them goes.
		local move = zombie.move
		if move and move.kind == "pin" then
			local character = move.target.character
			if character then
				character:SetAttribute(Attributes.Pinned, nil)
			end
			Squad.standUp(move.target, Config.Knockdown.GetUp)
		end
		zombie.model:Destroy()
	end
	table.clear(zombies)
	-- The sight filter held every body this run spawned: start it empty again.
	lookParams.FilterDescendantsInstances = {}
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
	table.clear(toldThisRun)
	lastPinRadioAt = -math.huge
	table.clear(slowGeneration)
	quiet = nil
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
