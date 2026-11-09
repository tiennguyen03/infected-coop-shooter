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
	["what the lobby builds is what the match reads"] = function()
		local sent = Handoff.departure("harlan_corridor", { 111, 222 }, { [111] = good })
		local first = Handoff.readJoin(sent, 111, check)
		expect.equal(first.fromLobby, true, "fromLobby")
		expect.equal(first.slot, 1, "boarding order is the slot")
		expect.equal(first.loadout.primary, "smg", "loadout carried")
		expect.equal(first.partySize, 2, "party size")
		local second = Handoff.readJoin(sent, 222, check)
		expect.equal(second.slot, 2, "second aboard")
		expect.equal(second.loadout.primary, "service_rifle", "no loadout sent: the default")
	end,
	["a lift never carries more than four"] = function()
		local sent = Handoff.departure("harlan_corridor", { 1, 2, 3, 4, 5 }, nil)
		local join = Handoff.readJoin(sent, 5, check)
		expect.equal(join.partySize, 4, "party size")
		expect.equal(join.slot, nil, "the fifth is not aboard")
	end,
	["a mission's outcome: extracted wins, a wipe after the Primary is partial, else a loss"] = function()
		expect.equal(Handoff.outcome("Extracted", true), "win", "extracted")
		expect.equal(Handoff.outcome("Extracted", false), "win", "extracted early")
		expect.equal(Handoff.outcome("Wiped", true), "partial", "wiped after the Primary")
		expect.equal(Handoff.outcome("Wiped", false), "loss", "wiped before it")
	end,
	["the lobby reads back what the match sent home"] = function()
		local sent = Handoff.result(
			"harlan_corridor",
			{ { id = "delta", outcome = "partial", secondaries = 1 } },
			false
		)
		local read = Handoff.readResult(sent)
		expect.equal(read ~= nil, true, "read")
		local result = read :: Handoff.Result
		expect.equal(result.missions[1].id, "delta", "mission")
		expect.equal(result.missions[1].outcome, "partial", "outcome")
		expect.equal(result.standDown, false, "standDown")
	end,
	["a result in any other shape is ignored"] = function()
		expect.equal(Handoff.readResult(nil), nil, "nothing")
		expect.equal(Handoff.readResult("hello"), nil, "garbage")
		local wrongVersion = Handoff.result("harlan_corridor", {}, true) :: any
		wrongVersion.version = 99
		expect.equal(Handoff.readResult(wrongVersion), nil, "version")
		local badOutcome = Handoff.result(
			"harlan_corridor",
			{ { id = "delta", outcome = "win", secondaries = 0 } },
			true
		) :: any
		badOutcome.missions[1].outcome = "flawless"
		expect.equal(Handoff.readResult(badOutcome), nil, "outcome")
	end,
}
