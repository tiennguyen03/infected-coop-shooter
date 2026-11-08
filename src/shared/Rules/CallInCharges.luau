--!strict
-- Call-in charge rules (docs/ARCHITECTURE.md F5): pure, unit-tested with Lune
-- (tests/CallInCharges.spec.luau). A slot holds charges that refill one at a time, one
-- cooldown apart; `nextAt` is when the next charge lands (nil when the slot is full).
-- Times are whatever clock the caller uses (CallInService: os.clock).

local CallInCharges = {}

-- One use. Returns (ok, charges, nextAt): an empty slot refuses; the first charge spent
-- from a full slot starts the timer, a running timer is kept.
function CallInCharges.use(
	charges: number,
	nextAt: number?,
	now: number,
	cooldown: number
): (boolean, number, number?)
	if charges <= 0 then
		return false, charges, nextAt
	end
	return true, charges - 1, nextAt or now + cooldown
end

-- The clock moved on. Returns (charges, nextAt): when the timer has run out a charge
-- lands, and the next one is queued from the moment this one was due until the slot is full.
function CallInCharges.tick(
	charges: number,
	max: number,
	nextAt: number?,
	now: number,
	cooldown: number
): (number, number?)
	if not nextAt or now < nextAt then
		return charges, nextAt
	end
	local landed = math.min(charges + 1, max)
	return landed, if landed < max then nextAt + cooldown else nil
end

return CallInCharges
