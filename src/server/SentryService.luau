--!strict
-- Doorman (tripod sentry MG call-in, CallInService; replaced the Magpie drones' code): a
-- tripod gun stands where it lands for Config.CallIns.Doorman.Duration seconds, turns to
-- the nearest Infected in Range it can see (a ray from the gun's pivot) and fires every
-- FireInterval. The body is the modelled gun (Config Model 2: MeshAssets dep_doorman_base
-- stands still, _cradle yaws, _gun pitches at the trunnion) or the Part tripod (Model 1, and
-- whenever the meshes are not loaded). The round hits the first Infected on the line (DamageService.dealDamage
-- with the part struck, so the Warden's plates still count); the world blocks it, squad
-- members never take it. Server-simulated anchored parts; a short tracer per shot.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DamageService = require(script.Parent.DamageService)
local PauseService = require(script.Parent.PauseService)
local Lifecycle = require(script.Parent.Lifecycle)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)

local ENEMY_TAG = "Enemy"
local RETARGET_INTERVAL = 0.25
local MUZZLE_HEIGHT = 3.2 -- the Part body's pivot above the ground
local PART_MUZZLE_REACH = 1.8 -- and its muzzle ahead of that pivot
local BASE_MESH, CRADLE_MESH, GUN_MESH = "dep_doorman_base", "dep_doorman_cradle", "dep_doorman_gun"
local SHOT_SOUND = "rbxassetid://95252334560110" -- the rifle report (SoundFX "shoot")
local GUN_COLOR = Color3.fromRGB(52, 56, 48)
local TRACER_COLOR = Color3.fromRGB(255, 214, 140)
-- Folders the sentry's round passes through (squad, effects, pickups).
local PASS_THROUGH = {
	"Sentries",
	"SquadBots",
	"Resupply",
	"SupplyDrops",
	"Wire",
	"Mines",
	"FirePools",
	"CallInEffects",
	"StrikeEffects",
	"Projectiles",
	"InfectedProjectiles",
}

type Sentry = {
	model: Model,
	head: BasePart, -- the turning gun
	cradle: BasePart?, -- the modelled body's yaw piece (nil on the Part body)
	base: Vector3, -- the pivot the head turns around (the trunnion); it sees from here
	aim: CFrame, -- at `base`, looking down the barrel
	reach: number, -- the muzzle's distance ahead of `base`
	owner: Player,
	expiresAt: number,
	nextFireAt: number,
	nextRetargetAt: number,
	target: Humanoid?,
	sound: Sound,
}

local SentryService = {}

local folder: Folder
local sentries: { Sentry } = {}
local lastStep = 0

local function part(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Metal
	p.Color = GUN_COLOR
	p.Parent = parent
	return p
end

-- The tripod: three splayed legs, a cradle, and the gun (receiver + barrel welded as one
-- "Gun" model part we re-CFrame each frame).
local function build(at: Vector3, facing: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Doorman"
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		local foot = at + Vector3.new(math.cos(angle) * 1.4, 0, math.sin(angle) * 1.4)
		local top = at + Vector3.new(0, MUZZLE_HEIGHT - 0.6, 0)
		local mid = (foot + top) / 2
		part("Leg", Vector3.new(0.2, 0.2, (top - foot).Magnitude), CFrame.lookAt(mid, top), model)
	end
	part(
		"Cradle",
		Vector3.new(0.6, 0.5, 0.6),
		CFrame.new(at + Vector3.new(0, MUZZLE_HEIGHT - 0.45, 0)),
		model
	)
	local pivot = at + Vector3.new(0, MUZZLE_HEIGHT, 0)
	local head =
		part("Gun", Vector3.new(0.5, 0.55, 3.4), CFrame.lookAt(pivot, pivot + facing), model)
	head.Material = Enum.Material.SmoothPlastic
	local box =
		part("AmmoBox", Vector3.new(0.5, 0.5, 0.6), head.CFrame * CFrame.new(0.5, -0.1, 0.2), head)
	box.Color = Color3.fromRGB(86, 96, 62)
	model.PrimaryPart = head
	model.Parent = folder
	return model, head
end

-- The modelled body (doorman.py): the base where it stands, the cradle on the tripod head,
-- the gun on its trunnion. Nil while any of the three meshes is missing.
local function buildModelled(at: Vector3, facing: Vector3): (Model?, BasePart?, BasePart?)
	local cfg = Config.CallIns.Doorman
	local base = MeshAssets.clone(BASE_MESH)
	local cradle = if base then MeshAssets.clone(CRADLE_MESH) else nil
	local gun = if cradle then MeshAssets.clone(GUN_MESH) else nil
	if not (base and cradle and gun) then
		if base then
			base:Destroy()
		end
		if cradle then
			cradle:Destroy()
		end
		return nil, nil, nil
	end
	local stand = CFrame.lookAt(at, at + facing)
	local model = Instance.new("Model")
	model.Name = "Doorman"
	base.Name = "Base"
	base.CFrame = stand * CFrame.new(MeshAssets.getOffset(BASE_MESH))
	cradle.Name = "Cradle"
	cradle.CFrame = (stand + Vector3.new(0, cfg.YawHeight, 0))
		* CFrame.new(MeshAssets.getOffset(CRADLE_MESH))
	gun.Name = "Gun"
	gun.CFrame = (stand + Vector3.new(0, cfg.PitchHeight, 0))
		* CFrame.new(MeshAssets.getOffset(GUN_MESH))
	for _, piece in { base, cradle, gun } do
		piece.Parent = model
	end
	model.PrimaryPart = gun
	model.Parent = folder
	return model, gun, cradle
end

-- Turns the sentry to `target`: the Part gun looks straight at it; the modelled cradle
-- yaws and its gun pitches at the trunnion, no further than PitchLimit.
local function aimAt(sentry: Sentry, target: Vector3)
	local cradle = sentry.cradle
	if not cradle then
		sentry.aim = CFrame.lookAt(sentry.base, target)
		sentry.head.CFrame = sentry.aim
		for _, child in sentry.head:GetChildren() do
			if child:IsA("BasePart") then
				child.CFrame = sentry.aim * CFrame.new(0.5, -0.1, 0.2)
			end
		end
		return
	end
	local cfg = Config.CallIns.Doorman
	local offset = target - sentry.base
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local limit = math.rad(cfg.PitchLimit)
	local pitch = math.clamp(math.atan2(offset.Y, flat.Magnitude), -limit, limit)
	local yaw = CFrame.lookAt(sentry.base, sentry.base + flat)
	sentry.aim = yaw * CFrame.Angles(pitch, 0, 0)
	cradle.CFrame = (yaw + Vector3.new(0, cfg.YawHeight - cfg.PitchHeight, 0))
		* CFrame.new(MeshAssets.getOffset(CRADLE_MESH))
	sentry.head.CFrame = sentry.aim * CFrame.new(MeshAssets.getOffset(GUN_MESH))
end

local function exclusions(): { Instance }
	local list: { Instance } = {}
	for _, name in PASS_THROUGH do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(list, found)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- The Infected model (if any) a ray from `origin` to `target` hits first, and where.
local function lineOfFire(
	origin: Vector3,
	target: Vector3,
	params: RaycastParams
): (Model?, BasePart?, Vector3)
	-- Two studs past the root so the ray ends inside the body, not at its centre.
	local offset = target - origin
	local reach = offset + (if offset.Magnitude > 0.01 then offset.Unit * 2 else Vector3.zero)
	local result = workspace:Raycast(origin, reach, params)
	if not result then
		return nil, nil, target
	end
	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	while model and not CollectionService:HasTag(model, ENEMY_TAG) do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model, if model then hit else nil, result.Position
end

local function nearestVisible(origin: Vector3, range: number, params: RaycastParams): Humanoid?
	local best: Humanoid? = nil
	local bestDistance = range
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				local distance = (root.Position - origin).Magnitude
				if distance < bestDistance then
					local hitModel = lineOfFire(origin, root.Position, params)
					if hitModel then
						bestDistance = distance
						best = humanoid
					end
				end
			end
		end
	end
	return best
end

local function remove(index: number)
	sentries[index].model:Destroy()
	sentries[index] = sentries[#sentries]
	sentries[#sentries] = nil
end

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local line =
		part("Tracer", Vector3.new(0.12, 0.12, length), CFrame.lookAt((from + to) / 2, to), folder)
	line.Material = Enum.Material.Neon
	line.Color = TRACER_COLOR
	line.CastShadow = false
	task.delay(0.05, function()
		line:Destroy()
	end)
end

-- CallInService: a Doorman stands at `point` facing `facing` (the throw direction). Over
-- MaxPerPlayer the owner's oldest goes first.
function SentryService.deploy(owner: Player, point: Vector3, facing: Vector3): boolean
	local cfg = Config.CallIns.Doorman
	local count = 0
	for _, sentry in sentries do
		if sentry.owner == owner then
			count += 1
		end
	end
	while count >= cfg.MaxPerPlayer do
		for index, sentry in sentries do
			if sentry.owner == owner then
				remove(index)
				break
			end
		end
		count -= 1
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local model: Model, head: BasePart
	local cradle: BasePart? = nil
	local meshModel: Model?, meshGun: BasePart?, meshCradle: BasePart? = nil, nil, nil
	if cfg.Model == 2 then
		meshModel, meshGun, meshCradle = buildModelled(point, flat)
	end
	if meshModel and meshGun and meshCradle then
		model, head, cradle = meshModel, meshGun, meshCradle
	else
		model, head = build(point, flat)
	end
	local pivotHeight = if cradle then cfg.PitchHeight else MUZZLE_HEIGHT
	local pivot = point + Vector3.new(0, pivotHeight, 0)
	local sound = Instance.new("Sound")
	sound.Name = "Shot"
	sound.SoundId = SHOT_SOUND
	sound.Volume = 0.45
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 200
	sound.SoundGroup = SoundBanks.worldGroup()
	sound.Parent = head
	table.insert(sentries, {
		model = model,
		head = head,
		cradle = cradle,
		base = pivot,
		aim = CFrame.lookAt(pivot, pivot + flat),
		reach = if cradle then cfg.MuzzleReach else PART_MUZZLE_REACH,
		owner = owner,
		expiresAt = os.clock() + cfg.Duration,
		nextFireAt = os.clock() + 0.6,
		nextRetargetAt = 0,
		target = nil,
		sound = sound,
	})
	return true
end

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, sentry in sentries do
			sentry.expiresAt += shift
			sentry.nextFireAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	if #sentries == 0 then
		return
	end
	local cfg = Config.CallIns.Doorman
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	for index = #sentries, 1, -1 do
		local sentry = sentries[index]
		if now >= sentry.expiresAt or not sentry.model.Parent or not sentry.owner.Parent then
			remove(index)
			continue
		end
		local target = sentry.target
		if
			now >= sentry.nextRetargetAt
			or not target
			or target.Health <= 0
			or not target.Parent
		then
			sentry.nextRetargetAt = now + RETARGET_INTERVAL
			target = nearestVisible(sentry.base, cfg.Range, params)
			sentry.target = target
		end
		local targetModel = target and target.Parent
		local root = targetModel and targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		aimAt(sentry, root.Position)
		if now < sentry.nextFireAt then
			continue
		end
		sentry.nextFireAt = now + cfg.FireInterval
		local muzzle = sentry.aim * Vector3.new(0, 0, -sentry.reach)
		local hitModel, hitPart, hitAt = lineOfFire(muzzle, root.Position, params)
		tracer(muzzle, hitAt)
		sentry.sound.PlaybackSpeed = 1.1 + math.random() * 0.1
		sentry.sound:Play()
		local humanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			DamageService.dealDamage(sentry.owner, humanoid, cfg.Damage, hitAt, "hit", hitPart)
		else
			-- The world took the round: look for a clear target next frame.
			sentry.nextRetargetAt = 0
		end
	end
end

-- Doormen standing for `player` (dev tools); every Doorman when nil.
function SentryService.count(player: Player?): number
	if not player then
		return #sentries
	end
	local count = 0
	for _, sentry in sentries do
		if sentry.owner == player then
			count += 1
		end
	end
	return count
end

function SentryService.reset()
	for _, sentry in sentries do
		sentry.model:Destroy()
	end
	table.clear(sentries)
	if folder then
		folder:ClearAllChildren()
	end
end

function SentryService.init()
	Lifecycle.register("SentryService", {
		onRunStart = SentryService.reset,
		onPlayerRemoving = function(player: Player)
			for index = #sentries, 1, -1 do
				if sentries[index].owner == player then
					remove(index)
				end
			end
		end,
	})
	folder = Instance.new("Folder")
	folder.Name = "Sentries"
	folder.Parent = workspace
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)
end

return SentryService
