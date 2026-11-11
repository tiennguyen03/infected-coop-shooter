--!strict
-- The wallet readout (owner, 2026-11-11): what a soldier holds, as two small marks with a
-- number each: the medal for merits (yellow), the steel tag for tabs (white). Built in code
-- like the rest of the UI and shared by both places: the Carrier's topbar (lobby WalletUI)
-- and the match's results screen (RunEndUI). The look is the HUD's (docs/STYLES.md > UI: no
-- panel, GothamBlack numbers, a soft dark stroke); the icons are the generator's glyphs
-- (Config.Wallet, assets/icons/build/icons.js); the numbers are written by Rules/Wallet.
--
-- When a balance changes the number counts to the new one and its mark swells and settles,
-- stepped at 15 Hz (never per frame).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Wallet = require(ReplicatedStorage.Shared.Rules.Wallet)

local WalletReadout = {}

local LOOK = Config.Wallet
local STEP = 1 / 15
local TEXT = Color3.fromRGB(240, 240, 240)
local YELLOW = Color3.fromRGB(230, 189, 96)

export type Readout = {
	frame: Frame,
	-- Shows the balances. The first call writes them; a later one counts to them unless
	-- `animate` is false.
	set: (merits: number, tabs: number, animate: boolean?) -> (),
}

type Entry = {
	label: TextLabel,
	icon: ImageLabel,
	color: Color3,
	shown: number,
	target: number,
	run: number, -- the count in flight; a newer one takes over
}

-- `heat` is 1 as a change lands and falls to 0: the number starts white, the mark swollen.
local function paint(entry: Entry, value: number, heat: number)
	entry.shown = value
	entry.label.Text = Wallet.format(value)
	entry.label.TextColor3 = entry.color:Lerp(Color3.new(1, 1, 1), heat)
	local swell = 1 + LOOK.PulseScale * heat
	entry.icon.Size = UDim2.fromScale(swell, swell)
end

local function count(entry: Entry, to: number)
	entry.target = to
	entry.run += 1
	local run = entry.run
	local from = entry.shown
	local started = os.clock()
	task.spawn(function()
		while entry.run == run and entry.label.Parent do
			local alpha = math.clamp((os.clock() - started) / LOOK.CountSeconds, 0, 1)
			paint(entry, Wallet.countUp(from, to, alpha), 1 - alpha)
			if alpha >= 1 then
				return
			end
			task.wait(STEP)
		end
	end)
end

local function entry(
	parent: Frame,
	order: number,
	image: string,
	color: Color3,
	size: number
): Entry
	-- The mark keeps a fixed box in the row, so its swell never pushes the numbers about.
	local box = Instance.new("Frame")
	box.Name = "Mark"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(size, size)
	box.LayoutOrder = order
	box.Parent = parent
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = image
	icon.Parent = box

	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.55
	label.Text = "0"
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.LayoutOrder = order + 1
	label.Parent = parent

	return { label = label, icon = icon, color = color, shown = 0, target = 0, run = 0 }
end

-- A row "[medal] 1,120   [tag] 40" under `parent`; `size` is the mark and number height in
-- px at 1080p (default Config.Wallet.Size). The caller places `frame`.
function WalletReadout.new(parent: Instance, size: number?): Readout
	local height = size or LOOK.Size
	local frame = Instance.new("Frame")
	frame.Name = "Wallet"
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, math.round(height * 0.3))
	layout.Parent = frame

	local merits = entry(frame, 1, LOOK.MeritsIcon, YELLOW, height)
	-- A wider gap between the two currencies than between a mark and its number.
	local gap = Instance.new("Frame")
	gap.Name = "Gap"
	gap.BackgroundTransparency = 1
	gap.Size = UDim2.fromOffset(math.round(height * 0.4), 1)
	gap.LayoutOrder = 3
	gap.Parent = frame
	local tabs = entry(frame, 4, LOOK.TabsIcon, TEXT, height)

	local primed = false
	local function show(item: Entry, value: number, animate: boolean)
		if animate and value ~= item.target then
			count(item, value)
		elseif not animate then
			item.target = value
			item.run += 1 -- stops a count in flight
			paint(item, value, 0)
		end
	end

	return {
		frame = frame,
		set = function(meritsHeld: number, tabsHeld: number, animate: boolean?)
			local moving = primed and animate ~= false
			primed = true
			show(merits, meritsHeld, moving)
			show(tabs, tabsHeld, moving)
		end,
	}
end

return WalletReadout
