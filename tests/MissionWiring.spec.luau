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

	["the MissionBoard remote is used by the board's service and UI"] = function()
		for _, path in
			{ "src/lobby/server/MissionBoardService.luau", "src/lobby/client/MissionBoardUI.luau" }
		do
			if not fs.isFile(path) then
				error(`{path} is missing`, 0)
			end
			if not string.find(fs.readFile(path), 'Remotes.get("MissionBoard")', 1, true) then
				error(`{path} does not use the MissionBoard remote`, 0)
			end
		end
	end,

	["LaunchService writes the launch record before teleporting"] = function()
		local text = fs.readFile("src/lobby/server/LaunchService.luau")
		local body = string.match(text, "function LaunchService%.send%(.-\nend\n")
		if not body then
			error("no LaunchService.send", 0)
		end
		local write = string.find(body, ":SetAsync(", 1, true)
		local teleport = string.find(body, "TeleportAsync(", 1, true)
		if not write or not teleport or write > teleport then
			error("send must store the launch record (SetAsync) before TeleportAsync", 0)
		end
	end,

	["the pad rings launch through LaunchService.send"] = function()
		local text = fs.readFile("src/lobby/server/LaunchService.luau")
		local lift = string.match(text, "local function lift%(.-\nend\n") or ""
		if string.find(lift, "TeleportAsync(", 1, true) then
			error("lift teleports by itself; it should call send", 0)
		end
	end,

	["MissionBoardService refuses a mission that is not open"] = function()
		local path = "src/lobby/server/MissionBoardService.luau"
		if
			not fs.isFile(path)
			or not string.find(fs.readFile(path), "MissionCatalog.isOpen(", 1, true)
		then
			error("MissionBoardService does not check MissionCatalog.isOpen", 0)
		end
	end,

	-- Final review fixes (loop sprint 1).
	["Infected spawns are clamped per axis to the mission's frame"] = function()
		local arena = fs.readFile("src/server/ArenaService.luau")
		if
			not string.find(arena, "function ArenaService.spawnInset(): (number, number)", 1, true)
		then
			error("spawnInset must return an x and a z inset (the frame is not square)", 0)
		end
		local enemy = fs.readFile("src/server/EnemyService.luau")
		if not string.find(enemy, "local insetX, insetZ = ArenaService.spawnInset()", 1, true) then
			error("EnemyService must clamp x and z by their own insets", 0)
		end
	end,

	["Delta's outer scenery is built only where the mission asks for it"] = function()
		local arena = fs.readFile("src/server/ArenaService.luau")
		local perimeter = string.match(arena, "local function buildPerimeter%(.-\nend\n") or ""
		if not string.find(perimeter, "FEATURES.Outskirts", 1, true) then
			error("buildPerimeter builds Delta's outskirts on every mission", 0)
		end
	end,

	["the match builds the catalog row's Layout and plays its Pool"] = function()
		local init = fs.readFile("src/server/Missions/init.luau")
		if not string.find(init, "byLayout[row.Layout]", 1, true) then
			error("Missions.current ignores the row's Layout", 0)
		end
		local objectives = fs.readFile("src/server/ObjectiveService.luau")
		if not string.find(objectives, "Missions.row().Pool", 1, true) then
			error("ObjectiveService ignores the row's Pool", 0)
		end
	end,

	-- Loop sprint 2: parties.
	["the Party remote is used by PartyService and PartyUI"] = function()
		for _, path in { "src/lobby/server/PartyService.luau", "src/lobby/client/PartyUI.luau" } do
			if not fs.isFile(path) then
				error(`{path} is missing`, 0)
			end
			if not string.find(fs.readFile(path), 'Remotes.get("Party")', 1, true) then
				error(`{path} does not use the Party remote`, 0)
			end
		end
	end,

	["the Mission Board launches through the party"] = function()
		local text = fs.readFile("src/lobby/server/MissionBoardService.luau")
		if not string.find(text, "PartyService.", 1, true) then
			error("MissionBoardService does not go through PartyService", 0)
		end
	end,

	["the deck rings board only when Config.Lobby.Launch.RingsBoard is on"] = function()
		local text = fs.readFile("src/lobby/server/LaunchService.luau")
		if not string.find(text, "LAUNCH.RingsBoard", 1, true) then
			error("LaunchService boards from the rings regardless of RingsBoard", 0)
		end
	end,

	["a flying squad cannot change (no invite, accept, leave or kick mid-launch)"] = function()
		local text = fs.readFile("src/lobby/server/PartyService.luau")
		if not string.find(text, "local function busy(", 1, true) then
			error("PartyService has no busy() guard for a squad that is lifting", 0)
		end
	end,

	["a squad stays lifting after a teleport that went (no second DEPLOY)"] = function()
		local text = fs.readFile("src/lobby/server/PartyService.luau")
		local launch = string.match(text, "local function launch%(.-\nend\n") or ""
		-- Right after the send the squad must not be marked idle: only the failure branch and
		-- the LiftTimeout may clear it.
		if
			launch == ""
			or string.find(
				launch,
				"LaunchService%.send%(going, mission, nil%)%s*\n%s*flying%[party%] = nil"
			)
			or not string.find(launch, "LiftTimeout", 1, true)
		then
			error("launch clears flying even when the teleport went", 0)
		end
	end,

	-- Loop sprint 3: the city war.
	["the run end moves the war board"] = function()
		local text = fs.readFile("src/server/RunManager.luau")
		if not string.find(text, "WarService.flush(", 1, true) then
			error("RunManager never calls WarService.flush", 0)
		end
	end,

	["the lobby reads the war board from the shared store"] = function()
		local text = fs.readFile("src/lobby/server/ContainmentBoard.luau")
		if not string.find(text, "Config.War.Store", 1, true) then
			error("ContainmentBoard does not read the war store", 0)
		end
	end,

	["the Mission Board's cards show their district's percent"] = function()
		local text = fs.readFile("src/lobby/client/MissionBoardUI.luau")
		if not string.find(text, "Attributes.WarBoard", 1, true) then
			error("MissionBoardUI does not read the war board", 0)
		end
	end,

	["the war save is waited for at shutdown, capped per hour, and never from Studio"] = function()
		local text = fs.readFile("src/server/WarService.luau")
		for _, needle in { "game:BindToClose(", "MaxWritesPerServerHour", "IsStudio()" } do
			if not string.find(text, needle, 1, true) then
				error(`WarService is missing {needle}`, 0)
			end
		end
	end,

	["the client badge parser skips malformed districts"] = function()
		local text = fs.readFile("src/lobby/client/MissionBoardUI.luau")
		if not string.find(text, 'typeof(district.name) == "string"', 1, true) then
			error("MissionBoardUI indexes districts without checking them", 0)
		end
	end,
}
