--!strict
-- Any gun as it ships (Config.luau's rows, loaded through tests/loadConfig), for the attachment
-- specs: the catalog Rules/AttachmentUnlock checks, and a merge of a fitting on gun `gunId`.
-- Not a spec (the runner only runs *.spec.luau).

local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local AttachmentUnlock = require("../src/shared/Rules/AttachmentUnlock")
local Record = require("../src/shared/Rules/Record")
local loadConfig = require("./loadConfig")

local Config = loadConfig()

local Fixture = {}

Fixture.Config = Config

-- A gun id ("service_rifle") is its Config.Weapons key in camel case ("ServiceRifle").
function Fixture.row(gunId: string): any
	local key = string.gsub(gunId, "(%a)(%w*)_?", function(first: string, rest: string)
		return string.upper(first) .. rest
	end)
	return Config.Weapons[key] or error(`no gun row {key}`)
end

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
		local ok, row = pcall(Fixture.row, gunId)
		return if ok then row.Caliber else nil
	end,
} :: AttachmentUnlock.Catalog

function Fixture.entry(id: string): any
	return options[id] or ammo[id] or error(`no option or ammo {id}`)
end

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

-- Gun `gunId` with `fitting` ([slot] = id; the ammo slot's id an ammo type): (stats, reason).
function Fixture.merge(
	gunId: string,
	fitting: { [string]: string }
): (AttachmentMerge.GunStats?, string?)
	local row = Fixture.row(gunId)
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
		id = gunId,
		caliber = row.Caliber,
		stats = AttachmentMerge.gunStats(row),
	}, equipped, round)
end

-- Like merge, erroring on a refusal.
function Fixture.stats(gunId: string, fitting: { [string]: string }): AttachmentMerge.GunStats
	local stats, reason = Fixture.merge(gunId, fitting)
	if not stats then
		error(`{gunId} refused: {reason}`, 2)
	end
	return stats
end

-- The ids gun `gunId` takes in `slot`.
function Fixture.idsIn(gunId: string, slot: string): { string }
	return AttachmentUnlock.idsIn(Fixture.catalog, gunId, slot)
end

return Fixture
