--!strict
-- The multi-slot stat merge (Rules/AttachmentMerge.merge; attachment system v2, Nova
-- 2026-11-20). Written before the rule.
local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local expect = require("./expect")

type Option = AttachmentMerge.Option
type Ammo = AttachmentMerge.Ammo

local GUN = "service_rifle"

local function base(): AttachmentMerge.GunStats
	return {
		damage = 20,
		projectileCount = 1,
		headshotMultiplier = 3,
		armorPenetration = 0,
		projectileBehavior = "standard",
		alertRadius = 110,
		range = 400,
		recoil = 1,
		recoilRecovery = 1,
		moveSpeed = 1,
		adsTime = 1,
		zoom = 1,
		magazineSize = 30,
		reloadTime = 2.2,
		hipSpread = 1.5,
	}
end

local GUN_INFO: AttachmentMerge.Gun = { id = GUN, caliber = "5.56", stats = base() }

local function option(
	id: string,
	slot: string,
	deltas: { AttachmentMerge.Delta },
	incompatible: { string }?
): Option
	return {
		id = id,
		slot = slot,
		compatibleGuns = { GUN },
		incompatibleWith = incompatible or {},
		deltas = deltas,
	}
end

local LONG = option("barrel_long", "Barrel", {
	{ field = "range", op = "multiply", value = 1.15 },
	{ field = "recoil", op = "multiply", value = 1.10 },
	{ field = "moveSpeed", op = "multiply", value = 0.95 },
})
local SUPPRESSED = option("suppressor", "Barrel", {
	{ field = "range", op = "multiply", value = 0.8 },
	{ field = "damage", op = "multiply", value = 0.9 },
}, { "muzzle_suppressor" })
local MUZZLE_SUPPRESSOR = option("muzzle_suppressor", "Muzzle", {
	{ field = "alertRadius", op = "multiply", value = 0.3 },
})
local BRAKE = option("muzzle_brake", "Muzzle", {
	{ field = "recoil", op = "multiply", value = 0.75 },
	{ field = "alertRadius", op = "multiply", value = 1.10 },
})
local EXTENDED = option("mag_extended", "Magazine", {
	{ field = "magazineSize", op = "add", value = 10 },
	{ field = "reloadTime", op = "multiply", value = 1.2 },
})
local DRUM = option("mag_drum", "Magazine", {
	{ field = "magazineSize", op = "add", value = 30 },
	{ field = "reloadTime", op = "multiply", value = 1.5 },
	{ field = "moveSpeed", op = "multiply", value = 0.9 },
}, { "stock_collapsed" })
local ACOG = option("acog", "Optic", {
	{ field = "zoom", op = "multiply", value = 3 },
	{ field = "adsTime", op = "multiply", value = 1.6 },
})
local GRIP = option("grip_vertical", "Underbarrel", {
	{ field = "recoilRecovery", op = "multiply", value = 1.2 },
})
local STOCK = option("stock_adjustable", "Stock", {
	{ field = "recoilRecovery", op = "multiply", value = 1.15 },
	{ field = "adsTime", op = "multiply", value = 1.1 },
})
local COLLAPSED = option("stock_collapsed", "Stock", {
	{ field = "recoilRecovery", op = "multiply", value = 0.9 },
	{ field = "adsTime", op = "multiply", value = 0.85 },
})

local function ammo(id: string, caliber: string, profile: AttachmentMerge.DamageProfile): Ammo
	return { id = id, caliberFamily = caliber, damageProfile = profile, incompatibleWith = {} }
end

local HP = ammo("ammo_556_hp", "5.56", {
	damage = 28,
	projectileCount = 1,
	headshotMultiplier = 4,
	armorPenetration = 0,
	alertRadiusMultiplier = 1,
	projectileBehavior = "standard",
	rangeMultiplier = 1,
})
local TRACER = ammo("ammo_556_tracer", "5.56", {
	damage = 20,
	projectileCount = 1,
	headshotMultiplier = 3,
	armorPenetration = 0,
	alertRadiusMultiplier = 1.2,
	projectileBehavior = "tracer",
	rangeMultiplier = 1,
})
local BUCKSHOT = ammo("ammo_12_buck", "12ga", {
	damage = 11,
	projectileCount = 8,
	headshotMultiplier = 1.5,
	armorPenetration = 0,
	alertRadiusMultiplier = 1,
	projectileBehavior = "standard",
	rangeMultiplier = 1,
})

local function near(actual: number, wanted: number, label: string)
	expect.near(actual, wanted, 1e-9, label)
end

local function merged(equipped: { [string]: Option }, chosen: Ammo?): AttachmentMerge.GunStats
	local stats, reason = AttachmentMerge.merge(GUN_INFO, equipped, chosen)
	expect.equal(reason, nil, "no rejection")
	return stats :: AttachmentMerge.GunStats
end

return {
	["no attachments: the final stats are the gun's own"] = function()
		local stats = merged({}, nil)
		local own = base()
		for field, value in own do
			expect.equal((stats :: any)[field], value, field)
		end
	end,
	["the base is never changed by a merge"] = function()
		merged({ Barrel = LONG }, HP)
		expect.equal(GUN_INFO.stats.range, 400, "range")
		expect.equal(GUN_INFO.stats.damage, 20, "damage")
	end,
	["one attachment applies its deltas"] = function()
		local stats = merged({ Barrel = LONG }, nil)
		near(stats.range, 460, "range")
		near(stats.recoil, 1.1, "recoil")
		near(stats.moveSpeed, 0.95, "moveSpeed")
		expect.equal(stats.damage, 20, "damage untouched")
	end,
	["every slot filled: all deltas compose"] = function()
		local stats = merged({
			Optic = ACOG,
			Barrel = LONG,
			Muzzle = BRAKE,
			Magazine = EXTENDED,
			Underbarrel = GRIP,
			Stock = STOCK,
		}, TRACER)
		near(stats.range, 460, "range")
		near(stats.recoil, 1.1 * 0.75, "recoil: long barrel x brake")
		near(stats.alertRadius, 110 * 1.10 * 1.2, "alert: brake x tracer")
		expect.equal(stats.magazineSize, 40, "magazine")
		near(stats.reloadTime, 2.2 * 1.2, "reload")
		near(stats.recoilRecovery, 1.2 * 1.15, "recovery: grip x stock")
		near(stats.adsTime, 1.6 * 1.1, "ADS: ACOG x stock")
		near(stats.zoom, 3, "zoom")
		expect.equal(stats.projectileBehavior, "tracer", "behaviour")
	end,
	["multiply composes multiplicatively"] = function()
		local stats = merged({ Underbarrel = GRIP, Stock = STOCK }, nil)
		near(stats.recoilRecovery, 1.38, "1.2 x 1.15")
	end,
	["add composes additively"] = function()
		local plusTen =
			option("a", "Magazine", { { field = "magazineSize", op = "add", value = 10 } })
		local plusFive =
			option("b", "Underbarrel", { { field = "magazineSize", op = "add", value = 5 } })
		local stats = merged({ Magazine = plusTen, Underbarrel = plusFive }, nil)
		expect.equal(stats.magazineSize, 45, "30 + 10 + 5")
	end,
	["multipliers scale the gun's own value, additions are added after"] = function()
		local times =
			option("a", "Magazine", { { field = "magazineSize", op = "multiply", value = 2 } })
		local plus =
			option("b", "Underbarrel", { { field = "magazineSize", op = "add", value = 10 } })
		local stats = merged({ Magazine = times, Underbarrel = plus }, nil)
		expect.equal(stats.magazineSize, 70, "30 x 2 + 10, not (30 + 10) x 2")
	end,
	["the ammo type replaces the damage profile"] = function()
		local stats = merged({}, HP)
		expect.equal(stats.damage, 28, "damage")
		expect.equal(stats.headshotMultiplier, 4, "headshot")
		expect.equal(stats.armorPenetration, 0, "armour pen")
		expect.equal(stats.projectileCount, 1, "projectiles")
		expect.equal(stats.alertRadius, 110, "alert x1")
		expect.equal(stats.range, 400, "range x1")
	end,
	["attachments still scale the ammo's round"] = function()
		local stats = merged({ Barrel = SUPPRESSED }, HP)
		near(stats.damage, 28 * 0.9, "the suppressed barrel's -10% on the HP round")
		near(stats.range, 400 * 0.8, "range")
	end,
	["a suppressed barrel and a suppressor muzzle device are refused together"] = function()
		local stats, reason = AttachmentMerge.merge(
			GUN_INFO,
			{ Barrel = SUPPRESSED, Muzzle = MUZZLE_SUPPRESSOR },
			nil
		)
		expect.equal(stats, nil, "no stats")
		expect.equal(reason, "incompatible:suppressor:muzzle_suppressor", "reason")
	end,
	["an incompatibility declared on either side refuses"] = function()
		local _, reason =
			AttachmentMerge.merge(GUN_INFO, { Stock = COLLAPSED, Magazine = DRUM }, nil)
		expect.equal(reason, "incompatible:mag_drum:stock_collapsed", "the drum names the stock")
	end,
	["ammo of the wrong caliber is refused"] = function()
		local stats, reason = AttachmentMerge.merge(GUN_INFO, {}, BUCKSHOT)
		expect.equal(stats, nil, "no stats")
		expect.equal(reason, "caliber:ammo_12_buck", "reason")
	end,
	["ammo that names a barrel it cannot go through is refused"] = function()
		local dragon = ammo("ammo_556_test_fire", "5.56", {
			damage = 10,
			projectileCount = 1,
			headshotMultiplier = 1,
			armorPenetration = 0,
			alertRadiusMultiplier = 1,
			projectileBehavior = "incendiary",
			rangeMultiplier = 1,
		})
		dragon.incompatibleWith = { "suppressor" }
		local _, reason = AttachmentMerge.merge(GUN_INFO, { Barrel = SUPPRESSED }, dragon)
		expect.equal(reason, "incompatible:ammo_556_test_fire:suppressor", "reason")
	end,
	["an option for another gun is refused"] = function()
		local other = option("mp5_thing", "Barrel", {})
		other.compatibleGuns = { "smg" }
		local _, reason = AttachmentMerge.merge(GUN_INFO, { Barrel = other }, nil)
		expect.equal(reason, "gun:mp5_thing", "reason")
	end,
	["an option in the wrong slot is refused"] = function()
		local _, reason = AttachmentMerge.merge(GUN_INFO, { Muzzle = LONG }, nil)
		expect.equal(reason, "slot:barrel_long", "reason")
	end,
	["ammo multipliers scale range and alert"] = function()
		local far = ammo("ammo_556_far", "5.56", {
			damage = 20,
			projectileCount = 1,
			headshotMultiplier = 3,
			armorPenetration = 0.5,
			alertRadiusMultiplier = 0.5,
			projectileBehavior = "subsonic",
			rangeMultiplier = 1.5,
		})
		local stats = merged({ Barrel = LONG }, far)
		near(stats.range, 400 * 1.5 * 1.15, "range: ammo x barrel")
		near(stats.alertRadius, 55, "alert")
		near(stats.armorPenetration, 0.5, "pen")
		expect.equal(stats.projectileBehavior, "subsonic", "behaviour")
	end,
	["armour penetration stays between 0 and 1"] = function()
		local over =
			option("x", "Underbarrel", { { field = "armorPenetration", op = "add", value = 2 } })
		local stats = merged({ Underbarrel = over }, nil)
		expect.equal(stats.armorPenetration, 1, "clamped")
	end,
	["a bad delta value is ignored"] = function()
		local nan = 0 / 0
		local bad = option("x", "Underbarrel", {
			{ field = "range", op = "multiply", value = nan },
			{ field = "range", op = "multiply", value = -1 },
			{ field = "range", op = "add", value = math.huge },
		})
		local stats = merged({ Underbarrel = bad }, nil)
		expect.equal(stats.range, 400, "range unchanged")
	end,
}
