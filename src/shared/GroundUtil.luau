--!strict
-- Small grounding helper: drops a world position onto the floor via a downward
-- raycast so floor effects (fire pools, air-strike markers, plague rats) sit on
-- the ground instead of at the height of whatever spawned them (usually an
-- enemy's torso). Characters and enemies are excluded; effect parts already set
-- CanQuery = false so the raycast skips them automatically.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ENEMY_TAG = "Enemy"
local CAST_HEIGHT = 60
local CAST_DEPTH = 240
local DEFAULT_OFFSET = 0.05

local GroundUtil = {}

local function buildParams(extraIgnore: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		table.insert(ignore, model)
	end
	if extraIgnore then
		for _, inst in extraIgnore do
			table.insert(ignore, inst)
		end
	end

	params.FilterDescendantsInstances = ignore
	return params
end

-- Floor position directly below `position`, raised by `yOffset` (default a hair
-- above the surface to avoid z-fighting). Falls back to `position` on a miss.
-- Iterates so it skips any character/corpse the tag/character filter missed —
-- e.g. an enemy untagged at the instant of death, which would otherwise be hit
-- directly below the kill point and leave the effect floating at torso height.
function GroundUtil.GetGroundPosition(
	position: Vector3,
	yOffset: number?,
	extraIgnore: { Instance }?
): Vector3
	local origin = Vector3.new(position.X, position.Y + CAST_HEIGHT, position.Z)
	local direction = Vector3.new(0, -CAST_DEPTH, 0)
	local params = buildParams(extraIgnore)
	local ignore = params.FilterDescendantsInstances
	local offset = yOffset or DEFAULT_OFFSET

	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			break
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			-- Hit a character/corpse: ignore it and cast again for the floor.
			table.insert(ignore, model)
			params.FilterDescendantsInstances = ignore
		else
			return hit.Position + Vector3.new(0, offset, 0)
		end
	end
	return position
end

function GroundUtil.GetGroundCFrame(
	position: Vector3,
	yOffset: number?,
	extraIgnore: { Instance }?
): CFrame
	return CFrame.new(GroundUtil.GetGroundPosition(position, yOffset, extraIgnore))
end

return GroundUtil
