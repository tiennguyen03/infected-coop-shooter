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
local offerCount: { [Player]: number } = {} -- level-ups offered, for the guarantee

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

local function rollRarity(): string
	local rarities = (Config.ItemRarities :: any) :: { [string]: { Weight: number } }
	local total = 0
	for _, r in rarities do
		total += r.Weight
	end
	local roll = math.random() * total
	for name, r in rarities do
		roll -= r.Weight
		if roll <= 0 then
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

-- Weighted-rarity offer: each card rolls a rarity then a distinct item from
-- that pool (falling back to any rarity if exhausted). When `guarantee` is
-- true, ensures at least one Uncommon-or-better card.
local function rollChoices(guarantee: boolean): { string }
	local count = math.min(
		Config.Items.ChoicesPerLevel,
		#(poolsByRarity.Common or {})
			+ #(poolsByRarity.Uncommon or {})
			+ #(poolsByRarity.Legendary or {})
	)
	local choices: { string } = {}
	local chosen: { [string]: boolean } = {}
	local hasUncommonPlus = false

	for _ = 1, count do
		local rarity = rollRarity()
		local id = pickFromRarity(rarity, chosen) or pickAny(chosen)
		if id then
			table.insert(choices, id)
			chosen[id] = true
			if (ItemDefinitions[id].Rarity or "Common") ~= "Common" then
				hasUncommonPlus = true
			end
		end
	end

	-- Guarantee: swap a Common card for an Uncommon-or-better one.
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
function ItemService.simulateOffers(samples: number): { [string]: number }
	local tally = { Common = 0, Uncommon = 0, Legendary = 0 }
	for _ = 1, samples do
		local rarity = rollRarity()
		local id = pickFromRarity(rarity, {}) or pickAny({})
		if id then
			local r = ItemDefinitions[id].Rarity or "Common"
			tally[r] = (tally[r] or 0) + 1
		end
	end
	return tally
end

local function presentOffer(player: Player)
	offerCount[player] = (offerCount[player] or 0) + 1
	local guarantee = offerCount[player] % Config.RarityGuaranteeEvery == 0
	local choices = rollChoices(guarantee)
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

-- On death, abandon any open/queued offer and unpause so the death screen is
-- unobstructed and restart works (the offer would otherwise keep the game
-- paused with the equipment screen up).
local function cancelOffers(player: Player)
	local hadOffer = activeOffer[player] ~= nil
	pendingOffers[player] = nil
	activeOffer[player] = nil
	if hadOffer then
		selectionRemote:FireClient(player, "cancel")
		PauseService.setPaused(false)
	end
end

local function watchPlayer(player: Player)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			cancelOffers(player)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
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
	offerCount[player] = nil
	player:SetAttribute("ItemsCollected", 0)
	itemsUpdateRemote:FireClient(player, {})
end

function ItemService.init()
	buildPools()
	selectionRemote = Remotes.get("ItemSelection")
	itemsUpdateRemote = Remotes.get("ItemsUpdate")

	XPService.addLevelUpListener(onLevelUp)
	selectionRemote.OnServerEvent:Connect(onPick)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if activeOffer[player] then
			PauseService.setPaused(false)
		end
		inventories[player] = nil
		pendingOffers[player] = nil
		activeOffer[player] = nil
		offerCount[player] = nil
	end)
end

return ItemService
