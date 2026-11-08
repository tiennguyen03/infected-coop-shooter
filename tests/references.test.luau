-- References between files that the type checker cannot see, because they are strings or
-- instance paths: remote names, upgrade and call-in ids, require paths, and every module
-- with an init() being started from its Main.

local Shared = require("./lib/shared")
local Source = require("./lib/source")

local function declaredRemotes(): { [string]: boolean }
	local text = Source.read("src/shared/Remotes.luau")
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

local function checkRemotes(t)
	local declared = declaredRemotes()
	local used: { [string]: boolean } = {}
	for _, file in Source.files() do
		for name in string.gmatch(file.text, 'Remotes%.get%("(%w+)"%)') do
			used[name] = true
			t.check(declared[name] == true, `{file.path} uses undeclared remote "{name}"`)
		end
	end
	for name in declared do
		t.check(used[name] == true, `remote "{name}" is declared but never used`)
	end
end

local function checkIds(t)
	local upgrades = Shared.require("UpgradeDefinitions").Rows
	local callIns = Shared.require("CallInDefinitions").Rows
	local weapons = Shared.require("WeaponDefinitions").Rows
	for _, file in Source.files() do
		local text = file.text
		for id in string.gmatch(text, 'hasUpgrade%([^,]+,%s*"([%w_]+)"%)') do
			local row = upgrades[id]
			local ok = row ~= nil and row.Kind == "upgrade"
			t.check(ok, `{file.path} checks unknown upgrade "{id}"`)
		end
		for id in string.gmatch(text, 'UpgradeDefinitions%.get%("([%w_]+)"%)') do
			t.check(upgrades[id] ~= nil, `{file.path} looks up unknown card "{id}"`)
		end
		for id in string.gmatch(text, 'CallInDefinitions%.get%("([%w_]+)"%)') do
			t.check(callIns[id] ~= nil, `{file.path} looks up unknown call-in "{id}"`)
		end
		for id in string.gmatch(text, 'WeaponDefinitions%.get%("([%w_]+)"%)') do
			t.check(weapons[id] ~= nil, `{file.path} looks up unknown weapon "{id}"`)
		end
		for id in string.gmatch(text, 'Id == "([%w_]+)"') do
			local known = upgrades[id] or callIns[id] or weapons[id]
			t.check(known ~= nil, `{file.path} compares against unknown id "{id}"`)
		end
	end
end

local function checkRequires(t)
	for _, file in Source.files() do
		local text = file.text
		for name in string.gmatch(text, "require%(script%.Parent%.([%w_]+)%)") do
			local path = `{file.dir}/{name}`
			local found = Source.exists(`{path}.luau`) or Source.exists(path)
			t.check(found, `{file.path} requires missing sibling "{name}"`)
		end
		for name in string.gmatch(text, "require%(ReplicatedStorage%.Shared%.([%w_]+)") do
			local path = `src/shared/{name}`
			local found = Source.exists(`{path}.luau`) or Source.exists(path)
			t.check(found, `{file.path} requires missing shared module "{name}"`)
		end
		local waitForShared = 'WaitForChild%("Shared"%):WaitForChild%("([%w_]+)"%)'
		for name in string.gmatch(text, waitForShared) do
			local path = `src/shared/{name}`
			local found = Source.exists(`{path}.luau`) or Source.exists(path)
			t.check(found, `{file.path} waits for missing shared module "{name}"`)
		end
	end
end

-- A module with an init() that its side's Main never starts would silently do nothing.
local function checkStarted(t)
	local mains = {
		["src/server"] = Source.read("src/server/Main.server.luau"),
		["src/client"] = Source.read("src/client/Main.client.luau"),
	}
	for _, file in Source.files() do
		local main = mains[file.dir]
		local name = string.match(file.name, "^([%w_]+)%.luau$")
		if main and name then
			local hasInit = string.find(file.text, `function {name}.init(`, 1, true) ~= nil
			local started = string.find(main, `script.Parent.{name}).init()`, 1, true) ~= nil
			t.check(not hasInit or started, `{file.path} has init() but Main never starts it`)
		end
	end
end

return function(t)
	checkRemotes(t)
	checkIds(t)
	checkRequires(t)
	checkStarted(t)
end
