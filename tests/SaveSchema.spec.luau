--!strict
local SaveSchema = require("../src/shared/Rules/SaveSchema")
local expect = require("./expect")

local RECORD = SaveSchema.Record
local LOADOUT = SaveSchema.Loadout

local function loadout()
	return {
		primary = "service_rifle",
		secondary = "pistol",
		grenade = "frag",
		callIns = { "hammer" },
	}
end

return {
	-- Reading: every status
	["no save yet is empty and may be written"] = function()
		local status, save = SaveSchema.read(RECORD, nil)
		expect.equal(status, "empty", "status")
		expect.equal(save, nil, "save")
		expect.equal(SaveSchema.writable(RECORD, nil), true, "writable")
	end,
	["a save that is not a table is junk and never written over"] = function()
		for _, junk in { "junk", 5, true } :: { any } do
			expect.equal((SaveSchema.read(RECORD, junk)), "junk", tostring(junk))
			expect.equal(SaveSchema.writable(RECORD, junk), false, tostring(junk))
		end
	end,
	["a version that is not a whole number at or above 0 is junk"] = function()
		expect.equal((SaveSchema.read(RECORD, { version = -1, merits = 5 })), "junk", "negative")
		expect.equal((SaveSchema.read(RECORD, { version = 1.5, merits = 5 })), "junk", "fraction")
		expect.equal((SaveSchema.read(RECORD, { version = "2", merits = 5 })), "junk", "string")
		expect.equal((SaveSchema.read(RECORD, { version = 0 / 0, merits = 5 })), "junk", "nan")
	end,
	["a save from a newer version is kept as it is and never written"] = function()
		local newer = { version = RECORD.version + 1, merits = 9000, medals = { "x" } }
		local status, save = SaveSchema.read(RECORD, newer)
		expect.equal(status, "newer", "status")
		expect.equal(save, nil, "no migrated copy")
		expect.equal(newer.version, RECORD.version + 1, "the stored table is untouched")
		expect.equal(SaveSchema.writable(RECORD, newer), false, "not writable")
	end,

	-- Record: v0 -> v1 -> v2
	["today's unversioned record reads as the current shape"] = function()
		local old = { merits = 640, owned = { "smg" } }
		local status, save = SaveSchema.read(RECORD, old)
		expect.equal(status, "ok", "status")
		local s = save :: any
		expect.equal(s.version, RECORD.version, "current version")
		expect.equal(s.merits, 640, "merits")
		expect.equal(s.owned[1], "smg", "owned")
		expect.equal(s.tabs, 0, "tabs added")
		expect.equal(#s.receipts, 0, "receipts added")
		expect.equal(old.merits, 640, "the stored table is not changed")
		expect.equal((old :: any).version, nil, "no version written onto the input")
	end,
	["an unversioned table without merits is junk"] = function()
		expect.equal((SaveSchema.read(RECORD, {})), "junk", "empty")
		expect.equal((SaveSchema.read(RECORD, { owned = {} })), "junk", "no merits")
	end,
	["a version 1 record gains tabs and receipts and keeps the rest"] = function()
		local status, save = SaveSchema.read(RECORD, { version = 1, merits = 10, owned = {} })
		expect.equal(status, "ok", "status")
		expect.equal((save :: any).tabs, 0, "tabs")
		expect.equal((save :: any).version, 2, "version")
	end,
	["a current record with bad merits is junk"] = function()
		expect.equal((SaveSchema.read(RECORD, { version = 2, merits = "x" })), "junk", "string")
		expect.equal((SaveSchema.read(RECORD, { version = 2 })), "junk", "missing")
	end,
	["migration never drops a field it does not know"] = function()
		local _, save =
			SaveSchema.read(RECORD, { merits = 5, owned = {}, medals = { "first_blood" }, x = 1 })
		expect.equal((save :: any).medals[1], "first_blood", "unknown table kept")
		expect.equal((save :: any).x, 1, "unknown number kept")
	end,
	["migration never lowers a currency"] = function()
		local cases = {
			{ merits = 0, owned = {} },
			{ merits = 123456, owned = {} },
			{ version = 1, merits = 77, owned = {} },
			{ version = 1, merits = 77, owned = {}, tabs = 40 }, -- tabs written before the bump
			{ version = 2, merits = 3, owned = {}, tabs = 900, receipts = {} },
		}
		for i, case in cases :: { any } do
			local _, save = SaveSchema.read(RECORD, case)
			local s = save :: any
			expect.equal(s.merits >= case.merits, true, `merits {i}`)
			expect.equal(s.tabs >= (case.tabs or 0), true, `tabs {i}`)
			expect.equal(s.tabs, case.tabs or 0, `tabs kept {i}`)
		end
	end,
	["migrating a current save changes nothing"] = function()
		local current =
			{ version = RECORD.version, merits = 8, owned = { "a" }, tabs = 2, receipts = { "r" } }
		local _, save = SaveSchema.read(RECORD, current)
		local s = save :: any
		expect.equal(s.merits, 8, "merits")
		expect.equal(s.tabs, 2, "tabs")
		expect.equal(s.receipts[1], "r", "receipts")
		expect.equal(s.owned[1], "a", "owned")
	end,

	-- Writing over a stored save
	["over keeps unknown fields of the stored save and writes the known ones"] = function()
		local stored = { version = 2, merits = 5, owned = {}, medals = { "m" } }
		local written =
			SaveSchema.over(RECORD, stored, { version = 2, merits = 9, owned = { "b" } })
		local w = written :: any
		expect.equal(w.merits, 9, "new merits")
		expect.equal(w.owned[1], "b", "new owned")
		expect.equal(w.medals[1], "m", "unknown kept")
		expect.equal(w.version, RECORD.version, "version")
	end,
	["over starts from nothing when there is no save"] = function()
		local w = SaveSchema.over(RECORD, nil, { merits = 1, owned = {} }) :: any
		expect.equal(w.merits, 1, "merits")
		expect.equal(w.version, RECORD.version, "stamped with the version")
	end,
	["over refuses a save it may not write"] = function()
		local newer = { version = RECORD.version + 1, merits = 1 }
		expect.equal(SaveSchema.over(RECORD, newer, { merits = 2 }), nil, "newer")
		expect.equal(SaveSchema.over(RECORD, "junk", { merits = 2 }), nil, "junk")
	end,

	-- Loadout
	["a version 1 Loadout save reads as it is"] = function()
		local status, save = SaveSchema.read(LOADOUT, { version = 1, loadout = loadout() })
		expect.equal(status, "ok", "status")
		expect.equal((save :: any).loadout.primary, "service_rifle", "primary")
	end,
	["an unversioned Loadout save is wrapped or stamped"] = function()
		local status, save = SaveSchema.read(LOADOUT, loadout())
		expect.equal(status, "ok", "bare Loadout")
		expect.equal((save :: any).loadout.primary, "service_rifle", "wrapped")
		expect.equal((save :: any).version, LOADOUT.version, "version")
		local status2, save2 = SaveSchema.read(LOADOUT, { loadout = loadout() })
		expect.equal(status2, "ok", "loadout field without a version")
		expect.equal((save2 :: any).loadout.grenade, "frag", "kept")
	end,
	["a Loadout save with no Loadout is junk"] = function()
		expect.equal((SaveSchema.read(LOADOUT, {})), "junk", "empty")
		expect.equal((SaveSchema.read(LOADOUT, { version = 1 })), "junk", "no loadout")
	end,
	["a newer Loadout save is never written"] = function()
		expect.equal(SaveSchema.writable(LOADOUT, { version = 2, loadout = {} }), false, "newer")
	end,

	-- The schema itself
	["every version from 1 up has exactly one step"] = function()
		for _, schema in { RECORD, LOADOUT } do
			expect.equal(#schema.steps, schema.version, schema.name)
		end
	end,
}
