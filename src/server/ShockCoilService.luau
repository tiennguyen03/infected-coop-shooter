--!strict
-- Pen Coil (Shock Coil call-in, CallInService): a pulse around the user that damages and
-- slows every Infected within Config.CallIns.PenCoil.Radius (the slow lives in
-- EnemyService.slow). Ground Strap (defibrillator upgrade): the same pulse stands up every
-- downed squadmate in its radius (Squad.revive).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyService = require(script.Parent.EnemyService)
local DamageService = require(script.Parent.DamageService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)

local ENEMY_TAG = "Enemy"

local ShockCoilService = {}

local effectFolder: Folder

-- Fires the pulse where `player` stands. `revive` is the Ground Strap flag. False when the
-- player has no body.
function ShockCoilService.pulse(player: Player, revive: boolean): boolean
	local member = Squad.fromPlayer(player)
	local root = member and member.root
	if not member or not root then
		return false
	end
	local cfg = Config.CallIns.PenCoil

	local ring = Instance.new("Part")
	ring.Name = "CoilPulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, cfg.Radius * 2, cfg.Radius * 2)
	ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 180, 255)
	ring.Transparency = 0.4
	ring.Parent = effectFolder
	TweenService
		:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		})
		:Play()
	task.delay(0.45, function()
		ring:Destroy()
	end)

	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local enemyRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and enemyRoot then
				if (enemyRoot.Position - root.Position).Magnitude <= cfg.Radius then
					DamageService.dealDamage(
						player,
						humanoid,
						cfg.Damage,
						enemyRoot.Position,
						"hit"
					)
					if humanoid.Health > 0 then
						EnemyService.slow(humanoid, cfg.SlowFactor, cfg.SlowDuration)
					end
				end
			end
		end
	end

	if revive then
		for _, downed in Squad.downed() do
			local downedRoot = downed.root
			if
				downed ~= member
				and downedRoot
				and (downedRoot.Position - root.Position).Magnitude <= cfg.Radius
			then
				Squad.revive(downed, member)
			end
		end
	end
	return true
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
