--!strict
-- Server-authoritative shooting. The player's rifle is hitscan: the client
-- sends a fire request, the server validates it (alive or Last Stand, rate, a round in the
-- magazine: LoadoutService), applies the weapon's spread cone, raycasts once and lands the
-- damage the same frame (a Head hit is a headshot). Through-and-Through carries the round
-- into the next Infected; Hollow Point staggers the one it hit. Drones still fly simulated
-- projectiles through ProjectileServer.fire.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Spread = require(ReplicatedStorage.Shared.Rules.Spread)
local ShotCone = require(ReplicatedStorage.Shared.ShotCone)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local EnemyService = require(script.Parent.EnemyService)
local KitService = require(script.Parent.KitService)
local DamageService = require(script.Parent.DamageService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ENEMY_TAG = "Enemy"
-- How far a reported fire origin may be from the character before the
-- request is rejected as suspicious.
local MAX_ORIGIN_OFFSET = 10
-- Folders a player's round never hits (effects, pickups, the squad's bots).
local PASS_THROUGH_FOLDERS = {
	"Resupply",
	"ResupplyCards",
	"InfectedProjectiles",
	"SquadBots",
	"Drones",
	"Mines",
	"FirePools",
	"KitEffects",
	"CallInEffects",
	"StrikeEffects",
}

type Projectile = {
	part: BasePart,
	direction: Vector3,
	owner: Player,
	damage: number,
	speed: number,
	expiresAt: number,
	raycastParams: RaycastParams,
	-- A rocket: called where it hits (or where it runs out of flight) instead of the direct
	-- damage; `humanoid` is the Infected it struck, if any.
	onImpact: ((position: Vector3, humanoid: Humanoid?) -> ())?,
}

export type FireOptions = {
	owner: Player, -- gets damage credit
	origin: Vector3,
	direction: Vector3, -- unit vector
	damage: number,
	speed: number?, -- defaults to the weapon projectile speed
	size: Vector3?,
	color: Color3?,
	exclude: { Instance }?, -- extra raycast exclusions beyond projectiles
	lifetime: number?, -- seconds before it despawns (default Config.Weapon.ProjectileLifetime)
	onImpact: ((position: Vector3, humanoid: Humanoid?) -> ())?,
}

local ProjectileServer = {}

local projectileFolder: Folder
local tracerRemote: RemoteEvent
local activeProjectiles: { Projectile } = {}
local lastFireTime: { [Player]: number } = {}
-- Bloom (the gun's Bloom* numbers): extra spread in degrees per player, as of lastFireTime.
local bloom: { [Player]: number } = {}

local function findEnemyHumanoid(hit: Instance): Humanoid?
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, ENEMY_TAG) then
			return model:FindFirstChildOfClass("Humanoid")
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function createProjectilePart(options: FireOptions): BasePart
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = options.size or Config.Weapon.ProjectileSize
	part.CFrame = CFrame.lookAt(options.origin, options.origin + options.direction)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = options.color or Color3.fromRGB(255, 200, 80)
	part.Parent = projectileFolder
	return part
end

-- Generic projectile spawner (drones).
function ProjectileServer.fire(options: FireOptions)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { projectileFolder }
	if options.exclude then
		for _, instance in options.exclude do
			table.insert(exclude, instance)
		end
	end
	params.FilterDescendantsInstances = exclude

	table.insert(activeProjectiles, {
		part = createProjectilePart(options),
		direction = options.direction,
		owner = options.owner,
		damage = options.damage,
		speed = options.speed or Config.Weapon.ProjectileSpeed,
		expiresAt = os.clock() + (options.lifetime or Config.Weapon.ProjectileLifetime),
		raycastParams = params,
		onImpact = options.onImpact,
	})
end

local function removeProjectile(index: number)
	local projectile = activeProjectiles[index]
	projectile.part:Destroy()
	-- Swap-remove keeps the update loop O(n) without table.remove shifting.
	activeProjectiles[index] = activeProjectiles[#activeProjectiles]
	activeProjectiles[#activeProjectiles] = nil
end

local function stepProjectiles(deltaTime: number)
	if PauseService.isPaused() then
		return
	end
	for index = #activeProjectiles, 1, -1 do
		local projectile = activeProjectiles[index]
		if os.clock() >= projectile.expiresAt then
			local onImpact = projectile.onImpact
			local at = projectile.part.Position
			removeProjectile(index)
			if onImpact then
				onImpact(at, nil)
			end
			continue
		end

		local step = projectile.direction * projectile.speed * deltaTime
		local result = workspace:Raycast(projectile.part.Position, step, projectile.raycastParams)
		if result then
			local humanoid = findEnemyHumanoid(result.Instance)
			local onImpact = projectile.onImpact
			if onImpact then
				removeProjectile(index)
				onImpact(
					result.Position,
					if humanoid and humanoid.Health > 0 then humanoid else nil
				)
				continue
			end
			if humanoid and humanoid.Health > 0 then
				DamageService.dealDamage(
					projectile.owner,
					humanoid,
					projectile.damage,
					result.Position,
					"hit"
				)
			end
			removeProjectile(index)
		else
			projectile.part.CFrame += step
		end
	end
end

-- A random direction inside the cone of `halfAngleDegrees` around `direction` (uniform
-- over the cone's disc, so shots do not bunch at the centre).
local function applySpread(direction: Vector3, halfAngleDegrees: number): Vector3
	return ShotCone.random(direction, halfAngleDegrees)
end

-- The damage multiplier for a hit on `part` of an Infected: a Head hit is a headshot,
-- scaled by the form's own HeadshotMultiplier when it has one, else the weapon's
-- (`headshotMultiplier`; the service rifle's when nil). BotService uses this too.
function ProjectileServer.hitMultiplier(
	part: Instance,
	humanoid: Humanoid,
	headshotMultiplier: number?
): (number, string)
	-- The Index's armour (IndexService): a plated part takes the round at the armoured rate
	-- (DamageService routes it to the plate); a limb whose plate is gone is exposed.
	if typeof(part:GetAttribute(Attributes.PlateHealth)) == "number" then
		return Config.Index.Warden.ArmouredMultiplier, "plate"
	end
	if part.Name ~= "Head" then
		if part:GetAttribute(Attributes.Exposed) == true then
			return Config.Index.Warden.ExposedMultiplier, "exposed"
		end
		return 1, "hit"
	end
	local model = humanoid.Parent
	local typeName = model and model:GetAttribute(Attributes.EnemyType)
	local definition = if typeof(typeName) == "string" then EnemyDefinitions[typeName] else nil
	local multiplier = (definition and definition.HeadshotMultiplier)
		or headshotMultiplier
		or WeaponDefinitions.get(WeaponDefinitions.DEFAULT).HeadshotMultiplier
	return multiplier, "headshot"
end

local function excludeList(character: Model?): { Instance }
	local exclude: { Instance } = { projectileFolder }
	if character then
		table.insert(exclude, character)
	end
	for _, name in PASS_THROUGH_FOLDERS do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	return exclude
end

-- One hitscan round: raycast, damage on an Infected hit (carrying on through `pierce` more
-- bodies), tracer to everyone else.
local function fireHitscan(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	damage: number,
	weapon: WeaponDefinitions.WeaponDefinition,
	pierce: number,
	stagger: boolean,
	exclude: { Instance }
)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = table.clone(exclude)
	params.FilterDescendantsInstances = filter
	local from = origin
	local remaining = weapon.Range
	local endPoint = origin + direction * weapon.Range
	local bodiesLeft = pierce
	while remaining > 0 do
		local result = workspace:Raycast(from, direction * remaining, params)
		if not result then
			break
		end
		endPoint = result.Position
		local humanoid = findEnemyHumanoid(result.Instance)
		if not humanoid or humanoid.Health <= 0 then
			break
		end
		local multiplier, kind =
			ProjectileServer.hitMultiplier(result.Instance, humanoid, weapon.HeadshotMultiplier)
		DamageService.dealDamage(
			player,
			humanoid,
			damage * multiplier,
			result.Position,
			kind,
			result.Instance
		)
		if stagger and humanoid.Health > 0 then
			EnemyService.stagger(humanoid, Config.Upgrades.HollowPoint.StaggerSeconds)
		end
		if bodiesLeft <= 0 then
			break
		end
		-- Through-and-Through: the round carries on past this body.
		bodiesLeft -= 1
		local model = humanoid.Parent
		if model then
			table.insert(filter, model)
			params.FilterDescendantsInstances = filter
		end
		remaining -= (result.Position - from).Magnitude
		from = result.Position
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			tracerRemote:FireClient(other, origin, endPoint, weapon.Sound)
		end
	end
end

-- A launcher's round (Config.Weapons.<id>.Explosive): a visible rocket at the gun's
-- ProjectileSpeed. A direct hit deals the gun's Damage to that Infected, then the blast
-- (KitService.blast, the frag's) hits everything in Radius. Other clients hear the launch.
local function fireRocket(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	weapon: WeaponDefinitions.WeaponDefinition,
	explosive: WeaponDefinitions.Explosive,
	exclude: { Instance }
)
	local speed = weapon.ProjectileSpeed or Config.Weapon.ProjectileSpeed
	ProjectileServer.fire({
		owner = player,
		origin = origin,
		direction = direction,
		damage = weapon.Damage,
		speed = speed,
		size = Config.Weapon.RocketSize,
		color = Config.Weapon.RocketColor,
		exclude = exclude,
		lifetime = weapon.Range / speed,
		onImpact = function(position: Vector3, humanoid: Humanoid?)
			if humanoid then
				DamageService.dealDamage(player, humanoid, weapon.Damage, position, "breach")
			end
			WorldSounds.at(position, "player_gear", "breach")
			KitService.blast(player, position, explosive)
		end,
	})
	for _, other in Players:GetPlayers() do
		if other ~= player then
			tracerRemote:FireClient(other, origin, origin, weapon.Sound)
		end
	end
end

local function onFireRequest(
	player: Player,
	origin: unknown,
	direction: unknown,
	aiming: unknown,
	pellets: unknown
)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if PauseService.isPaused() then
		return
	end
	-- Downed members cannot fire, unless Last Stand lets them shoot from the ground.
	local member = Squad.fromPlayer(player)
	if not member then
		return
	end
	local lastStand = false
	if not Squad.canAct(member) then
		if member.state == "Downed" and LoadoutService.hasUpgrade(player, "last_stand") then
			lastStand = true
		else
			return
		end
	end

	-- Server-side cooldown of the gun in hand; slight tolerance so honest clients at the
	-- rate limit aren't rejected by network jitter.
	local weapon = LoadoutService.getWeapon(player)
	local now = os.clock()
	if now - (lastFireTime[player] or 0) < weapon.FireCooldown * 0.9 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if (origin - root.Position).Magnitude > MAX_ORIGIN_OFFSET then
		return
	end
	if direction.Magnitude < 0.001 then
		return
	end
	-- The magazine: an empty one refuses the shot (the client asks for a reload).
	if not LoadoutService.consumeRound(player) then
		return
	end

	local previousShot = lastFireTime[player]
	lastFireTime[player] = now
	local exclude = excludeList(character)
	-- The client says whether it is aiming down sights; that only tightens the cone (the
	-- speed penalty is client-owned movement either way), so trusting it costs nothing.
	local spread = if aiming == true and not lastStand then weapon.AdsSpread else weapon.HipSpread
	-- Bloom (the gun's own numbers): recover what the pause since the previous shot earned,
	-- add this shot's kick. A swap carries the bloom over, capped at the new gun's max.
	local previous = math.min(bloom[player] or 0, weapon.BloomMax)
	local idle = now - (previousShot or now) - Config.Weapon.BloomRecoveryDelay
	if idle > 0 then
		previous = math.max(previous - idle * weapon.BloomRecovery, 0)
	end
	spread += previous
	bloom[player] = math.min(previous + weapon.BloomPerShot, weapon.BloomMax)
	player:SetAttribute(Attributes.Bloom, bloom[player])
	if lastStand then
		spread *= Config.Upgrades.LastStand.SpreadMultiplier
	end
	local baseDamage = weapon.Damage
	local pierce = weapon.Pierce or 0
	if LoadoutService.hasUpgrade(player, "through_and_through") then
		pierce += Config.Upgrades.ThroughAndThrough.Pierce
	end
	local stagger = LoadoutService.hasUpgrade(player, "hollow_point")
	local explosive = weapon.Explosive
	if explosive then
		fireRocket(player, origin, applySpread(direction.Unit, spread), weapon, explosive, exclude)
		return
	end
	-- A shotgun's pellets: the ones the client drew (so the tracers it shows are the hits),
	-- each checked against this cone; any missing or outside it is rolled here instead.
	local count = weapon.Pellets or 1
	local sent = if count > 1 and typeof(pellets) == "table" then pellets :: { unknown } else nil
	for index = 1, count do
		local aim = applySpread(direction.Unit, spread)
		local claimed = sent and sent[index]
		if typeof(claimed) == "Vector3" and claimed.Magnitude > 0.5 then
			local unit = claimed.Unit
			local off = ShotCone.angleDegrees(direction.Unit, unit)
			if Spread.allowed(off, spread, Config.Weapon.PelletTolerance) then
				aim = unit
			end
		end
		fireHitscan(player, origin, aim, baseDamage, weapon, pierce, stagger, exclude)
	end
end

function ProjectileServer.reset()
	for _, projectile in activeProjectiles do
		projectile.part:Destroy()
	end
	table.clear(activeProjectiles)
	-- Sweep any stray part not in the table (guards a 1-frame fire/reset race).
	if projectileFolder then
		projectileFolder:ClearAllChildren()
	end
end

-- One player's fire timing.
function ProjectileServer.resetPlayer(player: Player)
	lastFireTime[player] = nil
	bloom[player] = nil
	player:SetAttribute(Attributes.Bloom, 0)
end

function ProjectileServer.init()
	Lifecycle.register("ProjectileServer", {
		onRunStart = ProjectileServer.reset,
		onPlayerReset = ProjectileServer.resetPlayer,
		onPlayerRemoving = function(player: Player)
			lastFireTime[player] = nil
			bloom[player] = nil
		end,
	})
	projectileFolder = Instance.new("Folder")
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = workspace

	tracerRemote = Remotes.get("ShotTracer")
	Remotes.get("FireWeapon").OnServerEvent:Connect(onFireRequest)
	RunService.Heartbeat:Connect(stepProjectiles)
end

return ProjectileServer
