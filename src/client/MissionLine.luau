--!strict
-- The mission line (HUD language: HudTheme; after Prototype 2's objective line): one white
-- line at lower centre, verbs and targets in caps with the key word coloured, a smaller
-- second line and a thin progress bar under it. No panel. ObjectiveUI and ExtractionUI both
-- write it; extraction outranks the objective, so while extraction shows, the objective
-- waits underneath. On touch devices it sits at top centre, clear of the thumbstick.

local TweenService = game:GetService("TweenService")

local HudTheme = require(script.Parent.HudTheme)

local MissionLine = {}

local C = HudTheme.Color
local PRIORITY: { [string]: number } = { objective = 1, extraction = 2 }

type Entry = { line1: string, line2: string, progress: number?, color: Color3? }

local entries: { [string]: Entry } = {}
local root: Frame = nil :: any
local line1: TextLabel = nil :: any
local line2: TextLabel = nil :: any
local bar: Frame = nil :: any
local barFill: Frame = nil :: any
local shownOwner: string? = nil
local built = false

local function top(): (string?, Entry?)
	local best, bestEntry, bestRank = nil, nil, -1
	for owner, entry in entries do
		local rank = PRIORITY[owner] or 0
		if rank > bestRank then
			best, bestEntry, bestRank = owner, entry, rank
		end
	end
	return best, bestEntry
end

local function render()
	local owner, entry = top()
	if not entry then
		if root.Visible then
			TweenService:Create(line1, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.delay(0.3, function()
				if not top() then
					root.Visible = false
				end
			end)
		end
		shownOwner = nil
		return
	end
	local fresh = owner ~= shownOwner or not root.Visible
	shownOwner = owner
	root.Visible = true
	line1.TextTransparency = 0
	line1.Text = entry.line1
	line1.TextColor3 = entry.color or C.Text
	line2.Text = entry.line2
	line2.Visible = entry.line2 ~= ""
	bar.Visible = entry.progress ~= nil
	if entry.progress then
		barFill.Size = UDim2.fromScale(math.clamp(entry.progress, 0, 1), 1)
	end
	if fresh then
		-- Appear: fade in with an 8 px rise.
		local home = root.Position
		root.Position = home + UDim2.fromOffset(0, 8)
		line1.TextTransparency = 1
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(root, info, { Position = home }):Play()
		TweenService:Create(line1, info, { TextTransparency = 0 }):Play()
	end
end

-- Shows (or updates) `owner`'s line. `progress` 0..1 shows the bar; nil hides it.
function MissionLine.set(
	owner: string,
	text: string,
	sub: string,
	progress: number?,
	color: Color3?
)
	entries[owner] = { line1 = text, line2 = sub, progress = progress, color = color }
	render()
end

function MissionLine.clear(owner: string)
	if entries[owner] then
		entries[owner] = nil
		render()
	end
end

-- Builds the line once (ObjectiveUI.init calls it; ExtractionUI after).
function MissionLine.init()
	if built then
		return
	end
	built = true
	local gui = HudTheme.gui("MissionLine", 10)
	root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Visible = false
	if HudTheme.isTouch() then
		root.AnchorPoint = Vector2.new(0.5, 0)
		root.Position = UDim2.new(0.5, 0, 0, 40)
	else
		root.AnchorPoint = Vector2.new(0.5, 1)
		root.Position = UDim2.fromScale(0.5, 0.8)
	end
	root.Size = UDim2.fromOffset(900, 56)
	root.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = root

	line1 = HudTheme.label(root, { size = 22, rich = true })
	line1.LayoutOrder = 1
	line2 = HudTheme.label(root, { font = HudTheme.Font.Body, size = 18, rich = true })
	line2.LayoutOrder = 2
	bar = HudTheme.rect(root, UDim2.fromOffset(300, 3), C.Track, HudTheme.TrackTransparency)
	bar.LayoutOrder = 3
	barFill = HudTheme.rect(bar, UDim2.fromScale(0, 1), C.White)

	HudTheme.parent(gui)
end

return MissionLine
