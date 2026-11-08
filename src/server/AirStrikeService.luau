--!strict
-- Anvil (Fire Mission call-in, CallInService): the thrown marker lands; after
-- Config.CallIns.Anvil.WarningDelay the battery drops Shells on it, ShellInterval apart,
-- each a BlastRadius area hit (DamageService.dealDamage, the Infected only). Walk It In
-- (walking_barrage upgrade): more shells, stepping Step studs along the throw direction.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)

local ENEMY_TAG = "Enemy"

local AirStrikeService = {}

local effectFolder: Folder
-- Bumped on reset so a mission from the last run never lands in the next.
local generation = 0

local function enemyRootsNear(position: Vector3, range: number): { BasePart }
	local roots = {}
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				if (root.Position - position).Magnitude <= range then
					table.insert(roots, root)
				end
			end
		end
	end
	return roots
end

local function detonate(player: Player, center: Vector3)
	local cfg = Config.CallIns.Anvil

	-- Stock Explosion for the flash and boom only: zeroed radius/pressure so it can't hurt
	-- anyone; damage is applied manually below.
	local boom = Instance.new("Explosion")
	boom.Position = center
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace

	local blast = Instance.new("Part")
	blast.Shape = Enum.PartType.Ball
	blast.Size = Vector3.new(4, 4, 4)
	blast.Position = center
	blast.Anchored = true
	blast.CanCollide = false
	blast.CanQuery = false
	blast.CanTouch = false
	blast.Material = Enum.Material.Neon
	blast.Color = Color3.fromRGB(255, 140, 40)
	blast.Parent = effectFolder
	TweenService
		:Create(blast, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * cfg.BlastRadius * 2,
			Transparency = 1,
		})
		:Play()
	task.delay(0.5, function()
		blast:Destroy()
	end)

	for _, root in enemyRootsNear(center, cfg.BlastRadius) do
		local model = root.Parent :: Model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			DamageService.dealDamage(player, humanoid, cfg.BlastDamage, root.Position, "hit")
		end
	end
end

local function marker(at: Vector3): BasePart
	local cfg = Config.CallIns.Anvil
	local disc = Instance.new("Part")
	disc.Name = "StrikeMarker"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, cfg.BlastRadius * 2, cfg.BlastRadius * 2)
	disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(214, 69, 51)
	disc.Transparency = 0.45
	disc.Parent = effectFolder
	return disc
end

-- Waits `seconds` of unpaused time (a mission in the air holds while paused).
local function waitUnpaused(seconds: number)
	local remaining = seconds
	while remaining > 0 do
		local dt = task.wait()
		if not PauseService.isPaused() then
			remaining -= dt
		end
	end
end

-- CallInService: shells land on `point`; `direction` is the flat throw direction the
-- barrage walks along with `walking` (Walk It In).
function AirStrikeService.fireMission(
	player: Player,
	point: Vector3,
	direction: Vector3,
	walking: boolean
): boolean
	local cfg = Config.CallIns.Anvil
	local shells = if walking then Config.Upgrades.WalkingBarrage.Shells else cfg.Shells
	local step = if walking then Config.Upgrades.WalkingBarrage.Step else 0
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis

	local impacts: { Vector3 } = {}
	local markers: { BasePart } = {}
	for index = 1, shells do
		local scatter = Vector3.new(
			(math.random() * 2 - 1) * cfg.Scatter,
			0,
			(math.random() * 2 - 1) * cfg.Scatter
		)
		local impact =
			GroundUtil.GetGroundPosition(point + flat * step * (index - 1) + scatter, 0.05)
		table.insert(impacts, impact)
		table.insert(markers, marker(impact))
	end

	local thisGeneration = generation
	task.spawn(function()
		waitUnpaused(cfg.WarningDelay)
		for index, impact in impacts do
			if thisGeneration ~= generation then
				return
			end
			local disc = markers[index]
			if disc.Parent then
				disc:Destroy()
			end
			detonate(player, impact + Vector3.new(0, 2, 0))
			if index < #impacts then
				waitUnpaused(cfg.ShellInterval)
			end
		end
	end)
	return true
end

function AirStrikeService.reset()
	generation += 1
	if effectFolder then
		effectFolder:ClearAllChildren()
	end
end

function AirStrikeService.init()
	effectFolder = Instance.new("Folder")
	effectFolder.Name = "StrikeEffects"
	effectFolder.Parent = workspace
end

return AirStrikeService
