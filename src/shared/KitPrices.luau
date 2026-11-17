--!strict
-- What kit costs on the Carrier and which desk sells it, read from each item's own Config row
-- (AGENTS.md: per-item values live on the item's row): guns `Config.Weapons.<Gun>.Price` (via
-- WeaponDefinitions), grenades `Config.Grenade.<Name>.Price`, call-ins
-- `Config.CallIns.<Name>.Price`. 0 = issued free; no Price = not for sale. The desk is the
-- row's own `Desk` (a LobbyDesks id) or, with none, the default for its kind
-- (`Config.Lobby.Sellers`: guns and grenades at the Quartermaster's rack, every call-in at the
-- call-in desk; owner 2026-11-16). Used by Rules/Record's callers (RecordService on the server,
-- RecordClient and DeskShop on the client) and the Arms Room's rack (ArmsRack, ArmsRackUI).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local KitPrices = {}

local function callInRow(id: string): any
	local row = CallInDefinitions.get(id)
	return row and (Config.CallIns :: any)[row.ConfigKey]
end

local function grenadeRow(id: string): any
	local grenade = WeaponDefinitions.Grenades[id]
	return grenade and (Config.Grenade :: any)[grenade.ConfigKey]
end

-- The item's price in merits, or nil when it is not for sale.
function KitPrices.of(id: string): number?
	if WeaponDefinitions.exists(id) then
		return WeaponDefinitions.get(id).Price
	end
	if WeaponDefinitions.Grenades[id] then
		local tuning = grenadeRow(id)
		return tuning and tuning.Price
	end
	local row = callInRow(id)
	return row and row.Price
end

-- The desk that sells the item (LobbyDesks id), or nil for an id that is not kit.
function KitPrices.deskOf(id: string): string?
	local sellers = Config.Lobby.Sellers
	if WeaponDefinitions.exists(id) then
		return WeaponDefinitions.get(id).Desk or sellers.Gun
	end
	if WeaponDefinitions.Grenades[id] then
		local tuning = grenadeRow(id)
		return (tuning and tuning.Desk) or sellers.Grenade
	end
	local row = callInRow(id)
	if row then
		return row.Desk or sellers.CallIn
	end
	return nil
end

-- The call-ins a desk sells (LobbyDesks id), in the Arms Room's order.
function KitPrices.soldAt(deskId: string): { string }
	local ids: { string } = {}
	for _, id in CallInDefinitions.Order do
		local row = callInRow(id)
		if row and row.Price ~= nil and KitPrices.deskOf(id) == deskId then
			table.insert(ids, id)
		end
	end
	return ids
end

-- The ids in `ids` (in their order) that the desk sells: a rack shows only its own desk's kit.
function KitPrices.only(deskId: string, ids: { string }): { string }
	local kept: { string } = {}
	for _, id in ids do
		if KitPrices.deskOf(id) == deskId then
			table.insert(kept, id)
		end
	end
	return kept
end

return KitPrices
