--!strict
-- Mission success results screen, shown when the MissionSuccess remote fires
-- (extraction complete). Mirrors the death screen but green/positive. Restart
-- asks the server for a fresh run; hidden when the new character spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local MissionSuccessUI = {}

local overlay: ScreenGui?

local function formatTime(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

local function hide()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function statLine(parent: Frame, order: number, text: string)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 120 + order * 36)
	label.Size = UDim2.fromOffset(440, 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(225, 235, 225)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.Parent = parent
end

local function show()
	hide()
	local player = Players.LocalPlayer

	local startTime = (workspace:GetAttribute("RunStartTime") :: number?) or 0
	local survived = math.max(workspace:GetServerTimeNow() - startTime, 0)
	local kills = (player:GetAttribute("Kills") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1
	local items = (player:GetAttribute("ItemsCollected") :: number?) or 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "MissionSuccessUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(8, 26, 16)
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 44)
	title.Size = UDim2.fromOffset(640, 60)
	title.BackgroundTransparency = 1
	title.Text = "OPERATION COMPLETE"
	title.TextColor3 = Color3.fromRGB(90, 230, 140)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = dim

	statLine(dim, 0, `Time survived: {formatTime(survived)}`)
	statLine(dim, 1, `Infected killed: {kills}`)
	statLine(dim, 2, `Level reached: {level}`)
	statLine(dim, 3, `Items collected: {items}`)
	statLine(dim, 4, "Objective completed: Yes")
	statLine(dim, 5, "Extracted: Yes")

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 340)
	button.Size = UDim2.fromOffset(240, 52)
	button.BackgroundColor3 = Color3.fromRGB(60, 200, 120)
	button.Text = "RESTART"
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBlack
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = dim

	button.Activated:Connect(function()
		button.Text = "REDEPLOYING..."
		button.Active = false
		Remotes.get("RestartRun"):FireServer()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	overlay = gui
end

function MissionSuccessUI.init()
	Remotes.get("MissionSuccess").OnClientEvent:Connect(show)
	-- A fresh run respawns the character; clear the screen then.
	Players.LocalPlayer.CharacterAdded:Connect(hide)
end

return MissionSuccessUI
