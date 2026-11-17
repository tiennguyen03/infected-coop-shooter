--!strict
-- The Loadout screen's inspect card (LoadoutMenu; docs/STYLES.md section 5 > Loadout screen):
-- a call-in's or a grenade's numbers as labelled rows, each with a bar scaled against the rest
-- of the roster, plus the segmented bar's cell count and plain-word durations. Guns use
-- Rules/ArmsStats (and `stealth` here). Pure: the caller passes the item's own Config block;
-- every field is read by its generic name, so a new call-in shows its numbers by having them.
-- Spec: tests/KitCard.spec.luau.

local KitCard = {}

-- The shortest bar drawn, so a weak stat still shows a sliver (as ArmsStats).
KitCard.MIN_FRACTION = 0.06

export type Row = {
	label: string,
	text: string, -- the number as the card prints it
	fraction: number, -- 0..1 bar length against the best on the roster
}

-- What a call-in's Config block says, by meaning (any may be missing).
export type CallInStats = {
	damage: number?, -- per hit, or per second when perSecond
	perSecond: boolean,
	hits: number?, -- shells, bursts or mines per call
	radius: number?,
	blast: boolean, -- the radius is a blast's
	length: number?, -- a strip (the wire)
	reach: number?, -- a gun's range (the sentry)
	lasts: number?, -- seconds it stays
	charges: number?,
	cooldown: number?,
	arrives: number?, -- seconds from the throw to it working
}

local function trim(n: number): string
	local tenth = math.floor(n * 10 + 0.5) / 10
	if tenth == math.floor(tenth) then
		return tostring(math.floor(tenth))
	end
	return string.format("%.1f", tenth)
end

local function num(value: any): number?
	return if type(value) == "number" then value else nil
end

local function bar(fraction: number): number
	return math.clamp(fraction, KitCard.MIN_FRACTION, 1)
end

-- Bigger is better: this value over the best of `all`.
local function over(value: number, all: { number }): number
	local best = 0
	for _, v in all do
		best = math.max(best, v)
	end
	return bar(if best > 0 then value / best else 1)
end

-- Smaller is better: the best of `all` over this value.
local function under(value: number, all: { number }): number
	local best = math.huge
	for _, v in all do
		best = math.min(best, v)
	end
	return bar(if value > 0 then best / value else 1)
end

-- Filled segments of a `count`-cell bar for `fraction`: at least one unless it is zero.
function KitCard.cells(fraction: number, count: number): number
	if fraction <= 0 then
		return 0
	end
	return math.clamp(math.floor(fraction * count + 0.5), 1, count)
end

-- "45 s", "2.2 s", "2 min", "2 min 30 s".
function KitCard.duration(seconds: number): string
	if seconds < 60 then
		return `{trim(seconds)} s`
	end
	local minutes = math.floor(seconds / 60)
	local rest = math.floor(seconds - minutes * 60 + 0.5)
	return if rest > 0 then `{minutes} min {rest} s` else `{minutes} min`
end

function KitCard.callInStats(block: { [string]: any }): CallInStats
	local arrival = block.Arrival
	local perSecond = num(block.DamagePerSecond)
	return {
		damage = perSecond or num(block.BlastDamage) or num(block.Damage),
		perSecond = perSecond ~= nil,
		hits = num(block.Shells) or num(block.Bursts) or num(block.Mines),
		radius = num(block.BlastRadius) or num(block.Radius),
		blast = num(block.BlastRadius) ~= nil,
		length = num(block.Length),
		reach = num(block.Range),
		lasts = num(block.Duration) or num(block.Lifetime),
		charges = num(block.Charges),
		cooldown = num(block.Cooldown),
		arrives = num(block.Delay) or (if type(arrival) == "table" then num(arrival.Time) else nil),
	}
end

-- Total harm of one call: per hit x hits, or per second x how long it stays.
local function pull(s: CallInStats): number?
	local damage = s.damage
	if not damage then
		return nil
	end
	if s.perSecond then
		return damage * (s.lasts or 1)
	end
	return damage * (s.hits or 1)
end

local function gather(all: { CallInStats }, get: (CallInStats) -> number?): { number }
	local out = {}
	for _, s in all do
		local v = get(s)
		if v then
			table.insert(out, v)
		end
	end
	return out
end

-- One call-in's rows (only the stats it has), its bars against `all` (every call-in's block).
function KitCard.callIn(block: { [string]: any }, all: { { [string]: any } }): { Row }
	local s = KitCard.callInStats(block)
	local roster = {}
	for _, other in all do
		table.insert(roster, KitCard.callInStats(other))
	end
	local rows: { Row } = {}
	local function add(label: string, text: string, fraction: number)
		table.insert(rows, { label = label, text = text, fraction = fraction })
	end
	local damage, total = s.damage, pull(s)
	if damage and total then
		local text = if s.perSecond
			then `{trim(damage)} a second`
			elseif s.hits and s.hits > 1 then `{trim(damage)} x {s.hits}`
			else trim(damage)
		add("Damage", text, over(total, gather(roster, pull)))
	end
	local radius = s.radius
	if radius then
		add(
			if s.blast then "Blast radius" else "Radius",
			`{trim(radius)} studs`,
			over(
				radius,
				gather(roster, function(x)
					return x.radius
				end)
			)
		)
	end
	local length = s.length
	if length then
		add(
			"Length",
			`{trim(length)} studs`,
			over(
				length,
				gather(roster, function(x)
					return x.length
				end)
			)
		)
	end
	local reach = s.reach
	if reach then
		add(
			"Reach",
			`{trim(reach)} studs`,
			over(
				reach,
				gather(roster, function(x)
					return x.reach
				end)
			)
		)
	end
	local lasts = s.lasts
	if lasts then
		add(
			"Lasts",
			KitCard.duration(lasts),
			over(
				lasts,
				gather(roster, function(x)
					return x.lasts
				end)
			)
		)
	end
	local charges = s.charges
	if charges then
		add(
			"Charges",
			tostring(charges),
			over(
				charges,
				gather(roster, function(x)
					return x.charges
				end)
			)
		)
	end
	local cooldown = s.cooldown
	if cooldown then
		add(
			"Cooldown",
			KitCard.duration(cooldown),
			under(
				cooldown,
				gather(roster, function(x)
					return x.cooldown
				end)
			)
		)
	end
	local arrives = s.arrives
	if arrives then
		add(
			"Arrives",
			`{KitCard.duration(arrives)} after the throw`,
			under(
				arrives,
				gather(roster, function(x)
					return x.arrives
				end)
			)
		)
	end
	return rows
end

-- A grenade's rows from its Config.Grenade block, bars against `all` (every grenade's block).
function KitCard.grenade(block: { [string]: any }, all: { { [string]: any } }): { Row }
	local function field(name: string): (number, { number })
		local values = {}
		for _, other in all do
			local v = num(other[name])
			if v then
				table.insert(values, v)
			end
		end
		return num(block[name]) or 0, values
	end
	local damage, damages = field("Damage")
	local radius, radii = field("Radius")
	local fuse, fuses = field("FuseTime")
	local throw, throws = field("ThrowDistance")
	return {
		{ label = "Damage", text = trim(damage), fraction = over(damage, damages) },
		{ label = "Blast radius", text = `{trim(radius)} studs`, fraction = over(radius, radii) },
		{
			label = "Fuse",
			text = `{KitCard.duration(fuse)} after it lands`,
			fraction = under(fuse, fuses),
		},
		{ label = "Throw", text = `{trim(throw)} studs`, fraction = over(throw, throws) },
	}
end

-- A gun's noise (studs a shot carries to the Infected) as a bar: the quietest is the fullest.
function KitCard.stealth(noise: number, all: { number }): Row
	return { label = "Stealth", text = `heard at {trim(noise)} studs`, fraction = under(noise, all) }
end

return KitCard
