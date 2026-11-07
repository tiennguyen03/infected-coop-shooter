--!strict
-- Stances (2026-11-07): LeftControl toggles crouch, C toggles prone, either key from the
-- other stance switches straight across; Shift (sprint), Space (vault/climb, which also
-- stands a crouched body with nothing in front) and a respawn stand the body up. Speed
-- factors and transition times are Config.Player.Stances; the camera pivot drops with the
-- stance (CameraController) and the body plays the stance's clips (AnimationController).
-- Movement stays client-owned like sprint; the server sees the stance only through the
-- replicated animation tracks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local SprintController = require(script.Parent.SprintController)

export type Stance = AnimationController.Stance

local StanceController = {}

local stance: Stance = "stand"
local lockedUntil = 0

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
	local time = transitionTime(stance, newStance)
	AnimationController.setStance(newStance, time)
	stance = newStance
	lockedUntil = os.clock() + time
	SprintController.setStanceFactor(speedFactor(newStance), newStance == "stand")
	CameraController.setStance(newStance)
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
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or workspace:GetAttribute("GamePaused") == true then
			return
		end
		-- While sprinting these keys roll and slide instead (MovementController).
		local lowKey = input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C
		if lowKey and SprintController.isSprinting() then
			return
		end
		local character = Players.LocalPlayer.Character
		if character and character:GetAttribute("SquadState") == "Downed" then
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
		character:GetAttributeChangedSignal("SquadState"):Connect(function()
			local state = character:GetAttribute("SquadState")
			lockedUntil = 0
			if state == "Downed" then
				StanceController.setStance("prone")
			elseif state == "Alive" and stance == "prone" then
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
