--!strict
-- Weight. Stock Roblox walking snaps to full speed and stops dead, which makes
-- kiting free. Each frame, after the default control script has read the input (it calls
-- Humanoid:Move at RenderPriority.Input), this eases a tracked velocity toward the input
-- direction times WalkSpeed and hands the humanoid that instead: speeding up, stopping and
-- turning around all take time (Config.Movement.Momentum). Works for keyboard, gamepad and
-- touch alike because it reads the control module's move vector. MovementController
-- suspends it while a vault, climb, roll or slide carries the body and hands back the exit
-- velocity so the body leaves the move still moving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Momentum =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Momentum"))

local STEP_NAME = "Momentum"

local MomentumController = {}

local controls: any = nil
local velocity = Vector3.zero -- studs/s, horizontal
local suspended = false

local function getControls(): any
	if controls then
		return controls
	end
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, playerModule = pcall(require, module :: ModuleScript)
	if ok and playerModule then
		controls = (playerModule :: any):GetControls()
	end
	return controls
end

-- The input as a world-space direction (magnitude 0..1), relative to the camera's heading.
local function inputDirection(): Vector3
	local current = getControls()
	if not current then
		return Vector3.zero
	end
	local moveVector: Vector3 = current:GetMoveVector()
	if moveVector.Magnitude < 0.01 then
		return Vector3.zero
	end
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		return Vector3.zero
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local world = right * moveVector.X - forward * moveVector.Z
	if world.Magnitude > 1 then
		world = world.Unit
	end
	return world
end

local function step(dt: number)
	if suspended then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		velocity = Vector3.zero
		return
	end
	local speed = humanoid.WalkSpeed
	if speed <= 0 then
		velocity = Vector3.zero
		humanoid:Move(Vector3.zero, false)
		return
	end
	local settings = Config.Movement.Momentum
	local target = inputDirection() * speed
	-- Eases toward the input (Rules/Momentum: Acceleration up, Deceleration down or
	-- against the heading) and caps at a lower WalkSpeed at once.
	velocity =
		Momentum.step(velocity, target, speed, settings.Acceleration, settings.Deceleration, dt)
	humanoid:Move(velocity / speed, false)
end

-- A move (vault, climb, roll, slide) carries the body; momentum stops steering it.
function MomentumController.suspend()
	suspended = true
end

-- Hand steering back, carrying `exitVelocity` (studs/s) out of the move.
function MomentumController.resume(exitVelocity: Vector3?)
	suspended = false
	local exit = exitVelocity or Vector3.zero
	velocity = Vector3.new(exit.X, 0, exit.Z)
end

function MomentumController.getVelocity(): Vector3
	return velocity
end

-- A shove from outside (the Warden's Sweep, Impact "push"): the root takes the velocity at
-- once (the client owns its physics) and the carried momentum follows it, so the body
-- eases out of the shove instead of snapping back to the input.
function MomentumController.push(shove: Vector3)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	root.AssemblyLinearVelocity = shove
	velocity = Vector3.new(shove.X, 0, shove.Z)
end

function MomentumController.init()
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Input.Value + 1, step)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		velocity = Vector3.zero
		suspended = false
	end)
end

return MomentumController
