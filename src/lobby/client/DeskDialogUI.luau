--!strict
-- A desk's line (DeskService, LobbyDesks): talking to a desk (F on its prompt) shows who is
-- behind it, what they say and what the desk will issue once the record opens. Closes after
-- Config.Lobby.DialogSeconds or when you walk out of reach. Local only: nothing is sent.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local HudTheme = require(script.Parent.HudTheme)

local DeskDialogUI = {}

function DeskDialogUI.init()
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, desk in LobbyDesks do
		byId[desk.id] = desk
	end

	local gui = HudTheme.gui("DeskDialogUI", 6)
	local panel = HudTheme.rect(
		gui,
		UDim2.fromOffset(560, 0),
		HudTheme.Color.Track,
		HudTheme.TrackTransparency,
		true
	)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -250)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = panel

	local title = HudTheme.label(
		panel,
		{ size = 22, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow, rich = true }
	)
	title.LayoutOrder = 1
	local line = HudTheme.label(panel, { size = 18, font = HudTheme.Font.Body })
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.fromScale(1, 0)
	line.TextWrapped = true
	local issues = HudTheme.label(panel, { size = 15, color = HudTheme.Color.TextDim })
	issues.LayoutOrder = 3
	HudTheme.parent(gui)

	local openPrompt: ProximityPrompt? = nil
	local closeAt = 0

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		local id = prompt:GetAttribute(Attributes.DeskId)
		local desk = if type(id) == "string" then byId[id] else nil
		if not desk then
			return
		end
		if desk.rack then
			-- A desk with a rack talks through ArmsRackUI: one dialog on screen at a time.
			panel.Visible = false
			openPrompt = nil
			return
		end
		title.Text = `{desk.title}  {HudTheme.tint(desk.who, HudTheme.Color.TextDim)}`
		line.Text = `"{desk.line}"`
		issues.Text = `Issues: {desk.issues}. Opens when the record does.`
		panel.Visible = true
		openPrompt = prompt
		closeAt = os.clock() + Config.Lobby.DialogSeconds
	end)

	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local tooFar = false
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local anchor = openPrompt and openPrompt.Parent
		if root and anchor and anchor:IsA("BasePart") then
			tooFar = (root.Position - anchor.Position).Magnitude
				> Config.Lobby.DeskPromptDistance * 1.5
		end
		if tooFar or os.clock() >= closeAt then
			panel.Visible = false
			openPrompt = nil
		end
	end)
end

return DeskDialogUI
