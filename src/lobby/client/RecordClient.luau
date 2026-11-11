--!strict
-- This soldier's record on the client (RecordService sends it on the `Record` remote): the
-- merits held and the kit bought, for the Quartermaster's rack (ArmsRackUI: price, BUY), the
-- desks that sell call-ins (DeskShop) and the Loadmaster's Loadout (LoadmasterUI: kit not on
-- the record is locked). Display only;
-- the server decides every buy and every signature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)

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

-- On the record: bought or issued free.
function RecordClient.owns(id: string): boolean
	return record ~= nil and Record.owns(record, id, RecordClient.priceOf)
end

function RecordClient.buy(id: string)
	Remotes.get("Record"):FireServer(Messages.Record.Buy, id)
end

function RecordClient.init()
	Remotes.get("Record").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == Messages.Record.State and typeof(a) == "number" and typeof(b) == "table" then
			record = { merits = a, owned = b }
			changed:Fire()
		elseif kind == Messages.Record.Refused then
			refused:Fire(a, b)
		end
	end)
end

return RecordClient
