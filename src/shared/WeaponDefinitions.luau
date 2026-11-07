--!strict
-- Weapons as data (loadout rework 2026-11-07). One row per weapon; the service rifle reads
-- its numbers from Config.Weapon so every tuning value stays in Config. The server
-- (LoadoutService) owns each player's magazine and reserve for the weapon they carry;
-- ProjectileServer and BotService fire by the row. Later guns (sidearm, SMG, shotgun,
-- marksman, LMG) are new rows plus a mesh; Pellets and Pierce are read when present.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type WeaponDefinition = {
	Id: string,
	Name: string,
	Damage: number, -- per round (per pellet when Pellets is set)
	FireCooldown: number, -- seconds between shots
	MagazineSize: number,
	ReloadTime: number, -- seconds
	ReserveStart: number, -- rounds in reserve at insert
	ReserveMax: number,
	HipSpread: number, -- degrees, half-angle
	AdsSpread: number,
	Range: number, -- studs the hitscan ray reaches
	HeadshotMultiplier: number, -- on a Head hit (EnemyDefinitions may override per form)
	Pellets: number?, -- rounds per trigger pull (shotguns); nil = 1
	Pierce: number?, -- Infected a round passes through after the first; nil = 0
}

local WeaponDefinitions = {}

local ROWS: { [string]: WeaponDefinition } = {
	service_rifle = {
		Id = "service_rifle",
		Name = "Service Rifle",
		Damage = Config.Weapon.Damage,
		FireCooldown = Config.Weapon.FireCooldown,
		MagazineSize = Config.Weapon.MagazineSize,
		ReloadTime = Config.Weapon.ReloadTime,
		ReserveStart = Config.Weapon.ReserveStart,
		ReserveMax = Config.Weapon.ReserveMax,
		HipSpread = Config.Weapon.HipSpread,
		AdsSpread = Config.Weapon.ADS.Spread,
		Range = Config.Weapon.Range,
		HeadshotMultiplier = Config.Weapon.HeadshotMultiplier,
	},
}

WeaponDefinitions.DEFAULT = "service_rifle"
WeaponDefinitions.Rows = ROWS

-- The row for `id`, or the default rifle when the id is unknown (never nil).
function WeaponDefinitions.get(id: string?): WeaponDefinition
	return (id and ROWS[id]) or ROWS[WeaponDefinitions.DEFAULT]
end

function WeaponDefinitions.exists(id: string): boolean
	return ROWS[id] ~= nil
end

return WeaponDefinitions
