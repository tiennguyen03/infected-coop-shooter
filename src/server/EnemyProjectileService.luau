--!strict
-- Lobbed Infected projectiles (the Hocker's spit) and the caustic puddles they leave.
-- A spit is kinematic: the launch velocity is solved for a fixed flight time so the arc
-- clears low cover and lands where the target stood (plus a half lead on their velocity, so
-- a moving player can step out of it). Impact splashes every player in range and, when the
-- definition asks for one, leaves a puddle that ticks damage on anyone standing in it.
-- Player damage from any Infected goes through `damagePlayer` (difficulty, then the
-- Armour Plate shield soaks what it can: LoadoutService.absorb).
-- Looks: with Config.Enemies.SpitFX.Enabled the server makes no parts at all; it tells every
-- client what happened (Remotes EnemySpit) and each draws the glob, the splat and the pool
-- itself (client SpitFX). Off, the server makes the old ball and disc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DifficultyService = require(script.Parent.DifficultyService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local WorldSounds = require(script.Parent.WorldSounds)
local Lifecycle = require(script.Parent.Lifecycle)

-- Last pain grunt per player humanoid (weak keys: a dead character drops out).
local lastHurtVoiceAt: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any

export type Projectile = EnemyDefinitions.ProjectileSpec

type Spit = {
	id: number, -- names the spit to the clients drawing it
	part: BasePart?, -- the plain ball; nil while clients draw it (SpitFX)
	origin: Vector3,
	velocity: Vector3,
	launchedAt: number,
	expiresAt: number,
	lastPosition: Vector3,
	spec: Projectile,
	damage: number,
	params: RaycastParams,
}

type Puddle = {
	part: BasePart?, -- the plain disc; nil while clients draw it (SpitFX)
	center: Vector3,
	radius: number,
	damagePerSecond: number,
	expiresAt: number,
	nextTickAt: number,
}

local PUDDLE_TICK = 0.5
local PUDDLE_HEIGHT = 0.2

local EnemyProjectileService = {}

local folder: Folder
local spitRemote: RemoteEvent
local nextSpitId = 0

local function fxOn(): boolean
	return Config.Enemies.SpitFX.Enabled
end
local spits: { Spit } = {}
local puddles: { Puddle } = {}

-- The caustic puddle `position` stands in, as (centre, radius); nil when it is in none.
-- BotService: a bot steps out of it.
function EnemyProjectileService.puddleAt(position: Vector3): (Vector3?, number?)
	for _, puddle in puddles do
		local offset = position - puddle.center
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= puddle.radius
			and math.abs(offset.Y) < 6
		then
			return puddle.center, puddle.radius
		end
	end
	return nil, nil
end

-- The one entry point for Infected damage to a player: difficulty scaling, then the
-- player's Armour Plate shield takes the hit before health. `kind` "melee" is a limb or a
-- claw: a body inside its roll / vault / climb window (CoverMoveService, CoverMoveUntil)
-- is missed. Ground attacks, projectiles and puddles pass no kind and always land.
function EnemyProjectileService.damagePlayer(humanoid: Humanoid, amount: number, kind: string?)
	if humanoid.Health <= 0 then
		return
	end
	local character = humanoid.Parent
	if kind == "melee" and character then
		local coverUntil = character:GetAttribute(Attributes.CoverMoveUntil) :: number?
		if coverUntil and os.clock() < coverUntil then
			return
		end
	end
	local member = Squad.fromHumanoid(humanoid)
	-- A downed body takes no damage (decision #3: a rescue, not a snack).
	if member and member.state ~= "Alive" then
		return
	end
	-- Dev god mode (DevTestService "God"): Studio / creator only.
	if member and member.owner and member.owner:GetAttribute(Attributes.DevGod) == true then
		return
	end
	local dealt = amount * DifficultyService.getDamageMultiplier()
	if member and member.owner then
		LoadoutService.noteCombat(member.owner) -- in contact: the Arms Room stays shut
		dealt = LoadoutService.absorb(member.owner, dealt)
		if dealt <= 0 then
			return
		end
	end
	if member and humanoid.Health - dealt <= 0 then
		Squad.down(member)
		return
	end
	humanoid:TakeDamage(dealt)
	-- A grunt from the body (3D, the squad hears who got hit), one per burst of hits.
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local now = os.clock()
	if
		head
		and humanoid.Health > 0
		and now - (lastHurtVoiceAt[humanoid] or 0) >= Config.Audio.Voice.HurtCooldown
	then
		lastHurtVoiceAt[humanoid] = now
		WorldSounds.voice(head, "player_hits", "hurt")
	end
end

-- Every living squad body (players and bots) a splash or puddle can hurt.
local function livePlayerHumanoids(): { { humanoid: Humanoid, root: BasePart } }
	local result = {}
	for _, member in Squad.living() do
		local humanoid, root = member.humanoid, member.root
		if humanoid and root then
			table.insert(result, { humanoid = humanoid, root = root })
		end
	end
	return result
end

local function splash(position: Vector3, radius: number, damage: number)
	for _, target in livePlayerHumanoids() do
		if (target.root.Position - position).Magnitude <= radius then
			EnemyProjectileService.damagePlayer(target.humanoid, damage)
		end
	end
end

-- Returns the ground CFrame the puddle lies on (nil: this projectile leaves none).
local function spawnPuddle(position: Vector3, spec: Projectile): CFrame?
	local puddleSpec = spec.Puddle
	if not puddleSpec then
		return nil
	end
	local ground = GroundUtil.GetGroundCFrame(position, PUDDLE_HEIGHT / 2)
	local part: BasePart? = nil
	if not fxOn() then
		local disc = Instance.new("Part")
		disc.Name = "CausticPuddle"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(PUDDLE_HEIGHT, puddleSpec.Radius * 2, puddleSpec.Radius * 2)
		disc.CFrame = ground * CFrame.Angles(0, 0, math.rad(90))
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.CastShadow = false
		disc.Material = Enum.Material.Neon
		disc.Color = spec.Color
		disc.Transparency = 0.45
		disc.Parent = folder
		part = disc
	end
	-- Perf cap: the oldest puddle goes when a new one would exceed Config.Enemies.MaxPuddles
	-- (SpitFX drops its oldest pool by the same rule).
	if #puddles >= Config.Enemies.MaxPuddles then
		local oldest = puddles[1].part
		if oldest then
			oldest:Destroy()
		end
		table.remove(puddles, 1)
	end
	local puddle: Puddle = {
		part = part,
		center = ground.Position,
		radius = puddleSpec.Radius,
		damagePerSecond = puddleSpec.DamagePerSecond,
		expiresAt = os.clock() + puddleSpec.Duration,
		nextTickAt = os.clock() + PUDDLE_TICK,
	}
	table.insert(puddles, puddle)
	return ground
end

local function removeSpit(spit: Spit)
	if spit.part then
		spit.part:Destroy()
	end
end

local function impact(spit: Spit, position: Vector3, normal: Vector3)
	local spec = spit.spec
	splash(position, spec.SplashRadius, spit.damage)
	local ground = spawnPuddle(position, spec)
	removeSpit(spit)
	if fxOn() then
		local puddleSpec = spec.Puddle
		spitRemote:FireAllClients(
			Messages.EnemySpit.Impact,
			spit.id,
			position,
			normal,
			spec.SplashRadius,
			ground,
			puddleSpec and puddleSpec.Radius,
			puddleSpec and puddleSpec.Duration
		)
	end
end

-- A spitter planted and began its windup: clients rear its head back and run bile from
-- the mouth (SpitFX). The sac swell and the voice stay with EnemyService.
function EnemyProjectileService.windup(model: Model, seconds: number)
	if fxOn() then
		spitRemote:FireAllClients(Messages.EnemySpit.Windup, model, seconds)
	end
end

-- Launches a spit from `origin` to land at `targetPosition` (`targetVelocity` adds the
-- spec's lead). Flight time comes from the spec's speed over the flat distance. `damage` is
-- the definition's Damage, scaled on impact.
function EnemyProjectileService.fire(
	origin: Vector3,
	targetPosition: Vector3,
	targetVelocity: Vector3?,
	spec: Projectile,
	damage: number
)
	local flat = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)
	local flightTime = math.max(0.45, flat.Magnitude / spec.Speed)
	local lead = if targetVelocity
		then Vector3.new(targetVelocity.X, 0, targetVelocity.Z) * flightTime * spec.Lead
		else Vector3.zero
	local landing = targetPosition + lead
	local gravity = workspace.Gravity
	local velocity = (landing - origin) / flightTime + Vector3.new(0, 0.5 * gravity * flightTime, 0)

	nextSpitId += 1
	local part: BasePart? = nil
	if fxOn() then
		spitRemote:FireAllClients(
			Messages.EnemySpit.Launch,
			nextSpitId,
			origin,
			velocity,
			spec.Size
		)
	else
		local ball = Instance.new("Part")
		ball.Name = "Spit"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(spec.Size, spec.Size, spec.Size)
		ball.Position = origin
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Material = Enum.Material.Neon
		ball.Color = spec.Color
		ball.Parent = folder
		part = ball
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	-- The Enemy group does not collide with itself, so other Infected are skipped.
	params.CollisionGroup = "Enemy"

	local spit: Spit = {
		id = nextSpitId,
		part = part,
		origin = origin,
		velocity = velocity,
		launchedAt = os.clock(),
		expiresAt = os.clock() + flightTime + 1.5,
		lastPosition = origin,
		spec = spec,
		damage = damage,
		params = params,
	}
	table.insert(spits, spit)
end

local function stepSpits(now: number)
	local gravity = workspace.Gravity
	for index = #spits, 1, -1 do
		local spit = spits[index]
		local t = now - spit.launchedAt
		local position = spit.origin + spit.velocity * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
		local delta = position - spit.lastPosition
		local hit = if delta.Magnitude > 0
			then workspace:Raycast(spit.lastPosition, delta, spit.params)
			else nil
		if hit then
			impact(spit, hit.Position, hit.Normal)
			table.remove(spits, index)
		elseif now >= spit.expiresAt or position.Y < workspace.FallenPartsDestroyHeight + 50 then
			removeSpit(spit)
			if fxOn() then
				spitRemote:FireAllClients(Messages.EnemySpit.Gone, spit.id)
			end
			table.remove(spits, index)
		else
			if spit.part then
				spit.part.Position = position
			end
			spit.lastPosition = position
		end
	end
end

local function stepPuddles(now: number)
	for index = #puddles, 1, -1 do
		local puddle = puddles[index]
		if now >= puddle.expiresAt then
			if puddle.part then
				puddle.part:Destroy()
			end
			table.remove(puddles, index)
			continue
		end
		if now >= puddle.nextTickAt then
			puddle.nextTickAt = now + PUDDLE_TICK
			local center = puddle.center
			for _, target in livePlayerHumanoids() do
				local offset = target.root.Position - center
				if
					Vector3.new(offset.X, 0, offset.Z).Magnitude <= puddle.radius
					and math.abs(offset.Y) < 6
				then
					EnemyProjectileService.damagePlayer(
						target.humanoid,
						puddle.damagePerSecond * PUDDLE_TICK
					)
				end
			end
		end
	end
end

local lastStep = 0

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		-- Hold spits in the air and puddles on their clock while paused.
		local shift = now - lastStep
		for _, spit in spits do
			spit.launchedAt += shift
			spit.expiresAt += shift
		end
		for _, puddle in puddles do
			puddle.expiresAt += shift
			puddle.nextTickAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	stepSpits(now)
	stepPuddles(now)
end

-- Removes every spit and puddle (new run).
function EnemyProjectileService.reset()
	for _, spit in spits do
		removeSpit(spit)
	end
	table.clear(spits)
	for _, puddle in puddles do
		if puddle.part then
			puddle.part:Destroy()
		end
	end
	table.clear(puddles)
	spitRemote:FireAllClients(Messages.EnemySpit.Reset)
end

function EnemyProjectileService.init()
	Lifecycle.register("EnemyProjectileService", {
		onRunStart = EnemyProjectileService.reset,
	})
	spitRemote = Remotes.get("EnemySpit")
	folder = Instance.new("Folder")
	folder.Name = "InfectedProjectiles"
	folder.Parent = workspace
	RunService.Heartbeat:Connect(step)
end

return EnemyProjectileService
