--!strict
-- The Arms Room counter (owner, 2026-11-09, after a GTA gun counter): talk to the Quartermaster (F)
-- and choose. "Show me the guns." turns the camera to the long-gun wall behind him (ArmsRack;
-- Q or the button swaps to his glass counter): the gun under the cursor slides out with a
-- soft glow, a click frames it with its card (name, the real gun, the line, on the record or
-- not, stat bars from Rules/ArmsStats) in the screen the card leaves free, arrows step through
-- every piece, Back steps out. All local: the camera, the slide and the card are this player's alone, so four
-- soldiers can look at once. The rack is for buying (merits, after F9); equipping is the
-- Loadmaster's (LoadmasterUI).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
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
local HoldStill = require(script.Parent.HoldStill)
local HudTheme = require(script.Parent.HudTheme)
local RecordClient = require(script.Parent.RecordClient)

local ArmsRackUI = {}

local TUNING = Config.Lobby.Rack
local EASE = TweenInfo.new(TUNING.CameraSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local SLIDE = TweenInfo.new(TUNING.SlideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACTION_BACK = "ArmsRackBack"
local ACTION_NEXT = "ArmsRackNext"
local ACTION_PREV = "ArmsRackPrev"
local ACTION_CHOOSE = "ArmsRackChoose"
local ACTION_VIEW = "ArmsRackView"
-- The talk choices are numbered on screen, so the number keys pick them too.
local CHOICE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
}

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
local hidden: { Instance } = {}
local talkCloseAt = 0

-- --------------------------------------------------------------- the rack in the world
local function rackFolder(): Instance?
	local desks = Workspace:FindFirstChild("Desks")
	return desks and desks:FindFirstChild("ArmsRack")
end

-- The back of a display ("wall" or "counter"; ArmsRack): the overview frames it.
local function display(which: string): BasePart?
	local folder = rackFolder()
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute(Attributes.RackDisplay) == which then
			return child
		end
	end
	return nil
end

local function gun(id: string): Model?
	local folder = rackFolder()
	local model = folder and folder:FindFirstChild(id)
	return if model and model:IsA("Model") then model else nil
end

-- The way a piece or a display faces: toward whoever looks at it.
local function faceOf(thing: Instance): Vector3
	local face = thing:GetAttribute(Attributes.RackFace)
	return if typeof(face) == "Vector3" then face.Unit else Vector3.new(1, 0, 0)
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
	local tween = TweenService:Create(value, SLIDE, { Value = base + faceOf(model) * forward })
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
	-- Only the Hits boxes: each is a piece's whole place and never moves, so the pick does
	-- not flicker as a gun slides out under the cursor.
	local hits = folder:FindFirstChild("Hits")
	if not hits then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { hits }
	-- Mouse and touch positions are GUI coordinates (under the top bar): ScreenPointToRay, not
	-- ViewportPointToRay, or the pick lands a top bar's height above the cursor (Nova: the
	-- boxes sat below the guns).
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 60, params)
	local id = hit and hit.Instance.Name
	return if id and table.find(order, id) then gun(id) else nil
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

-- The display the overview shows ("wall" or "counter").
local showing = "wall"

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

-- Rack: the header, the Quartermaster's line, a hint, Back.
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
-- The soldier's merits and tabs (RecordClient), under the Quartermaster's line.
local rackMerits = HudTheme.label(
	rackHeader,
	{ size = 20, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow }
)
rackMerits.LayoutOrder = 4

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
bar.Size = UDim2.fromOffset(460, 40)
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
-- Between the long-gun wall and the glass counter (Q).
local viewButton = button(bar, "", 190)
viewButton.LayoutOrder = 4

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
-- BUY, for a gun not on the record (Rules/Record via RecordService).
local cardBuy = button(card, "", 372)
cardBuy.LayoutOrder = 4
cardBuy.Font = HudTheme.Font.Headline
cardBuy.Visible = false
local cardLine = HudTheme.label(card, { size = 15, font = HudTheme.Font.Body })
cardLine.LayoutOrder = 5
cardLine.AutomaticSize = Enum.AutomaticSize.Y
cardLine.Size = UDim2.fromScale(1, 0)
cardLine.TextWrapped = true
local cardRows = Instance.new("Frame")
cardRows.BackgroundTransparency = 1
cardRows.Size = UDim2.fromScale(1, 0)
cardRows.AutomaticSize = Enum.AutomaticSize.Y
cardRows.LayoutOrder = 6
cardRows.Parent = card
column(cardRows, 6)
local cardCount = HudTheme.label(card, { size = 14, color = HudTheme.Color.TextDim })
cardCount.LayoutOrder = 7

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

-- The camera that shows a thing of `size` (studs: across, up) at `target`, looking against
-- `face`, filling the screen rectangle `rect` (pixels: left, top, right, bottom) with `margin`
-- studs of air: back far enough for both sides to fit, then sideways and up so the thing sits
-- in the middle of the rectangle, not of the screen.
local function fitView(
	target: Vector3,
	face: Vector3,
	size: Vector2,
	fov: number,
	rect: Rect,
	minDistance: number
): CFrame
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1600, 900)
	local tanHalf = math.tan(math.rad(fov) / 2)
	-- Air round it: a share of its size, so a pistol fills the view as a rifle does.
	local margin = math.max(size.X, size.Y) * TUNING.Margin
	-- Studs across the screen's height at distance d: 2 d tanHalf.
	local distance = math.max(
		(size.X + margin * 2) * viewport.Y / (2 * tanHalf * math.max(rect.Width, 1)),
		(size.Y + margin * 2) * viewport.Y / (2 * tanHalf * math.max(rect.Height, 1)),
		minDistance
	)
	local studsPerPixel = 2 * distance * tanHalf / viewport.Y
	local centre = (rect.Min + rect.Max) / 2
	local right = (centre.X - viewport.X / 2) * studsPerPixel
	local down = (centre.Y - viewport.Y / 2) * studsPerPixel
	local look = CFrame.lookAt(target + face * distance, target)
	return look - look.RightVector * right + look.UpVector * down
end

-- The screen left free by the header (top left), the hint and buttons (bottom) and, when
-- `card`, the card (right), in viewport pixels.
local function freeRect(withCard: boolean): Rect
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1600, 900)
	local inset = GuiService:GetGuiInset().Y -- the HUD sits under the top bar
	local edge = HudTheme.Margin * 2
	local top = rackHeader.AbsolutePosition.Y + rackHeader.AbsoluteSize.Y + inset + edge
	local bottom = hint.AbsolutePosition.Y + inset - edge
	local right = viewport.X - edge
	if withCard then
		right = math.max(card.AbsolutePosition.X - edge, viewport.X * 0.45)
	end
	-- Never squeeze the view below half the screen's height.
	if bottom - top < viewport.Y * 0.5 then
		top, bottom = viewport.Y * 0.2, viewport.Y * 0.8
	end
	return Rect.new(edge, top, right, bottom)
end

local function overview()
	local part = display(showing)
	if not part then
		return
	end
	local span = part:GetAttribute(Attributes.RackSpan)
	local size = if typeof(span) == "Vector2" then span else Vector2.new(part.Size.Z, part.Size.Y)
	tweenCamera(
		fitView(part.Position, faceOf(part), size, TUNING.RackFov, freeRect(false), 0),
		TUNING.RackFov
	)
end

-- Frames a piece in the part of the screen the card leaves free (left of it), the whole gun
-- in view, at most InspectHeightShare of the screen's height.
local function frameGun(model: Model)
	local face = faceOf(model)
	local span = model:GetAttribute(Attributes.RackSpan)
	local size = if typeof(span) == "Vector2" then span else Vector2.new(3, 1)
	local target = (bases[model] or model:GetPivot()).Position + face * TUNING.SlideOut
	local rect = freeRect(true)
	local camera = Workspace.CurrentCamera
	local height = (if camera then camera.ViewportSize.Y else 900) * TUNING.InspectHeightShare
	local middle = (rect.Min.Y + rect.Max.Y) / 2
	rect = Rect.new(
		rect.Min.X,
		math.max(rect.Min.Y, middle - height / 2),
		rect.Max.X,
		math.min(rect.Max.Y, middle + height / 2)
	)
	tweenCamera(
		fitView(target, face, size, TUNING.InspectFov, rect, TUNING.MinInspectDistance),
		TUNING.InspectFov
	)
end

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

local function fillCard(id: string)
	local rack = desk and desk.rack
	if not rack then
		return
	end
	local name, designation, line, rows = rowsFor(id)
	cardName.Text = name
	cardDesignation.Text = designation
	-- On the record (bought or issued free) or for sale at its price; grenades come with the job.
	local price = RecordClient.priceOf(id)
	local owned = RecordClient.owns(id)
	cardStatus.Text = if owned
		then HudTheme.tint(rack.onIssue, HudTheme.Color.Yellow)
		else `{rack.notOnIssue}  {HudTheme.tint(
			`{price or 0} {rack.currency}`,
			HudTheme.Color.TextDim
		)}`
	local forSale = not owned and price ~= nil and RecordClient.loaded()
	cardBuy.Visible = forSale
	if forSale then
		local short = RecordClient.merits() < (price :: number)
		cardBuy.Text = if short
			then `{rack.buy} · {price} {rack.currency} (SHORT)`
			else `{rack.buy} · {price} {rack.currency}`
		cardBuy.TextTransparency = if short then 0.5 else 0
	end
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
local function setMovement(enabled: boolean)
	HoldStill.set(not enabled)
end

local function hideQuartermaster(hide: boolean)
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
	-- Him, his sign, and this soldier's own body (it stands between the camera and the wall).
	local desks = Workspace:FindFirstChild("Desks")
	local figures: { Instance } = {}
	local quartermaster = desks and desks:FindFirstChild(desk.title)
	if quartermaster then
		table.insert(figures, quartermaster)
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
	local inRack = mode == "rack" or mode == "inspect"
	talk.Visible = mode == "talk"
	-- Modal frees the mouse while the choices are up, even zoomed into first person.
	choiceLeave.Modal = mode == "talk"
	rackHeader.Visible = inRack
	hint.Visible = mode == "rack"
	bar.Visible = inRack
	prevButton.Visible = mode == "inspect"
	nextButton.Visible = mode == "inspect"
	viewButton.Visible = mode == "rack"
	viewButton.Text = if showing == "wall" then "The counter  >" else "<  Long guns"
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
			-- Back to the display that piece is on.
			local on = model and model:GetAttribute(Attributes.RackDisplay)
			showing = if type(on) == "string" then on else showing
			overview()
			showOverlay()
		elseif mode == "rack" then
			leaveRack()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function viewAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and mode == "rack" then
		hover(nil)
		showing = if showing == "wall" then "counter" else "wall"
		overview()
		showOverlay()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
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
	if not rack or not display("wall") then
		return
	end
	mode = "rack"
	showing = "wall"
	rackTitle.Text = rack.header
	rackSay.Text = `"{(desk :: LobbyDesks.Desk).talk.openLine}"`
	rackMerits.Text = `{RecordClient.merits()} {rack.currency}  ·  {RecordClient.tabs()} TABS`
	hint.Text = if HudTheme.isTouch()
		then "Tap a weapon to look closer"
		else "Click a weapon to look closer   ·   Q for the other display   ·   Backspace to step back"
	ContextActionService:UnbindAction(ACTION_CHOOSE)
	setMovement(false)
	if prompt then
		prompt.Enabled = false
	end
	hideQuartermaster(true)
	overview()
	ContextActionService:BindAction(
		ACTION_BACK,
		backAction,
		false,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindAction(
		ACTION_VIEW,
		viewAction,
		false,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonY
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
	ContextActionService:UnbindAction(ACTION_VIEW)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = TUNING.PlayFov
	end
	hideQuartermaster(false)
	setMovement(true)
	if prompt then
		prompt.Enabled = true
	end
	mode = "closed"
	showOverlay()
end

local closeTalk: () -> ()
local choose: (number) -> ()
local choiceKeyList: { Enum.KeyCode } = {}
for key in CHOICE_KEYS do
	table.insert(choiceKeyList, key)
end

local function chooseAction(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		choose(CHOICE_KEYS[input.KeyCode] or 0)
	end
	return Enum.ContextActionResult.Sink
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
	local said = chosen.talk
	talkLine.Text = `"{said.greetings[math.random(1, #said.greetings)]}"`
	-- 1 the guns, 2 the question, 3 leave (the same order at every desk).
	choiceWork.Text = `1.  {said.open}`
	choiceRack.Text = `2.  {said.ask}`
	choiceLeave.Text = `3.  {said.leave}`
	talkCloseAt = os.clock() + Config.Lobby.DialogSeconds * 3
	showOverlay()
	ContextActionService:BindAction(ACTION_CHOOSE, chooseAction, false, table.unpack(choiceKeyList))
end

function closeTalk()
	ContextActionService:UnbindAction(ACTION_CHOOSE)
	if mode == "talk" then
		mode = "closed"
		showOverlay()
	end
end

function choose(index: number)
	if mode ~= "talk" then
		return
	end
	if index == 1 then
		enterRack() -- unbinds the choice keys itself once the rack is really open
	elseif index == 2 and desk then
		talkLine.Text = `"{desk.talk.answer}"`
		talkCloseAt = os.clock() + Config.Lobby.DialogSeconds * 3
	elseif index == 3 then
		closeTalk()
	end
end

-- --------------------------------------------------------------- wiring
function ArmsRackUI.init()
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, entry in LobbyDesks do
		byId[entry.id] = entry
	end

	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt, who: Player)
		if who ~= player or mode == "rack" or mode == "inspect" then
			return
		end
		-- One dialog at a time: talking to another desk closes this one (DeskDialogUI
		-- hides its own panel when a rack desk opens).
		closeTalk()
		local id = triggered:GetAttribute(Attributes.DeskId)
		local chosen = if type(id) == "string" then byId[id] else nil
		if chosen and chosen.rack then
			openTalk(chosen, triggered)
		end
	end)

	-- Buying: the server answers with the new record (Changed) or a refusal (Refused).
	local meritsBefore = RecordClient.merits()
	cardBuy.Activated:Connect(function()
		local id = order[selected]
		if mode == "inspect" and id then
			meritsBefore = RecordClient.merits()
			RecordClient.buy(id)
		end
	end)
	RecordClient.Changed:Connect(function()
		local rack = desk and desk.rack
		if not rack or (mode ~= "rack" and mode ~= "inspect") then
			return
		end
		rackMerits.Text = `{RecordClient.merits()} {rack.currency}  ·  {RecordClient.tabs()} TABS`
		if RecordClient.merits() < meritsBefore and desk then
			rackSay.Text = `"{desk.talk.bought}"`
		end
		meritsBefore = RecordClient.merits()
		if mode == "inspect" and order[selected] then
			fillCard(order[selected])
		end
	end)
	RecordClient.Refused:Connect(function(_id: unknown, reason: unknown)
		if desk and desk.rack and (mode == "rack" or mode == "inspect") then
			rackSay.Text = if reason == "short"
				then `"{desk.talk.short}"`
				else `"{desk.talk.refused}"`
		end
	end)

	for index, choice in { choiceWork, choiceRack, choiceLeave } do
		choice.Activated:Connect(function()
			choose(index)
		end)
	end
	backButton.Activated:Connect(function()
		backAction(ACTION_BACK, Enum.UserInputState.Begin)
	end)
	prevButton.Activated:Connect(function()
		stepAction(-1)(ACTION_PREV, Enum.UserInputState.Begin)
	end)
	nextButton.Activated:Connect(function()
		stepAction(1)(ACTION_NEXT, Enum.UserInputState.Begin)
	end)
	viewButton.Activated:Connect(function()
		viewAction(ACTION_VIEW, Enum.UserInputState.Begin)
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
