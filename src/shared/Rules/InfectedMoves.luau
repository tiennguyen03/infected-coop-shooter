--!strict
-- The Infected's big moves (Config.InfectedMoves; docs/sprints/FUN_ENEMIES.md): pure,
-- unit-tested with Lune (tests/InfectedMoves.spec.luau). The Brute's plated front, the
-- Walkers' grab, the range bands, the Brute's charge length and scatter, the Runner's
-- pounce arc and the Hocker's barrage. Plain numbers in, plain numbers out (no Vector3:
-- the specs run outside Roblox).

local InfectedMoves = {}

export type ArmourSettings = {
	frontShare: number, -- damage share a plated front hit does
	backMultiplier: number, -- damage multiplier a hit in the back does
	frontDot: number, -- a hit whose face points further forward than this is front
	backDot: number, -- ...further back than this is back; between is the side
}

export type GrabSettings = {
	crowd: number, -- Infected round a soldier (the hitter counted) before a hit grabs
	slow: number, -- speed factor at the crowd
	slowPerExtra: number, -- taken off per body past the crowd
	minFactor: number, -- never slower than this
}

export type Facing = "front" | "side" | "back"

-- Which face of a body a round struck: (`forward`, `right`) is the hit point's offset from
-- the struck part's centre in the body's own frame. A round lands on the face toward the
-- shooter, so the face is where it came from.
function InfectedMoves.facing(forward: number, right: number, settings: ArmourSettings): Facing
	local length = math.sqrt(forward * forward + right * right)
	if length < 1e-6 then
		return "side"
	end
	local dot = forward / length
	if dot >= settings.frontDot then
		return "front"
	elseif dot <= settings.backDot then
		return "back"
	end
	return "side"
end

local function isLeg(partName: string): boolean
	return string.find(partName, "Leg", 1, true) ~= nil
		or string.find(partName, "Foot", 1, true) ~= nil
end

-- The damage multiplier for a round on `partName` from `face`: the plated front soaks,
-- the back pays more, the legs are never plated (and never the back bonus).
function InfectedMoves.armour(face: string, partName: string, settings: ArmourSettings): number
	if isLeg(partName) then
		return 1
	end
	if face == "front" then
		return settings.frontShare
	elseif face == "back" then
		return settings.backMultiplier
	end
	return 1
end

-- The speed factor a soldier keeps when `crowd` Infected stand round them as a Walker's
-- claw lands: 1 below the crowd, then slower per extra body down to the floor.
function InfectedMoves.grabFactor(crowd: number, settings: GrabSettings): number
	if crowd < settings.crowd then
		return 1
	end
	local factor = settings.slow - (crowd - settings.crowd) * settings.slowPerExtra
	return math.max(settings.minFactor, factor)
end

-- A move starts only with its target inside [minRange, maxRange].
function InfectedMoves.inBand(distance: number, minRange: number, maxRange: number): boolean
	return distance >= minRange and distance <= maxRange
end

-- How far a charge runs: past the target by `overrun`, never more than `maxDistance`.
function InfectedMoves.chargeLength(distance: number, overrun: number, maxDistance: number): number
	return math.min(distance + overrun, maxDistance)
end

-- The flat direction (unit) a charge throws a body: off the side of the line it stands on,
-- plus `along` of the charge's own direction. (`dirX`, `dirZ`) is the charge's unit
-- direction; `side` the body's signed offset to the right of the line (0: thrown right).
function InfectedMoves.scatter(
	dirX: number,
	dirZ: number,
	side: number,
	along: number
): (number, number)
	local rightX, rightZ = dirZ, -dirX
	local sign = if side < 0 then -1 else 1
	local x = rightX * sign + dirX * along
	local z = rightZ * sign + dirZ * along
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then
		return rightX, rightZ
	end
	return x / length, z / length
end

-- A point on the pounce, `t` (0..1) of the way from (x0, y0, z0) to (x1, y1, z1), `height`
-- studs above the straight line at half way.
function InfectedMoves.arc(
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	height: number,
	t: number
): (number, number, number)
	local lift = height * 4 * t * (1 - t)
	return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + lift, z0 + (z1 - z0) * t
end

-- Where `count` globs land round the mark (offsets): the first on it, the rest stepping out
-- `spread` studs either side across the line of the throw (`lineX`, `lineZ`, unit).
function InfectedMoves.barrage(
	count: number,
	spread: number,
	lineX: number,
	lineZ: number
): { { x: number, z: number } }
	local perpX, perpZ = -lineZ, lineX
	local spots = {}
	for index = 1, count do
		local step = math.floor(index / 2)
		local sign = if index % 2 == 0 then 1 else -1
		local distance = step * spread * sign
		table.insert(spots, { x = perpX * distance, z = perpZ * distance })
	end
	return spots
end

return InfectedMoves
