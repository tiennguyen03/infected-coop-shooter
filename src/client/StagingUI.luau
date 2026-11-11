--!strict
-- The staging line (docs/LOBBY_MATCH_HANDOFF.md): while a squad sent by the lobby is still
-- arriving (RunState Lobby, SquadExpected > 1), a centred line reads
-- "WAITING FOR SQUAD 2 / 4 · 0:23" until everyone has a body or the staging deadline passes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local HudTheme = require(script.Parent.HudTheme)

local StagingUI = {}

function StagingUI.init()
	local gui = Instance.new("ScreenGui")
	gui.DisplayOrder = 110 -- over the insertion cutscene's black cover (InsertionCutscene)
	gui.Name = "StagingUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	HudTheme.parent(gui)
	local line = HudTheme.label(gui, {
		font = HudTheme.Font.Headline,
		size = 22,
		align = Enum.TextXAlignment.Center,
	})
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0.18)
	line.Visible = false

	-- Polled a few times a second: the countdown ticks and the attributes are cheap to read.
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < 0.25 then
			return
		end
		last = now
		local expected = (workspace:GetAttribute(Attributes.SquadExpected) :: number?) or 1
		local staging = workspace:GetAttribute(Attributes.RunState) == "Lobby" and expected > 1
		line.Visible = staging and Players.LocalPlayer.Character ~= nil
		if not line.Visible then
			return
		end
		local arrived = (workspace:GetAttribute(Attributes.SquadArrived) :: number?) or 0
		local endsAt = (workspace:GetAttribute(Attributes.StagingEndsAt) :: number?) or 0
		local left = math.max(math.ceil(endsAt - workspace:GetServerTimeNow()), 0)
		line.Text = string.format(
			"WAITING FOR SQUAD %d / %d  ·  %d:%02d",
			arrived,
			expected,
			left // 60,
			left % 60
		)
	end)
end

return StagingUI
