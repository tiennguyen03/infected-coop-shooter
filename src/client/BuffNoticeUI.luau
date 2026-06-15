--!strict
-- Short on-screen announcement when a buff is gained (ammo cache pickups).
-- Text pops in under the crosshair and floats up while fading.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local LIFETIME = 1.4

local BuffNoticeUI = {}

local gui: ScreenGui

local function showNotice(text: string)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.62)
	label.Size = UDim2.fromOffset(420, 34)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(232, 181, 75)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	TweenService
		:Create(label, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.54),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		:Play()
	task.delay(LIFETIME, function()
		label:Destroy()
	end)
end

function BuffNoticeUI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "BuffNoticeUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.get("BuffNotice").OnClientEvent:Connect(showNotice)
end

return BuffNoticeUI
