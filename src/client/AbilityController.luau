--!strict
-- The soldier's keys (docs/PROGRESSION.md > Loadout): Q swaps long gun and sidearm, G throws
-- a grenade, V shoves, E uses a stim (KitService over UseAbility), 1-4 fire the call-ins
-- (CallIn remote) and 5 throws the Resupply flare. The server validates and performs them;
-- this controller forwards input and draws the grenade ghost: hold G and a ring shows where
-- the frag will land (the aim point, clamped to throw range, dropped to the ground) and how
-- far it reaches; release to throw it there. The call-ins and the flare throw at the
-- crosshair the same way (ThrowUtil, the server's maths).

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

local targeting = false
local ghost: Model? = nil
local ghostTarget: Vector3? = nil

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

local function buildGhost(radius: number): Model
	local model = Instance.new("Model")
	model.Name = "GrenadeGhost"
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = GHOST_COLOR
	ring.Transparency = 0.75
	ring.Parent = model
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.8, 0.8, 0.8)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = GHOST_COLOR
	core.Transparency = 0.3
	core.Parent = model
	model.PrimaryPart = core
	return model
end

local function updateGhost()
	local point = landingPoint(fragSettings().ThrowDistance)
	ghostTarget = point
	if not ghost or not point then
		return
	end
	local ring = ghost:FindFirstChild("Ring") :: BasePart
	local core = ghost:FindFirstChild("Core") :: BasePart
	ring.CFrame = CFrame.new(point + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	core.CFrame = CFrame.new(point + Vector3.new(0, 1, 0))
end

local function startTargeting()
	if
		targeting
		or ((Players.LocalPlayer:GetAttribute(Attributes.Grenades) :: number?) or 0) <= 0
	then
		return
	end
	targeting = true
	local model = buildGhost(fragSettings().Radius)
	ghost = model
	updateGhost()
	model.Parent = workspace
end

local function stopTargeting(): Vector3?
	if not targeting then
		return nil
	end
	targeting = false
	local target = ghostTarget
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostTarget = nil
	return target
end

-- Keys 1-4: the call-in in that slot, thrown at the crosshair when it is a throw kind.
local function useCallIn(slot: number)
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
	local point: Vector3? = nil
	if definition.Kind == "throw" then
		local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
		point = landingPoint(cfg.ThrowDistance)
		AnimationController.playAbility("throw")
	end
	Remotes.get("CallIn"):FireServer(slot, point)
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
			useCallIn(slot)
		elseif key == Enum.KeyCode.Q then
			useAbility:FireServer(Messages.Ability.Swap)
		elseif key == Enum.KeyCode.G then
			startTargeting()
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
		if input.KeyCode == Enum.KeyCode.G then
			local target = stopTargeting()
			if target and workspace:GetAttribute(Attributes.GamePaused) ~= true then
				useAbility:FireServer(Messages.Ability.Grenade, target)
				AnimationController.playAbility("throw")
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if targeting then
			updateGhost()
		end
	end)

	-- A respawn or the freeze cancels any held targeting.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		stopTargeting()
	end)
	workspace:GetAttributeChangedSignal(Attributes.GamePaused):Connect(function()
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			stopTargeting()
		end
	end)
end

return AbilityController
