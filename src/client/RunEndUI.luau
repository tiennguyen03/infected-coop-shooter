--!strict
-- Run-end screens (Co-op Sprint A step 5; replaced DeathScreenUI and MissionSuccessUI).
-- Everything keys on the server's run state, never on this client's respawn:
--   * Downed (Squad): a DOWNED banner with the bleed-out countdown and who is reviving.
--   * Dead while the run is live (squadmates or bots still fighting): a small K.I.A. banner,
--     no restart; the squad finishes the operation.
--   * RunState "Ended": the results screen for everyone, OPERATION COMPLETE (RunResult
--     "Extracted") or SQUAD WIPED ("Wiped"), the player's own stats, a READY button and the
--     ready count / countdown (RunManager: ReadyCount, ReadyNeeded, ReadyUpEndsAt).
--   * The screen goes away when the next run leaves Ended.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)
local SoundFX = require(script.Parent.SoundFX)

local C = HudTheme.Color

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
	local count = (workspace:GetAttribute(Attributes.ReadyCount) :: number?) or 0
	local needed = (workspace:GetAttribute(Attributes.ReadyNeeded) :: number?) or 1
	local endsAt = (workspace:GetAttribute(Attributes.ReadyUpEndsAt) :: number?) or 0
	local text = `{count} / {needed} ready`
	if endsAt > 0 then
		text ..= `  ·  next deployment in {math.max(
			math.ceil(endsAt - workspace:GetServerTimeNow()),
			0
		)}s`
	end
	-- A squad from the lobby flies home instead of redeploying (RunManager.goHome).
	local returnsHome = workspace:GetAttribute(Attributes.ReturnsHome) == true
	local homebound = workspace:GetAttribute(Attributes.Homebound) == true
	if homebound then
		text = "Helo inbound · back to the Carrier"
	elseif returnsHome then
		text = string.gsub(text, "next deployment", "Helo lifts")
	end
	status.Text = text
	local button = readyButton
	if button and homebound then
		button.Text = "LIFTING…"
		button.Active = false
		button.AutoButtonColor = false
	elseif
		button
		and returnsHome
		and Players.LocalPlayer:GetAttribute(Attributes.Ready) ~= true
	then
		button.Text = "BACK TO THE CARRIER"
	end
	if button and not homebound and Players.LocalPlayer:GetAttribute(Attributes.Ready) == true then
		button.Text = "READY ✓"
		button.Active = false
		button.AutoButtonColor = false
	end
end

-- Four thin red L-brackets in the screen corners (the menu frame language).
local function corners(parent: Instance)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = corner
		holder.Position = UDim2.new(
			corner.X,
			if corner.X == 0 then 24 else -24,
			corner.Y,
			if corner.Y == 0 then 24 else -24
		)
		holder.Size = UDim2.fromOffset(40, 40)
		holder.Parent = parent
		local across = HudTheme.rect(holder, UDim2.fromOffset(40, 2), C.Red)
		across.AnchorPoint = corner
		across.Position = UDim2.fromScale(corner.X, corner.Y)
		local down = HudTheme.rect(holder, UDim2.fromOffset(2, 40), C.Red)
		down.AnchorPoint = corner
		down.Position = UDim2.fromScale(corner.X, corner.Y)
	end
end

-- The results screen in the menu style (HudTheme; after Prototype 2's menus): a near-black
-- red field, corner brackets, a "//" header, the stats in a red-outlined box, a cream READY.
local function showResults()
	hideResults()
	hideBanner()
	local player = Players.LocalPlayer
	local extracted = workspace:GetAttribute(Attributes.RunResult) == "Extracted"
	local startTime = (workspace:GetAttribute(Attributes.RunStartTime) :: number?) or 0
	local survived = math.max(workspace:GetServerTimeNow() - startTime, 0)
	local kills = (player:GetAttribute(Attributes.Kills) :: number?) or 0
	local objectiveDone = workspace:GetAttribute(Attributes.ObjectiveCompleted) == true

	local gui = HudTheme.gui("RunEndUI", 100)
	gui.IgnoreGuiInset = true
	local field = HudTheme.rect(gui, UDim2.fromScale(1, 1), C.MenuBack, 0.1)
	corners(field)

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.fromOffset(520, 420)
	column.Parent = field
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 18)
	layout.Parent = column

	local header = HudTheme.label(column, {
		text = if extracted then "//OPERATION COMPLETE" else "//SQUAD WIPED",
		font = HudTheme.Font.Headline,
		size = 36,
		color = if extracted then C.Yellow else C.RedLight,
	})
	header.LayoutOrder = 1

	local box = HudTheme.rect(column, UDim2.fromOffset(520, 4 * 34 + 20), C.Track, 0.4)
	box.LayoutOrder = 2
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = C.Red
	boxStroke.Thickness = 1
	boxStroke.Parent = box
	local rows = {
		{ "TIME SURVIVED", formatTime(survived) },
		{ "INFECTED KILLED", tostring(kills) },
		{ "OBJECTIVE", if objectiveDone then "COMPLETE" else "FAILED" },
		{ "EXTRACTED", if extracted then "YES" else "NO" },
	}
	for index, row in rows do
		local y = 10 + (index - 1) * 34
		local name = HudTheme.label(box, { text = row[1], size = 14, color = C.TextDim })
		name.Position = UDim2.fromOffset(20, y + 6)
		local value =
			HudTheme.label(box, { text = row[2], size = 18, align = Enum.TextXAlignment.Right })
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -20, 0, y + 3)
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = 3
	button.Size = UDim2.fromOffset(240, 48)
	button.BackgroundColor3 = C.MenuSelect
	button.BorderSizePixel = 0
	button.Text = "READY"
	button.TextColor3 = C.MenuSelectText
	button.TextSize = 22
	button.Font = HudTheme.Font.Headline
	button.Parent = column
	button.Activated:Connect(function()
		if button.Active then
			SoundFX.ui("ui_radio", "ui_click")
			button.Text = "READY ✓"
			button.Active = false
			button.BackgroundTransparency = 0.4
			Remotes.get("RestartRun"):FireServer()
		end
	end)

	local status =
		HudTheme.label(column, { font = HudTheme.Font.Body, size = 16, color = C.TextDim })
	status.LayoutOrder = 4
	statusLabel = status
	readyButton = button
	HudTheme.parent(gui)
	results = gui
	refreshStatus()
end

local downedBanner: ScreenGui? = nil
local downedTimer: TextLabel? = nil
local downedBleed: Frame? = nil

local function hideDowned()
	if downedBanner then
		downedBanner:Destroy()
		downedBanner = nil
		downedTimer = nil
		downedBleed = nil
	end
end

local function refreshDowned()
	local timer = downedTimer
	local character = Players.LocalPlayer.Character
	if not timer or not character then
		return
	end
	local endsAt = (character:GetAttribute(Attributes.BleedOutAt) :: number?) or 0
	local seconds = math.max(endsAt - workspace:GetServerTimeNow(), 0)
	local left = math.ceil(seconds)
	local bleed = downedBleed
	if bleed then
		bleed.Size = UDim2.fromScale(math.clamp(seconds / Config.Downed.BleedOutSeconds, 0, 1), 1)
	end
	local reviver = character:GetAttribute(Attributes.Reviver)
	if typeof(reviver) == "string" and reviver ~= "" then
		timer.Text = `{HudTheme.tint(string.upper(reviver), C.Squad)} is reviving you · {left}s`
	else
		timer.Text = `Bleeding out in {left}s · hold on for a squadmate`
	end
end

-- A big red word and a line under it, no panel (HudTheme); downed adds the bleed-out bar.
local function bigBanner(
	name: string,
	title: string,
	sub: string,
	withBar: boolean
): (ScreenGui, TextLabel)
	local gui = HudTheme.gui(name, 90)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.fromScale(0.5, 0.22)
	column.Size = UDim2.fromOffset(600, 100)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = column
	local word = HudTheme.label(
		column,
		{ text = title, font = HudTheme.Font.Headline, size = 40, color = C.RedLight }
	)
	word.LayoutOrder = 1
	if withBar then
		local bar =
			HudTheme.rect(column, UDim2.fromOffset(360, 4), C.Track, HudTheme.TrackTransparency)
		bar.LayoutOrder = 2
		downedBleed = HudTheme.rect(bar, UDim2.fromScale(1, 1), C.Red)
	end
	local line =
		HudTheme.label(column, { text = sub, font = HudTheme.Font.Body, size = 18, rich = true })
	line.LayoutOrder = 3
	HudTheme.parent(gui)
	return gui, line
end

local function showDowned()
	if downedBanner or results then
		return
	end
	local gui, line = bigBanner("DownedBanner", "DOWNED", "", true)
	downedBanner = gui
	downedTimer = line
	refreshDowned()
end

local function showBanner()
	if banner or results then
		return
	end
	banner = bigBanner("KIABanner", "K.I.A.", "The squad fights on. You redeploy with them.", false)
end

local function refresh()
	if workspace:GetAttribute(Attributes.RunState) == "Ended" then
		if not results then
			showResults()
		end
		return
	end
	hideResults()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local downed = character ~= nil and character:GetAttribute(Attributes.SquadState) == "Downed"
	if humanoid and humanoid.Health <= 0 then
		hideDowned()
		showBanner()
	elseif downed then
		hideBanner()
		showDowned()
	else
		hideBanner()
		hideDowned()
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(refresh)
	character:GetAttributeChangedSignal(Attributes.SquadState):Connect(refresh)
	character:GetAttributeChangedSignal(Attributes.Reviver):Connect(refreshDowned)
	refresh()
end

function RunEndUI.init()
	local player = Players.LocalPlayer
	for _, name in { Attributes.RunState, Attributes.RunResult } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, name in
		{
			Attributes.ReadyCount,
			Attributes.ReadyNeeded,
			Attributes.ReadyUpEndsAt,
			Attributes.ReturnsHome,
			Attributes.Homebound,
		}
	do
		workspace:GetAttributeChangedSignal(name):Connect(refreshStatus)
	end
	player:GetAttributeChangedSignal(Attributes.Ready):Connect(refreshStatus)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	-- The countdowns tick down on screen.
	local lastTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick >= 0.25 then
			lastTick = now
			if statusLabel then
				refreshStatus()
			end
			if downedTimer then
				refreshDowned()
			end
		end
	end)
	-- Never offer to revive yourself: our own body's prompt stays hidden on this client.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local character = player.Character
		if character and prompt:IsDescendantOf(character) then
			prompt.Enabled = false
		end
	end)
	refresh()
end

return RunEndUI
