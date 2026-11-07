--!strict
-- Player health bar, bottom center. Tracks the humanoid across respawns; fill shifts
-- green -> red as health drops. The Armour Plate shield (Shield attribute, loadout rework)
-- is a blue overlay from the left over the health fill with a "+N" tag.

local Players = game:GetService("Players")

local HealthBarUI = {}

local fill: Frame
local shieldFill: Frame
local shieldTag: TextLabel
local label: TextLabel

local FULL_COLOR = Color3.fromRGB(96, 205, 72)
local LOW_COLOR = Color3.fromRGB(205, 60, 48)
local SHIELD_COLOR = Color3.fromRGB(96, 170, 230)

local function update(humanoid: Humanoid)
	local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = LOW_COLOR:Lerp(FULL_COLOR, fraction)
	label.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
end

local function updateShield()
	local shield = (Players.LocalPlayer:GetAttribute("Shield") :: number?) or 0
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local maxHealth = if humanoid then math.max(humanoid.MaxHealth, 1) else 100
	shieldFill.Visible = shield > 0
	shieldFill.Size = UDim2.fromScale(math.clamp(shield / maxHealth, 0, 1), 1)
	shieldTag.Text = if shield > 0 then `+{math.ceil(shield)}` else ""
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
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FULL_COLOR
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	shieldFill = Instance.new("Frame")
	shieldFill.Size = UDim2.fromScale(0, 1)
	shieldFill.BackgroundColor3 = SHIELD_COLOR
	shieldFill.BackgroundTransparency = 0.25
	shieldFill.BorderSizePixel = 0
	shieldFill.Visible = false
	shieldFill.ZIndex = 2
	shieldFill.Parent = bar
	local shieldCorner = Instance.new("UICorner")
	shieldCorner.CornerRadius = UDim.new(0, 6)
	shieldCorner.Parent = shieldFill

	shieldTag = Instance.new("TextLabel")
	shieldTag.AnchorPoint = Vector2.new(0, 0.5)
	shieldTag.Position = UDim2.new(1, 10, 0.5, 0)
	shieldTag.Size = UDim2.fromOffset(60, 20)
	shieldTag.BackgroundTransparency = 1
	shieldTag.Text = ""
	shieldTag.TextColor3 = SHIELD_COLOR
	shieldTag.TextScaled = true
	shieldTag.TextXAlignment = Enum.TextXAlignment.Left
	shieldTag.Font = Enum.Font.GothamBold
	shieldTag.Parent = bar

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "100 / 100"
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.ZIndex = 3
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
	Players.LocalPlayer:GetAttributeChangedSignal("Shield"):Connect(updateShield)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(updateShield)
	end)
	updateShield()
end

return HealthBarUI
