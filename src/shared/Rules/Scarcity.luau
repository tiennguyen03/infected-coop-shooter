--!strict
-- Scarcity (docs/sprints/FUN_SCARCITY.md, Config.Scarcity): mistakes cost something. Pure
-- rules, tested in tests/Scarcity.spec.luau:
--   * reserve: a gun's spare rounds at insert and at most, from its own row's Scarce block
--     when scarcity is on (WeaponDefinitions);
--   * addMags: a fallen squadmate's ammo pouch adds whole magazines up to the max;
--   * poolSize: the squad's reinforcements for a run, a base plus one per player;
--   * wiped: the mission is lost when no player is up and nobody can be dropped back in;
--   * pickAnchor: who a reinforcement drops to (the nearest player, else the nearest bot).

local Scarcity = {}

export type ReserveRow = {
	ReserveStart: number,
	ReserveMax: number,
	Scarce: { ReserveStart: number, ReserveMax: number }?,
}

-- (start, max) spare rounds for a gun row; the row's Scarce block when `scarce` is on.
function Scarcity.reserve(row: ReserveRow, scarce: boolean): (number, number)
	local block = row.Scarce
	if scarce and block then
		local max = math.max(block.ReserveMax, 0)
		return math.clamp(block.ReserveStart, 0, max), max
	end
	return row.ReserveStart, row.ReserveMax
end

-- The reserve after taking `mags` magazines of `magSize` from a pouch, capped at `max`;
-- never lowers a reserve that is already over the cap.
function Scarcity.addMags(reserve: number, magSize: number, max: number, mags: number): number
	if reserve >= max then
		return reserve
	end
	return math.min(reserve + magSize * math.max(mags, 0), max)
end

-- Reinforcements in a run for `players` players.
function Scarcity.poolSize(base: number, perPlayer: number, players: number): number
	return math.max(math.floor(base + perPlayer * math.max(players, 0)), 0)
end

export type WipeInput = {
	playersActive: number, -- players Alive or Downed
	botsActive: number, -- bots Alive or Downed: somebody on the ground to drop to
	pending: number, -- reinforcements already on the way
	left: number, -- reinforcements still in the pool
	enabled: boolean, -- Config.Scarcity.Reinforce on
}

-- True when the mission is lost. Off: every player dead (the old rule). On: no player up,
-- and either nobody at all is on the ground to drop to, or the pool is empty with nobody
-- inbound (dead is dead until extraction).
function Scarcity.wiped(input: WipeInput): boolean
	if input.playersActive > 0 then
		return false
	end
	if not input.enabled then
		return true
	end
	if input.botsActive <= 0 then
		return true
	end
	return input.pending <= 0 and input.left <= 0
end

export type Anchor = { id: string, isPlayer: boolean, distance: number }

-- The id of the squadmate a reinforcement drops beside: the nearest player standing, else
-- the nearest bot; nil when nobody stands.
function Scarcity.pickAnchor(candidates: { Anchor }): string?
	local best: Anchor? = nil
	for _, candidate in candidates do
		local current = best
		if
			current == nil
			or (candidate.isPlayer and not current.isPlayer)
			or (candidate.isPlayer == current.isPlayer and candidate.distance < current.distance)
		then
			best = candidate
		end
	end
	return if best then best.id else nil
end

return Scarcity
