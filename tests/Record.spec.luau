--!strict
local Record = require("../src/shared/Rules/Record")
local expect = require("./expect")

-- Prices as the guns' Config rows give them (0 = issued free).
local PRICES: { [string]: number } = {
	service_rifle = 0,
	pistol = 0,
	smg = 300,
	dmr = 500,
	frag = 0,
	incendiary = 200,
	hammer = 0,
	tripline = 0,
	doorman = 400,
}
local function priceOf(id: string): number?
	return PRICES[id]
end

local function loadout(primary: string, secondary: string, grenade: string?, callIns: { string }?)
	return {
		primary = primary,
		secondary = secondary,
		grenade = grenade or "frag",
		callIns = callIns or { "hammer", "tripline" },
	}
end

return {
	["a new record has the starting merits and owns nothing bought"] = function()
		local r = Record.new(1000)
		expect.equal(r.merits, 1000, "merits")
		expect.equal(#r.owned, 0, "owned")
	end,
	["free guns are always on the record"] = function()
		local r = Record.new(0)
		expect.equal(Record.owns(r, "service_rifle", priceOf), true, "rifle")
		expect.equal(Record.owns(r, "pistol", priceOf), true, "pistol")
		expect.equal(Record.owns(r, "smg", priceOf), false, "smg")
	end,
	["buying takes the price and puts the gun on the record"] = function()
		local r, ok = Record.buy(Record.new(1000), "smg", priceOf)
		expect.equal(ok, true, "bought")
		expect.equal(r.merits, 700, "merits left")
		expect.equal(Record.owns(r, "smg", priceOf), true, "owned")
	end,
	["a soldier short of merits cannot buy"] = function()
		local r, ok, reason = Record.buy(Record.new(400), "dmr", priceOf)
		expect.equal(ok, false, "refused")
		expect.equal(reason, "short", "reason")
		expect.equal(r.merits, 400, "merits kept")
	end,
	["exactly enough merits is enough"] = function()
		local r, ok = Record.buy(Record.new(500), "dmr", priceOf)
		expect.equal(ok, true, "bought")
		expect.equal(r.merits, 0, "spent out")
	end,
	["a gun already owned or issued free is not bought again"] = function()
		local r = Record.buy(Record.new(1000), "smg", priceOf)
		local _, again, reason = Record.buy(r, "smg", priceOf)
		expect.equal(again, false, "second buy")
		expect.equal(reason, "owned", "reason")
		local _, free, freeReason = Record.buy(Record.new(1000), "pistol", priceOf)
		expect.equal(free, false, "free gun")
		expect.equal(freeReason, "owned", "free reason")
	end,
	["something without a price cannot be bought"] = function()
		local _, ok, reason = Record.buy(Record.new(1000), "railgun", priceOf)
		expect.equal(ok, false, "refused")
		expect.equal(reason, "unknown", "reason")
	end,
	["buy does not change the record it was given"] = function()
		local before = Record.new(1000)
		Record.buy(before, "smg", priceOf)
		expect.equal(before.merits, 1000, "merits")
		expect.equal(#before.owned, 0, "owned")
	end,
	["a Loadout is allowed only with guns on the record"] = function()
		local r = Record.new(1000)
		expect.equal(
			Record.allows(r, loadout("service_rifle", "pistol"), priceOf),
			true,
			"free kit"
		)
		local ok, reason = Record.allows(r, loadout("smg", "pistol"), priceOf)
		expect.equal(ok, false, "unbought primary")
		expect.equal(reason, "not on record", "reason")
		r = Record.buy(r, "smg", priceOf)
		expect.equal(Record.allows(r, loadout("smg", "pistol"), priceOf), true, "after buying")
	end,
	["a Loadout is allowed only with its grenade and every call-in on the record"] = function()
		local r = Record.new(1000)
		local grenadeOk =
			Record.allows(r, loadout("service_rifle", "pistol", "incendiary"), priceOf)
		expect.equal(grenadeOk, false, "unbought grenade")
		local callInOk = Record.allows(
			r,
			loadout("service_rifle", "pistol", nil, { "hammer", "doorman" }),
			priceOf
		)
		expect.equal(callInOk, false, "unbought call-in")
		r = Record.buy(r, "doorman", priceOf)
		r = Record.buy(r, "incendiary", priceOf)
		expect.equal(
			Record.allows(
				r,
				loadout("service_rifle", "pistol", "incendiary", { "hammer", "doorman" }),
				priceOf
			),
			true,
			"after buying both"
		)
		expect.equal(r.merits, 400, "both paid for")
	end,
	["call-ins and grenades are bought like guns"] = function()
		local r, ok = Record.buy(Record.new(500), "doorman", priceOf)
		expect.equal(ok, true, "call-in bought")
		expect.equal(r.merits, 100, "merits left")
		local _, free, reason = Record.buy(r, "frag", priceOf)
		expect.equal(free, false, "the free grenade")
		expect.equal(reason, "owned", "issued free")
	end,
	["a saved record reads back the same"] = function()
		local r = Record.buy(Record.new(1000), "smg", priceOf)
		local back = Record.decode(Record.encode(r), 1000)
		expect.equal(back.merits, 700, "merits")
		expect.equal(Record.owns(back, "smg", priceOf), true, "owned")
	end,
	["no save, junk or another version reads as a new record"] = function()
		expect.equal(Record.decode(nil, 1000).merits, 1000, "nil")
		expect.equal(Record.decode("junk", 1000).merits, 1000, "string")
		local future = Record.encode(Record.new(5)) :: any
		future.version = Record.VERSION + 1
		expect.equal(Record.decode(future, 1000).merits, 1000, "future version")
	end,
	["a saved record is cleaned on read"] = function()
		local data = {
			version = Record.VERSION,
			merits = -50.5,
			owned = { "smg", "smg", 7, "dmr" },
		}
		local r = Record.decode(data, 1000)
		expect.equal(r.merits, 0, "merits never negative")
		expect.equal(#r.owned, 2, "duplicates and non-strings dropped")
	end,
}
