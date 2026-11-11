--!strict
-- Fire missions (call-ins, CallInService), the thrown marker lands and the guns answer:
--   Hammer (81 mm mortar, Config.CallIns.Hammer): Shells land Scatter studs around the mark,
--     the first Delay seconds after the throw, then ShellInterval apart. Walk It In
--     (walking_barrage): each shell lands Config.Upgrades.WalkingBarrage.Step further along
--     the throw.
--   Anvil (105 mm, Config.CallIns.Anvil): the same path, one heavy shell.
--   Shrike (helicopter gun run, Config.CallIns.Shrike): after Delay a gunship passes along
--     the throw; Bursts impacts centred on the mark, Step studs apart, BurstInterval apart.
-- Every impact is a BlastRadius area hit on the Infected only (DamageService.dealDamage; no
-- friendly fire); a blast kill throws limbs (GoreService.blast). Geometry and timing come
-- from Rules/StrikePattern.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local StrikePattern = require(ReplicatedStorage.Shared.Rules.StrikePattern)
local DamageService = require(script.Parent.DamageService)
local GoreService = require(script.Parent.GoreService)
local PauseService = require(script.Parent.PauseService)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ENEMY_TAG = "Enemy"
local MARKER_COLOR = Color3.fromRGB(214, 69, 51)
local SHRIKE_COLOR = Color3.fromRGB(255, 196, 90)
local GUNSHIP_COLOR = Color3.fromRGB(58, 64, 52)

export type Shell = {
	BlastRadius: number,
	BlastDamage: number,
}

-- A call-in block's own camera shake (ShakePower, ShakeGlobal): a call-in added to the
-- loadouts brings its own; Config.Camera.Shake.DefaultPower when it names none.
local function shakeOf(cfg: any): (number, number?)
	return cfg.ShakePower or Config.Camera.Shake.DefaultPower, cfg.ShakeGlobal
end

local AirStrikeService = {}

local effectFolder: Folder
-- Bumped on reset so a mission from the last run never lands in the next.
local generation = 0

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

-- The visible blast, tagged for the client screen shake (CameraController): `power` from
-- the call-in's ShakePower, `global` shake felt at any distance (its ShakeGlobal).
local function flash(
	center: Vector3,
	radius: number,
	color: Color3,
	seconds: number,
	power: number,
	global: number?
)
	local blast = Instance.new("Part")
	blast.Shape = Enum.PartType.Ball
	blast.Size = Vector3.new(2, 2, 2)
	blast.Position = center
	blast.Anchored = true
	blast.CanCollide = false
	blast.CanQuery = false
	blast.CanTouch = false
	blast.CastShadow = false
	blast.Material = Enum.Material.Neon
	blast.Color = color
	blast:SetAttribute(Attributes.BlastPower, power)
	if global then
		blast:SetAttribute(Attributes.BlastGlobal, global)
	end
	CollectionService:AddTag(blast, Attributes.BlastTag)
	blast.Parent = effectFolder
	TweenService
		:Create(blast, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * radius * 2,
			Transparency = 1,
		})
		:Play()
	task.delay(seconds + 0.05, function()
		blast:Destroy()
	end)
end

-- Area damage on the Infected around `center` (the one place a fire mission hurts).
local function hurtAround(player: Player?, center: Vector3, shell: Shell)
	for _, root in enemyRootsNear(center, shell.BlastRadius) do
		local model = root.Parent :: Model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			DamageService.dealDamage(player, humanoid, shell.BlastDamage, root.Position, "hit")
			if humanoid.Health <= 0 then
				GoreService.blast(humanoid, center)
			end
		end
	end
end

local function detonate(player: Player?, center: Vector3, shell: Shell)
	-- Stock Explosion for the flash and boom only: zeroed radius/pressure so it can't hurt
	-- anyone; damage is applied manually below.
	local boom = Instance.new("Explosion")
	boom.Position = center
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace
	local power, global = shakeOf(shell)
	flash(center, shell.BlastRadius, Color3.fromRGB(255, 140, 40), 0.45, power, global)
	hurtAround(player, center, shell)
end

local function marker(at: Vector3, radius: number): BasePart
	local disc = Instance.new("Part")
	disc.Name = "StrikeMarker"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = MARKER_COLOR
	disc.Transparency = 0.45
	disc.Parent = effectFolder
	return disc
end

-- Waits `seconds` of unpaused time (a mission in the air holds while paused).
local function waitUnpaused(seconds: number)
	local remaining = seconds
	while remaining > 0 do
		local dt = task.wait()
		if not PauseService.isPaused() then
			remaining -= dt
		end
	end
end

local function flatUnit(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

export type MissionConfig = {
	Delay: number,
	Shells: number,
	ShellInterval: number,
	BlastRadius: number,
	BlastDamage: number,
	Scatter: number,
}

-- CallInService (Hammer, Anvil): shells from `cfg` land around `point`; `direction` is the
-- flat throw direction, `step` how far each shell walks along it (Walk It In; 0 otherwise).
function AirStrikeService.fireMission(
	player: Player?, -- nil for a bot (no kill credit)
	cfg: MissionConfig,
	point: Vector3,
	direction: Vector3,
	step: number
): boolean
	local flat = flatUnit(direction)
	local impacts: { Vector3 } = {}
	local markers: { BasePart } = {}
	for _, offset in StrikePattern.offsets(cfg.Shells, step, false) do
		local scatter = Vector3.new(
			(math.random() * 2 - 1) * cfg.Scatter,
			0,
			(math.random() * 2 - 1) * cfg.Scatter
		)
		local impact = GroundUtil.GetGroundPosition(point + flat * offset + scatter, 0.05)
		table.insert(impacts, impact)
		table.insert(markers, marker(impact, cfg.BlastRadius))
	end

	local thisGeneration = generation
	local lead = Config.Audio.AnvilIncomingLead
	for index, at in StrikePattern.impactTimes(cfg.Shells, cfg.Delay, cfg.ShellInterval) do
		local impact = impacts[index]
		task.spawn(function()
			waitUnpaused(math.max(at - lead, 0))
			if thisGeneration ~= generation then
				return
			end
			WorldSounds.at(impact + Vector3.new(0, 30, 0), "callins", "anvil_incoming")
			waitUnpaused(math.min(lead, at))
			if thisGeneration ~= generation then
				return
			end
			local disc = markers[index]
			if disc.Parent then
				disc:Destroy()
			end
			WorldSounds.at(impact, "callins", "anvil_blast")
			detonate(player, impact + Vector3.new(0, 2, 0), cfg)
		end)
	end
	return true
end

-- The gunship's pass over the run (look only): the Shrike flies along the throw at
-- PassHeight with the rotor loop on it, its main rotor turning. The modelled helicopter
-- (MeshAssets veh_shrike_hull / _rotor, aircraft.py) when it loaded, else a plain hull.
-- Returns where its gun is right now (nil once it has gone).
local function gunshipPass(
	first: Vector3,
	last: Vector3,
	flat: Vector3,
	seconds: number
): () -> Vector3?
	local cfg = Config.CallIns.Shrike
	local height = Vector3.new(0, cfg.PassHeight, 0)
	local lead = flat * 60
	local from = first + height - lead
	local to = last + height + lead
	local mesh = MeshAssets.clone("veh_shrike_hull")
	local rotor: BasePart? = if mesh then MeshAssets.clone("veh_shrike_rotor") else nil
	local hullOffset = if mesh then MeshAssets.getOffset("veh_shrike_hull") else Vector3.zero
	local rotorOffset = MeshAssets.getOffset("veh_shrike_rotor")
	local body: BasePart
	if mesh then
		body = mesh
	else
		local box = Instance.new("Part")
		box.Size = Vector3.new(5, 3, 14)
		box.Material = Enum.Material.SmoothPlastic
		box.Color = GUNSHIP_COLOR
		body = box
	end
	local parts: { BasePart } = { body }
	if rotor then
		table.insert(parts, rotor)
	end
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	body.Name = "ShrikeGunship"
	body.Parent = effectFolder
	if rotor then
		rotor.Name = "Rotor"
		rotor.CastShadow = false
		rotor.Parent = body
	end
	WorldSounds.loopOn(body, "ambience", "lantern_rotor")

	local started = os.clock()
	local origin = CFrame.lookAt(from, from + flat)
	local function place(t: number)
		local at = from:Lerp(to, t)
		origin = CFrame.lookAt(at, at + flat)
		body.CFrame = origin * CFrame.new(hullOffset)
		if rotor then
			local spin = math.rad((os.clock() - started) * cfg.RotorSpin)
			rotor.CFrame = origin
				* CFrame.new(cfg.RotorHub)
				* CFrame.Angles(0, spin, 0)
				* CFrame.new(rotorOffset)
		end
	end
	place(0)
	local flight: RBXScriptConnection
	flight = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - started) / seconds
		if t >= 1 or not body.Parent then
			flight:Disconnect()
			body:Destroy()
			return
		end
		place(t)
	end)
	return function(): Vector3?
		if not body.Parent then
			return nil
		end
		return (origin * CFrame.new(cfg.GunMuzzle)).Position
	end
end

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local line = Instance.new("Part")
	line.Name = "Tracer"
	line.Size = Vector3.new(0.3, 0.3, length)
	line.CFrame = CFrame.lookAt((from + to) / 2, to)
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = SHRIKE_COLOR
	line.Parent = effectFolder
	task.delay(0.08, function()
		line:Destroy()
	end)
end

-- CallInService (Shrike): the gun run lands along `direction` through `point`.
function AirStrikeService.gunRun(player: Player, point: Vector3, direction: Vector3): boolean
	local cfg = Config.CallIns.Shrike
	local flat = flatUnit(direction)
	local impacts: { Vector3 } = {}
	for _, offset in StrikePattern.offsets(cfg.Bursts, cfg.Step, true) do
		table.insert(impacts, GroundUtil.GetGroundPosition(point + flat * offset, 0.05))
	end

	-- One strip marker over the whole run.
	local span = cfg.Step * (cfg.Bursts - 1) + cfg.BlastRadius * 2
	local strip = Instance.new("Part")
	strip.Name = "StrikeMarker"
	strip.Size = Vector3.new(cfg.BlastRadius * 2, 0.3, span)
	strip.CFrame = CFrame.lookAt(point, point + flat) + Vector3.new(0, 0.1, 0)
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	strip.Material = Enum.Material.Neon
	strip.Color = MARKER_COLOR
	strip.Transparency = 0.5
	strip.Parent = effectFolder

	local thisGeneration = generation
	task.spawn(function()
		local runTime = cfg.BurstInterval * (cfg.Bursts - 1)
		-- The gunship comes in from behind the throw so it is overhead for the bursts.
		local approach = math.min(1.5, cfg.Delay)
		waitUnpaused(cfg.Delay - approach)
		if thisGeneration ~= generation then
			return
		end
		local gunAt = gunshipPass(impacts[1], impacts[#impacts], flat, approach * 2 + runTime)
		waitUnpaused(approach)
		if strip.Parent then
			strip:Destroy()
		end
		for index, impact in impacts do
			if thisGeneration ~= generation then
				return
			end
			local muzzle = gunAt() or impact + Vector3.new(0, 40, 0)
			tracer(muzzle, impact)
			local power = shakeOf(cfg)
			flash(impact + Vector3.new(0, 1, 0), cfg.BlastRadius, SHRIKE_COLOR, 0.25, power)
			if index % 2 == 1 then
				WorldSounds.at(impact, "callins", "tripline_blast", 0.6)
			end
			hurtAround(player, impact + Vector3.new(0, 1, 0), cfg)
			if index < #impacts then
				waitUnpaused(cfg.BurstInterval)
			end
		end
	end)
	return true
end

function AirStrikeService.reset()
	generation += 1
	if effectFolder then
		effectFolder:ClearAllChildren()
	end
end

function AirStrikeService.init()
	Lifecycle.register("AirStrikeService", {
		onRunStart = AirStrikeService.reset,
	})
	effectFolder = Instance.new("Folder")
	effectFolder.Name = "StrikeEffects"
	effectFolder.Parent = workspace
end

return AirStrikeService
