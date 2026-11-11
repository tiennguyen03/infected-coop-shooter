--!strict
-- Each soldier's record (docs/sprints/LOBBY_V1_FALLOW.md > Buying at the Quartermaster;
-- owner + Tien, 2026-11-10): the merits they hold and the guns bought onto it at the
-- Quartermaster's rack. Loaded on join (a new soldier starts with Config.Lobby.Save.
-- StartMerits), kept in a DataStore (SaveSlot), sent to the soldier's client on the `Record`
-- remote. Buying is checked here with Rules/Record against each gun's own Config price
-- (WeaponDefinitions Price: 0 = issued free, nil = not for sale). The Loadmaster only signs
-- for a Loadout whose guns are on the record (`allows`). Merits are earned on missions: the
-- match pays them onto this same record (src/server/MeritService) while the soldier is away,
-- and the lobby reads it fresh on every join. Grenades and call-ins are bought the same way
-- (KitPrices: each item's own row; call-ins at the desk that sells them, DeskShop). The
-- record also holds tabs, the hard currency (TabsService pays Robux receipts through
-- `grantReceipt`); nothing is bought with tabs yet.

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
-- Soldiers whose saved record could not be read on join (a DataStore error, or Studio): the
-- record held here is a stand-in, and saving it would wipe the real one (merits earned on
-- missions, kit, paid tabs). They can still buy for this visit; nothing of it is saved.
local unread: { [Player]: boolean } = {}
-- Soldiers with a Robux receipt being paid right now: one at a time, and no buy meanwhile.
local granting: { [Player]: boolean } = {}
local remote: RemoteEvent
local slot: SaveSlot.Slot

function RecordService.priceOf(id: string): number?
	return KitPrices.of(id)
end

local function send(player: Player, record: Record.Record)
	remote:FireClient(
		player,
		Messages.Record.State,
		record.merits,
		table.clone(record.owned),
		record.tabs
	)
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
	local data, answered = slot:load(player)
	local record = Record.decode(data, SAVE.StartMerits)
	if player.Parent and not records[player] then
		if not answered then
			unread[player] = true
			warn(
				`[RecordService] {player.Name}'s record could not be read: this visit is not saved`
			)
		end
		records[player] = record
		send(player, record)
	end
end

-- Saves the record held here, unless the saved one was never read (see `unread`).
local function save(player: Player, record: Record.Record)
	if not unread[player] then
		slot:save(player, Record.encode(record))
	end
end

local function buy(player: Player, id: unknown)
	local record = records[player]
	-- No buy while a receipt is being paid: its save must not land over the tabs.
	if not record or typeof(id) ~= "string" or granting[player] then
		remote:FireClient(player, Messages.Record.Refused, id, "loading")
		return
	end
	local after, ok, reason = Record.buy(record, id, RecordService.priceOf)
	if not ok then
		remote:FireClient(player, Messages.Record.Refused, id, reason)
		return
	end
	records[player] = after
	save(player, after)
	print(`[RecordService] {player.Name} bought {id}: {after.merits} merits left`)
	send(player, after)
end

local function grant(player: Player, purchaseId: string, tabs: number): boolean
	local keep = Config.Tabs.ReceiptsKept
	-- A buy still waiting to be saved goes out first. From here to the end no other save of
	-- this record can start (buys are refused, receipts go one at a time, nothing is left
	-- waiting for the soldier leaving to flush), so none can land over the tabs.
	slot:write(player)
	local written = slot:update(player, function(old: unknown): any
		if not Record.canUpdate(old) then
			return nil
		end
		local stored = Record.decode(old, SAVE.StartMerits)
		local paid, granted = Record.grantReceipt(stored, purchaseId, tabs, keep)
		if not granted and not Record.hasReceipt(stored, purchaseId) then
			return nil -- a bad id or amount: nothing to write
		end
		return Record.encode(paid)
	end)
	if written == nil then
		return false
	end
	local held = records[player]
	if held then
		local after, granted = Record.grantReceipt(held, purchaseId, tabs, keep)
		if granted then
			records[player] = after
			-- The record held here can be ahead of the saved one (a buy whose save failed):
			-- save it again so the newest write has both.
			save(player, after)
			send(player, after)
		end
	end
	print(`[RecordService] {player.Name} paid {tabs} tabs for receipt {purchaseId}`)
	return true
end

-- Pays a Robux receipt's tabs onto the soldier's record, once (TabsService). The saved
-- record is changed in one step (SaveSlot.update) and only then the one held here. True when
-- the receipt is on the saved record (paid now or on an earlier try); false when it could not
-- be saved, and Roblox will offer the receipt again.
function RecordService.grantReceipt(player: Player, purchaseId: string, tabs: number): boolean
	while granting[player] and player.Parent do
		task.wait(0.1)
	end
	if granting[player] or not RecordService.waitFor(player) then
		return false
	end
	granting[player] = true
	local ok, paid = pcall(grant, player, purchaseId, tabs)
	granting[player] = nil
	if not ok then
		warn(`[RecordService] receipt {purchaseId} failed: {paid}`)
		return false
	end
	return paid
end

function RecordService.init()
	remote = Remotes.get("Record")
	slot = SaveSlot.new(SAVE.RecordStore, Record.KEY_PREFIX)
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
		unread[player] = nil
	end)
end

return RecordService
