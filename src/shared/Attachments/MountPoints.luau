--!strict
-- The mount points (attachment visuals, Nova 2026-11-20): six on a long gun (OpticMount,
-- BarrelMount, MuzzleMount, MagazineMount, UnderbarrelMount, StockMount), three on a sidearm
-- (the optic, barrel and magazine ones; the revolver's cylinder is fixed, so it has two).
-- Gun-agnostic: each gun's row carries where its own mounts sit (Config.Weapons.<gun>.Mounts,
-- in the grip's space like its Sight points); Rules/MountPointResolution looks one up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MountPointResolution = require(ReplicatedStorage.Shared.Rules.MountPointResolution)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local Schema = require(script.Parent.Schema)

local MountPoints = {}

export type Mount = MountPointResolution.Mount

-- Each slot's mount; the ammo slot puts nothing on the gun.
local slots: { [string]: string | false } = {
	Optic = "OpticMount",
	Barrel = "BarrelMount",
	Muzzle = "MuzzleMount",
	Magazine = "MagazineMount",
	Underbarrel = "UnderbarrelMount",
	Stock = "StockMount",
}
slots[Schema.ammoSlot() or "Ammo"] = false
MountPoints.SCHEMA = { slots = slots } :: MountPointResolution.Schema

MountPoints.LONG_GUN = {
	"OpticMount",
	"BarrelMount",
	"MuzzleMount",
	"MagazineMount",
	"UnderbarrelMount",
	"StockMount",
}
MountPoints.SIDEARM = { "OpticMount", "BarrelMount", "MagazineMount" }

-- Where gun `gunId`'s part for `slot` goes: (mount) or (nil, reason; MountPointResolution).
function MountPoints.resolve(gunId: string, slot: string): (Mount?, string?)
	local gun = if WeaponDefinitions.exists(gunId) then WeaponDefinitions.get(gunId) else nil
	return MountPointResolution.resolve(slot, gun and gun.Mounts :: any, MountPoints.SCHEMA)
end

return MountPoints
