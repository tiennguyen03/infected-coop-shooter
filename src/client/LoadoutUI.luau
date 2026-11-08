--!strict
-- Loadout HUD (HUD language: HudTheme). Both pieces read the LocalPlayer attributes
-- LoadoutService publishes:
--   * the ammo counter beside the crosshair: the magazine large, " / reserve" small and dim,
--     a thin white tick at its left; yellow when the magazine is low, "RELOADING" over a
--     thin bar while ReloadUntil is ahead of server time, red "DRY [R]" on empty. It is
--     attribute-driven and only ticks every frame while a reload runs;
--   * a field upgrade landing in a slot shows as a notification card (BuffNoticeUI) with
--     the upgrade's lore name and slot; the ability circle carries the mark (AbilityUI).
--     There is no always-on upgrade strip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local UpgradeDefinitions = require(Shared:WaitForChild("UpgradeDefinitions"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local BuffNoticeUI = require(script.Parent.BuffNoticeUI)
local HudTheme = require(script.Parent.HudTheme)

local LoadoutUI = {}

local C = HudTheme.Color
local LOW_MAG_FRACTION = 0.25
local SLOTS = UpgradeDefinitions.SLOTS
local SLOT_NAMES: { [string]: string } = {
	Dash = "Dash",
	Breach = "Breach",
	Rifle = "Rifle",
	Kit = "Kit",
	CallInA = "Call-in 1",
	CallInB = "Call-in 2",
}

local ammoLabel: TextLabel = nil :: any
local reloadBar: Frame = nil :: any
local reloadFill: Frame = nil :: any
local reloadConnection: RBXScriptConnection? = nil
local knownUpgrades: { [string]: string } = {}

local function createAmmoCounter(gui: ScreenGui)
	local root = Instance.new("Frame")
	root.Name = "Ammo"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0.5, 40, 0.5, 40)
	root.Size = UDim2.fromOffset(160, 34)
	root.Parent = gui

	local tick = HudTheme.rect(root, UDim2.fromOffset(1, 22), C.White, 0.2)
	tick.Position = UDim2.fromOffset(0, 4)

	ammoLabel = HudTheme.label(root, { font = HudTheme.Font.Headline, size = 26, rich = true })
	ammoLabel.Position = UDim2.fromOffset(8, 0)

	reloadBar = HudTheme.rect(root, UDim2.fromOffset(100, 3), C.Track, HudTheme.TrackTransparency)
	reloadBar.Position = UDim2.fromOffset(8, 30)
	reloadBar.Visible = false
	reloadFill = HudTheme.rect(reloadBar, UDim2.fromScale(0, 1), C.Yellow)
end

local function updateAmmo()
	local player = Players.LocalPlayer
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local mag = (player:GetAttribute(Attributes.Mag) :: number?) or 0
	local reserve = (player:GetAttribute(Attributes.Reserve) :: number?) or 0
	local reloadUntil = (player:GetAttribute(Attributes.ReloadUntil) :: number?) or 0
	local now = workspace:GetServerTimeNow()
	if reloadUntil > now then
		ammoLabel.Text = `<font size="14">RELOADING</font>`
		ammoLabel.TextColor3 = C.Yellow
		reloadBar.Visible = true
		reloadFill.Size =
			UDim2.fromScale(1 - math.clamp((reloadUntil - now) / weapon.ReloadTime, 0, 1), 1)
		if not reloadConnection then
			-- Tick every frame only while the reload runs.
			reloadConnection = RunService.Heartbeat:Connect(updateAmmo)
		end
		return
	end
	if reloadConnection then
		reloadConnection:Disconnect()
		reloadConnection = nil
	end
	reloadBar.Visible = false
	local dim = HudTheme.hex(C.TextDim)
	local reserveText = `<font size="16" color="{dim}" face="Gotham"> / {reserve}</font>`
	if mag <= 0 then
		ammoLabel.Text = (if reserve > 0 then "DRY [R]" else "DRY") .. reserveText
		ammoLabel.TextColor3 = C.RedLight
	else
		ammoLabel.Text = `{mag}{reserveText}`
		ammoLabel.TextColor3 = if mag <= weapon.MagazineSize * LOW_MAG_FRACTION
			then C.Yellow
			else C.Text
	end
end

-- A new upgrade in a slot: one card with its lore name.
local function checkUpgrades(announce: boolean)
	local player = Players.LocalPlayer
	for _, slot in SLOTS do
		local id = player:GetAttribute(Attributes.upgrade(slot))
		local current = if typeof(id) == "string" then id else ""
		if current ~= (knownUpgrades[slot] or "") then
			knownUpgrades[slot] = current
			local definition = UpgradeDefinitions.get(current)
			if announce and definition then
				BuffNoticeUI.card(definition.Name, `{SLOT_NAMES[slot] or slot} upgrade`)
			end
		end
	end
end

function LoadoutUI.init()
	local gui = HudTheme.gui("LoadoutUI")
	createAmmoCounter(gui)
	HudTheme.parent(gui)

	local player = Players.LocalPlayer
	for _, name in { Attributes.Mag, Attributes.Reserve, Attributes.ReloadUntil, Attributes.Weapon } do
		player:GetAttributeChangedSignal(name):Connect(updateAmmo)
	end
	updateAmmo()
	checkUpgrades(false)
	for _, slot in SLOTS do
		player:GetAttributeChangedSignal(Attributes.upgrade(slot)):Connect(function()
			checkUpgrades(true)
		end)
	end
end

return LoadoutUI
