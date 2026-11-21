--!strict
-- Looking at the Call-ins display (CallInDisplay; owner 2026-11-16: "the guy who sells the
-- call-ins should also have something similar" to the Quartermaster's rack). "Show me the
-- call-ins." at the desk (DeskDialogUI) turns the camera onto the row of pallets behind the
-- sergeant: the call-in under the cursor lifts with a soft glow, a click frames it with its
-- card (name, designation, ON YOUR RECORD or its price with BUY, what it does, uses and
-- recharge) in the screen the card leaves free, arrows step through every piece, Back steps
-- out, Back again leaves. The same look and keys as the rack (ArmsRackUI); all local, so four
-- soldiers can look at once. Each pallet's plate also says, for this soldier only, ON YOUR
-- RECORD or its price, so what is owned reads from across the hangar.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local DistrictUnlock = require(ReplicatedStorage.Shared.Rules.DistrictUnlock)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local HoldStill = require(script.Parent.HoldStill)
local HudTheme = require(script.Parent.HudTheme)
local RecordClient = require(script.Parent.RecordClient)

local CallInDisplayUI = {}

local RACK = Config.Lobby.Rack -- camera glide, glow and fields of view, as at the rack
local TUNING = Config.Lobby.CallInDisplay
local EASE = TweenInfo.new(RACK.CameraSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local LIFT = TweenInfo.new(RACK.SlideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACTION_BACK = "CallInDisplayBack"
local ACTION_NEXT = "CallInDisplayNext"
local ACTION_PREV = "CallInDisplayPrev"

type Mode = "closed" | "view" | "inspect"

local player = Players.LocalPlayer
local mode: Mode = "closed"
local desk: LobbyDesks.Desk? = nil
local prompt: ProximityPrompt? = nil
local order: { string } = {}
local selected = 0
local hovered: Model? = nil
local bases: { [Model]: CFrame } = {}
local glow: Highlight? = nil
local hidden: { Instance } = {}
local meritsBefore = 0

-- --------------------------------------------------------------- the row in the world
local function folder(): Instance?
	local desks = Workspace:FindFirstChild("Desks")
	return desks and desks:FindFirstChild("CallInDisplay")
end

local function piece(id: string): Model?
	local row = folder()
	local model = row and row:FindFirstChild(id)
	return if model and model:IsA("Model") then model else nil
end

local function faceOf(thing: Instance): Vector3
	local face = thing:GetAttribute(Attributes.RackFace)
	return if typeof(face) == "Vector3" then face.Unit else Vector3.new(-1, 0, 0)
end

local function lift(model: Model, up: number)
	local base = bases[model]
	if not base then
		base = model:GetPivot()
		bases[model] = base
	end
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe)
		model:PivotTo(cframe)
	end)
	local tween = TweenService:Create(value, LIFT, { Value = base + Vector3.new(0, up, 0) })
	tween.Completed:Once(function()
		value:Destroy()
	end)
	tween:Play()
end

local function setGlow(model: Model?)
	if glow then
		glow:Destroy()
		glow = nil
	end
	if model then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = HudTheme.Color.Yellow
		highlight.FillTransparency = RACK.GlowFill
		highlight.OutlineColor = HudTheme.Color.Yellow
		highlight.OutlineTransparency = RACK.GlowOutline
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = model
		highlight.Parent = model
		glow = highlight
	end
end

local function hover(model: Model?)
	if model == hovered then
		return
	end
	if hovered then
		lift(hovered, 0)
	end
	hovered = model
	if model then
		lift(model, TUNING.Lift)
	end
	setGlow(model)
end

local function pick(screen: Vector2): Model?
	local row = folder()
	local hits = row and row:FindFirstChild("Hits")
	local camera = Workspace.CurrentCamera
	if not (hits and camera) then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { hits }
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 80, params)
	local id = hit and hit.Instance.Name
	return if id and table.find(order, id) then piece(id) else nil
end

-- --------------------------------------------------------------- the screen
local gui = HudTheme.gui("CallInDisplayUI", 7)

local function button(parent: Instance, text: string, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 40)
	b.BackgroundColor3 = HudTheme.Color.Track
	b.BackgroundTransparency = HudTheme.TrackTransparency
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = HudTheme.Font.Line
	b.TextSize = 18
	b.TextColor3 = HudTheme.Color.Text
	b.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = HudTheme.Color.White
	stroke.Transparency = HudTheme.OutlineTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	b.Parent = parent
	return b
end

local function column(parent: Instance, gap: number)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = parent
end

-- The header, top left: the desk, the display, the sergeant's line, the merits.
local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(HudTheme.Margin * 2, HudTheme.Margin * 2)
header.AutomaticSize = Enum.AutomaticSize.XY
header.Visible = false
header.Parent = gui
column(header, 2)
local kicker = HudTheme.label(header, { size = 15, color = HudTheme.Color.TextDim })
kicker.LayoutOrder = 1
local title = HudTheme.label(header, { size = 34, font = HudTheme.Font.Headline })
title.LayoutOrder = 2
local say =
	HudTheme.label(header, { size = 17, font = HudTheme.Font.Body, color = HudTheme.Color.TextDim })
say.LayoutOrder = 3
local merits = HudTheme.label(
	header,
	{ size = 20, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow }
)
merits.LayoutOrder = 4

local hint = HudTheme.label(
	gui,
	{ size = 16, color = HudTheme.Color.TextDim, align = Enum.TextXAlignment.Center }
)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -HudTheme.Margin * 5)
hint.Visible = false

local bar = Instance.new("Frame")
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -HudTheme.Margin * 2)
bar.Size = UDim2.fromOffset(300, 40)
bar.Visible = false
bar.Parent = gui
local barList = Instance.new("UIListLayout")
barList.FillDirection = Enum.FillDirection.Horizontal
barList.HorizontalAlignment = Enum.HorizontalAlignment.Center
barList.SortOrder = Enum.SortOrder.LayoutOrder
barList.Padding = UDim.new(0, 10)
barList.Parent = bar
local prevButton = button(bar, "◀", 56)
prevButton.LayoutOrder = 1
local backButton = button(bar, "Back", 140)
backButton.LayoutOrder = 2
local nextButton = button(bar, "▶", 56)
nextButton.LayoutOrder = 3

-- The card, right: the call-in, its status and BUY, what it does, its numbers.
local card = HudTheme.rect(
	gui,
	UDim2.fromOffset(400, 0),
	HudTheme.Color.Track,
	HudTheme.TrackTransparency,
	true
)
card.AnchorPoint = Vector2.new(1, 0.5)
card.Position = UDim2.new(1, -HudTheme.Margin * 2, 0.5, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.Visible = false
do
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = card
end
column(card, 6)
local cardName = HudTheme.label(card, { size = 30, font = HudTheme.Font.Headline })
cardName.LayoutOrder = 1
local cardDesignation = HudTheme.label(card, { size = 16, color = HudTheme.Color.TextDim })
cardDesignation.LayoutOrder = 2
local cardStatus = HudTheme.label(card, { size = 16, font = HudTheme.Font.Headline, rich = true })
cardStatus.LayoutOrder = 3
local cardBuy = button(card, "", 364)
cardBuy.LayoutOrder = 4
cardBuy.Font = HudTheme.Font.Headline
cardBuy.Visible = false
local cardLine = HudTheme.label(card, { size = 15, font = HudTheme.Font.Body })
cardLine.LayoutOrder = 5
cardLine.AutomaticSize = Enum.AutomaticSize.Y
cardLine.Size = UDim2.fromScale(1, 0)
cardLine.TextWrapped = true
local cardRows = HudTheme.label(card, { size = 15, color = HudTheme.Color.TextDim, rich = true })
cardRows.LayoutOrder = 6
cardRows.AutomaticSize = Enum.AutomaticSize.Y
cardRows.Size = UDim2.fromScale(1, 0)
cardRows.TextWrapped = true
local cardCount = HudTheme.label(card, { size = 14, color = HudTheme.Color.TextDim })
cardCount.LayoutOrder = 7

HudTheme.parent(gui)

-- --------------------------------------------------------------- the plates' status
-- Each pallet's plate (CallInDisplay's Status parts) says, for this soldier, ON YOUR RECORD or
-- the price. SurfaceGuis in PlayerGui, adorned to the parts: only this soldier sees them.
local statusLabels: { [string]: TextLabel } = {}
local plateLabels: LobbyDesks.Rack? = nil
for _, entry in LobbyDesks do
	plateLabels = plateLabels or entry.display
end

local function statusText(id: string): (string, Color3)
	local onIssue = if plateLabels then plateLabels.onIssue else "ON YOUR RECORD"
	local currency = if plateLabels then plateLabels.currency else "MERITS"
	if RecordClient.owns(id) then
		return onIssue, HudTheme.Color.Yellow
	end
	return `{RecordClient.priceOf(id) or 0} {currency}`, HudTheme.Color.Text
end

local function paintPlates()
	for id, label in statusLabels do
		local text, color = statusText(id)
		label.Text = text
		label.TextColor3 = color
	end
end

local function watchPlates(row: Instance)
	local plates = row:WaitForChild("Plates", 30)
	if not plates then
		return
	end
	local function add(part: Instance)
		local id = part:GetAttribute(Attributes.RackDisplay)
		if not (part:IsA("BasePart") and type(id) == "string") or statusLabels[id] then
			return
		end
		local surface = Instance.new("SurfaceGui")
		surface.Name = `CallInStatus_{id}`
		surface.Adornee = part
		surface.Face = Enum.NormalId.Front
		surface.PixelsPerStud = 60
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = HudTheme.Font.Headline
		label.TextScaled = true
		label.TextStrokeTransparency = 0.6
		label.Parent = surface
		surface.Parent = player:WaitForChild("PlayerGui")
		statusLabels[id] = label
		local text, color = statusText(id)
		label.Text = text
		label.TextColor3 = color
	end
	for _, part in plates:GetChildren() do
		add(part)
	end
	plates.ChildAdded:Connect(add)
end

-- --------------------------------------------------------------- camera
local function tweenCamera(cframe: CFrame, fov: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, EASE, { CFrame = cframe, FieldOfView = fov }):Play()
end

-- The camera that fits `size` (across, up) at `target`, looking against `face`, into a share
-- of the screen (`across` of its width, `shift` the fraction left of centre the thing sits).
local function fitView(
	target: Vector3,
	face: Vector3,
	size: Vector2,
	fov: number,
	across: number,
	shift: number,
	minDistance: number
): CFrame
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1600, 900)
	local tanHalf = math.tan(math.rad(fov) / 2)
	local margin = math.max(size.X, size.Y) * RACK.Margin
	local aspect = viewport.X / math.max(viewport.Y, 1)
	local distance = math.max(
		(size.X + margin * 2) / (2 * tanHalf * aspect * across),
		(size.Y + margin * 2) / (2 * tanHalf * 0.6),
		minDistance
	)
	local look =
		CFrame.lookAt(target + face * distance + Vector3.new(0, distance * 0.25, 0), target)
	-- Slide the camera so the thing sits left of centre when the card takes the right.
	local studsAcross = 2 * distance * tanHalf * aspect
	return look + look.RightVector * studsAcross * shift
end

local function overview()
	local row = folder()
	local board = row and row:FindFirstChild("DisplayBoard")
	if not (board and board:IsA("BasePart")) then
		return
	end
	local span = board:GetAttribute(Attributes.RackSpan)
	local size = if typeof(span) == "Vector2" then span else Vector2.new(board.Size.X, 5)
	local face = faceOf(board)
	-- Aim at the middle of the row, half way up the pieces.
	local target = board.Position + face * 2 - Vector3.new(0, 1.5, 0)
	tweenCamera(fitView(target, face, size, RACK.RackFov, 0.9, 0, 0), RACK.RackFov)
end

local function frame(model: Model)
	local face = faceOf(model)
	local span = model:GetAttribute(Attributes.RackSpan)
	local size = if typeof(span) == "Vector2" then span else Vector2.new(3, 2)
	local base = bases[model] or model:GetPivot()
	local hit = folder() and (folder() :: Instance):FindFirstChild("Hits")
	local box = hit and hit:FindFirstChild(model.Name)
	local centre = if box and box:IsA("BasePart") then box.Position else base.Position
	tweenCamera(
		fitView(centre, face, size, RACK.InspectFov, 0.45, 0.2, RACK.MinInspectDistance),
		RACK.InspectFov
	)
end

-- --------------------------------------------------------------- the card
local function fillCard(id: string)
	local labels = desk and desk.display
	local def = CallInDefinitions.get(id)
	if not (labels and def) then
		return
	end
	cardName.Text = string.upper(def.Name)
	cardDesignation.Text = def.Codename
	local owned = RecordClient.owns(id)
	local price = RecordClient.priceOf(id)
	cardStatus.Text = if owned
		then HudTheme.tint(labels.onIssue, HudTheme.Color.Yellow)
		else `{labels.notOnIssue}  {HudTheme.tint(
			`{price or 0} {labels.currency}`,
			HudTheme.Color.TextDim
		)}`
	local forSale = not owned and price ~= nil and RecordClient.loaded()
	cardBuy.Visible = forSale
	if forSale then
		local short = RecordClient.merits() < (price :: number)
		local lock = RecordClient.lockText(id)
		cardBuy.Text = if lock
			then `{lock} · {price} {labels.currency}`
			elseif short then `{labels.buy} · {price} {labels.currency} (SHORT)`
			else `{labels.buy} · {price} {labels.currency}`
		cardBuy.TextTransparency = if short or lock then 0.5 else 0
	end
	cardLine.Text = def.Description
	local row = (Config.CallIns :: any)[def.ConfigKey] or {}
	local lines: { string } = {}
	if type(row.Charges) == "number" then
		table.insert(
			lines,
			`Uses before it recharges   {HudTheme.tint(tostring(row.Charges), HudTheme.Color.Text)}`
		)
	end
	if type(row.Cooldown) == "number" then
		table.insert(lines, `Recharge   {HudTheme.tint(`{row.Cooldown} s`, HudTheme.Color.Text)}`)
	end
	cardRows.Text = table.concat(lines, "\n")
	cardCount.Text = `{selected} / {#order}`
end

-- --------------------------------------------------------------- modes
local function hideFigures(hide: boolean)
	for _, thing in hidden do
		if thing:IsA("BasePart") then
			thing.LocalTransparencyModifier = 0
		elseif thing:IsA("BillboardGui") then
			thing.Enabled = true
		end
	end
	table.clear(hidden)
	if not (hide and desk) then
		return
	end
	-- The sergeant, his sign and this soldier's own body stand between the camera and the row.
	local desks = Workspace:FindFirstChild("Desks")
	local figures: { Instance } = {}
	local sergeant = desks and desks:FindFirstChild(desk.title)
	if sergeant then
		table.insert(figures, sergeant)
	end
	if player.Character then
		table.insert(figures, player.Character)
	end
	for _, figure in figures do
		for _, thing in figure:GetDescendants() do
			if thing:IsA("BasePart") then
				thing.LocalTransparencyModifier = 1
				table.insert(hidden, thing)
			elseif thing:IsA("BillboardGui") and thing.Enabled then
				thing.Enabled = false
				table.insert(hidden, thing)
			end
		end
	end
end

local function showOverlay()
	local open = mode ~= "closed"
	header.Visible = open
	hint.Visible = mode == "view"
	bar.Visible = open
	prevButton.Visible = mode == "inspect"
	nextButton.Visible = mode == "inspect"
	card.Visible = mode == "inspect"
end

local function inspect(index: number)
	local id = order[index]
	local model = id and piece(id)
	if not model then
		return
	end
	if mode == "inspect" and selected ~= index then
		local previous = piece(order[selected])
		if previous then
			lift(previous, 0)
		end
	end
	hovered = nil
	mode = "inspect"
	selected = index
	lift(model, TUNING.Lift)
	setGlow(model)
	frame(model)
	fillCard(id)
	showOverlay()
end

local function leave()
	hover(nil)
	for model, base in bases do
		if model.Parent then
			model:PivotTo(base)
		end
	end
	table.clear(bases)
	setGlow(nil)
	selected = 0
	ContextActionService:UnbindAction(ACTION_BACK)
	ContextActionService:UnbindAction(ACTION_NEXT)
	ContextActionService:UnbindAction(ACTION_PREV)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = RACK.PlayFov
	end
	hideFigures(false)
	HoldStill.set(false)
	if prompt then
		prompt.Enabled = true
	end
	mode = "closed"
	showOverlay()
end

local function backAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if mode == "inspect" then
			local model = piece(order[selected])
			if model then
				lift(model, 0)
			end
			setGlow(nil)
			selected = 0
			mode = "view"
			overview()
			showOverlay()
		elseif mode == "view" then
			leave()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function stepAction(step: number): (string, Enum.UserInputState) -> Enum.ContextActionResult
	return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin or #order == 0 then
			return Enum.ContextActionResult.Pass
		end
		if mode == "inspect" then
			inspect((selected - 1 + step) % #order + 1)
			return Enum.ContextActionResult.Sink
		elseif mode == "view" then
			-- A gamepad (or the arrow keys) starts at the first piece from the overview.
			hover(nil)
			inspect(if step > 0 then 1 else #order)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
end

-- Opens the display for `chosen` (a desk with `display`), talked to through `from`. False
-- when the row is not built (the caller falls back to its list, DeskShop).
function CallInDisplayUI.open(chosen: LobbyDesks.Desk, from: ProximityPrompt): boolean
	local labels = chosen.display
	local row = folder()
	if not (labels and row and row:FindFirstChild("DisplayBoard")) or mode ~= "closed" then
		return false
	end
	order = KitPrices.soldAt(chosen.id)
	if #order == 0 then
		return false
	end
	desk = chosen
	prompt = from
	mode = "view"
	kicker.Text = chosen.title
	title.Text = labels.header
	say.Text = `"{chosen.talk.openLine}"`
	merits.Text = RecordClient.balanceText()
	meritsBefore = RecordClient.merits()
	hint.Text = if HudTheme.isTouch()
		then "Tap a call-in to look closer"
		else "Click a call-in to look closer   ·   Backspace to step back"
	HoldStill.set(true)
	from.Enabled = false
	hideFigures(true)
	paintPlates()
	overview()
	ContextActionService:BindAction(
		ACTION_BACK,
		backAction,
		false,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindAction(
		ACTION_NEXT,
		stepAction(1),
		false,
		Enum.KeyCode.Right,
		Enum.KeyCode.D,
		Enum.KeyCode.DPadRight
	)
	ContextActionService:BindAction(
		ACTION_PREV,
		stepAction(-1),
		false,
		Enum.KeyCode.Left,
		Enum.KeyCode.A,
		Enum.KeyCode.DPadLeft
	)
	showOverlay()
	return true
end

function CallInDisplayUI.isOpen(): boolean
	return mode ~= "closed"
end

function CallInDisplayUI.init()
	task.spawn(function()
		local desks = Workspace:WaitForChild("Desks", 60)
		local row = desks and desks:WaitForChild("CallInDisplay", 60)
		if row then
			watchPlates(row)
		end
	end)

	cardBuy.Activated:Connect(function()
		local id = order[selected]
		if mode == "inspect" and id then
			meritsBefore = RecordClient.merits()
			RecordClient.buy(id)
		end
	end)
	RecordClient.Changed:Connect(function()
		paintPlates()
		if mode == "closed" or not desk then
			return
		end
		merits.Text = RecordClient.balanceText()
		if RecordClient.merits() < meritsBefore then
			say.Text = `"{desk.talk.bought}"`
		end
		meritsBefore = RecordClient.merits()
		if mode == "inspect" and order[selected] then
			fillCard(order[selected])
		end
	end)
	RecordClient.Refused:Connect(function(id: unknown, reason: unknown)
		if desk and mode ~= "closed" then
			say.Text = if reason == "locked" and typeof(id) == "string"
				then DistrictUnlock.need(KitPrices.unlockOf(id))
				elseif reason == "short" then `"{desk.talk.short}"`
				else `"{desk.talk.refused}"`
		end
	end)

	backButton.Activated:Connect(function()
		backAction(ACTION_BACK, Enum.UserInputState.Begin)
	end)
	prevButton.Activated:Connect(function()
		stepAction(-1)(ACTION_PREV, Enum.UserInputState.Begin)
	end)
	nextButton.Activated:Connect(function()
		stepAction(1)(ACTION_NEXT, Enum.UserInputState.Begin)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if mode == "view" and input.UserInputType == Enum.UserInputType.MouseMovement then
			hover(pick(Vector2.new(input.Position.X, input.Position.Y)))
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or mode ~= "view" then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local model = pick(Vector2.new(input.Position.X, input.Position.Y))
			local index = model and table.find(order, model.Name)
			if index then
				inspect(index)
			end
		end
	end)
	player.CharacterRemoving:Connect(function()
		if mode ~= "closed" then
			leave()
		end
	end)
end

return CallInDisplayUI
