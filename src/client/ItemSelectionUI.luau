--!strict
-- Level-up item selection: full-screen overlay with up to 3 item cards.
-- Server drives it through the ItemSelection remote; clicking a card sends
-- the chosen item id back and closes the panel. The game is soft-paused
-- (and the cursor unlocked by CameraController) while this is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ItemDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemDefinitions"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local CARD_WIDTH = 190
local CARD_HEIGHT = 250
local CARD_GAP = 20

local ItemSelectionUI = {}

local selectionRemote: RemoteEvent
local overlay: ScreenGui?

local function closeOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function createCard(parent: Frame, itemId: string, ownedStacks: number, position: UDim2)
	local definition = ItemDefinitions[itemId]
	if not definition then
		return
	end

	local rarityName = definition.Rarity or "Common"
	local rarity = Config.ItemRarities[rarityName] or Config.ItemRarities.Common
	local rarityColor = rarity.Color

	local card = Instance.new("TextButton")
	card.Name = itemId
	card.Position = position
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	-- Subtle rarity-tinted background accent.
	card.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(28, 30, 34), 0.82)
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = if rarityName == "Legendary"
		then 4
		elseif rarityName == "Uncommon" then 3
		else 2
	stroke.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Position = UDim2.fromOffset(0, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0, 14)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(rarity.DisplayName)
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 12
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = card

	-- Placeholder icon: colored plate with the abbreviation. Swapped for an
	-- ImageLabel when definition.IconId is set.
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
	icon.Position = UDim2.new(0.5, 0, 0, 16)
	icon.Size = UDim2.fromOffset(72, 72)
	icon.BorderSizePixel = 0
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = icon
	icon.Parent = card

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(10, 96)
	name.Size = UDim2.new(1, -20, 0, 40)
	name.BackgroundTransparency = 1
	name.Text = definition.Name
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextScaled = true
	name.TextWrapped = true
	name.Font = Enum.Font.GothamBold
	name.Parent = card

	local description = Instance.new("TextLabel")
	description.Position = UDim2.fromOffset(10, 140)
	description.Size = UDim2.new(1, -20, 0, 80)
	description.BackgroundTransparency = 1
	description.Text = definition.Description
	description.TextColor3 = Color3.fromRGB(190, 190, 190)
	description.TextSize = 14
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Font = Enum.Font.Gotham
	description.Parent = card

	local owned = Instance.new("TextLabel")
	owned.AnchorPoint = Vector2.new(0.5, 1)
	owned.Position = UDim2.new(0.5, 0, 1, -8)
	owned.Size = UDim2.new(1, -20, 0, 16)
	owned.BackgroundTransparency = 1
	owned.Text = if ownedStacks > 0 then `Owned: x{ownedStacks}` else "New"
	owned.TextColor3 = definition.Color
	owned.TextSize = 13
	owned.Font = Enum.Font.GothamBold
	owned.Parent = card

	card.Activated:Connect(function()
		selectionRemote:FireServer(itemId)
		closeOverlay()
	end)

	card.Parent = parent
end

local function showOffer(choices: { string }, inventory: { [string]: number })
	closeOverlay()

	local gui = Instance.new("ScreenGui")
	gui.Name = "ItemSelectionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.5, -(CARD_HEIGHT / 2) - 40)
	title.Size = UDim2.fromOffset(600, 40)
	title.BackgroundTransparency = 1
	title.Text = "LEVEL UP - CHOOSE EQUIPMENT"
	title.TextColor3 = Color3.fromRGB(255, 220, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = dim

	local totalWidth = #choices * CARD_WIDTH + (#choices - 1) * CARD_GAP
	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(totalWidth, CARD_HEIGHT)
	container.BackgroundTransparency = 1
	container.Parent = dim

	for index, itemId in choices do
		local x = (index - 1) * (CARD_WIDTH + CARD_GAP)
		createCard(container, itemId, inventory[itemId] or 0, UDim2.fromOffset(x, 0))
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = gui
end

local function watchCharacter(character: Model)
	-- Death must close the equipment screen so the death/restart UI is usable.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(closeOverlay)
end

function ItemSelectionUI.init()
	-- A run restart respawns the character; never leave a stale offer open.
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		closeOverlay()
		watchCharacter(character)
	end)
	if Players.LocalPlayer.Character then
		watchCharacter(Players.LocalPlayer.Character)
	end
	selectionRemote = Remotes.get("ItemSelection")
	selectionRemote.OnClientEvent:Connect(
		function(kind: string, choices: { string }, inventory: { [string]: number })
			if kind == "offer" then
				showOffer(choices, inventory)
			elseif kind == "cancel" then
				closeOverlay()
			end
		end
	)
end

return ItemSelectionUI
