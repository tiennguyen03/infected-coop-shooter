--!strict
-- Loadout HUD (HUD language: HudTheme). Reads the LocalPlayer attributes LoadoutService
-- publishes:
--   * the ammo counter beside the crosshair: the gun's name small above it with "[Q]" (Config.Keys.SwapGun) and
--     the other gun dim, the magazine large, " / reserve" small and dim, a thin white tick
--     at its left; yellow when the magazine is low, "RELOADING" over a thin bar while
--     ReloadUntil is ahead of server time, red "DRY [R]" (Keys.Reload) on empty. It is attribute-driven
--     and only ticks every frame while a reload runs;
--   * a field upgrade landing in a slot shows as a notification card (BuffNoticeUI) with
--     the upgrade's lore name and slot; the ability circle carries the mark (AbilityUI);
--   * the Arms Room host: Keys.Loadout (B) opens and closes the menu (LoadoutMenu, UI only), DEPLOY sends
--     the pick over the Loadout remote and the server's answer shows on the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local KeyBindings = require(Shared:WaitForChild("Rules"):WaitForChild("KeyBindings"))
local Messages = require(Shared:WaitForChild("Messages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UpgradeDefinitions = require(Shared:WaitForChild("UpgradeDefinitions"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local BuffNoticeUI = require(script.Parent.BuffNoticeUI)
local CameraController = require(script.Parent.CameraController)
local HudTheme = require(script.Parent.HudTheme)
local LoadoutMenu = require(script.Parent.LoadoutMenu)

local LoadoutUI = {}

local SWAP_KEY = KeyBindings.label(Config.Keys.SwapGun.Name)
local RELOAD_KEY = KeyBindings.label(Config.Keys.Reload.Name)

local C = HudTheme.Color
local LOW_MAG_FRACTION = 0.25
local SLOTS = UpgradeDefinitions.SLOTS
local SLOT_NAMES: { [string]: string } = {
	Grenade = "Grenade",
	Weapon = "Weapon",
	Kit = "Kit",
}
for slot = 1, Config.CallIns.Slots do
	SLOT_NAMES[UpgradeDefinitions.callInSlot(slot)] = `Call-in {slot}`
end
-- Why the server refused a change (Rules/Loadout reasons), as the menu says it.
local REFUSALS: { [string]: string } = {
	["away from the LZ"] = "GET TO THE LZ TO CHANGE KIT",
	["in contact"] = "IN CONTACT · WAIT FOR A CALM SPELL",
	down = "NOT WHILE DOWN",
}

local ammoLabel: TextLabel = nil :: any
local gunLabel: TextLabel = nil :: any
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

	gunLabel = HudTheme.label(root, { size = 12, rich = true })
	gunLabel.Position = UDim2.fromOffset(8, -14)

	ammoLabel = HudTheme.label(root, { font = HudTheme.Font.Headline, size = 26, rich = true })
	ammoLabel.Position = UDim2.fromOffset(8, 0)

	reloadBar = HudTheme.rect(root, UDim2.fromOffset(100, 3), C.Track, HudTheme.TrackTransparency)
	reloadBar.Position = UDim2.fromOffset(8, 30)
	reloadBar.Visible = false
	reloadFill = HudTheme.rect(reloadBar, UDim2.fromScale(0, 1), C.Yellow)
end

local function updateGun()
	local player = Players.LocalPlayer
	local inHand = player:GetAttribute(Attributes.Weapon) :: string?
	local primary = player:GetAttribute(Attributes.Primary) :: string?
	local secondary = player:GetAttribute(Attributes.Secondary) :: string?
	local other = if inHand == secondary then primary else secondary
	local weapon = WeaponDefinitions.get(inHand)
	local otherText = if other
		then HudTheme.tint(
			`  [{SWAP_KEY}] {string.upper(WeaponDefinitions.get(other).Name)}`,
			C.TextDim
		)
		else ""
	gunLabel.Text = `{string.upper(weapon.Name)}{otherText}`
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
		ammoLabel.Text = (if reserve > 0 then `DRY [{RELOAD_KEY}]` else "DRY") .. reserveText
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

----------------------------------------------------------------------
-- The Arms Room host (key B)
----------------------------------------------------------------------

local menuGui: ScreenGui = nil :: any
local menu: LoadoutMenu.Handle? = nil
local loadoutRemote: RemoteEvent

-- The carried loadout as the server published it (what the menu opens on).
local function currentLoadout()
	local player = Players.LocalPlayer
	local callIns = {}
	for slot = 1, Config.CallIns.Slots do
		local id = player:GetAttribute(Attributes.callIn(slot))
		if typeof(id) == "string" and id ~= "" then
			table.insert(callIns, id)
		end
	end
	return {
		primary = (player:GetAttribute(Attributes.Primary) :: string?) or WeaponDefinitions.DEFAULT,
		secondary = (player:GetAttribute(Attributes.Secondary) :: string?)
			or WeaponDefinitions.DEFAULT_SECONDARY,
		grenade = (player:GetAttribute(Attributes.Grenade) :: string?)
			or WeaponDefinitions.DEFAULT_GRENADE,
		callIns = callIns,
	}
end

local function closeMenu()
	local open = menu
	if open then
		open.destroy()
		menu = nil
		CameraController.setCursorFree("ArmsRoom", false)
	end
end

local function openMenu()
	if menu then
		return
	end
	local handle = LoadoutMenu.mount(menuGui, function(loadout)
		loadoutRemote:FireServer(Messages.Loadout.Request, loadout)
		local open = menu
		if open then
			open.status("REQUESTING...")
		end
	end)
	handle.set(currentLoadout())
	menu = handle
	CameraController.setCursorFree("ArmsRoom", true)
end

function LoadoutUI.init()
	local gui = HudTheme.gui("LoadoutUI")
	createAmmoCounter(gui)
	HudTheme.parent(gui)
	-- Above the results screen (RunEndUI, 100): the menu is open during the ready-up too.
	menuGui = HudTheme.gui("ArmsRoomUI", 110)
	HudTheme.parent(menuGui)

	local player = Players.LocalPlayer
	for _, name in { Attributes.Mag, Attributes.Reserve, Attributes.ReloadUntil, Attributes.Weapon } do
		player:GetAttributeChangedSignal(name):Connect(updateAmmo)
	end
	for _, name in { Attributes.Weapon, Attributes.Primary, Attributes.Secondary } do
		player:GetAttributeChangedSignal(name):Connect(updateGun)
	end
	updateAmmo()
	updateGun()
	checkUpgrades(false)
	for _, slot in SLOTS do
		player:GetAttributeChangedSignal(Attributes.upgrade(slot)):Connect(function()
			checkUpgrades(true)
		end)
	end

	loadoutRemote = Remotes.get("Loadout")
	loadoutRemote.OnClientEvent:Connect(function(kind: unknown, ok: unknown, reason: unknown)
		if kind ~= Messages.Loadout.Result then
			return
		end
		local open = menu
		if ok == true then
			BuffNoticeUI.card("LOADOUT SET", "Arms Room")
			closeMenu()
		elseif open then
			local text = if typeof(reason) == "string"
				then REFUSALS[reason] or string.upper(reason)
				else "REFUSED"
			open.status(text, false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.KeyCode ~= Config.Keys.Loadout then
			return
		end
		if menu then
			closeMenu()
		else
			openMenu()
		end
	end)
	player.CharacterAdded:Connect(closeMenu)
end

return LoadoutUI
