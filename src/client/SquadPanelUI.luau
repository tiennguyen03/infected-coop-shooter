--!strict
-- Squad status panel, left edge under the top-left HUD (owner 2026-11-11: no floating
-- health bars; squadmates' status on the side). One compact row per OTHER squad member,
-- player or bot, read from ReplicatedStorage.SquadRoster (Squad writes it; bodies stream
-- out, the roster does not): name, a thin health bar, the Armour Plate bar under it, and
-- the state on the right: red when low, "DOWN 23s" on a draining bar, "REVIVING" on a
-- filling blue bar, "DEAD 8s" greyed. The row flashes on a big hit or when its member goes
-- down. What a row shows is Rules/SquadPanel; numbers in Config.SquadPanel. Event-driven:
-- rows repaint on attribute changes, and a slow timer runs only while a countdown shows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"):WaitForChild("SquadPanel"))
local HudTheme = require(script.Parent.HudTheme)

local SquadPanelUI = {}

local C = HudTheme.Color
local settings = Config.SquadPanel
local VIEW_SETTINGS: Rules.Settings = {
	LowFraction = settings.LowFraction,
	BleedOutSeconds = Config.Downed.BleedOutSeconds,
	ReviveHold = Config.Downed.ReviveHold,
}
local STATE_WIDTH = 78
local NAME_HEIGHT = 16
local BAR_TOP = 19
local BAR_HEIGHT = 6
local SHIELD_TOP = 27
local SHIELD_HEIGHT = 3

type Row = {
	entry: Instance,
	frame: Frame,
	flash: Frame,
	name: TextLabel,
	state: TextLabel,
	fill: Frame,
	outline: UIStroke,
	shield: Frame,
	shieldFill: Frame,
	lastState: string?,
	lastHealth: number,
	ticking: boolean,
}

local rows: { [Instance]: Row } = {}
local root: Frame
local tickerRunning = false

local function number(entry: Instance, attribute: string): number
	local value = entry:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function text(entry: Instance, attribute: string): string
	local value = entry:GetAttribute(attribute)
	return if typeof(value) == "string" then value else ""
end

-- A player by their display name, a bot by its squad name.
local function displayName(entry: Instance): string
	local userId = number(entry, Attributes.SquadUserId)
	local player = if userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
	local name = if player then player.DisplayName else text(entry, Attributes.Callsign)
	return string.upper(name)
end

local function flash(row: Row)
	row.flash.BackgroundTransparency = 0.5
	TweenService:Create(
		row.flash,
		TweenInfo.new(settings.FlashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

local refresh: (row: Row) -> ()

-- Countdowns (bleed-out, revive, respawn) repaint on a slow timer that stops with them.
local function ensureTicker()
	if tickerRunning then
		return
	end
	tickerRunning = true
	task.spawn(function()
		local running = true
		while running do
			task.wait(settings.TickSeconds)
			running = false
			for _, row in rows do
				if row.ticking then
					refresh(row)
					running = running or row.ticking
				end
			end
		end
		tickerRunning = false
	end)
end

function refresh(row: Row)
	local entry = row.entry
	local state = entry:GetAttribute(Attributes.SquadState)
	local input: Rules.Input = {
		state = if typeof(state) == "string" then state else nil,
		health = number(entry, Attributes.SquadHealth),
		maxHealth = number(entry, Attributes.SquadMaxHealth),
		shield = number(entry, Attributes.Shield),
		bleedOutAt = number(entry, Attributes.BleedOutAt),
		reviver = text(entry, Attributes.Reviver),
		reviveEndsAt = number(entry, Attributes.ReviveEndsAt),
		respawnAt = number(entry, Attributes.RespawnAt),
	}
	local view = Rules.view(input, workspace:GetServerTimeNow(), VIEW_SETTINGS)
	if
		Rules.flashes(
			row.lastState,
			row.lastHealth,
			input.state,
			input.health,
			input.maxHealth,
			settings.BigHitFraction
		)
	then
		flash(row)
	end
	row.lastState, row.lastHealth = input.state, input.health

	local out = view.status == "Dead" or view.status == "Standby"
	local hot = view.status == "Low" or view.status == "Downed"
	local reviving = view.status == "Downed" and input.reviver ~= ""
	row.name.TextColor3 = if out then C.TextDim elseif hot then C.RedLight else C.Squad
	row.state.Text = view.text
	row.state.TextColor3 = if out then C.TextDim elseif reviving then C.Squad else C.RedLight
	row.fill.Size = UDim2.fromScale(view.bar, 1)
	row.fill.BackgroundColor3 = if view.barKind == "revive"
		then C.Squad
		elseif hot then C.RedLight
		else C.Red
	row.outline.Color = if hot then C.RedLight else C.White
	row.outline.Transparency = if hot then 0 else HudTheme.OutlineTransparency
	row.shield.Visible = view.shield > 0
	row.shieldFill.Size = UDim2.fromScale(view.shield, 1)

	row.ticking = view.ticking
	if view.ticking then
		ensureTicker()
	end
end

-- Rows in the squad's callsign order, the local player's own entry hidden.
local function layout()
	local entries: { Rules.Entry } = {}
	local rowOf: { [Rules.Entry]: Row } = {}
	for entry, row in rows do
		local item: Rules.Entry = {
			key = entry.Name,
			callsign = text(entry, Attributes.Callsign),
			userId = number(entry, Attributes.SquadUserId),
		}
		table.insert(entries, item)
		rowOf[item] = row
		row.frame.Visible = false
	end
	local ordered =
		Rules.order(entries, Config.Bots.Callsigns, Players.LocalPlayer.UserId, settings.MaxRows)
	for index, item in ordered do
		local frame = rowOf[item].frame
		frame.Position = UDim2.fromOffset(0, (index - 1) * (settings.RowHeight + settings.RowGap))
		frame.Visible = true
	end
end

local function addRow(entry: Instance)
	if rows[entry] then
		return
	end
	local width = settings.Width
	local frame = Instance.new("Frame")
	frame.Name = entry.Name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(width, settings.RowHeight)
	frame.Visible = false
	frame.Parent = root

	local flashFrame = HudTheme.rect(frame, UDim2.new(1, 8, 1, 4), C.RedLight, 1)
	flashFrame.Position = UDim2.fromOffset(-4, -2)

	local name = HudTheme.label(frame, { size = 14, color = C.Squad })
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.fromOffset(width - STATE_WIDTH, NAME_HEIGHT)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local state =
		HudTheme.label(frame, { size = 12, color = C.RedLight, align = Enum.TextXAlignment.Right })
	state.AutomaticSize = Enum.AutomaticSize.None
	state.Size = UDim2.fromOffset(STATE_WIDTH, NAME_HEIGHT)
	state.Position = UDim2.fromOffset(width - STATE_WIDTH, 0)

	local track = HudTheme.rect(
		frame,
		UDim2.fromOffset(width, BAR_HEIGHT),
		C.Track,
		HudTheme.TrackTransparency,
		true
	)
	track.Position = UDim2.fromOffset(0, BAR_TOP)
	local fill = HudTheme.rect(track, UDim2.fromScale(0, 1), C.Red)

	local shield = HudTheme.rect(
		frame,
		UDim2.fromOffset(width, SHIELD_HEIGHT),
		C.Track,
		HudTheme.TrackTransparency
	)
	shield.Position = UDim2.fromOffset(0, SHIELD_TOP)
	shield.Visible = false
	local shieldFill = HudTheme.rect(shield, UDim2.fromScale(0, 1), C.White)

	local row: Row = {
		entry = entry,
		frame = frame,
		flash = flashFrame,
		name = name,
		state = state,
		fill = fill,
		outline = track:FindFirstChildOfClass("UIStroke") :: UIStroke,
		shield = shield,
		shieldFill = shieldFill,
		lastState = nil,
		lastHealth = 0,
		ticking = false,
	}
	rows[entry] = row
	name.Text = displayName(entry)
	entry.AttributeChanged:Connect(function(attribute)
		if rows[entry] ~= row then
			return
		end
		if attribute == Attributes.Callsign or attribute == Attributes.SquadUserId then
			name.Text = displayName(entry)
			layout()
		end
		refresh(row)
	end)
	refresh(row)
	layout()
end

local function removeRow(entry: Instance)
	local row = rows[entry]
	if row then
		rows[entry] = nil
		row.frame:Destroy()
		layout()
	end
end

function SquadPanelUI.init()
	-- Roblox's own health bar (top right, shown when hurt) goes with the floating bars: the
	-- player's health is HealthBarUI.
	if not settings.OverheadBars then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
	end
	if not settings.Enabled then
		return
	end
	local gui = HudTheme.gui("SquadPanelUI")
	root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(HudTheme.Margin, settings.Top)
	root.Size =
		UDim2.fromOffset(settings.Width, settings.MaxRows * (settings.RowHeight + settings.RowGap))
	root.Parent = gui
	HudTheme.parent(gui)

	-- A squadmate's Player can arrive after their roster entry: name the rows again.
	Players.PlayerAdded:Connect(function()
		for entry, row in rows do
			row.name.Text = displayName(entry)
		end
	end)
	task.spawn(function()
		local roster = ReplicatedStorage:WaitForChild(Attributes.SquadRoster)
		roster.ChildAdded:Connect(addRow)
		roster.ChildRemoved:Connect(removeRow)
		for _, entry in roster:GetChildren() do
			addRow(entry)
		end
	end)
end

return SquadPanelUI
