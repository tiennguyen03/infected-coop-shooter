--!strict
-- Config.luau itself, loaded with Lune's Roblox datatypes, for specs that check the shipped
-- rows (not a spec: the runner only runs *.spec.luau). Same loader as tests/Sight.spec.luau.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ObjectiveDefinitions = require("../src/shared/ObjectiveDefinitions")

local cached: any = nil

return function(): any
	if cached then
		return cached
	end
	local env = {
		Vector3 = (roblox :: any).Vector3,
		Vector2 = (roblox :: any).Vector2,
		CFrame = (roblox :: any).CFrame,
		Color3 = (roblox :: any).Color3,
		UDim2 = (roblox :: any).UDim2,
		Enum = (roblox :: any).Enum,
		math = math,
		table = table,
		string = string,
		-- Config requires its one sibling, script.Parent.ObjectiveDefinitions.
		script = { Parent = { ObjectiveDefinitions = ObjectiveDefinitions } },
		require = function(module: any): any
			return module
		end,
	}
	local chunk = luau.load(
		fs.readFile("src/shared/Config.luau"),
		{ debugName = "Config", environment = env }
	)
	cached = chunk()
	return cached
end
