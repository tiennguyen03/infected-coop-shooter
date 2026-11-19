--!strict
local Breach = require("../src/shared/Rules/Breach")
local expect = require("./expect")

local S: Breach.Settings = {
	Threshold = { 100, 80 },
	Passive = { 0, 1 },
	TensionAt = 0.5,
	QuietDelay = 5,
	Decay = 10,
	Floor = { 0, 0.4 },
	MaxGainPerSecond = 6,
	RampSeconds = 600,
	WarnSeconds = 3,
	FloodSeconds = 10,
	Relief = { 40, 20 },
	Horde = { Base = 8, PerExtraPlayer = 4, Late = 10, Max = 30 },
	Trickle = { Calm = 2, Tension = 1, Breach = 4, Relief = 3 },
}

return {
	["pressure climbs from 0 to 1 over the ramp and stays there"] = function()
		expect.near(Breach.pressure(S, 0), 0, 1e-9, "start")
		expect.near(Breach.pressure(S, 300), 0.5, 1e-9, "half")
		expect.near(Breach.pressure(S, 9999), 1, 1e-9, "late")
	end,
	["the threshold falls as pressure rises (breaches come sooner late)"] = function()
		expect.near(Breach.threshold(S, 0), 100, 1e-9, "early")
		expect.near(Breach.threshold(S, 600), 80, 1e-9, "late")
	end,
	["relief is shorter late in the run"] = function()
		expect.near(Breach.relief(S, 0), 40, 1e-9, "early")
		expect.near(Breach.relief(S, 600), 20, 1e-9, "late")
	end,
	["a loud moment raises the alert"] = function()
		local state = Breach.new()
		local added = Breach.add(S, state, 15, 0, false)
		expect.near(added, 15, 1e-9, "added")
		expect.near(state.alert, 15, 1e-9, "alert")
	end,
	["sustained gunfire is capped per second"] = function()
		local state = Breach.new()
		for _ = 1, 20 do
			Breach.add(S, state, 1, 0.5, true)
		end
		expect.near(state.alert, 6, 1e-9, "capped in the second")
		Breach.add(S, state, 1, 1.6, true)
		expect.near(state.alert, 7, 1e-9, "a new second has room again")
	end,
	["nothing builds the alert during a breach or the relief after it"] = function()
		local state = Breach.new()
		Breach.start(S, state, 0, 0)
		expect.near(Breach.add(S, state, 50, 1, false), 0, 1e-9, "in the breach")
		state.phase = "Relief"
		expect.near(Breach.add(S, state, 50, 20, false), 0, 1e-9, "in the relief")
	end,
	["going quiet lets the alert fall after the delay"] = function()
		local state = Breach.new()
		Breach.add(S, state, 60, 0, false)
		Breach.step(S, state, 1, 3, 0, false)
		expect.near(state.alert, 60, 1e-9, "still fresh")
		Breach.step(S, state, 1, 6, 0, false)
		expect.near(state.alert, 50, 1e-9, "falling")
		for t = 7, 20 do
			Breach.step(S, state, 1, t, 0, false)
		end
		expect.near(state.alert, 0, 1e-9, "never below zero early")
	end,
	["late in the run the alert never falls below the floor"] = function()
		local state = Breach.new()
		Breach.add(S, state, 60, 0, false)
		for t = 6, 30 do
			Breach.step(S, state, 1, t, 600, false)
		end
		-- floor 0.4 of the late threshold 80 = 32 (passive 1/s pushes against the decay)
		expect.near(state.alert, 32, 1e-9)
	end,
	["tension shows once the alert passes its share of the threshold"] = function()
		local state = Breach.new()
		Breach.add(S, state, 49, 0, false)
		Breach.step(S, state, 0.1, 0.1, 0, false)
		expect.equal(state.phase, "Calm", "below")
		Breach.add(S, state, 2, 0.2, false)
		Breach.step(S, state, 0.1, 0.3, 0, false)
		expect.equal(state.phase, "Tension", "above")
	end,
	["the alert at the threshold calls a breach"] = function()
		local state = Breach.new()
		Breach.add(S, state, 100, 0, false)
		expect.equal(Breach.step(S, state, 0.1, 0.1, 0, false), true)
	end,
	["a blocked field holds the breach back (the Warden, extraction)"] = function()
		local state = Breach.new()
		Breach.add(S, state, 100, 0, false)
		expect.equal(Breach.step(S, state, 0.1, 0.1, 0, true), false)
		expect.equal(Breach.step(S, state, 0.1, 0.2, 0, false), true, "once clear")
	end,
	["a breach runs warning + flood, then the relief, then calm with the alert spent"] = function()
		local state = Breach.new()
		Breach.start(S, state, 0, 0)
		expect.equal(state.phase, "Breach", "breach")
		expect.equal(state.breaches, 1, "counted")
		Breach.step(S, state, 1, 12.9, 0, false)
		expect.equal(state.phase, "Breach", "still flooding")
		Breach.step(S, state, 1, 13, 0, false)
		expect.equal(state.phase, "Relief", "relief")
		Breach.step(S, state, 1, 52.9, 0, false)
		expect.equal(state.phase, "Relief", "relief holds 40 s")
		Breach.step(S, state, 1, 53, 0, false)
		expect.equal(state.phase, "Calm", "calm")
		expect.near(state.alert, 0, 1e-9, "spent")
	end,
	["no second breach while one runs"] = function()
		local state = Breach.new()
		Breach.start(S, state, 0, 0)
		state.alert = 500
		expect.equal(Breach.step(S, state, 0.1, 1, 0, false), false)
	end,
	["a horde grows with players and run time, never past its max or the room left"] = function()
		expect.equal(Breach.hordeSize(S, 0, 0, 0, 44), 8, "solo, early")
		expect.equal(Breach.hordeSize(S, 3, 0, 0, 44), 20, "four players")
		expect.equal(Breach.hordeSize(S, 0, 600, 0, 44), 18, "solo, late")
		expect.equal(Breach.hordeSize(S, 3, 600, 0, 44), 30, "four, late: the max")
		expect.equal(Breach.hordeSize(S, 3, 600, 40, 44), 4, "only the room under the cap")
		expect.equal(Breach.hordeSize(S, 0, 0, 50, 44), 0, "over the cap: none")
	end,
	["the trickle slows in the calm and nearly stops in a breach"] = function()
		expect.near(Breach.trickle(S, "Calm"), 2, 1e-9, "calm")
		expect.near(Breach.trickle(S, "Tension"), 1, 1e-9, "tension")
		expect.near(Breach.trickle(S, "Breach"), 4, 1e-9, "breach")
		expect.near(Breach.trickle(S, "Relief"), 3, 1e-9, "relief")
	end,
	["the horde arrives spread over the flood"] = function()
		local times = Breach.arrivals(5, 10)
		expect.equal(#times, 5, "count")
		expect.near(times[1], 0, 1e-9, "first at once")
		expect.near(times[5], 8, 1e-9, "last inside the flood")
	end,
	["a direction reads as a compass word (+X east, +Z north)"] = function()
		expect.equal(Breach.compass(0, 1), "north", "north")
		expect.equal(Breach.compass(1, 0), "east", "east")
		expect.equal(Breach.compass(-1, -1), "south-west", "south-west")
		expect.equal(Breach.compass(0.2, -1), "south", "near enough south")
	end,
}
