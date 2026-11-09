--!strict
-- Low-health feedback (satisfying pass, docs/STYLES.md "Low-health feedback"): as the local
-- player's health drops under Config.Audio.LowHealth.Start the screen greys (its own
-- ColorCorrection, LowHealthCC, beside SkyService's grade), the edges darken, a heartbeat
-- fades in and quickens, and the World SoundGroup (SoundBanks.worldGroup) muffles. One
-- intensity drives all four: Feel.lowHealth of the health fraction, 1 while Downed (Squad:
-- SquadState), 0 dead or with no character, eased toward over LowHealth.Ease seconds so a
-- heal fades it back out. Render only; nothing is sent to the server.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Rules"):WaitForChild("Feel"))
local SoundBanks = require(Shared:WaitForChild("SoundBanks"))
local HudTheme = require(script.Parent.HudTheme)

local LowHealthFX = {}

local CFG = Config.Audio.LowHealth
-- How far each dark edge reaches into the screen (fraction of the screen side).
local EDGE_DEPTH = 0.4
-- Below this the shown intensity counts as off (effects disabled, heartbeat stopped).
local OFF = 0.002

local shown = 0
local grade: ColorCorrectionEffect
local edges: { Frame } = {}
local gui: ScreenGui
local heartbeat: Sound
local muffle: EqualizerSoundEffect

local function target(): number
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return 0
	end
	local state = character:GetAttribute(Attributes.SquadState)
	if state == "Dead" then
		return 0
	elseif state == "Downed" then
		return 1
	end
	return Feel.lowHealth(humanoid.Health / math.max(humanoid.MaxHealth, 1), CFG.Start)
end

-- Four black strips fading inward; they overlap at the corners, which darkens those most.
-- No UIScale (HudTheme.gui adds one): these are sized in screen fractions.
local function buildVignette()
	gui = Instance.new("ScreenGui")
	gui.Name = "LowHealthVignette"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1 -- under the HUD, so health and ammo stay readable
	gui.Enabled = false
	local layout = {
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(1, EDGE_DEPTH), rotation = 90 },
		{ anchor = Vector2.new(0, 1), size = UDim2.fromScale(1, EDGE_DEPTH), rotation = -90 },
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(EDGE_DEPTH, 1), rotation = 0 },
		{ anchor = Vector2.new(1, 0), size = UDim2.fromScale(EDGE_DEPTH, 1), rotation = 180 },
	}
	for index, edge in layout do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = edge.anchor
		frame.Position = UDim2.fromScale(edge.anchor.X, edge.anchor.Y)
		frame.Size = edge.size
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		-- Eased falloff: dense at the edge, gone by the inner side of the strip.
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = gui
		edges[index] = frame
	end
	HudTheme.parent(gui)
end

-- The equalizer lives on the World SoundGroup, which the server makes and replicates.
local function attachMuffle()
	muffle = Instance.new("EqualizerSoundEffect")
	muffle.Name = "LowHealthMuffle"
	muffle.HighGain = 0
	muffle.MidGain = 0
	muffle.LowGain = 0
	muffle.Enabled = false
	task.spawn(function()
		local group = SoundService:WaitForChild(SoundBanks.WORLD_GROUP, 30)
		if group and group:IsA("SoundGroup") then
			muffle.Parent = group
		else
			warn("LowHealthFX: no World SoundGroup; low health will not muffle the world")
		end
	end)
end

local function apply(i: number)
	local on = i > OFF
	grade.Enabled = on
	grade.Saturation = CFG.Saturation * i
	gui.Enabled = on
	local transparency = 1 - CFG.Vignette * i
	for _, frame in edges do
		frame.BackgroundTransparency = transparency
	end
	muffle.Enabled = on
	muffle.HighGain = CFG.MuffleHigh * i
	muffle.MidGain = CFG.MuffleMid * i
	if on then
		heartbeat.Volume = CFG.HeartbeatVolume * i
		heartbeat.PlaybackSpeed = CFG.RateMin + (CFG.RateMax - CFG.RateMin) * i
		if not heartbeat.IsPlaying then
			heartbeat:Play()
		end
	elseif heartbeat.IsPlaying then
		heartbeat:Stop()
	end
end

local function step(dt: number)
	local goal = target()
	if goal == shown then
		return -- settled; the last apply already showed it
	end
	-- Linear approach: a full 0 -> 1 swing takes Ease seconds.
	local stepSize = if CFG.Ease > 0 then dt / CFG.Ease else 1
	if goal > shown then
		shown = math.min(shown + stepSize, goal)
	else
		shown = math.max(shown - stepSize, goal)
	end
	if shown <= OFF and goal == 0 then
		shown = 0
	end
	apply(shown)
end

function LowHealthFX.init()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LowHealthCC"
	grade.Enabled = false
	grade.Parent = Lighting

	-- The heartbeat is the player's own body: SoundService, outside the World group.
	heartbeat = Instance.new("Sound")
	heartbeat.Name = "LowHealthHeartbeat"
	heartbeat.SoundId = CFG.HeartbeatId
	heartbeat.Looped = true
	heartbeat.Volume = 0
	heartbeat.Parent = SoundService

	buildVignette()
	attachMuffle()
	apply(0)
	RunService.RenderStepped:Connect(step)
end

return LowHealthFX
