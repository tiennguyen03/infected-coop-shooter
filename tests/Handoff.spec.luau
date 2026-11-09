--!strict
local Handoff = require("../src/shared/Rules/Handoff")
local Loadout = require("../src/shared/Rules/Loadout")
local expect = require("./expect")

local catalog = {
	primaries = { "service_rifle", "smg" },
	secondaries = { "pistol" },
	grenades = { "frag" },
	callIns = { "hammer", "anvil", "shrike", "doorman" },
	slots = 4,
}

local check = {
	default = Loadout.default(catalog),
	isValid = function(loadout: unknown): boolean
		return (Loadout.validate(loadout, catalog))
	end,
}

local good = {
	primary = "smg",
	secondary = "pistol",
	grenade = "frag",
	callIns = { "anvil", "hammer", "shrike", "doorman" },
}

local function data(party: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	local out: { [string]: any } = {
		version = Handoff.VERSION,
		operation = "harlan_corridor",
		party = party,
	}
	for key, value in extra or {} do
		out[key] = value
	end
	return out
end

return {
	["no teleport data (Studio, a direct join) gets the defaults"] = function()
		local join = Handoff.readJoin(nil, 111, check)
		expect.equal(join.fromLobby, false, "fromLobby")
		expect.equal(join.operation, Handoff.DEFAULT_OPERATION, "operation")
		expect.equal(join.loadout.primary, "service_rifle", "default primary")
		expect.equal(join.partySize, 1, "party size")
	end,
	["a player's own loadout comes through"] = function()
		local join = Handoff.readJoin(data({ ["111"] = { slot = 2, loadout = good } }), 111, check)
		expect.equal(join.fromLobby, true, "fromLobby")
		expect.equal(join.loadout.primary, "smg", "primary")
		expect.equal(join.loadout.callIns[1], "anvil", "slot 1")
		expect.equal(join.slot, 2, "slot")
		expect.equal(join.operation, "harlan_corridor", "operation")
	end,
	["party size is how many the lobby sent"] = function()
		local join = Handoff.readJoin(
			data({
				["111"] = { loadout = good },
				["222"] = { loadout = good },
				["333"] = { loadout = good },
			}),
			222,
			check
		)
		expect.equal(join.partySize, 3)
	end,
	["a loadout the catalog does not offer falls back to the default"] = function()
		local bad = table.clone(good)
		bad.primary = "railgun"
		local join = Handoff.readJoin(data({ ["111"] = { loadout = bad } }), 111, check)
		expect.equal(join.loadout.primary, "service_rifle")
	end,
	["a player missing from the party list still plays, on the defaults"] = function()
		local join = Handoff.readJoin(data({ ["222"] = { loadout = good } }), 111, check)
		expect.equal(join.fromLobby, true, "fromLobby")
		expect.equal(join.loadout.primary, "service_rifle", "primary")
		expect.equal(join.slot, nil, "slot")
	end,
	["another version of the format is ignored, not trusted"] = function()
		local join =
			Handoff.readJoin(data({ ["111"] = { loadout = good } }, { version = 99 }), 111, check)
		expect.equal(join.fromLobby, false, "fromLobby")
		expect.equal(join.loadout.primary, "service_rifle", "primary")
	end,
	["garbage is ignored"] = function()
		local join = Handoff.readJoin("hello", 111, check)
		expect.equal(join.fromLobby, false)
		local join2 =
			Handoff.readJoin(data({ ["111"] = { slot = "two", loadout = 5 } }), 111, check)
		expect.equal(join2.loadout.primary, "service_rifle", "loadout")
		expect.equal(join2.slot, nil, "slot")
	end,
	["the result the match sends home keeps only the known outcomes"] = function()
		local result = Handoff.result("harlan_corridor", {
			{ id = "delta", outcome = "win", secondaries = 2 },
			{ id = "mile14", outcome = "weird", secondaries = 0 },
		}, true)
		expect.equal(result.version, Handoff.VERSION, "version")
		expect.equal(#result.missions, 2, "missions")
		expect.equal(result.missions[2].outcome, "loss", "unknown outcome")
		expect.equal(result.standDown, true, "standDown")
	end,
}
