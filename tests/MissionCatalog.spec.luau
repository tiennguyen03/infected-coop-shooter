--!strict
-- The mission catalog (src/shared/MissionCatalog.luau): every row points at a layout file and
-- an objective pool that exist, the board order lists each row once, and the words players
-- read on a card use plain language (docs/OWNER.md).

local fs = require("@lune/fs")

local Catalog = require("../src/shared/MissionCatalog")
local Definitions = require("../src/shared/ObjectiveDefinitions")

local BANNED = { "Primary", "Secondary", "Index", "Lantern", "NCOIC", "the Burn", "nets" }

local function check(ok: boolean, message: string)
	if not ok then
		error(message, 2)
	end
end

return {
	["every row's Layout file exists"] = function()
		for id, row in Catalog.Rows do
			local path = `src/server/Missions/{row.Layout}.luau`
			check(fs.isFile(path), `{id}: no layout file {path}`)
		end
	end,

	["every row's Pool is a map in ObjectiveDefinitions.Maps"] = function()
		for id, row in Catalog.Rows do
			check(Definitions.Maps[row.Pool] ~= nil, `{id}: no objective pool '{row.Pool}'`)
		end
	end,

	["every row's Id matches its key"] = function()
		for id, row in Catalog.Rows do
			check(row.Id == id, `{id}: Id is '{row.Id}'`)
		end
	end,

	["Order lists every row once"] = function()
		local seen: { [string]: boolean } = {}
		for _, id in Catalog.Order do
			check(Catalog.Rows[id] ~= nil, `Order names '{id}', which has no row`)
			check(not seen[id], `Order lists '{id}' twice`)
			seen[id] = true
		end
		for id in Catalog.Rows do
			check(seen[id] == true, `'{id}' is missing from Order`)
		end
	end,

	["DEFAULT is a row"] = function()
		check(Catalog.get(Catalog.DEFAULT) ~= nil, `DEFAULT '{Catalog.DEFAULT}' has no row`)
	end,

	["get returns nil for an unknown id"] = function()
		check(Catalog.get("kestrel_never") == nil, "unknown id returned a row")
	end,

	["isOpen respects Window"] = function()
		local row = table.clone(Catalog.Rows[Catalog.DEFAULT]) :: any
		row.Window = { From = 100, To = 200 }
		check(not Catalog.isOpen(row, 50), "open before From")
		check(Catalog.isOpen(row, 150), "closed inside the window")
		check(not Catalog.isOpen(row, 250), "open after To")
	end,

	["a row with no Window is open"] = function()
		for id, row in Catalog.Rows do
			if row.Window == nil then
				check(Catalog.isOpen(row, 0), `{id} closed with no Window`)
			end
		end
	end,

	["Delta and Mile 14 are open from day one"] = function()
		check(Catalog.get("delta") ~= nil and Catalog.get("mile14") ~= nil, "a row is missing")
		check(Catalog.Rows.delta.Window == nil, "delta has a window")
		check(Catalog.Rows.mile14.Window == nil, "mile14 has a window")
	end,

	["card words use no banned word"] = function()
		for id, row in Catalog.Rows do
			for _, word in BANNED do
				for _, text in { row.Name, row.Blurb, row.District } do
					check(not string.find(text, word, 1, true), `{id}: '{word}' in "{text}"`)
				end
			end
		end
	end,
}
