--!strict
-- The Mossberg 590 as it ships (Config.luau's rows, loaded through tests/loadConfig), for the
-- Mossberg attachment specs: the catalog Rules/AttachmentUnlock checks, and a merge with any
-- fitting. Not a spec (the runner only runs *.spec.luau).

local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local AttachmentUnlock = require("../src/shared/Rules/AttachmentUnlock")
local Record = require("../src/shared/Rules/Record")
local loadConfig = require("./loadConfig")

local Config = loadConfig()

local Fixture = {}

Fixture.Config = Config
Fixture.GUN = "shotgun"
Fixture.ROW = Config.Weapons.Shotgun

local function ammoSlot(): string
	for id, row in Config.AttachmentsV2.Slots do
		if row.Ammo then
			return id
		end
	end
	error("no ammo slot")
end
Fixture.AMMO_SLOT = ammoSlot()

local options: { [string]: any } = {}
for id, row in Config.AttachmentsV2.Options do
	options[id] = AttachmentMerge.optionFromRow(id, row)
end
for id, row in Config.Optics do
	options[id] = AttachmentMerge.opticFromRow(id, row, "Optic")
end
local ammo: { [string]: any } = {}
for id, row in Config.AttachmentsV2.Ammo do
	ammo[id] = AttachmentMerge.ammoFromRow(id, row, Fixture.AMMO_SLOT)
end

Fixture.catalog = {
	options = options,
	ammo = ammo,
	gunCaliber = function(gunId: string): string?
		return if gunId == Fixture.GUN then Fixture.ROW.Caliber else nil
	end,
} :: AttachmentUnlock.Catalog

-- A record that owns everything (the clash checks come after "locked").
function Fixture.richRecord(): Record.Record
	local record = Record.new(0)
	for id in options do
		table.insert(record.owned, id)
	end
	for id in ammo do
		table.insert(record.owned, id)
	end
	return record
end

-- The Mossberg with `fitting` ([slot] = id; the ammo slot's id an ammo type): (stats, reason).
function Fixture.merge(fitting: { [string]: string }): (AttachmentMerge.GunStats?, string?)
	local equipped: { [string]: AttachmentMerge.Option } = {}
	local round: AttachmentMerge.Ammo? = nil
	for slot, id in fitting do
		if slot == Fixture.AMMO_SLOT then
			round = ammo[id] or error(`no ammo {id}`)
		else
			equipped[slot] = options[id] or error(`no option {id}`)
		end
	end
	return AttachmentMerge.merge({
		id = Fixture.GUN,
		caliber = Fixture.ROW.Caliber,
		stats = AttachmentMerge.gunStats(Fixture.ROW),
	}, equipped, round)
end

-- Like merge, erroring on a refusal.
function Fixture.stats(fitting: { [string]: string }): AttachmentMerge.GunStats
	local stats, reason = Fixture.merge(fitting)
	if not stats then
		error(`refused: {reason}`, 2)
	end
	return stats
end

-- The ids the Mossberg takes in `slot`.
function Fixture.idsIn(slot: string): { string }
	return AttachmentUnlock.idsIn(Fixture.catalog, Fixture.GUN, slot)
end

return Fixture
