--!strict
-- Developer-only test tools. Commands run ONLY in Studio or for the creator
-- (gated in handleCommand), never for public players. Drives the existing
-- services so it always tests the real systems, not a parallel copy.
--
-- Invoke from the client DevTestPanel (creator), or directly via the Studio
-- MCP runtime eval, e.g.:
--   require(game.ServerScriptService.Server.DevTestService).spawnEnemy("Brute", 1)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local ItemService = require(script.Parent.ItemService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local RunManager = require(script.Parent.RunManager)
local XPService = require(script.Parent.XPService)

local CREATOR_USER_ID = 67169996
local ENEMY_TAG = "Enemy"

local DevTestService = {}

local function firstPlayer(): Player?
	return Players:GetPlayers()[1]
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function folderCount(name: string): number
	local folder = workspace:FindFirstChild(name)
	return if folder then #folder:GetChildren() else 0
end

-- Accepts the snake_case id ("ricochet_rounds") or a loose alias
-- ("RicochetRounds", "Ricochet Rounds").
local function resolveItemId(input: string): string?
	if ItemDefinitions[input] then
		return input
	end
	local normalized = string.lower((input:gsub("[%s_]", "")))
	for id in ItemDefinitions do
		if string.lower((id:gsub("_", ""))) == normalized then
			return id
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------

function DevTestService.giveXP(amount: number, player: Player?)
	local target = player or firstPlayer()
	if target then
		XPService.addXP(target, amount)
		print(`[DevTest] GiveXP {amount} -> {target.Name}`)
	end
end

function DevTestService.forceLevelUp(player: Player?)
	local target = player or firstPlayer()
	if not target then
		return
	end
	local xp = (target:GetAttribute("XP") :: number?) or 0
	local required = (target:GetAttribute("XPRequired") :: number?) or 100
	XPService.addXP(target, math.max(required - xp, 1))
	print(`[DevTest] ForceLevelUp -> {target.Name}`)
end

function DevTestService.grantItem(itemId: string, stacks: number?, player: Player?)
	local target = player or firstPlayer()
	local resolved = resolveItemId(itemId)
	if not target or not resolved then
		warn(`[DevTest] GrantItem: unknown item '{itemId}'`)
		return
	end
	for _ = 1, stacks or 1 do
		ItemService.addItem(target, resolved)
	end
	print(`[DevTest] GrantItem {resolved} x{stacks or 1} -> {target.Name}`)
end

-- Clears inventory and every active item effect for a live player without
-- restarting the run (stats return to normal).
function DevTestService.clearItems(player: Player?)
	local target = player or firstPlayer()
	if not target then
		return
	end
	ItemService.resetPlayer(target)
	ItemEffectService.resetPlayer(target)
	PlayerStatsService.resetPlayer(target)
	DevTestService.clearItemObjects()

	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.MaxHealth = Config.Player.MaxHealth
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end
	print(`[DevTest] ClearItems -> {target.Name}`)
end

-- Destroys item-spawned world objects (drones, fire pools, mines). Used by
-- ClearItems; each service owns its own reset.
function DevTestService.clearItemObjects()
	require(script.Parent.DroneService).reset()
	require(script.Parent.IncendiaryService).reset()
	require(script.Parent.MineService).reset()
	require(script.Parent.ShockCoilService).reset()
end

function DevTestService.forceObjectiveComplete()
	require(script.Parent.ObjectiveService).forceComplete()
	print("[DevTest] ForceObjectiveComplete (extraction should start)")
end

function DevTestService.forceMissionSuccess()
	require(script.Parent.ExtractionService).forceComplete()
	print("[DevTest] ForceMissionSuccess")
end

function DevTestService.spawnEnemy(enemyType: string, count: number)
	if not EnemyService.spawnWave then
		return
	end
	EnemyService.spawnWave(enemyType, count)
	print(`[DevTest] SpawnEnemy {enemyType} x{count}`)
end

function DevTestService.clearEnemies()
	EnemyService.clearAll()
	print("[DevTest] ClearEnemies")
end

function DevTestService.killPlayer(player: Player?)
	local target = player or firstPlayer()
	local humanoid = target and getHumanoid(target)
	if humanoid then
		humanoid.Health = 0
		print(`[DevTest] KillPlayer -> {(target :: Player).Name}`)
	end
end

function DevTestService.restartRun(player: Player?)
	local target = player or firstPlayer()
	if target then
		RunManager.resetRun(target)
		print(`[DevTest] RestartRun -> {target.Name}`)
	end
end

function DevTestService.printRunState(): { [string]: any }
	local player = firstPlayer()
	local humanoid = player and getHumanoid(player)
	local zone = workspace:FindFirstChild("ObjectiveZone")

	local state = {
		runActive = humanoid ~= nil and humanoid.Health > 0,
		elapsed = math.floor(
			(
				workspace:GetServerTimeNow()
				- (
					(workspace:GetAttribute("RunStartTime") :: number?)
					or workspace:GetServerTimeNow()
				)
			)
		),
		level = player and player:GetAttribute("Level"),
		xp = player and player:GetAttribute("XP"),
		xpNeeded = player and player:GetAttribute("XPRequired"),
		kills = player and player:GetAttribute("Kills"),
		enemyCount = EnemyService.count(),
		walkerCount = EnemyService.count("Walker"),
		runnerCount = EnemyService.count("Runner"),
		bruteCount = EnemyService.count("Brute"),
		droneCount = folderCount("Drones"),
		projectileCount = folderCount("Projectiles"),
		xpOrbCount = folderCount("XPOrbs"),
		ammoCacheCount = folderCount("AmmoCaches"),
		firePoolCount = folderCount("FirePools"),
		mineCount = folderCount("Mines"),
		markedTargets = ItemEffectService.getActiveMarkCount(),
		activeItemCount = player and player:GetAttribute("ItemsCollected") or 0,
		objectiveActive = workspace:GetAttribute("ObjectiveActive") == true,
		objectiveZoneExists = zone ~= nil,
	}

	print("[DevTest] RunState:")
	for key, value in state do
		print(string.format("  %s = %s", tostring(key), tostring(value)))
	end
	return state
end

-- Checks for leftover run objects/effects. Call right after RestartRun
-- (before the new run's first wave spawns ~1.5s later).
function DevTestService.verifyCleanup(): { pass: boolean, leftovers: { string } }
	local leftovers: { string } = {}

	local function check(label: string, n: number)
		if n > 0 then
			table.insert(leftovers, `{n} {label} still exist`)
		end
	end

	check("enemies", #CollectionService:GetTagged(ENEMY_TAG))
	check("drones", folderCount("Drones"))
	check("projectiles", folderCount("Projectiles"))
	check("XP orbs", folderCount("XPOrbs"))
	check("ammo caches", folderCount("AmmoCaches"))
	check("fire pools", folderCount("FirePools"))
	check("mines", folderCount("Mines"))
	check("marked targets", ItemEffectService.getActiveMarkCount())
	if workspace:FindFirstChild("ExtractionZone") then
		table.insert(leftovers, "extraction zone still exists")
	end
	if workspace:FindFirstChild("ObjectiveZone") then
		table.insert(leftovers, "objective zone still exists")
	end
	if workspace:GetAttribute("ExtractionActive") == true then
		table.insert(leftovers, "ExtractionActive still true")
	end
	if workspace:GetAttribute("Extracted") == true then
		table.insert(leftovers, "Extracted still true")
	end
	if workspace:GetAttribute("ObjectiveCompleted") == true then
		table.insert(leftovers, "ObjectiveCompleted still true")
	end

	local player = firstPlayer()
	if player then
		for _, stat in { "Damage", "FireRate", "MoveSpeed" } do
			local mult = (player:GetAttribute(stat .. "Mult") :: number?) or 1
			if math.abs(mult - 1) > 0.001 then
				table.insert(leftovers, `{stat} multiplier still {mult}`)
			end
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.MaxHealth > Config.Player.MaxHealth then
			table.insert(leftovers, `MaxHealth still {humanoid.MaxHealth} (shield leftover)`)
		end
		if (player:GetAttribute("ItemsCollected") :: number?) ~= 0 then
			table.insert(leftovers, "item stacks remain")
		end
	end

	local pass = #leftovers == 0
	if pass then
		print("[DevTest] Cleanup PASS")
	else
		print("[DevTest] Cleanup FAIL:")
		for _, line in leftovers do
			print("  - " .. line)
		end
	end
	return { pass = pass, leftovers = leftovers }
end

----------------------------------------------------------------------
-- Remote dispatch (creator/Studio only)
----------------------------------------------------------------------

local DISPATCH: { [string]: (player: Player, ...any) -> () } = {
	GiveXP = function(player, amount)
		DevTestService.giveXP(tonumber(amount) or 100, player)
	end,
	ForceLevelUp = function(player)
		DevTestService.forceLevelUp(player)
	end,
	GrantItem = function(player, itemId, stacks)
		DevTestService.grantItem(tostring(itemId), tonumber(stacks) or 1, player)
	end,
	ClearItems = function(player)
		DevTestService.clearItems(player)
	end,
	SpawnEnemy = function(_player, enemyType, count)
		DevTestService.spawnEnemy(tostring(enemyType), tonumber(count) or 1)
	end,
	ClearEnemies = function()
		DevTestService.clearEnemies()
	end,
	KillPlayer = function(player)
		DevTestService.killPlayer(player)
	end,
	RestartRun = function(player)
		DevTestService.restartRun(player)
	end,
	PrintRunState = function()
		DevTestService.printRunState()
	end,
	VerifyCleanup = function()
		DevTestService.verifyCleanup()
	end,
	ForceObjectiveComplete = function()
		DevTestService.forceObjectiveComplete()
	end,
	ForceMissionSuccess = function()
		DevTestService.forceMissionSuccess()
	end,
}

local function handleCommand(player: Player, command: unknown, ...: any)
	-- Hard gate: only the creator, and never on a live public server.
	if not (RunService:IsStudio() or player.UserId == CREATOR_USER_ID) then
		return
	end
	if typeof(command) ~= "string" then
		return
	end
	local handler = DISPATCH[command]
	if handler then
		handler(player, ...)
	end
end

function DevTestService.init()
	Remotes.get("DevCommand").OnServerEvent:Connect(handleCommand)
end

return DevTestService
