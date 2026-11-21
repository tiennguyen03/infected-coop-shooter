--!strict
-- This soldier's record on the client (RecordService sends it on the `Record` remote): the
-- merits and tabs held and the kit bought, for the Quartermaster's rack (ArmsRackUI: price,
-- BUY), the desks that sell call-ins (DeskShop) and the Loadmaster's Loadout (LoadmasterUI: kit not on
-- the record is locked). Display only;
-- the server decides every buy and every signature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local DistrictUnlock = require(ReplicatedStorage.Shared.Rules.DistrictUnlock)

local RecordClient = {}

local record: Record.Record? = nil -- nil until the server has sent it
local changed = Instance.new("BindableEvent")
local refused = Instance.new("BindableEvent")

-- Fires () when the record arrives or changes.
RecordClient.Changed = changed.Event
-- Fires (gunId, reason) when the server refuses a buy.
RecordClient.Refused = refused.Event

-- The item's price (gun, grenade or call-in), or nil when it is not for sale.
function RecordClient.priceOf(id: string): number?
	return KitPrices.of(id)
end

function RecordClient.loaded(): boolean
	return record ~= nil
end

function RecordClient.merits(): number
	return if record then record.merits else 0
end

-- Tabs held (the hard currency; nothing is bought with them yet).
function RecordClient.tabs(): number
	return if record then record.tabs else 0
end

-- The balances as one line for a panel: "1000 MERITS  ·  0 TABS".
function RecordClient.balanceText(): string
	return `{RecordClient.merits()} MERITS  ·  {RecordClient.tabs()} TABS`
end

-- On the record: bought or issued free.
function RecordClient.owns(id: string): boolean
	return record ~= nil and Record.owns(record, id, RecordClient.priceOf)
end

-- Missions won per district (the record's `wins`).
function RecordClient.wins(): { [string]: number }
	return if record then record.wins else {}
end

-- What still has to be won before `id` is on sale ("WIN 3 AT MILE 14 (1/3)"), or nil when it
-- is open (Rules/DistrictUnlock; the server checks the buy again).
function RecordClient.lockText(id: string): string?
	local unlock = KitPrices.unlockOf(id)
	if DistrictUnlock.met(unlock, RecordClient.wins()) then
		return nil
	end
	return DistrictUnlock.text(unlock, RecordClient.wins())
end

function RecordClient.buy(id: string)
	Remotes.get("Record"):FireServer(Messages.Record.Buy, id)
end

function RecordClient.init()
	Remotes.get("Record").OnClientEvent
		:Connect(function(kind: string, a: any, b: any, c: any, d: any)
			if kind == Messages.Record.State and typeof(a) == "number" and typeof(b) == "table" then
				-- Receipts stay on the server.
				record = {
					merits = a,
					owned = b,
					tabs = if typeof(c) == "number" then c else 0,
					receipts = {},
					wins = if typeof(d) == "table" then d else {}, -- shown as locks in the shop (the buy is checked on the server)
				}
				changed:Fire()
			elseif kind == Messages.Record.Refused then
				refused:Fire(a, b)
			end
		end)
end

return RecordClient
