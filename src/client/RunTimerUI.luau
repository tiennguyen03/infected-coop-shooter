--!strict
-- Run timer, top-right corner. Reads the server-published RunStartTime
-- workspace attribute and the shared server clock, so there is no remote
-- traffic and no drift.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))

local UPDATE_INTERVAL = 0.2 -- seconds

local RunTimerUI = {}

local function formatTime(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

function RunTimerUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RunTimerUI"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -16, 0, 12)
	label.Size = UDim2.fromOffset(110, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Text = "00:00"
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	task.spawn(function()
		while gui.Parent do
			local startTime = workspace:GetAttribute(Attributes.RunStartTime) :: number?
			if startTime then
				label.Text = formatTime(math.max(workspace:GetServerTimeNow() - startTime, 0))
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return RunTimerUI
