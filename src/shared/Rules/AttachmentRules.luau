--!strict
-- Optic unlocks and fitting as pure rules (tests/AttachmentRules.spec.luau; Nova, 2026-11-18:
-- the M16A4's optic slot at the Loadmaster). An optic is bought once with merits and kept
-- for good: it goes on the soldier's record like bought kit (Rules/Record `owned`), priced by
-- its own row (Config.Optics, Shared.Attachments.Optics). It can be fitted only when it is on
-- the record and the gun is one of its compatibleGuns. Merits only: no tabs, no Robux.
-- The callers: the lobby's OpticService (buy, equip, the Loadmaster's signature through
-- RecordService.allows) and GunsmithUI (the three states and the X/3 counter, display only).

local Record = require("./Record")

local AttachmentRules = {}

-- The slot optics go in (Config.Attachments.Slots; Loadout.attachments[gun].Optic).
AttachmentRules.SLOT = "Optic"

export type Optic = {
	id: string,
	displayName: string,
	description: string,
	compatibleGuns: { string }, -- gun ids (WeaponDefinitions) it fits
	zoomMultiplier: number, -- on the gun's own Sight.Zoom (Rules/AttachmentMerge)
	adsTimeMultiplier: number, -- on the time into the sights
	meritCost: number,
}

export type Optics = { [string]: Optic }
export type State = "locked" | "owned" | "equipped"
export type Attachments = { [string]: { [string]: string } }

-- An optic's price for Rules/Record: its meritCost, nil when the id is not an optic.
function AttachmentRules.priceOf(optics: Optics): Record.PriceOf
	return function(id: string): number?
		local optic = optics[id]
		return optic and optic.meritCost
	end
end

function AttachmentRules.fits(optic: Optic, gunId: string): boolean
	return table.find(optic.compatibleGuns, gunId) ~= nil
end

function AttachmentRules.owns(record: Record.Record, opticId: string, optics: Optics): boolean
	return optics[opticId] ~= nil and Record.owns(record, opticId, AttachmentRules.priceOf(optics))
end

-- (the new record, true) or (the record unchanged, false, "unknown" | "owned" | "short").
function AttachmentRules.buy(
	record: Record.Record,
	opticId: string,
	optics: Optics
): (Record.Record, boolean, string?)
	return Record.buy(record, opticId, AttachmentRules.priceOf(optics))
end

-- The buy applied to the record as stored (the lobby's UpdateAsync transform, the same path
-- the Quartermaster's guns take): (the value to store, nil) or (nil, reason).
function AttachmentRules.buyStored(
	stored: unknown,
	opticId: string,
	optics: Optics,
	startMerits: number
): (Record.Saved?, string?)
	return Record.buyStored(stored, opticId, AttachmentRules.priceOf(optics), startMerits)
end

-- May `opticId` go on `gunId`? (true) or (false, "unknown" | "incompatible" | "not owned").
function AttachmentRules.canEquip(
	record: Record.Record,
	gunId: string,
	opticId: string,
	optics: Optics
): (boolean, string?)
	local optic = optics[opticId]
	if not optic then
		return false, "unknown"
	end
	if not AttachmentRules.fits(optic, gunId) then
		return false, "incompatible"
	end
	if not AttachmentRules.owns(record, opticId, optics) then
		return false, "not owned"
	end
	return true, nil
end

-- Whether every optic fitted in `attachments` may be there (other slots are not checked
-- here): (true) or (false, the reason canEquip gave).
function AttachmentRules.fittedAllowed(
	record: Record.Record,
	attachments: Attachments?,
	optics: Optics
): (boolean, string?)
	local list: Attachments = attachments or {}
	for gunId, slots in list do
		local opticId = slots[AttachmentRules.SLOT]
		if opticId then
			local ok, reason = AttachmentRules.canEquip(record, gunId, opticId, optics)
			if not ok then
				return false, reason
			end
		end
	end
	return true, nil
end

-- How `opticId` shows in the menu, with `fitted` the optic on the gun now (nil = none).
function AttachmentRules.state(
	record: Record.Record,
	fitted: string?,
	opticId: string,
	optics: Optics
): State
	if not AttachmentRules.owns(record, opticId, optics) then
		return "locked"
	end
	return if fitted == opticId then "equipped" else "owned"
end

-- The optics `gunId` takes, cheapest first (then by id).
function AttachmentRules.forGun(optics: Optics, gunId: string): { Optic }
	local list: { Optic } = {}
	for _, optic in optics do
		if AttachmentRules.fits(optic, gunId) then
			table.insert(list, optic)
		end
	end
	table.sort(list, function(a, b)
		if a.meritCost ~= b.meritCost then
			return a.meritCost < b.meritCost
		end
		return a.id < b.id
	end)
	return list
end

-- (unlocked, total) of the optics `gunId` takes: the menu's "X/3 OPTICS UNLOCKED".
function AttachmentRules.unlocked(
	record: Record.Record,
	gunId: string,
	optics: Optics
): (number, number)
	local list = AttachmentRules.forGun(optics, gunId)
	local have = 0
	for _, optic in list do
		if AttachmentRules.owns(record, optic.id, optics) then
			have += 1
		end
	end
	return have, #list
end

return AttachmentRules
