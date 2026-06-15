--!strict
-- Death screen: on death, shows run stats (time survived, Infected killed,
-- level reached) and a restart button that asks the server for a new run.
-- Hidden automatically when the new character spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local DeathScreenUI = {}

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
	label.Position = UDim2.new(0.5, 0, 0, 120 + order * 38)
	label.Size = UDim2.fromOffset(420, 30)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(225, 225, 225)
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

	local gui = Instance.new("ScreenGui")
	gui.Name = "DeathScreenUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(28, 6, 6)
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 40)
	title.Size = UDim2.fromOffset(600, 64)
	title.BackgroundTransparency = 1
	title.Text = "K.I.A."
	title.TextColor3 = Color3.fromRGB(214, 69, 51)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = dim

	local items = (player:GetAttribute("ItemsCollected") :: number?) or 0
	statLine(dim, 0, `Time survived: {formatTime(survived)}`)
	statLine(dim, 1, `Infected killed: {kills}`)
	statLine(dim, 2, `Level reached: {level}`)
	statLine(dim, 3, `Items collected: {items}`)

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 320)
	button.Size = UDim2.fromOffset(240, 52)
	button.BackgroundColor3 = Color3.fromRGB(214, 69, 51)
	button.Text = "RESTART"
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBlack
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = dim

	button.Activated:Connect(function()
		button.Text = "DEPLOYING..."
		button.Active = false
		Remotes.get("RestartRun"):FireServer()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	overlay = gui
end

local function onCharacterAdded(character: Model)
	hide()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(show)
end

function DeathScreenUI.init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return DeathScreenUI
