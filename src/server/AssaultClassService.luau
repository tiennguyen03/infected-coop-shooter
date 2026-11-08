--!strict
-- Assault class V1 (Sprint 15): the default and only class. Provides the
-- Combat Momentum passive (kill-stacking damage/speed via PlayerStatsService),
-- a Q Combat Dash, and an E Breach Charge. All abilities are server-validated
-- (alive, run not paused, cooldown); client cooldowns are display only.
-- Field upgrades (LoadoutService flags): Flare Straps leaves
-- fire pools along the dash (IncendiaryService), Smoke Dash hides the body from melee for
-- a moment after it (the CoverMoveUntil window), Bait Charge makes the breach charge a lure
-- with a longer fuse (EnemyService.setLure).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local EnemyService = require(script.Parent.EnemyService)
local IncendiaryService = require(script.Parent.IncendiaryService)
local DamageService = require(script.Parent.DamageService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local Squad = require(script.Parent.Squad)

local ENEMY_TAG = "Enemy"
local MOMENTUM_SOURCE = "assault_momentum"

local AssaultClassService = {}

local abilityUsedRemote: RemoteEvent

-- Combat Momentum per player.
local momentumStacks: { [Player]: number } = {}
local momentumExpires: { [Player]: number } = {}
-- Ability cooldown end times (os.clock).
local dashReadyAt: { [Player]: number } = {}
local breachReadyAt: { [Player]: number } = {}
-- Active breach charges to clear on reset.
local chargeFolder: Folder
-- For freezing gameplay timers during the item-selection soft pause.
local lastHeartbeatClock = os.clock()

----------------------------------------------------------------------
-- Combat Momentum
----------------------------------------------------------------------

local function applyMomentum(player: Player)
	local stacks = momentumStacks[player] or 0
	PlayerStatsService.setBonus(player, MOMENTUM_SOURCE, {
		Damage = stacks * Config.Assault.DamagePerStack,
		MoveSpeed = stacks * Config.Assault.MoveSpeedPerStack,
	})
	player:SetAttribute("MomentumStacks", stacks)
end

local function onCreditedKill(player: Player)
	local stacks = math.min((momentumStacks[player] or 0) + 1, Config.Assault.MaxMomentumStacks)
	momentumStacks[player] = stacks
	momentumExpires[player] = os.clock() + Config.Assault.MomentumDuration
	applyMomentum(player)
end

----------------------------------------------------------------------
-- Q — Combat Dash
----------------------------------------------------------------------

local function doDash(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	-- Dash along move input, else character facing.
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.05 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.05 then
		return
	end
	dir = dir.Unit

	-- Raycast-clamp the destination so we never dash through walls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, chargeFolder }
	local hit = workspace:Raycast(root.Position, dir * Config.Assault.DashDistance, params)
	local distance = if hit
		then math.max((hit.Position - root.Position).Magnitude - 2, 0)
		else Config.Assault.DashDistance
	local target = root.Position + dir * distance

	-- Quick slide via a short tween of the root CFrame (keeps the player grounded).
	local goalCFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
	TweenService:Create(
		root,
		TweenInfo.new(Config.Assault.DashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = goalCFrame }
	):Play()

	-- Flare Straps: burning pools along the path.
	if LoadoutService.hasUpgrade(player, "fire_trail") then
		IncendiaryService.spawnTrail(
			player,
			root.Position,
			target,
			Config.Upgrades.FireTrail.PoolsPerDash
		)
	end
	-- Smoke Dash: the Infected melee cannot find the body for a moment after the dash.
	if LoadoutService.hasUpgrade(player, "smoke_dash") then
		local smokeUntil = os.clock()
			+ Config.Assault.DashDuration
			+ Config.Upgrades.SmokeDash.ImmunitySeconds
		local current = (character:GetAttribute("CoverMoveUntil") :: number?) or 0
		character:SetAttribute("CoverMoveUntil", math.max(current, smokeUntil))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150), Color3.fromRGB(70, 70, 70))
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 6),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Lifetime = NumberRange.new(1, 1.6)
		smoke.Speed = NumberRange.new(3, 6)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Enabled = false
		smoke.Parent = root
		smoke:Emit(40)
		task.delay(2, function()
			smoke:Destroy()
		end)
	end

	-- Simple dust streak.
	local streak = Instance.new("Part")
	streak.Size = Vector3.new(1, 1, distance)
	streak.CFrame = CFrame.lookAt(root.Position + dir * (distance / 2), root.Position + dir)
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.Material = Enum.Material.Neon
	streak.Color = Color3.fromRGB(200, 220, 255)
	streak.Transparency = 0.5
	streak.Parent = chargeFolder
	TweenService:Create(streak, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	task.delay(0.35, function()
		streak:Destroy()
	end)
end

----------------------------------------------------------------------
-- E — Breach Charge
----------------------------------------------------------------------

local function detonate(player: Player, center: Vector3)
	local cfg = Config.Assault
	local boom = Instance.new("Explosion")
	boom.Position = center
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(3, 3, 3)
	flash.Position = center
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 150, 60)
	flash.Parent = chargeFolder
	TweenService
		:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * cfg.BreachRadius * 2,
			Transparency = 1,
		})
		:Play()
	task.delay(0.45, function()
		flash:Destroy()
	end)

	for _, model in workspace:GetDescendants() do
		if model:IsA("Model") and game:GetService("CollectionService"):HasTag(model, ENEMY_TAG) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				humanoid
				and humanoid.Health > 0
				and root
				and (root.Position - center).Magnitude <= cfg.BreachRadius
			then
				DamageService.dealDamage(
					player,
					humanoid,
					cfg.BreachDamage,
					root.Position,
					"breach"
				)
			end
		end
	end
end

local function doBreach(player: Player, requested: Vector3?)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local cfg = Config.Assault

	-- Land point: where the client aimed (hold E to see it), clamped to throw range and
	-- stopped short of walls; facing-forward when no aim came.
	local center = ThrowUtil.landingPoint(root, requested, cfg.BreachThrowDistance, {
		character,
		chargeFolder,
	}) + Vector3.new(0, 1, 0)
	-- Bait Charge: a longer fuse, and the Infected around walk to it until it blows.
	local fuse = cfg.BreachFuseTime
	if LoadoutService.hasUpgrade(player, "lure_charge") then
		local lure = Config.Upgrades.LureCharge
		fuse = lure.FuseTime
		EnemyService.setLure(center, lure.Radius, fuse)
	end

	-- Blinking charge.
	local charge = Instance.new("Part")
	charge.Name = "BreachCharge"
	charge.Shape = Enum.PartType.Ball
	charge.Size = Vector3.new(1.2, 1.2, 1.2)
	charge.Position = center
	charge.Anchored = true
	charge.CanCollide = false
	charge.CanQuery = false
	charge.Material = Enum.Material.Neon
	charge.Color = Color3.fromRGB(255, 80, 60)
	charge.Parent = chargeFolder

	-- Warning ring on the ground.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, cfg.BreachRadius * 2, cfg.BreachRadius * 2)
	ring.CFrame = CFrame.new(center - Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 90, 60)
	ring.Transparency = 0.55
	ring.Parent = chargeFolder

	task.spawn(function()
		local blinks = 4
		for _ = 1, blinks do
			charge.Transparency = 0.6
			task.wait(fuse / (blinks * 2))
			charge.Transparency = 0
			task.wait(fuse / (blinks * 2))
		end
		if charge.Parent then
			charge:Destroy()
		end
		if ring.Parent then
			ring:Destroy()
		end
		detonate(player, center)
	end)
end

----------------------------------------------------------------------
-- Request handling (server-authoritative)
----------------------------------------------------------------------

local function canAct(player: Player): boolean
	if PauseService.isPaused() then
		return false
	end
	local member = Squad.fromPlayer(player)
	return member ~= nil and Squad.canAct(member)
end

local function onUseAbility(player: Player, abilityName: unknown, target: unknown)
	if not canAct(player) then
		return
	end
	local now = os.clock()
	if abilityName == "dash" then
		if now < (dashReadyAt[player] or 0) then
			return
		end
		dashReadyAt[player] = now + Config.Assault.DashCooldown
		abilityUsedRemote:FireClient(player, "dash", Config.Assault.DashCooldown)
		doDash(player)
	elseif abilityName == "breach" then
		if now < (breachReadyAt[player] or 0) then
			return
		end
		breachReadyAt[player] = now + Config.Assault.BreachCooldown
		abilityUsedRemote:FireClient(player, "breach", Config.Assault.BreachCooldown)
		doBreach(player, if typeof(target) == "Vector3" then target else nil)
	end
end

local function onHeartbeat()
	local now = os.clock()
	local dt = now - lastHeartbeatClock
	lastHeartbeatClock = now

	-- During the run-end freeze, slide cooldown / momentum end times forward by the
	-- elapsed real time so no progress is made while the field is frozen.
	if PauseService.isPaused() then
		for player, readyAt in dashReadyAt do
			if readyAt > now then
				dashReadyAt[player] = readyAt + dt
			end
		end
		for player, readyAt in breachReadyAt do
			if readyAt > now then
				breachReadyAt[player] = readyAt + dt
			end
		end
		for player, expires in momentumExpires do
			if (momentumStacks[player] or 0) > 0 then
				momentumExpires[player] = expires + dt
			end
		end
		return
	end

	for player, expires in momentumExpires do
		if (momentumStacks[player] or 0) > 0 and now >= expires then
			momentumStacks[player] = 0
			applyMomentum(player)
		end
	end
end

function AssaultClassService.resetPlayer(player: Player)
	momentumStacks[player] = 0
	momentumExpires[player] = nil
	dashReadyAt[player] = nil
	breachReadyAt[player] = nil
	player:SetAttribute("MomentumStacks", 0)
	PlayerStatsService.setBonus(player, MOMENTUM_SOURCE, {})
end

-- Run state shared by everyone (breach charges and effects in the world).
function AssaultClassService.reset()
	if chargeFolder then
		chargeFolder:ClearAllChildren()
	end
end

function AssaultClassService.init()
	chargeFolder = Instance.new("Folder")
	chargeFolder.Name = "AssaultEffects"
	chargeFolder.Parent = workspace

	abilityUsedRemote = Remotes.get("AbilityUsed")
	Remotes.get("UseAbility").OnServerEvent:Connect(onUseAbility)
	DamageService.addKillListener(onCreditedKill)
	RunService.Heartbeat:Connect(onHeartbeat)

	Players.PlayerRemoving:Connect(function(player)
		momentumStacks[player] = nil
		momentumExpires[player] = nil
		dashReadyAt[player] = nil
		breachReadyAt[player] = nil
	end)
end

return AssaultClassService
