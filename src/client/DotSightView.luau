--!strict
-- A red-dot sight's dot (Nova, 2026-11-20: the red dot "should actually have a red dot on
-- it"). Down the sight in first person the camera sits on the optic's axis
-- (CameraController, Rules/Sight), so the screen's centre is the lens's centre and where the
-- round goes; the dot is drawn there, as a real one reads (projected at infinity, no
-- parallax). It fades in over the last stretch of the raise so it appears as the sight lines
-- up. The look is the optic's own row (Config.Optics.<id>.Reticle): a hard dot and a soft halo.
-- Code-drawn, two frames; under the HUD (DisplayOrder -1) like ScopeView.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Optics = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attachments"):WaitForChild("Optics")
)

local DotSightView = {}

local REFERENCE_HEIGHT = 1080 -- Reticle sizes are pixels on a screen this tall
local FADE_FROM = 0.7 -- share of the raise before the dot starts to show
local HALO_OPACITY = 0.3 -- the halo's opacity when the dot is fully up

local gui: ScreenGui? = nil
local dot: Frame? = nil
local halo: Frame? = nil
local drawn: Optics.Reticle? = nil
local drawnHeight = -1
local shown = -1

local function round(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function build(): (Frame, Frame)
	local screen = Instance.new("ScreenGui")
	screen.Name = "DotSightView"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = -1
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	local h = round("Halo", screen)
	local d = round("Dot", screen)
	halo, dot = h, d
	return d, h
end

-- Draws `reticle` at `blend` of the raise into the sights (0 hides it; nil reticle: no dot).
function DotSightView.set(reticle: Optics.Reticle?, blend: number)
	local alpha = if reticle then math.clamp((blend - FADE_FROM) / (1 - FADE_FROM), 0, 1) else 0
	if alpha == 0 and shown == 0 then
		return
	end
	local d: Frame, h: Frame
	local builtDot, builtHalo = dot, halo
	if builtDot and builtHalo then
		d, h = builtDot, builtHalo
	elseif alpha == 0 then
		return
	else
		d, h = build()
	end
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else REFERENCE_HEIGHT
	if reticle and (reticle ~= drawn or height ~= drawnHeight) then
		drawn, drawnHeight = reticle, height
		local scale = height / REFERENCE_HEIGHT
		local size = math.max(math.floor(reticle.size * scale + 0.5), 2)
		local haloSize = size + 2 * math.max(math.floor(reticle.glow * scale + 0.5), 1)
		d.Size = UDim2.fromOffset(size, size)
		h.Size = UDim2.fromOffset(haloSize, haloSize)
		d.BackgroundColor3 = reticle.color
		h.BackgroundColor3 = reticle.color
	end
	if alpha ~= shown then
		shown = alpha
		d.BackgroundTransparency = 1 - alpha
		h.BackgroundTransparency = 1 - alpha * HALO_OPACITY
	end
	local screen = gui
	if screen then
		screen.Enabled = alpha > 0
	end
end

return DotSightView
