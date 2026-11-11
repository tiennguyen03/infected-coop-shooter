--!strict
-- What the Arms Room offers (docs/PROGRESSION.md > Loadout): the catalog the pure rules
-- (Rules/Loadout) validate against, built from the definition modules. Shared so the menu
-- (LoadoutMenu) and the server (LoadoutService.apply) agree; the lobby's Loadmaster uses it too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local ArmsRoom = {}

-- The default's first call-in slots (owner: Tripline on key 1).
ArmsRoom.PREFERRED_CALL_INS = { "tripline" }

function ArmsRoom.catalog(): Loadout.Catalog
	local callIns = {}
	for _, id in CallInDefinitions.Order do
		if CallInDefinitions.get(id) then
			table.insert(callIns, id)
		end
	end
	local attachments: { [string]: { [string]: { string } } } = {}
	for _, list in { WeaponDefinitions.PRIMARIES, WeaponDefinitions.SECONDARIES } do
		for _, id in list do
			local options = WeaponDefinitions.options(id)
			if next(options) then
				attachments[id] = options
			end
		end
	end
	return {
		primaries = table.clone(WeaponDefinitions.PRIMARIES),
		secondaries = table.clone(WeaponDefinitions.SECONDARIES),
		grenades = table.clone(WeaponDefinitions.GRENADES),
		callIns = callIns,
		preferredCallIns = ArmsRoom.PREFERRED_CALL_INS,
		slots = Config.CallIns.Slots,
		attachments = attachments,
	}
end

function ArmsRoom.default(): Loadout.Loadout
	return Loadout.default(ArmsRoom.catalog())
end

return ArmsRoom
