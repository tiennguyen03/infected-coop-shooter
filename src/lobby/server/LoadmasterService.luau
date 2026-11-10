--!strict
-- The Loadmaster's book (docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): each
-- soldier signs for a Loadout at his desk (LoadmasterUI, the Loadout remote) and it rides
-- the Lantern into the match as teleport data (LaunchService, Rules/Handoff). The server
-- checks every request with the same rules and catalog the match uses (Rules/Loadout,
-- ArmsRoom). Prototype: everything in the catalog may be signed for; what a soldier owns
-- (merits, the record) waits for the save service (F9).
--
-- Kept between visits (owner, 2026-11-10): the signed Loadout is saved in a DataStore keyed by
-- UserId (Rules/LoadoutSave, versioned) and loaded when the soldier joins, so it rides the
-- Lantern even if they never stop at the desk, and the Loadout screen opens on it. Writes
-- are spaced (Config.Lobby.Save.MinWriteGap; the newest pick wins) and flushed on leave and
-- shutdown. Every DataStore call is guarded: a failure, or Studio without API access, only
-- means the default Loadout. A stand-in for F9's save service, which should take this over.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local LoadoutSave = require(ReplicatedStorage.Shared.Rules.LoadoutSave)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LoadmasterService = {}

local SAVE = Config.Lobby.Save

local signed: { [Player]: Loadout.Loadout } = {}
local lastWrite: { [Player]: number } = {} -- os.clock of the last save started
local waiting: { [Player]: boolean } = {} -- a save is scheduled for the newest pick
local remote: RemoteEvent
local store: DataStore? = nil
local warned = false

local function keyFor(userId: number): string
	return `u_{userId}`
end

local function isValid(entry: unknown): boolean
	return (Loadout.validate(entry, ArmsRoom.catalog()))
end

-- Runs a DataStore call with retries; nil when it never succeeds (logged once per server).
local function attempt<T>(what: string, call: () -> T): T?
	if not store then
		return nil
	end
	local lastError = ""
	for try = 0, SAVE.Retries do
		local ok, result = pcall(call)
		if ok then
			return result
		end
		lastError = tostring(result)
		-- Studio without "Enable Studio Access to API Services": no call will work, so stop
		-- trying for this session instead of filling the log.
		if string.find(lastError, "Studio access", 1, true) then
			store = nil
			break
		end
		if try < SAVE.Retries then
			task.wait(SAVE.RetryDelay)
		end
	end
	if not warned then
		warned = true
		warn(`[LoadmasterService] {what} failed, Loadouts fall back to the default: {lastError}`)
	end
	return nil
end

local function write(player: Player)
	local loadout = signed[player]
	if not loadout or not store then
		return
	end
	local dataStore = store :: DataStore
	lastWrite[player] = os.clock()
	local saved = LoadoutSave.encode(loadout)
	local userId = player.UserId
	attempt("save", function()
		dataStore:SetAsync(keyFor(userId), saved, { userId })
		return true
	end)
end

-- Saves the newest pick, no more often than MinWriteGap per soldier.
local function queueWrite(player: Player)
	if waiting[player] then
		return -- the scheduled write will take the newest pick
	end
	local wait = (lastWrite[player] or -math.huge) + SAVE.MinWriteGap - os.clock()
	if wait <= 0 then
		task.spawn(write, player)
		return
	end
	waiting[player] = true
	task.delay(wait, function()
		waiting[player] = nil
		if player.Parent then
			write(player)
		end
	end)
end

local function load(player: Player)
	if not store then
		return
	end
	local dataStore = store :: DataStore
	local data = attempt("load", function()
		return dataStore:GetAsync(keyFor(player.UserId))
	end)
	local loadout = LoadoutSave.decode(data, isValid)
	-- A pick signed while the load was in flight is newer: keep it.
	if loadout and player.Parent and not signed[player] then
		signed[player] = loadout
		remote:FireClient(player, Messages.Loadout.Signed, loadout)
	end
end

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
	remote = Remotes.get("Loadout")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SAVE.Store)
	end)
	if ok then
		store = result
	else
		warn(`[LoadmasterService] no DataStore, Loadouts are not kept: {result}`)
	end

	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, requested: unknown)
		if kind ~= Messages.Loadout.Request then
			return
		end
		local valid, reason = Loadout.validate(requested, ArmsRoom.catalog())
		if valid then
			local source = requested :: Loadout.Loadout
			signed[player] = {
				primary = source.primary,
				secondary = source.secondary,
				grenade = source.grenade,
				callIns = table.clone(source.callIns),
			}
			queueWrite(player)
		end
		remote:FireClient(player, Messages.Loadout.Result, valid, reason)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		if waiting[player] then
			waiting[player] = nil
			write(player) -- the scheduled write would find the soldier gone
		end
		signed[player] = nil
		lastWrite[player] = nil
	end)
	game:BindToClose(function()
		for player in waiting do
			write(player)
		end
	end)
end

return LoadmasterService
