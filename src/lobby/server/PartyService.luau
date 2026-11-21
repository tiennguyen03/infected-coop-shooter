--!strict
-- Squads on the Carrier (loop sprint 2; rules: Rules/Party). Every soldier on this server is
-- in one party (alone = a party of one). The leader invites from the party panel (PartyUI)
-- anyone on the Carrier, or a friend anywhere through Roblox's invite (PartyUI sends it with
-- LaunchData `party:<leader>:<job>`; arriving here they join, arriving on another Carrier
-- they are offered a flight to this one). The leader picks a mission on the Mission Board and
-- presses DEPLOY (MissionBoardService -> PartyService.deploy); the members' DEPLOY is READY.
-- The squad flies, together, when all are ready or Config.Lobby.Party.DeployWait runs out,
-- through LaunchService.send. Each member is told their party's state over the Party remote
-- after every change (`view`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Party = require(ReplicatedStorage.Shared.Rules.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LaunchService = require(script.Parent.LaunchService)

local PartyService = {}

local CFG = Config.Lobby.Party
local CAPACITY = Config.Lobby.Launch.Capacity

local parties: Party.Parties = {}
local invites: Party.Invites = {}
local flying: { [Party.Party]: boolean } = {} -- a launch under way: never sent twice
local followTo: { [Player]: string } = {} -- a friend invite to another Carrier: its JobId

local partyRemote: RemoteEvent
local boardRemote: RemoteEvent

export type MemberView = { id: number, name: string, ready: boolean, leader: boolean }
export type View = {
	leader: number,
	members: { MemberView },
	mission: string?,
	deployIn: number?, -- seconds left on the countdown
	isLeader: boolean,
	flying: boolean,
}

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- What `player` sees of their party.
function PartyService.view(player: Player): View
	local party = Party.ensure(parties, player.UserId)
	local members: { MemberView } = {}
	for _, id in party.members do
		local member = playerOf(id)
		table.insert(members, {
			id = id,
			name = if member then member.DisplayName else "?",
			ready = party.ready[id] == true,
			leader = id == party.leader,
		})
	end
	return {
		leader = party.leader,
		members = members,
		mission = party.mission,
		deployIn = if party.deployAt then math.max(0, party.deployAt - os.clock()) else nil,
		isLeader = party.leader == player.UserId,
		flying = flying[party] == true,
	}
end

local function push(party: Party.Party?)
	if not party then
		return
	end
	for _, id in party.members do
		local member = playerOf(id)
		if member then
			partyRemote:FireClient(member, Messages.Party.State, PartyService.view(member))
		end
	end
end

local function notice(player: Player, text: string)
	partyRemote:FireClient(player, Messages.Party.Notice, text)
end

-- The party `player` is in (a party of one when alone).
function PartyService.partyOf(player: Player): Party.Party
	return Party.ensure(parties, player.UserId)
end

-- The Mission Board's DEPLOY: the leader picks `missionId` and starts the countdown; a
-- member's DEPLOY is READY. Returns false and why when refused.
function PartyService.deploy(player: Player, missionId: string): (boolean, string?)
	local party = Party.ensure(parties, player.UserId)
	if flying[party] then
		return false, "Your squad is already lifting."
	end
	if party.leader ~= player.UserId then
		Party.setReady(party, player.UserId, true)
		push(party)
		return true, nil
	end
	if party.mission ~= missionId then
		Party.pick(party, player.UserId, missionId)
	end
	Party.deploy(party, player.UserId, os.clock(), CFG.DeployWait)
	push(party)
	return true, nil
end

local function launch(party: Party.Party)
	flying[party] = true
	local present: { [number]: boolean } = {}
	for _, id in party.members do
		present[id] = playerOf(id) ~= nil
	end
	local going: { Player } = {}
	for _, id in Party.launchList(party, present) do
		local member = playerOf(id)
		if member then
			table.insert(going, member)
		end
	end
	for _, member in going do
		boardRemote:FireClient(member, Messages.MissionBoard.Lifting)
	end
	push(party)
	local mission = party.mission :: string
	task.spawn(function()
		local ok, reason = LaunchService.send(going, mission, nil)
		-- Gone: the squad stays "lifting" until its soldiers leave the server, so nobody can
		-- deploy it twice or join it on the way out. Failed: it is idle again.
		if ok then
			-- A teleport can still fail after it started (TeleportInitFailed): whoever is still
			-- here after LiftTimeout gets their squad back.
			task.delay(CFG.LiftTimeout, function()
				if flying[party] then
					flying[party] = nil
					party.deployAt = nil
					table.clear(party.ready)
					push(party)
				end
			end)
		else
			flying[party] = nil
			party.deployAt = nil
			table.clear(party.ready)
			for _, member in going do
				if member.Parent then
					boardRemote:FireClient(
						member,
						Messages.MissionBoard.Refused,
						reason or "The helicopter couldn't lift."
					)
				end
			end
		end
		push(party)
	end)
end

-- Whether `userId`'s squad is lifting: it cannot change until the teleport is over.
local function busy(userId: number): boolean
	local party = Party.of(parties, userId)
	return party ~= nil and flying[party] == true
end

local SQUAD_CHANGES = {
	[Messages.Party.Invite] = true,
	[Messages.Party.Accept] = true,
	[Messages.Party.Leave] = true,
	[Messages.Party.Kick] = true,
}

local function onIntent(player: Player, kind: unknown, arg: unknown)
	local me = player.UserId
	if SQUAD_CHANGES[kind :: any] then
		local invite = invites[me]
		local target = if typeof(arg) == "number" then arg else nil
		if
			busy(me)
			or (target ~= nil and busy(target))
			or (kind == Messages.Party.Accept and invite ~= nil and busy(invite.from))
		then
			notice(player, "Not while the squad is lifting.")
			return
		end
	end
	if kind == Messages.Party.Invite then
		local target = if typeof(arg) == "number" then playerOf(arg) else nil
		if not target then
			notice(player, "They're not on the Carrier.")
			return
		end
		local ok, why = Party.invite(parties, invites, me, target.UserId, os.clock(), CAPACITY)
		if not ok then
			notice(player, why or "Can't invite them.")
			return
		end
		partyRemote:FireClient(
			target,
			Messages.Party.Invited,
			me,
			player.DisplayName,
			CFG.InviteSeconds
		)
		notice(player, `Invite sent to {target.DisplayName}.`)
	elseif kind == Messages.Party.Accept then
		local before = Party.of(parties, me)
		local ok, why = Party.accept(parties, invites, me, os.clock(), CFG.InviteSeconds, CAPACITY)
		if not ok then
			notice(player, why or "Couldn't join.")
		end
		push(before)
		push(Party.of(parties, me))
	elseif kind == Messages.Party.Decline then
		invites[me] = nil
	elseif kind == Messages.Party.Leave then
		local party = Party.of(parties, me)
		if party and #party.members > 1 then
			Party.leave(parties, me)
			push(party)
			push(Party.ensure(parties, me))
		end
	elseif kind == Messages.Party.Kick then
		local party = Party.of(parties, me)
		if party and party.leader == me and typeof(arg) == "number" and arg ~= me then
			if table.find(party.members, arg) then
				Party.leave(parties, arg)
				push(party)
				local kicked = playerOf(arg)
				if kicked then
					Party.ensure(parties, arg)
					push(Party.of(parties, arg))
					notice(kicked, "You left the squad.")
				end
			end
		end
	elseif kind == Messages.Party.Ready then
		local party = Party.ensure(parties, me)
		Party.setReady(party, me, arg == true)
		push(party)
	elseif kind == Messages.Party.Follow then
		local job = followTo[player]
		followTo[player] = nil
		if job and not RunService:IsStudio() then
			local ok, err = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, job, player)
			end)
			if not ok then
				warn(`[PartyService] follow failed: {err}`)
				notice(player, "Couldn't reach their Carrier. Invite them again.")
			end
		end
	end
end

-- A soldier arriving from a friend's invite: join the leader here, or offer the flight to
-- the leader's Carrier.
local function arrived(player: Player)
	Party.ensure(parties, player.UserId)
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	local leaderId, job = Party.parseLaunch(if ok and data then data.LaunchData else nil)
	if leaderId and job then
		local leader = playerOf(leaderId)
		if job == game.JobId and leader then
			Party.invite(parties, invites, leaderId, player.UserId, os.clock(), CAPACITY)
			local joined = Party.accept(
				parties,
				invites,
				player.UserId,
				os.clock(),
				CFG.InviteSeconds,
				CAPACITY
			)
			if not joined then
				notice(player, `{leader.DisplayName}'s squad is full.`)
			end
		elseif job ~= game.JobId then
			followTo[player] = job
			local named, name = pcall(function()
				return Players:GetNameFromUserIdAsync(leaderId)
			end)
			partyRemote:FireClient(
				player,
				Messages.Party.Follow,
				if named then name else "your friend"
			)
		end
	end
	push(Party.of(parties, player.UserId))
end

function PartyService.init()
	partyRemote = Remotes.get("Party")
	boardRemote = Remotes.get("MissionBoard")
	partyRemote.OnServerEvent:Connect(onIntent)
	Players.PlayerAdded:Connect(arrived)
	for _, player in Players:GetPlayers() do
		task.spawn(arrived, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local party = Party.of(parties, player.UserId)
		Party.leave(parties, player.UserId)
		invites[player.UserId] = nil
		followTo[player] = nil
		push(party)
	end)
	-- Fly every party whose countdown is due; tell the members the countdown each second.
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < Config.Lobby.Launch.ScanInterval then
			return
		end
		local second = math.floor(now) ~= math.floor(last)
		last = now
		for _, party in parties do
			if party.deployAt and not flying[party] then
				if Party.due(party, now) then
					launch(party)
				elseif second then
					push(party)
				end
			end
		end
	end)
end

return PartyService
