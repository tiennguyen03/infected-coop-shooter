--!strict
-- Custom over-the-shoulder third-person camera. The default Roblox camera
-- only consumes mouse deltas when its own shift-lock is active, so we take
-- the camera Scriptable and drive it ourselves: yaw/pitch accumulate from
-- raw mouse deltas, the camera hangs behind the right shoulder, and the
-- character's yaw follows the camera. WeaponController aims through the
-- cursor position (screen center while locked), so shots land on the
-- crosshair. Aiming down sights (WeaponController) eases the camera in over the
-- shoulder, narrows the FOV and closes the crosshair; mouse sensitivity scales with the
-- FOV so the sights feel steady. No wall-occlusion handling yet - the arena is open ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PIVOT_HEIGHT = 2 -- studs above the root part, roughly head height
local HIP_FOV = 70
local CROSSHAIR_HIP = 22 -- ring diameter in pixels at the hip
local CROSSHAIR_ADS = 8

local CameraController = {}

local yaw = 0 -- radians
local pitch = math.rad(-10)
local distance: number = Config.Camera.Distance
local aiming = false
local adsBlend = 0 -- 0 = hip, 1 = sights; eased each frame
local crosshairRing: Frame? = nil

function CameraController.setAiming(on: boolean)
	aiming = on
end

local function applyCharacterSettings(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- We rotate the character to the camera yaw ourselves each frame.
	humanoid.AutoRotate = false

	-- Start the camera facing the same way the character spawned.
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local _, rootYaw, _ = root.CFrame:ToOrientation()
	yaw = rootYaw
	pitch = math.rad(-10)
end

local function createCrosshair()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = 0.2
	dot.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	dot.Parent = gui

	-- Spread ring: wide at the hip, closes into the dot while aiming down sights.
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(CROSSHAIR_HIP, CROSSHAIR_HIP)
	ring.BackgroundTransparency = 1
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = ring
	ring.Parent = gui
	crosshairRing = ring

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function consumeMouseInput()
	-- GetMouseDelta only reports while the mouse is locked, which is exactly
	-- the state we hold the mouse in.
	local delta = UserInputService:GetMouseDelta()
	local camera = workspace.CurrentCamera
	local fovScale = if camera then camera.FieldOfView / HIP_FOV else 1
	local sensitivity = math.rad(Config.Camera.Sensitivity)
		* UserSettings():GetService("UserGameSettings").MouseSensitivity
		* fovScale
	yaw -= delta.X * sensitivity
	local maxPitch = math.rad(Config.Camera.MaxPitch)
	pitch = math.clamp(pitch - delta.Y * sensitivity, -maxPitch, maxPitch)
end

local function onRenderStep(deltaTime: number)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Free the cursor while soft-paused (item selection) or dead (death
	-- screen); otherwise hold it locked for aiming.
	local needsCursor = workspace:GetAttribute("GamePaused") == true
		or not humanoid
		or humanoid.Health <= 0
	UserInputService.MouseIconEnabled = needsCursor
	-- Re-assert every frame; Roblox's scripts reset MouseBehavior.
	UserInputService.MouseBehavior = if needsCursor
		then Enum.MouseBehavior.Default
		else Enum.MouseBehavior.LockCenter

	if not camera or not root then
		return
	end

	consumeMouseInput()

	-- Ease between hip and sights over Config.Weapon.ADS.EnterTime.
	local ads = Config.Weapon.ADS
	local target = if aiming then 1 else 0
	local rate = deltaTime / math.max(ads.EnterTime, 0.01)
	adsBlend += math.clamp(target - adsBlend, -rate, rate)
	local shoulder = Config.Camera.ShoulderOffset:Lerp(ads.ShoulderOffset, adsBlend)
	local reach = distance + (ads.CameraDistance - distance) * adsBlend
	camera.FieldOfView = HIP_FOV + (ads.FOV - HIP_FOV) * adsBlend
	local ring = crosshairRing
	if ring then
		local size = CROSSHAIR_HIP + (CROSSHAIR_ADS - CROSSHAIR_HIP) * adsBlend
		ring.Size = UDim2.fromOffset(size, size)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local focus = root.Position
		+ Vector3.new(0, PIVOT_HEIGHT, 0)
		+ rotation:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, 0))
	camera.CFrame = CFrame.new(focus) * rotation * CFrame.new(0, 0, reach)

	-- Character faces the aim direction while alive.
	if humanoid and humanoid.Health > 0 then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
end

local function onInputChanged(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		distance = math.clamp(
			distance - input.Position.Z * 1.5,
			Config.Camera.MinDistance,
			Config.Camera.MaxDistance
		)
	end
end

function CameraController.init()
	local player = Players.LocalPlayer
	UserInputService.MouseIconEnabled = false
	createCrosshair()

	player.CharacterAdded:Connect(applyCharacterSettings)
	if player.Character then
		applyCharacterSettings(player.Character)
	end

	UserInputService.InputChanged:Connect(onInputChanged)

	-- After the default camera update so our settings win each frame.
	RunService:BindToRenderStep("OTSCamera", Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return CameraController
