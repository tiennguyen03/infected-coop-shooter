--!strict
-- Resupply (docs/PROGRESSION.md > Resupply): the draft that replaced the level-up pop-up.
-- Kills fill one run-wide pool (base orb XP, once per orb). When the pool covers the
-- current cost any living player throws the red flare; for DropDelay seconds the Infected
-- nearby walk to the flare instead of the squad, then a pallet drops out of the sky, lands
-- loud (a wave spawns around it) and shows each player their own three cards in a row in
-- front of it. Walk into a card to take it: one pick per player per pallet, cards vanish
-- after CardLifetime. Pool and drop count carry across stages. Server-authoritative: the
-- client only asks to throw and asks to pick; both are validated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local EnemyService = require(script.Parent.EnemyService)
local ItemService = require(script.Parent.ItemService)
local PauseService = require(script.Parent.PauseService)
local XPOrbService = require(script.Parent.XPOrbService)

local FLARE_COLOR = Color3.fromRGB(255, 60, 40)
local CRATE_DROP_HEIGHT = 60
local CRATE_DROP_TIME = 1.1
local CARD_HEIGHT = 2 -- card anchor above the ground
local CARD_FORWARD = 3.5 -- cards stand this far in front of the pallet, toward the thrower
local PICK_SLACK = 3 -- server tolerance on top of PickRadius (latency, card width)

type Pending = {
	position: Vector3,
	facing: Vector3, -- flat unit vector from the pallet toward where the thrower stood
	landAt: number,
	flare: BasePart,
}

type Crate = {
	id: number,
	part: BasePart,
	position: Vector3,
	cardPositions: { Vector3 },
	offers: { [Player]: { string } },
	picked: { [Player]: boolean },
	expiresAt: number,
}

local RequisitionService = {}

local folder: Folder
local resupplyRemote: RemoteEvent
local noticeRemote: RemoteEvent

local pool = 0
local drops = 0 -- pallets called this run (drives the cost curve and the guarantee)
local flareReadyAt = 0
local pending: Pending? = nil
local crates: { Crate } = {}
local nextCrateId = 1
local pressureUntil = 0
local lastStep = 0

local function livingPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(result, player)
		end
	end
	return result
end

local function currentCost(): number
	local cfg = Config.Requisition
	local base = math.min(cfg.BaseCost * cfg.CostGrowth ^ drops, cfg.CostCap)
	local extra = math.max(#livingPlayers() - 1, 0)
	return math.floor(base * (1 + cfg.CostPerExtraPlayer * extra))
end

local function publish()
	workspace:SetAttribute("ResupplyPool", math.floor(pool))
	workspace:SetAttribute("ResupplyCost", currentCost())
	workspace:SetAttribute(
		"ResupplyDropIn",
		if pending then math.max(pending.landAt - os.clock(), 0) else -1
	)
end

-- The one way in: base XP of a collected orb, once (not once per player), plus objective XP.
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
	resupplyRemote:FireAllClients("closed", crate.id)
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

local function land(drop: Pending)
	drop.flare:Destroy()
	local cfg = Config.Requisition

	local part: BasePart = MeshAssets.clone("prop_ammo_crate") or Instance.new("Part")
	part.Name = "Pallet"
	if part:IsA("Part") then
		part.Size = Vector3.new(3.2, 2, 2.4)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(107, 122, 74)
	end
	local rest = CFrame.lookAt(drop.position, drop.position + drop.facing)
		* CFrame.new(0, part.Size.Y / 2, 0)
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
	label.Text = "RESUPPLY"
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
	fall:Play()
	fall.Completed:Wait()
	if not part.Parent then
		return
	end

	-- Landed loud: the ring wave, extra pressure for a while.
	local living = livingPlayers()
	local wave = cfg.Lure.Wave + cfg.Lure.WavePerExtraPlayer * math.max(#living - 1, 0)
	EnemyService.spawnMixedWave(wave, drop.position)
	pressureUntil = os.clock() + cfg.Lure.SpawnFactorDuration
	workspace:SetAttribute("ResupplyActive", true)

	-- Personal cards: the same three positions for everyone, a different roll per player.
	if #crates >= cfg.MaxCrates then
		closeCrate(1)
	end
	local guarantee = drops % Config.Crates.GuaranteeEvery == 0
	local crate: Crate = {
		id = nextCrateId,
		part = part,
		position = drop.position,
		cardPositions = cardPositions(drop.position, drop.facing),
		offers = {},
		picked = {},
		expiresAt = os.clock() + cfg.CardLifetime,
	}
	nextCrateId += 1
	table.insert(crates, crate)
	for _, player in living do
		local choices = ItemService.rollChoices(Config.Crates.Weights.Requisition, guarantee)
		crate.offers[player] = choices
		resupplyRemote:FireClient(
			player,
			"cards",
			crate.id,
			choices,
			crate.cardPositions,
			ItemService.getInventory(player)
		)
	end
	print(`[Requisition] pallet {crate.id} down, {#living} players offered, wave {wave}`)
end

local function onFlare(player: Player, target: unknown)
	if pending or PauseService.isPaused() then
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
		flare = buildFlare(landing),
	}
	EnemyService.setLure(landing, cfg.Lure.Radius, cfg.DropDelay)
	resupplyRemote:FireAllClients("called", player.Name)
	publish()
	print(`[Requisition] {player.Name} threw the flare; pallet in {cfg.DropDelay}s (drop {drops})`)
end

local function onPick(player: Player, crateId: unknown, itemId: unknown)
	if typeof(crateId) ~= "number" or typeof(itemId) ~= "string" then
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
	local index = if offer then table.find(offer, itemId) else nil
	if not index then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local cardPosition = crate.cardPositions[index]
	local flat = Vector3.new(root.Position.X - cardPosition.X, 0, root.Position.Z - cardPosition.Z)
	if flat.Magnitude > Config.Requisition.PickRadius + PICK_SLACK then
		return
	end
	crate.picked[player] = true
	ItemService.addItem(player, itemId)
	resupplyRemote:FireClient(player, "picked", crate.id)
	local definition = ItemDefinitions[itemId]
	for _, other in Players:GetPlayers() do
		if other ~= player then
			noticeRemote:FireClient(other, `{player.Name} took {definition.Name}`)
		end
	end
end

local function onRemote(player: Player, kind: unknown, ...: unknown)
	if kind == "flare" then
		onFlare(player, ...)
	elseif kind == "pick" then
		onPick(player, ...)
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
	if pressureUntil > 0 and now >= pressureUntil then
		pressureUntil = 0
		workspace:SetAttribute("ResupplyActive", false)
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
	workspace:SetAttribute("ResupplyActive", false)
	publish()
end

function RequisitionService.init()
	folder = Instance.new("Folder")
	folder.Name = "Resupply"
	folder.Parent = workspace
	resupplyRemote = Remotes.get("Resupply")
	noticeRemote = Remotes.get("BuffNotice")
	resupplyRemote.OnServerEvent:Connect(onRemote)
	XPOrbService.addCollectListener(RequisitionService.addRequisition)
	workspace:SetAttribute("ResupplyActive", false)
	publish()
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)

	Players.PlayerRemoving:Connect(function(player)
		for _, crate in crates do
			crate.offers[player] = nil
			crate.picked[player] = nil
		end
	end)
end

return RequisitionService
