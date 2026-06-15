--!strict
-- Bottom-center XP bar. Driven entirely by the XP/Level/XPRequired player
-- attributes that XPService maintains on the server.

local Players = game:GetService("Players")

local SoundFX = require(script.Parent.SoundFX)

local XPBarUI = {}

local fill: Frame
local levelLabel: TextLabel
local progressLabel: TextLabel
local lastLevel = 1

local function update()
	local player = Players.LocalPlayer
	local xp = (player:GetAttribute("XP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1
	local required = (player:GetAttribute("XPRequired") :: number?) or 100

	fill.Size = UDim2.fromScale(math.clamp(xp / required, 0, 1), 1)
	levelLabel.Text = `LV {level}`
	progressLabel.Text = `{math.floor(xp)} / {required}`

	if level > lastLevel then
		SoundFX.play("levelup")
	end
	lastLevel = level
end

local function createBar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "XPBarUI"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.fromOffset(420, 20)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(85, 255, 170)
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	levelLabel = Instance.new("TextLabel")
	levelLabel.AnchorPoint = Vector2.new(1, 0.5)
	levelLabel.Position = UDim2.new(0, -10, 0.5, 0)
	levelLabel.Size = UDim2.fromOffset(80, 20)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "LV 1"
	levelLabel.TextColor3 = Color3.fromRGB(85, 255, 170)
	levelLabel.TextScaled = true
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = bar

	progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "0 / 100"
	progressLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	progressLabel.TextScaled = true
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.Parent = bar

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function XPBarUI.init()
	createBar()
	local player = Players.LocalPlayer
	for _, attribute in { "XP", "Level", "XPRequired" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()
end

return XPBarUI
