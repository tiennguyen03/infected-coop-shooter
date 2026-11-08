--!strict
-- The Warden's plate rules (docs/ARCHITECTURE.md F5): pure, unit-tested with Lune
-- (tests/Plates.spec.luau). A round on a plate damages the plate, never the body; while he
-- guards every plate but the flank one takes it scaled by the guard factor.

local Plates = {}

-- Returns (plate health left, damage the plate took).
function Plates.hit(
	health: number,
	damage: number,
	guardFactor: number?,
	flank: boolean
): (number, number)
	local dealt = if guardFactor and not flank then damage * guardFactor else damage
	return math.max(0, health - dealt), dealt
end

return Plates
