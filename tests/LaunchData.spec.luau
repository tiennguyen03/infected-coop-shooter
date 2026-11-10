--!strict
local LaunchData = require("../src/shared/Rules/LaunchData")
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
	["encode keeps the spot and the party"] = function()
		local data = LaunchData.encode(2, { 11, 22 }, {})
		expect.equal(data.spot, 2, "spot")
		expect.equal(#data.party, 2, "party size")
		expect.equal(data.party[2], 22, "second member")
	end,
	["a signed loadout round-trips by UserId"] = function()
		local data = LaunchData.encode(1, { 11 }, { [11] = signed() })
		local loadout = LaunchData.loadoutFor(data, 11, valid)
		expect.equal(loadout ~= nil, true, "found")
		local found = loadout :: Loadout.Loadout
		expect.equal(found.primary, "smg", "primary")
		expect.equal(found.callIns[1], "anvil", "slot 1")
		expect.equal(#found.callIns, 4, "slots")
	end,
	["loadouts are keyed by string so they survive teleport data"] = function()
		local data = LaunchData.encode(1, { 11 }, { [11] = signed() })
		expect.equal(data.loadouts["11"] ~= nil, true, "string key")
	end,
	["the decoded loadout is a copy"] = function()
		local data = LaunchData.encode(1, { 11 }, { [11] = signed() })
		local loadout = LaunchData.loadoutFor(data, 11, valid) :: Loadout.Loadout
		loadout.callIns[1] = "changed"
		expect.equal(data.loadouts["11"].callIns[1], "anvil", "source untouched")
	end,
	["someone who signed nothing gets nil"] = function()
		local data = LaunchData.encode(1, { 11, 22 }, { [11] = signed() })
		expect.equal(LaunchData.loadoutFor(data, 22, valid), nil, "unsigned")
	end,
	["no teleport data (Studio, a direct join) gets nil"] = function()
		expect.equal(LaunchData.loadoutFor(nil, 11, valid), nil, "nil data")
		expect.equal(LaunchData.loadoutFor("junk", 11, valid), nil, "string data")
		expect.equal(LaunchData.loadoutFor({ spot = 1 }, 11, valid), nil, "no loadouts")
	end,
	["a loadout the catalog does not allow gets nil"] = function()
		local bad = signed()
		bad.primary = "railgun"
		local data = LaunchData.encode(1, { 11 }, { [11] = bad })
		expect.equal(LaunchData.loadoutFor(data, 11, valid), nil, "unknown gun")
		local twice = signed()
		twice.callIns = { "anvil", "anvil", "hammer", "magpie" }
		data = LaunchData.encode(1, { 11 }, { [11] = twice })
		expect.equal(LaunchData.loadoutFor(data, 11, valid), nil, "repeated call-in")
	end,
	["a malformed entry gets nil"] = function()
		expect.equal(
			LaunchData.loadoutFor({ loadouts = { ["11"] = "smg" } }, 11, valid),
			nil,
			"string entry"
		)
		expect.equal(
			LaunchData.loadoutFor({ loadouts = { ["11"] = { primary = "smg" } } }, 11, valid),
			nil,
			"missing fields"
		)
	end,
}
