--!strict
-- What an Infected notices (Nova, 2026-11-11: the night map played quiet; "the infected ai
-- really should have multiple different states. sleeping/idle, wandering, alerted, chase").
-- Pure rules for EnemyService on a mission with Config.Awareness on; tests/Awareness.spec.luau.
--
-- States: Sleeping (slumped, eyes shut: only noise close by or a touch wakes it), Idle (standing
-- still), Wandering (shuffling about), Alerted (heard or glimpsed something: walks to the spot
-- and searches), Chase (knows where a soldier is: the old straight chase).
-- A noise has a reach: inside half of it a body comes straight for the noise-maker (Chase),
-- inside all of it it goes to look (Alerted). A sleeper hears less of it (Hearing.Sleeping).
-- Sight: a cone in front of the head, shorter at night and against a crouched or prone
-- soldier; a soldier in the cone builds the body's notice (faster the closer); a full notice is
-- a Chase, any notice an Alert toward where it was seen.

local Awareness = {}

export type State = "Sleeping" | "Idle" | "Wandering" | "Alerted" | "Chase"

export type Settings = {
	Hearing: { [string]: number }, -- per state: share of a noise's reach this body hears
	Sight: {
		Range: { [string]: number }, -- per state, studs (0: blind)
		HalfAngle: number, -- degrees either side of the facing
		Night: number, -- range factor on a night mission
		Crouch: number, -- range factor against a crouched soldier
		Prone: number, -- range factor against a prone soldier
		NoticeSeconds: number, -- at the edge of the range; quicker the closer
		Instant: number, -- studs: inside this, seen is noticed at once
	},
	Touch: number, -- studs: a soldier this close wakes even a sleeper (into Chase)
}

-- What a noise `distance` away with reach `reach` does to a body in `state`.
function Awareness.hear(settings: Settings, state: State, distance: number, reach: number): State?
	if state == "Chase" then
		return nil
	end
	local heard = reach * (settings.Hearing[state] or 1)
	if heard <= 0 or distance > heard then
		return nil
	end
	if distance <= heard * 0.5 then
		return "Chase"
	end
	return "Alerted"
end

-- How far a body in `state` sees a soldier in `stance` ("stand" | "crouch" | "prone").
function Awareness.sightRange(
	settings: Settings,
	state: State,
	stance: string,
	night: boolean
): number
	local sight = settings.Sight
	local range = sight.Range[state] or 0
	if night then
		range *= sight.Night
	end
	if stance == "crouch" then
		range *= sight.Crouch
	elseif stance == "prone" then
		range *= sight.Prone
	end
	return range
end

-- Whether a soldier `distance` away, at flat offset (offsetX, offsetZ) from the body, is inside
-- its cone of `range` when it faces (facingX, facingZ). Plain numbers: the rules run anywhere.
function Awareness.inCone(
	settings: Settings,
	facingX: number,
	facingZ: number,
	offsetX: number,
	offsetZ: number,
	distance: number,
	range: number
): boolean
	if range <= 0 or distance > range then
		return false
	end
	local facingLength = math.sqrt(facingX * facingX + facingZ * facingZ)
	local offsetLength = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
	if facingLength < 0.01 or offsetLength < 0.01 then
		return true
	end
	local cos = (facingX * offsetX + facingZ * offsetZ) / (facingLength * offsetLength)
	return cos >= math.cos(math.rad(settings.Sight.HalfAngle))
end

-- Notice gained per second against a soldier seen `distance` away inside `range` (1 = Chase).
function Awareness.noticeRate(settings: Settings, distance: number, range: number): number
	local sight = settings.Sight
	if distance <= sight.Instant then
		return math.huge
	end
	if range <= 0 or distance > range then
		return 0
	end
	-- From 1 / NoticeSeconds at the edge to four times that close in.
	local closeness = 1 - distance / range
	return (1 + 3 * closeness) / sight.NoticeSeconds
end

-- A touch: a soldier within Touch wakes any body straight into Chase.
function Awareness.touched(settings: Settings, distance: number): boolean
	return distance <= settings.Touch
end

-- Stronger of two reactions (Chase over Alerted over nothing).
function Awareness.stronger(a: State?, b: State?): State?
	if a == "Chase" or b == "Chase" then
		return "Chase"
	end
	if a == "Alerted" or b == "Alerted" then
		return "Alerted"
	end
	return a or b
end

return Awareness
