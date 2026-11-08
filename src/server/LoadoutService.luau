--!strict
-- The loadout (replaced ItemService): per player, the weapon it
-- carries with its magazine and reserve, the two call-in slots (keys 1 and 2), the six
-- field-upgrade slots and the Armour Plate shield. Power comes from here, not from in-run
-- growth (docs/PROGRESSION.md > Loadout, pallets and field upgrades). Server-authoritative:
-- ProjectileServer asks consumeRound before every shot, the Reload remote starts a reload
-- here, pallets re-arm through refillAmmo, RequisitionService hands out cards through
-- giveUpgrade / addShield, and every other service asks hasUpgrade for its flag. State is
-- published as Player attributes (Weapon, Mag, Reserve, ReloadUntil, CallIn1/2,
-- Upgrade<Slot>, Shield) so the HUD reads LocalPlayer only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Magazine = require(ReplicatedStorage.Shared.Rules.Magazine)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)

local LoadoutService = {}

type Loadout = {
	weapon: string,
	callIns: { string }, -- [1], [2]
	upgrades: { [string]: string }, -- slot (UpgradeDefinitions.SLOTS) -> upgrade id
	mag: number,
	reserve: number,
	reloadUntil: number?, -- os.clock; nil when not reloading
	shield: number,
}

local loadouts: { [Player]: Loadout } = {}
local callInChangedListeners: { (player: Player, slot: number) -> () } = {}
local lastStep = 0

local function freshLoadout(): Loadout
	local weapon = WeaponDefinitions.get(WeaponDefinitions.DEFAULT)
	return {
		weapon = weapon.Id,
		callIns = table.clone(CallInDefinitions.DEFAULT),
		upgrades = {},
		mag = weapon.MagazineSize,
		reserve = weapon.ReserveStart,
		reloadUntil = nil,
		shield = 0,
	}
end

local function get(player: Player): Loadout
	local loadout = loadouts[player]
	if not loadout then
		loadout = freshLoadout()
		loadouts[player] = loadout
	end
	return loadout
end

local function publishAmmo(player: Player, loadout: Loadout)
	player:SetAttribute(Attributes.Weapon, loadout.weapon)
	player:SetAttribute(Attributes.Mag, loadout.mag)
	player:SetAttribute(Attributes.Reserve, loadout.reserve)
	local reloadUntil = loadout.reloadUntil
	player:SetAttribute(
		Attributes.ReloadUntil,
		if reloadUntil then workspace:GetServerTimeNow() + (reloadUntil - os.clock()) else 0
	)
end

local function publishLoadout(player: Player, loadout: Loadout)
	player:SetAttribute(Attributes.callIn(1), loadout.callIns[1] or "")
	player:SetAttribute(Attributes.callIn(2), loadout.callIns[2] or "")
	for _, slot in UpgradeDefinitions.SLOTS do
		player:SetAttribute(Attributes.upgrade(slot), loadout.upgrades[slot] or "")
	end
	player:SetAttribute(Attributes.Shield, loadout.shield)
end

local function publish(player: Player, loadout: Loadout)
	publishAmmo(player, loadout)
	publishLoadout(player, loadout)
end

----------------------------------------------------------------------
-- Weapon, magazine, reserve
----------------------------------------------------------------------

function LoadoutService.getWeapon(player: Player): WeaponDefinitions.WeaponDefinition
	return WeaponDefinitions.get(get(player).weapon)
end

-- Swaps the weapon and starts it full (dev panel until the Armory exists).
function LoadoutService.setWeapon(player: Player, weaponId: string): boolean
	if not WeaponDefinitions.exists(weaponId) then
		return false
	end
	local loadout = get(player)
	local weapon = WeaponDefinitions.get(weaponId)
	loadout.weapon = weapon.Id
	loadout.mag = weapon.MagazineSize
	loadout.reserve = weapon.ReserveStart
	loadout.reloadUntil = nil
	publishAmmo(player, loadout)
	return true
end

function LoadoutService.isReloading(player: Player): boolean
	return get(player).reloadUntil ~= nil
end

-- A shot: false when the magazine is empty or a reload is in progress.
function LoadoutService.consumeRound(player: Player): boolean
	local loadout = get(player)
	if not Magazine.canFire(loadout.mag, loadout.reloadUntil ~= nil) then
		return false
	end
	loadout.mag -= 1
	player:SetAttribute(Attributes.Mag, loadout.mag)
	return true
end

local function finishReload(player: Player, loadout: Loadout)
	local weapon = WeaponDefinitions.get(loadout.weapon)
	loadout.mag, loadout.reserve =
		Magazine.reload(loadout.mag, loadout.reserve, weapon.MagazineSize)
	loadout.reloadUntil = nil
	publishAmmo(player, loadout)
end

-- R: starts a reload when the magazine is short and rounds remain. Combat Reload finishes
-- it at once at full Momentum. Returns true when a reload started (or finished).
function LoadoutService.startReload(player: Player): boolean
	local loadout = get(player)
	local weapon = WeaponDefinitions.get(loadout.weapon)
	if
		not Magazine.canReload(
			loadout.mag,
			loadout.reserve,
			weapon.MagazineSize,
			loadout.reloadUntil ~= nil
		)
	then
		return false
	end
	local member = Squad.fromPlayer(player)
	if not member or not Squad.canAct(member) or PauseService.isPaused() then
		return false
	end
	local stacks = (player:GetAttribute(Attributes.MomentumStacks) :: number?) or 0
	if
		LoadoutService.hasUpgrade(player, "combat_reload")
		and stacks >= Config.Upgrades.CombatReload.MomentumStacks
	then
		finishReload(player, loadout)
		return true
	end
	loadout.reloadUntil = os.clock() + weapon.ReloadTime
	publishAmmo(player, loadout)
	return true
end

-- A roll, a slide or going down drops the reload (the rounds stay where they were).
function LoadoutService.cancelReload(player: Player)
	local loadout = loadouts[player]
	if loadout and loadout.reloadUntil then
		loadout.reloadUntil = nil
		publishAmmo(player, loadout)
	end
end

-- A pallet's ammo box: full magazine and reserve.
function LoadoutService.refillAmmo(player: Player)
	local loadout = get(player)
	local weapon = WeaponDefinitions.get(loadout.weapon)
	loadout.mag = weapon.MagazineSize
	loadout.reserve = weapon.ReserveMax
	loadout.reloadUntil = nil
	publishAmmo(player, loadout)
end

----------------------------------------------------------------------
-- Call-in slots
----------------------------------------------------------------------

function LoadoutService.getCallIn(player: Player, slot: number): string?
	return get(player).callIns[slot]
end

-- The slot (1 or 2) carrying `callInId`, or nil.
function LoadoutService.slotOfCallIn(player: Player, callInId: string): number?
	for slot, id in get(player).callIns do
		if id == callInId then
			return slot
		end
	end
	return nil
end

-- CallInService listens: a swapped slot starts with fresh charges.
function LoadoutService.onCallInChanged(listener: (player: Player, slot: number) -> ())
	table.insert(callInChangedListeners, listener)
end

-- Puts `callInId` in slot 1 or 2 (dev panel until the Armory exists). The upgrade riding on
-- the old call-in leaves with it.
function LoadoutService.setCallIn(player: Player, slot: number, callInId: string): boolean
	if (slot ~= 1 and slot ~= 2) or not CallInDefinitions.get(callInId) then
		return false
	end
	local loadout = get(player)
	local other = if slot == 1 then 2 else 1
	if loadout.callIns[other] == callInId then
		-- The same tool in both slots: swap them instead.
		loadout.callIns[other] = loadout.callIns[slot]
		local otherKey = if other == 1 then "CallInA" else "CallInB"
		local slotKey = if slot == 1 then "CallInA" else "CallInB"
		loadout.upgrades[otherKey], loadout.upgrades[slotKey] =
			loadout.upgrades[slotKey], loadout.upgrades[otherKey]
	end
	loadout.callIns[slot] = callInId
	local slotKey = if slot == 1 then "CallInA" else "CallInB"
	local held = UpgradeDefinitions.get(loadout.upgrades[slotKey])
	if held and held.CallIn ~= callInId then
		loadout.upgrades[slotKey] = nil
	end
	publishLoadout(player, loadout)
	for _, listener in callInChangedListeners do
		listener(player, slot)
	end
	if loadout.callIns[other] ~= nil then
		for _, listener in callInChangedListeners do
			listener(player, other)
		end
	end
	return true
end

----------------------------------------------------------------------
-- Field upgrades
----------------------------------------------------------------------

-- The loadout slot an upgrade would fill for this player, or nil when it cannot (a call-in
-- upgrade for a call-in not carried).
local function slotFor(loadout: Loadout, definition: UpgradeDefinitions.CardDefinition): string?
	if definition.Kind ~= "upgrade" then
		return nil
	end
	if definition.Slot ~= "CallIn" then
		return definition.Slot
	end
	for slot, id in loadout.callIns do
		if id == definition.CallIn then
			return if slot == 1 then "CallInA" else "CallInB"
		end
	end
	return nil
end

function LoadoutService.hasUpgrade(player: Player, upgradeId: string): boolean
	local loadout = loadouts[player]
	if not loadout then
		return false
	end
	for _, id in loadout.upgrades do
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
	local loadout = get(player)
	local slot = slotFor(loadout, definition)
	if not slot then
		return false
	end
	loadout.upgrades[slot] = upgradeId
	publishLoadout(player, loadout)
	print(`[Loadout] {player.Name} took {definition.Name} ({slot})`)
	return true
end

function LoadoutService.clearUpgrades(player: Player)
	local loadout = get(player)
	table.clear(loadout.upgrades)
	publishLoadout(player, loadout)
end

-- Upgrades this player could take right now: applies to a slot they have, not already held.
function LoadoutService.availableUpgrades(player: Player): { string }
	local loadout = get(player)
	local ids = {}
	for _, id in UpgradeDefinitions.upgradeIds() do
		local definition = UpgradeDefinitions.get(id) :: UpgradeDefinitions.CardDefinition
		if slotFor(loadout, definition) and not LoadoutService.hasUpgrade(player, id) then
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
	local loadout = get(player)
	loadout.shield = math.min(loadout.shield + amount, Config.Crates.ShieldCap)
	player:SetAttribute(Attributes.Shield, loadout.shield)
end

-- Soaks `amount` of incoming damage on the plate; returns what reaches health.
function LoadoutService.absorb(player: Player, amount: number): number
	local loadout = loadouts[player]
	if not loadout or loadout.shield <= 0 then
		return amount
	end
	local soaked = math.min(loadout.shield, amount)
	loadout.shield -= soaked
	player:SetAttribute(Attributes.Shield, loadout.shield)
	return amount - soaked
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, loadout in loadouts do
			if loadout.reloadUntil then
				loadout.reloadUntil += shift
			end
		end
		lastStep = now
		return
	end
	lastStep = now
	for player, loadout in loadouts do
		local reloadUntil = loadout.reloadUntil
		if reloadUntil and now >= reloadUntil then
			finishReload(player, loadout)
		end
	end
end

-- A fresh loadout for a run start: the default call-ins, no upgrades, full rifle, no plate.
function LoadoutService.resetPlayer(player: Player)
	loadouts[player] = freshLoadout()
	publish(player, loadouts[player])
end

function LoadoutService.init()
	Lifecycle.register("LoadoutService", {
		onPlayerReset = LoadoutService.resetPlayer,
		onPlayerRemoving = function(player: Player)
			loadouts[player] = nil
		end,
	})
	Remotes.get("Reload").OnServerEvent:Connect(function(player: Player)
		LoadoutService.startReload(player)
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
