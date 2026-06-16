--!strict
-- Hold left mouse button to fire. Aims from the character toward whatever
-- the cursor is pointing at, then asks the server to spawn the projectile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundFX = require(script.Parent.SoundFX)

local WeaponController = {}

local isFiring = false
local lastFireTime = 0

local function getAimPoint(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	local projectiles = workspace:FindFirstChild("Projectiles")
	if projectiles then
		table.insert(exclude, projectiles)
	end
	params.FilterDescendantsInstances = exclude

	local result =
		workspace:Raycast(ray.Origin, ray.Direction * Config.Weapon.MaxAimDistance, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * Config.Weapon.MaxAimDistance
end

local function tryFire()
	if workspace:GetAttribute("GamePaused") == true then
		return
	end

	local now = os.clock()
	local fireRateMult = (Players.LocalPlayer:GetAttribute("FireRateMult") :: number?) or 1
	if now - lastFireTime < Config.Weapon.FireCooldown / fireRateMult then
		return
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local aimPoint = getAimPoint()
	if not aimPoint then
		return
	end

	-- Fire from the rifle muzzle when present (falls back to chest height).
	local rifle = character and character:FindFirstChild("Rifle")
	local muzzle = rifle and rifle:FindFirstChild("Muzzle") :: BasePart?
	local origin = if muzzle then muzzle.Position else root.Position + Vector3.new(0, 1, 0)
	local direction = aimPoint - origin
	if direction.Magnitude < 0.001 then
		return
	end

	lastFireTime = now
	Remotes.get("FireWeapon"):FireServer(origin, direction.Unit)

	-- Local-only muzzle flash and shot sound for instant feedback.
	SoundFX.play("shoot")
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.7, 0.7, 0.7)
	flash.Position = origin + direction.Unit * 1.5
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 220, 120)
	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 10
	light.Color = flash.Color
	light.Parent = flash
	flash.Parent = workspace
	task.delay(0.05, function()
		flash:Destroy()
	end)
end

function WeaponController.init()
	-- The rifle is a Tool, but it's always equipped — hide the backpack hotbar.
	local StarterGui = game:GetService("StarterGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if isFiring then
			tryFire()
		end
	end)
end

return WeaponController
