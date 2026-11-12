--!strict
-- Custom over-the-shoulder third-person camera. The default Roblox camera
-- only consumes mouse deltas when its own shift-lock is active, so we take
-- the camera Scriptable and drive it ourselves: yaw/pitch accumulate from
-- raw mouse deltas, the camera hangs behind the right shoulder, and the
-- character's yaw follows the camera. WeaponController aims through the
-- cursor position (screen center while locked), so shots land on the
-- crosshair. Aiming down sights (WeaponController) eases the camera in over the
-- shoulder, narrows the FOV and closes the crosshair; mouse sensitivity scales with the
-- FOV so the sights feel steady. The pivot drops with the stance (StanceController) and the
-- body's yaw can be locked while a vault/climb carries it (MovementController). No
-- wall-occlusion handling yet - the arena is open ground.
--
-- First person (Config.Camera.FirstPerson): T toggles it, or the wheel past the closest zoom.
-- The same yaw, pitch, kick, shake and sights, the eye on the Head instead of behind the
-- shoulder; this soldier's own body is hidden on this client, and FirstPersonView shows its
-- arms and gun. Down the sights in first person the crosshair fades out and the gun's own
-- sights aim (its row's Sight, Rules/Sight): the field of view narrows by that gun's Zoom,
-- and a scope draws its picture (ScopeView) while the gun is hidden. A reload or a Q swap
-- lowers the gun out of the sights until it is done. Third person keeps the shared
-- Config.Weapon.ADS view for every gun.
--
-- Binoculars (setScope, BinocularController): the same eye on the Head with a much narrower
-- view, from either camera mode; the gun's view model and scope picture are put away while
-- they are up.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local Feel =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Feel"))
local Spotting =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Spotting"))
local Sight =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Sight"))
local FirstPersonView = require(script.Parent.FirstPersonView)
local ScopeView = require(script.Parent.ScopeView)

local HIP_FOV = 70
local CROSSHAIR_HIP = 22 -- ring diameter in pixels at the hip
local CROSSHAIR_ADS = 8
local CROSSHAIR_PER_BLOOM = 10 -- extra ring diameter (px) per degree of bloom

local CameraController = {}

local yaw = 0 -- radians
local pitch = math.rad(-10)
local distance: number = Config.Camera.Distance
local aiming = false
local adsBlend = 0 -- 0 = hip, 1 = sights; eased each frame
local crosshairRing: Frame? = nil
local crosshairDot: Frame? = nil
local bloomShotAt: number? = nil -- when the Bloom attribute last changed (a shot)
local cursorHolders: { [string]: boolean } = {}
local pivotHeight: number = Config.Camera.PivotHeight.stand
local pivotTarget: number = pivotHeight
local bodyYawLocked = false
-- Per-shot kick (Config.Weapons.<id>.Kick): an extra rotation on top of pitch/yaw that eases
-- back to zero, so the aim itself never drifts. Radians.
local kickPitch = 0
local kickYaw = 0
local kickRecover = 0.12
-- Blast shake (Config.Camera.Shake): amplitude in degrees, decaying each frame.
local shakeAmplitude = 0
local lastFocus: Vector3? = nil
local firstPerson = false
local hiddenParts: { BasePart } = {} -- this soldier's parts hidden in first person
-- Binoculars (BinocularController, setScope): the eye goes to the Head and the view narrows
-- to scopeFov over scopeRaise seconds, and back over scopeLower.
local scoped = false
local scopeFov = HIP_FOV
local scopeRaise = 0.3
local scopeLower = 0.3
local scopeBlend = 0 -- 0 = no glass, 1 = through it
local eyeScoped = false -- scopeBlend > 0: the eye is on the Head whatever the camera mode
local sightWeapon: string? = nil -- the gun the sights were last eased for

-- Fraction left after `dt` of an exponential ease that is ~95% done after `over` seconds.
local function decayFactor(dt: number, over: number): number
	return math.exp(-3 * dt / math.max(over, 0.01))
end

local function onShot()
	local player = Players.LocalPlayer
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local kick = weapon.Kick
	local scale = 1 + (Config.Camera.Kick.AdsScale - 1) * adsBlend
	if firstPerson then
		-- A magnified picture is thrown further by the same kick (Rules/Sight.kickScale).
		local magnified = Sight.kickScale(weapon.Sight.Zoom, Config.Weapon.Sights.Zoom)
		scale *= 1 + (magnified - 1) * adsBlend
	end
	kickPitch += math.rad(kick.Pitch) * scale
	kickYaw += math.rad(kick.Yaw) * (math.random() * 2 - 1) * scale
	kickRecover = kick.Recover
end

local function onBlast(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local shake = Config.Camera.Shake
	local power = instance:GetAttribute(Attributes.BlastPower)
	local global = instance:GetAttribute(Attributes.BlastGlobal)
	local camera = workspace.CurrentCamera
	local from = lastFocus or (camera and camera.CFrame.Position) or instance.Position
	local added = 0
	if typeof(power) == "number" then
		added += Feel.shake(power, (instance.Position - from).Magnitude, shake.Radius)
	end
	if typeof(global) == "number" then
		added += global
	end
	shakeAmplitude = Feel.addShake(shakeAmplitude, added, shake.Cap)
end

-- A UI that needs the mouse (the dev panel) frees the cursor while it holds a reason.
-- A cutscene holds the camera (InsertionCutscene): the follow camera stands aside until off.
local cinematic = false
function CameraController.setCinematic(on: boolean)
	cinematic = on
end

function CameraController.setCursorFree(reason: string, free: boolean)
	if free then
		cursorHolders[reason] = true
	else
		cursorHolders[reason] = nil
	end
end

function CameraController.setAiming(on: boolean)
	aiming = on
end

-- The pivot eases to the stance's height (Config.Camera.PivotHeight).
function CameraController.setStance(stance: string)
	pivotTarget = (Config.Camera.PivotHeight :: { [string]: number })[stance]
		or Config.Camera.PivotHeight.stand
end

-- While locked the body keeps its heading; the camera still orbits.
function CameraController.setBodyYawLocked(locked: boolean)
	bodyYawLocked = locked
end

local function refreshHidden()
	for _, part in hiddenParts do
		part.LocalTransparencyModifier = 0
	end
	table.clear(hiddenParts)
	local character = Players.LocalPlayer.Character
	if not ((firstPerson or eyeScoped) and character) then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(hiddenParts, part)
		end
	end
end

function CameraController.setFirstPerson(on: boolean)
	if firstPerson == on then
		return
	end
	firstPerson = on
	refreshHidden()
	if not on then
		FirstPersonView.hide()
		ScopeView.set(0, 0)
	end
end

function CameraController.isFirstPerson(): boolean
	return firstPerson
end

-- Binoculars up (`fov` degrees through the glass, reached over `raise` seconds) or down
-- (nil; back over `lower`). The eye rides the Head while any of the glass is in the view.
function CameraController.setScope(fov: number?, raise: number?, lower: number?)
	scoped = fov ~= nil
	if fov then
		scopeFov = fov
	end
	scopeRaise = raise or scopeRaise
	scopeLower = lower or scopeLower
end

-- How far into the glass the view is (0 none, 1 through it).
function CameraController.scopeBlend(): number
	return scopeBlend
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
	pivotTarget = Config.Camera.PivotHeight.stand
	pivotHeight = pivotTarget
	bodyYawLocked = false
	kickPitch = 0
	kickYaw = 0
	shakeAmplitude = 0
	-- A new body: hide it again if we are in first person, and anything added to it later.
	task.defer(refreshHidden)
	character.DescendantAdded:Connect(function(thing)
		if (firstPerson or eyeScoped) and thing:IsA("BasePart") then
			task.defer(refreshHidden)
		end
	end)
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
	crosshairDot = dot

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
	if cinematic then
		UserInputService.MouseIconEnabled = false
		return
	end
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Free the cursor while soft-paused (item selection) or dead (death
	-- screen); otherwise hold it locked for aiming.
	local needsCursor = workspace:GetAttribute(Attributes.GamePaused) == true
		or not humanoid
		or humanoid.Health <= 0
		or next(cursorHolders) ~= nil
	UserInputService.MouseIconEnabled = needsCursor
	-- Re-assert every frame; Roblox's scripts reset MouseBehavior.
	UserInputService.MouseBehavior = if needsCursor
		then Enum.MouseBehavior.Default
		else Enum.MouseBehavior.LockCenter

	if not camera or not root then
		ScopeView.set(0, 0)
		return
	end

	consumeMouseInput()

	-- Ease between hip and sights over Config.Weapon.ADS.EnterTime (a scope: Sights.ScopeTime).
	local ads = Config.Weapon.ADS
	local player = Players.LocalPlayer
	local weaponId = player:GetAttribute(Attributes.Weapon) :: string?
	local sight = WeaponDefinitions.get(weaponId).Sight
	local gunScoped = firstPerson and sight.Kind == "scope" -- (`scoped` is the binoculars)
	local target = if aiming then 1 else 0
	if firstPerson then
		-- A reload or a Q swap takes the gun off the eye; another gun starts from the hip.
		local now = workspace:GetServerTimeNow()
		local reloadUntil = (player:GetAttribute(Attributes.ReloadUntil) :: number?) or 0
		local swapUntil = (player:GetAttribute(Attributes.SwapUntil) :: number?) or 0
		if reloadUntil > now or swapUntil > now or not humanoid or humanoid.Health <= 0 then
			target = 0
		end
		if weaponId ~= sightWeapon then
			adsBlend = 0
		end
	end
	sightWeapon = weaponId
	local enterTime = if gunScoped then Config.Weapon.Sights.ScopeTime else ads.EnterTime
	local rate = deltaTime / math.max(enterTime, 0.01)
	adsBlend += math.clamp(target - adsBlend, -rate, rate)
	local shoulder = Config.Camera.ShoulderOffset:Lerp(ads.ShoulderOffset, adsBlend)
	local reach = distance + (ads.CameraDistance - distance) * adsBlend
	-- First person: this gun's own zoom; a scope raises, then shades and zooms (Rules/Sight).
	local raise, zoom, shade = Sight.phases(gunScoped, adsBlend)
	local aimedFov = if firstPerson then Sight.fov(HIP_FOV, sight.Zoom) else ads.FOV
	-- Binoculars: the glass narrows the view further, and the eye sits on the Head while any
	-- of it is in the way.
	scopeBlend = Spotting.blend(scopeBlend, scoped, deltaTime, scopeRaise, scopeLower)
	if eyeScoped ~= (scopeBlend > 0) then
		eyeScoped = scopeBlend > 0
		refreshHidden()
	end
	camera.FieldOfView = Spotting.fov(HIP_FOV + (aimedFov - HIP_FOV) * zoom, scopeFov, scopeBlend)
	if eyeScoped then
		ScopeView.set(0, 0) -- the binoculars' own picture, not the gun's scope
	else
		ScopeView.set(shade, Sight.blink(shade))
	end
	local ring = crosshairRing
	if ring then
		local size = CROSSHAIR_HIP + (CROSSHAIR_ADS - CROSSHAIR_HIP) * adsBlend
		-- Bloom (server-owned, ProjectileServer): the ring opens while the trigger is held and
		-- closes as it recovers; mirror the recovery locally between shots.
		local bloomValue = (player:GetAttribute(Attributes.Bloom) :: number?) or 0
		if bloomValue > 0 then
			local shotAt = bloomShotAt or os.clock()
			local idle = os.clock() - shotAt - Config.Weapon.BloomRecoveryDelay
			if idle > 0 then
				local weapon =
					WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
				bloomValue = math.max(bloomValue - idle * weapon.BloomRecovery, 0)
			end
		end
		size += bloomValue * CROSSHAIR_PER_BLOOM
		ring.Size = UDim2.fromOffset(size, size)
		-- Down the sights in first person the sights aim: the crosshair fades out.
		-- Through binoculars their own reticle does.
		local fade = math.max(if firstPerson then adsBlend else 0, scopeBlend)
		local stroke = ring:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.35 + 0.65 * fade
		end
		local dot = crosshairDot
		if dot then
			dot.BackgroundTransparency = 0.2 + 0.8 * fade
		end
	end

	local pivotRate = deltaTime
		/ math.max(Config.Camera.PivotEaseTime, 0.01)
		* math.abs(Config.Camera.PivotHeight.stand - Config.Camera.PivotHeight.prone)
	pivotHeight += math.clamp(pivotTarget - pivotHeight, -pivotRate, pivotRate)

	camera.CameraType = Enum.CameraType.Scriptable
	-- Kick eases back over the gun's Recover; shake decays over Shake.Decay. Both ride on top
	-- of pitch/yaw, so the aim returns where the mouse left it.
	local kickLeft = decayFactor(deltaTime, kickRecover)
	kickPitch *= kickLeft
	kickYaw *= kickLeft
	shakeAmplitude *= decayFactor(deltaTime, Config.Camera.Shake.Decay)
	if shakeAmplitude < 0.01 then
		shakeAmplitude = 0
	end
	local shakePitch = 0
	local shakeRoll = 0
	if shakeAmplitude > 0 then
		local amplitude = math.rad(shakeAmplitude)
		shakePitch = amplitude * (math.random() * 2 - 1)
		shakeRoll = amplitude * (math.random() * 2 - 1)
	end
	local rotation =
		CFrame.fromEulerAnglesYXZ(pitch + kickPitch + shakePitch, yaw + kickYaw, shakeRoll)
	-- A prone body's root sits lower (StanceService RootDrop); the pivot stays on the body.
	local dropValue = root.Parent and root.Parent:GetAttribute(Attributes.RootDrop)
	local rootDrop = if typeof(dropValue) == "number" then dropValue else 0
	local focus = root.Position
		+ Vector3.new(0, pivotHeight + rootDrop, 0)
		+ rotation:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, 0))
	lastFocus = focus
	local head = character and character:FindFirstChild("Head")
	if (firstPerson or eyeScoped) and head and head:IsA("BasePart") then
		-- The eye on the head (it follows crouch, prone and the body's bob), just ahead of its
		-- centre; the sights only narrow the view. The body is re-hidden each frame because
		-- Roblox's camera scripts reset LocalTransparencyModifier.
		local eye = Config.Camera.FirstPerson
		local flatYaw = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		local at = head.Position
			+ Vector3.new(0, eye.EyeUp, 0)
			+ flatYaw:VectorToWorldSpace(Vector3.new(0, 0, -eye.EyeForward))
		lastFocus = at
		camera.CFrame = CFrame.new(at) * rotation
		for _, part in hiddenParts do
			part.LocalTransparencyModifier = 1
		end
		if eyeScoped then
			FirstPersonView.hide() -- the gun is slung while the binoculars are up
		else
			-- The gun gives way to the scope picture at the blink's darkest moment.
			FirstPersonView.update(character, camera.CFrame, sight, raise, shade >= 0.5, deltaTime)
		end
	else
		camera.CFrame = CFrame.new(focus) * rotation * CFrame.new(0, 0, reach)
		FirstPersonView.hide()
	end

	-- Character faces the aim direction while alive.
	if humanoid and humanoid.Health > 0 and not bodyYawLocked then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
end

local function onInputChanged(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local scroll = input.Position.Z
		if firstPerson then
			if scroll < 0 then -- wheel back: out to the closest third-person zoom
				CameraController.setFirstPerson(false)
				distance = Config.Camera.MinDistance
			end
			return
		end
		if scroll > 0 and distance <= Config.Camera.MinDistance then
			CameraController.setFirstPerson(true) -- wheel in past the closest zoom
			return
		end
		distance = math.clamp(
			distance - scroll * 1.5,
			Config.Camera.MinDistance,
			Config.Camera.MaxDistance
		)
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local keys = Config.Camera.FirstPerson
	if input.KeyCode == Config.Keys.Camera or input.KeyCode == keys.GamepadKey then
		CameraController.setFirstPerson(not firstPerson)
	end
end

function CameraController.init()
	local player = Players.LocalPlayer
	UserInputService.MouseIconEnabled = false
	createCrosshair()
	-- WeaponController stamps LastShotAt (local only) on every shot, so the ring holds its
	-- bloom at the cap too (an attribute set to the same value fires no change).
	player:GetAttributeChangedSignal(Attributes.LastShotAt):Connect(function()
		bloomShotAt = os.clock()
		onShot()
	end)
	-- Server blast flashes (AirStrikeService, KitService, MineService) shake the view.
	CollectionService:GetInstanceAddedSignal(Attributes.BlastTag):Connect(onBlast)

	player.CharacterAdded:Connect(applyCharacterSettings)
	if player.Character then
		applyCharacterSettings(player.Character)
	end

	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputBegan:Connect(onInputBegan)

	-- After the default camera update so our settings win each frame.
	RunService:BindToRenderStep("OTSCamera", Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return CameraController
