--!strict
-- How the wallet readout writes a balance (merits, tabs; WalletReadout): short enough for a
-- 20 px counter, exact while a price can still be compared against it. Pure, unit-tested with
-- Lune (tests/Wallet.spec.luau).

local Wallet = {}

local UNITS = {
	{ size = 1e9, suffix = "B" },
	{ size = 1e6, suffix = "M" },
	{ size = 1e3, suffix = "k" },
}
local EXACT_BELOW = 10000 -- every kit price is under this: the count is exact where it matters
local CAP = 999e9

-- A stored balance as a whole number: 0 for junk, a negative or NaN.
local function whole(value: unknown): number
	if typeof(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	return math.floor(value)
end

local function grouped(count: number): string
	local digits = string.format("%d", count)
	if #digits <= 3 then
		return digits
	end
	return string.sub(digits, 1, -4) .. "," .. string.sub(digits, -3)
end

-- "950", "1,000", "12.4k", "125k", "1.2M". Always rounded down: the readout never shows more
-- than is held.
function Wallet.format(value: number): string
	local count = whole(value)
	if count < EXACT_BELOW then
		return grouped(count)
	end
	if count > CAP then
		return "999B+"
	end
	for _, unit in UNITS do
		if count >= unit.size then
			-- Tenths as a whole number, so 19,999 is 199 tenths ("19.9k") and never "20k".
			local tenths = math.floor(count / (unit.size / 10))
			local units = tenths // 10
			local tenth = tenths % 10
			if units >= 100 or tenth == 0 then
				return string.format("%d%s", units, unit.suffix)
			end
			return string.format("%d.%d%s", units, tenth, unit.suffix)
		end
	end
	return grouped(count)
end

-- The number on screen `alpha` (0 to 1) of the way through a count from one balance to
-- another: fast first (quad out), whole, never past either end.
function Wallet.countUp(from: number, to: number, alpha: number): number
	local t = if alpha == alpha then math.clamp(alpha, 0, 1) else 1
	local eased = 1 - (1 - t) * (1 - t)
	local shown = from + (to - from) * eased
	shown = if to >= from then math.floor(shown) else math.ceil(shown)
	return math.clamp(shown, math.min(from, to), math.max(from, to))
end

return Wallet
