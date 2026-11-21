--!strict
-- Kit that unlocks with missions won in a city district (src/shared/Rules/DistrictUnlock.luau;
-- loop sprint 4): an item row's optional `Unlock = { District, Wins }` against the soldier's
-- record (`wins`, Rules/Record.win). Still bought with merits: this only opens the sale.

local DistrictUnlock = require("../src/shared/Rules/DistrictUnlock")

local function eq(actual: unknown, expected: unknown, what: string)
	if actual ~= expected then
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["an item with no Unlock is open"] = function()
		eq(DistrictUnlock.met(nil, {}), true, "no unlock")
	end,

	["enough wins in the district opens it"] = function()
		local unlock = { District = "MILE 14", Wins = 3 }
		eq(DistrictUnlock.met(unlock, { ["MILE 14"] = 3 }), true, "three")
		eq(DistrictUnlock.met(unlock, { ["MILE 14"] = 5 }), true, "more")
	end,

	["too few wins, or wins elsewhere, keep it shut"] = function()
		local unlock = { District = "MILE 14", Wins = 3 }
		eq(DistrictUnlock.met(unlock, { ["MILE 14"] = 2 }), false, "two")
		eq(DistrictUnlock.met(unlock, { DELTA = 9 }), false, "wrong district")
		eq(DistrictUnlock.met(unlock, {}), false, "none")
	end,

	["a malformed Unlock never opens by accident"] = function()
		eq(
			DistrictUnlock.met({ District = "MILE 14" } :: any, { ["MILE 14"] = 99 }),
			false,
			"no Wins"
		)
		eq(DistrictUnlock.met({ Wins = 1 } :: any, { ["MILE 14"] = 99 }), false, "no District")
	end,

	["text says what it takes, in plain words"] = function()
		eq(
			DistrictUnlock.text({ District = "MILE 14", Wins = 3 }, { ["MILE 14"] = 1 }),
			"WIN 3 AT MILE 14 (1/3)",
			"progress"
		)
		eq(
			DistrictUnlock.text({ District = "DELTA", Wins = 1 }, {}),
			"WIN 1 AT DELTA (0/1)",
			"none yet"
		)
		eq(DistrictUnlock.text(nil, {}), "", "open")
	end,

	["need is the refusal line"] = function()
		eq(
			DistrictUnlock.need({ District = "MILE 14", Wins = 3 }),
			"Win 3 missions at MILE 14 first.",
			"three"
		)
		eq(
			DistrictUnlock.need({ District = "DELTA", Wins = 1 }),
			"Win a mission at DELTA first.",
			"one"
		)
		eq(DistrictUnlock.need(nil), "", "none")
	end,
}
