--!strict
-- The city war (loop sprint 3; design: docs/superpowers/specs/2026-11-20-game-loop-design.md
-- section 6; tests/War.spec.luau). One shared board per season: each district's percent,
-- when it was last written, whether it is open and whether it is Secured. Every mission
-- brought home adds points to its district (per mission, not per player); the Infected
-- push back a little every hour; a loss takes nothing away. A district opens when the one
-- before it reaches UnlockAt and stays open; 100 is Secured (no more decay this season).
-- Pure: the match's WarService writes with UpdateAsync through `merge`, the lobby reads and
-- shows through `shown`. Times are os.time() seconds.

local War = {}

export type Record = { pct: number, at: number, unlocked: boolean?, secured: boolean? }
export type Board = { version: number, districts: { [string]: Record } }
export type Shown = {
	name: string,
	percent: number, -- with decay up to `now`, unrounded
	open: boolean,
	secured: boolean,
	opensWith: string?, -- the district whose 50% opens this one
}
export type Settings = {
	Points: { [string]: number },
	PointsPerPercent: number,
	DecayPerHour: number,
	UnlockAt: number,
	OpenAtStart: number,
	Districts: { { name: string, percent: number } },
}

War.VERSION = 1

-- War points for a mission's outcome ("win" | "partial" | "loss").
function War.points(outcome: string, cfg: Settings): number
	return cfg.Points[outcome] or 0
end

local function fresh(cfg: Settings, now: number): Board
	local districts: { [string]: Record } = {}
	for _, entry in cfg.Districts do
		districts[entry.name] = { pct = entry.percent, at = now }
	end
	return { version = War.VERSION, districts = districts }
end

-- A record's percent at `now`: the hourly push-back since it was written, never below 0;
-- a Secured district does not fall.
function War.decayed(record: Record, now: number, cfg: Settings): number
	if record.secured then
		return record.pct
	end
	local hours = math.max(0, now - record.at) / 3600
	return math.max(0, record.pct - hours * cfg.DecayPerHour)
end

-- Reads whatever the store held (garbage or nil starts the season over).
local function read(old: unknown, cfg: Settings, now: number): Board
	if typeof(old) ~= "table" or typeof((old :: any).districts) ~= "table" then
		return fresh(cfg, now)
	end
	local board = fresh(cfg, now)
	for name, record in (old :: any).districts do
		if
			board.districts[name]
			and typeof(record) == "table"
			and typeof(record.pct) == "number"
		then
			board.districts[name] = {
				pct = math.clamp(record.pct, 0, 100),
				at = if typeof(record.at) == "number" then record.at else now,
				unlocked = record.unlocked == true or nil,
				secured = record.secured == true or nil,
			}
		end
	end
	return board
end

-- The UpdateAsync transform: decay every district to `now`, add `add` (points by district
-- name), clamp, mark Secured at 100 and open the next district at UnlockAt.
function War.merge(old: unknown, add: { [string]: number }, now: number, cfg: Settings): Board
	local board = read(old, cfg, now)
	for index, entry in cfg.Districts do
		local record = board.districts[entry.name]
		local points = if record.secured then 0 else (add[entry.name] or 0) -- Secured takes no more
		local pct = War.decayed(record, now, cfg) + points / cfg.PointsPerPercent
		record.pct = math.clamp(pct, 0, 100)
		record.at = math.max(record.at, now) -- a server whose clock is behind never moves it back
		if record.pct >= 100 then
			record.secured = true
		end
		local nextEntry = cfg.Districts[index + 1]
		if nextEntry and record.pct >= cfg.UnlockAt then
			board.districts[nextEntry.name].unlocked = true
		end
	end
	return board
end

-- What the lobby shows, in board order, decayed to `now`.
function War.shown(board: Board, now: number, cfg: Settings): { Shown }
	local out: { Shown } = {}
	for index, entry in cfg.Districts do
		local record: Record = board.districts[entry.name] or { pct = entry.percent, at = now }
		local before = cfg.Districts[index - 1]
		table.insert(out, {
			name = entry.name,
			percent = War.decayed(record, now, cfg),
			open = index <= cfg.OpenAtStart or record.unlocked == true,
			secured = record.secured == true,
			opensWith = if before then before.name else nil,
		})
	end
	return out
end

-- The debrief line for a mission's points: "MILE 14 +1.5%" ("" for none; "DELTA SECURED" when
-- the district is already Secured and takes no more).
function War.gainText(district: string, points: number, cfg: Settings, secured: boolean?): string
	if secured then
		return `{district} SECURED`
	end
	if points <= 0 then
		return ""
	end
	local gain = points / cfg.PointsPerPercent
	local text = if gain == math.floor(gain)
		then string.format("%d", gain)
		else string.format("%.1f", gain)
	return `{district} +{text}%`
end

-- Seasons (loop sprint 5): the board starts over every `days` days from `start` (os.time()),
-- in a new store, so nothing has to wipe anything; personal unlocks live on each record and stay.
function War.season(now: number, start: number, days: number): number
	return math.max(0, math.floor((now - start) / (days * 86400))) + 1
end

function War.storeFor(prefix: string, season: number): string
	return `{prefix}{season}`
end

-- When the season running at `now` ends (os.time()).
function War.seasonEnds(now: number, start: number, days: number): number
	return start + War.season(now, start, days) * days * 86400
end

return War
