--!strict
local ExtractionWaves = require("../src/shared/Rules/ExtractionWaves")
local expect = require("./expect")

local WAVES: { ExtractionWaves.Wave } = {
	{ At = 30, Count = 12, PerExtraPlayer = 3, SpawnFactor = 0.6 },
	{ At = 50, Count = 6 },
}

return {
	["no wave is due before its mark"] = function()
		expect.equal(#ExtractionWaves.due(WAVES, 0, 29.9), 0)
	end,
	["a wave is due on the step that reaches its mark"] = function()
		local due = ExtractionWaves.due(WAVES, 29.9, 30)
		expect.equal(#due, 1, "count")
		expect.equal(due[1], 1, "index")
	end,
	["a wave is due once: not again on the next step"] = function()
		expect.equal(#ExtractionWaves.due(WAVES, 30, 30.1), 0)
	end,
	["a hold that stands still calls nothing"] = function()
		expect.equal(#ExtractionWaves.due(WAVES, 30, 30), 0)
	end,
	["one long step calls every wave it passes, in order"] = function()
		local due = ExtractionWaves.due(WAVES, 10, 60)
		expect.equal(#due, 2, "count")
		expect.equal(due[1], 1, "first")
		expect.equal(due[2], 2, "second")
	end,
	["a wave grows per extra player"] = function()
		expect.equal(ExtractionWaves.count(WAVES[1], 0), 12, "solo")
		expect.equal(ExtractionWaves.count(WAVES[1], 3), 21, "four players")
	end,
	["a wave with no per-player share stays its size"] = function()
		expect.equal(ExtractionWaves.count(WAVES[2], 3), 6)
	end,
	["the spawn factor is the base until a wave changes it"] = function()
		expect.near(ExtractionWaves.spawnFactor(WAVES, 0, 0.8), 0.8, 1e-9, "on call")
		expect.near(ExtractionWaves.spawnFactor(WAVES, 29, 0.8), 0.8, 1e-9, "before")
	end,
	["a passed wave's spawn factor holds until another replaces it"] = function()
		expect.near(ExtractionWaves.spawnFactor(WAVES, 30, 0.8), 0.6, 1e-9, "at the wave")
		expect.near(ExtractionWaves.spawnFactor(WAVES, 55, 0.8), 0.6, 1e-9, "past a wave with none")
	end,
}
