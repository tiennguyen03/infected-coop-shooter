--!strict
-- Emergency Ammo Cache item: supply crates drop near owners on a timer.
-- Touching one (proximity, like XP orbs) grants a random temporary buff:
-- +25% Damage/FireRate/MoveSpeed via PlayerStatsService, or a temporary
-- Shield implemented as a timed max-health boost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemService = require(script.Parent.ItemService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)

local BUFF_SOURCE = "ammo_cache"
local STAT_BUFFS = { "Damage", "FireRate", "MoveSpeed" }

type Cache = {
	part: BasePart,
	expiresAt: number,
}

local AmmoCacheService = {}

local cacheFolder: Folder
local buffRemote: RemoteEvent
local caches: { Cache } = {}
local nextSpawnAt: { [Player]: number } = {}
-- Generation counter so an expiring old buff never clears a newer one.
local buffGeneration: { [Player]: number } = {}

local function spawnInterval(stacks: number): number
	local cfg = Config.Items.AmmoCache
	return math.max(
		cfg.BaseInterval - (stacks - 1) * cfg.IntervalReductionPerStack,
		cfg.MinInterval
	)
end

local function applyRandomBuff(player: Player)
	local cfg = Config.Items.AmmoCache
	-- 4 outcomes: the 3 stat buffs plus Shield.
	local roll = math.random(#STAT_BUFFS + 1)
	if roll > #STAT_BUFFS then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth += cfg.ShieldHP
			humanoid.Health += cfg.ShieldHP
			task.delay(cfg.BuffDuration, function()
				if humanoid.Parent then
					humanoid.MaxHealth = math.max(humanoid.MaxHealth - cfg.ShieldHP, 1)
					humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
				end
			end)
		end
		buffRemote:FireClient(player, `SHIELD +{cfg.ShieldHP}`)
	else
		local stat = STAT_BUFFS[roll]
		local generation = (buffGeneration[player] or 0) + 1
		buffGeneration[player] = generation
		PlayerStatsService.setBonus(player, BUFF_SOURCE, { [stat] = cfg.BuffBonus })
		task.delay(cfg.BuffDuration, function()
			if buffGeneration[player] == generation and player.Parent then
				PlayerStatsService.setBonus(player, BUFF_SOURCE, {})
			end
		end)
		local label = if stat == "Damage"
			then "DAMAGE"
			elseif stat == "FireRate" then "FIRE RATE"
			else "SPEED"
		buffRemote:FireClient(player, `{label} +{cfg.BuffBonus * 100}%`)
	end
end

local function spawnCache(nearRoot: BasePart)
	local cfg = Config.Items.AmmoCache
	local angle = math.random() * math.pi * 2
	local distance = math.random(cfg.SpawnDistanceMin, cfg.SpawnDistanceMax)
	local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local spawnXZ = nearRoot.Position + offset

	local rayResult = workspace:Raycast(
		Vector3.new(spawnXZ.X, nearRoot.Position.Y + 50, spawnXZ.Z),
		Vector3.new(0, -200, 0)
	)
	local groundY = if rayResult then rayResult.Position.Y else 0

	local part = Instance.new("Part")
	part.Name = "AmmoCache"
	part.Size = Vector3.new(2.6, 1.6, 1.8)
	part.Position = Vector3.new(spawnXZ.X, groundY + 0.8, spawnXZ.Z)
	part.Orientation = Vector3.new(0, math.deg(angle), 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(107, 122, 74)

	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(90, 26)
	marker.StudsOffset = Vector3.new(0, 2.2, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SUPPLIES"
	label.TextColor3 = Color3.fromRGB(232, 181, 75)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = marker
	marker.Parent = part

	part.Parent = cacheFolder
	table.insert(caches, {
		part = part :: BasePart,
		expiresAt = os.clock() + cfg.CacheLifetime,
	})
end

local function removeCache(index: number)
	caches[index].part:Destroy()
	caches[index] = caches[#caches]
	caches[#caches] = nil
end

local function onHeartbeat()
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()

	-- Spawn timers, one per owning player.
	for _, player in Players:GetPlayers() do
		local stacks = ItemService.getStacks(player, "emergency_ammo_cache")
		if stacks == 0 then
			nextSpawnAt[player] = nil
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local at = nextSpawnAt[player]
		if not at then
			nextSpawnAt[player] = now + spawnInterval(stacks)
		elseif now >= at then
			nextSpawnAt[player] = now + spawnInterval(stacks)
			spawnCache(root)
		end
	end

	-- Cache pickup and expiry.
	for index = #caches, 1, -1 do
		local cache = caches[index]
		if now >= cache.expiresAt or not cache.part.Parent then
			removeCache(index)
			continue
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - cache.part.Position).Magnitude
				if distance <= Config.Items.AmmoCache.CollectRadius then
					applyRandomBuff(player)
					removeCache(index)
					break
				end
			end
		end
	end
end

function AmmoCacheService.reset()
	for _, cache in caches do
		cache.part:Destroy()
	end
	table.clear(caches)
	table.clear(nextSpawnAt)
	if cacheFolder then
		cacheFolder:ClearAllChildren()
	end
end

function AmmoCacheService.init()
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "AmmoCaches"
	cacheFolder.Parent = workspace

	buffRemote = Remotes.get("BuffNotice")
	RunService.Heartbeat:Connect(onHeartbeat)

	Players.PlayerRemoving:Connect(function(player: Player)
		nextSpawnAt[player] = nil
		buffGeneration[player] = nil
	end)
end

return AmmoCacheService
