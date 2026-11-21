--!strict
-- The Carrier's painted counts that change (docs/sprints/CARRIER_V2.md > Easter eggs 3, 4, 6):
-- the call-in numbers on the hull over the show floor, the MISSIONS HOME board, the DAYS SINCE
-- ONE GOT ABOARD tiles. CarrierV2 registers each lettering card whose generated row carries a
-- `count` tag (assets/3d/build/carrier_v2.py); this paints it, on start and again every few
-- minutes:
--   callin:<id>   the call-in's row Tally (Config.CallIns, through CallInDefinitions) + stored
--   mission:<id>  Config.Lobby.Tallies.Districts[id] + stored (the match adds one an extraction)
--   days:<n>      tile n (1 = hundreds) of the whole UTC days since Config.Lobby.DaysSince.Start
-- "Stored" is the shared DataStore key the match adds to at run end (server TallyService). It
-- is only read here; without it (Studio without API access) the start values show.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Tally = require(ReplicatedStorage.Shared.Rules.Tally)

local TallyBoards = {}

local CFG = Config.Lobby.Tallies
local DAYS = Config.Lobby.DaysSince
local DAY_TILES = 3

type Card = { tag: string, label: TextLabel }

local cards: { Card } = {}
local stored: Tally.Counts = {}
local store: GlobalDataStore? = nil
local warned = false

local function start(kind: string, id: string): number
	if kind == "callin" then
		local definition = CallInDefinitions.get(id)
		local row = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
		local value = row and row.Tally
		return if typeof(value) == "number" then value else 0
	end
	local value = (CFG.Districts :: { [string]: number })[id]
	return value or 0
end

local function text(tag: string): string?
	local kind, id = Tally.parse(tag)
	if kind == "days" then
		local tile = tonumber(id) or 1
		local digits = Tally.digits(Tally.daysSince(DAYS.Start, os.time()), DAY_TILES)
		return digits[math.clamp(tile, 1, DAY_TILES)]
	end
	if kind == "callin" or kind == "mission" then
		return Tally.format(Tally.shown(start(kind, id), stored, tag))
	end
	return nil
end

local function paint(card: Card)
	local value = text(card.tag)
	if value and card.label.Parent then
		card.label.Text = value
	end
end

local function paintAll(kinds: { [string]: boolean })
	for _, card in cards do
		if kinds[(Tally.parse(card.tag))] then
			paint(card)
		end
	end
end

-- Reads the shared key once (yields). Keeps the last good read on a failure.
local function read()
	if not CFG.Enabled then
		return
	end
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(CFG.Store)
		end)
		if not ok then
			if not warned then
				warned = true
				warn(`[TallyBoards] no DataStore {CFG.Store}, the start values show: {result}`)
			end
			return
		end
		store = result
	end
	local data = store :: GlobalDataStore
	local ok, value = pcall(function()
		return data:GetAsync(CFG.Key)
	end)
	if ok then
		stored = Tally.clean(value)
	elseif not warned then
		warned = true
		warn(`[TallyBoards] counts not read (logged once), the last ones show: {value}`)
	end
end

-- A lettering card whose row carries `tag`: painted now, and again on every refresh.
function TallyBoards.register(tag: string, label: TextLabel)
	local card = { tag = tag, label = label }
	table.insert(cards, card)
	paint(card)
end

function TallyBoards.init()
	if not Config.Lobby.CarrierV2.Enabled then
		return -- the boards are Carrier v2 lettering
	end
	task.spawn(function()
		while true do
			read()
			paintAll({ callin = true, mission = true })
			task.wait(CFG.RefreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(DAYS.RefreshSeconds)
			paintAll({ days = true })
		end
	end)
end

return TallyBoards
