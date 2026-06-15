--!strict
-- Combat drones from the Tactical Drone Beacon item: hover beside their
-- owner, pick the nearest Infected in range, and fire small projectiles
-- through ProjectileServer (so drone shots get damage numbers and proc the
-- owner's on-hit items). Server-simulated anchored parts, like projectiles.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemEffectService = require(script.Parent.ItemEffectService)
local PauseService = require(script.Parent.PauseService)
local ProjectileServer = require(script.Parent.ProjectileServer)

local ENEMY_TAG = "Enemy"
local RETARGET_INTERVAL = 0.25
local FOLLOW_LERP_RATE = 6

type Drone = {
	part: BasePart,
	owner: Player,
	angle: number, -- fixed offset angle so multiple drones spread out
	expiresAt: number,
	nextFireAt: number,
	nextRetargetAt: number,
	target: Humanoid?,
}

local DroneService = {}

local droneFolder: Folder
local drones: { Drone } = {}

local function countFor(player: Player): number
	local count = 0
	for _, drone in drones do
		if drone.owner == player then
			count += 1
		end
	end
	return count
end

local function nearestEnemy(position: Vector3): (Humanoid?, BasePart?)
	local bestHumanoid: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = Config.Items.Drone.TargetRange
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestHumanoid = humanoid
					bestRoot = root
				end
			end
		end
	end
	return bestHumanoid, bestRoot
end

function DroneService.deploy(owner: Player): boolean
	if countFor(owner) >= Config.Items.Drone.MaxActivePerPlayer then
		return false
	end
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	local part = Instance.new("Part")
	part.Name = "CombatDrone"
	part.Size = Vector3.new(1.1, 0.35, 1.1)
	part.CFrame = CFrame.new(root.Position + Vector3.new(0, Config.Items.Drone.FollowHeight, 0))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(63, 167, 214)
	part.Parent = droneFolder

	table.insert(drones, {
		part = part :: BasePart,
		owner = owner,
		angle = math.random() * math.pi * 2,
		expiresAt = os.clock() + Config.Items.Drone.Duration,
		nextFireAt = 0,
		nextRetargetAt = 0,
		target = nil,
	})
	return true
end

local function removeDrone(index: number)
	drones[index].part:Destroy()
	drones[index] = drones[#drones]
	drones[#drones] = nil
end

local function targetRootOf(drone: Drone): BasePart?
	local target = drone.target
	if not target or target.Health <= 0 or not target.Parent then
		drone.target = nil
		return nil
	end
	local model = target.Parent :: Model
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stepDrones(deltaTime: number)
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	for index = #drones, 1, -1 do
		local drone = drones[index]
		local character = drone.owner.Character
		local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if now >= drone.expiresAt or not ownerRoot or not drone.part.Parent then
			removeDrone(index)
			continue
		end

		-- Hover beside the owner with a gentle bob.
		local config = Config.Items.Drone
		local hoverTarget = ownerRoot.Position
			+ Vector3.new(
				math.cos(drone.angle) * config.FollowRadius,
				config.FollowHeight + math.sin(now * 2 + drone.angle) * 0.5,
				math.sin(drone.angle) * config.FollowRadius
			)
		local position =
			drone.part.Position:Lerp(hoverTarget, math.min(deltaTime * FOLLOW_LERP_RATE, 1))

		if now >= drone.nextRetargetAt then
			drone.nextRetargetAt = now + RETARGET_INTERVAL
			local humanoid = nearestEnemy(position)
			drone.target = humanoid
		end

		local targetRoot = targetRootOf(drone)
		if targetRoot then
			drone.part.CFrame = CFrame.lookAt(position, targetRoot.Position)
			if now >= drone.nextFireAt then
				drone.nextFireAt = now + config.FireInterval
				local direction = (targetRoot.Position - position).Unit
				local exclude: { Instance } = { droneFolder }
				if character then
					table.insert(exclude, character)
				end
				ProjectileServer.fire({
					owner = drone.owner,
					origin = position + direction * 1.2,
					direction = direction,
					damage = config.Damage,
					speed = config.ProjectileSpeed,
					size = Vector3.new(0.25, 0.25, 0.9),
					color = Color3.fromRGB(120, 205, 255),
					exclude = exclude,
				})
			end
		else
			drone.part.CFrame = CFrame.new(position)
		end
	end
end

function DroneService.reset()
	for _, drone in drones do
		drone.part:Destroy()
	end
	table.clear(drones)
	if droneFolder then
		droneFolder:ClearAllChildren()
	end
end

function DroneService.init()
	droneFolder = Instance.new("Folder")
	droneFolder.Name = "Drones"
	droneFolder.Parent = workspace

	ItemEffectService.setDroneDeployer(function(player: Player)
		DroneService.deploy(player)
	end)

	RunService.Heartbeat:Connect(stepDrones)

	Players.PlayerRemoving:Connect(function(player: Player)
		for index = #drones, 1, -1 do
			if drones[index].owner == player then
				removeDrone(index)
			end
		end
	end)
end

return DroneService
