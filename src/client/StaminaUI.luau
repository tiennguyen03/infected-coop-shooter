--!strict
-- Stamina, top left under the health stack (HUD language: HudTheme): a thin yellow bar,
-- shorter and thinner than health so it reads as the second meter. It is only on screen
-- while it matters: it fades in when stamina is spent and out once it has been full for
-- Config.Stamina.BarHideAfter. Winded (ran dry: no sprint, roll or slide until it recovers)
-- the fill and the outline turn red and pulse, so the player can see why sprint stopped.
-- Reads SprintController, which owns the stamina; polled at 15 Hz like the other HUD pulses,
-- and nothing is written while the bar is hidden and full.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudTheme = require(script.Parent.HudTheme)
local SprintController = require(script.Parent.SprintController)

local StaminaUI = {}

local C = HudTheme.Color
local BAR_WIDTH = 300
local BAR_HEIGHT = 4
local OFFSET_Y = 38 -- under the health bar (12..28) and the shield bar (31..37)
local RATE = 1 / 15
local FADE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Linear)

local track: Frame
local fill: Frame
local outline: UIStroke
local shown = false
local winded = false
local lastFraction = 1
local fullFor = 0
local pulseClock = 0

local function setShown(on: boolean)
	if on == shown then
		return
	end
	shown = on
	local info = if on then FADE_IN else FADE_OUT
	TweenService
		:Create(
			track,
			info,
			{ BackgroundTransparency = if on then HudTheme.TrackTransparency else 1 }
		)
		:Play()
	TweenService:Create(fill, info, { BackgroundTransparency = if on then 0 else 1 }):Play()
	TweenService
		:Create(outline, info, { Transparency = if on then HudTheme.OutlineTransparency else 1 })
		:Play()
end

local function setWinded(on: boolean)
	if on == winded then
		return
	end
	winded = on
	fill.BackgroundColor3 = if on then C.RedLight else C.Yellow
	outline.Color = if on then C.RedLight else C.White
	if not on and shown then
		fill.BackgroundTransparency = 0
		outline.Transparency = HudTheme.OutlineTransparency
	end
end

local function update(dt: number)
	local fraction, isWinded = SprintController.getStamina()
	if fraction >= 1 and not isWinded then
		fullFor += dt
		if not shown and lastFraction >= 1 then
			return -- hidden and full: nothing to do
		end
	else
		fullFor = 0
	end
	if fraction ~= lastFraction then
		lastFraction = fraction
		fill.Size = UDim2.fromScale(fraction, 1)
	end
	setWinded(isWinded)
	setShown(fullFor < Config.Stamina.BarHideAfter)
	if winded then
		pulseClock += dt
		local wave = 0.5 + 0.5 * math.sin(pulseClock * math.pi * 4) -- two beats a second
		fill.BackgroundTransparency = 0.45 * wave
		outline.Transparency = 0.5 * wave
	end
end

function StaminaUI.init()
	local gui = HudTheme.gui("StaminaUI")
	track = HudTheme.rect(gui, UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT), C.Track, 1, true)
	track.Position = UDim2.fromOffset(HudTheme.Margin, OFFSET_Y)
	outline = track:FindFirstChildOfClass("UIStroke") :: UIStroke
	outline.Transparency = 1
	fill = HudTheme.rect(track, UDim2.fromScale(1, 1), C.Yellow, 1)
	HudTheme.parent(gui)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < RATE then
			return
		end
		update(accumulator)
		accumulator = 0
	end)
end

return StaminaUI
