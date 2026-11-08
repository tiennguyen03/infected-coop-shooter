--!strict
-- The Index (Sprint 19): the Warden, Delta's boss. RunManager starts the fight when the
-- Primary completes; the Warden spawns beyond the Gate, walks the screening lane
-- (Config.Index.Warden.Waypoints) to the Apron and then hunts the nearest living squad
-- member. EnemyService owns the body (spawnBoss: the rig, limbs, health bar, voice, death)
-- but never steers it (Behaviour.Attack "boss"); this service does.
--
-- Armour: six plates welded to the limbs, each a part with a PlateHealth attribute. A rifle
-- round into a plate is taken by the plate (DamageService.dealDamage routes it; the
-- armoured rate comes from ProjectileServer.hitMultiplier), a limb whose plate is gone is
-- Exposed (x1.5) and the helmet coming off opens the head (EnemyDefinitions.Warden
-- HeadshotMultiplier). A plate at half health is cracked (boss bar pip), at zero it is
-- unwelded and falls (Debris) and the Warden staggers.
--
-- Kit: Shield Bash (close, frontal arc), Gate Charge (straight line at speed on an anchored
-- root; into hard cover = WallStun), Gas Canister (phase 2+, lobbed at the furthest member
-- through EnemyProjectileService, leaves a puddle), Guard (shield up: slow, frontal plates
-- take little; the back plate is the flank). Every attack is preceded by the handset tell
-- (BossUpdate "tell"; the carrier hiss clip is open work). Phases by body health: the Riot
-- Call at 60% and 25% (EnemyService.spawnWave round him). On death: the priority pallet
-- (RequisitionService "upgrade" crate), a full heal and re-arm for the squad.
-- docs/PROGRESSION.md "Index kit: the Warden"; docs/sprints/SPRINT_19_WARDEN.md.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local EnemyService = require(script.Parent.EnemyService)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local RequisitionService = require(script.Parent.RequisitionService)
local Squad = require(script.Parent.Squad)
local WorldSounds = require(script.Parent.WorldSounds)

local IndexService = {}

local TYPE_NAME = "Warden"
local ENEMY_COLLISION_GROUP = "Enemy"
local REPATH_INTERVAL = 0.25

type Plate = {
	name: string,
	part: BasePart,
	limb: BasePart,
	max: number,
	cracked: boolean,
	broken: boolean,
}

type Charge = {
	from: Vector3,
	direction: Vector3,
	startedAt: number,
	duration: number,
	hit: { [Humanoid]: boolean },
}

type Fight = {
	generation: number,
	handle: EnemyService.BossHandle,
	plates: { Plate },
	platesBroken: number,
	phase: number,
	walking: boolean,
	waypointIndex: number,
	walkStartedAt: number,
	sighted: boolean,
	-- An attack in flight: `pending` resolves at `resolveAt`; `busyUntil` blocks the next
	-- decision (windup, swing, charge, stagger, stun). `action` names what is happening.
	action: string?,
	pending: string?,
	resolveAt: number,
	busyUntil: number,
	charge: Charge?,
	cooldowns: { [string]: number },
	chargeCooldown: number,
	nextRepathAt: number,
	nextSyncAt: number,
}

local fight: Fight?
local generation = 0
local bossRemote: RemoteEvent
local noticeRemote: RemoteEvent
local damageRemote: RemoteEvent
local defeatedListeners: { () -> () } = {}

local function cfg()
	return Config.Index.Warden
end

local function radio(key: string)
	local line = cfg().Radio[key]
	if line then
		noticeRemote:FireAllClients(line)
	end
end

local function tell(kind: string)
	local current = fight
	if not current then
		return
	end
	bossRemote:FireAllClients("tell", kind)
	local head = current.handle.model:FindFirstChild("Head") :: BasePart?
	if head then
		-- The handset's carrier hiss is open work (needs the audio pipeline); the Brute's
		-- bank stands in so the tell is heard, not only read.
		WorldSounds.voice(head, "brute", "brute_attack")
	end
end

local function plateFractions(current: Fight): { number }
	local fractions = {}
	for _, plate in current.plates do
		local health = plate.part:GetAttribute("PlateHealth")
		local value = if plate.broken or typeof(health) ~= "number" then 0 else health / plate.max
		table.insert(fractions, math.clamp(value, 0, 1))
	end
	return fractions
end

local function sync(current: Fight)
	local humanoid = current.handle.humanoid
	local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
	bossRemote:FireAllClients(
		"state",
		math.clamp(fraction, 0, 1),
		plateFractions(current),
		current.phase
	)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function faceToward(root: BasePart, target: Vector3)
	local direction = flat(target - root.Position)
	if direction.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction.Unit)
	end
end

local function nearestTarget(current: Fight): Squad.Member?
	local member = Squad.nearestLiving(current.handle.root.Position)
	return member
end

local function furthestTarget(current: Fight, maxRange: number): Squad.Member?
	local best: Squad.Member? = nil
	local bestDistance = -1
	for _, member in Squad.living() do
		local root = member.root
		if root then
			local distance = (root.Position - current.handle.root.Position).Magnitude
			if distance <= maxRange and distance > bestDistance then
				best = member
				bestDistance = distance
			end
		end
	end
	return best
end

-- Hard cover between the Warden and `target` blocks a charge; other Infected never do.
local function lineClear(current: Fight, target: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { current.handle.model }
	params.CollisionGroup = ENEMY_COLLISION_GROUP
	local origin = current.handle.root.Position
	local hit = workspace:Raycast(origin, target.Position - origin, params)
	return hit == nil
		or (target.Parent ~= nil and hit.Instance:IsDescendantOf(target.Parent :: Instance))
end

-- --- plates

local function breakPlate(current: Fight, plate: Plate)
	if plate.broken then
		return
	end
	plate.broken = true
	current.platesBroken += 1
	local settings = cfg()
	local part = plate.part
	part:SetAttribute("PlateHealth", nil)
	part:SetAttribute("PlateMax", nil)
	plate.limb:SetAttribute("Exposed", true)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			child:Destroy()
		end
	end
	part.CanQuery = false
	part.CanCollide = true
	part.Massless = false
	local away = (part.Position - current.handle.root.Position)
	local push = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
	part.AssemblyLinearVelocity = push * settings.PlateBreakImpulse
		+ Vector3.new(0, settings.PlateBreakImpulse * 0.5, 0)
	part.AssemblyAngularVelocity =
		Vector3.new(math.random() * 6 - 3, math.random() * 6 - 3, math.random() * 6 - 3)
	Debris:AddItem(part, settings.PlateDebris)
	-- The break in the world: the hit burst everyone already knows (HitMarkerUI).
	damageRemote:FireAllClients(part.Position, 0, "break", nil)

	-- The stagger cancels a windup in progress; a charge already running carries on.
	EnemyService.stagger(current.handle.humanoid, settings.PlateBreakStagger)
	if current.pending then
		current.pending = nil
		current.action = nil
	end
	if not current.charge then
		current.action = "stagger"
		current.busyUntil = math.max(current.busyUntil, os.clock() + settings.PlateBreakStagger)
	end
	bossRemote:FireAllClients("tell", "break")
	if current.platesBroken == 1 then
		radio("FirstPlate")
	elseif current.platesBroken == #current.plates then
		radio("LastPlate")
	end
	sync(current)
end

local function watchPlate(current: Fight, plate: Plate)
	local settings = cfg()
	plate.part:GetAttributeChangedSignal("PlateHealth"):Connect(function()
		if fight ~= current or plate.broken then
			return
		end
		local health = plate.part:GetAttribute("PlateHealth")
		if typeof(health) ~= "number" then
			return
		end
		if health <= 0 then
			breakPlate(current, plate)
		elseif not plate.cracked and health <= plate.max * settings.CrackFraction then
			plate.cracked = true
			plate.part:SetAttribute("Cracked", true)
			sync(current)
		end
	end)
end

-- Welds the six plates onto the unscaled rig; EnemyService scales the model afterwards.
-- The rig's Humanoid scales every part of the character from its OriginalSize value
-- (BodyWidthScale and friends, set by ScaleTo), so each plate carries one at its build
-- size: without it the plate was scaled twice (seen 2026-11-07). Health goes on in
-- armPlates once the body is up.
local function buildPlates(model: Model)
	local settings = cfg()
	local definition = EnemyDefinitions[TYPE_NAME]
	for _, name in settings.PlateOrder do
		local spec = settings.Plates[name]
		local limb = model:FindFirstChild(spec.Limb) :: BasePart?
		if not limb then
			continue
		end
		local offset = MeshAssets.offsetOf(spec.Mesh) or Vector3.zero
		local part: BasePart? = MeshAssets.clone(spec.Mesh)
		if not part then
			-- Until the plate meshes are uploaded: a dark box of the mesh's size.
			local box = Instance.new("Part")
			box.Size = MeshAssets.getSize(spec.Mesh) or Vector3.new(1.5, 1.5, 0.5)
			box.Color = definition.Color
			box.Material = Enum.Material.Metal
			part = box
		end
		local plate = part :: BasePart
		plate.Name = "Plate_" .. name
		plate.CFrame = limb.CFrame * CFrame.new(offset)
		plate.Anchored = false
		plate.Massless = true
		plate.CanCollide = false
		plate.CanQuery = true
		plate.CanTouch = false
		plate.CastShadow = true
		plate.CollisionGroup = ENEMY_COLLISION_GROUP
		if spec.Flank then
			plate:SetAttribute("Flank", true)
		end
		local original = Instance.new("Vector3Value")
		original.Name = "OriginalSize"
		original.Value = plate.Size
		original.Parent = plate
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = plate
		weld.Parent = plate
		plate.Parent = model
	end
end

local function armPlates(current: Fight, healthMultiplier: number)
	local settings = cfg()
	local model = current.handle.model
	for _, name in settings.PlateOrder do
		local spec = settings.Plates[name]
		local plate = model:FindFirstChild("Plate_" .. name) :: BasePart?
		local limb = model:FindFirstChild(spec.Limb) :: BasePart?
		if not plate or not limb then
			continue
		end
		local health = spec.Health * healthMultiplier
		plate:SetAttribute("PlateHealth", health)
		plate:SetAttribute("PlateMax", health)
		local record: Plate = {
			name = name,
			part = plate,
			limb = limb,
			max = health,
			cracked = false,
			broken = false,
		}
		table.insert(current.plates, record)
		watchPlate(current, record)
	end
end

-- --- attacks

local function startWindup(current: Fight, kind: string, windup: number, target: BasePart?)
	local now = os.clock()
	current.pending = kind
	current.action = kind
	current.resolveAt = now + windup
	current.busyUntil = now + windup
	local root = current.handle.root
	current.handle.humanoid:MoveTo(root.Position)
	if target then
		faceToward(root, target.Position)
	end
	tell(kind)
end

local function resolveBash(current: Fight)
	local settings = cfg().Bash
	local root = current.handle.root
	local forward = flat(root.CFrame.LookVector)
	local cosHalfArc = math.cos(math.rad(settings.ArcDegrees / 2))
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot then
			continue
		end
		local offset = flat(targetRoot.Position - root.Position)
		local distance = offset.Magnitude
		if
			distance <= settings.Range * cfg().ScaleReach
			and (distance < 0.5 or forward:Dot(offset.Unit) >= cosHalfArc)
		then
			EnemyProjectileService.damagePlayer(humanoid, settings.Damage)
		end
	end
	if current.handle.attackTrack then
		current.handle.attackTrack:Play(0.1)
	end
	current.cooldowns.bash = os.clock() + settings.Cooldown
	current.busyUntil = os.clock() + settings.Recovery
	current.action = "swing"
end

local function resolveCharge(current: Fight, target: BasePart?)
	local settings = cfg().Charge
	local root = current.handle.root
	local direction = flat(root.CFrame.LookVector)
	if target then
		local toTarget = flat(target.Position - root.Position)
		if toTarget.Magnitude > 0.5 then
			direction = toTarget.Unit
		end
	end
	if direction.Magnitude < 0.01 then
		direction = Vector3.zAxis
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	current.handle.humanoid:MoveTo(root.Position)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	local now = os.clock()
	current.charge = {
		from = root.Position,
		direction = direction,
		startedAt = now,
		duration = settings.Distance / settings.Speed,
		hit = {},
	}
	current.action = "charge"
	current.busyUntil = now + settings.Distance / settings.Speed
	current.cooldowns.charge = now + current.chargeCooldown
	if current.handle.attackTrack then
		current.handle.attackTrack:Play(0.1)
	end
end

local function endCharge(current: Fight, wall: boolean)
	local root = current.handle.root
	current.charge = nil
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	local now = os.clock()
	if wall then
		local stun = cfg().Charge.WallStun
		current.action = "stun"
		current.busyUntil = now + stun
		EnemyService.stagger(current.handle.humanoid, stun)
		bossRemote:FireAllClients("tell", "stun")
	else
		current.action = "recover"
		current.busyUntil = now + cfg().Charge.Recovery
	end
end

local function stepCharge(current: Fight, charge: Charge, now: number)
	local settings = cfg().Charge
	local root = current.handle.root
	local elapsed = now - charge.startedAt
	local travelled = math.min(elapsed, charge.duration) * settings.Speed
	local nextPosition = charge.from + charge.direction * travelled
	-- Hard cover ahead ends the charge in a stun; squad bodies and other Infected do not.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { current.handle.model }
	params.CollisionGroup = ENEMY_COLLISION_GROUP
	local step = nextPosition - root.Position
	local probe = charge.direction * (step.Magnitude + settings.Probe * cfg().ScaleReach)
	local hit = workspace:Raycast(root.Position, probe, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local isBody = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
		if not isBody then
			endCharge(current, true)
			return
		end
	end
	root.CFrame = CFrame.lookAt(nextPosition, nextPosition + charge.direction)
	-- Everyone inside the charge's width is hit once.
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot or charge.hit[humanoid] then
			continue
		end
		local offset = targetRoot.Position - root.Position
		if
			flat(offset).Magnitude <= settings.Width * cfg().ScaleReach
			and math.abs(offset.Y) <= settings.HitHeight
		then
			charge.hit[humanoid] = true
			EnemyProjectileService.damagePlayer(humanoid, settings.Damage)
		end
	end
	if elapsed >= charge.duration then
		endCharge(current, false)
	end
end

local function resolveCanister(current: Fight)
	local settings = cfg().Canister
	local target = furthestTarget(current, settings.MaxRange)
	local root = current.handle.root
	if target and target.root then
		local origin = root.Position + Vector3.new(0, 2, 0) + flat(root.CFrame.LookVector) * 2
		EnemyProjectileService.fire(
			origin,
			target.root.Position,
			target.root.AssemblyLinearVelocity,
			settings.Projectile :: EnemyDefinitions.ProjectileSpec,
			settings.Damage
		)
	end
	local now = os.clock()
	current.cooldowns.canister = now + settings.Cooldown
	current.busyUntil = now + settings.Recovery
	current.action = "throw"
end

local function startGuard(current: Fight)
	local settings = cfg().Guard
	local now = os.clock()
	local humanoid = current.handle.humanoid
	local base = (humanoid:GetAttribute("BaseWalkSpeed") :: number?) or humanoid.WalkSpeed
	current.handle.model:SetAttribute("GuardFactor", settings.PlateDamageFactor)
	humanoid.WalkSpeed = base * settings.SpeedFactor
	current.action = "guard"
	current.busyUntil = now + settings.Duration
	current.cooldowns.guard = now + settings.Cooldown
	tell("guard")
end

local function endGuard(current: Fight)
	local humanoid = current.handle.humanoid
	current.handle.model:SetAttribute("GuardFactor", nil)
	local base = (humanoid:GetAttribute("BaseWalkSpeed") :: number?) or humanoid.WalkSpeed
	if not PauseService.isPaused() and humanoid.Health > 0 then
		humanoid.WalkSpeed = base
	end
end

local function resolvePending(current: Fight)
	local kind = current.pending
	current.pending = nil
	local target = nearestTarget(current)
	local targetRoot = target and target.root
	if kind == "bash" then
		resolveBash(current)
	elseif kind == "charge" then
		resolveCharge(current, targetRoot)
	elseif kind == "canister" then
		resolveCanister(current)
	end
end

-- Picks the next attack for the hunt. Returns true when one started.
local function chooseAttack(current: Fight, now: number, target: Squad.Member): boolean
	local settings = cfg()
	local root = current.handle.root
	local targetRoot = target.root
	if not targetRoot then
		return false
	end
	local distance = flat(targetRoot.Position - root.Position).Magnitude
	local reach = settings.ScaleReach
	if distance <= settings.Bash.Range * reach and now >= (current.cooldowns.bash or 0) then
		startWindup(current, "bash", settings.Bash.Windup, targetRoot)
		return true
	end
	if
		distance >= settings.Charge.MinRange
		and distance <= settings.Charge.MaxRange
		and now >= (current.cooldowns.charge or 0)
		and lineClear(current, targetRoot)
	then
		startWindup(current, "charge", settings.Charge.Windup, targetRoot)
		return true
	end
	if current.phase >= settings.Canister.MinPhase and now >= (current.cooldowns.canister or 0) then
		local far = furthestTarget(current, settings.Canister.MaxRange)
		if far and far.root then
			startWindup(current, "canister", settings.Canister.Windup, far.root)
			return true
		end
	end
	if
		distance >= settings.Guard.MinRange
		and distance <= settings.Guard.MaxRange
		and now >= (current.cooldowns.guard or 0)
	then
		startGuard(current)
		return true
	end
	return false
end

-- --- phases

local function enterPhase(current: Fight, phase: number)
	local settings = cfg()
	local spec = settings.Phases[phase - 1]
	current.phase = phase
	if not spec then
		return
	end
	local extra = DifficultyService.getExtraPlayers()
	local center = current.handle.root.Position
	-- The call answers one body per few frames: one burst of rigs would hitch a phone.
	task.spawn(function()
		for typeName, count in spec.RiotCall :: { [string]: number } do
			local total = count
				+ (if typeName == "Walker" then spec.WalkersPerExtraPlayer * extra else 0)
			for _ = 1, total do
				if fight ~= current then
					return
				end
				EnemyService.spawnWave(typeName, 1, center)
				for _ = 1, settings.RiotCallSpacing do
					task.wait()
				end
			end
		end
	end)
	if spec.ChargeCooldown then
		current.chargeCooldown = spec.ChargeCooldown
	end
	if spec.WalkSpeed then
		local humanoid = current.handle.humanoid
		humanoid:SetAttribute("BaseWalkSpeed", spec.WalkSpeed)
		if current.action ~= "guard" and not PauseService.isPaused() then
			humanoid.WalkSpeed = spec.WalkSpeed
		end
	end
	radio("RiotCall")
	tell("riot")
	sync(current)
end

local function checkPhase(current: Fight)
	local humanoid = current.handle.humanoid
	local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
	local phases = cfg().Phases
	for index, spec in phases do
		local phase = index + 1
		if fraction <= spec.Below and current.phase < phase then
			enterPhase(current, phase)
		end
	end
end

-- --- the fight

local function endFight(current: Fight, defeated: boolean)
	if fight ~= current then
		return
	end
	fight = nil
	workspace:SetAttribute("IndexActive", false)
	if current.charge then
		current.handle.root.Anchored = false
	end
	if defeated then
		radio("Kill")
		local root = current.handle.root
		local facing = flat(root.CFrame.LookVector)
		local drop = cfg().Drop
		-- The priority pallet: the Index's upgrade cards, a full heal and a re-arm.
		local ground = GroundUtil.GetGroundPosition(root.Position + facing * drop.Offset, 0)
		RequisitionService.dropCrate(ground, facing, "upgrade", false)
		for _, member in Squad.living() do
			if member.humanoid then
				member.humanoid.Health = member.humanoid.MaxHealth
			end
		end
		for _, player in Squad.livingOwners() do
			LoadoutService.refillAmmo(player)
		end
		for _, listener in defeatedListeners do
			listener()
		end
	end
	task.delay(cfg().HideDelay, function()
		if fight == nil then
			bossRemote:FireAllClients("hide")
		end
	end)
end

local function step()
	local current = fight
	if not current then
		return
	end
	local handle = current.handle
	if not handle.model.Parent then
		endFight(current, false)
		return
	end
	if handle.humanoid.Health <= 0 then
		return
	end
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	local settings = cfg()

	if now >= current.nextSyncAt then
		current.nextSyncAt = now + settings.SyncInterval
		sync(current)
	end
	checkPhase(current)

	local charge = current.charge
	if charge then
		stepCharge(current, charge, now)
		return
	end
	if current.pending and now >= current.resolveAt then
		resolvePending(current)
		return
	end
	local busy = now < current.busyUntil
	if busy and current.action ~= "guard" then
		return
	end
	if not busy and current.action then
		if current.action == "guard" then
			endGuard(current)
		end
		current.action = nil
	end

	local target = nearestTarget(current)
	local targetRoot = target and target.root

	if current.walking then
		-- The walk in: the lane's waypoints, then the hunt. A body in reach still gets bashed.
		local waypoint = settings.Waypoints[current.waypointIndex]
		if not waypoint or now - current.walkStartedAt > settings.WalkTimeout then
			current.walking = false
		else
			if targetRoot and not current.sighted then
				if
					(targetRoot.Position - handle.root.Position).Magnitude <= settings.SightingRange
				then
					current.sighted = true
					radio("Sighting")
				end
			end
			if
				targetRoot
				and flat(targetRoot.Position - handle.root.Position).Magnitude <= settings.Bash.Range * settings.ScaleReach
				and now >= (current.cooldowns.bash or 0)
			then
				startWindup(current, "bash", settings.Bash.Windup, targetRoot)
				return
			end
			if flat(handle.root.Position - waypoint).Magnitude <= settings.WaypointReach then
				local line = settings.WaypointRadio[current.waypointIndex]
				if line then
					radio(line)
				end
				current.waypointIndex += 1
				current.nextRepathAt = 0
			end
			if now >= current.nextRepathAt then
				current.nextRepathAt = now + REPATH_INTERVAL
				local next = settings.Waypoints[current.waypointIndex]
				if next then
					handle.humanoid:MoveTo(GroundUtil.GetGroundPosition(next, 0))
				end
			end
			return
		end
	end

	if not target or not targetRoot then
		return
	end
	if current.action ~= "guard" and chooseAttack(current, now, target) then
		return
	end
	if now >= current.nextRepathAt then
		current.nextRepathAt = now + REPATH_INTERVAL
		handle.humanoid:MoveTo(targetRoot.Position)
	end
end

local function spawn(groundPosition: Vector3, walk: boolean): boolean
	if fight then
		return false
	end
	local handle = EnemyService.spawnBoss(TYPE_NAME, groundPosition, buildPlates)
	if not handle then
		warn("[IndexService] The Warden could not spawn (no rig template)")
		return false
	end
	generation += 1
	local settings = cfg()
	local healthMultiplier = 1 + settings.HealthPerExtraPlayer * DifficultyService.getExtraPlayers()
	local humanoid = handle.humanoid
	humanoid.MaxHealth = humanoid.MaxHealth * healthMultiplier
	humanoid.Health = humanoid.MaxHealth

	local current: Fight = {
		generation = generation,
		handle = handle,
		plates = {},
		platesBroken = 0,
		phase = 1,
		walking = walk,
		waypointIndex = 1,
		walkStartedAt = os.clock(),
		sighted = not walk,
		action = nil,
		pending = nil,
		resolveAt = 0,
		busyUntil = os.clock() + settings.SpawnDelay,
		charge = nil,
		cooldowns = { charge = os.clock() + settings.Charge.FirstDelay },
		chargeCooldown = settings.Charge.Cooldown,
		nextRepathAt = 0,
		nextSyncAt = 0,
	}
	fight = current
	armPlates(current, healthMultiplier)
	workspace:SetAttribute("IndexActive", true)

	local names = {}
	for _, plate in current.plates do
		table.insert(names, plate.name)
	end
	bossRemote:FireAllClients("show", EnemyDefinitions[TYPE_NAME].DisplayName, names)
	sync(current)

	humanoid.Died:Connect(function()
		if fight == current then
			endFight(current, true)
		end
	end)
	print(
		`[IndexService] The Warden is up ({humanoid.MaxHealth} hp, {#current.plates} plates, walk {walk})`
	)
	return true
end

-- RunManager, on Primary complete: the Warden comes through the Gate and walks the lane.
-- Returns false when no boss could spawn (the run then skips to Extract).
function IndexService.start(): boolean
	local settings = cfg()
	radio("PrimaryComplete")
	local ok = spawn(GroundUtil.GetGroundPosition(settings.SpawnPosition, 0), true)
	if ok then
		task.delay(settings.GateOpenDelay, function()
			if fight then
				radio("GateOpen")
			end
		end)
	end
	return ok
end

-- Dev: the Warden at `position`, hunting at once (no walk in).
function IndexService.spawnAt(position: Vector3): boolean
	return spawn(GroundUtil.GetGroundPosition(position, 0), false)
end

function IndexService.isActive(): boolean
	return fight ~= nil
end

-- RunManager: the Index is dead; the run moves on to Extract.
function IndexService.onDefeated(listener: () -> ())
	table.insert(defeatedListeners, listener)
end

function IndexService.reset()
	local current = fight
	if current then
		endFight(current, false)
		if current.handle.model.Parent then
			current.handle.model:Destroy()
		end
	end
	workspace:SetAttribute("IndexActive", false)
end

-- Fresh clients (a late join mid-fight) get the current state on request.
function IndexService.init()
	bossRemote = Remotes.get("BossUpdate")
	noticeRemote = Remotes.get("BuffNotice")
	damageRemote = Remotes.get("DamageDealt")
	workspace:SetAttribute("IndexActive", false)
	bossRemote.OnServerEvent:Connect(function(player)
		local current = fight
		if current then
			local names = {}
			for _, plate in current.plates do
				table.insert(names, plate.name)
			end
			bossRemote:FireClient(player, "show", EnemyDefinitions[TYPE_NAME].DisplayName, names)
			local humanoid = current.handle.humanoid
			bossRemote:FireClient(
				player,
				"state",
				math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1),
				plateFractions(current),
				current.phase
			)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return IndexService
