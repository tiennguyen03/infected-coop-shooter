--!strict
local Objectives = require("../src/shared/Rules/Objectives")
local expect = require("./expect")

local function pool(ids: { string }): { Objectives.Pick }
	local picks = {}
	for _, id in ids do
		table.insert(picks, { Id = id, Weight = 1 })
	end
	return picks
end

local MAIN = pool({ "secure_site", "sanitize", "restore_comms" })
local SIDE = pool({ "silence_alarm", "lights_on", "misdrop", "clear_spitters" })

local function row(kind: string, role: string, map: string?, needs: { string }?): Objectives.Row
	return {
		Kind = kind,
		Map = map,
		Role = role,
		Module = "Module",
		Name = "Name",
		Brief = "Brief",
		Why = "A short reason",
		Done = "Done",
		Needs = needs or {},
	}
end

-- A sound two-objective map, rebuilt for each test so one can break a part of it.
local function sound(): ({ [string]: Objectives.Row }, { [string]: Objectives.Map })
	local rows = {
		burn = row("signature", "main", "delta", { "Points" }),
		hold = row("shared", "main", nil, { "Size" }),
		lamp = row("shared", "side"),
	}
	local maps = {
		delta = {
			Main = pool({ "burn", "hold" }),
			Side = pool({ "lamp" }),
			Sites = {
				burn = { { Name = "the Pens", Position = { 0, 0, 0 }, Points = { { 1, 0, 0 } } } },
				hold = { { Name = "the Yard", Position = { 0, 0, 0 }, Size = { 4, 1, 4 } } },
				lamp = { { Name = "the Depot", Position = { 0, 0, 0 } } },
			},
		},
	}
	return rows, maps
end

local function has(problems: { string }, part: string): boolean
	for _, problem in problems do
		if string.find(problem, part, 1, true) then
			return true
		end
	end
	return false
end

return {
	["a draw takes the pool entry the roll lands on"] = function()
		expect.equal(Objectives.draw(MAIN, nil, 0), "secure_site", "first")
		expect.equal(Objectives.draw(MAIN, nil, 0.5), "sanitize", "middle")
		expect.equal(Objectives.draw(MAIN, nil, 0.999), "restore_comms", "last")
	end,
	["a draw never repeats the last main objective"] = function()
		for step = 0, 99 do
			local drawn = Objectives.draw(MAIN, "sanitize", step / 100)
			expect.equal(drawn ~= "sanitize", true, `roll {step}`)
		end
	end,
	["without the last one, the rest of the pool is drawn evenly"] = function()
		expect.equal(Objectives.draw(MAIN, "secure_site", 0), "sanitize", "low")
		expect.equal(Objectives.draw(MAIN, "secure_site", 0.75), "restore_comms", "high")
	end,
	["a pool of one may repeat (nothing else to draw)"] = function()
		expect.equal(Objectives.draw(pool({ "secure_site" }), "secure_site", 0.4), "secure_site")
	end,
	["an empty pool draws nothing"] = function()
		expect.equal(Objectives.draw({}, nil, 0.4), nil)
	end,
	["a last objective that is not in the pool changes nothing"] = function()
		expect.equal(Objectives.draw(MAIN, "misdrop", 0), "secure_site")
	end,
	["a roll of 1 or more still lands in the pool"] = function()
		expect.equal(Objectives.draw(MAIN, nil, 1), "restore_comms", "one")
		expect.equal(Objectives.draw(MAIN, nil, -0.2), "secure_site", "negative")
	end,
	["side objectives are drawn without repeats"] = function()
		local sides = Objectives.drawSides(SIDE, 2, { 0, 0 })
		expect.equal(#sides, 2, "count")
		expect.equal(sides[1], "silence_alarm", "first")
		expect.equal(sides[2], "lights_on", "second is the next one left")
	end,
	["side objectives stop at the size of the pool"] = function()
		expect.equal(#Objectives.drawSides(pool({ "misdrop" }), 2, { 0.3, 0.9 }), 1)
	end,
	["a forced side objective comes first and is not drawn again"] = function()
		local sides = Objectives.drawSides(SIDE, 2, { 0.6, 0.6 }, "misdrop")
		expect.equal(sides[1], "misdrop", "forced")
		expect.equal(sides[2] ~= "misdrop", true, "no repeat")
		expect.equal(#sides, 2, "count")
	end,
	["a heavier objective is drawn more often"] = function()
		local picks = { { Id = "burn", Weight = 3 }, { Id = "hold", Weight = 1 } }
		expect.equal(Objectives.draw(picks, nil, 0.7), "burn", "inside its share")
		expect.equal(Objectives.draw(picks, nil, 0.8), "hold", "past it")
	end,
	["a pool offers only what it lists"] = function()
		expect.equal(Objectives.offers(MAIN, "sanitize"), true, "listed")
		expect.equal(Objectives.offers(MAIN, "misdrop"), false, "not listed")
		expect.equal(Objectives.offers(MAIN, 5), false, "garbage")
	end,
	["sound pools have no problems"] = function()
		local rows, maps = sound()
		expect.equal(#Objectives.validate(rows, maps), 0)
	end,
	["a map may list only objectives that exist"] = function()
		local rows, maps = sound()
		table.insert(maps.delta.Side, { Id = "ghost", Weight = 1 })
		expect.equal(has(Objectives.validate(rows, maps), 'no objective "ghost"'), true)
	end,
	["every map needs a signature main objective of its own"] = function()
		local rows, maps = sound()
		maps.delta.Main = pool({ "hold" })
		expect.equal(has(Objectives.validate(rows, maps), "no signature main objective"), true)
	end,
	["a signature objective is never offered on another map"] = function()
		local rows, maps = sound()
		rows.toll = row("signature", "main", "mile14")
		maps.mile14 = {
			Main = pool({ "toll", "burn" }),
			Side = {},
			Sites = {
				toll = { { Name = "the Toll Plaza", Position = { 0, 0, 0 } } },
				burn = { { Name = "the buses", Position = { 0, 0, 0 }, Points = {} } },
			},
		}
		expect.equal(
			has(Objectives.validate(rows, maps), "mile14: burn is delta's signature"),
			true
		)
	end,
	["a listed objective needs a site with everything it needs"] = function()
		local rows, maps = sound()
		maps.delta.Sites.lamp = nil
		maps.delta.Sites.hold = { { Name = "the Yard", Position = { 0, 0, 0 } } }
		local problems = Objectives.validate(rows, maps)
		expect.equal(has(problems, "delta: lamp has no site"), true, "no site")
		expect.equal(has(problems, "delta: hold site 1 has no Size"), true, "missing field")
	end,
	["an objective sits in the pool of its role, once, with a weight"] = function()
		local rows, maps = sound()
		maps.delta.Side = {
			{ Id = "lamp", Weight = 0 },
			{ Id = "lamp", Weight = 1 },
			{ Id = "hold", Weight = 1 },
		}
		local problems = Objectives.validate(rows, maps)
		expect.equal(has(problems, "lamp needs a weight above 0"), true, "weight")
		expect.equal(has(problems, "lamp is listed twice"), true, "twice")
		expect.equal(has(problems, "hold is a main objective in the side pool"), true, "role")
	end,
	["a row needs its words, and a reason short enough to read in a fight"] = function()
		local rows, maps = sound()
		rows.lamp.Done = ""
		rows.hold.Why = "one two three four five six seven eight nine"
		local problems = Objectives.validate(rows, maps)
		expect.equal(has(problems, "lamp: no Done"), true, "words")
		expect.equal(has(problems, "hold: Why is over 8 words"), true, "length")
	end,
	["Control calls out each unfound side objective later than the last"] = function()
		expect.equal(Objectives.revealAt(1, 90), 90, "first")
		expect.equal(Objectives.revealAt(2, 90), 180, "second")
	end,
	["a place index comes from the roll"] = function()
		expect.equal(Objectives.pick(3, 0), 1, "low")
		expect.equal(Objectives.pick(3, 0.5), 2, "middle")
		expect.equal(Objectives.pick(3, 0.99), 3, "high")
		expect.equal(Objectives.pick(3, 1), 3, "clamped")
		expect.equal(Objectives.pick(0, 0.5), 0, "nothing to pick")
	end,
	["a count grows per extra player"] = function()
		expect.equal(Objectives.scaled(3, 1, 0), 3, "solo")
		expect.equal(Objectives.scaled(3, 1, 3), 6, "four players")
		expect.equal(Objectives.scaled(3, nil, 3), 3, "no share")
	end,
	["a hold adds time only while someone holds it, and stops at the total"] = function()
		expect.near(Objectives.hold(10, 0.5, true, 45), 10.5, 1e-9, "held")
		expect.near(Objectives.hold(10, 0.5, false, 45), 10, 1e-9, "empty")
		expect.near(Objectives.hold(44.9, 0.5, true, 45), 45, 1e-9, "capped")
	end,
	["a timer runs down to zero and no further"] = function()
		expect.near(Objectives.countdown(10, 0.5), 9.5, 1e-9, "running")
		expect.near(Objectives.countdown(0.2, 0.5), 0, 1e-9, "floor")
	end,
	["the bar is the share done, and hidden with nothing to count"] = function()
		expect.near(Objectives.fraction(15, 45) :: number, 1 / 3, 1e-9, "third")
		expect.near(Objectives.fraction(50, 45) :: number, 1, 1e-9, "capped")
		expect.equal(Objectives.fraction(0, 0), nil, "no total")
	end,
	["progress reads as seconds, a count, or nothing"] = function()
		expect.equal(Objectives.progressText(12.7, 45, "s"), "12 of 45s", "seconds")
		expect.equal(Objectives.progressText(2, 3, "count"), "2 of 3", "count")
		expect.equal(Objectives.progressText(0, 0, ""), "", "nothing")
	end,
	["time left reads as minutes and seconds"] = function()
		expect.equal(Objectives.clock(240), "4:00", "four minutes")
		expect.equal(Objectives.clock(61.2), "1:02", "rounds up")
		expect.equal(Objectives.clock(0), "0:00", "zero")
		expect.equal(Objectives.clock(-3), "0:00", "never negative")
	end,
	["a line names its place"] = function()
		expect.equal(
			Objectives.fill("We lost {place}. Take it back.", "the Pens"),
			"We lost the Pens. Take it back.",
			"filled"
		)
		expect.equal(Objectives.fill("No place here.", "the Pens"), "No place here.", "untouched")
		expect.equal(Objectives.fill("At {place}.", "100% of it"), "At 100% of it.", "no patterns")
		expect.equal(
			Objectives.fill("From {place} to {to}.", "the Ridge", "the comm tower"),
			"From the Ridge to the comm tower.",
			"both"
		)
	end,
	["distance reads in whole metres"] = function()
		expect.equal(Objectives.metres(50, 0.28), 14)
	end,
	["a bearing is the turn from where the camera looks to the target"] = function()
		-- Looking down -Z (Roblox forward): +X is to the right.
		expect.near(Objectives.bearing(0, -1, 0, -10), 0, 1e-6, "ahead")
		expect.near(Objectives.bearing(0, -1, 10, 0), 90, 1e-6, "right")
		expect.near(Objectives.bearing(0, -1, -10, 0), -90, 1e-6, "left")
		expect.near(math.abs(Objectives.bearing(0, -1, 0, 10)), 180, 1e-6, "behind")
		expect.near(Objectives.bearing(0, 0, 0, 0), 0, 1e-6, "nothing to point at")
	end,
	["a board entry is live until it is done or failed"] = function()
		expect.equal(Objectives.isOpen("pending"), true, "pending")
		expect.equal(Objectives.isOpen("active"), true, "active")
		expect.equal(Objectives.isOpen("done"), false, "done")
		expect.equal(Objectives.isOpen("failed"), false, "failed")
	end,
}
