--!strict
-- Top-center extraction prompt, driven by the ExtractionUpdate remote.
-- States: available (reach the zone), progress (inside, holding), returning
-- (outside, paused), complete, hide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ExtractionUI = {}

local frame: Frame
local titleLabel: TextLabel
local detailLabel: TextLabel

local function setText(title: string, detail: string, color: Color3)
	frame.Visible = true
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	detailLabel.Text = detail
end

local function onUpdate(kind: string, progress: number)
	local required = Config.Extraction.HoldDuration
	if kind == Messages.ExtractionUpdate.Available then
		setText("EXTRACTION AVAILABLE", "Reach the extraction zone", Color3.fromRGB(120, 255, 170))
	elseif kind == Messages.ExtractionUpdate.Progress then
		setText(
			"EXTRACTION IN PROGRESS",
			string.format("Hold: %.1f / %d", progress, required),
			Color3.fromRGB(120, 255, 170)
		)
	elseif kind == Messages.ExtractionUpdate.Returning then
		setText(
			"RETURN TO EXTRACTION",
			string.format("Progress: %.1f / %d", progress, required),
			Color3.fromRGB(255, 200, 90)
		)
	elseif kind == Messages.ExtractionUpdate.Complete then
		setText("EXTRACTION COMPLETE", "Operation successful", Color3.fromRGB(120, 255, 170))
	elseif kind == Messages.ExtractionUpdate.Hide then
		frame.Visible = false
	end
end

function ExtractionUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtractionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 110)
	frame.Size = UDim2.fromOffset(360, 56)
	frame.BackgroundColor3 = Color3.fromRGB(16, 28, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(8, 4)
	titleLabel.Size = UDim2.new(1, -16, 0, 28)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = ""
	titleLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = frame

	detailLabel = Instance.new("TextLabel")
	detailLabel.Position = UDim2.fromOffset(8, 32)
	detailLabel.Size = UDim2.new(1, -16, 0, 20)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Text = ""
	detailLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	detailLabel.TextScaled = true
	detailLabel.Font = Enum.Font.Gotham
	detailLabel.Parent = frame

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Remotes.get("ExtractionUpdate").OnClientEvent:Connect(onUpdate)
end

return ExtractionUI
