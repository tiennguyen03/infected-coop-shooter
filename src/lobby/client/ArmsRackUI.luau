--!strict
-- The Arms Room counter (owner, 2026-11-09, after a GTA gun counter): talk to the armorer (F)
-- and choose. "Any work going?" gets his answer (no taskings yet); "Show me the rack." turns
-- the camera to the rack on the wall behind his cage (ArmsRack): the gun under the cursor
-- slides off its pegs with a soft glow, a click frames it with its card (name, the real gun,
-- the line, on issue or not, stat bars from Rules/ArmsStats), arrows step along the rack, Back
-- steps out. All local: the camera, the slide and the card are this player's alone, so four
-- soldiers can look at once. Nothing is drawn: the record is not open.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local ArmsStats = require(ReplicatedStorage.Shared.Rules.ArmsStats)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local HudTheme = require(script.Parent.HudTheme)

local ArmsRackUI = {}

local TUNING = Config.Lobby.Rack
local EASE = TweenInfo.new(TUNING.CameraSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local SLIDE = TweenInfo.new(TUNING.SlideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACTION_BACK = "ArmsRackBack"
local ACTION_NEXT = "ArmsRackNext"
local ACTION_PREV = "ArmsRackPrev"

type CardRow = { label: string, text: string, fraction: number? }
type Mode = "closed" | "talk" | "rack" | "inspect"

local player = Players.LocalPlayer
local mode: Mode = "closed"
local desk: LobbyDesks.Desk? = nil
local prompt: ProximityPrompt? = nil
local order: { string } = {} -- weapon ids along the rack
local hovered: Model? = nil
local selected = 0 -- index into `order` while inspecting
local bases: { [Model]: CFrame } = {}
local glow: Highlight? = nil
local hidden: { BasePart } = {}
local talkCloseAt = 0

-- --------------------------------------------------------------- the rack in the world
local function rackFolder(): Instance?
	local desks = Workspace:FindFirstChild("Desks")
	return desks and desks:FindFirstChild("ArmsRack")
end

local function board(): BasePart?
	local folder = rackFolder()
	local part = folder and folder:FindFirstChild("RackBoard")
	return if part and part:IsA("BasePart") then part else nil
end

local function gun(id: string): Model?
	local folder = rackFolder()
	local model = folder and folder:FindFirstChild(id)
	return if model and model:IsA("Model") then model else nil
end

-- Out of the board, into the hangar.
local function outward(): Vector3
	local part = board()
	return if part then part.CFrame.RightVector else Vector3.new(1, 0, 0)
end

local function slide(model: Model, forward: number)
	local base = bases[model]
	if not base then
		base = model:GetPivot()
		bases[model] = base
	end
	-- Tween a CFrameValue and pivot the model to it (a Model has no tweenable CFrame).
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe)
		model:PivotTo(cframe)
	end)
	local tween = TweenService:Create(value, SLIDE, { Value = base + outward() * forward })
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
		-- A soft rim, not a lit display (the rack is a wall behind a wire cage).
		local highlight = Instance.new("Highlight")
		highlight.FillColor = HudTheme.Color.Yellow
		highlight.FillTransparency = TUNING.GlowFill
		highlight.OutlineColor = HudTheme.Color.Yellow
		highlight.OutlineTransparency = TUNING.GlowOutline
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
		slide(hovered, 0)
	end
	hovered = model
	if model then
		slide(model, TUNING.SlideOut)
	end
	setGlow(model)
end

local function pick(screen: Vector2): Model?
	local folder = rackFolder()
	local camera = Workspace.CurrentCamera
	if not (folder and camera) then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 40, params)
	local part = hit and hit.Instance
	while part and part.Parent ~= folder do
		part = part.Parent
	end
	return if part and part:IsA("Model") and table.find(order, part.Name) then part else nil
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

-- Back far enough that a box of `half` (studs, wide x tall) fills the view at `fov`.
local function fitDistance(half: Vector2, fov: number): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(16, 9)
	local aspect = viewport.X / math.max(viewport.Y, 1)
	local tanHalf = math.tan(math.rad(fov) / 2)
	return math.max(half.Y / tanHalf, half.X / (tanHalf * aspect))
end

local function overview()
	local part = board()
	if not part then
		return
	end
	local half = Vector2.new(part.Size.Z / 2 + TUNING.Margin, part.Size.Y / 2 + TUNING.Margin)
	local distance = math.min(fitDistance(half, TUNING.RackFov), TUNING.MaxRackDistance)
	local eye = part.Position + outward() * distance
	tweenCamera(CFrame.lookAt(eye, part.Position), TUNING.RackFov)
end

local function frameGun(model: Model)
	local size = model:GetExtentsSize()
	local length = math.max(size.X, size.Z)
	local target = (bases[model] or model:GetPivot()).Position + outward() * TUNING.SlideOut
	local half = Vector2.new(length / 2 + TUNING.Margin * 0.5, size.Y / 2 + TUNING.Margin * 0.5)
	local distance = math.max(fitDistance(half, TUNING.InspectFov), TUNING.MinInspectDistance)
	-- Aim a little right of the gun so the card on the right does not cover it.
	local side = outward():Cross(Vector3.new(0, 1, 0)).Unit
	local aim = target - side * (length * TUNING.InspectShift)
	tweenCamera(CFrame.lookAt(aim + outward() * distance, aim), TUNING.InspectFov)
end

-- --------------------------------------------------------------- the screen
local gui = HudTheme.gui("ArmsRackUI", 7)

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

local function pad(parent: Instance, px: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px + 4)
	padding.PaddingRight = UDim.new(0, px + 4)
	padding.Parent = parent
end

-- Talk: who, the line, three choices.
local talk = HudTheme.rect(
	gui,
	UDim2.fromOffset(560, 0),
	HudTheme.Color.Track,
	HudTheme.TrackTransparency,
	true
)
talk.AnchorPoint = Vector2.new(0.5, 1)
talk.Position = UDim2.new(0.5, 0, 1, -200)
talk.AutomaticSize = Enum.AutomaticSize.Y
talk.Visible = false
pad(talk, 12)
column(talk, 8)
local talkTitle = HudTheme.label(
	talk,
	{ size = 22, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow, rich = true }
)
talkTitle.LayoutOrder = 1
local talkLine = HudTheme.label(talk, { size = 18, font = HudTheme.Font.Body })
talkLine.LayoutOrder = 2
talkLine.AutomaticSize = Enum.AutomaticSize.Y
talkLine.Size = UDim2.fromScale(1, 0)
talkLine.TextWrapped = true
local choiceWork = button(talk, "", 528)
choiceWork.LayoutOrder = 3
local choiceRack = button(talk, "", 528)
choiceRack.LayoutOrder = 4
local choiceLeave = button(talk, "", 528)
choiceLeave.LayoutOrder = 5
for _, choice in { choiceWork, choiceRack, choiceLeave } do
	choice.TextXAlignment = Enum.TextXAlignment.Left
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 14)
	inset.Parent = choice
end

-- Rack: the header, the armorer's line, a hint, Back.
local rackHeader = Instance.new("Frame")
rackHeader.BackgroundTransparency = 1
rackHeader.Position = UDim2.fromOffset(HudTheme.Margin * 2, HudTheme.Margin * 2)
rackHeader.AutomaticSize = Enum.AutomaticSize.XY
rackHeader.Visible = false
rackHeader.Parent = gui
column(rackHeader, 2)
local rackKicker =
	HudTheme.label(rackHeader, { size = 15, color = HudTheme.Color.TextDim, text = "ARMS ROOM" })
rackKicker.LayoutOrder = 1
local rackTitle = HudTheme.label(rackHeader, { size = 34, font = HudTheme.Font.Headline })
rackTitle.LayoutOrder = 2
local rackSay = HudTheme.label(
	rackHeader,
	{ size = 17, font = HudTheme.Font.Body, color = HudTheme.Color.TextDim }
)
rackSay.LayoutOrder = 3

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
bar.Size = UDim2.fromOffset(360, 40)
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

-- The card: the gun, its status, its line, its numbers.
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
pad(card, 14)
column(card, 6)
local cardName = HudTheme.label(card, { size = 30, font = HudTheme.Font.Headline })
cardName.LayoutOrder = 1
local cardDesignation = HudTheme.label(card, { size = 16, color = HudTheme.Color.TextDim })
cardDesignation.LayoutOrder = 2
local cardStatus = HudTheme.label(card, { size = 16, font = HudTheme.Font.Headline, rich = true })
cardStatus.LayoutOrder = 3
local cardLine = HudTheme.label(card, { size = 15, font = HudTheme.Font.Body })
cardLine.LayoutOrder = 4
cardLine.AutomaticSize = Enum.AutomaticSize.Y
cardLine.Size = UDim2.fromScale(1, 0)
cardLine.TextWrapped = true
local cardRows = Instance.new("Frame")
cardRows.BackgroundTransparency = 1
cardRows.Size = UDim2.fromScale(1, 0)
cardRows.AutomaticSize = Enum.AutomaticSize.Y
cardRows.LayoutOrder = 5
cardRows.Parent = card
column(cardRows, 6)
local cardCount = HudTheme.label(card, { size = 14, color = HudTheme.Color.TextDim })
cardCount.LayoutOrder = 6

local function statRow(row: CardRow, order_: number)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, if row.fraction then 30 else 20)
	frame.LayoutOrder = order_
	frame.Parent = cardRows
	local label = HudTheme.label(frame, { size = 15, text = row.label })
	label.Position = UDim2.fromOffset(0, 0)
	local value = HudTheme.label(frame, {
		size = 15,
		text = row.text,
		color = HudTheme.Color.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	local fraction = row.fraction
	if fraction then
		local track = HudTheme.rect(frame, UDim2.new(1, 0, 0, 6), HudTheme.Color.White, 0.85)
		track.Position = UDim2.fromOffset(0, 22)
		local fill = HudTheme.rect(track, UDim2.fromScale(fraction, 1), HudTheme.Color.Yellow, 0)
		fill.Name = "Fill"
	end
end

HudTheme.parent(gui)

-- --------------------------------------------------------------- the catalog
local function statsOf(id: string): ArmsStats.Stats
	local def = WeaponDefinitions.get(id)
	return {
		damage = def.Damage,
		pellets = def.Pellets,
		fireCooldown = def.FireCooldown,
		magazine = def.MagazineSize,
		reload = def.ReloadTime,
		range = def.Range,
		adsSpread = def.AdsSpread,
	}
end

local catalog = ArmsRoom.catalog()
local issued = ArmsRoom.default()
local guns: { [string]: boolean } = {}
local gunStats: { ArmsStats.Stats } = {}
for _, list in { catalog.primaries, catalog.secondaries } do
	for _, id in list do
		table.insert(order, id)
		guns[id] = true
		table.insert(gunStats, statsOf(id))
	end
end
for _, id in catalog.grenades do
	table.insert(order, id)
end

local function rowsFor(id: string): (string, string, string, { CardRow })
	if guns[id] then
		local def = WeaponDefinitions.get(id)
		local rows: { CardRow } = {}
		for _, row in ArmsStats.rows(statsOf(id), gunStats) do
			table.insert(rows, { label = row.label, text = row.text, fraction = row.fraction })
		end
		return def.Name, def.Designation, def.Description, rows
	end
	local grenade = WeaponDefinitions.grenade(id)
	local tuning = (Config.Grenade :: any)[grenade.ConfigKey]
	return grenade.Name,
		grenade.Designation,
		grenade.Description,
		{
			{ label = "Damage", text = tostring(tuning.Damage) },
			{ label = "Blast radius", text = `{tuning.Radius} studs` },
			{ label = "Fuse", text = `{tuning.FuseTime} s after it lands` },
			{ label = "Throw", text = `{tuning.ThrowDistance} studs` },
		}
end

local function isIssued(id: string): boolean
	return id == issued.primary or id == issued.secondary or id == issued.grenade
end

local function fillCard(id: string)
	local rack = desk and desk.rack
	if not rack then
		return
	end
	local name, designation, line, rows = rowsFor(id)
	cardName.Text = name
	cardDesignation.Text = designation
	cardStatus.Text = if isIssued(id)
		then HudTheme.tint(rack.onIssue, HudTheme.Color.Yellow)
		else `{rack.notOnIssue}  {HudTheme.tint(rack.notOnIssueWhy, HudTheme.Color.TextDim)}`
	cardLine.Text = line
	for _, child in cardRows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, row in rows do
		statRow(row, index)
	end
	cardCount.Text = `{selected} / {#order}`
end

-- --------------------------------------------------------------- modes
local controls: any = nil
local function playerControls(): any
	if controls == nil then
		local ok, module = pcall(function()
			local scripts = player:WaitForChild("PlayerScripts")
			return (require :: any)(scripts:WaitForChild("PlayerModule")):GetControls()
		end)
		controls = if ok then module else false
	end
	return controls or nil
end

local function hideArmorer(hide: boolean)
	for _, part in hidden do
		part.LocalTransparencyModifier = 0
	end
	table.clear(hidden)
	if not (hide and desk) then
		return
	end
	local desks = Workspace:FindFirstChild("Desks")
	local figure = desks and desks:FindFirstChild(desk.title)
	if figure then
		for _, part in figure:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
				table.insert(hidden, part)
			end
		end
	end
end

local function showOverlay()
	local inRack = mode == "rack" or mode == "inspect"
	talk.Visible = mode == "talk"
	rackHeader.Visible = inRack
	hint.Visible = mode == "rack"
	bar.Visible = inRack
	prevButton.Visible = mode == "inspect"
	nextButton.Visible = mode == "inspect"
	card.Visible = mode == "inspect"
end

local leaveRack: () -> ()
local inspect: (number) -> ()

local function backAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if mode == "inspect" then
			mode = "rack"
			local model = gun(order[selected])
			if model then
				slide(model, 0)
			end
			setGlow(nil)
			selected = 0
			overview()
			showOverlay()
		elseif mode == "rack" then
			leaveRack()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function stepAction(step: number): (string, Enum.UserInputState) -> Enum.ContextActionResult
	return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and mode == "inspect" then
			inspect((selected - 1 + step) % #order + 1)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
end

function inspect(index: number)
	local id = order[index]
	local model = id and gun(id)
	if not model then
		return
	end
	if mode == "inspect" and selected ~= index then
		local previous = gun(order[selected])
		if previous then
			slide(previous, 0)
		end
	end
	hovered = nil
	mode = "inspect"
	selected = index
	slide(model, TUNING.SlideOut)
	setGlow(model)
	frameGun(model)
	fillCard(id)
	showOverlay()
end

local function enterRack()
	local rack = desk and desk.rack
	if not rack or not board() then
		return
	end
	mode = "rack"
	rackTitle.Text = rack.header
	rackSay.Text = `"{rack.rackLine}"`
	hint.Text = if HudTheme.isTouch()
		then "Tap a weapon to look closer"
		else "Click a weapon to look closer   ·   Backspace to step back"
	local c = playerControls()
	if c then
		c:Disable()
	end
	if prompt then
		prompt.Enabled = false
	end
	hideArmorer(true)
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
end

function leaveRack()
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
		camera.FieldOfView = TUNING.PlayFov
	end
	hideArmorer(false)
	local c = playerControls()
	if c then
		c:Enable()
	end
	if prompt then
		prompt.Enabled = true
	end
	mode = "closed"
	showOverlay()
end

local function openTalk(chosen: LobbyDesks.Desk, from: ProximityPrompt)
	local rack = chosen.rack
	if not rack then
		return
	end
	desk = chosen
	prompt = from
	mode = "talk"
	talkTitle.Text = `{chosen.title}  {HudTheme.tint(chosen.who, HudTheme.Color.TextDim)}`
	talkLine.Text = `"{chosen.line}"`
	choiceWork.Text = `1.  {rack.askWork}`
	choiceRack.Text = `2.  {rack.showRack}`
	choiceLeave.Text = `3.  {rack.leave}`
	talkCloseAt = os.clock() + Config.Lobby.DialogSeconds * 3
	showOverlay()
end

local function closeTalk()
	if mode == "talk" then
		mode = "closed"
		showOverlay()
	end
end

-- --------------------------------------------------------------- wiring
function ArmsRackUI.init()
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, entry in LobbyDesks do
		byId[entry.id] = entry
	end

	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt, who: Player)
		if who ~= player or mode ~= "closed" then
			return
		end
		local id = triggered:GetAttribute(Attributes.DeskId)
		local chosen = if type(id) == "string" then byId[id] else nil
		if chosen and chosen.rack then
			openTalk(chosen, triggered)
		end
	end)

	choiceWork.Activated:Connect(function()
		local rack = desk and desk.rack
		if rack then
			talkLine.Text = `"{rack.workAnswer}"`
			talkCloseAt = os.clock() + Config.Lobby.DialogSeconds * 3
		end
	end)
	choiceRack.Activated:Connect(function()
		if mode == "talk" then
			enterRack()
		end
	end)
	choiceLeave.Activated:Connect(closeTalk)
	backButton.Activated:Connect(function()
		backAction(ACTION_BACK, Enum.UserInputState.Begin)
	end)
	prevButton.Activated:Connect(function()
		stepAction(-1)(ACTION_PREV, Enum.UserInputState.Begin)
	end)
	nextButton.Activated:Connect(function()
		stepAction(1)(ACTION_NEXT, Enum.UserInputState.Begin)
	end)

	-- Hover with the mouse; click or tap to look closer.
	UserInputService.InputChanged:Connect(function(input)
		if mode == "rack" and input.UserInputType == Enum.UserInputType.MouseMovement then
			hover(pick(Vector2.new(input.Position.X, input.Position.Y)))
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or mode ~= "rack" then
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

	-- The talk panel closes when you walk off or wait; a respawn leaves the rack.
	RunService.Heartbeat:Connect(function()
		if mode ~= "talk" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local anchor = prompt and prompt.Parent
		local tooFar = root ~= nil
			and anchor ~= nil
			and anchor:IsA("BasePart")
			and (root.Position - anchor.Position).Magnitude
				> Config.Lobby.DeskPromptDistance * 1.5
		if tooFar or os.clock() >= talkCloseAt then
			closeTalk()
		end
	end)
	player.CharacterRemoving:Connect(function()
		if mode == "rack" or mode == "inspect" then
			leaveRack()
		end
		closeTalk()
	end)
end

return ArmsRackUI
