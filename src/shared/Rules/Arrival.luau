--!strict
-- Call-in arrivals (docs/PROGRESSION.md > Call-in arrivals): what happens between the throw
-- and the effect. Pure, unit-tested with Lune (tests/Arrival.spec.luau). A call-in's row in
-- Config.CallIns carries an `Arrival` block; `resolve` lays it over the shared defaults
-- (Config.CallIns.Arrivals.Defaults), so a call-in added to the loadouts arrives as a plain
-- thrown marker until its row says otherwise. The server reads the timing (CallInService
-- waits `deployDelay`), the client draws the rest (CallInArrivalFX) with the curves below.

local Arrival = {}

-- Every arrival has these; the rest of the block belongs to its Style (CallInArrivalFX).
export type Resolved = {
	Style: string, -- which arrival CallInArrivalFX draws
	Time: number, -- seconds from the throw until the kit is on the ground and working
	Throw: number, -- seconds the thrown marker is in the air
	[string]: any,
}

-- `overrides` (a row's Arrival block, or nil) over `defaults`. Neither table is changed.
function Arrival.resolve(defaults: { [string]: any }, overrides: { [string]: any }?): Resolved
	local resolved = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			resolved[key] = value
		end
	end
	return resolved :: any
end

-- Seconds the server holds the kit back after the throw. Nothing when arrivals are off
-- (Config.CallIns.Arrivals.Enabled): the kit is there at once, as before.
function Arrival.deployDelay(arrival: Resolved, enabled: boolean): number
	if not enabled then
		return 0
	end
	return math.max(arrival.Time, 0)
end

-- 0 before `from`, 1 from `to` on, linear between.
function Arrival.progress(t: number, from: number, to: number): number
	if to <= from then
		return if t >= to then 1 else 0
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

-- Height above the ground of something dropped from `height` at `from` that lands at `to`,
-- gathering speed all the way (a bundle kicked out of a door).
function Arrival.fall(t: number, from: number, to: number, height: number): number
	local u = Arrival.progress(t, from, to)
	return height * (1 - u * u)
end

-- The same under a chute or a streamer: a steady rate.
function Arrival.drift(t: number, from: number, to: number, height: number): number
	return height * (1 - Arrival.progress(t, from, to))
end

-- Height of one hop between `from` and `to` that peaks at `height` (a bounce, a tossed charge).
function Arrival.hop(t: number, from: number, to: number, height: number): number
	local u = Arrival.progress(t, from, to)
	return 4 * height * u * (1 - u)
end

-- Fast first, settling at 1 (wire paying out, a ring closing).
function Arrival.easeOut(u: number): number
	local left = 1 - math.clamp(u, 0, 1)
	return 1 - left * left
end

-- Where an incoming shell is, measured from its impact: studs back along the throw and
-- studs up. It comes in `angleDegrees` above the ground from `distance` away; `remaining`
-- is 1 where it starts and 0 on the mark.
function Arrival.shellOffset(
	angleDegrees: number,
	distance: number,
	remaining: number
): (number, number)
	local reach = distance * math.clamp(remaining, 0, 1)
	local angle = math.rad(angleDegrees)
	return reach * math.cos(angle), reach * math.sin(angle)
end

-- When a cue `lead` seconds ahead of an impact plays: never before `earliest` (the marker
-- has to land first).
function Arrival.cueTime(impactAt: number, lead: number, earliest: number): number
	return math.max(impactAt - lead, earliest)
end

-- Angles (radians, 0 = along the throw) of `count` mines on an arc spanning `degrees`.
function Arrival.arcAngles(count: number, degrees: number): { number }
	local angles = table.create(count)
	local span = math.rad(degrees)
	for index = 1, count do
		local t = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
		angles[index] = t * span
	end
	return angles
end

-- Distances along a lane `length` long for marks `spacing` apart, centred on the middle.
function Arrival.lane(length: number, spacing: number): { number }
	if spacing <= 0 or length < spacing then
		return { 0 }
	end
	local count = math.floor(length / spacing) + 1
	local marks = table.create(count)
	local start = -spacing * (count - 1) / 2
	for index = 1, count do
		marks[index] = start + spacing * (index - 1)
	end
	return marks
end

-- The gunship's pass for a run of `bursts` impacts `interval` apart, the first `delay`
-- after the throw: it comes in `approach` seconds ahead of the first burst (less when the
-- delay is shorter) and takes as long again to leave. Returns (seconds after the throw it
-- appears, seconds it is in the air).
function Arrival.pass(
	delay: number,
	approach: number,
	bursts: number,
	interval: number
): (number, number)
	local lead = math.clamp(approach, 0, math.max(delay, 0))
	return delay - lead, lead * 2 + interval * math.max(bursts - 1, 0)
end

-- How far along its pass the gunship is at `t` (0 to 1), nil while it is not in the air.
function Arrival.passFraction(t: number, startsAt: number, seconds: number): number?
	if seconds <= 0 or t < startsAt or t > startsAt + seconds then
		return nil
	end
	return (t - startsAt) / seconds
end

return Arrival
