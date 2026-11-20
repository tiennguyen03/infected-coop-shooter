--!strict
-- Attachment system v2 at the Loadmaster's EDIT (Nova, 2026-11-20; the M16A4 first): unlocking
-- options and ammo types and fitting them, on the `Attachment` remote. Server-authoritative:
-- the client asks, Rules/AttachmentUnlock decides, and only this spends or fits. Mirrors the
-- optic slot's OpticService, with no new save path:
--   unlock: one-time, merits only, onto the soldier's record (RecordService.buyWith: the same
--           record and one-step save as the Quartermaster's guns and the optics).
--   equip:  an unlocked option, on a gun and slot it fits, with nothing it clashes with, goes
--           on the signed Loadout through LoadmasterService.fit (saved like SIGN FOR IT,
--           "u_<UserId>"): the per-gun fitting persists with the Loadout. "" or the issued part
--           empties the slot. A refusal names its reason, which the menu shows.
--   owned:  the options and ammo on the record; config: what is fitted to one gun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmmoTypes = require(ReplicatedStorage.Shared.Attachments.AmmoTypes)
local AttachmentOptions = require(ReplicatedStorage.Shared.Attachments.Options)
local AttachmentUnlock = require(ReplicatedStorage.Shared.Rules.AttachmentUnlock)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local LoadmasterService = require(script.Parent.LoadmasterService)
local RecordService = require(script.Parent.RecordService)

local AttachmentService = {}

local remote: RemoteEvent
local catalog = WeaponDefinitions.attachmentCatalog()
local priceOf = AttachmentUnlock.priceOf(catalog)

local function isEntry(id: string): boolean
	return AttachmentOptions.get(id) ~= nil or AmmoTypes.get(id) ~= nil
end

local function isBase(id: string): boolean
	local entry = AttachmentOptions.get(id) or AmmoTypes.get(id)
	return entry ~= nil and entry.base
end

-- What is fitted to `gunId` on the soldier's signed Loadout ([slot] = id).
local function configOf(player: Player, gunId: string): AttachmentUnlock.Config
	local loadout = LoadmasterService.loadoutsFor({ player })[player.UserId]
	local attachments = loadout and loadout.attachments
	return table.clone(attachments and attachments[gunId] or {})
end

local function sendOwned(player: Player)
	local record = RecordService.waitFor(player)
	if not record then
		remote:FireClient(player, Messages.Attachment.Refused, "", "loading")
		return
	end
	local ids: { string } = {}
	for _, id in record.owned do
		if isEntry(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	remote:FireClient(player, Messages.Attachment.Owned, ids)
end

local function unlock(player: Player, id: unknown)
	if typeof(id) ~= "string" or not isEntry(id) then
		remote:FireClient(player, Messages.Attachment.Refused, id, "unknown")
		return
	end
	local ok, reason = RecordService.buyWith(player, id, priceOf)
	if not ok then
		remote:FireClient(player, Messages.Attachment.Refused, id, reason)
		return
	end
	sendOwned(player)
end

local function equip(player: Player, gunId: unknown, slot: unknown, id: unknown)
	if typeof(gunId) ~= "string" or typeof(slot) ~= "string" or typeof(id) ~= "string" then
		remote:FireClient(player, Messages.Attachment.Refused, id, "unknown")
		return
	end
	-- The issued part is what an empty slot holds.
	local option: string? = if id == "" or isBase(id) then nil else id
	if option then
		local record = RecordService.waitFor(player)
		if not record then
			remote:FireClient(player, Messages.Attachment.Refused, id, "loading")
			return
		end
		local ok, reason =
			AttachmentUnlock.canEquip(record, gunId, slot, option, configOf(player, gunId), catalog)
		if not ok then
			remote:FireClient(player, Messages.Attachment.Refused, id, reason)
			return
		end
	end
	local fitted, reason = LoadmasterService.fit(player, gunId, slot, option)
	if not fitted then
		remote:FireClient(player, Messages.Attachment.Refused, id, reason)
		return
	end
	remote:FireClient(player, Messages.Attachment.Equipped, gunId, slot, option or "")
end

function AttachmentService.init()
	remote = Remotes.get("Attachment")
	remote.OnServerEvent:Connect(
		function(player: Player, kind: unknown, a: unknown, b: unknown, c: unknown)
			if kind == Messages.Attachment.Unlock then
				unlock(player, a)
			elseif kind == Messages.Attachment.Equip then
				equip(player, a, b, c)
			elseif kind == Messages.Attachment.Owned then
				sendOwned(player)
			elseif kind == Messages.Attachment.Config and typeof(a) == "string" then
				remote:FireClient(player, Messages.Attachment.Config, a, configOf(player, a))
			end
		end
	)
end

return AttachmentService
