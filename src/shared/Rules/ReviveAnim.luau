--!strict
-- The revive animation's rules (docs/PROGRESSION.md > Downed and revive): where the reviver
-- kneels beside the casualty, which part of the animation plays when, and the shapes of its
-- motions. Pure, unit-tested with Lune (tests/ReviveAnim.spec.luau). ReviveAnimService picks
-- the kneel point; Shared.ReviveAnimation plays the phases. Everything is flat (x, z) with
-- Roblox yaw: a body with yaw `a` looks along (-sin a, -cos a).

local ReviveAnim = {}

export type KneelSettings = {
	-- In the casualty's root space, flat: where the chest of the lying body is, and the unit
	-- direction from its feet to its head.
	chestX: number,
	chestZ: number,
	axisX: number,
	axisZ: number,
	distance: number, -- studs from the chest to the reviver's root
	turn: number, -- radians the kneeling body is turned left of the chest (the kneel clip is bladed)
	maxNudge: number, -- the reviver is never slid further than this
}

export type Times = {
	kneel: number, -- seconds to get down
	finish: number, -- seconds of the pull-up once the revive lands
	pullShare: number, -- share of `finish` spent pulling; the rest is standing
	nudgeSeconds: number, -- the slide to the kneel point takes at least this
	nudgeSpeed: number, -- ... and is never faster than this, studs per second
}

export type KneelPoint = { x: number, z: number, yaw: number }

-- "kneel" going down, "treat" working, "pull" and "stand" after the revive (the reviver);
-- "lie" and "rise" (the casualty); "walk" while the body moves under a treat; "none".
export type Phase = "none" | "kneel" | "treat" | "walk" | "pull" | "stand" | "lie" | "rise"

-- A flat offset in a body's root space, in the world, for a body with this yaw.
local function turn(x: number, z: number, yaw: number): (number, number)
	local cos, sin = math.cos(yaw), math.sin(yaw)
	return x * cos + z * sin, -x * sin + z * cos
end

-- The yaw of a body at (fromX, fromZ) that looks at (toX, toZ).
function ReviveAnim.facing(fromX: number, fromZ: number, toX: number, toZ: number): number
	return math.atan2(fromX - toX, fromZ - toZ)
end

-- Where the lying casualty's chest is, for a root at (x, z) with this yaw.
function ReviveAnim.chest(
	x: number,
	z: number,
	yaw: number,
	settings: KneelSettings
): (number, number)
	local dx, dz = turn(settings.chestX, settings.chestZ, yaw)
	return x + dx, z + dz
end

-- The two places to kneel: either side of the chest, straight across the body, each looking
-- at the chest (turned by `turn`).
function ReviveAnim.kneelPoints(
	x: number,
	z: number,
	yaw: number,
	settings: KneelSettings
): { KneelPoint }
	local chestX, chestZ = ReviveAnim.chest(x, z, yaw, settings)
	local axisX, axisZ = turn(settings.axisX, settings.axisZ, yaw)
	local points = {}
	for _, side in { 1, -1 } do
		local px = chestX - axisZ * side * settings.distance
		local pz = chestZ + axisX * side * settings.distance
		table.insert(points, {
			x = px,
			z = pz,
			yaw = ReviveAnim.facing(px, pz, chestX, chestZ) + settings.turn,
		})
	end
	return points
end

-- Which kneel point a reviver standing at (x, z) takes: the nearest one that is not blocked
-- and no further than `maxNudge`. nil = stay where you are.
function ReviveAnim.pick(
	points: { KneelPoint },
	x: number,
	z: number,
	blocked: { boolean },
	settings: KneelSettings
): number?
	local best: number? = nil
	local bestDistance = settings.maxNudge
	for index, point in points do
		local distance = math.sqrt((point.x - x) ^ 2 + (point.z - z) ^ 2)
		if not blocked[index] and distance <= bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- Seconds the slide to a kneel point `distance` studs away takes.
function ReviveAnim.nudgeSeconds(distance: number, times: Times): number
	return math.max(times.nudgeSeconds, distance / math.max(times.nudgeSpeed, 0.01))
end

-- What a body with this role (the ReviveRole attribute) is doing `elapsed` seconds after it
-- took the role. `moving`: the body is walking or crawling, which breaks a kneel or a lie
-- (the revive itself goes on: the rules do not root anyone).
function ReviveAnim.phase(role: string, elapsed: number, moving: boolean, times: Times): Phase
	local phase: Phase = "none"
	if role == "treat" then
		if moving then
			phase = "walk"
		elseif elapsed < times.kneel then
			phase = "kneel"
		else
			phase = "treat"
		end
	elseif role == "finish" then
		phase = if elapsed < times.finish * times.pullShare then "pull" else "stand"
	elseif role == "treated" then
		phase = if moving then "walk" else "lie"
	elseif role == "recover" then
		phase = "rise"
	end
	return phase
end

-- Smoothstep, clamped to 0..1.
function ReviveAnim.ease(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- How far down a press is, 0..1, `time` seconds in at `rate` presses per second: down and
-- back up once per cycle.
function ReviveAnim.press(time: number, rate: number): number
	return (1 - math.cos(time * rate * 2 * math.pi)) / 2
end

-- The weight of the pull-up reach over the finish: out fast, held, let go by the end.
function ReviveAnim.pull(elapsed: number, times: Times): number
	local total = math.max(times.finish, 0.01)
	local t = elapsed / total
	if t <= 0 or t >= 1 then
		return 0
	end
	local reach = ReviveAnim.ease(t / 0.2)
	local release = ReviveAnim.ease((1 - t) / (1 - times.pullShare))
	return math.min(reach, release)
end

-- `value` moved toward `target` by at most `step`.
function ReviveAnim.approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

return ReviveAnim
