--!strict
-- Run lifecycle and the run state machine (Co-op Sprint A step 1, Shared.RunStates).
-- RunManager is the only writer of the workspace attributes RunState / RunResult:
--   Lobby -> Insert (squad lands, Config.Run.InsertSeconds) -> Explore (first wave, the
--   objective timer arms) -> Primary (hold zone up) -> Index (boss; passthrough until the
--   Warden) -> Extract -> Ended ("Extracted" on extraction, "Wiped" when nobody is alive).
-- Auto-respawn is off: death ends a player's run; RestartRun (death or results screen)
-- starts a fresh one. Every system with run state exposes a reset for this module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local AirStrikeService = require(script.Parent.AirStrikeService)
local AssaultClassService = require(script.Parent.AssaultClassService)
local BotService = require(script.Parent.BotService)
local CallInService = require(script.Parent.CallInService)
local DifficultyService = require(script.Parent.DifficultyService)
local DroneService = require(script.Parent.DroneService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local EnemyService = require(script.Parent.EnemyService)
local ExtractionService = require(script.Parent.ExtractionService)
local IncendiaryService = require(script.Parent.IncendiaryService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local LoadoutService = require(script.Parent.LoadoutService)
local MineService = require(script.Parent.MineService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local ProjectileServer = require(script.Parent.ProjectileServer)
local RequisitionService = require(script.Parent.RequisitionService)
local ShockCoilService = require(script.Parent.ShockCoilService)
local Squad = require(script.Parent.Squad)

local RunManager = {}

-- Bumped on every run start so a pending Insert -> Explore timer never fires into a later run.
local runGeneration = 0

-- Ready-up after a run ends (decision #4): players who pressed READY, and a generation so
-- a countdown from an earlier result screen never starts a later run.
local ready: { [Player]: boolean } = {}
local readyGeneration = 0

local function publishReady()
	local count = 0
	for _, player in Players:GetPlayers() do
		if ready[player] then
			count += 1
		end
		player:SetAttribute("Ready", ready[player] == true)
	end
	workspace:SetAttribute("ReadyCount", count)
	workspace:SetAttribute("ReadyNeeded", #Players:GetPlayers())
end

local function clearReady()
	table.clear(ready)
	readyGeneration += 1
	workspace:SetAttribute("ReadyUpEndsAt", 0)
	publishReady()
end

local function setState(state: RunStates.RunState, result: RunStates.RunResult?)
	workspace:SetAttribute("RunState", state)
	if result then
		workspace:SetAttribute("RunResult", result)
	end
	print("[RunManager] RunState ->", state, result or "")
end

local function beginRun()
	runGeneration += 1
	local generation = runGeneration
	setState("Insert", "")
	BotService.startRun()
	task.delay(Config.Run.InsertSeconds, function()
		if generation ~= runGeneration or RunStates.current() ~= "Insert" then
			return
		end
		setState("Explore")
		EnemyService.startSortie()
		ObjectiveService.arm()
	end)
end

-- Freezes the field (stops spawns, frees the cursor for the results screen) and clears the
-- horde. The result screens key on RunState == "Ended" and RunResult.
function RunManager.endRun(result: RunStates.RunResult)
	if RunStates.current() == "Ended" then
		return
	end
	runGeneration += 1
	PauseService.setPaused(true)
	EnemyService.clearAll()
	clearReady()
	setState("Ended", result)
end

-- Bots never hold a run open on their own: it is over when no player is Alive or Downed
-- (a downed player can still be revived).
local function anyoneAlive(): boolean
	return #Squad.activeOwners() > 0
end

local function onDied()
	if RunStates.current() ~= "Ended" and RunStates.current() ~= "Lobby" and not anyoneAlive() then
		RunManager.endRun("Wiped")
	end
end

-- One player's run state, back to a fresh start (loadout, call-in charges, class, stats,
-- fire timing).
local function resetPlayer(player: Player)
	AssaultClassService.resetPlayer(player)
	ItemEffectService.resetPlayer(player)
	LoadoutService.resetPlayer(player)
	CallInService.resetPlayer(player)
	PlayerStatsService.resetPlayer(player)
	ProjectileServer.resetPlayer(player)
end

-- A fresh run for the whole squad: every run-level service resets once, then every player
-- is reset and respawned (register #8). Public so DevTestService can force one.
function RunManager.startRun()
	clearReady()
	PauseService.setPaused(false)
	EnemyService.reset()
	EnemyProjectileService.reset()
	DroneService.reset()
	ProjectileServer.reset()
	IncendiaryService.reset()
	MineService.reset()
	ShockCoilService.reset()
	AirStrikeService.reset()
	RequisitionService.reset()
	ItemEffectService.reset()
	AssaultClassService.reset()
	DifficultyService.restart()
	ObjectiveService.reset()
	ExtractionService.reset()
	Squad.resetRun()
	local players = Players:GetPlayers()
	for _, player in players do
		resetPlayer(player)
	end
	beginRun()
	for _, player in players do
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
	print("[RunManager] Run restarted for", #players, "player(s)")
end

local function allReady(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not ready[player] then
			return false
		end
	end
	return true
end

-- READY from the results screen. Only once the run is over (one player dying mid-run never
-- resets it for the squad). The first READY opens Config.Run.ReadyUpSeconds; the next run
-- starts when every player is ready or the countdown runs out.
local function onRestartRequest(player: Player)
	if RunStates.current() ~= "Ended" then
		return
	end
	ready[player] = true
	publishReady()
	if allReady() then
		RunManager.startRun()
		return
	end
	if ((workspace:GetAttribute("ReadyUpEndsAt") :: number?) or 0) > 0 then
		return
	end
	local generation = readyGeneration
	workspace:SetAttribute(
		"ReadyUpEndsAt",
		workspace:GetServerTimeNow() + Config.Run.ReadyUpSeconds
	)
	task.delay(Config.Run.ReadyUpSeconds, function()
		if generation == readyGeneration and RunStates.current() == "Ended" then
			RunManager.startRun()
		end
	end)
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(onDied)
	end
	-- The first body on the field starts the first run.
	if RunStates.current() == "Lobby" then
		beginRun()
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	else
		player:LoadCharacterAsync()
	end
end

function RunManager.init()
	-- Death ends the run; respawning only happens through resetRun.
	Players.CharacterAutoLoads = false
	setState("Lobby", "")

	-- Explore -> Primary when the hold zone appears; Primary -> Index -> Extract when the hold
	-- is done (Index is a passthrough until the Warden); Extract -> Ended on extraction.
	ObjectiveService.onActivated(function()
		if RunStates.current() == "Explore" then
			setState("Primary")
		end
	end)
	ObjectiveService.onComplete(function()
		if RunStates.current() == "Ended" then
			return
		end
		setState("Index")
		setState("Extract")
		ExtractionService.start()
	end)
	ExtractionService.onComplete(function()
		RunManager.endRun("Extracted")
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		task.defer(function()
			onDied()
			-- The one holding out left: everyone still here may already be ready.
			if RunStates.current() == "Ended" then
				publishReady()
				if allReady() then
					RunManager.startRun()
				end
			end
		end)
	end)
	Players.PlayerAdded:Connect(publishReady)
	clearReady()

	Remotes.get("RestartRun").OnServerEvent:Connect(onRestartRequest)
end

return RunManager
