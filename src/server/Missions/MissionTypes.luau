--!strict
-- The shapes of a mission's layout (docs/ARCHITECTURE.md F6): every mission file in this
-- folder returns a `Mission` built from these, and ArenaService builds whichever mission is
-- current (`Missions.current()`). Field notes live with each type.

export type Hill = {
	name: string,
	x: number,
	z: number,
	top: Vector2,
	height: number,
	base: number?,
	open: { [string]: boolean }?,
}
export type Dressing = {
	name: string,
	x: number,
	z: number,
	yaw: number,
	burning: boolean?,
	lift: number?,
	shell: boolean?,
	shadow: boolean?,
	floor: number?, -- ground height to use instead of the raycast (a piece inside a building)
	-- Scenery past the perimeter (A15): no collision, no queries, no shadow, no colliders.
	decor: boolean?,
	-- A perch container whose own pallet ramp runs under its footprint by design: the
	-- straddle check skips it (every other piece must stand on one flat height).
	perch: boolean?,
}

export type Patch = { x: number, z: number, w: number, d: number, kind: string, yaw: number? }

export type Ramp =
	{ x: number, z: number, yaw: number, rise: number, base: number, length: number? }

export type FencePanel = { x: number, z: number, yaw: number }

export type Side = string -- "south" | "north" | "east" | "west"
export type Opening = {
	kind: string, -- "door" | "window" | "breach" | "gap"
	at: number, -- along the wall, from its centre (south/north: +x, east/west: +z)
	width: number?,
	sill: number?, -- window only (0 = an arch from the floor)
	head: number?, -- top of the opening (door / window / breach)
}
-- A straight flight against `side`, bottom end at `at` along that wall, rising toward
-- `dir` (+1 / -1 along the wall) from the floor of `storey` by `rise` (default one storey).
export type StairSpec = { side: Side, at: number, dir: number, storey: number, rise: number? }
-- A TrussPart against `side` at `at`, from `bottom` (default the ground) to `top`; `inside`
-- puts it inside the wall (the slabs above get a hole for the climber).
export type LadderSpec = { side: Side, at: number, top: number, bottom: number?, inside: boolean? }
-- A wall inside the footprint along x or z at `at`, between `from` and `to` on the other axis.
export type InteriorWall = {
	along: string, -- "x" | "z"
	at: number,
	from: number,
	to: number,
	storey: number,
	openings: { Opening }?,
}
-- A partial slab (choir loft, workshop mezzanine) with an optional rail on one edge.
export type Mezzanine =
	{ x0: number, x1: number, z0: number, z1: number, level: number, rail: Side? }
-- A plain Part in the building's frame (catwalk, canopy, columns): `at` is its centre.
export type Extra = {
	name: string,
	size: Vector3,
	at: Vector3,
	material: string?,
	class: string?,
	yaw: number?,
}
export type BuildingSpec = {
	name: string,
	x: number,
	z: number,
	yaw: number?,
	width: number,
	depth: number,
	storeys: number,
	storeyHeight: number?, -- default Config.Arena.Kit.Storey
	material: string, -- Config.Arena.Materials key
	walls: { { [string]: { Opening } } }, -- [storey][side]
	interior: { InteriorWall }?,
	stairs: { StairSpec }?,
	ladders: { LadderSpec }?,
	mezzanines: { Mezzanine }?,
	extras: { Extra }?,
	roof: boolean?, -- default true
	parapet: boolean?, -- default true
	lips: boolean?, -- default true
}

-- One mission: its id and name and the layout tables ArenaService builds from.
export type Mission = {
	Id: string,
	Name: string,
	Hills: { Hill },
	Dressing: { Dressing }, -- placed pieces (props already merged in)
	Patches: { Patch },
	Ramps: { Ramp },
	Perimeter: { Dressing }, -- scenery past the fence (decor)
	Fence: { FencePanel },
	Buildings: { BuildingSpec },
}

return {}
