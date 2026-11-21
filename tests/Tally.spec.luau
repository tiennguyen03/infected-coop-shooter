--!strict
local Tally = require("../src/shared/Rules/Tally")
local expect = require("./expect")

return {
	["numbers are painted with thousands commas"] = function()
		expect.equal(Tally.format(0), "0", "zero")
		expect.equal(Tally.format(7), "7", "one digit")
		expect.equal(Tally.format(999), "999", "three digits")
		expect.equal(Tally.format(1000), "1,000", "four digits")
		expect.equal(Tally.format(1284), "1,284", "the owner's example")
		expect.equal(Tally.format(1234567), "1,234,567", "seven digits")
		expect.equal(Tally.format(-5), "0", "never below zero")
		expect.equal(Tally.format(12.9), "12", "whole numbers")
	end,
	["a board tag names its kind and id"] = function()
		expect.equal(Tally.key("callin", "hammer"), "callin:hammer", "call-in key")
		local kind, id = Tally.parse("mission:mile14")
		expect.equal(kind, "mission", "kind")
		expect.equal(id, "mile14", "id")
		local k2, i2 = Tally.parse("days")
		expect.equal(k2, "days", "a bare kind")
		expect.equal(i2, "", "no id")
	end,
	["a run's counts add onto the stored totals"] = function()
		local merged = Tally.merge({ ["callin:hammer"] = 10, ["mission:delta"] = 2 }, {
			["callin:hammer"] = 3,
			["callin:anvil"] = 1,
		})
		expect.equal(merged["callin:hammer"], 13, "added")
		expect.equal(merged["callin:anvil"], 1, "new key")
		expect.equal(merged["mission:delta"], 2, "kept")
	end,
	["a missing or broken store starts from nothing"] = function()
		local merged = Tally.merge(nil, { ["callin:hammer"] = 2 })
		expect.equal(merged["callin:hammer"], 2, "from nil")
		local junk = Tally.merge(
			{ ["callin:hammer"] = "lots", [5] = 3, ["callin:anvil"] = -4 } :: any,
			{ ["callin:hammer"] = 1 }
		)
		expect.equal(junk["callin:hammer"], 1, "a non-number is dropped")
		expect.equal(junk["callin:anvil"], nil, "a negative is dropped")
		expect.equal(Tally.merge("nope" :: any, {})["x"], nil, "not a table")
	end,
	["the board shows the start value plus the stored count"] = function()
		local stored = Tally.clean({ ["callin:hammer"] = 16 })
		expect.equal(Tally.shown(1284, stored, "callin:hammer"), 1300, "start + stored")
		expect.equal(Tally.shown(1284, stored, "callin:anvil"), 1284, "nothing stored yet")
		expect.equal(Tally.shown(nil, stored, "callin:hammer"), 16, "no start value")
	end,
	["dates become whole days since 1970 (UTC)"] = function()
		expect.equal(Tally.dayNumber("1970-01-01"), 0, "the epoch")
		expect.equal(Tally.dayNumber("1970-01-02"), 1, "the next day")
		expect.equal(Tally.dayNumber("2000-03-01"), 11017, "after a leap day")
		expect.equal(Tally.dayNumber("2026-11-18") - Tally.dayNumber("2026-04-18"), 214, "214 days")
		expect.equal(Tally.dayNumber("bad"), nil, "not a date")
	end,
	["days since counts whole UTC days and never goes below zero"] = function()
		local start = "2026-04-18"
		local day = 86400
		local launch = Tally.dayNumber("2026-11-18") :: number * day
		expect.equal(Tally.daysSince(start, launch), 214, "on the day")
		expect.equal(Tally.daysSince(start, launch + day - 1), 214, "still the same day")
		expect.equal(Tally.daysSince(start, launch + day), 215, "the next day")
		expect.equal(Tally.daysSince(start, 0), 0, "before the start")
		expect.equal(Tally.daysSince("bad", launch), 0, "a bad date shows 0")
	end,
	["the days board shows one digit per tile"] = function()
		local d = Tally.digits(214, 3)
		expect.equal(#d, 3, "three tiles")
		expect.equal(d[1] .. d[2] .. d[3], "214", "in order")
		local small = Tally.digits(7, 3)
		expect.equal(small[1] .. small[2] .. small[3], "007", "padded")
		local big = Tally.digits(1500, 3)
		expect.equal(big[1] .. big[2] .. big[3], "999", "capped at the tiles")
	end,
}
