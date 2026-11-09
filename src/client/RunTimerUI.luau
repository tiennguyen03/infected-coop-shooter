--!strict
-- Run timer, top centre. Reads the server-published RunStartTime
-- workspace attribute and the shared server clock, so there is no remote
-- traffic and no drift.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local HudTheme = require(script.Parent.HudTheme)

local UPDATE_INTERVAL = 0.2 -- seconds

local RunTimerUI = {}

local function formatTime(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

function RunTimerUI.init()
	-- Top centre (HudTheme): bold white digits, no panel (the corners belong to the health
	-- stack and the boss bar / notification cards).
	local gui = HudTheme.gui("RunTimerUI")
	local label = HudTheme.label(gui, { text = "00:00", size = 16 })
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 8)
	HudTheme.parent(gui)

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
