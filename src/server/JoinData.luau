--!strict
-- The one place the match reads a soldier's teleport data from the lobby (docs/
-- MULTIPLAYER_READINESS.md decision 7; the lobby builds it with Rules/LaunchData). Nothing
-- here is trusted: the Loadout is re-checked against the match's catalog, and a soldier with
-- no data (Studio, a direct join, a late joiner) or a bad Loadout gets nil and the caller's
-- default. A stateless helper (no init): call it when the value is first needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local LaunchData = require(ReplicatedStorage.Shared.Rules.LaunchData)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)

local JoinData = {}

-- The Loadout this soldier signed for at the Loadmaster, or nil.
function JoinData.loadout(player: Player): Loadout.Loadout?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return nil
	end
	local catalog = ArmsRoom.catalog()
	local loadout = LaunchData.loadoutFor(
		joinData.TeleportData,
		player.UserId,
		function(entry: unknown): boolean
			return (Loadout.validate(entry, catalog))
		end
	)
	if loadout then
		print(`[JoinData] {player.Name} arrived with a signed Loadout ({loadout.primary})`)
	end
	return loadout
end

return JoinData
