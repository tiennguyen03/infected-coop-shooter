--!strict
-- Measures the world for a binoculars mark (Rules/Spotting decides what the numbers are
-- worth). Shared by the client (BinocularController: the marker under the crosshair) and
-- the server (CallInService: the same mark checked again from the soldier's head), so both
-- agree, like ThrowUtil for a throw.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local Spotting = require(script.Parent.Rules.Spotting)

local ENEMY_TAG = "Enemy"
local UP = Vector3.yAxis
-- Folders a line of sight passes through (effects, pickups, kit on the ground).
local PASS_THROUGH = {
	"Resupply",
	"ResupplyCards",
	"Sentries",
	"Wire",
	"SupplyDrops",
	"Mines",
	"FirePools",
	"KitEffects",
	"CallInEffects",
	"StrikeEffects",
	"Projectiles",
	"InfectedProjectiles",
	"Tracers",
	"Drones",
	"GrenadeGhost",
	"SquadBots",
}

local SpotUtil = {}

-- The binoculars settings of a call-in's Config row: its own block over the shared one.
function SpotUtil.settings(row: { [string]: any }?): Spotting.Settings
	return Spotting.resolve(Config.CallIns.Binoculars :: any, row and row.Binoculars)
end

-- What a sight line ignores: effects and the squad's bodies, plus the Infected when
-- `bodies` is true (a crowd never hides the ground behind it).
function SpotUtil.exclusions(bodies: boolean): { Instance }
	local exclude: { Instance } = {}
	for _, name in PASS_THROUGH do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	if bodies then
		for _, model in CollectionService:GetTagged(ENEMY_TAG) do
			table.insert(exclude, model)
		end
	end
	return exclude
end

local function paramsFor(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- Where the eye is for a body: its Head, else a little above the root.
function SpotUtil.eye(character: Model): Vector3?
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + UP * 1.5
	end
	return nil
end

-- The ground point under a look from `eye` along `direction`: the first surface in the
-- way, and when that is a wall or a body, the ground at its foot. Nil when the look meets
-- nothing (sky). `seen` excludes effects and the squad; `clear` the Infected too.
function SpotUtil.sight(
	eye: Vector3,
	direction: Vector3,
	settings: Spotting.Settings,
	seen: { Instance },
	clear: { Instance }
): Vector3?
	local hit =
		workspace:Raycast(eye, direction.Unit * Config.Weapon.MaxAimDistance, paramsFor(seen))
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	local onBody = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
	if not onBody and hit.Normal.Y >= settings.MinSlope then
		return hit.Position
	end
	-- A wall or a body: step off it and drop to the ground at its foot.
	local from = hit.Position + hit.Normal + UP * 0.5
	local ground = workspace:Raycast(from, -UP * 400, paramsFor(clear))
	return if ground then ground.Position else nil
end

-- Measures the mark at `point` as seen from `eye` (`clear` from SpotUtil.exclusions(true)).
function SpotUtil.measure(
	eye: Vector3,
	point: Vector3,
	settings: Spotting.Settings,
	clear: { Instance }
): Spotting.Measured
	local params = paramsFor(clear)
	-- The view: from the eye to a little above the mark, so grass and kerbs do not hide it.
	local line = point + UP * settings.SightLift - eye
	local length = line.Magnitude
	local blocked: number? = nil
	if length > 0.01 then
		local wall = workspace:Raycast(eye, line, params)
		if wall then
			blocked = length - (wall.Position - eye).Magnitude
		end
	end
	-- The ground: the nearest surface under (or just over) the mark.
	local probe = settings.GroundProbe :: number
	local floor = workspace:Raycast(point + UP * probe, -UP * probe * 2, params)
	return {
		distance = (point - eye).Magnitude,
		blocked = blocked,
		ground = if floor then math.abs(floor.Position.Y - point.Y) else nil,
		slope = if floor then floor.Normal.Y else nil,
	}
end

return SpotUtil
