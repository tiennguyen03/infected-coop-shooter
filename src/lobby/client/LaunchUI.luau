--!strict
-- Your seat on a Lantern spot (LaunchService): while you stand in a boarding box, the lower
-- middle of the screen shows the spot, who is aboard and the countdown to lift; "LIFTING"
-- when it goes, and the reason when a teleport does not happen. HUD style per HudTheme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudTheme = require(script.Parent.HudTheme)

local LaunchUI = {}

local FAILED_SECONDS = 6

function LaunchUI.init()
	local gui = HudTheme.gui("LaunchUI", 5)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -120)
	holder.Size = UDim2.fromOffset(520, 110)
	holder.Visible = false
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = holder

	local title = HudTheme.label(
		holder,
		{ size = 26, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow }
	)
	title.LayoutOrder = 1
	local crew = HudTheme.label(holder, { size = 18 })
	crew.LayoutOrder = 2
	local status = HudTheme.label(holder, { size = 22, font = HudTheme.Font.Headline })
	status.LayoutOrder = 3
	HudTheme.parent(gui)

	local liftAt: number? = nil -- os.clock on this client
	local hideAt: number? = nil

	Remotes.get("Launch").OnClientEvent:Connect(function(kind: string, ...)
		if kind == Messages.Launch.Manifest then
			local spot, names, secondsLeft = ...
			title.Text = `LANTERN · SPOT {spot}`
			crew.Text =
				`Aboard {#names}/{Config.Lobby.Launch.Capacity}: {table.concat(names, ", ")}`
			status.TextColor3 = HudTheme.Color.Text
			liftAt = os.clock() + (secondsLeft :: number)
			hideAt = nil
			holder.Visible = true
		elseif kind == Messages.Launch.Lifting then
			liftAt = nil
			status.Text = "LIFTING"
			status.TextColor3 = HudTheme.Color.Yellow
		elseif kind == Messages.Launch.Failed then
			local reason = ...
			liftAt = nil
			status.Text = reason
			status.TextColor3 = HudTheme.Color.RedLight
			hideAt = os.clock() + FAILED_SECONDS
			holder.Visible = true
		elseif kind == Messages.Launch.Cleared then
			liftAt = nil
			holder.Visible = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if liftAt then
			status.Text = `Lifts in {math.ceil(math.max(0, liftAt - os.clock()))}`
		end
		if hideAt and os.clock() >= hideAt then
			hideAt = nil
			holder.Visible = false
		end
	end)
end

return LaunchUI
