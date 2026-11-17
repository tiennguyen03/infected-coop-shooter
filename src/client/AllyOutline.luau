--!strict
-- A light outline on every squadmate, seen through walls (owner, 2026-11-11): other players'
-- soldiers and the bots (workspace.SquadBots). A Highlight with no fill, so it never hides
-- the body; it turns yellow while that squadmate is downed (the SquadState attribute).
-- Local to each client; tuning in Config.AllyOutline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AllyOutline = {}

local NAME = "AllyOutline"
local BOT_FOLDER = "SquadBots"

local function refresh(body: Model, highlight: Highlight)
	local tuning = Config.AllyOutline
	local state = body:GetAttribute(Attributes.SquadState)
	local downed = state == "Downed"
	highlight.Enabled = state ~= "Dead"
	highlight.OutlineColor = if downed then tuning.DownedColor else tuning.Color
	highlight.OutlineTransparency = if downed
		then tuning.DownedTransparency
		else tuning.Transparency
end

local function outline(body: Model)
	if body:FindFirstChild(NAME) then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = NAME
	highlight.Adornee = body
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = body
	refresh(body, highlight)
	-- The Highlight dies with the body, and the connection with it.
	body:GetAttributeChangedSignal(Attributes.SquadState):Connect(function()
		refresh(body, highlight)
	end)
end

local function onPlayer(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	player.CharacterAdded:Connect(outline)
	if player.Character then
		outline(player.Character)
	end
end

local function onBot(child: Instance)
	if child:IsA("Model") then
		outline(child)
	end
end

local function watchBots(folder: Instance)
	folder.ChildAdded:Connect(onBot)
	for _, child in folder:GetChildren() do
		onBot(child)
	end
end

function AllyOutline.init()
	if not Config.AllyOutline.Enabled then
		return
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	-- The bots' folder is made by the server at boot; it may arrive after this client starts.
	local folder = workspace:FindFirstChild(BOT_FOLDER)
	if folder then
		watchBots(folder)
	else
		workspace.ChildAdded:Connect(function(child)
			if child.Name == BOT_FOLDER then
				watchBots(child)
			end
		end)
	end
end

return AllyOutline
