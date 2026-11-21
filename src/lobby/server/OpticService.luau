--!strict
-- The optic slot at the Loadmaster's EDIT (Nova, 2026-11-18; the M16A4 first): buying an
-- optic and fitting it, on the `Optic` remote. Server-authoritative: the client asks, this
-- checks with Rules/AttachmentRules and spends.
--   buy:   one-time, merits only, onto the soldier's record through RecordService.buyWith, the
--          same saved record and one-step save (UpdateAsync) as the Quartermaster's guns.
--          Pay once, own forever; no tabs, no Robux.
--   equip: an optic on the record, on a gun it fits, goes on the signed Loadout through
--          LoadmasterService.fit (saved like SIGN FOR IT, SaveSlot "u_<UserId>"); "" takes
--          it off.
--   owned: the optics on the record, for the menu's states and its "X/3" counter.
-- The Loadmaster also refuses to sign a Loadout with an optic not on the record
-- (RecordService.allows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttachmentRules = require(ReplicatedStorage.Shared.Rules.AttachmentRules)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Optics = require(ReplicatedStorage.Shared.Attachments.Optics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LoadmasterService = require(script.Parent.LoadmasterService)
local RecordService = require(script.Parent.RecordService)

local OpticService = {}

local remote: RemoteEvent
local priceOf = AttachmentRules.priceOf(Optics.Rows)

-- The optic ids on the soldier's record (nil while it loads).
local function ownedOptics(player: Player): { string }?
	local record = RecordService.waitFor(player)
	if not record then
		return nil
	end
	local ids: { string } = {}
	for _, id in record.owned do
		if Optics.Rows[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function sendOwned(player: Player)
	local ids = ownedOptics(player)
	if ids then
		remote:FireClient(player, Messages.Optic.State, ids)
	else
		remote:FireClient(player, Messages.Optic.Refused, "", "loading")
	end
end

local function buy(player: Player, opticId: unknown)
	if typeof(opticId) ~= "string" or not Optics.Rows[opticId] then
		remote:FireClient(player, Messages.Optic.Refused, opticId, "unknown")
		return
	end
	local ok, reason = RecordService.buyWith(player, opticId, priceOf)
	if not ok then
		remote:FireClient(player, Messages.Optic.Refused, opticId, reason)
		return
	end
	sendOwned(player)
end

local function equip(player: Player, gunId: unknown, opticId: unknown)
	if typeof(gunId) ~= "string" or typeof(opticId) ~= "string" then
		remote:FireClient(player, Messages.Optic.Refused, opticId, "unknown")
		return
	end
	if opticId ~= "" then
		local record = RecordService.waitFor(player)
		if not record then
			remote:FireClient(player, Messages.Optic.Refused, opticId, "loading")
			return
		end
		local ok, reason = AttachmentRules.canEquip(record, gunId, opticId, Optics.Rows)
		if not ok then
			remote:FireClient(player, Messages.Optic.Refused, opticId, reason)
			return
		end
	end
	local fitted, reason =
		LoadmasterService.fit(player, gunId, Optics.SLOT, if opticId ~= "" then opticId else nil)
	if not fitted then
		remote:FireClient(player, Messages.Optic.Refused, opticId, reason)
		return
	end
	remote:FireClient(player, Messages.Optic.Equipped, gunId, opticId)
end

function OpticService.init()
	remote = Remotes.get("Optic")
	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, a: unknown, b: unknown)
		if kind == Messages.Optic.Buy then
			buy(player, a)
		elseif kind == Messages.Optic.Equip then
			equip(player, a, b)
		elseif kind == Messages.Optic.Owned then
			sendOwned(player)
		end
	end)
end

return OpticService
