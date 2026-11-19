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
local Config = require(ReplicatedStorage.Shared.Config)
local InfectedMoves = require(ReplicatedStorage.Shared.Rules.InfectedMoves)
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

-- A form with an Armour row (Config.InfectedMoves.<form>.Armour, the Brute): a round on the
-- plated front does FrontShare and shows as "plate" (a headshot keeps its marker), one in
-- the back BackMultiplier, the side and the legs full (Rules/InfectedMoves). The face is
-- where the round landed on the struck part, in the body's own frame. Blasts pass no part
-- and are never plated.
local function armoured(
	humanoid: Humanoid,
	part: Instance,
	position: Vector3?,
	amount: number,
	kind: string
): (number, string)
	local moves = Config.InfectedMoves
	local model = humanoid.Parent
	local root = humanoid.RootPart
	if
		not moves.Enabled
		or workspace:GetAttribute(Attributes.DevMovesOff) == true
		or not model
		or not root
		or not part:IsA("BasePart")
	then
		return amount, kind
	end
	local typeName = model:GetAttribute(Attributes.EnemyType)
	local row = if typeof(typeName) == "string" then (moves :: any)[typeName] else nil
	local settings = row and row.Armour
	if not settings or not settings.Enabled then
		return amount, kind
	end
	local rule: InfectedMoves.ArmourSettings = {
		frontShare = settings.FrontShare,
		backMultiplier = settings.BackMultiplier,
		frontDot = settings.FrontDot,
		backDot = settings.BackDot,
	}
	local offset = (position or part.Position) - part.Position
	local face = InfectedMoves.facing(
		offset:Dot(root.CFrame.LookVector),
		offset:Dot(root.CFrame.RightVector),
		rule
	)
	local multiplier = InfectedMoves.armour(face, part.Name, rule)
	if multiplier < 1 and kind ~= "headshot" then
		kind = "plate"
	end
	return amount * multiplier, kind
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
		local share = part:GetAttribute(Attributes.WeakSpot)
		local left, body
		left, amount, body = Plates.hit(
			plateHealth,
			amount,
			if typeof(guard) == "number" then guard else nil,
			part:GetAttribute(Attributes.Flank) == true,
			if typeof(share) == "number" then share else nil
		)
		part:SetAttribute(Attributes.PlateHealth, left)
		if attacker then
			lastDamager[humanoid] = attacker
		end
		-- The weak spot: its share goes through to the body (the boss bar moves).
		if body > 0 then
			lastDamageKind[humanoid] = kind or "plate"
			humanoid:TakeDamage(body)
		end
		reportHit(attacker, position, amount, kind or "plate")
		return
	end
	-- A plated front (the Brute): a round's share by the face it struck.
	if part and (kind == "hit" or kind == "headshot") then
		amount, kind = armoured(humanoid, part, position, amount, kind :: string)
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
