--!strict
-- Call-in geometry and timing (docs/PROGRESSION.md > Call-ins): pure, unit-tested with Lune
-- (tests/StrikePattern.spec.luau). AirStrikeService turns offsets into world points along
-- the flat throw direction; ConcertinaService asks inStrip for each Infected; the supply
-- drops count visits with visit.

local StrikePattern = {}

-- Distances along the throw for `count` impacts `step` studs apart. From the mark forward
-- (Hammer, Walk It In), or `centred` on the mark (Shrike's gun run).
function StrikePattern.offsets(count: number, step: number, centred: boolean): { number }
	local offsets = table.create(count)
	local start = if centred then -step * (count - 1) / 2 else 0
	for index = 1, count do
		offsets[index] = start + step * (index - 1)
	end
	return offsets
end

-- Seconds after the call when each impact lands: the first at `delay`, then `interval` apart.
function StrikePattern.impactTimes(count: number, delay: number, interval: number): { number }
	local times = table.create(count)
	for index = 1, count do
		times[index] = delay + interval * (index - 1)
	end
	return times
end

-- True when the flat offset (dx, dz) from a strip's centre lies inside a strip `length` long
-- and `width` wide whose long axis is the unit direction (dirX, dirZ).
function StrikePattern.inStrip(
	dx: number,
	dz: number,
	dirX: number,
	dirZ: number,
	length: number,
	width: number
): boolean
	local along = dx * dirX + dz * dirZ
	local across = dx * -dirZ + dz * dirX
	return math.abs(along) <= length / 2 and math.abs(across) <= width / 2
end

-- One visit to a supply bundle holding `left` visits. Returns (visits left, served).
function StrikePattern.visit(left: number): (number, boolean)
	if left <= 0 then
		return 0, false
	end
	return left - 1, true
end

return StrikePattern
