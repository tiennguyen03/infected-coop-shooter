--!strict
-- Vault and climb (2026-11-07) in place of the stock jump. Space, with cover in front
-- (Shared.Ledge), carries the body over thin low cover (jersey, hesco: the vault clip) or
-- onto taller cover (bunker, humvee, container: the climb clip); sprinting into low cover
-- vaults by itself. T-walls and buses are too tall and stay walls. During a move the root
-- is anchored and driven along Ledge.position for Config.Movement.*Duration seconds, the
-- body's heading is locked (CameraController) and the stance is stood up
-- (StanceController). Space with nothing in front stands a crouched or prone body up; it
-- never jumps (PlayerSetup zeroes JumpPower as well).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ledge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ledge"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
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

local move: Move? = nil
local nextAutoCheck = 0

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
	for _, name in { "Projectiles", "Tracers", "Resupply", "ResupplyCards", "XPOrbs" } do
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
end

local function begin(humanoid: Humanoid, root: BasePart, ledge: Ledge.Ledge)
	local settings = Config.Movement
	local kind: "vault" | "climb" = if ledge.over then "vault" else "climb"
	local duration = if kind == "vault" then settings.VaultDuration else settings.ClimbDuration
	StanceController.setStance("stand")
	CameraController.setBodyYawLocked(true)
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
	if move or workspace:GetAttribute("GamePaused") == true then
		return Enum.ContextActionResult.Sink
	end
	local model, humanoid, root = character()
	if not model or not humanoid or not root then
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

local function step()
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
	return move ~= nil
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
		CameraController.setBodyYawLocked(false)
	end)
	RunService.Heartbeat:Connect(step)
end

return MovementController
