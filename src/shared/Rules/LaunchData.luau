--!strict
-- What a Lantern launch carries from the lobby into the match (teleport data; docs/
-- MULTIPLAYER_READINESS.md decision 7): the spot, the party's UserIds and each soldier's
-- Loadout as signed at the Loadmaster. Pure, unit-tested with Lune (tests/LaunchData.spec).
-- Teleport data is JSON, so loadouts are keyed by the UserId as a string. The match never
-- trusts it: `loadoutFor` runs the caller's validator (Rules/Loadout.validate against the
-- match's own catalog) and answers nil for anything missing or wrong; the caller falls back
-- to the default Loadout. Rules modules do not require each other, hence the validator.

local LaunchData = {}

-- Same shape as Rules/Loadout's Loadout.
export type Loadout = {
	primary: string,
	secondary: string,
	grenade: string,
	callIns: { string },
}

export type Data = {
	spot: number,
	party: { number },
	loadouts: { [string]: Loadout },
}

export type Validator = (loadout: unknown) -> boolean

local function copy(loadout: Loadout): Loadout
	return {
		primary = loadout.primary,
		secondary = loadout.secondary,
		grenade = loadout.grenade,
		callIns = table.clone(loadout.callIns),
	}
end

function LaunchData.encode(spot: number, party: { number }, loadouts: { [number]: Loadout }): Data
	local byKey: { [string]: Loadout } = {}
	for userId, loadout in loadouts do
		byKey[tostring(userId)] = copy(loadout)
	end
	return { spot = spot, party = table.clone(party), loadouts = byKey }
end

function LaunchData.loadoutFor(data: unknown, userId: number, isValid: Validator): Loadout?
	if typeof(data) ~= "table" then
		return nil
	end
	local loadouts = (data :: any).loadouts
	if typeof(loadouts) ~= "table" then
		return nil
	end
	local entry = loadouts[tostring(userId)]
	if not isValid(entry) then
		return nil
	end
	return copy(entry :: Loadout)
end

return LaunchData
