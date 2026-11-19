--!strict
local Scarcity = require("../src/shared/Rules/Scarcity")
local expect = require("./expect")

return {
	["a gun's reserve comes from its Scarce row only when scarcity is on"] = function()
		local row = {
			ReserveStart = 120,
			ReserveMax = 240,
			Scarce = { ReserveStart = 90, ReserveMax = 150 },
		}
		local start, max = Scarcity.reserve(row, true)
		expect.equal(start, 90, "scarce start")
		expect.equal(max, 150, "scarce max")
		local oldStart, oldMax = Scarcity.reserve(row, false)
		expect.equal(oldStart, 120, "old start")
		expect.equal(oldMax, 240, "old max")
	end,
	["a gun with no Scarce row keeps its reserves"] = function()
		local start, max = Scarcity.reserve({ ReserveStart = 1, ReserveMax = 1 }, true)
		expect.equal(start, 1, "start")
		expect.equal(max, 1, "max")
	end,
	["a Scarce start never exceeds its max"] = function()
		local start, max = Scarcity.reserve({
			ReserveStart = 10,
			ReserveMax = 20,
			Scarce = { ReserveStart = 50, ReserveMax = 30 },
		}, true)
		expect.equal(start, 30, "start clamped to max")
		expect.equal(max, 30, "max")
	end,
	["a pouch adds whole magazines up to the max"] = function()
		expect.equal(Scarcity.addMags(30, 30, 150, 2), 90, "two mags in")
		expect.equal(Scarcity.addMags(120, 30, 150, 2), 150, "capped")
		expect.equal(Scarcity.addMags(150, 30, 150, 2), 150, "already full")
		expect.equal(Scarcity.addMags(0, 8, 32, 0), 0, "no mags")
		expect.equal(Scarcity.addMags(200, 30, 150, 1), 200, "never takes rounds away")
	end,
	["the pool is a base plus one per player, never below zero"] = function()
		expect.equal(Scarcity.poolSize(2, 1, 1), 3, "solo")
		expect.equal(Scarcity.poolSize(2, 1, 4), 6, "four players")
		expect.equal(Scarcity.poolSize(2, 1, 0), 2, "nobody yet")
		expect.equal(Scarcity.poolSize(-5, 0, 2), 0, "never negative")
	end,
	["a living player keeps the mission going"] = function()
		expect.equal(
			false,
			Scarcity.wiped({
				playersActive = 1,
				botsActive = 0,
				pending = 0,
				left = 0,
				enabled = true,
			}),
			"one player up"
		)
	end,
	["with reinforcements off every player down is the end"] = function()
		expect.equal(
			true,
			Scarcity.wiped({
				playersActive = 0,
				botsActive = 3,
				pending = 0,
				left = 5,
				enabled = false,
			}),
			"old rule"
		)
	end,
	["a dead player with a reinforcement left and a bot standing is not a wipe"] = function()
		expect.equal(
			false,
			Scarcity.wiped({
				playersActive = 0,
				botsActive = 2,
				pending = 0,
				left = 2,
				enabled = true,
			}),
			"about to be queued"
		)
		expect.equal(
			false,
			Scarcity.wiped({
				playersActive = 0,
				botsActive = 1,
				pending = 1,
				left = 0,
				enabled = true,
			}),
			"one inbound"
		)
	end,
	["nobody on the ground to drop to is a wipe"] = function()
		expect.equal(
			true,
			Scarcity.wiped({
				playersActive = 0,
				botsActive = 0,
				pending = 1,
				left = 3,
				enabled = true,
			}),
			"nobody left standing"
		)
	end,
	["the pool empty and nobody inbound is a wipe"] = function()
		expect.equal(
			true,
			Scarcity.wiped({
				playersActive = 0,
				botsActive = 3,
				pending = 0,
				left = 0,
				enabled = true,
			}),
			"dead is dead"
		)
	end,
	["a reinforcement drops to the nearest player before any bot"] = function()
		local pick = Scarcity.pickAnchor({
			{ id = "b:1", isPlayer = false, distance = 5 },
			{ id = "p:2", isPlayer = true, distance = 80 },
			{ id = "p:3", isPlayer = true, distance = 40 },
		})
		expect.equal(pick, "p:3", "nearest player")
		local botOnly = Scarcity.pickAnchor({
			{ id = "b:1", isPlayer = false, distance = 30 },
			{ id = "b:2", isPlayer = false, distance = 10 },
		})
		expect.equal(botOnly, "b:2", "nearest bot when no player stands")
		expect.equal(Scarcity.pickAnchor({}), nil, "nobody")
	end,
}
