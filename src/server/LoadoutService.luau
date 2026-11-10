--!strict
-- The loadout (docs/PROGRESSION.md > Loadout): per player, the primary and the secondary
-- with their own magazines and reserves (Q swaps them), the grenade type with the grenades
-- and stims left, the call-ins in Config.CallIns.Slots slots (keys 1-4), the field-upgrade
-- slots and the Armour Plate shield. Power comes from here, not from in-run growth.
-- Server-authoritative: ProjectileServer asks consumeRound before every shot, the Reload
-- remote starts a reload here, pallets re-arm through refillAmmo, KitService spends
-- grenades and stims, RequisitionService hands out cards through giveUpgrade / addShield /
-- refillStims / refillGrenades, and every other service asks hasUpgrade for its flag.
-- The Arms Room (LoadoutMenu, the Loadout remote) changes the pick through apply(), which
-- validates with Rules/Loadout and gates the timing (Insert / ready-up any time; in a run at
-- the LZ after a calm spell). The pick survives a run restart. State is published as Player
-- attributes (Weapon, Primary, Secondary, Mag, Reserve, ReloadUntil, SwapUntil, Grenade,
-- Grenades, Stims, CallIn<n>, Upgrade<Slot>, Shield) so the HUD reads LocalPlayer only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Magazine = require(ReplicatedStorage.Shared.Rules.Magazine)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local DamageService = require(script.Parent.DamageService)
local JoinData = require(script.Parent.JoinData)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local LoadoutService = {}

type Gun = {
	id: string,
	mag: number,
	reserve: number,
}

type GunSlot = "primary" | "secondary"

type State = {
	primary: Gun,
	secondary: Gun,
	active: GunSlot,
	grenade: string,
	grenades: number,
	stims: number,
	callIns: { string }, -- [slot]
	upgrades: { [string]: string }, -- slot (UpgradeDefinitions.SLOTS) -> upgrade id
	reloadUntil: number?, -- os.clock; nil when not reloading
	swapUntil: number?, -- os.clock; nil when not swapping
	shield: number,
	lastCombatAt: number, -- os.clock of the last damage dealt or taken
}

export type CallInChangedListener = (player: Player, slot: number, startEmpty: boolean) -> ()

local states: { [Player]: State } = {}
-- The Arms Room pick per player; kept across runs (a run reset re-arms it).
local picks: { [Player]: Loadout.Loadout } = {}
local callInChangedListeners: { CallInChangedListener } = {}
local resultRemote: RemoteEvent
local lastStep = 0

local function fullGun(id: string): Gun
	local weapon = WeaponDefinitions.get(id)
	return { id = weapon.Id, mag = weapon.MagazineSize, reserve = weapon.ReserveStart }
end

local function pickFor(player: Player): Loadout.Loadout
	local pick = picks[player]
	if not pick then
		-- The Loadout signed for at the lobby's Loadmaster (teleport data, re-checked), else
		-- the default.
		pick = JoinData.loadout(player) or ArmsRoom.default()
		picks[player] = pick
	end
	return pick
end

local function freshState(pick: Loadout.Loadout): State
	return {
		primary = fullGun(pick.primary),
		secondary = fullGun(pick.secondary),
		active = "primary",
		grenade = pick.grenade,
		grenades = Config.Grenade.Carried,
		stims = Config.Stim.Carried,
		callIns = table.clone(pick.callIns),
		upgrades = {},
		reloadUntil = nil,
		swapUntil = nil,
		shield = 0,
		lastCombatAt = 0,
	}
end

local function get(player: Player): State
	local state = states[player]
	if not state then
		state = freshState(pickFor(player))
		states[player] = state
	end
	return state
end

local function activeGun(state: State): Gun
	return if state.active == "primary" then state.primary else state.secondary
end

local function serverTime(clock: number?): number
	return if clock then workspace:GetServerTimeNow() + (clock - os.clock()) else 0
end

local function publishAmmo(player: Player, state: State)
	local gun = activeGun(state)
	player:SetAttribute(Attributes.Weapon, gun.id)
	player:SetAttribute(Attributes.Primary, state.primary.id)
	player:SetAttribute(Attributes.Secondary, state.secondary.id)
	player:SetAttribute(Attributes.Mag, gun.mag)
	player:SetAttribute(Attributes.Reserve, gun.reserve)
	player:SetAttribute(Attributes.ReloadUntil, serverTime(state.reloadUntil))
	player:SetAttribute(Attributes.SwapUntil, serverTime(state.swapUntil))
end

local function publishKit(player: Player, state: State)
	player:SetAttribute(Attributes.Grenade, state.grenade)
	player:SetAttribute(Attributes.Grenades, state.grenades)
	player:SetAttribute(Attributes.Stims, state.stims)
end

local function publishLoadout(player: Player, state: State)
	for slot = 1, Config.CallIns.Slots do
		player:SetAttribute(Attributes.callIn(slot), state.callIns[slot] or "")
	end
	for _, slot in UpgradeDefinitions.SLOTS do
		player:SetAttribute(Attributes.upgrade(slot), state.upgrades[slot] or "")
	end
	player:SetAttribute(Attributes.Shield, state.shield)
end

local function publish(player: Player, state: State)
	publishAmmo(player, state)
	publishKit(player, state)
	publishLoadout(player, state)
end

local function canAct(player: Player): boolean
	local member = Squad.fromPlayer(player)
	return member ~= nil and Squad.canAct(member) and not PauseService.isPaused()
end

local function swapping(state: State): boolean
	local swapUntil = state.swapUntil
	return swapUntil ~= nil and os.clock() < swapUntil
end

----------------------------------------------------------------------
-- Guns, magazines, reserves
----------------------------------------------------------------------

-- The gun in hand.
function LoadoutService.getWeapon(player: Player): WeaponDefinitions.WeaponDefinition
	return WeaponDefinitions.get(activeGun(get(player)).id)
end

-- Puts `weaponId` in its slot, full, and in hand (dev panel).
function LoadoutService.setWeapon(player: Player, weaponId: string): boolean
	if not WeaponDefinitions.exists(weaponId) then
		return false
	end
	local state = get(player)
	local weapon = WeaponDefinitions.get(weaponId)
	local pick = pickFor(player)
	if weapon.Slot == "primary" then
		state.primary = fullGun(weapon.Id)
		pick.primary = weapon.Id
	else
		state.secondary = fullGun(weapon.Id)
		pick.secondary = weapon.Id
	end
	state.active = weapon.Slot
	state.reloadUntil = nil
	state.swapUntil = nil
	publishAmmo(player, state)
	return true
end

function LoadoutService.isReloading(player: Player): boolean
	return get(player).reloadUntil ~= nil
end

-- A shot: false when the magazine is empty, a reload or a swap is in progress.
function LoadoutService.consumeRound(player: Player): boolean
	local state = get(player)
	local gun = activeGun(state)
	if swapping(state) or not Magazine.canFire(gun.mag, state.reloadUntil ~= nil) then
		return false
	end
	gun.mag -= 1
	player:SetAttribute(Attributes.Mag, gun.mag)
	return true
end

local function finishReload(player: Player, state: State)
	local gun = activeGun(state)
	local weapon = WeaponDefinitions.get(gun.id)
	gun.mag, gun.reserve = Magazine.reload(gun.mag, gun.reserve, weapon.MagazineSize)
	state.reloadUntil = nil
	publishAmmo(player, state)
end

-- R: starts a reload when the magazine is short and rounds remain. True when one started.
function LoadoutService.startReload(player: Player): boolean
	local state = get(player)
	local gun = activeGun(state)
	local weapon = WeaponDefinitions.get(gun.id)
	if
		swapping(state)
		or not Magazine.canReload(
			gun.mag,
			gun.reserve,
			weapon.MagazineSize,
			state.reloadUntil ~= nil
		)
	then
		return false
	end
	local member = Squad.fromPlayer(player)
	if not member or not canAct(player) then
		return false
	end
	state.reloadUntil = os.clock() + weapon.ReloadTime
	publishAmmo(player, state)
	if member.root then
		local own = if weapon.Sound then weapon.Sound .. "_reload" else nil
		if own and SoundBanks.hasGroup(SoundBanks.GUN_BANK, own) then
			WorldSounds.on(member.root, SoundBanks.GUN_BANK, own, "Gear")
		else
			WorldSounds.on(member.root, "player_gear", "reload", "Gear")
		end
	end
	return true
end

-- A roll, a slide, a swap or going down drops the reload (the rounds stay where they were).
function LoadoutService.cancelReload(player: Player)
	local state = states[player]
	if state and state.reloadUntil then
		state.reloadUntil = nil
		publishAmmo(player, state)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			WorldSounds.stop(root, "Gear")
		end
	end
end

-- Q: long gun <-> sidearm. Each keeps its own magazine; a reload in progress is dropped.
function LoadoutService.swap(player: Player): boolean
	local state = get(player)
	if swapping(state) or not canAct(player) then
		return false
	end
	LoadoutService.cancelReload(player)
	state.active = if state.active == "primary" then "secondary" else "primary"
	state.swapUntil = os.clock() + Config.Weapon.SwapTime
	publishAmmo(player, state)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		WorldSounds.on(root, "player_gear", "dry_fire", "Gear")
	end
	return true
end

-- A pallet's ammo box: both guns full (magazine and reserve) and the grenades back.
function LoadoutService.refillAmmo(player: Player)
	local state = get(player)
	for _, gun in { state.primary, state.secondary } do
		local weapon = WeaponDefinitions.get(gun.id)
		gun.mag = weapon.MagazineSize
		gun.reserve = weapon.ReserveMax
	end
	state.reloadUntil = nil
	state.grenades = Config.Grenade.Carried
	publishAmmo(player, state)
	publishKit(player, state)
end

----------------------------------------------------------------------
-- Grenades and stims (KitService spends them)
----------------------------------------------------------------------

function LoadoutService.getGrenade(player: Player): string
	return get(player).grenade
end

-- One grenade out of the pouch; false when none are left.
function LoadoutService.useGrenade(player: Player): boolean
	local state = get(player)
	if state.grenades <= 0 then
		return false
	end
	state.grenades -= 1
	publishKit(player, state)
	return true
end

function LoadoutService.refillGrenades(player: Player)
	local state = get(player)
	state.grenades = Config.Grenade.Carried
	publishKit(player, state)
end

function LoadoutService.useStim(player: Player): boolean
	local state = get(player)
	if state.stims <= 0 then
		return false
	end
	state.stims -= 1
	publishKit(player, state)
	return true
end

function LoadoutService.refillStims(player: Player)
	local state = get(player)
	state.stims = Config.Stim.Carried
	publishKit(player, state)
end

----------------------------------------------------------------------
-- Call-in slots
----------------------------------------------------------------------

function LoadoutService.getCallIn(player: Player, slot: number): string?
	return get(player).callIns[slot]
end

-- The slot carrying `callInId`, or nil.
function LoadoutService.slotOfCallIn(player: Player, callInId: string): number?
	for slot, id in get(player).callIns do
		if id == callInId then
			return slot
		end
	end
	return nil
end

-- CallInService listens: a changed slot starts full, or empty with its cooldown running
-- (`startEmpty`, an Arms Room change in a run).
function LoadoutService.onCallInChanged(listener: CallInChangedListener)
	table.insert(callInChangedListeners, listener)
end

local function notifyCallIn(player: Player, slot: number, startEmpty: boolean)
	for _, listener in callInChangedListeners do
		listener(player, slot, startEmpty)
	end
end

-- New call-ins per slot: an upgrade follows its call-in to its new slot and leaves with it.
local function setCallIns(player: Player, state: State, callIns: { string }, startEmpty: boolean)
	local old = state.callIns
	local moved: { [string]: string } = {}
	for slot = 1, Config.CallIns.Slots do
		local key = UpgradeDefinitions.callInSlot(slot)
		local upgrade = state.upgrades[key]
		if upgrade and old[slot] then
			moved[old[slot]] = upgrade
		end
		state.upgrades[key] = nil
	end
	state.callIns = table.clone(callIns)
	for slot, id in state.callIns do
		state.upgrades[UpgradeDefinitions.callInSlot(slot)] = moved[id]
	end
	publishLoadout(player, state)
	for _, slot in Loadout.changedSlots(old, state.callIns) do
		notifyCallIn(player, slot, startEmpty)
	end
end

-- Puts `callInId` in `slot` (dev panel); the same tool already in another slot swaps over.
function LoadoutService.setCallIn(player: Player, slot: number, callInId: string): boolean
	if slot < 1 or slot > Config.CallIns.Slots or not CallInDefinitions.get(callInId) then
		return false
	end
	local state = get(player)
	local callIns = table.clone(state.callIns)
	local other = table.find(callIns, callInId)
	if other then
		callIns[other] = callIns[slot]
	end
	callIns[slot] = callInId
	setCallIns(player, state, callIns, false)
	pickFor(player).callIns = table.clone(callIns)
	return true
end

----------------------------------------------------------------------
-- The Arms Room
----------------------------------------------------------------------

-- Seconds since this player last dealt or took damage.
function LoadoutService.calmFor(player: Player): number
	return os.clock() - get(player).lastCombatAt
end

-- EnemyProjectileService (damage taken) and the hit listener (damage dealt).
function LoadoutService.noteCombat(player: Player)
	local state = states[player]
	if state then
		state.lastCombatAt = os.clock()
	end
end

local function gateState(player: Player): Loadout.GateState
	local member = Squad.fromPlayer(player)
	local root = member and member.root
	local lz = Config.Extraction.ZonePosition
	local distance = math.huge
	if root then
		distance = Vector3.new(root.Position.X - lz.X, 0, root.Position.Z - lz.Z).Magnitude
	end
	return {
		phase = RunStates.current(),
		lzDistance = distance,
		calmFor = LoadoutService.calmFor(player),
		alive = member ~= nil and Squad.canAct(member),
	}
end

-- The Arms Room's confirm. (true, nil) or (false, reason). A newly picked gun starts full,
-- re-picking the carried one keeps its ammo; a call-in that changes slot in a run starts
-- empty with its cooldown running (full before the drop).
function LoadoutService.apply(player: Player, requested: unknown): (boolean, string?)
	local ok, reason = Loadout.validate(requested, ArmsRoom.catalog())
	if not ok then
		return false, reason
	end
	local gate = gateState(player)
	ok, reason = Loadout.canChange(
		gate,
		{ lzRadius = Config.Loadout.LzRadius, calmSeconds = Config.Loadout.CalmSeconds }
	)
	if not ok then
		return false, reason
	end
	local source = requested :: Loadout.Loadout
	local pick: Loadout.Loadout = {
		primary = source.primary,
		secondary = source.secondary,
		grenade = source.grenade,
		callIns = table.clone(source.callIns),
	}
	picks[player] = pick
	local state = get(player)
	if state.primary.id ~= pick.primary then
		state.primary = fullGun(pick.primary)
	end
	if state.secondary.id ~= pick.secondary then
		state.secondary = fullGun(pick.secondary)
	end
	if state.grenade ~= pick.grenade then
		state.grenade = pick.grenade
		state.grenades = Config.Grenade.Carried
	end
	state.reloadUntil = nil
	setCallIns(player, state, pick.callIns, RunStates.isLive())
	publishAmmo(player, state)
	publishKit(player, state)
	print(
		`[Loadout] {player.Name}: {pick.primary} / {pick.secondary} / {pick.grenade} / {table.concat(
			pick.callIns,
			", "
		)}`
	)
	return true, nil
end

----------------------------------------------------------------------
-- Field upgrades
----------------------------------------------------------------------

-- The loadout slot an upgrade would fill for this player, or nil when it cannot (a call-in
-- upgrade for a call-in not carried).
local function slotFor(state: State, definition: UpgradeDefinitions.CardDefinition): string?
	if definition.Kind ~= "upgrade" then
		return nil
	end
	if definition.Slot ~= "CallIn" then
		return definition.Slot
	end
	for slot, id in state.callIns do
		if id == definition.CallIn then
			return UpgradeDefinitions.callInSlot(slot)
		end
	end
	return nil
end

function LoadoutService.hasUpgrade(player: Player, upgradeId: string): boolean
	local state = states[player]
	if not state then
		return false
	end
	for _, id in state.upgrades do
		if id == upgradeId then
			return true
		end
	end
	return false
end

function LoadoutService.getUpgrade(player: Player, slot: string): string?
	return get(player).upgrades[slot]
end

-- Takes an upgrade: its slot's previous pick is replaced. False when it does not apply.
function LoadoutService.giveUpgrade(player: Player, upgradeId: string): boolean
	local definition = UpgradeDefinitions.get(upgradeId)
	if not definition then
		return false
	end
	local state = get(player)
	local slot = slotFor(state, definition)
	if not slot then
		return false
	end
	state.upgrades[slot] = upgradeId
	publishLoadout(player, state)
	print(`[Loadout] {player.Name} took {definition.Name} ({slot})`)
	return true
end

function LoadoutService.clearUpgrades(player: Player)
	local state = get(player)
	table.clear(state.upgrades)
	publishLoadout(player, state)
end

-- Upgrades this player could take right now: applies to a slot they have, not already held.
function LoadoutService.availableUpgrades(player: Player): { string }
	local state = get(player)
	local ids = {}
	for _, id in UpgradeDefinitions.upgradeIds() do
		local definition = UpgradeDefinitions.get(id) :: UpgradeDefinitions.CardDefinition
		if slotFor(state, definition) and not LoadoutService.hasUpgrade(player, id) then
			table.insert(ids, id)
		end
	end
	return ids
end

-- `count` distinct random upgrades for an upgrade crate (fewer when the pool is short).
function LoadoutService.rollUpgradeOffer(player: Player, count: number): { string }
	local pool = LoadoutService.availableUpgrades(player)
	local choices = {}
	while #choices < count and #pool > 0 do
		local index = math.random(#pool)
		table.insert(choices, pool[index])
		table.remove(pool, index)
	end
	return choices
end

----------------------------------------------------------------------
-- Armour Plate
----------------------------------------------------------------------

function LoadoutService.addShield(player: Player, amount: number)
	local state = get(player)
	state.shield = math.min(state.shield + amount, Config.Crates.ShieldCap)
	player:SetAttribute(Attributes.Shield, state.shield)
end

-- Soaks `amount` of incoming damage on the plate; returns what reaches health.
function LoadoutService.absorb(player: Player, amount: number): number
	local state = states[player]
	if not state or state.shield <= 0 then
		return amount
	end
	local soaked = math.min(state.shield, amount)
	state.shield -= soaked
	player:SetAttribute(Attributes.Shield, state.shield)
	return amount - soaked
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, state in states do
			if state.reloadUntil then
				state.reloadUntil += shift
			end
		end
		lastStep = now
		return
	end
	lastStep = now
	for player, state in states do
		local reloadUntil = state.reloadUntil
		if reloadUntil and now >= reloadUntil then
			finishReload(player, state)
		end
		local swapUntil = state.swapUntil
		if swapUntil and now >= swapUntil then
			state.swapUntil = nil
		end
	end
end

-- A run start: the Arms Room pick re-armed full, no upgrades, no plate.
function LoadoutService.resetPlayer(player: Player)
	local state = freshState(pickFor(player))
	states[player] = state
	publish(player, state)
end

local function onLoadoutRemote(player: Player, kind: unknown, requested: unknown)
	if kind ~= Messages.Loadout.Request then
		return
	end
	local ok, reason = LoadoutService.apply(player, requested)
	resultRemote:FireClient(player, Messages.Loadout.Result, ok, reason)
end

function LoadoutService.init()
	Lifecycle.register("LoadoutService", {
		onPlayerReset = LoadoutService.resetPlayer,
		onPlayerRemoving = function(player: Player)
			states[player] = nil
			picks[player] = nil
		end,
	})
	Remotes.get("Reload").OnServerEvent:Connect(function(player: Player)
		LoadoutService.startReload(player)
	end)
	resultRemote = Remotes.get("Loadout")
	resultRemote.OnServerEvent:Connect(onLoadoutRemote)
	-- Damage dealt keeps the soldier "in contact" for the Arms Room gate.
	DamageService.addHitListener(function(info)
		if info.attacker then
			LoadoutService.noteCombat(info.attacker)
		end
	end)
	Squad.onStateChanged(function(member, _old, new)
		if member.owner and new ~= "Alive" then
			LoadoutService.cancelReload(member.owner)
		end
	end)
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)

	Players.PlayerAdded:Connect(function(player)
		publish(player, get(player))
	end)
	for _, player in Players:GetPlayers() do
		publish(player, get(player))
	end
end

return LoadoutService
