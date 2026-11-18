--!strict
-- Kit Mods at the Loadmaster (Nova, 2026-11-18; the KIT MODS tab, KitModsTab): buying the next
-- rank of a mod with merits, on the `KitMods` remote. Server-authoritative: the client names
-- the mod and the rank it is buying, this checks it with Rules/KitModRules against the record
-- as it is stored and spends there, in one step (RecordService.change: the same save as the
-- Quartermaster's guns). Merits only, never tabs. The ranks are ids on the record, so the
-- match reads them from the same record (src/server/KitModService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local KitModRules = require(ReplicatedStorage.Shared.Rules.KitModRules)
local KitMods = require(ReplicatedStorage.Shared.KitMods)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RecordService = require(script.Parent.RecordService)

local KitModService = {}

local remote: RemoteEvent

-- Sends the soldier's ranks (and keeps their KitRanks attribute in step).
local function sendRanks(player: Player)
	local record = RecordService.waitFor(player)
	if not record then
		remote:FireClient(player, Messages.KitMods.Refused, "", "loading")
		return
	end
	local ranks = KitModRules.ranks(record.owned, KitMods.Rows)
	if player.Parent then
		player:SetAttribute(Attributes.KitRanks, KitModRules.encode(ranks))
		remote:FireClient(player, Messages.KitMods.State, ranks)
	end
end

local function buy(player: Player, modId: unknown, rank: unknown)
	if
		typeof(modId) ~= "string"
		or typeof(rank) ~= "number"
		or rank ~= math.floor(rank)
		or not KitMods.Rows[modId]
	then
		remote:FireClient(player, Messages.KitMods.Refused, modId, "unknown")
		return
	end
	local ok, reason = RecordService.change(player, `bought {modId} rank {rank}`, function(record)
		return KitModRules.buyRank(record, modId, rank, KitMods.Rows)
	end)
	if not ok then
		remote:FireClient(player, Messages.KitMods.Refused, modId, reason)
		return
	end
	sendRanks(player)
end

function KitModService.init()
	remote = Remotes.get("KitMods")
	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, a: unknown, b: unknown)
		if kind == Messages.KitMods.Buy then
			buy(player, a, b)
		elseif kind == Messages.KitMods.Get then
			sendRanks(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(sendRanks, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(sendRanks, player)
	end
end

return KitModService
