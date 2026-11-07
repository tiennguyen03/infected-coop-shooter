--!strict
-- Dev tools v2 (2026-11-07): Studio / creator only. F1 opens a clickable panel (the cursor
-- is freed while it is open) grouped by what you are testing; a live info line shows FPS,
-- run state, Infected alive and the squad. Hotkeys for the actions used mid-fight work with
-- the panel closed. Every button fires DevCommand (DevTestService), so the engineer can
-- drive the same commands from scripts: `Remotes.DevCommand:FireServer("God")` etc.
-- Teleports run here (the client owns its character's physics).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local CameraController = require(script.Parent.CameraController)

local CREATOR_USER_ID = 67169996
local TOGGLE_KEY = Enum.KeyCode.F1

local DevTestPanel = {}

type Action = { label: string, send: { any }?, run: (() -> ())?, hotkey: Enum.KeyCode? }
type Section = { title: string, actions: { Action } }

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

local remote: RemoteEvent

-- A DevCommand payload: the command name and its arguments.
local function cmd(...: any): { any }
	return { ... }
end
local panel: ScrollingFrame? = nil
local infoLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

local function send(args: { any })
	remote:FireServer(table.unpack(args))
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

local function sections(): { Section }
	local teleports: { Action } = {}
	for _, spot in TELEPORTS do
		table.insert(teleports, {
			label = spot.label,
			run = function()
				teleport(spot.x, spot.z)
			end,
		})
	end
	return {
		{
			title = "PLAYER",
			actions = {
				{ label = "God mode", send = cmd("God"), hotkey = Enum.KeyCode.F2 },
				{ label = "Heal / revive", send = cmd("Heal") },
				{ label = "Down me", send = cmd("DownPlayer") },
				{ label = "Kill me", send = cmd("KillPlayer") },
			},
		},
		{
			title = "RUN",
			actions = {
				{ label = "Restart run", send = cmd("RestartRun"), hotkey = Enum.KeyCode.F5 },
				{ label = "Hold zone now", send = cmd("ActivateObjective") },
				{ label = "Complete hold", send = cmd("ForceObjectiveComplete") },
				{ label = "Extract (win)", send = cmd("ForceMissionSuccess") },
				{ label = "Wipe (lose)", send = cmd("ForceWipe") },
				{ label = "Fill Resupply", send = cmd("FillResupply"), hotkey = Enum.KeyCode.F6 },
			},
		},
		{
			title = "INFECTED",
			actions = {
				{ label = "Spawning on/off", send = cmd("ToggleSpawns"), hotkey = Enum.KeyCode.F7 },
				{ label = "Clear all", send = cmd("ClearEnemies"), hotkey = Enum.KeyCode.F3 },
				{
					label = "10 Walkers",
					send = cmd("SpawnEnemy", "Walker", 10),
					hotkey = Enum.KeyCode.F4,
				},
				{ label = "5 Runners", send = cmd("SpawnEnemy", "Runner", 5) },
				{ label = "1 Brute", send = cmd("SpawnEnemy", "Brute", 1) },
				{ label = "3 Hockers", send = cmd("SpawnEnemy", "Hocker", 3) },
			},
		},
		{
			title = "SQUAD",
			actions = {
				{ label = "Down a bot", send = cmd("DownBot") },
				{ label = "Kill bots", send = cmd("KillBots") },
				{ label = "No bots", send = cmd("SetBots", 0) },
				{ label = "1 bot", send = cmd("SetBots", 1) },
				{ label = "3 bots", send = cmd("SetBots", 3) },
			},
		},
		{ title = "TELEPORT", actions = teleports },
		{
			title = "CHECKS",
			actions = {
				{ label = "Print state", send = cmd("PrintRunState") },
				{ label = "Verify cleanup", send = cmd("VerifyCleanup") },
				{ label = "Level up", send = cmd("ForceLevelUp") },
			},
		},
	}
end

local function keyName(key: Enum.KeyCode): string
	return key.Name
end

local function makeButton(parent: Instance, action: Action)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(38, 44, 46)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(228, 230, 226)
	button.Text = if action.hotkey
		then `{action.label}  [{keyName(action.hotkey)}]`
		else action.label
	button.TextWrapped = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Activated:Connect(function()
		if action.run then
			action.run()
		elseif action.send then
			send(action.send)
		end
	end)
	button.Parent = parent
end

local function buildPanel()
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
	strip.TextColor3 = Color3.fromRGB(150, 235, 180)
	strip.TextStrokeTransparency = 0.5
	strip.Parent = gui
	infoLabel = strip

	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -12, 0.5, 0)
	frame.Size = UDim2.new(0, 330, 0.86, 0)
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = 4
	frame.BackgroundColor3 = Color3.fromRGB(16, 19, 20)
	frame.BackgroundTransparency = 0.08
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
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(150, 235, 180)
	title.Text = `DEV TOOLS  ·  {keyName(TOGGLE_KEY)} to close`
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 16)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(200, 200, 196)
	status.Parent = frame
	statusLabel = status

	for index, section in sections() do
		local header = Instance.new("TextLabel")
		header.LayoutOrder = index * 2
		header.Size = UDim2.new(1, 0, 0, 16)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBold
		header.TextSize = 12
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = Color3.fromRGB(215, 160, 80)
		header.Text = section.title
		header.Parent = frame

		local grid = Instance.new("Frame")
		grid.LayoutOrder = index * 2 + 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		grid.Parent = frame
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -4, 0, 30)
		layout.CellPadding = UDim2.fromOffset(8, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for _, action in section.actions do
			makeButton(grid, action)
		end
	end

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

-- FPS, run state, Infected alive and squad states, refreshed a few times a second.
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
	local squadState = (character and character:GetAttribute("SquadState")) or "-"
	local text = string.format(
		"%.0f fps  ·  %s  ·  %d Infected  ·  me %s%s%s",
		fps,
		tostring(workspace:GetAttribute("RunState") or "?"),
		#CollectionService:GetTagged("Enemy"),
		tostring(squadState),
		if player:GetAttribute("DevGod") == true then "  ·  GOD" else "",
		if workspace:GetAttribute("DevSpawnsOff") == true then "  ·  SPAWNS OFF" else ""
	)
	if infoLabel then
		infoLabel.Text = text .. `   [{keyName(TOGGLE_KEY)} dev tools]`
	end
	if statusLabel then
		local bots = workspace:FindFirstChild("SquadBots")
		statusLabel.Text = string.format("bots alive: %d", if bots then #bots:GetChildren() else 0)
	end
end

function DevTestPanel.init()
	if not (RunService:IsStudio() or Players.LocalPlayer.UserId == CREATOR_USER_ID) then
		return
	end
	remote = Remotes.get("DevCommand")
	buildPanel()

	local hotkeys: { [Enum.KeyCode]: Action } = {}
	for _, section in sections() do
		for _, action in section.actions do
			if action.hotkey then
				hotkeys[action.hotkey] = action
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			setOpen(not (panel and panel.Visible))
			return
		end
		local action = hotkeys[input.KeyCode]
		if action then
			if action.run then
				action.run()
			elseif action.send then
				send(action.send)
			end
		end
	end)
	RunService.Heartbeat:Connect(updateInfo)
end

return DevTestPanel
