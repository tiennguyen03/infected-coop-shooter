--!strict
-- Resupply (docs/PROGRESSION.md > Loadout, pallets and field upgrades). Every kill credits
-- its form's SupplyValue to one run-wide pool (EnemyService kill listener; no orbs since
-- the loadout rework), the hold objective adds its reward. When the pool covers
-- the current cost any living player throws the red flare (key 3); for DropDelay seconds
-- the Infected nearby walk to the flare instead of the squad, then a pallet drops out of
-- the sky and lands loud (a wave spawns around it). The pallet is the ammo box: every
-- living player who walks within RearmRadius is re-armed once (full magazine + reserve).
-- Its three cards are the supply cards (Medkit / Restock / Armour Plate; one pick per
-- player per pallet). An upgrade crate (`dropCrate(..., "upgrade")`, the Primary's site
-- crates) shows each player field upgrades instead. Server-authoritative: the client only
-- asks to throw and asks to pick; both are validated here.

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
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local CallInService = require(script.Parent.CallInService)
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
local PICK_SLACK = 3 -- server tolerance on top of PickRadius (latency, card width)

export type CrateKind = "supply" | "upgrade"

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

-- What `player` sees on a crate of `kind`: the supply cards, or a roll of field upgrades
-- they can still take (possibly none).
local function offerFor(player: Player, kind: CrateKind): { string }
	if kind == "supply" then
		return table.clone(Config.Crates.SupplyCards)
	end
	return LoadoutService.rollUpgradeOffer(player, Config.Crates.CardsPerPlayer)
end

-- Drops a crate of `kind` on `position` (ground-snapped), cards facing `facing`. `loud`
-- lands it like a pallet: a ring wave and extra pressure for a while. The part falls in
-- from the sky; the cards show once it lands. `landed`: it is already on the ground (a
-- Misdrop pallet the squad reached), so no fall.
function RequisitionService.dropCrate(
	position: Vector3,
	facing: Vector3,
	kind: CrateKind,
	loud: boolean,
	landed: boolean?
)
	local cfg = Config.Requisition
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

	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(110, 26)
	marker.StudsOffset = Vector3.new(0, 2.6, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if kind == "supply" then "RESUPPLY" else "FIELD KIT"
	label.TextColor3 = Color3.fromRGB(232, 181, 75)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = marker
	marker.Parent = part

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

	local living = livingPlayers()
	if loud then
		-- Landed loud: the ring wave, extra pressure for a while.
		local wave = cfg.Lure.Wave + cfg.Lure.WavePerExtraPlayer * math.max(#living - 1, 0)
		EnemyService.spawnMixedWave(wave, ground)
		pressureUntil = os.clock() + cfg.Lure.SpawnFactorDuration
		workspace:SetAttribute(Attributes.ResupplyActive, true)
	end

	-- Personal cards: the same three positions for everyone, each player's own offer.
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
		rearmed = {},
		expiresAt = os.clock() + cfg.CardLifetime,
	}
	nextCrateId += 1
	table.insert(crates, crate)
	for _, player in living do
		local choices = offerFor(player, kind)
		crate.offers[player] = choices
		if #choices > 0 then
			resupplyRemote:FireClient(
				player,
				Messages.Resupply.Cards,
				crate.id,
				kind,
				choices,
				crate.cardPositions
			)
		end
	end
	print(`[Requisition] {kind} crate {crate.id} down, {#living} players offered`)
end

local function land(drop: Pending)
	drop.flare:Destroy()
	RequisitionService.dropCrate(drop.position, drop.facing, "supply", true)
end

local function onFlare(player: Player, target: unknown)
	if pending or PauseService.isPaused() then
		return
	end
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) then
		return
	end
	local now = os.clock()
	if now < flareReadyAt or pool < currentCost() then
		return
	end
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
	pending = {
		position = landing,
		facing = Vector3.new(facing.X, 0, facing.Z).Unit,
		landAt = now + cfg.DropDelay,
		flare = (function()
			local flare = buildFlare(landing)
			WorldSounds.loopOn(flare, "callins", "flare_burn")
			return flare
		end)(),
	}
	EnemyService.setLure(landing, cfg.Lure.Radius, cfg.DropDelay)
	resupplyRemote:FireAllClients(Messages.Resupply.Called, Squad.callsign(player))
	publish()
	print(`[Requisition] {player.Name} threw the flare; pallet in {cfg.DropDelay}s (drop {drops})`)
end

-- Applies a taken card to the player. Returns the notice for the rest of the squad.
local function applyCard(player: Player, cardId: string): string?
	local definition = UpgradeDefinitions.get(cardId)
	if not definition then
		return nil
	end
	if definition.Kind == "upgrade" then
		if not LoadoutService.giveUpgrade(player, cardId) then
			return nil
		end
	elseif cardId == "medkit" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
		LoadoutService.refillStims(player)
	elseif cardId == "restock" then
		CallInService.refill(player)
		LoadoutService.refillGrenades(player)
		LoadoutService.refillStims(player)
	elseif cardId == "armour_plate" then
		LoadoutService.addShield(player, Config.Crates.ArmourPlate)
	else
		return nil
	end
	return `{Squad.callsign(player)} took {definition.Name}`
end

local function onPick(player: Player, crateId: unknown, cardId: unknown)
	if typeof(crateId) ~= "number" or typeof(cardId) ~= "string" then
		return
	end
	local crate: Crate? = nil
	for _, candidate in crates do
		if candidate.id == crateId then
			crate = candidate
		end
	end
	if not crate or crate.picked[player] then
		return
	end
	local offer = crate.offers[player]
	local index = if offer then table.find(offer, cardId) else nil
	if not index then
		return
	end
	local member = Squad.fromPlayer(player)
	local root = member and member.root
	if not member or not Squad.canAct(member) or not root then
		return
	end
	local cardPosition = crate.cardPositions[index]
	local flat = Vector3.new(root.Position.X - cardPosition.X, 0, root.Position.Z - cardPosition.Z)
	if flat.Magnitude > Config.Requisition.PickRadius + PICK_SLACK then
		return
	end
	local notice = applyCard(player, cardId)
	if not notice then
		return
	end
	crate.picked[player] = true
	WorldSounds.on(root, "ui_radio", "card_pick", "Gear")
	resupplyRemote:FireClient(player, Messages.Resupply.Picked, crate.id)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			noticeRemote:FireClient(other, notice, Messages.Notice.Pickup)
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
