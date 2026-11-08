--!strict
-- Cards (replaces ItemDefinitions). Two kinds:
--   "supply": the three cards on every Resupply pallet (Medkit, Restock, Armour Plate);
--   "upgrade": the twelve field upgrades, one slot each (Dash, Breach, Rifle, Kit and the
--   two call-in slots); a new pick in a filled slot replaces it. Each upgrade is a flag the
--   owning service reads (LoadoutService.hasUpgrade); numbers live in Config.Upgrades.
-- Names are the lore names where the lore developer gave one (docs/LORE.md); ids are the
-- mechanic. Metadata only; no gameplay logic here. Icons reuse the uploaded item set.

export type CardKind = "supply" | "upgrade"
export type Slot = "Dash" | "Breach" | "Rifle" | "Kit" | "CallIn"

export type CardDefinition = {
	Id: string,
	Kind: CardKind,
	Name: string,
	Description: string,
	Slot: Slot?, -- upgrades only; "CallIn" resolves to CallInA / CallInB by CallIn below
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
		Description = "Heal to full.",
		Abbrev = "MK",
		Color = Color3.fromRGB(210, 130, 130),
		IconId = "rbxassetid://137643580128142",
	},
	restock = {
		Id = "restock",
		Kind = "supply",
		Name = "Restock",
		Description = "Every call-in charge back.",
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

	-- Dash.
	fire_trail = {
		Id = "fire_trail",
		Kind = "upgrade",
		Name = "Flare Straps",
		Description = "The dash leaves burning ground behind you.",
		Slot = "Dash",
		Abbrev = "FS",
		Color = Color3.fromRGB(232, 120, 40),
		IconId = "rbxassetid://120185044572558",
	},
	smoke_dash = {
		Id = "smoke_dash",
		Kind = "upgrade",
		Name = "Smoke Dash",
		Description = "The dash pops smoke: the Infected cannot find you for a moment after it.",
		Slot = "Dash",
		Abbrev = "SD",
		Color = Color3.fromRGB(150, 160, 170),
		IconId = "rbxassetid://87239041890547",
	},
	-- Breach.
	lure_charge = {
		Id = "lure_charge",
		Kind = "upgrade",
		Name = "Bait Charge",
		Description = "The breach charge draws the Infected in for three seconds, then blows.",
		Slot = "Breach",
		Abbrev = "BC",
		Color = Color3.fromRGB(220, 60, 60),
		IconId = "rbxassetid://136190678726539",
	},
	-- Rifle.
	through_and_through = {
		Id = "through_and_through",
		Kind = "upgrade",
		Name = "Through-and-Through",
		Description = "Rounds pass through the first Infected into the next.",
		Slot = "Rifle",
		Abbrev = "TT",
		Color = Color3.fromRGB(120, 200, 210),
		IconId = "rbxassetid://114114705411597",
	},
	hollow_point = {
		Id = "hollow_point",
		Kind = "upgrade",
		Name = "Hollow Point",
		Description = "Every hit stops the Infected in its tracks for a moment.",
		Slot = "Rifle",
		Abbrev = "HP",
		Color = Color3.fromRGB(196, 58, 44),
		IconId = "rbxassetid://106052794609307",
	},
	-- Kit.
	combat_reload = {
		Id = "combat_reload",
		Kind = "upgrade",
		Name = "Combat Reload",
		Description = "At five Momentum the reload is instant.",
		Slot = "Kit",
		Abbrev = "CR",
		Color = Color3.fromRGB(200, 120, 60),
		IconId = "rbxassetid://86057108539929",
	},
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
	-- Call-ins.
	walking_barrage = {
		Id = "walking_barrage",
		Kind = "upgrade",
		Name = "Walk It In",
		Description = "Anvil fires five shells that walk forward along your throw.",
		Slot = "CallIn",
		CallIn = "anvil",
		Abbrev = "WI",
		Color = Color3.fromRGB(214, 69, 51),
		IconId = "rbxassetid://112349300482610",
	},
	escort = {
		Id = "escort",
		Kind = "upgrade",
		Name = "Last Flight",
		Description = "Magpie's drones stay over you while you are down, and their clock stops.",
		Slot = "CallIn",
		CallIn = "magpie",
		Abbrev = "LF",
		Color = Color3.fromRGB(63, 167, 214),
		IconId = "rbxassetid://117089147085343",
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
	defibrillator = {
		Id = "defibrillator",
		Kind = "upgrade",
		Name = "Ground Strap",
		Description = "A Pen Coil pulse stands up every downed squadmate in its radius (uses a revive).",
		Slot = "CallIn",
		CallIn = "pen_coil",
		Abbrev = "GS",
		Color = Color3.fromRGB(120, 180, 255),
		IconId = "rbxassetid://83350462961014",
	},
}

UpgradeDefinitions.Rows = ROWS
-- The six loadout slots an upgrade can fill, in HUD order.
UpgradeDefinitions.SLOTS = { "Dash", "Breach", "Rifle", "Kit", "CallInA", "CallInB" }

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
