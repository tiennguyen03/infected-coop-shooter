--!strict
-- Creator-only dev panel: a small key-bound cheat sheet that fires DevCommand.
-- Only initializes in Studio or for the creator, so public players never see
-- it. Keys: F1 give XP, F2 force level-up, F3 spawn Brute, F4 spawn Walkers,
-- F5 clear enemies, F6 kill player, F7 restart, F8 print state, F9 cleanup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local CREATOR_USER_ID = 67169996

local DevTestPanel = {}

local BINDINGS: { { key: Enum.KeyCode, label: string, send: { any } } } = {
	{ key = Enum.KeyCode.F1, label = "F1  Give 100 XP", send = { "GiveXP", 100 } },
	{ key = Enum.KeyCode.F2, label = "F2  Force level-up", send = { "ForceLevelUp" } },
	{ key = Enum.KeyCode.F3, label = "F3  Spawn Brute", send = { "SpawnEnemy", "Brute", 1 } },
	{
		key = Enum.KeyCode.F4,
		label = "F4  Spawn 10 Walkers",
		send = { "SpawnEnemy", "Walker", 10 },
	},
	{ key = Enum.KeyCode.F5, label = "F5  Clear enemies", send = { "ClearEnemies" } },
	{ key = Enum.KeyCode.F6, label = "F6  Kill player", send = { "KillPlayer" } },
	{ key = Enum.KeyCode.F7, label = "F7  Restart run", send = { "RestartRun" } },
	{ key = Enum.KeyCode.F8, label = "F8  Print run state", send = { "PrintRunState" } },
	{ key = Enum.KeyCode.F9, label = "F9  Verify cleanup", send = { "VerifyCleanup" } },
}

local function buildPanel(remote: RemoteEvent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevTestPanel"
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 8, 0.5, 0)
	frame.Size = UDim2.fromOffset(190, #BINDINGS * 18 + 24)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(8, 4)
	title.Size = UDim2.new(1, -16, 0, 16)
	title.BackgroundTransparency = 1
	title.Text = "DEV TOOLS"
	title.TextColor3 = Color3.fromRGB(120, 255, 170)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	for index, binding in BINDINGS do
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(8, 22 + (index - 1) * 18)
		label.Size = UDim2.new(1, -16, 0, 16)
		label.BackgroundTransparency = 1
		label.Text = binding.label
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextSize = 12
		label.Font = Enum.Font.Gotham
		label.Parent = frame
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		for _, binding in BINDINGS do
			if input.KeyCode == binding.key then
				remote:FireServer(table.unpack(binding.send))
				break
			end
		end
	end)
end

function DevTestPanel.init()
	if not (RunService:IsStudio() or Players.LocalPlayer.UserId == CREATOR_USER_ID) then
		return
	end
	buildPanel(Remotes.get("DevCommand"))
end

return DevTestPanel
