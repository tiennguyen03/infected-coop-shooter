--!strict
-- Owns player item inventories and the level-up selection flow: each level
-- gained queues one offer; offers present one at a time (game soft-pauses
-- while one is open). The client picks via the ItemSelection remote; picks
-- are validated against the offered choices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PauseService = require(script.Parent.PauseService)
local XPService = require(script.Parent.XPService)

local ItemService = {}

local selectionRemote: RemoteEvent
local itemsUpdateRemote: RemoteEvent

local inventories: { [Player]: { [string]: number } } = {}
local pendingOffers: { [Player]: number } = {}
local activeOffer: { [Player]: { string } } = {}

local function getInventory(player: Player): { [string]: number }
	local inventory = inventories[player]
	if not inventory then
		inventory = {}
		inventories[player] = inventory
	end
	return inventory
end

local function rollChoices(): { string }
	local pool = {}
	for id in ItemDefinitions do
		table.insert(pool, id)
	end
	for i = #pool, 2, -1 do
		local j = math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local choices = {}
	for i = 1, math.min(Config.Items.ChoicesPerLevel, #pool) do
		table.insert(choices, pool[i])
	end
	return choices
end

local function presentOffer(player: Player)
	local choices = rollChoices()
	if #choices == 0 then
		pendingOffers[player] = 0
		return
	end
	activeOffer[player] = choices
	PauseService.setPaused(true)
	selectionRemote:FireClient(player, "offer", choices, getInventory(player))
end

function ItemService.addItem(player: Player, itemId: string)
	local inventory = getInventory(player)
	inventory[itemId] = (inventory[itemId] or 0) + 1
	itemsUpdateRemote:FireClient(player, inventory)

	local total = 0
	for _, stacks in inventory do
		total += stacks
	end
	player:SetAttribute("ItemsCollected", total)
end

function ItemService.getStacks(player: Player, itemId: string): number
	return getInventory(player)[itemId] or 0
end

local function onLevelUp(player: Player, _newLevel: number)
	pendingOffers[player] = (pendingOffers[player] or 0) + 1
	if not activeOffer[player] then
		presentOffer(player)
	end
end

local function onPick(player: Player, itemId: unknown)
	local offer = activeOffer[player]
	if not offer or typeof(itemId) ~= "string" or not table.find(offer, itemId) then
		return
	end
	activeOffer[player] = nil
	pendingOffers[player] = math.max((pendingOffers[player] or 1) - 1, 0)
	ItemService.addItem(player, itemId)

	if pendingOffers[player] > 0 then
		presentOffer(player)
	else
		PauseService.setPaused(false)
	end
end

function ItemService.resetPlayer(player: Player)
	inventories[player] = {}
	pendingOffers[player] = nil
	activeOffer[player] = nil
	player:SetAttribute("ItemsCollected", 0)
	itemsUpdateRemote:FireClient(player, {})
end

function ItemService.init()
	selectionRemote = Remotes.get("ItemSelection")
	itemsUpdateRemote = Remotes.get("ItemsUpdate")

	XPService.addLevelUpListener(onLevelUp)
	selectionRemote.OnServerEvent:Connect(onPick)

	Players.PlayerRemoving:Connect(function(player)
		if activeOffer[player] then
			PauseService.setPaused(false)
		end
		inventories[player] = nil
		pendingOffers[player] = nil
		activeOffer[player] = nil
	end)
end

return ItemService
