--!strict
-- Merits for a mission (owner 2026-11-10; docs/OWNER.md, docs/LOBBY_MATCH_HANDOFF.md > Merits):
-- when a mission ends, every real player in the server, dead or alive, is paid for its
-- outcome (Rules/Economy.missionMerits, Config.Merits; never per kill, bots earn nothing).
-- The pay goes onto the record the lobby reads (DataStore Config.Lobby.Save.RecordStore, key
-- Rules/Record.key, the versioned Rules/Record shape) with UpdateAsync: the stored record is
-- read, credited and written back in one step, never overwritten blind. A player is in the
-- lobby or in a match, never both, so the two servers never write the same record at once.
-- RunManager is the only caller: `pay` at run end, `settle` before the trip home.
--
-- The amount is shown on the results screen through the player attribute MeritsEarned
-- (-1 when the save failed), and the wallet under it through MeritsHeld and TabsHeld: the
-- record as it was saved, or as it was read when nothing was paid. A failed save, or Studio without API access, is logged and the
-- run end carries on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Rules.Economy)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Lifecycle = require(script.Parent.Lifecycle)

local MeritService = {}

local PAY = Config.Merits
local SAVE = Config.Lobby.Save

local store: DataStore? = nil
local storeTried = false
local warned = false
local pending = 0 -- saves still in flight

local function recordStore(): DataStore?
	if not storeTried then
		storeTried = true
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(SAVE.RecordStore)
		end)
		if ok then
			store = result
		else
			warn(`[MeritService] no DataStore {SAVE.RecordStore}, merits are not kept: {result}`)
		end
	end
	return store
end

-- The record of `userId` as it is saved (yields), for the wallet on the results screen when
-- nothing was paid; nil when it cannot be read. One try: it is only shown.
local function held(userId: number): Record.Record?
	local data = recordStore()
	if not data then
		return nil
	end
	local ok, saved = pcall(function()
		return data:GetAsync(Record.key(userId))
	end)
	if not ok or not Record.canUpdate(saved) then
		return nil
	end
	return Record.decode(saved, SAVE.StartMerits)
end

-- The wallet the results screen shows (RunEndUI): what the record holds now.
local function publish(player: Player, record: Record.Record)
	if player.Parent then
		player:SetAttribute(Attributes.MeritsHeld, record.merits)
		player:SetAttribute(Attributes.TabsHeld, record.tabs)
	end
end

-- Adds `amount` merits to the saved record of `userId` (yields). The record once it is
-- saved; nil when the store is unavailable, every try failed, or the save is one this code
-- cannot read (left untouched).
local function credit(userId: number, amount: number): Record.Record?
	local lastError = "the saved record is not one this server can read"
	for try = 0, PAY.Retries do
		local data = recordStore()
		if not data then
			lastError = "no DataStore"
			break
		end
		local ok, result = pcall(function()
			return data:UpdateAsync(Record.key(userId), function(old: unknown): ...any
				if not Record.canUpdate(old) then
					return nil -- cancels the update
				end
				local record = Record.earn(Record.decode(old, SAVE.StartMerits), amount)
				return Record.encode(record), { userId }
			end)
		end)
		if ok then
			if result ~= nil then
				return Record.decode(result, SAVE.StartMerits)
			end
			break
		end
		lastError = tostring(result)
		if string.find(lastError, "Studio access", 1, true) then
			store = nil -- no call will work this session
			break
		end
		if try < PAY.Retries then
			task.wait(PAY.RetryDelay)
		end
	end
	if not warned then
		warned = true
		warn(`[MeritService] merits not saved (logged once): {lastError}`)
	end
	return nil
end

-- Pays every player here for the mission that just ended. Does not yield: the amount is on
-- each player's MeritsEarned attribute at once and the saves run on their own.
function MeritService.pay(outcome: string, secondaries: number)
	local amount = Economy.missionMerits(outcome, secondaries, PAY)
	local players = Players:GetPlayers()
	print(`[MeritService] {outcome}: {amount} merits each to {#players} player(s)`)
	for _, player in players do
		player:SetAttribute(Attributes.MeritsEarned, amount)
		local userId = player.UserId
		if amount <= 0 then
			-- Nothing to save: the record is only read, for the wallet on the results screen.
			task.spawn(function()
				local ok, record = pcall(held, userId)
				if ok and record then
					publish(player, record)
				end
			end)
			continue
		end
		pending += 1
		task.spawn(function()
			local ok, saved = pcall(credit, userId, amount)
			pending -= 1
			if ok and saved then
				publish(player, saved)
				return
			end
			if not ok then
				warn(`[MeritService] paying {userId} failed: {saved}`)
			end
			if player.Parent then
				player:SetAttribute(Attributes.MeritsEarned, -1)
			end
		end)
	end
end

-- Yields until every save in flight is done, Config.Merits.SettleSeconds at most, so the
-- lobby reads the paid record when the squad lands.
function MeritService.settle()
	local started = os.clock()
	while pending > 0 and os.clock() - started < PAY.SettleSeconds do
		task.wait(0.1)
	end
end

function MeritService.init()
	Lifecycle.register("MeritService", {
		onPlayerReset = function(player: Player)
			player:SetAttribute(Attributes.MeritsEarned, nil)
			player:SetAttribute(Attributes.MeritsHeld, nil)
			player:SetAttribute(Attributes.TabsHeld, nil)
		end,
	})
	game:BindToClose(MeritService.settle)
end

return MeritService
