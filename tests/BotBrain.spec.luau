--!strict
local BotBrain = require("../src/shared/Rules/BotBrain")
local expect = require("./expect")

local MOVE = {
	TeleportMinDistance = 30,
	StuckSeconds = 6,
	NoPathStuckSeconds = 3,
	PathFailLimit = 3,
	TeleportCooldown = 10,
}
local STIM = { StimBelow = 0.4, StimCooldown = 8 }
local FRAG = { Radius = 10, MinCluster = 4, MinDistance = 14, MaxDistance = 35, SafeRadius = 14 }

local function at(x: number, z: number, heavy: boolean?): BotBrain.Point
	return { x = x, z = z, heavy = heavy }
end

local function stuck(overrides: { [string]: any }): boolean
	local input = {
		distance = 60,
		stalledFor = 0,
		pathFails = 0,
		fellOut = false,
		sinceTeleport = 100,
	}
	for key, value in overrides do
		(input :: any)[key] = value
	end
	return BotBrain.shouldTeleport(input, MOVE)
end

-- Four Infected in a knot 20 studs ahead of a bot at the origin.
local KNOT = { at(0, 20), at(2, 21), at(-2, 19), at(1, 23) }

return {
	["a bot far behind but still moving walks, never teleports"] = function()
		expect.equal(stuck({ distance = 200 }), false)
	end,
	["no progress for StuckSeconds while far teleports"] = function()
		expect.equal(stuck({ stalledFor = 5.9 }), false, "before")
		expect.equal(stuck({ stalledFor = 6 }), true, "after")
	end,
	["a stalled bot close to its leader stays put"] = function()
		expect.equal(stuck({ distance = 30, stalledFor = 60, pathFails = 9 }), false)
	end,
	["no path several times in a row shortens the wait, but the bot must still be stalled"] = function()
		expect.equal(stuck({ pathFails = 3, stalledFor = 0 }), false, "moving")
		expect.equal(stuck({ pathFails = 2, stalledFor = 3 }), false, "two fails")
		expect.equal(stuck({ pathFails = 3, stalledFor = 3 }), true, "three fails")
	end,
	["a bot that fell out of the world teleports at once"] = function()
		expect.equal(stuck({ distance = 5, fellOut = true, sinceTeleport = 0 }), true)
	end,
	["no second teleport inside the cooldown"] = function()
		expect.equal(stuck({ stalledFor = 20, sinceTeleport = 9 }), false)
	end,

	["the stall clock runs while the bot stays within StuckDistance of its mark"] = function()
		local mark, since = BotBrain.stall(nil, nil, at(0, 0), 10, 3)
		expect.equal(since, 10, "starts")
		mark, since = BotBrain.stall(mark, since, at(2, 0), 14, 3)
		expect.equal(since, 10, "kept")
		mark, since = BotBrain.stall(mark, since, at(5, 0), 15, 3)
		expect.equal(since, 15, "reset on progress")
		expect.equal(mark.x, 5, "new mark")
	end,

	["a hurt standing bot with a stim uses it"] = function()
		local input = { health = 40, maxHealth = 100, stims = 1, standing = true, sinceStim = 99 }
		expect.equal(BotBrain.shouldStim(input, STIM), true)
	end,
	["no stim above the threshold, with none left, downed, or inside the cooldown"] = function()
		local function stim(overrides: { [string]: any }): boolean
			local input =
				{ health = 30, maxHealth = 100, stims = 2, standing = true, sinceStim = 99 }
			for key, value in overrides do
				(input :: any)[key] = value
			end
			return BotBrain.shouldStim(input, STIM)
		end
		expect.equal(stim({ health = 41 }), false, "healthy")
		expect.equal(stim({ stims = 0 }), false, "none left")
		expect.equal(stim({ standing = false }), false, "downed")
		expect.equal(stim({ sinceStim = 7 }), false, "cooldown")
		expect.equal(stim({ health = 0 }), false, "dead")
	end,

	["a knot of Infected at a safe distance is a grenade target"] = function()
		local target, count = BotBrain.clusterTarget(at(0, 0), KNOT, { at(0, 0) }, FRAG)
		expect.equal(target ~= nil, true, "target")
		expect.equal(count, 4, "count")
	end,
	["too few Infected is not a target"] = function()
		local few = { KNOT[1], KNOT[2], KNOT[3] }
		expect.equal((BotBrain.clusterTarget(at(0, 0), few, {}, FRAG)), nil)
	end,
	["never with a squadmate inside the safe radius"] = function()
		expect.equal((BotBrain.clusterTarget(at(0, 0), KNOT, { at(6, 24) }, FRAG)), nil)
	end,
	["never closer than MinDistance or beyond the throw"] = function()
		local close = { at(0, 8), at(1, 9), at(-1, 8), at(0, 10) }
		expect.equal((BotBrain.clusterTarget(at(0, 0), close, {}, FRAG)), nil, "close")
		local far = { at(0, 50), at(1, 51), at(-1, 50), at(0, 52) }
		expect.equal((BotBrain.clusterTarget(at(0, 0), far, {}, FRAG)), nil, "far")
	end,
	["the densest knot wins"] = function()
		local enemies = table.clone(KNOT)
		for _, point in { at(25, 0), at(26, 1), at(24, -1), at(25, 2), at(27, 0) } do
			table.insert(enemies, point)
		end
		local target, count = BotBrain.clusterTarget(at(0, 0), enemies, {}, FRAG)
		expect.equal(count, 5, "count")
		expect.equal((target :: BotBrain.Point).x >= 24, true, "the right-hand knot")
	end,
	["a heavy alone is a target only when HeavyCounts"] = function()
		local brute = { at(0, 25, true) }
		expect.equal((BotBrain.clusterTarget(at(0, 0), brute, {}, FRAG)), nil, "frag")
		local strike = table.clone(FRAG) :: any
		strike.HeavyCounts = true
		local target = BotBrain.clusterTarget(at(0, 0), brute, {}, strike)
		expect.equal(target ~= nil, true, "strike")
	end,

	["a teleport lands on the first spot no player is looking at"] = function()
		-- One player at the origin looking down +Z.
		local viewers = { { x = 0, z = 0, lookX = 0, lookZ = 1 } }
		local spots = { at(0, 10), at(5, 12), at(0, -10) }
		expect.equal(BotBrain.teleportSpot(spots, viewers, 0.3), 3)
	end,
	["with every spot in view the first one is used"] = function()
		local viewers = { { x = 0, z = 0, lookX = 0, lookZ = 1 } }
		expect.equal(BotBrain.teleportSpot({ at(0, 10), at(1, 12) }, viewers, 0.3), 1)
	end,
	["a spot behind one player but in front of another is in view"] = function()
		local viewers = {
			{ x = 0, z = 0, lookX = 0, lookZ = 1 },
			{ x = 0, z = -30, lookX = 0, lookZ = 1 },
		}
		expect.equal(BotBrain.teleportSpot({ at(0, -10), at(0, -40) }, viewers, 0.3), 2)
	end,

	["a stand-off spot is StandOff from the boss, on the leader's side"] = function()
		local ring = { StandOff = 30, SpreadDegrees = 40 }
		for slot = 1, 3 do
			local spot = BotBrain.standOff(at(0, 0), at(0, 10), slot, ring)
			expect.near(math.sqrt(spot.x * spot.x + spot.z * spot.z), 30, 0.01, `radius {slot}`)
			expect.equal(spot.z > 0, true, `leader's side {slot}`)
		end
	end,
	["the three slots spread round the ring, further apart than a charge is wide"] = function()
		local ring = { StandOff = 30, SpreadDegrees = 40 }
		local spots = {}
		for slot = 1, 3 do
			spots[slot] = BotBrain.standOff(at(0, 0), at(0, 10), slot, ring)
		end
		for a = 1, 3 do
			for b = a + 1, 3 do
				local dx, dz = spots[a].x - spots[b].x, spots[a].z - spots[b].z
				expect.equal(math.sqrt(dx * dx + dz * dz) > 19, true, `{a}-{b}`)
			end
		end
		expect.equal(spots[1].x * spots[2].x < 0, true, "either side of the leader's line")
	end,
	["a leader standing on the boss still gives a spot on the ring"] = function()
		local spot = BotBrain.standOff(at(5, 5), at(5, 5), 1, { StandOff = 30, SpreadDegrees = 40 })
		local dx, dz = spot.x - 5, spot.z - 5
		expect.near(math.sqrt(dx * dx + dz * dz), 30, 0.01)
	end,

	["a revive waits while an Infected or the boss is on the downed body"] = function()
		local rule = { ReviveSafeRadius = 12, BossReviveClear = 26 }
		expect.equal(BotBrain.reviveSafe(40, nil, rule), true, "clear")
		expect.equal(BotBrain.reviveSafe(11, nil, rule), false, "Infected close")
		expect.equal(BotBrain.reviveSafe(40, 25, rule), false, "boss on top")
		expect.equal(BotBrain.reviveSafe(40, 27, rule), true, "boss away")
	end,

	["a body inside a puddle steps out past its edge the short way"] = function()
		local out = BotBrain.stepOut(at(3, 0), at(0, 0), 9, 3) :: BotBrain.Point
		expect.near(out.x, 12, 0.01, "x")
		expect.near(out.z, 0, 0.01, "z")
		expect.equal(BotBrain.stepOut(at(13, 0), at(0, 0), 9, 3), nil, "outside")
		expect.equal(BotBrain.stepOut(at(0, 0), at(0, 0), 9, 3) ~= nil, true, "dead centre")
	end,
}
