--!strict
-- Which mount on a gun's model an attachment slot's part goes on (Rules/MountPointResolution;
-- the attachment visuals, Nova 2026-11-20). Written before the rule.
local MountPointResolution = require("../src/shared/Rules/MountPointResolution")
local expect = require("./expect")

-- The schema as Shared.Attachments.MountPoints gives it: slot -> mount, the ammo slot none.
local SCHEMA: MountPointResolution.Schema = {
	slots = {
		Optic = "OpticMount",
		Barrel = "BarrelMount",
		Muzzle = "MuzzleMount",
		Magazine = "MagazineMount",
		Underbarrel = "UnderbarrelMount",
		Stock = "StockMount",
		Ammo = false,
	},
}

local LONG_GUN: MountPointResolution.Mounts = {
	OpticMount = { at = { 0, 0.6, -0.2 } },
	BarrelMount = { at = { 0, 0.36, -1.2 } },
	MuzzleMount = { at = { 0, 0.36, -2.0 } },
	MagazineMount = { at = { 0, -0.1, -0.4 } },
	UnderbarrelMount = { at = { 0, 0.2, -1.1 } },
	StockMount = { at = { 0, 0.3, 0.8 } },
}

local SIDEARM: MountPointResolution.Mounts = {
	OpticMount = { at = { 0, 0.3, 0 } },
	BarrelMount = { at = { 0, 0.25, -0.4 } },
	MagazineMount = { at = { 0, -0.2, 0 } },
}

return {
	["each of the six slots resolves on a long gun that has them all"] = function()
		for slot, mount in SCHEMA.slots do
			if mount then
				local found, why = MountPointResolution.resolve(slot, LONG_GUN, SCHEMA)
				expect.equal(found, LONG_GUN[mount :: string], slot)
				expect.equal(why, nil, `{slot} no reason`)
			end
		end
	end,
	["a sidearm resolves its own mounts"] = function()
		for _, slot in { "Optic", "Barrel", "Magazine" } do
			local found = MountPointResolution.resolve(slot, SIDEARM, SCHEMA)
			expect.equal(found ~= nil, true, slot)
		end
	end,
	["a mount the model lacks: nil, and the applier skips it"] = function()
		local found, why = MountPointResolution.resolve("Underbarrel", SIDEARM, SCHEMA)
		expect.equal(found, nil, "no underbarrel mount on a pistol")
		expect.equal(why, "missing", "reason")
		local none, noModel = MountPointResolution.resolve("Optic", nil, SCHEMA)
		expect.equal(none, nil, "a gun with no mounts at all")
		expect.equal(noModel, "missing", "reason")
	end,
	["the ammo slot has no mount"] = function()
		local found, why = MountPointResolution.resolve("Ammo", LONG_GUN, SCHEMA)
		expect.equal(found, nil, "ammo is not a part on the gun")
		expect.equal(why, "none", "reason")
	end,
	["an unknown slot is refused"] = function()
		local found, why = MountPointResolution.resolve("Bayonet", LONG_GUN, SCHEMA)
		expect.equal(found, nil, "no such slot")
		expect.equal(why, "slot", "reason")
		local _, empty = MountPointResolution.resolve("", LONG_GUN, SCHEMA)
		expect.equal(empty, "slot", "empty id")
	end,
}
