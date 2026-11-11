--!strict
-- Hold left mouse button to fire the gun in hand (a "semi" gun fires once per click). Aims
-- from the character toward whatever the cursor is pointing at, then asks the server to
-- fire the round. No shot goes out while the Q swap (SwapUntil) brings the other gun up.
-- Hold right mouse button to aim down sights (ADS): tighter spread (server), slower
-- walk and no sprint (SprintController), closer camera and narrower FOV
-- (CameraController), rifle shouldered (AnimationController), crosshair closes.
-- The magazine is the server's (LoadoutService: Mag, Reserve,
-- ReloadUntil attributes): R asks for a reload, an empty magazine asks for one on the next
-- trigger pull, and no shot is sent while reloading. Last Stand lets a downed body fire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Loadout =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Loadout"))
local ShotCone = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotCone"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local SoundFX = require(script.Parent.SoundFX)
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local FirstPersonView = require(script.Parent.FirstPersonView)
local SprintController = require(script.Parent.SprintController)

local WeaponController = {}

local isFiring = false
local isAiming = false
local aimButton = false -- the right mouse button is down
local aimHeld = false -- a dev tool holds the sights up (WeaponController.holdAim)
local triggerSpent = false -- a semi-auto round went out on this press
local lastFireTime = 0
local lastReloadRequest = 0
local tracerFolder: Folder? = nil
local RELOAD_REQUEST_GAP = 0.5 -- seconds between automatic reload requests on an empty mag
local blocked = false -- the hands are full (binoculars up): no shot, no sights

-- A thin bright line from the muzzle to where the round went, gone in a few frames. Drawn
-- locally for our own shots (instant) and for other players' shots via ShotTracer.
local function drawTracer(origin: Vector3, endPoint: Vector3)
	local folder = tracerFolder
	if not folder then
		return
	end
	local length = (endPoint - origin).Magnitude
	if length < 1 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Size = Vector3.new(0.12, 0.12, length)
	tracer.CFrame = CFrame.lookAt(origin, endPoint) * CFrame.new(0, 0, -length / 2)
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 214, 120)
	tracer.Transparency = 0.2
	tracer.Parent = folder
	task.delay(Config.Weapon.TracerDuration, function()
		tracer:Destroy()
	end)
end

local function setAiming(on: boolean)
	if isAiming == on then
		return
	end
	isAiming = on
	CameraController.setAiming(on)
	SprintController.setAiming(on)
	AnimationController.setAiming(on or isFiring)
end

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
	for _, name in { "Projectiles", "Tracers", "Resupply", "ResupplyCards", "Drones", "Mines" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude

	local result =
		workspace:Raycast(ray.Origin, ray.Direction * Config.Weapon.MaxAimDistance, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * Config.Weapon.MaxAimDistance
end

-- The hands are busy with something else (BinocularController): the trigger and the sights
-- do nothing until it lets go. The mouse buttons are then that thing's to read.
function WeaponController.setBlocked(on: boolean)
	blocked = on
	if on then
		isFiring = false
		setAiming(false)
		AnimationController.setAiming(false)
	end
end

-- The magazine as the server published it.
function WeaponController.isReloading(): boolean
	local until_ = (Players.LocalPlayer:GetAttribute(Attributes.ReloadUntil) :: number?) or 0
	return until_ > workspace:GetServerTimeNow()
end

function WeaponController.requestReload()
	local player = Players.LocalPlayer
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local mag = (player:GetAttribute(Attributes.Mag) :: number?) or 0
	local reserve = (player:GetAttribute(Attributes.Reserve) :: number?) or 0
	if WeaponController.isReloading() or mag >= weapon.MagazineSize or reserve <= 0 then
		return
	end
	if
		workspace:GetAttribute(Attributes.GamePaused) == true
		or player:GetAttribute(Attributes.Cinematic) == true
	then
		return
	end
	lastReloadRequest = os.clock()
	Remotes.get("Reload"):FireServer()
end

local function tryFire()
	if
		workspace:GetAttribute(Attributes.GamePaused) == true
		or Players.LocalPlayer:GetAttribute(Attributes.Cinematic) == true
	then
		return
	end

	local player = Players.LocalPlayer
	local now = os.clock()
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local cooldown = weapon.FireCooldown
	if now - lastFireTime < cooldown then
		return
	end
	-- Semi-auto: one round per click (a held trigger waits for the next press).
	if weapon.FireMode == "semi" and triggerSpent then
		return
	end
	if WeaponController.isReloading() then
		return
	end
	local swapUntil = (player:GetAttribute(Attributes.SwapUntil) :: number?) or 0
	if swapUntil > workspace:GetServerTimeNow() then
		return -- the Q swap is still bringing the other gun up
	end
	if ((player:GetAttribute(Attributes.Mag) :: number?) or 0) <= 0 then
		-- Dry: ask for a reload (once per half second while the trigger is held).
		if now - lastReloadRequest >= RELOAD_REQUEST_GAP then
			SoundFX.ui("player_gear", "dry_fire")
			WeaponController.requestReload()
		end
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		character
		and character:GetAttribute(Attributes.SquadState) == "Downed"
		and player:GetAttribute(Attributes.UpgradeKit) ~= "last_stand"
	then
		return
	end
	if character and character:GetAttribute(Attributes.KnockedUntil) ~= nil then
		return -- knocked down (Squad.knock): the server refuses the shot too
	end

	local aimPoint = getAimPoint()
	if not aimPoint then
		return
	end

	-- Fire from the rifle muzzle when present (falls back to chest height); in first person from
	-- the barrel of the gun on screen (FirstPersonView), which sits by the eye, so the shot
	-- runs down the sight line.
	local rifle = character and character:FindFirstChild("Rifle")
	local muzzle = rifle and rifle:FindFirstChild("Muzzle") :: BasePart?
	local shown = if CameraController.isFirstPerson() then FirstPersonView.muzzle() else nil
	local origin = shown or if muzzle then muzzle.Position else root.Position + Vector3.new(0, 1, 0)
	local direction = aimPoint - origin
	if direction.Magnitude < 0.001 then
		return
	end

	-- Keep the cadence on low frame rates: the next shot is due one cooldown after this
	-- one was, not after this frame (but never bank more than one shot after a pause).
	lastFireTime = if now - lastFireTime < cooldown * 2 then lastFireTime + cooldown else now
	player:SetAttribute(Attributes.LastShotAt, now)
	triggerSpent = true
	-- A shotgun: draw every pellet in its cone and send those directions, so what you see
	-- is what hits (the server checks each against the cone it allows).
	local count = weapon.Pellets or 1
	local pellets: { Vector3 }? = nil
	if count > 1 then
		local bloom = (player:GetAttribute(Attributes.Bloom) :: number?) or 0
		local cone = (if isAiming then weapon.AdsSpread else weapon.HipSpread) + bloom
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { character :: Instance }
		if tracerFolder then
			table.insert(ignore, tracerFolder)
		end
		params.FilterDescendantsInstances = ignore
		local list = {}
		for _ = 1, count do
			local pellet = ShotCone.random(direction.Unit, cone)
			table.insert(list, pellet)
			local hit = workspace:Raycast(origin, pellet * weapon.Range, params)
			drawTracer(origin, if hit then hit.Position else origin + pellet * weapon.Range)
		end
		pellets = list
	end
	Remotes.get("FireWeapon"):FireServer(origin, direction.Unit, isAiming, pellets)
	AnimationController.onShot()
	if not pellets then
		-- Behind a scope picture the tracer starts well out (Sights.Scope.TracerStart).
		local from = origin
		if shown and FirstPersonView.isHidden() then
			local out = math.min(direction.Magnitude / 2, Config.Weapon.Sights.Scope.TracerStart)
			from = origin + direction.Unit * out
		end
		drawTracer(from, aimPoint)
	end

	-- Local-only muzzle flash and shot sound for instant feedback. A suppressor (the
	-- Loadmaster's EDIT, Config.Attachments) quiets the shot and hides the flash.
	local fitted = Players.LocalPlayer:GetAttribute(Attributes.Fitted)
	local barrel = Loadout.fitted(
		Loadout.decodeFitted(if typeof(fitted) == "string" then fitted else ""),
		weapon.Id,
		"Barrel"
	)
	local option = barrel and Config.Attachments.Options[barrel]
	SoundFX.gunshot(weapon.Sound, nil, if option then option.Volume else nil)
	if option then
		return
	end
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	-- In first person the flash shrinks with the gun on screen (FirstPersonView.scale); behind
	-- a scope picture only its light shows, not a ball across the magnified lens.
	local flashScale = if shown then FirstPersonView.scale() else 1
	if shown and FirstPersonView.isHidden() then
		flash.Transparency = 1
	end
	flash.Size = Vector3.new(0.7, 0.7, 0.7) * flashScale
	flash.Position = origin + direction.Unit * 1.5 * flashScale
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

-- Holds the sights up without the mouse button (the dev sight tour, SightTour).
function WeaponController.holdAim(on: boolean)
	aimHeld = on
	setAiming(on or aimButton)
end

function WeaponController.init()
	-- The rifle is a Tool, but it's always equipped — hide the backpack hotbar.
	local StarterGui = game:GetService("StarterGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local folder = Instance.new("Folder")
	folder.Name = "Tracers"
	folder.Parent = workspace
	tracerFolder = folder
	-- Another squad member's shot (a player or a bot): the tracer plus a 3D gunshot.
	Remotes.get("ShotTracer").OnClientEvent
		:Connect(function(origin: Vector3, endPoint: Vector3, sound: string?, barrel: string?)
			drawTracer(origin, endPoint)
			local option = if typeof(barrel) == "string"
				then Config.Attachments.Options[barrel]
				else nil
			local volume = if option then 0.8 * option.Volume else 0.8
			SoundFX.gunshot(if typeof(sound) == "string" then sound else nil, origin, volume)
		end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local button = input.UserInputType
		if
			blocked
			and (
				button == Enum.UserInputType.MouseButton1
				or button == Enum.UserInputType.MouseButton2
			)
		then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = true
			triggerSpent = false
			AnimationController.setAiming(true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimButton = true
			setAiming(true)
		elseif input.KeyCode == Config.Keys.Reload then
			WeaponController.requestReload()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isFiring = false
			AnimationController.setAiming(isAiming)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimButton = false
			setAiming(aimHeld)
		end
	end)

	-- A respawn or the run-end freeze drops the sights.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		isFiring = false
		setAiming(false)
	end)
	workspace:GetAttributeChangedSignal(Attributes.GamePaused):Connect(function()
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			setAiming(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if isFiring then
			tryFire()
		end
	end)
end

return WeaponController
