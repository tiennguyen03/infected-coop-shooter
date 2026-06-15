--!strict
-- Repulsor Mine Kit item: while owned, periodically drops a mine behind the
-- player that detonates when an Infected wanders close, dealing area damage.
-- Mines never hurt the player (only tagged enemies are damaged).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemEffectService = require(script.Parent.ItemEffectService)
local ItemService = require(script.Parent.ItemService)
local PauseService = require(script.Parent.PauseService)

local ENEMY_TAG = "Enemy"

local function mineStacks(player: Player): number
	return ItemService.getStacks(player, "repulsor_mine_kit")
end

type Mine = {
	part: BasePart,
	owner: Player,
	expiresAt: number,
}

local MineService = {}

local mineFolder: Folder
local mines: { Mine } = {}
local nextDropAt: { [Player]: number } = {}

local function mineInterval(stacks: number): number
	local cfg = Config.Items.Mine
	return math.max(cfg.BaseInterval - (stacks - 1) * cfg.IntervalPerStack, cfg.MinInterval)
end

local function mineDamage(stacks: number): number
	local cfg = Config.Items.Mine
	return math.min(cfg.BaseDamage + (stacks - 1) * cfg.DamagePerStack, cfg.MaxDamage)
end

local function removeMine(index: number)
	mines[index].part:Destroy()
	mines[index] = mines[#mines]
	mines[#mines] = nil
end

local function detonate(mine: Mine)
	local cfg = Config.Items.Mine
	local center = mine.part.Position
	local damage = mineDamage(mineStacks(mine.owner))

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(2, 2, 2)
	flash.Position = center
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(120, 180, 255)
	flash.Parent = mineFolder
	TweenService
		:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * cfg.BlastRadius * 2,
			Transparency = 1,
		})
		:Play()
	task.delay(0.4, function()
		flash:Destroy()
	end)

	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				if (root.Position - center).Magnitude <= cfg.BlastRadius then
					ItemEffectService.dealDamage(mine.owner, humanoid, damage, root.Position, "hit")
				end
			end
		end
	end
end

local function dropMine(owner: Player, root: BasePart)
	local cfg = Config.Items.Mine

	local ownedCount = 0
	for _, mine in mines do
		if mine.owner == owner then
			ownedCount += 1
		end
	end
	if ownedCount >= cfg.MaxMines then
		for index, mine in mines do
			if mine.owner == owner then
				removeMine(index)
				break
			end
		end
	end

	-- Behind the player relative to facing.
	local behind = root.Position - root.CFrame.LookVector * 6
	local result = workspace:Raycast(behind + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0))
	local groundY = if result then result.Position.Y else root.Position.Y - 2.5

	local part = Instance.new("Part")
	part.Name = "RepulsorMine"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2, 2)
	part.CFrame = CFrame.new(Vector3.new(behind.X, groundY + 0.2, behind.Z))
		* CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(96, 150, 220)
	part.Parent = mineFolder

	table.insert(mines, {
		part = part :: BasePart,
		owner = owner,
		expiresAt = os.clock() + cfg.Lifetime,
	})
end

local function onHeartbeat()
	if PauseService.isPaused() then
		return
	end
	local cfg = Config.Items.Mine
	local now = os.clock()

	-- Drop timers per owning player.
	for _, player in Players:GetPlayers() do
		local stacks = mineStacks(player)
		if stacks == 0 then
			nextDropAt[player] = nil
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local at = nextDropAt[player]
		if not at then
			nextDropAt[player] = now + mineInterval(stacks)
		elseif now >= at then
			nextDropAt[player] = now + mineInterval(stacks)
			dropMine(player, root)
		end
	end

	-- Trigger / expiry.
	for index = #mines, 1, -1 do
		local mine = mines[index]
		if now >= mine.expiresAt or not mine.part.Parent then
			removeMine(index)
			continue
		end
		local center = mine.part.Position
		local triggered = false
		for _, model in CollectionService:GetTagged(ENEMY_TAG) do
			if model:IsA("Model") then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if humanoid and humanoid.Health > 0 and root then
					if (root.Position - center).Magnitude <= cfg.TriggerRadius then
						triggered = true
						break
					end
				end
			end
		end
		if triggered then
			detonate(mine)
			removeMine(index)
		end
	end
end

function MineService.reset()
	for _, mine in mines do
		mine.part:Destroy()
	end
	table.clear(mines)
	table.clear(nextDropAt)
	if mineFolder then
		mineFolder:ClearAllChildren()
	end
end

function MineService.init()
	mineFolder = Instance.new("Folder")
	mineFolder.Name = "Mines"
	mineFolder.Parent = workspace
	RunService.Heartbeat:Connect(onHeartbeat)

	Players.PlayerRemoving:Connect(function(player: Player)
		nextDropAt[player] = nil
	end)
end

return MineService
