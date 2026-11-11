--!strict
-- The soldier's keys (Config.Keys; docs/PROGRESSION.md > Loadout): SwapGun swaps long gun
-- and sidearm, Grenade throws one, Shove shoves, Stim uses a stim (KitService over
-- UseAbility), CallIns fire the call-ins (CallIn remote) and Flare throws the Resupply flare.
-- The server validates and performs them; this controller forwards input and draws the
-- aim: hold the Grenade key or a thrown call-in's key and an
-- arc from the hand plus that item's marker show where it will land (the aim point, clamped
-- to throw range, dropped to the ground) and what it covers; release to throw it there. The
-- flare throws at the crosshair at once (ThrowUtil, the server's maths). Every throw starts
-- the throw clip here at once; the thing leaves the hand at the clip's release (ThrowWindUp).
-- A call-in whose row says AimMode "Binoculars" (the Anvil) is not thrown: its key raises the
-- binoculars (BinocularController), and any other kit key lowers them.

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
local Spotting = require(Shared:WaitForChild("Rules"):WaitForChild("Spotting"))
local AnimationController = require(script.Parent.AnimationController)
local BinocularController = require(script.Parent.BinocularController)

local GHOST_COLOR = Color3.fromRGB(255, 150, 60)

local Keys = Config.Keys

-- The key for each call-in slot (Config.CallIns.Slots).
local CALL_IN_KEYS: { [Enum.KeyCode]: number } = {}
for slot, key in Keys.CallIns do
	CALL_IN_KEYS[key] = slot
end

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
			"CallInEffects",
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
-- actually know where it lands"): hold the Grenade key or a thrown call-in's key, and a dotted arc from the
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
-- One throw at a time (the server's rule, ThrowWindUp): os.clock until which the hand is
-- still winding one up, with a little over for the trip to the server.
local THROW_MARGIN = 0.15
local throwingUntil = 0

-- Starts the throw clip; false while the last throw has not left the hand yet.
local function beginThrow(): boolean
	local now = os.clock()
	if now < throwingUntil then
		return false
	end
	throwingUntil = now + AnimationController.playThrow() + THROW_MARGIN
	return true
end

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

-- Grenade key held: the frag (if one is left).
local function aimGrenade()
	if ((Players.LocalPlayer:GetAttribute(Attributes.Grenades) :: number?) or 0) <= 0 then
		return
	end
	local settings = fragSettings()
	startAiming(
		Keys.Grenade,
		nil,
		settings.ThrowDistance,
		{ Shape = "ring", Radius = settings.Radius }
	)
end

-- A call-in key: a thrown call-in is aimed while the key is held and thrown on release; a "self"
-- call-in fires at once.
local function pressCallIn(key: Enum.KeyCode, slot: number)
	local player = Players.LocalPlayer
	local definition =
		CallInDefinitions.get(player:GetAttribute(Attributes.callIn(slot)) :: string?)
	if not definition then
		BinocularController.cancel()
		return
	end
	local charges = (player:GetAttribute(Attributes.callInCharges(slot)) :: number?) or 0
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	-- Marked through binoculars, not thrown: the key raises them, or lowers them again.
	if Spotting.mode(cfg) == "Binoculars" then
		if charges > 0 or BinocularController.isUp() then
			stopAiming()
			BinocularController.press(slot)
		end
		return
	end
	BinocularController.cancel()
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
	-- The clip starts now; the server lets go at its release (ThrowWindUp).
	if not beginThrow() then
		return
	end
	if state.slot then
		Remotes.get("CallIn"):FireServer(state.slot, target)
	else
		Remotes.get("UseAbility"):FireServer(Messages.Ability.Grenade, target)
	end
end

-- The flare key: the flare goes at the crosshair at once. The clip plays when the squad can pay for
-- a pallet and none is inbound (the server's own gates, RequisitionService).
local function throwFlare()
	local pool = (workspace:GetAttribute(Attributes.ResupplyPool) :: number?) or 0
	local cost = (workspace:GetAttribute(Attributes.ResupplyCost) :: number?) or 1
	local dropIn = (workspace:GetAttribute(Attributes.ResupplyDropIn) :: number?) or -1
	if pool < cost or dropIn >= 0 or not beginThrow() then
		return
	end
	Remotes.get("Resupply")
		:FireServer(Messages.Resupply.Flare, landingPoint(Config.Requisition.FlareThrowDistance))
end

function AbilityController.init()
	local useAbility = Remotes.get("UseAbility")

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
			return
		end
		-- Any other kit key takes the hands off the binoculars.
		if
			key == Keys.SwapGun
			or key == Keys.Grenade
			or key == Keys.Shove
			or key == Keys.Stim
			or key == Keys.Flare
		then
			BinocularController.cancel()
		end
		if key == Keys.SwapGun then
			useAbility:FireServer(Messages.Ability.Swap)
		elseif key == Keys.Grenade then
			aimGrenade()
		elseif key == Keys.Shove then
			useAbility:FireServer(Messages.Ability.Shove)
		elseif key == Keys.Stim then
			useAbility:FireServer(Messages.Ability.Stim)
		elseif key == Keys.Flare then
			throwFlare()
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
