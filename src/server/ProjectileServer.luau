--!strict
-- Server-authoritative projectiles. Clients only send a fire request; the
-- server validates it, simulates the projectile, and applies damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemEffectService = require(script.Parent.ItemEffectService)
local ItemService = require(script.Parent.ItemService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)

local ENEMY_TAG = "Enemy"
-- How far a reported fire origin may be from the character before the
-- request is rejected as suspicious.
local MAX_ORIGIN_OFFSET = 10

type Projectile = {
	part: BasePart,
	direction: Vector3,
	owner: Player,
	damage: number,
	speed: number,
	canProc: boolean, -- whether a hit rolls on-hit items (bleed/ricochet)
	expiresAt: number,
	raycastParams: RaycastParams,
}

export type FireOptions = {
	owner: Player, -- gets damage credit and item procs
	origin: Vector3,
	direction: Vector3, -- unit vector
	damage: number,
	speed: number?, -- defaults to the weapon projectile speed
	size: Vector3?,
	color: Color3?,
	canProc: boolean?, -- default true; false for chained/secondary hits
	exclude: { Instance }?, -- extra raycast exclusions beyond projectiles
}

local ProjectileServer = {}

local projectileFolder: Folder
local activeProjectiles: { Projectile } = {}
local lastFireTime: { [Player]: number } = {}
local shotCount: { [Player]: number } = {} -- for Shrapnel Magazine

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

-- Generic projectile spawner used by the player weapon and by drones.
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
		canProc = if options.canProc == nil then true else options.canProc,
		expiresAt = os.clock() + Config.Weapon.ProjectileLifetime,
		raycastParams = params,
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
			removeProjectile(index)
			continue
		end

		local step = projectile.direction * projectile.speed * deltaTime
		local result = workspace:Raycast(projectile.part.Position, step, projectile.raycastParams)
		if result then
			local humanoid = findEnemyHumanoid(result.Instance)
			if humanoid and humanoid.Health > 0 then
				ItemEffectService.dealDamage(
					projectile.owner,
					humanoid,
					projectile.damage,
					result.Position,
					"hit"
				)
				if projectile.canProc then
					ItemEffectService.onProjectileHit(
						projectile.owner,
						humanoid,
						result.Position,
						projectile.damage
					)
				end
			end
			removeProjectile(index)
		else
			projectile.part.CFrame += step
		end
	end
end

local function onFireRequest(player: Player, origin: unknown, direction: unknown)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	if PauseService.isPaused() then
		return
	end

	-- Server-side cooldown scaled by the player's fire rate multiplier;
	-- slight tolerance so honest clients at the rate limit aren't rejected
	-- by network jitter.
	local now = os.clock()
	local cooldown = Config.Weapon.FireCooldown
		/ PlayerStatsService.getMultiplier(player, "FireRate")
	if now - (lastFireTime[player] or 0) < cooldown * 0.9 then
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

	lastFireTime[player] = now
	local exclude: { Instance } = {}
	if character then
		table.insert(exclude, character)
	end
	local aim = direction.Unit
	local baseDamage = Config.Weapon.Damage * PlayerStatsService.getMultiplier(player, "Damage")
	ProjectileServer.fire({
		owner = player,
		origin = origin,
		direction = aim,
		damage = baseDamage,
		exclude = exclude,
	})

	-- Shrapnel Magazine: every Nth player shot fires extra angled rounds.
	-- Only player gun shots count (drones call fire() directly).
	local count = (shotCount[player] or 0) + 1
	shotCount[player] = count
	local shrapStacks = ItemService.getStacks(player, "shrapnel_magazine")
	if shrapStacks > 0 and count % Config.Items.Shrapnel.ShotsPerBurst == 0 then
		local extra = math.min(1 + shrapStacks, Config.Items.Shrapnel.MaxExtra)
		local maxAngle = math.rad(math.min(8 + (extra - 2) * 2, 16))
		for i = 1, extra do
			-- Spread evenly across [-maxAngle, +maxAngle].
			local t = if extra == 1 then 0 else (i - 1) / (extra - 1) * 2 - 1
			local spreadDir = (CFrame.Angles(0, t * maxAngle, 0) * CFrame.new(aim)).Position
			ProjectileServer.fire({
				owner = player,
				origin = origin,
				direction = spreadDir.Unit,
				damage = baseDamage * Config.Items.Shrapnel.DamageFactor,
				color = Color3.fromRGB(255, 170, 90),
				exclude = exclude,
			})
		end
	end
end

function ProjectileServer.reset()
	for _, projectile in activeProjectiles do
		projectile.part:Destroy()
	end
	table.clear(activeProjectiles)
	table.clear(shotCount)
	-- Sweep any stray part not in the table (guards a 1-frame fire/reset race).
	if projectileFolder then
		projectileFolder:ClearAllChildren()
	end
end

function ProjectileServer.init()
	projectileFolder = Instance.new("Folder")
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = workspace

	Remotes.get("FireWeapon").OnServerEvent:Connect(onFireRequest)
	RunService.Heartbeat:Connect(stepProjectiles)

	Players.PlayerRemoving:Connect(function(player)
		lastFireTime[player] = nil
		shotCount[player] = nil
	end)
end

return ProjectileServer
