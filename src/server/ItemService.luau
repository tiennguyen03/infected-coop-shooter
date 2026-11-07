--!strict
-- Owns player item inventories and the card roll every crate uses. Items reach a player
-- only through addItem (RequisitionService validates a card pick, dev tools grant). The
-- old level-up offer flow is gone: a level grows the body (PassiveItemService), the draft
-- happens at a pallet in the world (docs/PROGRESSION.md > Resupply).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type RarityWeights = { [string]: number }

local ItemService = {}

local itemsUpdateRemote: RemoteEvent
local inventoryChangedHandler: ((player: Player) -> ())? = nil

-- PassiveItemService registers here to recompute passives when items change.
function ItemService.setInventoryChangedHandler(handler: (player: Player) -> ())
	inventoryChangedHandler = handler
end

local inventories: { [Player]: { [string]: number } } = {}

-- Item ids grouped by rarity (built once at init).
local poolsByRarity: { [string]: { string } } = {}

local function buildPools()
	poolsByRarity = {}
	for id, def in ItemDefinitions do
		local rarity = def.Rarity or "Common"
		poolsByRarity[rarity] = poolsByRarity[rarity] or {}
		table.insert(poolsByRarity[rarity], id)
	end
end

local function rollRarity(weights: RarityWeights): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = math.random() * total
	for name, weight in weights do
		roll -= weight
		if roll <= 0 and weight > 0 then
			return name
		end
	end
	return "Common"
end

-- A random item of `rarity` not already in `chosen`, or nil if exhausted.
local function pickFromRarity(rarity: string, chosen: { [string]: boolean }): string?
	local pool = poolsByRarity[rarity]
	if not pool then
		return nil
	end
	local available = {}
	for _, id in pool do
		if not chosen[id] then
			table.insert(available, id)
		end
	end
	if #available == 0 then
		return nil
	end
	return available[math.random(#available)]
end

-- Any remaining item of any rarity (fallback when a rarity pool is empty).
local function pickAny(chosen: { [string]: boolean }): string?
	local available = {}
	for id in ItemDefinitions do
		if not chosen[id] then
			table.insert(available, id)
		end
	end
	if #available == 0 then
		return nil
	end
	return available[math.random(#available)]
end

local function getInventory(player: Player): { [string]: number }
	local inventory = inventories[player]
	if not inventory then
		inventory = {}
		inventories[player] = inventory
	end
	return inventory
end

function ItemService.getInventory(player: Player): { [string]: number }
	return getInventory(player)
end

-- One player's cards for one crate: each card rolls a rarity from `weights` then a
-- distinct item from that pool (any rarity if exhausted). `guarantee` swaps a Common card
-- for an Uncommon-or-better one when none rolled.
function ItemService.rollChoices(weights: RarityWeights, guarantee: boolean): { string }
	local count = math.min(
		Config.Crates.CardsPerPlayer,
		#(poolsByRarity.Common or {})
			+ #(poolsByRarity.Uncommon or {})
			+ #(poolsByRarity.Legendary or {})
	)
	local choices: { string } = {}
	local chosen: { [string]: boolean } = {}
	local hasUncommonPlus = false

	for _ = 1, count do
		local rarity = rollRarity(weights)
		local id = pickFromRarity(rarity, chosen) or pickAny(chosen)
		if id then
			table.insert(choices, id)
			chosen[id] = true
			if (ItemDefinitions[id].Rarity or "Common") ~= "Common" then
				hasUncommonPlus = true
			end
		end
	end

	if guarantee and not hasUncommonPlus then
		local upgrade = pickFromRarity("Uncommon", chosen) or pickFromRarity("Legendary", chosen)
		if upgrade then
			for index, id in choices do
				if (ItemDefinitions[id].Rarity or "Common") == "Common" then
					chosen[id] = nil
					choices[index] = upgrade
					chosen[upgrade] = true
					break
				end
			end
		end
	end
	return choices
end

-- Dev-only: tally rarity distribution over N simulated single cards.
function ItemService.simulateOffers(samples: number, weights: RarityWeights): { [string]: number }
	local tally = { Common = 0, Uncommon = 0, Legendary = 0 }
	for _ = 1, samples do
		local rarity = rollRarity(weights)
		local id = pickFromRarity(rarity, {}) or pickAny({})
		if id then
			local r = ItemDefinitions[id].Rarity or "Common"
			tally[r] = (tally[r] or 0) + 1
		end
	end
	return tally
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

	if inventoryChangedHandler then
		inventoryChangedHandler(player)
	end
end

function ItemService.getStacks(player: Player, itemId: string): number
	return getInventory(player)[itemId] or 0
end

function ItemService.resetPlayer(player: Player)
	inventories[player] = {}
	player:SetAttribute("ItemsCollected", 0)
	itemsUpdateRemote:FireClient(player, {})
end

function ItemService.init()
	buildPools()
	itemsUpdateRemote = Remotes.get("ItemsUpdate")

	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

return ItemService
