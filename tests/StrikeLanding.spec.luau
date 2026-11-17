--!strict
local StrikeLanding = require("../src/shared/Rules/StrikeLanding")
local expect = require("./expect")

local DEFAULTS: StrikeLanding.Settings = { Hold = 0, HoldAfter = 0.5, Height = 8 }

-- Speeds of the forms (EnemyDefinitions WalkSpeed), studs/s.
local WALKER, RUNNER, BRUTE = 9.5, 17, 6.5

-- A small crowd sim on the ground plane: `count` bodies spread over a disc of `spread`
-- studs round the mark (0, 0), all chasing a soldier standing `throw` studs away at
-- (-throw, 0) at `speed`. A body inside `hold` studs of the mark walks to the mark instead
-- (EnemyService's lure). Returns how many are inside `radius` of the mark after `seconds`.
local function landed(
	count: number,
	spread: number,
	throw: number,
	speed: number,
	hold: number,
	seconds: number,
	radius: number
): number
	local xs, zs = {}, {}
	for index = 1, count do
		-- A sunflower spread: even cover of the disc, no randomness.
		local r = spread * math.sqrt((index - 0.5) / count)
		local angle = index * 2.39996
		xs[index], zs[index] = r * math.cos(angle), r * math.sin(angle)
	end
	local dt = 0.05
	for _ = 1, math.floor(seconds / dt + 0.5) do
		for index = 1, count do
			local x, z = xs[index], zs[index]
			local goalX, goalZ = -throw, 0
			if hold > 0 and math.sqrt(x * x + z * z) <= hold then
				goalX, goalZ = 0, 0
			end
			local dx, dz = goalX - x, goalZ - z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance > 1 then
				local stepLength = math.min(speed * dt, distance)
				xs[index] = x + dx / distance * stepLength
				zs[index] = z + dz / distance * stepLength
			end
		end
	end
	local inside = 0
	for index = 1, count do
		if math.sqrt(xs[index] ^ 2 + zs[index] ^ 2) <= radius then
			inside += 1
		end
	end
	return inside
end

return {
	["a row without its own block gets the defaults"] = function()
		local resolved = StrikeLanding.resolve(true, DEFAULTS, nil)
		expect.equal(resolved.Hold, 0, "no hold")
		expect.equal(resolved.HoldAfter, 0.5, "after")
		expect.equal(resolved.Height, 8, "height")
		expect.equal(resolved.Flat, true, "flat")
	end,
	["a row's own block overrides only what it names"] = function()
		local resolved = StrikeLanding.resolve(true, DEFAULTS, { Hold = 16, HoldAfter = 2 })
		expect.equal(resolved.Hold, 16, "hold")
		expect.equal(resolved.HoldAfter, 2, "after")
		expect.equal(resolved.Height, 8, "height from the defaults")
	end,
	["switched off: no hold and the old sphere test"] = function()
		local resolved = StrikeLanding.resolve(false, DEFAULTS, { Hold = 16, Height = 20 })
		expect.equal(resolved.Hold, 0, "no hold")
		expect.equal(resolved.Flat, false, "sphere")
		expect.equal(StrikeLanding.holdSeconds(resolved, 3), 0, "nothing held")
	end,
	["the hold lasts until the first impact plus HoldAfter"] = function()
		local resolved = StrikeLanding.resolve(true, DEFAULTS, { Hold = 16, HoldAfter = 2 })
		expect.equal(StrikeLanding.holdSeconds(resolved, 3), 5, "hammer")
		local none = StrikeLanding.resolve(true, DEFAULTS, nil)
		expect.equal(StrikeLanding.holdSeconds(none, 3), 0, "a row without a hold")
	end,
	["a blast is measured flat, with a height allowance"] = function()
		local resolved = StrikeLanding.resolve(true, DEFAULTS, nil)
		-- A Brute's root sits about 6 studs up: a gun-run burst (5 studs) 1 up from the
		-- ground right under it missed it in 3D (5 studs off) and hits it flat.
		expect.equal(StrikeLanding.inBlast(resolved, 0.5, 5, 0, 5), true, "brute under a burst")
		expect.equal(StrikeLanding.inBlast(resolved, 4.9, 2, 0, 5), true, "inside the edge")
		expect.equal(StrikeLanding.inBlast(resolved, 5.1, 0, 0, 5), false, "outside")
		expect.equal(StrikeLanding.inBlast(resolved, 0, 9, 0, 12), false, "on a roof above")
	end,
	["switched off, a blast is the old sphere"] = function()
		local resolved = StrikeLanding.resolve(false, DEFAULTS, nil)
		expect.equal(StrikeLanding.inBlast(resolved, 0.5, 5, 0, 5), false, "brute missed")
		expect.equal(StrikeLanding.inBlast(resolved, 3, 3, 0, 5), true, "inside the sphere")
	end,
	-- Why they "move out of the way" (2026-11-16): nothing dodges; the crowd keeps chasing
	-- the thrower and is long gone when the round lands. Twenty bodies on the mark, the
	-- soldier 35 studs off.
	["today: a crowd on the Hammer's mark has walked out before the first shell"] = function()
		expect.equal(landed(20, 10, 35, WALKER, 0, 3, 12), 0, "walkers")
		expect.equal(landed(20, 10, 35, RUNNER, 0, 3, 12), 0, "runners")
		-- Brutes are slow: 1 of 20 is still on the edge (and a shell does 80 of its 260).
		expect.equal(landed(20, 10, 35, BRUTE, 0, 3, 12) <= 1, true, "brutes")
	end,
	["today: the Anvil's five seconds empty a 20-stud blast"] = function()
		expect.equal(landed(20, 15, 200, WALKER, 0, 5, 20), 0, "walkers")
		expect.equal(landed(20, 15, 200, BRUTE, 0, 5, 20), 0, "brutes")
	end,
	["held: the crowd on the mark is still there when the round lands"] = function()
		expect.equal(landed(20, 10, 35, WALKER, 16, 3, 12), 20, "hammer walkers")
		expect.equal(landed(20, 10, 35, RUNNER, 16, 3, 12), 20, "hammer runners")
		expect.equal(landed(20, 15, 200, BRUTE, 20, 5, 20), 20, "anvil brutes")
	end,
	["held: only what the mark is on is drawn in; a crowd beside it walks past"] = function()
		-- A crowd 30 studs to the side of the mark never comes within 16 of it.
		local inside = 0
		local count, speed = 20, WALKER
		for index = 1, count do
			local x, z = 0, 30 + (index % 5)
			for _ = 1, 60 do
				local dx, dz = -35 - x, 0 - z
				local distance = math.sqrt(dx * dx + dz * dz)
				if math.sqrt(x * x + z * z) <= 16 then
					dx, dz, distance = -x, -z, math.sqrt(x * x + z * z)
				end
				if distance > 1 then
					x += dx / distance * math.min(speed * 0.05, distance)
					z += dz / distance * math.min(speed * 0.05, distance)
				end
			end
			if math.sqrt(x * x + z * z) <= 12 then
				inside += 1
			end
		end
		expect.equal(inside, 0, "the player still has to put it on them")
	end,
}
