--!strict
-- The Plot's Containment Board (docs/LORE.md > The Fallow): a lit perspex panel with one
-- column per district, its percent and the band word, written by a plotter standing behind
-- it. Rereads the board every Config.Containment.RefreshSeconds; a changed number is wiped
-- and rewritten (fade out, swap, fade in) with no fanfare. Built on the server, so every
-- soldier in the lobby reads the same board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Containment = require(ReplicatedStorage.Shared.Rules.Containment)
local Build = require(script.Parent.Build)
local ContainmentBoard = require(script.Parent.ContainmentBoard)
local Layout = require(script.Parent.FallowLayout)

local PlotService = {}

local PENCIL = Color3.fromRGB(240, 226, 170)
local PENCIL_DIM = Color3.fromRGB(190, 176, 130)
local WIPE = TweenInfo.new(0.35)

type Column = {
	percent: TextLabel,
	band: TextLabel,
	shown: number?,
}

local columns: { [string]: Column } = {}

local function label(
	parent: Instance,
	text: string,
	size: number,
	font: Enum.Font,
	color: Color3
): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = UDim2.new(1, 0, 0, size + 8)
	item.Text = text
	item.TextSize = size
	item.Font = font
	item.TextColor3 = color
	item.Parent = parent
	return item
end

local function buildPanel(): Frame
	local folder = Build.folder(Workspace, "Plot")
	local panel = Build.part(
		folder,
		"Board",
		Layout.Board.size,
		Layout.Board.cframe,
		Color3.fromRGB(150, 170, 160),
		{ material = Enum.Material.Glass, transparency = 0.55 }
	)
	-- The frame around the perspex.
	local size = Layout.Board.size
	for _, y in { -size.Y / 2, size.Y / 2 } do
		Build.part(
			folder,
			"BoardFrame",
			Vector3.new(0.6, 0.4, size.Z + 0.4),
			Layout.Board.cframe * CFrame.new(0, y, 0),
			Color3.fromRGB(30, 30, 32)
		)
	end
	-- (The silent plotter who stood behind it is gone: Control's watch officer runs the Plot
	-- now, a desk at the map table, DeskService; owner 2026-11-10.)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- the panel is lit from behind
	gui.Parent = panel

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local title = label(root, "CONTAINMENT", 46, Enum.Font.PermanentMarker, PENCIL)
	title.Position = UDim2.fromOffset(0, 10)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(20, 90)
	row.Size = UDim2.new(1, -40, 1, -110)
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

local function buildColumns(row: Frame, districts: { ContainmentBoard.District })
	for index, district in districts do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.LayoutOrder = index
		column.Size = UDim2.fromScale(0, 1)
		column.Parent = row
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 18)
		list.Parent = column
		local name = label(column, district.name, 30, Enum.Font.PermanentMarker, PENCIL_DIM)
		name.LayoutOrder = 1
		local percent = label(column, "", 96, Enum.Font.PermanentMarker, PENCIL)
		percent.LayoutOrder = 2
		local band = label(column, "", 34, Enum.Font.PermanentMarker, PENCIL)
		band.LayoutOrder = 3
		columns[district.name] = { percent = percent, band = band, shown = nil }
	end
end

local function write(column: Column, value: number)
	local shown = Containment.percent(value)
	if column.shown == shown then
		return
	end
	local first = column.shown == nil
	column.shown = shown
	local function swap()
		column.percent.Text = `{shown}%`
		column.band.Text = string.upper(Containment.band(shown, Config.Containment.Bands))
	end
	if first then
		swap()
		return
	end
	-- Wipe and rewrite.
	for _, item in { column.percent, column.band } do
		TweenService:Create(item, WIPE, { TextTransparency = 1 }):Play()
	end
	task.delay(WIPE.Time, function()
		swap()
		for _, item in { column.percent, column.band } do
			TweenService:Create(item, WIPE, { TextTransparency = 0 }):Play()
		end
	end)
end

local function refresh()
	local ok, districts = pcall(ContainmentBoard.read)
	if not ok then
		warn(`[PlotService] board read failed: {districts}`)
		return
	end
	for _, district in districts do
		local column = columns[district.name]
		if column then
			write(column, district.percent)
		end
	end
end

function PlotService.init()
	local row = buildPanel()
	buildColumns(row, ContainmentBoard.read())
	refresh()
	task.spawn(function()
		while true do
			task.wait(Config.Containment.RefreshSeconds)
			refresh()
		end
	end)
end

return PlotService
