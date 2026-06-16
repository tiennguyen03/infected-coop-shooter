--!strict
-- Plague Rat Charm (Sprint 16): on a credited kill, ItemEffectService rolls a
-- chance and calls spawn() here. Rats are simple part-built models that crawl
-- to the nearest Infected, latch on, and deal damage over time through the
-- central dealDamage (so kill credit + Hunter's Mark apply). Same server-
-- simulated pattern as DroneService; rat damage uses kind "rat" so a rat kill
-- never spawns more rats (guarded in ItemEffectService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local ItemEffectService = require(script.Parent.ItemEffectService)
local PauseService = require(script.Parent.PauseService)

-- Body is 0.5 tall; this keeps it sitting just above the floor.
local GROUND_OFFSET = 0.4

local ENEMY_TAG = "Enemy"

type Rat = {
	model: Model,
	body: BasePart,
	owner: Player,
	target: Humanoid?,
	expiresAt: number,
	latchUntil: number, -- 0 when not latched
	retargets: number,
	nextTickAt: number,
}

local PlagueRatService = {}

local ratFolder: Folder
local rats: { Rat } = {}

local function buildRat(position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "PlagueRat"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.6, 0.5, 1.2)
	body.Position = position
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = Color3.fromRGB(46, 42, 40)
	body.Parent = model

	local function attach(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material: Enum.Material?
	): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = material or Enum.Material.SmoothPlastic
		part.Color = color
		part.CFrame = body.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	attach(
		"Head",
		Vector3.new(0.5, 0.4, 0.4),
		Vector3.new(0, 0.02, -0.8),
		Color3.fromRGB(40, 36, 34)
	)
	attach("Tail", Vector3.new(0.12, 0.12, 1), Vector3.new(0, 0, 1), Color3.fromRGB(70, 50, 50))
	attach(
		"EyeL",
		Vector3.new(0.12, 0.12, 0.12),
		Vector3.new(-0.14, 0.1, -0.98),
		Color3.fromRGB(255, 70, 70),
		Enum.Material.Neon
	)
	attach(
		"EyeR",
		Vector3.new(0.12, 0.12, 0.12),
		Vector3.new(0.14, 0.1, -0.98),
		Color3.fromRGB(255, 70, 70),
		Enum.Material.Neon
	)

	model.PrimaryPart = body
	model.Parent = ratFolder
	return model, body
end

local function countFor(owner: Player): number
	local count = 0
	for _, rat in rats do
		if rat.owner == owner then
			count += 1
		end
	end
	return count
end

local function nearestEnemy(position: Vector3, exclude: Humanoid?): Humanoid?
	local best: Humanoid? = nil
	local bestDistance = Config.Items.PlagueRat.TargetRange
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid ~= exclude and humanoid.Health > 0 and root then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = humanoid
				end
			end
		end
	end
	return best
end

function PlagueRatService.spawn(owner: Player, position: Vector3, stacks: number)
	local cfg = Config.Items.PlagueRat
	local count = cfg.RatsPerStack[math.min(stacks, #cfg.RatsPerStack)]

	for _ = 1, count do
		-- Remove this owner's oldest rat if at cap.
		if countFor(owner) >= cfg.MaxActivePerPlayer then
			for index, rat in rats do
				if rat.owner == owner then
					rat.model:Destroy()
					rats[index] = rats[#rats]
					rats[#rats] = nil
					break
				end
			end
		end

		-- Spawn on the floor near the kill (kill position is at torso height).
		local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
		local spawnPos = GroundUtil.GetGroundPosition(position + offset, GROUND_OFFSET)
		local model, body = buildRat(spawnPos)
		local now = os.clock()
		table.insert(rats, {
			model = model,
			body = body,
			owner = owner,
			target = nil,
			expiresAt = now + cfg.Lifetime,
			latchUntil = 0,
			retargets = 0,
			nextTickAt = now + 1,
		})
	end
end

local function removeRat(index: number)
	rats[index].model:Destroy()
	rats[index] = rats[#rats]
	rats[#rats] = nil
end

local function targetRoot(humanoid: Humanoid): BasePart?
	local model = humanoid.Parent :: Model?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stepRats(deltaTime: number)
	if PauseService.isPaused() then
		return
	end
	local cfg = Config.Items.PlagueRat
	local now = os.clock()

	for index = #rats, 1, -1 do
		local rat = rats[index]
		if now >= rat.expiresAt or not rat.body.Parent then
			removeRat(index)
			continue
		end

		-- Validate / acquire target.
		local target = rat.target
		if target and (target.Health <= 0 or not target.Parent) then
			rat.target = nil
			rat.latchUntil = 0
			target = nil
		end
		if not target and rat.retargets <= cfg.MaxRetargets then
			local found = nearestEnemy(rat.body.Position, nil)
			if found then
				if rat.target == nil and rat.retargets > 0 then
					rat.retargets += 1
				end
				rat.target = found
				target = found
			end
		end

		if not target then
			-- Idle bob in place, kept on the floor. Move the whole model (parts
			-- are welded to the body) so nothing is left behind.
			local idle = GroundUtil.GetGroundPosition(rat.body.Position, GROUND_OFFSET)
			local rot = rat.body.CFrame - rat.body.CFrame.Position
			rat.model:PivotTo(CFrame.new(idle + Vector3.new(0, math.sin(now * 6) * 0.05, 0)) * rot)
			continue
		end

		local tRoot = targetRoot(target)
		if not tRoot then
			rat.target = nil
			continue
		end

		-- Work in the horizontal plane so rats crawl along the floor instead of
		-- climbing to the target's torso height.
		local toTarget = tRoot.Position - rat.body.Position
		local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
		local distance = flat.Magnitude

		if rat.latchUntil > now and distance <= cfg.ContactRange + 1.5 then
			-- Latched: sit at the target's feet with a bite bob, tick damage.
			local bite = math.sin(now * 18) * 0.12
			local groundPos = GroundUtil.GetGroundPosition(tRoot.Position, GROUND_OFFSET)
			local base = groundPos + Vector3.new(0, bite, 0)
			local face = if distance > 0.05
				then base + flat.Unit
				else base + rat.body.CFrame.LookVector
			rat.model:PivotTo(CFrame.lookAt(base, face))
			if now >= rat.nextTickAt then
				rat.nextTickAt += 1
				ItemEffectService.dealDamage(
					rat.owner,
					target,
					cfg.DamagePerSecond,
					tRoot.Position,
					"rat"
				)
			end
		elseif distance <= cfg.ContactRange then
			-- Reached the target: latch on.
			rat.latchUntil = now + cfg.LatchDuration
			rat.nextTickAt = now + 1
		else
			-- Crawl toward the target along the floor with a low bob.
			local dir = flat.Unit
			local step = dir * math.min(cfg.CrawlSpeed * deltaTime, distance)
			local newPos = GroundUtil.GetGroundPosition(rat.body.Position + step, GROUND_OFFSET)
			newPos += Vector3.new(0, math.sin(now * 10) * 0.04, 0)
			rat.model:PivotTo(CFrame.lookAt(newPos, newPos + dir))
		end
	end
end

function PlagueRatService.reset()
	for _, rat in rats do
		rat.model:Destroy()
	end
	table.clear(rats)
	if ratFolder then
		ratFolder:ClearAllChildren()
	end
end

function PlagueRatService.init()
	ratFolder = Instance.new("Folder")
	ratFolder.Name = "PlagueRats"
	ratFolder.Parent = workspace

	ItemEffectService.setRatSpawner(function(owner: Player, position: Vector3, stacks: number)
		PlagueRatService.spawn(owner, position, stacks)
	end)
	RunService.Heartbeat:Connect(stepRats)

	Players.PlayerRemoving:Connect(function(player: Player)
		for index = #rats, 1, -1 do
			if rats[index].owner == player then
				removeRat(index)
			end
		end
	end)
end

return PlagueRatService
