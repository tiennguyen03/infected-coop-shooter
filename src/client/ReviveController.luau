--!strict
-- The revive animation on this client (Shared.ReviveAnimation, Config.ReviveAnimation). The
-- local body plays its own clips when the server gives it a role (kneeling over a casualty,
-- or lying on its back and getting up), so the squad sees them through the Animator, and
-- holds its heading meanwhile instead of turning with the camera. Every body with a role,
-- ours, a squadmate's or a bot's, gets its arms posed here each frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ReviveAnimation =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReviveAnimation"))
local CameraController = require(script.Parent.CameraController)

local ReviveController = {}

function ReviveController.init()
	if not Config.ReviveAnimation.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local function onCharacterAdded(character: Model)
		ReviveAnimation.drive(character, { setYawLocked = CameraController.setBodyYawLocked })
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	ReviveAnimation.watch()
end

return ReviveController
