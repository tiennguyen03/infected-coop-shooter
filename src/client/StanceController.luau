--!strict
-- Stances: LeftControl toggles crouch, C toggles prone, either key from the
-- other stance switches straight across; Shift (sprint), Space (vault/climb, which also
-- stands a crouched body with nothing in front) and a respawn stand the body up. Speed
-- factors and transition times are Config.Player.Stances; the camera pivot drops with the
-- stance (CameraController) and the body plays the stance's clips (AnimationController).
-- Movement stays client-owned like sprint; the server hears each change on the Stance
-- remote (StanceService drops the HipHeight for a prone body so it fits a crawl space) and
-- bounces "prone" back when a stand-up is refused under a ceiling, which this side also
-- checks first (Config.Player.Stances.ProneHeadroom).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local SprintController = require(script.Parent.SprintController)

export type Stance = AnimationController.Stance

local StanceController = {}

local stance: Stance = "stand"
local lockedUntil = 0
local stanceRemote: RemoteEvent? = nil

-- A prone body under a ceiling stays down: nothing within ProneHeadroom above the root.
local function headroomClear(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local size = Vector3.new(root.Size.X, 0.2, root.Size.Z)
	local hit = workspace:Blockcast(
		root.CFrame,
		size,
		Vector3.new(0, Config.Player.Stances.ProneHeadroom, 0),
		params
	)
	return hit == nil
end

local function transitionTime(from: Stance, to: Stance): number
	local times = Config.Player.Stances.TransitionTime
	local key = if to == "stand" then from else to
	return (times :: { [string]: number })[key] or 0
end

local function speedFactor(of: Stance): number
	local settings = Config.Player.Stances
	if of == "crouch" then
		return settings.CrouchSpeedFactor
	elseif of == "prone" then
		return settings.ProneSpeedFactor
	end
	return 1
end

local function alive(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Returns true when the stance changed.
function StanceController.setStance(newStance: Stance): boolean
	if newStance == stance then
		return false
	end
	if not alive() or os.clock() < lockedUntil then
		return false
	end
	if stance == Messages.Stance.Prone and not headroomClear() then
		return false -- crawl space: no room to get up here
	end
	local time = transitionTime(stance, newStance)
	AnimationController.setStance(newStance, time)
	stance = newStance
	lockedUntil = os.clock() + time
	SprintController.setStanceFactor(speedFactor(newStance), newStance == "stand")
	CameraController.setStance(newStance)
	if stanceRemote then
		stanceRemote:FireServer(newStance)
	end
	return true
end

function StanceController.getStance(): Stance
	return stance
end

local function toggle(target: Stance)
	if stance == target then
		StanceController.setStance("stand")
	else
		StanceController.setStance(target)
	end
end

function StanceController.init()
	local remote = Remotes.get("Stance")
	stanceRemote = remote
	remote.OnClientEvent:Connect(function(forced: unknown)
		if forced == Messages.Stance.Prone and stance ~= Messages.Stance.Prone then
			lockedUntil = 0
			StanceController.setStance("prone")
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or workspace:GetAttribute(Attributes.GamePaused) == true then
			return
		end
		-- While sprinting these keys roll and slide instead (MovementController).
		local lowKey = input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C
		if lowKey and SprintController.isSprinting() then
			return
		end
		local character = Players.LocalPlayer.Character
		if character and character:GetAttribute(Attributes.SquadState) == "Downed" then
			return -- stays prone until revived
		end
		if input.KeyCode == Enum.KeyCode.LeftControl then
			toggle("crouch")
		elseif input.KeyCode == Enum.KeyCode.C then
			toggle("prone")
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			StanceController.setStance("stand")
		end
	end)

	-- Downed (Squad) drops the body prone; a revive stands it up. The body that already
	-- exists at boot gets the hook too.
	local function watchSquadState(character: Model)
		character:GetAttributeChangedSignal(Attributes.SquadState):Connect(function()
			local state = character:GetAttribute(Attributes.SquadState)
			lockedUntil = 0
			if state == "Downed" then
				StanceController.setStance("prone")
			elseif state == "Alive" and stance == Messages.Stance.Prone then
				StanceController.setStance("stand")
			end
		end)
	end
	if Players.LocalPlayer.Character then
		watchSquadState(Players.LocalPlayer.Character)
	end
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		watchSquadState(character)
		stance = "stand"
		lockedUntil = 0
		SprintController.setStanceFactor(1, true)
		CameraController.setStance("stand")
	end)
end

return StanceController
