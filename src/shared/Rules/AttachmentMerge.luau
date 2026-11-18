--!strict
-- What fitted attachments do to a gun's aiming, as pure maths (tests/AttachmentMerge.spec.luau).
-- Each attachment's row may carry multipliers; they apply on top of the gun's own values, in
-- turn, so two that both change zoom multiply. The gun's row is never changed. First used by
-- the M16A4's optics (Config.Optics: zoomMultiplier on Sight.Zoom, adsTimeMultiplier on the
-- time into the sights; CameraController). The suppressor's quiet shot stays its own rule
-- (WeaponDefinitions.shotNoise): it replaces a value rather than scaling one.

local AttachmentMerge = {}

export type Stats = {
	zoom: number, -- magnification over the hip view (Rules/Sight)
	adsTime: number, -- seconds into the sights
}

export type Modifier = {
	zoomMultiplier: number?,
	adsTimeMultiplier: number?,
}

-- A multiplier that means something: above zero and a real number; anything else is 1.
local function factor(value: number?): number
	if value == nil or value ~= value or value <= 0 or value == math.huge then
		return 1
	end
	return value
end

function AttachmentMerge.apply(base: Stats, modifiers: { Modifier }): Stats
	local zoom, adsTime = base.zoom, base.adsTime
	for _, modifier in modifiers do
		zoom *= factor(modifier.zoomMultiplier)
		adsTime *= factor(modifier.adsTimeMultiplier)
	end
	return { zoom = zoom, adsTime = adsTime }
end

return AttachmentMerge
