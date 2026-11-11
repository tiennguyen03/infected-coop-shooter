--!strict
-- Resupply (docs/PROGRESSION.md > Loadout, pallets and field upgrades). Every kill credits
-- its form's SupplyValue to one run-wide pool (EnemyService kill listener; no orbs since
-- the loadout rework), the hold objective adds its reward. When the pool covers
-- the current cost any living player throws the red flare (key 3); for DropDelay seconds
-- the Infected nearby walk to the flare instead of the squad, then a pallet drops out of
-- the sky and lands loud (a wave spawns around it). The pallet is the ammo box: every
-- living player who walks within RearmRadius is re-armed once (full magazine + reserve).
-- Its three cards are the supply cards (Medkit / Restock / Armour Plate; one pick per
-- player per pallet). An upgrade crate (`dropCrate(..., "upgrade")`, the site crate) shows
-- each player field upgrades instead; an objective crate (`"objective"`, the hold's end)
-- does too and restocks the whole squad as it lands (Config.Crates.Kinds).
-- Taking a card (owner 2026-11-11): never by walking over it. The crate carries a
-- ProximityPrompt; the client opens a panel of the player's cards on it (RewardPanel) and
-- asks for one. Server-authoritative: the client only asks to throw and asks to pick; both
-- are validated here (Rules/Reward.checkPick: the crate, the offer, one pick per player,
-- reach, not downed). Bots near a crate take a supply card by need (Reward.botChoice).
-- Config.Requisition.Pick.WalkOver = true restores the old walk-into-a-card pick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Reward = require(ReplicatedStorage.Shared.Rules.Reward)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local BotService = require(script.Parent.BotService)
local CallInService = require(script.Parent.CallInService)
local ThrowWindUp = require(script.Parent.ThrowWindUp)
local EnemyService = require(script.Parent.EnemyService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local FLARE_COLOR = Color3.fromRGB(255, 60, 40)
local CRATE_DROP_HEIGHT = 60
local CRATE_DROP_TIME = 1.1
local CARD_HEIGHT = 2 -- card anchor above the ground
local CARD_FORWARD = 3.5 -- cards stand this far in front of the pallet, toward the thrower
local PICK_SLACK = 3 -- walk-over only: server tolerance on top of PickRadius
local MARKER_COLOR = Color3.fromRGB(232, 181, 75)

export type CrateKind = "supply" | "upgrade" | "objective"

-- A row of Config.Crates.Kinds.
type KindRow = { Label: string, Lifetime: number, Beacon: boolean, Squad: Reward.Effects? }

type Pending = {
	position: Vector3,
	facing: Vector3, -- flat unit vector from the pallet toward where the thrower stood
	landAt: number,
	flare: BasePart,
}

type Crate = {
	id: number,
	kind: CrateKind,
	part: BasePart,
	position: Vector3,
	cardPositions: { Vector3 },
	offers: { [Player]: { string } },
	picked: { [Player]: boolean },
	botPicked: { [string]: boolean }, -- Squad member ids of the bots that took a card
	taken: { string }, -- callsigns that have taken a card, in order
	status: TextLabel, -- the marker's second line: "TAKEN 1/2"
	rearmed: { [Player]: boolean },
	expiresAt: number,
}

local RequisitionService = {}

local folder: Folder
local resupplyRemote: RemoteEvent
local noticeRemote: RemoteEvent

local pool = 0
local drops = 0 -- pallets called this run (drives the cost curve)
local flareReadyAt = 0
local pending: Pending? = nil
local crates: { Crate } = {}
local nextCrateId = 1
local pressureUntil = 0
local lastStep = 0

local function livingPlayers(): { Player }
	return Squad.livingOwners()
end

local function kindRow(kind: CrateKind): KindRow
	return (Config.Crates.Kinds :: any)[kind] or Config.Crates.Kinds.supply
end

local function cardEffects(): { [string]: Reward.Effects }
	return Config.Crates.Cards :: any
end

local function currentCost(): number
	local cfg = Config.Requisition
	local base = math.min(cfg.BaseCost * cfg.CostGrowth ^ drops, cfg.CostCap)
	local extra = math.max(#livingPlayers() - 1, 0)
	return math.floor(base * (1 + cfg.CostPerExtraPlayer * extra))
end

local function publish()
	workspace:SetAttribute(Attributes.ResupplyPool, math.floor(pool))
	workspace:SetAttribute(Attributes.ResupplyCost, currentCost())
	workspace:SetAttribute(
		Attributes.ResupplyDropIn,
		if pending then math.max(pending.landAt - os.clock(), 0) else -1
	)
end

-- The one way in: a kill's SupplyValue (once, not once per player) and the objective reward.
function RequisitionService.addRequisition(amount: number)
	pool += amount
	publish()
end

function RequisitionService.getPool(): number
	return pool
end

local function buildFlare(position: Vector3): BasePart
	local flare = Instance.new("Part")
	flare.Name = "Flare"
	flare.Shape = Enum.PartType.Ball
	flare.Size = Vector3.new(0.8, 0.8, 0.8)
	flare.Position = position + Vector3.new(0, 0.5, 0)
	flare.Anchored = true
	flare.CanCollide = false
	flare.CanQuery = false
	flare.CanTouch = false
	flare.CastShadow = false
	flare.Material = Enum.Material.Neon
	flare.Color = FLARE_COLOR
	local light = Instance.new("PointLight")
	light.Color = FLARE_COLOR
	light.Brightness = 3
	light.Range = 18
	light.Parent = flare
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(FLARE_COLOR, Color3.fromRGB(120, 30, 20))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(2.5, 3.5)
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(4, 7)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(1.5, 2, 0)
	smoke.LightEmission = 0.3
	smoke.Parent = flare
	flare.Parent = folder
	return flare
end

local function closeCrate(index: number)
	local crate = crates[index]
	crate.part:Destroy()
	table.remove(crates, index)
	resupplyRemote:FireAllClients(Messages.Resupply.Closed, crate.id)
end

local function cardPositions(center: Vector3, facing: Vector3): { Vector3 }
	local right = facing:Cross(Vector3.yAxis)
	local positions = {}
	local count = Config.Crates.CardsPerPlayer
	for index = 1, count do
		local offset = (index - (count + 1) / 2) * Config.Requisition.CardSpacing
		local flat = center + facing * CARD_FORWARD + right * offset
		local ground = workspace:Raycast(flat + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0))
		local groundY = if ground then ground.Position.Y else center.Y
		table.insert(positions, Vector3.new(flat.X, groundY + CARD_HEIGHT, flat.Z))
	end
	return positions
end

-- What `player` sees on a crate of `kind`: the supply cards, or field upgrades they do
-- not hold (ones for an empty slot first), filled up with supply cards when short.
local function offerFor(player: Player, kind: CrateKind): { string }
	local supply = Config.Crates.SupplyCards
	if kind == "supply" then
		return table.clone(supply)
	end
	local count = Config.Crates.CardsPerPlayer
	return Reward.pad(LoadoutService.rollUpgradeOffer(player, count), supply, count)
end

-- Gives a set of effects to a member: the heal reaches a bot, the rest needs a player's kit.
local function applyEffects(member: Squad.Member, effects: Reward.Effects)
	local humanoid = member.humanoid
	if effects.Heal and humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	local player = member.owner
	if not player then
		return
	end
	if effects.Ammo then
		LoadoutService.refillAmmo(player)
	end
	if effects.CallIns then
		CallInService.refill(player)
	end
	if effects.Grenades then
		LoadoutService.refillGrenades(player)
	end
	if effects.Stims then
		LoadoutService.refillStims(player)
	end
	local plate = effects.Plate
	if plate and plate > 0 then
		LoadoutService.addShield(player, plate)
	end
end

-- The label over a crate: what it is, and under it who has taken theirs.
local function buildMarker(part: BasePart, text: string): TextLabel
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(240, 54)
	marker.StudsOffset = Vector3.new(0, 3.4, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 300
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = MARKER_COLOR
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = marker
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Position = UDim2.fromOffset(0, 34)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(240, 240, 240)
	status.TextStrokeTransparency = 0.4
	status.TextScaled = true
	status.Font = Enum.Font.GothamBold
	status.Parent = marker
	marker.Parent = part
	return status
end

-- A thin pillar of light over a crate worth walking to, seen across the map.
local function buildBeacon(part: BasePart, ground: Vector3)
	local cfg = Config.Crates.Beacon
	local beam = Instance.new("Part")
	beam.Name = "Beacon"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(cfg.Height, cfg.Width, cfg.Width)
	beam.CFrame = CFrame.new(ground + Vector3.new(0, cfg.Height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = MARKER_COLOR
	beam.Transparency = cfg.Transparency
	beam.Parent = part
	local light = Instance.new("PointLight")
	light.Color = MARKER_COLOR
	light.Brightness = 2
	light.Range = 16
	light.Parent = part
end

-- The prompt a player holds to open the crate's cards; the client reads CrateId off it.
local function buildPrompt(part: BasePart, crateId: number, text: string)
	local cfg = Config.Requisition.Pick
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CratePrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = text
	prompt.KeyboardKeyCode = cfg.Key
	prompt.GamepadKeyCode = cfg.GamepadKey
	prompt.HoldDuration = cfg.Hold
	prompt.MaxActivationDistance = cfg.Radius
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute(Attributes.CrateId, crateId)
	prompt.Parent = part
end

-- Who has taken a card: the marker's second line and every client's panel.
local function publishTaken(crate: Crate)
	local offered, picked = 0, 0
	for player in crate.offers do
		offered += 1
		if crate.picked[player] then
			picked += 1
		end
	end
	crate.status.Text = if #crate.taken > 0 and offered > 0 then `TAKEN {picked}/{offered}` else ""
	resupplyRemote:FireAllClients(Messages.Resupply.Taken, crate.id, crate.taken)
end

-- Sends `player` their cards on `crate` (also: the upgrade each card would replace).
local function sendCards(player: Player, crate: Crate)
	local choices = crate.offers[player]
	if not choices or #choices == 0 then
		return
	end
	local replaces: { string } = {}
	for index, cardId in choices do
		replaces[index] = LoadoutService.replacedBy(player, cardId) or ""
	end
	resupplyRemote:FireClient(
		player,
		Messages.Resupply.Cards,
		crate.id,
		crate.kind,
		choices,
		crate.cardPositions,
		crate.position,
		math.max(crate.expiresAt - os.clock(), 0),
		replaces
	)
end

-- Drops a crate of `kind` on `position` (ground-snapped), facing `facing`. `loud` lands it
-- like a pallet: a ring wave and extra pressure for a while. The part falls in from the
-- sky; once it lands each player has their cards on it and, for a kind with a Squad row
-- (the Main objective's reward), every living soldier is restocked.
-- `landed`: it is already on the ground (a Misdrop pallet the squad reached), so no fall.
function RequisitionService.dropCrate(
	position: Vector3,
	facing: Vector3,
	kind: CrateKind,
	loud: boolean,
	landed: boolean?
)
	local cfg = Config.Requisition
	local row = kindRow(kind)
	local ground = GroundUtil.GetGroundPosition(position, 0)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis

	local part: BasePart = MeshAssets.clone("prop_ammo_crate") or Instance.new("Part")
	part.Name = if kind == "supply" then "Pallet" else "UpgradeCrate"
	if part:IsA("Part") then
		part.Size = Vector3.new(3.2, 2, 2.4)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(107, 122, 74)
	end
	local rest = CFrame.lookAt(ground, ground + forward) * CFrame.new(0, part.Size.Y / 2, 0)
	part.CFrame = rest + Vector3.new(0, CRATE_DROP_HEIGHT, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = folder
	local status = buildMarker(part, row.Label)

	local fall = TweenService:Create(
		part,
		TweenInfo.new(CRATE_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = rest }
	)
	if landed then
		part.CFrame = rest
	else
		fall:Play()
		fall.Completed:Wait()
		if not part.Parent then
			return
		end
		WorldSounds.at(ground, "callins", "pallet_land")
	end
	if row.Beacon then
		buildBeacon(part, ground)
	end

	local living = livingPlayers()
	if loud then
		-- Landed loud: the ring wave, extra pressure for a while.
		local wave = cfg.Lure.Wave + cfg.Lure.WavePerExtraPlayer * math.max(#living - 1, 0)
		EnemyService.spawnMixedWave(wave, ground)
		pressureUntil = os.clock() + cfg.Lure.SpawnFactorDuration
		workspace:SetAttribute(Attributes.ResupplyActive, true)
	end

	-- The squad's share first, then each player's own cards: a downed player gets theirs
	-- too, to take once back up.
	local squad = row.Squad
	if squad then
		for _, member in Squad.living() do
			applyEffects(member, squad)
		end
	end
	if #crates >= cfg.MaxCrates then
		closeCrate(1)
	end
	local crate: Crate = {
		id = nextCrateId,
		kind = kind,
		part = part,
		position = ground,
		cardPositions = cardPositions(ground, forward),
		offers = {},
		picked = {},
		botPicked = {},
		taken = {},
		status = status,
		rearmed = {},
		expiresAt = os.clock() + row.Lifetime,
	}
	nextCrateId += 1
	table.insert(crates, crate)
	if not cfg.Pick.WalkOver then
		buildPrompt(part, crate.id, row.Label)
	end
	local offered = 0
	for _, player in Players:GetPlayers() do
		if Squad.fromPlayer(player) then
			crate.offers[player] = offerFor(player, kind)
			sendCards(player, crate)
			offered += 1
		end
	end
	print(`[Requisition] {kind} crate {crate.id} down, {offered} players offered`)
end

local function land(drop: Pending)
	drop.flare:Destroy()
	RequisitionService.dropCrate(drop.position, drop.facing, "supply", true)
end

-- True when `player` may throw the flare now: standing, no pallet inbound, the cooldown
-- over and the pool covering the cost.
local function canThrowFlare(player: Player): boolean
	if pending or PauseService.isPaused() then
		return false
	end
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) then
		return false
	end
	return os.clock() >= flareReadyAt and pool >= currentCost()
end

-- The release (ThrowWindUp, the throw clip's release): the pool pays here and the flare
-- flies from the hand for FlareFlight (ThrowFX on the clients) before it burns on the mark.
local function releaseFlare(player: Player, target: unknown)
	if not canThrowFlare(player) then
		return
	end
	local now = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local cfg = Config.Requisition
	pool -= currentCost()
	drops += 1
	flareReadyAt = now + cfg.DropDelay + cfg.FlareCooldown

	local landing = ThrowUtil.landingPoint(
		root,
		if typeof(target) == "Vector3" then target else nil,
		cfg.FlareThrowDistance,
		{ character, folder }
	)
	local back = Vector3.new(root.Position.X - landing.X, 0, root.Position.Z - landing.Z)
	local facing = if back.Magnitude > 0.5 then back.Unit else -root.CFrame.LookVector
	local flare = buildFlare(landing)
	flare.Parent = nil -- in the air until it lands
	local thrown: Pending = {
		position = landing,
		facing = Vector3.new(facing.X, 0, facing.Z).Unit,
		landAt = now + cfg.DropDelay,
		flare = flare,
	}
	pending = thrown
	ThrowWindUp.thrown(player, flare.Position, cfg.FlareFlight, FLARE_COLOR)
	task.spawn(function()
		PauseService.wait(cfg.FlareFlight)
		if pending == thrown then
			flare.Parent = folder
			WorldSounds.loopOn(flare, "callins", "flare_burn")
		end
	end)
	EnemyService.setLure(landing, cfg.Lure.Radius, cfg.DropDelay)
	resupplyRemote:FireAllClients(Messages.Resupply.Called, Squad.callsign(player))
	publish()
	print(`[Requisition] {player.Name} threw the flare; pallet in {cfg.DropDelay}s (drop {drops})`)
end

-- The flare key: the wind-up starts; the flare leaves the hand, and the pool pays, at the release.
local function onFlare(player: Player, target: unknown)
	if canThrowFlare(player) then
		ThrowWindUp.begin(player, function()
			releaseFlare(player, target)
		end)
	end
end

-- Applies a taken card to the member. Returns the notice for the rest of the squad.
local function applyCard(member: Squad.Member, cardId: string): string?
	local definition = UpgradeDefinitions.get(cardId)
	if not definition then
		return nil
	end
	local player = member.owner
	if definition.Kind == "upgrade" then
		if not player or not LoadoutService.giveUpgrade(player, cardId) then
			return nil
		end
	else
		local effects = cardEffects()[cardId]
		if not effects then
			return nil
		end
		applyEffects(member, effects)
		if cardId == "restock" then
			BotService.restock() -- the pallet restocks the bots' frags and stims too
		end
	end
	return `{member.name} took {definition.Name}`
end

local function findCrate(crateId: number): Crate?
	for _, candidate in crates do
		if candidate.id == crateId then
			return candidate
		end
	end
	return nil
end

local function onPick(player: Player, crateId: unknown, cardId: unknown)
	if typeof(crateId) ~= "number" or typeof(cardId) ~= "string" then
		return
	end
	local crate = findCrate(crateId)
	local member = Squad.fromPlayer(player)
	local root = member and member.root
	local offer = if crate then crate.offers[player] else nil
	local pickCfg = Config.Requisition.Pick
	-- Reach: the crate itself, or (walk-over) the card the player walked into.
	local target = if crate then crate.position else Vector3.zero
	local radius = pickCfg.Radius + pickCfg.Slack
	if crate and pickCfg.WalkOver then
		local index = if offer then table.find(offer, cardId) else nil
		target = if index then crate.cardPositions[index] else target
		radius = Config.Requisition.PickRadius + PICK_SLACK
	end
	local distance = if root
		then Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z).Magnitude
		else math.huge
	local ok, reason = Reward.checkPick({
		open = crate ~= nil and os.clock() < crate.expiresAt,
		offer = offer,
		cardId = cardId,
		picked = crate ~= nil and crate.picked[player] == true,
		canAct = member ~= nil and root ~= nil and Squad.canAct(member),
		distance = distance,
		radius = radius,
	})
	local notice = if ok and member then applyCard(member, cardId) else nil
	if not crate or not member or not root or not notice then
		resupplyRemote:FireClient(player, Messages.Resupply.Refused, crateId, reason or "gone")
		return
	end
	crate.picked[player] = true
	table.insert(crate.taken, member.name)
	WorldSounds.on(root, "ui_radio", "card_pick", "Gear")
	resupplyRemote:FireClient(player, Messages.Resupply.Picked, crate.id, cardId)
	publishTaken(crate)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			noticeRemote:FireClient(other, notice, Messages.Notice.Pickup)
		end
	end
end

-- Bots take no panel: one close to a crate takes the supply card that covers what it is
-- missing most (a bot has health only), once per crate.
local function botPicks()
	local cfg = Config.Crates
	for _, crate in crates do
		if crate.kind ~= "supply" then
			continue -- field upgrades: a bot has no loadout to carry one
		end
		for _, member in Squad.living() do
			local root, humanoid = member.root, member.humanoid
			if member.kind ~= "bot" or crate.botPicked[member.id] or not root or not humanoid then
				continue
			end
			if (root.Position - crate.position).Magnitude > cfg.BotRadius then
				continue
			end
			local need: Reward.Need = {
				Heal = 1 - humanoid.Health / math.max(humanoid.MaxHealth, 1),
			}
			local cardId = Reward.botChoice(cfg.SupplyCards, cardEffects(), need, cfg.BotNeed)
			local notice = if cardId then applyCard(member, cardId) else nil
			if notice then
				crate.botPicked[member.id] = true
				table.insert(crate.taken, member.name)
				publishTaken(crate)
				noticeRemote:FireAllClients(notice, Messages.Notice.Pickup)
			end
		end
	end
end

local function onRemote(player: Player, kind: unknown, ...: unknown)
	if kind == Messages.Resupply.Flare then
		onFlare(player, ...)
	elseif kind == Messages.Resupply.Pick then
		onPick(player, ...)
	end
end

-- The pallet is the ammo box: a living player within RearmRadius is re-armed once per crate.
local function rearmNearby()
	local radius = Config.Requisition.RearmRadius
	for _, crate in crates do
		for _, player in livingPlayers() do
			if crate.rearmed[player] then
				continue
			end
			local member = Squad.fromPlayer(player)
			local root = member and member.root
			if root and (root.Position - crate.position).Magnitude <= radius then
				crate.rearmed[player] = true
				LoadoutService.refillAmmo(player)
				noticeRemote:FireClient(player, "RE-ARMED", Messages.Notice.Pickup)
			end
		end
	end
end

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		-- Hold the drop, the cards and the cooldown on their clocks while paused.
		local shift = now - lastStep
		if pending then
			pending.landAt += shift
		end
		for _, crate in crates do
			crate.expiresAt += shift
		end
		flareReadyAt += shift
		pressureUntil += shift
		lastStep = now
		return
	end
	lastStep = now

	local drop = pending
	if drop and now >= drop.landAt then
		pending = nil
		task.spawn(land, drop)
	end
	for index = #crates, 1, -1 do
		if now >= crates[index].expiresAt then
			closeCrate(index)
		end
	end
	rearmNearby()
	botPicks()
	if pressureUntil > 0 and now >= pressureUntil then
		pressureUntil = 0
		workspace:SetAttribute(Attributes.ResupplyActive, false)
	end
	publish()
end

-- New run: pool, drop count, flare, pallets and cards all go.
function RequisitionService.reset()
	pool = 0
	drops = 0
	flareReadyAt = 0
	pressureUntil = 0
	if pending then
		pending.flare:Destroy()
		pending = nil
	end
	for index = #crates, 1, -1 do
		closeCrate(index)
	end
	EnemyService.setLure(nil)
	workspace:SetAttribute(Attributes.ResupplyActive, false)
	publish()
end

function RequisitionService.init()
	Lifecycle.register("RequisitionService", {
		onRunStart = RequisitionService.reset,
		onPlayerRemoving = function(player: Player)
			for _, crate in crates do
				crate.offers[player] = nil
				crate.picked[player] = nil
				crate.rearmed[player] = nil
			end
		end,
	})
	folder = Instance.new("Folder")
	folder.Name = "Resupply"
	folder.Parent = workspace
	resupplyRemote = Remotes.get("Resupply")
	noticeRemote = Remotes.get("BuffNotice")
	resupplyRemote.OnServerEvent:Connect(onRemote)
	EnemyService.addKillListener(function(supplyValue: number)
		RequisitionService.addRequisition(supplyValue)
	end)
	workspace:SetAttribute(Attributes.ResupplyActive, false)
	publish()
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)
end

return RequisitionService
