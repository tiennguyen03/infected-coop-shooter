--!strict
-- The stun-slow helper. Pen Coil (the shock pulse call-in) retired 2026-11-08 as too
-- sci-fi; its slow lives on for the Stun grenade (docs/PROGRESSION.md > Loadout: 0.4x for
-- 3 s in 14 studs). `stunArea` slows (EnemyService.slow) and optionally damages every
-- Infected in a radius, with a quick ring for the look. Owns the "CallInEffects" folder.
-- Nothing calls it yet; the grenade passes its own Config.Grenade numbers.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local EnemyService = require(script.Parent.EnemyService)
local DamageService = require(script.Parent.DamageService)
local Lifecycle = require(script.Parent.Lifecycle)

local ENEMY_TAG = "Enemy"

local ShockCoilService = {}

local effectFolder: Folder

-- Slows every Infected within `radius` of `center` to `factor` for `seconds`, after
-- `damage` (0 for none) credited to `player`. Returns how many it caught.
function ShockCoilService.stunArea(
	player: Player?,
	center: Vector3,
	radius: number,
	factor: number,
	seconds: number,
	damage: number
): number
	local ring = Instance.new("Part")
	ring.Name = "StunRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(230, 230, 220)
	ring.Transparency = 0.5
	ring.Parent = effectFolder
	TweenService:Create(ring, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	task.delay(0.45, function()
		ring:Destroy()
	end)

	local caught = 0
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root then
				if (root.Position - center).Magnitude <= radius then
					caught += 1
					if damage > 0 then
						DamageService.dealDamage(player, humanoid, damage, root.Position, "hit")
					end
					if humanoid.Health > 0 then
						EnemyService.slow(humanoid, factor, seconds)
					end
				end
			end
		end
	end
	return caught
end

function ShockCoilService.reset()
	if effectFolder then
		effectFolder:ClearAllChildren()
	end
end

function ShockCoilService.init()
	Lifecycle.register("ShockCoilService", {
		onRunStart = ShockCoilService.reset,
	})
	effectFolder = Instance.new("Folder")
	effectFolder.Name = "CallInEffects"
	effectFolder.Parent = workspace
end

return ShockCoilService
