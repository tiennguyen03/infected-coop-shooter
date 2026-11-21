--!strict
-- Squads on the Carrier (src/shared/Rules/Party.luau): who can invite whom, joining, leaving,
-- who picks and deploys, when the party flies, and who goes.

local Party = require("../src/shared/Rules/Party")

local CAP = 4
local TTL = 60

local function eq(actual: unknown, expected: unknown, what: string)
	if actual ~= expected then
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function world(): (any, any)
	return {}, {}
end

local function join(parties, invites, from: number, to: number, now: number?)
	assert(Party.invite(parties, invites, from, to, now or 0, CAP))
	assert(Party.accept(parties, invites, to, now or 0, TTL, CAP))
end

return {
	["a soldier with no party leads a party of one"] = function()
		local parties = world()
		local party = Party.ensure(parties, 1)
		eq(party.leader, 1, "leader")
		eq(#party.members, 1, "members")
		eq(Party.of(parties, 1), party, "of")
	end,

	["invite then accept joins the inviter's party"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 2)
		eq(party and party.leader, 1, "leader")
		eq(party and #party.members, 2, "members")
		eq(parties[2], nil, "the invitee's own party is gone")
		eq(invites[2], nil, "the invite is used")
	end,

	["you cannot invite yourself"] = function()
		local parties, invites = world()
		local ok, why = Party.invite(parties, invites, 1, 1, 0, CAP)
		eq(ok, false, "ok")
		eq(why ~= nil, true, "a reason")
	end,

	["you cannot invite someone already in a squad"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local ok = Party.invite(parties, invites, 3, 2, 0, CAP)
		eq(ok, false, "invite a member of another squad")
	end,

	["a full party cannot invite"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		join(parties, invites, 1, 3)
		join(parties, invites, 1, 4)
		eq((Party.invite(parties, invites, 1, 5, 0, CAP)), false, "fifth")
	end,

	["only the leader invites"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		eq((Party.invite(parties, invites, 2, 3, 0, CAP)), false, "a member invites")
	end,

	["an expired invite cannot be accepted"] = function()
		local parties, invites = world()
		assert(Party.invite(parties, invites, 1, 2, 0, CAP))
		eq((Party.accept(parties, invites, 2, TTL + 1, TTL, CAP)), false, "late")
		eq(invites[2], nil, "the expired invite is dropped")
	end,

	["accepting with no invite fails"] = function()
		local parties, invites = world()
		eq((Party.accept(parties, invites, 2, 0, TTL, CAP)), false, "no invite")
	end,

	["a party that filled while the invite waited refuses it"] = function()
		local parties, invites = world()
		assert(Party.invite(parties, invites, 1, 5, 0, CAP))
		join(parties, invites, 1, 2)
		join(parties, invites, 1, 3)
		join(parties, invites, 1, 4)
		eq((Party.accept(parties, invites, 5, 1, TTL, CAP)), false, "full by now")
	end,

	["the leader leaving hands over to the next member"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		join(parties, invites, 1, 3)
		Party.leave(parties, 1)
		local party = Party.of(parties, 2)
		eq(party and party.leader, 2, "new leader")
		eq(party and #party.members, 2, "two left")
		eq(parties[1], nil, "no party for the leaver")
		eq(Party.of(parties, 1), nil, "the leaver is in none")
	end,

	["the last member leaving deletes the party"] = function()
		local parties = world()
		Party.ensure(parties, 1)
		Party.leave(parties, 1)
		eq(parties[1], nil, "gone")
	end,

	["a member leaving loses their ready mark"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 1) :: any
		Party.setReady(party, 2, true)
		Party.leave(parties, 2)
		eq(party.ready[2], nil, "ready cleared")
	end,

	["only the leader picks and deploys"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 1) :: any
		eq(Party.pick(party, 2, "mile14"), false, "member picks")
		eq(Party.pick(party, 1, "mile14"), true, "leader picks")
		eq(party.mission, "mile14", "mission")
		eq(Party.deploy(party, 2, 0, 15), false, "member deploys")
		eq(Party.deploy(party, 1, 0, 15), true, "leader deploys")
	end,

	["deploy needs a pick"] = function()
		local parties = world()
		local party = Party.ensure(parties, 1)
		eq(Party.deploy(party, 1, 0, 15), false, "no mission")
	end,

	["a new pick clears everyone's ready and the countdown"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 1) :: any
		Party.pick(party, 1, "delta")
		Party.setReady(party, 2, true)
		Party.deploy(party, 1, 0, 15)
		Party.pick(party, 1, "mile14")
		eq(party.ready[2], nil, "ready cleared")
		eq(party.deployAt, nil, "countdown cleared")
	end,

	["due when everyone is ready"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 1) :: any
		Party.pick(party, 1, "delta")
		Party.deploy(party, 1, 0, 15)
		eq(Party.due(party, 1), false, "member not ready")
		Party.setReady(party, 2, true)
		eq(Party.due(party, 1), true, "all ready")
	end,

	["due when the countdown runs out"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		local party = Party.of(parties, 1) :: any
		Party.pick(party, 1, "delta")
		Party.deploy(party, 1, 0, 15)
		eq(Party.due(party, 14), false, "before")
		eq(Party.due(party, 15), true, "at the end")
	end,

	["never due without a deploy"] = function()
		local parties = world()
		local party = Party.ensure(parties, 1)
		Party.pick(party, 1, "delta")
		Party.setReady(party, 1, true)
		eq(Party.due(party, 100), false, "no deploy")
	end,

	["a solo leader is due as soon as they deploy"] = function()
		local parties = world()
		local party = Party.ensure(parties, 1)
		Party.pick(party, 1, "delta")
		Party.deploy(party, 1, 0, 15)
		eq(Party.due(party, 0), true, "solo")
	end,

	["launchList keeps those still here, leader first"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		join(parties, invites, 1, 3)
		local party = Party.of(parties, 1) :: any
		local list = Party.launchList(party, { [1] = true, [3] = true })
		eq(#list, 2, "two")
		eq(list[1], 1, "leader first")
		eq(list[2], 3, "then 3")
	end,

	["parseLaunch reads a friend's invite"] = function()
		local leader, job = Party.parseLaunch("party:123:abc-def")
		eq(leader, 123, "leader")
		eq(job, "abc-def", "job")
	end,

	["parseLaunch ignores anything else"] = function()
		for _, text in { "", "party:", "party:x:y", "other:1:2", "party:12" } do
			local leader = Party.parseLaunch(text)
			eq(leader, nil, `"{text}"`)
		end
		eq((Party.parseLaunch(nil)), nil, "nil")
		eq((Party.parseLaunch(42)), nil, "a number")
	end,

	["launchText round-trips through parseLaunch"] = function()
		local leader, job = Party.parseLaunch(Party.launchText(77, "job-1"))
		eq(leader, 77, "leader")
		eq(job, "job-1", "job")
	end,

	-- Review fixes (sprint 2).
	["accepting is refused while you lead a squad of two or more"] = function()
		local parties, invites = world()
		join(parties, invites, 2, 3)
		assert(Party.invite(parties, invites, 1, 9, 0, CAP))
		invites[2] = { from = 1, at = 0 } -- an invite that reached 2 before they built a squad
		eq((Party.accept(parties, invites, 2, 0, TTL, CAP)), false, "leader of two accepts")
		eq(
			Party.of(parties, 3) and (Party.of(parties, 3) :: any).leader,
			2,
			"their squad is intact"
		)
	end,

	["accepting after the inviter stopped leading fails"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		assert(Party.invite(parties, invites, 1, 5, 0, CAP))
		Party.leave(parties, 1)
		eq((Party.accept(parties, invites, 5, 0, TTL, CAP)), false, "inviter gone")
	end,

	["a handover clears everyone's ready"] = function()
		local parties, invites = world()
		join(parties, invites, 1, 2)
		join(parties, invites, 1, 3)
		local party = Party.of(parties, 1) :: any
		Party.pick(party, 1, "delta")
		Party.setReady(party, 3, true)
		Party.leave(parties, 1)
		eq(party.ready[3], nil, "ready cleared on handover")
	end,

	["deploying again with the same mission keeps the countdown"] = function()
		local parties = world()
		local party = Party.ensure(parties, 1) :: any
		join(parties, {}, 1, 2)
		Party.pick(party, 1, "delta")
		Party.deploy(party, 1, 0, 15)
		Party.deploy(party, 1, 10, 15)
		eq(party.deployAt, 15, "not restarted")
	end,
}
