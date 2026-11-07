--!strict
-- Resupply on the client: the HUD meter above the XP bar (pool / cost, "[F] FLARE" when it
-- covers the cost, the drop countdown while a pallet is inbound) and the world cards. When a
-- pallet lands the server sends this player their own three item ids and the three card
-- positions; this module stands a card at each as a billboard anchored to a local part and
-- picks the one the player walks into. Other players see their own cards at the same spots.
-- Nothing here pauses the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ItemDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemDefinitions"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundFX = require(script.Parent.SoundFX)

local CARD_STUDS = Vector2.new(2.6, 3.4) -- billboard size in studs
local AMBER = Color3.fromRGB(232, 181, 75)
local READY = Color3.fromRGB(255, 120, 60)
local DIM = Color3.fromRGB(20, 20, 20)
local CALL_NOTICE_SECONDS = 3

type Card = { itemId: string, anchor: BasePart, position: Vector3 }
type CrateCards = { id: number, cards: { Card }, pickSent: boolean }

local ResupplyUI = {}

local resupplyRemote: RemoteEvent
local fill: Frame
local label: TextLabel
local noticeUntil = 0
local noticeText = ""
local worldFolder: Folder
local openCrates: { [number]: CrateCards } = {}

----------------------------------------------------------------------
-- HUD meter
----------------------------------------------------------------------

local function updateMeter()
	local pool = (workspace:GetAttribute("ResupplyPool") :: number?) or 0
	local cost = (workspace:GetAttribute("ResupplyCost") :: number?) or 1
	local dropIn = (workspace:GetAttribute("ResupplyDropIn") :: number?) or -1
	local now = os.clock()

	if dropIn >= 0 then
		fill.Size = UDim2.fromScale(1 - math.clamp(dropIn / Config.Requisition.DropDelay, 0, 1), 1)
		fill.BackgroundColor3 = READY
		label.Text = if now < noticeUntil
			then noticeText
			else `SUPPLY DROP 0:{string.format("%02d", math.ceil(dropIn))}`
		return
	end
	local ratio = math.clamp(pool / math.max(cost, 1), 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
	if pool >= cost then
		-- Ready: a slow pulse so the eye finds it without a pop-up.
		local pulse = 0.5 + 0.5 * math.sin(now * 4)
		fill.BackgroundColor3 = AMBER:Lerp(READY, pulse)
		label.Text = "RESUPPLY READY   [F] FLARE"
	else
		fill.BackgroundColor3 = AMBER
		label.Text = `RESUPPLY {math.floor(pool)} / {cost}`
	end
end

local function createMeter()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResupplyUI"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -76) -- above the HP bar (-50) and the XP bar (-24)
	bar.Size = UDim2.fromOffset(420, 18)
	bar.BackgroundColor3 = DIM
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = AMBER
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "RESUPPLY 0 / 450"
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = bar

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

----------------------------------------------------------------------
-- World cards
----------------------------------------------------------------------

local function buildCardFace(parent: BillboardGui, itemId: string, ownedStacks: number)
	local definition = ItemDefinitions[itemId]
	local rarityName = definition.Rarity or "Common"
	local rarity = Config.ItemRarities[rarityName] or Config.ItemRarities.Common
	local rarityColor = rarity.Color

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(28, 30, 34), 0.82)
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = if rarityName == "Legendary"
		then 4
		elseif rarityName == "Uncommon" then 3
		else 2
	stroke.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.fromScale(1, 0.07)
	rarityLabel.Position = UDim2.fromScale(0, 0.02)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(rarity.DisplayName)
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = card

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
	description.Size = UDim2.fromScale(0.88, 0.3)
	description.BackgroundTransparency = 1
	description.Text = definition.Description
	description.TextColor3 = Color3.fromRGB(190, 190, 190)
	description.TextScaled = true
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Font = Enum.Font.Gotham
	description.Parent = card

	local owned = Instance.new("TextLabel")
	owned.AnchorPoint = Vector2.new(0.5, 1)
	owned.Position = UDim2.fromScale(0.5, 0.97)
	owned.Size = UDim2.fromScale(0.9, 0.07)
	owned.BackgroundTransparency = 1
	owned.Text = if ownedStacks > 0 then `Owned: x{ownedStacks}` else "New"
	owned.TextColor3 = definition.Color
	owned.TextScaled = true
	owned.Font = Enum.Font.GothamBold
	owned.Parent = card

	card.Parent = parent
end

local function buildCard(itemId: string, position: Vector3, ownedStacks: number): Card
	local definition = ItemDefinitions[itemId]
	local rarity = Config.ItemRarities[definition.Rarity or "Common"] or Config.ItemRarities.Common

	-- The anchor: a thin glowing base plate on the ground in the rarity colour.
	local anchor = Instance.new("Part")
	anchor.Name = itemId
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
	anchor.Color = rarity.Color
	anchor.Transparency = 0.35
	anchor.Parent = worldFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(CARD_STUDS.X, CARD_STUDS.Y)
	billboard.StudsOffset = Vector3.new(0, CARD_STUDS.Y / 2 + 0.3, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Adornee = anchor
	buildCardFace(billboard, itemId, ownedStacks)
	billboard.Parent = anchor

	return { itemId = itemId, anchor = anchor, position = position }
end

local function closeCards(crateId: number, taken: string?)
	local crate = openCrates[crateId]
	if not crate then
		return
	end
	openCrates[crateId] = nil
	for _, card in crate.cards do
		if taken and card.itemId == taken then
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
	choices: { string },
	positions: { Vector3 },
	inventory: { [string]: number }
)
	closeCards(crateId)
	local crate: CrateCards = { id = crateId, cards = {}, pickSent = false }
	for index, itemId in choices do
		local position = positions[index]
		if position and ItemDefinitions[itemId] then
			table.insert(crate.cards, buildCard(itemId, position, inventory[itemId] or 0))
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
				resupplyRemote:FireServer("pick", crate.id, card.itemId)
				-- Optimistic: fade the others now; the server's "picked" clears the rest.
				closeCards(crate.id, card.itemId)
				SoundFX.play("levelup")
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
		if kind == "cards" then
			showCards(...)
		elseif kind == "picked" or kind == "closed" then
			local crateId = ...
			closeCards(crateId)
		elseif kind == "called" then
			local thrower = ...
			noticeText = if thrower == Players.LocalPlayer.Name
				then "FLARE OUT - PALLET INBOUND"
				else `{string.upper(thrower)} CALLED SUPPLY`
			noticeUntil = os.clock() + CALL_NOTICE_SECONDS
		end
	end)

	Players.LocalPlayer.CharacterAdded:Connect(clearAll)
	RunService.Heartbeat:Connect(function()
		updateMeter()
		checkPicks()
	end)
end

return ResupplyUI
