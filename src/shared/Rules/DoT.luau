--!strict
-- Damage over time, as pure maths (tests/DoT.spec.luau): the one rule for every burn, first
-- the Mossberg's Dragon's Breath (BurnService; Nova, 2026-11-20). The Cauterizer's fire and the
-- Leech's acid reuse it, never a second rule.
-- A target holds stacks; each hit adds one that pays `damage` evenly over `seconds` on its own
-- clock (eight pellets that land are eight stacks, burning eight times as hard). A tick pays
-- what every stack owes since the last tick, never past its end, so the total is exact however
-- often it is ticked. Past `maxStacks` a fresh stack replaces the one ending soonest (what that
-- one had not paid is lost), so a target burns hard but never without limit.

local DoT = {}

export type Stack = {
	perSecond: number,
	paidUntil: number, -- the clock this stack has paid up to
	endsAt: number,
}

export type State = { stacks: { Stack } }

function DoT.new(): State
	return { stacks = {} }
end

local function real(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- A hit at `now`: `damage` over `seconds`. False when nothing was added (no damage, no time,
-- no room, or not a real number).
function DoT.add(
	state: State,
	now: number,
	damage: number,
	seconds: number,
	maxStacks: number
): boolean
	if not (real(damage) and real(seconds) and real(now)) or damage <= 0 or seconds <= 0 then
		return false
	end
	if maxStacks < 1 then
		return false
	end
	local stack: Stack = { perSecond = damage / seconds, paidUntil = now, endsAt = now + seconds }
	local stacks = state.stacks
	if #stacks < maxStacks then
		table.insert(stacks, stack)
		return true
	end
	local soonest = 1
	for index, other in stacks do
		if other.endsAt < stacks[soonest].endsAt then
			soonest = index
		end
	end
	stacks[soonest] = stack
	return true
end

-- The damage every stack owes from its last payment up to `now`; spent stacks are dropped.
function DoT.tick(state: State, now: number): number
	local total = 0
	local stacks = state.stacks
	for index = #stacks, 1, -1 do
		local stack = stacks[index]
		local upTo = math.min(now, stack.endsAt)
		if upTo > stack.paidUntil then
			total += stack.perSecond * (upTo - stack.paidUntil)
			stack.paidUntil = upTo
		end
		if stack.paidUntil >= stack.endsAt then
			table.remove(stacks, index)
		end
	end
	return total
end

-- Whether anything still burns after `now`.
function DoT.active(state: State, now: number): boolean
	for _, stack in state.stacks do
		if stack.endsAt > now then
			return true
		end
	end
	return false
end

-- The damage still to come after `now` (what is owed before it is not counted).
function DoT.remaining(state: State, now: number): number
	local total = 0
	for _, stack in state.stacks do
		total += stack.perSecond * math.max(0, stack.endsAt - math.max(stack.paidUntil, now))
	end
	return total
end

return DoT
