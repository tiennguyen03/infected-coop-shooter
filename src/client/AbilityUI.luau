--!strict
-- Bottom-right ability panel: Q Dash + E Breach with cooldown countdowns, then the two
-- call-in tiles [1] / [2] with the lore name, charge pips and
-- the time to the next charge (CallIn<n>Charges / CallIn<n>ReadyAt attributes, server
-- time), plus a Combat Momentum stack readout. Ability cooldowns are driven by the
-- AbilityUsed remote (server authority); the UI counts down locally for display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CallInDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CallInDefinitions"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AbilityUI = {}

type Slot = { frame: Frame, label: TextLabel, cdLabel: TextLabel, readyUntil: number }
type CallInTile = { frame: Frame, label: TextLabel, cdLabel: TextLabel, pips: { Frame } }
local slots: { [string]: Slot } = {}
local callInTiles: { CallInTile } = {}
local momentumLabel: TextLabel

local READY_COLOR = Color3.fromRGB(60, 120, 180)
local COOLING_COLOR = Color3.fromRGB(45, 48, 55)
local PIP_ON = Color3.fromRGB(232, 181, 75)
local PIP_OFF = Color3.fromRGB(70, 72, 78)
local TILE_WIDTH = 96
local TILE_GAP = 8
local MAX_PIPS = 3

local function makeSlot(parent: Frame, key: string, name: string, order: number): Slot
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(TILE_WIDTH, 52)
	frame.Position = UDim2.fromOffset(order * (TILE_WIDTH + TILE_GAP), 0)
	frame.BackgroundColor3 = READY_COLOR
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Text = `[{key}] {name}`
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local cdLabel = Instance.new("TextLabel")
	cdLabel.Position = UDim2.fromOffset(0, 28)
	cdLabel.Size = UDim2.new(1, 0, 0, 20)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text = "READY"
	cdLabel.TextColor3 = Color3.fromRGB(180, 230, 200)
	cdLabel.TextScaled = true
	cdLabel.Font = Enum.Font.Gotham
	cdLabel.Parent = frame

	return { frame = frame, label = label, cdLabel = cdLabel, readyUntil = 0 }
end

-- A call-in tile: the slot's base layout plus a row of charge pips under the name.
local function makeCallInTile(parent: Frame, slot: number, order: number): CallInTile
	local base = makeSlot(parent, tostring(slot), "", order)
	base.cdLabel.Position = UDim2.fromOffset(0, 34)
	base.cdLabel.Size = UDim2.new(1, 0, 0, 16)
	local pips = {}
	for index = 1, MAX_PIPS do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(14, 5)
		pip.Position = UDim2.fromOffset(8 + (index - 1) * 18, 28)
		pip.BackgroundColor3 = PIP_OFF
		pip.BorderSizePixel = 0
		pip.Visible = false
		pip.Parent = base.frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = pip
		table.insert(pips, pip)
	end
	return { frame = base.frame, label = base.label, cdLabel = base.cdLabel, pips = pips }
end

local function updateCallInTile(tile: CallInTile, slot: number)
	local player = Players.LocalPlayer
	local definition = CallInDefinitions.get(player:GetAttribute(`CallIn{slot}`) :: string?)
	if not definition then
		tile.frame.Visible = false
		return
	end
	tile.frame.Visible = true
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	local charges = (player:GetAttribute(`CallIn{slot}Charges`) :: number?) or 0
	local readyAt = (player:GetAttribute(`CallIn{slot}ReadyAt`) :: number?) or 0
	tile.label.Text = `[{slot}] {definition.Name}`
	for index, pip in tile.pips do
		pip.Visible = index <= cfg.Charges
		pip.BackgroundColor3 = if index <= charges then PIP_ON else PIP_OFF
	end
	local remaining = readyAt - workspace:GetServerTimeNow()
	if charges > 0 then
		tile.frame.BackgroundColor3 = READY_COLOR
		tile.cdLabel.Text = if remaining > 0 and charges < cfg.Charges
			then string.format("%d  +%.0fs", charges, remaining)
			else "READY"
	else
		tile.frame.BackgroundColor3 = COOLING_COLOR
		tile.cdLabel.Text = if remaining > 0 then string.format("%.0fs", remaining) else "..."
	end
end

function AbilityUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityUI"
	gui.ResetOnSpawn = false

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -16, 1, -16)
	container.Size = UDim2.fromOffset(4 * TILE_WIDTH + 3 * TILE_GAP, 52)
	container.BackgroundTransparency = 1
	container.Parent = gui

	slots.dash = makeSlot(container, "Q", "Dash", 0)
	slots.breach = makeSlot(container, "E", "Breach", 1)
	callInTiles[1] = makeCallInTile(container, 1, 2)
	callInTiles[2] = makeCallInTile(container, 2, 3)

	momentumLabel = Instance.new("TextLabel")
	momentumLabel.AnchorPoint = Vector2.new(1, 1)
	momentumLabel.Position = UDim2.new(1, -16, 1, -76)
	momentumLabel.Size = UDim2.fromOffset(200, 18)
	momentumLabel.BackgroundTransparency = 1
	momentumLabel.Text = ""
	momentumLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
	momentumLabel.TextScaled = true
	momentumLabel.TextXAlignment = Enum.TextXAlignment.Right
	momentumLabel.Font = Enum.Font.GothamBold
	momentumLabel.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.get("AbilityUsed").OnClientEvent:Connect(function(name: string, cooldown: unknown)
		local slot = slots[name]
		if slot and typeof(cooldown) == "number" then
			slot.readyUntil = os.clock() + cooldown
		end
	end)

	local lastClock = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - lastClock
		lastClock = now
		-- Freeze the countdown while the field is frozen (run end) so the display matches
		-- the server, which also pauses cooldown progress.
		local paused = workspace:GetAttribute("GamePaused") == true
		for _, slot in slots do
			if paused and slot.readyUntil > now then
				slot.readyUntil += dt
			end
			local remaining = slot.readyUntil - now
			if remaining > 0 then
				slot.frame.BackgroundColor3 = COOLING_COLOR
				slot.cdLabel.Text = string.format("%.1fs", remaining)
			else
				slot.frame.BackgroundColor3 = READY_COLOR
				slot.cdLabel.Text = "READY"
			end
		end
		for slot, tile in callInTiles do
			updateCallInTile(tile, slot)
		end
		local stacks = (Players.LocalPlayer:GetAttribute("MomentumStacks") :: number?) or 0
		momentumLabel.Text = if stacks > 0 then `MOMENTUM x{stacks}` else ""
	end)
end

return AbilityUI
