--!strict
-- The map room's Mission Board (loop sprint 1; layout: the ui-ux-designer's brief in the
-- sprint's PR). The watch officer's "Show me the missions." opens the paper-map view
-- (DeskDialogUI.viewMap) and this board in the talk panel's place: one card per
-- MissionCatalog.Order row (district, name, line), one selected, DEPLOY, a status line.
-- DEPLOY asks the server to fly this soldier, alone with bots, into the picked mission
-- (MissionBoardService over the MissionBoard remote). 1..n pick, Enter deploys, Backspace
-- steps away (the dialog closes with it). Room is left on each card for the district's
-- percent, a lock, an Order border and the party (loop sprints 2-4).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudTheme = require(script.Parent.HudTheme)
local Messages = require(ReplicatedStorage.Shared.Messages)
local MissionCatalog = require(ReplicatedStorage.Shared.MissionCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MissionBoardUI = {}

local C = HudTheme.Color
local WIDTH = 560
local CARD_W, CARD_H = 528, 132
local ACTION = "MissionBoardKeys"
local PICK_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
}
local DEPLOY_KEYS = { Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonY }
local BACK_KEYS = { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB }
local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Card = { id: string, button: TextButton, labels: { TextLabel }, stroke: UIStroke }

local gui: ScreenGui
local frame: Frame
local voice: TextLabel
local status: TextLabel
local deploy: TextButton
local cards: { Card } = {}
local selected: string? = nil
local lifting = false
local open = false
local onClosed: (() -> ())? = nil
local remote: RemoteEvent

local function paint()
	for _, card in cards do
		local on = card.id == selected
		card.button.BackgroundColor3 = if on then C.MenuSelect else C.Track
		card.button.BackgroundTransparency = if on then 0 else 0.35
		for _, label in card.labels do
			label.TextColor3 = if on
				then C.MenuSelectText
				else label:GetAttribute("Dim") and C.TextDim or C.Text
		end
	end
	local ready = selected ~= nil and not lifting
	deploy.Active = ready
	deploy.AutoButtonColor = ready
	deploy.BackgroundTransparency = if ready then 0 else 0.5
	deploy.TextColor3 = if ready then C.MenuSelectText else C.TextDim
end

local function say(text: string, color: Color3)
	status.Text = text
	status.TextColor3 = color
	status.Visible = text ~= ""
end

local function pick(id: string)
	if lifting then
		return
	end
	selected = id
	say("", C.Text)
	paint()
end

local function send()
	if not selected or lifting then
		return
	end
	remote:FireServer(Messages.MissionBoard.Deploy, selected)
end

local function label(
	parent: Instance,
	text: string,
	font: Enum.Font,
	size: number,
	at: UDim2,
	dim: boolean?
): TextLabel
	local l = HudTheme.label(
		parent,
		{ text = text, font = font, size = size, color = if dim then C.TextDim else C.Text }
	)
	l.Position = at
	l:SetAttribute("Dim", dim == true)
	return l
end

local function buildCard(parent: Instance, row: MissionCatalog.Row, order: number): Card
	local button = Instance.new("TextButton")
	button.Name = row.Id
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(CARD_W, CARD_H)
	button.BackgroundColor3 = C.Track
	button.BackgroundTransparency = 0.35
	button.BorderSizePixel = 0
	button.LayoutOrder = order
	button.Selectable = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.White
	stroke.Transparency = HudTheme.OutlineTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local labels = {
		label(button, row.District, HudTheme.Font.Line, 14, UDim2.fromOffset(12, 10), true),
		label(button, row.Name, HudTheme.Font.Headline, 26, UDim2.fromOffset(12, 30)),
	}
	local blurb = label(button, row.Blurb, HudTheme.Font.Body, 16, UDim2.fromOffset(12, 64))
	blurb.AutomaticSize = Enum.AutomaticSize.None
	blurb.Size = UDim2.fromOffset(CARD_W - 24, 40)
	blurb.TextWrapped = true
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	table.insert(labels, blurb)
	local function hover(on: boolean)
		stroke.Thickness = if on then 2 else 1
		stroke.Color = if on then C.Text else C.White
		stroke.Transparency = if on then 0 else HudTheme.OutlineTransparency
	end
	button.MouseEnter:Connect(function()
		hover(true)
	end)
	button.MouseLeave:Connect(function()
		hover(false)
	end)
	button.SelectionGained:Connect(function()
		hover(true)
		pick(row.Id)
	end)
	button.SelectionLost:Connect(function()
		hover(false)
	end)
	button.Activated:Connect(function()
		pick(row.Id)
	end)
	button.Parent = parent
	return { id = row.Id, button = button, labels = labels, stroke = stroke }
end

local function keys(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local index = table.find(PICK_KEYS, input.KeyCode)
	if index then
		local card = cards[index]
		if card then
			pick(card.id)
		end
	elseif table.find(DEPLOY_KEYS, input.KeyCode) then
		send()
	elseif table.find(BACK_KEYS, input.KeyCode) then
		MissionBoardUI.close()
	end
	return Enum.ContextActionResult.Sink
end

function MissionBoardUI.isOpen(): boolean
	return open
end

-- Opens the board with the watch officer's line; `closed` runs when it closes (the dialog
-- closes with it).
function MissionBoardUI.open(line: string, who: string, closed: () -> ())
	open = true
	onClosed = closed
	lifting = false
	voice.Text = `"{line}"`
	local header = frame:FindFirstChild("Header") :: TextLabel
	header.Text = `//MISSION BOARD  {HudTheme.tint(string.upper(who), C.TextDim)}`
	-- The first open card starts picked, so DEPLOY is never dead on arrival.
	selected = nil
	for _, card in cards do
		local row = MissionCatalog.get(card.id)
		if row and MissionCatalog.isOpen(row, os.time()) then
			selected = card.id
			break
		end
	end
	say("", C.Text)
	paint()
	local keyList = table.clone(PICK_KEYS)
	for _, key in DEPLOY_KEYS do
		table.insert(keyList, key)
	end
	for _, key in BACK_KEYS do
		table.insert(keyList, key)
	end
	ContextActionService:BindActionAtPriority(
		ACTION,
		keys,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(keyList)
	)
	frame.Position = UDim2.new(0, 32, 0.5, 8)
	frame.Visible = true
	TweenService:Create(frame, FADE, { Position = UDim2.new(0, 32, 0.5, 0) }):Play()
	if UserInputService.GamepadEnabled and cards[1] then
		game:GetService("GuiService").SelectedObject = cards[1].button
	end
end

function MissionBoardUI.close()
	if not open then
		return
	end
	open = false
	ContextActionService:UnbindAction(ACTION)
	frame.Visible = false
	local closed = onClosed
	onClosed = nil
	if closed then
		closed()
	end
end

function MissionBoardUI.init()
	remote = Remotes.get("MissionBoard")
	gui = HudTheme.gui("MissionBoardUI", 7) -- over the talk (6), under a desk screen (8)

	frame = HudTheme.rect(gui, UDim2.fromOffset(WIDTH, 0), C.MenuBack, 0.06)
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 32, 0.5, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = frame

	local header = HudTheme.label(frame, { size = 22, font = HudTheme.Font.Headline, rich = true })
	header.Name = "Header"
	header.LayoutOrder = 1
	voice = HudTheme.label(frame, { size = 18, font = HudTheme.Font.Body })
	voice.LayoutOrder = 2
	voice.AutomaticSize = Enum.AutomaticSize.Y
	voice.Size = UDim2.fromScale(1, 0)
	voice.TextWrapped = true

	local scroller = Instance.new("ScrollingFrame")
	scroller.LayoutOrder = 3
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local rows = #MissionCatalog.Order
	scroller.Size = UDim2.fromOffset(CARD_W, math.min(rows, 3) * (CARD_H + 10) - 10)
	scroller.Parent = frame
	local cardList = Instance.new("UIListLayout")
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Padding = UDim.new(0, 10)
	cardList.Parent = scroller
	for order, id in MissionCatalog.Order do
		local row = MissionCatalog.get(id)
		if row then
			table.insert(cards, buildCard(scroller, row, order))
		end
	end

	status = HudTheme.label(frame, { size = 16, font = HudTheme.Font.Body })
	status.LayoutOrder = 4
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.Size = UDim2.fromScale(1, 0)
	status.TextWrapped = true
	status.Visible = false

	deploy = Instance.new("TextButton")
	deploy.LayoutOrder = 5
	deploy.Size = UDim2.fromOffset(CARD_W, 56)
	deploy.BackgroundColor3 = C.MenuSelect
	deploy.BorderSizePixel = 0
	deploy.Font = HudTheme.Font.Headline
	deploy.TextSize = 22
	deploy.TextColor3 = C.MenuSelectText
	deploy.Text = "DEPLOY · ALONE WITH BOTS"
	deploy.Modal = true -- frees the mouse even zoomed into first person
	deploy.Parent = frame
	deploy.Activated:Connect(send)

	local hint = HudTheme.label(frame, {
		size = 13,
		font = HudTheme.Font.Line,
		color = C.TextDim,
		text = if UserInputService.GamepadEnabled
			then "[A] PICK  ·  [Y] DEPLOY  ·  [B] BACK"
			else `[1-{rows}] PICK  ·  [ENTER] DEPLOY  ·  [BACKSPACE] STEP AWAY`,
	})
	hint.LayoutOrder = 6

	remote.OnClientEvent:Connect(function(kind: string, text: string?)
		if kind == Messages.MissionBoard.Lifting then
			lifting = true
			say("Lifting...", C.Yellow)
		elseif kind == Messages.MissionBoard.Refused then
			lifting = false
			say(text or "Not now.", C.RedLight)
		end
		paint()
	end)

	HudTheme.parent(gui)
end

return MissionBoardUI
