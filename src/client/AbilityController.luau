--!strict
-- Sends Q (dash) / E (breach) ability requests and the F (Resupply flare) throw to the
-- server. The server validates and performs them; this controller forwards input and draws
-- the breach ghost: hold E and a ring shows where the charge will land (the aim point,
-- clamped to throw range, dropped to the ground), release to throw it there. A tap throws
-- at the crosshair. F throws the flare at the crosshair the same way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
	for _, name in { "Projectiles", "AssaultEffects", "BreachGhost", "Resupply" } do
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
	ghost = buildGhost()
	updateGhost()
	ghost.Parent = workspace
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

function AbilityController.init()
	local useAbility = Remotes.get("UseAbility")
	local resupply = Remotes.get("Resupply")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Don't fire abilities while the run is soft-paused (item selection).
		if workspace:GetAttribute("GamePaused") == true then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			useAbility:FireServer("dash")
		elseif input.KeyCode == Enum.KeyCode.E then
			startTargeting()
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

	-- A respawn or a pause cancels any held targeting.
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
