--!strict
-- The Index boss bar (Sprint 19): top right while the Warden is up (HudTheme language). The body bar, six
-- plate pips (full -> cracked at Config.Index.Warden.CrackFraction -> gone) and the tell
-- line: the handset's words before each attack (BossUpdate "tell"). Driven entirely by the
-- BossUpdate remote: ("show", name, plateNames) | ("state", bodyFraction, plateFractions,
-- phase) | ("tell", kind) | ("hide"). Asks the server for the state on boot (late join).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local BuffNoticeUI = require(script.Parent.BuffNoticeUI)
local HudTheme = require(script.Parent.HudTheme)

local BossBarUI = {}

-- STYLES.md palette: wound for the body, gun.l for a plate, objective yellow for a crack
-- and the tell line, friendly blue for the stun, the standard panel grey.
local BODY_COLOR = Color3.fromHex("c4464a") -- wound
local PLATE_COLOR = Color3.fromHex("8f969c") -- gun.l
local CRACK_COLOR = Color3.fromHex("e6bd60") -- objective yellow
local TELL_COLOR = Color3.fromHex("e6bd60")
local STUN_COLOR = Color3.fromHex("3fa7d6") -- friendly blue
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local DIM_TEXT = Color3.fromRGB(120, 120, 124)

local PLATE_LABELS: { [string]: string } = {
	Helmet = "HELM",
	Chest = "CHEST",
	Back = "BACK",
	ShoulderL = "L SHLD",
	ShoulderR = "R SHLD",
	Shield = "SHIELD",
}

local TELL_TEXT: { [string]: string } = {
	bash = "...hands. Show me your hands. Hands...",
	charge = "...move back. Move back. Clear the lane...",
	canister = "...gas. Gas in the lane...",
	riot = "...all posts, Gate. Crowd at the wire. Send the reserve...",
	guard = "GUARD UP: flank him",
	stun = "STUNNED",
	["break"] = "PLATE OFF",
	-- Kit expansion (placeholders in the MP's voice until the lore pass).
	pound = "...GET DOWN. Get down, get down...",
	sweep = "...clear the lane. CLEAR THE LANE...",
	slam = "...hold still. HOLD STILL...",
	stomp = "...off the wire. OFF THE WIRE...",
}

local frame: Frame = nil :: any
local nameLabel: TextLabel = nil :: any
local bodyFill: Frame = nil :: any
local emblemStroke: UIStroke = nil :: any
local pipRow: Frame = nil :: any
local pips: { { holder: Frame, fill: Frame, label: TextLabel } } = {}
local stunUntil = 0

local C = HudTheme.Color
local BAR_WIDTH = 380
local PLATE_WIDTH = 56

local function makePip(
	name: string,
	order: number
): { holder: Frame, fill: Frame, label: TextLabel }
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(PLATE_WIDTH, 20)
	holder.LayoutOrder = order
	holder.Parent = pipRow
	local track =
		HudTheme.rect(holder, UDim2.fromOffset(PLATE_WIDTH, 6), C.Track, HudTheme.TrackTransparency)
	local fill = HudTheme.rect(track, UDim2.fromScale(1, 1), PLATE_COLOR)
	local label = HudTheme.label(holder, {
		text = PLATE_LABELS[name] or string.upper(name),
		font = HudTheme.Font.Line,
		size = 11,
	})
	label.Position = UDim2.fromOffset(0, 8)
	return { holder = holder, fill = fill, label = label }
end

local function show(name: string, plateNames: { string })
	nameLabel.Text = string.upper(name)
	for _, pip in pips do
		pip.holder:Destroy()
	end
	table.clear(pips)
	for index, plateName in plateNames do
		table.insert(pips, makePip(plateName, index))
	end
	bodyFill.Size = UDim2.fromScale(1, 1)
	frame.Visible = true
	BuffNoticeUI.setCardTop(120)
end

local function state(bodyFraction: number, plateFractions: { number }, _phase: number)
	bodyFill.Size = UDim2.fromScale(math.clamp(bodyFraction, 0, 1), 1)
	local crackAt = Config.Index.Warden.CrackFraction
	for index, pip in pips do
		local fraction = plateFractions[index] or 0
		pip.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if fraction <= 0 then
			pip.fill.BackgroundColor3 = PLATE_COLOR
			pip.label.TextColor3 = DIM_TEXT
		elseif fraction <= crackAt then
			pip.fill.BackgroundColor3 = CRACK_COLOR
			pip.label.TextColor3 = CRACK_COLOR
		else
			pip.fill.BackgroundColor3 = PLATE_COLOR
			pip.label.TextColor3 = TEXT_COLOR
		end
	end
end

-- The handset's words before each attack, as a subtitle under the mission line; a stun
-- turns the emblem blue for its length.
local function tell(kind: string)
	local stun = kind == Messages.BossTell.Stun
	local text = TELL_TEXT[kind] or string.upper(kind)
	local hold = if stun then Config.Index.Warden.Charge.WallStun else Config.Index.Warden.TellHold
	local speaker = if string.sub(text, 1, 3) == "..." then "Handset" else nil
	BuffNoticeUI.subtitle(speaker, text, if stun then STUN_COLOR else TELL_COLOR, hold)
	if stun then
		stunUntil = os.clock() + hold
		emblemStroke.Color = STUN_COLOR
		task.delay(hold, function()
			if os.clock() >= stunUntil then
				emblemStroke.Color = C.RedLight
			end
		end)
	end
end

local function hide()
	frame.Visible = false
	BuffNoticeUI.setCardTop(12)
end

-- The Pound's ring on the ground through its windup: one flat cylinder, no particles.
local zonePart: BasePart? = nil
local function zone(position: Vector3, radius: number, seconds: number)
	if zonePart then
		zonePart:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "BossZone"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = TELL_COLOR
	part.Transparency = 0.55
	part.Parent = workspace
	zonePart = part
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 0.15 }):Play()
	task.delay(seconds + 0.15, function()
		if zonePart == part then
			zonePart = nil
		end
		part:Destroy()
	end)
end

local function onUpdate(kind: string, ...: any)
	if kind == Messages.BossUpdate.Show then
		show(...)
	elseif kind == Messages.BossUpdate.State then
		state(...)
	elseif kind == Messages.BossUpdate.Tell then
		tell(...)
	elseif kind == Messages.BossUpdate.Zone then
		zone(...)
	elseif kind == Messages.BossUpdate.Hide then
		hide()
		if zonePart then
			zonePart:Destroy()
			zonePart = nil
		end
	end
end

-- Top right, mirroring the player's health stack (HudTheme; after Prototype 2's boss bar):
-- the name right-aligned in red, a faceted red body bar ending in a round emblem, the six
-- plates as small bars under it.
function BossBarUI.init()
	local gui = HudTheme.gui("BossBarUI", 11)
	frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -HudTheme.Margin, 0, 12)
	frame.Size = UDim2.fromOffset(BAR_WIDTH + 44, 92)
	frame.Visible = false
	frame.Parent = gui

	nameLabel = HudTheme.label(frame, {
		text = "THE WARDEN",
		font = HudTheme.Font.Headline,
		size = 16,
		color = C.RedLight,
		align = Enum.TextXAlignment.Right,
	})
	nameLabel.AnchorPoint = Vector2.new(1, 0)
	nameLabel.Position = UDim2.new(1, -44, 0, 0)

	local track = HudTheme.rect(
		frame,
		UDim2.fromOffset(BAR_WIDTH, 16),
		C.Track,
		HudTheme.TrackTransparency,
		true
	)
	track.AnchorPoint = Vector2.new(1, 0)
	track.Position = UDim2.new(1, -44, 0, 22)
	bodyFill = HudTheme.rect(track, UDim2.fromScale(1, 1), BODY_COLOR)
	bodyFill.AnchorPoint = Vector2.new(1, 0)
	bodyFill.Position = UDim2.fromScale(1, 0)
	HudTheme.facet(bodyFill, C.RedLight, C.Red)

	local emblem = HudTheme.rect(frame, UDim2.fromOffset(34, 34), C.Track, 0.2)
	emblem.AnchorPoint = Vector2.new(1, 0)
	emblem.Position = UDim2.new(1, 0, 0, 13)
	local emblemCorner = Instance.new("UICorner")
	emblemCorner.CornerRadius = UDim.new(1, 0)
	emblemCorner.Parent = emblem
	emblemStroke = Instance.new("UIStroke")
	emblemStroke.Color = C.RedLight
	emblemStroke.Thickness = 2
	emblemStroke.Parent = emblem
	local glyph = HudTheme.label(
		emblem,
		{ text = "W", font = HudTheme.Font.Headline, size = 16, color = C.RedLight }
	)
	glyph.AutomaticSize = Enum.AutomaticSize.None
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center

	pipRow = Instance.new("Frame")
	pipRow.BackgroundTransparency = 1
	pipRow.AnchorPoint = Vector2.new(1, 0)
	pipRow.Position = UDim2.new(1, -44, 0, 44)
	pipRow.Size = UDim2.fromOffset(BAR_WIDTH, 22)
	pipRow.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipRow

	HudTheme.parent(gui)
	local remote = Remotes.get("BossUpdate")
	remote.OnClientEvent:Connect(onUpdate)
	remote:FireServer()
end

return BossBarUI
