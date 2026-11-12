--!strict
-- The first-person arms and gun (Nova, 2026-11-10: "show the characters arms, him holding the
-- rifle", a reload animation, "everything properly angled"). A viewmodel of its own, as FPS
-- games do: the body's clips are made for the body seen from behind and their hands do not
-- meet the gun from the eye. A local copy of the held gun, two gloved hands and two Pike-grey
-- forearms, parented to the camera, animated here from the same events the body uses:
--   * the gun points where the camera looks. At the hip its grip sits where its kind of gun is
--     carried (Config.Weapon.Sights.Hold: a long gun low right, a sidearm nearer the middle,
--     a launcher on the shoulder). Down the sights the eye goes on the gun's own sight line
--     (the row's Sight, Rules/Sight): its eye relief behind the rear sight, looking at the
--     front one, so the post sits centred in the peep or notch on the screen's centre. Down a
--     scope the gun comes to the eye the same way and is then hidden: ScopeView draws the
--     picture (CameraController);
--   * the right hand holds it exactly as the body's right hand holds the real gun; the left
--     hand on the handguard (under the grip for a sidearm); the forearms run back to elbows
--     below the view;
--   * a reload (ReloadUntil, timed to the server's reload): the gun tilts, the left hand pulls
--     the magazine down and out of view, comes back with a fresh one, seats it, and returns;
--   * each shot (LastShotAt) kicks the gun back and up; turning the camera makes the gun lag a
--     touch behind; walking bobs it (kick and lag are smaller down the sights, so they stay
--     lined up); a Q swap (SwapUntil) dips it out of view and back.
-- The whole viewmodel is built at full size in the camera's space and then shrunk toward the
-- eye by Scale: it looks the same, but a wall or a squadmate a stud away no longer cuts into
-- it. A rear sight close to the eye would fall inside the camera's near plane at that scale,
-- so the scale grows just enough to keep it in view (Rules/Sight.viewScale).
-- Shots in first person leave from its barrel (FirstPersonView.muzzle, WeaponController).
-- Others never see it: they see the real body, which this client hides in first person.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sight =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Sight"))

local FirstPersonView = {}

local VIEW = Config.Camera.FirstPerson
local SLEEVE = Color3.fromRGB(99, 109, 119) -- the Pike fatigues (palette "gun")
local GLOVE = Color3.fromRGB(48, 53, 59) -- palette "dark"
local HOLD = Config.Weapon.Sights.Hold :: { [string]: Vector3 }
local HAND = Vector3.new(0.42, 0.34, 0.5)
local SLEEVE_WIDTH = 0.46

type View = {
	character: Model,
	model: Model,
	gun: BasePart?,
	gunSource: BasePart?,
	-- The suppressor on its barrel (PlayerSetup's Suppressor part), copied with it.
	can: BasePart?,
	canSource: BasePart?,
	canFrame: CFrame, -- in the gun's space at full size
	canFull: Vector3,
	full: Vector3, -- the held gun's real size
	muzzle: Vector3, -- its barrel tip, in its own space at full size
	origin: CFrame, -- the grip (the Tool's Handle, the mesh's design origin) in the gun's space
	grip: CFrame, -- the right hand in the gun's space
	scale: number, -- the viewmodel's size on screen (VIEW.Scale, or more for a close sight)
	hands: { BasePart }, -- left, right
	arms: { BasePart }, -- left, right
}

local view: View? = nil
local reloadFrom = 0 -- server time the current reload began
local reloadUntil = 0
local swapFrom = 0 -- server time the current Q swap began
local swapUntil = 0
local concealed = false -- the viewmodel is hidden behind the scope picture
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
	local s = VIEW.Scale
	for _, side in { "Left", "Right" } do
		table.insert(hands, block(model, side .. "Glove", HAND * s, GLOVE))
		table.insert(
			arms,
			block(
				model,
				side .. "Sleeve",
				Vector3.new(SLEEVE_WIDTH * s, SLEEVE_WIDTH * s, 1),
				SLEEVE
			)
		)
	end
	model.Parent = Workspace.CurrentCamera
	return {
		character = character,
		model = model,
		gun = nil,
		gunSource = nil,
		can = nil,
		canSource = nil,
		canFrame = CFrame.new(),
		canFull = Vector3.one,
		full = Vector3.one,
		muzzle = Vector3.zero,
		origin = CFrame.new(),
		grip = CFrame.new(0, -0.3, 0.4),
		scale = s,
		hands = hands,
		arms = arms,
	}
end

-- The gun copy follows the gun in hand (swaps, respawns); the grip is where the body's right
-- hand holds the real one.
local function fitGun(current: View)
	local source = heldGun(current.character)
	local sourceTool = source and source:FindFirstAncestorOfClass("Tool")
	local found = sourceTool and sourceTool:FindFirstChild("Suppressor")
	local canSource = if found and found:IsA("BasePart") then found else nil
	if
		source == current.gunSource
		and (current.gun ~= nil) == (source ~= nil)
		and canSource == current.canSource
	then
		return
	end
	if current.gun then
		current.gun:Destroy()
		current.gun = nil
	end
	if current.can then
		current.can:Destroy()
		current.can = nil
	end
	current.canSource = canSource
	current.gunSource = source
	local realHand = current.character:FindFirstChild("RightHand")
	if not (source and realHand and realHand:IsA("BasePart")) then
		return
	end
	local copy = source:Clone()
	copy:ClearAllChildren()
	quiet(copy)
	current.full = source.Size
	copy.Size = source.Size * current.scale
	copy.Parent = current.model
	current.gun = copy
	if canSource then
		local can = canSource:Clone()
		can:ClearAllChildren()
		quiet(can)
		current.canFull = canSource.Size
		current.canFrame = source.CFrame:ToObjectSpace(canSource.CFrame)
		can.Size = canSource.Size * current.scale
		can.Parent = current.model
		current.can = can
	end
	-- The barrel tip: the tool's Muzzle part (PlayerSetup), else the gun's front end.
	local tool = source:FindFirstAncestorOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Muzzle", true)
	current.muzzle = if muzzle and muzzle:IsA("BasePart")
		then source.CFrame:PointToObjectSpace(muzzle.Position)
		else Vector3.new(0, 0, -source.Size.Z / 2)
	-- The grip: the Tool's Handle, the origin the row's sight points are measured from.
	local handle = tool and tool:FindFirstChild("Handle")
	current.origin = if handle and handle:IsA("BasePart")
		then source.CFrame:ToObjectSpace(handle.CFrame)
		else CFrame.new()
	current.grip = source.CFrame:ToObjectSpace(realHand.CFrame)
end

-- Resizes the viewmodel to `scale` (the gun copy, the gloves, the sleeves' width).
local function rescale(current: View, scale: number)
	if math.abs(scale - current.scale) < 1e-3 then
		return
	end
	current.scale = scale
	if current.gun then
		current.gun.Size = current.full * scale
	end
	if current.can then
		current.can.Size = current.canFull * scale
	end
	for _, hand in current.hands do
		hand.Size = HAND * scale
	end
	for _, arm in current.arms do
		arm.Size = Vector3.new(SLEEVE_WIDTH * scale, SLEEVE_WIDTH * scale, arm.Size.Z)
	end
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

-- Shows the arms and gun for `character` at `camera` (nil: none), aimed by the gun's `sight`;
-- `ads` 0 at the hip to 1 down the sights; `hidden`: the scope picture is up, draw nothing
-- (the barrel still moves, shots leave from it). Call each frame after the camera is placed.
function FirstPersonView.update(
	character: Model?,
	camera: CFrame?,
	sight: Sight.Resolved,
	ads: number,
	hidden: boolean,
	dt: number
)
	concealed = hidden
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
	local modifier = if hidden then 1 else 0
	for _, part in active.model:GetChildren() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = modifier
		end
	end
	local size = active.full
	-- Irons close to the eye must clear the near plane (a scope is hidden when it gets there).
	local lens = Workspace.CurrentCamera
	local near = if lens then math.abs(lens.NearPlaneZ) else 0.1
	local clearance = sight.EyeRelief - VIEW.KickBack * VIEW.AdsKick
	rescale(
		active,
		if sight.Kind == "scope"
			then VIEW.Scale
			else Sight.viewScale(VIEW.Scale, near, clearance, VIEW.NearMargin)
	)
	local S = active.scale
	-- Camera space at full size -> the world, shrunk toward the eye.
	local function world(at: CFrame): CFrame
		return camera * CFrame.new(at.Position * S) * at.Rotation
	end

	-- Sway: the gun lags the camera's turn a little and settles back.
	local previous = lastCamera
	lastCamera = camera
	if previous then
		local turn = previous:ToObjectSpace(camera)
		local lag = VIEW.Sway * (1 - (1 - VIEW.AdsSway) * ads)
		sway = (sway + Vector2.new(turn.LookVector.X, turn.LookVector.Y) * lag)
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

	-- A Q swap: the gun dips out of view and comes back up as the other one.
	local dip = if now < swapUntil and swapUntil > swapFrom
		then math.sin(math.pi * (now - swapFrom) / (swapUntil - swapFrom))
		else 0

	-- The grip in the camera's space. At the hip: where this kind of gun is carried, pointing
	-- along the camera. Down the sights: the camera is the eye on the gun's sight line (the
	-- relief behind the rear sight, looking at the front one), so the gun is that turned inside
	-- out. Then bob, kick and the swap's dip move it; sway and the kick's tip turn it about
	-- the hand.
	local hip = CFrame.new(HOLD[sight.Hold] or HOLD.long)
	local eye = Sight.eye(sight.Rear, sight.Front, sight.EyeRelief)
	local sights = CFrame.lookAt(eye, sight.Front):Inverse()
	local kickBack = kick * VIEW.KickBack * (1 - (1 - VIEW.AdsKick) * ads)
	local moved = bob + Vector3.new(0, -dip * VIEW.SwapDip, kickBack)
	local gripCFrame = CFrame.new(moved)
		* hip:Lerp(sights, ads)
		* CFrame.Angles(sway.Y + kick * math.rad(VIEW.KickPitch) - dip * math.rad(20), sway.X, 0)
	-- The gun's own part (its bounds centre) from the grip, then the reload's tilt.
	local gunCFrame = gripCFrame * active.origin:Inverse() * reloadGun
	gun.CFrame = world(gunCFrame)
	if active.can then
		active.can.CFrame = world(gunCFrame * active.canFrame)
	end
	muzzleAt = world(gunCFrame * CFrame.new(active.muzzle)).Position

	-- Hands: the right on the grip; the left on the handguard (under the grip for a sidearm),
	-- or off to the magazine during a reload.
	local long = sight.Hold ~= "sidearm"
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

-- The viewmodel's size on screen against the real gun (WeaponController scales the flash).
function FirstPersonView.scale(): number
	local current = view
	return if current then current.scale else VIEW.Scale
end

-- True while the scope picture stands in for the gun (no flash ball across the lens).
function FirstPersonView.isHidden(): boolean
	return concealed
end

function FirstPersonView.hide()
	destroy()
	lastCamera = nil
	concealed = false
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
	player:GetAttributeChangedSignal(Attributes.SwapUntil):Connect(function()
		local untilAt = player:GetAttribute(Attributes.SwapUntil)
		local now = Workspace:GetServerTimeNow()
		if typeof(untilAt) == "number" and untilAt > now then
			swapFrom, swapUntil = now, untilAt
		else
			swapUntil = 0
		end
	end)
end

return FirstPersonView
