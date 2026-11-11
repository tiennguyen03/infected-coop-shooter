--!strict
-- Each soldier's record (docs/sprints/LOBBY_V1_FALLOW.md > Buying at the Quartermaster;
-- owner + Tien, 2026-11-10): the merits they hold and the guns bought onto it at the
-- Quartermaster's rack. Loaded on join (a new soldier starts with Config.Lobby.Save.
-- StartMerits), kept in a DataStore (SaveSlot), sent to the soldier's client on the `Record`
-- remote. Buying is checked here with Rules/Record against each gun's own Config price
-- (WeaponDefinitions Price: 0 = issued free, nil = not for sale). The Loadmaster only signs
-- for a Loadout whose guns are on the record (`allows`). Merits are only granted at the start
-- for now: earning them from runs is open (the match would save what a run pays). Grenades
-- and call-ins are bought the same way (KitPrices: each item's own row; call-ins at the desk
-- that sells them, DeskShop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local SaveSlot = require(script.Parent.SaveSlot)

local RecordService = {}

local SAVE = Config.Lobby.Save
local LOAD_WAIT = 10 -- seconds `waitFor` waits for a record still loading

local records: { [Player]: Record.Record } = {}
local remote: RemoteEvent
local slot: SaveSlot.Slot

function RecordService.priceOf(id: string): number?
	return KitPrices.of(id)
end

local function send(player: Player, record: Record.Record)
	remote:FireClient(player, Messages.Record.State, record.merits, table.clone(record.owned))
end

-- The soldier's record, waiting up to LOAD_WAIT while it loads; nil when they left.
function RecordService.waitFor(player: Player): Record.Record?
	local started = os.clock()
	while not records[player] and player.Parent and os.clock() - started < LOAD_WAIT do
		task.wait(0.1)
	end
	return records[player]
end

-- Whether every gun in `loadout` is on the soldier's record.
function RecordService.allows(player: Player, loadout: Record.Loadout): (boolean, string?)
	local record = RecordService.waitFor(player)
	if not record then
		return false, "record not loaded"
	end
	return Record.allows(record, loadout, RecordService.priceOf)
end

local function load(player: Player)
	local record = Record.decode(slot:load(player), SAVE.StartMerits)
	if player.Parent and not records[player] then
		records[player] = record
		send(player, record)
	end
end

local function buy(player: Player, id: unknown)
	local record = records[player]
	if not record or typeof(id) ~= "string" then
		remote:FireClient(player, Messages.Record.Refused, id, "loading")
		return
	end
	local after, ok, reason = Record.buy(record, id, RecordService.priceOf)
	if not ok then
		remote:FireClient(player, Messages.Record.Refused, id, reason)
		return
	end
	records[player] = after
	slot:save(player, Record.encode(after))
	print(`[RecordService] {player.Name} bought {id}: {after.merits} merits left`)
	send(player, after)
end

function RecordService.init()
	remote = Remotes.get("Record")
	slot = SaveSlot.new(SAVE.RecordStore, "r_")
	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, id: unknown)
		if kind == Messages.Record.Buy then
			buy(player, id)
		end
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		records[player] = nil
	end)
end

return RecordService
