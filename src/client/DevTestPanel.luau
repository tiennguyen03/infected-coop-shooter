--!strict
-- Dev tools v3: Studio / creator only. F1 opens a tabbed panel (the cursor is freed while it
-- is open): one tab per thing you are testing, so nothing needs scrolling past. Lists that
-- used to be loose buttons are rows: a call-in with its slot and FIRE buttons, an Infected
-- form with its counts. Toggles (god mode, spawning, pause) light up while on, and a line
-- under the title repeats the last command sent. A strip at the bottom of the screen shows
-- FPS, run state, Infected alive and the squad. Hotkeys work with the panel closed.
-- Every button fires DevCommand (DevTestService), so the engineer can drive the same
-- commands from scripts: `Remotes.DevCommand:FireServer("God")` etc.
-- Teleports run here (the client owns its character's physics).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CallInDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CallInDefinitions"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local UpgradeDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local CameraController = require(script.Parent.CameraController)

local CREATOR_USER_ID = 67169996
local TOGGLE_KEY = Enum.KeyCode.F1

local DevTestPanel = {}

-- A button. `send` is a DevCommand payload, `run` a local action; `on` makes it a toggle that
-- lights up while it returns true; `echo` is what the last-command line says (default: label).
type Action = {
	label: string,
	send: { any }?,
	run: (() -> ())?,
	hotkey: Enum.KeyCode?,
	on: (() -> boolean)?,
	echo: string?,
}
-- A name with a few small buttons beside it ("Walker  1  5  10  25").
type Row = { label: string, buttons: { Action } }
type Group = { title: string, actions: { Action }?, rows: { Row }? }
type Tab = { title: string, groups: { Group } }

-- Named spots on Checkpoint Delta (x, z); the ground height is found by raycast.
local TELEPORTS: { { label: string, x: number, z: number } } = {
	{ label = "LZ", x = -90, z = -90 },
	{ label = "Apron", x = 0, z = 0 },
	{ label = "Compound", x = 50, z = 50 },
	{ label = "Ridge", x = -100, z = 30 },
	{ label = "Pens", x = -240, z = 120 },
	{ label = "Depot", x = 200, z = 32 },
	{ label = "Overlook", x = 105, z = -105 },
	{ label = "Gate", x = -30, z = -255 },
}
-- The Infected forms the spawn rows offer, and the counts on each row.
local SPAWN_FORMS = { "Walker", "Runner", "Brute", "Hocker" }
local SPAWN_COUNTS = { 1, 5, 10, 25 }
local BOT_COUNTS = { 0, 1, 2, 3 }

local PANEL_WIDTH = 400
local TAB_COLUMNS = 4
local TAB_HEIGHT = 26
local COLOR = {
	Panel = Color3.fromRGB(16, 19, 20),
	Button = Color3.fromRGB(38, 44, 46),
	ButtonOn = Color3.fromRGB(64, 122, 88),
	Tab = Color3.fromRGB(28, 33, 35),
	TabOn = Color3.fromRGB(215, 160, 80),
	Text = Color3.fromRGB(228, 230, 226),
	TextDim = Color3.fromRGB(170, 174, 170),
	TextOnTab = Color3.fromRGB(20, 22, 22),
	Accent = Color3.fromRGB(150, 235, 180),
	Header = Color3.fromRGB(215, 160, 80),
}

local remote: RemoteEvent
local panel: Frame? = nil
local infoLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local lastLabel: TextLabel? = nil
local toggles: { { button: TextButton, on: () -> boolean } } = {}
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}

-- A DevCommand payload: the command name and its arguments.
local function cmd(...: any): { any }
	return { ... }
end

local function teleport(x: number, z: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	local y = if hit then hit.Position.Y + 3.5 else 10
	character:PivotTo(CFrame.new(x, y, z))
	root.AssemblyLinearVelocity = Vector3.zero
end

local function fire(action: Action)
	if action.run then
		action.run()
	elseif action.send then
		remote:FireServer(table.unpack(action.send))
	end
	if lastLabel then
		lastLabel.Text = `> {action.echo or action.label}`
	end
end

-- A list of buttons of mixed shapes (some with a hotkey, some toggles), typed as one list.
local function acts(...: Action): { Action }
	return { ... }
end

local function tabs(): { Tab }
	local player = Players.LocalPlayer

	-- CALL-INS: one row per call-in: put it in a slot, or fire it with no slot or charge.
	local callInRows: { Row } = {}
	for _, id in CallInDefinitions.Order do
		local definition = CallInDefinitions.get(id) :: CallInDefinitions.CallInDefinition
		local buttons: { Action } = {}
		for slot = 1, Config.CallIns.Slots do
			table.insert(buttons, {
				label = tostring(slot),
				send = cmd("SetCallIn", slot, id),
				echo = `{definition.Name} in slot {slot}`,
			})
		end
		table.insert(
			buttons,
			{ label = "FIRE", send = cmd("FireCallIn", id), echo = `Fire {definition.Name}` }
		)
		table.insert(callInRows, { label = definition.Name, buttons = buttons })
	end

	-- GUNS: every gun row, by slot.
	local primaries: { Action } = {}
	local sidearms: { Action } = {}
	for _, id in WeaponDefinitions.allIds() do
		local definition = WeaponDefinitions.get(id)
		table.insert(if definition.Slot == "secondary" then sidearms else primaries, {
			label = `{definition.Name} ({definition.Designation})`,
			send = cmd("SetWeapon", id),
		})
	end

	-- UPGRADES: every field upgrade, by the slot it sits in.
	local upgradeGroups: { Group } = {
		{
			title = "ALL",
			actions = {
				{ label = "Clear upgrades", send = cmd("ClearUpgrades") },
				{ label = "Drop upgrade crate", send = cmd("DropUpgradeCrate") },
			},
		},
	}
	local bySlot: { [string]: { Action } } = {}
	local slotOrder: { string } = {}
	for _, id in UpgradeDefinitions.upgradeIds() do
		local definition = UpgradeDefinitions.get(id) :: UpgradeDefinitions.CardDefinition
		local slot = string.upper(definition.Slot or "other")
		if not bySlot[slot] then
			bySlot[slot] = {}
			table.insert(slotOrder, slot)
		end
		table.insert(bySlot[slot], { label = definition.Name, send = cmd("GiveUpgrade", id) })
	end
	table.sort(slotOrder)
	for _, slot in slotOrder do
		table.insert(upgradeGroups, { title = slot, actions = bySlot[slot] })
	end

	local spawnRows: { Row } = {}
	for _, form in SPAWN_FORMS do
		local buttons: { Action } = {}
		for _, count in SPAWN_COUNTS do
			table.insert(buttons, {
				label = tostring(count),
				send = cmd("SpawnEnemy", form, count),
				echo = `Spawn {count} {form}`,
				hotkey = if form == "Walker" and count == 10 then Enum.KeyCode.F4 else nil,
			})
		end
		table.insert(spawnRows, { label = form, buttons = buttons })
	end

	local botButtons: { Action } = {}
	for _, count in BOT_COUNTS do
		table.insert(
			botButtons,
			{ label = tostring(count), send = cmd("SetBots", count), echo = `Bots: {count}` }
		)
	end

	local teleports: { Action } = {}
	for _, spot in TELEPORTS do
		table.insert(teleports, {
			label = spot.label,
			echo = `Teleport: {spot.label}`,
			run = function()
				teleport(spot.x, spot.z)
			end,
		})
	end

	return {
		{
			title = "RUN",
			groups = {
				{
					title = "THE MISSION, IN ORDER",
					actions = acts(
						{
							label = "Restart run",
							send = cmd("RestartRun"),
							hotkey = Enum.KeyCode.F5,
						},
						{ label = "Hold zone now", send = cmd("ActivateObjective") },
						{ label = "Complete hold", send = cmd("ForceObjectiveComplete") },
						{ label = "Warden (from the Gate)", send = cmd("SpawnWarden") },
						{ label = "Kill the Warden", send = cmd("KillWarden") },
						{ label = "Extract (win)", send = cmd("ForceMissionSuccess") },
						{ label = "Wipe (lose)", send = cmd("ForceWipe") }
					),
				},
				{
					title = "THE FIELD",
					actions = acts(
						{
							label = "Pause",
							send = cmd("TogglePause"),
							on = function()
								return workspace:GetAttribute(Attributes.GamePaused) == true
							end,
						},
						{
							label = "Fill Resupply",
							send = cmd("FillResupply"),
							hotkey = Enum.KeyCode.F6,
						},
						{ label = "Drop supply crate", send = cmd("DropSupplyCrate") },
						{ label = "Drop upgrade crate", send = cmd("DropUpgradeCrate") }
					),
				},
				{
					title = "CHECKS (answers in the Output)",
					actions = acts(
						{ label = "Print state", send = cmd("PrintRunState") },
						{ label = "Verify cleanup", send = cmd("VerifyCleanup") },
						{ label = "Go to the lobby (live)", send = cmd("ToLobby") }
					),
				},
			},
		},
		{
			title = "PLAYER",
			groups = {
				{
					title = "ME",
					actions = acts(
						{
							label = "God mode",
							send = cmd("God"),
							hotkey = Enum.KeyCode.F2,
							on = function()
								return player:GetAttribute(Attributes.DevGod) == true
							end,
						},
						{ label = "Heal / revive", send = cmd("Heal") },
						{
							label = "Refill ammo",
							send = cmd("RefillAmmo"),
							hotkey = Enum.KeyCode.F8,
						},
						{ label = "Restock call-ins", send = cmd("RestockCallIns") },
						{ label = "Down me", send = cmd("DownPlayer") },
						{ label = "Kill me", send = cmd("KillPlayer") }
					),
				},
				{
					title = "BOTS",
					rows = { { label = "How many", buttons = botButtons } },
					actions = acts(
						{ label = "Down a bot", send = cmd("DownBot") },
						{ label = "Kill bots", send = cmd("KillBots") }
					),
				},
			},
		},
		{
			title = "INFECTED",
			groups = {
				{
					title = "ALL",
					actions = acts({
						label = "Spawning stopped",
						send = cmd("ToggleSpawns"),
						hotkey = Enum.KeyCode.F7,
						on = function()
							return workspace:GetAttribute(Attributes.DevSpawnsOff) == true
						end,
					}, {
						label = "Clear all",
						send = cmd("ClearEnemies"),
						hotkey = Enum.KeyCode.F3,
					}),
				},
				{ title = "SPAWN AROUND THE SQUAD", rows = spawnRows },
				{
					title = "THE WARDEN",
					actions = acts({
						label = "From the Gate",
						send = cmd("SpawnWarden"),
						echo = "Warden (Gate)",
					}, {
						label = "In front of me",
						send = cmd("WardenHere"),
						hotkey = Enum.KeyCode.F9,
						echo = "Warden here",
					}, {
						label = "Kill him",
						send = cmd("KillWarden"),
						echo = "Kill the Warden",
					}),
				},
			},
		},
		{
			title = "GUNS",
			groups = {
				{ title = "LONG GUNS", actions = primaries },
				{ title = "SIDEARMS", actions = sidearms },
				{
					title = "AMMO",
					actions = acts({ label = "Refill ammo", send = cmd("RefillAmmo") }),
				},
			},
		},
		{
			title = "CALL-INS",
			groups = {
				{
					title = `1-{Config.CallIns.Slots} PUTS IT ON THAT KEY  ·  FIRE DROPS IT AHEAD`,
					rows = callInRows,
				},
				{
					title = "ALL",
					actions = acts({ label = "Restock call-ins", send = cmd("RestockCallIns") }),
				},
			},
		},
		{ title = "UPGRADES", groups = upgradeGroups },
		{ title = "TELEPORT", groups = { { title = "CHECKPOINT DELTA", actions = teleports } } },
	}
end

local function style(button: TextButton, radius: number)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = COLOR.Text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = button
end

local function makeButton(parent: Instance, action: Action): TextButton
	local button = Instance.new("TextButton")
	style(button, 4)
	button.BackgroundColor3 = COLOR.Button
	button.TextSize = 13
	button.Text = if action.hotkey then `{action.label}  [{action.hotkey.Name}]` else action.label
	button.TextWrapped = true
	button.Activated:Connect(function()
		fire(action)
	end)
	local on = action.on
	if on then
		table.insert(toggles, { button = button, on = on })
	end
	button.Parent = parent
	return button
end

local function makeRow(parent: Instance, row: Row, order: number)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 28)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(0.34, 1)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextColor3 = COLOR.Text
	name.Text = row.label
	name.Parent = frame
	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromScale(0.34, 0)
	buttons.Size = UDim2.fromScale(0.66, 1)
	buttons.BackgroundTransparency = 1
	buttons.Parent = frame
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / #row.buttons, -4, 1, 0)
	layout.CellPadding = UDim2.fromOffset(4, 0)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons
	for index, action in row.buttons do
		local button = makeButton(buttons, action)
		button.LayoutOrder = index
		-- Row buttons are narrow: the hotkey would not fit, so it goes beside the name.
		button.Text = action.label
		if action.hotkey then
			name.Text = `{row.label} [{action.hotkey.Name}={action.label}]`
		end
	end
end

local function makePage(parent: Instance, tab: Tab, top: number): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = tab.title
	page.Position = UDim2.fromOffset(0, top)
	page.Size = UDim2.new(1, 0, 1, -top)
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 4
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Visible = false
	page.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = page

	local order = 0
	for _, group in tab.groups do
		order += 1
		local header = Instance.new("TextLabel")
		header.LayoutOrder = order
		header.Size = UDim2.new(1, 0, 0, 18)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBold
		header.TextSize = 11
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextYAlignment = Enum.TextYAlignment.Bottom
		header.TextColor3 = COLOR.Header
		header.Text = group.title
		header.Parent = page
		local rows: { Row } = group.rows or {}
		for _, row in rows do
			order += 1
			makeRow(page, row, order)
		end
		local actions = group.actions
		if actions and #actions > 0 then
			order += 1
			local grid = Instance.new("Frame")
			grid.LayoutOrder = order
			grid.Size = UDim2.fromScale(1, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.BackgroundTransparency = 1
			grid.Parent = page
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.new(0.5, -4, 0, 30)
			layout.CellPadding = UDim2.fromOffset(8, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = grid
			for index, action in actions do
				makeButton(grid, action).LayoutOrder = index
			end
		end
	end
	return page
end

local function showTab(title: string)
	for name, page in pages do
		page.Visible = name == title
	end
	for name, button in tabButtons do
		local selected = name == title
		button.BackgroundColor3 = if selected then COLOR.TabOn else COLOR.Tab
		button.TextColor3 = if selected then COLOR.TextOnTab else COLOR.TextDim
	end
end

local function line(parent: Instance, y: number, height: number, size: number, color: Color3)
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(0, y)
	text.Size = UDim2.new(1, 0, 0, height)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextSize = size
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextColor3 = color
	text.Parent = parent
	return text
end

local function buildPanel(all: { Tab })
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevTestPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Always-visible strip: the toggle hint and the live info line.
	local strip = Instance.new("TextLabel")
	strip.Name = "Info"
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.new(0, 8, 1, -8)
	strip.Size = UDim2.fromOffset(520, 18)
	strip.BackgroundTransparency = 1
	strip.Font = Enum.Font.Code
	strip.TextSize = 13
	strip.TextXAlignment = Enum.TextXAlignment.Left
	strip.TextColor3 = COLOR.Accent
	strip.TextStrokeTransparency = 0.5
	strip.Parent = gui
	infoLabel = strip

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -12, 0.5, 0)
	frame.Size = UDim2.new(0, PANEL_WIDTH, 0.86, 0)
	frame.BackgroundColor3 = COLOR.Panel
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 10)
	end
	pad.Parent = frame

	local title = line(frame, 0, 20, 16, COLOR.Accent)
	title.Font = Enum.Font.GothamBold
	title.Text = `DEV TOOLS  ·  {TOGGLE_KEY.Name} to close`
	statusLabel = line(frame, 22, 14, 12, COLOR.TextDim)
	local last = line(frame, 38, 14, 12, COLOR.Accent)
	last.Text = "> -"
	lastLabel = last

	-- The tab bar: every tab visible at once, the open one lit.
	local tabRows = math.ceil(#all / TAB_COLUMNS)
	local barTop = 58
	local barHeight = tabRows * TAB_HEIGHT + (tabRows - 1) * 4
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(0, barTop)
	bar.Size = UDim2.new(1, 0, 0, barHeight)
	bar.BackgroundTransparency = 1
	bar.Parent = frame
	local barLayout = Instance.new("UIGridLayout")
	barLayout.CellSize = UDim2.new(1 / TAB_COLUMNS, -3, 0, TAB_HEIGHT)
	barLayout.CellPadding = UDim2.fromOffset(4, 4)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar

	local pageTop = barTop + barHeight + 8
	for index, tab in all do
		local button = Instance.new("TextButton")
		style(button, 4)
		button.LayoutOrder = index
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.Text = tab.title
		button.Activated:Connect(function()
			showTab(tab.title)
		end)
		button.Parent = bar
		tabButtons[tab.title] = button
		pages[tab.title] = makePage(frame, tab, pageTop)
	end
	showTab(all[1].title)

	panel = frame
end

local function setOpen(open: boolean)
	local frame = panel
	if not frame then
		return
	end
	frame.Visible = open
	CameraController.setCursorFree("DevTestPanel", open)
end

-- FPS, run state, Infected alive and squad states, refreshed a few times a second; the
-- toggles take their lit or unlit colour here too.
local frames, elapsed = 0, 0
local function updateInfo(dt: number)
	frames += 1
	elapsed += dt
	if elapsed < 0.4 then
		return
	end
	local fps = frames / elapsed
	frames, elapsed = 0, 0
	local player = Players.LocalPlayer
	local character = player.Character
	local squadState = (character and character:GetAttribute(Attributes.SquadState)) or "-"
	local runState = tostring(workspace:GetAttribute(Attributes.RunState) or "?")
	local infected = #CollectionService:GetTagged("Enemy")
	local flags = (if player:GetAttribute(Attributes.DevGod) == true then "  ·  GOD" else "")
		.. (if workspace:GetAttribute(Attributes.DevSpawnsOff) == true
			then "  ·  SPAWNS OFF"
			else "")
		.. (if workspace:GetAttribute(Attributes.GamePaused) == true then "  ·  PAUSED" else "")
	if infoLabel then
		infoLabel.Text = string.format(
			"%.0f fps  ·  %s  ·  %d Infected  ·  me %s%s   [%s dev tools]",
			fps,
			runState,
			infected,
			tostring(squadState),
			flags,
			TOGGLE_KEY.Name
		)
	end
	if statusLabel then
		local bots = workspace:FindFirstChild("SquadBots")
		statusLabel.Text = string.format(
			"%s  ·  %d Infected  ·  %d bots%s",
			runState,
			infected,
			if bots then #bots:GetChildren() else 0,
			flags
		)
	end
	local frame = panel
	if frame and frame.Visible then
		for _, toggle in toggles do
			toggle.button.BackgroundColor3 = if toggle.on() then COLOR.ButtonOn else COLOR.Button
		end
	end
end

function DevTestPanel.init()
	if not (RunService:IsStudio() or Players.LocalPlayer.UserId == CREATOR_USER_ID) then
		return
	end
	remote = Remotes.get("DevCommand")
	local all = tabs()
	buildPanel(all)

	local hotkeys: { [Enum.KeyCode]: Action } = {}
	for _, tab in all do
		for _, group in tab.groups do
			local actions: { Action } = group.actions or {}
			for _, action in actions do
				if action.hotkey then
					hotkeys[action.hotkey] = action
				end
			end
			local rows: { Row } = group.rows or {}
			for _, row in rows do
				for _, action in row.buttons do
					if action.hotkey then
						hotkeys[action.hotkey] = action
					end
				end
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			local frame = panel
			setOpen(not (frame and frame.Visible))
			return
		end
		local action = hotkeys[input.KeyCode]
		if action then
			fire(action)
		end
	end)
	RunService.Heartbeat:Connect(updateInfo)
end

return DevTestPanel
