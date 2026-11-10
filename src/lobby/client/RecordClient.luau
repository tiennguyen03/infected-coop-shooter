--!strict
-- This soldier's record on the client (RecordService sends it on the `Record` remote): the
-- merits held and the guns bought, for the Quartermaster's rack (ArmsRackUI: price, BUY) and
-- the Loadmaster's Loadout (LoadmasterUI: guns not on the record are locked). Display only;
-- the server decides every buy and every signature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local RecordClient = {}

local record: Record.Record? = nil -- nil until the server has sent it
local changed = Instance.new("BindableEvent")
local refused = Instance.new("BindableEvent")

local guns: { [string]: boolean } = {}
do
	local catalog = ArmsRoom.catalog()
	for _, list in { catalog.primaries, catalog.secondaries } do
		for _, id in list do
			guns[id] = true
		end
	end
end

-- Fires () when the record arrives or changes.
RecordClient.Changed = changed.Event
-- Fires (gunId, reason) when the server refuses a buy.
RecordClient.Refused = refused.Event

-- The gun's price, or nil when it is not for sale (grenades, anything off the catalog).
function RecordClient.priceOf(id: string): number?
	return if guns[id] then WeaponDefinitions.get(id).Price else nil
end

function RecordClient.loaded(): boolean
	return record ~= nil
end

function RecordClient.merits(): number
	return if record then record.merits else 0
end

-- On the record: bought, issued free, or not a gun at all (grenades are never locked).
function RecordClient.owns(id: string): boolean
	if not guns[id] then
		return true
	end
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
