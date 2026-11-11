--!strict
-- The first-person sight picture as pure maths (tests/Sight.spec.luau; no Roblox APIs beyond
-- arithmetic on the vectors it is handed, so Lune runs it). A gun row's `Sight`
-- (Config.Weapons.<id>.Sight) names two points on its mesh, from the grip, barrel along -Z:
--   Rear:  the centre of the rear aperture, the top of the rear notch, a scope's eyepiece;
--   Front: the tip of the front post, the bead, a scope's objective.
-- The eye goes on the line through them, EyeRelief behind Rear, looking at Front: the front
-- sight is then dead centre behind the rear one, which is where the shot goes (the round
-- leaves the barrel toward the point under the screen's centre). FirstPersonView places the
-- gun from this; CameraController takes the aimed field of view and the scope's phases.

local Sight = {}

export type Kind = "irons" | "scope"
-- How the gun is carried at the hip (Config.Weapon.Sights.Hold has the grip's place for each).
export type Hold = "long" | "sidearm" | "shoulder"

-- A gun row's sight as written in Config: only the two points are required.
export type Raw = {
	Rear: Vector3,
	Front: Vector3,
	Kind: string?,
	Hold: string?,
	EyeRelief: number?,
	Zoom: number?,
}

export type Resolved = {
	Kind: Kind,
	Hold: Hold,
	Rear: Vector3,
	Front: Vector3,
	EyeRelief: number, -- studs from the eye to Rear, at the gun's real size
	Zoom: number, -- magnification over the hip view
}

export type Defaults = {
	Zoom: number,
	ScopeZoom: number,
	EyeRelief: { [string]: number }, -- by Hold
	ScopeRelief: number,
}

-- What a sane sight looks like (Sight.problems); validation, not tuning.
Sight.LIMITS = {
	MinRadius = 0.25, -- studs between Rear and Front
	MaxTilt = 2, -- degrees between the sight line and the bore
	MaxOverBore = 0.45, -- studs the rear sight may stand off the bore
	MaxParallax = 0.5, -- degrees between sight line and bore at the zero distance
	IronsRelief = { 0.2, 1.5 },
	ScopeRelief = { 0.2, 0.5 },
	IronsZoom = { 1, 2 },
	ScopeZoom = { 2, 10 },
}

function Sight.resolve(raw: Raw, defaults: Defaults): Resolved
	-- A misspelt Kind or Hold is kept as written: Sight.problems names it (the spec).
	local kind: Kind = (raw.Kind or "irons") :: any
	local hold: Hold = (raw.Hold or "long") :: any
	local scoped = kind == "scope"
	local relief = raw.EyeRelief
	if not relief then
		relief = if scoped
			then defaults.ScopeRelief
			else defaults.EyeRelief[hold] or defaults.EyeRelief.long
	end
	return {
		Kind = kind,
		Hold = hold,
		Rear = raw.Rear,
		Front = raw.Front,
		EyeRelief = relief :: number,
		Zoom = raw.Zoom or if scoped then defaults.ScopeZoom else defaults.Zoom,
	}
end

-- The vertical field of view (degrees) that shows the world `zoom` times larger than
-- `hipFov` does: tan(fov / 2) = tan(hipFov / 2) / zoom.
function Sight.fov(hipFov: number, zoom: number): number
	return math.deg(2 * math.atan(math.tan(math.rad(hipFov) / 2) / math.max(zoom, 0.01)))
end

-- Where the eye goes, in the gun's space: on the sight line, `relief` behind the rear sight.
function Sight.eye(rear: Vector3, front: Vector3, relief: number): Vector3
	local back = rear - front
	return rear + back / math.max(back.Magnitude, 1e-6) * relief
end

-- Degrees between the sight line and the bore (the gun's -Z).
function Sight.tilt(rear: Vector3, front: Vector3): number
	local along = front - rear
	return math.deg(math.acos(math.clamp(-along.Z / math.max(along.Magnitude, 1e-6), -1, 1)))
end

-- Degrees the bore must turn toward the sight line, `offset` studs away, for the two to
-- meet `distance` studs out (the zero).
function Sight.parallax(offset: number, distance: number): number
	if distance <= 0 then
		return 90
	end
	return math.deg(math.atan(offset / distance))
end

-- The viewmodel is drawn shrunk toward the eye by `base` (it looks the same and walls do not
-- cut into it). A sight `clearance` studs from the eye at full size would then fall inside the
-- camera's near plane (`near` studs) and vanish: grow the scale until it clears by `margin`,
-- never past full size.
function Sight.viewScale(base: number, near: number, clearance: number, margin: number): number
	if clearance <= 0 then
		return 1
	end
	return math.clamp(near * margin / clearance, base, 1)
end

local function smooth(t: number, a: number, b: number): number
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Aiming, `ads` 0 at the hip to 1 down the sights, as (raise: the gun to the eye, zoom: the
-- field of view toward the aimed one, shade: the scope picture over the screen). Irons raise
-- and zoom together. A scope comes up first, then the picture closes in while the view zooms,
-- so the eye never sees the zoomed gun.
function Sight.phases(scoped: boolean, ads: number): (number, number, number)
	local t = math.clamp(ads, 0, 1)
	if not scoped then
		return t, t, 0
	end
	return math.min(t / 0.55, 1), smooth(t, 0.55, 1), smooth(t, 0.5, 0.85)
end

-- How black the lens is while the picture arrives (`shade` 0..1): the eye passing the
-- eyepiece. FirstPersonView swaps the gun out at the darkest moment.
function Sight.blink(shade: number): number
	return 4 * shade * (1 - shade)
end

-- A kick of so many degrees moves a magnified picture further across the screen: scale it
-- down by the square root of the extra zoom over the standard sights (never up).
function Sight.kickScale(zoom: number, standardZoom: number): number
	return math.min(math.sqrt(standardZoom / math.max(zoom, 0.01)), 1)
end

-- Everything wrong with a gun's sight, as text (none: it is sane). `muzzle` is the barrel tip
-- from the grip, `zero` the distance at which the sights and the shot must agree.
function Sight.problems(sight: Resolved, muzzle: Vector3, zero: number): { string }
	local limits = Sight.LIMITS
	local problems = {}
	local function check(ok: boolean, text: string)
		if not ok then
			table.insert(problems, text)
		end
	end
	local kind, hold = sight.Kind :: string, sight.Hold :: string
	local scoped = kind == "scope"
	check(kind == "irons" or scoped, `unknown Kind "{kind}"`)
	check(hold == "long" or hold == "sidearm" or hold == "shoulder", `unknown Hold "{hold}"`)
	local rear, front = sight.Rear, sight.Front
	check(
		rear.Z - front.Z >= limits.MinRadius,
		"Front must be ahead of Rear (-Z) by a sight radius"
	)
	check(front.Z >= muzzle.Z - 0.05, "Front is beyond the muzzle")
	local tilt = Sight.tilt(rear, front)
	check(
		tilt <= limits.MaxTilt,
		`the sight line is {string.format("%.1f", tilt)} degrees off the bore`
	)
	-- The rear sight's place over the barrel's axis.
	local up, side = rear.Y - muzzle.Y, rear.X - muzzle.X
	local offBore = math.sqrt(up * up + side * side)
	check(up > 0, "the sight line is not above the bore")
	check(offBore <= limits.MaxOverBore, "Rear stands too far off the bore")
	check(
		Sight.parallax(offBore, zero) <= limits.MaxParallax,
		"sight line and bore do not agree at the zero distance"
	)
	local relief = if scoped then limits.ScopeRelief else limits.IronsRelief
	check(
		sight.EyeRelief >= relief[1] and sight.EyeRelief <= relief[2],
		`EyeRelief {sight.EyeRelief} outside {relief[1]}..{relief[2]}`
	)
	-- The eye is behind the rear sight (and so behind the front one).
	check(Sight.eye(rear, front, sight.EyeRelief).Z > rear.Z, "the eye is not behind Rear")
	local zoom = if scoped then limits.ScopeZoom else limits.IronsZoom
	check(
		sight.Zoom >= zoom[1] and sight.Zoom <= zoom[2],
		`Zoom {sight.Zoom} outside {zoom[1]}..{zoom[2]}`
	)
	return problems
end

return Sight
