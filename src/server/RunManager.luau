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
local AmmoCacheService = require(script.Parent.AmmoCacheService)
local AssaultClassService = require(script.Parent.AssaultClassService)
local BotService = require(script.Parent.BotService)
local DifficultyService = require(script.Parent.DifficultyService)
local DroneService = require(script.Parent.DroneService)
local EnemyProjectileService = require(script.Parent.EnemyProjectileService)
local EnemyService = require(script.Parent.EnemyService)
local ExtractionService = require(script.Parent.ExtractionService)
local IncendiaryService = require(script.Parent.IncendiaryService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local ItemService = require(script.Parent.ItemService)
local MineService = require(script.Parent.MineService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PassiveItemService = require(script.Parent.PassiveItemService)
local PauseService = require(script.Parent.PauseService)
local PlagueRatService = require(script.Parent.PlagueRatService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local ProjectileServer = require(script.Parent.ProjectileServer)
local RequisitionService = require(script.Parent.RequisitionService)
local ShockCoilService = require(script.Parent.ShockCoilService)
local XPOrbService = require(script.Parent.XPOrbService)
local XPService = require(script.Parent.XPService)

local RunManager = {}

-- Bumped on every run start so a pending Insert -> Explore timer never fires into a later run.
local runGeneration = 0

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
	setState("Ended", result)
end

local function anyoneAlive(): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return true
		end
	end
	return false
end

local function onDied()
	if RunStates.current() ~= "Ended" and RunStates.current() ~= "Lobby" and not anyoneAlive() then
		RunManager.endRun("Wiped")
	end
end

-- Public so DevTestService can force a restart regardless of alive state.
function RunManager.resetRun(player: Player)
	PauseService.setPaused(false)
	EnemyService.reset()
	EnemyProjectileService.reset()
	XPOrbService.reset()
	DroneService.reset()
	ProjectileServer.reset()
	AmmoCacheService.reset()
	IncendiaryService.reset()
	MineService.reset()
	ShockCoilService.reset()
	PlagueRatService.reset()
	RequisitionService.reset()
	AssaultClassService.resetPlayer(player)
	ItemEffectService.resetPlayer(player)
	ItemService.resetPlayer(player)
	PassiveItemService.resetPlayer(player)
	XPService.resetPlayer(player)
	PlayerStatsService.resetPlayer(player)
	DifficultyService.restart()
	ObjectiveService.reset()
	ExtractionService.reset()
	beginRun()
	player:LoadCharacterAsync()
	print("[RunManager] Run restarted for", player.Name)
end

local function onRestartRequest(player: Player)
	-- Honor restarts when the player is dead OR the run has ended.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local dead = not character or not humanoid or humanoid.Health <= 0
	if dead or RunStates.current() == "Ended" then
		RunManager.resetRun(player)
	end
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
	Players.PlayerRemoving:Connect(function()
		task.defer(onDied)
	end)

	Remotes.get("RestartRun").OnServerEvent:Connect(onRestartRequest)
end

return RunManager
