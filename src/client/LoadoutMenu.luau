--!strict
-- The Loadout menu (docs/PROGRESSION.md > Loadout; titled "Arms Room" in the match): UI only,
-- hosted by the match (LoadoutUI) and the lobby's Loadmaster (LoadmasterUI, via `options`).
-- `mount(parent, onConfirm)` builds the screen in the menu style (HudTheme: near-black red
-- field, "//" header, cream selection; layout in docs/STYLES.md section 5 > Loadout screen)
-- inside `parent` and returns a handle. Owner 2026-11-16: bigger, each item with its shape,
-- and the picked item turning in 3D beside its stats. So: lists of rows, each with a small
-- dark shape of the item (Shared.Showcase), and an inspect panel with the item turning slowly
-- in one ViewportFrame and its numbers as segmented bars. The frame, rows and inspect panel
-- are KitView's, shared with the Carrier's desk screens (lobby DeskScreen). A screen
-- smaller than Config.LoadoutScreen.Compact gets tabs and one list instead of three columns.
-- The soldier picks one primary, one sidearm, one grenade and up to Config.CallIns.Slots
-- different call-ins (click or tap to add in slot order, again to take out; hovering or a
-- gamepad's selection inspects); confirm (or Enter / gamepad Y) hands the table to
-- `onConfirm`. Whether the change is allowed is the server's call (LoadoutService.apply); the
-- host shows the answer with `handle.status`. The picks are checked with the same pure rules
-- the server uses (Rules/Loadout) so confirm greys out on a short pick.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local ArmsRoom = require(Shared:WaitForChild("ArmsRoom"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local KeyBindings = require(Rules:WaitForChild("KeyBindings"))
local Loadout = require(Rules:WaitForChild("Loadout"))
local Showcase = require(Shared:WaitForChild("Showcase"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local HudTheme = require(script.Parent.HudTheme)
local KitView = require(script.Parent.KitView)

local LoadoutMenu = {}

local C = HudTheme.Color
local callInKeys = Config.Keys.CallIns
local ACTION_CONFIRM = "LoadoutMenuConfirm"
local ACTION_TAB = "LoadoutMenuTab"

local function keyLabel(key: Enum.KeyCode): string
	return KeyBindings.label(key.Name)
end

-- What a host may change; left out, the match's Arms Room text is used.
export type Options = {
	title: string?, -- the header, after the "//"
	hint: string?,
	confirm: string?, -- the confirm button
	-- A gun the soldier may not carry: returns the badge shown in its place (e.g. its price),
	-- or nil when it may be picked. Locked items cannot be picked and keep confirm greyed.
	locked: ((id: string) -> string?)?,
	-- The Loadmaster's EDIT (GunsmithUI): given, a gun that takes attachments gets an EDIT
	-- button; the host opens its screen with what is fitted and calls `done` with the new
	-- fitting ([slot] = option).
	edit: ((
		gunId: string,
		fitted: { [string]: string },
		done: (fitted: { [string]: string }) -> ()
	) -> ())?,
}

export type Handle = {
	frame: Frame,
	set: (loadout: Loadout.Loadout) -> (),
	status: (text: string, good: boolean?) -> (),
	refresh: () -> (), -- repaint after what `locked` answers has changed
	destroy: () -> (),
}

type Entry = KitView.Entry

function LoadoutMenu.mount(
	parent: Instance,
	onConfirm: (loadout: Loadout.Loadout) -> (),
	options: Options?
): Handle
	local opts: Options = options or {}
	local catalog = ArmsRoom.catalog()
	local pick = Loadout.default(catalog)
	pick.attachments = {}

	-- Every gun's, grenade's and call-in's numbers, for the bars' "against the rest".
	local allGunIds = table.clone(catalog.primaries)
	for _, id in catalog.secondaries do
		table.insert(allGunIds, id)
	end
	local roster = KitView.roster(allGunIds, catalog.grenades, catalog.callIns)

	-- --------------------------------------------------------------- size and layout
	local hintText = opts.hint
		or `[{keyLabel(Config.Keys.Loadout)}] CLOSE   ·   CHANGES AT INSERT, READY-UP, OR AT THE LANDING ZONE WHEN CALM`
	if UserInputService.GamepadEnabled then
		hintText ..= "   ·   [A] PICK   [Y] CONFIRM   [B] BACK"
	end
	local screen = KitView.screen(parent, opts.title or "ARMS ROOM", hintText)
	local frame, L, W, H = screen.frame, screen.L, screen.W, screen.H
	local connections = screen.connections

	-- --------------------------------------------------------------- the inspect panel
	local inspectX = if L.compact
		then L.pad + L.column + 16
		else L.pad + 3 * L.column + 2 * L.gap + 24
	local inspectY = if L.compact then 52 else L.bodyTop
	local inspectPanel = KitView.inspect(
		frame,
		L,
		Vector2.new(inspectX, inspectY),
		Vector2.new(W - L.pad - inspectX, H - L.footer - inspectY)
	)

	-- --------------------------------------------------------------- footer
	local summaryTitle =
		HudTheme.label(frame, { text = "YOUR LOADOUT", size = 13, color = C.TextDim })
	summaryTitle.Position = UDim2.fromOffset(L.pad, H - L.footer + 22)
	local summary = HudTheme.label(frame, { size = L.stat, rich = true })
	summary.Position = UDim2.fromOffset(L.pad, H - L.footer + 42)
	summaryTitle.Visible = not L.compact
	summary.Visible = not L.compact

	local statusLabel = HudTheme.label(frame, {
		text = "",
		size = L.stat - 1,
		color = C.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	statusLabel.AnchorPoint = Vector2.new(1, 0.5)
	if L.compact then
		statusLabel.Position = UDim2.new(1, -(L.pad + L.confirm.X + 16), 1, -(L.footer / 2))
	else
		statusLabel.AnchorPoint = Vector2.new(1, 1)
		statusLabel.Position = UDim2.new(1, -L.pad, 1, -(20 + L.confirm.Y + 8))
	end

	local deploy = KitView.confirmButton(screen, opts.confirm or "DEPLOY LOADOUT")

	-- --------------------------------------------------------------- state
	local painters: { () -> () } = {}
	local inspected: Entry? = nil
	local rowsById: { [string]: TextButton } = {}
	local shapes: { [string]: () -> () } = {} -- refills a row's shape when its model arrives

	local function isLocked(id: string): string?
		local locked = opts.locked
		return if locked then locked(id) else nil
	end

	local function isPicked(entry: Entry): (boolean, number?)
		if entry.kind == "callIn" then
			local slot = table.find(pick.callIns, entry.id)
			return slot ~= nil, slot
		end
		return pick.primary == entry.id or pick.secondary == entry.id or pick.grenade == entry.id,
			nil
	end

	local function paintInspect()
		local entry = inspected
		if not entry then
			return
		end
		local picked, slot = isPicked(entry)
		local lock = isLocked(entry.id)
		local where = entry.section
		if picked then
			local key = slot and callInKeys[slot]
			where ..= if key
				then `  ·  {HudTheme.tint(`ON KEY {keyLabel(key)}`, C.Yellow)}`
				else `  ·  {HudTheme.tint("IN YOUR LOADOUT", C.Yellow)}`
		end
		inspectPanel.kicker.Text = where
		inspectPanel.name.Text = entry.title
		inspectPanel.sub.Text = entry.subtitle
		local itemStatus = inspectPanel.status
		if lock then
			itemStatus.Text =
				`{HudTheme.tint("NOT ON YOUR RECORD", C.RedLight)}  {HudTheme.tint(lock, C.Yellow)}`
		elseif opts.locked then
			itemStatus.Text = HudTheme.tint("ON YOUR RECORD", C.Yellow)
		else
			itemStatus.Text = ""
		end
		itemStatus.Visible = itemStatus.Text ~= ""
		inspectPanel.line.Text = entry.description
		local fitted = pick.attachments and pick.attachments[entry.id]
		inspectPanel.stats(KitView.statRows(entry, roster, fitted and fitted.Barrel))
	end

	local function setInspected(entry: Entry)
		inspected = entry
		inspectPanel.show(entry)
		for _, paint in painters do
			paint()
		end
		paintInspect()
	end

	local function repaint()
		for _, paint in painters do
			paint()
		end
		paintInspect()
		local ok = Loadout.validate(pick, catalog)
			and not isLocked(pick.primary)
			and not isLocked(pick.secondary)
			and not isLocked(pick.grenade)
		for _, id in pick.callIns do
			ok = ok and not isLocked(id)
		end
		deploy.Active = ok
		deploy.BackgroundTransparency = if ok then 0 else 0.5
		-- The footer's one line: what the soldier is taking.
		local parts = {
			string.upper(WeaponDefinitions.get(pick.primary).Name),
			string.upper(WeaponDefinitions.get(pick.secondary).Name),
			string.upper(WeaponDefinitions.grenade(pick.grenade).Name),
		}
		for slot, id in pick.callIns do
			local row = CallInDefinitions.get(id)
			local key = callInKeys[slot]
			table.insert(
				parts,
				`{if key then HudTheme.tint(keyLabel(key), C.Yellow) .. " " else ""}{string.upper(
					if row then row.Name else id
				)}`
			)
		end
		summary.Text = table.concat(parts, "   ·   ")
	end

	-- The selection box a gamepad shows on a row (cream, as Prototype 2's highlight).
	local selector = KitView.selector()

	-- --------------------------------------------------------------- lists
	local function addItem(section: Frame, index: number, entry: Entry, onPick: () -> ())
		local row = KitView.row(section, index, entry, L, selector)
		local item = row.item
		rowsById[entry.id] = item
		local refill = row.refill
		if refill then
			shapes[entry.id] = refill
		end

		-- EDIT: what is fitted to this gun (the Loadmaster only).
		local editGun = opts.edit
		local offers = catalog.attachments and catalog.attachments[entry.id]
		if entry.kind == "gun" and editGun and offers then
			local editButton = Instance.new("TextButton")
			editButton.Name = "Edit"
			editButton.AutoButtonColor = false
			editButton.AnchorPoint = Vector2.new(1, 1)
			editButton.Position = UDim2.new(1, -8, 1, -8)
			editButton.Size =
				UDim2.fromOffset(if L.compact then 64 else 52, if L.compact then 30 else 22)
			editButton.BackgroundColor3 = C.Red
			editButton.BorderSizePixel = 0
			editButton.Font = HudTheme.Font.Line
			editButton.TextSize = L.sub - 1
			editButton.TextColor3 = C.Text
			editButton.Text = "EDIT"
			editButton.SelectionImageObject = selector
			editButton.Parent = item
			editButton.Activated:Connect(function()
				local attachments = pick.attachments or {}
				pick.attachments = attachments
				editGun(entry.id, table.clone(attachments[entry.id] or {}), function(fitted)
					attachments[entry.id] = if next(fitted) then fitted else nil
					repaint()
				end)
			end)
		end

		item.MouseEnter:Connect(function()
			setInspected(entry)
		end)
		item.SelectionGained:Connect(function()
			setInspected(entry)
		end)
		item.Activated:Connect(function()
			if not isLocked(entry.id) then
				onPick()
			end
			setInspected(entry)
			repaint()
		end)

		table.insert(painters, function()
			local selected, slot = isPicked(entry)
			local lock = isLocked(entry.id)
			local badge, badgeColor, sub = "", C.Yellow, entry.subtitle
			if lock then
				badge = lock
			else
				local key = slot and callInKeys[slot]
				badge = if key then `[{keyLabel(key)}]` else ""
				badgeColor = if selected then C.MenuSelectText else C.Yellow
				-- "+SUP" for each attachment fitted to this gun.
				local fitted: { [string]: string } = pick.attachments and pick.attachments[entry.id]
					or {}
				for _, option in fitted do
					local attachment = Config.Attachments.Options[option]
					sub ..= if attachment
						then ` +{string.upper(string.sub(attachment.Name, 1, 3))}`
						else ""
				end
			end
			row.paint({
				selected = selected,
				focus = inspected ~= nil and inspected.id == entry.id,
				dim = lock ~= nil,
				badge = badge,
				badgeColor = badgeColor,
				sub = sub,
			})
		end)
	end

	local bodyH = H - L.footer - L.bodyTop
	local holders: { ScrollingFrame } = {}
	if L.compact then
		table.insert(
			holders,
			KitView.scroller(frame, Vector2.new(L.pad, L.bodyTop), Vector2.new(L.column, bodyH), 6)
		)
	else
		for index = 1, 3 do
			table.insert(
				holders,
				KitView.scroller(
					frame,
					Vector2.new(L.pad + (index - 1) * (L.column + L.gap), L.bodyTop),
					Vector2.new(L.column + 8, bodyH),
					4
				)
			)
		end
	end
	for _, holder in holders do
		KitView.list(holder, 18)
	end
	local function holder(index: number): ScrollingFrame
		return holders[math.min(index, #holders)]
	end

	local callInHeader = `CALL-INS  (KEYS {keyLabel(callInKeys[1])}-{keyLabel(
		callInKeys[catalog.slots] or callInKeys[#callInKeys]
	)})`
	local showHeaders = not L.compact
	local primaries = KitView.section(holder(1), 1, "PRIMARY", showHeaders)
	local sidearms = KitView.section(holder(2), 2, "SIDEARM", showHeaders)
	local grenades = KitView.section(holder(2), 3, "GRENADE", showHeaders)
	local callIns = KitView.section(holder(3), 4, callInHeader, showHeaders)
	local sections = { primaries, sidearms, grenades, callIns }

	local entries: { [string]: Entry } = {}
	for index, id in catalog.primaries do
		local entry = KitView.weaponEntry(id, "PRIMARY")
		entries[id] = entry
		addItem(primaries, index, entry, function()
			pick.primary = id
		end)
	end
	for index, id in catalog.secondaries do
		local entry = KitView.weaponEntry(id, "SIDEARM")
		entries[id] = entry
		addItem(sidearms, index, entry, function()
			pick.secondary = id
		end)
	end
	for index, id in catalog.grenades do
		local entry = KitView.grenadeEntry(id)
		entries[id] = entry
		addItem(grenades, index, entry, function()
			pick.grenade = id
		end)
	end
	for index, id in catalog.callIns do
		local entry = KitView.callInEntry(id)
		entries[id] = entry
		addItem(callIns, index, entry, function()
			local slot = table.find(pick.callIns, id)
			if slot then
				table.remove(pick.callIns, slot)
			elseif #pick.callIns < catalog.slots then
				table.insert(pick.callIns, id)
			end
		end)
	end

	-- Compact: one list at a time behind four tabs (gamepad shoulders step through them).
	local tab = 1
	local tabButtons: { TextButton } = {}
	local function showTab(index: number)
		tab = index
		for i, sectionFrame in sections do
			sectionFrame.Visible = i == index
		end
		holders[1].CanvasPosition = Vector2.zero
		for i, button in tabButtons do
			local on = i == index
			button.BackgroundColor3 = if on then C.MenuSelect else C.Track
			button.BackgroundTransparency = if on then 0 else 0.35
			button.TextColor3 = if on then C.MenuSelectText else C.Text
		end
	end
	if L.compact then
		local labels = { "PRIMARY", "SIDEARM", "GRENADE", "CALL-INS" }
		local width = math.floor((L.column - 3 * 6) / 4)
		for index, text in labels do
			local button = Instance.new("TextButton")
			button.AutoButtonColor = false
			button.BorderSizePixel = 0
			button.Position = UDim2.fromOffset(L.pad + (index - 1) * (width + 6), 52)
			button.Size = UDim2.fromOffset(width, 50)
			button.Font = HudTheme.Font.Line
			button.TextSize = 15
			button.Text = text
			button.SelectionImageObject = selector
			button.Parent = frame
			button.Activated:Connect(function()
				showTab(index)
			end)
			table.insert(tabButtons, button)
		end
		showTab(1)
		ContextActionService:BindAction(ACTION_TAB, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				local step = if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
				showTab((tab - 1 + step) % #sections + 1)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	end

	-- --------------------------------------------------------------- confirm
	local function confirm()
		if deploy.Active then
			onConfirm(Loadout.copy(pick))
		end
	end
	deploy.Activated:Connect(confirm)
	ContextActionService:BindAction(ACTION_CONFIRM, function(_, state)
		if state == Enum.UserInputState.Begin and not parent:FindFirstChild("Gunsmith") then
			confirm()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonY)

	-- The inspected model turns while the screen shows (not under the EDIT screen, which has
	-- its own turning gun); the one ViewportFrame redraws only then.
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			if not frame.Visible or parent:FindFirstChild("Gunsmith") then
				return
			end
			inspectPanel.turn(dt)
		end)
	)
	-- Models that load after the screen opened replace their stand-ins.
	local arrived = Showcase.onArrived(function(id)
		local refill = shapes[id]
		if refill then
			refill()
		end
		inspectPanel.reshow(id)
	end)
	if arrived then
		table.insert(connections, arrived)
	end

	repaint()
	setInspected(entries[pick.primary] or KitView.weaponEntry(pick.primary, "PRIMARY"))
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = rowsById[pick.primary]
	end

	local handle: Handle = {
		frame = frame,
		set = function(loadout: Loadout.Loadout)
			pick = Loadout.copy(loadout)
			pick.attachments = pick.attachments or {}
			repaint()
			local entry = entries[pick.primary]
			if entry then
				setInspected(entry)
				if UserInputService.GamepadEnabled then
					GuiService.SelectedObject = rowsById[pick.primary]
				end
			end
		end,
		refresh = repaint,
		status = function(text: string, good: boolean?)
			statusLabel.Text = text
			statusLabel.TextColor3 = if good == true
				then C.Yellow
				elseif good == false then C.RedLight
				else C.TextDim
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			ContextActionService:UnbindAction(ACTION_CONFIRM)
			ContextActionService:UnbindAction(ACTION_TAB)
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(frame) then
				GuiService.SelectedObject = nil
			end
			selector:Destroy()
			frame:Destroy()
		end,
	}
	return handle
end

return LoadoutMenu
