--!strict
-- The crate's cards as a panel (owner 2026-11-11: big, readable, picked on purpose; never
-- by walking over a card). ResupplyUI opens it when the player holds the crate's prompt:
-- up to three large cards side by side at screen centre, each with its key, its kind, an
-- icon, the name and one plain line of what it does. Pick with a click or tap, keys 1-3,
-- or the gamepad (stick or D-pad to a card, A). The game does not pause: the layer behind
-- is only lightly dimmed, the soldier can still walk (ResupplyUI closes the panel when
-- they walk away) and still be hit. Close without a pick: the prompt key again, Backspace,
-- gamepad B, a click beside the cards, or walking off.
-- Sizes at 1080p (docs/STYLES.md > UI): header 30, card name 28 (24 or 20 when one long
-- word needs it), description 20, kind tag and key 16, footer 16. The panel scales with
-- the HUD and is held at 0.7 or more on a short screen (name 19 px, description 14 px on
-- an 844 x 390 phone).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local HudTheme = require(script.Parent.HudTheme)

local C = HudTheme.Color

local CARD_SIZE = Vector2.new(300, 400)
local CARD_GAP = 16
local HEADER_HEIGHT = 74
local FOOTER_HEIGHT = 36
local ACTION = "RewardPanelKeys"
local SUPPLY_COLOR = C.Yellow
local UPGRADE_COLOR = C.Squad
local ANSWER_SECONDS = 2 -- no word from the server by then: the cards wake up again
local PICK_KEYS = Config.Requisition.Pick.CardKeys

export type Options = {
	title: string, -- the crate's label: "RESUPPLY"
	note: string, -- the line under it
	cards: { string }, -- card ids, left to right
	replaces: { string }, -- per card: the upgrade id it would replace, or ""
	expiresAt: number, -- os.clock when the crate closes
	taken: { string }, -- callsigns that have taken theirs
	onPick: (cardId: string) -> (),
	onClose: () -> (), -- closed without a pick
}

type CardView = {
	cardId: string,
	button: TextButton,
	stroke: UIStroke,
	scale: UIScale,
}

type Open = {
	options: Options,
	root: Frame,
	dim: TextButton,
	cards: { CardView },
	status: TextLabel,
	clock: TextLabel,
	takenRow: Frame,
	pending: string?, -- the card asked for, until the server answers
	done: boolean, -- a pick was confirmed: the panel is on its way out
	token: number,
}

local RewardPanel = {}

local gui: ScreenGui? = nil
local open: Open? = nil
local tokens = 0

-- The kind tag on a card and its colour.
local function kindOf(definition: UpgradeDefinitions.CardDefinition): (string, Color3)
	if definition.Kind == "supply" then
		return definition.Tag or "SUPPLY", SUPPLY_COLOR
	end
	local slot: string = definition.Slot or "FIELD"
	if definition.Slot == "CallIn" then
		slot = definition.CallIn or "CALL-IN"
	end
	return string.upper(`{slot} UPGRADE`), UPGRADE_COLOR
end

-- On top of the HUD scale: bigger on a short screen (a phone), as far as the panel fits.
local function panelScale(columns: number): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local hud = math.clamp(viewport.Y / 1080, 0.62, 1)
	local width = columns * CARD_SIZE.X + (columns - 1) * CARD_GAP + 40
	local height = HEADER_HEIGHT + CARD_SIZE.Y + FOOTER_HEIGHT + 40
	local fit = math.min(viewport.X / width, viewport.Y / height)
	local wanted = math.clamp(math.max(hud, 0.7), 0.5, math.max(fit, 0.5))
	return wanted / hud * Config.Requisition.Pick.PanelScale
end

-- The largest of `sizes` at which every word of `text` fits `width` (a word never wraps).
local function fitSize(text: string, font: Enum.Font, width: number, sizes: { number }): number
	for _, size in sizes do
		local fits = true
		for word in string.gmatch(text, "%S+") do
			if TextService:GetTextSize(word, size, font, Vector2.new(4000, 100)).X > width then
				fits = false
				break
			end
		end
		if fits then
			return size
		end
	end
	return sizes[#sizes]
end

local function fixed(label: TextLabel, position: UDim2, size: UDim2)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = position
	label.Size = size
	label.TextWrapped = true
end

local function highlight(current: Open, index: number?)
	for cardIndex, card in current.cards do
		local on = cardIndex == index
		card.stroke.Color = if on then C.MenuSelect else C.Red
		card.stroke.Thickness = if on then 3 else 1
		card.button.BackgroundTransparency = if on then 0 else 0.08
	end
end

local function setTaken(current: Open, names: { string })
	current.takenRow:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = current.takenRow
	if #names == 0 then
		return
	end
	HudTheme.label(current.takenRow, { text = "TAKEN", size = 16, color = C.TextDim })
	for _, name in names do
		-- The tick: a yellow square, then the callsign.
		HudTheme.rect(current.takenRow, UDim2.fromOffset(10, 10), C.Yellow)
		HudTheme.label(current.takenRow, { text = string.upper(name), size = 16 })
	end
end

local function unbind(current: Open)
	ContextActionService:UnbindAction(ACTION)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(current.root) then
		GuiService.SelectedObject = nil
	end
end

local function destroy(current: Open)
	if open == current then
		unbind(current)
		open = nil
	end
	current.root:Destroy()
	current.dim:Destroy()
end

-- Closes the panel. `silent` skips onClose (the caller already knows).
function RewardPanel.close(silent: boolean?)
	local current = open
	if not current then
		return
	end
	destroy(current)
	if not silent and not current.done then
		current.options.onClose()
	end
end

function RewardPanel.isOpen(): boolean
	return open ~= nil
end

local function ask(current: Open, index: number)
	local card = current.cards[index]
	if not card or current.pending or current.done then
		return
	end
	current.pending = card.cardId
	current.status.Text = ""
	highlight(current, index)
	current.options.onPick(card.cardId)
	local token = current.token
	task.delay(ANSWER_SECONDS, function()
		if open == current and current.token == token and current.pending and not current.done then
			current.pending = nil
			current.status.Text = "NO ANSWER. PICK AGAIN."
		end
	end)
end

-- The server refused the pick: say why and let the player pick again.
function RewardPanel.refuse(text: string)
	local current = open
	if current and not current.done then
		current.pending = nil
		current.status.Text = text
	end
end

-- The server took the pick: the card flashes, the others fade, the panel goes.
function RewardPanel.confirm(cardId: string)
	local current = open
	if not current or current.done then
		return
	end
	current.done = true
	unbind(current)
	local quick = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, card in current.cards do
		card.button.Active = false
		if card.cardId == cardId then
			card.stroke.Color = C.MenuSelect
			card.stroke.Thickness = 3
			card.button.BackgroundColor3 = C.MenuSelect
			card.button.BackgroundTransparency = 0
			TweenService:Create(card.scale, quick, { Scale = 1.06 }):Play()
			TweenService:Create(card.button, TweenInfo.new(0.3), { BackgroundColor3 = C.MenuBack })
				:Play()
		else
			TweenService:Create(card.scale, quick, { Scale = 0.94 }):Play()
			TweenService:Create(card.button, quick, { BackgroundTransparency = 0.7 }):Play()
		end
	end
	current.status.Text = ""
	task.delay(Config.Requisition.Pick.ConfirmSeconds, function()
		if current.root.Parent then
			destroy(current)
		end
	end)
end

-- Who has taken a card from this crate (ResupplyUI, on the server's word).
function RewardPanel.setTaken(names: { string })
	local current = open
	if current then
		setTaken(current, names)
	end
end

local function buildCard(
	current: Open,
	parent: Frame,
	index: number,
	definition: UpgradeDefinitions.CardDefinition,
	replaces: string
): CardView
	local kindText, kindColor = kindOf(definition)
	local button = Instance.new("TextButton")
	button.Name = definition.Id
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	button.Position = UDim2.fromOffset((index - 1) * (CARD_SIZE.X + CARD_GAP), HEADER_HEIGHT)
	button.BackgroundColor3 = C.MenuBack
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button

	-- Top row: the key on the left, the kind on the right; a bar in the kind's colour.
	local bar = HudTheme.rect(button, UDim2.new(1, 0, 0, 4), kindColor)
	bar.Position = UDim2.fromOffset(0, 0)
	if not HudTheme.isTouch() then
		local key = HudTheme.label(button, { text = `[{index}]`, size = 16, color = C.Yellow })
		key.Position = UDim2.fromOffset(12, 12)
	end
	local tag = HudTheme.label(button, {
		text = kindText,
		size = 16,
		color = kindColor,
		align = Enum.TextXAlignment.Right,
	})
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, -12, 0, 12)

	local icon: GuiObject
	if definition.IconId then
		local image = Instance.new("ImageLabel")
		image.Image = definition.IconId
		image.BackgroundTransparency = 1
		icon = image
	else
		local plate = Instance.new("TextLabel")
		plate.Text = definition.Abbrev
		plate.TextColor3 = C.Text
		plate.TextSize = 36
		plate.Font = HudTheme.Font.Headline
		plate.BackgroundColor3 = definition.Color
		icon = plate
	end
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 42)
	icon.Size = UDim2.fromOffset(88, 88)
	icon.BorderSizePixel = 0
	icon.Parent = button

	local nameText = string.upper(definition.Name)
	local name = HudTheme.label(button, {
		text = nameText,
		font = HudTheme.Font.Headline,
		-- 28, or the next size down a long single word needs to stay on the card.
		size = fitSize(nameText, HudTheme.Font.Headline, CARD_SIZE.X - 24, { 28, 24, 20 }),
		align = Enum.TextXAlignment.Center,
	})
	fixed(name, UDim2.fromOffset(12, 138), UDim2.new(1, -24, 0, 62))
	name.TextYAlignment = Enum.TextYAlignment.Center

	local description = HudTheme.label(button, {
		text = definition.Description,
		font = HudTheme.Font.Body,
		size = 20,
		align = Enum.TextXAlignment.Center,
	})
	fixed(description, UDim2.fromOffset(16, 206), UDim2.new(1, -32, 0, 148))
	description.TextYAlignment = Enum.TextYAlignment.Top

	local replaced = UpgradeDefinitions.get(replaces)
	if replaced then
		local warning = HudTheme.label(button, {
			text = `REPLACES {string.upper(replaced.Name)}`,
			size = 16,
			color = C.RedLight,
			align = Enum.TextXAlignment.Center,
		})
		fixed(warning, UDim2.new(0, 12, 1, -34), UDim2.new(1, -24, 0, 22))
	end

	button.MouseEnter:Connect(function()
		if not current.pending and not current.done then
			highlight(current, index)
		end
	end)
	button.MouseLeave:Connect(function()
		if not current.pending and not current.done then
			highlight(current, nil)
		end
	end)
	button.SelectionGained:Connect(function()
		if not current.pending and not current.done then
			highlight(current, index)
		end
	end)
	button.Activated:Connect(function()
		ask(current, index)
	end)
	return { cardId = definition.Id, button = button, stroke = stroke, scale = scale }
end

local function onKey(_action: string, state: Enum.UserInputState, input: InputObject)
	local current = open
	if not current or state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local index = table.find(PICK_KEYS, input.KeyCode)
	if index then
		ask(current, index)
	else
		RewardPanel.close()
	end
	return Enum.ContextActionResult.Sink
end

-- Opens the panel on a crate's cards (one panel at a time).
function RewardPanel.open(options: Options)
	RewardPanel.close(true)
	local screen: ScreenGui = gui or HudTheme.gui("RewardPanel", 60)
	if not gui then
		gui = screen
		HudTheme.parent(screen)
	end
	local pick = Config.Requisition.Pick
	local columns = math.max(#options.cards, 1)
	local width = columns * CARD_SIZE.X + (columns - 1) * CARD_GAP

	-- A light dim; a click on it (beside the cards) closes the panel.
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Selectable = false
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.fromScale(4, 4)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = screen

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(width, HEADER_HEIGHT + CARD_SIZE.Y + FOOTER_HEIGHT)
	root.Position = UDim2.new(0.5, 0, 0.5, 8)
	root.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Scale = panelScale(columns)
	scale.Parent = root

	local title = HudTheme.label(root, {
		text = `//{options.title}`,
		font = HudTheme.Font.Headline,
		size = 30,
		color = C.Yellow,
	})
	title.Position = UDim2.fromOffset(0, 0)
	local note = HudTheme.label(root, { text = options.note, font = HudTheme.Font.Body, size = 18 })
	fixed(note, UDim2.fromOffset(0, 38), UDim2.new(1, -150, 0, 30))
	note.TextWrapped = false
	note.TextTruncate = Enum.TextTruncate.AtEnd
	local clock = HudTheme.label(root, {
		size = 16,
		color = C.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	clock.AnchorPoint = Vector2.new(1, 0)
	clock.Position = UDim2.new(1, 0, 0, 42)

	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT + 8)
	footer.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT - 8)
	footer.Parent = root
	local takenRow = Instance.new("Frame")
	takenRow.BackgroundTransparency = 1
	takenRow.Size = UDim2.fromScale(0.6, 1)
	takenRow.Parent = footer
	local status = HudTheme.label(footer, {
		size = 16,
		color = C.RedLight,
		align = Enum.TextXAlignment.Center,
	})
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.5)
	local closeButton = Instance.new("TextButton")
	closeButton.AutoButtonColor = false
	closeButton.Selectable = false
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.fromScale(1, 0.5)
	closeButton.Size = UDim2.fromOffset(200, 28)
	closeButton.BackgroundTransparency = 1
	closeButton.Font = HudTheme.Font.Line
	closeButton.TextSize = 16
	closeButton.TextColor3 = C.TextDim
	closeButton.TextStrokeTransparency = 0.55
	closeButton.TextXAlignment = Enum.TextXAlignment.Right
	closeButton.Text = if HudTheme.isTouch()
		then "CLOSE (or walk away)"
		else `[{pick.Key.Name}] CLOSE (or walk away)`
	closeButton.Parent = footer

	tokens += 1
	local current: Open = {
		options = options,
		root = root,
		dim = dim,
		cards = {},
		status = status,
		clock = clock,
		takenRow = takenRow,
		pending = nil,
		done = false,
		token = tokens,
	}
	for index, cardId in options.cards do
		local definition = UpgradeDefinitions.get(cardId)
		if definition then
			table.insert(
				current.cards,
				buildCard(current, root, index, definition, options.replaces[index] or "")
			)
		end
	end
	setTaken(current, options.taken)
	open = current

	dim.Activated:Connect(function()
		RewardPanel.close()
	end)
	closeButton.Activated:Connect(function()
		RewardPanel.close()
	end)

	-- Keys 1-3 pick, the prompt key / Backspace / B close. Bound above the game's own keys,
	-- so 1-3 do not throw a call-in while the panel is up.
	ContextActionService:BindActionAtPriority(
		ACTION,
		onKey,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		pick.Key,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.ButtonB,
		table.unpack(PICK_KEYS)
	)
	local first = current.cards[1]
	if first and UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
		GuiService.SelectedObject = first.button
	end

	-- Appear: 0.18 s, the dim fades in and the panel rises 8 px.
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(dim, info, { BackgroundTransparency = pick.Dim }):Play()
	TweenService:Create(root, info, { Position = UDim2.fromScale(0.5, 0.5) }):Play()

	-- The countdown to the crate closing, four times a second (never per frame).
	task.spawn(function()
		while open == current and not current.done do
			local left = math.max(math.ceil(options.expiresAt - os.clock()), 0)
			current.clock.Text =
				`closes in {math.floor(left / 60)}:{string.format("%02d", left % 60)}`
			task.wait(0.25)
		end
	end)
end

return RewardPanel
