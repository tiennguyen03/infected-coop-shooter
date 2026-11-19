--!strict
-- Reinforcements and ammo pouches (Config.Scarcity; docs/sprints/FUN_SCARCITY.md).
--
-- Reinforcements: one pool per run for the whole squad (Rules/Scarcity.poolSize: Base +
-- PerPlayer for every player who has joined this run). A player who dies (Squad: bled out,
-- or a lethal hit with no revives left) during a live run spends one: after Delay seconds the
-- helicopter drops them beside the nearest standing squadmate (a player first, else a bot;
-- Rules/Scarcity.pickAnchor), from DropHeight when there is open sky there. They land with the
-- insert kit (LoadoutService.reinforce). With the pool empty they stay dead until the squad
-- extracts. Bots never spend it (BotService waits Reinforce.BotRespawnSeconds instead).
-- RunManager asks `wiped` (Rules/Scarcity.wiped) whether the mission is lost.
--
-- Ammo pouches: any squadmate who dies (bots too, Pouch.FromBots) leaves a pouch at the body;
-- each living player may take it once (hold Keys.Interact) for magazines of both guns.
--
-- Published: workspace ReinforceLeft / ReinforceTotal (the HUD's pool, ReinforceUI); on the
-- Player ReinforceAt (server time of their drop, 0 = none) and ReinforceTo (who they drop to);
-- the roster's RespawnAt (Squad.setRespawnIn) so squadmates read "DEAD 8s".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local Scarcity = require(ReplicatedStorage.Shared.Rules.Scarcity)
local LoadoutService = require(script.Parent.LoadoutService)
local Squad = require(script.Parent.Squad)
local WorldSounds = require(script.Parent.WorldSounds)

local ReinforceService = {}

local POUCH_COLOR = Color3.fromRGB(84, 88, 62)
local LABEL_COLOR = Color3.fromRGB(230, 189, 96) -- the HUD yellow
local MAX_POUCHES = 8 -- the oldest goes when a ninth drops (perf)
local DIRECTIONS = 8 -- spots tried round the squadmate
local RETRY_SECONDS = 2 -- a drop with nobody on their feet to land by tries again after this

local function settings()
	return Config.Scarcity
end

-- Reinforcements on (the master switch and its own).
function ReinforceService.enabled(): boolean
	return settings().Enabled and settings().Reinforce.Enabled
end

local function pouchesOn(): boolean
	return settings().Enabled and settings().Pouch.Enabled
end

-- Run state. `generation` is bumped on every run so a drop timer never lands in a later run.
local generation = 0
local total = 0
local used = 0
local seen: { [number]: boolean } = {} -- UserIds who have joined this run (each adds PerPlayer)
local pending: { [Player]: number } = {} -- player -> the generation their drop belongs to
local pouches: { Instance } = {}
local folder: Folder
local notice: RemoteEvent

local function left(): number
	return math.max(total - used, 0)
end

local function publish()
	workspace:SetAttribute(
		Attributes.ReinforceTotal,
		if ReinforceService.enabled() then total else 0
	)
	workspace:SetAttribute(
		Attributes.ReinforceLeft,
		if ReinforceService.enabled() then left() else 0
	)
end

local function setDrop(player: Player, at: number, to: string)
	player:SetAttribute(Attributes.ReinforceAt, at)
	player:SetAttribute(Attributes.ReinforceTo, to)
end

local function radio(text: string)
	notice:FireAllClients(text, Messages.Notice.Radio)
end

-- Reinforcements left in the pool (DevTestService, specs through Rules/Scarcity).
function ReinforceService.left(): number
	return left()
end

-- Dev: the pool set to `count` left (the total grows if it must).
function ReinforceService.setLeft(count: number)
	count = math.max(math.floor(count), 0)
	total = math.max(total, used + count)
	used = total - count
	publish()
end

local function pendingCount(): number
	local count = 0
	for _ in pending do
		count += 1
	end
	return count
end

-- True when the mission is lost (RunManager): no player up and nobody to drop back in.
function ReinforceService.wiped(): boolean
	local playersActive, botsActive = 0, 0
	for _, member in Squad.members() do
		if Squad.isActive(member) then
			if member.owner then
				playersActive += 1
			else
				botsActive += 1
			end
		end
	end
	return Scarcity.wiped({
		playersActive = playersActive,
		botsActive = botsActive,
		pending = pendingCount(),
		left = left(),
		enabled = ReinforceService.enabled(),
	})
end

----------------------------------------------------------------------
-- Ammo pouches
----------------------------------------------------------------------

local function removePouch(pouch: Instance)
	local index = table.find(pouches, pouch)
	if index then
		table.remove(pouches, index)
	end
	pouch:Destroy()
end

local function dropPouch(member: Squad.Member, position: Vector3)
	local cfg = settings().Pouch
	local ground = GroundUtil.GetGroundPosition(position, 0.3)
	local pouch = Instance.new("Part")
	pouch.Name = "AmmoPouch"
	pouch.Anchored = true
	pouch.CanCollide = false
	pouch.CanQuery = false
	pouch.CanTouch = false
	pouch.Size = Vector3.new(1.4, 0.6, 1)
	pouch.Color = POUCH_COLOR
	pouch.Material = Enum.Material.Fabric
	pouch.CFrame = CFrame.new(ground) * CFrame.Angles(0, math.random() * math.pi * 2, 0)

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(120, 20)
	label.StudsOffset = Vector3.new(0, 1.6, 0)
	label.MaxDistance = 60
	label.LightInfluence = 0
	label.Parent = pouch
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = LABEL_COLOR
	text.TextStrokeTransparency = 0.45
	text.Text = "AMMO"
	text.Parent = label

	local taken: { [Player]: boolean } = {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PouchPrompt"
	prompt.ActionText = "Take ammo"
	prompt.ObjectText = `{member.name}'s pouch`
	prompt.KeyboardKeyCode = Config.Keys.Interact
	prompt.GamepadKeyCode = Config.Requisition.Pick.GamepadKey
	prompt.HoldDuration = cfg.Hold
	prompt.MaxActivationDistance = cfg.Radius
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		local taker = Squad.fromPlayer(player)
		local root = taker and taker.root
		if not taker or not root or not Squad.canAct(taker) or taken[player] then
			return
		end
		if (root.Position - pouch.Position).Magnitude > cfg.Radius + 3 then
			return
		end
		if not LoadoutService.addMags(player, cfg.PrimaryMags, cfg.SecondaryMags) then
			notice:FireClient(player, "AMMO FULL", Messages.Notice.Pickup)
			return
		end
		taken[player] = true
		WorldSounds.on(root, "player_gear", "reload", "Gear")
		notice:FireClient(
			player,
			`AMMO  +{cfg.PrimaryMags} mags from {member.name}`,
			Messages.Notice.Pickup
		)
		-- Everyone who can take it has: the pouch is empty.
		local everyone = true
		for _, other in Players:GetPlayers() do
			if not taken[other] then
				everyone = false
			end
		end
		if everyone then
			removePouch(pouch)
		end
	end)
	prompt.Parent = pouch

	pouch.Parent = folder
	table.insert(pouches, pouch)
	while #pouches > MAX_POUCHES do
		removePouch(pouches[1])
	end
	task.delay(cfg.LifeSeconds, function()
		if pouch.Parent then
			removePouch(pouch)
		end
	end)
end

----------------------------------------------------------------------
-- The drop
----------------------------------------------------------------------

-- The squadmate a reinforcement drops beside, nearest to `near` (a player first).
local function anchorFor(near: Vector3, exclude: Squad.Member?): Squad.Member?
	local candidates: { Scarcity.Anchor } = {}
	local byId: { [string]: Squad.Member } = {}
	for _, member in Squad.living() do
		local root = member.root
		if member ~= exclude and root then
			byId[member.id] = member
			table.insert(candidates, {
				id = member.id,
				isPlayer = member.owner ~= nil,
				distance = (root.Position - near).Magnitude,
			})
		end
	end
	local id = Scarcity.pickAnchor(candidates)
	return if id then byId[id] else nil
end

-- Where the soldier lands beside `anchor`: a spot Distance away in the open (seen from the
-- squadmate, open sky above), fallen into from DropHeight; else right beside them.
local function dropCFrame(anchor: Squad.Member, ignore: { Instance }): CFrame
	local cfg = settings().Reinforce
	local root = anchor.root :: BasePart
	local origin = root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local start = math.random() * math.pi * 2
	for index = 0, DIRECTIONS - 1 do
		local angle = start + index * (math.pi * 2 / DIRECTIONS)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.Distance
		local spot = origin + offset
		if not workspace:Raycast(origin, offset, params) then
			local sky = workspace:Raycast(spot, Vector3.new(0, cfg.DropHeight + 4, 0), params)
			local floor = workspace:Raycast(spot, Vector3.new(0, -12, 0), params)
			if not sky and floor then
				local landing = floor.Position + Vector3.new(0, cfg.DropHeight, 0)
				return CFrame.lookAt(landing, Vector3.new(origin.X, landing.Y, origin.Z))
			end
		end
	end
	return root.CFrame * CFrame.new(2.5, 0, 0)
end

local function drop(player: Player, deathPosition: Vector3)
	if pending[player] ~= generation then
		return
	end
	local member = Squad.fromPlayer(player)
	if not player.Parent or not member or not RunStates.isLive() then
		pending[player] = nil
		used = math.max(used - 1, 0) -- nobody went: the reinforcement is not spent
		publish()
		return
	end
	local anchor = anchorFor(deathPosition, member)
	if not anchor then
		-- Everyone left is down: the bird waits for somebody on their feet (a wipe, if it
		-- comes, clears the drop with the run).
		task.delay(RETRY_SECONDS, drop, player, deathPosition)
		return
	end
	pending[player] = nil
	setDrop(player, 0, "")
	local myGeneration = generation
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	local character = player.Character
	if not ok or not character or myGeneration ~= generation then
		if not ok then
			warn(`[Reinforce] {player.Name} could not be dropped: {err}`)
		end
		return
	end
	local ignore: { Instance } = { character }
	for _, other in Squad.members() do
		if other.character then
			table.insert(ignore, other.character)
		end
	end
	-- The squadmate may have moved or gone down during the load: ask again.
	local target = anchorFor(deathPosition, member) or anchor
	if target.root then
		character:PivotTo(dropCFrame(target, ignore))
		WorldSounds.at((target.root :: BasePart).Position, "ambience", "lantern_rotor", 0.8)
	end
	LoadoutService.reinforce(player)
	-- A fresh soldier: the mission's revives start again for them (Config.Downed.MaxRevives).
	member.revivesUsed = 0
	print(`[Reinforce] {player.Name} dropped beside {target.name} ({left()} left)`)
end

local function onDeath(member: Squad.Member)
	local root = member.root
	local position = if root then root.Position else Vector3.zero
	if
		pouchesOn()
		and RunStates.isLive()
		and root
		and (member.owner or settings().Pouch.FromBots)
	then
		dropPouch(member, position)
	end
	local player = member.owner
	if not player or not ReinforceService.enabled() or not RunStates.isLive() then
		return
	end
	if pending[player] then
		return
	end
	if left() <= 0 then
		setDrop(player, 0, "")
		radio(settings().Reinforce.Radio.Empty)
		return
	end
	-- Somebody still in the fight (on their feet or down) to drop to; nobody: RunManager
	-- calls the wipe.
	local anchor = anchorFor(position, member)
	local anyoneActive = anchor ~= nil
	for _, other in Squad.members() do
		anyoneActive = anyoneActive or (other ~= member and Squad.isActive(other))
	end
	if not anyoneActive then
		return
	end
	local cfg = settings().Reinforce
	local toName = if anchor then anchor.name else "the squad"
	used += 1
	pending[player] = generation
	local at = workspace:GetServerTimeNow() + cfg.Delay
	setDrop(player, at, toName)
	Squad.setRespawnIn(member, cfg.Delay)
	publish()
	radio(string.format(cfg.Radio.Inbound, member.name, toName))
	if left() == 0 then
		task.delay(2.5, function()
			radio(cfg.Radio.Last)
		end)
	end
	task.delay(cfg.Delay, drop, player, position)
end

-- A fresh run (the Insert state): the pool refilled for the players here, nothing inbound,
-- the pouches gone.
local function resetRun()
	generation += 1
	used = 0
	table.clear(seen)
	table.clear(pending)
	local count = 0
	for _, player in Players:GetPlayers() do
		seen[player.UserId] = true
		setDrop(player, 0, "")
		count += 1
	end
	local cfg = settings().Reinforce
	total = Scarcity.poolSize(cfg.Base, cfg.PerPlayer, count)
	for _, pouch in table.clone(pouches) do
		removePouch(pouch)
	end
	publish()
end

-- A player who joins partway adds their share to the pool (once per run).
local function onPlayerAdded(player: Player)
	setDrop(player, 0, "")
	if seen[player.UserId] or RunStates.current() == "Lobby" then
		return
	end
	seen[player.UserId] = true
	total += settings().Reinforce.PerPlayer
	publish()
end

function ReinforceService.init()
	folder = Instance.new("Folder")
	folder.Name = "AmmoPouches"
	folder.Parent = workspace
	notice = Remotes.get("BuffNotice")
	Squad.onStateChanged(function(member, _old, new)
		if new == "Dead" then
			onDeath(member)
		end
	end)
	workspace:GetAttributeChangedSignal(Attributes.RunState):Connect(function()
		local state = RunStates.current()
		if state == "Insert" then
			resetRun()
		elseif state == "Ended" then
			generation += 1
			table.clear(pending)
			for _, player in Players:GetPlayers() do
				setDrop(player, 0, "")
			end
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		if pending[player] then
			pending[player] = nil
			used = math.max(used - 1, 0)
			publish()
		end
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	publish()
end

return ReinforceService
