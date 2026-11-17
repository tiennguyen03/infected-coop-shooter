--!strict
-- Vehicles (docs/PROGRESSION.md > The ATV; Nova and Tien 2026-11-17). A call-in row with a
-- `Vehicle` block (Config.CallIns.ATV) is a vehicle: CallInService asks `check` before it
-- spends the charge and `deliver` when the helo's sling sets it down (CallInArrivalFX
-- "sling" draws the flight). Nothing here names a vehicle; the row and VehicleBody do.
--
-- Seats: E (Config.Keys.Interact) on the prompt gets on, driver first, then the back seat
-- (Rules/Vehicle.seatFor); E again gets off (client VehicleController sends "exit"). The
-- character carries Riding ("driver" | "gunner") while seated: the client controllers stand
-- still, and the server refuses the driver's shots, everyone's grenades, call-ins, shove and
-- flare (the gunner fires their primary; stims are allowed). Downed, knocked down or dead
-- falls off. In solo the nearest free bot takes the back seat when a player drives.
--
-- Physics: the driver's client simulates the chassis (network owner, VehiclePhysics); the
-- server does while nobody drives, and takes it back for a moment if it goes faster than an
-- honest drive (Vehicle.overSpeed). Rams, health, the wreck and the seats are the server's.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Vehicle = require(ReplicatedStorage.Shared.Rules.Vehicle)
local VehicleBody = require(ReplicatedStorage.Shared.VehicleBody)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)

local DamageService = require(script.Parent.DamageService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local EnemyService = require(script.Parent.EnemyService)
local Lifecycle = require(script.Parent.Lifecycle)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local WorldSounds = require(script.Parent.WorldSounds)

local VehicleService = {}

local ENEMY_TAG = "Enemy"
local RAM_REPEAT = 0.6 -- seconds before the same vehicle can ram the same body again
local CHECK_INTERVAL = 0.25 -- seconds between the slow checks (righting prompt, riders)
local TAKE_BACK = 1 -- seconds the server holds a chassis that went too fast
local WRECK_LINGER = 8 -- seconds the burnt-out wreck stays
local EXIT_SIDE = 3.4 -- studs out from the centre a rider steps off
local BOARD_REACH = 6 -- studs from the ATV a bot gets on from
local BOARD_SPEED = 4 -- studs/s: the ATV must be about this slow for a bot to get on
local PARK_SPEED = 0.5 -- studs/s: slower than this, empty and grounded, it settles
local PARK_AFTER = 1 -- seconds settled before it is parked (anchored)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

export type SeatName = Vehicle.Seat

type Ride = {
	model: Model,
	root: BasePart,
	id: string, -- the call-in id
	bodyId: string,
	cfg: any, -- the row's Vehicle block
	owner: Player?,
	health: number,
	stage: Vehicle.Stage,
	seats: { driver: Seat | VehicleSeat, gunner: Seat | VehicleSeat },
	riders: { [string]: Squad.Member }, -- by SeatName
	prompts: { [string]: ProximityPrompt }, -- by SeatName: get on that seat
	right: ProximityPrompt,
	boarding: Squad.Member?, -- the bot walking over to take the back seat
	rammed: { [Model]: number },
	heldUntil: number, -- the server holds the chassis until (over-speed)
	wreckAt: number?, -- burning: blows at this os.clock
	stillSince: number?, -- empty and settling since (os.clock); parked after PARK_AFTER
	effects: { Instance },
}

local rides: { Ride } = {}
local pending: { [Player]: number } = {} -- called in, not yet set down
local folder: Folder
local effects: Folder
local vehicleRemote: RemoteEvent
local noticeRemote: RemoteEvent
local nextCheck = 0
local serverParams: RaycastParams? = nil -- the wheel rays' filter, rebuilt each second
local paramsAt = 0

-- A parked (anchored) chassis wakes up to be ridden, flipped or knocked about.
local function unpark(ride: Ride)
	ride.stillSince = nil
	if ride.root.Anchored and not ride.wreckAt then
		ride.root.Anchored = false
	end
end

-- ------------------------------------------------------------------ lookups

local function vehicleCfg(callInId: string): any
	local definition = CallInDefinitions.get(callInId)
	local row = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	return row and row.Vehicle
end

-- Whether call-in `callInId` is a vehicle (its row has a Vehicle block).
function VehicleService.isVehicle(callInId: string): boolean
	return vehicleCfg(callInId) ~= nil
end

local function rideOf(character: Model?): (Ride?, SeatName?)
	if not character then
		return nil, nil
	end
	for _, ride in rides do
		for seatName, member in ride.riders do
			if member.character == character then
				return ride, seatName :: SeatName
			end
		end
	end
	return nil, nil
end

-- The seat `character` rides in ("driver" | "gunner"), or nil on foot.
function VehicleService.seatOf(character: Model?): SeatName?
	local _, seatName = rideOf(character)
	return seatName :: any
end

-- Whether the back-seat gunner on `character` may fire along `direction` (not through the
-- driver). True for anyone not in a back seat.
function VehicleService.gunnerMayFire(character: Model?, direction: Vector3): boolean
	local ride, seatName = rideOf(character)
	if not ride or seatName ~= "gunner" then
		return true
	end
	local look = ride.root.CFrame.LookVector
	return Vehicle.gunnerCanFire(
		look.X,
		look.Z,
		direction.X,
		direction.Z,
		ride.cfg.Gunner.BlockedArc
	)
end

-- The hip-spread factor for the back seat on `character` (1 when not moving fast, or not
-- in a back seat).
function VehicleService.gunnerBloom(character: Model?): number
	local ride, seatName = rideOf(character)
	if not ride or seatName ~= "gunner" then
		return 1
	end
	local gunner = ride.cfg.Gunner
	local velocity = ride.root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return if flat > gunner.MovingSpeed then gunner.MovingBloom else 1
end

local function flatSpeed(ride: Ride): number
	local velocity = ride.root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function notice(player: Player?, text: string)
	if player and player.Parent then
		noticeRemote:FireClient(player, text, Messages.Notice.Radio)
	end
end

-- The camera shake every client nearby feels (CameraController watches the BlastTag).
local function shake(position: Vector3, power: number)
	local marker = Instance.new("Part")
	marker.Size = Vector3.one
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Position = position
	marker:SetAttribute(Attributes.BlastPower, power)
	CollectionService:AddTag(marker, Attributes.BlastTag)
	marker.Parent = effects
	Debris:AddItem(marker, 0.5)
end

-- ------------------------------------------------------------------ seats

-- Each seat has its own prompt at its own place (the driver's at the tank, the back seat's
-- at the rack), shown while that seat is free: a soldier picks a seat by where they stand
-- (one prompt per key shows at a time, the nearer).
local function refreshPrompt(ride: Ride)
	for seatName, prompt in ride.prompts do
		prompt.Enabled = ride.riders[seatName] == nil and ride.wreckAt == nil
	end
end

local function setOwner(ride: Ride)
	if not ride.root:IsDescendantOf(Workspace) or ride.root.Anchored then
		return
	end
	local driver = ride.riders.driver
	local owner = if driver and os.clock() >= ride.heldUntil then driver.owner else nil
	if ride.root:GetNetworkOwner() ~= owner then
		ride.root:SetNetworkOwner(owner)
	end
end

local function getOff(ride: Ride, seatName: SeatName)
	local member = ride.riders[seatName]
	if not member then
		return
	end
	ride.riders[seatName] = nil
	local seatPart = ride.seats[seatName]
	local weld = seatPart:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local character, humanoid, root = member.character, member.humanoid, member.root
	if character then
		character:SetAttribute(Attributes.Riding, nil)
	end
	if humanoid then
		humanoid.Sit = false
	end
	if root and root.Parent and humanoid and humanoid.Health > 0 then
		-- Step off on the side away from anything in the way (left first).
		local frame = ride.root.CFrame
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder, character :: Model }
		local spot = frame * CFrame.new(-EXIT_SIDE, 0, 0)
		for _, side in { -1, 1 } do
			local out = frame.RightVector * side * EXIT_SIDE
			if not Workspace:Raycast(frame.Position, out, params) then
				spot = frame * CFrame.new(side * EXIT_SIDE, 0, 0)
				break
			end
		end
		root.CFrame = CFrame.lookAlong(spot.Position + Vector3.new(0, 1, 0), frame.LookVector)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if seatName == "driver" then
		-- The bot in the back gets off with its driver (bots never drive).
		local gunner = ride.riders.gunner
		if gunner and gunner.kind == "bot" then
			getOff(ride, "gunner")
		end
	end
	setOwner(ride)
	refreshPrompt(ride)
end

local function seatMember(ride: Ride, seatName: SeatName, member: Squad.Member): boolean
	local humanoid, character = member.humanoid, member.character
	if not humanoid or not character or ride.riders[seatName] or ride.wreckAt then
		return false
	end
	unpark(ride)
	ride.riders[seatName] = member
	character:SetAttribute(Attributes.Riding, seatName)
	ride.seats[seatName]:Sit(humanoid)
	if seatName == "gunner" and member.owner then
		LoadoutService.usePrimary(member.owner)
	end
	setOwner(ride)
	refreshPrompt(ride)
	return true
end

local function stopBoarding(ride: Ride)
	local bot = ride.boarding
	ride.boarding = nil
	if bot and bot.character then
		bot.character:SetAttribute(Attributes.BoardAt, nil)
	end
end

-- Solo: while a player drives with the back seat free, the nearest free bot within
-- BotRideRange walks to the ATV (BotService reads BoardAt as where to stand) and gets on
-- once it is within BOARD_REACH and the ATV is nearly stopped. Checked every CHECK_INTERVAL.
local function boardBot(ride: Ride)
	local driver = ride.riders.driver
	if ride.riders.gunner or not driver or driver.kind ~= "player" or ride.wreckAt then
		stopBoarding(ride)
		return
	end
	local best: Squad.Member? = nil
	local bestDistance = ride.cfg.BotRideRange
	for _, member in Squad.members() do
		local root = member.root
		if
			member.kind == "bot"
			and root
			and Squad.canAct(member)
			and not VehicleService.seatOf(member.character)
		then
			local distance = (root.Position - ride.root.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = member, distance
			end
		end
	end
	if best ~= ride.boarding then
		stopBoarding(ride)
	end
	if not best then
		return
	end
	if bestDistance <= BOARD_REACH and flatSpeed(ride) <= BOARD_SPEED then
		stopBoarding(ride)
		seatMember(ride, "gunner", best)
		return
	end
	ride.boarding = best
	local character = best.character
	if character then
		-- Beside the back seat, on the ground.
		local beside = ride.root.CFrame * CFrame.new(-EXIT_SIDE, 0, 2)
		character:SetAttribute(Attributes.BoardAt, beside.Position)
	end
end

local function onGetOn(ride: Ride, player: Player, seatName: SeatName)
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) or VehicleService.seatOf(member.character) then
		return
	end
	if ride.boarding == member then
		stopBoarding(ride)
	end
	if seatMember(ride, seatName, member) and seatName == "driver" then
		boardBot(ride)
	end
end

local function onRight(ride: Ride, player: Player)
	local member = Squad.fromPlayer(player)
	local frame = ride.root.CFrame
	if
		not member
		or not Squad.canAct(member)
		or ride.wreckAt
		or not Vehicle.needsRighting(
			frame.UpVector.Y,
			flatSpeed(ride),
			ride.cfg.Right.Tilt,
			ride.cfg.Right.Slow
		)
	then
		return
	end
	local look = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	if look.Magnitude < 0.1 then
		look = Vector3.new(frame.UpVector.X, 0, frame.UpVector.Z)
	end
	if look.Magnitude < 0.1 then
		look = Vector3.zAxis
	end
	unpark(ride)
	ride.root:SetNetworkOwner(nil)
	ride.root.CFrame = CFrame.lookAlong(frame.Position + Vector3.new(0, 2.5, 0), look.Unit)
	ride.root.AssemblyLinearVelocity = Vector3.zero
	ride.root.AssemblyAngularVelocity = Vector3.zero
	WorldSounds.at(frame.Position, "callins", "pallet_land", 0.6, 0.8)
	setOwner(ride)
end

-- ------------------------------------------------------------------ health

-- One emitter of the built-in smoke sprite under the tank, made once and retuned per
-- stage (docs/STYLES.md section 8: palette-tinted sprites, no stock fire textures).
local function emitter(ride: Ride, name: string): ParticleEmitter
	local attachment = ride.root:FindFirstChild("Engine") :: Attachment?
	if not attachment then
		local made = Instance.new("Attachment")
		made.Name = "Engine"
		made.Position = Vector3.new(0, 0.9, 0) -- under the tank
		made.Parent = ride.root
		attachment = made
	end
	local existing = (attachment :: Attachment):FindFirstChild(name)
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Texture = SMOKE_TEXTURE
	made.SpreadAngle = Vector2.new(15, 15)
	made.Rotation = NumberRange.new(0, 360)
	made.RotSpeed = NumberRange.new(-40, 40)
	made.Parent = attachment
	table.insert(ride.effects, made)
	return made
end

local function showStage(ride: Ride)
	if ride.stage == "smoke" or ride.stage == "fire" then
		local burning = ride.stage == "fire"
		local smoke = emitter(ride, "Smoke")
		smoke.Color = ColorSequence.new(Color3.fromRGB(70, 70, 68), Color3.fromRGB(40, 40, 40))
		smoke.Size = NumberSequence.new(if burning then 1.5 else 0.8, if burning then 4 else 2.5)
		smoke.Transparency = NumberSequence.new(0.35, 1)
		smoke.Lifetime = NumberRange.new(1.8, 2.6)
		smoke.Speed = NumberRange.new(3, 5)
		smoke.Rate = if burning then 9 else 4
	end
	if ride.stage == "fire" then
		local fire = emitter(ride, "Fire")
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 60, 30))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new(1.6, 0)
		fire.Transparency = NumberSequence.new(0.1, 1)
		fire.Lifetime = NumberRange.new(0.4, 0.7)
		fire.Speed = NumberRange.new(3, 5)
		fire.Rate = 14
	end
end

-- The blast: an expanding ball in the call-ins' flash colour, tagged for the camera shake
-- (CameraController), as AirStrikeService draws its blasts.
local function flash(position: Vector3, radius: number)
	local defaults = Config.CallIns.Arrivals.Defaults
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 2
	ball.Position = position
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = defaults.Flash
	ball:SetAttribute(Attributes.BlastPower, 3)
	CollectionService:AddTag(ball, Attributes.BlastTag)
	ball.Parent = effects
	TweenService:Create(
		ball,
		TweenInfo.new(defaults.FlashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * radius * 2, Transparency = 1 }
	):Play()
	Debris:AddItem(ball, defaults.FlashTime + 0.05)
end

local function destroyRide(ride: Ride)
	stopBoarding(ride)
	for seatName in ride.riders do
		getOff(ride, seatName :: SeatName)
	end
	local index = table.find(rides, ride)
	if index then
		table.remove(rides, index)
	end
	ride.model:Destroy()
end

local function blowUp(ride: Ride)
	local wreck = ride.cfg.Wreck
	local position = ride.root.Position
	-- Riders still aboard are thrown off, hurt and knocked down.
	for seatName, member in table.clone(ride.riders) do
		getOff(ride, seatName :: SeatName)
		local humanoid = member.humanoid
		if humanoid then
			EnemyProjectileService.damagePlayer(humanoid, wreck.RiderDamage)
			if member.state == "Alive" then
				Squad.knock(member, wreck.Knock)
			end
		end
	end
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = (model :: Model).PrimaryPart
		if
			humanoid
			and root
			and humanoid.Health > 0
			and (root.Position - position).Magnitude <= wreck.Radius
		then
			EnemyService.noteBlast(humanoid, position)
			DamageService.dealDamage(ride.owner, humanoid, wreck.Damage, root.Position, "blast")
		end
	end
	flash(position, wreck.Radius)
	WorldSounds.at(position, "callins", "anvil_blast", 0.8, 1.1)
	-- The burnt-out wreck stays a while, then goes; it no longer counts as a vehicle. It is
	-- anchored where it stands (no suspension runs on it now), smoking, the fire out.
	local index = table.find(rides, ride)
	if index then
		table.remove(rides, index)
	end
	ride.root.Anchored = true
	stopBoarding(ride)
	for _, prompt in ride.prompts do
		prompt:Destroy()
	end
	ride.right:Destroy()
	local fire = ride.root:FindFirstChild("Engine")
		and (ride.root:FindFirstChild("Engine") :: Instance):FindFirstChild("Fire")
	if fire and fire:IsA("ParticleEmitter") then
		fire.Enabled = false
	end
	for _, part in ride.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = part.Color:Lerp(Color3.fromRGB(24, 24, 22), 0.85)
		elseif part:IsA("SurfaceGui") then
			part:Destroy()
		end
	end
	Debris:AddItem(ride.model, WRECK_LINGER)
end

local function hurt(ride: Ride, amount: number)
	if amount <= 0 or ride.wreckAt then
		return
	end
	unpark(ride)
	ride.health = math.max(ride.health - amount, 0)
	ride.model:SetAttribute(Attributes.VehicleHealth, ride.health)
	local stage = Vehicle.stage(ride.health, ride.cfg.Health, ride.cfg.SmokeAt, ride.cfg.FireAt)
	if stage ~= ride.stage then
		ride.stage = stage :: any
		if stage == "wreck" then
			ride.wreckAt = os.clock() + ride.cfg.Wreck.Burn
			ride.stage = "fire"
			showStage(ride)
			refreshPrompt(ride)
			for _, member in ride.riders do
				notice(member.owner, "It's going up! Get off!")
			end
		else
			showStage(ride)
		end
	end
end

-- The Infected's hit on a rider (EnemyProjectileService.damagePlayer): the vehicle under
-- them takes `amount` (the attacker's VehicleDamage) too.
local function onRiderHit(humanoid: Humanoid, amount: number)
	local ride = rideOf(humanoid.Parent :: Model?)
	if ride then
		hurt(ride, amount)
	end
end

-- ------------------------------------------------------------------ rams

local function ram(ride: Ride, now: number)
	local cfg = ride.cfg.Ram
	local frame = ride.root.CFrame
	local forwardSpeed = ride.root.AssemblyLinearVelocity:Dot(frame.LookVector)
	if math.abs(forwardSpeed) < cfg.MinSpeed then
		return
	end
	local body = VehicleBody.get(ride.bodyId)
	if not body then
		return
	end
	-- The box in front of the bumper (behind it when reversing), in the chassis' frame.
	local ahead = if forwardSpeed > 0 then -1 else 1 -- forward is -Z
	local halfWidth = body.size.X / 2 + 1
	local near, far = body.bumper, body.bumper + cfg.Reach
	local driver = ride.riders.driver
	local credit = driver and driver.owner or ride.owner
	local keep = 1
	local hitAt: Vector3? = nil
	for _, tagged in CollectionService:GetTagged(ENEMY_TAG) do
		local model = tagged :: Model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model.PrimaryPart
		if humanoid and root and humanoid.Health > 0 and now >= (ride.rammed[model] or 0) then
			local local_ = frame:PointToObjectSpace(root.Position)
			local along = local_.Z * ahead
			if
				math.abs(local_.X) <= halfWidth
				and along >= near
				and along <= far
				and math.abs(local_.Y) <= 4
			then
				ride.rammed[model] = now + RAM_REPEAT
				local damage = Vehicle.ramDamage(forwardSpeed, cfg.MinSpeed, cfg.PerSpeed)
				local name = model:GetAttribute(Attributes.EnemyType)
				local definition = if typeof(name) == "string" then EnemyDefinitions[name] else nil
				if definition and definition.RamStop then
					DamageService.dealDamage(credit, humanoid, damage, root.Position, "ram")
					EnemyService.stagger(humanoid, cfg.Stagger)
					hurt(ride, cfg.StopDamage)
					keep = 0
				else
					EnemyService.noteBlast(humanoid, ride.root.Position)
					DamageService.dealDamage(credit, humanoid, damage, root.Position, "ram")
					hurt(ride, cfg.SelfDamage)
					keep *= 1 - cfg.Slow
				end
				hitAt = root.Position
			end
		end
	end
	if hitAt then
		-- One thud and one shake for the frame, however many it went through.
		WorldSounds.at(hitAt, "callins", "pallet_land", 0.9, 0.7)
		shake(ride.root.Position, cfg.ShakePower)
	end
	if keep < 1 then
		if
			driver
			and driver.owner
			and not ride.root.Anchored
			and ride.root:GetNetworkOwner() == driver.owner
		then
			vehicleRemote:FireClient(driver.owner, Messages.Vehicle.Ram, keep)
		else
			ride.root.AssemblyLinearVelocity *= keep
		end
	end
	for model, untilTime in ride.rammed do
		if now >= untilTime then
			ride.rammed[model] = nil
		end
	end
end

-- ------------------------------------------------------------------ the call

local function counts(player: Player): (number, number, Ride?)
	local mine, squad = pending[player] or 0, 0
	local own: Ride? = nil
	for _, other in pending do
		squad += other
	end
	for _, ride in rides do
		if not ride.wreckAt then
			squad += 1
			if ride.owner == player then
				mine += 1
				own = ride
			end
		end
	end
	return mine, squad, own
end

-- Whether `player` may call vehicle `callInId` down at `landing`. False and why when the
-- squad has its share out, theirs is occupied, or the ground is not clear (no charge is
-- spent: CallInService asks first). A new one replaces their own empty one here.
function VehicleService.check(
	player: Player,
	callInId: string,
	landing: Vector3
): (boolean, string?)
	local cfg = vehicleCfg(callInId)
	if not cfg then
		return false, "not a vehicle"
	end
	local mine, squad, own = counts(player)
	local verdict = Vehicle.callCheck(
		mine,
		squad,
		cfg.PerPlayer,
		cfg.PerSquad,
		own ~= nil and next(own.riders) ~= nil
	)
	if verdict == "refuse" then
		local why = if own and next(own.riders)
			then "Your ATV's still got people on it."
			else "Squad's got all the ATVs it can have."
		notice(player, why)
		return false, why
	end
	-- Room on the ground: nothing solid in the box it will stand in.
	local clear = cfg.Clear :: Vector3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	for _, member in Squad.members() do
		if member.character then
			table.insert(exclude, member.character)
		end
	end
	overlap.FilterDescendantsInstances = exclude
	overlap.CollisionGroup = VehiclePhysics.RayGroup
	local box = CFrame.new(landing + Vector3.new(0, clear.Y / 2 + 0.4, 0))
	for _, part in Workspace:GetPartBoundsInBox(box, clear, overlap) do
		if part.CanCollide and part.Transparency < 1 then
			notice(player, "No room to set it down there.")
			return false, "blocked"
		end
	end
	if verdict == "replace" and own then
		destroyRide(own)
	end
	pending[player] = (pending[player] or 0) + 1
	return true, nil
end

-- The sling sets vehicle `callInId` down at `landing` facing `direction` for `player`.
function VehicleService.deliver(
	player: Player,
	callInId: string,
	landing: Vector3,
	direction: Vector3
)
	pending[player] = math.max((pending[player] or 1) - 1, 0)
	local cfg = vehicleCfg(callInId)
	local body = cfg and VehicleBody.get(cfg.Body)
	if not cfg or not body or not player.Parent then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local look = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local frame = CFrame.lookAlong(landing + Vector3.new(0, body.rest + 0.15, 0), look)
	local model = VehicleBody.build(cfg.Body, frame, false)
	if not model then
		return
	end
	local root = model.PrimaryPart :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = VehiclePhysics.Group
		end
	end
	model:SetAttribute(Attributes.VehicleId, callInId)
	model:SetAttribute(Attributes.VehicleOwner, player.UserId)
	model:SetAttribute(Attributes.VehicleHealth, cfg.Health)
	model:SetAttribute(Attributes.VehicleMaxHealth, cfg.Health)

	local name = (CallInDefinitions.get(callInId) :: any).Name
	-- One prompt per seat, at that seat (Nova 2026-11-17: pick the back seat yourself).
	local prompts: { [string]: ProximityPrompt } = {}
	local spots: { [string]: Vector3 } =
		{ driver = body.driver, gunner = body.gunner + Vector3.new(0, 0, 0.8) }
	for seatName, spot in spots do
		local anchor = Instance.new("Attachment")
		anchor.Name = "GetOn_" .. seatName
		anchor.Position = spot
		anchor.Parent = root
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GetOn"
		prompt.ObjectText = name
		prompt.ActionText = if seatName == "driver" then "Drive" else "Ride in back"
		prompt.KeyboardKeyCode = Config.Keys.Interact
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = cfg.PromptReach
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompts[seatName] = prompt
	end
	local right = Instance.new("ProximityPrompt")
	right.Name = "Right"
	right.ObjectText = name
	right.ActionText = "Flip it over"
	right.KeyboardKeyCode = Config.Keys.Interact
	right.HoldDuration = cfg.Right.Hold
	right.MaxActivationDistance = cfg.PromptReach
	right.RequiresLineOfSight = false
	right.Enabled = false
	right.Parent = root

	local ride: Ride = {
		model = model,
		root = root,
		id = callInId,
		bodyId = cfg.Body,
		cfg = cfg,
		owner = player,
		health = cfg.Health,
		stage = "ok",
		seats = {
			-- By class, never by name: a body piece can share a seat's name.
			driver = model:FindFirstChildOfClass("VehicleSeat") :: VehicleSeat,
			gunner = model:FindFirstChildOfClass("Seat") :: Seat,
		},
		riders = {},
		prompts = prompts,
		right = right,
		boarding = nil,
		rammed = {},
		heldUntil = 0,
		wreckAt = nil,
		effects = {},
	}
	for seatName, prompt in prompts do
		prompt.Triggered:Connect(function(who)
			onGetOn(ride, who, seatName :: SeatName)
		end)
	end
	right.Triggered:Connect(function(who)
		onRight(ride, who)
	end)
	model.Parent = folder
	root:SetNetworkOwner(nil)
	table.insert(rides, ride)
	WorldSounds.at(landing, "callins", "pallet_land", 1, 0.6)
	print(`[Vehicle] {player.Name}'s {callInId} set down`)
end

-- ------------------------------------------------------------------ the loop

-- Seats still held by who should hold them: dead, downed, knocked down or gone falls off;
-- a seat whose weld broke frees up.
local function checkRiders(ride: Ride)
	for seatName, member in ride.riders do
		local humanoid = member.humanoid
		local character = member.character
		local seated = humanoid and humanoid.SeatPart == ride.seats[seatName :: SeatName]
		if
			not humanoid
			or humanoid.Health <= 0
			or member.state ~= "Alive"
			or not character
			or not character.Parent
			or character:GetAttribute(Attributes.KnockedUntil) ~= nil
			or not seated
		then
			getOff(ride, seatName :: SeatName)
		end
	end
end

local function physicsStep(dt: number)
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	for _, ride in rides do
		local root = ride.root
		-- Anchored (parked) first: asking an anchored part for its owner is an error.
		if not root.Anchored and root:GetNetworkOwner() == nil then
			if not serverParams or now - paramsAt > 1 then
				local list: { Instance } = { folder }
				for _, member in Squad.members() do
					if member.character then
						table.insert(list, member.character)
					end
				end
				serverParams = VehiclePhysics.params(list)
				paramsAt = now
			end
			local grounded = VehiclePhysics.step(
				ride.model,
				ride.bodyId,
				ride.cfg,
				{ throttle = 0, steer = 0 },
				dt,
				serverParams :: RaycastParams
			)
			-- Empty, on all its wheels and still for a moment: park it (anchored, nothing to
			-- simulate or send) until someone gets on, flips it or it is hit.
			local still = root.AssemblyLinearVelocity.Magnitude < PARK_SPEED
				and root.AssemblyAngularVelocity.Magnitude < 0.2
			if still and grounded == 4 and next(ride.riders) == nil and not ride.wreckAt then
				ride.stillSince = ride.stillSince or now
				if now - (ride.stillSince :: number) >= PARK_AFTER then
					root.Anchored = true
				end
			else
				ride.stillSince = nil
			end
		end
	end
end

local function step()
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	local slow = now >= nextCheck
	if slow then
		nextCheck = now + CHECK_INTERVAL
	end
	for index = #rides, 1, -1 do
		local ride = rides[index]
		if not ride.model.Parent or not ride.root.Parent then
			table.remove(rides, index)
			continue
		end
		if ride.wreckAt and now >= ride.wreckAt then
			blowUp(ride)
			continue
		end
		ram(ride, now)
		-- An over-speed drive: the server holds it a moment and brings it back to top speed.
		if
			ride.riders.driver
			and Vehicle.overSpeed(flatSpeed(ride), ride.cfg.TopSpeed, ride.cfg.SpeedSlack)
			and now >= ride.heldUntil
		then
			ride.heldUntil = now + TAKE_BACK
			ride.root:SetNetworkOwner(nil)
			ride.root.AssemblyLinearVelocity = ride.root.AssemblyLinearVelocity.Unit
				* ride.cfg.TopSpeed
			warn(`[Vehicle] {ride.id} over speed; the server holds it {TAKE_BACK} s`)
		end
		if slow then
			-- A running engine carries (the quiet missions' awareness): idle to full by speed.
			local engine = ride.cfg.Engine
			if engine and ride.riders.driver then
				local share = math.clamp(flatSpeed(ride) / ride.cfg.TopSpeed, 0, 1)
				EnemyService.noise(
					ride.root.Position,
					engine.NoiseIdle + (engine.Noise - engine.NoiseIdle) * share
				)
			end
			checkRiders(ride)
			setOwner(ride)
			boardBot(ride)
			local frame = ride.root.CFrame
			local tipped = Vehicle.needsRighting(
				frame.UpVector.Y,
				flatSpeed(ride),
				ride.cfg.Right.Tilt,
				ride.cfg.Right.Slow
			)
			ride.right.Enabled = ride.wreckAt == nil and next(ride.riders) == nil and tipped
			-- On its side: only the flip prompt shows (the seats' would hide it, same key).
			refreshPrompt(ride)
			if tipped then
				for _, prompt in ride.prompts do
					prompt.Enabled = false
				end
			end
			-- Fell off the map.
			if frame.Position.Y < Workspace.FallenPartsDestroyHeight + 5 then
				destroyRide(ride)
			end
		end
	end
end

local function onVehicleMessage(player: Player, kind: unknown)
	if kind ~= Messages.Vehicle.Exit then
		return
	end
	local ride, seatName = rideOf(player.Character)
	if ride and seatName then
		getOff(ride, seatName :: any)
	end
end

function VehicleService.reset()
	for index = #rides, 1, -1 do
		destroyRide(rides[index])
	end
	table.clear(pending)
end

local function registerGroups()
	for _, group in { VehiclePhysics.Group, VehiclePhysics.RayGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	for _, other in { "Enemy", "Gore" } do
		if not PhysicsService:IsCollisionGroupRegistered(other) then
			PhysicsService:RegisterCollisionGroup(other)
		end
		PhysicsService:CollisionGroupSetCollidable(VehiclePhysics.RayGroup, other, false)
	end
	PhysicsService:CollisionGroupSetCollidable(VehiclePhysics.Group, "Gore", false)
	PhysicsService:CollisionGroupSetCollidable(VehiclePhysics.RayGroup, VehiclePhysics.Group, false)
end

function VehicleService.init()
	folder = Instance.new("Folder")
	folder.Name = "Vehicles" -- vehicle Models only (VehicleController walks it)
	folder.Parent = Workspace
	effects = Instance.new("Folder")
	effects.Name = "VehicleEffects" -- shake markers and the wreck's flash
	effects.Parent = Workspace
	registerGroups()
	vehicleRemote = Remotes.get("Vehicle")
	noticeRemote = Remotes.get("BuffNotice")
	vehicleRemote.OnServerEvent:Connect(onVehicleMessage)
	EnemyProjectileService.vehicleHit = onRiderHit
	Lifecycle.register("VehicleService", {
		onRunStart = VehicleService.reset,
		onMissionStart = VehicleService.reset,
		onPlayerRemoving = function(player: Player)
			pending[player] = nil
			for _, ride in rides do
				for seatName, member in ride.riders do
					if member.owner == player then
						getOff(ride, seatName :: SeatName)
					end
				end
				if ride.owner == player then
					ride.owner = nil
				end
			end
		end,
	})
	RunService.PreSimulation:Connect(physicsStep)
	RunService.Heartbeat:Connect(step)
end

return VehicleService
