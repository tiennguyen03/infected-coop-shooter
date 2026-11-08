--!strict
-- Resupply on the client: the HUD meter top left under the abilities (pool / cost, "[5] FLARE" when it
-- covers the cost, the drop countdown while a pallet is inbound; a short pulse when a kill
-- feeds the pool) and the world cards. When a crate lands the server sends this player
-- their own card ids (supply cards on a pallet, field upgrades on an upgrade crate:
-- UpgradeDefinitions) and the card positions; this module stands a card at each as a
-- billboard anchored to a local part and picks the one the player walks into. Other
-- players see their own cards at the same spots. Nothing here pauses the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UpgradeDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local HudTheme = require(script.Parent.HudTheme)
local BuffNoticeUI = require(script.Parent.BuffNoticeUI)

local C = HudTheme.Color

local CARD_STUDS = Vector2.new(2.6, 3.4) -- billboard size in studs
local SUPPLY_COLOR = Color3.fromRGB(107, 122, 74)
local UPGRADE_COLOR = Color3.fromRGB(63, 167, 214)
local CALL_NOTICE_SECONDS = 3
local GAIN_PULSE_SECONDS = 0.35

type Card = { cardId: string, anchor: BasePart, position: Vector3 }
type CrateCards = { id: number, cards: { Card }, pickSent: boolean }

local ResupplyUI = {}

local resupplyRemote: RemoteEvent
local fill: Frame
local label: TextLabel
local noticeUntil = 0
local noticeText = ""
local lastPool = 0
local gainPulseUntil = 0
local worldFolder: Folder
local openCrates: { [number]: CrateCards } = {}

----------------------------------------------------------------------
-- HUD meter
----------------------------------------------------------------------

local function setText(text: string, color: Color3)
	if label.Text ~= text then
		label.Text = text
	end
	if label.TextColor3 ~= color then
		label.TextColor3 = color
	end
end

local function updateMeter()
	local pool = (workspace:GetAttribute(Attributes.ResupplyPool) :: number?) or 0
	local cost = (workspace:GetAttribute(Attributes.ResupplyCost) :: number?) or 1
	local dropIn = (workspace:GetAttribute(Attributes.ResupplyDropIn) :: number?) or -1
	local now = os.clock()
	if pool > lastPool then
		gainPulseUntil = now + GAIN_PULSE_SECONDS
	end
	lastPool = pool

	if dropIn >= 0 then
		-- Inbound: the bar drains to the landing.
		fill.Size = UDim2.fromScale(math.clamp(dropIn / Config.Requisition.DropDelay, 0, 1), 1)
		fill.BackgroundColor3 = C.Yellow
		if now < noticeUntil then
			setText(noticeText, C.Yellow)
		else
			setText(`PALLET 0:{string.format("%02d", math.ceil(dropIn))}`, C.Yellow)
		end
		return
	end
	local ratio = math.clamp(pool / math.max(cost, 1), 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
	if pool >= cost then
		-- Ready: the bar pulses so the eye finds it without a pop-up.
		local pulse = 0.5 + 0.5 * math.sin(now * 4)
		fill.BackgroundColor3 = C.Yellow:Lerp(C.White, pulse)
		setText(`RESUPPLY READY  {HudTheme.tint("[5] FLARE", C.Yellow)}`, C.Text)
	else
		-- A kill just fed the pool: a brief brighten.
		local gain = math.clamp((gainPulseUntil - now) / GAIN_PULSE_SECONDS, 0, 1)
		fill.BackgroundColor3 = C.TextDim:Lerp(C.White, gain)
		setText(`RESUPPLY {math.floor(pool)}/{cost}`, C.Text)
	end
end

-- Top left under the ability circles (HudTheme): a 14 pt line and a thin bar with ticks at
-- the quarters; no panel.
local function createMeter()
	local gui = HudTheme.gui("ResupplyUI")
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(HudTheme.Margin, 108)
	root.Size = UDim2.fromOffset(240, 24)
	root.Parent = gui

	label = HudTheme.label(root, { size = 14, rich = true })
	label.Text = `RESUPPLY 0/{Config.Requisition.BaseCost}`

	local bar = HudTheme.rect(root, UDim2.fromOffset(240, 4), C.Track, HudTheme.TrackTransparency)
	bar.Position = UDim2.fromOffset(0, 19)
	fill = HudTheme.rect(bar, UDim2.fromScale(0, 1), C.TextDim)
	for _, quarter in { 0.25, 0.5, 0.75 } do
		local tick = HudTheme.rect(bar, UDim2.fromOffset(1, 6), C.White, 0.4)
		tick.Position = UDim2.new(quarter, 0, 0, -1)
	end

	HudTheme.parent(gui)
end

----------------------------------------------------------------------
-- World cards
----------------------------------------------------------------------

-- The kind tag line: "SUPPLY" on a pallet card, the upgrade's slot on a field upgrade.
local function kindLine(definition: UpgradeDefinitions.CardDefinition): (string, Color3)
	if definition.Kind == "supply" then
		return "SUPPLY", SUPPLY_COLOR
	end
	local slot = definition.Slot or "UPGRADE"
	if definition.Slot == "CallIn" then
		slot = definition.CallIn or "CallIn"
	end
	return string.upper(`{slot} UPGRADE`), UPGRADE_COLOR
end

local function buildCardFace(parent: BillboardGui, definition: UpgradeDefinitions.CardDefinition)
	local kindText, kindColor = kindLine(definition)

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = kindColor:Lerp(Color3.fromRGB(28, 30, 34), 0.82)
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = kindColor
	stroke.Thickness = 2
	stroke.Parent = card

	local kindLabel = Instance.new("TextLabel")
	kindLabel.Size = UDim2.fromScale(1, 0.07)
	kindLabel.Position = UDim2.fromScale(0, 0.02)
	kindLabel.BackgroundTransparency = 1
	kindLabel.Text = kindText
	kindLabel.TextColor3 = kindColor
	kindLabel.TextScaled = true
	kindLabel.Font = Enum.Font.GothamBold
	kindLabel.Parent = card

	local icon: GuiObject
	if definition.IconId then
		local image = Instance.new("ImageLabel")
		image.Image = definition.IconId
		image.BackgroundTransparency = 1
		icon = image
	else
		local plate = Instance.new("TextLabel")
		plate.Text = definition.Abbrev
		plate.TextColor3 = Color3.fromRGB(240, 240, 240)
		plate.TextScaled = true
		plate.Font = Enum.Font.GothamBlack
		plate.BackgroundColor3 = definition.Color
		icon = plate
	end
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.11)
	icon.Size = UDim2.fromScale(0.38, 0.29)
	icon.BorderSizePixel = 0
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.1, 0)
	iconCorner.Parent = icon
	icon.Parent = card

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromScale(0.05, 0.42)
	name.Size = UDim2.fromScale(0.9, 0.12)
	name.BackgroundTransparency = 1
	name.Text = definition.Name
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextScaled = true
	name.TextWrapped = true
	name.Font = Enum.Font.GothamBold
	name.Parent = card

	local description = Instance.new("TextLabel")
	description.Position = UDim2.fromScale(0.06, 0.56)
	description.Size = UDim2.fromScale(0.88, 0.34)
	description.BackgroundTransparency = 1
	description.Text = definition.Description
	description.TextColor3 = Color3.fromRGB(190, 190, 190)
	description.TextScaled = true
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Font = Enum.Font.Gotham
	description.Parent = card

	card.Parent = parent
end

local function buildCard(definition: UpgradeDefinitions.CardDefinition, position: Vector3): Card
	local _, kindColor = kindLine(definition)

	-- The anchor: a thin glowing base plate on the ground in the kind colour.
	local anchor = Instance.new("Part")
	anchor.Name = definition.Id
	anchor.Shape = Enum.PartType.Cylinder
	anchor.Size = Vector3.new(0.2, 2.2, 2.2)
	anchor.CFrame = CFrame.new(position - Vector3.new(0, 2 - 0.1, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Material = Enum.Material.Neon
	anchor.Color = kindColor
	anchor.Transparency = 0.35
	anchor.Parent = worldFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(CARD_STUDS.X, CARD_STUDS.Y)
	billboard.StudsOffset = Vector3.new(0, CARD_STUDS.Y / 2 + 0.3, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Adornee = anchor
	buildCardFace(billboard, definition)
	billboard.Parent = anchor

	return { cardId = definition.Id, anchor = anchor, position = position }
end

local function closeCards(crateId: number, taken: string?)
	local crate = openCrates[crateId]
	if not crate then
		return
	end
	openCrates[crateId] = nil
	for _, card in crate.cards do
		if taken and card.cardId == taken then
			-- The one we took: flash and go.
			card.anchor.Transparency = 0
			task.delay(0.25, function()
				card.anchor:Destroy()
			end)
		else
			local fade = TweenService:Create(card.anchor, TweenInfo.new(0.4), { Transparency = 1 })
			fade:Play()
			fade.Completed:Once(function()
				card.anchor:Destroy()
			end)
		end
	end
end

local function showCards(
	crateId: number,
	_kind: string,
	choices: { string },
	positions: { Vector3 }
)
	closeCards(crateId)
	local crate: CrateCards = { id = crateId, cards = {}, pickSent = false }
	for index, cardId in choices do
		local position = positions[index]
		local definition = UpgradeDefinitions.get(cardId)
		if position and definition then
			table.insert(crate.cards, buildCard(definition, position))
		end
	end
	openCrates[crateId] = crate
end

-- Walk into a card to take it: ask the server once, it confirms with "picked".
local function checkPicks()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	for _, crate in openCrates do
		if crate.pickSent then
			continue
		end
		for _, card in crate.cards do
			local flat =
				Vector3.new(root.Position.X - card.position.X, 0, root.Position.Z - card.position.Z)
			if flat.Magnitude <= Config.Requisition.PickRadius then
				crate.pickSent = true
				resupplyRemote:FireServer(Messages.Resupply.Pick, crate.id, card.cardId)
				-- Optimistic: fade the others now; the server's "picked" clears the rest.
				closeCards(crate.id, card.cardId) -- the pouch sound is the server's (card_pick)
				break
			end
		end
	end
end

local function clearAll()
	for crateId in openCrates do
		closeCards(crateId)
	end
end

function ResupplyUI.init()
	resupplyRemote = Remotes.get("Resupply")
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "ResupplyCards"
	worldFolder.Parent = workspace
	createMeter()

	resupplyRemote.OnClientEvent:Connect(function(kind: string, ...: any)
		if kind == Messages.Resupply.Cards then
			showCards(...)
		elseif kind == Messages.Resupply.Picked or kind == Messages.Resupply.Closed then
			local crateId = ...
			closeCards(crateId)
		elseif kind == Messages.Resupply.Called then
			local thrower = ...
			noticeText = if thrower == Players.LocalPlayer:GetAttribute(Attributes.Callsign)
				then "FLARE OUT · PALLET INBOUND"
				else `{string.upper(thrower)} CALLED SUPPLY`
			noticeUntil = os.clock() + CALL_NOTICE_SECONDS
			BuffNoticeUI.card(noticeText)
		end
	end)

	Players.LocalPlayer.CharacterAdded:Connect(clearAll)
	RunService.Heartbeat:Connect(function()
		updateMeter()
		checkPicks()
	end)
end

return ResupplyUI
