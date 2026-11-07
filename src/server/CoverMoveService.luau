--!strict
-- CoverMoveService: the client runs the vault/climb/roll (MovementController) and reports it
-- with the CoverMove remote. The server opens a short window, stored on the character as
-- the "CoverMoveUntil" attribute (server os.clock), in which Infected melee skips that body
-- (EnemyService.attackIfTouching). Ranged attacks still land. Windows are capped at the
-- configured move duration and can't be chained without a gap, so the remote can't buy
-- standing immunity. State is per player and dropped on PlayerRemoving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local CoverMoveService = {}

local windowEnds: { [Player]: number } = {}

local function onCoverMove(player: Player, kind: unknown)
	if kind ~= "vault" and kind ~= "climb" and kind ~= "roll" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local settings = Config.Movement
	local now = os.clock()
	local lastEnd = windowEnds[player]
	if lastEnd and now < lastEnd + settings.CoverImmunity.Cooldown then
		return
	end
	local duration = if kind == "vault"
		then settings.VaultDuration
		elseif kind == "roll" then settings.Roll.Duration
		else settings.ClimbDuration
	local ends = now + duration + settings.CoverImmunity.Grace
	windowEnds[player] = ends
	character:SetAttribute("CoverMoveUntil", ends)
end

function CoverMoveService.init()
	Remotes.get("CoverMove").OnServerEvent:Connect(onCoverMove)
	Players.PlayerRemoving:Connect(function(player)
		windowEnds[player] = nil
	end)
end

return CoverMoveService
