--!strict
-- Concertina (wire call-in, CallInService): a strip of wire Config.CallIns.Concertina.Length
-- long and Width wide, laid across the throw and centred where it lands, stays for
-- Duration. Every TickInterval each Infected inside it (Rules/StrikePattern.inStrip) is
-- slowed to SlowFactor (EnemyService.slow, Pen Coil's old slow) and cut for
-- DamagePerSecond (DamageService.dealDamage, kind "fire": a damage-over-time tick). The
-- squad walks over it unharmed. The look is the prop_concertina mesh, stretched to Length.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local StrikePattern = require(ReplicatedStorage.Shared.Rules.StrikePattern)
local DamageService = require(script.Parent.DamageService)
local EnemyService = require(script.Parent.EnemyService)
local PauseService = require(script.Parent.PauseService)
local Lifecycle = require(script.Parent.Lifecycle)

local ENEMY_TAG = "Enemy"
local REACH_UP = 6 -- an Infected's root this far above or below the wire still counts

type Strip = {
	part: BasePart,
	owner: Player,
	center: Vector3,
	axis: Vector3, -- flat unit vector of the long side
	expiresAt: number,
	nextTickAt: number,
}

local ConcertinaService = {}

local folder: Folder
local strips: { Strip } = {}
local lastStep = 0

local function remove(index: number)
	strips[index].part:Destroy()
	table.remove(strips, index)
end

local function build(center: Vector3, axis: Vector3): BasePart
	local cfg = Config.CallIns.Concertina
	local wire: BasePart = MeshAssets.clone("prop_concertina") or Instance.new("Part")
	wire.Name = "Concertina"
	local height = 2.9
	if wire:IsA("Part") then
		-- Placeholder when the mesh template is missing.
		wire.Material = Enum.Material.DiamondPlate
		wire.Color = Color3.fromRGB(150, 156, 160)
		wire.Transparency = 0.3
	end
	-- The mesh's long side is X: stretch it to Length, Width deep.
	wire.Size = Vector3.new(cfg.Length, height, cfg.Width)
	wire.CFrame = CFrame.lookAt(center, center + axis) * CFrame.Angles(0, math.rad(90), 0)
		+ Vector3.new(0, height / 2, 0)
	wire.Anchored = true
	wire.CanCollide = false
	wire.CanQuery = false
	wire.CanTouch = false
	wire.Parent = folder
	return wire
end

-- CallInService: wire across `facing` (the throw direction), centred on `point`. Over
-- MaxPerPlayer the owner's oldest strip goes first.
function ConcertinaService.lay(owner: Player, point: Vector3, facing: Vector3): boolean
	local cfg = Config.CallIns.Concertina
	local flat = Vector3.new(facing.X, 0, facing.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local axis = flat:Cross(Vector3.yAxis).Unit
	local count = 0
	for _, strip in strips do
		if strip.owner == owner then
			count += 1
		end
	end
	while count >= cfg.MaxPerPlayer do
		for index, strip in strips do
			if strip.owner == owner then
				remove(index)
				break
			end
		end
		count -= 1
	end
	table.insert(strips, {
		part = build(point, axis),
		owner = owner,
		center = point,
		axis = axis,
		expiresAt = os.clock() + cfg.Duration,
		nextTickAt = os.clock(),
	})
	return true
end

local function tick(strip: Strip)
	local cfg = Config.CallIns.Concertina
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if not model:IsA("Model") then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or humanoid.Health <= 0 or not root then
			continue
		end
		local offset = root.Position - strip.center
		if math.abs(offset.Y) > REACH_UP then
			continue
		end
		if
			StrikePattern.inStrip(
				offset.X,
				offset.Z,
				strip.axis.X,
				strip.axis.Z,
				cfg.Length,
				cfg.Width
			)
		then
			EnemyService.slow(humanoid, cfg.SlowFactor, cfg.TickInterval + 0.2)
			DamageService.dealDamage(
				strip.owner,
				humanoid,
				cfg.DamagePerSecond * cfg.TickInterval,
				root.Position,
				"fire"
			)
		end
	end
end

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, strip in strips do
			strip.expiresAt += shift
			strip.nextTickAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	for index = #strips, 1, -1 do
		local strip = strips[index]
		if now >= strip.expiresAt or not strip.part.Parent then
			remove(index)
		elseif now >= strip.nextTickAt then
			strip.nextTickAt = now + Config.CallIns.Concertina.TickInterval
			tick(strip)
		end
	end
end

-- Wire strips down (dev tools).
function ConcertinaService.count(): number
	return #strips
end

function ConcertinaService.reset()
	table.clear(strips)
	if folder then
		folder:ClearAllChildren()
	end
end

function ConcertinaService.init()
	Lifecycle.register("ConcertinaService", {
		onRunStart = ConcertinaService.reset,
		onPlayerRemoving = function(player: Player)
			for index = #strips, 1, -1 do
				if strips[index].owner == player then
					remove(index)
				end
			end
		end,
	})
	folder = Instance.new("Folder")
	folder.Name = "Wire"
	folder.Parent = workspace
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)
end

return ConcertinaService
