--!strict
-- Overpenetration: a round that carries on through what it hits (the Fifty, Nova 2026-11-20;
-- Config.Weapons.<gun>.Overpen). Pure, unit-tested with Lune (tests/Overpen.spec.luau). The
-- server (ProjectileServer) walks the round's line and asks this rule at every thing it meets:
--
-- - A body (an Infected or a soldier) takes the round at its share, then the round goes on.
--   Each body pierced takes Falloff off the share (linear: 1, 0.9, 0.8, ...), never below 0.
--   The round hits at most Bodies bodies; the last one stops it.
-- - A soldier counts as a body and takes the round too (friendly fire is the trade-off, not a
--   bug), scaled by FriendlyFire.
-- - A wall no thicker than WallThickness is passed through at no cost; a thicker one, or one
--   whose thickness is unknown (terrain), stops the round.
--
-- The M2010's Pierce still runs its own count in ProjectileServer (retrofit: a later PR).

local Overpen = {}

export type Settings = {
	bodies: number, -- bodies a round hits at most (the last stops it)
	falloff: number, -- share taken off the round per body pierced
	wallThickness: number, -- studs: a wall this thick or thinner is passed through
	friendlyFire: number, -- a soldier's share of what an Infected would take
}

export type Kind = "infected" | "soldier" | "wall"

export type Round = {
	settings: Settings,
	pierced: number, -- bodies hit so far
	stopped: boolean,
}

function Overpen.new(settings: Settings): Round
	return { settings = settings, pierced = 0, stopped = false }
end

-- What the round does to the thing it met: (the share of the round's damage it takes, whether
-- the round carries on past it). `thickness` is the wall's along the line (nil: unknown).
function Overpen.hit(round: Round, kind: Kind, thickness: number?): (number, boolean)
	if round.stopped then
		return 0, false
	end
	local settings = round.settings
	if kind == "wall" then
		if thickness ~= nil and thickness <= settings.wallThickness then
			return 0, true
		end
		round.stopped = true
		return 0, false
	end
	local share = math.max(0, 1 - settings.falloff * round.pierced)
	if kind == "soldier" then
		share *= settings.friendlyFire
	end
	round.pierced += 1
	if round.pierced >= settings.bodies then
		round.stopped = true
	end
	return share, not round.stopped
end

-- A body's damage: the round's damage at `share`.
function Overpen.damage(roundDamage: number, share: number): number
	return roundDamage * share
end

return Overpen
