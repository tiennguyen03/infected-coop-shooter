--!strict
-- The Carrier's painted counts (docs/sprints/CARRIER_V2.md > Easter eggs 3, 4, 6): the call-in
-- numbers on the hull, the MISSIONS HOME board, the DAYS SINCE board. Pure: the match adds a
-- run's counts onto the stored totals (TallyService), the lobby paints start value + stored
-- total (TallyBoards). A count is keyed "<kind>:<id>" (callin:hammer, mission:delta).

local Tally = {}

export type Counts = { [string]: number }

local DAY = 86400

-- "1,284": whole, never below zero, thousands commas.
function Tally.format(n: number): string
	local text = tostring(math.max(0, math.floor(n)))
	local out = text
	while true do
		local swapped, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		out = swapped
		if count == 0 then
			break
		end
	end
	return out
end

function Tally.key(kind: string, id: string): string
	return `{kind}:{id}`
end

-- "mission:mile14" -> "mission", "mile14"; "days" -> "days", "".
function Tally.parse(tag: string): (string, string)
	local kind, id = string.match(tag, "^([^:]+):(.*)$")
	if kind then
		return kind, id :: string
	end
	return tag, ""
end

-- A stored value made safe: string keys with whole counts of zero or more; anything else is
-- dropped (an empty table for a missing or broken save).
function Tally.clean(stored: unknown): Counts
	local out: Counts = {}
	if typeof(stored) ~= "table" then
		return out
	end
	for key, value in stored :: { [any]: any } do
		if typeof(key) == "string" and typeof(value) == "number" and value >= 0 then
			out[key] = math.floor(value)
		end
	end
	return out
end

-- The stored totals with one run's counts added (the UpdateAsync step).
function Tally.merge(stored: unknown, add: Counts): Counts
	local out = Tally.clean(stored)
	for key, n in Tally.clean(add) do
		out[key] = (out[key] or 0) + n
	end
	return out
end

-- What a board shows: the row's start value (Config) plus what the squads have added.
function Tally.shown(start: number?, stored: Counts, tag: string): number
	return math.max(0, math.floor(start or 0)) + (stored[tag] or 0)
end

-- Days from 1970-01-01 to a "YYYY-MM-DD" date (UTC, proleptic Gregorian); nil if not a date.
function Tally.dayNumber(date: string): number?
	local ys, ms, ds = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not ys then
		return nil
	end
	local y, m, d = tonumber(ys) :: number, tonumber(ms) :: number, tonumber(ds) :: number
	if m < 1 or m > 12 or d < 1 or d > 31 then
		return nil
	end
	-- Howard Hinnant's days_from_civil.
	if m <= 2 then
		y -= 1
	end
	local era = y // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- Whole days from `start` ("YYYY-MM-DD", UTC midnight) to `now` (os.time()); 0 before it or
-- for a bad date.
function Tally.daysSince(start: string, now: number): number
	local first = Tally.dayNumber(start)
	if not first then
		return 0
	end
	return math.max(0, now // DAY - first)
end

-- `n` as `width` digit strings for number tiles, zero-padded, capped at the tiles' 999...
function Tally.digits(n: number, width: number): { string }
	local cap = 10 ^ width - 1
	local text = string.format("%0" .. width .. "d", math.clamp(math.floor(n), 0, cap))
	local out = {}
	for i = 1, width do
		table.insert(out, string.sub(text, i, i))
	end
	return out
end

return Tally
