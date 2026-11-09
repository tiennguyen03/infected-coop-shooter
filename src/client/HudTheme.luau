--!strict
-- The HUD's visual language (docs/STYLES.md section 5.1, after Prototype 2's HUD; the
-- ui-ux-designer's reference board in .superpowers/ui-refs/prototype2): no panels behind
-- HUD text, white bold type with a soft dark stroke, hard-edged bars, red for health,
-- enemies and alerts, white for the secondary meter, yellow for places and bonus targets.
-- Every HUD script builds its ScreenGui through `HudTheme.gui` so one UIScale keeps the
-- layout readable from 1080p down to a phone.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HudTheme = {}

HudTheme.Color = table.freeze({
	Text = Color3.fromRGB(240, 240, 240),
	TextDim = Color3.fromRGB(150, 154, 160),
	Red = Color3.fromRGB(185, 52, 52),
	RedLight = Color3.fromRGB(232, 90, 90),
	RedDark = Color3.fromRGB(90, 40, 40),
	White = Color3.fromRGB(240, 240, 240),
	Track = Color3.fromRGB(18, 19, 22),
	Yellow = Color3.fromRGB(230, 189, 96),
	Squad = Color3.fromRGB(63, 167, 214),
	Stun = Color3.fromRGB(78, 132, 196),
	MenuBack = Color3.fromRGB(22, 8, 8),
	MenuSelect = Color3.fromRGB(232, 222, 196),
	MenuSelectText = Color3.fromRGB(28, 30, 34),
})

HudTheme.Font = table.freeze({
	Headline = Enum.Font.GothamBlack,
	Line = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
})

HudTheme.TrackTransparency = 0.3
HudTheme.OutlineTransparency = 0.75
HudTheme.Margin = 16

-- Hex for RichText <font color="#..."> runs.
function HudTheme.hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- A RichText run in a colour: `HudTheme.tint("CHECKPOINT", HudTheme.Color.Yellow)`.
function HudTheme.tint(text: string, color: Color3): string
	return `<font color="{HudTheme.hex(color)}">{text}</font>`
end

local function scaleFor(viewport: Vector2): number
	return math.clamp(viewport.Y / 1080, 0.62, 1)
end

-- Touch-only devices (no keyboard): the layout moves out of the thumbstick and jump zones.
function HudTheme.isTouch(): boolean
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- A HUD ScreenGui with one UIScale that follows the viewport (never per frame).
function HudTheme.gui(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = displayOrder or 0
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			uiScale.Scale = scaleFor(camera.ViewportSize)
		end
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return gui
end

function HudTheme.parent(gui: ScreenGui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

export type LabelOptions = {
	text: string?,
	font: Enum.Font?,
	size: number?, -- TextSize at 1080p
	color: Color3?,
	align: Enum.TextXAlignment?,
	rich: boolean?,
}

-- HUD text: no background, white, a soft dark stroke, a fixed TextSize (never TextScaled).
function HudTheme.label(parent: Instance, options: LabelOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = options.text or ""
	label.Font = options.font or HudTheme.Font.Line
	label.TextSize = options.size or 18
	label.TextColor3 = options.color or HudTheme.Color.Text
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.55
	label.TextXAlignment = options.align or Enum.TextXAlignment.Left
	label.RichText = options.rich == true
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.Parent = parent
	return label
end

-- A hard-edged rectangle (no corners), optionally outlined.
function HudTheme.rect(
	parent: Instance,
	size: UDim2,
	color: Color3,
	transparency: number?,
	outline: boolean?
): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if outline then
		local stroke = Instance.new("UIStroke")
		stroke.Color = HudTheme.Color.White
		stroke.Transparency = HudTheme.OutlineTransparency
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
	return frame
end

-- The two-tone "faceted" fill: a hard step from the light tone (top 40%) to the base tone.
function HudTheme.facet(frame: Frame, light: Color3, base: Color3)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.4, light),
		ColorSequenceKeypoint.new(0.401, base),
		ColorSequenceKeypoint.new(1, base),
	})
	gradient.Parent = frame
end

return HudTheme
