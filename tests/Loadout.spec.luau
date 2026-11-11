--!strict
local Loadout = require("../src/shared/Rules/Loadout")
local expect = require("./expect")

local CATALOG: Loadout.Catalog = {
	primaries = { "service_rifle", "smg", "dmr" },
	secondaries = { "pistol" },
	grenades = { "frag" },
	callIns = { "magpie", "tripline", "anvil", "pen_coil", "hammer" },
	preferredCallIns = { "tripline", "missing_one" },
	slots = 4,
	attachments = {
		service_rifle = { Barrel = { "suppressor" } },
		pistol = { Barrel = { "suppressor" } },
	},
}

local SETTINGS: Loadout.GateSettings = { lzRadius = 30, calmSeconds = 5 }

local function valid(): Loadout.Loadout
	return {
		primary = "smg",
		secondary = "pistol",
		grenade = "frag",
		callIns = { "anvil", "tripline", "hammer", "magpie" },
	}
end

return {
	["a suppressor the gun takes is valid"] = function()
		local loadout = valid()
		loadout.attachments = { service_rifle = { Barrel = "suppressor" } }
		expect.equal((Loadout.validate(loadout, CATALOG)), true)
	end,
	["an attachment the gun does not take is refused"] = function()
		local loadout = valid()
		loadout.attachments = { smg = { Barrel = "suppressor" } } -- smg offers none here
		expect.equal(select(2, Loadout.validate(loadout, CATALOG)), "attachments")
		loadout.attachments = { service_rifle = { Barrel = "flash_hider" } }
		expect.equal(select(2, Loadout.validate(loadout, CATALOG)), "attachments")
		loadout.attachments = { service_rifle = { Stock = "suppressor" } }
		expect.equal(select(2, Loadout.validate(loadout, CATALOG)), "attachments")
	end,
	["no attachments is valid"] = function()
		expect.equal((Loadout.validate(valid(), CATALOG)), true)
	end,
	["fitted reads one slot"] = function()
		local attachments = { pistol = { Barrel = "suppressor" } }
		expect.equal(Loadout.fitted(attachments, "pistol", "Barrel"), "suppressor")
		expect.equal(Loadout.fitted(attachments, "smg", "Barrel"), nil)
		expect.equal(Loadout.fitted(nil, "pistol", "Barrel"), nil)
	end,
	["the fitted string round-trips"] = function()
		local attachments =
			{ pistol = { Barrel = "suppressor" }, service_rifle = { Barrel = "suppressor" } }
		local text = Loadout.encodeFitted(attachments)
		expect.equal(text, "pistol.Barrel=suppressor;service_rifle.Barrel=suppressor")
		local back = Loadout.decodeFitted(text)
		expect.equal(Loadout.fitted(back, "service_rifle", "Barrel"), "suppressor")
		expect.equal(Loadout.encodeFitted(nil), "")
		expect.equal(next(Loadout.decodeFitted("")), nil)
	end,
	["a copy shares no tables"] = function()
		local loadout = valid()
		loadout.attachments = { pistol = { Barrel = "suppressor" } }
		local copied = Loadout.copy(loadout)
		copied.attachments.pistol.Barrel = "none"
		table.insert(copied.callIns, "x")
		expect.equal(loadout.attachments.pistol.Barrel, "suppressor")
		expect.equal(#loadout.callIns, 4)
	end,
	["the default carries the first gun of each list"] = function()
		local loadout = Loadout.default(CATALOG)
		expect.equal(loadout.primary, "service_rifle", "primary")
		expect.equal(loadout.secondary, "pistol", "secondary")
		expect.equal(loadout.grenade, "frag", "grenade")
	end,
	["the default puts the preferred call-ins first and fills the rest in order"] = function()
		local loadout = Loadout.default(CATALOG)
		expect.equal(#loadout.callIns, 4, "slots")
		expect.equal(loadout.callIns[1], "tripline", "slot 1")
		expect.equal(loadout.callIns[2], "magpie", "slot 2")
		expect.equal(loadout.callIns[3], "anvil", "slot 3")
		expect.equal(loadout.callIns[4], "pen_coil", "slot 4")
	end,
	["the default is valid"] = function()
		local ok, reason = Loadout.validate(Loadout.default(CATALOG), CATALOG)
		expect.equal(ok, true, reason)
	end,
	["a short catalog fills only the slots it can"] = function()
		local short = table.clone(CATALOG)
		short.callIns = { "tripline", "anvil" }
		local loadout = Loadout.default(short)
		expect.equal(#loadout.callIns, 2, "slots")
		expect.equal((Loadout.validate(loadout, short)), true, "valid")
	end,
	["a full pick is valid"] = function()
		local ok, reason = Loadout.validate(valid(), CATALOG)
		expect.equal(ok, true, reason)
	end,
	["a non-table is refused"] = function()
		local ok, reason = Loadout.validate("rifle", CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "malformed", "reason")
	end,
	["an unknown primary is refused"] = function()
		local loadout = valid()
		loadout.primary = "railgun"
		local ok, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "primary", "reason")
	end,
	["a sidearm in the primary slot is refused"] = function()
		local loadout = valid()
		loadout.primary = "pistol"
		expect.equal((Loadout.validate(loadout, CATALOG)), false, "ok")
	end,
	["an unknown secondary or grenade is refused"] = function()
		local loadout = valid()
		loadout.secondary = "smg"
		local _, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(reason, "secondary", "secondary")
		loadout = valid()
		loadout.grenade = "nuke"
		_, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(reason, "grenade", "grenade")
	end,
	["the same call-in twice is refused"] = function()
		local loadout = valid()
		loadout.callIns = { "anvil", "anvil", "hammer", "magpie" }
		local ok, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "duplicate call-in", "reason")
	end,
	["too few call-ins are refused"] = function()
		local loadout = valid()
		loadout.callIns = { "anvil", "tripline", "hammer" }
		local _, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(reason, "call-ins", "reason")
	end,
	["an unknown call-in is refused"] = function()
		local loadout = valid()
		loadout.callIns = { "anvil", "tripline", "hammer", "orbital_laser" }
		local _, reason = Loadout.validate(loadout, CATALOG)
		expect.equal(reason, "call-ins", "reason")
	end,
	["changed slots are the ones whose call-in moved or changed"] = function()
		local changed = Loadout.changedSlots(
			{ "tripline", "anvil", "magpie", "pen_coil" },
			{ "tripline", "magpie", "anvil", "hammer" }
		)
		expect.equal(#changed, 3, "count")
		expect.equal(changed[1], 2, "first")
		expect.equal(changed[2], 3, "second")
		expect.equal(changed[3], 4, "third")
	end,
	["the menu opens any time before the drop and during the ready-up"] = function()
		for _, phase in { "Lobby", "Insert", "Ended" } do
			local ok = Loadout.canChange(
				{ phase = phase, lzDistance = 500, calmFor = 0, alive = false },
				SETTINGS
			)
			expect.equal(ok, true, phase)
		end
	end,
	["in a run it opens at the LZ after a calm spell"] = function()
		local ok = Loadout.canChange(
			{ phase = "Explore", lzDistance = 20, calmFor = 6, alive = true },
			SETTINGS
		)
		expect.equal(ok, true, "ok")
	end,
	["in a run it stays shut away from the LZ"] = function()
		local ok, reason = Loadout.canChange(
			{ phase = "Primary", lzDistance = 31, calmFor = 60, alive = true },
			SETTINGS
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "away from the LZ", "reason")
	end,
	["in a run it stays shut while fighting"] = function()
		local ok, reason = Loadout.canChange(
			{ phase = "Extract", lzDistance = 5, calmFor = 4.9, alive = true },
			SETTINGS
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "in contact", "reason")
	end,
	["in a run a downed or dead soldier cannot change"] = function()
		local ok, reason = Loadout.canChange(
			{ phase = "Explore", lzDistance = 5, calmFor = 60, alive = false },
			SETTINGS
		)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "down", "reason")
	end,
}
