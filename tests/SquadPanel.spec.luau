--!strict
local SquadPanel = require("../src/shared/Rules/SquadPanel")
local expect = require("./expect")

local SETTINGS = { LowFraction = 0.3, BleedOutSeconds = 30, ReviveHold = 3 }

local function input(overrides: { [string]: any }): SquadPanel.Input
	local base: { [string]: any } = {
		state = "Alive",
		health = 100,
		maxHealth = 100,
		shield = 0,
		bleedOutAt = 0,
		reviver = "",
		reviveEndsAt = 0,
		respawnAt = 0,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

return {
	["a healthy member shows a full health bar and no text"] = function()
		local view = SquadPanel.view(input({}), 100, SETTINGS)
		expect.equal(view.status, "Normal", "status")
		expect.equal(view.barKind, "health", "barKind")
		expect.equal(view.bar, 1, "bar")
		expect.equal(view.text, "", "text")
		expect.equal(view.ticking, false, "ticking")
	end,
	["under the low fraction the status is Low"] = function()
		local view = SquadPanel.view(input({ health = 29 }), 100, SETTINGS)
		expect.equal(view.status, "Low", "status")
		expect.near(view.bar, 0.29, 1e-6, "bar")
		expect.equal(SquadPanel.view(input({ health = 30 }), 100, SETTINGS).status, "Normal", "at")
	end,
	["armour is a fraction of max health, capped at 1"] = function()
		expect.near(SquadPanel.view(input({ shield = 25 }), 0, SETTINGS).shield, 0.25, 1e-6, "25")
		expect.equal(SquadPanel.view(input({ shield = 400 }), 0, SETTINGS).shield, 1, "capped")
		expect.equal(
			SquadPanel.view(input({ shield = 25, state = "Dead", health = 0 }), 0, SETTINGS).shield,
			0,
			"dead"
		)
	end,
	["a downed member shows the bleed-out time left on a draining bar"] = function()
		local view = SquadPanel.view(
			input({ state = "Downed", health = 1, bleedOutAt = 115 }),
			100,
			SETTINGS
		)
		expect.equal(view.status, "Downed", "status")
		expect.equal(view.barKind, "bleed", "barKind")
		expect.near(view.bar, 0.5, 1e-6, "bar")
		expect.equal(view.text, "DOWN 15s", "text")
		expect.equal(view.ticking, true, "ticking")
	end,
	["a downed member with no timer yet still reads DOWN"] = function()
		local view = SquadPanel.view(input({ state = "Downed", health = 1 }), 100, SETTINGS)
		expect.equal(view.text, "DOWN", "text")
		expect.equal(view.bar, 0, "bar")
	end,
	["a revive in progress fills the bar and names the state"] = function()
		local view = SquadPanel.view(
			input({
				state = "Downed",
				health = 1,
				bleedOutAt = 115,
				reviver = "Pike One",
				reviveEndsAt = 101.5,
			}),
			100,
			SETTINGS
		)
		expect.equal(view.barKind, "revive", "barKind")
		expect.near(view.bar, 0.5, 1e-6, "bar")
		expect.equal(view.text, "REVIVING", "text")
	end,
	["a reviver without an end time keeps the bleed bar"] = function()
		local view = SquadPanel.view(
			input({ state = "Downed", health = 1, bleedOutAt = 110, reviver = "Pike One" }),
			100,
			SETTINGS
		)
		expect.equal(view.barKind, "bleed", "barKind")
		expect.equal(view.text, "REVIVING", "text")
	end,
	["a dead member is greyed with the respawn time when there is one"] = function()
		local dead = SquadPanel.view(input({ state = "Dead", health = 0 }), 100, SETTINGS)
		expect.equal(dead.status, "Dead", "status")
		expect.equal(dead.barKind, "none", "barKind")
		expect.equal(dead.text, "DEAD", "text")
		expect.equal(dead.ticking, false, "ticking")
		local back =
			SquadPanel.view(input({ state = "Dead", health = 0, respawnAt = 107.2 }), 100, SETTINGS)
		expect.equal(back.text, "DEAD 8s", "text")
		expect.equal(back.ticking, true, "ticking")
		local late =
			SquadPanel.view(input({ state = "Dead", health = 0, respawnAt = 90 }), 100, SETTINGS)
		expect.equal(late.text, "DEAD", "late text")
		expect.equal(late.ticking, false, "late ticking")
	end,
	["a member with no body yet is on standby, not dead"] = function()
		local view = SquadPanel.view(input({ state = false, health = 0 }), 100, SETTINGS)
		expect.equal(view.status, "Standby", "status")
		expect.equal(view.text, "", "text")
		expect.equal(view.barKind, "none", "barKind")
	end,
	["a zero max health never divides by zero"] = function()
		local view = SquadPanel.view(input({ health = 0, maxHealth = 0 }), 0, SETTINGS)
		expect.equal(view.bar, 0, "bar")
	end,
	["a big hit or going down flashes the row; chip damage and healing do not"] = function()
		expect.equal(SquadPanel.flashes("Alive", 100, "Alive", 70, 100, 0.25), true, "big hit")
		expect.equal(SquadPanel.flashes("Alive", 100, "Alive", 90, 100, 0.25), false, "chip")
		expect.equal(SquadPanel.flashes("Alive", 40, "Alive", 100, 100, 0.25), false, "heal")
		expect.equal(SquadPanel.flashes("Alive", 10, "Downed", 1, 100, 0.25), true, "downed")
		expect.equal(SquadPanel.flashes("Downed", 1, "Downed", 1, 100, 0.25), false, "still down")
		expect.equal(SquadPanel.flashes("Downed", 1, "Dead", 0, 100, 0.25), true, "died")
		expect.equal(SquadPanel.flashes(nil, 0, "Alive", 100, 100, 0.25), false, "spawned")
		expect.equal(SquadPanel.flashes(nil, 0, "Dead", 0, 100, 0.25), false, "first seen dead")
		expect.equal(SquadPanel.flashes("Dead", 0, "Dead", 0, 100, 0.25), false, "still dead")
	end,
	["rows follow the callsign order, then the key; the viewer is left out"] = function()
		local callsigns = { "Pike One", "Pike Two", "Pike Three", "Pike Four" }
		local ordered = SquadPanel.order({
			{ key = "b:3", callsign = "Pike Four", userId = 0 },
			{ key = "p:7", callsign = "Pike One", userId = 7 },
			{ key = "b:1", callsign = "Pike Two", userId = 0 },
			{ key = "p:9", callsign = "Pike Two", userId = 9 },
			{ key = "b:2", callsign = "Zed", userId = 0 },
		}, callsigns, 7, 3)
		expect.equal(#ordered, 3, "capped")
		expect.equal(ordered[1].key, "b:1", "first")
		expect.equal(ordered[2].key, "p:9", "second")
		expect.equal(ordered[3].key, "b:3", "third")
	end,
	["an unknown callsign sorts last"] = function()
		local ordered = SquadPanel.order({
			{ key = "b", callsign = "Zed", userId = 0 },
			{ key = "a", callsign = "Pike Two", userId = 0 },
		}, { "Pike One", "Pike Two" }, 1, 3)
		expect.equal(ordered[1].key, "a", "first")
		expect.equal(ordered[2].key, "b", "second")
	end,
}
