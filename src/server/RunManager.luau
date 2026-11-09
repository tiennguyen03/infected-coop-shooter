--!strict
-- Run lifecycle and the run state machine (Co-op Sprint A step 1, Shared.RunStates).
-- RunManager is the only writer of the workspace attributes RunState / RunResult:
--   Lobby -> Insert (squad lands, Config.Run.InsertSeconds) -> Explore (first wave, the
--   objective timer arms) -> Primary (hold zone up) -> Index (boss; passthrough until the
--   Warden) -> Extract -> Ended ("Extracted" on extraction, "Wiped" when nobody is alive).
-- Auto-respawn is off: death ends a player's run; RestartRun (death or results screen)
-- starts a fresh one. Every system with run state registers its reset with Lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local BotService = require(script.Parent.BotService)
local EnemyService = require(script.Parent.EnemyService)
local ExtractionService = require(script.Parent.ExtractionService)
local IndexService = require(script.Parent.IndexService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)

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
		player:SetAttribute(Attributes.Ready, ready[player] == true)
	end
	workspace:SetAttribute(Attributes.ReadyCount, count)
	workspace:SetAttribute(Attributes.ReadyNeeded, #Players:GetPlayers())
end

local function clearReady()
	table.clear(ready)
	readyGeneration += 1
	workspace:SetAttribute(Attributes.ReadyUpEndsAt, 0)
	publishReady()
end

local function setState(state: RunStates.RunState, result: RunStates.RunResult?)
	workspace:SetAttribute(Attributes.RunState, state)
	if result then
		workspace:SetAttribute(Attributes.RunResult, result)
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
		EnemyService.startMission()
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

-- A fresh run for the whole squad: every registered onRunStart hook runs once, then every
-- player's onPlayerReset hooks, then everyone respawns (register #8). Public so DevTestService can force one.
function RunManager.startRun()
	clearReady()
	-- Every service resets its own run and player state through its registered hooks
	-- (Lifecycle, docs/ARCHITECTURE.md F2); nothing here names a service.
	Lifecycle.runStart()
	local players = Players:GetPlayers()
	for _, player in players do
		Lifecycle.playerReset(player)
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
	if ((workspace:GetAttribute(Attributes.ReadyUpEndsAt) :: number?) or 0) > 0 then
		return
	end
	local generation = readyGeneration
	workspace:SetAttribute(
		Attributes.ReadyUpEndsAt,
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
	Lifecycle.register("RunManager", {
		onPlayerRemoving = function(player: Player)
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
		end,
	})
	-- Death ends the run; respawning only happens through resetRun.
	Players.CharacterAutoLoads = false
	setState("Lobby", "")

	-- Explore -> Primary when the hold zone appears; Primary -> Index when the hold is done
	-- (the Warden comes through the Gate; IndexService); Index -> Extract when he dies (or at
	-- once if no boss could spawn); Extract -> Ended on extraction.
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
		if not IndexService.start() then
			setState("Extract")
			ExtractionService.start()
		end
	end)
	IndexService.onDefeated(function()
		if RunStates.current() ~= "Index" then
			return
		end
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
	Players.PlayerAdded:Connect(publishReady)
	clearReady()

	Remotes.get("RestartRun").OnServerEvent:Connect(onRestartRequest)
end

return RunManager
