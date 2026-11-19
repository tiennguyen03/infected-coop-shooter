--!strict
-- Kit Mods as pure rules (tests/KitModRules.spec.luau; Nova, 2026-11-18: the Loadmaster's
-- KIT MODS tab). A Kit Mod is a passive buff on the soldier whatever gun they carry, bought
-- rank by rank with merits (never tabs), up to its maxRank, and kept for good. If a bonus
-- changes how one gun behaves it is an attachment instead (Rules/AttachmentRules).
--
-- Each rank bought is one id on the soldier's record (`<modId>@<rank>`, Rules/Record `owned`),
-- so a rank and its merits are spent in one step on the saved record (`buyRankStored`, the
-- lobby's UpdateAsync, the same path as buying kit) and the match's merit pay keeps them. A
-- mod's rank is the highest unbroken rank on the record. Only the next rank can be bought:
-- the client names the rank it is buying, so a double click or a stale screen never pays twice.

local Record = require("./Record")

local KitModRules = {}

export type Mod = {
	id: string,
	displayName: string,
	description: string,
	maxRank: number,
	costPerRank: { number }, -- merits for rank 1, 2, 3...
	effectPerRank: number, -- added to `effect` per rank held
	effect: string, -- what it changes (Config.KitMods rows' Effect; the services ask `bonus`)
	enabled: boolean, -- false: shown greyed, not for sale, no effect yet
}

export type Mods = { [string]: Mod }
export type Ranks = { [string]: number }

function KitModRules.rankId(modId: string, rank: number): string
	return `{modId}@{rank}`
end

-- The highest rank r of `modId` with ranks 1..r all in `owned` (0 = none).
function KitModRules.rankOf(owned: { string }, modId: string, maxRank: number): number
	local rank = 0
	while rank < maxRank and table.find(owned, KitModRules.rankId(modId, rank + 1)) do
		rank += 1
	end
	return rank
end

-- Every mod's rank from the record's owned ids.
function KitModRules.ranks(owned: { string }, mods: Mods): Ranks
	local ranks: Ranks = {}
	for id, mod in mods do
		ranks[id] = KitModRules.rankOf(owned, id, mod.maxRank)
	end
	return ranks
end

-- Merits for the rank after `rank`, or nil at the cap.
function KitModRules.nextCost(mod: Mod, rank: number): number?
	if rank >= mod.maxRank then
		return nil
	end
	return mod.costPerRank[rank + 1]
end

-- May the soldier buy rank `rank` of `modId` now? (true) or (false, "unknown" | "disabled" |
-- "maxed" | "beyond max" | "not next" | "short").
function KitModRules.canBuy(
	record: Record.Record,
	modId: string,
	rank: number,
	mods: Mods
): (boolean, string?)
	local mod = mods[modId]
	if not mod then
		return false, "unknown"
	end
	if not mod.enabled then
		return false, "disabled"
	end
	local held = KitModRules.rankOf(record.owned, modId, mod.maxRank)
	if held >= mod.maxRank then
		return false, "maxed"
	end
	if rank > mod.maxRank then
		return false, "beyond max"
	end
	if rank ~= held + 1 then
		return false, "not next"
	end
	local cost = mod.costPerRank[rank]
	if cost == nil then
		return false, "unknown"
	end
	if record.merits < cost then
		return false, "short"
	end
	return true, nil
end

-- (the new record, true) or (the record unchanged, false, reason as canBuy).
function KitModRules.buyRank(
	record: Record.Record,
	modId: string,
	rank: number,
	mods: Mods
): (Record.Record, boolean, string?)
	local ok, reason = KitModRules.canBuy(record, modId, rank, mods)
	if not ok then
		return record, false, reason
	end
	local mod = mods[modId]
	local id = KitModRules.rankId(modId, rank)
	return Record.buy(record, id, function(asked: string): number?
		return if asked == id then mod.costPerRank[rank] else nil
	end)
end

-- The buy applied to the record as it is stored (the lobby's UpdateAsync transform), checked
-- against the stored rank and merits: (the value to store, nil) or (nil, reason).
function KitModRules.buyRankStored(
	stored: unknown,
	modId: string,
	rank: number,
	mods: Mods,
	startMerits: number
): (Record.Saved?, string?)
	if not Record.canUpdate(stored) then
		return nil, "unreadable"
	end
	local after, ok, reason =
		KitModRules.buyRank(Record.decode(stored, startMerits), modId, rank, mods)
	if not ok then
		return nil, reason
	end
	return Record.encode(after), nil
end

-- The total `effect` from the ranks held: each enabled mod with that effect, its
-- effectPerRank times its rank (never past maxRank).
function KitModRules.bonus(ranks: Ranks, mods: Mods, effect: string): number
	local total = 0
	for id, mod in mods do
		if mod.enabled and mod.effect == effect then
			local rank = math.clamp(ranks[id] or 0, 0, mod.maxRank)
			total += mod.effectPerRank * rank
		end
	end
	return total
end

-- The ranks as one attribute string ("mod=rank;...", sorted, rank 0 left out), and back.
function KitModRules.encode(ranks: Ranks): string
	local parts: { string } = {}
	for id, rank in ranks do
		if rank > 0 then
			table.insert(parts, `{id}={rank}`)
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function KitModRules.decode(text: string): Ranks
	local ranks: Ranks = {}
	for entry in string.gmatch(text, "[^;]+") do
		local id, rank = string.match(entry, "^([^=]+)=(%d+)$")
		if id and rank then
			ranks[id] = tonumber(rank) :: number
		end
	end
	return ranks
end

return KitModRules
