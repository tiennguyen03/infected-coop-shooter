--!strict
-- Air Support Authorization item: ItemEffectService counts credited kills
-- and calls strike() through the registered handler. A strike targets the
-- densest Infected cluster near the player: red warning marker, short
-- delay, then area damage. Strike kills credit the player, so they feed
-- drones and further strikes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local ItemEffectService = require(script.Parent.ItemEffectService)

local ENEMY_TAG = "Enemy"

local AirStrikeService = {}

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

-- The cluster center is the enemy with the most other enemies inside the
-- blast radius around it.
local function findClusterCenter(playerPosition: Vector3): Vector3?
	local cfg = Config.Items.AirSupport
	local candidates = enemyRootsNear(playerPosition, cfg.SearchRange)
	if #candidates == 0 then
		return nil
	end
	local bestRoot = candidates[1]
	local bestCount = -1
	for _, root in candidates do
		local count = 0
		for _, other in candidates do
			if (other.Position - root.Position).Magnitude <= cfg.BlastRadius then
				count += 1
			end
		end
		if count > bestCount then
			bestCount = count
			bestRoot = root
		end
	end
	return bestRoot.Position
end

local function detonate(player: Player, center: Vector3)
	local cfg = Config.Items.AirSupport

	-- Stock Explosion for the flash and boom only — zeroed radius/pressure
	-- so it can't hurt anyone; damage is applied manually below.
	local boom = Instance.new("Explosion")
	boom.Position = center
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace

	-- Blast visual: expanding fading sphere.
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
	blast.Parent = workspace
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
			ItemEffectService.dealDamage(player, humanoid, cfg.BlastDamage, root.Position, "hit")
		end
	end
end

function AirStrikeService.strike(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local center = findClusterCenter(root.Position)
	if not center then
		return
	end
	local cfg = Config.Items.AirSupport
	-- Drop the marker to the floor below the cluster (cluster center is at the
	-- enemies' torso height); the filtered cast ignores characters/enemies.
	local impact = GroundUtil.GetGroundPosition(center, 0.05)

	-- Red warning disc on the ground.
	local marker = Instance.new("Part")
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.4, cfg.BlastRadius * 2, cfg.BlastRadius * 2)
	marker.CFrame = CFrame.new(impact) * CFrame.Angles(0, 0, math.rad(90))
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(214, 69, 51)
	marker.Transparency = 0.45
	marker.Parent = workspace

	task.delay(cfg.WarningDelay, function()
		marker:Destroy()
		detonate(player, impact + Vector3.new(0, 2, 0))
	end)
end

function AirStrikeService.init()
	ItemEffectService.setAirStriker(function(player: Player)
		AirStrikeService.strike(player)
	end)
end

return AirStrikeService
