--!strict
-- Squad: the one roster every system asks "who is on our side" (Co-op Sprint A,
-- docs/sprints/SPRINT_17_COOP_A.md section 1). A member is a player or a server-side bot
-- (BotService); targeting, splash damage, zones and the wipe check read members from
-- here, so a bot is seen the same way as a player. Per-owner state (loadout, stat mults)
-- stays on the Player; bots have none (`ownerAttribute` default).
--
-- State per member: Alive -> Downed (a lethal hit, decision #3) -> Alive (revived) or
-- Dead (bled out, killed while out of revives). Downed bodies are not targets and take no
-- damage; a squadmate holds F (ProximityPrompt) for Config.Downed.ReviveHold to stand them
-- up; bots revive with Squad.revive. Replicated as character attributes SquadState,
-- BleedOutAt (server time) and Reviver, mirrored on the Player for client UI. Spare
-- Tourniquet (the UpgradeKit attribute, loadout rework): a downed player stands up on their
-- own Config.Upgrades.Tourniquet.Seconds after going down, once per run (SelfReviveAt).
-- Also hands out landing pads (step 4). Requires only Players, Config and ArenaService, so
-- any service can require it without a cycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArenaService = require(script.Parent.ArenaService)
-- LoadoutService requires Squad, so Squad reaches it lazily (knock only).
local function loadoutService(): any
	return require(script.Parent.LoadoutService) :: any
end

export type MemberKind = "player" | "bot"
export type MemberState = "Alive" | "Downed" | "Dead"
export type Member = {
	id: string, -- "p:<UserId>" | "b:<slot>", stable across respawns
	kind: MemberKind,
	owner: Player?, -- nil for bots
	name: string,
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	padIndex: number?, -- landing pad slot, claimed on first spawn
	state: MemberState,
	bleedOutAt: number?, -- os.clock, Downed only
	revivesUsed: number, -- this run; at Config.Downed.MaxRevives a lethal hit kills
	prompt: ProximityPrompt?,
	tourniquetUsed: boolean, -- the Spare Tourniquet self-revive, once per run
	selfReviveAt: number?, -- os.clock, Downed with the tourniquet only
}

local Squad = {}

local members: { Member } = {}
local byPlayer: { [Player]: Member } = {}
local byHumanoid: { [Humanoid]: Member } = {}
local stateListeners: { (member: Member, old: MemberState, new: MemberState) -> () } = {}

local function newMember(id: string, kind: MemberKind, owner: Player?, name: string): Member
	return {
		id = id,
		kind = kind,
		owner = owner,
		name = name,
		character = nil,
		humanoid = nil,
		root = nil,
		padIndex = nil,
		state = "Dead",
		bleedOutAt = nil,
		revivesUsed = 0,
		prompt = nil,
		tourniquetUsed = false,
		selfReviveAt = nil,
	}
end

local function publish(member: Member)
	local bleedOutServer = 0
	local selfReviveServer = 0
	if member.state == "Downed" and member.bleedOutAt then
		bleedOutServer = workspace:GetServerTimeNow() + (member.bleedOutAt - os.clock())
	end
	if member.state == "Downed" and member.selfReviveAt then
		selfReviveServer = workspace:GetServerTimeNow() + (member.selfReviveAt - os.clock())
	end
	for _, target in { member.character :: Instance?, member.owner :: Instance? } do
		if target then
			target:SetAttribute("SquadState", member.state)
			target:SetAttribute("BleedOutAt", bleedOutServer)
			target:SetAttribute("SelfReviveAt", selfReviveServer)
		end
	end
end

local function setReviver(member: Member, name: string)
	for _, target in { member.character :: Instance?, member.owner :: Instance? } do
		if target then
			target:SetAttribute("Reviver", name)
		end
	end
end

local function clearPrompt(member: Member)
	if member.prompt then
		member.prompt:Destroy()
		member.prompt = nil
	end
	setReviver(member, "")
end

local function setState(member: Member, state: MemberState)
	local old: MemberState = member.state
	if old == state then
		return
	end
	member.state = state
	if state ~= "Downed" then
		member.bleedOutAt = nil
		member.selfReviveAt = nil
		clearPrompt(member)
	end
	publish(member)
	for _, listener in stateListeners do
		task.spawn(function()
			listener(member, old, state)
		end)
	end
end

-- Listeners run on every state change (RunManager's wipe check, BotService).
function Squad.onStateChanged(listener: (member: Member, old: MemberState, new: MemberState) -> ())
	table.insert(stateListeners, listener)
end

-- Points `member` at a (new) body; nil clears it. A new living body is Alive.
function Squad.bindCharacter(member: Member, character: Model?)
	if member.humanoid then
		byHumanoid[member.humanoid] = nil
	end
	clearPrompt(member)
	member.character = character
	member.humanoid = character and character:FindFirstChildOfClass("Humanoid")
	member.root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = member.humanoid
	if humanoid then
		byHumanoid[humanoid] = member
		humanoid.Died:Connect(function()
			if member.humanoid == humanoid then
				setState(member, "Dead")
			end
		end)
		member.state = "Dead" -- force the publish below
		setState(member, if humanoid.Health > 0 then "Alive" else "Dead")
	else
		setState(member, "Dead")
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
	clearPrompt(member)
	if member.humanoid then
		byHumanoid[member.humanoid] = nil
	end
	if member.owner then
		byPlayer[member.owner] = nil
	end
end

function Squad.addBot(slot: number, name: string): Member
	local member = newMember("b:" .. slot, "bot", nil, name)
	add(member)
	return member
end

function Squad.removeBot(member: Member)
	remove(member)
end

local function hasBody(member: Member): boolean
	local humanoid = member.humanoid
	return humanoid ~= nil
		and member.root ~= nil
		and humanoid.Health > 0
		and member.character ~= nil
		and member.character.Parent ~= nil
end

-- Alive and standing: a target, a shooter, a zone holder, a reviver.
local function isAlive(member: Member): boolean
	return member.state == "Alive" and hasBody(member)
end

function Squad.isAlive(member: Member): boolean
	return isAlive(member)
end

-- Still in the fight: Alive or Downed (a downed member can still be revived).
function Squad.isActive(member: Member): boolean
	return (member.state == "Alive" or member.state == "Downed") and hasBody(member)
end

-- Knocked down (Squad.knock): the KnockedUntil attribute is on the character while it lasts.
function Squad.isKnocked(member: Member): boolean
	local character = member.character
	return character ~= nil and character:GetAttribute("KnockedUntil") ~= nil
end

-- May act (fire, use abilities, throw the flare): Alive and on their feet.
function Squad.canAct(member: Member): boolean
	return isAlive(member) and not Squad.isKnocked(member)
end

-- Knocks a living member down for `seconds` (the Warden's Pound and Stomp): no moving,
-- firing or abilities (canAct), the reload dropped, the fall and get-up clips on the client
-- (Impact "knockdown"); bots read the attribute. Config.Knockdown.Grace after standing
-- refuses the next knockdown so two of them cannot chain. Returns true when it took.
function Squad.knock(member: Member, seconds: number): boolean
	local character = member.character
	if not isAlive(member) or not character then
		return false
	end
	local now = os.clock()
	local grace = character:GetAttribute("KnockGraceUntil") :: number?
	if (grace and now < grace) or character:GetAttribute("KnockedUntil") ~= nil then
		return false
	end
	local until_ = now + seconds
	character:SetAttribute("KnockedUntil", until_)
	if member.owner then
		loadoutService().cancelReload(member.owner)
		Remotes.get("Impact"):FireClient(member.owner, "knockdown", seconds)
	end
	task.delay(seconds, function()
		if character.Parent and character:GetAttribute("KnockedUntil") == until_ then
			character:SetAttribute("KnockedUntil", nil)
			character:SetAttribute("KnockGraceUntil", os.clock() + Config.Knockdown.Grace)
		end
	end)
	return true
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

-- Members waiting for a revive.
function Squad.downed(): { Member }
	local result = {}
	for _, member in members do
		if member.state == "Downed" and hasBody(member) then
			table.insert(result, member)
		end
	end
	return result
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

-- Players still in the fight (Alive or Downed): the run is wiped when this is empty.
function Squad.activeOwners(): { Player }
	local result = {}
	for _, member in members do
		if member.owner and Squad.isActive(member) then
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

-- Stands a downed member up at Config.Downed.ReviveHealthFraction health. `free` (the
-- Spare Tourniquet) does not count against Config.Downed.MaxRevives.
function Squad.revive(member: Member, by: Member?, free: boolean?)
	if member.state ~= "Downed" or not hasBody(member) then
		return
	end
	local humanoid = member.humanoid :: Humanoid
	if not free then
		member.revivesUsed += 1
	end
	humanoid.Health = humanoid.MaxHealth * Config.Downed.ReviveHealthFraction
	local regen = member.character and member.character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen.Enabled = true
	end
	setState(member, "Alive")
	print(`[Squad] {member.name} revived by {by and by.name or "?"} ({member.revivesUsed} used)`)
end

-- Kills a member outright (bleed-out, out of revives, dev tools).
function Squad.kill(member: Member)
	local humanoid = member.humanoid
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function addPrompt(member: Member)
	local root = member.root
	if not root then
		return
	end
	local settings = Config.Downed
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = member.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = settings.ReviveHold
	prompt.MaxActivationDistance = settings.ReviveRadius
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.PromptButtonHoldBegan:Connect(function(player)
		setReviver(member, player.DisplayName)
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		setReviver(member, "")
	end)
	prompt.Triggered:Connect(function(player)
		local reviver = byPlayer[player]
		if not reviver or reviver == member or not isAlive(reviver) then
			return
		end
		local reviverRoot = reviver.root :: BasePart
		local downedRoot = member.root
		if
			downedRoot
			and (reviverRoot.Position - downedRoot.Position).Magnitude
				<= settings.ReviveRadius + 2
		then
			Squad.revive(member, reviver)
		end
	end)
	prompt.Parent = root
	member.prompt = prompt
end

-- A lethal hit: down the member (decision #3) unless they are out of revives.
function Squad.down(member: Member)
	if member.state ~= "Alive" or not hasBody(member) then
		return
	end
	if member.revivesUsed >= Config.Downed.MaxRevives then
		Squad.kill(member)
		return
	end
	local humanoid = member.humanoid :: Humanoid
	humanoid.Health = Config.Downed.DownedHealth
	-- The stock regen script would refill a downed bar; it resumes on revive.
	local regen = member.character and member.character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen.Enabled = false
	end
	member.bleedOutAt = os.clock() + Config.Downed.BleedOutSeconds
	-- Spare Tourniquet: the body gets itself up, once per run.
	if
		not member.tourniquetUsed
		and Squad.ownerAttribute(member, "UpgradeKit", "") == "tourniquet"
	then
		member.tourniquetUsed = true
		member.selfReviveAt = os.clock() + Config.Upgrades.Tourniquet.Seconds
	end
	setState(member, "Downed")
	addPrompt(member)
	print(`[Squad] {member.name} is down`)
end

-- RunManager, on every run start: revives are counted per run.
function Squad.resetRun()
	for _, member in members do
		member.revivesUsed = 0
		member.tourniquetUsed = false
	end
end

-- The member's landing pad slot: the lowest one no other member holds (players claim
-- theirs before the bots are rebuilt on a run start).
function Squad.padFor(member: Member): number
	if member.padIndex then
		return member.padIndex
	end
	local taken: { [number]: boolean } = {}
	for _, other in members do
		if other.padIndex then
			taken[other.padIndex] = true
		end
	end
	local index = 1
	while taken[index] do
		index += 1
	end
	member.padIndex = index
	return index
end

-- Where `member` lands at the start of a run.
function Squad.spawnCFrame(member: Member): CFrame
	return ArenaService.getSpawnPad(Squad.padFor(member))
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
	local member = newMember("p:" .. player.UserId, "player", player, player.DisplayName)
	byPlayer[player] = member
	add(member)
	-- Every (re)spawn lands on the member's own pad around the LZ helipad.
	local pad = ArenaService.getSpawnLocation(Squad.padFor(member))
	if pad then
		player.RespawnLocation = pad
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Humanoid", 10)
		Squad.bindCharacter(member, character)
	end)
	if player.Character then
		Squad.bindCharacter(member, player.Character)
	end
end

-- Bleed-out: a downed member whose timer runs out dies. A tourniquet stands them up first.
local function step()
	local now = os.clock()
	for _, member in members do
		local selfReviveAt = member.selfReviveAt
		if member.state == "Downed" and selfReviveAt and now >= selfReviveAt then
			member.selfReviveAt = nil
			print(`[Squad] {member.name} used the tourniquet`)
			Squad.revive(member, member, true)
			continue
		end
		local bleedOutAt = member.bleedOutAt
		if member.state == "Downed" and bleedOutAt and now >= bleedOutAt then
			member.bleedOutAt = nil
			print(`[Squad] {member.name} bled out`)
			Squad.kill(member)
		end
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
	RunService.Heartbeat:Connect(step)
end

return Squad
