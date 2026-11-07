--!strict
-- Where a thrown thing lands: the requested aim point clamped to the thrower's reach,
-- stopped short of any wall in the way and dropped to the ground. Shared by the breach
-- charge (server), the red flare (server) and the client's aim ghosts so all agree.

local ThrowUtil = {}

function ThrowUtil.landingPoint(
	root: BasePart,
	requested: Vector3?,
	maxDistance: number,
	exclude: { Instance }
): Vector3
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
	local reach = maxDistance
	if requested then
		local flat = Vector3.new(requested.X - root.Position.X, 0, requested.Z - root.Position.Z)
		if flat.Magnitude > 0.5 then
			dir = flat.Unit
			reach = math.min(flat.Magnitude, maxDistance)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local wall = workspace:Raycast(root.Position, dir * reach, params)
	local landXZ = if wall then wall.Position - dir * 2 else root.Position + dir * reach
	local ground =
		workspace:Raycast(landXZ + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0), params)
	return if ground then ground.Position else landXZ
end

return ThrowUtil
