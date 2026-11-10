--!strict
-- What kit costs on the Carrier, read from each item's own Config row (AGENTS.md: per-item
-- values live on the item's row): guns `Config.Weapons.<Gun>.Price` (via WeaponDefinitions),
-- grenades `Config.Grenade.<Name>.Price`, call-ins `Config.CallIns.<Name>.Price` and the desk
-- that sells them, `.Desk` ("fires", "engineers", "loadmaster"). Guns and grenades are sold at
-- the Quartermaster's rack. 0 = issued free; no Price = not for sale. Used by Rules/Record's
-- callers (RecordService on the server, RecordClient and DeskShop on the client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local KitPrices = {}

local function callInRow(id: string): any
	local row = CallInDefinitions.get(id)
	return row and (Config.CallIns :: any)[row.ConfigKey]
end

-- The item's price in merits, or nil when it is not for sale.
function KitPrices.of(id: string): number?
	if WeaponDefinitions.exists(id) then
		return WeaponDefinitions.get(id).Price
	end
	local grenade = WeaponDefinitions.Grenades[id]
	if grenade then
		local tuning = (Config.Grenade :: any)[grenade.ConfigKey]
		return tuning and tuning.Price
	end
	local row = callInRow(id)
	return row and row.Price
end

-- The call-ins a desk sells (LobbyDesks id), in the Arms Room's order.
function KitPrices.soldAt(deskId: string): { string }
	local ids: { string } = {}
	for _, id in CallInDefinitions.Order do
		local row = callInRow(id)
		if row and row.Desk == deskId and row.Price ~= nil then
			table.insert(ids, id)
		end
	end
	return ids
end

return KitPrices
