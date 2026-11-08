--!strict
-- Per-player stat multipliers. Sources (items, buffs) contribute additive
-- bonuses keyed by a source name; the recomputed multiplier is published as
-- a player attribute (DamageMult/FireRateMult/MoveSpeedMult) so client
-- systems read it via replication. Server systems use getMultiplier.
local Lifecycle = require(script.Parent.Lifecycle)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attributes = require(ReplicatedStorage.Shared.Attributes)

local STATS = { "Damage", "FireRate", "MoveSpeed" }

local PlayerStatsService = {}

-- bonuses[player][source][stat] = additive bonus (0.2 = +20%)
local bonuses: { [Player]: { [string]: { [string]: number } } } = {}

local function recompute(player: Player)
	local playerBonuses = bonuses[player]
	for _, stat in STATS do
		local total = 1
		if playerBonuses then
			for _, sourceBonuses in playerBonuses do
				total += sourceBonuses[stat] or 0
			end
		end
		player:SetAttribute(Attributes.statMult(stat), total)
	end
end

-- Replaces all bonuses from `source` for this player and recomputes.
function PlayerStatsService.setBonus(
	player: Player,
	source: string,
	statBonuses: { [string]: number }
)
	local playerBonuses = bonuses[player]
	if not playerBonuses then
		playerBonuses = {}
		bonuses[player] = playerBonuses
	end
	playerBonuses[source] = statBonuses
	recompute(player)
end

function PlayerStatsService.getMultiplier(player: Player, stat: string): number
	return (player:GetAttribute(Attributes.statMult(stat)) :: number?) or 1
end

function PlayerStatsService.resetPlayer(player: Player)
	bonuses[player] = nil
	recompute(player)
end

function PlayerStatsService.init()
	Lifecycle.register("PlayerStatsService", {
		onPlayerReset = PlayerStatsService.resetPlayer,
		onPlayerRemoving = function(player: Player)
			bonuses[player] = nil
		end,
	})
	Players.PlayerAdded:Connect(recompute)
	for _, player in Players:GetPlayers() do
		recompute(player)
	end
end

return PlayerStatsService
