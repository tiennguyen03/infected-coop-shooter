--!strict
-- How a soldier's four directional locomotion clips are mixed (pure; tests/MoveBlend.spec.luau).
-- Used by SoldierLocomotion, which the match's AnimationController and the lobby's
-- SoldierMoves both drive.

local MoveBlend = {}

export type Weights = { forward: number, back: number, left: number, right: number }

MoveBlend.DIRECTIONS = { "forward", "back", "left", "right" }
MoveBlend.MIN_RATE = 0.6
MoveBlend.MAX_RATE = 1.8

-- Blend weights from the direction of travel in the body's frame: the body faces -Z, +X is
-- its right. Diagonals split between two clips; directions missing from `available` (any
-- table keyed by direction, e.g. a set's tracks) go to forward.
function MoveBlend.weights(localX: number, localZ: number, available: { [string]: any }): Weights
	local forward = math.max(0, -localZ)
	local back = math.max(0, localZ)
	local right = math.max(0, localX)
	local left = math.max(0, -localX)
	local total = forward + back + right + left
	if total <= 0 then
		return { forward = 1, back = 0, left = 0, right = 0 }
	end
	local weights: { [string]: number } = {
		forward = forward / total,
		back = back / total,
		left = left / total,
		right = right / total,
	}
	for _, direction in MoveBlend.DIRECTIONS do
		if direction ~= "forward" and not available[direction] then
			weights.forward += weights[direction]
			weights[direction] = 0
		end
	end
	return weights :: any
end

-- Playback rate of a clip cut for `reference` studs/s at `speed` studs/s, so feet do not
-- slide. A clip with no measured speed plays at 1.
function MoveBlend.rate(speed: number, reference: number?): number
	if not reference or reference <= 0 then
		return 1
	end
	return math.clamp(speed / reference, MoveBlend.MIN_RATE, MoveBlend.MAX_RATE)
end

return MoveBlend
