--!strict
-- Night vision on and off, for everyone to see (Config.NightVision.Goggles): a client's
-- NightVision remote says its goggles went down or up, and this sets its character's
-- NightVision attribute; every client then lowers or raises that body's goggles (client
-- NightVision). A new character starts with them up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NightVisionService = {}

function NightVisionService.init()
	Remotes.get("NightVision").OnServerEvent:Connect(function(player: Player, on: unknown)
		if typeof(on) ~= "boolean" then
			return
		end
		local character = player.Character
		if character then
			character:SetAttribute(Attributes.NightVision, on)
		end
	end)
end

return NightVisionService
