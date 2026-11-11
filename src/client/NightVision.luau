--!strict
-- Night vision goggles (Nova, 2026-11-11: the goggles on the soldier's FAST helmet, for a night
-- area). Config.Keys.NightVision (or Config.NightVision.GamepadKey) flips them down or up: a
-- short blink and a click, then the world through the tubes: Lighting exposure raised so the
-- dark reads, a green colour correction that takes the colour out, bloom on anything lit, a
-- small flicker and dark screen edges. Everything here is local to the player; it turns off on
-- respawn and on death. Config.NightVision holds every value.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundFX = require(script.Parent.SoundFX)

local NightVision = {}

local NV = Config.NightVision

local on = false
local exposureAdded = 0
local color: ColorCorrectionEffect
local bloom: BloomEffect
local edges: ScreenGui
local blink: Frame
local random = Random.new()

-- The dark screen edges: four gradient strips (no image needed).
local function buildOverlay(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "NightVision"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5 -- under the HUD
	gui.Enabled = false
	local share = NV.Vignette
	for _, side in { "Top", "Bottom", "Left", "Right" } do
		local strip = Instance.new("Frame")
		strip.BorderSizePixel = 0
		strip.BackgroundColor3 = Color3.new(0, 0, 0)
		local vertical = side == "Top" or side == "Bottom"
		strip.Size = if vertical then UDim2.fromScale(1, share) else UDim2.fromScale(share, 1)
		strip.Position = UDim2.fromScale(
			if side == "Right" then 1 - share else 0,
			if side == "Bottom" then 1 - share else 0
		)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = ({ Top = 90, Bottom = 270, Left = 0, Right = 180 })[side]
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = strip
		strip.Parent = gui
	end
	local dark = Instance.new("Frame")
	dark.Name = "Blink"
	dark.BorderSizePixel = 0
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 1
	dark.Size = UDim2.fromScale(1, 1)
	dark.Parent = gui
	return gui, dark
end

local function apply(state: boolean)
	color.Enabled = state
	bloom.Enabled = state
	edges.Enabled = state
	if state then
		exposureAdded = NV.Exposure
		Lighting.ExposureCompensation += exposureAdded
	else
		Lighting.ExposureCompensation -= exposureAdded
		exposureAdded = 0
	end
end

-- Flips the goggles to `state`: the screen blinks dark, the view changes at the darkest point.
local function set(state: boolean, instant: boolean?)
	if state == on then
		return
	end
	on = state
	if instant then
		apply(state)
		return
	end
	local click = NV.Click
	SoundFX.ui(click.Bank, click.Group, click.Volume, click.Pitch)
	-- The blink lives on the overlay, which is visible for the flip either way.
	edges.Enabled = true
	local half = TweenInfo.new(NV.FlipSeconds / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local down = TweenService:Create(blink, half, { BackgroundTransparency = 0 })
	down.Completed:Once(function()
		if on == state then
			apply(state)
			edges.Enabled = true -- keep the blink drawn while it fades
		end
		local up = TweenService:Create(blink, half, { BackgroundTransparency = 1 })
		up.Completed:Once(function()
			edges.Enabled = on
		end)
		up:Play()
	end)
	down:Play()
end

local function isToggle(input: InputObject): boolean
	return input.KeyCode == Config.Keys.NightVision or input.KeyCode == NV.GamepadKey
end

function NightVision.isOn(): boolean
	return on
end

function NightVision.init()
	if not NV.Enabled then
		return
	end
	color = Instance.new("ColorCorrectionEffect")
	color.Name = "NightVision"
	color.TintColor = NV.Tint
	color.Brightness = NV.Brightness
	color.Contrast = NV.Contrast
	color.Saturation = NV.Saturation
	color.Enabled = false
	color.Parent = Lighting
	bloom = Instance.new("BloomEffect")
	bloom.Name = "NightVisionBloom"
	bloom.Intensity = NV.Bloom.Intensity
	bloom.Size = NV.Bloom.Size
	bloom.Threshold = NV.Bloom.Threshold
	bloom.Enabled = false
	bloom.Parent = Lighting
	local player = Players.LocalPlayer
	edges, blink = buildOverlay()
	edges.Parent = player:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isToggle(input) then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			set(not on)
		end
	end)
	-- The tubes' slight noise.
	RunService.RenderStepped:Connect(function()
		if on then
			color.Brightness = NV.Brightness + random:NextNumber(-NV.Flicker, NV.Flicker)
		end
	end)
	local function watch(character: Model)
		set(false, true)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				set(false, true)
			end)
		end
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return NightVision
