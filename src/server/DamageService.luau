--!strict
-- The one damage entry point every player-owned source routes through
-- (DamageService.dealDamage): the rifle, the breach charge, the bots and every call-in
-- (drones, mines, shells, the coil, fire). It records who last hurt an Infected so the kill
-- is credited (Kills attribute, kill listeners) and reports the hit to the
-- clients (hit marker, sparks, 3D hit sound). The item economy it used to host left with the
-- loadout rework: upgrades are flags on LoadoutService read by the service
-- that owns the tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Plates = require(ReplicatedStorage.Shared.Rules.Plates)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Lifecycle = require(script.Parent.Lifecycle)

local DamageService = {}

local damageRemote: RemoteEvent

-- Credits a kill to the last player who damaged the humanoid; the kind of that last hit is
-- kept for the death report.
local lastDamager: { [Humanoid]: Player } = {}
local lastDamageKind: { [Humanoid]: string } = {}

-- Credited-kill listeners. Fired once
-- per credited kill with the killing player.
local killListeners: { (player: Player) -> () } = {}
function DamageService.addKillListener(listener: (player: Player) -> ())
	table.insert(killListeners, listener)
end

-- Body-hit listeners (GoreService: dismemberment). Fired after every hit that reached the
-- body (plates excluded) with the part struck when known and whether it killed.
export type HitInfo = {
	attacker: Player?,
	humanoid: Humanoid,
	amount: number,
	position: Vector3?,
	kind: string,
	part: Instance?,
	killed: boolean,
}
local hitListeners: { (info: HitInfo) -> () } = {}
function DamageService.addHitListener(listener: (info: HitInfo) -> ())
	table.insert(hitListeners, listener)
end

-- THE damage entry point. `attacker` is nil for a squad bot (BotService): no kill credit, no
-- hit marker. `kind` names the source ("hit", "headshot", "breach", "fire", ...). `part` is
-- the part the round hit when known: an Index plate (PlateHealth attribute, IndexService)
-- takes the hit instead of the body, at GuardFactor while he guards (the Flank plate never).
-- A hit is reported to the player who landed it only (MULTIPLAYER_READINESS #9): their
-- hit marker, spark and hit sound. Squadmates do not receive every round anyone fires; a
-- bot's hit (no attacker) is not reported. Kills still go to everyone (onEnemyKilled).
local function reportHit(attacker: Player?, position: Vector3?, amount: number, kind: string)
	if attacker and position and attacker.Parent then
		damageRemote:FireClient(attacker, position, amount, kind, attacker)
	end
end

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
	local plateHealth = part and part:GetAttribute(Attributes.PlateHealth)
	if part and typeof(plateHealth) == "number" then
		local model = part:FindFirstAncestorOfClass("Model")
		local guard = model and model:GetAttribute(Attributes.GuardFactor)
		local left
		left, amount = Plates.hit(
			plateHealth,
			amount,
			if typeof(guard) == "number" then guard else nil,
			part:GetAttribute(Attributes.Flank) == true
		)
		part:SetAttribute(Attributes.PlateHealth, left)
		if attacker then
			lastDamager[humanoid] = attacker
		end
		reportHit(attacker, position, amount, kind or "plate")
		return
	end
	-- A bot's hit (no attacker) leaves any player's kill credit on the target in place.
	if attacker then
		lastDamager[humanoid] = attacker
	end
	lastDamageKind[humanoid] = kind or "hit"
	humanoid:TakeDamage(amount)
	reportHit(attacker, position, amount, kind or "hit")
	if #hitListeners > 0 then
		local info: HitInfo = {
			attacker = attacker,
			humanoid = humanoid,
			amount = amount,
			position = position,
			kind = kind or "hit",
			part = part,
			killed = humanoid.Health <= 0,
		}
		for _, listener in hitListeners do
			task.spawn(listener, info)
		end
	end
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
	killer:SetAttribute(
		Attributes.Kills,
		((killer:GetAttribute(Attributes.Kills) :: number?) or 0) + 1
	)
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
	player:SetAttribute(Attributes.Kills, 0)
end

function DamageService.init()
	Lifecycle.register("DamageService", {
		onRunStart = DamageService.reset,
		onPlayerReset = DamageService.resetPlayer,
	})
	damageRemote = Remotes.get("DamageDealt")
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(Attributes.Kills, 0)
	end)
end

return DamageService
