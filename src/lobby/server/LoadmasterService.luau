--!strict
-- The Loadmaster's book (docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): each
-- soldier signs for a Loadout at his desk (LoadmasterUI, the Loadout remote) and it rides
-- the Lantern into the match as teleport data (LaunchService, Rules/LaunchData). The server
-- checks every request with the same rules and catalog the match uses (Rules/Loadout,
-- ArmsRoom). Prototype: everything in the catalog may be signed for; what a soldier owns
-- (merits, the record) waits for the save service (F9). Nothing is saved between visits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LoadmasterService = {}

local signed: { [Player]: Loadout.Loadout } = {}

-- Every signed Loadout among `players`, keyed by UserId (unsigned soldiers are left out and
-- fly the default).
function LoadmasterService.loadoutsFor(players: { Player }): { [number]: Loadout.Loadout }
	local out: { [number]: Loadout.Loadout } = {}
	for _, player in players do
		local loadout = signed[player]
		if loadout then
			out[player.UserId] = loadout
		end
	end
	return out
end

function LoadmasterService.init()
	local remote = Remotes.get("Loadout")
	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, requested: unknown)
		if kind ~= Messages.Loadout.Request then
			return
		end
		local ok, reason = Loadout.validate(requested, ArmsRoom.catalog())
		if ok then
			local source = requested :: Loadout.Loadout
			signed[player] = {
				primary = source.primary,
				secondary = source.secondary,
				grenade = source.grenade,
				callIns = table.clone(source.callIns),
			}
		end
		remote:FireClient(player, Messages.Loadout.Result, ok, reason)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		signed[player] = nil
	end)
end

return LoadmasterService
