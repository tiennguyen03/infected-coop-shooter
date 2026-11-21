--!strict
-- The map room's Mission Board (loop sprints 1-2; docs/PROGRESSION.md > Missions): a soldier
-- picks a mission card at the watch officer's table (MissionBoardUI) and presses DEPLOY. The
-- server checks the pick (a catalog row, open now, not pressed again inside
-- Config.Lobby.MissionBoard.DeployCooldown) and hands it to the soldier's party
-- (PartyService.deploy): the leader's DEPLOY picks the mission and starts the squad's
-- countdown, a member's DEPLOY is READY. Alone, you are a party of one and fly at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local MissionCatalog = require(ReplicatedStorage.Shared.MissionCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PartyService = require(script.Parent.PartyService)

local MissionBoardService = {}

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
		lastDeploy[player] = os.clock()
		local ok, reason = PartyService.deploy(player, missionId :: string)
		if not ok then
			remote:FireClient(player, Messages.MissionBoard.Refused, reason or "Not now.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastDeploy[player] = nil
	end)
end

return MissionBoardService
