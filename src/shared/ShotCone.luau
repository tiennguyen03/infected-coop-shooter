--!strict
-- Directions inside a gun's shot cone (Rules/Spread does the numbers). The client draws a
-- shotgun's pellets with `random` and sends them; the server takes each one `angleDegrees`
-- off the aim allows (Spread.allowed) and rolls its own for the rest.

local Spread = require(script.Parent.Rules.Spread)

local ShotCone = {}

-- A direction uniform over the cone of `halfAngleDegrees` around `direction` (a unit vector).
function ShotCone.random(direction: Vector3, halfAngleDegrees: number): Vector3
	local angle, roll = Spread.sample(halfAngleDegrees, math.random(), math.random())
	if angle == 0 then
		return direction
	end
	local frame = CFrame.lookAt(Vector3.zero, direction)
	return frame:VectorToWorldSpace(
		Vector3.new(
			math.cos(roll) * math.sin(angle),
			math.sin(roll) * math.sin(angle),
			-math.cos(angle)
		)
	).Unit
end

-- Degrees between two unit vectors.
function ShotCone.angleDegrees(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

return ShotCone
