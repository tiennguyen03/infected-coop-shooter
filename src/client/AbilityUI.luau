--!strict
-- Abilities, top left under the health stack (HUD language: HudTheme; after Prototype 2's
-- power circles): four circles, Q Dash, E Breach, 1 and 2 the call-ins. Ready: a white
-- outline and the key letter. Cooling: a white fill rises from the bottom and the seconds
-- show under the circle. Call-ins carry their charges as small squares under the circle
-- (yellow on, dim off) and dim out when empty. A small white diamond on a circle marks a
-- field upgrade in that slot. Momentum stacks read below the resupply meter.
-- Ability cooldowns come from the AbilityUsed remote (server authority), call-in charges from
-- the CallIn<n>Charges / CallIn<n>ReadyAt attributes; display only, refreshed at 15 Hz and
-- written only when a value changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)

local AbilityUI = {}

local C = HudTheme.Color
local CIRCLE = 38
local GAP = 8
local MAX_PIPS = 3
local TOP = 44 -- under the health stack

type Circle = {
	frame: Frame,
	stroke: UIStroke,
	letter: TextLabel,
	caption: TextLabel,
	fill: UIGradient,
	fillFrame: Frame,
	pips: { Frame },
	upgrade: Frame,
	name: string,
	readyUntil: number,
	shown: { [string]: any }, -- last written values (write only on change)
}

local circles: { [string]: Circle } = {}
local momentumLabel: TextLabel

local function setIf(circle: Circle, key: string, value: any, apply: () -> ())
	if circle.shown[key] ~= value then
		circle.shown[key] = value
		apply()
	end
end

local function makeCircle(parent: Frame, key: string, name: string, order: number): Circle
	local frame =
		HudTheme.rect(parent, UDim2.fromOffset(CIRCLE, CIRCLE), C.Track, HudTheme.TrackTransparency)
	frame.Position = UDim2.fromOffset(order * (CIRCLE + GAP), 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.White
	stroke.Transparency = 0.6
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	-- The cooldown fill: a white disc whose gradient shows only the bottom `fraction`.
	local fillFrame = HudTheme.rect(frame, UDim2.fromScale(1, 1), C.White, 0)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fillFrame
	local fill = Instance.new("UIGradient")
	fill.Rotation = -90
	fill.Transparency = NumberSequence.new(1)
	fill.Parent = fillFrame

	local letter = HudTheme.label(frame, { text = key, font = HudTheme.Font.Headline, size = 16 })
	letter.AutomaticSize = Enum.AutomaticSize.None
	letter.Size = UDim2.fromScale(1, 1)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	letter.ZIndex = 3

	local caption = HudTheme.label(frame, { text = name, font = HudTheme.Font.Body, size = 11 })
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, 7)
	caption.Size = UDim2.fromOffset(CIRCLE + GAP, 12)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.Visible = not HudTheme.isTouch()

	local pips = {}
	for index = 1, MAX_PIPS do
		local pip = HudTheme.rect(frame, UDim2.fromOffset(6, 3), C.TextDim)
		pip.AnchorPoint = Vector2.new(0.5, 0)
		pip.Position = UDim2.new(0.5, (index - 2) * 9, 1, 2)
		pip.Visible = false
		table.insert(pips, pip)
	end

	local upgrade = HudTheme.rect(frame, UDim2.fromOffset(6, 6), C.White)
	upgrade.AnchorPoint = Vector2.new(0.5, 0.5)
	upgrade.Position = UDim2.new(1, -3, 0, 3)
	upgrade.Rotation = 45
	upgrade.Visible = false
	upgrade.ZIndex = 4

	return {
		frame = frame,
		stroke = stroke,
		letter = letter,
		caption = caption,
		fill = fill,
		fillFrame = fillFrame,
		pips = pips,
		upgrade = upgrade,
		name = name,
		readyUntil = 0,
		shown = {},
	}
end

-- The white fill rising from the bottom: `fraction` of the cooldown still to run.
local function setFill(circle: Circle, fraction: number)
	local step = math.floor(math.clamp(fraction, 0, 1) * 40 + 0.5) / 40
	setIf(circle, "fill", step, function()
		if step <= 0 then
			circle.fill.Transparency = NumberSequence.new(1)
		elseif step >= 1 then
			circle.fill.Transparency = NumberSequence.new(0.55)
		else
			circle.fill.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(step, 0.55),
				NumberSequenceKeypoint.new(math.min(step + 0.001, 1), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end)
end

local function setReady(circle: Circle, ready: boolean, empty: boolean)
	setIf(
		circle,
		"ready",
		if empty then "empty" elseif ready then "ready" else "cooling",
		function()
			circle.letter.TextColor3 = if ready then C.Text else C.TextDim
			circle.stroke.Transparency = if ready then 0.6 else 0.85
			circle.frame.BackgroundTransparency = if empty then 0.6 else HudTheme.TrackTransparency
			if ready then
				-- The ready flash: the outline goes red, then back to white.
				circle.stroke.Color = C.RedLight
				circle.stroke.Transparency = 0
				task.delay(0.25, function()
					circle.stroke.Color = C.White
					circle.stroke.Transparency = 0.6
				end)
			end
		end
	)
end

local function setCaption(circle: Circle, text: string)
	setIf(circle, "caption", text, function()
		circle.caption.Text = text
	end)
end

local function updateAbility(circle: Circle, now: number, cooldown: number)
	local remaining = circle.readyUntil - now
	if remaining > 0 then
		setReady(circle, false, false)
		setFill(circle, remaining / math.max(cooldown, 0.01))
		setCaption(circle, string.format("%.0fs", math.ceil(remaining)))
	else
		setReady(circle, true, false)
		setFill(circle, 0)
		setCaption(circle, circle.name)
	end
end

local function updateCallIn(circle: Circle, slot: number)
	local player = Players.LocalPlayer
	local definition =
		CallInDefinitions.get(player:GetAttribute(Attributes.callIn(slot)) :: string?)
	if not definition then
		circle.frame.Visible = false
		return
	end
	circle.frame.Visible = true
	local cfg = (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	local charges = (player:GetAttribute(Attributes.callInCharges(slot)) :: number?) or 0
	local readyAt = (player:GetAttribute(Attributes.callInReadyAt(slot)) :: number?) or 0
	local remaining = readyAt - workspace:GetServerTimeNow()
	circle.name = definition.Name
	for index, pip in circle.pips do
		local visible = index <= cfg.Charges
		local color = if index <= charges then C.Yellow else C.TextDim
		setIf(circle, "pip" .. index, `{visible}{index <= charges}`, function()
			pip.Visible = visible
			pip.BackgroundColor3 = color
		end)
	end
	if charges > 0 then
		setReady(circle, true, false)
		setFill(circle, 0)
		setCaption(circle, definition.Name)
	else
		setReady(circle, false, true)
		setFill(circle, if remaining > 0 then remaining / math.max(cfg.Cooldown, 0.01) else 0)
		setCaption(
			circle,
			if remaining > 0 then string.format("%.0fs", math.ceil(remaining)) else "..."
		)
	end
end

local UPGRADE_SLOTS: { [string]: string } =
	{ Dash = "dash", Breach = "breach", CallInA = "callin1", CallInB = "callin2" }
local ABILITY_COOLDOWNS: { [string]: number } = {
	dash = Config.Assault.DashCooldown,
	breach = Config.Assault.BreachCooldown,
}

local function updateUpgradeMarks()
	local player = Players.LocalPlayer
	for slotName, key in UPGRADE_SLOTS do
		local circle = circles[key]
		local upgrade = player:GetAttribute(Attributes.upgrade(slotName))
		if circle then
			circle.upgrade.Visible = typeof(upgrade) == "string" and upgrade ~= ""
		end
	end
end

function AbilityUI.init()
	local gui = HudTheme.gui("AbilityUI")
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(HudTheme.Margin, TOP)
	row.Size = UDim2.fromOffset(4 * CIRCLE + 3 * GAP, CIRCLE + 20)
	row.Parent = gui

	circles.dash = makeCircle(row, "Q", "Dash", 0)
	circles.breach = makeCircle(row, "E", "Breach", 1)
	circles.callin1 = makeCircle(row, "1", "", 2)
	circles.callin2 = makeCircle(row, "2", "", 3)

	momentumLabel = HudTheme.label(gui, { size = 14, color = C.Yellow })
	momentumLabel.Position = UDim2.fromOffset(HudTheme.Margin, 132)

	HudTheme.parent(gui)

	Remotes.get("AbilityUsed").OnClientEvent:Connect(function(name: string, cooldown: unknown)
		local circle = circles[name]
		if circle and typeof(cooldown) == "number" then
			circle.readyUntil = os.clock() + cooldown
			circle.shown.cooldown = cooldown
		end
	end)
	local player = Players.LocalPlayer
	for _, slotName in { "Dash", "Breach", "CallInA", "CallInB" } do
		player:GetAttributeChangedSignal(Attributes.upgrade(slotName)):Connect(updateUpgradeMarks)
	end
	updateUpgradeMarks()

	local lastClock = os.clock()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 15 then
			return
		end
		accumulator = 0
		local now = os.clock()
		local step = now - lastClock
		lastClock = now
		-- Freeze the countdown while the field is frozen (run end), as the server does.
		local paused = workspace:GetAttribute(Attributes.GamePaused) == true
		for key, cooldown in ABILITY_COOLDOWNS do
			local circle = circles[key]
			if paused and circle.readyUntil > now then
				circle.readyUntil += step
			end
			updateAbility(circle, now, (circle.shown.cooldown :: number?) or cooldown)
		end
		updateCallIn(circles.callin1, 1)
		updateCallIn(circles.callin2, 2)
		local stacks = (player:GetAttribute(Attributes.MomentumStacks) :: number?) or 0
		local text = if stacks > 0 then `MOMENTUM x{stacks}` else ""
		if momentumLabel.Text ~= text then
			momentumLabel.Text = text
		end
	end)
end

return AbilityUI
