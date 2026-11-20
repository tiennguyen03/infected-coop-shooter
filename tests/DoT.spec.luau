--!strict
-- Damage over time (Rules/DoT): the one burn rule, first used by the Mossberg's Dragon's
-- Breath; the Cauterizer's fire and the Leech's acid reuse it. Written before the rule.
local DoT = require("../src/shared/Rules/DoT")
local expect = require("./expect")

local function near(actual: number, expected: number, message: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{message}: expected {expected}, got {actual}`)
	end
end

-- Ticks every `step` seconds from `from` to `to`; the total paid.
local function run(state: DoT.State, from: number, to: number, step: number): number
	local total = 0
	local t = from
	while t < to - 1e-9 do
		t = math.min(t + step, to)
		total += DoT.tick(state, t)
	end
	return total
end

return {
	["one stack pays its whole damage over its seconds"] = function()
		local state = DoT.new()
		expect.equal(DoT.add(state, 0, 15, 5, 8), true, "added")
		near(run(state, 0, 5, 0.5), 15, "15 over 5 s")
		expect.equal(DoT.active(state, 5), false, "spent at 5 s")
	end,
	["a tick pays only the time since the last one"] = function()
		local state = DoT.new()
		DoT.add(state, 0, 15, 5, 8)
		near(DoT.tick(state, 1), 3, "3 per second")
		near(DoT.tick(state, 1), 0, "nothing twice for the same second")
		near(DoT.tick(state, 2.5), 4.5, "1.5 s more")
		near(DoT.remaining(state, 2.5), 7.5, "what is still to come")
	end,
	["a late tick never pays past the end"] = function()
		local state = DoT.new()
		DoT.add(state, 0, 15, 5, 8)
		near(DoT.tick(state, 60), 15, "the whole burn, no more")
		near(DoT.tick(state, 61), 0, "then nothing")
	end,
	["stacks add: eight pellet hits burn eight times as hard"] = function()
		local state = DoT.new()
		for _ = 1, 8 do
			DoT.add(state, 0, 15, 5, 8)
		end
		near(DoT.tick(state, 1), 24, "8 x 3 per second")
		near(run(state, 1, 5, 0.5), 96, "the rest")
	end,
	["each stack keeps its own clock"] = function()
		local state = DoT.new()
		DoT.add(state, 0, 15, 5, 8)
		DoT.add(state, 2, 15, 5, 8)
		near(DoT.tick(state, 5), 15 + 9, "the first done, the second 3 s in")
		expect.equal(DoT.active(state, 5), true, "the second still burns")
		near(DoT.tick(state, 7), 6, "the second's last 2 s")
		expect.equal(DoT.active(state, 7), false, "both spent")
	end,
	["past the cap a fresh stack replaces the one ending soonest"] = function()
		local state = DoT.new()
		DoT.add(state, 0, 10, 5, 2) -- ends 5
		DoT.add(state, 1, 10, 5, 2) -- ends 6
		DoT.add(state, 2, 10, 5, 2) -- replaces the first: ends 7
		expect.equal(#state.stacks, 2, "never more than the cap")
		-- What the first stack paid before it was replaced is lost; the new one starts at 2.
		near(DoT.remaining(state, 2), 8 + 10, "the second's 8 left and the new 10")
	end,
	["nonsense adds nothing"] = function()
		local state = DoT.new()
		expect.equal(DoT.add(state, 0, 0, 5, 8), false, "no damage")
		expect.equal(DoT.add(state, 0, 15, 0, 8), false, "no seconds")
		expect.equal(DoT.add(state, 0, 0 / 0, 5, 8), false, "NaN")
		expect.equal(DoT.add(state, 0, math.huge, 5, 8), false, "infinite")
		expect.equal(DoT.add(state, 0, 15, 5, 0), false, "no room")
		expect.equal(DoT.active(state, 0), false, "nothing burning")
	end,
}
