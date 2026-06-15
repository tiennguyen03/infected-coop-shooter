--!strict
-- Shock Coil item: while owned, periodically emits a pulse around the player
-- that damages and briefly slows nearby Infected. Slows restore the enemy's
-- BaseWalkSpeed attribute (set by EnemyService) and use a per-humanoid
-- generation so overlapping pulses never strand an enemy at reduced speed.

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

local ShockCoilService = {}

local nextPulseAt: { [Player]: number } = {}
local slowGeneration: { [Humanoid]: number } = {}

local function shockStacks(player: Player): number
	return ItemService.getStacks(player, "shock_coil")
end

local function cooldown(stacks: number): number
	local cfg = Config.Items.ShockCoil
	return math.max(cfg.BaseCooldown - (stacks - 1) * cfg.CooldownPerStack, cfg.MinCooldown)
end

local function damage(stacks: number): number
	local cfg = Config.Items.ShockCoil
	return math.min(cfg.BaseDamage + (stacks - 1) * cfg.DamagePerStack, cfg.MaxDamage)
end

local function applySlow(humanoid: Humanoid)
	local cfg = Config.Items.ShockCoil
	local base = (humanoid:GetAttribute("BaseWalkSpeed") :: number?) or humanoid.WalkSpeed
	local generation = (slowGeneration[humanoid] or 0) + 1
	slowGeneration[humanoid] = generation
	humanoid.WalkSpeed = base * cfg.SlowFactor
	task.delay(cfg.SlowDuration, function()
		if humanoid.Parent and slowGeneration[humanoid] == generation then
			humanoid.WalkSpeed = base
			slowGeneration[humanoid] = nil
		end
	end)
end

local function pulse(player: Player, root: BasePart, stacks: number)
	local cfg = Config.Items.ShockCoil
	local dmg = damage(stacks)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, cfg.Radius * 2, cfg.Radius * 2)
	ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 180, 255)
	ring.Transparency = 0.4
	ring.Parent = workspace
	TweenService
		:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		})
		:Play()
	task.delay(0.45, function()
		ring:Destroy()
	end)

	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local enemyRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and enemyRoot then
				if (enemyRoot.Position - root.Position).Magnitude <= cfg.Radius then
					ItemEffectService.dealDamage(player, humanoid, dmg, enemyRoot.Position, "hit")
					if humanoid.Health > 0 then
						applySlow(humanoid)
					end
				end
			end
		end
	end
end

local function onHeartbeat()
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local stacks = shockStacks(player)
		if stacks == 0 then
			nextPulseAt[player] = nil
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local at = nextPulseAt[player]
		if not at then
			nextPulseAt[player] = now + cooldown(stacks)
		elseif now >= at then
			nextPulseAt[player] = now + cooldown(stacks)
			pulse(player, root, stacks)
		end
	end
end

function ShockCoilService.reset()
	table.clear(nextPulseAt)
	table.clear(slowGeneration)
end

function ShockCoilService.init()
	RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextPulseAt[player] = nil
	end)
end

return ShockCoilService
