--!strict
-- Which mission a match server builds (src/shared/Rules/MissionPick.luau): the lobby's launch
-- record first, then the place's own tag, then the catalog's default. Anything unknown,
-- malformed or out of its window falls through; the match must always boot.

local Catalog = require("../src/shared/MissionCatalog")
local MissionPick = require("../src/shared/Rules/MissionPick")

local function eq(actual: unknown, expected: unknown, what: string)
	if actual ~= expected then
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

-- A catalog with one row in a window, for the window cases.
local function windowed(): any
	local rows = table.clone(Catalog.Rows) :: any
	local event = table.clone(rows.mile14)
	event.Window = { From = 100, To = 200 }
	rows.mile14 = event
	return {
		Rows = rows,
		Order = Catalog.Order,
		DEFAULT = Catalog.DEFAULT,
		get = function(id: string)
			return rows[id]
		end,
		isOpen = Catalog.isOpen,
	}
end

return {
	["stored mission wins"] = function()
		eq(MissionPick.choose({ mission = "mile14" }, "delta", 0, Catalog), "mile14", "stored")
	end,

	["tagged used when nothing stored"] = function()
		eq(MissionPick.choose(nil, "mile14", 0, Catalog), "mile14", "tagged")
	end,

	["default when nothing stored or tagged"] = function()
		eq(MissionPick.choose(nil, nil, 0, Catalog), Catalog.DEFAULT, "default")
	end,

	["garbage stored falls back"] = function()
		eq(MissionPick.choose(42, nil, 0, Catalog), Catalog.DEFAULT, "a number")
		eq(MissionPick.choose({ mission = 7 }, nil, 0, Catalog), Catalog.DEFAULT, "a number id")
		eq(MissionPick.choose("mile14", nil, 0, Catalog), Catalog.DEFAULT, "a bare string")
	end,

	["unknown id falls back"] = function()
		eq(MissionPick.choose({ mission = "kestrel" }, nil, 0, Catalog), Catalog.DEFAULT, "stored")
		eq(MissionPick.choose(nil, "kestrel", 0, Catalog), Catalog.DEFAULT, "tagged")
	end,

	["closed window falls back to tagged then default"] = function()
		local cat = windowed()
		eq(MissionPick.choose({ mission = "mile14" }, "delta", 50, cat), "delta", "to tagged")
		eq(MissionPick.choose({ mission = "mile14" }, nil, 250, cat), cat.DEFAULT, "to default")
		eq(MissionPick.choose({ mission = "mile14" }, nil, 150, cat), "mile14", "inside")
	end,

	["launchRecord shape"] = function()
		local record = MissionPick.launchRecord("mile14", { 1, 2 })
		eq(record.mission, "mile14", "mission")
		eq(record.version, 1, "version")
		eq(#record.party, 2, "party size")
		eq(record.party[1], 1, "first")
		eq(record.party[2], 2, "second")
	end,

	["launchRecord reads back through choose"] = function()
		local record = MissionPick.launchRecord("mile14", { 1 })
		eq(MissionPick.choose(record, nil, 0, Catalog), "mile14", "round trip")
	end,
}
