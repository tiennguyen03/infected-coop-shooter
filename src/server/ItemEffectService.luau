--!strict
-- The one damage entry point every player-owned source routes through
-- (ItemEffectService.dealDamage): the rifle, the breach charge, the bots and every call-in
-- (drones, mines, shells, the coil, fire). It records who last hurt an Infected so the kill
-- is credited (Kills attribute, kill listeners: Combat Momentum) and reports the hit to the
-- clients (hit marker, sparks, 3D hit sound). The item economy it used to host left with the
-- loadout rework (2026-11-07): upgrades are flags on LoadoutService read by the service
-- that owns the tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ItemEffectService = {}

local damageRemote: RemoteEvent

-- Credits a kill to the last player who damaged the humanoid; the kind of that last hit is
-- kept for the death report.
local lastDamager: { [Humanoid]: Player } = {}
local lastDamageKind: { [Humanoid]: string } = {}

-- Credited-kill listeners (AssaultClassService uses this for Combat Momentum). Fired once
-- per credited kill with the killing player.
local killListeners: { (player: Player) -> () } = {}
function ItemEffectService.addKillListener(listener: (player: Player) -> ())
	table.insert(killListeners, listener)
end

-- THE damage entry point. `attacker` is nil for a squad bot (BotService): no kill credit, no
-- hit marker. `kind` names the source ("hit", "headshot", "breach", "fire", ...).
function ItemEffectService.dealDamage(
	attacker: Player?,
	humanoid: Humanoid,
	amount: number,
	position: Vector3?,
	kind: string?
)
	if humanoid.Health <= 0 then
		return
	end
	-- A bot's hit (no attacker) leaves any player's kill credit on the target in place.
	if attacker then
		lastDamager[humanoid] = attacker
	end
	lastDamageKind[humanoid] = kind or "hit"
	humanoid:TakeDamage(amount)
	if position then
		damageRemote:FireAllClients(position, amount, kind or "hit", attacker)
	end
end

-- Credit a kill without dealing damage (kept for sources that bypass TakeDamage).
function ItemEffectService.recordDamager(player: Player, humanoid: Humanoid)
	lastDamager[humanoid] = player
end

-- EnemyService, on every death: the kill stat and the kill listeners for the credited player.
function ItemEffectService.onEnemyKilled(humanoid: Humanoid)
	local killer = lastDamager[humanoid]
	lastDamager[humanoid] = nil
	lastDamageKind[humanoid] = nil

	local deathRoot = humanoid.RootPart
	local deathPosition = deathRoot and deathRoot.Position
	if deathPosition then
		damageRemote:FireAllClients(deathPosition, 0, "death", killer)
	end
	if not killer or not killer.Parent then
		return
	end
	killer:SetAttribute("Kills", ((killer:GetAttribute("Kills") :: number?) or 0) + 1)
	for _, listener in killListeners do
		listener(killer)
	end
end

-- Run state keyed by Infected (kill credit): once per run start.
function ItemEffectService.reset()
	table.clear(lastDamager)
	table.clear(lastDamageKind)
end

-- One player's stats; RunManager calls it for every player on a run start.
function ItemEffectService.resetPlayer(player: Player)
	player:SetAttribute("Kills", 0)
end

function ItemEffectService.init()
	damageRemote = Remotes.get("DamageDealt")
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Kills", 0)
	end)
end

return ItemEffectService
