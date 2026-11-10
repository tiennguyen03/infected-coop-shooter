--!strict
-- A soldier's record (docs/LORE.md > The Fallow: "the kit signed to their name"): the merits
-- they hold and the guns bought onto it at the Quartermaster's rack (RecordService,
-- ArmsRackUI). Pure, unit-tested with Lune (tests/Record.spec.luau). Prices come from each
-- gun's own Config row through `priceOf` (0 = issued free and always on the record, nil = not
-- for sale). The saved form carries a version from day one; a missing, junk or other-version
-- save reads as a new record with the starting merits.

local Record = {}

Record.VERSION = 1

export type Record = {
	merits: number,
	owned: { string }, -- bought guns (free ones are never listed)
}

export type PriceOf = (id: string) -> number?

export type Saved = {
	version: number,
	merits: number,
	owned: { string },
}

-- Only the guns are bought; grenades and call-ins come with the job.
export type Loadout = { primary: string, secondary: string }

function Record.new(startMerits: number): Record
	return { merits = startMerits, owned = {} }
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
	return { merits = record.merits - price, owned = owned }, true, nil
end

-- Whether every gun in `loadout` is on the record: (true) or (false, "not on record").
function Record.allows(record: Record, loadout: Loadout, priceOf: PriceOf): (boolean, string?)
	for _, id in { loadout.primary, loadout.secondary } do
		if not Record.owns(record, id, priceOf) then
			return false, "not on record"
		end
	end
	return true, nil
end

function Record.encode(record: Record): Saved
	return { version = Record.VERSION, merits = record.merits, owned = table.clone(record.owned) }
end

function Record.decode(data: unknown, startMerits: number): Record
	if typeof(data) ~= "table" then
		return Record.new(startMerits)
	end
	local saved = data :: any
	if saved.version ~= Record.VERSION or typeof(saved.merits) ~= "number" then
		return Record.new(startMerits)
	end
	local owned: { string } = {}
	if typeof(saved.owned) == "table" then
		for _, id in saved.owned do
			if typeof(id) == "string" and not table.find(owned, id) then
				table.insert(owned, id)
			end
		end
	end
	return { merits = math.max(0, math.floor(saved.merits)), owned = owned }
end

return Record
