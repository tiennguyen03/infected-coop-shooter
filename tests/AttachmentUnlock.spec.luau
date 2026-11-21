--!strict
-- Unlocking and fitting attachment options (Rules/AttachmentUnlock; attachment system v2,
-- Nova 2026-11-20). Written before the rule.
local AttachmentUnlock = require("../src/shared/Rules/AttachmentUnlock")
local Record = require("../src/shared/Rules/Record")
local expect = require("./expect")

local GUN = "service_rifle"

local CATALOG: AttachmentUnlock.Catalog = {
	gunCaliber = function(gunId: string): string?
		return if gunId == GUN then "5.56" else nil
	end,
	options = {
		barrel_standard = {
			id = "barrel_standard",
			slot = "Barrel",
			compatibleGuns = { GUN },
			incompatibleWith = {},
			meritCost = 0,
		},
		barrel_long = {
			id = "barrel_long",
			slot = "Barrel",
			compatibleGuns = { GUN },
			incompatibleWith = {},
			meritCost = 150,
		},
		suppressor = {
			id = "suppressor",
			slot = "Barrel",
			compatibleGuns = { GUN },
			incompatibleWith = { "muzzle_brake" },
			meritCost = 0,
		},
		muzzle_brake = {
			id = "muzzle_brake",
			slot = "Muzzle",
			compatibleGuns = { GUN },
			incompatibleWith = {},
			meritCost = 200,
		},
		mp5_barrel = {
			id = "mp5_barrel",
			slot = "Barrel",
			compatibleGuns = { "smg" },
			incompatibleWith = {},
			meritCost = 100,
		},
	},
	ammo = {
		ammo_556_ap = {
			id = "ammo_556_ap",
			slot = "Ammo",
			caliberFamily = "5.56",
			incompatibleWith = {},
			meritCost = 200,
		},
		ammo_12_slug = {
			id = "ammo_12_slug",
			slot = "Ammo",
			caliberFamily = "12ga",
			incompatibleWith = {},
			meritCost = 150,
		},
	},
}

local function record(merits: number, owned: { string }): Record.Record
	local r = Record.new(merits)
	r.owned = owned
	return r
end

return {
	["fitting an owned option is allowed"] = function()
		local ok, reason = AttachmentUnlock.canEquip(
			record(0, { "barrel_long" }),
			GUN,
			"Barrel",
			"barrel_long",
			{},
			CATALOG
		)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "reason")
	end,
	["a free (base) option needs no unlock"] = function()
		local ok =
			AttachmentUnlock.canEquip(record(0, {}), GUN, "Barrel", "barrel_standard", {}, CATALOG)
		expect.equal(ok, true, "ok")
	end,
	["fitting a locked option is refused"] = function()
		local ok, reason =
			AttachmentUnlock.canEquip(record(9999, {}), GUN, "Barrel", "barrel_long", {}, CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "locked", "reason")
	end,
	["fitting an incompatible combination is refused with the other option named"] = function()
		local ok, reason = AttachmentUnlock.canEquip(
			record(0, { "muzzle_brake" }),
			GUN,
			"Barrel",
			"suppressor",
			{ Muzzle = "muzzle_brake" },
			CATALOG
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "incompatible:muzzle_brake", "reason")
	end,
	["the option in the slot being changed does not count against the new one"] = function()
		local ok = AttachmentUnlock.canEquip(
			record(0, { "barrel_long" }),
			GUN,
			"Barrel",
			"suppressor",
			{ Barrel = "barrel_long" },
			CATALOG
		)
		expect.equal(ok, true, "replacing the barrel")
	end,
	["fitting an option on the wrong gun is refused"] = function()
		local ok, reason = AttachmentUnlock.canEquip(
			record(0, { "mp5_barrel" }),
			GUN,
			"Barrel",
			"mp5_barrel",
			{},
			CATALOG
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "incompatible gun", "reason")
	end,
	["fitting an option in the wrong slot is refused"] = function()
		local ok, reason = AttachmentUnlock.canEquip(
			record(0, { "barrel_long" }),
			GUN,
			"Muzzle",
			"barrel_long",
			{},
			CATALOG
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "wrong slot", "reason")
	end,
	["ammo of another caliber is refused"] = function()
		local ok, reason = AttachmentUnlock.canEquip(
			record(0, { "ammo_12_slug" }),
			GUN,
			"Ammo",
			"ammo_12_slug",
			{},
			CATALOG
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "wrong caliber", "reason")
	end,
	["owned ammo of the gun's caliber is allowed"] = function()
		local ok = AttachmentUnlock.canEquip(
			record(0, { "ammo_556_ap" }),
			GUN,
			"Ammo",
			"ammo_556_ap",
			{},
			CATALOG
		)
		expect.equal(ok, true, "ok")
	end,
	["an unknown option is refused"] = function()
		local ok, reason =
			AttachmentUnlock.canEquip(record(0, {}), GUN, "Barrel", "nope", {}, CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "unknown", "reason")
	end,
	["unlocking with enough merits is allowed and spends them"] = function()
		local after, ok, reason = AttachmentUnlock.unlock(record(500, {}), "barrel_long", CATALOG)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "reason")
		expect.equal(after.merits, 350, "merits")
		expect.equal(table.find(after.owned, "barrel_long") ~= nil, true, "owned")
	end,
	["unlocking without enough merits is refused"] = function()
		local after, ok, reason = AttachmentUnlock.unlock(record(100, {}), "barrel_long", CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "short", "reason")
		expect.equal(after.merits, 100, "merits kept")
	end,
	["unlocking an option already owned is refused"] = function()
		local _, ok, reason =
			AttachmentUnlock.unlock(record(500, { "barrel_long" }), "barrel_long", CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "owned", "reason")
	end,
	["a free option is already owned"] = function()
		local _, ok, reason = AttachmentUnlock.unlock(record(500, {}), "barrel_standard", CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "owned", "reason")
	end,
	["ammo unlocks the same way"] = function()
		local after, ok = AttachmentUnlock.unlock(record(500, {}), "ammo_556_ap", CATALOG)
		expect.equal(ok, true, "ok")
		expect.equal(after.merits, 300, "merits")
	end,
	["a whole fitting is checked slot by slot"] = function()
		local ok, reason = AttachmentUnlock.configAllowed(
			record(0, { "muzzle_brake" }),
			GUN,
			{ Barrel = "suppressor", Muzzle = "muzzle_brake" },
			CATALOG
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "incompatible:muzzle_brake", "reason")
		local fine = AttachmentUnlock.configAllowed(
			record(0, { "muzzle_brake", "barrel_long" }),
			GUN,
			{ Barrel = "barrel_long", Muzzle = "muzzle_brake" },
			CATALOG
		)
		expect.equal(fine, true, "an allowed fitting")
	end,
	["a slot's unlocked count"] = function()
		local have, total =
			AttachmentUnlock.unlockedIn(record(0, { "barrel_long" }), GUN, "Barrel", CATALOG)
		expect.equal(have, 3, "standard, suppressor (free) and long")
		expect.equal(total, 3, "the M16's three barrels")
	end,
}
