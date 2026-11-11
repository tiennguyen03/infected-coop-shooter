--!strict
-- Call-ins: keys 1-4 fire the call-ins in the player's Config.CallIns.Slots slots (the
-- loadout, LoadoutService.getCallIn). Each slot holds Config.CallIns.<Key>.Charges
-- charges that refill one at a time every Cooldown seconds; a Restock card fills them.
-- Server-authoritative: the client sends the slot and where it aimed; this validates
-- (alive, not paused, a charge), clamps the throw with ThrowUtil like the flare, and hands
-- the effect to the owning service (AirStrikeService: Hammer, Anvil, Shrike; SentryService:
-- Doorman; MineService: Tripline; ConcertinaService; SupplyDropService: Speedball, Aid Bag)
-- with that call-in's upgrade flag. Published per player as
-- CallIn<n>Charges and CallIn<n>ReadyAt (server time of the next charge; 0 when full).
-- Arrivals (Rules/Arrival, Config.CallIns.Arrivals): every throw is told to every client
-- once (remote CallInArrival) and CallInArrivalFX draws how that call-in comes in; an
-- emplacement or a bundle is held back here for its row's Arrival.Time while it does.
-- Binoculars (a row with AimMode "Binoculars": the Anvil; Rules/Spotting, SpotUtil): nothing
-- is thrown. The client says when the binoculars go up and come down (remote CallInSpot;
-- the body's Spotting attribute shows them to the squad), then sends the mark over CallIn;
-- the mark is taken only from binoculars that are up, on ground, in range and in the line
-- of sight of the soldier's own head. `spotFor` does the same for a body without a slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Arrival = require(ReplicatedStorage.Shared.Rules.Arrival)
local CallInCharges = require(ReplicatedStorage.Shared.Rules.CallInCharges)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Spotting = require(ReplicatedStorage.Shared.Rules.Spotting)
local SpotUtil = require(ReplicatedStorage.Shared.SpotUtil)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local AirStrikeService = require(script.Parent.AirStrikeService)
local ConcertinaService = require(script.Parent.ConcertinaService)
local LoadoutService = require(script.Parent.LoadoutService)
local MineService = require(script.Parent.MineService)
local PauseService = require(script.Parent.PauseService)
local SentryService = require(script.Parent.SentryService)
local SupplyDropService = require(script.Parent.SupplyDropService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

-- Folders a throw never lands on (effects and pickups between the thrower and the ground).
local THROW_PASS_THROUGH = {
	"Resupply",
	"ResupplyCards",
	"Sentries",
	"Wire",
	"SupplyDrops",
	"Mines",
	"FirePools",
	"KitEffects",
	"CallInEffects",
	"StrikeEffects",
	"Projectiles",
	"InfectedProjectiles",
	"SquadBots",
}

type Slot = {
	charges: number,
	nextChargeAt: number?, -- os.clock; nil when full
}

local CallInService = {}

-- How many call-in slots a loadout has (the soldier kit owns the number).
local function slotCount(): number
	return ((Config.CallIns :: { [string]: any }).Slots :: number?) or 2
end

local slots: { [Player]: { Slot } } = {}
-- Whose binoculars are up: the slot they are for and when they went up (os.clock).
local spotting: { [Player]: { slot: number, since: number } } = {}
local usedRemote: RemoteEvent
local arrivalRemote: RemoteEvent
local lastStep = 0
-- Bumped on a run start so kit still on its way down from the last run never lands in the next.
local generation = 0

-- Runs `deploy` once the kit has arrived, `seconds` of unpaused time from now (at once for
-- 0). Dropped when the run restarted or the thrower left meanwhile.
local function deployAfter(seconds: number, player: Player, deploy: () -> ())
	if seconds <= 0 then
		deploy()
		return
	end
	local thisGeneration = generation
	task.spawn(function()
		PauseService.wait(seconds)
		if thisGeneration == generation and player.Parent then
			deploy()
		end
	end)
end

local function chargesFor(player: Player, slot: number): number
	local definition = CallInDefinitions.get(LoadoutService.getCallIn(player, slot))
	if not definition then
		return 0
	end
	return (Config.CallIns :: { [string]: any })[definition.ConfigKey].Charges
end

local function cooldownFor(player: Player, slot: number): number
	local definition = CallInDefinitions.get(LoadoutService.getCallIn(player, slot))
	if not definition then
		return 0
	end
	return (Config.CallIns :: { [string]: any })[definition.ConfigKey].Cooldown
end

local function publish(player: Player, slot: number, state: Slot)
	player:SetAttribute(Attributes.callInCharges(slot), state.charges)
	local nextChargeAt = state.nextChargeAt
	player:SetAttribute(
		Attributes.callInReadyAt(slot),
		if nextChargeAt then workspace:GetServerTimeNow() + (nextChargeAt - os.clock()) else 0
	)
end

local function fresh(player: Player, slot: number): Slot
	return { charges = chargesFor(player, slot), nextChargeAt = nil }
end

local function get(player: Player): { Slot }
	local state = slots[player]
	if state then
		return state
	end
	local created: { Slot } = {}
	for slot = 1, slotCount() do
		created[slot] = fresh(player, slot)
		publish(player, slot, created[slot])
	end
	slots[player] = created
	return created
end

-- Every slot back to full (a Restock card, a run start).
function CallInService.refill(player: Player)
	local state = get(player)
	for slot = 1, slotCount() do
		state[slot] = fresh(player, slot)
		publish(player, slot, state[slot])
	end
end

local function throwExclusions(character: Model): { Instance }
	local exclude: { Instance } = { character }
	for _, name in THROW_PASS_THROUGH do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	return exclude
end

-- Fires `definition` for `player`. Returns true when the effect went off (a charge is spent).
local function fire(
	player: Player,
	definition: CallInDefinitions.CallInDefinition,
	requested: Vector3?
): boolean
	local member = Squad.fromPlayer(player)
	local character = player.Character
	local root = member and member.root
	if not member or not character or not root then
		return false
	end
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]

	local landing = root.Position
	local direction = root.CFrame.LookVector
	local marked = Spotting.mode(cfg) == "Binoculars"
	if marked then
		-- Marked through binoculars: the point itself (onCallIn checked it), nothing thrown.
		landing = requested or landing
	elseif definition.Kind == "throw" then
		landing =
			ThrowUtil.landingPoint(root, requested, cfg.ThrowDistance, throwExclusions(character))
		WorldSounds.at(landing, "callins", "callin_throw")
	end
	local flat = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
	if flat.Magnitude > 0.5 then
		direction = flat.Unit
	end
	-- The arrival: the clients draw it, and anything that is not a fire mission (those keep
	-- their own Delay) is on the ground and working `holdFor` seconds from now.
	local arrivals = Config.CallIns.Arrivals
	local arrival = Arrival.resolve(arrivals.Defaults :: any, cfg.Arrival)
	local holdFor = Arrival.deployDelay(arrival, arrivals.Enabled)
	local impacts: { Vector3 }? = nil
	local fired = false
	local id = definition.Id
	if id == "hammer" then
		local walking = LoadoutService.hasUpgrade(player, "walking_barrage")
		local step = if walking then Config.Upgrades.WalkingBarrage.Step else 0
		fired, impacts =
			AirStrikeService.fireMission(player, Config.CallIns.Hammer, landing, direction, step)
	elseif id == "anvil" then
		fired, impacts =
			AirStrikeService.fireMission(player, Config.CallIns.Anvil, landing, direction, 0)
	elseif id == "shrike" then
		fired, impacts = AirStrikeService.gunRun(player, landing, direction)
	elseif id == "doorman" then
		fired = true
		deployAfter(holdFor, player, function()
			SentryService.deploy(player, landing, direction)
		end)
	elseif id == "tripline" then
		fired = true
		deployAfter(holdFor, player, function()
			MineService.layArc(player, landing, direction)
		end)
	elseif id == "concertina" then
		fired = true
		deployAfter(holdFor, player, function()
			ConcertinaService.lay(player, landing, direction)
		end)
	elseif id == "speedball" or id == "aid_bag" then
		fired = true
		local falls = not arrivals.Enabled
		deployAfter(holdFor, player, function()
			SupplyDropService.drop(id, landing, direction, falls)
		end)
	end
	if fired and arrivals.Enabled then
		arrivalRemote:FireAllClients(id, player, landing, direction, impacts)
	end
	return fired
end

-- Dev tools (DevTestService FireCallIn): fires call-in `id` for `player` aimed at `point`
-- without a slot or a charge. False for an unknown id or no body.
function CallInService.fireFree(player: Player, id: string, point: Vector3?): boolean
	local definition = CallInDefinitions.get(id)
	if not definition then
		return false
	end
	return fire(player, definition, point)
end

-- The binoculars come down (the body's Spotting attribute goes with them).
local function lower(player: Player)
	spotting[player] = nil
	local character = player.Character
	if character and character:GetAttribute(Attributes.Spotting) ~= nil then
		character:SetAttribute(Attributes.Spotting, nil)
	end
end

-- Whether `point` is ground the body can see from its own head, within the row's range
-- (Rules/Spotting, with the server's slack).
local function markSeen(character: Model, cfg: any, point: Vector3): (boolean, string?)
	local eye = SpotUtil.eye(character)
	if not eye then
		return false, "no body"
	end
	local settings = SpotUtil.settings(cfg)
	local measured = SpotUtil.measure(eye, point, settings, SpotUtil.exclusions(true))
	return Spotting.check(settings, measured, true)
end

local function validSlot(slot: unknown): boolean
	return typeof(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= slotCount()
end

-- CallInSpot: the client's binoculars went up for `slot`, or came down.
local function onSpot(player: Player, slot: unknown, raised: unknown)
	if raised ~= true or not validSlot(slot) or PauseService.isPaused() then
		lower(player)
		return
	end
	local member = Squad.fromPlayer(player)
	local character = player.Character
	local slotIndex = slot :: number
	local definition = CallInDefinitions.get(LoadoutService.getCallIn(player, slotIndex))
	local cfg = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	local state = get(player)[slotIndex]
	if
		not member
		or not character
		or not Squad.canAct(member)
		or Spotting.mode(cfg) ~= "Binoculars"
		or not CallInCharges.use(state.charges, state.nextChargeAt, os.clock(), 0)
	then
		lower(player)
		return
	end
	spotting[player] = { slot = slotIndex, since = os.clock() }
	character:SetAttribute(Attributes.Spotting, true)
end

-- A body without a slot marks a point through binoculars and fires call-in `id` on it: a
-- squad bot (BotService carries no call-ins yet; this is its way in). The body raises the
-- binoculars for the row's Raise, then the mission goes; no view, no charge. `credit` gets
-- the kills. False when the row is not a binoculars fire mission or the body cannot see
-- the point.
function CallInService.spotFor(
	character: Model,
	id: string,
	point: Vector3,
	credit: Player?
): boolean
	local definition = CallInDefinitions.get(id)
	local cfg = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not definition or not cfg or not (root and root:IsA("BasePart")) then
		return false
	end
	if Spotting.mode(cfg) ~= "Binoculars" or typeof(cfg.Shells) ~= "number" then
		return false
	end
	if PauseService.isPaused() or not markSeen(character, cfg, point) then
		return false
	end
	local settings = SpotUtil.settings(cfg)
	local thisGeneration = generation
	character:SetAttribute(Attributes.Spotting, true)
	task.spawn(function()
		PauseService.wait(settings.Raise)
		if character.Parent then
			character:SetAttribute(Attributes.Spotting, nil)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if thisGeneration ~= generation or not humanoid or humanoid.Health <= 0 then
			return
		end
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		local direction = if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
		local _, impacts = AirStrikeService.fireMission(credit, cfg, point, direction, 0)
		if Config.CallIns.Arrivals.Enabled then
			arrivalRemote:FireAllClients(definition.Id, credit, point, direction, impacts)
		end
	end)
	return true
end

local function onCallIn(player: Player, slot: unknown, requested: unknown)
	if not validSlot(slot) then
		return
	end
	if PauseService.isPaused() then
		return
	end
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) then
		return
	end
	local slotIndex = slot :: number
	local definition = CallInDefinitions.get(LoadoutService.getCallIn(player, slotIndex))
	if not definition then
		return
	end
	-- Daisy Chain: the Tripline key with mines still armed blows them (no charge spent).
	if
		definition.Id == "tripline"
		and LoadoutService.hasUpgrade(player, "command_detonation")
		and MineService.armedCount(player) > 0
	then
		local blown = MineService.detonateAll(player)
		usedRemote:FireClient(player, Messages.Ability.CallIn, slotIndex, "detonate")
		print(`[CallIn] {player.Name} blew {blown} mine(s) (Daisy Chain)`)
		return
	end
	local state = get(player)[slotIndex]
	-- CallInCharges.use is the gate: an empty slot refuses before anything is thrown.
	local canUse = CallInCharges.use(state.charges, state.nextChargeAt, os.clock(), 0)
	if not canUse then
		return
	end
	local point = if typeof(requested) == "Vector3" then requested else nil
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	if Spotting.mode(cfg) == "Binoculars" then
		-- The mark counts only from this slot's binoculars, up for the raise; they come down
		-- whether or not it is taken.
		local up = spotting[player]
		local raisedFor = if up and up.slot == slotIndex then os.clock() - up.since else nil
		lower(player)
		local character = player.Character
		if not point or not character then
			return
		end
		if not Spotting.canConfirm(raisedFor, SpotUtil.settings(cfg)) then
			print(`[CallIn] {player.Name}: {definition.Name} mark refused (binoculars not up)`)
			return
		end
		local seen, reason = markSeen(character, cfg, point)
		if not seen then
			print(`[CallIn] {player.Name}: {definition.Name} mark refused ({reason})`)
			return
		end
	end
	if not fire(player, definition, point) then
		return
	end
	local _
	_, state.charges, state.nextChargeAt = CallInCharges.use(
		state.charges,
		state.nextChargeAt,
		os.clock(),
		cooldownFor(player, slotIndex)
	)
	publish(player, slotIndex, state)
	usedRemote:FireClient(player, Messages.Ability.CallIn, slotIndex, definition.Id)
	print(`[CallIn] {player.Name} used {definition.Name} ({state.charges} left)`)
end

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, state in slots do
			for _, slotState in state do
				if slotState.nextChargeAt then
					slotState.nextChargeAt += shift
				end
			end
		end
		lastStep = now
		return
	end
	lastStep = now
	for player, state in slots do
		for slot, slotState in state do
			local before = slotState.nextChargeAt
			slotState.charges, slotState.nextChargeAt = CallInCharges.tick(
				slotState.charges,
				chargesFor(player, slot),
				before,
				now,
				cooldownFor(player, slot)
			)
			if slotState.nextChargeAt ~= before then
				publish(player, slot, slotState)
			end
		end
	end
end

-- Run start: full charges in every slot.
function CallInService.resetPlayer(player: Player)
	lower(player)
	CallInService.refill(player)
end

function CallInService.init()
	Lifecycle.register("CallInService", {
		onRunStart = function()
			generation += 1
		end,
		onPlayerReset = CallInService.resetPlayer,
		onPlayerRemoving = function(player: Player)
			slots[player] = nil
			spotting[player] = nil
		end,
	})
	usedRemote = Remotes.get("AbilityUsed")
	arrivalRemote = Remotes.get("CallInArrival")
	Remotes.get("CallIn").OnServerEvent:Connect(onCallIn)
	Remotes.get("CallInSpot").OnServerEvent:Connect(onSpot)
	-- Going down takes the binoculars with it.
	Squad.onStateChanged(function(member, _old, new)
		if member.owner and new ~= "Alive" then
			lower(member.owner)
		end
	end)
	-- A changed slot (dev panel, the Arms Room) starts full, or empty with its cooldown
	-- running when the Arms Room changed it in a run.
	LoadoutService.onCallInChanged(function(player, slot, startEmpty)
		local state = get(player)
		state[slot] = fresh(player, slot)
		if startEmpty then
			state[slot].charges = 0
			state[slot].nextChargeAt = os.clock() + cooldownFor(player, slot)
		end
		publish(player, slot, state[slot])
	end)
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)
	Players.PlayerAdded:Connect(function(player)
		get(player)
	end)
	for _, player in Players:GetPlayers() do
		get(player)
	end
end

return CallInService
