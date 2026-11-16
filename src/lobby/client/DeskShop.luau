--!strict
-- The call-ins a Carrier desk sells (owner, 2026-11-10: grenades and call-ins are bought too):
-- a panel beside the desk's talk panel listing each call-in the desk sells (KitPrices.soldAt:
-- the row's `Desk`), with what it is, ON YOUR RECORD or its price, and BUY. Fires sells the
-- fire missions, the Engineers the emplacements and wire, the Loadmaster what Lantern kicks
-- (DeskDialogUI, LoadmasterUI). The server decides every buy (RecordService); the panel
-- repaints when the record changes (RecordClient).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local HudTheme = require(script.Parent.HudTheme)
local RecordClient = require(script.Parent.RecordClient)

local DeskShop = {}

local WIDTH = 420

local gui = HudTheme.gui("DeskShop", 8)
local panel = HudTheme.rect(
	gui,
	UDim2.fromOffset(WIDTH, 0),
	HudTheme.Color.Track,
	HudTheme.TrackTransparency,
	true
)
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -HudTheme.Margin * 2, 0.5, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Visible = false
do
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = panel
end
local title = HudTheme.label(
	panel,
	{ size = 20, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow }
)
title.LayoutOrder = 1
local merits = HudTheme.label(panel, { size = 15, color = HudTheme.Color.TextDim })
merits.LayoutOrder = 2
local note = HudTheme.label(panel, { size = 14, color = HudTheme.Color.RedLight })
note.LayoutOrder = 999
note.Size = UDim2.fromScale(1, 0)
note.AutomaticSize = Enum.AutomaticSize.Y
note.TextWrapped = true

local shown: { string } = {}
local said: LobbyDesks.Talk? = nil -- the desk's own bought / short / refused lines
local meritsBefore = 0
local rows: { Frame } = {}

local function clearRows()
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
end

local function paint()
	merits.Text = RecordClient.balanceText()
	clearRows()
	for index, id in shown do
		local def = CallInDefinitions.get(id)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 40)
		row.LayoutOrder = 10 + index
		row.Parent = panel
		local name = HudTheme.label(row, {
			size = 16,
			font = HudTheme.Font.Headline,
			text = string.upper(if def then def.Name else id),
		})
		name.Position = UDim2.fromOffset(0, 2)
		local what = HudTheme.label(row, {
			size = 13,
			color = HudTheme.Color.TextDim,
			text = if def then def.Codename else "",
		})
		what.Position = UDim2.fromOffset(0, 22)
		local price = RecordClient.priceOf(id) or 0
		if RecordClient.owns(id) then
			local owned = HudTheme.label(row, {
				size = 14,
				font = HudTheme.Font.Headline,
				color = HudTheme.Color.Yellow,
				text = "ON YOUR RECORD",
				align = Enum.TextXAlignment.Right,
			})
			owned.AnchorPoint = Vector2.new(1, 0)
			owned.Position = UDim2.new(1, 0, 0, 10)
		else
			local short = RecordClient.merits() < price
			local buy = Instance.new("TextButton")
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.fromScale(1, 0.5)
			buy.Size = UDim2.fromOffset(170, 32)
			buy.BackgroundColor3 = HudTheme.Color.Track
			buy.BackgroundTransparency = 0.2
			buy.BorderSizePixel = 0
			buy.Font = HudTheme.Font.Headline
			buy.TextSize = 14
			buy.TextColor3 = HudTheme.Color.Text
			buy.TextTransparency = if short then 0.5 else 0
			buy.Text = if short then `BUY · {price} (SHORT)` else `BUY · {price} MERITS`
			buy.Modal = true -- frees the mouse while the panel is up
			local stroke = Instance.new("UIStroke")
			stroke.Color = HudTheme.Color.White
			stroke.Transparency = HudTheme.OutlineTransparency
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = buy
			buy.Parent = row
			buy.Activated:Connect(function()
				note.Text = ""
				meritsBefore = RecordClient.merits()
				RecordClient.buy(id)
			end)
		end
		table.insert(rows, row)
	end
end

-- Shows what a desk sells (call-in ids), with the desk's own lines; nothing to sell hides it.
function DeskShop.show(heading: string, ids: { string }, talk: LobbyDesks.Talk?)
	shown = table.clone(ids)
	said = talk
	meritsBefore = RecordClient.merits()
	if #shown == 0 then
		DeskShop.hide()
		return
	end
	title.Text = heading
	note.Text = ""
	paint()
	panel.Visible = true
end

function DeskShop.hide()
	panel.Visible = false
	shown = {}
	clearRows()
end

function DeskShop.init()
	HudTheme.parent(gui)
	RecordClient.Changed:Connect(function()
		if panel.Visible then
			paint()
			if said and RecordClient.merits() < meritsBefore then
				note.TextColor3 = HudTheme.Color.Yellow
				note.Text = `"{said.bought}"`
			end
			meritsBefore = RecordClient.merits()
		end
	end)
	RecordClient.Refused:Connect(function(_id: unknown, reason: unknown)
		if panel.Visible then
			note.TextColor3 = HudTheme.Color.RedLight
			local line = if said
				then (if reason == "short" then said.short else said.refused)
				else nil
			note.Text = if line
				then `"{line}"`
				elseif reason == "short" then "Not enough merits."
				else "Try again in a minute."
		end
	end)
end

return DeskShop
