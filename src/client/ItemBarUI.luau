--!strict
-- Top-center strip showing owned items as small framed icons with stack
-- counts. Rebuilt from the ItemsUpdate remote whenever inventory changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemDefinitions"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local SLOT_SIZE = 40
local SLOT_GAP = 6

local ItemBarUI = {}

local bar: Frame

local function rebuild(inventory: { [string]: number })
	for _, child in bar:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Sort for a stable display order.
	local ids = {}
	for itemId, stacks in inventory do
		if stacks > 0 and ItemDefinitions[itemId] then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids)

	bar.Size = UDim2.fromOffset(#ids * (SLOT_SIZE + SLOT_GAP) + SLOT_GAP, SLOT_SIZE + 8)
	bar.Visible = #ids > 0

	for index, itemId in ids do
		local definition = ItemDefinitions[itemId]
		local slot: GuiObject
		if definition.IconId then
			local image = Instance.new("ImageLabel")
			image.Image = definition.IconId
			image.BackgroundColor3 = Color3.fromRGB(32, 34, 38)
			slot = image
		else
			local plate = Instance.new("TextLabel")
			plate.Text = definition.Abbrev
			plate.TextColor3 = Color3.fromRGB(240, 240, 240)
			plate.TextScaled = true
			plate.Font = Enum.Font.GothamBlack
			plate.BackgroundColor3 = definition.Color
			slot = plate
		end
		slot.Position = UDim2.fromOffset(SLOT_GAP + (index - 1) * (SLOT_SIZE + SLOT_GAP), 4)
		slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
		slot.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = slot

		local stacks = inventory[itemId]
		if stacks > 1 then
			local count = Instance.new("TextLabel")
			count.AnchorPoint = Vector2.new(1, 1)
			count.Position = UDim2.new(1, -2, 1, -2)
			count.Size = UDim2.fromOffset(16, 12)
			count.BackgroundTransparency = 1
			count.Text = `x{stacks}`
			count.TextColor3 = Color3.fromRGB(255, 255, 255)
			count.TextStrokeTransparency = 0.2
			count.TextSize = 12
			count.Font = Enum.Font.GothamBold
			count.Parent = slot
		end

		slot.Parent = bar
	end
end

function ItemBarUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ItemBarUI"
	gui.ResetOnSpawn = false

	bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 12)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.get("ItemsUpdate").OnClientEvent:Connect(rebuild)
end

return ItemBarUI
