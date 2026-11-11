--!strict
-- Crate rewards (docs/PROGRESSION.md > Pallets, Field upgrades): what a crate offers a
-- player, whether a pick is allowed, what a bot takes, and the one-line text of a set of
-- effects. Pure: RequisitionService feeds it the player's state and applies the result.

-- What a supply card or the squad reward gives (Config.Crates.Cards / Kinds.*.Squad).
export type Effects = {
	Heal: boolean?, -- health to full
	Ammo: boolean?, -- both guns full, magazine and reserve
	CallIns: boolean?, -- every call-in charge back
	Grenades: boolean?,
	Stims: boolean?,
	Plate: number?, -- armour added, soaked before health
}

-- How much of each a soldier is missing, 0 (full) to 1 (empty); absent means 0.
export type Need = {
	Heal: number?,
	Ammo: number?,
	CallIns: number?,
	Grenades: number?,
	Stims: number?,
	Plate: number?,
}

-- A field upgrade this player could carry and the loadout slot it would fill.
export type Candidate = { Id: string, Slot: string }

export type PickInput = {
	open: boolean, -- the crate is down and has not closed
	offer: { string }?, -- what this player was offered on it
	cardId: string,
	picked: boolean, -- this player already took one from this crate
	canAct: boolean, -- alive, not downed, not knocked flat
	distance: number, -- studs from the crate
	radius: number, -- studs: the reach, the server's slack included
}

local Reward = {}

local EFFECT_ORDER = { "Heal", "Ammo", "CallIns", "Grenades", "Stims", "Plate" }
local EFFECT_WORDS: { [string]: string } = {
	Heal = "Full health",
	Ammo = "ammo",
	CallIns = "call-ins",
	Grenades = "grenades",
	Stims = "stims",
}

local function draw(pool: { string }, into: { string }, count: number, random: (number) -> number)
	while #into < count and #pool > 0 do
		local index = math.clamp(random(#pool), 1, #pool)
		table.insert(into, table.remove(pool, index) :: string)
	end
end

-- Up to `count` different field upgrades: never one in `held` (slot -> upgrade id), ones
-- for an empty slot first, ones that would replace a pick only to fill the seats left.
-- `random(n)` returns 1..n.
function Reward.upgradeOffer(
	candidates: { Candidate },
	held: { [string]: string },
	count: number,
	random: (number) -> number
): { string }
	local fresh: { string } = {}
	local replacing: { string } = {}
	for _, candidate in candidates do
		local inSlot = held[candidate.Slot]
		if inSlot == nil then
			table.insert(fresh, candidate.Id)
		elseif inSlot ~= candidate.Id then
			table.insert(replacing, candidate.Id)
		end
	end
	local offer: { string } = {}
	draw(fresh, offer, count, random)
	draw(replacing, offer, count, random)
	return offer
end

-- A short offer filled up to `count` with supply cards, in their order.
function Reward.pad(offer: { string }, supply: { string }, count: number): { string }
	local padded = table.clone(offer)
	for _, cardId in supply do
		if #padded >= count then
			break
		end
		if not table.find(padded, cardId) then
			table.insert(padded, cardId)
		end
	end
	return padded
end

-- Whether the server takes a pick. The reason is a word the client turns into a line:
-- "gone" | "taken" | "not_offered" | "down" | "far".
function Reward.checkPick(input: PickInput): (boolean, string?)
	if not input.open then
		return false, "gone"
	end
	if input.picked then
		return false, "taken"
	end
	if not input.offer or not table.find(input.offer, input.cardId) then
		return false, "not_offered"
	end
	if not input.canAct then
		return false, "down"
	end
	if input.distance > input.radius then
		return false, "far"
	end
	return true, nil
end

local function score(effects: Effects, need: Need): number
	local total = 0
	for _, key in EFFECT_ORDER do
		local gives = (effects :: any)[key]
		if gives and gives ~= 0 then
			total += (need :: any)[key] or 0
		end
	end
	return total
end

-- What a bot takes from `offer`: the card covering the most of what it is missing, or
-- nothing when that is under `threshold`. Cards without a row in `cards` (field upgrades)
-- are never taken.
function Reward.botChoice(
	offer: { string },
	cards: { [string]: Effects },
	need: Need,
	threshold: number
): string?
	local best: string? = nil
	local bestScore = 0
	for _, cardId in offer do
		local effects = cards[cardId]
		if effects then
			local value = score(effects, need)
			if value > bestScore then
				best = cardId
				bestScore = value
			end
		end
	end
	return if bestScore >= threshold then best else nil
end

-- "Full health, ammo, call-ins, grenades, stims, +50 armour": what a set of effects gives.
function Reward.effectsLine(effects: Effects): string
	local parts: { string } = {}
	for _, key in EFFECT_ORDER do
		local gives = (effects :: any)[key]
		if key == "Plate" then
			if typeof(gives) == "number" and gives > 0 then
				table.insert(parts, `+{gives} armour`)
			end
		elseif gives then
			table.insert(parts, EFFECT_WORDS[key])
		end
	end
	return table.concat(parts, ", ")
end

return Reward
