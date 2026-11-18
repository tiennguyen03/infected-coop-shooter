--!strict
-- The mission line (HUD language: HudTheme; after Prototype 2's objective line): one white
-- line, verbs and targets in caps with the key word coloured, a smaller second line, an
-- optional dim third line (what to do now) and, whenever there is progress to show, the
-- meter: a readout ("HOLDING  23 of 60s") over a 440x10 yellow bar (Config.Objectives.Meter;
-- owner 2026-11-17: the old 3 px bar was missed). No panel. ObjectiveUI and ExtractionUI
-- both write it; extraction outranks the objective, so while extraction shows, the
-- objective waits underneath.
--
-- The mission stack (Config.Hud) is one top-to-bottom flow: this block, then whatever is
-- attached under it (subtitles; on touch the insert card), so none of them can overlap.
-- PC: from 72% down the screen; touch: top centre, clear of the thumbstick and buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudTheme = require(script.Parent.HudTheme)

local MissionLine = {}

local C = HudTheme.Color
local PRIORITY: { [string]: number } = { objective = 1, extraction = 2 }
local WIDTH = 900

-- What an owner shows. `progress` 0..1 shows the meter (nil hides it); `readout` is the
-- line over the bar; `paused` dims the fill and turns the bar's outline red (a hold that
-- stopped).
export type Line = {
	text: string,
	sub: string?,
	detail: string?, -- the dim third line
	progress: number?,
	readout: string?,
	paused: boolean?,
	color: Color3?, -- line one's colour (red: RETURN to the LZ)
}

local entries: { [string]: Line } = {}
local stack: Frame = nil :: any
local block: Frame = nil :: any
local line1: TextLabel = nil :: any
local line2: TextLabel = nil :: any
local line3: TextLabel = nil :: any
local meter: Frame = nil :: any
local readout: TextLabel = nil :: any
local bar: Frame = nil :: any
local barFill: Frame = nil :: any
local barOutline: UIStroke = nil :: any
local shownOwner: string? = nil
local shownProgress: number? = nil
local built = false

local function top(): (string?, Line?)
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
		if block.Visible then
			TweenService:Create(line1, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.delay(0.3, function()
				if not top() then
					block.Visible = false
				end
			end)
		end
		shownOwner = nil
		shownProgress = nil
		return
	end
	local fresh = owner ~= shownOwner or not block.Visible
	shownOwner = owner
	block.Visible = true
	line1.TextTransparency = 0
	line1.Text = entry.text
	line1.TextColor3 = entry.color or C.Text
	line2.Text = entry.sub or ""
	line2.Visible = line2.Text ~= ""
	line3.Text = entry.detail or ""
	line3.Visible = line3.Text ~= ""

	local progress = entry.progress
	meter.Visible = progress ~= nil
	if progress then
		readout.Text = entry.readout or ""
		readout.Visible = readout.Text ~= ""
		barFill.BackgroundColor3 = if entry.paused then C.TextDim else C.Yellow
		barOutline.Color = if entry.paused then C.RedLight else C.White
		barOutline.Transparency = if entry.paused then 0 else HudTheme.OutlineTransparency
		local size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		if fresh or shownProgress == nil then
			barFill.Size = size
		elseif progress ~= shownProgress then
			-- The server steps about once a second: ease to it so the bar is seen to move.
			TweenService:Create(
				barFill,
				TweenInfo.new(
					Config.Objectives.Meter.FillSeconds,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{ Size = size }
			):Play()
		end
	end
	shownProgress = progress

	if fresh then
		-- Appear: fade in (the stack's layout places the block, so no rise).
		line1.TextTransparency = 1
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(line1, info, { TextTransparency = 0 }):Play()
	end
end

-- Shows (or updates) `owner`'s line.
function MissionLine.set(owner: string, line: Line)
	entries[owner] = line
	render()
end

function MissionLine.clear(owner: string)
	if entries[owner] then
		entries[owner] = nil
		render()
	end
end

-- Puts `object` in the mission stack under the line (`order` 2 and up: the subtitle, the
-- touch insert card), so it flows below it instead of being placed over it.
function MissionLine.attach(object: GuiObject, order: number)
	MissionLine.init()
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(0, 0)
	object.LayoutOrder = order
	object.Parent = stack
end

-- Builds the stack once (ObjectiveUI.init calls it; ExtractionUI and BuffNoticeUI after).
function MissionLine.init()
	if built then
		return
	end
	built = true
	local gui = HudTheme.gui("MissionLine", 10)
	stack = Instance.new("Frame")
	stack.Name = "MissionStack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = if HudTheme.isTouch()
		then UDim2.new(0.5, 0, 0, Config.Hud.MissionTopTouch)
		else UDim2.fromScale(0.5, Config.Hud.MissionTop)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.Size = UDim2.fromOffset(WIDTH, 0)
	stack.Parent = gui
	local stackLayout = Instance.new("UIListLayout")
	stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stackLayout.Padding = UDim.new(0, 8)
	stackLayout.Parent = stack

	block = Instance.new("Frame")
	block.Name = "Line"
	block.BackgroundTransparency = 1
	block.AutomaticSize = Enum.AutomaticSize.Y
	block.Size = UDim2.fromOffset(WIDTH, 0)
	block.LayoutOrder = 1
	block.Visible = false
	block.Parent = stack
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = block

	line1 = HudTheme.label(block, { size = 22, rich = true })
	line1.LayoutOrder = 1
	line2 = HudTheme.label(block, { font = HudTheme.Font.Body, size = 18, rich = true })
	line2.LayoutOrder = 2
	line3 = HudTheme.label(block, {
		font = HudTheme.Font.Body,
		size = 14,
		color = C.TextDim,
		rich = true,
	})
	line3.LayoutOrder = 3
	line3.Visible = false

	-- The meter: a GothamBlack readout over a hard-edged yellow bar with a 1 px outline.
	local settings = Config.Objectives.Meter
	meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.BackgroundTransparency = 1
	meter.AutomaticSize = Enum.AutomaticSize.Y
	meter.Size = UDim2.fromOffset(settings.Width, 0)
	meter.LayoutOrder = 4
	meter.Visible = false
	meter.Parent = block
	local meterLayout = Instance.new("UIListLayout")
	meterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	meterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	meterLayout.Padding = UDim.new(0, 4)
	meterLayout.Parent = meter
	-- A little air between the text lines and the meter.
	local gap = Instance.new("UIPadding")
	gap.PaddingTop = UDim.new(0, 4)
	gap.Parent = meter
	readout = HudTheme.label(meter, { font = HudTheme.Font.Headline, size = 20, rich = true })
	readout.LayoutOrder = 1
	bar = HudTheme.rect(
		meter,
		UDim2.fromOffset(settings.Width, settings.Height),
		C.Track,
		HudTheme.TrackTransparency,
		true
	)
	bar.LayoutOrder = 2
	barOutline = bar:FindFirstChildOfClass("UIStroke") :: UIStroke
	barFill = HudTheme.rect(bar, UDim2.fromScale(0, 1), C.Yellow)

	HudTheme.parent(gui)
end

return MissionLine
