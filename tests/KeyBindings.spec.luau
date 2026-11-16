--!strict
-- Config.Keys: one key, one action. Config.luau cannot load outside Roblox (Enum, Vector3),
-- so the table is read from its source text.
local fs = require("@lune/fs")
local KeyBindings = require("../src/shared/Rules/KeyBindings")
local expect = require("./expect")

-- Actions that may share a key because they never listen at the same time: Roll and Slide
-- only while sprinting, Crouch only while not (StanceController skips its keys then).
local SHARED = { { "Crouch", "Roll" }, { "Crouch", "Slide" } }

-- A list here is one key per slot (each slot its own action), not alternatives for one.
local PER_SLOT: { [string]: boolean } = { CallIns = true }

local function configKeys(): { [string]: { string } }
	local text = fs.readFile("src/shared/Config.luau")
	local block = string.match(text, "\n\tKeys = (%b{})") or ""
	local bindings: { [string]: { string } } = {}
	local action: string? = nil
	for line in string.gmatch(block, "[^\n]+") do
		local code = string.gsub(line, "%-%-.*$", "")
		action = string.match(code, "^%s*(%w+) = ") or action
		for key in string.gmatch(code, "Enum%.KeyCode%.(%w+)") do
			if action and PER_SLOT[action] then
				local slot = 1
				while bindings[`{action}[{slot}]`] do
					slot += 1
				end
				bindings[`{action}[{slot}]`] = { key }
			elseif action then
				local keys = bindings[action] or {}
				table.insert(keys, key)
				bindings[action] = keys
			end
		end
	end
	return bindings
end

return {
	["a key reads as its cap"] = function()
		expect.equal(KeyBindings.label("E"), "E", "letter")
		expect.equal(KeyBindings.label("Five"), "5", "digit")
		expect.equal(KeyBindings.label("LeftControl"), "Ctrl", "control")
		expect.equal(KeyBindings.labels({ "C", "LeftControl" }), "C / Ctrl", "two keys")
	end,
	["two actions on one key is a clash unless the pair is allowed"] = function()
		local bindings = { Stim = { "E" }, Interact = { "E" }, Crouch = { "C" }, Slide = { "C" } }
		local problems = KeyBindings.clashes(bindings, { { "Crouch", "Slide" } })
		expect.equal(#problems, 1, "clashes")
		expect.equal(problems[1], "E is bound to both Interact and Stim", "which")
		expect.equal(#KeyBindings.clashes({ A = { "X", "X" } }, {}), 1, "same key twice")
	end,
	["Config.Keys gives no key to two actions"] = function()
		local bindings = configKeys()
		for _, action in { "Interact", "Stim", "Shove", "Crouch", "Prone", "Flare", "CallIns[4]" } do
			if not bindings[action] then
				error(`Config.Keys.{action} not found (table moved or renamed?)`)
			end
		end
		local problems = KeyBindings.clashes(bindings, SHARED)
		if #problems > 0 then
			error("\n  " .. table.concat(problems, "\n  "))
		end
	end,
}
