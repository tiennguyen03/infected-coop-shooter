--!strict
-- Call-ins: keys 1 and 2 fire the two call-ins the player's
-- loadout carries (LoadoutService.getCallIn). Each slot holds Config.CallIns.<Key>.Charges
-- charges that refill one at a time every Cooldown seconds; a Restock card fills them.
-- Server-authoritative: the client sends the slot and where it aimed; this validates
-- (alive, not paused, a charge), clamps the throw with ThrowUtil like the flare, and hands
-- the effect to the owning service (DroneService, MineService, AirStrikeService,
-- ShockCoilService) with that call-in's upgrade flag. Published per player as
-- CallIn<n>Charges and CallIn<n>ReadyAt (server time of the next charge; 0 when full).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ThrowUtil = require(ReplicatedStorage.Shared.ThrowUtil)
local AirStrikeService = require(script.Parent.AirStrikeService)
local DroneService = require(script.Parent.DroneService)
local LoadoutService = require(script.Parent.LoadoutService)
local MineService = require(script.Parent.MineService)
local PauseService = require(script.Parent.PauseService)
local ShockCoilService = require(script.Parent.ShockCoilService)
local Squad = require(script.Parent.Squad)

-- Folders a throw never lands on (effects and pickups between the thrower and the ground).
local THROW_PASS_THROUGH = {
	"Resupply",
	"ResupplyCards",
	"Drones",
	"Mines",
	"FirePools",
	"AssaultEffects",
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
	player:SetAttribute(`CallIn{slot}Charges`, state.charges)
	local nextChargeAt = state.nextChargeAt
	player:SetAttribute(
		`CallIn{slot}ReadyAt`,
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
	local created: { Slot } = { fresh(player, 1), fresh(player, 2) }
	slots[player] = created
	publish(player, 1, created[1])
	publish(player, 2, created[2])
	return created
end

-- Both slots back to full (a Restock card, a run start).
function CallInService.refill(player: Player)
	local state = get(player)
	for slot = 1, 2 do
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

	if definition.Id == "magpie" then
		return DroneService.deployBeacon(
			player,
			landing,
			LoadoutService.hasUpgrade(player, "escort")
		)
	elseif definition.Id == "tripline" then
		return MineService.layArc(player, landing, direction)
	elseif definition.Id == "anvil" then
		return AirStrikeService.fireMission(
			player,
			landing,
			direction,
			LoadoutService.hasUpgrade(player, "walking_barrage")
		)
	elseif definition.Id == "pen_coil" then
		return ShockCoilService.pulse(player, LoadoutService.hasUpgrade(player, "defibrillator"))
	end
	return false
end

local function onCallIn(player: Player, slot: unknown, requested: unknown)
	if slot ~= 1 and slot ~= 2 then
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
		usedRemote:FireClient(player, "callin", slotIndex, "detonate")
		print(`[CallIn] {player.Name} blew {blown} mine(s) (Daisy Chain)`)
		return
	end
	local state = get(player)[slotIndex]
	if state.charges <= 0 then
		return
	end
	local point = if typeof(requested) == "Vector3" then requested else nil
	if not fire(player, definition, point) then
		return
	end
	state.charges -= 1
	if not state.nextChargeAt then
		state.nextChargeAt = os.clock() + cooldownFor(player, slotIndex)
	end
	publish(player, slotIndex, state)
	usedRemote:FireClient(player, "callin", slotIndex, definition.Id)
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
			local nextChargeAt = slotState.nextChargeAt
			if nextChargeAt and now >= nextChargeAt then
				local max = chargesFor(player, slot)
				slotState.charges = math.min(slotState.charges + 1, max)
				slotState.nextChargeAt = if slotState.charges < max
					then nextChargeAt + cooldownFor(player, slot)
					else nil
				publish(player, slot, slotState)
			end
		end
	end
end

-- Run start: full charges for both slots.
function CallInService.resetPlayer(player: Player)
	CallInService.refill(player)
end

function CallInService.init()
	usedRemote = Remotes.get("AbilityUsed")
	Remotes.get("CallIn").OnServerEvent:Connect(onCallIn)
	-- A swapped slot (dev panel, later the Armory) starts full.
	LoadoutService.onCallInChanged(function(player, slot)
		local state = get(player)
		state[slot] = fresh(player, slot)
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
	Players.PlayerRemoving:Connect(function(player)
		slots[player] = nil
	end)
end

return CallInService
