--!strict
-- Magpie (Drone Beacon call-in, CallInService): the thrown beacon lands and two of
-- Lantern's quadcopters lift off it, follow the thrower for Config.CallIns.Magpie.Duration
-- seconds, pick the nearest Infected in range and fire small projectiles through
-- ProjectileServer (damage numbers, kill credit). Last Flight (escort upgrade): the drones
-- stay with a downed owner and their clock pauses until they are back up; without it they
-- hold position over where the owner fell. Server-simulated anchored parts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local PauseService = require(script.Parent.PauseService)
local ProjectileServer = require(script.Parent.ProjectileServer)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ENEMY_TAG = "Enemy"
local RETARGET_INTERVAL = 0.25
local FOLLOW_LERP_RATE = 6
local BEACON_LIFETIME = 4 -- the beacon prop stays on the ground this long after the launch

type Drone = {
	part: BasePart,
	owner: Player,
	angle: number, -- fixed offset angle so multiple drones spread out
	escort: boolean,
	expiresAt: number,
	nextFireAt: number,
	nextRetargetAt: number,
	target: Humanoid?,
	holdAt: Vector3?, -- where a non-escort drone hovers while its owner is down
}

local DroneService = {}

local droneFolder: Folder
local drones: { Drone } = {}
local lastStep = 0

local function countFor(player: Player): number
	local count = 0
	for _, drone in drones do
		if drone.owner == player then
			count += 1
		end
	end
	return count
end

local function nearestEnemy(position: Vector3, range: number): Humanoid?
	local bestHumanoid: Humanoid? = nil
	local bestDistance = range
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestHumanoid = humanoid
				end
			end
		end
	end
	return bestHumanoid
end

local function removeDrone(index: number)
	drones[index].part:Destroy()
	drones[index] = drones[#drones]
	drones[#drones] = nil
end

local function placeBeacon(point: Vector3)
	local beacon: BasePart = MeshAssets.clone("prop_drone_beacon") or Instance.new("Part")
	beacon.Name = "DroneBeacon"
	if beacon:IsA("Part") then
		beacon.Size = Vector3.new(1.5, 3.2, 1.4)
		beacon.Material = Enum.Material.Metal
		beacon.Color = Color3.fromRGB(63, 167, 214)
	end
	beacon.CFrame = CFrame.new(point + Vector3.new(0, beacon.Size.Y / 2, 0))
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.Parent = droneFolder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 205, 255)
	light.Brightness = 2
	light.Range = 12
	light.Parent = beacon
	task.delay(BEACON_LIFETIME, function()
		beacon:Destroy()
	end)
end

local function spawnDrone(owner: Player, at: Vector3, escort: boolean)
	local cfg = Config.CallIns.Magpie
	local part: BasePart = MeshAssets.clone("prop_drone") or Instance.new("Part")
	part.Name = "CombatDrone"
	if part:IsA("Part") then
		-- Placeholder when the mesh template is missing.
		part.Size = Vector3.new(1.1, 0.35, 1.1)
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(63, 167, 214)
	end
	part.CFrame = CFrame.new(at)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = droneFolder
	WorldSounds.loopOn(part :: BasePart, "callins", "magpie_hover")
	table.insert(drones, {
		part = part :: BasePart,
		owner = owner,
		angle = math.random() * math.pi * 2,
		escort = escort,
		expiresAt = os.clock() + cfg.Duration,
		nextFireAt = os.clock() + 0.5,
		nextRetargetAt = 0,
		target = nil,
		holdAt = nil,
	})
end

-- CallInService: the beacon lands at `point`; Config.CallIns.Magpie.Drones lift off it and
-- follow `owner`. Over MaxDronesPerPlayer, the owner's oldest drones leave first.
function DroneService.deployBeacon(owner: Player, point: Vector3, escort: boolean): boolean
	local cfg = Config.CallIns.Magpie
	placeBeacon(point)
	for _ = 1, cfg.Drones do
		while countFor(owner) >= cfg.MaxDronesPerPlayer do
			for index, drone in drones do
				if drone.owner == owner then
					removeDrone(index)
					break
				end
			end
		end
		spawnDrone(owner, point + Vector3.new(0, cfg.FollowHeight, 0), escort)
	end
	return true
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
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, drone in drones do
			drone.expiresAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	local config = Config.CallIns.Magpie
	for index = #drones, 1, -1 do
		local drone = drones[index]
		local member = Squad.fromPlayer(drone.owner)
		local ownerRoot = member and member.root
		if now >= drone.expiresAt or not member or not ownerRoot or not drone.part.Parent then
			removeDrone(index)
			continue
		end
		if member.state == "Dead" then
			removeDrone(index)
			continue
		end

		-- A downed owner: Last Flight keeps the drones with them on a paused clock; otherwise
		-- they hold where the owner fell.
		local anchor = ownerRoot.Position
		if member.state == "Downed" then
			if drone.escort then
				drone.expiresAt += deltaTime
			else
				if not drone.holdAt then
					drone.holdAt = ownerRoot.Position
				end
				anchor = drone.holdAt :: Vector3
			end
		else
			drone.holdAt = nil
		end

		-- Hover beside the anchor with a gentle bob.
		local hoverTarget = anchor
			+ Vector3.new(
				math.cos(drone.angle) * config.FollowRadius,
				config.FollowHeight + math.sin(now * 2 + drone.angle) * 0.5,
				math.sin(drone.angle) * config.FollowRadius
			)
		local position =
			drone.part.Position:Lerp(hoverTarget, math.min(deltaTime * FOLLOW_LERP_RATE, 1))

		if now >= drone.nextRetargetAt then
			drone.nextRetargetAt = now + RETARGET_INTERVAL
			drone.target = nearestEnemy(position, config.TargetRange)
		end

		local targetRoot = targetRootOf(drone)
		if targetRoot then
			drone.part.CFrame = CFrame.lookAt(position, targetRoot.Position)
			if now >= drone.nextFireAt then
				drone.nextFireAt = now + config.FireInterval
				local direction = (targetRoot.Position - position).Unit
				local exclude: { Instance } = { droneFolder }
				local character = drone.owner.Character
				if character then
					table.insert(exclude, character)
				end
				local bots = workspace:FindFirstChild("SquadBots")
				if bots then
					table.insert(exclude, bots)
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

-- Drones in the air for `player` (dev tools).
function DroneService.count(player: Player?): number
	if not player then
		return #drones
	end
	return countFor(player)
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
	Lifecycle.register("DroneService", {
		onRunStart = DroneService.reset,
		onPlayerRemoving = function(player: Player)
			for index = #drones, 1, -1 do
				if drones[index].owner == player then
					removeDrone(index)
				end
			end
		end,
	})
	droneFolder = Instance.new("Folder")
	droneFolder.Name = "Drones"
	droneFolder.Parent = workspace
	lastStep = os.clock()
	RunService.Heartbeat:Connect(stepDrones)
end

return DroneService
