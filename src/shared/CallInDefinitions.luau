--!strict
-- Call-ins (docs/PROGRESSION.md > Call-ins): the slots on the number keys, chosen before
-- the drop (the Arms Room; the dev panel today). Metadata only: Name is the HUD name and
-- Codename the designation under it (docs/LORE.md naming kit), numbers live in
-- Config.CallIns, the effect lives in the owning service (AirStrikeService: Hammer, Anvil,
-- Shrike; SentryService: Doorman; MineService: Tripline; ConcertinaService: Concertina;
-- SupplyDropService: Speedball, Aid Bag) fired by CallInService.
-- Kind "throw": aimed at the crosshair and clamped to ThrowDistance (ThrowUtil, like the
-- flare). Kind "self": fires where the user stands. Icons reuse the uploaded item set.
-- Retired 2026-11-08 (too sci-fi): Magpie (drones), Pen Coil (shock pulse; its slow is the
-- Stun grenade's, EnemyService.slow / ShockCoilService.stunArea).

local Config = require(script.Parent.Config)

export type CallInKind = "throw" | "self"

export type CallInDefinition = {
	Id: string,
	Name: string, -- lore name on the HUD
	Codename: string, -- the designation under it
	Description: string,
	Kind: CallInKind,
	ConfigKey: string, -- Config.CallIns[ConfigKey]
	Abbrev: string,
	Color: Color3,
	IconId: string?,
}

local CallInDefinitions = {}

local FIRE_MISSION = Color3.fromRGB(214, 69, 51)
local EMPLACEMENT = Color3.fromRGB(96, 150, 220)
local SUPPLY = Color3.fromRGB(232, 181, 75)

local ROWS: { [string]: CallInDefinition } = {
	hammer = {
		Id = "hammer",
		Name = "Hammer",
		Codename = "81 mm mortar",
		Description = "Mark a point: six mortar shells walk in around it, a second apart.",
		Kind = "throw",
		ConfigKey = "Hammer",
		Abbrev = "HM",
		Color = FIRE_MISSION,
		IconId = "rbxassetid://112349300482610",
	},
	anvil = {
		Id = "anvil",
		Name = "Anvil",
		Codename = "105 mm battery",
		Description = "Mark a point: one 105 mm shell lands there five seconds later. Stand clear.",
		Kind = "throw",
		ConfigKey = "Anvil",
		Abbrev = "AV",
		Color = Color3.fromRGB(176, 48, 36),
		IconId = "rbxassetid://112349300482610",
	},
	shrike = {
		Id = "shrike",
		Name = "Shrike",
		Codename = "helicopter gun run",
		Description = "Mark a line: a gunship rakes ten bursts along your throw four seconds later.",
		Kind = "throw",
		ConfigKey = "Shrike",
		Abbrev = "SH",
		Color = Color3.fromRGB(196, 110, 52),
		IconId = "rbxassetid://98301242278764",
	},
	doorman = {
		Id = "doorman",
		Name = "Doorman",
		Codename = "tripod sentry MG",
		Description = "A tripod gun that holds where it lands for 45 s and shoots the nearest Infected it can see.",
		Kind = "throw",
		ConfigKey = "Doorman",
		Abbrev = "DM",
		Color = EMPLACEMENT,
		IconId = "rbxassetid://124493023372188",
	},
	tripline = {
		Id = "tripline",
		Name = "Tripline",
		Codename = "AP mines",
		Description = "Throw the line: six charges land in an arc and blow when the Infected step on it.",
		Kind = "throw",
		ConfigKey = "Tripline",
		Abbrev = "TL",
		Color = EMPLACEMENT,
		IconId = "rbxassetid://92670564918027",
	},
	concertina = {
		Id = "concertina",
		Name = "Concertina",
		Codename = "wire",
		Description = "A 16-stud strip of wire across your throw for 60 s: the Infected in it crawl and bleed.",
		Kind = "throw",
		ConfigKey = "Concertina",
		Abbrev = "CW",
		Color = Color3.fromRGB(150, 160, 170),
		IconId = "rbxassetid://124919143174637",
	},
	speedball = {
		Id = "speedball",
		Name = "Speedball",
		Codename = "ammo bundle",
		Description = "An ammo bundle kicked out of the door: four re-arms, and it lands quiet.",
		Kind = "throw",
		ConfigKey = "Speedball",
		Abbrev = "SB",
		Color = SUPPLY,
		IconId = "rbxassetid://127917945022019",
	},
	aid_bag = {
		Id = "aid_bag",
		Name = "Aid Bag",
		Codename = "medical drop",
		Description = "Everyone within six studs of the bag: full heal, stims back, +25 plate. Once each.",
		Kind = "throw",
		ConfigKey = "AidBag",
		Abbrev = "AB",
		Color = Color3.fromRGB(210, 130, 130),
		IconId = "rbxassetid://137643580128142",
	},
}

-- The starting loadout, one id per slot (Config.CallIns.Slots, 2 until the Arms Room).
local STARTING = { "hammer", "tripline", "doorman", "aid_bag" }
local slotCount = ((Config.CallIns :: { [string]: any }).Slots :: number?) or 2
CallInDefinitions.DEFAULT = table.move(STARTING, 1, math.min(slotCount, #STARTING), 1, {})
CallInDefinitions.Rows = ROWS
CallInDefinitions.Order = {
	"hammer",
	"anvil",
	"shrike",
	"doorman",
	"tripline",
	"concertina",
	"speedball",
	"aid_bag",
}

function CallInDefinitions.get(id: string?): CallInDefinition?
	return if id then ROWS[id] else nil
end

return CallInDefinitions
