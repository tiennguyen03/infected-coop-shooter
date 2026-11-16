--!strict
-- The real objective pools (src/shared/ObjectiveDefinitions.luau), checked the way
-- Rules/Objectives.validate checks any: every map lists only objectives that exist, has a
-- signature main objective of its own, and gives each listed objective the sites it needs.
-- Also: each row's module is on disk, and no line uses a word the owner ruled out.

local fs = require("@lune/fs")

local Definitions = require("../src/shared/ObjectiveDefinitions")
local Objectives = require("../src/shared/Rules/Objectives")

local function fail(problems: { string })
	if #problems > 0 then
		error("\n  " .. table.concat(problems, "\n  "), 2)
	end
end

-- Plain words for players (docs/OWNER.md, 2026-11-11): none of the coined names.
local BANNED = { "Primary", "Secondary", "Index", "Lantern", "NCOIC", "the Burn", "nets" }

return {
	["the pools are sound"] = function()
		fail(Objectives.validate(Definitions.Rows :: any, Definitions.Maps :: any))
	end,
	["every objective's module exists"] = function()
		local problems = {}
		for id, row in Definitions.Rows do
			if not fs.isFile(`src/server/Objectives/{row.Module}.luau`) then
				table.insert(problems, `{id}: no src/server/Objectives/{row.Module}.luau`)
			end
		end
		fail(problems)
	end,
	["every objective is offered on some map"] = function()
		local listed: { [string]: boolean } = {}
		for _, map in Definitions.Maps do
			for _, pool in { map.Main, map.Side } do
				for _, pick in pool do
					listed[pick.Id] = true
				end
			end
		end
		local problems = {}
		for id in Definitions.Rows do
			if not listed[id] then
				table.insert(problems, `{id} is in no map's pool`)
			end
		end
		fail(problems)
	end,
	["every position is three numbers"] = function()
		local problems = {}
		local function check(where: string, value: any)
			if typeof(value) ~= "table" or #value ~= 3 then
				table.insert(problems, `{where} is not x, y, z`)
			end
		end
		for mapId, map in Definitions.Maps do
			for id, sites in map.Sites do
				for index, site in sites do
					local where = `{mapId}.{id}[{index}]`
					check(`{where}.Position`, site.Position)
					for _, field in { "Size", "To" } do
						if (site :: any)[field] ~= nil then
							check(`{where}.{field}`, (site :: any)[field])
						end
					end
					for _, field in { "Points", "Spawns" } do
						for at, point in (site :: any)[field] or {} do
							check(`{where}.{field}[{at}]`, point)
						end
					end
				end
			end
		end
		fail(problems)
	end,
	["the players' lines use plain words"] = function()
		local problems = {}
		for id, row in Definitions.Rows do
			for _, field in { "Name", "Brief", "Why", "Done", "Failed" } do
				local text = (row :: any)[field]
				if typeof(text) == "string" then
					for _, word in BANNED do
						if string.find(text, word, 1, true) then
							table.insert(problems, `{id}.{field} says "{word}"`)
						end
					end
				end
			end
		end
		fail(problems)
	end,
}
