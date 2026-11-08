--!strict
-- Top-center objective panel. Driven entirely by the ObjectiveUpdate remote:
-- "started" shows it, "progress" updates the counter, "completed" removes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ObjectiveUI = {}

local screenGui: ScreenGui?
local progressLabel: TextLabel?

local function formatProgress(progress: number): string
	return string.format("Progress: %.1f / %d", progress, Config.Objective.RequiredSeconds)
end

local function destroyPanel()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
		progressLabel = nil
	end
end

local function createPanel()
	destroyPanel()

	local gui = Instance.new("ScreenGui")
	gui.Name = "ObjectiveUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the item bar, which owns the very top of the screen.
	frame.Position = UDim2.new(0.5, 0, 0, 64)
	frame.Size = UDim2.fromOffset(340, 64)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 30)
	title.Position = UDim2.fromOffset(8, 4)
	title.BackgroundTransparency = 1
	title.Text = "OBJECTIVE: Secure the Area"
	title.TextColor3 = Color3.fromRGB(255, 220, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local progress = Instance.new("TextLabel")
	progress.Size = UDim2.new(1, -16, 0, 24)
	progress.Position = UDim2.fromOffset(8, 34)
	progress.BackgroundTransparency = 1
	progress.Text = formatProgress(0)
	progress.TextColor3 = Color3.fromRGB(235, 235, 235)
	progress.TextScaled = true
	progress.Font = Enum.Font.Gotham
	progress.Parent = frame

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui
	progressLabel = progress
end

local function onObjectiveUpdate(
	kind: string,
	progress: number,
	playersIn: number?,
	playersLiving: number?
)
	if kind == Messages.ObjectiveUpdate.Started then
		createPanel()
	elseif kind == Messages.ObjectiveUpdate.Progress then
		if progressLabel then
			local text = formatProgress(progress)
			if playersLiving and playersLiving > 1 then
				text ..= string.format("  (%d / %d in)", playersIn or 0, playersLiving)
			end
			progressLabel.Text = text
		end
	elseif kind == Messages.ObjectiveUpdate.Completed then
		destroyPanel()
	end
end

function ObjectiveUI.init()
	Remotes.get("ObjectiveUpdate").OnClientEvent:Connect(onObjectiveUpdate)
end

return ObjectiveUI
