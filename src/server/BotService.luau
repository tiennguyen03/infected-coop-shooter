--!strict
-- Bot squadmates (2026-11-07). In solo the other Chosen fill the squad as server-side AI
-- (docs/PROGRESSION.md > The spine): one fewer per real player, up to a squad of 4. Each
-- bot is a Squad member, so the Infected chase it and enemy splash hurts it exactly like a
-- player. It wears the class body and rifle (PlayerSetup), follows the nearest player in a
-- formation slot, faces and shoots the nearest Infected it can see through the one damage
-- entry point (ItemEffectService.dealDamage with no attacker: no kill credit, no hit
-- marker), and rejoins at its slot RespawnSeconds after dying. Numbers in Config.Bots.
-- Not yet: downed/revive (Sprint A step 6), call-ins (loadout rework), vaulting.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Animations)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local ItemEffectService = require(script.Parent.ItemEffectService)
local PlayerSetup = require(script.Parent.PlayerSetup)
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
}

local bots: { Bot } = {}
local folder: Folder
local tracerRemote: RemoteEvent
local runGeneration = 0

local function leaderRoot(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Squad.livingOwners() do
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
	}
	for _, track in { bot.tracks.idle, bot.tracks.walk, bot.tracks.run } do
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
		{ "Projectiles", "Tracers", "InfectedProjectiles", "XPOrbs", "Resupply", "ResupplyCards" }
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
			local headshot = hit.Instance.Name == "Head"
			local multiplier = if headshot then Config.Weapon.HeadshotMultiplier else 1
			ItemEffectService.dealDamage(
				nil,
				humanoid,
				Config.Bots.Damage * multiplier,
				hit.Position,
				if headshot then "headshot" else "hit"
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

local function think(bot: Bot, now: number, params: RaycastParams)
	local humanoid, root, model = bot.humanoid, bot.root, bot.model
	if not humanoid or not root or not model or humanoid.Health <= 0 then
		tryRespawn(bot, now)
		return
	end

	-- Follow: hold the formation slot behind the nearest player.
	local leader = leaderRoot(root.Position)
	if leader then
		local slot = slotPosition(bot, leader)
		local distance =
			Vector3.new(slot.X - root.Position.X, 0, slot.Z - root.Position.Z).Magnitude
		if distance > Config.Bots.TeleportBeyond then
			model:PivotTo(CFrame.new(slot + Vector3.new(0, 3, 0)))
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
	if enemy and aim then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(aim.X, root.Position.Y, aim.Z))
		if now >= bot.nextShot then
			bot.nextShot = now + Config.Bots.FireCooldown * (0.85 + math.random() * 0.3)
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

local function wanted(): number
	return math.clamp(Config.Bots.Count, 0, math.max(MAX_SQUAD - #Players:GetPlayers(), 0))
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
