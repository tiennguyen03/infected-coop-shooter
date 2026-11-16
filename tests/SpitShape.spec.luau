--!strict
local SpitShape = require("../src/shared/Rules/SpitShape")
local expect = require("./expect")

local GLOB: SpitShape.GlobSettings = {
	stretch = 1.6, -- length over width at rest
	speedStretch = 0.01, -- extra stretch per stud/s
	maxStretch = 2.6,
	wobble = 0.2, -- +/- share of the stretch
	wobbleRate = 9, -- Hz
}

local POOL: SpitShape.PoolSettings = { grow = 0.25, startSize = 0.3, fade = 1 }

local REAR: SpitShape.RearSettings = { back = 16, lunge = 8, recover = 0.3 }

return {
	["a glob is longer than it is wide and keeps its volume"] = function()
		local length, width = SpitShape.glob(0, 0, GLOB)
		expect.near(length / width, 1.6, 1e-9, "stretch at rest")
		expect.near(length * width * width, 1, 1e-9, "volume")
	end,
	["a faster glob stretches more, up to the cap"] = function()
		local slow = SpitShape.glob(0, 20, GLOB)
		local fast = SpitShape.glob(0, 60, GLOB)
		expect.equal(fast > slow, true, "faster is longer")
		local length, width = SpitShape.glob(0, 10000, GLOB)
		expect.near(length / width, 2.6, 1e-9, "capped")
	end,
	["the wobble swings the stretch both ways and never flattens it to a ball"] = function()
		local least, most = math.huge, 0
		for step = 0, 100 do
			local length, width = SpitShape.glob(step / 100 / 9, 0, GLOB)
			least = math.min(least, length / width)
			most = math.max(most, length / width)
		end
		expect.near(most, 1.6 * 1.2, 1e-3, "most")
		expect.near(least, 1.6 * 0.8, 1e-3, "least")
		expect.equal(least > 1, true, "never a ball")
	end,
	["a pool spreads in, holds, then fades out at the end of its life"] = function()
		local size, fade = SpitShape.pool(0, 4, POOL)
		expect.near(size, 0.3, 1e-9, "starts small")
		expect.equal(fade, 0, "starts solid")
		size, fade = SpitShape.pool(0.25, 4, POOL)
		expect.near(size, 1, 1e-9, "full after the spread")
		size, fade = SpitShape.pool(2, 4, POOL)
		expect.equal(size, 1, "holds")
		expect.equal(fade, 0, "holds solid")
		size, fade = SpitShape.pool(3.5, 4, POOL)
		expect.near(fade, 0.5, 1e-9, "half faded")
		size, fade = SpitShape.pool(4, 4, POOL)
		expect.equal(fade, 1, "gone")
		size, fade = SpitShape.pool(9, 4, POOL)
		expect.equal(fade, 1, "stays gone")
	end,
	["a pool shorter than its fade still starts solid"] = function()
		local _, fade = SpitShape.pool(0, 0.5, POOL)
		expect.equal(fade, 0, "solid at birth")
		_, fade = SpitShape.pool(0.5, 0.5, POOL)
		expect.equal(fade, 1, "gone at the end")
	end,
	["the head rears back over the windup, snaps forward on the spit, then settles"] = function()
		expect.equal(SpitShape.rear(0, 0.8, REAR), 0, "level at the start")
		expect.equal(SpitShape.rear(0.4, 0.8, REAR) >= 8, true, "half way back by half")
		expect.near(SpitShape.rear(0.8, 0.8, REAR), -8, 1e-9, "lunge at the spit")
		expect.near(SpitShape.rear(0.7999, 0.8, REAR), 16, 1e-2, "full rear just before")
		expect.near(SpitShape.rear(1.1, 0.8, REAR), 0, 1e-9, "settled")
		expect.equal(SpitShape.rear(5, 0.8, REAR), 0, "stays settled")
	end,
	["a windup of no length goes straight to the lunge"] = function()
		expect.near(SpitShape.rear(0, 0, REAR), -8, 1e-9, "lunge")
	end,
}
