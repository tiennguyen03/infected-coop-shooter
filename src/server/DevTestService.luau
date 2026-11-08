--!strict
-- Developer-only test tools. Commands run ONLY in Studio or for the creator
-- (gated in handleCommand), never for public players. Drives the existing
-- services so it always tests the real systems, not a parallel copy.
--
-- Invoke from the client DevTestPanel (creator), or directly via the Studio
-- MCP runtime eval, e.g.:
--   require(game.ServerScriptService.Server.DevTestService).spawnEnemy("Brute", 1)
-- Loadout rework: SetCallIn / GiveUpgrade / ClearUpgrades / RefillAmmo /
-- RestockCallIns / SetWeapon / DropUpgradeCrate / DropSupplyCrate drive LoadoutService,
-- CallInService and RequisitionService directly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local CallInService = require(script.Parent.CallInService)
local EnemyService = require(script.Parent.EnemyService)
local IndexService = require(script.Parent.IndexService)
local LoadoutService = require(script.Parent.LoadoutService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local RequisitionService = require(script.Parent.RequisitionService)
local RunManager = require(script.Parent.RunManager)
local DifficultyService = require(script.Parent.DifficultyService)
local PauseService = require(script.Parent.PauseService)

local CREATOR_USER_ID = 67169996
local ENEMY_TAG = "Enemy"

local DevTestService = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function folderCount(name: string): number
	local folder = workspace:FindFirstChild(name)
	return if folder then #folder:GetChildren() else 0
end

-- Accepts a snake_case id ("hollow_point") or a loose alias ("HollowPoint", "Hollow Point").
local function resolveId(rows: { [string]: any }, input: string): string?
	if rows[input] then
		return input
	end
	local normalized = string.lower((input:gsub("[%s_]", "")))
	for id in rows do
		if string.lower((id:gsub("_", ""))) == normalized then
			return id
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------

function DevTestService.setCallIn(player: Player, slot: number, callInId: string)
	local resolved = resolveId(CallInDefinitions.Rows, callInId)
	if not resolved or not LoadoutService.setCallIn(player, slot, resolved) then
		warn(`[DevTest] SetCallIn: unknown call-in '{callInId}' or slot {slot}`)
		return
	end
	print(`[DevTest] SetCallIn {slot} = {resolved} -> {player.Name}`)
end

function DevTestService.giveUpgrade(player: Player, upgradeId: string)
	local resolved = resolveId(UpgradeDefinitions.Rows, upgradeId)
	if not resolved or not LoadoutService.giveUpgrade(player, resolved) then
		warn(`[DevTest] GiveUpgrade: '{upgradeId}' unknown or not applicable to this loadout`)
		return
	end
	print(`[DevTest] GiveUpgrade {resolved} -> {player.Name}`)
end

-- Clears every field upgrade and the stat bonuses for a live player without restarting.
function DevTestService.clearUpgrades(player: Player)
	LoadoutService.clearUpgrades(player)
	PlayerStatsService.resetPlayer(player)
	DevTestService.clearCallInObjects()
	print(`[DevTest] ClearUpgrades -> {player.Name}`)
end

-- Destroys call-in world objects (drones, fire pools, mines, strike markers).
function DevTestService.clearCallInObjects()
	require(script.Parent.DroneService).reset()
	require(script.Parent.IncendiaryService).reset()
	require(script.Parent.MineService).reset()
	require(script.Parent.ShockCoilService).reset()
	require(script.Parent.AirStrikeService).reset()
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

function DevTestService.killPlayer(player: Player)
	local target: Player? = player
	local humanoid = target and getHumanoid(target)
	if humanoid then
		humanoid.Health = 0
		print(`[DevTest] KillPlayer -> {(target :: Player).Name}`)
	end
end

function DevTestService.restartRun(player: Player)
	local target: Player? = player
	if target then
		RunManager.startRun()
		print(`[DevTest] RestartRun -> {target.Name}`)
	end
end

-- Drops a crate of `kind` in front of the player (quiet: no wave).
function DevTestService.dropCrate(player: Player, kind: "supply" | "upgrade")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local at = root.Position + flat * 12
	task.spawn(RequisitionService.dropCrate, at, -flat, kind, false)
	print(`[DevTest] Drop {kind} crate -> {player.Name}`)
end

function DevTestService.printRunState(): { [string]: any }
	local zone = workspace:FindFirstChild("ObjectiveZone")

	local state: { [string]: any } = {
		runState = workspace:GetAttribute(Attributes.RunState),
		runResult = workspace:GetAttribute(Attributes.RunResult),
		elapsed = math.floor(
			(
				workspace:GetServerTimeNow()
				- (
					(workspace:GetAttribute(Attributes.RunStartTime) :: number?)
					or workspace:GetServerTimeNow()
				)
			)
		),
		threatClock = math.floor(DifficultyService.getElapsed()), -- unpaused seconds
		spawnInterval = math.floor(DifficultyService.getSpawnInterval() * 100) / 100,
		enemyCount = EnemyService.count(),
		walkerCount = EnemyService.count("Walker"),
		runnerCount = EnemyService.count("Runner"),
		bruteCount = EnemyService.count("Brute"),
		hockerCount = EnemyService.count("Hocker"),
		droneCount = folderCount("Drones"),
		projectileCount = folderCount("Projectiles"),
		firePoolCount = folderCount("FirePools"),
		mineCount = folderCount("Mines"),
		strikeEffectCount = folderCount("StrikeEffects"),
		resupplyPool = workspace:GetAttribute(Attributes.ResupplyPool),
		resupplyCost = workspace:GetAttribute(Attributes.ResupplyCost),
		objectiveActive = workspace:GetAttribute(Attributes.ObjectiveActive) == true,
		objectiveZoneExists = zone ~= nil,
	}

	print("[DevTest] RunState:")
	for key, value in state do
		print(string.format("  %s = %s", tostring(key), tostring(value)))
	end
	-- Every squad member (players and bots), then each player's own loadout.
	local Squad = require(script.Parent.Squad)
	for _, member in Squad.members() do
		print(
			string.format(
				"  member %s (%s) %s, revives used %d",
				member.name,
				member.kind,
				member.state,
				member.revivesUsed
			)
		)
	end
	for _, player in Players:GetPlayers() do
		local upgrades = {}
		for _, slot in UpgradeDefinitions.SLOTS do
			local id = player:GetAttribute(Attributes.upgrade(slot))
			if typeof(id) == "string" and id ~= "" then
				table.insert(upgrades, `{slot}={id}`)
			end
		end
		print(
			string.format(
				"  player %s: %s mag %s/%s, kills %s, shield %s, call-ins %s(%s) %s(%s), upgrades [%s]",
				player.Name,
				tostring(player:GetAttribute(Attributes.Weapon)),
				tostring(player:GetAttribute(Attributes.Mag)),
				tostring(player:GetAttribute(Attributes.Reserve)),
				tostring(player:GetAttribute(Attributes.Kills)),
				tostring(player:GetAttribute(Attributes.Shield)),
				tostring(player:GetAttribute(Attributes.callIn(1))),
				tostring(player:GetAttribute(Attributes.callInCharges(1))),
				tostring(player:GetAttribute(Attributes.callIn(2))),
				tostring(player:GetAttribute(Attributes.callInCharges(2))),
				table.concat(upgrades, ", ")
			)
		)
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
	check("fire pools", folderCount("FirePools"))
	check("mines", folderCount("Mines"))
	check("strike effects", folderCount("StrikeEffects"))
	check("call-in effects", folderCount("CallInEffects"))
	check("resupply objects", folderCount("Resupply"))
	if workspace:FindFirstChild("ExtractionZone") then
		table.insert(leftovers, "extraction zone still exists")
	end
	if workspace:FindFirstChild("ObjectiveZone") then
		table.insert(leftovers, "objective zone still exists")
	end
	if workspace:GetAttribute(Attributes.ExtractionActive) == true then
		table.insert(leftovers, "ExtractionActive still true")
	end
	if workspace:GetAttribute(Attributes.RunState) == "Ended" then
		table.insert(leftovers, "RunState still Ended")
	end
	if workspace:GetAttribute(Attributes.ObjectiveCompleted) == true then
		table.insert(leftovers, "ObjectiveCompleted still true")
	end

	for _, player in Players:GetPlayers() do
		for _, stat in { "MoveSpeed" } do
			local mult = (player:GetAttribute(Attributes.statMult(stat)) :: number?) or 1
			if math.abs(mult - 1) > 0.001 then
				table.insert(leftovers, `{player.Name}: {stat} multiplier still {mult}`)
			end
		end
		local weapon = LoadoutService.getWeapon(player)
		if (player:GetAttribute(Attributes.Mag) :: number?) ~= weapon.MagazineSize then
			table.insert(leftovers, `{player.Name}: magazine not full`)
		end
		if ((player:GetAttribute(Attributes.Shield) :: number?) or 0) ~= 0 then
			table.insert(leftovers, `{player.Name}: shield remains`)
		end
		for _, slot in UpgradeDefinitions.SLOTS do
			local id = player:GetAttribute(Attributes.upgrade(slot))
			if typeof(id) == "string" and id ~= "" then
				table.insert(leftovers, `{player.Name}: upgrade {id} remains in {slot}`)
			end
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
	-- Loadout rework.
	SetCallIn = function(player, slot, callInId)
		DevTestService.setCallIn(player, tonumber(slot) or 1, tostring(callInId))
	end,
	GiveUpgrade = function(player, upgradeId)
		DevTestService.giveUpgrade(player, tostring(upgradeId))
	end,
	ClearUpgrades = function(player)
		DevTestService.clearUpgrades(player)
	end,
	RefillAmmo = function(player)
		LoadoutService.refillAmmo(player)
		print(`[DevTest] RefillAmmo -> {player.Name}`)
	end,
	RestockCallIns = function(player)
		CallInService.refill(player)
		print(`[DevTest] RestockCallIns -> {player.Name}`)
	end,
	SetWeapon = function(player, weaponId)
		local id = tostring(weaponId)
		if LoadoutService.setWeapon(player, id) then
			print(`[DevTest] SetWeapon {id} -> {player.Name}`)
		else
			local known = table.clone(WeaponDefinitions.PRIMARIES)
			table.move(
				WeaponDefinitions.SECONDARIES,
				1,
				#WeaponDefinitions.SECONDARIES,
				#known + 1,
				known
			)
			warn(`[DevTest] SetWeapon: unknown weapon '{id}' (have: {table.concat(known, ", ")})`)
		end
	end,
	DropUpgradeCrate = function(player)
		DevTestService.dropCrate(player, "upgrade")
	end,
	DropSupplyCrate = function(player)
		DevTestService.dropCrate(player, "supply")
	end,
	SpawnEnemy = function(_player, enemyType, count)
		DevTestService.spawnEnemy(tostring(enemyType), tonumber(count) or 1)
	end,
	ClearEnemies = function()
		DevTestService.clearEnemies()
	end,
	-- Ends the Warden fight at once (his body to 0): the run moves on to extraction.
	KillWarden = function()
		for _, model in CollectionService:GetTagged("Enemy") do
			if model:GetAttribute(Attributes.EnemyType) == "Warden" then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
		print("[DevTest] KillWarden")
	end,
	-- The Index: the full entrance from the Gate, or the Warden in front of you (no walk).
	SpawnWarden = function()
		print("[DevTest] SpawnWarden (the Gate) ->", IndexService.start())
	end,
	WardenHere = function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
			print("[DevTest] WardenHere ->", IndexService.spawnAt(root.Position + forward * 24))
		end
	end,
	KillPlayer = function(player)
		DevTestService.killPlayer(player)
	end,
	-- Downs the caller (or the named bot) as if from a lethal hit.
	DownPlayer = function(player, botName)
		local Squad = require(script.Parent.Squad)
		for _, member in Squad.members() do
			if (botName and member.name == botName) or (not botName and member.owner == player) then
				Squad.down(member)
				print(`[DevTest] DownPlayer -> {member.name}`)
			end
		end
	end,
	RevivePlayer = function(player, botName)
		local Squad = require(script.Parent.Squad)
		for _, member in Squad.members() do
			if (botName and member.name == botName) or (not botName and member.owner == player) then
				Squad.revive(member, nil)
			end
		end
	end,
	RestartRun = function(player)
		DevTestService.restartRun(player)
	end,
	-- Freezes / unfreezes the field (the threat clock, cooldowns and timers stop).
	TogglePause = function()
		PauseService.setPaused(not PauseService.isPaused())
		print(`[DevTest] Paused -> {PauseService.isPaused()}`)
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
	FillResupply = function()
		local cost = (workspace:GetAttribute(Attributes.ResupplyCost) :: number?) or 0
		RequisitionService.addRequisition(math.max(cost - RequisitionService.getPool(), 0))
		print("[DevTest] FillResupply -> pool covers the next flare")
	end,
	-- Dev tools v2. Toggles answer with the new state in the output.
	God = function(player)
		local on = player:GetAttribute(Attributes.DevGod) ~= true
		player:SetAttribute(Attributes.DevGod, on)
		print(`[DevTest] God {if on then "ON" else "OFF"} -> {player.Name}`)
	end,
	Heal = function(player)
		local Squad = require(script.Parent.Squad)
		local member = Squad.fromPlayer(player)
		if member and member.state == "Downed" then
			Squad.revive(member, nil)
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	ToggleSpawns = function()
		local off = workspace:GetAttribute(Attributes.DevSpawnsOff) ~= true
		workspace:SetAttribute(Attributes.DevSpawnsOff, off)
		print(`[DevTest] Infected spawning {if off then "OFF" else "ON"}`)
	end,
	ActivateObjective = function()
		require(script.Parent.ObjectiveService).activateNow()
		print("[DevTest] ActivateObjective")
	end,
	ForceWipe = function()
		require(script.Parent.RunManager).endRun("Wiped")
		print("[DevTest] ForceWipe")
	end,
	DownBot = function()
		local Squad = require(script.Parent.Squad)
		for _, member in Squad.living() do
			if member.kind == "bot" then
				Squad.down(member)
				print(`[DevTest] DownBot -> {member.name}`)
				return
			end
		end
	end,
	KillBots = function()
		local Squad = require(script.Parent.Squad)
		for _, member in Squad.members() do
			if member.kind == "bot" then
				Squad.kill(member)
			end
		end
	end,
	SetBots = function(_player, count)
		require(script.Parent.BotService).setCount(tonumber(count) or 3)
		print(`[DevTest] SetBots -> {tostring(count)}`)
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
