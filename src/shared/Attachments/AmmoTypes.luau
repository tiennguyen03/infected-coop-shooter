--!strict
-- The ammo types as typed records (attachment system v2, Nova 2026-11-20): one per row of
-- Config.AttachmentsV2.Ammo. A separate module from the options because an ammo type is a
-- different shape: it carries a whole damage profile that REPLACES the gun's own
-- (Rules/AttachmentMerge), not deltas. The schema is shared; each caliber family has its own
-- rows (only 5.56 so far, on the M16A4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AttachmentMerge = require(ReplicatedStorage.Shared.Rules.AttachmentMerge)
local Schema = require(script.Parent.Schema)

local AmmoTypes = {}

export type AmmoType = AttachmentMerge.Ammo & {
	displayName: string,
	description: string,
	slot: string, -- the ammo slot (Schema)
	meritCost: number, -- 0: the issued round, always owned
	base: boolean,
}

local SLOT = Schema.ammoSlot() or "Ammo"

local ROWS: { [string]: AmmoType } = {}
for id, row in Config.AttachmentsV2.Ammo :: { [string]: any } do
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		description = row.Description,
		caliberFamily = row.Caliber,
		slot = SLOT,
		incompatibleWith = table.clone(row.IncompatibleWith or {}),
		meritCost = row.Price,
		base = row.Base == true,
		damageProfile = {
			damage = row.Damage,
			projectileCount = row.Projectiles,
			headshotMultiplier = row.HeadshotMultiplier,
			armorPenetration = row.ArmourPenetration,
			alertRadiusMultiplier = row.AlertMultiplier,
			projectileBehavior = row.Behaviour,
			rangeMultiplier = row.RangeMultiplier,
		},
	}
end

AmmoTypes.Rows = ROWS
AmmoTypes.SLOT = SLOT

function AmmoTypes.get(id: string?): AmmoType?
	return if id then ROWS[id] else nil
end

-- The menu's line for an ammo type ("28 dmg, x4 head, 0% pen").
function AmmoTypes.summary(ammo: AmmoType): string
	local profile = ammo.damageProfile
	local parts = {
		string.format("%d dmg", profile.damage),
		string.format("x%g head", profile.headshotMultiplier),
		string.format("%d%% armour pen", math.floor(profile.armorPenetration * 100 + 0.5)),
	}
	if profile.projectileCount > 1 then
		table.insert(parts, 1, `{profile.projectileCount} pellets`)
	end
	if profile.alertRadiusMultiplier ~= 1 then
		table.insert(
			parts,
			string.format(
				"%+d%% alert",
				math.floor((profile.alertRadiusMultiplier - 1) * 100 + 0.5)
			)
		)
	end
	return table.concat(parts, ", ")
end

return AmmoTypes
