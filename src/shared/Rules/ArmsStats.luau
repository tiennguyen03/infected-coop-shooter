--!strict
-- The Arms Room's stat card (lobby ArmsRackUI): one gun's numbers as labelled bars, each
-- scaled against the best gun on the rack, so a bar reads "how this gun compares". Pure: the
-- caller passes plain numbers (from WeaponDefinitions); spec in tests/ArmsStats.spec.luau.

local ArmsStats = {}

-- The shortest bar drawn, so a weak stat still shows a sliver.
ArmsStats.MIN_FRACTION = 0.06

export type Stats = {
	damage: number, -- per round (per pellet when pellets is set)
	pellets: number?,
	fireCooldown: number, -- seconds between shots
	magazine: number,
	reload: number, -- seconds
	range: number, -- studs
	adsSpread: number, -- degrees, aimed
}

export type Row = {
	label: string,
	text: string, -- the number as the card prints it
	fraction: number, -- 0..1 bar length against the best on the rack
}

local function pull(s: Stats): number
	return s.damage * (s.pellets or 1)
end

local function rpm(s: Stats): number
	return 60 / s.fireCooldown
end

local function trim(n: number): string
	if n == math.floor(n) then
		return tostring(n)
	end
	return string.format("%.1f", n)
end

local function bar(fraction: number): number
	return math.clamp(fraction, ArmsStats.MIN_FRACTION, 1)
end

-- Bigger is better: this value over the best.
local function over(value: number, all: { Stats }, get: (Stats) -> number): number
	local best = 0
	for _, s in all do
		best = math.max(best, get(s))
	end
	return bar(if best > 0 then value / best else 1)
end

-- Smaller is better: the best over this value.
local function under(value: number, all: { Stats }, get: (Stats) -> number): number
	local best = math.huge
	for _, s in all do
		best = math.min(best, get(s))
	end
	return bar(if value > 0 then best / value else 1)
end

function ArmsStats.rows(s: Stats, all: { Stats }): { Row }
	local pellets = s.pellets
	return {
		{
			label = "Damage",
			text = if pellets and pellets > 1
				then `{trim(s.damage)} x {pellets}`
				else trim(s.damage),
			fraction = over(pull(s), all, pull),
		},
		{
			label = "Fire rate",
			text = `{math.floor(rpm(s) + 0.5)} rpm`,
			fraction = over(rpm(s), all, rpm),
		},
		{
			label = "Magazine",
			text = tostring(s.magazine),
			fraction = over(s.magazine, all, function(x)
				return x.magazine
			end),
		},
		{
			label = "Reload",
			text = `{trim(s.reload)} s`,
			fraction = under(s.reload, all, function(x)
				return x.reload
			end),
		},
		{
			label = "Range",
			text = `{trim(s.range)} studs`,
			fraction = over(s.range, all, function(x)
				return x.range
			end),
		},
		{
			label = "Accuracy",
			text = `{trim(s.adsSpread)}° aimed`,
			fraction = under(s.adsSpread, all, function(x)
				return x.adsSpread
			end),
		},
	}
end

return ArmsStats
