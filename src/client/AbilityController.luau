--!strict
-- Sends Q (dash) / E (breach) ability requests to the server. The server
-- validates and performs the ability; this controller only forwards input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AbilityController = {}

function AbilityController.init()
	local useAbility = Remotes.get("UseAbility")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Don't fire abilities while the run is soft-paused (item selection).
		if workspace:GetAttribute("GamePaused") == true then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			useAbility:FireServer("dash")
		elseif input.KeyCode == Enum.KeyCode.E then
			useAbility:FireServer("breach")
		end
	end)
end

return AbilityController
