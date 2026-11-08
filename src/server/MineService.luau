--!strict
-- Tripline (Mines call-in, CallInService): the thrown line lands and Config.CallIns.Tripline
-- .Mines charges settle on an arc bulging away from the thrower. A mine blows when an
-- Infected steps within TriggerRadius (area damage through DamageService.dealDamage;
-- never the squad). Daisy Chain (command_detonation upgrade): CallInService asks
-- detonateAll when the owner presses the Tripline key with mines still armed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ENEMY_TAG = "Enemy"

type Mine = {
	part: BasePart,
	owner: Player,
	expiresAt: number,
}

local MineService = {}

local mineFolder: Folder
local mines: { Mine } = {}
local lastStep = 0

local function removeMine(index: number)
	mines[index].part:Destroy()
	mines[index] = mines[#mines]
	mines[#mines] = nil
end

local function detonate(mine: Mine)
	local cfg = Config.CallIns.Tripline
	local center = mine.part.Position
	WorldSounds.at(center, "callins", "tripline_blast")

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
					DamageService.dealDamage(mine.owner, humanoid, cfg.Damage, root.Position, "hit")
				end
			end
		end
	end
end

local function placeMine(owner: Player, at: Vector3)
	local cfg = Config.CallIns.Tripline
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

	local ground = GroundUtil.GetGroundPosition(at, 0)
	local part: BasePart = MeshAssets.clone("prop_repulsor_mine") or Instance.new("Part")
	part.Name = "Mine"
	if part:IsA("Part") then
		-- Placeholder when the mesh template is missing: a flat cylinder lying on the ground.
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.4, 2, 2)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(96, 150, 220)
		part.CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
	else
		part.CFrame = CFrame.new(ground + Vector3.new(0, part.Size.Y / 2, 0))
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = mineFolder

	table.insert(mines, {
		part = part :: BasePart,
		owner = owner,
		expiresAt = os.clock() + cfg.Lifetime,
	})
end

-- CallInService: the line lands at `point`; the mines settle on an arc of ArcRadius around
-- it spanning ArcDegrees, centred on `facing` (flat, away from the thrower).
function MineService.layArc(owner: Player, point: Vector3, facing: Vector3): boolean
	local cfg = Config.CallIns.Tripline
	local forward = Vector3.new(facing.X, 0, facing.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zAxis
	local count = cfg.Mines
	local span = math.rad(cfg.ArcDegrees)
	for index = 1, count do
		local t = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
		local angle = t * span
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(forward)
		placeMine(owner, point + direction * cfg.ArcRadius)
	end
	WorldSounds.at(point, "callins", "tripline_arm")
	return true
end

-- Mines still armed for `owner`.
function MineService.armedCount(owner: Player): number
	local count = 0
	for _, mine in mines do
		if mine.owner == owner then
			count += 1
		end
	end
	return count
end

-- Daisy Chain: every armed mine of `owner` blows now.
function MineService.detonateAll(owner: Player): number
	local blown = 0
	for index = #mines, 1, -1 do
		local mine = mines[index]
		if mine.owner == owner then
			detonate(mine)
			removeMine(index)
			blown += 1
		end
	end
	return blown
end

local function onHeartbeat()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, mine in mines do
			mine.expiresAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	local cfg = Config.CallIns.Tripline
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
	if mineFolder then
		mineFolder:ClearAllChildren()
	end
end

function MineService.init()
	Lifecycle.register("MineService", {
		onRunStart = MineService.reset,
		onPlayerRemoving = function(player: Player)
			for index = #mines, 1, -1 do
				if mines[index].owner == player then
					removeMine(index)
				end
			end
		end,
	})
	mineFolder = Instance.new("Folder")
	mineFolder.Name = "Mines"
	mineFolder.Parent = workspace
	lastStep = os.clock()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MineService
