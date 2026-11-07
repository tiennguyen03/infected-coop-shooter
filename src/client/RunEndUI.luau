--!strict
-- Run-end screens (Co-op Sprint A step 5; replaced DeathScreenUI and MissionSuccessUI).
-- Everything keys on the server's run state, never on this client's respawn:
--   * Dead while the run is live (squadmates or bots still fighting): a small K.I.A. banner,
--     no restart; the squad finishes the operation.
--   * RunState "Ended": the results screen for everyone, OPERATION COMPLETE (RunResult
--     "Extracted") or SQUAD WIPED ("Wiped"), the player's own stats, a READY button and the
--     ready count / countdown (RunManager: ReadyCount, ReadyNeeded, ReadyUpEndsAt).
--   * The screen goes away when the next run leaves Ended.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local RunEndUI = {}

local results: ScreenGui? = nil
local banner: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local readyButton: TextButton? = nil

local function formatTime(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

local function newGui(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.IgnoreGuiInset = true
	return gui
end

local function label(
	parent: Instance,
	text: string,
	y: number,
	height: number,
	color: Color3,
	font: Enum.Font
): TextLabel
	local item = Instance.new("TextLabel")
	item.AnchorPoint = Vector2.new(0.5, 0)
	item.Position = UDim2.new(0.5, 0, 0, y)
	item.Size = UDim2.fromOffset(560, height)
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = color
	item.TextScaled = true
	item.Font = font
	item.Parent = parent
	return item
end

local function hideResults()
	if results then
		results:Destroy()
		results = nil
		statusLabel = nil
		readyButton = nil
	end
end

local function hideBanner()
	if banner then
		banner:Destroy()
		banner = nil
	end
end

local function refreshStatus()
	local status = statusLabel
	if not status then
		return
	end
	local count = (workspace:GetAttribute("ReadyCount") :: number?) or 0
	local needed = (workspace:GetAttribute("ReadyNeeded") :: number?) or 1
	local endsAt = (workspace:GetAttribute("ReadyUpEndsAt") :: number?) or 0
	local text = `{count} / {needed} ready`
	if endsAt > 0 then
		text ..= `  -  next deployment in {math.max(
			math.ceil(endsAt - workspace:GetServerTimeNow()),
			0
		)}s`
	end
	status.Text = text
	local button = readyButton
	if button and Players.LocalPlayer:GetAttribute("Ready") == true then
		button.Text = "READY ✓"
		button.Active = false
		button.AutoButtonColor = false
	end
end

local function showResults()
	hideResults()
	hideBanner()
	local player = Players.LocalPlayer
	local extracted = workspace:GetAttribute("RunResult") == "Extracted"
	local startTime = (workspace:GetAttribute("RunStartTime") :: number?) or 0
	local survived = math.max(workspace:GetServerTimeNow() - startTime, 0)
	local kills = (player:GetAttribute("Kills") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1
	local items = (player:GetAttribute("ItemsCollected") :: number?) or 0
	local objectiveDone = workspace:GetAttribute("ObjectiveCompleted") == true

	local gui = newGui("RunEndUI", 100)
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = if extracted then Color3.fromRGB(8, 26, 16) else Color3.fromRGB(28, 6, 6)
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local accent = if extracted then Color3.fromRGB(90, 230, 140) else Color3.fromRGB(214, 69, 51)
	local body = Color3.fromRGB(225, 230, 225)
	label(
		dim,
		if extracted then "OPERATION COMPLETE" else "SQUAD WIPED",
		44,
		60,
		accent,
		Enum.Font.GothamBlack
	)
	local lines = {
		`Time survived: {formatTime(survived)}`,
		`Infected killed: {kills}`,
		`Level reached: {level}`,
		`Items collected: {items}`,
		`Objective completed: {if objectiveDone then "Yes" else "No"}`,
		`Extracted: {if extracted then "Yes" else "No"}`,
	}
	for index, line in lines do
		label(dim, line, 120 + (index - 1) * 36, 28, body, Enum.Font.Gotham)
	end

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 350)
	button.Size = UDim2.fromOffset(240, 52)
	button.BackgroundColor3 = accent
	button.Text = "READY"
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBlack
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = dim
	button.Activated:Connect(function()
		if button.Active then
			button.Text = "READY ✓"
			button.Active = false
			Remotes.get("RestartRun"):FireServer()
		end
	end)

	statusLabel = label(dim, "", 414, 26, body, Enum.Font.Gotham)
	readyButton = button
	gui.Parent = player:WaitForChild("PlayerGui")
	results = gui
	refreshStatus()
end

local function showBanner()
	if banner or results then
		return
	end
	local gui = newGui("KIABanner", 90)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 96)
	frame.Size = UDim2.fromOffset(460, 64)
	frame.BackgroundColor3 = Color3.fromRGB(28, 6, 6)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = gui
	local title = label(frame, "K.I.A.", 6, 30, Color3.fromRGB(214, 69, 51), Enum.Font.GothamBlack)
	title.Size = UDim2.fromOffset(420, 30)
	local sub = label(
		frame,
		"The squad fights on. You redeploy with them.",
		38,
		20,
		Color3.fromRGB(225, 225, 225),
		Enum.Font.Gotham
	)
	sub.Size = UDim2.fromOffset(420, 20)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	banner = gui
end

local function refresh()
	if workspace:GetAttribute("RunState") == "Ended" then
		if not results then
			showResults()
		end
		return
	end
	hideResults()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		showBanner()
	else
		hideBanner()
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(refresh)
	refresh()
end

function RunEndUI.init()
	local player = Players.LocalPlayer
	for _, name in { "RunState", "RunResult" } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, name in { "ReadyCount", "ReadyNeeded", "ReadyUpEndsAt" } do
		workspace:GetAttributeChangedSignal(name):Connect(refreshStatus)
	end
	player:GetAttributeChangedSignal("Ready"):Connect(refreshStatus)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	-- The countdown ticks down on screen.
	local lastTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if statusLabel and now - lastTick >= 0.25 then
			lastTick = now
			refreshStatus()
		end
	end)
	refresh()
end

return RunEndUI
