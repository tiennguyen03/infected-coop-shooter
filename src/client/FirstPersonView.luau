--!strict
-- The first-person arms and gun (Nova, 2026-11-10: "show the characters arms, him holding the
-- rifle", a reload animation, "everything properly angled"). A viewmodel of its own, as FPS
-- games do: the body's clips are made for the body seen from behind and their hands do not
-- meet the gun from the eye. A local copy of the held gun, two gloved hands and two Pike-grey
-- forearms, parented to the camera, animated here from the same events the body uses:
--   * the gun points where the camera looks: low and right at the hip, centred with its top on
--     the eye line down the sights (Config.Camera.FirstPerson);
--   * the right hand holds it exactly as the body's right hand holds the real gun; the left
--     hand on the handguard (under the grip for a sidearm); the forearms run back to elbows
--     below the view;
--   * a reload (ReloadUntil, timed to the server's reload): the gun tilts, the left hand pulls
--     the magazine down and out of view, comes back with a fresh one, seats it, and returns;
--   * each shot (LastShotAt) kicks the gun back and up; turning the camera makes the gun lag a
--     touch behind; walking bobs it.
-- The whole viewmodel is built at full size in the camera's space and then shrunk toward the
-- eye by Scale: it looks the same, but a wall or a squadmate a stud away no longer cuts into it.
-- Shots in first person leave from its barrel (FirstPersonView.muzzle, WeaponController).
-- Others never see it: they see the real body, which this client hides in first person.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FirstPersonView = {}

local VIEW = Config.Camera.FirstPerson
local SLEEVE = Color3.fromRGB(99, 109, 119) -- the Pike fatigues (palette "gun")
local GLOVE = Color3.fromRGB(48, 53, 59) -- palette "dark"
local SIDEARM_LENGTH = 1.6 -- a held gun shorter than this is gripped two-handed at the grip
local S = VIEW.Scale

type View = {
	character: Model,
	model: Model,
	gun: BasePart?,
	gunSource: BasePart?,
	full: Vector3, -- the held gun's real size
	muzzle: Vector3, -- its barrel tip, in its own space at full size
	sight: Vector3?, -- its irons' sight line at the rear sight, likewise (nil: not modelled)
	grip: CFrame, -- the right hand in the gun's space
	hands: { BasePart }, -- left, right
	arms: { BasePart }, -- left, right
}

local view: View? = nil
local reloadFrom = 0 -- server time the current reload began
local reloadUntil = 0
local kick = 0 -- 0..1, eases back after each shot
local lastCamera: CFrame? = nil
local sway = Vector2.zero -- radians the gun lags behind the camera (yaw, pitch)
local bobTime = 0
local muzzleAt: Vector3? = nil -- the shown gun's barrel tip this frame

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- the aim ray passes through
	part.CanTouch = false
	part.CastShadow = false
	part.LocalTransparencyModifier = 0
end

local function block(model: Model, name: string, size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	quiet(part)
	part.Parent = model
	return part
end

-- The held gun's visible part: the biggest visible part of the character's Tool.
local function heldGun(character: Model): BasePart?
	local tool = character:FindFirstChildOfClass("Tool")
	local best: BasePart? = nil
	if tool then
		for _, part in tool:GetDescendants() do
			if
				part:IsA("BasePart")
				and part.Transparency < 1
				and (not best or part.Size.Magnitude > best.Size.Magnitude)
			then
				best = part
			end
		end
	end
	return best
end

local function destroy()
	local current = view
	if current then
		current.model:Destroy()
		view = nil
	end
	muzzleAt = nil
end

local function build(character: Model): View
	local model = Instance.new("Model")
	model.Name = "FirstPersonArms"
	local hands, arms = {}, {}
	for _, side in { "Left", "Right" } do
		table.insert(hands, block(model, side .. "Glove", Vector3.new(0.42, 0.34, 0.5) * S, GLOVE))
		table.insert(
			arms,
			block(model, side .. "Sleeve", Vector3.new(0.46 * S, 0.46 * S, 1), SLEEVE)
		)
	end
	model.Parent = Workspace.CurrentCamera
	return {
		character = character,
		model = model,
		gun = nil,
		gunSource = nil,
		full = Vector3.one,
		muzzle = Vector3.zero,
		sight = nil,
		grip = CFrame.new(0, -0.3, 0.4),
		hands = hands,
		arms = arms,
	}
end

-- The gun copy follows the gun in hand (swaps, respawns); the grip is where the body's right
-- hand holds the real one.
local function fitGun(current: View)
	local source = heldGun(current.character)
	if source == current.gunSource and (current.gun ~= nil) == (source ~= nil) then
		return
	end
	if current.gun then
		current.gun:Destroy()
		current.gun = nil
	end
	current.gunSource = source
	local realHand = current.character:FindFirstChild("RightHand")
	if not (source and realHand and realHand:IsA("BasePart")) then
		return
	end
	local copy = source:Clone()
	copy:ClearAllChildren()
	quiet(copy)
	current.full = source.Size
	copy.Size = source.Size * S
	copy.Parent = current.model
	current.gun = copy
	-- The barrel tip: the tool's Muzzle part (PlayerSetup), else the gun's front end.
	local tool = source:FindFirstAncestorOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Muzzle", true)
	current.muzzle = if muzzle and muzzle:IsA("BasePart")
		then source.CFrame:PointToObjectSpace(muzzle.Position)
		else Vector3.new(0, 0, -source.Size.Z / 2)
	-- The irons (PlayerSetup's Sight part, from MeshAssets `sight`).
	local sight = tool and tool:FindFirstChild("Sight", true)
	current.sight = if sight and sight:IsA("BasePart")
		then source.CFrame:PointToObjectSpace(sight.Position)
		else nil
	current.grip = source.CFrame:ToObjectSpace(realHand.CFrame)
end

-- Smooth 0..1 between a and b.
local function ease(t: number, a: number, b: number): number
	local x = math.clamp((t - a) / math.max(b - a, 1e-3), 0, 1)
	return x * x * (3 - 2 * x)
end

-- The reload, 0..1 through it, as (the gun's extra pose, where the left hand goes in the
-- gun's space instead of the handguard, how far it has gone there 0..1).
local function reloadPose(t: number, size: Vector3): (CFrame, Vector3, number)
	local tilt = ease(t, 0, 0.15) * (1 - ease(t, 0.85, 1))
	local gunPose = CFrame.new(0, -0.25 * tilt, 0.15 * tilt)
		* CFrame.Angles(math.rad(12) * tilt, 0, math.rad(-28) * tilt)
	local magwell = Vector3.new(0, -size.Y * 0.55, -size.Z * 0.05)
	local below = magwell + Vector3.new(-0.2, -1.6, 0.3)
	-- To the magazine, down out of view with it, back up with a fresh one, seat it, return.
	local hand: Vector3
	local away: number
	if t < 0.2 then
		hand, away = magwell, ease(t, 0.08, 0.2)
	elseif t < 0.45 then
		hand, away = magwell:Lerp(below, ease(t, 0.2, 0.4)), 1
	elseif t < 0.7 then
		hand, away = below:Lerp(magwell, ease(t, 0.45, 0.65)), 1
	else
		hand = magwell + Vector3.new(0, 0.08 * (1 - ease(t, 0.7, 0.76)), 0)
		away = 1 - ease(t, 0.78, 0.92)
	end
	return gunPose, hand, away
end

-- A forearm from the elbow to the wrist.
local function reach(arm: BasePart, elbow: Vector3, wrist: Vector3)
	local length = math.max((wrist - elbow).Magnitude, 0.3)
	arm.Size = Vector3.new(arm.Size.X, arm.Size.Y, length)
	arm.CFrame = CFrame.lookAt((elbow + wrist) / 2, wrist)
end

-- Shows the arms and gun for `character` at `camera` (nil: none); `ads` 0 at the hip to 1
-- down the sights. Call each frame after the camera is placed.
function FirstPersonView.update(character: Model?, camera: CFrame?, ads: number, dt: number)
	if not (character and camera) then
		destroy()
		lastCamera = nil
		return
	end
	local current = view
	if current and (current.character ~= character or not current.model.Parent) then
		destroy()
		current = nil
	end
	local active: View = current or build(character)
	view = active
	fitGun(active)
	local gun = active.gun
	if not gun then
		muzzleAt = nil
		for _, part in active.model:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
		return
	end
	for _, part in active.model:GetChildren() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
	local size = active.full
	-- Camera space at full size -> the world, shrunk toward the eye.
	local function world(at: CFrame): CFrame
		return camera * CFrame.new(at.Position * S) * at.Rotation
	end

	-- Sway: the gun lags the camera's turn a little and settles back.
	local previous = lastCamera
	lastCamera = camera
	if previous then
		local turn = previous:ToObjectSpace(camera)
		sway = (sway + Vector2.new(turn.LookVector.X, turn.LookVector.Y) * VIEW.Sway)
			* math.exp(-dt / 0.12)
	end
	local swayLimit = math.rad(6)
	sway = Vector2.new(
		math.clamp(sway.X, -swayLimit, swayLimit),
		math.clamp(sway.Y, -swayLimit, swayLimit)
	)
	-- Bob while walking (not down the sights).
	local root = character:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart")
		then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		else 0
	bobTime += dt * math.clamp(speed / 8, 0, 2) * 7
	local bobAmount = math.clamp(speed / 16, 0, 1) * (1 - ads) * VIEW.Bob
	local bob =
		Vector3.new(math.cos(bobTime) * bobAmount, math.abs(math.sin(bobTime)) * bobAmount, 0)
	-- Kick eases back.
	kick *= math.exp(-dt / 0.07)

	-- Reload progress.
	local now = Workspace:GetServerTimeNow()
	local reloadT = if now < reloadUntil and reloadUntil > reloadFrom
		then (now - reloadFrom) / (reloadUntil - reloadFrom)
		else 1
	local reloadGun, magHand, toMag = reloadPose(reloadT, size)

	-- The gun: pointing along the camera, its centre low right at the hip, under the eye down
	-- the sights; then sway, bob, kick and the reload's tilt.
	local hip = VIEW.GunHip.Position
	-- Down the sights: the irons' sight line through the eye (the rear sight SightEye ahead,
	-- the front post on the screen's centre); a gun without modelled irons sits by its size.
	local sight = active.sight
	local sights = if sight
		then Vector3.new(0, 0, -VIEW.SightEye) - sight
		else Vector3.new(0, -size.Y * VIEW.SightDrop, VIEW.GunAds.Position.Z)
	local place = hip:Lerp(sights, ads) + bob + Vector3.new(0, 0, kick * VIEW.KickBack)
	local gunCFrame = CFrame.new(place)
		* CFrame.Angles(sway.Y + kick * math.rad(VIEW.KickPitch), sway.X, 0)
		* reloadGun
	gun.CFrame = world(gunCFrame)
	muzzleAt = world(gunCFrame * CFrame.new(active.muzzle)).Position

	-- Hands: the right on the grip; the left on the handguard (under the grip for a sidearm),
	-- or off to the magazine during a reload.
	local long = math.max(size.X, size.Y, size.Z) >= SIDEARM_LENGTH
	local right = gunCFrame * active.grip
	local guard = if long
		then gunCFrame * CFrame.new(0, -size.Y * 0.32, -size.Z * 0.22)
		else right * CFrame.new(-0.12, -0.18, 0.05)
	local left = guard:Lerp(gunCFrame * CFrame.new(magHand), toMag)
	active.hands[1].CFrame = world(left * CFrame.Angles(0, 0, math.rad(-20)))
	active.hands[2].CFrame = world(right)
	-- Forearms back to elbows below the view (the left one follows its hand to the magazine).
	local leftElbow =
		CFrame.new(Vector3.new(-0.55, -1.75, -0.9) + (left.Position - guard.Position) * 0.4)
	local rightElbow = CFrame.new(1.25, -1.7, -0.6)
	reach(active.arms[1], world(leftElbow).Position, world(left * CFrame.new(0, 0, 0.2)).Position)
	reach(active.arms[2], world(rightElbow).Position, world(right * CFrame.new(0, 0, 0.2)).Position)
end

-- Where a shot leaves in first person: the shown gun's barrel tip (nil when none is shown).
function FirstPersonView.muzzle(): Vector3?
	return muzzleAt
end

function FirstPersonView.hide()
	destroy()
	lastCamera = nil
end

-- Shots and reloads come in as the body's do (WeaponController stamps LastShotAt; the server
-- sets ReloadUntil).
function FirstPersonView.init()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(Attributes.LastShotAt):Connect(function()
		kick = 1
	end)
	player:GetAttributeChangedSignal(Attributes.ReloadUntil):Connect(function()
		local untilAt = player:GetAttribute(Attributes.ReloadUntil)
		local now = Workspace:GetServerTimeNow()
		if typeof(untilAt) == "number" and untilAt > now then
			reloadFrom, reloadUntil = now, untilAt
		else
			reloadUntil = 0 -- cancelled (a swap)
		end
	end)
end

return FirstPersonView
