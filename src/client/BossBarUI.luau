--!strict
-- The Index boss bar (Sprint 19): top centre while the Warden is up. The body bar, six
-- plate pips (full -> cracked at Config.Index.Warden.CrackFraction -> gone) and the tell
-- line: the handset's words before each attack (BossUpdate "tell"). Driven entirely by the
-- BossUpdate remote: ("show", name, plateNames) | ("state", bodyFraction, plateFractions,
-- phase) | ("tell", kind) | ("hide"). Asks the server for the state on boot (late join).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local BossBarUI = {}

-- STYLES.md palette: wound for the body, gun.l for a plate, objective yellow for a crack
-- and the tell line, friendly blue for the stun, the standard panel grey.
local BODY_COLOR = Color3.fromHex("c4464a") -- wound
local PLATE_COLOR = Color3.fromHex("8f969c") -- gun.l
local CRACK_COLOR = Color3.fromHex("e6bd60") -- objective yellow
local TELL_COLOR = Color3.fromHex("e6bd60")
local STUN_COLOR = Color3.fromHex("3fa7d6") -- friendly blue
local PANEL_COLOR = Color3.fromRGB(28, 30, 34)
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

local frame: Frame
local nameLabel: TextLabel
local bodyFill: Frame
local tellLabel: TextLabel
local pipRow: Frame
local pips: { { holder: Frame, fill: Frame, label: TextLabel } } = {}
local tellGeneration = 0

local function makePip(name: string): { holder: Frame, fill: Frame, label: TextLabel }
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1 / 6, -4, 1, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = pipRow

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.fromOffset(0, 0)
	track.BackgroundColor3 = Color3.fromRGB(44, 46, 52)
	track.BorderSizePixel = 0
	track.Parent = holder

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = PLATE_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = track

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 12)
	label.Position = UDim2.fromOffset(0, 10)
	label.BackgroundTransparency = 1
	label.Text = PLATE_LABELS[name] or string.upper(name)
	label.TextColor3 = TEXT_COLOR
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Parent = holder
	return { holder = holder, fill = fill, label = label }
end

local function show(name: string, plateNames: { string })
	nameLabel.Text = string.upper(name)
	for _, pip in pips do
		pip.holder:Destroy()
	end
	table.clear(pips)
	for _, plateName in plateNames do
		table.insert(pips, makePip(plateName))
	end
	bodyFill.Size = UDim2.fromScale(1, 1)
	tellLabel.Text = ""
	frame.Visible = true
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

local function tell(kind: string)
	tellGeneration += 1
	local generation = tellGeneration
	tellLabel.Text = TELL_TEXT[kind] or string.upper(kind)
	tellLabel.TextColor3 = if kind == "stun" then STUN_COLOR else TELL_COLOR
	tellLabel.TextTransparency = 0
	local hold = if kind == "stun"
		then Config.Index.Warden.Charge.WallStun
		else Config.Index.Warden.TellHold
	task.delay(hold, function()
		if generation == tellGeneration then
			TweenService:Create(tellLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

local function hide()
	frame.Visible = false
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
	if kind == "show" then
		show(...)
	elseif kind == "state" then
		state(...)
	elseif kind == "tell" then
		tell(...)
	elseif kind == "zone" then
		zone(...)
	elseif kind == "hide" then
		hide()
		if zonePart then
			zonePart:Destroy()
			zonePart = nil
		end
	end
end

function BossBarUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBarUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the loadout rows (slots end near y 136) and clear of the objective panel's spot.
	frame.Position = UDim2.new(0.5, 0, 0, 148)
	frame.Size = UDim2.fromOffset(440, 92)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(10, 4)
	nameLabel.Size = UDim2.new(1, -20, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "THE WARDEN"
	nameLabel.TextColor3 = BODY_COLOR
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Parent = frame

	local bodyTrack = Instance.new("Frame")
	bodyTrack.Position = UDim2.fromOffset(10, 28)
	bodyTrack.Size = UDim2.new(1, -20, 0, 12)
	bodyTrack.BackgroundColor3 = Color3.fromRGB(44, 46, 52)
	bodyTrack.BorderSizePixel = 0
	bodyTrack.Parent = frame

	bodyFill = Instance.new("Frame")
	bodyFill.Size = UDim2.fromScale(1, 1)
	bodyFill.BackgroundColor3 = BODY_COLOR
	bodyFill.BorderSizePixel = 0
	bodyFill.Parent = bodyTrack

	pipRow = Instance.new("Frame")
	pipRow.Position = UDim2.fromOffset(10, 46)
	pipRow.Size = UDim2.new(1, -20, 0, 22)
	pipRow.BackgroundTransparency = 1
	pipRow.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipRow

	tellLabel = Instance.new("TextLabel")
	tellLabel.Position = UDim2.fromOffset(10, 70)
	tellLabel.Size = UDim2.new(1, -20, 0, 18)
	tellLabel.BackgroundTransparency = 1
	tellLabel.Text = ""
	tellLabel.TextColor3 = TELL_COLOR
	tellLabel.TextSize = 13
	tellLabel.Font = Enum.Font.GothamBold
	tellLabel.Parent = frame

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local remote = Remotes.get("BossUpdate")
	remote.OnClientEvent:Connect(onUpdate)
	remote:FireServer()
end

return BossBarUI
