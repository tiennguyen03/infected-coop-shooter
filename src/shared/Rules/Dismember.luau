--!strict
-- Dismemberment rules (docs/PROGRESSION.md > Dismemberment; numbers in
-- Config.Enemies.Dismember): pure, unit-tested with Lune (tests/Dismember.spec.luau).
-- GoreService feeds it the part a round struck and the running total on the joint above
-- it, and does the breaking, throwing and stumps.

local Dismember = {}

-- One Config.Enemies.Dismember.Joints row. Part names carry no Left/Right prefix. Counts:
-- the parts whose hits fill the joint's total. Falls: the parts that leave when it breaks.
export type JointSpec = { Counts: { string }, Falls: { string }, Fraction: number, Limb: string }

-- "LeftLowerArm" -> "Left", "LowerArm". A part with no side (head, torso) gives nil, nil.
function Dismember.sideOf(partName: string): (string?, string?)
	if string.sub(partName, 1, 4) == "Left" then
		return "Left", string.sub(partName, 5)
	elseif string.sub(partName, 1, 5) == "Right" then
		return "Right", string.sub(partName, 6)
	end
	return nil, nil
end

-- The joint whose total a hit on `base` (a part name without its side) fills.
function Dismember.jointFor(joints: { [string]: JointSpec }, base: string): string?
	for joint, spec in joints do
		if table.find(spec.Counts, base) then
			return joint
		end
	end
	return nil
end

-- Whether a form (a Config.Enemies.Dismember.Forms row) can lose that kind of limb.
function Dismember.canSever(form: { Arms: boolean?, Legs: boolean? }, limb: string): boolean
	return (limb == "Arm" and form.Arms == true) or (limb == "Leg" and form.Legs == true)
end

-- One hit of `amount` on a joint whose running total is `total` (nil: untouched). The joint
-- breaks on the hit that takes the total to `maxHealth` x `fraction`. Returns the new total
-- and whether it broke; a broken joint's total is -math.huge, so it never breaks twice.
function Dismember.hit(
	total: number?,
	amount: number,
	maxHealth: number,
	fraction: number
): (number, boolean)
	local sum = (total or 0) + amount
	if sum >= maxHealth * fraction then
		return -math.huge, true
	end
	return sum, false
end

return Dismember
