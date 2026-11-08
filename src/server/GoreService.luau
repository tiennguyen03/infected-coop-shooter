--!strict
-- Dismemberment (owner 2026-11-08: "when you shoot the zombie, parts of them fall off...
-- similar to how Warden's armor plates fall off"; rules by the systems designer in
-- docs/PROGRESSION.md > Dismemberment, numbers in Config.Enemies.Dismember).
--
-- Every Infected limb is its own mesh part (MeshAssets.dressModel), so a limb comes off by
-- breaking its joint: the Motor6D above the struck part goes, the parts below it leave the
-- rig as one jointed group and are thrown along the round like a Warden plate, and a raw
-- stump (`inf_gore_stump`) is welded where they were. The joint above the part that was hit
-- keeps a running damage total; it breaks on the hit that takes it past MaxHealth x the
-- joint's Fraction. Rounds still do full body damage (time-to-kill is unchanged). An arm
-- lost weakens the melee (EnemyService.disarm), a leg lost makes the body crawl and stop
-- climbing (EnemyService.cripple); a killing headshot throws the head; a blast kill
-- (GoreService.blast: Anvil, Tripline) throws two more groups. The Index hosts never sever.
--
-- The flesh chunks at every body hit are client-side (GoreFX, from the templates this
-- service copies into ReplicatedStorage.GorePieces).

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DamageService = require(script.Parent.DamageService)
local EnemyService = require(script.Parent.EnemyService)
local Lifecycle = require(script.Parent.Lifecycle)

local GoreService = {}

local GROUP = "Gore"
local CHUNKS = { "inf_gore_chunk_a", "inf_gore_chunk_b", "inf_gore_chunk_c" }

type State = { totals: { [string]: number }, armsLost: number }
local states: { [Model]: State } = {}
local loose: { Model } = {} -- oldest first
local folder: Folder
local damageRemote: RemoteEvent

local function cfg()
	return Config.Enemies.Dismember
end

type JointSpec = { Counts: { string }, Falls: { string }, Fraction: number, Limb: string }
local function joints(): { [string]: JointSpec }
	return Config.Enemies.Dismember.Joints :: any
end

local function sideOf(partName: string): (string?, string?)
	if string.sub(partName, 1, 4) == "Left" then
		return "Left", string.sub(partName, 5)
	elseif string.sub(partName, 1, 5) == "Right" then
		return "Right", string.sub(partName, 6)
	end
	return nil, nil
end

-- The joint whose total a hit on `base` (a part name without its side) fills.
local function jointFor(base: string): string?
	for joint, spec in joints() do
		if table.find(spec.Counts, base) then
			return joint
		end
	end
	return nil
end

-- The joint that holds `part` to the rig, the part above it and the joint's world frame.
-- Rigs built by BuildRigFromAttachments use an AnimationConstraint (plus a
-- BallSocketConstraint) in the child part; older rigs a Motor6D.
local function jointInto(model: Model, part: BasePart): (Instance?, BasePart?, CFrame?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 == part then
			local parent = descendant.Part0
			return descendant, parent, if parent then parent.CFrame * descendant.C0 else nil
		elseif descendant:IsA("AnimationConstraint") then
			local a0, a1 = descendant.Attachment0, descendant.Attachment1
			if a1 and a1.Parent == part then
				local parent = if a0 then a0.Parent else nil
				return descendant,
					if parent and parent:IsA("BasePart") then parent else nil,
					if a0 then a0.WorldCFrame else nil
			end
		end
	end
	return nil, nil, nil
end

local function trimLoose()
	while #loose > cfg().MaxLoosePieces do
		local oldest = table.remove(loose, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local function weldStump(parent: BasePart, jointFrame: CFrame, scale: number)
	local stump = MeshAssets.clone("inf_gore_stump")
	if not stump then
		return
	end
	stump.Size *= scale
	-- The mesh's raw face is its +Y; the joint frame's -Y points down the lost limb.
	stump.CFrame = jointFrame * CFrame.Angles(math.pi, 0, 0)
	stump.Anchored = false
	stump.Massless = true
	stump.CanCollide = false
	stump.CanQuery = false
	stump.CanTouch = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = stump
	weld.Parent = stump
	stump.Parent = parent
end

-- Breaks the joint above `top` (a part in `model`) and throws `top` with every part in
-- `names` that is still on the rig. Returns false when the part is already gone.
local function detach(
	model: Model,
	top: BasePart,
	names: { string },
	push: Vector3,
	impulse: number
): boolean
	local joint, parent, frame = jointInto(model, top)
	if not joint then
		return false
	end
	local jointFrame = frame or top.CFrame
	joint:Destroy()
	for _, child in top:GetChildren() do -- the ball socket and no-collide pairs of that joint
		if child:IsA("BallSocketConstraint") then
			local a1 = child.Attachment1
			if a1 and a1.Parent == top then
				child:Destroy()
			end
		end
	end

	local piece = Instance.new("Model")
	piece.Name = "Severed"
	local parts: { BasePart } = {}
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	for _, part in parts do
		part.Parent = piece
		part.Anchored = false
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = false
		part.CollisionGroup = GROUP
	end
	piece.PrimaryPart = top
	piece.Parent = folder
	for _, part in parts do
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end
	local direction = if push.Magnitude > 0.01 then push.Unit else Vector3.yAxis
	top.AssemblyLinearVelocity = direction * impulse + Vector3.new(0, impulse * 0.5, 0)
	top.AssemblyAngularVelocity =
		Vector3.new(math.random() * 8 - 4, math.random() * 8 - 4, math.random() * 8 - 4)

	if parent and parent.Parent == model then
		weldStump(parent, jointFrame, model:GetScale())
	end
	damageRemote:FireAllClients(jointFrame.Position, 0, "break", nil)

	table.insert(loose, piece)
	trimLoose()
	local settings = cfg()
	task.delay(settings.SettleAnchor, function()
		if piece.Parent then
			for _, part in parts do
				part.Anchored = true
			end
		end
	end)
	Debris:AddItem(piece, settings.PieceLifetime)
	return true
end

local function formOf(model: Model): (string?, any)
	local typeName = model:GetAttribute(Attributes.EnemyType)
	if typeof(typeName) ~= "string" then
		return nil, nil
	end
	return typeName, cfg().Forms[typeName]
end

-- Breaks `joint` on `side` of `model` (no total needed) and applies what losing it does.
local function sever(
	model: Model,
	humanoid: Humanoid,
	side: string,
	joint: string,
	push: Vector3,
	impulse: number
)
	local settings = cfg()
	local spec = joints()[joint]
	local _, form = formOf(model)
	if not spec or not form then
		return
	end
	local names = {}
	for _, base in spec.Falls do
		table.insert(names, side .. base)
	end
	local top = model:FindFirstChild(names[1])
	if not top or not top:IsA("BasePart") then
		return
	end
	if not detach(model, top, names, push, impulse) then
		return
	end
	if humanoid.Health > 0 then
		if spec.Limb == "Arm" then
			EnemyService.disarm(model, settings.ArmLostDamage)
		else
			EnemyService.cripple(model, settings.CrawlSpeed)
		end
		EnemyService.stagger(humanoid, form.SeverStagger or settings.SeverStagger)
	end
end

local function canSever(form: any, limb: string): boolean
	return (limb == "Arm" and form.Arms == true) or (limb == "Leg" and form.Legs == true)
end

local function pushFrom(info: DamageService.HitInfo, model: Model): Vector3
	local attacker = info.attacker
	local character = attacker and attacker.Character
	local from = character and character:FindFirstChild("HumanoidRootPart")
	local at = info.position or model:GetPivot().Position
	if from and from:IsA("BasePart") then
		return at - from.Position
	end
	return at - model:GetPivot().Position
end

local function onHit(info: DamageService.HitInfo)
	local settings = cfg()
	local part = info.part
	if not settings.Enabled or not part or not part:IsA("BasePart") then
		return
	end
	local model = info.humanoid.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local typeName, form = formOf(model)
	if not typeName or not form then
		return
	end
	local push = pushFrom(info, model)
	if part.Name == "Head" then
		if info.killed and settings.HeadPopOnKill then
			local head = part :: BasePart
			detach(model, head, { "Head" }, push, settings.Impulse)
		end
		return
	end
	local side, base = sideOf(part.Name)
	if not side or not base then
		return
	end
	local joint = jointFor(base)
	local spec = joint and joints()[joint]
	if not joint or not spec or not canSever(form, spec.Limb) then
		return
	end
	local state = states[model]
	if not state then
		state = { totals = {}, armsLost = 0 }
		states[model] = state
		model.Destroying:Once(function()
			states[model] = nil
		end)
	end
	local key = side .. joint
	local total = (state.totals[key] or 0) + info.amount
	state.totals[key] = total
	local definition = EnemyDefinitions[typeName]
	local maxHealth = if definition then definition.MaxHealth else info.humanoid.MaxHealth
	if total >= maxHealth * spec.Fraction then
		state.totals[key] = -math.huge -- once
		sever(model, info.humanoid, side, joint, push, settings.Impulse)
	end
end

-- A blast kill (AirStrikeService, MineService): throws BlastKillSevers random limb groups
-- away from `center`.
function GoreService.blast(humanoid: Humanoid, center: Vector3)
	local settings = cfg()
	local model = humanoid.Parent
	if not settings.Enabled or not model or not model:IsA("Model") then
		return
	end
	local _, form = formOf(model)
	if not form then
		return
	end
	local options = {}
	for joint, spec in joints() do
		if canSever(form, spec.Limb) then
			for _, side in { "Left", "Right" } do
				table.insert(options, { joint = joint, side = side })
			end
		end
	end
	for _ = 1, settings.BlastKillSevers do
		if #options == 0 then
			break
		end
		local pick = table.remove(options, math.random(1, #options))
		if pick then
			sever(
				model,
				humanoid,
				pick.side,
				pick.joint,
				model:GetPivot().Position - center,
				settings.BlastImpulse
			)
		end
	end
end

local function clearLoose()
	for _, piece in loose do
		piece:Destroy()
	end
	table.clear(loose)
	table.clear(states)
end

function GoreService.init()
	damageRemote = Remotes.get("DamageDealt")
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, "Enemy", false)
	end)
	folder = Instance.new("Folder")
	folder.Name = "Gore"
	folder.Parent = workspace
	DamageService.addHitListener(onHit)
	Lifecycle.register("GoreService", { onRunStart = clearLoose })
	-- The chunk templates for the clients' GoreFX (MeshAssets templates are server-only).
	task.spawn(function()
		local pieces = Instance.new("Folder")
		pieces.Name = "GorePieces"
		for _, name in CHUNKS do
			local chunk = MeshAssets.waitFor(name, 30)
			if chunk then
				chunk.Anchored = false
				chunk.CanCollide = true
				chunk.CanQuery = false
				chunk.CanTouch = false
				chunk.CastShadow = false
				chunk.CollisionGroup = GROUP
				chunk.Parent = pieces
			end
		end
		pieces.Parent = ReplicatedStorage
	end)
end

return GoreService
