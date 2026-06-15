--!strict
-- Player health bar, bottom center above the XP bar. Tracks the humanoid
-- across respawns; fill shifts green -> red as health drops (and grows
-- past the bar when a Shield buff raises max health).

local Players = game:GetService("Players")

local HealthBarUI = {}

local fill: Frame
local label: TextLabel

local FULL_COLOR = Color3.fromRGB(96, 205, 72)
local LOW_COLOR = Color3.fromRGB(205, 60, 48)

local function update(humanoid: Humanoid)
	local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = LOW_COLOR:Lerp(FULL_COLOR, fraction)
	label.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	update(humanoid)
	humanoid.HealthChanged:Connect(function()
		update(humanoid)
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		update(humanoid)
	end)
end

function HealthBarUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBarUI"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -50)
	bar.Size = UDim2.fromOffset(420, 20)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FULL_COLOR
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "100 / 100"
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.Parent = bar

	local hpTag = Instance.new("TextLabel")
	hpTag.AnchorPoint = Vector2.new(1, 0.5)
	hpTag.Position = UDim2.new(0, -10, 0.5, 0)
	hpTag.Size = UDim2.fromOffset(80, 20)
	hpTag.BackgroundTransparency = 1
	hpTag.Text = "HP"
	hpTag.TextColor3 = FULL_COLOR
	hpTag.TextScaled = true
	hpTag.TextXAlignment = Enum.TextXAlignment.Right
	hpTag.Font = Enum.Font.GothamBold
	hpTag.Parent = bar

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Players.LocalPlayer.CharacterAdded:Connect(watchCharacter)
	if Players.LocalPlayer.Character then
		watchCharacter(Players.LocalPlayer.Character)
	end
end

return HealthBarUI
