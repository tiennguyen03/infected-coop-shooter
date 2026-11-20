--!strict
-- The Kit Mods in a match (Nova, 2026-11-18): each soldier's ranks, bought at the Loadmaster's
-- KIT MODS tab (lobby KitModService), are read once from their merit record when they join
-- (MeritService.readRecord, the same DataStore and key the lobby writes) and published as the
-- KitRanks attribute (Rules/KitModRules.encode). The services that own an effect read it
-- through KitMods.bonusFor: LoadoutService (StimsCarried) and the client's SprintController
-- (StaminaRolls). The record is the only source: a client cannot set its own ranks. No record
-- (Studio without API access, a DataStore error) = no ranks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local KitModRules = require(ReplicatedStorage.Shared.Rules.KitModRules)
local KitMods = require(ReplicatedStorage.Shared.KitMods)
local LoadoutService = require(script.Parent.LoadoutService)
local MeritService = require(script.Parent.MeritService)

local KitModService = {}

-- Publishes `ranks` for `player` and hands them any stims the new cap allows.
function KitModService.apply(player: Player, ranks: KitModRules.Ranks)
	if not player.Parent then
		return
	end
	local before = KitMods.bonusFor(player, "StimsCarried")
	player:SetAttribute(Attributes.KitRanks, KitModRules.encode(ranks))
	LoadoutService.addKitStims(player, KitMods.bonusFor(player, "StimsCarried") - before)
end

local function load(player: Player)
	local record = MeritService.readRecord(player.UserId)
	if not record then
		return
	end
	KitModService.apply(player, KitModRules.ranks(record.owned, KitMods.Rows))
end

function KitModService.init()
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return KitModService
