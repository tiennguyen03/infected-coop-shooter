--!strict
-- Bot squadmates. In solo generic Pike soldiers fill the squad as server-side AI
-- (docs/PROGRESSION.md > The run): one fewer per real player, up to a squad of 4. Each
-- bot is a Squad member, so the Infected chase it and enemy splash hurts it exactly like a
-- player. It wears the class body and rifle (PlayerSetup), follows the nearest player in a
-- formation slot, faces and shoots the nearest Infected it can see through the one damage
-- entry point (DamageService.dealDamage with no attacker: no kill credit, no hit
-- marker), and rejoins at its slot RespawnSeconds after dying. Numbers in Config.Bots.
-- Downed (Squad): a downed bot lies prone and waits; a standing bot breaks formation to
-- revive the nearest downed squadmate when no Infected is close (Config.Bots.Revive*).
-- It carries the service rifle's magazine (reloads from an infinite reserve).
-- Movement: a bot always walks to its slot, in a straight line when the slot is close and
-- in sight, else along a PathfindingService path, sprinting when far. It teleports only as
-- a last resort (Rules/BotBrain.shouldTeleport: far and stalled, or out of the world), to a
-- spot no living player is facing.
-- Consumables: a soldier's stims and frags, and one fire mission each, through the
-- players' own server paths (KitService.dose / throwFrag, CallInService.fireMissionFor);
-- the when and where are Rules/BotBrain. Not yet: vaulting.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Animations = require(ReplicatedStorage.Shared.Animations)
local BotBrain = require(ReplicatedStorage.Shared.Rules.BotBrain)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local AvatarLook = require(ReplicatedStorage.Shared.AvatarLook)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local CallInService = require(script.Parent.CallInService)
local DamageService = require(script.Parent.DamageService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local KitService = require(script.Parent.KitService)
local PauseService = require(script.Parent.PauseService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local ProjectileServer = require(script.Parent.ProjectileServer)
local ReviveAnimService = require(script.Parent.ReviveAnimService)
local Squad = require(script.Parent.Squad)
local SupplyDropService = require(script.Parent.SupplyDropService)

local ENEMY_TAG = "Enemy"
local MAX_SQUAD = 4
local LOS_CHECKS = 3 -- nearest Infected tested for line of sight per decision

local BotService = {}

type PathInstance = typeof(game:GetService("PathfindingService"):CreatePath())

type Tracks = {
	idle: AnimationTrack?,
	walk: AnimationTrack?,
	run: AnimationTrack?,
	fire: AnimationTrack?,
	downed: AnimationTrack?,
	knockdown: AnimationTrack?,
	getup: AnimationTrack?,
}

type Bot = {
	slot: number,
	member: Squad.Member,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	muzzle: BasePart?,
	tracks: Tracks,
	nextThink: number,
	nextShot: number,
	respawnAt: number?,
	spawning: boolean,
	rounds: number, -- left in the magazine (WeaponDefinitions; the reserve is infinite)
	reloadUntil: number?, -- os.clock while reloading
	target: Humanoid?, -- the Infected it is shooting (a new one costs ReactionTime)
	reviving: Squad.Member?, -- the downed member this bot is reviving
	reviveProgress: number, -- seconds held next to them
	stuckMark: BotBrain.Point?, -- where the follow last made progress, and when (BotBrain.stall)
	stuckSince: number?,
	knocked: boolean?, -- on the ground (Squad.knock), clips started
	-- The path being walked (PathfindingService), its request and how many failed in a row.
	pathObject: PathInstance?,
	waypoints: { PathWaypoint }?,
	waypointIndex: number,
	pathPending: boolean,
	pathAt: number, -- os.clock of the last request
	pathGoal: Vector3?,
	pathFails: number,
	teleportedAt: number,
	-- Consumables, per run: what is left, and os.clock times of the last stim and the next
	-- scan, throw and fire mission.
	stims: number,
	grenades: number,
	stimAt: number,
	nextScanAt: number,
	grenadeAt: number,
	callInAt: number,
}

local bots: { Bot } = {}
local folder: Folder
local tracerRemote: RemoteEvent
local noticeRemote: RemoteEvent
local runGeneration = 0
local nextPathAt = 0 -- os.clock: one path request per Config.Bots.PathStagger across all bots
local squadCallInAt = 0 -- os.clock: no bot calls a fire mission before this (CallIn.SquadGap)

local function leaderRoot(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	-- Standing players lead; with every player downed, the downed bodies anchor the bots.
	local owners = Squad.livingOwners()
	if #owners == 0 then
		owners = Squad.activeOwners()
	end
	for _, player in owners do
		local member = Squad.fromPlayer(player)
		local root = member and member.root
		if root then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

local function flatLook(part: BasePart): Vector3
	local look = part.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude < 0.01 then Vector3.new(0, 0, -1) else flat.Unit
end

-- `offset` in the leader's flat frame (+Z is behind, +X to the right).
local function behindLeader(leader: BasePart, offset: Vector3): Vector3
	return CFrame.lookAlong(leader.Position, flatLook(leader)):PointToWorldSpace(offset)
end

local function slotPosition(bot: Bot, leader: BasePart): Vector3
	local slots = Config.Bots.Slots
	return behindLeader(leader, slots[((bot.slot - 1) % #slots) + 1])
end

local function stopTracks(bot: Bot)
	for _, track in bot.tracks :: { [string]: AnimationTrack } do
		track:Stop(0.1)
	end
end

local function despawn(bot: Bot)
	local model = bot.model
	bot.model, bot.humanoid, bot.root, bot.muzzle = nil, nil, nil, nil
	bot.tracks = {}
	Squad.bindCharacter(bot.member, nil)
	if model then
		model:Destroy()
	end
end

local function loadTracks(bot: Bot, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local found = animator :: Animator
	local clips = Config.Animations.Assault
	bot.tracks = {
		idle = Animations.load(found, clips.idle, Enum.AnimationPriority.Core),
		walk = Animations.load(found, clips.walk.forward, Enum.AnimationPriority.Movement),
		run = Animations.load(found, clips.run.forward, Enum.AnimationPriority.Movement),
		fire = Animations.load(found, clips.fire, Enum.AnimationPriority.Action2),
		downed = Animations.load(found, clips.downed, Enum.AnimationPriority.Action3),
		knockdown = Animations.load(found, clips.knockdown, Enum.AnimationPriority.Action3),
		getup = Animations.load(found, clips.getup, Enum.AnimationPriority.Action3),
	}
	for _, track in { bot.tracks.idle, bot.tracks.walk, bot.tracks.run, bot.tracks.downed } do
		if track then
			track.Looped = true
		end
	end
	if bot.tracks.idle then
		bot.tracks.idle:Play(0.2)
	end
end

-- Drops the revive this bot was holding (the squad panel's revive bar follows the Reviver).
local function stopReviving(bot: Bot)
	if bot.reviveProgress > 0 and bot.reviving then
		Squad.clearReviver(bot.reviving, bot.member)
	end
	bot.reviveProgress = 0
end

local function spawnBot(bot: Bot, position: Vector3)
	if bot.spawning then
		return
	end
	bot.spawning = true
	local generation = runGeneration
	-- A bot wears the soldier's look (Config.Player.Look) when it is on.
	local ok, built = pcall(function()
		if Config.Player.Look.Enabled then
			return AvatarLook.rig(PlayerSetup.look())
		end
		return Players:CreateHumanoidModelFromDescription(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
	end)
	bot.spawning = false
	if not ok or typeof(built) ~= "Instance" then
		warn("[BotService] could not build a bot rig:", built)
		return
	end
	local rig = built :: Model
	if generation ~= runGeneration or not table.find(bots, bot) then
		rig:Destroy()
		return
	end
	rig.Name = bot.member.name
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local animateScript = rig:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy() -- a LocalScript: never runs on a server rig; we drive the clips
	end
	humanoid.DisplayName = bot.member.name
	PlayerSetup.hideOverhead(humanoid)
	humanoid.MaxHealth = Config.Bots.MaxHealth
	humanoid.Health = Config.Bots.MaxHealth
	humanoid.WalkSpeed = Config.Bots.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	if not Config.Player.Look.Enabled and MeshAssets.waitFor(PlayerSetup.BODY .. "head", 5) then
		MeshAssets.dressModel(rig, PlayerSetup.BODY)
	end
	rig:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a rig never half-streams
	rig.Parent = folder
	CollectionService:AddTag(rig, "SquadBot")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	PlayerSetup.attachRifle(rig, humanoid)
	local rifle = rig:FindFirstChild("Rifle")
	local muzzle = rifle and rifle:FindFirstChild("Muzzle")
	bot.muzzle = if muzzle and muzzle:IsA("BasePart") then muzzle else nil
	bot.model, bot.humanoid, bot.root = rig, humanoid, root
	bot.respawnAt = nil
	bot.nextShot = os.clock() + 0.5
	bot.rounds = WeaponDefinitions.get(WeaponDefinitions.DEFAULT).MagazineSize
	bot.reloadUntil = nil
	bot.waypoints, bot.pathFails = nil, 0
	bot.stuckMark, bot.stuckSince = nil, nil
	Squad.bindCharacter(bot.member, rig)
	loadTracks(bot, humanoid)

	humanoid.Died:Connect(function()
		if bot.model ~= rig then
			return
		end
		stopTracks(bot)
		stopReviving(bot)
		bot.respawnAt = os.clock() + Config.Bots.RespawnSeconds
		Squad.setRespawnIn(bot.member, Config.Bots.RespawnSeconds)
		task.delay(4, function()
			if bot.model == rig then
				despawn(bot)
			end
		end)
	end)
end

type Candidate = { humanoid: Humanoid, model: Model, torso: BasePart, distance: number }

-- The nearest Infected within range that the bot can see, and the point to aim at.
local function pickTarget(eye: Vector3, params: RaycastParams): (Humanoid?, Vector3?)
	local candidates: { Candidate } = {}
	local range = Config.Bots.Range
	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		if not tagged:IsA("Model") then
			continue
		end
		local humanoid = tagged:FindFirstChildOfClass("Humanoid")
		local torso = tagged:FindFirstChild("UpperTorso")
			or tagged:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and torso and torso:IsA("BasePart") then
			local distance = (torso.Position - eye).Magnitude
			if distance <= range then
				table.insert(candidates, {
					humanoid = humanoid,
					model = tagged,
					torso = torso,
					distance = distance,
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(LOS_CHECKS, #candidates) do
		local candidate = candidates[index]
		local hit = workspace:Raycast(eye, candidate.torso.Position - eye, params)
		if hit and hit.Instance:IsDescendantOf(candidate.model) then
			local head = candidate.model:FindFirstChild("Head")
			local aimAtHead = head ~= nil
				and head:IsA("BasePart")
				and math.random() < Config.Bots.HeadshotChance
			local aim = if aimAtHead then (head :: BasePart).Position else candidate.torso.Position
			return candidate.humanoid, aim
		end
	end
	return nil, nil
end

local function applySpread(direction: Vector3, halfAngleDegrees: number): Vector3
	local angle = math.rad(halfAngleDegrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	local frame = CFrame.lookAt(Vector3.zero, direction)
	local offset = Vector3.new(
		math.cos(roll) * math.sin(angle),
		math.sin(roll) * math.sin(angle),
		-math.cos(angle)
	)
	return frame:VectorToWorldSpace(offset).Unit
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, name in
		{
			"Projectiles",
			"Tracers",
			"InfectedProjectiles",
			"Resupply",
			"ResupplyCards",
			"Drones",
			"Mines",
			"FirePools",
			"KitEffects",
			"CallInEffects",
			"StrikeEffects",
		}
	do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(exclude, found)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function enemyFromPart(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not CollectionService:HasTag(model, ENEMY_TAG) do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function shoot(bot: Bot, origin: Vector3, aim: Vector3, params: RaycastParams)
	local direction = applySpread((aim - origin).Unit, Config.Bots.Spread)
	local range = WeaponDefinitions.get(WeaponDefinitions.DEFAULT).Range
	local hit = workspace:Raycast(origin, direction * range, params)
	local endPoint = if hit then hit.Position else origin + direction * range
	if hit then
		local humanoid = enemyFromPart(hit.Instance)
		if humanoid and humanoid.Health > 0 then
			local weapon = WeaponDefinitions.get(WeaponDefinitions.DEFAULT)
			local multiplier, kind =
				ProjectileServer.hitMultiplier(hit.Instance, humanoid, weapon.HeadshotMultiplier)
			DamageService.dealDamage(
				nil,
				humanoid,
				Config.Bots.Damage * multiplier,
				hit.Position,
				kind,
				hit.Instance
			)
		end
	end
	tracerRemote:FireAllClients(origin, endPoint)
	local fire = bot.tracks.fire
	if fire then
		fire:Play(0.05)
	end
end

local function setTrack(track: AnimationTrack?, on: boolean, speed: number, clip: string?)
	if not track then
		return
	end
	if on and not track.IsPlaying then
		track:Play(0.2)
	elseif not on and track.IsPlaying then
		track:Stop(0.2)
	end
	if on and clip then
		local clipSpeed = (Config.Animations.MoveClipSpeed :: { [string]: number })[clip]
		if clipSpeed then
			track:AdjustSpeed(math.clamp(speed / clipSpeed, 0.6, 1.8))
		end
	end
end

local function animate(bot: Bot, speed: number)
	local tracks = bot.tracks
	local moving = speed > 1
	local running = speed > Config.Bots.WalkSpeed + 2
	local clips = Config.Animations.Assault
	setTrack(tracks.idle, not moving, speed, nil)
	setTrack(tracks.walk, moving and not running, speed, clips.walk.forward)
	setTrack(tracks.run, running, speed, clips.run.forward)
end

local function tryRespawn(bot: Bot, now: number)
	local respawnAt = bot.respawnAt
	if bot.model or not respawnAt or now < respawnAt or not RunStates.isLive() then
		return
	end
	local leader = leaderRoot(Vector3.zero)
	if leader then
		bot.respawnAt = nil
		task.spawn(spawnBot, bot, slotPosition(bot, leader))
	end
end

-- The boss on the field (an Infected whose EnemyDefinitions row is a Boss), looked for
-- again every Config.Bots.Boss.ScanInterval; nil when there is none alive.
local bossRoot: BasePart? = nil
local nextBossScanAt = 0
local function liveBoss(): BasePart?
	local now = os.clock()
	if now >= nextBossScanAt then
		nextBossScanAt = now + Config.Bots.Boss.ScanInterval
		bossRoot = nil
		for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
			local typeName = tagged:GetAttribute(Attributes.EnemyType)
			local definition = if typeof(typeName) == "string"
				then (EnemyDefinitions :: { [string]: any })[typeName]
				else nil
			local humanoid = tagged:FindFirstChildOfClass("Humanoid")
			local root = tagged:FindFirstChild("HumanoidRootPart")
			if
				definition
				and definition.Boss
				and humanoid
				and humanoid.Health > 0
				and root
				and root:IsA("BasePart")
			then
				bossRoot = root
				break
			end
		end
	end
	local found = bossRoot
	return if found and found.Parent then found else nil
end

local function nearestInfectedDistance(position: Vector3): number
	local best = math.huge
	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		local enemyRoot = tagged:FindFirstChild("HumanoidRootPart")
		local humanoid = tagged:FindFirstChildOfClass("Humanoid")
		if enemyRoot and enemyRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			best = math.min(best, (enemyRoot.Position - position).Magnitude)
		end
	end
	return best
end

-- Downed: lie prone, stop, wait for a revive.
local function holdDowned(bot: Bot, humanoid: Humanoid, root: BasePart)
	humanoid.WalkSpeed = 0
	humanoid:MoveTo(root.Position)
	humanoid.AutoRotate = false
	stopReviving(bot)
	bot.reviving = nil
	local tracks = bot.tracks
	for _, track in { tracks.idle, tracks.walk, tracks.run } do
		if track and track.IsPlaying then
			track:Stop(0.2)
		end
	end
	if tracks.downed and not tracks.downed.IsPlaying then
		tracks.downed:Play(0.3)
		tracks.downed:AdjustSpeed(0) -- held on all fours: a downed bot waits for help
	end
end

-- Revive the nearest downed squadmate when it is safe enough. Returns true while busy.
local function tryRevive(bot: Bot, humanoid: Humanoid, root: BasePart, boss: BasePart?): boolean
	local settings = Config.Bots
	local target = bot.reviving
	if not target or target.state ~= "Downed" then
		stopReviving(bot)
		target = nil
		local best = settings.ReviveSearch
		for _, member in Squad.downed() do
			local downedRoot = member.root
			if member ~= bot.member and downedRoot then
				local distance = (downedRoot.Position - root.Position).Magnitude
				if distance < best then
					best, target = distance, member
				end
			end
		end
		bot.reviving = target
	end
	local downedRoot = target and target.root
	if not target or not downedRoot then
		return false
	end
	local safe = BotBrain.reviveSafe(
		nearestInfectedDistance(downedRoot.Position),
		if boss then (boss.Position - downedRoot.Position).Magnitude else nil,
		{
			ReviveSafeRadius = settings.ReviveSafeRadius,
			BossReviveClear = settings.Boss.ReviveClear,
		}
	)
	if not safe then
		stopReviving(bot)
		return false -- too hot (an Infected, or the boss on top of them): fight first
	end
	local distance = (downedRoot.Position - root.Position).Magnitude
	if distance > Config.Downed.ReviveRadius - 2 then
		humanoid.WalkSpeed = settings.RunSpeed
		humanoid:MoveTo(downedRoot.Position)
		stopReviving(bot)
		return true
	end
	humanoid:MoveTo(root.Position)
	if bot.reviveProgress == 0 then
		Squad.setReviver(target, bot.member, Config.Downed.ReviveHold)
	end
	ReviveAnimService.hold(bot.member, target) -- kneel and treat while the hold runs
	bot.reviveProgress += settings.ThinkInterval
	if bot.reviveProgress >= Config.Downed.ReviveHold then
		Squad.revive(target, bot.member)
		bot.reviving = nil
		bot.reviveProgress = 0
	end
	return true
end

-- The floor under a formation slot: the first surface below the leader's feet level plus a
-- little, ignoring bodies. Falls back to the slot itself.
local function floorAt(slot: Vector3, leader: BasePart, self: Model): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder, self }
	if leader.Parent then
		table.insert(exclude, leader.Parent)
	end
	params.FilterDescendantsInstances = exclude
	local origin = slot + Vector3.new(0, 2, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else slot
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function clearStall(bot: Bot)
	bot.stuckMark, bot.stuckSince = nil, nil
end

local function clearPath(bot: Bot)
	bot.waypoints = nil
	bot.waypointIndex = 1
end

-- Asks for a path to `goal` off the think loop; the waypoints land on the bot when it
-- returns. A path not found counts toward Config.Bots.PathFailLimit.
local function requestPath(bot: Bot, from: Vector3, goal: Vector3, now: number)
	local settings = Config.Bots
	bot.pathPending = true
	bot.pathAt = now
	bot.pathGoal = goal
	nextPathAt = now + settings.PathStagger
	local path = bot.pathObject
	if not path then
		path = PathfindingService:CreatePath({
			AgentRadius = settings.PathAgentRadius,
			AgentHeight = settings.PathAgentHeight,
			AgentCanJump = false, -- a bot does not jump or vault yet
			AgentCanClimb = false,
			WaypointSpacing = settings.PathWaypointSpacing,
		})
		bot.pathObject = path
	end
	local enginePath: PathInstance = path
	local model = bot.model
	task.spawn(function()
		local ok = pcall(enginePath.ComputeAsync, enginePath, from, goal)
		bot.pathPending = false
		if bot.model ~= model then
			return
		end
		if ok and enginePath.Status == Enum.PathStatus.Success then
			bot.waypoints = enginePath:GetWaypoints()
			bot.waypointIndex = 2
			bot.pathFails = 0
		else
			bot.waypoints = nil
			bot.pathFails += 1
		end
	end)
end

-- Walks toward the next waypoint; false when there is no path to walk.
local function followPath(bot: Bot, humanoid: Humanoid, here: Vector3): boolean
	local waypoints = bot.waypoints
	if not waypoints then
		return false
	end
	local reach = Config.Bots.PathWaypointReach
	while bot.waypointIndex <= #waypoints do
		if flatDistance(waypoints[bot.waypointIndex].Position, here) > reach then
			break
		end
		bot.waypointIndex += 1
	end
	local target = waypoints[bot.waypointIndex]
	if not target then
		bot.waypoints = nil
		return false
	end
	humanoid:MoveTo(target.Position)
	return true
end

-- The last resort: the bot reappears on the floor of the first spot no living player is
-- facing (its own slot, the other slots, then straight behind the leader).
local function teleport(bot: Bot, humanoid: Humanoid, root: BasePart, leader: BasePart, now: number)
	local settings = Config.Bots
	local model = bot.model :: Model
	local spots: { Vector3 } = { slotPosition(bot, leader) }
	for _, offset in settings.Slots do
		table.insert(spots, behindLeader(leader, offset))
	end
	table.insert(spots, behindLeader(leader, Vector3.new(0, 0, settings.TeleportBehind)))
	local points: { BotBrain.Point } = {}
	for index, spot in spots do
		points[index] = { x = spot.X, z = spot.Z }
	end
	local viewers: { BotBrain.Viewer } = {}
	for _, player in Squad.livingOwners() do
		local member = Squad.fromPlayer(player)
		local viewerRoot = member and member.root
		if viewerRoot then
			local look = flatLook(viewerRoot)
			table.insert(viewers, {
				x = viewerRoot.Position.X,
				z = viewerRoot.Position.Z,
				lookX = look.X,
				lookZ = look.Z,
			})
		end
	end
	local spot = spots[BotBrain.teleportSpot(points, viewers, settings.TeleportViewDot)]
	model:PivotTo(
		CFrame.new(
			floorAt(spot, leader, model)
				+ Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.2, 0)
		)
	)
	root.AssemblyLinearVelocity = Vector3.zero
	clearStall(bot)
	clearPath(bot)
	bot.pathFails = 0
	bot.teleportedAt = now
	print(`[BotService] {bot.member.name} was stuck and rejoined the squad`)
end

-- Follow: walk to the formation slot behind the nearest player. Straight there when it is
-- close, level and in sight; otherwise along a path to the leader. Teleporting is
-- BotBrain.shouldTeleport's call.
local function follow(
	bot: Bot,
	humanoid: Humanoid,
	root: BasePart,
	leader: BasePart,
	now: number,
	params: RaycastParams,
	post: Vector3?, -- stand here instead of the slot (a boss stand-off, out of a puddle)
	slack: number -- closer than this to the slot or the post: stand
)
	local settings = Config.Bots
	local here = root.Position
	local slot = post or slotPosition(bot, leader)
	local toSlot = flatDistance(slot, here)
	if toSlot > slack then
		bot.stuckMark, bot.stuckSince = BotBrain.stall(
			bot.stuckMark,
			bot.stuckSince,
			{ x = here.X, z = here.Z },
			now,
			settings.StuckDistance
		)
	else
		clearStall(bot)
	end
	local stuck = BotBrain.shouldTeleport({
		distance = (leader.Position - here).Magnitude,
		-- On a post the bot is away from its leader on purpose: only a fall teleports it.
		stalledFor = if bot.stuckSince and not post then now - bot.stuckSince else 0,
		pathFails = bot.pathFails,
		fellOut = here.Y < leader.Position.Y - settings.FallBelow,
		sinceTeleport = now - bot.teleportedAt,
	}, settings)
	if stuck then
		teleport(bot, humanoid, root, leader, now)
		return
	end
	if toSlot <= slack then
		clearPath(bot)
		humanoid:MoveTo(here)
		return
	end
	humanoid.WalkSpeed = if toSlot > settings.CatchUpBeyond
		then settings.CatchUpSpeed
		elseif post or toSlot > settings.RunBeyond then settings.RunSpeed
		else settings.WalkSpeed

	local level = post ~= nil or math.abs(leader.Position.Y - here.Y) <= settings.DirectMaxRise
	local stalledFor = now - (bot.stuckSince or now)
	if toSlot <= settings.DirectWithin and level and stalledFor < settings.DirectGiveUp then
		local toward = Vector3.new(slot.X - here.X, 0, slot.Z - here.Z)
		if not workspace:Raycast(here, toward, params) then
			clearPath(bot)
			humanoid:MoveTo(slot)
			return
		end
	end
	-- The slot is out of reach (inside a wall, past low cover) but the leader is right
	-- here: close enough.
	local goal = post or leader.Position
	if not post and (goal - here).Magnitude <= settings.NearLeader then
		clearPath(bot)
		clearStall(bot)
		humanoid:MoveTo(here)
		return
	end

	local pathGoal = bot.pathGoal
	local stale = bot.waypoints == nil
		or pathGoal == nil
		or (goal - pathGoal).Magnitude >= settings.PathRegoal
	if
		stale
		and not bot.pathPending
		and now >= nextPathAt
		and now - bot.pathAt >= settings.PathInterval
	then
		requestPath(bot, here, goal, now)
	end
	if not followPath(bot, humanoid, here) then
		humanoid:MoveTo(slot) -- no path yet (or none found): head straight for it
	end
end

-- Another task (downed, knocked, a dodge, a revive) took the bot off its follow: the path
-- and the stall clock start over when it resumes.
local function breakFollow(bot: Bot)
	clearStall(bot)
	clearPath(bot)
end

----------------------------------------------------------------------
-- Consumables: the when and where are Rules/BotBrain, the effect is the players' own
-- server path (KitService, CallInService) with no owner.
----------------------------------------------------------------------

local function tryStim(bot: Bot, humanoid: Humanoid, now: number, below: number)
	local use = BotBrain.shouldStim({
		health = humanoid.Health,
		maxHealth = humanoid.MaxHealth,
		stims = bot.stims,
		standing = Squad.canAct(bot.member),
		sinceStim = now - bot.stimAt,
	}, { StimBelow = below, StimCooldown = Config.Bots.StimCooldown })
	if use then
		bot.stims -= 1
		bot.stimAt = now
		KitService.dose(bot.member)
		print(`[BotService] {bot.member.name} used a stim ({bot.stims} left)`)
	end
end

-- The Infected within `reach` of `from` (the nearest Config.Bots.ScanMax of them) and
-- every squad member still in the fight, as flat points for BotBrain.clusterTarget.
local function scan(from: Vector3, reach: number): ({ BotBrain.Point }, { BotBrain.Point })
	local settings = Config.Bots
	local found: { { point: BotBrain.Point, distance: number } } = {}
	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		local humanoid = tagged:FindFirstChildOfClass("Humanoid")
		local enemyRoot = tagged:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and enemyRoot and enemyRoot:IsA("BasePart") then
			local position = enemyRoot.Position
			local distance = flatDistance(position, from)
			if distance <= reach then
				table.insert(found, {
					distance = distance,
					point = {
						x = position.X,
						y = position.Y,
						z = position.Z,
						heavy = humanoid.MaxHealth >= settings.CallIn.HeavyHealth,
					},
				})
			end
		end
	end
	if #found > settings.ScanMax then
		table.sort(found, function(a, b)
			return a.distance < b.distance
		end)
	end
	local enemies: { BotBrain.Point } = {}
	for index = 1, math.min(#found, settings.ScanMax) do
		enemies[index] = found[index].point
	end
	local friends: { BotBrain.Point } = {}
	for _, member in Squad.members() do
		local memberRoot = member.root
		if memberRoot and Squad.isActive(member) then
			table.insert(friends, { x = memberRoot.Position.X, z = memberRoot.Position.Z })
		end
	end
	return enemies, friends
end

-- The point to throw at for `target`, or nil when the throw would not get there: a throw
-- stops at the first thing in its way (ThrowUtil), so a wall refuses it, and so does an
-- Infected so close that it would land inside `minDistance`.
local function throwPoint(
	root: BasePart,
	target: BotBrain.Point,
	minDistance: number,
	params: RaycastParams
): Vector3?
	local here = root.Position
	local point = Vector3.new(target.x, target.y or here.Y, target.z)
	local hit = workspace:Raycast(here, Vector3.new(point.X - here.X, 0, point.Z - here.Z), params)
	if hit and flatDistance(hit.Position, point) > 3 then
		if
			not enemyFromPart(hit.Instance)
			or flatDistance(hit.Position, here) - 2 < minDistance
		then
			return nil
		end
	end
	return point
end

-- Every ScanInterval while it has a target: a fire mission at a big knot or a heavy, else
-- a frag at a knot (Config.Bots.CallIn / Grenade).
local function tryThrow(bot: Bot, model: Model, root: BasePart, now: number, params: RaycastParams)
	local settings = Config.Bots
	if now < bot.nextScanAt or not Squad.canAct(bot.member) then
		return
	end
	bot.nextScanAt = now + settings.ScanInterval
	local callIn = settings.CallIn
	local definition =
		CallInDefinitions.get(callIn.Kit[((bot.slot - 1) % math.max(#callIn.Kit, 1)) + 1])
	local mission = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	local missionReady = mission ~= nil and now >= bot.callInAt and now >= squadCallInAt
	local frag = (Config.Grenade :: any)[WeaponDefinitions.grenade(nil).ConfigKey]
	local fragReady = bot.grenades > 0 and now >= bot.grenadeAt
	if not missionReady and not fragReady then
		return
	end
	local reach = frag.ThrowDistance + frag.Radius
	-- A mission marked through binoculars (the Anvil) has no ThrowDistance: the bot marks
	-- within its own sight range.
	local missionReach = if mission then mission.ThrowDistance or settings.Range else 0
	if missionReady then
		reach = math.max(reach, missionReach + mission.BlastRadius)
	end
	local enemies, friends = scan(root.Position, reach)
	local self: BotBrain.Point = { x = root.Position.X, z = root.Position.Z }

	if missionReady and definition then
		local safe = mission.Aim.Radius + callIn.FriendMargin
		local target = BotBrain.clusterTarget(self, enemies, friends, {
			Radius = mission.BlastRadius,
			MinCluster = callIn.MinCluster,
			MinDistance = safe,
			MaxDistance = missionReach,
			SafeRadius = safe,
			HeavyCounts = true,
		})
		local point = target and throwPoint(root, target, safe, params)
		if point and CallInService.fireMissionFor(bot.member, definition.Id, point) then
			bot.callInAt = now + callIn.Cooldown
			squadCallInAt = now + callIn.SquadGap
			noticeRemote:FireAllClients(
				string.format(callIn.Radio, bot.member.name, definition.Name),
				Messages.Notice.Radio
			)
			print(`[BotService] {bot.member.name} called {definition.Name}`)
			return
		end
	end
	if fragReady then
		local safe = frag.Radius + settings.Grenade.FriendMargin
		local target, count = BotBrain.clusterTarget(self, enemies, friends, {
			Radius = frag.Radius,
			MinCluster = settings.Grenade.MinCluster,
			MinDistance = safe,
			MaxDistance = frag.ThrowDistance,
			SafeRadius = safe,
		})
		local point = target and throwPoint(root, target, safe, params)
		if point then
			bot.grenades -= 1
			bot.grenadeAt = now + settings.Grenade.Cooldown
			KitService.throwFrag(nil, model, root, point, nil)
			print(`[BotService] {bot.member.name} threw a frag at {count} ({bot.grenades} left)`)
		end
	end
end

-- IndexService marks the Pound / Stomp disc or the Slam / Charge line on workspace
-- attributes while it winds up; a bot inside walks out (radially, or sideways off a line).
local function dodgeDanger(humanoid: Humanoid, root: BasePart, now: number): boolean
	local untilTime = workspace:GetAttribute(Attributes.BossDangerUntil) :: number?
	if not untilTime or now >= untilTime then
		return false
	end
	local center = workspace:GetAttribute(Attributes.BossDanger) :: Vector3?
	local radius = workspace:GetAttribute(Attributes.BossDangerRadius) :: number?
	if not center or not radius then
		return false
	end
	local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local kind = workspace:GetAttribute(Attributes.BossDangerKind)
	local margin = Config.Bots.Boss.DodgeMargin
	if kind == "line" then
		local direction = workspace:GetAttribute(Attributes.BossDangerDir) :: Vector3?
		local length = (workspace:GetAttribute(Attributes.BossDangerLength) :: number?) or 0
		if not direction then
			return false
		end
		local along = offset:Dot(direction)
		if along < -2 or along > length + margin then
			return false
		end
		local side = offset - direction * along
		if side.Magnitude > radius + margin then
			return false
		end
		local out = if side.Magnitude > 0.1
			then side.Unit
			else Vector3.new(-direction.Z, 0, direction.X)
		humanoid.WalkSpeed = Config.Bots.Boss.DodgeSpeed
		humanoid:MoveTo(root.Position + out * (radius + margin + 2 - side.Magnitude))
		return true
	end
	if offset.Magnitude > radius + margin then
		return false
	end
	local out = if offset.Magnitude > 0.1 then offset.Unit else Vector3.xAxis
	humanoid.WalkSpeed = Config.Bots.Boss.DodgeSpeed
	humanoid:MoveTo(center + out * (radius + margin + 2))
	return true
end

local function think(bot: Bot, now: number, params: RaycastParams)
	local humanoid, root, model = bot.humanoid, bot.root, bot.model
	if not humanoid or not root or not model or humanoid.Health <= 0 then
		tryRespawn(bot, now)
		return
	end
	if bot.member.state == "Downed" then
		breakFollow(bot)
		holdDowned(bot, humanoid, root)
		return
	end
	local downedTrack = bot.tracks.downed
	if downedTrack and downedTrack.IsPlaying then
		downedTrack:Stop(0.3)
	end
	-- Pulling a squadmate up, or getting up after a revive: stand still while the clip plays.
	if ReviveAnimService.busy(model) then
		humanoid:MoveTo(root.Position)
		return
	end
	-- Knocked down (Squad.knock): on the ground until the attribute clears; the fall and
	-- the get-up play at the rates that fit the knockdown.
	local knockedUntil = model:GetAttribute(Attributes.KnockedUntil) :: number?
	if knockedUntil then
		breakFollow(bot)
		if not bot.knocked then
			bot.knocked = true
			humanoid:MoveTo(root.Position)
			for _, track in { bot.tracks.idle, bot.tracks.walk, bot.tracks.run } do
				if track and track.IsPlaying then
					track:Stop(0.1)
				end
			end
			local getUp = Config.Knockdown.GetUp
			local fall = bot.tracks.knockdown
			local total = knockedUntil - now
			if fall then
				fall:Play(0.05)
				fall:AdjustSpeed(math.max(fall.Length, 0.01) / math.max(total - getUp, 0.2))
			end
			task.delay(math.max(total - getUp, 0), function()
				local rise = bot.tracks.getup
				if rise and bot.model == model then
					if fall and fall.IsPlaying then
						fall:Stop(0.1)
					end
					rise:Play(0.05)
					rise:AdjustSpeed(math.max(rise.Length, 0.01) / getUp)
				end
			end)
		end
		return
	end
	bot.knocked = false
	local settings = Config.Bots
	local leader = leaderRoot(root.Position)
	-- A boss fight (Config.Bots.Boss): the boss is within Engage of the bot's leader.
	local boss = if settings.Boss.Enabled then liveBoss() else nil
	if
		boss
		and not (leader and flatDistance(boss.Position, leader.Position) <= settings.Boss.Engage)
	then
		boss = nil
	end
	local kitFree = RunStates.isLive() and not PauseService.isPaused()
	if kitFree then
		tryStim(bot, humanoid, now, if boss then settings.Boss.StimBelow else settings.StimBelow)
	end
	-- The Warden's ground attacks (IndexService danger attributes): step out of the ring or
	-- the line while he winds up, nothing else.
	if dodgeDanger(humanoid, root, now) then
		breakFollow(bot)
		animate(
			bot,
			Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		)
		return
	end
	if tryRevive(bot, humanoid, root, boss) then
		breakFollow(bot)
		humanoid.AutoRotate = true
		local velocity = root.AssemblyLinearVelocity
		animate(bot, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		return
	end

	if leader then
		-- Where to stand: out of a caustic puddle first, then the boss stand-off ring
		-- (BotBrain.standOff: spread, out of his reach), else the formation slot.
		local here: BotBrain.Point = { x = root.Position.X, z = root.Position.Z }
		local post: BotBrain.Point? = nil
		local slack = settings.FollowSlack
		if settings.Boss.Enabled then
			local center, radius = EnemyProjectileService.puddleAt(root.Position)
			if center and radius then
				post = BotBrain.stepOut(
					here,
					{ x = center.X, z = center.Z },
					radius,
					settings.Boss.PuddleMargin
				)
				slack = 1
			end
		end
		if not post and boss then
			post = BotBrain.standOff(
				{ x = boss.Position.X, z = boss.Position.Z },
				{ x = leader.Position.X, z = leader.Position.Z },
				bot.slot,
				settings.Boss
			)
			slack = settings.Boss.Slack
		end
		follow(
			bot,
			humanoid,
			root,
			leader,
			now,
			params,
			if post then Vector3.new(post.x, root.Position.Y, post.z) else nil,
			slack
		)
	end

	-- Fight: face and shoot the nearest visible Infected while the field is live.
	local enemy, aim = nil, nil
	if RunStates.isLive() then
		enemy, aim = pickTarget(root.Position + Vector3.new(0, 1.5, 0), params)
	end
	if enemy and enemy ~= bot.target then
		bot.target = enemy
		bot.nextShot = math.max(bot.nextShot, now + Config.Bots.ReactionTime)
	end
	if enemy and kitFree then
		tryThrow(bot, model, root, now, params)
	end
	-- The magazine: a bot reloads like the player (WeaponDefinitions), from an infinite reserve.
	local weapon = WeaponDefinitions.get(WeaponDefinitions.DEFAULT)
	local reloadUntil = bot.reloadUntil
	if reloadUntil and now >= reloadUntil then
		bot.reloadUntil = nil
		bot.rounds = weapon.MagazineSize
	elseif not reloadUntil and bot.rounds <= 0 then
		bot.reloadUntil = now + weapon.ReloadTime
	end
	if enemy and aim then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(aim.X, root.Position.Y, aim.Z))
		if now >= bot.nextShot and not bot.reloadUntil and bot.rounds > 0 then
			bot.nextShot = now + Config.Bots.FireCooldown * (0.85 + math.random() * 0.3)
			bot.rounds -= 1
			local origin = if bot.muzzle
				then bot.muzzle.Position
				else root.Position + Vector3.new(0, 1.5, 0)
			shoot(bot, origin, aim, params)
		end
	else
		humanoid.AutoRotate = true
	end

	local velocity = root.AssemblyLinearVelocity
	animate(bot, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
end

local function step()
	if #bots == 0 then
		return
	end
	local now = os.clock()
	local params: RaycastParams? = nil
	for _, bot in bots do
		if now >= bot.nextThink then
			bot.nextThink = now + Config.Bots.ThinkInterval
			if not params then
				params = rayParams()
			end
			think(bot, now, params :: RaycastParams)
		end
	end
end

local countOverride: number? = nil -- dev SetBots

local function wanted(): number
	local count = countOverride or Config.Bots.Count
	return math.clamp(count, 0, math.max(MAX_SQUAD - #Players:GetPlayers(), 0))
end

local function removeBot(bot: Bot)
	local index = table.find(bots, bot)
	if index then
		table.remove(bots, index)
	end
	despawn(bot)
	Squad.removeBot(bot.member)
end

-- RunManager, on every run start: rebuild the bot squad around the first player.
function BotService.startRun()
	runGeneration += 1
	for _, bot in table.clone(bots) do
		removeBot(bot)
	end
	local now = os.clock()
	local settings = Config.Bots
	squadCallInAt = 0
	for slot = 1, wanted() do
		local names = Squad.freeCallsigns()
		local stagger = (slot - 1) / MAX_SQUAD -- bots think and scan on different frames
		table.insert(bots, {
			slot = slot,
			member = Squad.addBot(slot, names[((slot - 1) % #names) + 1]),
			model = nil,
			humanoid = nil,
			root = nil,
			muzzle = nil,
			tracks = {},
			nextThink = now + stagger * settings.ThinkInterval,
			waypointIndex = 1,
			pathPending = false,
			pathAt = 0,
			pathFails = 0,
			teleportedAt = 0,
			stims = Config.Stim.Carried,
			grenades = Config.Grenade.Carried,
			stimAt = 0,
			nextScanAt = now + stagger * settings.ScanInterval,
			grenadeAt = 0,
			callInAt = now + settings.CallIn.FirstDelay,
			nextShot = 0,
			respawnAt = nil,
			spawning = false,
			rounds = WeaponDefinitions.get(WeaponDefinitions.DEFAULT).MagazineSize,
			reloadUntil = nil,
			target = nil,
			reviving = nil,
			reviveProgress = 0,
		})
	end
	local generation = runGeneration
	-- Wait for a player body to anchor the formation (a restart respawns the player).
	task.spawn(function()
		local deadline = os.clock() + 10
		local leader = leaderRoot(Vector3.zero)
		while not leader and os.clock() < deadline do
			task.wait(0.25)
			leader = leaderRoot(Vector3.zero)
		end
		if generation ~= runGeneration then
			return
		end
		-- A run start lands every bot on its own pad (Squad hands out the free ones).
		for _, bot in bots do
			local pad = Squad.spawnCFrame(bot.member).Position - Vector3.new(0, 3, 0)
			task.spawn(spawnBot, bot, pad)
		end
	end)
end

-- Dev: change how many bots fill the squad and rebuild them now.
function BotService.setCount(count: number)
	countOverride = math.clamp(math.floor(count), 0, MAX_SQUAD)
	BotService.startRun()
end

-- RequisitionService, when a player takes a Restock card: every bot's frags and stims back.
function BotService.restock()
	for _, bot in bots do
		bot.stims = Config.Stim.Carried
		bot.grenades = Config.Grenade.Carried
	end
end

-- Bot bodies currently alive on the field (dev tools, tests).
function BotService.count(): number
	local alive = 0
	for _, bot in bots do
		if bot.humanoid and bot.humanoid.Health > 0 then
			alive += 1
		end
	end
	return alive
end

function BotService.init()
	folder = Instance.new("Folder")
	folder.Name = "SquadBots"
	folder.Parent = workspace
	tracerRemote = Remotes.get("ShotTracer")
	noticeRemote = Remotes.get("BuffNotice")
	-- An Aid Bag refills a treated bot's stims, as it does a player's.
	SupplyDropService.onAidBag(function(member)
		for _, bot in bots do
			if bot.member == member then
				bot.stims = Config.Stim.Carried
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
	-- A real player joining takes a bot's place.
	Players.PlayerAdded:Connect(function()
		while #bots > wanted() do
			removeBot(bots[#bots])
		end
	end)
end

return BotService
