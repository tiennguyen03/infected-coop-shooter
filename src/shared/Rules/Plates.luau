--!strict
-- The Warden's plate rules (docs/ARCHITECTURE.md F5): pure, unit-tested with Lune
-- (tests/Plates.spec.luau). A round on a plate damages the plate, never the body; while he
-- guards every plate but the flank one takes it scaled by the guard factor. The weak spot
-- (the back plate over his radio pack, Config.Index.Warden.WeakSpot) also passes `bodyShare`
-- of the round through to the body.

local Plates = {}

-- Returns (plate health left, damage the plate took, damage the body takes).
function Plates.hit(
	health: number,
	damage: number,
	guardFactor: number?,
	flank: boolean,
	bodyShare: number?
): (number, number, number)
	local dealt = if guardFactor and not flank then damage * guardFactor else damage
	return math.max(0, health - dealt), dealt, dealt * (bodyShare or 0)
end

return Plates
