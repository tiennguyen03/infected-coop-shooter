--!strict
-- Strikes landing on the crowd (Config.CallIns.Landing; docs/PROGRESSION.md > Call-ins):
-- pure, unit-tested in Lune (tests/StrikeLanding.spec.luau).
-- Owner 2026-11-16: "the call-ins ... aren't that effective because the zombies move out of
-- the way". Nothing dodged: the Infected keep chasing the nearest soldier and walk 30-50
-- studs between the mark and the round. Two answers, each per row with a default:
--   Hold: the Infected within Hold studs of a fire mission's mark are drawn to the marker
--     (the smoke, the noise) until HoldAfter seconds after the first impact
--     (AirStrikeService, through EnemyService.setLure). Only what the mark is on.
--   Height: a blast is measured flat along the ground, and reaches Height studs up or down
--     (a Brute's root sits about 6 studs up, so a sphere from the ground missed it).
-- Enabled false: no hold, and every blast is the old sphere from its centre.

local StrikeLanding = {}

export type Settings = {
	Hold: number, -- studs round the mark the Infected are drawn in (0 = none)
	HoldAfter: number, -- seconds after the first impact the hold ends
	Height: number, -- studs above or below a blast's centre a body still counts
}

export type Resolved = {
	Hold: number,
	HoldAfter: number,
	Height: number,
	Flat: boolean, -- measured flat with Height; false = the old sphere
}

-- A row's `Landing` block over the defaults; with the switch off, no hold and the sphere.
function StrikeLanding.resolve(
	enabled: boolean,
	defaults: Settings,
	row: { [string]: any }?
): Resolved
	local own = row or {}
	local function pick(key: string): number
		local value = own[key]
		if typeof(value) == "number" then
			return value
		end
		return (defaults :: any)[key]
	end
	return {
		Hold = if enabled then pick("Hold") else 0,
		HoldAfter = pick("HoldAfter"),
		Height = pick("Height"),
		Flat = enabled,
	}
end

-- Seconds from the call to the hold's end, for a mission whose first impact is
-- `firstImpact` seconds away (0 = no hold).
function StrikeLanding.holdSeconds(resolved: Resolved, firstImpact: number): number
	if resolved.Hold <= 0 then
		return 0
	end
	return math.max(firstImpact + resolved.HoldAfter, 0)
end

-- Whether a body (dx, dy, dz) from a blast's centre is inside its `radius`.
function StrikeLanding.inBlast(
	resolved: Resolved,
	dx: number,
	dy: number,
	dz: number,
	radius: number
): boolean
	if not resolved.Flat then
		return dx * dx + dy * dy + dz * dz <= radius * radius
	end
	return dx * dx + dz * dz <= radius * radius and math.abs(dy) <= resolved.Height
end

return StrikeLanding
