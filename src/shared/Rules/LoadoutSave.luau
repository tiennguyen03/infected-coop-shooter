--!strict
-- The saved form of a soldier's signed Loadout (LoadmasterService keeps it between visits;
-- docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout). Pure, unit-tested with Lune
-- (tests/LoadoutSave.spec.luau). A version number from day one (docs/ARCHITECTURE.md F9);
-- reading back runs the caller's validator (Rules/Loadout against today's catalog), so a save
-- naming a retired gun, or written in another format, reads as nil and the default is used.
-- Rules modules do not require each other, hence the validator.

local LoadoutSave = {}

LoadoutSave.VERSION = 1

-- Same shape as Rules/Loadout's Loadout.
export type Loadout = {
	primary: string,
	secondary: string,
	grenade: string,
	callIns: { string },
	attachments: { [string]: { [string]: string } }?,
}

export type Saved = {
	version: number,
	loadout: Loadout,
}

local function copy(loadout: Loadout): Loadout
	local attachments: { [string]: { [string]: string } }? = nil
	if loadout.attachments then
		local copied = {}
		for gun, slots in loadout.attachments do
			copied[gun] = table.clone(slots)
		end
		attachments = copied
	end
	return {
		primary = loadout.primary,
		secondary = loadout.secondary,
		grenade = loadout.grenade,
		callIns = table.clone(loadout.callIns),
		attachments = attachments,
	}
end

function LoadoutSave.encode(loadout: Loadout): Saved
	return { version = LoadoutSave.VERSION, loadout = copy(loadout) }
end

function LoadoutSave.decode(data: unknown, isValid: (loadout: unknown) -> boolean): Loadout?
	if typeof(data) ~= "table" then
		return nil
	end
	local saved = data :: any
	if saved.version ~= LoadoutSave.VERSION or not isValid(saved.loadout) then
		return nil
	end
	return copy(saved.loadout :: Loadout)
end

return LoadoutSave
