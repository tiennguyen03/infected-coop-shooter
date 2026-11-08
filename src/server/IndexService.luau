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
-- Kit (systems-designer pass): where you stand picks his move. Shield
-- Bash (close, 70° arc; roll through it), Shield Sweep (180° arc and a shove; get behind
-- him), Overhead Slam (a narrow line at a body that stopped moving in reach; step aside),
-- Ground Pound (fists into the road: a disc on the ground knocks everyone down, the roll
-- does not beat it, distance or a ledge does), Stomp (a body in his boots on any side:
-- small disc, knockdown; roll it), Gate Charge (straight line at speed on an anchored
-- root; into hard cover = WallStun), Gas Canister (phase 2+, or any phase at a perched
-- member; lobbed at the furthest member through EnemyProjectileService, leaves a puddle),
-- Guard (a reaction to his plates taking fire: shield up, slow, frontal plates take little;
-- the back plate is the flank). He walks a beat between attacks (AttackGap by phase),
-- never repeats one except the Bash, never chains two knockdowns. Limb attacks are "melee"
-- (EnemyProjectileService.damagePlayer: a rolling body is missed). Every attack is preceded
-- by the handset tell (BossUpdate "tell"; the carrier hiss clip is open work); the Pound
-- also draws its ring (BossUpdate "zone") and every ground / line attack marks the danger
-- on workspace attributes so bots step out of it (BotService). Phases by body health: the
-- Riot Call at 60% and 25% (EnemyService.spawnWave round him). On death: the priority
-- pallet (RequisitionService "upgrade" crate), a full heal and re-arm for the squad.
-- docs/PROGRESSION.md "Index kit: the Warden"; docs/sprints/SPRINT_19_WARDEN.md.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Animations)
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
local Lifecycle = require(script.Parent.Lifecycle)

local IndexService = {}

local TYPE_NAME = "Warden"
local ENEMY_COLLISION_GROUP = "Enemy"
local REPATH_INTERVAL = 0.25

type Plate = {
	name: string,
	part: BasePart,
	limb: BasePart,
	max: number,
	health: number, -- last seen, for the damage log (Guard trigger)
	cracked: boolean,
	broken: boolean,
}

-- Attacks that put a body on the ground; never two in a row.
local KNOCKDOWN_ATTACKS: { [string]: boolean } = { pound = true, stomp = true }
-- Attack -> its Config.Index.Warden block.
local ATTACK_SETTINGS: { [string]: string } = {
	bash = "Bash",
	sweep = "Sweep",
	slam = "Slam",
	pound = "Pound",
	stomp = "Stomp",
	charge = "Charge",
	canister = "Canister",
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
	poundCooldown: number,
	lastAttack: string?, -- the no-repeat rule
	nextDecisionAt: number, -- the beat: he walks until then after a recovery
	plateHits: { { t: number, amount: number } }, -- recent plate damage (Guard trigger)
	nextRepathAt: number,
	nextSyncAt: number,
	-- His clips (Config.Animations.Infected.Warden): idle whenever he stands still (Idle
	-- priority over the Core walk), the rest Action overlays played by the attacks.
	tracks: { [string]: AnimationTrack },
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

-- Plays one of his clips (fade in), nil-safe for an unpublished clip outside Studio.
local function play(current: Fight, name: string, fade: number?)
	local track = current.tracks[name]
	if track then
		track:Play(fade or 0.1)
	end
	return track
end

local function stop(current: Fight, name: string, fade: number?)
	local track = current.tracks[name]
	if track and track.IsPlaying then
		track:Stop(fade or 0.2)
	end
end

local function loadTracks(handle: EnemyService.BossHandle): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	local animator = handle.humanoid:FindFirstChildOfClass("Animator")
	local clips = Config.Animations.Infected[TYPE_NAME]
	if not animator or not clips then
		return tracks
	end
	local wanted: { [string]: Enum.AnimationPriority } = {
		idle = Enum.AnimationPriority.Idle,
		guard = Enum.AnimationPriority.Action,
		charge = Enum.AnimationPriority.Action2,
		riot = Enum.AnimationPriority.Action2,
		throw = Enum.AnimationPriority.Action,
		pound = Enum.AnimationPriority.Action2,
		sweep = Enum.AnimationPriority.Action2,
		slam = Enum.AnimationPriority.Action2,
		stomp = Enum.AnimationPriority.Action2,
		hit = Enum.AnimationPriority.Action3,
	}
	for name, priority in wanted do
		local clip = (clips :: { [string]: string })[name]
		local track = clip and Animations.load(animator :: Animator, clip, priority)
		if track then
			track.Looped = name == "idle" or name == "guard" or name == "charge"
			tracks[name] = track
		end
	end
	return tracks
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

-- The idle: on when the body is not moving, off the moment it is (the walk shows again).
local function updateIdle(current: Fight)
	local idle = current.tracks.idle
	if not idle then
		return
	end
	-- MoveDirection stays zero on a MoveTo-driven server humanoid, so
	-- the root's ground speed is the test; a charge (anchored root) counts as moving.
	local root = current.handle.root
	local moving = current.charge ~= nil
		or flat(root.AssemblyLinearVelocity).Magnitude > cfg().IdleSpeed
	if moving and idle.IsPlaying then
		idle:Stop(0.2)
	elseif not moving and not idle.IsPlaying then
		idle:Play(0.2)
	end
end

-- Where a body's feet are: the root sits HipHeight + half its height above them.
local function feetY(humanoid: Humanoid, root: BasePart): number
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
end

-- A member standing PerchHeight above his feet: out of reach of every limb and the Pound.
local function isPerched(current: Fight, member: Squad.Member): boolean
	local humanoid, root = member.humanoid, member.root
	if not humanoid or not root then
		return false
	end
	return feetY(humanoid, root) - feetY(current.handle.humanoid, current.handle.root)
		>= cfg().PerchHeight
end

-- The pending attack's shape on workspace attributes (BotService.dodgeDanger): a disc
-- (Pound, Stomp) or a line (Slam, Charge), until `untilTime`.
local function markDanger(
	kind: "disc" | "line",
	center: Vector3,
	radius: number,
	untilTime: number,
	direction: Vector3?,
	length: number?
)
	workspace:SetAttribute("BossDangerKind", kind)
	workspace:SetAttribute("BossDanger", center)
	workspace:SetAttribute("BossDangerRadius", radius)
	workspace:SetAttribute("BossDangerDir", direction or Vector3.zAxis)
	workspace:SetAttribute("BossDangerLength", length or 0)
	workspace:SetAttribute("BossDangerUntil", untilTime)
end

local function clearDanger()
	workspace:SetAttribute("BossDangerUntil", 0)
end

-- Plate damage taken inside Guard.TriggerWindow seconds.
local function recentPlateDamage(current: Fight, now: number): number
	local window = cfg().Guard.TriggerWindow
	local total = 0
	local kept = {}
	for _, hit in current.plateHits do
		if now - hit.t <= window then
			total += hit.amount
			table.insert(kept, hit)
		end
	end
	current.plateHits = kept
	return total
end

-- The no-repeat rule: never the same attack twice in a row except the Bash (the filler),
-- never a knockdown attack after a knockdown attack.
local function allowed(current: Fight, kind: string): boolean
	local last = current.lastAttack
	if not last then
		return true
	end
	if kind ~= "bash" and kind == last then
		return false
	end
	if KNOCKDOWN_ATTACKS[kind] and KNOCKDOWN_ATTACKS[last] then
		return false
	end
	return true
end

local function ready(current: Fight, kind: string, now: number): boolean
	return now >= (current.cooldowns[kind] or 0) and allowed(current, kind)
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

-- Guard off: speed back, plates take full damage, shield down. Safe to call when he is not
-- guarding; anything that takes over his action (a stagger, a windup) calls it.
local function cancelGuard(current: Fight)
	local humanoid = current.handle.humanoid
	stop(current, "guard", 0.3)
	current.handle.model:SetAttribute("GuardFactor", nil)
	local base = (humanoid:GetAttribute("BaseWalkSpeed") :: number?) or humanoid.WalkSpeed
	if not PauseService.isPaused() and humanoid.Health > 0 then
		humanoid.WalkSpeed = base
	end
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
		clearDanger()
		for _, name in { "pound", "sweep", "slam", "stomp" } do
			stop(current, name, 0.1)
		end
	end
	if not current.charge then
		if current.action == "guard" then
			cancelGuard(current)
		end
		current.action = "stagger"
		current.busyUntil = math.max(current.busyUntil, os.clock() + settings.PlateBreakStagger)
		stop(current, "idle", 0.05)
		play(current, "hit", 0.05)
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
		if health < plate.health then
			table.insert(current.plateHits, { t = os.clock(), amount = plate.health - health })
		end
		plate.health = health
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
-- size: without it the plate was scaled twice. Health goes on in
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
			health = health,
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
	print(`[IndexService] {kind} (phase {current.phase})`)
	if current.action == "guard" then
		cancelGuard(current)
	end
	current.pending = kind
	current.action = kind
	current.resolveAt = now + windup
	current.busyUntil = now + windup
	local root = current.handle.root
	current.handle.humanoid:MoveTo(root.Position)
	if target then
		faceToward(root, target.Position)
	end
	local settings = cfg()
	local reach = settings.ScaleReach
	-- The clip runs so its blow lands at StrikeAt of it when the windup ends; the Bash
	-- wears the rig's own attack track (EnemyService), the others their named clips.
	local track = if kind == "bash" then current.handle.attackTrack else current.tracks[kind]
	local block = ATTACK_SETTINGS[kind] and (settings :: any)[ATTACK_SETTINGS[kind]]
	if track and block and block.StrikeAt then
		stop(current, "idle", 0.05)
		track:Play(0.05)
		local length = track.Length
		if length > 0 then
			track:AdjustSpeed(length * block.StrikeAt / windup)
		end
	elseif kind == "canister" then
		play(current, "throw")
	end
	-- The shape of what is coming, for the bots and (the Pound) the squad's ring.
	local forward = flat(root.CFrame.LookVector)
	if forward.Magnitude < 0.01 then
		forward = Vector3.zAxis
	else
		forward = forward.Unit
	end
	local ground = GroundUtil.GetGroundPosition(root.Position, 0)
	if kind == "pound" then
		local radius = settings.Pound.Radius * reach
		markDanger("disc", ground, radius, current.resolveAt)
		bossRemote:FireAllClients("zone", ground, radius, windup)
	elseif kind == "stomp" then
		markDanger("disc", ground, settings.Stomp.Radius * reach, current.resolveAt)
	elseif kind == "slam" then
		markDanger(
			"line",
			ground,
			settings.Slam.Width * reach / 2,
			current.resolveAt,
			forward,
			settings.Slam.Length * reach
		)
	elseif kind == "charge" then
		markDanger(
			"line",
			ground,
			settings.Charge.Width * reach,
			current.resolveAt + settings.Charge.Distance / settings.Charge.Speed,
			forward,
			settings.Charge.Distance
		)
	end
	tell(kind)
end

-- A limb lands: "melee" damage (a rolling body is missed), the attack's cooldown and
-- recovery, and the no-repeat memory.
local function landed(current: Fight, kind: string, settings: any)
	local now = os.clock()
	current.cooldowns[kind] = now + settings.Cooldown
	current.busyUntil = now + settings.Recovery
	current.action = "swing"
	current.lastAttack = kind
	clearDanger()
end

-- A shove away from him: players through Impact "push" (the client owns its physics),
-- bots straight on the root.
local function shove(current: Fight, member: Squad.Member, speed: number)
	local targetRoot = member.root
	if not targetRoot then
		return
	end
	local away = flat(targetRoot.Position - current.handle.root.Position)
	local direction = if away.Magnitude > 0.1
		then away.Unit
		else flat(current.handle.root.CFrame.LookVector)
	local velocity = direction * speed + Vector3.new(0, speed * 0.25, 0)
	if member.owner then
		Remotes.get("Impact"):FireClient(member.owner, "push", velocity)
	else
		targetRoot.AssemblyLinearVelocity = velocity
	end
end

-- Bash and Sweep: a frontal arc. The Sweep shoves whoever it catches.
local function resolveArc(current: Fight, kind: "bash" | "sweep")
	local settings: any = if kind == "bash" then cfg().Bash else cfg().Sweep
	local root = current.handle.root
	local forward = flat(root.CFrame.LookVector)
	local cosHalfArc = math.cos(math.rad(settings.ArcDegrees / 2))
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot or isPerched(current, member) then
			continue
		end
		local offset = flat(targetRoot.Position - root.Position)
		local distance = offset.Magnitude
		if
			distance <= settings.Range * cfg().ScaleReach
			and (distance < 0.5 or forward:Dot(offset.Unit) >= cosHalfArc)
		then
			EnemyProjectileService.damagePlayer(humanoid, settings.Damage, "melee")
			if kind == "sweep" and humanoid.Health > 0 then
				shove(current, member, settings.Pushback)
			end
		end
	end
	landed(current, kind, settings)
end

-- Overhead Slam: a line ahead of him, Length long and Width wide.
local function resolveSlam(current: Fight)
	local settings = cfg().Slam
	local reach = cfg().ScaleReach
	local root = current.handle.root
	local forward = flat(root.CFrame.LookVector)
	if forward.Magnitude > 0.01 then
		forward = forward.Unit
	end
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot or isPerched(current, member) then
			continue
		end
		local offset = flat(targetRoot.Position - root.Position)
		local along = offset:Dot(forward)
		local side = (offset - forward * along).Magnitude
		if
			along >= -1
			and along <= settings.Length * reach
			and side <= settings.Width * reach / 2
		then
			EnemyProjectileService.damagePlayer(humanoid, settings.Damage, "melee")
		end
	end
	landed(current, "slam", settings)
end

-- Pound and Stomp: a disc on the ground round him; everyone inside goes down. The Pound is
-- the ground moving (no roll window), the Stomp a boot (melee: the roll beats it).
local function resolveDisc(current: Fight, kind: "pound" | "stomp")
	local settings: any = if kind == "pound" then cfg().Pound else cfg().Stomp
	local reach = cfg().ScaleReach
	local root = current.handle.root
	local hitHeight = if kind == "pound" then settings.HitHeight else cfg().PerchHeight
	for _, member in Squad.living() do
		local humanoid, targetRoot = member.humanoid, member.root
		if not humanoid or not targetRoot then
			continue
		end
		local offset = targetRoot.Position - root.Position
		local height = feetY(humanoid, targetRoot) - feetY(current.handle.humanoid, root)
		if flat(offset).Magnitude <= settings.Radius * reach and height < hitHeight then
			local before = humanoid.Health
			EnemyProjectileService.damagePlayer(
				humanoid,
				settings.Damage,
				if kind == "stomp" then "melee" else nil
			)
			-- A missed stomp (the roll) is no knockdown either; a Pound always is.
			if humanoid.Health > 0 and (kind == "pound" or humanoid.Health < before) then
				Squad.knock(member, settings.Knockdown)
			end
		end
	end
	landed(current, kind, settings)
	if kind == "pound" then
		current.cooldowns.pound = os.clock() + current.poundCooldown
	end
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
	stop(current, "idle", 0.05)
	play(current, "charge", 0.05)
end

local function endCharge(current: Fight, wall: boolean)
	local root = current.handle.root
	current.charge = nil
	stop(current, "charge", 0.15)
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
	current.lastAttack = "canister"
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
	play(current, "guard", 0.2)
	tell("guard")
end

local function endGuard(current: Fight)
	cancelGuard(current)
end

local function resolvePending(current: Fight)
	local kind = current.pending
	current.pending = nil
	local target = nearestTarget(current)
	local targetRoot = target and target.root
	if kind == "bash" or kind == "sweep" then
		resolveArc(current, kind)
	elseif kind == "slam" then
		resolveSlam(current)
	elseif kind == "pound" or kind == "stomp" then
		resolveDisc(current, kind)
	elseif kind == "charge" then
		current.lastAttack = "charge"
		resolveCharge(current, targetRoot)
	elseif kind == "canister" then
		resolveCanister(current)
	end
end

-- Living members inside a disc of `radius` round him (the crowd test for Sweep and Pound).
local function countWithin(current: Fight, radius: number, frontal: boolean): number
	local root = current.handle.root
	local forward = flat(root.CFrame.LookVector)
	local count = 0
	for _, member in Squad.living() do
		local targetRoot = member.root
		if not targetRoot or isPerched(current, member) then
			continue
		end
		local offset = flat(targetRoot.Position - root.Position)
		if
			offset.Magnitude <= radius
			and (not frontal or offset.Magnitude < 0.5 or forward:Dot(offset.Unit) >= 0)
		then
			count += 1
		end
	end
	return count
end

-- A member in his boots (any side): the Stomp's trigger.
local function hugger(current: Fight): Squad.Member?
	local range = cfg().HugRange * cfg().ScaleReach
	for _, member in Squad.living() do
		local targetRoot = member.root
		if targetRoot and not isPerched(current, member) then
			if flat(targetRoot.Position - current.handle.root.Position).Magnitude <= range then
				return member
			end
		end
	end
	return nil
end

-- A member in front of him, in Slam reach, that has stopped moving: the Slam's trigger.
local function planted(current: Fight): Squad.Member?
	local settings = cfg()
	local root = current.handle.root
	local forward = flat(root.CFrame.LookVector)
	for _, member in Squad.living() do
		local targetRoot = member.root
		if not targetRoot or isPerched(current, member) then
			continue
		end
		local offset = flat(targetRoot.Position - root.Position)
		if
			offset.Magnitude <= settings.Slam.Length * settings.ScaleReach
			and (offset.Magnitude < 0.5 or forward:Dot(offset.Unit) >= 0.5)
			and flat(targetRoot.AssemblyLinearVelocity).Magnitude < settings.PlantedSpeed
		then
			return member
		end
	end
	return nil
end

-- A weighted pick among the ready close-band attacks (CloseWeights; a crowd doubles the
-- Sweep and the Pound).
local function pickClose(current: Fight, now: number): string?
	local settings = cfg()
	local reach = settings.ScaleReach
	local crowd = settings.CrowdCount
	local candidates: { { kind: string, weight: number } } = {}
	local total = 0
	for kind, weight in settings.CloseWeights :: { [string]: number } do
		if not ready(current, kind, now) then
			continue
		end
		local w = weight
		local crowded = (
			kind == "sweep"
			and countWithin(current, settings.Sweep.Range * reach, true) >= crowd
		)
			or (
				kind == "pound"
				and countWithin(current, settings.Pound.Radius * reach, false) >= crowd
			)
		if crowded then
			w *= 2
		end
		table.insert(candidates, { kind = kind, weight = w })
		total += w
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, candidate in candidates do
		roll -= candidate.weight
		if roll <= 0 then
			return candidate.kind
		end
	end
	return candidates[#candidates].kind
end

-- Picks the next attack for the hunt: reactions first (a body in his boots, plates under
-- fire, a planted body in reach), then the nearest member's range band. Returns true when
-- one started.
local function chooseAttack(current: Fight, now: number, target: Squad.Member): boolean
	local settings = cfg()
	local root = current.handle.root
	local targetRoot = target.root
	if not targetRoot then
		return false
	end
	local reach = settings.ScaleReach
	local perched = isPerched(current, target)

	-- Reactions.
	if not perched then
		local close = hugger(current)
		if close and close.root and ready(current, "stomp", now) then
			startWindup(current, "stomp", settings.Stomp.Windup, close.root)
			return true
		end
	end
	if
		now >= (current.cooldowns.guard or 0)
		and recentPlateDamage(current, now) >= settings.Guard.TriggerPlateDamage
	then
		startGuard(current)
		return true
	end
	if not perched then
		local still = planted(current)
		if still and still.root and ready(current, "slam", now) then
			startWindup(current, "slam", settings.Slam.Windup, still.root)
			return true
		end
	end

	-- Bands.
	local distance = flat(targetRoot.Position - root.Position).Magnitude
	local canisterReady = ready(current, "canister", now)
		and (perched or current.phase >= settings.Canister.MinPhase)
	if perched then
		if canisterReady then
			local far = furthestTarget(current, settings.Canister.MaxRange)
			if far and far.root then
				startWindup(current, "canister", settings.Canister.Windup, far.root)
				return true
			end
		end
		return false
	end
	if distance <= settings.HugRange * reach then
		if ready(current, "bash", now) then
			startWindup(current, "bash", settings.Bash.Windup, targetRoot)
			return true
		end
	elseif distance <= settings.Bash.Range * reach then
		local kind = pickClose(current, now)
		if kind then
			local block = (settings :: any)[ATTACK_SETTINGS[kind]]
			startWindup(current, kind, block.Windup, targetRoot)
			return true
		end
	elseif distance <= settings.Pound.MaxRange * reach then
		if distance >= settings.Pound.MinRange * reach and ready(current, "pound", now) then
			startWindup(current, "pound", settings.Pound.Windup, targetRoot)
			return true
		end
	elseif distance >= settings.Charge.MinRange and distance <= settings.Charge.MaxRange then
		if ready(current, "charge", now) and lineClear(current, targetRoot) then
			startWindup(current, "charge", settings.Charge.Windup, targetRoot)
			return true
		end
	end
	if canisterReady then
		local far = furthestTarget(current, settings.Canister.MaxRange)
		if
			far
			and far.root
			and flat(far.root.Position - root.Position).Magnitude
				> settings.Pound.MaxRange * reach
		then
			startWindup(current, "canister", settings.Canister.Windup, far.root)
			return true
		end
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
	if spec.PoundCooldown then
		current.poundCooldown = spec.PoundCooldown
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
	-- The call is the beat: a guard or a windup in progress gives way to it (a charge already
	-- running carries on and skips the roar).
	if not current.charge then
		if current.action == "guard" then
			cancelGuard(current)
		end
		if current.pending then
			current.pending = nil
			clearDanger()
			for _, name in { "pound", "sweep", "slam", "stomp" } do
				stop(current, name, 0.1)
			end
		end
		local now = os.clock()
		current.handle.humanoid:MoveTo(current.handle.root.Position)
		current.action = "riot"
		current.busyUntil = now + settings.RiotCallHold
		stop(current, "idle", 0.05)
		play(current, "riot", 0.1)
	end
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
	clearDanger()
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
	updateIdle(current)

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
		-- The beat: a walk at the squad before the next decision (AttackGap by phase).
		local gaps = settings.AttackGap
		current.nextDecisionAt = now + (gaps[math.clamp(current.phase, 1, #gaps)] or 0)
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
					(targetRoot.Position - handle.root.Position).Magnitude
					<= settings.SightingRange
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
	if
		current.action ~= "guard"
		and now >= current.nextDecisionAt
		and chooseAttack(current, now, target)
	then
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
		cooldowns = {
			charge = os.clock() + settings.Charge.FirstDelay,
			pound = os.clock() + settings.Charge.FirstDelay, -- the first move is never the Pound
		},
		chargeCooldown = settings.Charge.Cooldown,
		poundCooldown = settings.Pound.Cooldown,
		lastAttack = nil,
		nextDecisionAt = 0,
		plateHits = {},
		nextRepathAt = 0,
		nextSyncAt = 0,
		tracks = loadTracks(handle),
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
	Lifecycle.register("IndexService", {
		onRunStart = IndexService.reset,
	})
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
