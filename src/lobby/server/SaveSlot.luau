--!strict
-- One saved value per soldier in a DataStore (the lobby's stand-in for the F9 save service,
-- docs/ARCHITECTURE.md; the save rules: docs/SAVES.md): LoadmasterService keeps the signed
-- Loadout in one, RecordService the record (merits, kit bought) in another. Keys are
-- "<prefix><UserId>". Each slot has a Rules/SaveSchema schema: what is read is migrated to the
-- current shape by the caller, and every write goes through UpdateAsync and is checked against
-- what is stored at that moment, so a save written by newer code (a rollout) or one this code
-- cannot read is never written over.
--
-- Read-only visits: when the load fails (a DataStore error, or Studio without "Enable Studio
-- Access to API Services") or the stored save is newer or junk, the slot writes nothing for
-- that soldier this visit and sets their SaveOffline attribute (the lobby's notice,
-- WalletUI). Writes are spaced (Config.Lobby.Save.MinWriteGap, the newest value wins) and
-- flushed when the soldier leaves and on shutdown. Every call is guarded and retried.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local SaveSchema = require(ReplicatedStorage.Shared.Rules.SaveSchema)

local SaveSlot = {}
SaveSlot.__index = SaveSlot

local SAVE = Config.Lobby.Save

export type Slot = typeof(setmetatable(
	{} :: {
		name: string,
		prefix: string,
		schema: SaveSchema.Schema,
		store: DataStore?,
		warned: boolean,
		pending: { [Player]: any }, -- the newest value not yet written
		lastWrite: { [Player]: number },
		scheduled: { [Player]: boolean },
		readOnly: { [Player]: boolean }, -- nothing is written for them this visit
	},
	SaveSlot
))

function SaveSlot.new(storeName: string, prefix: string, schema: SaveSchema.Schema): Slot
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if not ok then
		warn(`[SaveSlot] no DataStore {storeName}, nothing is kept: {store}`)
	end
	local slot = setmetatable({
		name = storeName,
		prefix = prefix,
		schema = schema,
		store = if ok then store else nil,
		warned = false,
		pending = {},
		lastWrite = {},
		scheduled = {},
		readOnly = {},
	}, SaveSlot)
	Players.PlayerRemoving:Connect(function(player: Player)
		slot.scheduled[player] = nil
		slot:write(player) -- anything still pending
		slot.lastWrite[player] = nil
		slot.readOnly[player] = nil
	end)
	game:BindToClose(function()
		for player in slot.pending do
			slot:write(player)
		end
	end)
	return slot
end

-- Runs a DataStore call with retries; nil when it never succeeds.
function SaveSlot.attempt<T>(self: Slot, what: string, call: (store: DataStore) -> T): T?
	local lastError = ""
	for try = 0, SAVE.Retries do
		local store = self.store
		if not store then
			return nil
		end
		local ok, result = pcall(call, store)
		if ok then
			return result
		end
		lastError = tostring(result)
		if string.find(lastError, "Studio access", 1, true) then
			self.store = nil -- no call will work this session
			break
		end
		if try < SAVE.Retries then
			task.wait(SAVE.RetryDelay)
		end
	end
	if not self.warned then
		self.warned = true
		warn(`[SaveSlot] {self.name} {what} failed, not kept this session: {lastError}`)
	end
	return nil
end

-- Makes this visit read-only for `player`: nothing is written, and the notice shows.
function SaveSlot.goReadOnly(self: Slot, player: Player, why: string)
	if self.readOnly[player] then
		return
	end
	self.readOnly[player] = true
	self.pending[player] = nil
	if player.Parent then
		player:SetAttribute(Attributes.SaveOffline, true)
	end
	warn(`[SaveSlot] {self.name}: {player.Name}'s save {why}; nothing is saved this visit`)
end

-- Read-only for this slot, or for any other slot of the same soldier (the SaveOffline
-- attribute, set only by the server): one unreadable save stops every write of the visit.
function SaveSlot.isReadOnly(self: Slot, player: Player): boolean
	return self.readOnly[player] == true or player:GetAttribute(Attributes.SaveOffline) == true
end

-- The saved value as stored (yields; the caller migrates it), or nil when there is none or
-- the store is unavailable. The second value says whether the store answered: false means the
-- read failed, so a nil is "unknown", not "no save". A failed read, or a stored save that is
-- newer than this code or junk, makes the visit read-only.
function SaveSlot.load(self: Slot, player: Player): (unknown, boolean)
	local key = self.prefix .. player.UserId
	local answered = false
	local value = self:attempt("load", function(store: DataStore): unknown
		local stored = store:GetAsync(key)
		answered = true
		return stored
	end)
	if not answered then
		self:goReadOnly(player, "could not be read")
	else
		local status = SaveSchema.read(self.schema, value)
		if status == "newer" then
			self:goReadOnly(player, "is from a newer version of the game")
		elseif status == "junk" then
			self:goReadOnly(player, "is not one this version can read")
		end
	end
	return value, answered
end

-- The UpdateAsync step: `transform` on what is stored, refused when that may not be written
-- over (a newer or junk save, even one that appeared after the load).
local function guarded(self: Slot, player: Player, transform: (old: unknown) -> any)
	local userId = player.UserId
	return function(old: unknown): ...any
		if not SaveSchema.writable(self.schema, old) then
			return nil
		end
		local value = transform(old)
		if value == nil then
			return nil
		end
		return value, { userId }
	end
end

function SaveSlot.write(self: Slot, player: Player)
	local value = self.pending[player]
	if value == nil then
		return
	end
	self.pending[player] = nil
	if self:isReadOnly(player) then
		return
	end
	self.lastWrite[player] = os.clock()
	local key = self.prefix .. player.UserId
	local step = guarded(self, player, function(old: unknown): any
		-- The whole value is replaced (only this server writes it), keeping unknown fields.
		return SaveSchema.over(self.schema, old, value)
	end)
	self:attempt("save", function(store: DataStore)
		store:UpdateAsync(key, step)
		return true
	end)
end

-- Changes the saved value in one step (UpdateAsync, yields): `transform` gets what is stored
-- and returns what to store, or nil to leave it alone. Returns the value written, or nil when
-- nothing was written (a read-only visit, the store is unavailable, every try failed, the
-- stored save may not be written over, or `transform` said nil). For changes that must not be
-- lost or doubled (a buy, a Robux receipt: RecordService); `save` stays the path for values
-- only this server writes (the Loadout).
function SaveSlot.update(self: Slot, player: Player, transform: (old: unknown) -> any): any
	if self:isReadOnly(player) then
		return nil
	end
	local key = self.prefix .. player.UserId
	local step = guarded(self, player, transform)
	return self:attempt("update", function(store: DataStore): any
		return store:UpdateAsync(key, step)
	end)
end

-- Saves `value` for `player`, no more often than MinWriteGap; a later value replaces one
-- still waiting. Nothing is saved on a read-only visit.
function SaveSlot.save(self: Slot, player: Player, value: any)
	if self:isReadOnly(player) then
		return
	end
	self.pending[player] = value
	if self.scheduled[player] then
		return
	end
	local wait = (self.lastWrite[player] or -math.huge) + SAVE.MinWriteGap - os.clock()
	if wait <= 0 then
		task.spawn(self.write, self, player)
		return
	end
	self.scheduled[player] = true
	task.delay(wait, function()
		if self.scheduled[player] then
			self.scheduled[player] = nil
			if player.Parent then
				self:write(player)
			end
		end
	end)
end

return SaveSlot
