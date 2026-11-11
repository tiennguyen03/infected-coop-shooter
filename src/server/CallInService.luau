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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local CallInCharges = require(ReplicatedStorage.Shared.Rules.CallInCharges)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
local usedRemote: RemoteEvent
local lastStep = 0

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
	if definition.Kind == "throw" then
		landing =
			ThrowUtil.landingPoint(root, requested, cfg.ThrowDistance, throwExclusions(character))
		local flat = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
		if flat.Magnitude > 0.5 then
			direction = flat.Unit
		end
	end

	if definition.Kind == "throw" then
		WorldSounds.at(landing, "callins", "callin_throw")
	end
	local id = definition.Id
	if id == "hammer" then
		local walking = LoadoutService.hasUpgrade(player, "walking_barrage")
		local step = if walking then Config.Upgrades.WalkingBarrage.Step else 0
		return AirStrikeService.fireMission(player, Config.CallIns.Hammer, landing, direction, step)
	elseif id == "anvil" then
		return AirStrikeService.fireMission(player, Config.CallIns.Anvil, landing, direction, 0)
	elseif id == "shrike" then
		return AirStrikeService.gunRun(player, landing, direction)
	elseif id == "doorman" then
		return SentryService.deploy(player, landing, direction)
	elseif id == "tripline" then
		return MineService.layArc(player, landing, direction)
	elseif id == "concertina" then
		return ConcertinaService.lay(player, landing, direction)
	elseif id == "speedball" or id == "aid_bag" then
		return SupplyDropService.drop(id, landing, direction)
	end
	return false
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

-- A bot's fire mission (BotService; it keeps its own cooldown): a shelled mission (the
-- Hammer, the Anvil) thrown from `member`'s body at `point`, clamped and landed like a player's throw, with no
-- owner (no kill credit, no upgrades). False for any other call-in or no body.
function CallInService.fireMissionFor(member: Squad.Member, id: string, point: Vector3): boolean
	local definition = CallInDefinitions.get(id)
	local character, root = member.character, member.root
	if not definition or not character or not root or not Squad.canAct(member) then
		return false
	end
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	-- A shelled fire mission is a thrown row with Shells (AirStrikeService.MissionConfig).
	if definition.Kind ~= "throw" or typeof(cfg.Shells) ~= "number" then
		return false
	end
	local landing =
		ThrowUtil.landingPoint(root, point, cfg.ThrowDistance, throwExclusions(character))
	local flat = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
	local direction = if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
	WorldSounds.at(landing, "callins", "callin_throw")
	return AirStrikeService.fireMission(nil, cfg, landing, direction, 0)
end

local function onCallIn(player: Player, slot: unknown, requested: unknown)
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > slotCount() then
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
	CallInService.refill(player)
end

function CallInService.init()
	Lifecycle.register("CallInService", {
		onPlayerReset = CallInService.resetPlayer,
		onPlayerRemoving = function(player: Player)
			slots[player] = nil
		end,
	})
	usedRemote = Remotes.get("AbilityUsed")
	Remotes.get("CallIn").OnServerEvent:Connect(onCallIn)
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
