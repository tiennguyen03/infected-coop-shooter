--!strict
-- Bot squadmates (2026-11-07). In solo the other Chosen fill the squad as server-side AI
-- (docs/PROGRESSION.md > The spine): one fewer per real player, up to a squad of 4. Each
-- bot is a Squad member, so the Infected chase it and enemy splash hurts it exactly like a
-- player. It wears the class body and rifle (PlayerSetup), follows the nearest player in a
-- formation slot, faces and shoots the nearest Infected it can see through the one damage
-- entry point (DamageService.dealDamage with no attacker: no kill credit, no hit
-- marker), and rejoins at its slot RespawnSeconds after dying. Numbers in Config.Bots.
-- Downed (Squad): a downed bot lies prone and waits; a standing bot breaks formation to
-- revive the nearest downed squadmate when no Infected is close (Config.Bots.Revive*).
-- It carries the service rifle's magazine (reloads from an infinite reserve). Not yet:
-- call-ins, vaulting.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Animations)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local DamageService = require(script.Parent.DamageService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local ProjectileServer = require(script.Parent.ProjectileServer)
local Squad = require(script.Parent.Squad)

local ENEMY_TAG = "Enemy"
local MAX_SQUAD = 4
local LOS_CHECKS = 3 -- nearest Infected tested for line of sight per decision

local BotService = {}

type Tracks = {
	idle: AnimationTrack?,
	walk: AnimationTrack?,
	run: AnimationTrack?,
	fire: AnimationTrack?,
	downed: AnimationTrack?,
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
	stuckFrom: Vector3?, -- where the follow last made progress, and when (Config.Bots.StuckSeconds)
	stuckSince: number?,
}

local bots: { Bot } = {}
local folder: Folder
local tracerRemote: RemoteEvent
local runGeneration = 0

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

local function slotPosition(bot: Bot, leader: BasePart): Vector3
	local slots = Config.Bots.Slots
	local offset = slots[((bot.slot - 1) % #slots) + 1]
	local look = leader.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAlong(leader.Position, flat.Unit):PointToWorldSpace(offset)
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

local function spawnBot(bot: Bot, position: Vector3)
	if bot.spawning then
		return
	end
	bot.spawning = true
	local generation = runGeneration
	local ok, built = pcall(function()
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
	humanoid.MaxHealth = Config.Bots.MaxHealth
	humanoid.Health = Config.Bots.MaxHealth
	humanoid.WalkSpeed = Config.Bots.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	if MeshAssets.waitFor(PlayerSetup.BODY .. "head", 5) then
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
	Squad.bindCharacter(bot.member, rig)
	loadTracks(bot, humanoid)

	humanoid.Died:Connect(function()
		if bot.model ~= rig then
			return
		end
		stopTracks(bot)
		bot.respawnAt = os.clock() + Config.Bots.RespawnSeconds
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
			"AssaultEffects",
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
	local range = Config.Weapon.Range
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
	bot.reviving = nil
	bot.reviveProgress = 0
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
local function tryRevive(bot: Bot, humanoid: Humanoid, root: BasePart): boolean
	local settings = Config.Bots
	local target = bot.reviving
	if not target or target.state ~= "Downed" then
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
		bot.reviveProgress = 0
	end
	local downedRoot = target and target.root
	if not target or not downedRoot then
		return false
	end
	if nearestInfectedDistance(downedRoot.Position) < settings.ReviveSafeRadius then
		bot.reviveProgress = 0
		return false -- too hot: fight first
	end
	local distance = (downedRoot.Position - root.Position).Magnitude
	if distance > Config.Downed.ReviveRadius - 2 then
		humanoid.WalkSpeed = settings.RunSpeed
		humanoid:MoveTo(downedRoot.Position)
		bot.reviveProgress = 0
		return true
	end
	humanoid:MoveTo(root.Position)
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

local function think(bot: Bot, now: number, params: RaycastParams)
	local humanoid, root, model = bot.humanoid, bot.root, bot.model
	if not humanoid or not root or not model or humanoid.Health <= 0 then
		tryRespawn(bot, now)
		return
	end
	if bot.member.state == "Downed" then
		holdDowned(bot, humanoid, root)
		return
	end
	local downedTrack = bot.tracks.downed
	if downedTrack and downedTrack.IsPlaying then
		downedTrack:Stop(0.3)
	end
	if tryRevive(bot, humanoid, root) then
		humanoid.AutoRotate = true
		local velocity = root.AssemblyLinearVelocity
		animate(bot, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		return
	end

	-- Follow: hold the formation slot behind the nearest player. Far behind, or stuck on a
	-- doorway or a stair for StuckSeconds, the bot reappears in the slot at floor level
	-- (the slot sits at the leader's root height, which may be a floor up).
	local leader = leaderRoot(root.Position)
	if leader then
		local slot = slotPosition(bot, leader)
		local distance =
			Vector3.new(slot.X - root.Position.X, 0, slot.Z - root.Position.Z).Magnitude
		local stuck = false
		if distance > Config.Bots.FollowSlack then
			local from = bot.stuckFrom
			if from and (root.Position - from).Magnitude < Config.Bots.StuckDistance then
				stuck = now - (bot.stuckSince or now) >= Config.Bots.StuckSeconds
			else
				bot.stuckFrom = root.Position
				bot.stuckSince = now
			end
		else
			bot.stuckFrom = nil
			bot.stuckSince = nil
		end
		if distance > Config.Bots.TeleportBeyond or stuck then
			model:PivotTo(
				CFrame.new(
					floorAt(slot, leader, model)
						+ Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.2, 0)
				)
			)
			bot.stuckFrom = nil
			bot.stuckSince = nil
		elseif distance > Config.Bots.FollowSlack then
			humanoid.WalkSpeed = if distance > Config.Bots.RunBeyond
				then Config.Bots.RunSpeed
				else Config.Bots.WalkSpeed
			humanoid:MoveTo(slot)
		else
			humanoid:MoveTo(root.Position)
		end
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
	for slot = 1, wanted() do
		local names = Config.Bots.Names
		table.insert(bots, {
			slot = slot,
			member = Squad.addBot(slot, names[((slot - 1) % #names) + 1]),
			model = nil,
			humanoid = nil,
			root = nil,
			muzzle = nil,
			tracks = {},
			nextThink = 0,
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
	RunService.Heartbeat:Connect(step)
	-- A real player joining takes a bot's place.
	Players.PlayerAdded:Connect(function()
		while #bots > wanted() do
			removeBot(bots[#bots])
		end
	end)
end

return BotService
