--!strict
-- Bot squadmate decisions (BotService), pure and unit-tested with Lune
-- (tests/BotBrain.spec.luau): when a bot gives up walking and teleports, when it stims,
-- where it throws a grenade or a fire mission, and where a teleport may land. Positions
-- are flat (x, z) points; every threshold is passed in from Config.Bots.

local BotBrain = {}

-- `y` rides along for the caller (the height to throw at); no rule reads it.
export type Point = { x: number, z: number, y: number?, heavy: boolean? }
export type Viewer = { x: number, z: number, lookX: number, lookZ: number }

local function distance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

export type TeleportInput = {
	distance: number, -- to the leader
	stalledFor: number, -- seconds without progress (BotBrain.stall)
	pathFails: number, -- paths not found in a row
	fellOut: boolean, -- far below the leader: out of the world
	sinceTeleport: number, -- seconds since the last teleport
}
export type TeleportSettings = {
	TeleportMinDistance: number,
	StuckSeconds: number,
	NoPathStuckSeconds: number,
	PathFailLimit: number,
	TeleportCooldown: number,
}

-- A bot walks. It teleports only when it fell out of the world, or when it is far from its
-- leader and has made no progress for StuckSeconds (NoPathStuckSeconds once PathFailLimit
-- paths in a row were not found).
function BotBrain.shouldTeleport(input: TeleportInput, settings: TeleportSettings): boolean
	if input.fellOut then
		return true
	end
	if
		input.sinceTeleport < settings.TeleportCooldown
		or input.distance <= settings.TeleportMinDistance
	then
		return false
	end
	local patience = if input.pathFails >= settings.PathFailLimit
		then settings.NoPathStuckSeconds
		else settings.StuckSeconds
	return input.stalledFor >= patience
end

-- The stall clock: `mark` is where the bot last made progress, `since` when. Moving
-- `stuckDistance` away from the mark is progress. Returns the new (mark, since).
function BotBrain.stall(
	mark: Point?,
	since: number?,
	here: Point,
	now: number,
	stuckDistance: number
): (Point, number)
	if mark and since and distance(mark, here) < stuckDistance then
		return mark, since
	end
	return here, now
end

export type StimInput = {
	health: number,
	maxHealth: number,
	stims: number,
	standing: boolean, -- alive, not downed, not knocked down
	sinceStim: number,
}

function BotBrain.shouldStim(
	input: StimInput,
	settings: { StimBelow: number, StimCooldown: number }
): boolean
	return input.standing
		and input.stims > 0
		and input.health > 0
		and input.health <= input.maxHealth * settings.StimBelow
		and input.sinceStim >= settings.StimCooldown
end

export type ClusterSettings = {
	Radius: number, -- the blast: Infected inside it count
	MinCluster: number,
	MinDistance: number, -- from the thrower
	MaxDistance: number, -- the throw
	SafeRadius: number, -- no squad member this close to the target
	HeavyCounts: boolean?, -- one heavy (a Brute, a boss) is worth a throw on its own
}

-- Where to throw: the Infected with the most others inside Radius, between MinDistance and
-- MaxDistance from `self`, with no friend inside SafeRadius. Returns (target, count), or nil
-- when no knot is worth it. A heavy inside the blast outranks any count when HeavyCounts.
function BotBrain.clusterTarget(
	self: Point,
	enemies: { Point },
	friends: { Point },
	settings: ClusterSettings
): (Point?, number)
	local best: Point? = nil
	local bestCount, bestScore = 0, 0
	for _, candidate in enemies do
		local reach = distance(self, candidate)
		if reach < settings.MinDistance or reach > settings.MaxDistance then
			continue
		end
		local safe = true
		for _, friend in friends do
			if distance(friend, candidate) < settings.SafeRadius then
				safe = false
				break
			end
		end
		if not safe then
			continue
		end
		local count, heavy = 0, false
		for _, enemy in enemies do
			if distance(enemy, candidate) <= settings.Radius then
				count += 1
				heavy = heavy or enemy.heavy == true
			end
		end
		local heavyHit = heavy and settings.HeavyCounts == true
		if count < settings.MinCluster and not heavyHit then
			continue
		end
		local score = count + (if heavyHit then 1000 else 0)
		if score > bestScore then
			best, bestCount, bestScore = candidate, count, score
		end
	end
	return best, bestCount
end

-- Which of `spots` a teleporting bot lands on: the first one outside every viewer's view
-- cone (the dot of the viewer's flat look with the direction to the spot is under
-- `viewDot`); the first spot when all are in view.
function BotBrain.teleportSpot(spots: { Point }, viewers: { Viewer }, viewDot: number): number
	for index, spot in spots do
		local seen = false
		for _, viewer in viewers do
			local dx, dz = spot.x - viewer.x, spot.z - viewer.z
			local length = math.sqrt(dx * dx + dz * dz)
			if length < 0.01 or (dx * viewer.lookX + dz * viewer.lookZ) / length >= viewDot then
				seen = true
				break
			end
		end
		if not seen then
			return index
		end
	end
	return 1
end

-- Boss fights: where bot `slot` stands. On a ring StandOff from the boss, on the leader's
-- side of it, the slots fanned SpreadDegrees apart either side of the boss-to-leader line
-- (slot 1 left, 2 right, 3 further left, ...) so one swing, charge or pound cannot catch
-- them all.
function BotBrain.standOff(
	boss: Point,
	leader: Point,
	slot: number,
	settings: { StandOff: number, SpreadDegrees: number }
): Point
	local dx, dz = leader.x - boss.x, leader.z - boss.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		dx, dz, length = 0, 1, 1
	end
	dx, dz = dx / length, dz / length
	local side = if slot % 2 == 1 then -1 else 1
	local angle = math.rad(settings.SpreadDegrees) * math.ceil(slot / 2) * side
	local cos, sin = math.cos(angle), math.sin(angle)
	return {
		x = boss.x + (dx * cos - dz * sin) * settings.StandOff,
		z = boss.z + (dx * sin + dz * cos) * settings.StandOff,
	}
end

-- Whether a downed body is safe to revive: no Infected within ReviveSafeRadius of it and
-- no boss within BossReviveClear (`bossDistance` nil when there is none).
function BotBrain.reviveSafe(
	infectedDistance: number,
	bossDistance: number?,
	settings: { ReviveSafeRadius: number, BossReviveClear: number }
): boolean
	if infectedDistance < settings.ReviveSafeRadius then
		return false
	end
	return bossDistance == nil or bossDistance >= settings.BossReviveClear
end

-- A body inside a disc (a caustic puddle) of `radius` round `center`: the point `margin`
-- past its edge, straight out. Nil when it already stands outside.
function BotBrain.stepOut(here: Point, center: Point, radius: number, margin: number): Point?
	local dx, dz = here.x - center.x, here.z - center.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length > radius then
		return nil
	end
	if length < 0.01 then
		dx, dz, length = 1, 0, 1
	end
	local reach = radius + margin
	return { x = center.x + dx / length * reach, z = center.z + dz / length * reach }
end

return BotBrain
