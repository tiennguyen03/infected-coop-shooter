--!strict
-- The soldier's kit beside the guns (docs/PROGRESSION.md > Loadout; replaced the Assault
-- class's dash, breach charge and Combat Momentum): Q swaps long gun and sidearm
-- (LoadoutService.swap), G throws a grenade, F shoves, V uses a stim (Config.Keys; the client
-- sends the kind, never the key). The UseAbility remote
-- carries the kind (Messages.Ability); everything is server-validated (standing, not paused,
-- a grenade or stim left, the shove's cooldown) and the counts live on LoadoutService.
-- Bait Charge (lure_charge upgrade): a frag lures the Infected around it until it blows.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local DamageService = require(script.Parent.DamageService)
local EnemyService = require(script.Parent.EnemyService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local ThrowWindUp = require(script.Parent.ThrowWindUp)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ENEMY_TAG = "Enemy"
local FRAG_COLOR = Color3.fromRGB(255, 120, 60)

type FragSettings = {
	ThrowDistance: number,
	Flight: number?, -- seconds in the air; Config.Grenade.Flight when the row has none
	FuseTime: number,
	Radius: number,
	Damage: number,
	ShakePower: number?,
}
-- What a blast needs: the frag's settings, or a launcher row's Explosive.
type BlastSettings = { Radius: number, Damage: number, ShakePower: number? }

local KitService = {}

local abilityUsedRemote: RemoteEvent
local effectsFolder: Folder
-- os.clock times, per player; shifted forward while the field is frozen.
local shoveReadyAt: { [Player]: number } = {}
local throwReadyAt: { [Player]: number } = {}
local stimUntil: { [Player]: number } = {}
local lastHeartbeat = os.clock()

local function standing(player: Player): (Squad.Member?, BasePart?)
	if PauseService.isPaused() then
		return nil, nil
	end
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) or not member.root then
		return nil, nil
	end
	return member, member.root
end

local function enemiesNear(
	center: Vector3,
	radius: number
): { { humanoid: Humanoid, root: BasePart } }
	local found = {}
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if
			humanoid
			and humanoid.Health > 0
			and root
			and root:IsA("BasePart")
			and (root.Position - center).Magnitude <= radius
		then
			table.insert(found, { humanoid = humanoid, root = root })
		end
	end
	return found
end

----------------------------------------------------------------------
-- G: grenade (the frag; the old breach charge's throw and blast)
----------------------------------------------------------------------

-- The frag's blast, shared by anything that explodes on a soldier's behalf (the Goose's
-- rocket): a flash, the screen shake, `Damage` to every Infected within `Radius`. No friendly
-- fire (the call-ins' rule). `player` is nil for a bot's frag (no kill credit, no hit marker).
function KitService.blast(player: Player?, center: Vector3, settings: BlastSettings)
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
	-- Tagged for the client screen shake (CameraController).
	flash:SetAttribute(
		Attributes.BlastPower,
		settings.ShakePower or Config.Camera.Shake.DefaultPower
	)
	CollectionService:AddTag(flash, Attributes.BlastTag)
	flash.Parent = effectsFolder
	TweenService
		:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * settings.Radius * 2,
			Transparency = 1,
		})
		:Play()
	task.delay(0.45, function()
		flash:Destroy()
	end)

	for _, enemy in enemiesNear(center, settings.Radius) do
		DamageService.dealDamage(
			player,
			enemy.humanoid,
			settings.Damage,
			enemy.root.Position,
			"breach"
		)
	end
end

-- The throw itself, for a player (releaseGrenade, after its checks) or a bot (BotService,
-- `player` nil; it counts its own grenades): grenade `grenadeId` leaves `character` toward
-- `requested`, flies for its Flight (ThrowFX on the clients), lands (ThrowUtil), blinks
-- through its fuse and blows (KitService.blast).
function KitService.throwFrag(
	player: Player?,
	character: Model,
	root: BasePart,
	requested: Vector3?,
	grenadeId: string?
)
	local definition = WeaponDefinitions.grenade(grenadeId)
	local settings = (Config.Grenade :: any)[definition.ConfigKey] :: FragSettings
	local center = ThrowUtil.landingPoint(root, requested, settings.ThrowDistance, {
		character,
		effectsFolder,
	}) + Vector3.new(0, 1, 0)
	local flight = settings.Flight or Config.Grenade.Flight
	WorldSounds.at(center, "callins", "callin_throw")
	if player then
		ThrowWindUp.thrown(player, center, flight, FRAG_COLOR)
	end
	-- Bait Charge: a longer fuse, and the Infected around walk to it until it blows.
	local fuse = settings.FuseTime
	if player and LoadoutService.hasUpgrade(player, "lure_charge") then
		local lure = Config.Upgrades.LureCharge
		fuse = lure.FuseTime
		EnemyService.setLure(center, lure.Radius, flight + fuse)
	end

	local grenade = Instance.new("Part")
	grenade.Name = "Grenade"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(0.8, 0.8, 0.8)
	grenade.Position = center
	grenade.Anchored = true
	grenade.CanCollide = false
	grenade.CanQuery = false
	grenade.Material = Enum.Material.Neon
	grenade.Color = FRAG_COLOR

	-- Warning ring on the ground: the blast radius.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, settings.Radius * 2, settings.Radius * 2)
	ring.CFrame = CFrame.new(center - Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = FRAG_COLOR
	ring.Transparency = 0.6
	ring.Parent = effectsFolder

	task.spawn(function()
		PauseService.wait(flight) -- in the air; the ring already warns where it lands
		if not ring.Parent then
			return -- a run start cleared the field
		end
		grenade.Parent = effectsFolder
		local blinks = 4
		for _ = 1, blinks do
			grenade.Transparency = 0.6
			task.wait(fuse / (blinks * 2))
			grenade.Transparency = 0
			task.wait(fuse / (blinks * 2))
		end
		grenade:Destroy()
		ring:Destroy()
		WorldSounds.at(center, "player_gear", "breach")
		KitService.blast(player, center, settings)
	end)
end

-- The release (ThrowWindUp, the throw clip's release): the grenade is spent here, flies
-- from the hand for its Flight and its fuse starts when it lands.
local function releaseGrenade(player: Player, requested: Vector3?)
	local member, root = standing(player)
	local character = player.Character
	if not member or not root or not character then
		return
	end
	if not LoadoutService.useGrenade(player) then
		return
	end
	KitService.throwFrag(player, character, root, requested, LoadoutService.getGrenade(player))
end

-- G: the wind-up starts (one throw at a time, ThrowGap apart, a grenade in the pouch); the
-- grenade leaves the hand, and the pouch, at the release.
local function throwGrenade(player: Player, requested: Vector3?)
	local member = standing(player)
	if not member then
		return
	end
	local now = os.clock()
	if now < (throwReadyAt[player] or 0) or LoadoutService.grenadesLeft(player) <= 0 then
		return
	end
	local began = ThrowWindUp.begin(player, function()
		releaseGrenade(player, requested)
	end)
	if began then
		throwReadyAt[player] = now + Config.Grenade.ThrowGap
	end
end

----------------------------------------------------------------------
-- Shove
----------------------------------------------------------------------

local function shove(player: Player)
	local member, root = standing(player)
	local character = player.Character
	if not member or not root or not character then
		return
	end
	local now = os.clock()
	if now < (shoveReadyAt[player] or 0) then
		return
	end
	local settings = Config.Shove
	shoveReadyAt[player] = now + settings.Cooldown
	abilityUsedRemote:FireClient(player, Messages.Ability.Shove, settings.Cooldown)
	WorldSounds.on(root, "player_gear", "vault", "Move")

	local look = root.CFrame.LookVector
	local facing = Vector3.new(look.X, 0, look.Z)
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.zAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, enemy in enemiesNear(root.Position, settings.Reach) do
		local offset = enemy.root.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local direction = if flat.Magnitude > 0.1 then flat.Unit else facing
		if direction:Dot(facing) < settings.ConeDot then
			continue
		end
		local humanoid = enemy.humanoid
		DamageService.dealDamage(player, humanoid, settings.Damage, enemy.root.Position, "hit")
		local model = humanoid.Parent
		local typeName = model and model:GetAttribute(Attributes.EnemyType)
		local definition = if typeof(typeName) == "string" then EnemyDefinitions[typeName] else nil
		-- An Index host does not get pushed around.
		if humanoid.Health <= 0 or (definition and definition.Boss) then
			continue
		end
		EnemyService.stagger(humanoid, settings.StaggerSeconds)
		-- Driven back, stopped short of a wall.
		params.FilterDescendantsInstances = { character, model :: Instance, effectsFolder }
		local hit = workspace:Raycast(enemy.root.Position, direction * settings.Push, params)
		local distance = if hit
			then math.max((hit.Position - enemy.root.Position).Magnitude - 1.5, 0)
			else settings.Push
		local goal = enemy.root.CFrame + direction * distance
		TweenService:Create(
			enemy.root,
			TweenInfo.new(settings.PushTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = goal }
		):Play()
	end
end

----------------------------------------------------------------------
-- Stim
----------------------------------------------------------------------

-- The dose itself, for a player (stim, after its checks) or a bot (BotService; it counts
-- its own stims): Config.Stim.Heal over Duration on `member`.
function KitService.dose(member: Squad.Member)
	local humanoid = member.humanoid
	if not humanoid then
		return
	end
	local settings = Config.Stim
	if member.root then
		WorldSounds.on(member.root, "player_gear", "revive", "Gear")
	end
	local perTick = settings.Heal / settings.Ticks
	task.spawn(function()
		for _ = 1, settings.Ticks do
			task.wait(settings.Duration / settings.Ticks)
			while PauseService.isPaused() do
				task.wait(0.1)
			end
			-- Going down or dying stops the dose.
			if humanoid.Health <= 0 or not Squad.isAlive(member) then
				return
			end
			humanoid.Health = math.min(humanoid.Health + perTick, humanoid.MaxHealth)
		end
	end)
end

local function stim(player: Player)
	local member = standing(player)
	local humanoid = member and member.humanoid
	if not member or not humanoid then
		return
	end
	local now = os.clock()
	if now < (stimUntil[player] or 0) or humanoid.Health >= humanoid.MaxHealth then
		return -- one stim at a time; a full bar wastes none
	end
	if not LoadoutService.useStim(player) then
		return
	end
	stimUntil[player] = now + Config.Stim.Duration
	KitService.dose(member)
end

----------------------------------------------------------------------
-- Request handling
----------------------------------------------------------------------

local function onUseAbility(player: Player, kind: unknown, target: unknown)
	if kind == Messages.Ability.Swap then
		LoadoutService.swap(player)
	elseif kind == Messages.Ability.Grenade then
		throwGrenade(player, if typeof(target) == "Vector3" then target else nil)
	elseif kind == Messages.Ability.Shove then
		shove(player)
	elseif kind == Messages.Ability.Stim then
		stim(player)
	end
end

-- The run-end freeze: slide the cooldowns forward so no time passes while frozen.
local function onHeartbeat()
	local now = os.clock()
	local dt = now - lastHeartbeat
	lastHeartbeat = now
	if not PauseService.isPaused() then
		return
	end
	for _, timers in { shoveReadyAt, throwReadyAt, stimUntil } do
		for player, readyAt in timers do
			if readyAt > now then
				timers[player] = readyAt + dt
			end
		end
	end
end

local function forget(player: Player)
	shoveReadyAt[player] = nil
	throwReadyAt[player] = nil
	stimUntil[player] = nil
end

function KitService.init()
	Lifecycle.register("KitService", {
		onRunStart = function()
			effectsFolder:ClearAllChildren()
		end,
		onPlayerReset = forget,
		onPlayerRemoving = forget,
	})
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "KitEffects"
	effectsFolder.Parent = workspace

	abilityUsedRemote = Remotes.get("AbilityUsed")
	Remotes.get("UseAbility").OnServerEvent:Connect(onUseAbility)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return KitService
