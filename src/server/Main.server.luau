--!strict
-- Server bootstrap. Requires each system module and starts it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating remotes first guarantees clients never wait on a system that
-- hasn't initialized yet.
require(ReplicatedStorage.Shared.Remotes)
require(ReplicatedStorage.Shared.MeshAssets).init()

require(ReplicatedStorage.Shared.Animations).init()
require(script.Parent.SkyService).init()
require(script.Parent.ArenaService).init()
require(script.Parent.Squad).init()
require(script.Parent.PauseService).init()
require(script.Parent.WorldSounds).init()
require(script.Parent.DifficultyService).init()
require(script.Parent.PlayerStatsService).init()
require(script.Parent.LoadoutService).init()
require(script.Parent.ItemEffectService).init()
require(script.Parent.PlayerSetup).init()
require(script.Parent.CoverMoveService).init()
require(script.Parent.StanceService).init()
require(script.Parent.ProjectileServer).init()
require(script.Parent.DroneService).init()
require(script.Parent.AirStrikeService).init()
require(script.Parent.IncendiaryService).init()
require(script.Parent.MineService).init()
require(script.Parent.EnemyProjectileService).init()
require(script.Parent.EnemyService).init()
require(script.Parent.ShockCoilService).init()
require(script.Parent.AssaultClassService).init()
require(script.Parent.CallInService).init()
require(script.Parent.RequisitionService).init()
require(script.Parent.ObjectiveService).init()
require(script.Parent.ExtractionService).init()
require(script.Parent.IndexService).init()
require(script.Parent.BotService).init()
require(script.Parent.RunManager).init()
require(script.Parent.DevTestService).init()

print("[Server] All systems initialized")
