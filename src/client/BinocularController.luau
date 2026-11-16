--!strict
-- Binoculars (docs/PROGRESSION.md > Binoculars; Rules/Spotting): how a call-in whose Config
-- row says AimMode "Binoculars" (the Anvil) is aimed. Its slot key raises them
-- (AbilityController.press): the camera goes to the eye and narrows (CameraController
-- setScope), the gun is put away (WeaponController.setBlocked), a black mask with a thin
-- reticle and a range readout covers the screen, and a ring on the ground shows where the
-- round will land: the first surface under the crosshair, dropped to the foot of a wall,
-- measured with SpotUtil exactly as the server will measure it again from the head. Fire
-- (left click, gamepad Binoculars.ConfirmKey) sends the mark over the CallIn remote; right
-- click, Binoculars.CancelKey, the slot's key again or any other kit key lowers them. The
-- server is told when they go up and come down (CallInSpot) so the squad sees it
-- (BinocularPose). The readout is written only when it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpotUtil = require(Shared:WaitForChild("SpotUtil"))
local Spotting = require(Shared:WaitForChild("Rules"):WaitForChild("Spotting"))
local CameraController = require(script.Parent.CameraController)
local HudTheme = require(script.Parent.HudTheme)
local WeaponController = require(script.Parent.WeaponController)

local C = HudTheme.Color
local EXCLUSION_REFRESH = 0.25 -- seconds between rebuilding what the sight lines ignore
local READOUT_INTERVAL = 1 / 15 -- the range is rewritten at most this often
local REFUSED = Color3.fromRGB(150, 154, 160)
local BAR = 6000 -- px: a mask bar reaches past any screen
local REASON_TEXT: { [string]: string } = {
	range = "OUT OF RANGE",
	close = "TOO CLOSE",
	sight = "NO LINE OF SIGHT",
	ground = "NO GROUND",
}

type Up = {
	slot: number,
	settings: Spotting.Settings,
	color: Color3, -- the call-in's accent (CallInDefinitions.Color)
	seen: { Instance }, -- what the look passes through
	clear: { Instance }, -- that and the Infected
	excludedAt: number,
	marker: Model,
	ring: Part,
	post: Part,
	point: Vector3?,
	ok: boolean,
}

local BinocularController = {}

local state: Spotting.State = "Lowered"
local up: Up? = nil
local holdingGun = false -- the weapon is blocked until the binoculars are fully down

local maskGui: ScreenGui
local glass: Frame
local glassStroke: UIStroke
local maskPieces: { Frame } = {}
local readoutGui: ScreenGui
local titleLabel: TextLabel
local rangeLabel: TextLabel
local statusLabel: TextLabel
local hintLabel: TextLabel
local lastRange = ""
local lastStatus = ""
local lastReadoutAt = 0

local function ghost(name: string, parent: Instance, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Parent = parent
	return part
end

-- A black bar hung off one side of the glass, reaching past the screen edge.
local function bar(anchor: Vector2, position: UDim2, size: UDim2)
	local piece = Instance.new("Frame")
	piece.AnchorPoint = anchor
	piece.Position = position
	piece.Size = size
	piece.BackgroundColor3 = Color3.new(0, 0, 0)
	piece.BorderSizePixel = 0
	piece.Parent = glass
	table.insert(maskPieces, piece)
end

-- A reticle line (1 px, white) inside the glass.
local function line(position: UDim2, size: UDim2)
	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = position
	piece.Size = size
	piece.BackgroundColor3 = C.White
	piece.BackgroundTransparency = 0.35
	piece.BorderSizePixel = 0
	piece.Parent = glass
end

local function buildGui()
	local settings = Config.CallIns.Binoculars
	-- The mask: everything outside a pill-shaped glass is black. Four bars cover the screen
	-- around the glass's box and a thick stroke rounds its corners.
	maskGui = Instance.new("ScreenGui")
	maskGui.Name = "BinocularMask"
	maskGui.ResetOnSpawn = false
	maskGui.IgnoreGuiInset = true
	maskGui.DisplayOrder = -5 -- under the HUD
	maskGui.Enabled = false
	glass = Instance.new("Frame")
	glass.Name = "Glass"
	glass.AnchorPoint = Vector2.new(0.5, 0.5)
	glass.Position = UDim2.fromScale(0.5, 0.5)
	glass.Size = UDim2.fromScale(0.96, settings.MaskHeight)
	glass.BackgroundTransparency = 1
	glass.BorderSizePixel = 0
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = settings.MaskWidth
	aspect.Parent = glass
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = glass
	glassStroke = Instance.new("UIStroke")
	glassStroke.Color = Color3.new(0, 0, 0)
	glassStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glassStroke.Parent = glass
	glass.Parent = maskGui
	bar(Vector2.new(1, 0.5), UDim2.fromScale(0, 0.5), UDim2.fromOffset(BAR, BAR * 2))
	bar(Vector2.new(0, 0.5), UDim2.fromScale(1, 0.5), UDim2.fromOffset(BAR, BAR * 2))
	bar(Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0), UDim2.fromOffset(BAR * 2, BAR))
	bar(Vector2.new(0.5, 0), UDim2.fromScale(0.5, 1), UDim2.fromOffset(BAR * 2, BAR))
	-- The stroke has to fill the square corners the pill leaves: a quarter of its height.
	local function fitStroke()
		glassStroke.Thickness = math.max(glass.AbsoluteSize.Y * 0.25, 1)
	end
	glass:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStroke)
	fitStroke()
	-- The reticle: a cross open at the centre, with range ticks on the lower arm.
	line(UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(3, 3))
	line(UDim2.new(0.5, -70, 0.5, 0), UDim2.fromOffset(100, 1))
	line(UDim2.new(0.5, 70, 0.5, 0), UDim2.fromOffset(100, 1))
	line(UDim2.new(0.5, 0, 0.5, -70), UDim2.fromOffset(1, 100))
	line(UDim2.new(0.5, 0, 0.5, 70), UDim2.fromOffset(1, 100))
	for tick = 1, 4 do
		line(UDim2.new(0.5, 0, 0.5, 20 + tick * 20), UDim2.fromOffset(18 - tick * 3, 1))
	end
	maskGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The readout: the call-in, the range to the mark, whether it can be fired on, the keys.
	readoutGui = HudTheme.gui("BinocularReadout", 6)
	readoutGui.Enabled = false
	local function centred(y: number, options: HudTheme.LabelOptions): TextLabel
		local label = HudTheme.label(readoutGui, options)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.new(0.5, 0, 0.5, y)
		label.TextXAlignment = Enum.TextXAlignment.Center
		return label
	end
	titleLabel = centred(-190, { size = 14, color = C.TextDim })
	rangeLabel = centred(150, { size = 26, font = HudTheme.Font.Headline })
	statusLabel = centred(178, { size = 14 })
	hintLabel = centred(204, { size = 12, color = C.TextDim, font = HudTheme.Font.Body })
	HudTheme.parent(readoutGui)
end

local lastFade = -1

local function setFade(alpha: number)
	if alpha == lastFade then
		return
	end
	lastFade = alpha
	local transparency = 1 - alpha
	for _, piece in maskPieces do
		piece.BackgroundTransparency = transparency
	end
	glassStroke.Transparency = transparency
end

local function writeReadout(range: string, status: string, statusColor: Color3)
	if range ~= lastRange then
		lastRange = range
		rangeLabel.Text = range
	end
	if status ~= lastStatus then
		lastStatus = status
		statusLabel.Text = status
		statusLabel.TextColor3 = statusColor
	end
end

local function refreshExclusions(current: Up)
	current.seen = SpotUtil.exclusions(false)
	current.clear = SpotUtil.exclusions(true)
	current.excludedAt = os.clock()
end

-- Puts everything away. `tell`: the server has not heard they came down (a cancel).
local function lowerNow(tell: boolean)
	local current = up
	state = "Lowered"
	up = nil
	if not current then
		return
	end
	current.marker:Destroy()
	CameraController.setScope(nil)
	if tell then
		Remotes.get("CallInSpot"):FireServer(current.slot, false)
	end
end

local function raise(slot: number)
	local player = Players.LocalPlayer
	local definition =
		CallInDefinitions.get(player:GetAttribute(Attributes.callIn(slot)) :: string?)
	local cfg = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	if not definition or not cfg then
		state = "Lowered"
		return
	end
	local settings = SpotUtil.settings(cfg)
	local marker = Instance.new("Model")
	marker.Name = "GrenadeGhost" -- the name the other aim rays skip
	local aim = cfg.Aim :: { Radius: number? }?
	local radius = (aim and aim.Radius) or (cfg.BlastRadius :: number?) or 3
	local ring = ghost("Ring", marker, 0.7)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.Color = definition.Color
	local post = ghost("Post", marker, 0.4)
	post.Size = Vector3.new(0.5, 24, 0.5)
	post.Color = definition.Color
	local created: Up = {
		slot = slot,
		settings = settings,
		color = definition.Color,
		seen = {},
		clear = {},
		excludedAt = 0,
		marker = marker,
		ring = ring,
		post = post,
		point = nil,
		ok = false,
	}
	refreshExclusions(created)
	up = created
	holdingGun = true
	WeaponController.setBlocked(true)
	CameraController.setScope(settings.FieldOfView, settings.Raise, settings.Lower)
	Remotes.get("CallInSpot"):FireServer(slot, true)
	titleLabel.Text = `{string.upper(definition.Name)}  {string.upper(definition.Codename)}`
	hintLabel.Text = "[LMB] FIRE MISSION    [RMB] LOWER"
	lastRange, lastStatus = "", ""
	writeReadout("-- M", "RAISING", C.TextDim)
	setFade(CameraController.scopeBlend())
	maskGui.Enabled = true
	readoutGui.Enabled = true
end

-- Feeds one event through the rule and does what it says.
local function handle(event: Spotting.Event, slot: number?)
	local current = up
	local ready = current ~= nil and current.ok and CameraController.scopeBlend() >= 1
	local nextState, action = Spotting.next(state, event, ready)
	state = nextState :: any
	if action == "raise" and slot then
		raise(slot)
	elseif action == "lower" then
		lowerNow(true)
	elseif action == "fire" and current and current.point then
		Remotes.get("CallIn"):FireServer(current.slot, current.point)
		lowerNow(false)
	end
end

-- The slot key of a binoculars call-in: up, or down again; another binoculars slot swaps.
function BinocularController.press(slot: number)
	local current = up
	if current and current.slot ~= slot then
		handle("cancel")
	end
	handle("key", slot)
end

-- Anything else the soldier does with their hands lowers them.
function BinocularController.cancel()
	if up then
		handle("cancel")
	end
end

function BinocularController.isUp(): boolean
	return up ~= nil
end

local function update()
	local blend = CameraController.scopeBlend()
	local current = up
	if not current then
		if maskGui.Enabled then
			setFade(blend)
			if blend <= 0 then
				maskGui.Enabled = false
				readoutGui.Enabled = false
			end
		end
		-- The gun comes back once the binoculars are fully down.
		if holdingGun and blend <= 0 then
			holdingGun = false
			WeaponController.setBlocked(false)
		end
		return
	end
	setFade(blend)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	if now - current.excludedAt > EXCLUSION_REFRESH then
		refreshExclusions(current)
	end
	local settings = current.settings
	local eye = camera.CFrame.Position
	local point =
		SpotUtil.sight(eye, camera.CFrame.LookVector, settings, current.seen, current.clear)
	local ok, reason = false, "ground" :: string?
	local distance = 0
	if point then
		local measured = SpotUtil.measure(eye, point, settings, current.clear)
		distance = measured.distance
		ok, reason = Spotting.check(settings, measured, false)
	end
	current.point = point
	current.ok = ok
	current.marker.Parent = if point then workspace else nil
	if point then
		local color = if ok then current.color else REFUSED
		current.ring.Color = color
		current.post.Color = color
		current.ring.CFrame = CFrame.new(point + Vector3.new(0, 0.15, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		current.post.CFrame = CFrame.new(point + Vector3.new(0, 12, 0))
	end
	if now - lastReadoutAt < READOUT_INTERVAL then
		return
	end
	lastReadoutAt = now
	local range = if point then Spotting.rangeText(distance, settings.MetresPerStud) else "-- M"
	if blend < 1 then
		writeReadout(range, "RAISING", C.TextDim)
	elseif ok then
		writeReadout(range, "MARK SET", C.Yellow)
	else
		writeReadout(range, REASON_TEXT[reason or "ground"] or "NO MARK", C.RedLight)
	end
end

function BinocularController.init()
	buildGui()
	local settings = Config.CallIns.Binoculars
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not up then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == settings.ConfirmKey
		then
			handle("fire")
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.KeyCode == settings.CancelKey
		then
			handle("cancel")
		end
	end)
	RunService.RenderStepped:Connect(update)

	-- A respawn, going down, the freeze or a slot that changed under them: they come down.
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(BinocularController.cancel)
	player:GetAttributeChangedSignal(Attributes.SquadState):Connect(function()
		if player:GetAttribute(Attributes.SquadState) ~= "Alive" then
			BinocularController.cancel()
		end
	end)
	workspace:GetAttributeChangedSignal(Attributes.GamePaused):Connect(function()
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			BinocularController.cancel()
		end
	end)
	for slot = 1, Config.CallIns.Slots do
		player:GetAttributeChangedSignal(Attributes.callIn(slot)):Connect(function()
			local current = up
			if current and current.slot == slot then
				BinocularController.cancel()
			end
		end)
	end
end

return BinocularController
