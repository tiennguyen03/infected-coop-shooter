--!strict
-- Resupply on the client: the HUD meter top left under the abilities (pool / cost, "[X] FLARE" (Config.Keys.Flare) when it
-- covers the cost, the drop countdown while a pallet is inbound; a short pulse when a kill
-- feeds the pool) and the crate's cards. When a crate lands the server sends this player
-- their own card ids (supply cards on a pallet, field upgrades on an upgrade or objective
-- crate: UpgradeDefinitions). The player walks up, holds the crate's prompt and picks from
-- a panel (RewardPanel; owner 2026-11-11: never by walking over a card); walking away,
-- going down or the crate closing shuts the panel without a pick. Nothing here pauses the
-- game. Config.Requisition.Pick.WalkOver = true brings back the old way: a small card
-- billboard at each card position, taken by walking into it.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local KeyBindings = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("KeyBindings")
)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Reward =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Reward"))
local UpgradeDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local HudTheme = require(script.Parent.HudTheme)
local BuffNoticeUI = require(script.Parent.BuffNoticeUI)
local CameraController = require(script.Parent.CameraController)
local RewardPanel = require(script.Parent.RewardPanel)

local FLARE_HINT = `[{KeyBindings.label(Config.Keys.Flare.Name)}] FLARE`

local C = HudTheme.Color

local CARD_STUDS = Vector2.new(2.6, 3.4) -- billboard size in studs
local SUPPLY_COLOR = Color3.fromRGB(107, 122, 74)
local UPGRADE_COLOR = Color3.fromRGB(63, 167, 214)
local CALL_NOTICE_SECONDS = 3
local GAIN_PULSE_SECONDS = 0.35

type Card = { cardId: string, anchor: BasePart, position: Vector3 }
type CrateCards = { id: number, cards: { Card }, pickSent: boolean }

-- This player's cards on a crate (the panel's content).
type Offer = {
	id: number,
	kind: string,
	choices: { string },
	replaces: { string },
	position: Vector3,
	expiresAt: number, -- os.clock
	picked: boolean,
	taken: { string }, -- callsigns that have taken theirs
	prompt: ProximityPrompt?,
}

-- Why the server refused a pick (Rules/Reward.checkPick), in plain words.
local REFUSALS: { [string]: string } = {
	gone = "THIS CRATE HAS CLOSED.",
	taken = "YOU ALREADY TOOK ONE FROM THIS CRATE.",
	not_offered = "THAT CARD IS NOT ON THIS CRATE.",
	down = "YOU CANNOT PICK WHILE DOWN.",
	far = "TOO FAR FROM THE CRATE. STEP CLOSER.",
}

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
local offers: { [number]: Offer } = {}
local panelCrate: number? = nil -- the crate the panel is open on

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
		setText(`RESUPPLY READY  {HudTheme.tint(FLARE_HINT, C.Yellow)}`, C.Text)
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
-- The panel (hold the crate's prompt, pick from big cards)
----------------------------------------------------------------------

local function kindRow(kind: string): { Label: string, Squad: { [string]: any }? }
	return (Config.Crates.Kinds :: any)[kind] or Config.Crates.Kinds.supply
end

local function setPrompt(offer: Offer, enabled: boolean)
	local prompt = offer.prompt
	if prompt and prompt.Parent then
		-- Local only: the other players' prompt on this crate is theirs.
		prompt.Enabled = enabled
	end
end

local function closePanel()
	if panelCrate then
		RewardPanel.close() -- onClose below puts the prompt back
	end
end

local function openPanel(offer: Offer)
	closePanel()
	local row = kindRow(offer.kind)
	local squad = row.Squad
	panelCrate = offer.id
	setPrompt(offer, false)
	CameraController.setCursorFree("RewardPanel", true)
	RewardPanel.open({
		title = row.Label,
		note = if squad
			then `Pick one. The squad already got: {Reward.effectsLine(squad :: any)}.`
			else "Pick one. Each soldier picks their own.",
		cards = offer.choices,
		replaces = offer.replaces,
		expiresAt = offer.expiresAt,
		taken = offer.taken,
		onPick = function(cardId: string)
			resupplyRemote:FireServer(Messages.Resupply.Pick, offer.id, cardId)
		end,
		onClose = function()
			panelCrate = nil
			CameraController.setCursorFree("RewardPanel", false)
			if not offer.picked then
				setPrompt(offer, true)
			end
		end,
	})
end

-- The crate's prompt was held: open this player's cards on it.
local function onPrompt(prompt: ProximityPrompt)
	local crateId = prompt:GetAttribute(Attributes.CrateId)
	if typeof(crateId) ~= "number" then
		return
	end
	local offer = offers[crateId]
	if not offer or offer.picked then
		prompt.Enabled = false
		BuffNoticeUI.card("NOTHING LEFT HERE", "You already took yours")
		return
	end
	offer.prompt = prompt
	openPanel(offer)
end

local function onPicked(crateId: number, cardId: string?)
	local offer = offers[crateId]
	if not offer then
		return
	end
	offer.picked = true
	setPrompt(offer, false)
	local definition = UpgradeDefinitions.get(cardId)
	if definition then
		-- The pick moment: the card flashes in the panel (the pouch sound is the server's)
		-- and a line under the mission line says what was taken.
		BuffNoticeUI.subtitle(
			nil,
			`<b>{string.upper(definition.Name)}</b> taken. {definition.Description}`,
			C.Yellow,
			5
		)
	end
	if panelCrate == crateId then
		panelCrate = nil
		CameraController.setCursorFree("RewardPanel", false)
		if cardId then
			RewardPanel.confirm(cardId)
		else
			RewardPanel.close(true)
		end
	end
end

local function storeOffer(
	crateId: number,
	kind: string,
	choices: { string },
	cratePosition: Vector3,
	secondsLeft: number,
	replaces: { string }
)
	offers[crateId] = {
		id = crateId,
		kind = kind,
		choices = choices,
		replaces = replaces,
		position = cratePosition,
		expiresAt = os.clock() + secondsLeft,
		picked = false,
		taken = {},
		prompt = nil,
	}
	-- The arrival: say what landed and how to take it.
	local row = kindRow(kind)
	if row.Squad then
		BuffNoticeUI.card("SQUAD RESTOCKED", "Reward crate down: 1 field upgrade each")
	else
		BuffNoticeUI.card(`{row.Label} DOWN`, "Open it at the crate: pick 1")
	end
end

-- The open panel shuts when its player walks off, goes down or dies.
local function watchPanel()
	local crateId = panelCrate
	local offer = if crateId then offers[crateId] else nil
	if not offer then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local standing = character ~= nil
		and root ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and character:GetAttribute(Attributes.SquadState) ~= "Downed"
	local away = root
		and Vector3.new(
				root.Position.X - offer.position.X,
				0,
				root.Position.Z - offer.position.Z
			).Magnitude
			> Config.Requisition.Pick.CloseRadius
	if not standing or away then
		closePanel()
	end
end

----------------------------------------------------------------------
-- World cards (Config.Requisition.Pick.WalkOver: the old way)
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

-- A respawn: the walk-over cards go; the panel shuts but the offers stay to be taken.
local function clearAll()
	for crateId in openCrates do
		closeCards(crateId)
	end
	closePanel()
end

function ResupplyUI.init()
	resupplyRemote = Remotes.get("Resupply")
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "ResupplyCards"
	worldFolder.Parent = workspace
	createMeter()

	resupplyRemote.OnClientEvent:Connect(function(kind: string, ...: any)
		if kind == Messages.Resupply.Cards then
			local crateId, crateKind, choices, positions, cratePosition, secondsLeft, replaces = ...
			if Config.Requisition.Pick.WalkOver then
				showCards(crateId, crateKind, choices, positions)
			else
				storeOffer(crateId, crateKind, choices, cratePosition, secondsLeft, replaces)
			end
		elseif kind == Messages.Resupply.Picked then
			local crateId, cardId = ...
			closeCards(crateId)
			onPicked(crateId, cardId)
		elseif kind == Messages.Resupply.Refused then
			local crateId, reason = ...
			if panelCrate == crateId then
				RewardPanel.refuse(REFUSALS[reason] or "NOT TAKEN. PICK AGAIN.")
			end
		elseif kind == Messages.Resupply.Taken then
			local crateId, names = ...
			local offer = offers[crateId]
			if offer then
				offer.taken = names
				if panelCrate == crateId then
					RewardPanel.setTaken(names)
				end
			end
		elseif kind == Messages.Resupply.Closed then
			local crateId = ...
			closeCards(crateId)
			if panelCrate == crateId then
				closePanel()
			end
			offers[crateId] = nil
		elseif kind == Messages.Resupply.Called then
			local thrower = ...
			noticeText = if thrower == Players.LocalPlayer:GetAttribute(Attributes.Callsign)
				then "FLARE OUT · PALLET INBOUND"
				else `{string.upper(thrower)} CALLED SUPPLY`
			noticeUntil = os.clock() + CALL_NOTICE_SECONDS
			BuffNoticeUI.card(noticeText)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == Players.LocalPlayer then
			onPrompt(prompt)
		end
	end)
	-- A crate this player has already taken from shows them no prompt.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local crateId = prompt:GetAttribute(Attributes.CrateId)
		local offer = if typeof(crateId) == "number" then offers[crateId] else nil
		if offer then
			offer.prompt = prompt
			if offer.picked or panelCrate == offer.id then
				prompt.Enabled = false
			end
		end
	end)

	Players.LocalPlayer.CharacterAdded:Connect(clearAll)
	RunService.Heartbeat:Connect(function()
		updateMeter()
		checkPicks()
		watchPanel()
	end)
end

return ResupplyUI
