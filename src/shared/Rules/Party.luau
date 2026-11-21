--!strict
-- Squads on the Carrier (loop sprint 2; tests/Party.spec.luau). Every soldier is in at most
-- one party; a soldier with none leads a party of one. Parties are keyed by their leader's
-- UserId; invites by the invitee's UserId (one pending invite each, the newest wins). Only
-- the leader invites, kicks, picks the mission and deploys; deploying starts a countdown,
-- and the party flies when every member is ready or the countdown runs out. Times are the
-- caller's clock (PartyService: os.clock). Pure: the lobby's PartyService owns the tables.

local Party = {}

export type Party = {
	leader: number,
	members: { number }, -- leader first, then joining order
	ready: { [number]: boolean },
	mission: string?, -- the leader's pick (MissionCatalog id)
	deployAt: number?, -- when the countdown ends (nil = not deploying)
}

export type Parties = { [number]: Party }
export type Invites = { [number]: { from: number, at: number } }

local LAUNCH_PREFIX = "party"

-- The party `userId` is in, or nil.
function Party.of(parties: Parties, userId: number): Party?
	for _, party in parties do
		if table.find(party.members, userId) then
			return party
		end
	end
	return nil
end

-- The party `userId` is in, making them a party of one when they have none.
function Party.ensure(parties: Parties, userId: number): Party
	local party = Party.of(parties, userId)
	if party then
		return party
	end
	local fresh: Party = { leader = userId, members = { userId }, ready = {} }
	parties[userId] = fresh
	return fresh
end

function Party.new(leader: number): Party
	return { leader = leader, members = { leader }, ready = {} }
end

-- Takes `userId` out of whatever party they are in. A leaving leader hands the party to the
-- next member; an emptied party is gone. The leaver is in no party afterwards.
function Party.leave(parties: Parties, userId: number)
	local party = Party.of(parties, userId)
	if not party then
		return
	end
	local index = table.find(party.members, userId)
	if index then
		table.remove(party.members, index)
	end
	party.ready[userId] = nil
	parties[party.leader] = nil
	if #party.members == 0 then
		return
	end
	if party.leader == userId then
		-- A new leader starts the launch over: no countdown, nobody ready.
		party.leader = party.members[1]
		party.deployAt = nil
		table.clear(party.ready)
	end
	parties[party.leader] = party
end

-- `from` invites `to`. Refused: yourself, a member who is not the leader, a full party,
-- someone already in a squad of two or more.
function Party.invite(
	parties: Parties,
	invites: Invites,
	from: number,
	to: number,
	now: number,
	capacity: number
): (boolean, string?)
	if from == to then
		return false, "You can't invite yourself."
	end
	local party = Party.ensure(parties, from)
	if party.leader ~= from then
		return false, "Only the squad leader can invite."
	end
	if #party.members >= capacity then
		return false, "Your squad is full."
	end
	local theirs = Party.of(parties, to)
	if theirs and #theirs.members > 1 then
		return false, "They're already in a squad."
	end
	invites[to] = { from = from, at = now }
	return true, nil
end

-- `to` accepts their pending invite: they leave their own (solo) party and join the
-- inviter's. Refused when there is none, it expired, or that party is full or gone.
function Party.accept(
	parties: Parties,
	invites: Invites,
	to: number,
	now: number,
	ttl: number,
	capacity: number
): (boolean, string?)
	local invite = invites[to]
	invites[to] = nil
	if not invite then
		return false, "No invite to accept."
	end
	if now - invite.at > ttl then
		return false, "That invite ran out."
	end
	local party = Party.of(parties, invite.from)
	if not party or party.leader ~= invite.from then
		return false, "That squad is gone."
	end
	if #party.members >= capacity then
		return false, "That squad is full."
	end
	local mine = Party.of(parties, to)
	if mine and #mine.members > 1 then
		return false, "Leave your squad first."
	end
	Party.leave(parties, to)
	table.insert(party.members, to)
	return true, nil
end

-- The leader picks the mission: everyone's ready and any countdown start over.
function Party.pick(party: Party, by: number, missionId: string): boolean
	if by ~= party.leader then
		return false
	end
	party.mission = missionId
	table.clear(party.ready)
	party.deployAt = nil
	return true
end

function Party.setReady(party: Party, by: number, on: boolean)
	if table.find(party.members, by) then
		if on then
			party.ready[by] = true
		else
			party.ready[by] = nil
		end
	end
end

-- The leader deploys: the countdown starts and the leader counts as ready.
function Party.deploy(party: Party, by: number, now: number, wait: number): boolean
	if by ~= party.leader or party.mission == nil then
		return false
	end
	if party.deployAt then
		return true -- already counting down: pressing again changes nothing
	end
	party.ready[by] = true
	party.deployAt = now + wait
	return true
end

-- Whether the party flies now: deploying, and everyone ready or the countdown over.
function Party.due(party: Party, now: number): boolean
	local at = party.deployAt
	if at == nil then
		return false
	end
	if now >= at then
		return true
	end
	for _, member in party.members do
		if not party.ready[member] then
			return false
		end
	end
	return true
end

-- Who flies: the members still in the server (`present`), leader first.
function Party.launchList(party: Party, present: { [number]: boolean }): { number }
	local list: { number } = {}
	for _, member in party.members do
		if present[member] then
			table.insert(list, member)
		end
	end
	return list
end

-- A friend invite's LaunchData: who leads, and their server.
function Party.launchText(leader: number, jobId: string): string
	return `{LAUNCH_PREFIX}:{leader}:{jobId}`
end

function Party.parseLaunch(text: unknown): (number?, string?)
	if typeof(text) ~= "string" then
		return nil, nil
	end
	local leader, job = string.match(text, `^{LAUNCH_PREFIX}:(%d+):(.+)$`)
	if not leader or not job then
		return nil, nil
	end
	return tonumber(leader), job
end

return Party
