--!strict
-- Loadout HUD (replaced ItemBarUI). Two pieces, both read from
-- LocalPlayer attributes LoadoutService publishes:
--   * the ammo counter beside the crosshair: MAG / RESERVE, amber when the magazine is low,
--     "RELOADING" with a draining bar while ReloadUntil is ahead of server time, red "DRY"
--     on an empty magazine;
--   * the loadout strip, top-left: the two call-in names and the six field-upgrade slots
--     (Dash, Breach, Rifle, Kit, and one per call-in), each showing the upgrade's lore name
--     or a dim "-".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))

local CallInDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CallInDefinitions"))
local UpgradeDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))

local LoadoutUI = {}

local TEXT = Color3.fromRGB(235, 235, 235)
local DIM = Color3.fromRGB(120, 124, 130)
local AMBER = Color3.fromRGB(232, 181, 75)
local RED = Color3.fromRGB(214, 69, 51)
local PANEL = Color3.fromRGB(20, 20, 20)
local LOW_MAG_FRACTION = 0.25

local ammoLabel: TextLabel
local reloadBar: Frame
local reloadFill: Frame
local slotLabels: { [string]: TextLabel } = {}
local callInLabels: { TextLabel } = {}

-- Slot order on the strip; CallInA / CallInB are named after the call-in they ride on.
local STRIP_SLOTS = { "Dash", "Breach", "Rifle", "Kit", "CallInA", "CallInB" }

local function createAmmoCounter(gui: ScreenGui)
	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "Ammo"
	ammoLabel.AnchorPoint = Vector2.new(0, 0.5)
	ammoLabel.Position = UDim2.new(0.5, 70, 0.5, 34)
	ammoLabel.Size = UDim2.fromOffset(150, 26)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = "30 / 120"
	ammoLabel.TextColor3 = TEXT
	ammoLabel.TextStrokeTransparency = 0.6
	ammoLabel.TextScaled = true
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ammoLabel.Font = Enum.Font.GothamBlack
	ammoLabel.Parent = gui

	reloadBar = Instance.new("Frame")
	reloadBar.Name = "Reload"
	reloadBar.AnchorPoint = Vector2.new(0, 0.5)
	reloadBar.Position = UDim2.new(0.5, 70, 0.5, 52)
	reloadBar.Size = UDim2.fromOffset(120, 5)
	reloadBar.BackgroundColor3 = PANEL
	reloadBar.BackgroundTransparency = 0.4
	reloadBar.BorderSizePixel = 0
	reloadBar.Visible = false
	reloadBar.Parent = gui
	reloadFill = Instance.new("Frame")
	reloadFill.Size = UDim2.fromScale(0, 1)
	reloadFill.BackgroundColor3 = AMBER
	reloadFill.BorderSizePixel = 0
	reloadFill.Parent = reloadBar
end

local function makeStripLabel(parent: Frame, order: number, width: number): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.fromOffset(width, 22)
	label.BackgroundColor3 = PANEL
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Text = "-"
	label.TextColor3 = DIM
	label.TextSize = 13
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = label
	return label
end

local function createStrip(gui: ScreenGui)
	local strip = Instance.new("Frame")
	strip.Name = "Loadout"
	strip.Position = UDim2.fromOffset(16, 52)
	strip.Size = UDim2.fromOffset(640, 22)
	strip.BackgroundTransparency = 1
	strip.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	callInLabels[1] = makeStripLabel(strip, 1, 92)
	callInLabels[2] = makeStripLabel(strip, 2, 92)
	for index, slot in STRIP_SLOTS do
		slotLabels[slot] = makeStripLabel(strip, 10 + index, 96)
	end
end

local function updateAmmo()
	local player = Players.LocalPlayer
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local mag = (player:GetAttribute(Attributes.Mag) :: number?) or 0
	local reserve = (player:GetAttribute(Attributes.Reserve) :: number?) or 0
	local reloadUntil = (player:GetAttribute(Attributes.ReloadUntil) :: number?) or 0
	local now = workspace:GetServerTimeNow()
	if reloadUntil > now then
		ammoLabel.Text = "RELOADING"
		ammoLabel.TextColor3 = AMBER
		reloadBar.Visible = true
		local remaining = reloadUntil - now
		reloadFill.Size = UDim2.fromScale(1 - math.clamp(remaining / weapon.ReloadTime, 0, 1), 1)
		return
	end
	reloadBar.Visible = false
	if mag <= 0 then
		ammoLabel.Text = if reserve > 0 then `DRY  [R]  / {reserve}` else "DRY  / 0"
		ammoLabel.TextColor3 = RED
	else
		ammoLabel.Text = `{mag} / {reserve}`
		ammoLabel.TextColor3 = if mag <= weapon.MagazineSize * LOW_MAG_FRACTION then AMBER else TEXT
	end
end

local function updateStrip()
	local player = Players.LocalPlayer
	for slot = 1, 2 do
		local definition =
			CallInDefinitions.get(player:GetAttribute(Attributes.callIn(slot)) :: string?)
		local label = callInLabels[slot]
		label.Text = if definition then `{slot}  {definition.Name}` else `{slot}  -`
		label.TextColor3 = if definition then definition.Color else DIM
	end
	for _, slot in STRIP_SLOTS do
		local label = slotLabels[slot]
		local definition =
			UpgradeDefinitions.get(player:GetAttribute(Attributes.upgrade(slot)) :: string?)
		local slotName = slot
		if slot == "CallInA" or slot == "CallInB" then
			local callIn = CallInDefinitions.get(
				player:GetAttribute(Attributes.callIn(if slot == "CallInA" then 1 else 2)) :: string?
			)
			slotName = if callIn then callIn.Name else slot
		end
		if definition then
			label.Text = definition.Name
			label.TextColor3 = TEXT
		else
			label.Text = `{slotName}: -`
			label.TextColor3 = DIM
		end
	end
end

function LoadoutUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadoutUI"
	gui.ResetOnSpawn = false
	createAmmoCounter(gui)
	createStrip(gui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local player = Players.LocalPlayer
	for _, name in { Attributes.callIn(1), Attributes.callIn(2) } do
		player:GetAttributeChangedSignal(name):Connect(updateStrip)
	end
	for _, slot in STRIP_SLOTS do
		player:GetAttributeChangedSignal(Attributes.upgrade(slot)):Connect(updateStrip)
	end
	updateStrip()
	RunService.RenderStepped:Connect(updateAmmo)
end

return LoadoutUI
