--!strict
-- Vault and climb (2026-11-07) in place of the stock jump. Space, with cover in front
-- (Shared.Ledge), carries the body over thin low cover (jersey, hesco: the vault clip) or
-- onto taller cover (bunker, humvee, container: the climb clip); sprinting into low cover
-- vaults by itself. T-walls and buses are too tall and stay walls. During a move the root
-- is anchored and driven along Ledge.position for Config.Movement.*Duration seconds, the
-- body's heading is locked (CameraController) and the stance is stood up
-- (StanceController). Space with nothing in front stands a crouched or prone body up; it
-- never jumps (PlayerSetup zeroes JumpPower as well).
--
-- Roll and slide (2026-11-07): while sprinting, LeftControl rolls and C slides along the
-- direction of travel (StanceController leaves those keys alone while sprinting). Both
-- lock the heading, drive the humanoid along that direction at a speed this module owns
-- (SprintController.setOverrideSpeed) and hand the exit speed back to MomentumController.
-- The roll reports itself to the server (CoverMove) for its melee immunity window.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ledge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ledge"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
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
	duration: number,
	startSpeed: number,
	endSpeed: number,
}

local move: Move? = nil
local dash: Dash? = nil
local nextAutoCheck = 0
local readyAt = { roll = 0, slide = 0 }

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
	local duration = if kind == "vault" then settings.VaultDuration else settings.ClimbDuration
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
	if move or dash or workspace:GetAttribute("GamePaused") == true then
		return Enum.ContextActionResult.Sink
	end
	local model, humanoid, root = character()
	if
		not model
		or not humanoid
		or not root
		or model:GetAttribute("SquadState") == "Downed"
		or model:GetAttribute("KnockedUntil") ~= nil
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

local function endDash(current: Dash)
	dash = nil
	SprintController.setOverrideSpeed(nil)
	CameraController.setBodyYawLocked(false)
	if current.root.Parent then
		-- Leave the move still travelling: the end speed, capped by the walk/sprint speed.
		local exitSpeed = math.min(current.endSpeed, current.humanoid.WalkSpeed)
		MomentumController.resume(current.direction * exitSpeed)
	else
		MomentumController.resume(Vector3.zero)
	end
	readyAt[current.kind] = os.clock()
		+ Config.Movement[if current.kind == "roll" then "Roll" else "Slide"].Cooldown
end

local function stepDash(current: Dash)
	if not current.root.Parent or current.humanoid.Health <= 0 then
		endDash(current)
		return
	end
	local alpha = (os.clock() - current.startedAt) / current.duration
	if alpha >= 1 then
		endDash(current)
		return
	end
	local speed = current.startSpeed + (current.endSpeed - current.startSpeed) * alpha
	SprintController.setOverrideSpeed(speed)
	current.humanoid:Move(current.direction, false)
end

-- Sprint + LeftControl (roll) or sprint + C (slide). Returns true when it started.
function MovementController.tryDash(kind: "roll" | "slide"): boolean
	if move or dash or workspace:GetAttribute("GamePaused") == true then
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
		or model:GetAttribute("SquadState") == "Downed"
		or model:GetAttribute("KnockedUntil") ~= nil
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
	local duration, startSpeed, endSpeed
	if kind == "roll" then
		duration, startSpeed, endSpeed =
			settings.Roll.Duration, settings.Roll.Speed, settings.Roll.Speed
	else
		duration, startSpeed, endSpeed =
			settings.Slide.Duration, settings.Slide.StartSpeed, settings.Slide.EndSpeed
	end
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
		startSpeed = startSpeed,
		endSpeed = endSpeed,
	}
	return true
end

local function step()
	local currentDash = dash
	if currentDash then
		stepDash(currentDash)
		return
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

function MovementController.isMoving(): boolean
	return move ~= nil or dash ~= nil
end

function MovementController.init()
	ContextActionService:BindActionAtPriority(
		ACTION,
		onSpace,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		move = nil
		dash = nil
		readyAt.roll, readyAt.slide = 0, 0
		SprintController.setOverrideSpeed(nil)
		CameraController.setBodyYawLocked(false)
		MomentumController.resume(Vector3.zero)
	end)
	-- Sprint + LeftControl rolls, sprint + C slides (StanceController skips these while
	-- sprinting). Shift is read from the key itself: sprint may be blocked (ADS) mid-press.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not SprintController.isSprinting() then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftControl then
			MovementController.tryDash("roll")
		elseif input.KeyCode == Enum.KeyCode.C then
			MovementController.tryDash("slide")
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return MovementController
