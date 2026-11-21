--!strict
-- The squad's reinforcements on the HUD (ReinforceService, Config.Scarcity.Reinforce): one
-- line at the top of the left column, over the squad panel (HudTheme.inLeftColumn, so
-- nothing stacks): "REINFORCEMENTS" 12 dim, then one square per reinforcement, yellow while
-- it is left and an empty outline once spent (the charge squares' language, docs/STYLES.md
-- §5). With the pool empty it reads "NO REINFORCEMENTS" in red. A square just spent flashes
-- red and fades to the outline. Hidden when reinforcements are off (ReinforceTotal 0).
-- Event-driven.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local HudTheme = require(script.Parent.HudTheme)

local ReinforceUI = {}

local C = HudTheme.Color
local SQUARE = 9
local GAP = 4
local FLASH_SECONDS = 0.5

local root: Frame
local label: TextLabel
local squares: Frame
local lastLeft = -1

local function number(name: string): number
	local value = workspace:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local total = number(Attributes.ReinforceTotal)
	local left = math.clamp(number(Attributes.ReinforceLeft), 0, total)
	root.Visible = total > 0
	if total <= 0 then
		lastLeft = -1
		return
	end
	if left <= 0 then
		label.Text = "NO REINFORCEMENTS"
		label.TextColor3 = C.RedLight
	else
		label.Text = "REINFORCEMENTS"
		label.TextColor3 = C.TextDim
	end
	for _, child in squares:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index = 1, total do
		local filled = index <= left
		local square = HudTheme.rect(
			squares,
			UDim2.fromOffset(SQUARE, SQUARE),
			if filled then C.Yellow else C.Track,
			if filled then 0 else HudTheme.TrackTransparency,
			not filled
		)
		square.LayoutOrder = index
		-- Just spent: it flashes red and fades to the empty outline.
		if not filled and lastLeft >= 0 and index <= lastLeft then
			square.BackgroundColor3 = C.RedLight
			square.BackgroundTransparency = 0
			TweenService:Create(
				square,
				TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = C.Track, BackgroundTransparency = HudTheme.TrackTransparency }
			):Play()
		end
	end
	lastLeft = left
end

function ReinforceUI.init()
	root = Instance.new("Frame")
	root.Name = "Reinforcements"
	root.BackgroundTransparency = 1
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Size = UDim2.fromOffset(0, 0)
	root.Visible = false

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	label = HudTheme.label(root, { text = "REINFORCEMENTS", size = 12, color = C.TextDim })
	label.LayoutOrder = 1

	squares = Instance.new("Frame")
	squares.BackgroundTransparency = 1
	squares.AutomaticSize = Enum.AutomaticSize.XY
	squares.Size = UDim2.fromOffset(0, SQUARE)
	squares.LayoutOrder = 2
	squares.Parent = root
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, GAP)
	row.Parent = squares

	-- First in the left column: the squad panel (1) and the objective list (2) under it.
	HudTheme.inLeftColumn(root, 0)
	for _, name in { Attributes.ReinforceLeft, Attributes.ReinforceTotal } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return ReinforceUI
