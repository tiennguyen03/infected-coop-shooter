--!strict
-- A soldier's record (docs/LORE.md > The Fallow: "the kit signed to their name"): the merits
-- they hold and the kit bought onto it: guns and grenades at the Quartermaster's rack,
-- call-ins at the desk that issues them (RecordService, ArmsRackUI, DeskShop). Pure,
-- unit-tested with Lune (tests/Record.spec.luau). Prices come from each item's own Config row
-- through `priceOf` (KitPrices: 0 = issued free and always on the record, nil = not for sale).
--
-- Two currencies (owner, 2026-11-10; docs/OWNER.md): **merits** are earned on missions (the
-- match pays them, MeritService) and buy kit; **tabs** are bought with Robux or granted by
-- events (TabsService) and will buy cosmetics and conveniences, never power. The record also
-- remembers the last Robux receipts it was paid for, so one purchase never pays twice.
--
-- The saved form carries a version and is read through Rules/SaveSchema (docs/SAVES.md): 0 =
-- unversioned, 1 = merits and kit, 2 adds tabs and receipts; any older save is migrated on
-- read. A missing, junk or newer-version save reads as a new record with the starting merits;
-- a server that updates a save in place checks `canUpdate` first so it never writes over one
-- it cannot read, and passes the stored value to `encode` so fields it does not know are kept.

local SaveSchema = require("./SaveSchema")

local Record = {}

Record.VERSION = SaveSchema.Record.version
-- The record's DataStore key is "r_<UserId>", the same in the lobby and the match.
Record.KEY_PREFIX = "r_"

export type Record = {
	merits: number,
	owned: { string }, -- bought kit ids: guns, grenades, call-ins (free ones are never listed)
	tabs: number,
	receipts: { string }, -- Robux PurchaseIds already paid out, oldest first
	wins: { [string]: number }, -- missions won per city district ("MILE 14" = 3; loop sprint 4)
}

export type PriceOf = (id: string) -> number?

export type Saved = {
	version: number,
	merits: number,
	owned: { string },
	tabs: number,
	receipts: { string },
	wins: { [string]: number },
}

export type Loadout = { primary: string, secondary: string, grenade: string, callIns: { string } }

function Record.key(userId: number): string
	return Record.KEY_PREFIX .. tostring(userId)
end

function Record.new(startMerits: number): Record
	return { merits = startMerits, owned = {}, tabs = 0, receipts = {}, wins = {} }
end

-- A whole number above zero (not NaN, not infinite): the only amounts tabs move in.
local function wholeAmount(amount: number): boolean
	return amount == amount and amount > 0 and amount < math.huge and amount == math.floor(amount)
end

-- A stored balance, cleaned: never negative, never a fraction, 0 when it is not a number.
local function balance(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function with(record: Record, changes: { [string]: any }): Record
	local copy: any = {
		merits = record.merits,
		owned = record.owned,
		tabs = record.tabs,
		receipts = record.receipts,
		wins = record.wins,
	}
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

function Record.owns(record: Record, id: string, priceOf: PriceOf): boolean
	local price = priceOf(id)
	if price ~= nil and price <= 0 then
		return true
	end
	return table.find(record.owned, id) ~= nil
end

-- (the new record, true) or (the record unchanged, false, "owned" | "unknown" | "short").
function Record.buy(record: Record, id: string, priceOf: PriceOf): (Record, boolean, string?)
	local price = priceOf(id)
	if price == nil then
		return record, false, "unknown"
	end
	if Record.owns(record, id, priceOf) then
		return record, false, "owned"
	end
	if record.merits < price then
		return record, false, "short"
	end
	local owned = table.clone(record.owned)
	table.insert(owned, id)
	return with(record, { merits = record.merits - price, owned = owned }), true, nil
end

-- Merits earned on a mission (Rules/Economy.missionMerits): whole, never a loss.
function Record.earn(record: Record, amount: number): Record
	return with(record, { merits = record.merits + balance(amount) })
end

-- One more mission won in `district` (MeritService, in the same UpdateAsync as the pay).
function Record.win(record: Record, district: string): Record
	local wins = table.clone(record.wins)
	wins[district] = (wins[district] or 0) + 1
	return with(record, { wins = wins })
end

-- (the new record, true) or (the record unchanged, false, "invalid").
function Record.grantTabs(record: Record, amount: number): (Record, boolean, string?)
	if not wholeAmount(amount) then
		return record, false, "invalid"
	end
	return with(record, { tabs = record.tabs + amount }), true, nil
end

-- (the new record, true) or (the record unchanged, false, "invalid" | "short").
function Record.spendTabs(record: Record, amount: number): (Record, boolean, string?)
	if not wholeAmount(amount) then
		return record, false, "invalid"
	end
	if record.tabs < amount then
		return record, false, "short"
	end
	return with(record, { tabs = record.tabs - amount }), true, nil
end

function Record.hasReceipt(record: Record, purchaseId: string): boolean
	return table.find(record.receipts, purchaseId) ~= nil
end

-- Pays a Robux receipt's tabs once: (the new record, true), or (the record unchanged, false)
-- when this receipt was already paid or the id or amount is bad. Only the newest `keep`
-- receipts are remembered.
function Record.grantReceipt(
	record: Record,
	purchaseId: string,
	tabs: number,
	keep: number
): (Record, boolean)
	if purchaseId == "" or Record.hasReceipt(record, purchaseId) then
		return record, false
	end
	local paid, ok = Record.grantTabs(record, tabs)
	if not ok then
		return record, false
	end
	local receipts = table.clone(record.receipts)
	table.insert(receipts, purchaseId)
	while #receipts > math.max(1, keep) do
		table.remove(receipts, 1)
	end
	return with(paid, { receipts = receipts }), true
end

-- Whether everything in `loadout` (both guns, the grenade, every call-in) is on the record:
-- (true) or (false, "not on record").
function Record.allows(record: Record, loadout: Loadout, priceOf: PriceOf): (boolean, string?)
	local ids = { loadout.primary, loadout.secondary, loadout.grenade }
	for _, id in loadout.callIns do
		table.insert(ids, id)
	end
	for _, id in ids do
		if not Record.owns(record, id, priceOf) then
			return false, "not on record"
		end
	end
	return true, nil
end

-- The value to save. Pass what is stored (`stored`, the UpdateAsync `old`) so every field this
-- code does not know is kept; without it (or when it may not be written over) only the
-- record's own fields are written.
function Record.encode(record: Record, stored: unknown?): Saved
	local fields = {
		version = Record.VERSION,
		merits = record.merits,
		owned = table.clone(record.owned),
		tabs = record.tabs,
		receipts = table.clone(record.receipts),
		wins = table.clone(record.wins),
	}
	local over = if stored ~= nil then SaveSchema.over(SaveSchema.Record, stored, fields) else nil
	return (over or fields) :: any
end

-- The stored record migrated to the current shape, or nil when it is none this code reads.
local function readable(data: unknown): SaveSchema.Save?
	local status, save = SaveSchema.read(SaveSchema.Record, data)
	return if status == "ok" then save else nil
end

-- Whether a server may update this stored value in place (UpdateAsync): no save yet, or one
-- this code reads (older ones are migrated). Junk or a newer version is left alone.
function Record.canUpdate(data: unknown): boolean
	return SaveSchema.writable(SaveSchema.Record, data)
end

local function strings(list: unknown): { string }
	local clean: { string } = {}
	if typeof(list) == "table" then
		for _, value in list :: { unknown } do
			if typeof(value) == "string" and value ~= "" and not table.find(clean, value) then
				table.insert(clean, value)
			end
		end
	end
	return clean
end

-- Win counts by district name, cleaned: whole numbers above zero only.
local function counts(map: unknown): { [string]: number }
	local clean: { [string]: number } = {}
	if typeof(map) == "table" then
		for key, value in map :: { [unknown]: unknown } do
			if
				typeof(key) == "string"
				and typeof(value) == "number"
				and value == value
				and value >= 1
			then
				clean[key] = math.floor(value)
			end
		end
	end
	return clean
end

function Record.decode(data: unknown, startMerits: number): Record
	local saved: any = readable(data)
	if not saved then
		return Record.new(startMerits)
	end
	return {
		merits = balance(saved.merits),
		owned = strings(saved.owned),
		tabs = balance(saved.tabs),
		receipts = strings(saved.receipts),
		wins = counts(saved.wins),
	}
end

-- A buy applied to the record as it is stored (the lobby's UpdateAsync transform), so merits
-- the match paid since the lobby read the record are kept: (the value to store, nil), or
-- (nil, "unreadable" | "owned" | "unknown" | "short") and nothing is written. A save this code
-- cannot read (junk, a newer version) is never written over.
function Record.buyStored(
	stored: unknown,
	id: string,
	priceOf: PriceOf,
	startMerits: number
): (Saved?, string?)
	if not Record.canUpdate(stored) then
		return nil, "unreadable"
	end
	local after, ok, reason = Record.buy(Record.decode(stored, startMerits), id, priceOf)
	if not ok then
		return nil, reason
	end
	return Record.encode(after, stored), nil
end

return Record
