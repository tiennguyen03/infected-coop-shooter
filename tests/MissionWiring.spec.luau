--!strict
-- How missions are wired between files, read from the source text (loop sprint 1,
-- docs/superpowers/plans/2026-11-20-sprint1-pick-a-mission.md): the match builds the mission
-- the lobby launched, and every map-specific value comes from the mission file, not from a
-- Config value only Checkpoint Delta has. Not a Rules spec: it guards the wiring.

local fs = require("@lune/fs")

type File = { path: string, text: string }

local function walk(dir: string, out: { File })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, { path = path, text = fs.readFile(path) })
		end
	end
end

local files: { File } = {}
for _, root in { "src/server", "src/client", "src/shared", "src/lobby" } do
	walk(root, files)
end

-- Files whose text contains `needle` (plain find), minus the allowed paths.
local function readers(needle: string, allowed: { string }): { string }
	local out = {}
	for _, file in files do
		if string.find(file.text, needle, 1, true) then
			local ok = false
			for _, path in allowed do
				if file.path == path then
					ok = true
				end
			end
			if not ok then
				table.insert(out, file.path)
			end
		end
	end
	return out
end

local function none(found: { string }, what: string)
	if #found > 0 then
		error(`{what}:\n  ` .. table.concat(found, "\n  "), 2)
	end
end

return {
	["Config.Operation.Missions is read nowhere (the catalog picks the mission)"] = function()
		none(readers("Operation.Missions", {}), "still read by")
	end,

	["Extraction.ZonePosition is read only by Delta's mission file and the client's fallback"] = function()
		none(
			readers("Extraction.ZonePosition", {
				"src/server/Missions/Delta.luau",
				"src/client/InsertionCutscene.luau",
				"src/shared/Config.luau",
			}),
			"Delta's landing pad is still read directly by"
		)
	end,

	["Objective.ZonePosition is read only by Delta's mission file"] = function()
		none(
			readers(
				"Objective.ZonePosition",
				{ "src/server/Missions/Delta.luau", "src/shared/Config.luau" }
			),
			"Delta's hold point is still read directly by"
		)
	end,

	["the Warden's Delta route is read only by Delta's mission file"] = function()
		local found = {}
		for _, needle in
			{ "settings.SpawnPosition", "settings.Waypoints", "settings.WaypointRadio" }
		do
			for _, path in readers(needle, {}) do
				table.insert(found, `{path} ({needle})`)
			end
		end
		none(found, "the Warden's route is still read from Config by")
	end,

	["ArenaService has no single HALF constant (each mission has its own frame)"] = function()
		local text = fs.readFile("src/server/ArenaService.luau")
		if string.find(text, "local HALF = ", 1, true) then
			error("ArenaService still fixes the map at one size", 0)
		end
	end,
}
