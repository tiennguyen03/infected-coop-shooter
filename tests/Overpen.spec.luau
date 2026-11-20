--!strict
local Overpen = require("../src/shared/Rules/Overpen")
local expect = require("./expect")

-- The Fifty's numbers (Config.Weapons.Fifty.Overpen) as the rule takes them.
local SETTINGS: Overpen.Settings = {
	bodies = 4,
	falloff = 0.10,
	wallThickness = 1.0,
	friendlyFire = 1.0,
}

local function near(actual: number, wanted: number, label: string)
	expect.near(actual, wanted, 1e-9, label)
end

return {
	["the first body takes the whole round and the round carries on"] = function()
		local round = Overpen.new(SETTINGS)
		local share, continues = Overpen.hit(round, "infected")
		near(share, 1, "share")
		expect.equal(continues, true, "continues")
	end,
	["each body pierced takes 10% off the round"] = function()
		local round = Overpen.new(SETTINGS)
		local shares = {}
		for _ = 1, 4 do
			local share = Overpen.hit(round, "infected")
			table.insert(shares, share)
		end
		near(shares[1], 1.0, "first")
		near(shares[2], 0.9, "second")
		near(shares[3], 0.8, "third")
		near(shares[4], 0.7, "fourth")
	end,
	["the round passes through up to four bodies and stops at the fourth"] = function()
		local round = Overpen.new(SETTINGS)
		for index = 1, 3 do
			local _, continues = Overpen.hit(round, "infected")
			expect.equal(continues, true, `continues after body {index}`)
		end
		local share, continues = Overpen.hit(round, "infected")
		near(share, 0.7, "fourth share")
		expect.equal(continues, false, "stops at the fourth")
	end,
	["a fifth body in the line is never hit"] = function()
		local round = Overpen.new(SETTINGS)
		for _ = 1, 4 do
			Overpen.hit(round, "infected")
		end
		local share, continues = Overpen.hit(round, "infected")
		near(share, 0, "fifth share")
		expect.equal(continues, false, "fifth continues")
	end,
	["a pierced squadmate takes the round: friendly fire applies"] = function()
		local round = Overpen.new(SETTINGS)
		Overpen.hit(round, "infected")
		local share, continues = Overpen.hit(round, "soldier")
		near(share, 0.9, "squadmate share")
		expect.equal(continues, true, "the round carries on past the squadmate")
	end,
	["a squadmate counts as a body pierced"] = function()
		local round = Overpen.new(SETTINGS)
		Overpen.hit(round, "soldier")
		local share = Overpen.hit(round, "infected")
		near(share, 0.9, "the Infected behind the squadmate")
	end,
	["friendly fire scales by its own share"] = function()
		local round = Overpen.new({
			bodies = 4,
			falloff = 0.10,
			wallThickness = 1.0,
			friendlyFire = 0.5,
		})
		local share = Overpen.hit(round, "soldier")
		near(share, 0.5, "squadmate share")
		local infected = Overpen.hit(round, "infected")
		near(infected, 0.9, "the Infected is not scaled")
	end,
	["the round passes through a wall no thicker than the threshold"] = function()
		local round = Overpen.new(SETTINGS)
		local share, continues = Overpen.hit(round, "wall", 0.4)
		near(share, 0, "a wall takes no damage")
		expect.equal(continues, true, "through a thin wall")
		local exact, through = Overpen.hit(round, "wall", 1.0)
		near(exact, 0, "exact share")
		expect.equal(through, true, "through a wall exactly at the threshold")
	end,
	["a wall thicker than the threshold stops the round"] = function()
		local round = Overpen.new(SETTINGS)
		local _, continues = Overpen.hit(round, "wall", 1.5)
		expect.equal(continues, false, "a thick wall stops it")
		local share = Overpen.hit(round, "infected")
		near(share, 0, "nothing behind a thick wall is hit")
	end,
	["a wall of unknown thickness stops the round"] = function()
		local round = Overpen.new(SETTINGS)
		local _, continues = Overpen.hit(round, "wall", nil)
		expect.equal(continues, false, "unknown thickness (terrain) stops it")
	end,
	["a thin wall costs no falloff and is not a body"] = function()
		local round = Overpen.new(SETTINGS)
		Overpen.hit(round, "wall", 0.5)
		local share = Overpen.hit(round, "infected")
		near(share, 1, "the body behind a thin wall")
	end,
	["the wall threshold is configurable"] = function()
		local round = Overpen.new({
			bodies = 4,
			falloff = 0.10,
			wallThickness = 2.0,
			friendlyFire = 1.0,
		})
		local _, continues = Overpen.hit(round, "wall", 1.5)
		expect.equal(continues, true, "1.5 is thin under a 2.0 threshold")
	end,
	["the falloff never goes below zero"] = function()
		local round = Overpen.new({
			bodies = 20,
			falloff = 0.10,
			wallThickness = 1.0,
			friendlyFire = 1.0,
		})
		local last = 1
		for _ = 1, 15 do
			last = Overpen.hit(round, "infected")
		end
		near(last, 0, "share after ten bodies")
	end,
	["damage is the round's damage times the share"] = function()
		near(Overpen.damage(180, 0.7), 126, "fourth body of a 180 round")
	end,
}
