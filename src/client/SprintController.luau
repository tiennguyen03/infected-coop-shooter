--!strict
-- Hold LeftShift to sprint. WalkSpeed is set locally; the character is
-- client-owned so this takes effect immediately without replication. Aiming down sights
-- (WeaponController) overrides sprint and slows the walk by Config.Weapon.ADS.MoveSpeedFactor;
-- a stance (StanceController) scales the walk and may forbid sprinting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SprintController = {}

local isSprinting = false
local isAiming = false
local stanceFactor = 1
local sprintAllowed = true

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local humanoid = getHumanoid()
	if humanoid then
		local base = if isSprinting
				and sprintAllowed
				and not isAiming
			then Config.Player.SprintSpeed
			else Config.Player.WalkSpeed
		local mult = (Players.LocalPlayer:GetAttribute("MoveSpeedMult") :: number?) or 1
		if isAiming then
			mult *= Config.Weapon.ADS.MoveSpeedFactor
		end
		mult *= stanceFactor
		humanoid.WalkSpeed = base * mult
	end
end

local function setSprinting(sprinting: boolean)
	isSprinting = sprinting
	applySpeed()
end

function SprintController.setAiming(aiming: boolean)
	isAiming = aiming
	applySpeed()
end

-- A stance scales the walk; sprint is only possible standing.
function SprintController.setStanceFactor(factor: number, canSprint: boolean)
	stanceFactor = factor
	sprintAllowed = canSprint
	applySpeed()
end

function SprintController.isSprinting(): boolean
	return isSprinting and sprintAllowed and not isAiming
end

function SprintController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftShift then
			setSprinting(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			setSprinting(false)
		end
	end)

	-- A respawned character starts at base speed even if Shift is held.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		isAiming = false
		stanceFactor = 1
		sprintAllowed = true
		setSprinting(false)
	end)

	-- Items/buffs can change the multiplier mid-run; reapply immediately.
	Players.LocalPlayer:GetAttributeChangedSignal("MoveSpeedMult"):Connect(applySpeed)
end

return SprintController
