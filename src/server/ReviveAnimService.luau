--!strict
-- The revive animation's server half (Config.ReviveAnimation; docs/PROGRESSION.md > Downed
-- and revive). Looks only: Squad and BotService still decide who revives whom, for how long
-- and what stops it. This service follows them and tells every client what to show:
--
--   ReviveRole on the reviver's body ("treat", then "finish" when the revive lands) and on
--   the casualty's ("treated", then "recover"), with the ReviveAnim tag while a role is set;
--   ReviveKneel / ReviveChest on the reviver: the kneel point beside the casualty's chest
--   (Rules/ReviveAnim; the reviver's own position when both sides are blocked or too far).
--
-- Shared.ReviveAnimation plays it: each player's client for its own body, this service for
-- the bots. A player's hold comes through Squad.onRevive; a bot reports its hold every
-- think with `hold`, and a session it stops reporting ends.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local ReviveAnimation = require(ReplicatedStorage.Shared.ReviveAnimation)
local Rules = require(ReplicatedStorage.Shared.Rules.ReviveAnim)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)
local Squad = require(script.Parent.Squad)

local ReviveAnimService = {}

local settings = Config.ReviveAnimation
local BOT_TAG = "SquadBot"
local ENEMY_TAG = "Enemy"
local SOUND_SLOT = "Treat"
local FLOOR_REACH = 8 -- studs below a root that count as its floor
local RANGE_SLACK = 4 -- studs past the revive radius before a session is dropped

type Session = {
	reviver: Squad.Member,
	casualty: Squad.Member,
	side: number?, -- which kneel point (Rules.kneelPoints index); nil = stayed put
	bot: boolean,
	seenAt: number, -- os.clock of a bot's last `hold`
	nextSound: number,
}

local sessions: { [Squad.Member]: Session } = {} -- by reviver
-- Per body: a counter that outdates a timed role's clear, and when the role was set.
local roleTokens: { [Model]: number } = setmetatable({} :: any, { __mode = "k" })
local roleSince: { [Model]: number } = setmetatable({} :: any, { __mode = "k" })

local function setRole(character: Model?, role: string)
	if not character then
		return
	end
	roleTokens[character] = (roleTokens[character] or 0) + 1
	roleSince[character] = os.clock()
	character:SetAttribute(Attributes.ReviveRole, role)
	if role == "" then
		character:SetAttribute(Attributes.ReviveKneel, nil)
		character:SetAttribute(Attributes.ReviveChest, nil)
		CollectionService:RemoveTag(character, ReviveAnimation.TAG)
	else
		CollectionService:AddTag(character, ReviveAnimation.TAG)
	end
end

-- A role that clears itself (the pull-up, the get-up) unless another one replaced it.
local function timedRole(character: Model?, role: string, seconds: number)
	if not character then
		return
	end
	setRole(character, role)
	local token = roleTokens[character]
	task.delay(seconds, function()
		if roleTokens[character] == token and character.Parent then
			setRole(character, "")
		end
	end)
end

local function treatedBy(casualty: Squad.Member): boolean
	for _, session in sessions do
		if session.casualty == casualty then
			return true
		end
	end
	return false
end

local function endSession(session: Session)
	sessions[session.reviver] = nil
	setRole(session.reviver.character, "")
	local body = session.casualty.character
	if
		body
		and not treatedBy(session.casualty)
		and body:GetAttribute(Attributes.ReviveRole) == "treated"
	then
		setRole(body, "") -- nobody is on them any more: back to the downed crawl
	end
end

-- Only the world blocks a kneel point: bodies (the squad, the Infected) move out of it.
local function worldFilter(): { Instance }
	local exclude: { Instance } = CollectionService:GetTagged(ENEMY_TAG)
	for _, member in Squad.members() do
		if member.character then
			table.insert(exclude, member.character)
		end
	end
	return exclude
end

-- Whether a reviver at `from` cannot kneel at `point`: a wall between the chest and the
-- point or between the reviver and the point, no room for a body there, or no floor at the
-- height the reviver stands on. `from`, `chest` and `point` are at root height.
local function isBlocked(
	from: Vector3,
	chest: Vector3,
	point: Vector3,
	exclude: { Instance }
): boolean
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = exclude
	rayParams.RespectCanCollide = true
	-- Low cover is under root height: test at the knee as well.
	for _, drop in { 0, 1.5 } do
		local offset = Vector3.new(0, -drop, 0)
		if
			workspace:Raycast(chest + offset, point - chest, rayParams)
			or workspace:Raycast(from + offset, point - from, rayParams)
		then
			return true
		end
	end
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = exclude
	overlapParams.RespectCanCollide = true
	overlapParams.MaxParts = 1
	if
		#workspace:GetPartBoundsInBox(CFrame.new(point), Vector3.new(1.8, 2.5, 1.8), overlapParams)
		> 0
	then
		return true
	end
	local down = Vector3.new(0, -FLOOR_REACH, 0)
	local floor = workspace:Raycast(point, down, rayParams)
	local ownFloor = workspace:Raycast(from, down, rayParams)
	if not floor then
		return true
	end
	return ownFloor ~= nil
		and math.abs(floor.Position.Y - ownFloor.Position.Y) > settings.GroundTolerance
end

-- Where `reviver` kneels for `casualty`: the nearer free side of the chest, or where they
-- stand (turned to the chest) when neither side will do. Returns the kneel CFrame, the
-- chest and the side taken.
local function kneelFor(
	reviver: Squad.Member,
	reviverRoot: BasePart,
	casualty: Squad.Member,
	casualtyRoot: BasePart
): (CFrame, Vector3, number?)
	local kneel = ReviveAnimation.kneelSettings()
	local from = reviverRoot.Position
	local body = casualtyRoot.Position
	local _, yaw, _ = casualtyRoot.CFrame:ToOrientation()
	local chestX, chestZ = Rules.chest(body.X, body.Z, yaw, kneel)
	local chest = Vector3.new(chestX, body.Y, chestZ)
	local points = Rules.kneelPoints(body.X, body.Z, yaw, kneel)
	local exclude = worldFilter()
	local blocked = {}
	for index, point in points do
		local taken = false
		for other, session in sessions do
			if other ~= reviver and session.casualty == casualty and session.side == index then
				taken = true
			end
		end
		blocked[index] = taken
			or isBlocked(from, chest, Vector3.new(point.x, from.Y, point.z), exclude)
	end
	local side = Rules.pick(points, from.X, from.Z, blocked, kneel)
	if side then
		local point = points[side]
		return CFrame.new(point.x, from.Y, point.z) * CFrame.Angles(0, point.yaw, 0), chest, side
	end
	local facing = Rules.facing(from.X, from.Z, chestX, chestZ) + kneel.turn
	return CFrame.new(from) * CFrame.Angles(0, facing, 0), chest, nil
end

-- `reviver` started working on `casualty` (a player's hold began, a bot's first `hold`).
function ReviveAnimService.begin(reviver: Squad.Member, casualty: Squad.Member)
	if not settings.Enabled then
		return
	end
	local now = os.clock()
	local existing = sessions[reviver]
	if existing then
		if existing.casualty == casualty then
			existing.seenAt = now
			return
		end
		endSession(existing)
	end
	local reviverRoot, casualtyRoot = reviver.root, casualty.root
	if
		reviver == casualty
		or not Squad.isAlive(reviver)
		or casualty.state ~= "Downed"
		or not reviverRoot
		or not casualtyRoot
		or not reviver.character
		or not casualty.character
	then
		return
	end
	local kneelAt, chest, side = kneelFor(reviver, reviverRoot, casualty, casualtyRoot)
	reviver.character:SetAttribute(Attributes.ReviveKneel, kneelAt)
	reviver.character:SetAttribute(Attributes.ReviveChest, chest)
	sessions[reviver] = {
		reviver = reviver,
		casualty = casualty,
		side = side,
		bot = reviver.kind == "bot",
		seenAt = now,
		nextSound = now + settings.KneelSeconds,
	}
	setRole(reviver.character, "treat")
	if casualty.character:GetAttribute(Attributes.ReviveRole) ~= "treated" then
		setRole(casualty.character, "treated")
	end
end

-- A bot is next to `casualty`, holding: call every think while it does (BotService).
function ReviveAnimService.hold(reviver: Squad.Member, casualty: Squad.Member)
	ReviveAnimService.begin(reviver, casualty)
end

-- `reviver` let go before the revive landed: they stand at once, the casualty drops back.
function ReviveAnimService.cancel(reviver: Squad.Member)
	local session = sessions[reviver]
	if session then
		endSession(session)
	end
end

-- `casualty` was revived (by `reviver`, or by nobody: the tourniquet, dev tools): the
-- reviver pulls them up, anyone else on them stands, the casualty gets up.
function ReviveAnimService.complete(casualty: Squad.Member, reviver: Squad.Member?)
	if not settings.Enabled then
		return
	end
	for other, session in sessions do
		if session.casualty == casualty then
			sessions[other] = nil
			if other ~= reviver then
				setRole(other.character, "")
			end
		end
	end
	if reviver and reviver ~= casualty and Squad.isAlive(reviver) then
		timedRole(reviver.character, "finish", settings.FinishSeconds)
	end
	timedRole(casualty.character, "recover", settings.RecoverSeconds)
end

-- A bot's body is in the first part of its pull-up or get-up: it stands still (BotService).
function ReviveAnimService.busy(character: Model): boolean
	local role = character:GetAttribute(Attributes.ReviveRole)
	if role ~= "finish" and role ~= "recover" then
		return false
	end
	return os.clock() - (roleSince[character] or 0) < settings.BotHoldSeconds
end

-- The soft rustle of someone working, from the reviver.
local function playTreatSound(root: BasePart)
	local sound = settings.Sound
	if not SoundBanks.has(sound.Bank) then
		return
	end
	local slot = root:FindFirstChild(SOUND_SLOT)
	if not slot or not slot:IsA("Sound") then
		local rolloff = Config.Audio.Voice
		local created = SoundBanks.create(SOUND_SLOT, rolloff.RollOffMin, rolloff.RollOffMax)
		created.Parent = root
		slot = created
	end
	SoundBanks.play(slot :: Sound, sound.Bank, sound.Group, sound.Volume)
end

-- Ends the sessions the rules have ended: a reviver who went down or walked off, a casualty
-- who bled out, a bot that stopped holding.
local function step()
	local now = os.clock()
	local botTimeout = Config.Bots.ThinkInterval * 2 + 0.25
	local range = Config.Downed.ReviveRadius + RANGE_SLACK
	for _, session in sessions do
		local reviverRoot, casualtyRoot = session.reviver.root, session.casualty.root
		local valid = Squad.isAlive(session.reviver)
			and session.casualty.state == "Downed"
			and reviverRoot ~= nil
			and casualtyRoot ~= nil
			and (reviverRoot.Position - casualtyRoot.Position).Magnitude <= range
			and (not session.bot or now - session.seenAt <= botTimeout)
		if not valid then
			endSession(session)
		elseif reviverRoot and now >= session.nextSound then
			session.nextSound = now + settings.Sound.Interval
			playTreatSound(reviverRoot)
		end
	end
end

function ReviveAnimService.init()
	if not settings.Enabled then
		return
	end
	Squad.onRevive(function(event, casualty, reviver)
		if event == "complete" then
			ReviveAnimService.complete(casualty, reviver)
		elseif reviver and event == "begin" then
			ReviveAnimService.begin(reviver, casualty)
		elseif reviver and event == "cancel" then
			ReviveAnimService.cancel(reviver)
		end
	end)
	-- The server owns a bot's Animator: it plays the bot's clips.
	local function driveBot(instance: Instance)
		if instance:IsA("Model") then
			task.spawn(ReviveAnimation.drive, instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(BOT_TAG):Connect(driveBot)
	for _, bot in CollectionService:GetTagged(BOT_TAG) do
		driveBot(bot)
	end
	RunService.Heartbeat:Connect(step)
end

return ReviveAnimService
