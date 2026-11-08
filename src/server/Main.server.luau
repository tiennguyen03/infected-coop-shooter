--!strict
-- Server bootstrap: starts every system in BOOT order (docs/ARCHITECTURE.md F2). Each
-- init() runs in pcall; the first one that fails is named in the log with the list of
-- systems that did start, and boot stops with an error instead of silently skipping
-- everything after it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating remotes first guarantees clients never wait on a system that hasn't initialized.
require(ReplicatedStorage.Shared.Remotes)

local Shared = ReplicatedStorage.Shared
local Server = script.Parent

-- Order matters: a system starts after the systems it reads at init time.
local BOOT: { ModuleScript } = {
	Shared.MeshAssets,
	Shared.Animations,
	Server.Lifecycle,
	Server.SkyService,
	Server.ArenaService,
	Server.Squad,
	Server.PauseService,
	Server.WorldSounds,
	Server.DifficultyService,
	Server.PlayerStatsService,
	Server.LoadoutService,
	Server.DamageService,
	Server.PlayerSetup,
	Server.CoverMoveService,
	Server.StanceService,
	Server.ProjectileServer,
	Server.DroneService,
	Server.AirStrikeService,
	Server.IncendiaryService,
	Server.MineService,
	Server.EnemyProjectileService,
	Server.EnemyService,
	Server.ShockCoilService,
	Server.AssaultClassService,
	Server.CallInService,
	Server.RequisitionService,
	Server.ObjectiveService,
	Server.ExtractionService,
	Server.IndexService,
	Server.BotService,
	Server.RunManager,
	Server.DevTestService,
}

local started: { string } = {}
for _, module in BOOT do
	local ok, err = pcall(function()
		(require(module) :: any).init()
	end)
	if not ok then
		warn(`[Server] started before the failure: {table.concat(started, ", ")}`)
		error(`[Server] {module.Name}.init() failed, boot stopped: {err}`, 0)
	end
	table.insert(started, module.Name)
end

print(`[Server] All systems initialized ({#started})`)
