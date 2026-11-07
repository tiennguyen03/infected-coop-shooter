--!strict
-- Sends Q (dash) / E (breach) ability requests, the 1 / 2 call-ins (loadout rework
-- 2026-11-07) and the 3 (Resupply flare) throw to the server. The server validates and
-- performs them; this controller forwards input and draws the breach ghost: hold E and a
-- ring shows where the charge will land (the aim point, clamped to throw range, dropped to
-- the ground), release to throw it there. A tap throws at the crosshair. The call-ins and
-- the flare throw at the crosshair the same way (ThrowUtil, the server's maths).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CallInDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CallInDefinitions"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ThrowUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ThrowUtil"))
local AnimationController = require(script.Parent.AnimationController)

local GHOST_COLOR = Color3.fromRGB(255, 150, 60)

local AbilityController = {}

local targeting = false
local ghost: Model? = nil
local ghostTarget: Vector3? = nil

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
			"AssaultEffects",
			"BreachGhost",
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

local function buildGhost(): Model
	local model = Instance.new("Model")
	model.Name = "BreachGhost"
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, Config.Assault.BreachRadius * 2, Config.Assault.BreachRadius * 2)
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
	core.Size = Vector3.new(1.2, 1.2, 1.2)
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
	local point = landingPoint(Config.Assault.BreachThrowDistance)
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
	if targeting then
		return
	end
	targeting = true
	local model = buildGhost()
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

-- Key 1 or 2: the call-in in that slot, thrown at the crosshair when it is a throw kind.
local function useCallIn(slot: number)
	local player = Players.LocalPlayer
	local definition = CallInDefinitions.get(player:GetAttribute(`CallIn{slot}`) :: string?)
	if not definition then
		return
	end
	local charges = (player:GetAttribute(`CallIn{slot}Charges`) :: number?) or 0
	-- Daisy Chain: the Tripline key still goes out on an empty slot (the server blows the
	-- armed mines without a charge).
	local daisyChain = definition.Id == "tripline"
		and (
			player:GetAttribute("UpgradeCallInA") == "command_detonation"
			or player:GetAttribute("UpgradeCallInB") == "command_detonation"
		)
	if charges <= 0 and not daisyChain then
		return
	end
	local point: Vector3? = nil
	if definition.Kind == "throw" then
		local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
		point = landingPoint(cfg.ThrowDistance)
		AnimationController.playAbility("breach")
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
		if workspace:GetAttribute("GamePaused") == true then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			useAbility:FireServer("dash")
		elseif input.KeyCode == Enum.KeyCode.E then
			startTargeting()
		elseif input.KeyCode == Enum.KeyCode.One then
			useCallIn(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			useCallIn(2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			resupply:FireServer("flare", landingPoint(Config.Requisition.FlareThrowDistance))
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.E then
			local target = stopTargeting()
			if target and workspace:GetAttribute("GamePaused") ~= true then
				useAbility:FireServer("breach", target)
				AnimationController.playAbility("breach")
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
	workspace:GetAttributeChangedSignal("GamePaused"):Connect(function()
		if workspace:GetAttribute("GamePaused") == true then
			stopTargeting()
		end
	end)
end

return AbilityController
