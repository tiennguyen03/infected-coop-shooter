--!strict
-- The Carrier's counts from the match (docs/sprints/CARRIER_V2.md > Easter eggs 3 and 6, owner
-- 2026-11-18): every call-in a player fires this run, and one MISSIONS HOME for the mission when
-- the squad extracts. Counted in memory and added to the one shared key (DataStore
-- Config.Lobby.Tallies.Store, key .Key) once, at run end, with UpdateAsync (Rules/Tally.merge),
-- so many servers ending together each add their share and none writes over another. The lobby
-- reads the same key (TallyBoards). A failed save, or Studio without API access, is warned once
-- and the counts are dropped: these are paint on a wall, not a record.
-- Callers: CallInService (`callIn`), RunManager (`flush` at run end).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tally = require(ReplicatedStorage.Shared.Rules.Tally)
local Lifecycle = require(script.Parent.Lifecycle)

local TallyService = {}

local CFG = Config.Lobby.Tallies

local counts: Tally.Counts = {}
local store: GlobalDataStore? = nil
local storeTried = false
local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(`[TallyService] counts not saved (logged once): {message}`)
	end
end

local function tallyStore(): GlobalDataStore?
	if not storeTried then
		storeTried = true
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(CFG.Store)
		end)
		if ok then
			store = result
		else
			warnOnce(tostring(result))
		end
	end
	return store
end

local function save(add: Tally.Counts)
	for try = 0, CFG.Retries do
		local data = tallyStore()
		if not data then
			return
		end
		local ok, err = pcall(function()
			data:UpdateAsync(CFG.Key, function(old: unknown): ...any
				return Tally.merge(old, add)
			end)
		end)
		if ok then
			return
		end
		local message = tostring(err)
		if string.find(message, "Studio access", 1, true) then
			store = nil -- no call will work this session
			warnOnce(message)
			return
		end
		if try == CFG.Retries then
			warnOnce(message)
		else
			task.wait(CFG.RetryDelay)
		end
	end
end

-- One use of call-in `id` (a CallInDefinitions id) by a player.
function TallyService.callIn(id: string)
	local key = Tally.key("callin", id)
	counts[key] = (counts[key] or 0) + 1
end

-- Run end: adds this run's counts (and the mission home, when `extracted`) to the shared key.
-- Does not yield; the save runs on its own.
function TallyService.flush(extracted: boolean, missionId: string)
	if extracted then
		local key = Tally.key("mission", missionId)
		counts[key] = (counts[key] or 0) + 1
	end
	local add = counts
	counts = {}
	if not CFG.Enabled or next(add) == nil then
		return
	end
	task.spawn(save, add)
end

function TallyService.init()
	Lifecycle.register("TallyService", {
		onRunStart = function()
			counts = {}
		end,
	})
	game:BindToClose(function()
		-- A server shut down mid-run still adds the call-ins already fired.
		if CFG.Enabled and next(counts) ~= nil then
			local add = counts
			counts = {}
			save(add)
		end
	end)
end

return TallyService
