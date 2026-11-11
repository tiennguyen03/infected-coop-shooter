--!strict
-- Vault and climb in place of the stock jump. Space (Config.Keys.Vault), with cover in front
-- (Shared.Ledge), carries the body over thin low cover (jersey, hesco: the vault clip) or
-- onto taller cover (bunker, humvee, container: the climb clip); sprinting into low cover
-- vaults by itself. T-walls and buses are too tall and stay walls. During a move the root
-- is anchored and driven along Ledge.position for Config.Movement.*Duration seconds, the
-- body's heading is locked (CameraController) and the stance is stood up
-- (StanceController). Space with nothing in front stands a crouched or prone body up; it
-- never jumps (PlayerSetup zeroes JumpPower as well).
--
-- Roll and slide (keys: Config.Keys): Sprint twice quickly rolls; while sprinting, holding a
-- Crouch key (C or LeftControl) slides along the direction of travel until the key is let
-- go (StanceController leaves those keys alone while sprinting). Both
-- lock the heading, drive the humanoid along that direction at a speed this module owns
-- (SprintController.setOverrideSpeed) and hand the exit speed back to MomentumController.
-- The roll reports itself to the server (CoverMove) for its melee immunity window. Each
-- costs stamina once on entry (Config.Stamina, SprintController.spendStamina).
--
-- The slide keeps momentum (Rules/Slide, Config.Movement.Slide): it starts from the speed
-- going in, and each frame friction takes speed off and the floor under the body (one short
-- ray) adds it downhill or takes more uphill, until it is too slow. Whatever speed is left
-- above the walk or sprint speed then bleeds off (the coast) instead of snapping.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ledge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ledge"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Slide =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Slide"))
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local MomentumController = require(script.Parent.MomentumController)
local SprintController = require(script.Parent.SprintController)
local StanceController = require(script.Parent.StanceController)

local ACTION = "VaultClimb"
local AUTO_CHECK_INTERVAL = 0.15
local AUTO_PRESS_SPEED = 6 -- studs/s: slower than this while pushing forward = against cover

local MovementController = {}

type Move = {
	root: BasePart,
	ledge: Ledge.Ledge,
	start: Vector3,
	yaw: CFrame,
	startedAt: number,
	duration: number,
}

type Dash = {
	kind: "roll" | "slide",
	humanoid: Humanoid,
	root: BasePart,
	direction: Vector3,
	startedAt: number,
	duration: number, -- the roll's length; a slide ends by its speed
	speed: number, -- studs/s now
	params: RaycastParams, -- for the slide's floor ray
	clip: "playing" | "held" | "done", -- the slide clip: holds its pose on a long slide
	held: boolean, -- a slide: lasts while its key is down (slideKey)
}

local move: Move? = nil
local dash: Dash? = nil
local coast: number? = nil -- studs/s still carried out of a roll or slide, bleeding off
local nextAutoCheck = 0
local readyAt = { roll = 0, slide = 0 }
local slideKey: Enum.KeyCode? = nil -- the key holding the current slide down; nil once let go

local function character(): (Model?, Humanoid?, BasePart?)
	local model = Players.LocalPlayer.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return model, humanoid, root
end

local function rayParams(model: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model }
	for _, name in { "Projectiles", "Tracers", "Resupply", "ResupplyCards", "Drones", "Mines" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function finish(current: Move)
	local root = current.root
	root.CFrame = CFrame.new(current.ledge.landing) * current.yaw
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	move = nil
	CameraController.setBodyYawLocked(false)
	MomentumController.resume(Vector3.zero)
end

local function begin(humanoid: Humanoid, root: BasePart, ledge: Ledge.Ledge)
	local settings = Config.Movement
	local kind: "vault" | "climb" = if ledge.over then "vault" else "climb"
	local duration = if kind == Messages.CoverMove.Vault
		then settings.VaultDuration
		else settings.ClimbDuration
	coast = nil
	SprintController.setOverrideSpeed(nil)
	StanceController.setStance("stand")
	CameraController.setBodyYawLocked(true)
	MomentumController.suspend()
	AnimationController.playMove(kind, duration)
	Remotes.get("CoverMove"):FireServer(kind)
	local yaw = CFrame.lookAlong(Vector3.zero, ledge.forward)
	root.CFrame = CFrame.new(root.Position) * yaw
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	humanoid:Move(Vector3.zero, false)
	move = {
		root = root,
		ledge = ledge,
		start = root.Position,
		yaw = yaw,
		startedAt = os.clock(),
		duration = duration,
	}
end

-- Looks for a ledge the way the body is heading (its move direction, else where it faces).
local function findLedge(
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	maxHeight: number
): Ledge.Ledge?
	local forward = humanoid.MoveDirection
	if forward.Magnitude < 0.1 then
		forward = root.CFrame.LookVector
	end
	return Ledge.find(root, humanoid, forward, maxHeight, rayParams(model))
end

local function onSpace(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if move or dash or workspace:GetAttribute(Attributes.GamePaused) == true then
		return Enum.ContextActionResult.Sink
	end
	local model, humanoid, root = character()
	if
		not model
		or not humanoid
		or not root
		or model:GetAttribute(Attributes.SquadState) == "Downed"
		or model:GetAttribute(Attributes.KnockedUntil) ~= nil
	then
		return Enum.ContextActionResult.Sink
	end
	local ledge = findLedge(model, humanoid, root, Config.Movement.ClimbMaxHeight)
	if ledge then
		begin(humanoid, root, ledge)
	else
		StanceController.setStance("stand")
	end
	return Enum.ContextActionResult.Sink
end

local function slideGetUp(): number
	local settings = Config.Movement.Slide
	return settings.ClipDuration * (1 - settings.ClipHoldAt)
end

local function endDash(current: Dash)
	dash = nil
	if current.clip == "held" then
		AnimationController.releaseMove(current.kind, slideGetUp())
	end
	SprintController.setOverrideSpeed(nil)
	CameraController.setBodyYawLocked(false)
	if current.root.Parent then
		-- Leave the move still travelling. Speed above the walk/sprint speed is kept and
		-- bleeds off in step() (the coast); the body never stops dead or snaps down.
		local exitSpeed = current.speed
		if exitSpeed > SprintController.getBaseSpeed() then
			coast = exitSpeed
			SprintController.setOverrideSpeed(exitSpeed)
		end
		MomentumController.resume(current.direction * exitSpeed)
	else
		MomentumController.resume(Vector3.zero)
	end
	readyAt[current.kind] = os.clock()
		+ Config.Movement[if current.kind == Messages.CoverMove.Roll then "Roll" else "Slide"].Cooldown
end

-- How steeply the floor under a sliding body falls away along its travel (Slide.slope);
-- 0 in the air.
local function floorSlope(current: Dash): number
	local hit = workspace:Raycast(
		current.root.Position,
		Vector3.new(0, -Config.Movement.Slide.FloorProbe, 0),
		current.params
	)
	if not hit then
		return 0
	end
	return Slide.slope(current.direction.X, current.direction.Z, hit.Normal.X, hit.Normal.Z)
end

local function stepDash(current: Dash, dt: number)
	if not current.root.Parent or current.humanoid.Health <= 0 then
		endDash(current)
		return
	end
	local elapsed = os.clock() - current.startedAt
	if current.kind == Messages.CoverMove.Roll then
		if elapsed >= current.duration then
			endDash(current)
			return
		end
	else
		local settings = Config.Movement.Slide
		local slope = floorSlope(current)
		current.speed = Slide.step(current.speed, slope, dt, settings)
		-- A held slide: letting the key go gets the body up (never before MinHold).
		local letGo = current.held and slideKey == nil and elapsed >= settings.MinHold
		if letGo or Slide.isOver(current.speed, elapsed, settings) then
			endDash(current)
			return
		end
		-- The clip runs once; when the slide will outlast it, it holds the slide pose and
		-- plays the get-up as the slide runs out. A flat slide never holds.
		local left = Slide.timeLeft(current.speed, slope, elapsed, settings)
		if current.clip == "playing" then
			if elapsed >= settings.ClipDuration * settings.ClipHoldAt then
				if left > slideGetUp() then
					AnimationController.holdMove(current.kind)
					current.clip = "held"
				else
					current.clip = "done"
				end
			end
		elseif current.clip == "held" and left <= slideGetUp() then
			AnimationController.releaseMove(current.kind, slideGetUp())
			current.clip = "done"
		end
	end
	SprintController.setOverrideSpeed(current.speed)
	current.humanoid:Move(current.direction, false)
end

-- A roll (Sprint twice) or a slide (sprint + hold a Crouch key). Returns true when it started.
function MovementController.tryDash(kind: "roll" | "slide"): boolean
	if move or dash or workspace:GetAttribute(Attributes.GamePaused) == true then
		return false
	end
	if os.clock() < readyAt[kind] then
		return false
	end
	local model, humanoid, root = character()
	if
		not model
		or not humanoid
		or not root
		or model:GetAttribute(Attributes.SquadState) == "Downed"
		or model:GetAttribute(Attributes.KnockedUntil) ~= nil
	then
		return false
	end
	local heading = MomentumController.getVelocity()
	if heading.Magnitude < 1 then
		heading = humanoid.MoveDirection
	end
	heading = Vector3.new(heading.X, 0, heading.Z)
	if heading.Magnitude < 0.1 then
		return false
	end
	local direction = heading.Unit
	local settings = Config.Movement
	local isRoll = kind == Messages.CoverMove.Roll
	-- Last refusal: a winded body cannot roll or slide. The cost is paid once, here.
	local cost = if isRoll then Config.Stamina.RollCost else Config.Stamina.SlideCost
	if not SprintController.spendStamina(cost) then
		return false
	end
	local duration = if isRoll then settings.Roll.Duration else settings.Slide.ClipDuration
	local startSpeed = if isRoll
		then settings.Roll.Speed
		else Slide.entrySpeed(heading.Magnitude, settings.Slide)
	coast = nil
	StanceController.setStance("stand")
	CameraController.setBodyYawLocked(true)
	MomentumController.suspend()
	root.CFrame = CFrame.lookAlong(root.Position, direction)
	SprintController.setOverrideSpeed(startSpeed)
	AnimationController.playMove(kind, duration)
	-- The roll buys its melee window; the slide only drops a reload in progress.
	Remotes.get("CoverMove"):FireServer(kind)
	dash = {
		kind = kind,
		humanoid = humanoid,
		root = root,
		direction = direction,
		startedAt = os.clock(),
		duration = duration,
		speed = startSpeed,
		params = rayParams(model),
		clip = if isRoll then "done" else "playing",
		held = not isRoll,
	}
	return true
end

local function step(dt: number)
	local currentDash = dash
	if currentDash then
		stepDash(currentDash, dt)
		return
	end
	local carried = coast
	if carried then
		local speed = carried - Config.Movement.Slide.ExitDecel * dt
		if speed <= SprintController.getBaseSpeed() then
			coast = nil
			SprintController.setOverrideSpeed(nil)
		else
			coast = speed
			SprintController.setOverrideSpeed(speed)
		end
	end
	local current = move
	if current then
		if not current.root.Parent then
			move = nil
			CameraController.setBodyYawLocked(false)
			return
		end
		local alpha = (os.clock() - current.startedAt) / current.duration
		if alpha >= 1 then
			finish(current)
			return
		end
		current.root.CFrame = CFrame.new(Ledge.position(current.start, current.ledge, alpha))
			* current.yaw
		return
	end

	-- Sprinting into low cover vaults it.
	if not Config.Movement.AutoVaultSprinting or not SprintController.isSprinting() then
		return
	end
	local now = os.clock()
	if now < nextAutoCheck then
		return
	end
	nextAutoCheck = now + AUTO_CHECK_INTERVAL
	local model, humanoid, root = character()
	if not model or not humanoid or not root or humanoid.MoveDirection.Magnitude < 0.5 then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > AUTO_PRESS_SPEED then
		return
	end
	local ledge = findLedge(model, humanoid, root, Config.Movement.VaultMaxHeight)
	if ledge then
		begin(humanoid, root, ledge)
	end
end

function MovementController.init()
	ContextActionService:BindActionAtPriority(
		ACTION,
		onSpace,
		false,
		Enum.ContextActionPriority.High.Value,
		Config.Keys.Vault,
		Enum.KeyCode.ButtonA
	)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		move = nil
		dash = nil
		coast = nil
		readyAt.roll, readyAt.slide = 0, 0
		SprintController.setOverrideSpeed(nil)
		CameraController.setBodyYawLocked(false)
		MomentumController.resume(Vector3.zero)
	end)
	-- Sprint twice quickly rolls (the first press is the sprint). While sprinting, holding a
	-- Crouch key slides for as long as the key is down (StanceController skips those
	-- keys while sprinting); letting go ends the slide once it is MinHold old.
	local lastShiftAt = -math.huge
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Keys.Sprint then
			local now = os.clock()
			if now - lastShiftAt <= Config.Movement.Roll.DoubleTap then
				lastShiftAt = -math.huge
				MovementController.tryDash("roll")
			else
				lastShiftAt = now
			end
		elseif table.find(Config.Keys.Crouch, input.KeyCode) then
			if SprintController.isSprinting() and MovementController.tryDash("slide") then
				slideKey = input.KeyCode
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if slideKey and input.KeyCode == slideKey then
			slideKey = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return MovementController
