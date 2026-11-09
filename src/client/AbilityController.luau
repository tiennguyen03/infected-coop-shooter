--!strict
-- The soldier's keys (docs/PROGRESSION.md > Loadout): Q swaps long gun and sidearm, G throws
-- a grenade, V shoves, E uses a stim (KitService over UseAbility), 1-4 fire the call-ins
-- (CallIn remote) and 5 throws the Resupply flare. The server validates and performs them;
-- this controller forwards input and draws the aim: hold G or a thrown call-in's key and an
-- arc from the hand plus that item's marker show where it will land (the aim point, clamped
-- to throw range, dropped to the ground) and what it covers; release to throw it there. The
-- flare throws at the crosshair at once (ThrowUtil, the server's maths).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Messages = require(Shared:WaitForChild("Messages"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ThrowUtil = require(Shared:WaitForChild("ThrowUtil"))
local UpgradeDefinitions = require(Shared:WaitForChild("UpgradeDefinitions"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local AnimationController = require(script.Parent.AnimationController)

local GHOST_COLOR = Color3.fromRGB(255, 150, 60)

-- Keys 1-4 for the call-in slots (Config.CallIns.Slots).
local CALL_IN_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

local AbilityController = {}

type FragSettings = { ThrowDistance: number, Radius: number }

local function fragSettings(): FragSettings
	local definition =
		WeaponDefinitions.grenade(Players.LocalPlayer:GetAttribute(Attributes.Grenade) :: string?)
	return (Config.Grenade :: any)[definition.ConfigKey] :: FragSettings
end

local function raycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	for _, name in
		{
			"Projectiles",
			"KitEffects",
			"GrenadeGhost",
			"Resupply",
			"Drones",
			"Mines",
			"SquadBots",
		}
	do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- Where a throw of `maxDistance` would land right now: aim point clamped to range,
-- stopped at walls, dropped to the ground (ThrowUtil, same maths as the server).
local function landingPoint(maxDistance: number): Vector3?
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return nil
	end
	local params = raycastParams()
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * Config.Weapon.MaxAimDistance, params)
	local aim = if hit
		then hit.Position
		else ray.Origin + ray.Direction * Config.Weapon.MaxAimDistance
	return ThrowUtil.landingPoint(root, aim, maxDistance, params.FilterDescendantsInstances)
end

-- Aiming a throw (owner 2026-11-09: "hold and release with trajectory indicators so I
-- actually know where it lands"): hold G or a thrown call-in's key, and a dotted arc from the
-- hand plus the item's own marker (its Aim row: a ring, or a strip along or across the throw)
-- follow the crosshair; release to throw there. Pressing another throw key switches to it.
type AimShape =
	{ Shape: string, Radius: number?, Length: number?, Width: number?, Across: boolean? }
type Aiming = {
	key: Enum.KeyCode, -- the key held
	slot: number?, -- the call-in slot; nil for the grenade
	reach: number, -- ThrowDistance
	aim: AimShape,
	model: Model,
	beads: { Part },
	marker: Part,
	target: Vector3?,
}

local aiming: Aiming? = nil

local function ghostPart(name: string, parent: Instance, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = GHOST_COLOR
	part.Transparency = transparency
	part.Parent = parent
	return part
end

local function startAiming(key: Enum.KeyCode, slot: number?, reach: number, aim: AimShape)
	if aiming then
		aiming.model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "GrenadeGhost" -- excluded from the aim raycasts (raycastParams)
	local beads: { Part } = {}
	for _ = 1, Config.CallIns.AimArc.Beads do
		local bead = ghostPart("Bead", model, 0.35)
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.new(0.35, 0.35, 0.35)
		table.insert(beads, bead)
	end
	local marker = ghostPart("Marker", model, 0.7)
	if aim.Shape == "strip" then
		marker.Size = Vector3.new(aim.Width or 3, 0.3, aim.Length or 10)
	else
		marker.Shape = Enum.PartType.Cylinder
		local radius = aim.Radius or 3
		marker.Size = Vector3.new(0.3, radius * 2, radius * 2)
	end
	local core = ghostPart("Core", model, 0.3)
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.8, 0.8, 0.8)
	model.PrimaryPart = core
	model.Parent = workspace
	aiming = {
		key = key,
		slot = slot,
		reach = reach,
		aim = aim,
		model = model,
		beads = beads,
		marker = marker,
		target = nil,
	}
end

-- Moves the arc and the marker to where the throw would land now.
local function updateAiming()
	local state = aiming
	if not state then
		return
	end
	local point = landingPoint(state.reach)
	state.target = point
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	state.model.Parent = if point and root then workspace else nil
	if not point or not root then
		return
	end
	-- The arc: a parabola from the hand to the landing point.
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local flat = Vector3.new(point.X - from.X, 0, point.Z - from.Z)
	local arc = Config.CallIns.AimArc
	local rise = math.max(flat.Magnitude * arc.Rise, arc.MinRise)
	local count = #state.beads
	for index, bead in state.beads do
		local t = index / (count + 1)
		local at = from:Lerp(point, t) + Vector3.new(0, 4 * rise * t * (1 - t), 0)
		bead.CFrame = CFrame.new(at)
	end
	-- The marker on the ground: a ring, or a strip along (or across) the throw.
	local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local ground = point + Vector3.new(0, 0.15, 0)
	if state.aim.Shape == "strip" then
		local frame = CFrame.lookAt(ground, ground + direction)
		state.marker.CFrame = if state.aim.Across
			then frame * CFrame.Angles(0, math.rad(90), 0)
			else frame
	else
		state.marker.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	end
	local core = state.model.PrimaryPart
	if core then
		core.CFrame = CFrame.new(point + Vector3.new(0, 1, 0))
	end
end

-- Ends aiming; returns what was aimed (nil when nothing was).
local function stopAiming(): Aiming?
	local state = aiming
	aiming = nil
	if state then
		state.model:Destroy()
	end
	return state
end

-- G held: the frag (if one is left).
local function aimGrenade()
	if ((Players.LocalPlayer:GetAttribute(Attributes.Grenades) :: number?) or 0) <= 0 then
		return
	end
	local settings = fragSettings()
	startAiming(
		Enum.KeyCode.G,
		nil,
		settings.ThrowDistance,
		{ Shape = "ring", Radius = settings.Radius }
	)
end

-- Keys 1-4: a thrown call-in is aimed while the key is held and thrown on release; a "self"
-- call-in fires at once.
local function pressCallIn(key: Enum.KeyCode, slot: number)
	local player = Players.LocalPlayer
	local definition =
		CallInDefinitions.get(player:GetAttribute(Attributes.callIn(slot)) :: string?)
	if not definition then
		return
	end
	local charges = (player:GetAttribute(Attributes.callInCharges(slot)) :: number?) or 0
	-- Daisy Chain: the Tripline key still goes out on an empty slot (the server blows the
	-- armed mines without a charge).
	local daisyChain = definition.Id == "tripline"
		and player:GetAttribute(Attributes.upgrade(UpgradeDefinitions.callInSlot(slot)))
			== "command_detonation"
	if charges <= 0 and not daisyChain then
		return
	end
	if definition.Kind ~= "throw" or charges <= 0 then
		Remotes.get("CallIn"):FireServer(slot, nil)
		return
	end
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	startAiming(
		key,
		slot,
		cfg.ThrowDistance,
		(cfg.Aim :: AimShape?) or { Shape = "ring", Radius = 3 }
	)
end

-- The held key came up: throw what was being aimed.
local function release(key: Enum.KeyCode)
	if not aiming or aiming.key ~= key then
		return
	end
	local state = stopAiming() :: Aiming
	local target = state.target
	if not target or workspace:GetAttribute(Attributes.GamePaused) == true then
		return
	end
	if state.slot then
		Remotes.get("CallIn"):FireServer(state.slot, target)
	else
		Remotes.get("UseAbility"):FireServer(Messages.Ability.Grenade, target)
	end
	AnimationController.playAbility("throw")
end

function AbilityController.init()
	local useAbility = Remotes.get("UseAbility")
	local resupply = Remotes.get("Resupply")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Nothing fires while the field is frozen (run end).
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			return
		end
		local key = input.KeyCode
		local slot = CALL_IN_KEYS[key]
		if slot and slot <= Config.CallIns.Slots then
			pressCallIn(key, slot)
		elseif key == Enum.KeyCode.Q then
			useAbility:FireServer(Messages.Ability.Swap)
		elseif key == Enum.KeyCode.G then
			aimGrenade()
		elseif key == Enum.KeyCode.V then
			useAbility:FireServer(Messages.Ability.Shove)
		elseif key == Enum.KeyCode.E then
			useAbility:FireServer(Messages.Ability.Stim)
		elseif key == Enum.KeyCode.Five then
			resupply:FireServer(
				Messages.Resupply.Flare,
				landingPoint(Config.Requisition.FlareThrowDistance)
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		release(input.KeyCode)
	end)

	RunService.RenderStepped:Connect(updateAiming)

	-- A respawn or the freeze cancels any held aim.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		stopAiming()
	end)
	workspace:GetAttributeChangedSignal(Attributes.GamePaused):Connect(function()
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			stopAiming()
		end
	end)
end

return AbilityController
