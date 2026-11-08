--!strict
-- Cards (replaces ItemDefinitions). Two kinds:
--   "supply": the three cards on every Resupply pallet (Medkit, Restock, Armour Plate);
--   "upgrade": the field upgrades, one slot each (Grenade, Weapon, Kit and one per carried
--   call-in, docs/PROGRESSION.md > Field upgrades); a new pick in a filled slot replaces it.
--   Each upgrade is a flag the owning service reads (LoadoutService.hasUpgrade); numbers
--   live in Config.Upgrades.
-- Names are the lore names where the lore developer gave one (docs/LORE.md); ids are the
-- mechanic. Metadata only; no gameplay logic here. Icons reuse the uploaded item set.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type CardKind = "supply" | "upgrade"
export type Slot = "Grenade" | "Weapon" | "Kit" | "CallIn"

export type CardDefinition = {
	Id: string,
	Kind: CardKind,
	Name: string,
	Description: string,
	Slot: Slot?, -- upgrades only; "CallIn" resolves to CallIn<n> by the slot carrying CallIn
	CallIn: string?, -- the call-in id a "CallIn" upgrade rides on
	Abbrev: string,
	Color: Color3,
	IconId: string?,
}

local UpgradeDefinitions = {}

local SUPPLY = Color3.fromRGB(232, 181, 75)

local ROWS: { [string]: CardDefinition } = {
	-- Supply cards.
	medkit = {
		Id = "medkit",
		Kind = "supply",
		Name = "Medkit",
		Description = "Heal to full, stims refilled.",
		Abbrev = "MK",
		Color = Color3.fromRGB(210, 130, 130),
		IconId = "rbxassetid://137643580128142",
	},
	restock = {
		Id = "restock",
		Kind = "supply",
		Name = "Restock",
		Description = "Every call-in charge back, grenades and stims too.",
		Abbrev = "RS",
		Color = SUPPLY,
		IconId = "rbxassetid://127917945022019",
	},
	armour_plate = {
		Id = "armour_plate",
		Kind = "supply",
		Name = "Armour Plate",
		Description = "+50 plate, soaked before health.",
		Abbrev = "AP",
		Color = Color3.fromRGB(78, 132, 196),
		IconId = "rbxassetid://112286218001477",
	},

	-- Grenade.
	lure_charge = {
		Id = "lure_charge",
		Kind = "upgrade",
		Name = "Bait Charge",
		Description = "A frag draws the Infected in for three seconds, then blows.",
		Slot = "Grenade",
		Abbrev = "BC",
		Color = Color3.fromRGB(220, 60, 60),
		IconId = "rbxassetid://136190678726539",
	},
	-- Weapon (any gun).
	through_and_through = {
		Id = "through_and_through",
		Kind = "upgrade",
		Name = "Through-and-Through",
		Description = "Rounds from any gun pass through the first Infected into the next.",
		Slot = "Weapon",
		Abbrev = "TT",
		Color = Color3.fromRGB(120, 200, 210),
		IconId = "rbxassetid://114114705411597",
	},
	hollow_point = {
		Id = "hollow_point",
		Kind = "upgrade",
		Name = "Hollow Point",
		Description = "Every hit from any gun stops the Infected in its tracks for a moment.",
		Slot = "Weapon",
		Abbrev = "HP",
		Color = Color3.fromRGB(196, 58, 44),
		IconId = "rbxassetid://106052794609307",
	},
	-- Kit.
	last_stand = {
		Id = "last_stand",
		Kind = "upgrade",
		Name = "Last Stand",
		Description = "Fire from the ground while downed (hip, wide).",
		Slot = "Kit",
		Abbrev = "LS",
		Color = Color3.fromRGB(70, 214, 140),
		IconId = "rbxassetid://75905528365649",
	},
	tourniquet = {
		Id = "tourniquet",
		Kind = "upgrade",
		Name = "Spare Tourniquet",
		Description = "Once per mission, get back up on your own four seconds after going down.",
		Slot = "Kit",
		Abbrev = "ST",
		Color = Color3.fromRGB(176, 38, 52),
		IconId = "rbxassetid://124871799608336",
	},
	-- Call-ins (one slot per carried call-in).
	walking_barrage = {
		Id = "walking_barrage",
		Kind = "upgrade",
		Name = "Walk It In",
		Description = "Hammer's shells walk forward along your throw, eight studs apart.",
		Slot = "CallIn",
		CallIn = "hammer",
		Abbrev = "WI",
		Color = Color3.fromRGB(214, 69, 51),
		IconId = "rbxassetid://112349300482610",
	},
	command_detonation = {
		Id = "command_detonation",
		Kind = "upgrade",
		Name = "Daisy Chain",
		Description = "Press Tripline's key again to blow every charge you have out.",
		Slot = "CallIn",
		CallIn = "tripline",
		Abbrev = "DC",
		Color = Color3.fromRGB(96, 150, 220),
		IconId = "rbxassetid://92670564918027",
	},
}

-- The slot key a call-in upgrade fills when its call-in sits in call-in slot `slot`.
function UpgradeDefinitions.callInSlot(slot: number): string
	return `CallIn{slot}`
end

local slots = { "Grenade", "Weapon", "Kit" }
for slot = 1, Config.CallIns.Slots do
	table.insert(slots, UpgradeDefinitions.callInSlot(slot))
end

UpgradeDefinitions.Rows = ROWS
-- Every loadout slot an upgrade can fill, in HUD order.
UpgradeDefinitions.SLOTS = slots

function UpgradeDefinitions.get(id: string?): CardDefinition?
	return if id then ROWS[id] else nil
end

-- Every upgrade id (stable order for rolls and the dev panel).
function UpgradeDefinitions.upgradeIds(): { string }
	local ids = {}
	for id, row in ROWS do
		if row.Kind == "upgrade" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

return UpgradeDefinitions
