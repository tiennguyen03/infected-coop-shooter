--!strict
-- The breach marker (BreachService, remote Breach): a red chevron and "BREACH" on a ring round
-- the middle of the screen, pointing at the side the horde comes from (ahead = top), pulsing
-- for Config.Breaches.Marker.Seconds and fading out. Every client draws it from its own camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)

local BreachUI = {}

local C = HudTheme.Color
local FADE = 1 -- seconds the marker fades at the end

local holder: Frame
local arrow: Frame
local label: TextLabel
local from: Vector3? = nil
local shownAt = 0
local showFor = 0

local function bar(parent: Instance, rotation: number, offsetX: number)
	local piece = HudTheme.rect(parent, UDim2.fromOffset(24, 7), C.RedLight)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.new(0.5, offsetX, 0.5, 0)
	piece.Rotation = rotation
end

local function build()
	local gui = HudTheme.gui("BreachUI", 5)
	holder = Instance.new("Frame")
	holder.Name = "Marker"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(120, 80)
	holder.Visible = false
	holder.Parent = gui

	-- A chevron pointing up (two bars meeting at the top); the frame turns to aim it.
	arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.3)
	arrow.Size = UDim2.fromOffset(40, 40)
	arrow.Parent = holder
	bar(arrow, -45, -8)
	bar(arrow, 45, 8)

	label = HudTheme.label(holder, {
		text = "BREACH",
		font = HudTheme.Font.Headline,
		size = 20,
		color = C.RedLight,
		align = Enum.TextXAlignment.Center,
	})
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.62)
	HudTheme.parent(gui)
end

local function update()
	local point = from
	local camera = Workspace.CurrentCamera
	if not point or not camera then
		return
	end
	local age = os.clock() - shownAt
	if age >= showFor then
		from = nil
		holder.Visible = false
		return
	end
	local relative = camera.CFrame:PointToObjectSpace(point)
	local angle = math.atan2(relative.X, -relative.Z) -- 0 = straight ahead, clockwise
	local viewport = camera.ViewportSize
	local radius = math.min(viewport.X, viewport.Y) * Config.Breaches.Marker.Radius
	holder.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
	arrow.Rotation = math.deg(angle)
	local pulse = 0.5 + 0.5 * math.sin(age * 8)
	local fade = math.clamp((showFor - age) / FADE, 0, 1)
	local transparency = 1 - fade * (0.55 + 0.45 * pulse)
	label.TextTransparency = transparency
	label.TextStrokeTransparency = math.max(transparency, 0.55)
	for _, piece in arrow:GetChildren() do
		if piece:IsA("Frame") then
			piece.BackgroundTransparency = transparency
		end
	end
	holder.Visible = true
end

local function onBreach(kind: string, point: Vector3?, seconds: number?)
	if kind == Messages.Breach.Warn and typeof(point) == "Vector3" then
		from = point
		shownAt = os.clock()
		showFor = seconds or Config.Breaches.Marker.Seconds
	elseif kind == Messages.Breach.Clear then
		from = nil
		holder.Visible = false
	end
end

function BreachUI.init()
	build()
	Remotes.get("Breach").OnClientEvent:Connect(onBreach)
	RunService.RenderStepped:Connect(update)
end

return BreachUI
