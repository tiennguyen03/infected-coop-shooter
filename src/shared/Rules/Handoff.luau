--!strict
-- The lobby <-> match handoff (docs/LOBBY_MATCH_HANDOFF.md): what the lobby place sends as
-- teleport data when it sends a party into a match, and what the match sends home. Pure and
-- unit-tested (tests/Handoff.spec.luau) so both places agree on one shape.
--
-- Teleport data is client-visible and can be forged: it only ever chooses things a player
-- could choose in the lobby anyway (a loadout from the catalog, the operation), and every
-- field is checked here. Progress (unlocks, containment) is never read from it.

local Handoff = {}

Handoff.VERSION = 1
Handoff.DEFAULT_OPERATION = "harlan_corridor"
Handoff.OUTCOMES = { win = true, partial = true, loss = true }

-- The loadout shape (Rules/Loadout) and the two checks the caller passes in, so this rule
-- needs no other module: `default` is Loadout.default(catalog), `isValid` wraps
-- Loadout.validate(loadout, catalog).
export type Loadout = {
	primary: string,
	secondary: string,
	grenade: string,
	callIns: { string },
	attachments: { [string]: { [string]: string } }?,
}
export type LoadoutCheck = { default: Loadout, isValid: (loadout: unknown) -> boolean }

-- What a joining player brings, after checking.
export type Join = {
	fromLobby: boolean, -- false in Studio, on a direct join, or when the data was unusable
	operation: string,
	partySize: number, -- players the lobby sent (1 when unknown); late or missing ones are normal
	slot: number?, -- the squad slot the lobby gave this player (1-4)
	-- The main objective the squad picked in the lobby (an ObjectiveDefinitions id), when
	-- the lobby sends one. The match plays it only if that map's pool offers it.
	objective: string?,
	loadout: Loadout,
}

export type MissionResult = { id: string, outcome: string, secondaries: number }
export type Result = {
	version: number,
	operation: string,
	missions: { MissionResult },
	standDown: boolean, -- the squad boarded at the last mission (vs a wipe)
}

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- `data` is `player:GetJoinData().TeleportData` (nil when there is none); `userId` the
-- joining player's; `check` the default loadout and the catalog check (see LoadoutCheck).
function Handoff.readJoin(data: unknown, userId: number, check: LoadoutCheck): Join
	local join: Join = {
		fromLobby = false,
		operation = Handoff.DEFAULT_OPERATION,
		partySize = 1,
		slot = nil,
		objective = nil,
		loadout = check.default,
	}
	if typeof(data) ~= "table" then
		return join
	end
	local raw = data :: { [string]: unknown }
	if raw.version ~= Handoff.VERSION or typeof(raw.party) ~= "table" then
		return join
	end
	join.fromLobby = true
	if typeof(raw.operation) == "string" then
		join.operation = raw.operation
	end
	if typeof(raw.objective) == "string" then
		join.objective = raw.objective
	end
	local party = raw.party :: { [string]: unknown }
	join.partySize = math.clamp(count(party), 1, 4)
	local mine = party[tostring(userId)]
	if typeof(mine) ~= "table" then
		return join
	end
	local member = mine :: { [string]: unknown }
	local slot = member.slot
	if typeof(slot) == "number" and slot >= 1 and slot <= 4 and slot == math.floor(slot) then
		join.slot = slot
	end
	if check.isValid(member.loadout) then
		join.loadout = member.loadout :: Loadout
	end
	return join
end

-- The teleport data the match sends the party home with. Unknown outcomes count as a loss.
function Handoff.result(operation: string, missions: { MissionResult }, standDown: boolean): Result
	local clean: { MissionResult } = {}
	for _, mission in missions do
		table.insert(clean, {
			id = mission.id,
			outcome = if Handoff.OUTCOMES[mission.outcome] then mission.outcome else "loss",
			secondaries = math.max(0, math.floor(mission.secondaries)),
		})
	end
	return {
		version = Handoff.VERSION,
		operation = operation,
		missions = clean,
		standDown = standDown,
	}
end

-- The lobby's side of the trip in: the teleport data for the soldiers aboard one Lantern, in
-- boarding order (slot 1 first), at most four. `loadouts` by UserId is optional: a member
-- without one gets the match's default (the lobby issues none yet). `objective` is
-- optional: the main objective the squad chose (nothing in the lobby sets it yet).
function Handoff.departure(
	operation: string,
	aboard: { number },
	loadouts: { [number]: Loadout }?,
	objective: string?
): { [string]: any }
	local party: { [string]: any } = {}
	for index, userId in aboard do
		if index > 4 then
			break
		end
		local member: { [string]: any } = { slot = index }
		local loadout = loadouts and loadouts[userId]
		if loadout then
			member.loadout = loadout
		end
		party[tostring(userId)] = member
	end
	return {
		version = Handoff.VERSION,
		operation = operation,
		party = party,
		objective = objective,
	}
end

-- A mission's outcome from how its run ended (RunStates result) and whether the Primary was
-- done: extracted is a win, a wipe after the Primary partial, any other wipe a loss.
function Handoff.outcome(runResult: string, primaryDone: boolean): string
	if runResult == "Extracted" then
		return "win"
	end
	return if primaryDone then "partial" else "loss"
end

-- The lobby's side of the trip home: the Result the match sent, or nil when the data is not
-- one (no data, another version, a field of the wrong type, an unknown outcome).
function Handoff.readResult(data: unknown): Result?
	if typeof(data) ~= "table" then
		return nil
	end
	local raw = data :: { [string]: unknown }
	if raw.version ~= Handoff.VERSION or typeof(raw.operation) ~= "string" then
		return nil
	end
	if typeof(raw.missions) ~= "table" or typeof(raw.standDown) ~= "boolean" then
		return nil
	end
	local missions: { MissionResult } = {}
	for _, entry in raw.missions :: { unknown } do
		if typeof(entry) ~= "table" then
			return nil
		end
		local mission = entry :: { [string]: unknown }
		local outcome = mission.outcome
		if
			typeof(mission.id) ~= "string"
			or typeof(outcome) ~= "string"
			or not Handoff.OUTCOMES[outcome]
			or typeof(mission.secondaries) ~= "number"
		then
			return nil
		end
		table.insert(missions, {
			id = mission.id :: string,
			outcome = outcome,
			secondaries = mission.secondaries :: number,
		})
	end
	return {
		version = Handoff.VERSION,
		operation = raw.operation :: string,
		missions = missions,
		standDown = raw.standDown :: boolean,
	}
end

return Handoff
