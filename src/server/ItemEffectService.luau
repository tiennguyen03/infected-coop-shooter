--!strict
-- Central hub for item effects and the one damage entry point every
-- player-owned source routes through (ItemEffectService.dealDamage), which
-- applies Hunter's Mark, credits the kill, and shows the damage number.
--
-- Items handled here: Hollow Point (bleed on hit), Adrenaline (low-HP buff),
-- Tactical Drone / Air Support (on-kill procs, delegated via setters),
-- Kevlar Plate Carrier (shield on level-up), Vampire Serum (heal on kills),
-- Ricochet Rounds (chain on hit), Hunter's Mark Optics (priority debuff).
-- Incendiary / Mine / Shock live in their own services but route damage and
-- kill credit back through here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemService = require(script.Parent.ItemService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local XPService = require(script.Parent.XPService)

local ENEMY_TAG = "Enemy"
local ADRENALINE_SOURCE = "adrenaline_injector"
local ADRENALINE_CHECK_INTERVAL = 0.2

local ItemEffectService = {}

local damageRemote: RemoteEvent
local droneDeployer: ((player: Player) -> ())? = nil
local airStriker: ((player: Player) -> ())? = nil
local firePoolSpawner: ((player: Player, position: Vector3) -> ())? = nil

-- Credits a kill to the last player who damaged the humanoid; the kind of
-- that last hit lets on-kill effects avoid recursive spawns (e.g. a fire
-- kill must not spawn another fire pool).
local lastDamager: { [Humanoid]: Player } = {}
local lastDamageKind: { [Humanoid]: string } = {}

local adrenalineApplied: { [Player]: number } = {}
local killsTowardStrike: { [Player]: number } = {}
local killsTowardHeal: { [Player]: number } = {}
local kevlarShield: { [Player]: number } = {} -- current shield from Kevlar
local timeSinceAdrenalineCheck = 0

type Mark = {
	humanoid: Humanoid,
	bonus: number,
	expiresAt: number,
	highlight: Highlight,
}
local marks: { [Player]: Mark } = {}
local nextMarkAt: { [Player]: number } = {}

function ItemEffectService.setDroneDeployer(deployer: (player: Player) -> ())
	droneDeployer = deployer
end

function ItemEffectService.setAirStriker(striker: (player: Player) -> ())
	airStriker = striker
end

function ItemEffectService.setFirePoolSpawner(spawner: (player: Player, position: Vector3) -> ())
	firePoolSpawner = spawner
end

-- THE damage entry point. Every player-owned damage source calls this so
-- Hunter's Mark, kill credit, and damage numbers are applied consistently.
function ItemEffectService.dealDamage(
	attacker: Player,
	humanoid: Humanoid,
	amount: number,
	position: Vector3?,
	kind: string?
)
	if humanoid.Health <= 0 then
		return
	end

	local mark = marks[attacker]
	if mark and mark.humanoid == humanoid then
		amount *= 1 + mark.bonus
	end

	lastDamager[humanoid] = attacker
	lastDamageKind[humanoid] = kind or "hit"
	humanoid:TakeDamage(amount)
	if position then
		damageRemote:FireAllClients(position, amount, kind or "hit")
	end
end

-- Back-compat: credit a kill without dealing damage (unused now that all
-- sources route through dealDamage, kept for safety).
function ItemEffectService.recordDamager(player: Player, humanoid: Humanoid)
	lastDamager[humanoid] = player
end

----------------------------------------------------------------------
-- Hollow Point bleed
----------------------------------------------------------------------

type Bleed = {
	expiresAt: number,
	nextTick: number,
	owner: Player,
}
local bleeds: { [Humanoid]: Bleed } = {}

local function applyBleed(humanoid: Humanoid, owner: Player)
	local now = os.clock()
	local existing = bleeds[humanoid]
	if existing then
		existing.expiresAt = now + Config.Items.HollowPoint.BleedDuration
		existing.owner = owner
	else
		bleeds[humanoid] = {
			expiresAt = now + Config.Items.HollowPoint.BleedDuration,
			nextTick = now + 1,
			owner = owner,
		}
	end
end

----------------------------------------------------------------------
-- Ricochet Rounds
----------------------------------------------------------------------

local function nearbyEnemyHumanoids(
	position: Vector3,
	range: number,
	exclude: Humanoid,
	limit: number
): { Humanoid }
	local found: { Humanoid } = {}
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid ~= exclude and humanoid.Health > 0 and root then
				if (root.Position - position).Magnitude <= range then
					table.insert(found, humanoid)
					if #found >= limit then
						break
					end
				end
			end
		end
	end
	return found
end

-- Called by ProjectileServer when a proc-capable projectile hits an enemy.
-- baseDamage already includes the player's damage multiplier.
function ItemEffectService.onProjectileHit(
	shooter: Player,
	humanoid: Humanoid,
	position: Vector3,
	baseDamage: number
)
	local bleedStacks = ItemService.getStacks(shooter, "hollow_point_rounds")
	if bleedStacks > 0 then
		local chance = Config.Items.HollowPoint.BleedChancePerStack * bleedStacks
		if math.random() < chance then
			applyBleed(humanoid, shooter)
		end
	end

	local ricochetStacks = ItemService.getStacks(shooter, "ricochet_rounds")
	if ricochetStacks > 0 then
		local cfg = Config.Items.Ricochet
		local chance = math.min(cfg.ChancePerStack * ricochetStacks, cfg.ChanceCap)
		if math.random() < chance then
			local maxTargets = math.min(1 + math.floor(ricochetStacks / 3), cfg.MaxTargets)
			-- Instant chain (no traveling projectile) so ricochet can never
			-- re-trigger procs or loop.
			local targets = nearbyEnemyHumanoids(position, cfg.Range, humanoid, maxTargets)
			for _, target in targets do
				local root = (target.Parent :: Model):FindFirstChild(
						"HumanoidRootPart"
					) :: BasePart?
				ItemEffectService.dealDamage(
					shooter,
					target,
					baseDamage * cfg.DamageFactor,
					root and root.Position,
					"hit"
				)
			end
		end
	end
end

----------------------------------------------------------------------
-- On kill: Vampire, Drone, Air Support, Incendiary, kill stat
----------------------------------------------------------------------

function ItemEffectService.onEnemyKilled(humanoid: Humanoid)
	local killer = lastDamager[humanoid]
	local killKind = lastDamageKind[humanoid]
	lastDamager[humanoid] = nil
	lastDamageKind[humanoid] = nil
	bleeds[humanoid] = nil

	local deathRoot = humanoid.RootPart
	local deathPosition = deathRoot and deathRoot.Position
	if deathPosition then
		damageRemote:FireAllClients(deathPosition, 0, "death")
	end
	if not killer or not killer.Parent then
		return
	end

	killer:SetAttribute("Kills", ((killer:GetAttribute("Kills") :: number?) or 0) + 1)

	-- Vampire Serum: heal every N credited kills.
	local vampStacks = ItemService.getStacks(killer, "vampire_serum")
	if vampStacks > 0 then
		local count = (killsTowardHeal[killer] or 0) + 1
		if count >= Config.Items.Vampire.KillsPerHeal then
			killsTowardHeal[killer] = 0
			local character = killer.Character
			local hp = character and character:FindFirstChildOfClass("Humanoid")
			if hp and hp.Health > 0 then
				hp.Health = math.min(
					hp.Health + Config.Items.Vampire.HealPerStack * vampStacks,
					hp.MaxHealth
				)
			end
		else
			killsTowardHeal[killer] = count
		end
	end

	-- Tactical Drone Beacon.
	local droneStacks = ItemService.getStacks(killer, "tactical_drone_beacon")
	if droneStacks > 0 and droneDeployer then
		if math.random() < Config.Items.Drone.ProcChancePerStack * droneStacks then
			droneDeployer(killer)
		end
	end

	-- Incendiary Gel: never chains from a fire kill (recursion guard).
	local gelStacks = ItemService.getStacks(killer, "incendiary_gel")
	if gelStacks > 0 and firePoolSpawner and killKind ~= "fire" and deathPosition then
		local chance = math.min(
			Config.Items.Incendiary.ChancePerStack * gelStacks,
			Config.Items.Incendiary.ChanceCap
		)
		if math.random() < chance then
			firePoolSpawner(killer, deathPosition)
		end
	end

	-- Air Support Authorization: every N credited kills.
	local strikeStacks = ItemService.getStacks(killer, "air_support_authorization")
	if strikeStacks > 0 and airStriker then
		local cfg = Config.Items.AirSupport
		local required = math.max(
			cfg.BaseKillRequirement - (strikeStacks - 1) * cfg.ReductionPerStack,
			cfg.MinKillRequirement
		)
		local count = (killsTowardStrike[killer] or 0) + 1
		if count >= required then
			killsTowardStrike[killer] = 0
			airStriker(killer)
		else
			killsTowardStrike[killer] = count
		end
	end
end

----------------------------------------------------------------------
-- Kevlar Plate Carrier (level-up shield)
----------------------------------------------------------------------

local function onLevelUp(player: Player, _newLevel: number)
	local stacks = ItemService.getStacks(player, "kevlar_plate_carrier")
	if stacks == 0 then
		return
	end
	local cfg = Config.Items.Kevlar
	local current = kevlarShield[player] or 0
	local grant = math.min(stacks * cfg.ShieldPerStack, cfg.ShieldCap - current)
	if grant <= 0 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.MaxHealth += grant
	humanoid.Health += grant
	kevlarShield[player] = current + grant

	task.delay(cfg.Duration, function()
		if humanoid.Parent and (kevlarShield[player] or 0) >= grant then
			humanoid.MaxHealth = math.max(humanoid.MaxHealth - grant, 1)
			humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
			kevlarShield[player] = (kevlarShield[player] or grant) - grant
		end
	end)
end

----------------------------------------------------------------------
-- Hunter's Mark Optics
----------------------------------------------------------------------

local function highestHealthEnemy(position: Vector3, range: number): Humanoid?
	local best: Humanoid? = nil
	local bestHealth = 0
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				if
					(root.Position - position).Magnitude <= range
					and humanoid.Health > bestHealth
				then
					bestHealth = humanoid.Health
					best = humanoid
				end
			end
		end
	end
	return best
end

local function clearMark(player: Player)
	local mark = marks[player]
	if mark then
		mark.highlight:Destroy()
		marks[player] = nil
	end
end

local function stepHunterMark(now: number)
	for _, player in Players:GetPlayers() do
		local stacks = ItemService.getStacks(player, "hunters_mark_optics")
		local mark: Mark? = marks[player]
		if
			mark
			and (now >= mark.expiresAt or mark.humanoid.Health <= 0 or not mark.humanoid.Parent)
		then
			clearMark(player)
			mark = nil
		end
		if stacks == 0 then
			continue
		end
		if not mark and now >= (nextMarkAt[player] or 0) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local cfg = Config.Items.HunterMark
				local target = highestHealthEnemy(root.Position, cfg.Range)
				nextMarkAt[player] = now + cfg.Interval
				if target then
					local highlight = Instance.new("Highlight")
					highlight.FillColor = Color3.fromRGB(220, 40, 40)
					highlight.FillTransparency = 0.55
					highlight.OutlineColor = Color3.fromRGB(255, 80, 80)
					highlight.Parent = target.Parent
					marks[player] = {
						humanoid = target,
						bonus = math.min(cfg.BonusPerStack * stacks, cfg.BonusCap),
						expiresAt = now + cfg.Duration,
						highlight = highlight,
					}
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Adrenaline (low-HP stat buff)
----------------------------------------------------------------------

local function stepAdrenaline()
	for _, player in Players:GetPlayers() do
		local stacks = ItemService.getStacks(player, ADRENALINE_SOURCE)
		local effectiveStacks = 0
		if stacks > 0 then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				humanoid
				and humanoid.Health > 0
				and humanoid.Health / humanoid.MaxHealth
					< Config.Items.Adrenaline.HealthFraction
			then
				effectiveStacks = stacks
			end
		end

		if (adrenalineApplied[player] or 0) ~= effectiveStacks then
			adrenalineApplied[player] = effectiveStacks
			PlayerStatsService.setBonus(player, ADRENALINE_SOURCE, {
				MoveSpeed = Config.Items.Adrenaline.MoveSpeedPerStack * effectiveStacks,
				FireRate = Config.Items.Adrenaline.FireRatePerStack * effectiveStacks,
			})
		end
	end
end

local function onHeartbeat(deltaTime: number)
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()

	timeSinceAdrenalineCheck += deltaTime
	if timeSinceAdrenalineCheck >= ADRENALINE_CHECK_INTERVAL then
		timeSinceAdrenalineCheck = 0
		stepAdrenaline()
	end

	stepHunterMark(now)

	for humanoid, bleed in bleeds do
		if humanoid.Health <= 0 or not humanoid.Parent or now >= bleed.expiresAt then
			bleeds[humanoid] = nil
		elseif now >= bleed.nextTick then
			bleed.nextTick += 1
			local root = humanoid.RootPart
			ItemEffectService.dealDamage(
				bleed.owner,
				humanoid,
				Config.Items.HollowPoint.BleedTickDamage,
				root and root.Position,
				"bleed"
			)
		end
	end
end

-- Number of players currently holding a Hunter's Mark target (dev tools).
function ItemEffectService.getActiveMarkCount(): number
	local count = 0
	for _ in marks do
		count += 1
	end
	return count
end

function ItemEffectService.resetPlayer(player: Player)
	table.clear(bleeds)
	table.clear(lastDamager)
	table.clear(lastDamageKind)
	adrenalineApplied[player] = nil
	killsTowardStrike[player] = nil
	killsTowardHeal[player] = nil
	kevlarShield[player] = nil
	nextMarkAt[player] = nil
	clearMark(player)
	player:SetAttribute("Kills", 0)
end

function ItemEffectService.init()
	damageRemote = Remotes.get("DamageDealt")
	XPService.addLevelUpListener(onLevelUp)
	RunService.Heartbeat:Connect(onHeartbeat)

	Players.PlayerRemoving:Connect(function(player)
		adrenalineApplied[player] = nil
		killsTowardStrike[player] = nil
		killsTowardHeal[player] = nil
		kevlarShield[player] = nil
		nextMarkAt[player] = nil
		clearMark(player)
	end)
end

return ItemEffectService
