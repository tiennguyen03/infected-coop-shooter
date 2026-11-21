--!strict
-- Which mission a match server builds (tests/MissionPick.spec.luau). The lobby writes a
-- launch record (`launchRecord`) to MemoryStore under the reserved server's PrivateServerId;
-- the match reads it at boot and passes it here with the place's own Workspace tag
-- (Attributes.Mission: a Studio test, or a place built for one mission). The first one that
-- names an open catalog row wins; anything else falls through to the catalog's default, so
-- a match always boots.

local MissionPick = {}

MissionPick.VERSION = 1

export type Record = { mission: string, party: { number }, version: number }

-- The catalog shape this reads (MissionCatalog, or a test's copy).
type Catalog = {
	DEFAULT: string,
	get: (id: string) -> any,
	isOpen: (row: any, now: number) -> boolean,
}

local function open(id: unknown, now: number, catalog: Catalog): boolean
	if typeof(id) ~= "string" then
		return false
	end
	local row = catalog.get(id)
	return row ~= nil and catalog.isOpen(row, now)
end

function MissionPick.choose(stored: unknown, tagged: unknown, now: number, catalog: Catalog): string
	if typeof(stored) == "table" then
		local id = (stored :: any).mission
		if open(id, now, catalog) then
			return id
		end
	end
	if open(tagged, now, catalog) then
		return tagged :: string
	end
	return catalog.DEFAULT
end

-- The value the lobby stores for one launch: the mission and who is going (UserIds).
function MissionPick.launchRecord(missionId: string, userIds: { number }): Record
	return { mission = missionId, party = table.clone(userIds), version = MissionPick.VERSION }
end

return MissionPick
