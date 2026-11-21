--!strict
-- The city war (src/shared/Rules/War.luau): one shared board of districts every server's
-- missions push. Points per mission, decay over time, the next district opening at 50%,
-- Secured at 100%, and what the lobby shows.

local War = require("../src/shared/Rules/War")

local HOUR = 3600

local CFG: any = {
	Points = { win = 3, partial = 1, loss = 0 },
	PointsPerPercent = 2,
	DecayPerHour = 0.25,
	UnlockAt = 50,
	OpenAtStart = 2,
	Districts = {
		{ name = "DELTA", percent = 25 },
		{ name = "MILE 14", percent = 0 },
		{ name = "KESTREL", percent = 0 },
	},
}

local function near(actual: number, expected: number, what: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{what}: expected {expected}, got {actual}`, 2)
	end
end

local function eq(actual: unknown, expected: unknown, what: string)
	if actual ~= expected then
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function row(shown: { War.Shown }, name: string): War.Shown
	for _, entry in shown do
		if entry.name == name then
			return entry
		end
	end
	error(`no {name}`, 2)
end

return {
	["points per outcome"] = function()
		eq(War.points("win", CFG), 3, "win")
		eq(War.points("partial", CFG), 1, "partial")
		eq(War.points("loss", CFG), 0, "loss")
		eq(War.points("nonsense", CFG), 0, "unknown")
	end,

	["an empty store starts from the board's start values"] = function()
		local board = War.merge(nil, {}, 0, CFG)
		near(board.districts["DELTA"].pct, 25, "Delta")
		near(board.districts["MILE 14"].pct, 0, "Mile 14")
	end,

	["garbage in the store starts over"] = function()
		local board = War.merge({ districts = 5 }, {}, 0, CFG)
		near(board.districts["DELTA"].pct, 25, "Delta")
	end,

	["a win adds 1.5 percent"] = function()
		local board = War.merge(nil, { ["MILE 14"] = 3 }, 0, CFG)
		near(board.districts["MILE 14"].pct, 1.5, "Mile 14")
	end,

	["points to a district not on the board are ignored"] = function()
		local board = War.merge(nil, { ["NOWHERE"] = 3 }, 0, CFG)
		eq(board.districts["NOWHERE"], nil, "no district made up")
	end,

	["the Infected push back 0.25 percent an hour"] = function()
		local board = War.merge(nil, {}, 0, CFG)
		local later = War.merge(board, {}, 4 * HOUR, CFG)
		near(later.districts["DELTA"].pct, 24, "four hours")
	end,

	["decay never goes below zero"] = function()
		local board = War.merge(nil, {}, 0, CFG)
		local later = War.merge(board, {}, 1000 * HOUR, CFG)
		near(later.districts["DELTA"].pct, 0, "floor")
	end,

	["decay applies before the new points"] = function()
		local board = War.merge(nil, {}, 0, CFG)
		local later = War.merge(board, { DELTA = 3 }, 4 * HOUR, CFG)
		near(later.districts["DELTA"].pct, 25.5, "24 + 1.5")
	end,

	["100 percent is Secured: no decay after"] = function()
		local board = War.merge(nil, { DELTA = 200 }, 0, CFG)
		near(board.districts["DELTA"].pct, 100, "clamped")
		eq(board.districts["DELTA"].secured, true, "secured")
		local later = War.merge(board, {}, 100 * HOUR, CFG)
		near(later.districts["DELTA"].pct, 100, "no decay when secured")
	end,

	["the first districts start open; the next opens at 50 percent and stays open"] = function()
		local shown = War.shown(War.merge(nil, {}, 0, CFG), 0, CFG)
		eq(row(shown, "DELTA").open, true, "Delta")
		eq(row(shown, "MILE 14").open, true, "Mile 14")
		eq(row(shown, "KESTREL").open, false, "Kestrel closed")
		local pushed = War.merge(nil, { ["MILE 14"] = 100 }, 0, CFG)
		eq(row(War.shown(pushed, 0, CFG), "KESTREL").open, true, "Kestrel opens at 50")
		local fallen = War.merge(pushed, {}, 100 * HOUR, CFG)
		eq(row(War.shown(fallen, 100 * HOUR, CFG), "KESTREL").open, true, "stays open after decay")
	end,

	["shown decays between reads and keeps board order"] = function()
		local board = War.merge(nil, {}, 0, CFG)
		local shown = War.shown(board, 4 * HOUR, CFG)
		eq(shown[1].name, "DELTA", "first")
		eq(shown[2].name, "MILE 14", "second")
		near(shown[1].percent, 24, "decayed")
	end,

	["shown says what opens a closed district"] = function()
		local shown = War.shown(War.merge(nil, {}, 0, CFG), 0, CFG)
		eq(row(shown, "KESTREL").opensWith, "MILE 14", "opened by the one before")
	end,

	["gainText reads like the debrief"] = function()
		eq(War.gainText("MILE 14", 3, CFG), "MILE 14 +1.5%", "win")
		eq(War.gainText("DELTA", 1, CFG), "DELTA +0.5%", "partial")
		eq(War.gainText("DELTA", 0, CFG), "", "nothing")
	end,

	-- Review fixes (sprint 3).
	["a Secured district's line says so instead of a gain"] = function()
		eq(War.gainText("DELTA", 3, CFG, true), "DELTA SECURED", "secured")
		eq(War.gainText("DELTA", 3, CFG, false), "DELTA +1.5%", "not secured")
	end,

	["a server with a slow clock never moves a record's time back"] = function()
		local board = War.merge(nil, { DELTA = 2 }, 1000, CFG)
		local behind = War.merge(board, { DELTA = 2 }, 900, CFG)
		eq(behind.districts.DELTA.at, 1000, "kept the later time")
	end,

	-- Loop sprint 5: seasons.
	["season numbers count from the first season's start"] = function()
		local DAY = 86400
		eq(War.season(1000, 1000, 28), 1, "the first day")
		eq(War.season(1000 + 27 * DAY, 1000, 28), 1, "day 28")
		eq(War.season(1000 + 28 * DAY, 1000, 28), 2, "day 29 is season 2")
		eq(War.season(500, 1000, 28), 1, "before the start counts as the first")
	end,

	["each season has its own store"] = function()
		eq(War.storeFor("War_S", 1), "War_S1", "one")
		eq(War.storeFor("War_S", 12), "War_S12", "twelve")
	end,

	["season end time"] = function()
		eq(War.seasonEnds(1000 + 5, 1000, 28), 1000 + 28 * 86400, "first season ends")
	end,
}
