--!strict
-- The waves that hit the pad while the squad holds it for the bird (docs/PROGRESSION.md >
-- Operation > Extraction): pure, unit-tested with Lune (tests/ExtractionWaves.spec.luau).
-- ExtractionService feeds it Config.Extraction.Waves and the hold's progress in seconds,
-- which only runs while every living player is on the pad.

local ExtractionWaves = {}

export type Wave = {
	At: number, -- seconds of hold progress
	Count: number, -- Infected, one player
	PerExtraPlayer: number?, -- more per living player beyond the first
	SpawnFactor: number?, -- spawn interval multiplier from this wave on
}

-- Indexes of the waves whose mark the hold passed going from `before` to `after` seconds,
-- in list order. Each wave is due on exactly one step.
function ExtractionWaves.due(waves: { Wave }, before: number, after: number): { number }
	local due = {}
	for index, wave in waves do
		if wave.At > before and wave.At <= after then
			table.insert(due, index)
		end
	end
	return due
end

-- How many Infected the wave brings with `extraPlayers` living players beyond the first.
function ExtractionWaves.count(wave: Wave, extraPlayers: number): number
	return wave.Count + (wave.PerExtraPlayer or 0) * math.max(extraPlayers, 0)
end

-- The spawn interval multiplier at `progress` seconds: `base` until a wave that carries its
-- own has been passed, then the latest such wave's.
function ExtractionWaves.spawnFactor(waves: { Wave }, progress: number, base: number): number
	local factor, latest = base, -math.huge
	for _, wave in waves do
		if wave.SpawnFactor and wave.At <= progress and wave.At >= latest then
			factor, latest = wave.SpawnFactor, wave.At
		end
	end
	return factor
end

return ExtractionWaves
