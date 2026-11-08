--!strict
-- Call-ins: the two slots on keys 1 and 2, chosen before the
-- drop (the Armory later; the dev panel today). Metadata only: names are the lore names
-- (docs/LORE.md), numbers live in Config.CallIns, the effect lives in the owning service
-- (DroneService, MineService, AirStrikeService, ShockCoilService) fired by CallInService.
-- Kind "throw": aimed at the crosshair and clamped to ThrowDistance (ThrowUtil, like the
-- flare). Kind "self": fires where the user stands. Icons reuse the uploaded item set.

export type CallInKind = "throw" | "self"

export type CallInDefinition = {
	Id: string,
	Name: string, -- lore name on the HUD
	Codename: string, -- what the tool is (design name)
	Description: string,
	Kind: CallInKind,
	ConfigKey: string, -- Config.CallIns[ConfigKey]
	Abbrev: string,
	Color: Color3,
	IconId: string?,
}

local CallInDefinitions = {}

local ROWS: { [string]: CallInDefinition } = {
	magpie = {
		Id = "magpie",
		Name = "Magpie",
		Codename = "Drone Beacon",
		Description = "Throw the beacon: two of Lantern's quadcopters fly with you for 30 s and shoot whatever gets close.",
		Kind = "throw",
		ConfigKey = "Magpie",
		Abbrev = "MG",
		Color = Color3.fromRGB(63, 167, 214),
		IconId = "rbxassetid://93910900196884",
	},
	tripline = {
		Id = "tripline",
		Name = "Tripline",
		Codename = "Mines",
		Description = "Throw the line: six charges land in an arc and blow when the Infected step on it.",
		Kind = "throw",
		ConfigKey = "Tripline",
		Abbrev = "TL",
		Color = Color3.fromRGB(96, 150, 220),
		IconId = "rbxassetid://92670564918027",
	},
	anvil = {
		Id = "anvil",
		Name = "Anvil",
		Codename = "Fire Mission",
		Description = "Mark a point: three shells from the battery land there three seconds later.",
		Kind = "throw",
		ConfigKey = "Anvil",
		Abbrev = "AV",
		Color = Color3.fromRGB(214, 69, 51),
		IconId = "rbxassetid://112349300482610",
	},
	pen_coil = {
		Id = "pen_coil",
		Name = "Pen Coil",
		Codename = "Shock Coil",
		Description = "A crowd-control pulse around you: damages and slows every Infected in reach.",
		Kind = "self",
		ConfigKey = "PenCoil",
		Abbrev = "PC",
		Color = Color3.fromRGB(120, 180, 255),
		IconId = "rbxassetid://83350462961014",
	},
}

-- Keys 1 and 2 at insert until the Armory exists.
CallInDefinitions.DEFAULT = { "magpie", "tripline" }
CallInDefinitions.Rows = ROWS
CallInDefinitions.Order = { "magpie", "tripline", "anvil", "pen_coil" }

function CallInDefinitions.get(id: string?): CallInDefinition?
	return if id then ROWS[id] else nil
end

return CallInDefinitions
