--!strict
-- The Containment Board's data, as the lobby reads it (docs/PROGRESSION.md > The Containment
-- Board; loop sprint 3): the city war's shared board (Rules/War), written by every match at a
-- run's end (WarService) and read here with one GetAsync, decayed to now. `layout` is the
-- board's columns with their start values and never yields (build the panel with it);
-- `read` yields on the DataStore and keeps the last good read if a read fails (or Studio has
-- no API access). Each read is also published for the clients' Mission Board cards
-- (Attributes.WarBoard on workspace, JSON of the districts).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local War = require(ReplicatedStorage.Shared.Rules.War)

local ContainmentBoard = {}

export type District = {
	name: string,
	percent: number,
	open: boolean,
	secured: boolean,
	opensWith: string?,
}

local last: War.Board? = nil
local warned = false

local function settings(): War.Settings
	local s = table.clone(Config.War) :: any
	s.Districts = Config.Containment.Districts
	return s
end

local function toDistricts(board: War.Board): { District }
	local out: { District } = {}
	for _, shown in War.shown(board, os.time(), settings()) do
		table.insert(out, {
			name = shown.name,
			percent = shown.percent,
			open = shown.open,
			secured = shown.secured,
			opensWith = shown.opensWith,
		})
	end
	return out
end

-- Every district at its start value, in board order. Never yields.
function ContainmentBoard.layout(): { District }
	return toDistricts(War.merge(nil, {}, os.time(), settings()))
end

-- Every district in board order, as the shared board holds it now. Yields on the DataStore;
-- callers run it off the main thread.
function ContainmentBoard.read(): { District }
	local ok, raw = pcall(function()
		local cfg = Config.War
		local store =
			War.storeFor(cfg.StorePrefix, War.season(os.time(), cfg.SeasonStart, cfg.SeasonDays))
		return DataStoreService:GetDataStore(store):GetAsync(cfg.Key)
	end)
	if ok then
		last = War.merge(raw, {}, os.time(), settings())
	elseif not warned then
		warned = true
		warn(`[ContainmentBoard] the war board was not read (logged once): {raw}`)
	end
	local districts = toDistricts(last or War.merge(nil, {}, os.time(), settings()))
	workspace:SetAttribute(Attributes.WarBoard, HttpService:JSONEncode(districts))
	return districts
end

return ContainmentBoard
