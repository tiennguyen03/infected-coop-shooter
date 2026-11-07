--!strict
-- Finds the ledge in front of a humanoid: the solid cover it is walking into, the height of
-- that cover's top above the feet, and where the body ends up after going over or onto it.
-- Shared by the player's vault/climb (client MovementController) and the Infected climb
-- (server EnemyService) so both read the same world. Numbers come from Config.Movement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Ledge = {
	part: BasePart, -- the cover
	height: number, -- top above the feet
	topY: number,
	over: boolean, -- true: thin cover with ground behind, the body goes over it
	-- Root positions (root centre) at the top of the move and where it lands.
	apex: Vector3,
	landing: Vector3,
	forward: Vector3, -- flat unit direction of the move
}

local Ledge = {}

local function isStatic(part: BasePart): boolean
	if not part.Anchored or not part.CanCollide then
		return false
	end
	local model = part:FindFirstAncestorOfClass("Model")
	return not (model and model:FindFirstChildOfClass("Humanoid"))
end

local function castDown(origin: Vector3, length: number, params: RaycastParams): RaycastResult?
	return workspace:Raycast(origin, Vector3.new(0, -length, 0), params)
end

-- `forward` is any flat direction (the move direction, the way to the target); `maxHeight`
-- is the tallest top this body can take. `params` excludes the body itself.
function Ledge.find(
	root: BasePart,
	humanoid: Humanoid,
	forward: Vector3,
	maxHeight: number,
	params: RaycastParams
): Ledge?
	local settings = Config.Movement
	local flat = Vector3.new(forward.X, 0, forward.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	flat = flat.Unit
	local rootOffset = humanoid.HipHeight + root.Size.Y / 2 -- root centre above the feet
	local feetY = root.Position.Y - rootOffset

	-- The cover: a ray at knee height, then one at the chest.
	local wall: RaycastResult? = nil
	for _, y in { feetY + 1, root.Position.Y } do
		local origin = Vector3.new(root.Position.X, y, root.Position.Z)
		local hit = workspace:Raycast(origin, flat * settings.Reach, params)
		if hit and hit.Instance:IsA("BasePart") and isStatic(hit.Instance) then
			wall = hit
			break
		end
	end
	if not wall then
		return nil
	end
	local part = wall.Instance :: BasePart

	-- Taller than the body can take (cover rotates about Y only, so the box top is exact
	-- enough): no ledge. Guards the top ray from starting inside the part.
	local boxTop = part.Position.Y + part.Size.Y / 2
	if boxTop - feetY > maxHeight + 0.5 then
		return nil
	end

	-- The top: straight down from above the cover, just past its face.
	local probe = wall.Position + flat * 0.6
	local top =
		castDown(Vector3.new(probe.X, feetY + maxHeight + 0.5, probe.Z), maxHeight + 0.5, params)
	if not top then
		return nil
	end
	local height = top.Position.Y - feetY
	if height < settings.MinHeight or height > maxHeight then
		return nil
	end
	-- Room to stand on it.
	if
		workspace:Raycast(
			top.Position + Vector3.new(0, 0.2, 0),
			Vector3.new(0, settings.Headroom, 0),
			params
		)
	then
		return nil
	end

	local topY = top.Position.Y
	-- Thin cover with ground behind it: go over and land on the far side.
	if height <= settings.VaultMaxHeight then
		local far = wall.Position + flat * settings.VaultDepth
		local clearance = Vector3.new(0, topY + 1.5, 0)
		local lineStart = Vector3.new(wall.Position.X, 0, wall.Position.Z) + clearance
		local blocked = workspace:Raycast(lineStart, flat * settings.VaultDepth, params)
		local ground = castDown(Vector3.new(far.X, topY + 1, far.Z), topY + 1 - (feetY - 3), params)
		if not blocked and ground and ground.Position.Y <= feetY + 1.5 then
			return {
				part = part,
				height = height,
				topY = topY,
				over = true,
				apex = Vector3.new(probe.X, topY + rootOffset + 0.4, probe.Z),
				landing = ground.Position + Vector3.new(0, rootOffset, 0),
				forward = flat,
			}
		end
	end

	-- Onto the top.
	local landingXZ = wall.Position + flat * 1.6
	local landingTop = castDown(Vector3.new(landingXZ.X, topY + 2, landingXZ.Z), 2.5, params)
	local landingY = if landingTop then landingTop.Position.Y else topY
	return {
		part = part,
		height = height,
		topY = topY,
		over = false,
		apex = Vector3.new(probe.X, landingY + rootOffset + 0.3, probe.Z),
		landing = Vector3.new(landingXZ.X, landingY + rootOffset, landingXZ.Z),
		forward = flat,
	}
end

-- Where the root is at `alpha` (0..1) of a move: up to the apex, then across to the
-- landing. Eased so the body hangs at the top for a beat.
function Ledge.position(start: Vector3, ledge: Ledge, alpha: number): Vector3
	local riseEnd = if ledge.over then 0.45 else 0.55
	if alpha < riseEnd then
		local t = alpha / riseEnd
		t = t * t * (3 - 2 * t)
		return start:Lerp(ledge.apex, t)
	end
	local t = (alpha - riseEnd) / (1 - riseEnd)
	t = t * t * (3 - 2 * t)
	return ledge.apex:Lerp(ledge.landing, t)
end

return Ledge
