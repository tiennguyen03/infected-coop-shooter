--!strict
-- One saved value per soldier in a DataStore (the lobby's stand-in for the F9 save service,
-- docs/ARCHITECTURE.md): LoadmasterService keeps the signed Loadout in one, RecordService the
-- record (merits, guns bought) in another. Keys are "<prefix><UserId>". Writes are spaced
-- (Config.Lobby.Save.MinWriteGap, the newest value wins) and flushed when the soldier leaves
-- and on shutdown. Every call is guarded and retried: a failure, or Studio without "Enable
-- Studio Access to API Services", stops the slot for the session with one log line, and the
-- caller carries on without saving.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SaveSlot = {}
SaveSlot.__index = SaveSlot

local SAVE = Config.Lobby.Save

export type Slot = typeof(setmetatable(
	{} :: {
		name: string,
		prefix: string,
		store: DataStore?,
		warned: boolean,
		pending: { [Player]: any }, -- the newest value not yet written
		lastWrite: { [Player]: number },
		scheduled: { [Player]: boolean },
	},
	SaveSlot
))

function SaveSlot.new(storeName: string, prefix: string): Slot
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if not ok then
		warn(`[SaveSlot] no DataStore {storeName}, nothing is kept: {store}`)
	end
	local slot = setmetatable({
		name = storeName,
		prefix = prefix,
		store = if ok then store else nil,
		warned = false,
		pending = {},
		lastWrite = {},
		scheduled = {},
	}, SaveSlot)
	Players.PlayerRemoving:Connect(function(player: Player)
		slot.scheduled[player] = nil
		slot:write(player) -- anything still pending
		slot.lastWrite[player] = nil
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

-- The saved value (yields), or nil when there is none or the store is unavailable.
function SaveSlot.load(self: Slot, player: Player): unknown
	local key = self.prefix .. player.UserId
	return self:attempt("load", function(store: DataStore)
		return store:GetAsync(key)
	end)
end

function SaveSlot.write(self: Slot, player: Player)
	local value = self.pending[player]
	if value == nil then
		return
	end
	self.pending[player] = nil
	self.lastWrite[player] = os.clock()
	local key = self.prefix .. player.UserId
	local userId = player.UserId
	self:attempt("save", function(store: DataStore)
		store:SetAsync(key, value, { userId })
		return true
	end)
end

-- Changes the saved value in one step (UpdateAsync, yields): `transform` gets what is stored
-- and returns what to store, or nil to leave it alone. Returns the value written, or nil when
-- nothing was written (the store is unavailable, every try failed, or `transform` said nil).
-- For changes that must not be lost or doubled (a Robux receipt); `save` stays the everyday
-- path.
function SaveSlot.update(self: Slot, player: Player, transform: (old: unknown) -> any): any
	local key = self.prefix .. player.UserId
	local userId = player.UserId
	return self:attempt("update", function(store: DataStore): any
		return store:UpdateAsync(key, function(old: unknown): ...any
			local value = transform(old)
			if value == nil then
				return nil
			end
			return value, { userId }
		end)
	end)
end

-- Saves `value` for `player`, no more often than MinWriteGap; a later value replaces one
-- still waiting.
function SaveSlot.save(self: Slot, player: Player, value: any)
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
