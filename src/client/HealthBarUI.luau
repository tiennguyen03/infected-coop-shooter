--!strict
-- Player health, top left (HUD language: HudTheme; after Prototype 2's health stack): a
-- long thin red bar with a two-tone fill and a white damage trail that holds, then shrinks;
-- under it a thinner white bar for the Armour Plate shield (Shield attribute) with a "+N"
-- tag. No numbers on the bar. Below 30% the outline turns red and a red edge vignette pulses;
-- downed, the fill dims and the vignette holds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local HudTheme = require(script.Parent.HudTheme)

local HealthBarUI = {}

local C = HudTheme.Color
local BAR_WIDTH = 400
local LOW_FRACTION = 0.3
local CHIP_HOLD = 0.35
local CHIP_SHRINK = 0.25

local track: Frame
local fill: Frame
local chip: Frame
local outline: UIStroke
local shieldTrack: Frame
local shieldFill: Frame
local shieldTag: TextLabel
local vignette: { Frame } = {}
local lastFraction = 1
local chipToken = 0
local low = false
local downed = false
local pulseClock = 0

local function setFraction(fraction: number)
	fill.Size = UDim2.fromScale(fraction, 1)
	if fraction < lastFraction then
		-- The damage trail holds at the old value, then shrinks to the new one.
		chipToken += 1
		local token = chipToken
		if chip.Size.X.Scale < lastFraction then
			chip.Size = UDim2.fromScale(lastFraction, 1)
		end
		task.delay(CHIP_HOLD, function()
			if token == chipToken then
				TweenService:Create(
					chip,
					TweenInfo.new(CHIP_SHRINK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(fraction, 1) }
				):Play()
			end
		end)
	else
		chip.Size = UDim2.fromScale(fraction, 1)
	end
	lastFraction = fraction
	low = fraction > 0 and fraction < LOW_FRACTION
	outline.Color = if low then C.RedLight else C.White
	outline.Transparency = if low then 0 else HudTheme.OutlineTransparency
end

local function update(humanoid: Humanoid)
	setFraction(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1))
end

local function updateShield()
	local shield = (Players.LocalPlayer:GetAttribute(Attributes.Shield) :: number?) or 0
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local maxHealth = if humanoid then math.max(humanoid.MaxHealth, 1) else 100
	shieldTrack.Visible = shield > 0
	shieldFill.Size = UDim2.fromScale(math.clamp(shield / maxHealth, 0, 1), 1)
	shieldTag.Text = if shield > 0 then `+{math.ceil(shield)}` else ""
end

local function updateDowned(character: Model)
	downed = character:GetAttribute(Attributes.SquadState) == "Downed"
	fill.Visible = not downed
	track.BackgroundColor3 = if downed then C.RedDark else C.Track
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	lastFraction = 1
	chip.Size = UDim2.fromScale(1, 1)
	update(humanoid)
	humanoid.HealthChanged:Connect(function()
		update(humanoid)
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		update(humanoid)
	end)
	character:GetAttributeChangedSignal(Attributes.SquadState):Connect(function()
		updateDowned(character)
	end)
	updateDowned(character)
end

-- Four red edge strips fading inward: low health pulses them, downed holds them.
local function buildVignette()
	local gui = HudTheme.gui("DamageVignette", 1)
	gui.IgnoreGuiInset = true
	local edges = {
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(1, 0.12), rotation = 90 },
		{ anchor = Vector2.new(0, 1), size = UDim2.fromScale(1, 0.12), rotation = -90 },
		{ anchor = Vector2.new(0, 0), size = UDim2.fromScale(0.12, 1), rotation = 0 },
		{ anchor = Vector2.new(1, 0), size = UDim2.fromScale(0.12, 1), rotation = 180 },
	}
	for index, edge in edges do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = edge.anchor
		frame.Position = UDim2.fromScale(edge.anchor.X, edge.anchor.Y)
		frame.Size = edge.size
		frame.BackgroundColor3 = C.Red
		frame.BorderSizePixel = 0
		frame.Visible = false
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new(0.35, 1)
		gradient.Parent = frame
		frame.Parent = gui
		vignette[index] = frame
	end
	HudTheme.parent(gui)
end

function HealthBarUI.init()
	local gui = HudTheme.gui("HealthBarUI")
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(HudTheme.Margin, 12)
	root.Size = UDim2.fromOffset(BAR_WIDTH + 80, 32)
	root.Parent = gui

	track = HudTheme.rect(
		root,
		UDim2.fromOffset(BAR_WIDTH, 16),
		C.Track,
		HudTheme.TrackTransparency,
		true
	)
	outline = track:FindFirstChildOfClass("UIStroke") :: UIStroke
	chip = HudTheme.rect(track, UDim2.fromScale(1, 1), C.White, 0.2)
	fill = HudTheme.rect(track, UDim2.fromScale(1, 1), C.Red)
	HudTheme.facet(fill, C.RedLight, C.Red)

	shieldTrack =
		HudTheme.rect(root, UDim2.fromOffset(BAR_WIDTH, 6), C.Track, HudTheme.TrackTransparency)
	shieldTrack.Position = UDim2.fromOffset(0, 19)
	shieldTrack.Visible = false
	shieldFill = HudTheme.rect(shieldTrack, UDim2.fromScale(0, 1), C.White)
	shieldTag = HudTheme.label(root, { size = 14 })
	shieldTag.Position = UDim2.fromOffset(BAR_WIDTH + 8, 15)

	HudTheme.parent(gui)
	buildVignette()

	Players.LocalPlayer.CharacterAdded:Connect(watchCharacter)
	if Players.LocalPlayer.Character then
		task.spawn(watchCharacter, Players.LocalPlayer.Character)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.Shield):Connect(updateShield)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(updateShield)
	end)
	updateShield()

	-- The vignette pulse: computed at 15 Hz, not tweened; nothing runs when it is off.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 15 then
			return
		end
		pulseClock += accumulator
		accumulator = 0
		local on = low or downed
		for _, frame in vignette do
			if frame.Visible ~= on then
				frame.Visible = on
			end
		end
		if low and not downed then
			local alpha = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(pulseClock * math.pi * 2))
			for _, frame in vignette do
				frame.BackgroundTransparency = alpha - 0.35
			end
		elseif downed then
			for _, frame in vignette do
				frame.BackgroundTransparency = 0
			end
		end
	end)
end

return HealthBarUI
