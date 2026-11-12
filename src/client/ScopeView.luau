--!strict
-- The scope picture (owner 2026-11-11: "the sniper rifle makes no sense"; Nova 2026-11-10: the
-- scopes were "a ring and a crosshair with no zoom"). Down a scope in first person the camera
-- zooms to the scope's magnification (CameraController, Rules/Sight.fov) and this draws what
-- the eye sees at the eyepiece: a round lens on the screen's centre, black around it, a soft
-- shadow inside the rim, and the reticle, whose centre is the screen's centre, where the
-- round goes. FirstPersonView hides the gun while it is up.
--
-- Code-drawn, no image: the black round the lens is two blocks above and below it and a
-- strip either side of each of Scope.Rows rows across it, cut to the circle's chord; the
-- stair-steps that leaves (never deeper than a row) are covered by a black ring stroked round
-- the lens. Built once, laid out again when the viewport changes, and touched only while the
-- picture fades. Under the HUD (DisplayOrder -1), so health and ammo stay readable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ScopeView = {}

local STYLE = Config.Weapon.Sights.Scope
local BLACK = Color3.new(0, 0, 0)
local RETICLE = Color3.fromRGB(12, 12, 12)
local DOT = Color3.fromRGB(232, 90, 90) -- red.l (docs/STYLES.md > UI palette)

type Piece = { frame: Frame, stroke: UIStroke?, base: number } -- base: transparency when up

local gui: ScreenGui? = nil
local pieces: { Piece } = {}
local blinkDisc: Frame? = nil
local laidOutFor: Vector2? = nil
local shown = -1 -- the shade last drawn
local blinked = -1

local function frame(parent: Instance, color: Color3, base: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Parent = parent
	table.insert(pieces, { frame = f, stroke = nil, base = base or 0 })
	return f
end

-- A rectangle from (x0, y0) to (x1, y1) in pixels.
local function span(f: Frame, x0: number, y0: number, x1: number, y1: number)
	f.Position = UDim2.fromOffset(math.floor(x0), math.floor(y0))
	f.Size = UDim2.fromOffset(
		math.max(math.ceil(x1) - math.floor(x0), 0),
		math.max(math.ceil(y1) - math.floor(y0), 0)
	)
end

-- A ring: an empty round frame of radius `inner` with a stroke `width` wide outside it.
local function ring(parent: Instance, base: number): (Frame, UIStroke)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Transparency = 1
	stroke.Parent = f
	f.Parent = parent
	table.insert(pieces, { frame = f, stroke = stroke, base = base })
	return f, stroke
end

local function layout(root: ScreenGui, view: Vector2)
	for _, piece in pieces do
		piece.frame:Destroy()
	end
	table.clear(pieces)
	if blinkDisc then
		blinkDisc:Destroy()
	end
	local cx, cy = view.X / 2, view.Y / 2
	-- A share of the height; on a narrow (portrait) screen, of the width.
	local radius = math.floor(math.min(view.Y * STYLE.Lens, view.X * 0.46))
	local rows = STYLE.Rows
	local rowHeight = 2 * radius / rows

	-- The eye passing the eyepiece: the lens goes black for a moment (ScopeView.set).
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromOffset(cx, cy)
	disc.Size = UDim2.fromOffset(2 * radius + 2, 2 * radius + 2)
	disc.BackgroundColor3 = BLACK
	disc.BackgroundTransparency = 1
	disc.BorderSizePixel = 0
	local discCorner = Instance.new("UICorner")
	discCorner.CornerRadius = UDim.new(1, 0)
	discCorner.Parent = disc
	disc.Parent = root
	blinkDisc = disc

	-- The reticle: a fine crosshair with range marks, three heavy posts (left, right, below)
	-- that stop short of the centre, and a red dot on it.
	local line, post = STYLE.Line, STYLE.Post
	span(frame(root, RETICLE), cx - radius, cy - line / 2, cx + radius, cy + line / 2)
	span(frame(root, RETICLE), cx - line / 2, cy - radius, cx + line / 2, cy + radius)
	local gap = radius * STYLE.PostGap
	span(frame(root, RETICLE), cx - radius, cy - post / 2, cx - gap, cy + post / 2)
	span(frame(root, RETICLE), cx + gap, cy - post / 2, cx + radius, cy + post / 2)
	span(frame(root, RETICLE), cx - post / 2, cy + gap, cx + post / 2, cy + radius)
	for i = 1, STYLE.Ticks do
		local at = radius * STYLE.TickStep * i
		local half = if i % 2 == 0 then 5 else 3
		for _, side in { -1, 1 } do
			local x, y = cx + side * at, cy + side * at
			span(frame(root, RETICLE), x - line / 2, cy - half, x + line / 2, cy + half)
			span(frame(root, RETICLE), cx - half, y - line / 2, cx + half, y + line / 2)
		end
	end
	local dot = frame(root, DOT)
	span(dot, cx - STYLE.Dot / 2, cy - STYLE.Dot / 2, cx + STYLE.Dot / 2, cy + STYLE.Dot / 2)

	-- The soft shadow inside the rim: rings that darken toward it.
	local shadowWidth = math.max(math.floor(radius * STYLE.ShadowWidth), 1)
	for i, transparency in STYLE.Shadow do
		local inner = radius - i * shadowWidth
		local f, stroke = ring(root, transparency)
		f.Position = UDim2.fromOffset(cx, cy)
		f.Size = UDim2.fromOffset(2 * inner, 2 * inner)
		stroke.Thickness = shadowWidth + 1
	end

	-- The black round the lens.
	span(frame(root, BLACK), 0, 0, view.X, cy - radius)
	span(frame(root, BLACK), 0, cy + radius, view.X, view.Y)
	for i = 0, rows - 1 do
		local y0 = -radius + i * rowHeight
		local y1 = y0 + rowHeight
		-- The row's widest chord: at its edge nearest the centre line.
		local nearest = if y0 < 0 and y1 > 0 then 0 else math.min(math.abs(y0), math.abs(y1))
		local half = math.sqrt(math.max(radius * radius - nearest * nearest, 0))
		span(frame(root, BLACK), 0, cy + y0, cx - half, cy + y1)
		span(frame(root, BLACK), cx + half, cy + y0, view.X, cy + y1)
	end
	-- The rim: covers the strips' stair-steps (at most a row deep) and a little of the lens.
	local rimInner = radius - 2
	local rim, rimStroke = ring(root, 0)
	rim.Position = UDim2.fromOffset(cx, cy)
	rim.Size = UDim2.fromOffset(2 * rimInner, 2 * rimInner)
	rimStroke.Thickness = math.ceil(rowHeight) + 4

	laidOutFor = view
	shown = -1
	blinked = -1
end

local function screen(): ScreenGui
	local existing = gui
	if existing then
		return existing
	end
	local made = Instance.new("ScreenGui")
	made.Name = "ScopeView"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	made.DisplayOrder = -1
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = made
	return made
end

-- Draws the picture `shade` up (0 none, 1 fully), the lens `blink` black (0..1).
function ScopeView.set(shade: number, blink: number)
	if shade <= 0 then
		local existing = gui
		if existing and existing.Enabled then
			existing.Enabled = false
		end
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local root = screen()
	if laidOutFor ~= camera.ViewportSize then
		layout(root, camera.ViewportSize)
	end
	root.Enabled = true
	if shade ~= shown then
		shown = shade
		for _, piece in pieces do
			local transparency = 1 - (1 - piece.base) * shade
			local stroke = piece.stroke
			if stroke then
				stroke.Transparency = transparency
			else
				piece.frame.BackgroundTransparency = transparency
			end
		end
	end
	local disc = blinkDisc
	if disc and blink ~= blinked then
		blinked = blink
		disc.BackgroundTransparency = 1 - math.clamp(blink, 0, 1)
	end
end

return ScopeView
