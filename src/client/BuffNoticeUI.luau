--!strict
-- Notices (HUD language: HudTheme; after Prototype 2's notification card and subtitles).
-- The BuffNotice remote carries (text, kind):
-- - a radio line (Messages.Notice.Radio) is a subtitle at lower centre under the mission
--   line: "CONTROL: line", the speaker in bold caps; the Warden's tells use the same line
--   ("HANDSET: ...", BossBarUI);
-- - anything else (a pickup, a squadmate's pick) is a card at top right: a dark strip with a
--   red-outlined square and a bold title; up to three stack downward, each slides in,
--   holds and fades. While the boss bar shows, the cards start lower (BossBarUI).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)

local BuffNoticeUI = {}

local C = HudTheme.Color
local CARD_SIZE = Vector2.new(340, 56)
local CARD_GAP = 6
local CARD_HOLD = 2.5
local MAX_CARDS = 3
local SUBTITLE_HOLD = 3.5

local cardColumn: Frame = nil :: any
local cards: { Frame } = {}
local subtitle: TextLabel = nil :: any
local subtitleToken = 0
local cardTop = 12

local function restack()
	for index, card in cards do
		local target = UDim2.new(1, 0, 0, (index - 1) * (CARD_SIZE.Y + CARD_GAP))
		TweenService:Create(card, TweenInfo.new(0.18), { Position = target }):Play()
	end
end

local function removeCard(card: Frame)
	local index = table.find(cards, card)
	if index then
		table.remove(cards, index)
	end
	card:Destroy()
	restack()
end

local function abbreviation(text: string): string
	local letters = ""
	for word in string.gmatch(text, "%a+") do
		letters ..= string.upper(string.sub(word, 1, 1))
		if #letters >= 2 then
			break
		end
	end
	return if letters ~= "" then letters else "+"
end

function BuffNoticeUI.card(title: string, sub: string?)
	while #cards >= MAX_CARDS do
		removeCard(cards[1])
	end
	local card =
		HudTheme.rect(cardColumn, UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y), C.Track, 0.25)
	card.AnchorPoint = Vector2.new(1, 0)
	local square = HudTheme.rect(card, UDim2.fromOffset(40, 40), C.Track, 0.2)
	square.Position = UDim2.fromOffset(8, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.RedLight
	stroke.Thickness = 1
	stroke.Parent = square
	local glyph = HudTheme.label(
		square,
		{ text = abbreviation(title), font = HudTheme.Font.Headline, size = 14 }
	)
	glyph.AutomaticSize = Enum.AutomaticSize.None
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	local titleLabel = HudTheme.label(
		card,
		{ text = string.upper(title), font = HudTheme.Font.Headline, size = 16 }
	)
	titleLabel.Position = UDim2.fromOffset(58, if sub then 9 else 18)
	if sub then
		local subLabel = HudTheme.label(
			card,
			{ text = sub, font = HudTheme.Font.Body, size = 13, color = C.TextDim }
		)
		subLabel.Position = UDim2.fromOffset(58, 31)
	end
	table.insert(cards, card)
	-- Slide in from 40 px right, hold, fade.
	local slot = UDim2.new(1, 0, 0, (#cards - 1) * (CARD_SIZE.Y + CARD_GAP))
	card.Position = slot + UDim2.fromOffset(40, 0)
	card.BackgroundTransparency = 1
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, info, { Position = slot, BackgroundTransparency = 0.25 }):Play()
	task.delay(CARD_HOLD, function()
		if card.Parent then
			for _, descendant in card:GetDescendants() do
				if descendant:IsA("TextLabel") then
					TweenService:Create(
						descendant,
						TweenInfo.new(0.3),
						{ TextTransparency = 1, TextStrokeTransparency = 1 }
					):Play()
				end
			end
			TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.delay(0.3, function()
				if card.Parent then
					removeCard(card)
				end
			end)
		end
	end)
end

-- A subtitle line: "SPEAKER: text" at lower centre, held then faded.
function BuffNoticeUI.subtitle(speaker: string?, text: string, color: Color3?, hold: number?)
	subtitleToken += 1
	local token = subtitleToken
	local prefix = if speaker then `<b>{string.upper(speaker)}:</b> ` else ""
	subtitle.Text = prefix .. text
	subtitle.TextColor3 = color or C.Text
	subtitle.TextTransparency = 0
	subtitle.TextStrokeTransparency = 0.55
	subtitle.Visible = true
	task.delay(hold or SUBTITLE_HOLD, function()
		if token == subtitleToken then
			TweenService:Create(
				subtitle,
				TweenInfo.new(0.3),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
		end
	end)
end

-- Moves the card column (BossBarUI pushes it under the boss bar while the bar shows).
function BuffNoticeUI.setCardTop(y: number)
	cardTop = y
	if cardColumn then
		cardColumn.Position = UDim2.new(1, -HudTheme.Margin, 0, cardTop)
	end
end

local function onNotice(text: string, kind: string?)
	if kind == Messages.Notice.Radio then
		BuffNoticeUI.subtitle("Control", text)
	else
		BuffNoticeUI.card(text)
	end
end

function BuffNoticeUI.init()
	local gui = HudTheme.gui("BuffNoticeUI", 20)
	cardColumn = Instance.new("Frame")
	cardColumn.BackgroundTransparency = 1
	cardColumn.AnchorPoint = Vector2.new(1, 0)
	cardColumn.Position = UDim2.new(1, -HudTheme.Margin, 0, cardTop)
	cardColumn.Size = UDim2.fromOffset(CARD_SIZE.X, (CARD_SIZE.Y + CARD_GAP) * MAX_CARDS)
	cardColumn.Parent = gui

	subtitle = HudTheme.label(gui, { font = HudTheme.Font.Body, size = 16, rich = true })
	subtitle.AutomaticSize = Enum.AutomaticSize.Y
	subtitle.AnchorPoint = Vector2.new(0.5, if HudTheme.isTouch() then 0 else 1)
	subtitle.Position = if HudTheme.isTouch()
		then UDim2.new(0.5, 0, 0, 112)
		else UDim2.new(0.5, 0, 0.8, 52)
	subtitle.Size = UDim2.fromOffset(820, 0)
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Visible = false

	HudTheme.parent(gui)
	Remotes.get("BuffNotice").OnClientEvent:Connect(onNotice)
end

return BuffNoticeUI
