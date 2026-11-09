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
export type Loadout = { primary: string, secondary: string, grenade: string, callIns: { string } }
export type LoadoutCheck = { default: Loadout, isValid: (loadout: unknown) -> boolean }

-- What a joining player brings, after checking.
export type Join = {
	fromLobby: boolean, -- false in Studio, on a direct join, or when the data was unusable
	operation: string,
	partySize: number, -- players the lobby sent (1 when unknown); late or missing ones are normal
	slot: number?, -- the squad slot the lobby gave this player (1-4)
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

return Handoff
