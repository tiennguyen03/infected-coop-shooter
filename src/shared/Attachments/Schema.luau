--!strict
-- The attachment slots as typed records (attachment system v2, Nova 2026-11-20), one per row
-- of Config.AttachmentsV2.Slots: no list of slot names lives here or anywhere else. A gun takes
-- the slots whose families include its row's Family (Config.Weapons.<gun>.Family).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Schema = {}

export type Slot = {
	id: string, -- the slot's key (Loadout.attachments[gun][id])
	displayName: string,
	order: number, -- its place in the menu
	compatibleGunFamilies: { string },
	maxOptionsPerGun: number,
	ammo: boolean, -- the ammo-type slot: its options are Shared.Attachments.AmmoTypes
}

local ROWS: { [string]: Slot } = {}
for id, row in Config.AttachmentsV2.Slots :: { [string]: any } do
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		order = row.Order,
		compatibleGunFamilies = table.clone(row.Families),
		maxOptionsPerGun = row.MaxOptions,
		ammo = row.Ammo == true,
	}
end

Schema.Rows = ROWS

function Schema.get(id: string): Slot?
	return ROWS[id]
end

-- The slots a gun of `family` takes (nil: none), in menu order.
function Schema.forFamily(family: string?): { Slot }
	local list: { Slot } = {}
	if not family then
		return list
	end
	for _, slot in ROWS do
		if table.find(slot.compatibleGunFamilies, family) then
			table.insert(list, slot)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

-- The ammo-type slot's id (the one row marked Ammo).
function Schema.ammoSlot(): string?
	for id, slot in ROWS do
		if slot.ammo then
			return id
		end
	end
	return nil
end

return Schema
