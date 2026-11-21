--!strict
-- Unlocking and fitting attachment options and ammo types (attachment system v2, Nova
-- 2026-11-20; tests/AttachmentUnlock.spec.luau). Pure: the server asks it before every unlock
-- and equip (the lobby's AttachmentService, the Loadmaster's signature through
-- RecordService.allows) and the menu asks it for the states and the "X/Y unlocked" counters.
-- An option is unlocked once with merits and kept for good on the soldier's record, like
-- bought kit (Rules/Record `owned`); a free one (meritCost 0, the issued part) is always
-- owned. Merits only: no tabs, no Robux.

local Record = require("./Record")

local AttachmentUnlock = {}

export type OptionEntry = {
	id: string,
	slot: string,
	compatibleGuns: { string },
	incompatibleWith: { string },
	meritCost: number,
}

export type AmmoEntry = {
	id: string,
	slot: string, -- the ammo slot
	caliberFamily: string,
	compatibleGuns: { string }?, -- set: only these guns of the caliber take it
	incompatibleWith: { string },
	meritCost: number,
}

export type Catalog = {
	options: { [string]: OptionEntry },
	ammo: { [string]: AmmoEntry },
	gunCaliber: (gunId: string) -> string?,
}

export type Config = { [string]: string } -- [slot] = option or ammo id
export type State = "locked" | "owned" | "equipped"

type Entry = { id: string, slot: string, incompatibleWith: { string }, meritCost: number }

local function entryOf(catalog: Catalog, id: string): Entry?
	return (catalog.options[id] :: any) or (catalog.ammo[id] :: any)
end

-- An id's price for Rules/Record: its meritCost, nil when it is neither an option nor ammo.
function AttachmentUnlock.priceOf(catalog: Catalog): Record.PriceOf
	return function(id: string): number?
		local entry = entryOf(catalog, id)
		return entry and entry.meritCost
	end
end

function AttachmentUnlock.owns(record: Record.Record, id: string, catalog: Catalog): boolean
	return entryOf(catalog, id) ~= nil
		and Record.owns(record, id, AttachmentUnlock.priceOf(catalog))
end

-- Whether `id` is offered on gun `gunId` in `slot` at all (an option for that gun and slot, or
-- ammo of the gun's caliber in that slot): (true) or (false, the reason).
local function offered(
	catalog: Catalog,
	gunId: string,
	slot: string,
	id: string
): (boolean, string?)
	local option = catalog.options[id]
	if option then
		if table.find(option.compatibleGuns, gunId) == nil then
			return false, "incompatible gun"
		end
		if option.slot ~= slot then
			return false, "wrong slot"
		end
		return true, nil
	end
	local ammo = catalog.ammo[id]
	if ammo then
		if ammo.slot ~= slot then
			return false, "wrong slot"
		end
		if ammo.caliberFamily ~= catalog.gunCaliber(gunId) then
			return false, "wrong caliber"
		end
		if ammo.compatibleGuns and table.find(ammo.compatibleGuns, gunId) == nil then
			return false, "incompatible gun"
		end
		return true, nil
	end
	return false, "unknown"
end

-- May `id` go in `slot` on gun `gunId`, next to what `current` has in the other slots?
-- (true) or (false, "unknown" | "incompatible gun" | "wrong slot" | "wrong caliber" | "locked"
-- | "incompatible:<the other id>").
function AttachmentUnlock.canEquip(
	record: Record.Record,
	gunId: string,
	slot: string,
	id: string,
	current: Config,
	catalog: Catalog
): (boolean, string?)
	local ok, reason = offered(catalog, gunId, slot, id)
	if not ok then
		return false, reason
	end
	if not AttachmentUnlock.owns(record, id, catalog) then
		return false, "locked"
	end
	local entry = entryOf(catalog, id) :: Entry
	local others: { string } = {}
	for otherSlot in current do
		if otherSlot ~= slot then
			table.insert(others, otherSlot)
		end
	end
	table.sort(others)
	for _, otherSlot in others do
		local otherId = current[otherSlot]
		local other = entryOf(catalog, otherId)
		if
			other
			and (
				table.find(entry.incompatibleWith, otherId) ~= nil
				or table.find(other.incompatibleWith, id) ~= nil
			)
		then
			return false, `incompatible:{otherId}`
		end
	end
	return true, nil
end

-- A whole fitting for one gun, slot by slot (in name order): (true) or (false, the first
-- reason canEquip gives).
function AttachmentUnlock.configAllowed(
	record: Record.Record,
	gunId: string,
	config: Config,
	catalog: Catalog
): (boolean, string?)
	local slots: { string } = {}
	for slot in config do
		table.insert(slots, slot)
	end
	table.sort(slots)
	for _, slot in slots do
		local ok, reason =
			AttachmentUnlock.canEquip(record, gunId, slot, config[slot], config, catalog)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

-- (the new record, true) or (the record unchanged, false, "unknown" | "owned" | "short").
function AttachmentUnlock.unlock(
	record: Record.Record,
	id: string,
	catalog: Catalog
): (Record.Record, boolean, string?)
	return Record.buy(record, id, AttachmentUnlock.priceOf(catalog))
end

-- How `id` shows in the menu, with `fitted` the id in its slot now (nil: the free one).
function AttachmentUnlock.state(
	record: Record.Record,
	fitted: string?,
	id: string,
	catalog: Catalog
): State
	if not AttachmentUnlock.owns(record, id, catalog) then
		return "locked"
	end
	local entry = entryOf(catalog, id)
	local free = entry ~= nil and entry.meritCost <= 0
	if fitted == id or (fitted == nil and free) then
		return "equipped"
	end
	return "owned"
end

-- The ids offered on gun `gunId` in `slot`, cheapest first (then by id).
function AttachmentUnlock.idsIn(catalog: Catalog, gunId: string, slot: string): { string }
	local ids: { string } = {}
	for id in catalog.options do
		if offered(catalog, gunId, slot, id) then
			table.insert(ids, id)
		end
	end
	for id in catalog.ammo do
		if offered(catalog, gunId, slot, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ca, cb =
			(entryOf(catalog, a) :: Entry).meritCost, (entryOf(catalog, b) :: Entry).meritCost
		if ca ~= cb then
			return ca < cb
		end
		return a < b
	end)
	return ids
end

-- (unlocked, total) of what gun `gunId` takes in `slot`: the menu's "X/Y" per slot.
function AttachmentUnlock.unlockedIn(
	record: Record.Record,
	gunId: string,
	slot: string,
	catalog: Catalog
): (number, number)
	local ids = AttachmentUnlock.idsIn(catalog, gunId, slot)
	local have = 0
	for _, id in ids do
		if AttachmentUnlock.owns(record, id, catalog) then
			have += 1
		end
	end
	return have, #ids
end

return AttachmentUnlock
