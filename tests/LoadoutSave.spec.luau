--!strict
local LoadoutSave = require("../src/shared/Rules/LoadoutSave")
local Loadout = require("../src/shared/Rules/Loadout")
local expect = require("./expect")

local CATALOG: Loadout.Catalog = {
	primaries = { "service_rifle", "smg" },
	secondaries = { "pistol" },
	grenades = { "frag" },
	callIns = { "magpie", "tripline", "anvil", "hammer" },
	slots = 4,
}

local function valid(loadout: unknown): boolean
	return (Loadout.validate(loadout, CATALOG))
end

local function signed(): Loadout.Loadout
	return {
		primary = "smg",
		secondary = "pistol",
		grenade = "frag",
		callIns = { "anvil", "tripline", "hammer", "magpie" },
	}
end

return {
	["a saved Loadout reads back the same"] = function()
		local loadout = LoadoutSave.decode(LoadoutSave.encode(signed()), valid)
		expect.equal(loadout ~= nil, true, "read back")
		local found = loadout :: Loadout.Loadout
		expect.equal(found.primary, "smg", "primary")
		expect.equal(found.callIns[2], "tripline", "slot 2")
		expect.equal(#found.callIns, 4, "slots")
	end,
	["the save carries its format version"] = function()
		expect.equal(LoadoutSave.encode(signed()).version, LoadoutSave.VERSION, "version")
	end,
	["the save is a copy, not the live table"] = function()
		local loadout = signed()
		local saved = LoadoutSave.encode(loadout)
		loadout.callIns[1] = "changed"
		expect.equal(saved.loadout.callIns[1], "anvil", "copy")
	end,
	["nothing saved yet reads as nil"] = function()
		expect.equal(LoadoutSave.decode(nil, valid), nil, "nil")
		expect.equal(LoadoutSave.decode("junk", valid), nil, "string")
		expect.equal(LoadoutSave.decode({}, valid), nil, "empty table")
	end,
	["another format version reads as nil"] = function()
		local data = LoadoutSave.encode(signed()) :: any
		data.version = LoadoutSave.VERSION + 1
		expect.equal(LoadoutSave.decode(data, valid), nil, "future version")
	end,
	["a Loadout the catalog no longer allows reads as nil"] = function()
		local old = signed()
		old.primary = "retired_gun"
		expect.equal(LoadoutSave.decode(LoadoutSave.encode(old), valid), nil, "retired gun")
	end,
}
