--!strict
-- Vehicles on this client (docs/PROGRESSION.md > The ATV; server VehicleService):
--   * the driver's client drives: each physics step runs VehiclePhysics on the chassis it
--     was given, with the seat's throttle and steer (W/S, A/D, the left stick);
--   * a ram the server counted slows it ("ram": keep that share of the speed);
--   * E (Config.Keys.Interact) gets off; while riding no prompt shows (no reviving or
--     opening crates from a seat) and the camera stops turning the body (that would drag
--     the vehicle: CameraController.setBodyYawLocked);
--   * every vehicle's wheels spin, steer and ride their springs here, for this client only
--     (the server's wheels are looks, never physics);
--   * a small panel says which seat you are in, the keys, and the vehicle's health.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local Messages = require(Shared:WaitForChild("Messages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Vehicle = require(Shared:WaitForChild("Rules"):WaitForChild("Vehicle"))
local VehicleBody = require(Shared:WaitForChild("VehicleBody"))
local VehiclePhysics = require(Shared:WaitForChild("VehiclePhysics"))

local CameraController = require(script.Parent.CameraController)
local HudTheme = require(script.Parent.HudTheme)

local VehicleController = {}

local WHEEL_RANGE = 160 -- studs: wheels farther than this from the camera are not animated

local player = Players.LocalPlayer
local folder: Instance? = nil
local remote: RemoteEvent
local riding: string? = nil -- "driver" | "gunner"
local params: RaycastParams? = nil
local paramsBuiltAt = 0
local nextPanelAt = 0 -- the panel is redrawn a few times a second, not every frame

local panel: Frame
local seatLabel: TextLabel
local keysLabel: TextLabel
local healthFill: Frame

-- ------------------------------------------------------------------ lookups

local function vehicleOf(seat: Instance?): Model?
	if not seat or not folder then
		return nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	if model and model:IsDescendantOf(folder) then
		return model
	end
	return nil
end

local function cfgOf(model: Model): any
	local id = model:GetAttribute(Attributes.VehicleId)
	local definition = if typeof(id) == "string" then CallInDefinitions.get(id) else nil
	local row = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	return row and row.Vehicle
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The wheel rays pass through the vehicles and every soldier (rebuilt now and then: bodies
-- respawn).
local function rayParams(): RaycastParams
	local now = os.clock()
	if params and now - paramsBuiltAt < 1 then
		return params
	end
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	local bots = Workspace:FindFirstChild("SquadBots")
	if bots then
		table.insert(exclude, bots)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params = VehiclePhysics.params(exclude)
	paramsBuiltAt = now
	return params :: RaycastParams
end

-- ------------------------------------------------------------------ driving

local function keyAxis(plus: { Enum.KeyCode }, minus: { Enum.KeyCode }): number
	local value = 0
	for _, key in plus do
		if UserInputService:IsKeyDown(key) then
			value += 1
			break
		end
	end
	for _, key in minus do
		if UserInputService:IsKeyDown(key) then
			value -= 1
			break
		end
	end
	return value
end

local function driveStep(dt: number)
	if riding ~= "driver" then
		return
	end
	local body = humanoid()
	local seat = body and body.SeatPart
	local model = vehicleOf(seat)
	if not model or not seat then
		return
	end
	local cfg = cfgOf(model)
	if not cfg then
		return
	end
	-- The seat's own reading (keyboard, stick) when it has one; the keys otherwise.
	local throttle, steer = 0, 0
	if seat:IsA("VehicleSeat") then
		throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	end
	if throttle == 0 then
		throttle = keyAxis(Config.Keys.Drive.Forward, Config.Keys.Drive.Back)
	end
	if steer == 0 then
		steer = keyAxis(Config.Keys.Drive.Right, Config.Keys.Drive.Left)
	end
	VehiclePhysics.step(
		model,
		cfg.Body,
		cfg,
		{ throttle = throttle, steer = steer },
		dt,
		rayParams()
	)
end

-- ------------------------------------------------------------------ wheels (looks)

type Wheel = { axle: Weld, mount: Vector3, front: boolean, angle: number, drawn: boolean }

-- Each vehicle's wheels, found once (weak keys: a destroyed vehicle drops out).
local wheelCache: { [Model]: { Wheel } } = setmetatable({}, { __mode = "k" }) :: any

local function wheelsOf(model: Model): { Wheel }
	local cached = wheelCache[model]
	if cached then
		return cached
	end
	local wheels: { Wheel } = {}
	for _, tyre in model:GetChildren() do
		local axle = tyre:FindFirstChild("Axle")
		local mount = tyre:GetAttribute("Mount")
		if tyre:IsA("BasePart") and axle and axle:IsA("Weld") and typeof(mount) == "Vector3" then
			table.insert(wheels, {
				axle = axle,
				mount = mount,
				front = tyre:GetAttribute("Front") == true,
				angle = 0,
				drawn = false,
			})
		end
	end
	wheelCache[model] = wheels
	return wheels
end

local function animateWheels(dt: number)
	if not folder then
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue -- only vehicles live here, but never trust that
		end
		local model = child
		local root = model.PrimaryPart
		local cfg = if root then cfgOf(model) else nil
		local body = cfg and VehicleBody.get(cfg.Body)
		if root and cfg and body and (root.Position - eye).Magnitude <= WHEEL_RANGE then
			local frame = root.CFrame
			local velocity = root.AssemblyLinearVelocity
			local forward = velocity:Dot(frame.LookVector)
			-- The steer the wheels show: what turns the body at this speed (no input needed).
			local yawRate = root.AssemblyAngularVelocity:Dot(frame.UpVector)
			local wheelbase = math.abs(body.wheels[1].mount.Z - body.wheels[3].mount.Z)
			local steer = if math.abs(forward) > 1
				then math.clamp(
					math.atan(yawRate * wheelbase / forward),
					-math.rad(cfg.SteerAngle),
					math.rad(cfg.SteerAngle)
				)
				else 0
			local length = cfg.Suspension.Travel + body.wheelRadius
			-- Standing still with nothing turning: the wheels stay as they were drawn.
			local moving = velocity.Magnitude > 0.3 or root.AssemblyAngularVelocity.Magnitude > 0.1
			local wheels = wheelsOf(model)
			for _, wheel in wheels do
				if moving or not wheel.drawn then
					wheel.drawn = true
					local mount = wheel.mount
					local hit = Workspace:Raycast(
						frame:PointToWorldSpace(mount),
						-frame.UpVector * length,
						rayParams()
					)
					local drop = if hit
						then hit.Distance - body.wheelRadius
						else cfg.Suspension.Travel
					-- Never drawn higher than the fenders allow (VehicleBody wheelLift).
					local y = math.min(mount.Y - drop, body.wheelLift)
					wheel.angle = (wheel.angle + forward / body.wheelRadius * dt) % (math.pi * 2)
					-- yawRate > 0 turns left; a positive Y turn points the wheel left too.
					local turn = if wheel.front then steer else 0
					wheel.axle.C0 = CFrame.new(mount.X, y, mount.Z)
						* CFrame.Angles(0, turn, 0)
						* CFrame.Angles(-wheel.angle, 0, 0)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ the panel

local function buildPanel()
	local gui = HudTheme.gui("VehicleHud", 4)
	panel = HudTheme.rect(
		gui,
		UDim2.fromOffset(300, 64),
		HudTheme.Color.Track,
		HudTheme.TrackTransparency,
		true
	)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	-- At the bottom edge: the objective banner sits just above the middle of the bottom.
	panel.Position = UDim2.new(0.5, 0, 1, -34)
	panel.Visible = false
	seatLabel = HudTheme.label(panel, { text = "", font = HudTheme.Font.Headline, size = 18 })
	seatLabel.Position = UDim2.fromOffset(12, 6)
	keysLabel = HudTheme.label(
		panel,
		{ text = "", font = HudTheme.Font.Body, size = 14, color = HudTheme.Color.TextDim }
	)
	keysLabel.Position = UDim2.fromOffset(12, 28)
	local track = HudTheme.rect(panel, UDim2.new(1, -24, 0, 5), HudTheme.Color.RedDark, 0)
	track.Position = UDim2.new(0, 12, 1, -11)
	healthFill = HudTheme.rect(track, UDim2.fromScale(1, 1), HudTheme.Color.White, 0)
	HudTheme.parent(gui)
end

local function keyName(key: Enum.KeyCode): string
	return UserInputService:GetStringForKeyCode(key) or key.Name
end

local function updatePanel()
	local body = humanoid()
	local model = vehicleOf(body and body.SeatPart)
	panel.Visible = riding ~= nil and model ~= nil
	if not panel.Visible or not model then
		return
	end
	local id = model:GetAttribute(Attributes.VehicleId)
	local definition = if typeof(id) == "string" then CallInDefinitions.get(id) else nil
	local name = string.upper(if definition then definition.Name else "Vehicle")
	local off = keyName(Config.Keys.Interact)
	if riding == "driver" then
		seatLabel.Text = `{name} · DRIVING`
		keysLabel.Text = `W / S throttle · A / D steer · {off} get off`
	else
		seatLabel.Text = `{name} · BACK SEAT`
		keysLabel.Text = `fire your rifle all round, not past the driver · {off} get off`
	end
	local health = model:GetAttribute(Attributes.VehicleHealth)
	local max = model:GetAttribute(Attributes.VehicleMaxHealth)
	local share = if typeof(health) == "number"
			and typeof(max) == "number"
			and max > 0
		then health / max
		else 1
	healthFill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	healthFill.BackgroundColor3 = if share <= 0.25 then HudTheme.Color.Red else HudTheme.Color.White
end

-- ------------------------------------------------------------------ riding state

local function setRiding(seat: string?)
	if seat == riding then
		return
	end
	riding = seat
	CameraController.setBodyYawLocked(seat ~= nil)
	ProximityPromptService.Enabled = seat == nil
	nextPanelAt = 0 -- show or hide the panel at once
end

local function watchCharacter(character: Model)
	setRiding(nil)
	local function read()
		local value = character:GetAttribute(Attributes.Riding)
		setRiding(if typeof(value) == "string" then value else nil)
	end
	character:GetAttributeChangedSignal(Attributes.Riding):Connect(read)
	read()
end

local function onInput(input: InputObject)
	if not riding or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Config.Keys.Interact or input.KeyCode == Config.Keys.GetOffPad then
		remote:FireServer(Messages.Vehicle.Exit)
	end
end

local function onMessage(kind: unknown, keep: unknown)
	if kind ~= Messages.Vehicle.Ram or typeof(keep) ~= "number" then
		return
	end
	local body = humanoid()
	local model = vehicleOf(body and body.SeatPart)
	local root = model and model.PrimaryPart
	if root and riding == "driver" then
		root.AssemblyLinearVelocity *= math.clamp(keep, 0, 1)
	end
end

-- Whether this soldier may fire along `direction` from where they sit (WeaponController):
-- the driver never; the back seat not through the driver.
function VehicleController.mayFire(direction: Vector3): boolean
	if riding == nil then
		return true
	end
	if riding == "driver" then
		return false
	end
	local body = humanoid()
	local model = vehicleOf(body and body.SeatPart)
	local root = model and model.PrimaryPart
	local cfg = model and cfgOf(model)
	if not root or not cfg then
		return true
	end
	local look = root.CFrame.LookVector
	return Vehicle.gunnerCanFire(look.X, look.Z, direction.X, direction.Z, cfg.Gunner.BlockedArc)
end

-- The seat this soldier rides in, or nil on foot.
function VehicleController.riding(): string?
	return riding
end

function VehicleController.init()
	remote = Remotes.get("Vehicle")
	task.spawn(function()
		folder = Workspace:WaitForChild("Vehicles", 30)
	end)
	buildPanel()
	remote.OnClientEvent:Connect(onMessage)
	UserInputService.InputBegan:Connect(onInput)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	RunService.PreSimulation:Connect(driveStep)
	RunService.RenderStepped:Connect(function(dt)
		animateWheels(dt)
		local now = os.clock()
		if now >= nextPanelAt then
			nextPanelAt = now + 0.2
			updatePanel()
		end
	end)
end

return VehicleController
