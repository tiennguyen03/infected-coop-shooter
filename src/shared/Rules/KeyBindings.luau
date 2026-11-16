--!strict
-- Keys as the player reads them, and the one-key-one-action rule for Config.Keys. Pure: it
-- works on KeyCode names (`Enum.KeyCode.E.Name`), so tests/KeyBindings.spec.luau can check
-- the Config.Keys table from its source.

local KeyBindings = {}

-- KeyCode names that do not read as the key's cap.
local LABELS: { [string]: string } = {
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftAlt = "Alt",
	RightAlt = "Alt",
}

-- What a hint shows for a key: label(Config.Keys.Stim.Name) -> "V".
function KeyBindings.label(name: string): string
	return LABELS[name] or name
end

-- An action with more than one key: labels({ "C", "LeftControl" }) -> "C / Ctrl".
function KeyBindings.labels(names: { string }): string
	local out = {}
	for _, name in names do
		table.insert(out, KeyBindings.label(name))
	end
	return table.concat(out, " / ")
end

-- Every key that two actions (or one action twice) claim, as sorted sentences. `shared`
-- lists the pairs of actions that may share a key because they never listen together.
function KeyBindings.clashes(bindings: { [string]: { string } }, shared: { { string } }): { string }
	local allowed: { [string]: boolean } = {}
	for _, pair in shared do
		allowed[`{pair[1]}|{pair[2]}`] = true
		allowed[`{pair[2]}|{pair[1]}`] = true
	end
	local actions = {}
	for action in bindings do
		table.insert(actions, action)
	end
	table.sort(actions)
	local owners: { [string]: { string } } = {}
	local problems = {}
	for _, action in actions do
		local seen: { [string]: boolean } = {}
		for _, key in bindings[action] do
			if seen[key] then
				table.insert(problems, `{action} lists {key} twice`)
				continue
			end
			seen[key] = true
			local held: { string } = owners[key] or {}
			for _, other in held do
				if not allowed[`{other}|{action}`] then
					table.insert(problems, `{key} is bound to both {other} and {action}`)
				end
			end
			table.insert(held, action)
			owners[key] = held
		end
	end
	return problems
end

return KeyBindings
