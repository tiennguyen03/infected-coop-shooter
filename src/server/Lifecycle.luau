--!strict
-- The lifecycle registry (docs/ARCHITECTURE.md F2). Every service with run, sortie,
-- operation or per-player state registers its hooks here from its own init(); RunManager
-- fires the phases and never names a service. A service that forgets to register is the one
-- that leaks state, so registration lives next to the state it resets.
--
-- Phases:
--   onRunStart       a fresh run (RunManager.startRun), every registered hook once
--   onSortieStart    a new sortie inside an operation (the campaign; fired when it exists)
--   onOperationStart a new operation (the campaign; fired when it exists)
--   onPlayerReset    one player's state back to a fresh start, after onRunStart
--   onPlayerRemoving one player left the server (connected once, here)
--
-- Hooks run in registration order (boot order), each in pcall: one hook's error is warned
-- with the service's name and the others still run. A hook registered with `last = true`
-- runs after every other hook of its phase (Squad's revive counter goes last).

local Players = game:GetService("Players")

local Lifecycle = {}

export type Hooks = {
	onRunStart: (() -> ())?,
	onSortieStart: (() -> ())?,
	onOperationStart: (() -> ())?,
	onPlayerReset: ((Player) -> ())?,
	onPlayerRemoving: ((Player) -> ())?,
	last: boolean?,
}

type Entry = { name: string, hooks: Hooks }

local entries: { Entry } = {}

local function ordered(): { Entry }
	local first: { Entry }, late: { Entry } = {}, {}
	for _, entry in entries do
		table.insert(if entry.hooks.last then late else first, entry)
	end
	for _, entry in late do
		table.insert(first, entry)
	end
	return first
end

local function call(phase: string, name: string, hook: (...any) -> ...any, ...: any)
	local ok, err = pcall(hook, ...)
	if not ok then
		warn(`[Lifecycle] {name}.{phase} failed: {err}`)
	end
end

-- Registers `hooks` under `name` (the service's module name). Call once, from init().
function Lifecycle.register(name: string, hooks: Hooks)
	for _, entry in entries do
		assert(entry.name ~= name, `[Lifecycle] {name} registered twice`)
	end
	table.insert(entries, { name = name, hooks = hooks })
end

function Lifecycle.runStart()
	for _, entry in ordered() do
		local hook = entry.hooks.onRunStart
		if hook then
			call("onRunStart", entry.name, hook)
		end
	end
end

function Lifecycle.sortieStart()
	for _, entry in ordered() do
		local hook = entry.hooks.onSortieStart
		if hook then
			call("onSortieStart", entry.name, hook)
		end
	end
end

function Lifecycle.operationStart()
	for _, entry in ordered() do
		local hook = entry.hooks.onOperationStart
		if hook then
			call("onOperationStart", entry.name, hook)
		end
	end
end

function Lifecycle.playerReset(player: Player)
	for _, entry in ordered() do
		local hook = entry.hooks.onPlayerReset
		if hook then
			call("onPlayerReset", entry.name, hook, player)
		end
	end
end

-- Names of every registered service, in the order their hooks run.
function Lifecycle.registered(): { string }
	local names = {}
	for _, entry in ordered() do
		table.insert(names, entry.name)
	end
	return names
end

function Lifecycle.init()
	Players.PlayerRemoving:Connect(function(player)
		for _, entry in ordered() do
			local hook = entry.hooks.onPlayerRemoving
			if hook then
				call("onPlayerRemoving", entry.name, hook, player)
			end
		end
	end)
end

return Lifecycle
