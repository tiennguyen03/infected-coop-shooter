--!strict
-- Cross-file references the type checker cannot see, read from the source text: remote names
-- (Remotes.get takes a string, and a misspelt one waits forever for a remote that never
-- appears), require paths, the server BOOT list, and modules whose init() nobody calls.
-- Not a Rules spec: it guards the wiring between modules (docs/ARCHITECTURE.md F5).

local fs = require("@lune/fs")

type File = { path: string, dir: string, name: string, text: string }

local function walk(dir: string, out: { File })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, out)
		else
			local module = string.match(name, "^(.+)%.luau$")
			if module then
				local text = fs.readFile(path)
				table.insert(out, { path = path, dir = dir, name = module, text = text })
			end
		end
	end
end

local files: { File } = {}
for _, root in { "src/server", "src/client", "src/shared" } do
	walk(root, files)
end
-- The lobby place's own code: only for the remote check (its requires of match modules
-- go through lobby.project.json mappings, which are not siblings on disk).
local withLobby: { File } = table.clone(files)
walk("src/lobby", withLobby)

local function exists(path: string): boolean
	return fs.isFile(`{path}.luau`) or fs.isDir(path)
end

local function fail(problems: { string })
	if #problems > 0 then
		error("\n  " .. table.concat(problems, "\n  "), 2)
	end
end

local function declaredRemotes(): { [string]: boolean }
	local text = fs.readFile("src/shared/Remotes.luau")
	local block = string.match(text, "local REMOTE_NAMES = (%b{})") or ""
	local names = {}
	-- One name per line, before its comment: `"FireWeapon", -- client -> server ...`.
	for line in string.gmatch(block, "[^\n]+") do
		local name = string.match(line, '^%s*"(%w+)",')
		if name then
			names[name] = true
		end
	end
	return names
end

return {
	["every remote used is declared, and every declared remote is used"] = function()
		local declared = declaredRemotes()
		local used: { [string]: boolean } = {}
		local problems = {}
		for _, file in withLobby do
			for name in string.gmatch(file.text, 'Remotes%.get%("(%w+)"%)') do
				used[name] = true
				if not declared[name] then
					table.insert(problems, `{file.path}: remote "{name}" is not in REMOTE_NAMES`)
				end
			end
		end
		for name in declared do
			if not used[name] then
				table.insert(problems, `remote "{name}" is declared but nothing uses it`)
			end
		end
		if next(declared) == nil then
			table.insert(problems, "found no names in Remotes.luau's REMOTE_NAMES (table moved?)")
		end
		fail(problems)
	end,

	["every required module exists"] = function()
		local problems = {}
		local sharedForms = {
			"require%(ReplicatedStorage%.Shared%.([%w_]+)",
			'Shared:WaitForChild%("([%w_]+)"%)',
		}
		for _, file in files do
			for name in string.gmatch(file.text, "require%(script%.Parent%.([%w_]+)") do
				if not exists(`{file.dir}/{name}`) then
					table.insert(problems, `{file.path}: no sibling module "{name}"`)
				end
			end
			for _, form in sharedForms do
				for name in string.gmatch(file.text, form) do
					if not exists(`src/shared/{name}`) then
						table.insert(problems, `{file.path}: no shared module "{name}"`)
					end
				end
			end
		end
		fail(problems)
	end,

	["every module in the server BOOT list exists"] = function()
		local main = fs.readFile("src/server/Main.server.luau")
		local boot = string.match(main, "local BOOT: [^=]+= (%b{})") or ""
		local problems = {}
		for folder, name in string.gmatch(boot, "(%w+)%.([%w_]+),") do
			local dir = if folder == "Shared" then "src/shared" else "src/server"
			if not exists(`{dir}/{name}`) then
				table.insert(problems, `BOOT names {folder}.{name}, which does not exist`)
			end
		end
		if boot == "" then
			table.insert(problems, "found no BOOT list in Main.server.luau (renamed?)")
		end
		fail(problems)
	end,

	["every module with an init() is started by something"] = function()
		local everything = {}
		for _, file in files do
			table.insert(everything, file.text)
		end
		local source = table.concat(everything, "\n")
		local main = fs.readFile("src/server/Main.server.luau")
		local problems = {}
		for _, file in files do
			if string.find(file.text, `function {file.name}.init(`, 1, true) then
				local fromBoot = string.find(main, `.{file.name},`, 1, true) ~= nil
				local direct = string.find(source, `{file.name}).init()`, 1, true) ~= nil
				-- `Name.init()` calls, minus the `function Name.init()` definition itself.
				local _, calls = string.gsub(source, `{file.name}%.init%(%)`, "")
				local _, defs = string.gsub(source, `function {file.name}%.init%(%)`, "")
				if not (fromBoot or direct or calls > defs) then
					table.insert(problems, `{file.path} has init() but nothing calls it`)
				end
			end
		end
		fail(problems)
	end,
}
