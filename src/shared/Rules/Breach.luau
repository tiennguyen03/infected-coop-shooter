--!strict
-- Breaches and the pressure rhythm (docs/PROGRESSION.md > Breaches; design note
-- docs/sprints/FUN_BREACHES.md): pure, unit-tested with Lune (tests/Breach.spec.luau).
-- BreachService feeds it Config.Breaches, the run's threat clock and the loud moments.
--
-- One alert meter per run (shared by the squad). Noise and contact raise it; going quiet lets
-- it fall after QuietDelay (never below the late-run Floor). At the threshold a breach
-- starts: WarnSeconds of warning, then FloodSeconds of horde, then Relief seconds where
-- nothing builds, then Calm with the alert spent. Pressure (0..1 over RampSeconds of run
-- time) makes the threshold lower, the relief shorter and the horde bigger late in the run.
-- Phases: Calm -> Tension (alert past TensionAt of the threshold) -> Breach -> Relief -> Calm.

local Breach = {}

export type Phase = "Calm" | "Tension" | "Breach" | "Relief"

export type Settings = {
	Threshold: { number }, -- alert for a breach { at pressure 0, at pressure 1 }
	Passive: { number }, -- alert per second from time alone { early, late }
	TensionAt: number, -- share of the threshold where Calm turns to Tension
	QuietDelay: number, -- seconds after the last loud moment before the alert falls
	Decay: number, -- alert per second while quiet
	Floor: { number }, -- share of the threshold the alert never falls below { early, late }
	MaxGainPerSecond: number, -- gunfire's most alert in any one second (all guns together)
	RampSeconds: number, -- run seconds for pressure to reach 1
	WarnSeconds: number, -- the warning before the horde
	FloodSeconds: number, -- the horde arrives over this long
	Relief: { number }, -- seconds of quiet after a breach { early, late }
	Horde: { Base: number, PerExtraPlayer: number, Late: number, Max: number },
	Trickle: { [string]: number }, -- spawn-interval multiplier per phase (bigger = fewer)
}

export type State = {
	alert: number,
	phase: Phase,
	phaseUntil: number, -- clock when a Breach or Relief ends
	lastLoudAt: number,
	windowAt: number, -- start of the current one-second gunfire window
	windowGain: number,
	breaches: number,
}

function Breach.new(): State
	return {
		alert = 0,
		phase = "Calm",
		phaseUntil = 0,
		lastLoudAt = -math.huge,
		windowAt = -math.huge,
		windowGain = 0,
		breaches = 0,
	}
end

local function lerp(pair: { number }, t: number): number
	return pair[1] + (pair[2] - pair[1]) * t
end

-- 0 at the start of a run, 1 after RampSeconds of threat clock.
function Breach.pressure(s: Settings, elapsed: number): number
	return math.clamp(elapsed / math.max(s.RampSeconds, 1), 0, 1)
end

function Breach.threshold(s: Settings, elapsed: number): number
	return lerp(s.Threshold, Breach.pressure(s, elapsed))
end

function Breach.relief(s: Settings, elapsed: number): number
	return lerp(s.Relief, Breach.pressure(s, elapsed))
end

-- A loud moment worth `amount` at clock `now`. `capped` (gunfire) shares MaxGainPerSecond
-- with every other shot in the same second. Nothing builds during a breach or its relief.
-- Returns what was added.
function Breach.add(s: Settings, state: State, amount: number, now: number, capped: boolean): number
	if amount <= 0 or state.phase == "Breach" or state.phase == "Relief" then
		return 0
	end
	local added = amount
	if capped then
		if now - state.windowAt >= 1 then
			state.windowAt = now
			state.windowGain = 0
		end
		added = math.clamp(s.MaxGainPerSecond - state.windowGain, 0, amount)
		state.windowGain += added
	end
	state.alert += added
	state.lastLoudAt = now
	return added
end

-- Starts a breach now (the threshold was reached, an objective called one, or the dev menu).
function Breach.start(s: Settings, state: State, now: number, _elapsed: number)
	state.phase = "Breach"
	state.phaseUntil = now + s.WarnSeconds + s.FloodSeconds
	state.breaches += 1
end

-- One tick. Moves the phases on and the alert up or down. Returns true when a breach should
-- start now (the caller calls `start`); never while `blocked` (the Warden on the field,
-- extraction, a paused field).
function Breach.step(
	s: Settings,
	state: State,
	dt: number,
	now: number,
	elapsed: number,
	blocked: boolean
): boolean
	if state.phase == "Breach" then
		if now >= state.phaseUntil then
			state.phase = "Relief"
			state.phaseUntil = now + Breach.relief(s, elapsed)
		end
		return false
	elseif state.phase == "Relief" then
		if now >= state.phaseUntil then
			state.phase = "Calm"
			state.alert = 0
			state.lastLoudAt = -math.huge
		end
		return false
	end
	local pressure = Breach.pressure(s, elapsed)
	local threshold = lerp(s.Threshold, pressure)
	local alert = state.alert + lerp(s.Passive, pressure) * dt
	if now - state.lastLoudAt >= s.QuietDelay then
		local floor = lerp(s.Floor, pressure) * threshold
		if alert > floor then
			alert = math.max(alert - s.Decay * dt, floor)
		end
	end
	state.alert = math.max(alert, 0)
	state.phase = if state.alert >= threshold * s.TensionAt then "Tension" else "Calm"
	return not blocked and state.alert >= threshold
end

-- Bodies in a breach: Base, + PerExtraPlayer per living player beyond the first, + Late at
-- full pressure; never more than Max nor more than the room under the live cap.
function Breach.hordeSize(
	s: Settings,
	extraPlayers: number,
	elapsed: number,
	alive: number,
	cap: number
): number
	local horde = s.Horde
	local size = horde.Base
		+ horde.PerExtraPlayer * math.max(extraPlayers, 0)
		+ horde.Late * Breach.pressure(s, elapsed)
	size = math.min(math.floor(size + 0.5), horde.Max)
	return math.max(math.min(size, cap - alive), 0)
end

-- The roaming spawn interval's multiplier in this phase (1 when the phase has no row).
function Breach.trickle(s: Settings, phase: Phase): number
	return s.Trickle[phase] or 1
end

-- Seconds after the flood starts at which each of `count` bodies arrives, evenly spread
-- (the first at once, the last a step before the flood ends).
function Breach.arrivals(count: number, flood: number): { number }
	local times = {}
	for index = 1, count do
		table.insert(times, (index - 1) * flood / math.max(count, 1))
	end
	return times
end

local COMPASS =
	{ "east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east" }

-- A flat direction as the radio says it (+X east, +Z north, docs/LEVELS.md).
function Breach.compass(x: number, z: number): string
	local angle = math.atan2(z, x) -- 0 = east, counter-clockwise
	local sector = math.floor(angle / (math.pi / 4) + 0.5) % 8
	return COMPASS[sector + 1]
end

return Breach
