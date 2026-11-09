--!strict
-- Guns and grenades as data (docs/PROGRESSION.md > Loadout). One row per gun; every number
-- comes from Config.Weapons.<ConfigKey> so tuning stays in Config. A soldier carries one
-- primary and one secondary (Slot), each with its own magazine and reserve on the server
-- (LoadoutService); ProjectileServer fires by the active row, BotService by the rifle's.
-- The Arms Room (LoadoutMenu, Rules/Loadout) lists PRIMARIES, SECONDARIES and GRENADES.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type WeaponSlot = "primary" | "secondary"
export type FireMode = "auto" | "semi"
-- Per-shot camera kick: Pitch degrees up, a random +/- Yaw degrees, eased back over Recover s.
export type WeaponKick = { Pitch: number, Yaw: number, Recover: number }

export type WeaponDefinition = {
	Id: string,
	Name: string, -- HUD name
	Designation: string, -- the real gun
	Description: string, -- one line for the Arms Room
	Slot: WeaponSlot,
	FireMode: FireMode, -- "semi": one round per click
	Damage: number, -- per round (per pellet when Pellets is set)
	FireCooldown: number, -- seconds between shots
	MagazineSize: number,
	ReloadTime: number, -- seconds
	ReserveStart: number, -- rounds in reserve at insert
	ReserveMax: number,
	HipSpread: number, -- degrees, half-angle
	AdsSpread: number,
	BloomPerShot: number, -- degrees added to the cone per round
	BloomMax: number,
	BloomRecovery: number, -- degrees per second once the trigger rests
	AdsMoveFactor: number, -- walk speed multiplier while aiming
	Range: number, -- studs the hitscan ray reaches
	HeadshotMultiplier: number, -- on a Head hit (EnemyDefinitions may override per form)
	Pellets: number?, -- rounds per trigger pull (shotguns); nil = 1
	Pierce: number?, -- Infected a round passes through after the first; nil = 0
	Kick: WeaponKick, -- per-shot camera kick (CameraController)
	Heavy: boolean, -- staggers a Brute (Config.Enemies.Flinch)
}

export type GrenadeDefinition = {
	Id: string,
	Name: string,
	Designation: string,
	Description: string,
	ConfigKey: string, -- Config.Grenade[ConfigKey]
}

type Tuning = {
	FireMode: string,
	Damage: number,
	FireCooldown: number,
	MagazineSize: number,
	ReloadTime: number,
	ReserveStart: number,
	ReserveMax: number,
	HipSpread: number,
	AdsSpread: number,
	BloomPerShot: number,
	BloomMax: number,
	BloomRecovery: number,
	AdsMoveFactor: number,
	Range: number,
	HeadshotMultiplier: number,
	Pellets: number?,
	Pierce: number?,
	Kick: WeaponKick,
	Heavy: boolean?,
}

local function row(
	id: string,
	slot: WeaponSlot,
	name: string,
	designation: string,
	description: string,
	tuning: Tuning
): WeaponDefinition
	return {
		Id = id,
		Name = name,
		Designation = designation,
		Description = description,
		Slot = slot,
		FireMode = if tuning.FireMode == "semi" then "semi" else "auto",
		Damage = tuning.Damage,
		FireCooldown = tuning.FireCooldown,
		MagazineSize = tuning.MagazineSize,
		ReloadTime = tuning.ReloadTime,
		ReserveStart = tuning.ReserveStart,
		ReserveMax = tuning.ReserveMax,
		HipSpread = tuning.HipSpread,
		AdsSpread = tuning.AdsSpread,
		BloomPerShot = tuning.BloomPerShot,
		BloomMax = tuning.BloomMax,
		BloomRecovery = tuning.BloomRecovery,
		AdsMoveFactor = tuning.AdsMoveFactor,
		Range = tuning.Range,
		HeadshotMultiplier = tuning.HeadshotMultiplier,
		Pellets = tuning.Pellets,
		Pierce = tuning.Pierce,
		Kick = tuning.Kick,
		Heavy = tuning.Heavy == true,
	}
end

local W = (Config.Weapons :: any) :: { [string]: Tuning }

local WeaponDefinitions = {}

local ROWS: { [string]: WeaponDefinition } = {
	service_rifle = row(
		"service_rifle",
		"primary",
		"Service Rifle",
		"M16A4",
		"The all-rounder. Fire in short bursts: a held trigger sprays at range.",
		W.ServiceRifle
	),
	smg = row(
		"smg",
		"primary",
		"SMG",
		"MP5",
		"Best from the hip. Chews through Runners, struggles on Brutes.",
		W.Smg
	),
	lmg = row(
		"lmg",
		"primary",
		"LMG",
		"M249",
		"A 100-round belt: no reload inside a hold. Slow to aim on the move.",
		W.Lmg
	),
	shotgun = row(
		"shotgun",
		"primary",
		"Shotgun",
		"Mossberg 590",
		"Point-blank, one pump per shot. Drops anything but a Brute in one pull.",
		W.Shotgun
	),
	dmr = row(
		"dmr",
		"primary",
		"DMR",
		"M110",
		"One round per Walker, through two in a line. Poor up close, short on ammo.",
		W.Dmr
	),
	pistol = row(
		"pistol",
		"secondary",
		"Pistol",
		"M17",
		"The sidearm. Q to draw it when the long gun runs dry.",
		W.Pistol
	),
}

local GRENADES: { [string]: GrenadeDefinition } = {
	frag = {
		Id = "frag",
		Name = "Frag",
		Designation = "M67",
		Description = "Hold G to aim, release to throw. Kills a Hocker, not a Brute.",
		ConfigKey = "Frag",
	},
}

WeaponDefinitions.DEFAULT = "service_rifle"
WeaponDefinitions.DEFAULT_SECONDARY = "pistol"
WeaponDefinitions.DEFAULT_GRENADE = "frag"
WeaponDefinitions.Rows = ROWS
WeaponDefinitions.Grenades = GRENADES
-- Arms Room order (the first of each list is the default).
WeaponDefinitions.PRIMARIES = { "service_rifle", "smg", "lmg", "shotgun", "dmr" }
WeaponDefinitions.SECONDARIES = { "pistol" }
WeaponDefinitions.GRENADES = { "frag" }

-- The row for `id`, or the default rifle when the id is unknown (never nil).
function WeaponDefinitions.get(id: string?): WeaponDefinition
	return (id and ROWS[id]) or ROWS[WeaponDefinitions.DEFAULT]
end

function WeaponDefinitions.exists(id: string): boolean
	return ROWS[id] ~= nil
end

function WeaponDefinitions.grenade(id: string?): GrenadeDefinition
	return (id and GRENADES[id]) or GRENADES[WeaponDefinitions.DEFAULT_GRENADE]
end

return WeaponDefinitions
