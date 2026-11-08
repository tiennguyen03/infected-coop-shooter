--!strict
-- Flare Straps (fire_trail upgrade, AssaultClassService): the Combat Dash leaves burning
-- pools along its path (Config.Upgrades.FireTrail) that tick damage on the Infected standing
-- in them. Pools never hurt the squad.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)

local ENEMY_TAG = "Enemy"

type Pool = {
	part: BasePart,
	owner: Player,
	expiresAt: number,
	nextTick: number,
}

local IncendiaryService = {}

local poolFolder: Folder
local pools: { Pool } = {}
local lastStep = 0

local function removePool(index: number)
	pools[index].part:Destroy()
	pools[index] = pools[#pools]
	pools[#pools] = nil
end

function IncendiaryService.spawnPool(owner: Player, position: Vector3)
	local cfg = Config.Upgrades.FireTrail

	-- Enforce the per-player pool cap by removing this owner's oldest.
	local ownedCount = 0
	for _, pool in pools do
		if pool.owner == owner then
			ownedCount += 1
		end
	end
	if ownedCount >= cfg.MaxPools then
		for index, pool in pools do
			if pool.owner == owner then
				removePool(index)
				break
			end
		end
	end

	local ground = GroundUtil.GetGroundPosition(position, 0.05)

	local part = Instance.new("Part")
	part.Name = "FirePool"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.5, cfg.Radius * 2, cfg.Radius * 2)
	part.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(235, 110, 35)
	part.Transparency = 0.4
	part.Parent = poolFolder
	TweenService:Create(part, TweenInfo.new(cfg.Duration), { Transparency = 0.85 }):Play()

	local now = os.clock()
	table.insert(pools, {
		part = part :: BasePart,
		owner = owner,
		expiresAt = now + cfg.Duration,
		nextTick = now + 1,
	})
end

-- `count` pools spaced evenly from `from` to `to` (the dash path).
function IncendiaryService.spawnTrail(owner: Player, from: Vector3, to: Vector3, count: number)
	if count <= 0 then
		return
	end
	for index = 1, count do
		local alpha = if count > 1 then (index - 1) / (count - 1) else 0.5
		IncendiaryService.spawnPool(owner, from:Lerp(to, alpha))
	end
end

local function onHeartbeat()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, pool in pools do
			pool.expiresAt += shift
			pool.nextTick += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	local cfg = Config.Upgrades.FireTrail
	for index = #pools, 1, -1 do
		local pool = pools[index]
		if now >= pool.expiresAt then
			removePool(index)
		elseif now >= pool.nextTick then
			pool.nextTick += 1
			local center = pool.part.Position
			for _, model in CollectionService:GetTagged(ENEMY_TAG) do
				if model:IsA("Model") then
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					if humanoid and humanoid.Health > 0 and root then
						if (root.Position - center).Magnitude <= cfg.Radius then
							DamageService.dealDamage(
								pool.owner,
								humanoid,
								cfg.DamagePerSecond,
								root.Position,
								"fire"
							)
						end
					end
				end
			end
		end
	end
end

function IncendiaryService.reset()
	for _, pool in pools do
		pool.part:Destroy()
	end
	table.clear(pools)
	if poolFolder then
		poolFolder:ClearAllChildren()
	end
end

function IncendiaryService.init()
	poolFolder = Instance.new("Folder")
	poolFolder.Name = "FirePools"
	poolFolder.Parent = workspace
	lastStep = os.clock()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return IncendiaryService
