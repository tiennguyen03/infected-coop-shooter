--!strict
-- Bottom-right ability panel: Q Dash + E Breach with cooldown countdowns,
-- plus a Combat Momentum stack readout. Cooldowns are driven by the
-- AbilityUsed remote (server authority); the UI counts down locally for
-- display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AbilityUI = {}

type Slot = { frame: Frame, label: TextLabel, cdLabel: TextLabel, readyUntil: number }
local slots: { [string]: Slot } = {}
local momentumLabel: TextLabel

local READY_COLOR = Color3.fromRGB(60, 120, 180)
local COOLING_COLOR = Color3.fromRGB(45, 48, 55)

local function makeSlot(parent: Frame, key: string, name: string, order: number): Slot
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(96, 52)
	frame.Position = UDim2.fromOffset(order * 104, 0)
	frame.BackgroundColor3 = READY_COLOR
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Text = `[{key}] {name}`
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local cdLabel = Instance.new("TextLabel")
	cdLabel.Position = UDim2.fromOffset(0, 28)
	cdLabel.Size = UDim2.new(1, 0, 0, 20)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text = "READY"
	cdLabel.TextColor3 = Color3.fromRGB(180, 230, 200)
	cdLabel.TextScaled = true
	cdLabel.Font = Enum.Font.Gotham
	cdLabel.Parent = frame

	return { frame = frame, label = label, cdLabel = cdLabel, readyUntil = 0 }
end

function AbilityUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityUI"
	gui.ResetOnSpawn = false

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -16, 1, -16)
	container.Size = UDim2.fromOffset(200, 52)
	container.BackgroundTransparency = 1
	container.Parent = gui

	slots.dash = makeSlot(container, "Q", "Dash", 0)
	slots.breach = makeSlot(container, "E", "Breach", 1)

	momentumLabel = Instance.new("TextLabel")
	momentumLabel.AnchorPoint = Vector2.new(1, 1)
	momentumLabel.Position = UDim2.new(1, -16, 1, -76)
	momentumLabel.Size = UDim2.fromOffset(200, 18)
	momentumLabel.BackgroundTransparency = 1
	momentumLabel.Text = ""
	momentumLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
	momentumLabel.TextScaled = true
	momentumLabel.TextXAlignment = Enum.TextXAlignment.Right
	momentumLabel.Font = Enum.Font.GothamBold
	momentumLabel.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.get("AbilityUsed").OnClientEvent:Connect(function(name: string, cooldown: number)
		local slot = slots[name]
		if slot then
			slot.readyUntil = os.clock() + cooldown
		end
	end)

	local lastClock = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - lastClock
		lastClock = now
		-- Freeze the countdown while the run is soft-paused (item selection) so
		-- the display matches the server, which also pauses cooldown progress.
		local paused = workspace:GetAttribute("GamePaused") == true
		for _, slot in slots do
			if paused and slot.readyUntil > now then
				slot.readyUntil += dt
			end
			local remaining = slot.readyUntil - now
			if remaining > 0 then
				slot.frame.BackgroundColor3 = COOLING_COLOR
				slot.cdLabel.Text = string.format("%.1fs", remaining)
			else
				slot.frame.BackgroundColor3 = READY_COLOR
				slot.cdLabel.Text = "READY"
			end
		end
		local stacks = (Players.LocalPlayer:GetAttribute("MomentumStacks") :: number?) or 0
		momentumLabel.Text = if stacks > 0 then `MOMENTUM x{stacks}` else ""
	end)
end

return AbilityUI
