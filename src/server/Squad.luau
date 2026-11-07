--!strict
-- Squad: the one roster every system asks "who is on our side" (Co-op Sprint A step 3,
-- docs/sprints/SPRINT_17_COOP_A.md section 1). A member is a player or a server-side bot
-- (BotService); targeting, splash damage and anything else that keys on "a squad body"
-- reads members from here so a bot is seen the same way as a player. Per-owner state
-- (items, XP, stat mults) stays on the Player; bots have none (`ownerAttribute` default).
-- This first cut tracks Alive/Dead from the humanoid; Downed/revive, pads and the ready
-- vote land in later Sprint A steps. Requires nothing but Players, so any service can
-- require it without a cycle.

local Players = game:GetService("Players")

export type MemberKind = "player" | "bot"
export type Member = {
	id: string, -- "p:<UserId>" | "b:<slot>", stable across respawns
	kind: MemberKind,
	owner: Player?, -- nil for bots
	name: string,
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
}

local Squad = {}

local members: { Member } = {}
local byPlayer: { [Player]: Member } = {}
local byHumanoid: { [Humanoid]: Member } = {}

-- Points `member` at a (new) body; nil clears it.
function Squad.bindCharacter(member: Member, character: Model?)
	if member.humanoid then
		byHumanoid[member.humanoid] = nil
	end
	member.character = character
	member.humanoid = character and character:FindFirstChildOfClass("Humanoid")
	member.root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if member.humanoid then
		byHumanoid[member.humanoid] = member
	end
end

local function add(member: Member)
	table.insert(members, member)
end

local function remove(member: Member)
	local index = table.find(members, member)
	if index then
		table.remove(members, index)
	end
	if member.humanoid then
		byHumanoid[member.humanoid] = nil
	end
	if member.owner then
		byPlayer[member.owner] = nil
	end
end

function Squad.addBot(slot: number, name: string): Member
	local member: Member = {
		id = "b:" .. slot,
		kind = "bot",
		owner = nil,
		name = name,
		character = nil,
		humanoid = nil,
		root = nil,
	}
	add(member)
	return member
end

function Squad.removeBot(member: Member)
	remove(member)
end

local function isAlive(member: Member): boolean
	local humanoid = member.humanoid
	local root = member.root
	return humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
		and member.character ~= nil
		and member.character.Parent ~= nil
end

function Squad.members(): { Member }
	return table.clone(members)
end

function Squad.living(): { Member }
	local result = {}
	for _, member in members do
		if isAlive(member) then
			table.insert(result, member)
		end
	end
	return result
end

function Squad.isAlive(member: Member): boolean
	return isAlive(member)
end

-- Living players (owners), for things only a player can do (collect, vote, extract).
function Squad.livingOwners(): { Player }
	local result = {}
	for _, member in members do
		if member.owner and isAlive(member) then
			table.insert(result, member.owner)
		end
	end
	return result
end

function Squad.fromPlayer(player: Player): Member?
	return byPlayer[player]
end

function Squad.fromHumanoid(humanoid: Humanoid): Member?
	return byHumanoid[humanoid]
end

-- The nearest living member to `position` and its distance (math.huge when nobody lives).
function Squad.nearestLiving(position: Vector3): (Member?, number)
	local nearest: Member? = nil
	local nearestDistance = math.huge
	for _, member in members do
		local root = member.root
		if root and isAlive(member) then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearest = member
				nearestDistance = distance
			end
		end
	end
	return nearest, nearestDistance
end

-- A per-owner attribute (IncomingDamageMult, ...), or `default` for a bot.
function Squad.ownerAttribute(member: Member, name: string, default: any): any
	local owner = member.owner
	if not owner then
		return default
	end
	local value = owner:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function onPlayerAdded(player: Player)
	local member: Member = {
		id = "p:" .. player.UserId,
		kind = "player",
		owner = player,
		name = player.DisplayName,
		character = nil,
		humanoid = nil,
		root = nil,
	}
	byPlayer[player] = member
	add(member)
	player.CharacterAdded:Connect(function(character)
		-- The humanoid and root exist by the time CharacterAdded fires for a loaded rig.
		character:WaitForChild("HumanoidRootPart", 10)
		Squad.bindCharacter(member, character)
	end)
	if player.Character then
		Squad.bindCharacter(member, player.Character)
	end
end

function Squad.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local member = byPlayer[player]
		if member then
			remove(member)
		end
	end)
end

return Squad
