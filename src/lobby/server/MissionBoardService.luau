--!strict
-- The map room's Mission Board (loop sprint 1; docs/PROGRESSION.md > Missions): a soldier
-- picks a mission card at the watch officer's table (MissionBoardUI) and presses DEPLOY. The
-- server checks the pick (a catalog row, open now, not already lifting, not pressed again
-- inside Config.Lobby.MissionBoard.DeployCooldown) and flies that soldier, alone with bots,
-- into it through LaunchService.send. Loop sprint 2 replaces "alone" with the soldier's party.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local MissionCatalog = require(ReplicatedStorage.Shared.MissionCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LaunchService = require(script.Parent.LaunchService)

local MissionBoardService = {}

local lifting: { [Player]: boolean } = {}
local lastDeploy: { [Player]: number } = {} -- os.clock of the last accepted DEPLOY

-- Why `player` may not deploy into `missionId` now, or nil when they may.
local function refusal(player: Player, missionId: unknown): string?
	if typeof(missionId) ~= "string" then
		return "Pick a mission first."
	end
	local row = MissionCatalog.get(missionId)
	if not row or not MissionCatalog.isOpen(row, os.time()) then
		return "That mission isn't open."
	end
	if lifting[player] then
		return "You're already lifting."
	end
	local last = lastDeploy[player]
	if last and os.clock() - last < Config.Lobby.MissionBoard.DeployCooldown then
		return "Hold on, the helicopter's still turning round."
	end
	return nil
end

function MissionBoardService.init()
	local remote = Remotes.get("MissionBoard")
	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, missionId: unknown)
		if kind ~= Messages.MissionBoard.Deploy then
			return
		end
		local why = refusal(player, missionId)
		if why then
			remote:FireClient(player, Messages.MissionBoard.Refused, why)
			return
		end
		local id = missionId :: string
		lifting[player] = true
		lastDeploy[player] = os.clock()
		remote:FireClient(player, Messages.MissionBoard.Lifting)
		local ok, reason = LaunchService.send({ player }, id, nil)
		lifting[player] = nil
		if not ok and player.Parent then
			remote:FireClient(
				player,
				Messages.MissionBoard.Refused,
				reason or "The helicopter couldn't lift."
			)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lifting[player] = nil
		lastDeploy[player] = nil
	end)
end

return MissionBoardService
