--!strict
-- Spotting (docs/PROGRESSION.md > Binoculars): a call-in marked through binoculars instead
-- of thrown. Pure, unit-tested with Lune (tests/Spotting.spec.luau). A call-in's row in
-- Config.CallIns says `AimMode = "Binoculars"` (default "Throw") and may carry a
-- `Binoculars` block laid over Config.CallIns.Binoculars. The world is measured elsewhere
-- (SpotUtil casts the rays, on the client for the marker and again on the server from the
-- soldier's head); this decides what a measured mark is worth, when the binoculars go up
-- and down, and how far up they are.

local Spotting = {}

export type Mode = "Throw" | "Binoculars"
export type State = "Lowered" | "Raised"
export type Event = "key" | "fire" | "cancel"
export type Action = "raise" | "lower" | "fire"
-- Why a mark is refused: past MaxRange, inside MinRange, hidden from the eye, not on ground.
export type Reason = "range" | "close" | "sight" | "ground"

export type Settings = {
	MaxRange: number, -- studs from the eye
	MinRange: number,
	FieldOfView: number, -- degrees, through the glass
	Raise: number, -- seconds to bring them up
	Lower: number,
	MinSlope: number, -- the ground's normal.Y at the mark: below this it is a wall
	-- What the server forgives (the client's eye and the server's head never quite agree).
	Slack: { Range: number, Sight: number, Ground: number, Raise: number },
	[string]: any,
}

-- What SpotUtil measured for one mark.
export type Measured = {
	distance: number, -- studs from the eye to the mark
	blocked: number?, -- studs short of the mark the view stops at; nil when it is seen
	ground: number?, -- studs between the mark and the ground under it; nil = nothing there
	slope: number?, -- that ground's normal.Y
}

-- The client's own leeway for a mark sitting a hair off the surface it was read from.
local GROUND_EPSILON = 0.5

-- How a call-in's row is aimed.
function Spotting.mode(row: { [string]: any }?): Mode
	return if row and row.AimMode == "Binoculars" then "Binoculars" else "Throw"
end

-- `overrides` (a row's Binoculars block, or nil) over `defaults`. Neither table is changed.
function Spotting.resolve(defaults: { [string]: any }, overrides: { [string]: any }?): Settings
	local resolved = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			resolved[key] = value
		end
	end
	return resolved :: any
end

-- Whether a measured mark may be fired on. `forgiving` (the server) allows the Slack.
function Spotting.check(settings: Settings, mark: Measured, forgiving: boolean): (boolean, Reason?)
	local slack = settings.Slack
	local rangeSlack = if forgiving then slack.Range else 0
	local sightSlack = if forgiving then slack.Sight else 0
	local groundSlack = if forgiving then slack.Ground else GROUND_EPSILON
	if mark.distance > settings.MaxRange + rangeSlack then
		return false, "range"
	end
	if mark.distance < settings.MinRange - rangeSlack then
		return false, "close"
	end
	local ground, slope = mark.ground, mark.slope
	if not ground or not slope or ground > groundSlack or slope < settings.MinSlope then
		return false, "ground"
	end
	local blocked = mark.blocked
	if blocked and blocked > sightSlack then
		return false, "sight"
	end
	return true, nil
end

-- The binoculars' two states. `ready`: they are fully up and the mark is good.
function Spotting.next(state: State, event: Event, ready: boolean): (State, Action?)
	if state == "Lowered" then
		if event == "key" then
			return "Raised", "raise"
		end
		return "Lowered", nil
	end
	if event == "fire" then
		if ready then
			return "Lowered", "fire"
		end
		return "Raised", nil
	end
	return "Lowered", "lower"
end

-- Server: a mark counts only from binoculars that have been up for the raise.
function Spotting.canConfirm(raisedFor: number?, settings: Settings): boolean
	return raisedFor ~= nil and raisedFor >= settings.Raise - settings.Slack.Raise
end

-- How far up the binoculars are (0 down, 1 at the eyes) after `dt` more seconds.
function Spotting.blend(
	alpha: number,
	raised: boolean,
	dt: number,
	raise: number,
	lower: number
): number
	local seconds = if raised then raise else lower
	if seconds <= 0 then
		return if raised then 1 else 0
	end
	local step = dt / seconds
	return math.clamp(if raised then alpha + step else alpha - step, 0, 1)
end

-- The camera's field of view `alpha` of the way into the glass.
function Spotting.fov(base: number, zoomed: number, alpha: number): number
	return base + (zoomed - base) * math.clamp(alpha, 0, 1)
end

-- The range readout: whole metres.
function Spotting.rangeText(studs: number, metresPerStud: number): string
	return `{math.floor(math.max(studs, 0) * metresPerStud + 0.5)} M`
end

return Spotting
