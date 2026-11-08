--!strict
-- Hit feedback. The server reports each hit to the player who landed it only, and every
-- kill to everyone, with DamageDealt(position, amount, kind, attacker). The shooter sees
-- the spark burst and hears the 3D hit sound at the hit point; everyone sees a kill's
-- burst. Only the attacker gets the crosshair hit marker:
-- four diagonal ticks, white on a hit, larger and gold on a headshot, larger and red on a
-- kill. Damage over time (bleed, fire, rats) bursts but never marks, so the marker stays
-- tied to the trigger. Sizes and timings in Config.HitMarker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local GoreFX = require(script.Parent.GoreFX)
local SoundFX = require(script.Parent.SoundFX)

local HitMarkerUI = {}

local HIT_COLOR = Color3.fromRGB(255, 233, 120)
local HEADSHOT_COLOR = Color3.fromRGB(255, 255, 255)
local BLEED_COLOR = Color3.fromRGB(255, 90, 70)
local DEATH_COLOR = Color3.fromRGB(110, 185, 90)
-- Kinds that come straight from a trigger pull or a thrown/called weapon hit.
local MARKED_KINDS = { hit = true, headshot = true, breach = true }

local markerRoot: Frame? = nil
local ticks: { Frame } = {}
local markerToken = 0

-- Short spark burst at a world position (hit/bleed/death feedback).
local function burst(position: Vector3, color: Color3, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.3)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)

	task.delay(1, function()
		attachment:Destroy()
	end)
end

local function createMarker()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HitMarker"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6

	local root = Instance.new("Frame")
	root.Name = "Marker"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	for _, angle in { 45, 135, 225, 315 } do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.BorderSizePixel = 0
		tick.Rotation = angle
		tick.Parent = root
		table.insert(ticks, tick)
	end

	markerRoot = root
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function showMarker(kind: string)
	local root = markerRoot
	if not root then
		return
	end
	local settings = Config.HitMarker
	local isKill = kind == "death"
	local scale = if isKill
		then settings.KillScale
		elseif kind == "headshot" then settings.HeadshotScale
		else 1
	local color = if isKill
		then settings.Colors.kill
		elseif kind == "headshot" then settings.Colors.headshot
		else settings.Colors.hit
	local gap = settings.Gap * scale
	local length = settings.Length * scale
	local radius = gap + length / 2
	for index, tick in ticks do
		local angle = math.rad(45 + (index - 1) * 90)
		tick.Size = UDim2.fromOffset(length, settings.Thickness * (if isKill then 1.5 else 1))
		tick.Position = UDim2.fromOffset(math.cos(angle) * radius, math.sin(angle) * radius)
		tick.BackgroundColor3 = color
		tick.BackgroundTransparency = 0
		-- Rotation follows the tick's direction from the centre.
		tick.Rotation = math.deg(angle)
	end
	root.Visible = true

	markerToken += 1
	local token = markerToken
	local duration = if isKill then settings.KillDuration else settings.Duration
	local fade = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, tick in ticks do
		TweenService:Create(tick, fade, { BackgroundTransparency = 1 }):Play()
	end
	task.delay(duration, function()
		if token == markerToken then
			root.Visible = false
		end
	end)
end

local function onDamageDealt(position: Vector3, _amount: number, kind: string?, attacker: Player?)
	if kind == "death" then
		-- The death cry comes from the body itself (EnemyService plays the form's bank).
		burst(position, DEATH_COLOR, 14)
	elseif kind == "bleed" then
		burst(position, BLEED_COLOR, 5)
	elseif kind == "headshot" then
		burst(position, HEADSHOT_COLOR, 10)
		SoundFX.playAt("player_hits", "headshot", position, "hit")
		GoreFX.spray(position, Config.Enemies.Dismember.Chunks.Headshot)
	else
		burst(position, HIT_COLOR, 7)
		SoundFX.playAt("player_hits", "bodyshot", position, "hit")
		if kind == "hit" or kind == "breach" then
			GoreFX.spray(position, Config.Enemies.Dismember.Chunks.Body)
		end
	end

	if attacker ~= Players.LocalPlayer then
		return
	end
	if kind == "death" or MARKED_KINDS[kind or "hit"] then
		showMarker(kind or "hit")
	end
end

function HitMarkerUI.init()
	createMarker()
	Remotes.get("DamageDealt").OnClientEvent:Connect(onDamageDealt)
end

return HitMarkerUI
