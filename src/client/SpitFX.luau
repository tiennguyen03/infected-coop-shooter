--!strict
-- How an Infected spit looks (owner, 2026-11-11: the Hocker's spit was "just a yellow
-- circle"). The server owns the arc, the hit and the puddle damage and makes no parts
-- (EnemyProjectileService); it reports each step on Remotes EnemySpit and this draws it:
--   windup: the spitter's head goes back and bile runs from its mouth, then it snaps forward
--   launch: a stretched, wobbling glob along its path, a darker clot dragging behind on a
--           strand, drops falling off
--   impact: a burst of drops off the surface, a blotch on a wall, and on the ground the pool:
--           a core disc of exactly the damage radius over a dark rim, bubbling, fading out as
--           its damage ends. Splashed players get a bile smear at the screen edges.
-- Budget (docs/STYLES.md > Performance budget): every body is pooled and reused; nine
-- emitters in all, burst only (`Emit`), whatever the number of spitters; splats and pools
-- are capped, oldest first. Looks and caps: Config.Enemies.SpitFX; curves: Rules/SpitShape.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Messages = require(Shared:WaitForChild("Messages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpitShape = require(Shared:WaitForChild("Rules"):WaitForChild("SpitShape"))
local HudTheme = require(script.Parent.HudTheme)

local SpitFX = {}

local CFG = Config.Enemies.SpitFX

local GLOB_SHAPE: SpitShape.GlobSettings = {
	stretch = CFG.Glob.Stretch,
	speedStretch = CFG.Glob.SpeedStretch,
	maxStretch = CFG.Glob.MaxStretch,
	wobble = CFG.Glob.Wobble,
	wobbleRate = CFG.Glob.WobbleRate,
}
local POOL_SHAPE: SpitShape.PoolSettings = {
	grow = CFG.Pool.Grow,
	startSize = CFG.Pool.StartSize,
	fade = CFG.Pool.Fade,
}
local REAR_SHAPE: SpitShape.RearSettings = {
	back = CFG.Tell.HeadBack,
	lunge = CFG.Tell.Lunge,
	recover = CFG.Tell.Recover,
}

-- The engine's soft round sprite; small and opaque it reads as a drop.
local DROP_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local GLOB_TIMEOUT = 10 -- seconds a glob flies with no word from the server before it goes
local DEFAULT_SIZE = 1.4 -- a splat whose glob this client never saw
local POOL_HEIGHT = 0.12
local RIM_HEIGHT = 0.1
local RIM_DROP = 0.03 -- the rim sits this far under the core, so the two never z-fight
local SPLAT_HEIGHT = 0.05
local SPLAT_GROW = 0.12 -- seconds a blotch takes to spread
local SMEAR_DEPTH = 0.3 -- how far each smeared edge reaches into the screen
local DROP_BURST = 4 -- drops the shared allowance can save up
local RING = 3 -- hosts per emitter kind, used in turn (two bursts in one frame keep their places)

type Glob = {
	id: number,
	part: Part,
	mesh: SpecialMesh,
	tail: Part,
	tailMesh: SpecialMesh,
	trail: Trail,
	left: Attachment,
	right: Attachment,
	origin: Vector3,
	velocity: Vector3,
	size: number,
	launchedAt: number,
	nextDripAt: number,
	phase: number,
}

type Pool = {
	core: Part,
	rim: Part,
	ground: CFrame,
	radius: number,
	duration: number,
	bornAt: number,
	nextBubbleAt: number,
	settled: boolean, -- full size and solid: nothing to set until the fade
}

type Splat = {
	parts: { Part },
	sizes: { number },
	bornAt: number,
	settled: boolean,
}

type Windup = {
	model: Model,
	head: BasePart,
	neck: Motor6D?,
	base: CFrame,
	seconds: number,
	startedAt: number,
	nextDroolAt: number,
}

type Host = { part: Part, emitter: ParticleEmitter }

local folder: Folder
local globs: { Glob } = {}
local freeGlobs: { Glob } = {}
local pools: { Pool } = {}
local freePools: { Pool } = {}
local splats: { Splat } = {}
local freeSplats: { Splat } = {}
local windups: { Windup } = {}

local dripHosts: { Host } = {}
local burstHosts: { Host } = {}
local bubbleHosts: { Host } = {}
local hostTurn = 0
local dropAllowance = 0

local smearGui: ScreenGui
local smearEdges: { Frame } = {}
local smearStartedAt = -math.huge

-- A CFrame at `position` looking along `direction` (safe when that is straight up or down).
local function facing(position: Vector3, direction: Vector3): CFrame
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + direction, up)
end

local function body(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	return part
end

local function disc(name: string, color: Color3): Part
	local part = body(name, color)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Lays a disc (a Cylinder: its axis is X) flat on `surface`, whose look direction is the
-- surface normal, `offset` studs across it and `lift` studs off it.
local function layDisc(part: Part, surface: CFrame, offset: Vector2, lift: number)
	part.CFrame = surface
		* CFrame.new(offset.X, offset.Y, -lift)
		* CFrame.Angles(0, math.rad(90), 0)
end

---------------------------------------------------------------------------------------------
-- Drops: three kinds of emitter, a few hosts each, moved to where the drop is wanted.

local function host(name: string, build: (ParticleEmitter) -> ()): Host
	local part = body(name, Color3.new())
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = DROP_TEXTURE
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Rotation = NumberRange.new(0, 360)
	build(emitter)
	emitter.Parent = part
	part.Parent = folder
	return { part = part, emitter = emitter }
end

local function buildHosts()
	local drops = CFG.Drops
	local colors = ColorSequence.new(drops.Color, drops.DarkColor)
	for index = 1, RING do
		dripHosts[index] = host("SpitDrip", function(emitter)
			emitter.Color = colors
			emitter.Size = NumberSequence.new(drops.Size, drops.Size * 0.4)
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.7, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(0.45, 0.8)
			emitter.Speed = NumberRange.new(0, 2.5)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Acceleration = Vector3.new(0, -38, 0)
		end)
		burstHosts[index] = host("SpitBurst", function(emitter)
			emitter.Color = colors
			emitter.Size = NumberSequence.new(drops.Size * 1.6, drops.Size * 0.5)
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.6, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(0.35, 0.75)
			emitter.Speed = NumberRange.new(CFG.Impact.BurstSpeed * 0.4, CFG.Impact.BurstSpeed)
			emitter.SpreadAngle = Vector2.new(65, 65)
			emitter.EmissionDirection = Enum.NormalId.Front
			emitter.Acceleration = Vector3.new(0, -55, 0)
			emitter.Drag = 1.5
		end)
		bubbleHosts[index] = host("SpitBubble", function(emitter)
			emitter.Color = ColorSequence.new(CFG.Pool.BubbleColor)
			-- Swells, holds, pops.
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.6, 0.5),
				NumberSequenceKeypoint.new(0.9, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.9, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(0.5, 0.9)
			emitter.Speed = NumberRange.new(0.2, 0.6)
			emitter.SpreadAngle = Vector2.zero
			emitter.EmissionDirection = Enum.NormalId.Top
		end)
	end
end

local function nextHost(hosts: { Host }): Host
	hostTurn = hostTurn % RING + 1
	return hosts[hostTurn]
end

-- One falling drop, if the shared allowance (Drops.MaxPerSecond) has one to give.
local function drop(position: Vector3)
	if dropAllowance < 1 then
		return
	end
	dropAllowance -= 1
	local target = nextHost(dripHosts)
	target.part.Position = position
	target.emitter:Emit(1)
end

---------------------------------------------------------------------------------------------
-- The glob in flight.

local function newGlob(): Glob
	local glob = CFG.Glob
	local part = body("SpitGlob", glob.Color)
	part.Size = Vector3.one
	part.Reflectance = glob.Reflectance
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	local tail = body("SpitClot", glob.TailColor)
	tail.Size = Vector3.one
	tail.Reflectance = glob.Reflectance
	local tailMesh = Instance.new("SpecialMesh")
	tailMesh.MeshType = Enum.MeshType.Sphere
	tailMesh.Parent = tail
	local left = Instance.new("Attachment")
	left.Parent = part
	local right = Instance.new("Attachment")
	right.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = left
	trail.Attachment1 = right
	trail.Enabled = false
	trail.FaceCamera = true
	trail.Lifetime = glob.StrandLife
	trail.MinLength = 0.05
	trail.Color = ColorSequence.new(glob.StrandColor)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.LightEmission = 0
	trail.LightInfluence = 1
	trail.Parent = part
	return {
		id = 0,
		part = part,
		mesh = mesh,
		tail = tail,
		tailMesh = tailMesh,
		trail = trail,
		left = left,
		right = right,
		origin = Vector3.zero,
		velocity = Vector3.zero,
		size = 1,
		launchedAt = 0,
		nextDripAt = 0,
		phase = 0,
	}
end

local function arc(glob: Glob, t: number): Vector3
	return glob.origin + glob.velocity * t - Vector3.new(0, 0.5 * workspace.Gravity * t * t, 0)
end

local function placeGlob(glob: Glob, t: number)
	local position = arc(glob, t)
	local velocity = glob.velocity - Vector3.new(0, workspace.Gravity * t, 0)
	local speed = velocity.Magnitude
	local direction = if speed > 1e-3 then velocity / speed else Vector3.yAxis
	local size = glob.size
	local length, width = SpitShape.glob(t, speed, GLOB_SHAPE)
	-- A second, slower wobble across the glob, so its section is never a clean circle.
	local across = 0.12 * math.sin(t * CFG.Glob.WobbleRate * 5 + glob.phase)
	glob.part.CFrame = facing(position, direction)
	glob.mesh.Scale = Vector3.new(width * (1 + across), width * (1 - across), length) * size
	-- The clot rides the same arc a little behind, wobbling out of step.
	local lag = CFG.Glob.TailLag * length * size / math.max(speed, 1)
	local tailLength, tailWidth = SpitShape.glob(t + 0.5 / CFG.Glob.WobbleRate, speed, GLOB_SHAPE)
	glob.tail.CFrame = facing(arc(glob, math.max(t - lag, 0)), direction)
	glob.tailMesh.Scale = Vector3.new(tailWidth, tailWidth, tailLength * 1.3)
		* size
		* CFG.Glob.TailSize
end

local function releaseGlob(index: number)
	local glob = globs[index]
	table.remove(globs, index)
	glob.trail.Enabled = false
	glob.part.Parent = nil
	glob.tail.Parent = nil
	table.insert(freeGlobs, glob)
end

local function releaseGlobById(id: number): number?
	for index, glob in globs do
		if glob.id == id then
			local size = glob.size
			releaseGlob(index)
			return size
		end
	end
	return nil
end

local function launch(id: number, origin: Vector3, velocity: Vector3, size: number)
	local glob = table.remove(freeGlobs) or newGlob()
	glob.id = id
	glob.origin = origin
	glob.velocity = velocity
	glob.size = size
	glob.launchedAt = os.clock()
	glob.nextDripAt = glob.launchedAt + CFG.Glob.DripInterval
	glob.phase = math.random() * math.pi * 2
	local half = size * CFG.Glob.StrandWidth * 0.5
	glob.left.Position = Vector3.new(-half, 0, 0)
	glob.right.Position = Vector3.new(half, 0, 0)
	placeGlob(glob, 0)
	glob.part.Parent = folder
	glob.tail.Parent = folder
	glob.trail:Clear()
	glob.trail.Enabled = true
	table.insert(globs, glob)
end

local function stepGlobs(now: number)
	for index = #globs, 1, -1 do
		local glob = globs[index]
		local t = now - glob.launchedAt
		if t > GLOB_TIMEOUT then
			releaseGlob(index)
			continue
		end
		placeGlob(glob, t)
		if now >= glob.nextDripAt then
			glob.nextDripAt = now + CFG.Glob.DripInterval
			drop(glob.tail.Position)
		end
	end
end

---------------------------------------------------------------------------------------------
-- The blotch a hit leaves: one disc and a few smaller ones round it, so the edge is uneven.

local function newSplat(): Splat
	local parts = {}
	for index = 1, 1 + CFG.Impact.SplatLobes do
		parts[index] = disc("SpitSplat", CFG.Impact.SplatColor)
	end
	return { parts = parts, sizes = {}, bornAt = 0, settled = false }
end

local function releaseSplat(index: number)
	local splat = splats[index]
	table.remove(splats, index)
	for _, part in splat.parts do
		part.Parent = nil
	end
	table.insert(freeSplats, splat)
end

-- `blotch` is the middle disc's diameter (0: none, the lobes only); the lobes sit `reach`
-- studs out from the middle and are `lobe` studs across, give or take.
local function splatAt(surface: CFrame, blotch: number, reach: number, lobe: number, lift: number)
	if #splats >= CFG.Impact.MaxSplats then
		releaseSplat(1)
	end
	local splat = table.remove(freeSplats) or newSplat()
	splat.bornAt = os.clock()
	splat.settled = false
	local turn = math.random() * math.pi * 2
	local lobes = if blotch > 0 then #splat.parts - 1 else #splat.parts
	for index, part in splat.parts do
		local offset = Vector2.zero
		local size = blotch
		if index > 1 or blotch <= 0 then
			local angle = turn + index / math.max(lobes, 1) * math.pi * 2 + math.random() * 0.8
			local out = reach * (0.85 + math.random() * 0.25)
			offset = Vector2.new(math.cos(angle), math.sin(angle)) * out
			size = lobe * (0.7 + math.random() * 0.6)
		end
		splat.sizes[index] = size
		part.Size = Vector3.new(SPLAT_HEIGHT, size * 0.4, size * 0.4)
		part.Transparency = 0.05
		layDisc(part, surface, offset, lift + index * 0.004)
		part.Parent = folder
	end
	table.insert(splats, splat)
end

local function stepSplats(now: number)
	local life = CFG.Impact.SplatLife
	for index = #splats, 1, -1 do
		local splat = splats[index]
		local age = now - splat.bornAt
		if age >= life then
			releaseSplat(index)
			continue
		end
		local fading = age > life * 0.5
		if splat.settled and not fading then
			continue
		end
		local grown = math.clamp(age / SPLAT_GROW, 0, 1)
		local share = 0.4 + 0.6 * grown
		local fade = if fading then (age - life * 0.5) / (life * 0.5) else 0
		for partIndex, part in splat.parts do
			local size = splat.sizes[partIndex] * share
			part.Size = Vector3.new(SPLAT_HEIGHT, size, size)
			part.Transparency = 0.05 + 0.95 * fade
		end
		splat.settled = grown >= 1
	end
end

---------------------------------------------------------------------------------------------
-- The damaging pool.

local function newPool(): Pool
	local core = disc("SpitPool", CFG.Pool.Color)
	core.Reflectance = CFG.Glob.Reflectance
	local rim = disc("SpitPoolRim", CFG.Pool.EdgeColor)
	return {
		core = core,
		rim = rim,
		ground = CFrame.identity,
		radius = 1,
		duration = 1,
		bornAt = 0,
		nextBubbleAt = 0,
		settled = false,
	}
end

local function releasePool(index: number)
	local pool = pools[index]
	table.remove(pools, index)
	pool.core.Parent = nil
	pool.rim.Parent = nil
	table.insert(freePools, pool)
end

local function shapePool(pool: Pool, age: number)
	local share, fade = SpitShape.pool(age, pool.duration, POOL_SHAPE)
	local across = pool.radius * 2 * share
	local rimAcross = (pool.radius + CFG.Pool.EdgeWidth) * 2 * share
	pool.core.Size = Vector3.new(POOL_HEIGHT, across, across)
	pool.rim.Size = Vector3.new(RIM_HEIGHT, rimAcross, rimAcross)
	pool.core.Transparency = CFG.Pool.Transparency + (1 - CFG.Pool.Transparency) * fade
	pool.rim.Transparency = fade
	pool.settled = share >= 1 and fade <= 0
end

local function poolAt(ground: CFrame, radius: number, duration: number)
	-- The server drops its oldest puddle past the same cap, in the same order.
	if #pools >= Config.Enemies.MaxPuddles then
		releasePool(1)
	end
	local pool = table.remove(freePools) or newPool()
	local now = os.clock()
	pool.ground = ground
	pool.radius = radius
	pool.duration = duration
	pool.bornAt = now
	pool.nextBubbleAt = now + CFG.Pool.BubbleInterval * math.random()
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X
	pool.core.CFrame = ground * flat
	pool.rim.CFrame = ground * CFrame.new(0, -RIM_DROP, 0) * flat
	shapePool(pool, 0)
	pool.core.Parent = folder
	pool.rim.Parent = folder
	table.insert(pools, pool)
end

local function stepPools(now: number)
	for index = #pools, 1, -1 do
		local pool = pools[index]
		local age = now - pool.bornAt
		if age >= pool.duration then
			releasePool(index)
			continue
		end
		local fading = age > pool.duration - CFG.Pool.Fade
		if not pool.settled or fading then
			shapePool(pool, age)
		end
		if now >= pool.nextBubbleAt and not fading then
			pool.nextBubbleAt = now + CFG.Pool.BubbleInterval * (0.6 + math.random() * 0.8)
			-- Toward the rim more than the middle: froth marks the edge.
			local out = pool.radius * (0.35 + 0.6 * math.random())
			local angle = math.random() * math.pi * 2
			local target = nextHost(bubbleHosts)
			target.part.Position = (pool.ground * CFrame.new(
				math.cos(angle) * out,
				POOL_HEIGHT,
				math.sin(angle) * out
			)).Position
			target.emitter:Emit(1)
		end
	end
end

---------------------------------------------------------------------------------------------
-- The smear on a splashed player's screen: four strips fading inward, like the low-health
-- vignette (LowHealthFX) and under the HUD the same way.

local function buildSmear()
	smearGui = Instance.new("ScreenGui")
	smearGui.Name = "SpitSmear"
	smearGui.ResetOnSpawn = false
	smearGui.IgnoreGuiInset = true
	smearGui.DisplayOrder = -1
	smearGui.Enabled = false
	local layout = {
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(1, SMEAR_DEPTH), rotation = 90 },
		{ anchor = Vector2.new(0, 1), size = UDim2.fromScale(1, SMEAR_DEPTH), rotation = -90 },
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(SMEAR_DEPTH, 1), rotation = 0 },
		{ anchor = Vector2.new(1, 0), size = UDim2.fromScale(SMEAR_DEPTH, 1), rotation = 180 },
	}
	for index, edge in layout do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = edge.anchor
		frame.Position = UDim2.fromScale(edge.anchor.X, edge.anchor.Y)
		frame.Size = edge.size
		frame.BackgroundColor3 = CFG.Smear.Color
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Active = false
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = smearGui
		smearEdges[index] = frame
	end
	HudTheme.parent(smearGui)
end

local function stepSmear(now: number)
	if not smearGui.Enabled then
		return
	end
	local left = 1 - (now - smearStartedAt) / CFG.Smear.Time
	if left <= 0 then
		smearGui.Enabled = false
		return
	end
	-- Runs off quickly at first, the last of it lingering.
	local transparency = 1 - CFG.Smear.Strength * left * left
	for _, frame in smearEdges do
		frame.BackgroundTransparency = transparency
	end
end

local function smearIfSplashed(position: Vector3, splashRadius: number)
	if not CFG.Smear.Enabled then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= splashRadius then
		smearStartedAt = os.clock()
		smearGui.Enabled = true
	end
end

---------------------------------------------------------------------------------------------
-- The tell: the spitter's head through its windup. The neck's C0 is changed on this client
-- only (the server and the body's clips never touch it) and put back when the tell ends.

local function endWindup(index: number)
	local windup = windups[index]
	table.remove(windups, index)
	local neck = windup.neck
	if neck and neck.Parent then
		neck.C0 = windup.base
	end
end

local function startWindup(model: Model, seconds: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	-- A second windup on a body still settling from its last: start again from level.
	for index = #windups, 1, -1 do
		if windups[index].model == model then
			endWindup(index)
		end
	end
	local neck = head:FindFirstChild("Neck")
	local joint: Motor6D? = if neck and neck:IsA("Motor6D") then neck else nil
	local now = os.clock()
	table.insert(windups, {
		model = model,
		head = head,
		neck = joint,
		base = if joint then joint.C0 else CFrame.identity,
		seconds = seconds,
		startedAt = now,
		nextDroolAt = now + CFG.Tell.DroolInterval,
	})
end

local function stepWindups(now: number)
	for index = #windups, 1, -1 do
		local windup = windups[index]
		local age = now - windup.startedAt
		local neck = windup.neck
		-- Killed mid-windup: the ragdoll switches the joint off (EnemyService) and the body goes.
		local gone = windup.head.Parent == nil
			or not windup.model:IsDescendantOf(workspace)
			or (neck ~= nil and (neck.Parent == nil or not neck.Enabled))
		if gone or age >= windup.seconds + CFG.Tell.Recover then
			endWindup(index)
			continue
		end
		if neck then
			local degrees = SpitShape.rear(age, windup.seconds, REAR_SHAPE)
			neck.C0 = windup.base * CFrame.Angles(math.rad(degrees), 0, 0)
		end
		if age < windup.seconds and now >= windup.nextDroolAt then
			windup.nextDroolAt = now + CFG.Tell.DroolInterval
			local headCFrame = windup.head.CFrame
			drop(headCFrame.Position + headCFrame.LookVector * 0.6 - headCFrame.UpVector * 0.25)
		end
	end
end

---------------------------------------------------------------------------------------------

local function impact(
	id: number,
	position: Vector3,
	normal: Vector3,
	splashRadius: number,
	poolGround: CFrame?,
	poolRadius: number?,
	poolSeconds: number?
)
	local size = releaseGlobById(id) or DEFAULT_SIZE
	local burst = nextHost(burstHosts)
	burst.part.CFrame = facing(position + normal * 0.2, normal)
	burst.emitter:Emit(CFG.Impact.Burst)
	local blotch = CFG.Impact.SplatSize * size
	if poolGround and poolRadius and poolSeconds then
		poolAt(poolGround, poolRadius, poolSeconds)
		-- On the floor the pool is the blotch: the lobes go round its edge instead, under
		-- the rim, and are gone before the pool is.
		if normal.Y > 0.7 then
			local surface = facing(poolGround.Position, poolGround.UpVector)
			splatAt(surface, 0, poolRadius, poolRadius * 0.4, -RIM_DROP - RIM_HEIGHT * 0.5)
		else
			splatAt(facing(position, normal), blotch, blotch * 0.45, blotch * 0.4, 0.03)
		end
	else
		splatAt(facing(position, normal), blotch, blotch * 0.45, blotch * 0.4, 0.03)
	end
	smearIfSplashed(position, splashRadius)
end

local function reset()
	for index = #globs, 1, -1 do
		releaseGlob(index)
	end
	for index = #pools, 1, -1 do
		releasePool(index)
	end
	for index = #splats, 1, -1 do
		releaseSplat(index)
	end
	for index = #windups, 1, -1 do
		endWindup(index)
	end
end

-- Paused (PauseService holds the server's spits and puddles): hold everything on its clock.
local function hold(dt: number)
	for _, glob in globs do
		glob.launchedAt += dt
	end
	for _, pool in pools do
		pool.bornAt += dt
	end
	for _, splat in splats do
		splat.bornAt += dt
	end
	for _, windup in windups do
		windup.startedAt += dt
	end
	smearStartedAt += dt
end

local function step(dt: number)
	if workspace:GetAttribute(Attributes.GamePaused) == true then
		hold(dt)
		return
	end
	local now = os.clock()
	dropAllowance = math.min(dropAllowance + dt * CFG.Drops.MaxPerSecond, DROP_BURST)
	stepWindups(now)
	stepGlobs(now)
	stepSplats(now)
	stepPools(now)
	stepSmear(now)
end

function SpitFX.init()
	folder = Instance.new("Folder")
	folder.Name = "SpitFX"
	folder.Parent = workspace
	buildHosts()
	buildSmear()
	local kinds = Messages.EnemySpit
	Remotes.get("EnemySpit").OnClientEvent:Connect(function(kind: string, ...: any)
		if kind == kinds.Launch then
			launch(...)
		elseif kind == kinds.Impact then
			impact(...)
		elseif kind == kinds.Gone then
			releaseGlobById(...)
		elseif kind == kinds.Windup then
			-- nil: the body is not streamed in on this client.
			local model, seconds = ...
			if typeof(model) == "Instance" and model:IsA("Model") then
				startWindup(model, seconds)
			end
		elseif kind == kinds.Reset then
			reset()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return SpitFX
