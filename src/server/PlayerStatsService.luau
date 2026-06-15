--!strict
-- Per-player stat multipliers. Sources (items, buffs) contribute additive
-- bonuses keyed by a source name; the recomputed multiplier is published as
-- a player attribute (DamageMult/FireRateMult/MoveSpeedMult) so client
-- systems read it via replication. Server systems use getMultiplier.

local Players = game:GetService("Players")

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
		player:SetAttribute(stat .. "Mult", total)
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
	return (player:GetAttribute(stat .. "Mult") :: number?) or 1
end

function PlayerStatsService.resetPlayer(player: Player)
	bonuses[player] = nil
	recompute(player)
end

function PlayerStatsService.init()
	Players.PlayerAdded:Connect(recompute)
	for _, player in Players:GetPlayers() do
		recompute(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		bonuses[player] = nil
	end)
end

return PlayerStatsService
