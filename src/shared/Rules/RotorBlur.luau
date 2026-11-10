--!strict
-- How a spinning Lantern rotor reads as it spools to lift (LanternSpool; owner, 2026-11-10:
-- the old swap at 3 s made the blades look gone). Pure, unit-tested with Lune
-- (tests/RotorBlur.spec.luau). Over the last `start` seconds to `full` seconds before lift the
-- blades fade only part way (they stay visible) while the blur disc thickens from nothing to
-- a faint disc, on an eased curve so the change builds instead of popping.

local RotorBlur = {}

export type Settings = {
	start: number, -- seconds before lift the blur begins
	full: number, -- seconds before lift it is complete
	bladeFade: number, -- the blades' LocalTransparencyModifier when complete (< 1: still seen)
	disc: number, -- the blur disc's Transparency when complete
}

-- Smoothstep: slow in, slow out.
local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- (blade transparency modifier, disc transparency) with `remaining` seconds to lift.
function RotorBlur.at(remaining: number, settings: Settings): (number, number)
	local span = math.max(settings.start - settings.full, 1e-6)
	local t = ease(math.clamp((settings.start - remaining) / span, 0, 1))
	return settings.bladeFade * t, 1 - (1 - settings.disc) * t
end

return RotorBlur
