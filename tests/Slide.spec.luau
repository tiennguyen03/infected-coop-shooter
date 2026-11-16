--!strict
local Slide = require("../src/shared/Rules/Slide")
local expect = require("./expect")

local S = {
	EntryBoost = 6,
	MinEntrySpeed = 24,
	Friction = 17,
	SlopeAccel = 60,
	MaxSpeed = 40,
	MinSpeed = 14,
	MaxDuration = 6,
}

local SIN15 = math.sin(math.rad(15))
local SIN25 = math.sin(math.rad(25))

return {
	["a slide carries the speed going in, plus the boost"] = function()
		expect.equal(Slide.entrySpeed(24, S), 30, "from a sprint")
		expect.equal(Slide.entrySpeed(31, S), 37, "from a faster body")
	end,
	["a slow entry still gets a slide worth having, a fast one is capped"] = function()
		expect.equal(Slide.entrySpeed(5, S), 24, "floor")
		expect.equal(Slide.entrySpeed(39, S), 40, "cap")
	end,
	["slope is positive downhill, negative uphill, zero on the flat"] = function()
		-- Travelling +X. A floor whose normal leans +X falls away ahead of the body.
		expect.equal(Slide.slope(1, 0, 0, 0), 0, "flat")
		expect.near(Slide.slope(1, 0, SIN15, 0), SIN15, 1e-9, "down")
		expect.near(Slide.slope(-1, 0, SIN15, 0), -SIN15, 1e-9, "up")
		expect.near(Slide.slope(0, 1, SIN15, 0), 0, 1e-9, "across")
	end,
	["flat ground bleeds speed off through friction"] = function()
		expect.near(Slide.step(30, 0, 0.5, S), 21.5, 1e-9)
	end,
	["a flat slide from a sprint lasts about as long as the old fixed one"] = function()
		local speed, seconds = Slide.entrySpeed(24, S), 0
		while not Slide.isOver(speed, seconds, S) do
			speed = Slide.step(speed, 0, 1 / 60, S)
			seconds += 1 / 60
		end
		expect.near(seconds, 0.95, 0.05)
	end,
	["a steep downhill gains a little, up to the cap"] = function()
		local faster = Slide.step(30, SIN25, 0.5, S)
		expect.equal(faster > 30, true, "gains")
		expect.equal(faster < 36, true, "a little")
		expect.equal(Slide.step(39.9, SIN25, 5, S), 40, "capped")
	end,
	["uphill dies quickly"] = function()
		local speed, seconds = 30, 0
		while not Slide.isOver(speed, seconds, S) do
			speed = Slide.step(speed, -SIN15, 1 / 60, S)
			seconds += 1 / 60
		end
		expect.equal(seconds < 0.6, true)
	end,
	["a slide ends under MinSpeed or at MaxDuration"] = function()
		expect.equal(Slide.isOver(14, 0.2, S), true, "too slow")
		expect.equal(Slide.isOver(14.1, 0.2, S), false, "still going")
		expect.equal(Slide.isOver(40, 6, S), true, "time cap")
	end,
	["timeLeft: seconds until it stops on this slope, the time cap when it will not"] = function()
		expect.near(Slide.timeLeft(31, 0, 0, S), 1, 1e-9, "flat")
		expect.equal(Slide.timeLeft(31, SIN25, 2, S), 4, "only the time cap")
		expect.equal(Slide.timeLeft(10, 0, 0, S), 0, "already over")
	end,
}
