--!strict
-- Containment Board bands (docs/PROGRESSION.md > The Containment Board): pure, unit-tested
-- with Lune (tests/Containment.spec.luau). A district's percent maps to the band word Control
-- uses for it; the band list (Config.Containment.Bands) gives each band's minimum percent.

local Containment = {}

export type Band = {
	name: string,
	min: number,
}

-- The whole percent the board shows, clamped to 0..100.
function Containment.percent(value: number): number
	return math.clamp(math.floor(value), 0, 100)
end

-- The band for a percent: the band with the highest minimum at or below it.
function Containment.band(value: number, bands: { Band }): string
	local shown = Containment.percent(value)
	local best: Band? = nil
	for _, band in bands do
		if shown >= band.min and (best == nil or band.min > best.min) then
			best = band
		end
	end
	return if best then best.name else ""
end

return Containment
