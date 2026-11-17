--!strict
local Arrival = require("../src/shared/Rules/Arrival")
local expect = require("./expect")

return {
	["a row's own Arrival values win over the defaults"] = function()
		local defaults = { Style = "thrown", Time = 0, Throw = 0.45 }
		local resolved = Arrival.resolve(defaults, { Style = "mortar", Time = 2 })
		expect.equal(resolved.Style, "mortar", "style")
		expect.equal(resolved.Time, 2, "time")
		expect.equal(resolved.Throw, 0.45, "throw falls back")
		expect.equal(defaults.Style, "thrown", "defaults untouched")
	end,
	["a row without an Arrival block gets every default"] = function()
		local resolved = Arrival.resolve({ Style = "thrown", Time = 0, Throw = 0.45 }, nil)
		expect.equal(resolved.Style, "thrown", "style")
		expect.equal(resolved.Time, 0, "time")
	end,
	["the server waits the arrival's Time, and not at all when arrivals are off"] = function()
		expect.equal(Arrival.deployDelay({ Style = "case", Time = 2.2, Throw = 0.45 }, true), 2.2)
		expect.equal(Arrival.deployDelay({ Style = "case", Time = 2.2, Throw = 0.45 }, false), 0)
		expect.equal(Arrival.deployDelay({ Style = "thrown", Time = -1, Throw = 0.45 }, true), 0)
	end,
	["progress runs 0 to 1 between two times and holds outside them"] = function()
		expect.equal(Arrival.progress(0, 1, 3), 0, "before")
		expect.equal(Arrival.progress(2, 1, 3), 0.5, "middle")
		expect.equal(Arrival.progress(9, 1, 3), 1, "after")
		expect.equal(Arrival.progress(0.5, 1, 1), 0, "empty span, before")
		expect.equal(Arrival.progress(1, 1, 1), 1, "empty span, at")
	end,
	["a free fall starts slow and lands exactly at the end"] = function()
		expect.equal(Arrival.fall(0, 1, 2, 50), 50, "still up before the kick")
		expect.near(Arrival.fall(1.5, 1, 2, 50), 37.5, 0.001, "half the time, a quarter of the way")
		expect.equal(Arrival.fall(2, 1, 2, 50), 0, "landed")
		expect.equal(Arrival.fall(5, 1, 2, 50), 0, "stays down")
	end,
	["a drop under a chute comes down at a steady rate"] = function()
		expect.near(Arrival.drift(1.5, 1, 2, 40), 20, 0.001, "half way")
		expect.equal(Arrival.drift(2, 1, 2, 40), 0, "landed")
	end,
	["a hop leaves the ground and comes back to it"] = function()
		expect.equal(Arrival.hop(0, 1, 2, 3), 0, "before")
		expect.near(Arrival.hop(1.5, 1, 2, 3), 3, 0.001, "apex")
		expect.equal(Arrival.hop(2, 1, 2, 3), 0, "down")
	end,
	["easeOut is fast first and ends at 1"] = function()
		expect.equal(Arrival.easeOut(0), 0, "start")
		expect.near(Arrival.easeOut(0.5), 0.75, 0.001, "ahead of linear")
		expect.equal(Arrival.easeOut(1), 1, "end")
	end,
	["a shell comes in from behind and above, and ends on the mark"] = function()
		local back, up = Arrival.shellOffset(90, 100, 1)
		expect.near(back, 0, 0.001, "straight down: no way back")
		expect.near(up, 100, 0.001, "straight down: all height")
		back, up = Arrival.shellOffset(60, 200, 0.5)
		expect.near(back, 50, 0.001, "half way in, back")
		expect.near(up, 86.6025, 0.001, "half way in, up")
		back, up = Arrival.shellOffset(60, 200, 0)
		expect.equal(back, 0, "on the mark")
		expect.equal(up, 0, "on the ground")
	end,
	["a cue never plays before the marker has landed"] = function()
		expect.equal(Arrival.cueTime(5, 1.5, 0.45), 3.5, "lead before the impact")
		expect.equal(Arrival.cueTime(1, 2.4, 0.45), 0.45, "held until the throw lands")
	end,
	["the mines' arc is spread evenly either side of the throw"] = function()
		local angles = Arrival.arcAngles(6, 160)
		expect.equal(#angles, 6, "count")
		expect.near(angles[1], -math.rad(80), 0.0001, "first")
		expect.near(angles[6], math.rad(80), 0.0001, "last")
		expect.near(angles[3] + angles[4], 0, 0.0001, "symmetric")
		local one = Arrival.arcAngles(1, 160)
		expect.equal(one[1], 0, "a single mine sits on the throw")
	end,
	["lane marks are centred on the mark and never further apart than asked"] = function()
		local marks = Arrival.lane(46, 6)
		expect.equal(#marks, 8, "count")
		expect.near(marks[1] + marks[8], 0, 0.0001, "centred")
		expect.near(marks[2] - marks[1], 6, 0.0001, "spacing")
		expect.equal(#Arrival.lane(2, 6), 1, "a short lane still has one")
		expect.equal(Arrival.lane(2, 6)[1], 0, "on the mark")
		expect.equal(#Arrival.lane(46, 0), 1, "no spacing: one mark, no endless loop")
	end,
	["the gunship is over the first burst when it lands and gone after the run"] = function()
		-- Delay 4, Approach 1.5, 10 bursts 0.15 apart: in the air from 2.5 for 4.35 s
		local startsAt, seconds = Arrival.pass(4, 1.5, 10, 0.15)
		expect.near(startsAt, 2.5, 0.0001, "starts")
		expect.near(seconds, 4.35, 0.0001, "seconds")
		expect.equal(Arrival.passFraction(1, startsAt, seconds), nil, "not yet in the air")
		expect.near(Arrival.passFraction(4, startsAt, seconds) :: number, 1.5 / 4.35, 0.0001)
		expect.equal(Arrival.passFraction(7, startsAt, seconds), nil, "gone")
		local early = Arrival.pass(1, 1.5, 10, 0.15)
		expect.equal(early, 0, "a short delay shortens the approach")
	end,
}
