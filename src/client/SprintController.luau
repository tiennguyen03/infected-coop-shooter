--!strict
-- Hold LeftShift to sprint. WalkSpeed is set locally; the character is
-- client-owned so this takes effect immediately without replication.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SprintController = {}

local isSprinting = false

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local humanoid = getHumanoid()
	if humanoid then
		local base = if isSprinting then Config.Player.SprintSpeed else Config.Player.WalkSpeed
		local mult = (Players.LocalPlayer:GetAttribute("MoveSpeedMult") :: number?) or 1
		humanoid.WalkSpeed = base * mult
	end
end

local function setSprinting(sprinting: boolean)
	isSprinting = sprinting
	applySpeed()
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
		setSprinting(false)
	end)

	-- Items/buffs can change the multiplier mid-run; reapply immediately.
	Players.LocalPlayer:GetAttributeChangedSignal("MoveSpeedMult"):Connect(applySpeed)
end

return SprintController
