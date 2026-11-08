--!strict
-- The one damage entry point every player-owned source routes through
-- (DamageService.dealDamage): the rifle, the breach charge, the bots and every call-in
-- (drones, mines, shells, the coil, fire). It records who last hurt an Infected so the kill
-- is credited (Kills attribute, kill listeners: Combat Momentum) and reports the hit to the
-- clients (hit marker, sparks, 3D hit sound). Field upgrades are flags on LoadoutService,
-- read by the service that owns the tool, not here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DamageService = {}

local damageRemote: RemoteEvent

-- Credits a kill to the last player who damaged the humanoid; the kind of that last hit is
-- kept for the death report.
local lastDamager: { [Humanoid]: Player } = {}
local lastDamageKind: { [Humanoid]: string } = {}

-- Credited-kill listeners (AssaultClassService uses this for Combat Momentum). Fired once
-- per credited kill with the killing player.
local killListeners: { (player: Player) -> () } = {}
function DamageService.addKillListener(listener: (player: Player) -> ())
	table.insert(killListeners, listener)
end

-- THE damage entry point. `attacker` is nil for a squad bot (BotService): no kill credit, no
-- hit marker. `kind` names the source ("hit", "headshot", "breach", "fire", ...). `part` is
-- the part the round hit when known: an Index plate (PlateHealth attribute, IndexService)
-- takes the hit instead of the body, at GuardFactor while he guards (the Flank plate never).
function DamageService.dealDamage(
	attacker: Player?,
	humanoid: Humanoid,
	amount: number,
	position: Vector3?,
	kind: string?,
	part: Instance?
)
	if humanoid.Health <= 0 then
		return
	end
	local plateHealth = part and part:GetAttribute("PlateHealth")
	if part and typeof(plateHealth) == "number" then
		local model = part:FindFirstAncestorOfClass("Model")
		local guard = model and model:GetAttribute("GuardFactor")
		if typeof(guard) == "number" and part:GetAttribute("Flank") ~= true then
			amount *= guard
		end
		part:SetAttribute("PlateHealth", math.max(0, plateHealth - amount))
		if attacker then
			lastDamager[humanoid] = attacker
		end
		if position then
			damageRemote:FireAllClients(position, amount, kind or "plate", attacker)
		end
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
function DamageService.recordDamager(player: Player, humanoid: Humanoid)
	lastDamager[humanoid] = player
end

-- EnemyService, on every death: the kill stat and the kill listeners for the credited player.
function DamageService.onEnemyKilled(humanoid: Humanoid)
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
function DamageService.reset()
	table.clear(lastDamager)
	table.clear(lastDamageKind)
end

-- One player's stats; RunManager calls it for every player on a run start.
function DamageService.resetPlayer(player: Player)
	player:SetAttribute("Kills", 0)
end

function DamageService.init()
	damageRemote = Remotes.get("DamageDealt")
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Kills", 0)
	end)
end

return DamageService
