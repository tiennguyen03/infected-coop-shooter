--!strict
-- A breaching round on a wall, as pure maths (tests/WallBreach.spec.luau; the Mossberg's
-- breaching shell, Nova 2026-11-20; WallBreachService does the parts).
-- Breakable: a building wall (Names) no thicker than MaxThickness, of a light material
-- (Materials: the huts' planks, the Shed's sheet metal, painted panel). Concrete and brick hold.
-- Each breaching hit pushes the wall by the gun's breachPower (1 as issued, the breaching
-- muzzle doubles it); at Toughness the wall opens. So doors of light walls take one shot with
-- the breaching muzzle and two without.
-- The opening is door-sized (Hole) from the wall's foot, centred on the hit and slid inside
-- the wall; what is left of the wall stays as up to three pieces (left, right, over the hole).
-- Coordinates are the wall's own, centred: u along it (-length/2..length/2), y up it.

local WallBreach = {}

export type Settings = {
	Names: { string }, -- the part names that are walls (ArenaService's "Wall")
	Materials: { string }, -- Enum.Material names that a breaching round opens
	MaxThickness: number, -- studs
	Toughness: number, -- breachPower to open one
	Hole: { Width: number, Height: number },
	MinPiece: number, -- studs: a strip thinner than this is not kept
}

export type Piece = { u0: number, u1: number, y0: number, y1: number }

function WallBreach.breakable(
	name: string,
	thickness: number,
	material: string,
	settings: Settings
): boolean
	return table.find(settings.Names, name) ~= nil
		and thickness <= settings.MaxThickness
		and table.find(settings.Materials, material) ~= nil
end

local function push(power: number): number
	if power ~= power or power == math.huge or power <= 0 then
		return 0
	end
	return power
end

-- How many hits of `power` open a wall (math.huge: never).
function WallBreach.hitsToBreak(power: number, toughness: number): number
	local p = push(power)
	if p <= 0 then
		return math.huge
	end
	-- A small slack so 0.5 x 4 is 2 hits, not 3 from float error.
	return math.max(1, math.ceil(toughness / p - 1e-9))
end

-- A hit of `power` on a wall that has taken `damage`: (its damage now, whether it opened).
function WallBreach.struck(damage: number, power: number, toughness: number): (number, boolean)
	local p = push(power)
	if p <= 0 then
		return damage, false
	end
	local now = damage + p
	return now, now >= toughness - 1e-9
end

-- The pieces left of a wall `length` long and `height` tall, hit `hitU` along it.
function WallBreach.cut(length: number, height: number, hitU: number, settings: Settings): { Piece }
	local half, top, bottom = length / 2, height / 2, -height / 2
	local width = math.min(settings.Hole.Width, length)
	local centre = math.clamp(hitU, -half + width / 2, half - width / 2)
	local a, b = centre - width / 2, centre + width / 2
	local holeTop = bottom + settings.Hole.Height
	local min = settings.MinPiece
	local pieces: { Piece } = {}
	if a - -half >= min then
		table.insert(pieces, { u0 = -half, u1 = a, y0 = bottom, y1 = top })
	end
	if half - b >= min then
		table.insert(pieces, { u0 = b, u1 = half, y0 = bottom, y1 = top })
	end
	if top - holeTop >= min and b - a >= min then
		table.insert(pieces, { u0 = a, u1 = b, y0 = holeTop, y1 = top })
	end
	return pieces
end

return WallBreach
