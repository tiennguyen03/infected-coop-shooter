--!strict
-- The stamina rules: pure, no Roblox APIs, unit-tested with Lune (tests/Stamina.spec.luau).
-- SprintController owns the one state on the client (movement is client-owned) and calls
-- these; numbers are Config.Stamina. Sprinting drains, a roll or slide spends a cost, and
-- it comes back after RegenDelay without spending. At zero the body is winded: no sprint
-- and no spend until it is back at WindedRecover. The state is changed in place so a
-- per-frame step allocates nothing.

local Stamina = {}

export type Settings = {
	Max: number,
	SprintDrain: number, -- per second while sprinting
	Regen: number, -- per second once RegenDelay has passed
	RegenDelay: number, -- seconds since the last drain or spend
	WindedRecover: number, -- winded ends at this much
}

export type State = {
	value: number,
	idle: number, -- seconds since the last drain or spend
	winded: boolean,
}

function Stamina.new(settings: Settings): State
	return { value = settings.Max, idle = settings.RegenDelay, winded = false }
end

function Stamina.refill(state: State, settings: Settings)
	state.value = settings.Max
	state.idle = settings.RegenDelay
	state.winded = false
end

function Stamina.canSprint(state: State): boolean
	return not state.winded and state.value > 0
end

-- A roll or slide may start with any stamina left; only a winded body is refused.
function Stamina.canSpend(state: State): boolean
	return not state.winded and state.value > 0
end

-- Takes `cost` (floored at zero, which winds the body). False when refused; a zero cost
-- always goes and does not restart the regen delay.
function Stamina.spend(state: State, cost: number): boolean
	if cost <= 0 then
		return true
	end
	if not Stamina.canSpend(state) then
		return false
	end
	state.value = math.max(state.value - cost, 0)
	state.idle = 0
	if state.value <= 0 then
		state.winded = true
	end
	return true
end

-- One tick. `sprinting` is "the body wants to sprint and is moving"; a winded body drains
-- nothing, so holding the key does not hold the regen off.
function Stamina.step(state: State, dt: number, sprinting: boolean, settings: Settings)
	if sprinting and Stamina.canSprint(state) then
		state.value = math.max(state.value - settings.SprintDrain * dt, 0)
		state.idle = 0
		if state.value <= 0 then
			state.winded = true
		end
		return
	end
	state.idle += dt
	local resting = math.min(dt, state.idle - settings.RegenDelay)
	if resting > 0 and state.value < settings.Max then
		state.value = math.min(state.value + settings.Regen * resting, settings.Max)
	end
	if state.winded and state.value >= settings.WindedRecover then
		state.winded = false
	end
end

function Stamina.fraction(state: State, settings: Settings): number
	if settings.Max <= 0 then
		return 0
	end
	return math.clamp(state.value / settings.Max, 0, 1)
end

return Stamina
