--!strict
-- What fitted attachments do to a gun, as pure maths (tests/AttachmentMerge.spec.luau,
-- tests/AttachmentMergeV2.spec.luau). The gun's own values are never changed.
--
-- `apply` (the optic slot, 2026-11-18): an optic's multipliers on zoom and the time into the
-- sights. Kept for the guns still on one-slot fitting.
--
-- `merge` (attachment system v2, Nova 2026-11-20): every slot on a gun at once (Optic,
-- Barrel, Muzzle, Magazine, Ammo, Underbarrel, Stock; Shared.Attachments.Schema). Each option
-- carries deltas, each naming its operation:
--   multiply: the factors of every option on a field multiply together and scale the value;
--   add:      the amounts add together and are added after the multipliers.
-- So a field ends as  value x (every multiply) + (every add)  (a drum's +30 rounds is never
-- doubled by something that scales the magazine).
-- The ammo type is not a delta: its damage profile REPLACES the gun's own (damage, rounds per
-- shot, headshot multiplier, armour penetration, behaviour) and scales its range and alert
-- radius, before the attachments apply. Attachments still act on the new round (a suppressed
-- barrel's -10% damage bites on HP rounds too); otherwise, since a gun always carries some
-- ammo, a damage delta would never matter.
-- Compatibility: an option for another gun or in another slot, ammo of another caliber, or any
-- pair where one names the other in incompatibleWith refuses the whole fitting, with a reason.
-- A row may say why in its clashReasons (clashReason; the Loadmaster's menu shows it).
--
-- The Mossberg 590 (2026-11-20) extended this minimally: a damage profile may also carry
-- spreadMultiplier (a slug's one ball has no pellet pattern), recoilMultiplier (a slug kicks
-- harder) and burn (Dragon's Breath: each projectile hit burns, Rules/DoT); the stat block
-- gained adsSpread (the aimed cone, a shotgun's pattern) and breachPower (a breaching round's
-- push on a wall, Rules/WallBreach). The row helpers (optionFromRow, opticFromRow, ammoFromRow,
-- gunStats) turn Config rows into these records, for Shared.Attachments and the specs alike.

local AttachmentMerge = {}

export type Stats = {
	zoom: number, -- magnification over the hip view (Rules/Sight)
	adsTime: number, -- seconds into the sights
}

export type Modifier = {
	zoomMultiplier: number?,
	adsTimeMultiplier: number?,
}

-- A multiplier that means something: above zero and a real number; anything else is 1.
local function factor(value: number?): number
	if value == nil or value ~= value or value <= 0 or value == math.huge then
		return 1
	end
	return value
end

function AttachmentMerge.apply(base: Stats, modifiers: { Modifier }): Stats
	local zoom, adsTime = base.zoom, base.adsTime
	for _, modifier in modifiers do
		zoom *= factor(modifier.zoomMultiplier)
		adsTime *= factor(modifier.adsTimeMultiplier)
	end
	return { zoom = zoom, adsTime = adsTime }
end

----------------------------------------------------------------------
-- v2: the whole gun
----------------------------------------------------------------------

export type Behavior = "standard" | "incendiary" | "tracer" | "breaching" | "subsonic"

-- A gun's final stat block. Most are the gun's own numbers; recoil, recoilRecovery, moveSpeed,
-- adsTime and zoom are factors on the gun's own (1 = as issued).
export type GunStats = {
	damage: number, -- per projectile
	projectileCount: number,
	headshotMultiplier: number,
	armorPenetration: number, -- 0..1: the share of a plate's reduction the round ignores
	projectileBehavior: string,
	alertRadius: number, -- studs a shot carries to the Infected
	range: number,
	recoil: number, -- factor on the kick and the bloom per shot
	recoilRecovery: number, -- factor on how fast the kick and bloom come back
	moveSpeed: number, -- factor on the walk while it is in hand
	adsTime: number, -- factor on the time into the sights
	zoom: number, -- factor on the sight's magnification (an optic's own sight carries it)
	magazineSize: number,
	reloadTime: number,
	hipSpread: number,
	adsSpread: number?, -- the aimed cone (nil: a gun without one to scale)
	breachPower: number?, -- a breaching round's push per hit on a wall (Rules/WallBreach); 1 as issued
	burn: Burn?, -- an incendiary round's burn per projectile hit (Rules/DoT); nil: none
}

-- Per projectile hit: `damage` in all, over `seconds` (Rules/DoT).
export type Burn = { damage: number, seconds: number }

export type Op = "multiply" | "add"
export type Delta = { field: string, op: Op, value: number }

export type Option = {
	id: string,
	slot: string,
	compatibleGuns: { string },
	incompatibleWith: { string },
	deltas: { Delta },
	clashReasons: { [string]: string }?, -- [other id] = why they cannot go together
}

export type DamageProfile = {
	damage: number,
	projectileCount: number,
	headshotMultiplier: number,
	armorPenetration: number,
	alertRadiusMultiplier: number,
	projectileBehavior: string,
	rangeMultiplier: number,
	spreadMultiplier: number?, -- on the gun's cones; nil = 1
	recoilMultiplier: number?, -- on the kick; nil = 1
	burn: Burn?,
}

export type Ammo = {
	id: string,
	caliberFamily: string,
	damageProfile: DamageProfile,
	incompatibleWith: { string },
	clashReasons: { [string]: string }?,
}

export type Gun = { id: string, caliber: string?, stats: GunStats }

-- A value a delta may use: a real, finite number.
local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function names(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

-- The first pair in `fitted` (plus `ammo`) that cannot go together, as "a:b" with `a` the one
-- that names `b`; nil when every pair goes together. Slots are walked in name order so the
-- answer is always the same.
local function clash(fitted: { Option }, ammo: Ammo?): string?
	for _, option in fitted do
		for _, other in fitted do
			if other ~= option and names(option.incompatibleWith, other.id) then
				return `{option.id}:{other.id}`
			end
		end
		if ammo and names(option.incompatibleWith, ammo.id) then
			return `{option.id}:{ammo.id}`
		end
	end
	if ammo then
		for _, option in fitted do
			if names(ammo.incompatibleWith, option.id) then
				return `{ammo.id}:{option.id}`
			end
		end
	end
	return nil
end

-- Gun `gun` with `equipped` (slot -> option) and `ammo` (nil: the gun's own round): its final
-- stats, or (nil, the reason): "gun:<id>", "slot:<id>", "caliber:<id>", "incompatible:<a>:<b>".
function AttachmentMerge.merge(
	gun: Gun,
	equipped: { [string]: Option },
	ammo: Ammo?
): (GunStats?, string?)
	local slots: { string } = {}
	for slot in equipped do
		table.insert(slots, slot)
	end
	table.sort(slots)
	local fitted: { Option } = {}
	for _, slot in slots do
		local option = equipped[slot]
		if not names(option.compatibleGuns, gun.id) then
			return nil, `gun:{option.id}`
		end
		if option.slot ~= slot then
			return nil, `slot:{option.id}`
		end
		table.insert(fitted, option)
	end
	if ammo and ammo.caliberFamily ~= gun.caliber then
		return nil, `caliber:{ammo.id}`
	end
	local pair = clash(fitted, ammo)
	if pair then
		return nil, `incompatible:{pair}`
	end

	local stats = table.clone(gun.stats)
	if ammo then
		local profile = ammo.damageProfile
		stats.damage = profile.damage
		stats.projectileCount = profile.projectileCount
		stats.headshotMultiplier = profile.headshotMultiplier
		stats.armorPenetration = profile.armorPenetration
		stats.projectileBehavior = profile.projectileBehavior
		stats.alertRadius *= factor(profile.alertRadiusMultiplier)
		stats.range *= factor(profile.rangeMultiplier)
		stats.recoil *= factor(profile.recoilMultiplier)
		local spread = factor(profile.spreadMultiplier)
		stats.hipSpread *= spread
		if stats.adsSpread then
			stats.adsSpread *= spread
		end
		local burn = profile.burn
		stats.burn = if burn then { damage = burn.damage, seconds = burn.seconds } else nil
	end

	local scale: { [string]: number } = {}
	local plus: { [string]: number } = {}
	for _, option in fitted do
		for _, delta in option.deltas do
			local value = delta.value
			if typeof((stats :: any)[delta.field]) ~= "number" or not finite(value) then
				continue
			end
			if delta.op == "multiply" then
				if value > 0 then
					scale[delta.field] = (scale[delta.field] or 1) * value
				end
			elseif delta.op == "add" then
				plus[delta.field] = (plus[delta.field] or 0) + value
			end
		end
	end
	local out = stats :: any
	for field, value in stats :: any do
		if typeof(value) == "number" then
			out[field] = value * (scale[field] or 1) + (plus[field] or 0)
		end
	end
	stats.armorPenetration = math.clamp(stats.armorPenetration, 0, 1)
	stats.projectileCount = math.max(1, math.floor(stats.projectileCount + 0.5))
	stats.magazineSize = math.max(1, math.floor(stats.magazineSize + 0.5))
	return stats, nil
end

-- Why `a` and `b` cannot go together, as either row says it (nil: neither says).
function AttachmentMerge.clashReason(
	a: { id: string, clashReasons: { [string]: string }? }?,
	b: { id: string, clashReasons: { [string]: string }? }?
): string?
	if not a or not b then
		return nil
	end
	local mine = a.clashReasons and a.clashReasons[b.id]
	return mine or (b.clashReasons and b.clashReasons[a.id]) or nil
end

----------------------------------------------------------------------
-- Config rows into records (Shared.Attachments.Options / AmmoTypes, and the specs)
----------------------------------------------------------------------

-- What Rules/AttachmentUnlock also needs of each.
export type OptionEntry = Option & { meritCost: number, base: boolean }
export type AmmoEntry = Ammo & { slot: string, meritCost: number, base: boolean }

local function reasons(row: any): { [string]: string }
	return if row.ClashReasons then table.clone(row.ClashReasons) else {}
end

-- A Config.AttachmentsV2.Options row.
function AttachmentMerge.optionFromRow(id: string, row: any): OptionEntry
	local deltas: { Delta } = {}
	for _, delta in row.Deltas do
		table.insert(deltas, { field = delta.Field, op = delta.Op :: Op, value = delta.Value })
	end
	return {
		id = id,
		slot = row.Slot,
		compatibleGuns = table.clone(row.Guns),
		incompatibleWith = table.clone(row.IncompatibleWith or {}),
		deltas = deltas,
		clashReasons = reasons(row),
		meritCost = row.Price,
		base = row.Base == true,
	}
end

-- A Config.Optics row in the Optic slot `slot`: its zoom and ADS multipliers as deltas.
function AttachmentMerge.opticFromRow(id: string, row: any, slot: string): OptionEntry
	local deltas: { Delta } = {
		{ field = "zoom", op = "multiply", value = row.ZoomMultiplier },
		{ field = "adsTime", op = "multiply", value = row.AdsTimeMultiplier },
	}
	return {
		id = id,
		slot = slot,
		compatibleGuns = table.clone(row.Guns),
		incompatibleWith = {},
		deltas = deltas,
		clashReasons = {},
		meritCost = row.Price,
		base = false,
	}
end

-- A Config.AttachmentsV2.Ammo row in the ammo slot `slot`.
function AttachmentMerge.ammoFromRow(id: string, row: any, slot: string): AmmoEntry
	return {
		id = id,
		caliberFamily = row.Caliber,
		slot = slot,
		incompatibleWith = table.clone(row.IncompatibleWith or {}),
		clashReasons = reasons(row),
		meritCost = row.Price,
		base = row.Base == true,
		damageProfile = {
			damage = row.Damage,
			projectileCount = row.Projectiles,
			headshotMultiplier = row.HeadshotMultiplier,
			armorPenetration = row.ArmourPenetration,
			alertRadiusMultiplier = row.AlertMultiplier,
			projectileBehavior = row.Behaviour,
			rangeMultiplier = row.RangeMultiplier,
			spreadMultiplier = row.SpreadMultiplier,
			recoilMultiplier = row.RecoilMultiplier,
			burn = if row.Burn
				then { damage = row.Burn.Damage, seconds = row.Burn.Seconds }
				else nil,
		},
	}
end

-- The numbers of a gun row (a Config.Weapons row, or a WeaponDefinition: the same names) as
-- the stat block, as issued; `noise` replaces its Noise (the suppressed barrel's reach).
function AttachmentMerge.gunStats(row: any, noise: number?): GunStats
	return {
		damage = row.Damage,
		projectileCount = row.Pellets or 1,
		headshotMultiplier = row.HeadshotMultiplier,
		armorPenetration = 0,
		projectileBehavior = "standard",
		alertRadius = noise or row.Noise,
		range = row.Range,
		recoil = 1,
		recoilRecovery = 1,
		moveSpeed = 1,
		adsTime = 1,
		zoom = 1,
		magazineSize = row.MagazineSize,
		reloadTime = row.ReloadTime,
		hipSpread = row.HipSpread,
		adsSpread = row.AdsSpread,
		breachPower = 1,
		burn = nil,
	}
end

return AttachmentMerge
