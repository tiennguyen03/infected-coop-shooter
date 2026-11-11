--!strict
local Manifest = require("../src/shared/Rules/Manifest")
local expect = require("./expect")

local SETTINGS: Manifest.Settings = { capacity = 4, countdown = 20, fullCountdown = 5 }

return {
	["an empty spot has no one aboard and no lift time"] = function()
		local m = Manifest.new()
		m = Manifest.update(m, {}, 0, SETTINGS)
		expect.equal(#m.aboard, 0, "aboard")
		expect.equal(m.liftAt, nil, "liftAt")
	end,
	["the first soldier on the spot starts the countdown"] = function()
		local m = Manifest.update(Manifest.new(), { 11 }, 100, SETTINGS)
		expect.equal(#m.aboard, 1, "aboard")
		expect.equal(m.liftAt, 120, "liftAt")
	end,
	["a second soldier keeps the running countdown"] = function()
		local m = Manifest.update(Manifest.new(), { 11 }, 100, SETTINGS)
		m = Manifest.update(m, { 11, 22 }, 110, SETTINGS)
		expect.equal(#m.aboard, 2, "aboard")
		expect.equal(m.liftAt, 120, "liftAt")
	end,
	["boarding order is kept and newcomers go to the back"] = function()
		local m = Manifest.update(Manifest.new(), { 11, 22 }, 0, SETTINGS)
		m = Manifest.update(m, { 33, 22, 11 }, 1, SETTINGS)
		expect.equal(m.aboard[1], 11, "first")
		expect.equal(m.aboard[2], 22, "second")
		expect.equal(m.aboard[3], 33, "third")
	end,
	["a soldier who steps off leaves the manifest"] = function()
		local m = Manifest.update(Manifest.new(), { 11, 22 }, 0, SETTINGS)
		m = Manifest.update(m, { 22 }, 1, SETTINGS)
		expect.equal(#m.aboard, 1, "aboard")
		expect.equal(m.aboard[1], 22, "who stays")
		expect.equal(m.liftAt, 20, "countdown kept")
	end,
	["everyone stepping off clears the countdown"] = function()
		local m = Manifest.update(Manifest.new(), { 11 }, 0, SETTINGS)
		m = Manifest.update(m, {}, 5, SETTINGS)
		expect.equal(m.liftAt, nil, "liftAt")
	end,
	["a full bird shortens the countdown"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		m = Manifest.update(m, { 1, 2, 3, 4 }, 2, SETTINGS)
		expect.equal(m.liftAt, 7, "liftAt")
	end,
	["a full bird never lengthens a countdown already shorter"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		m = Manifest.update(m, { 1, 2, 3, 4 }, 18, SETTINGS)
		expect.equal(m.liftAt, 20, "liftAt")
	end,
	["a fifth soldier on the spot is left off"] = function()
		local m = Manifest.update(Manifest.new(), { 1, 2, 3, 4, 5 }, 0, SETTINGS)
		expect.equal(#m.aboard, 4, "aboard")
		expect.equal(Manifest.isAboard(m, 5), false, "fifth")
		expect.equal(Manifest.isAboard(m, 4), true, "fourth")
	end,
	["the bird lifts when the countdown runs out"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		expect.equal(Manifest.due(m, 19.9), false, "before")
		expect.equal(Manifest.due(m, 20), true, "at")
	end,
	["an empty spot is never due"] = function()
		expect.equal(Manifest.due(Manifest.new(), 1000), false, "due")
	end,
	["update does not change the manifest it was given"] = function()
		local before = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		Manifest.update(before, { 1, 2 }, 1, SETTINGS)
		expect.equal(#before.aboard, 1, "aboard")
	end,
	["a solo pick shortens the countdown at once"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		local ok
		m, ok = Manifest.setSquad(m, 1, 1, 2, SETTINGS)
		expect.equal(ok, true, "accepted")
		expect.equal(m.squad, 1, "squad")
		expect.equal(m.liftAt, 7, "liftAt")
	end,
	["a squad of two lifts early once the second soldier boards"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		m = Manifest.setSquad(m, 1, 2, 1, SETTINGS)
		expect.equal(m.liftAt, 20, "still waiting for the second")
		m = Manifest.update(m, { 1, 2 }, 4, SETTINGS)
		expect.equal(m.liftAt, 9, "full at two")
	end,
	["only the first soldier aboard picks the squad size"] = function()
		local m = Manifest.update(Manifest.new(), { 1, 2 }, 0, SETTINGS)
		local after, ok = Manifest.setSquad(m, 2, 2, 1, SETTINGS)
		expect.equal(ok, false, "second soldier refused")
		expect.equal(after.squad, nil, "squad unchanged")
		local _, offOk = Manifest.setSquad(m, 9, 1, 1, SETTINGS)
		expect.equal(offOk, false, "someone not aboard refused")
	end,
	["a squad size outside 1 to capacity is refused"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		local _, low = Manifest.setSquad(m, 1, 0, 1, SETTINGS)
		local _, high = Manifest.setSquad(m, 1, 5, 1, SETTINGS)
		local _, half = Manifest.setSquad(m, 1, 1.5, 1, SETTINGS)
		expect.equal(low, false, "zero")
		expect.equal(high, false, "over capacity")
		expect.equal(half, false, "not a whole number")
	end,
	["a squad size never lengthens a shorter countdown"] = function()
		local m = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		m = Manifest.setSquad(m, 1, 1, 18, SETTINGS)
		expect.equal(m.liftAt, 20, "liftAt")
	end,
	["the squad size is kept while someone is aboard and cleared when the spot empties"] = function()
		local m = Manifest.update(Manifest.new(), { 1, 2 }, 0, SETTINGS)
		m = Manifest.setSquad(m, 1, 3, 0, SETTINGS)
		m = Manifest.update(m, { 1, 2 }, 1, SETTINGS)
		expect.equal(m.squad, 3, "kept")
		m = Manifest.update(m, {}, 2, SETTINGS)
		expect.equal(m.squad, nil, "cleared")
	end,
	["setSquad does not change the manifest it was given"] = function()
		local before = Manifest.update(Manifest.new(), { 1 }, 0, SETTINGS)
		Manifest.setSquad(before, 1, 1, 1, SETTINGS)
		expect.equal(before.squad, nil, "squad")
		expect.equal(before.liftAt, 20, "liftAt")
	end,
}
