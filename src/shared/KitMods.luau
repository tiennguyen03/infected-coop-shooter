--!strict
-- Kit Mods as typed records (Nova, 2026-11-18: the Loadmaster's KIT MODS tab), one per row of
-- Config.KitMods: every number comes from that row, and no list of mod names lives here or
-- anywhere else. Rules/KitModRules takes `KitMods.Rows`; a service that owns an effect asks
-- `KitMods.bonusFor(player, effect)`, read from the player's KitRanks attribute (KitModService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local KitModRules = require(ReplicatedStorage.Shared.Rules.KitModRules)

local KitMods = {}

export type KitMod = KitModRules.Mod & { order: number }

local ROWS: { [string]: KitMod } = {}
for id, row in Config.KitMods do
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		description = row.Description,
		maxRank = row.MaxRank,
		costPerRank = table.clone(row.Costs),
		effectPerRank = row.PerRank,
		effect = row.Effect,
		enabled = row.Enabled,
		order = row.Order,
	}
end

-- Every mod by id, the shape Rules/KitModRules takes.
KitMods.Rows = (ROWS :: any) :: KitModRules.Mods

function KitMods.get(id: string): KitMod?
	return ROWS[id]
end

-- Every mod id in menu order (Order, then id).
function KitMods.ordered(): { string }
	local ids: { string } = {}
	for id in ROWS do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local oa, ob = ROWS[a].order, ROWS[b].order
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return ids
end

-- The ranks `player` holds (their KitRanks attribute; none until it is set).
function KitMods.ranksOf(player: Player): KitModRules.Ranks
	local text = player:GetAttribute(Attributes.KitRanks)
	return KitModRules.decode(if typeof(text) == "string" then text else "")
end

-- What `player`'s ranks add to `effect` (Config.KitMods rows' Effect).
function KitMods.bonusFor(player: Player, effect: string): number
	return KitModRules.bonus(KitMods.ranksOf(player), KitMods.Rows, effect)
end

return KitMods
