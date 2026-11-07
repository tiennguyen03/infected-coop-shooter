--!strict
-- Floating damage numbers: the server reports each projectile hit and we
-- render a short-lived number that drifts up and fades at the hit position.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundFX = require(script.Parent.SoundFX)

local LIFETIME = 0.7 -- seconds
local RISE_STUDS = 3

local DamageNumberUI = {}

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

local HIT_COLOR = Color3.fromRGB(255, 233, 120)
local HEADSHOT_COLOR = Color3.fromRGB(255, 255, 255)
local BLEED_COLOR = Color3.fromRGB(255, 90, 70)

local function showDamageNumber(position: Vector3, amount: number, kind: string?)
	if kind == "death" then
		-- No number; the enemy died: a burst here, the death cry comes from the body
		-- itself (EnemyService plays the form's bank on the server).
		burst(position, Color3.fromRGB(110, 185, 90), 14)
		return
	end
	if kind == "bleed" then
		burst(position, BLEED_COLOR, 5)
	elseif kind == "headshot" then
		burst(position, HEADSHOT_COLOR, 10)
		SoundFX.playAt("player_hits", "headshot", position, "hit")
	else
		burst(position, HIT_COLOR, 7)
		SoundFX.playAt("player_hits", "bodyshot", position, "hit")
	end

	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = if kind == "headshot"
		then UDim2.fromScale(3.4, 1.6)
		else UDim2.fromScale(2.5, 1.2)
	billboard.AlwaysOnTop = true
	billboard.Adornee = attachment
	-- Slight horizontal jitter so rapid hits don't stack into one blob.
	billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 0, 0)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = if kind == "bleed"
		then BLEED_COLOR
		elseif kind == "headshot" then HEADSHOT_COLOR
		else HIT_COLOR
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	TweenService
		:Create(
			billboard,
			TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				StudsOffset = billboard.StudsOffset + Vector3.new(0, RISE_STUDS, 0),
			}
		)
		:Play()
	TweenService
		:Create(label, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		:Play()

	task.delay(LIFETIME, function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

function DamageNumberUI.init()
	Remotes.get("DamageDealt").OnClientEvent:Connect(showDamageNumber)
end

return DamageNumberUI
