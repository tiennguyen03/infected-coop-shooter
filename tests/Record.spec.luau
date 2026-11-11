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
	-- Merits earned on missions, and tabs (the hard currency).
	["a new record holds no tabs and no receipts"] = function()
		local r = Record.new(1000)
		expect.equal(r.tabs, 0, "tabs")
		expect.equal(#r.receipts, 0, "receipts")
	end,
	["earning adds whole merits and never takes any"] = function()
		local r = Record.earn(Record.new(100), 150)
		expect.equal(r.merits, 250, "earned")
		expect.equal(Record.earn(r, 10.9).merits, 260, "floored")
		expect.equal(Record.earn(r, -40).merits, 250, "never negative pay")
		expect.equal(Record.earn(r, 0 / 0).merits, 250, "not a number")
	end,
	["earning does not change the record it was given, and keeps kit and tabs"] = function()
		local before = Record.grantTabs(Record.buy(Record.new(1000), "smg", priceOf), 40)
		local after = Record.earn(before, 120)
		expect.equal(before.merits, 700, "before")
		expect.equal(after.merits, 820, "after")
		expect.equal(after.tabs, 40, "tabs kept")
		expect.equal(Record.owns(after, "smg", priceOf), true, "kit kept")
	end,
	["buying with merits leaves tabs and receipts alone"] = function()
		local r = Record.grantReceipt(Record.new(1000), "p1", 80, 50)
		r = Record.buy(r, "smg", priceOf)
		expect.equal(r.tabs, 80, "tabs")
		expect.equal(#r.receipts, 1, "receipts")
	end,
	["tabs are granted in whole positive amounts"] = function()
		local r, ok = Record.grantTabs(Record.new(0), 100)
		expect.equal(ok, true, "granted")
		expect.equal(r.tabs, 100, "tabs")
		expect.equal(r.merits, 0, "merits untouched")
		for _, bad in { 0, -5, 2.5, 0 / 0, math.huge } do
			local same, badOk, reason = Record.grantTabs(r, bad)
			expect.equal(badOk, false, "refused")
			expect.equal(reason, "invalid", "reason")
			expect.equal(same.tabs, 100, "tabs kept")
		end
	end,
	["tabs are spent like merits: enough is enough, short is refused"] = function()
		local r = Record.grantTabs(Record.new(0), 100)
		local after, ok = Record.spendTabs(r, 100)
		expect.equal(ok, true, "spent")
		expect.equal(after.tabs, 0, "spent out")
		expect.equal(r.tabs, 100, "the record given is unchanged")
		local same, shortOk, reason = Record.spendTabs(r, 101)
		expect.equal(shortOk, false, "short")
		expect.equal(reason, "short", "reason")
		expect.equal(same.tabs, 100, "kept")
		local _, badOk, badReason = Record.spendTabs(r, -1)
		expect.equal(badOk, false, "negative")
		expect.equal(badReason, "invalid", "reason")
	end,
	["a receipt grants its tabs once"] = function()
		local r, granted = Record.grantReceipt(Record.new(0), "p1", 80, 50)
		expect.equal(granted, true, "first")
		expect.equal(r.tabs, 80, "tabs")
		local again, second = Record.grantReceipt(r, "p1", 80, 50)
		expect.equal(second, false, "second")
		expect.equal(again.tabs, 80, "not paid twice")
		expect.equal(Record.hasReceipt(again, "p1"), true, "remembered")
	end,
	["a receipt with a bad id or amount grants nothing"] = function()
		local r, emptyId = Record.grantReceipt(Record.new(0), "", 80, 50)
		expect.equal(emptyId, false, "empty id")
		local _, zero = Record.grantReceipt(r, "p1", 0, 50)
		expect.equal(zero, false, "zero tabs")
		expect.equal(r.tabs, 0, "tabs")
	end,
	["only the newest receipts are kept"] = function()
		local r = Record.new(0)
		for i = 1, 53 do
			r = Record.grantReceipt(r, `p{i}`, 10, 50)
		end
		expect.equal(#r.receipts, 50, "kept")
		expect.equal(r.tabs, 530, "every one paid")
		expect.equal(Record.hasReceipt(r, "p53"), true, "newest")
		expect.equal(Record.hasReceipt(r, "p3"), false, "oldest dropped")
		expect.equal(r.receipts[50], "p53", "newest last")
	end,
	["tabs and receipts save and read back"] = function()
		local r = Record.grantReceipt(Record.new(1000), "p1", 80, 50)
		local saved = Record.encode(r)
		expect.equal(saved.version, 2, "version")
		local back = Record.decode(saved, 1000)
		expect.equal(back.tabs, 80, "tabs")
		expect.equal(Record.hasReceipt(back, "p1"), true, "receipt")
	end,
	["a version 1 save keeps its merits and kit and gets 0 tabs"] = function()
		local old = { version = 1, merits = 640, owned = { "smg" } }
		local r = Record.decode(old, 1000)
		expect.equal(r.merits, 640, "merits")
		expect.equal(Record.owns(r, "smg", priceOf), true, "kit")
		expect.equal(r.tabs, 0, "tabs")
		expect.equal(#r.receipts, 0, "receipts")
		expect.equal(Record.encode(r).version, 2, "saved forward")
	end,
	["saved tabs and receipts are cleaned on read"] = function()
		local data = {
			version = 2,
			merits = 10,
			owned = {},
			tabs = -3.5,
			receipts = { "p1", 4, "p1", "", "p2" },
		}
		local r = Record.decode(data, 1000)
		expect.equal(r.tabs, 0, "tabs never negative")
		expect.equal(#r.receipts, 2, "junk and duplicates dropped")
		local noTabs = Record.decode({ version = 2, merits = 10, owned = {} }, 1000)
		expect.equal(noTabs.tabs, 0, "missing tabs")
		expect.equal(noTabs.merits, 10, "merits kept")
	end,
	["only a missing save or one this code can read may be updated in place"] = function()
		expect.equal(Record.canUpdate(nil), true, "a new soldier")
		expect.equal(Record.canUpdate({ version = 1, merits = 5, owned = {} }), true, "v1")
		expect.equal(Record.canUpdate(Record.encode(Record.new(5))), true, "current")
		expect.equal(Record.canUpdate("junk"), false, "junk")
		expect.equal(Record.canUpdate({ version = 3, merits = 5 }), false, "a newer version")
		expect.equal(Record.canUpdate({ version = 2, merits = "x" }), false, "bad merits")
	end,
	["the DataStore key is the same for the lobby and the match"] = function()
		expect.equal(Record.key(12345), "r_12345", "key")
		expect.equal(Record.KEY_PREFIX, "r_", "prefix")
	end,
}
