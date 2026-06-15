--!strict
-- Server bootstrap. Requires each system module and starts it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating remotes first guarantees clients never wait on a system that
-- hasn't initialized yet.
require(ReplicatedStorage.Shared.Remotes)

require(script.Parent.PauseService).init()
require(script.Parent.DifficultyService).init()
require(script.Parent.PlayerStatsService).init()
require(script.Parent.XPService).init()
require(script.Parent.XPOrbService).init()
require(script.Parent.ItemService).init()
require(script.Parent.ItemEffectService).init()
require(script.Parent.PlayerSetup).init()
require(script.Parent.ProjectileServer).init()
require(script.Parent.DroneService).init()
require(script.Parent.AmmoCacheService).init()
require(script.Parent.AirStrikeService).init()
require(script.Parent.IncendiaryService).init()
require(script.Parent.MineService).init()
require(script.Parent.ShockCoilService).init()
require(script.Parent.EnemyService).init()
require(script.Parent.ObjectiveService).init()
require(script.Parent.ExtractionService).init()
require(script.Parent.RunManager).init()
require(script.Parent.DevTestService).init()

print("[Server] All systems initialized")
