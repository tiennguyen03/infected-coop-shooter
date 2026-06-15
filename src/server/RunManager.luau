--!strict
-- Run lifecycle: disables auto-respawn so death ends the run, and rebuilds
-- a fresh run when the client asks to restart from the death screen. Every
-- system with run state exposes a reset for this module to call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AmmoCacheService = require(script.Parent.AmmoCacheService)
local DifficultyService = require(script.Parent.DifficultyService)
local DroneService = require(script.Parent.DroneService)
local EnemyService = require(script.Parent.EnemyService)
local ExtractionService = require(script.Parent.ExtractionService)
local IncendiaryService = require(script.Parent.IncendiaryService)
local ItemEffectService = require(script.Parent.ItemEffectService)
local ItemService = require(script.Parent.ItemService)
local MineService = require(script.Parent.MineService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PauseService = require(script.Parent.PauseService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local ProjectileServer = require(script.Parent.ProjectileServer)
local ShockCoilService = require(script.Parent.ShockCoilService)
local XPOrbService = require(script.Parent.XPOrbService)
local XPService = require(script.Parent.XPService)

local RunManager = {}

-- Public so DevTestService can force a restart regardless of alive state.
function RunManager.resetRun(player: Player)
	PauseService.setPaused(false)
	EnemyService.reset()
	XPOrbService.reset()
	DroneService.reset()
	ProjectileServer.reset()
	AmmoCacheService.reset()
	IncendiaryService.reset()
	MineService.reset()
	ShockCoilService.reset()
	ItemEffectService.resetPlayer(player)
	ItemService.resetPlayer(player)
	XPService.resetPlayer(player)
	PlayerStatsService.resetPlayer(player)
	DifficultyService.restart()
	ObjectiveService.reset()
	ExtractionService.reset()
	player:LoadCharacterAsync()
	print("[RunManager] Run restarted for", player.Name)
end

local function onRestartRequest(player: Player)
	-- Honor restarts when the player is dead OR the run ended in success.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local dead = not character or not humanoid or humanoid.Health <= 0
	local extracted = workspace:GetAttribute("Extracted") == true
	if dead or extracted then
		RunManager.resetRun(player)
	end
end

function RunManager.init()
	-- Death ends the run; respawning only happens through resetRun.
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(function(player)
		player:LoadCharacterAsync()
	end)
	for _, player in Players:GetPlayers() do
		if not player.Character then
			player:LoadCharacterAsync()
		end
	end

	Remotes.get("RestartRun").OnServerEvent:Connect(onRestartRequest)
end

return RunManager
