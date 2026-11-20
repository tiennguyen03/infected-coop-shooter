--!strict
-- The 12-gauge ammo family on the Mossberg 590 (Nova, 2026-11-20): buckshot, slug, Dragon's
-- Breath, breaching. Each is a whole damage profile that replaces the gun's own
-- (Rules/AttachmentMerge); read from the shipped Config rows. Written before the rows.
local DoT = require("../src/shared/Rules/DoT")
local WallBreach = require("../src/shared/Rules/WallBreach")
local expect = require("./expect")
local M = require("./mossbergFixture")

local Config = M.Config
local AMMO = M.AMMO_SLOT
local BUCK = "ammo_12ga_buckshot"
local SLUG = "ammo_12ga_slug"
local DRAGON = "ammo_12ga_dragons_breath"
local BREACHING = "ammo_12ga_breaching"
local ALL = { BUCK, SLUG, DRAGON, BREACHING }

local function near(actual: number, expected: number, label: string)
	expect.near(actual, expected, 1e-6, label)
end

return {
	["four 12-gauge rounds, buckshot the issued one"] = function()
		local bases = 0
		for _, id in ALL do
			local row = Config.AttachmentsV2.Ammo[id]
			expect.equal(row ~= nil, true, id)
			expect.equal(row.Caliber, "12ga", `{id} caliber`)
			if row.Base then
				bases += 1
				expect.equal(id, BUCK, "the base")
				expect.equal(row.Price, 0, "free")
			else
				expect.equal(row.Price > 0, true, `{id} costs merits`)
			end
		end
		expect.equal(bases, 1, "one base")
	end,
	["buckshot: 8 pellets of 11, 1.5x head, 45 studs, as issued"] = function()
		local stats = M.stats({ [AMMO] = BUCK })
		expect.equal(stats.projectileCount, 8, "pellets")
		near(stats.damage, 11, "damage")
		near(stats.headshotMultiplier, 1.5, "head")
		near(stats.range, 45, "range")
		expect.equal(stats.projectileBehavior, "standard", "behaviour")
		local issued = M.stats({})
		for field, value in issued :: any do
			expect.equal((stats :: any)[field], value, `buckshot is the issued round: {field}`)
		end
	end,
	["slug: one ball of 80, 3x head, 200 studs, kicks 20% harder, no pellet pattern"] = function()
		local stats = M.stats({ [AMMO] = SLUG })
		local issued = M.stats({})
		expect.equal(stats.projectileCount, 1, "one projectile")
		near(stats.damage, 80, "damage")
		near(stats.headshotMultiplier, 3, "head")
		near(stats.range, 200, "range")
		near(stats.recoil, 1.2, "recoil")
		expect.equal(stats.projectileBehavior, "standard", "behaviour")
		expect.equal(stats.hipSpread < issued.hipSpread / 4, true, "no spread from the hip")
		expect.equal(
			(stats.adsSpread :: number) < (issued.adsSpread :: number) / 4,
			true,
			"nor aimed"
		)
	end,
	["Dragon's Breath: 8 pellets of 6, each hit burns 15 over 5 s, louder"] = function()
		local stats = M.stats({ [AMMO] = DRAGON })
		local buck = M.stats({ [AMMO] = BUCK })
		expect.equal(stats.projectileCount, 8, "pellets")
		near(stats.damage, 6, "damage")
		near(stats.headshotMultiplier, 1.5, "head")
		near(stats.range, 45, "range")
		expect.equal(stats.projectileBehavior, "incendiary", "behaviour")
		local burn = stats.burn
		if not burn then
			error("no burn")
		end
		near(burn.damage, 15, "burn damage")
		near(burn.seconds, 5, "burn seconds")
		expect.equal(
			stats.alertRadius > buck.alertRadius,
			true,
			"the hissing pellets carry further"
		)
		expect.equal(buck.burn, nil, "buckshot does not burn")
	end,
	["Dragon's Breath burns stack across pellets on one Infected"] = function()
		local stats = M.stats({ [AMMO] = DRAGON })
		local burn = stats.burn :: any
		local state = DoT.new()
		for _ = 1, stats.projectileCount do
			DoT.add(state, 0, burn.damage, burn.seconds, Config.DoT.MaxStacks)
		end
		near(DoT.remaining(state, 0), 15 * 8, "eight burns")
		near(stats.damage * stats.projectileCount, 48, "less up front than buckshot's 88")
	end,
	["breaching: one heavy slug of 30, 1x head, 60 studs, breaks a thin wall"] = function()
		local stats = M.stats({ [AMMO] = BREACHING })
		expect.equal(stats.projectileCount, 1, "one projectile")
		near(stats.damage, 30, "damage")
		near(stats.headshotMultiplier, 1, "head")
		near(stats.range, 60, "range")
		expect.equal(stats.projectileBehavior, "breaching", "behaviour")
		local settings = Config.WallBreach
		expect.equal(WallBreach.breakable("Wall", 0.6, "WoodPlanks", settings), true, "a hut wall")
		local damage, broken = 0, false
		local shots = 0
		while not broken and shots < 10 do
			damage, broken =
				WallBreach.struck(damage, stats.breachPower :: number, settings.Toughness)
			shots += 1
		end
		expect.equal(broken, true, "it opens")
		expect.equal(shots, 2, "two shots on the standard muzzle")
	end,
	["only the breaching round breaks walls"] = function()
		for _, id in { BUCK, SLUG, DRAGON } do
			expect.equal(M.stats({ [AMMO] = id }).projectileBehavior ~= "breaching", true, id)
		end
	end,
	["shells are shells: the round never changes the tube"] = function()
		for _, id in ALL do
			expect.equal(M.stats({ [AMMO] = id }).magazineSize, 8, `{id} in the issued tube`)
			expect.equal(
				M.stats({ Magazine = "m590_tube_12", [AMMO] = id }).magazineSize,
				12,
				`{id} in the high-cap tube`
			)
		end
	end,
	["the headshot multiplier is the round's, not the gun's"] = function()
		for _, id in ALL do
			near(
				M.stats({ [AMMO] = id }).headshotMultiplier,
				Config.AttachmentsV2.Ammo[id].HeadshotMultiplier,
				id
			)
		end
	end,
	["attachments still act on the new round"] = function()
		local slug = M.stats({ [AMMO] = SLUG })
		local short = M.stats({ Barrel = "m590_barrel_14", [AMMO] = SLUG })
		near(short.range, slug.range * 0.8, "the short barrel's -20% on the slug's 200")
		local comp = M.stats({ Muzzle = "m590_muzzle_compensator", [AMMO] = SLUG })
		near(comp.recoil, 1.2 * 0.85, "the compensator on the slug's kick")
	end,
	["the Mossberg's other parts, as specified"] = function()
		local issued = M.stats({})
		local short = M.stats({ Barrel = "m590_barrel_14" })
		near(short.range, issued.range * 0.8, "short range")
		near(short.moveSpeed, 1.1, "short move")
		near(short.adsTime, 0.9, "short ADS")
		expect.equal(short.hipSpread > issued.hipSpread, true, "short spreads wider")
		local choke = M.stats({ Barrel = "m590_barrel_choke" })
		near(choke.range, issued.range * 1.2, "choke range")
		near(choke.moveSpeed, 0.9, "choke move")
		local comp = M.stats({ Muzzle = "m590_muzzle_compensator" })
		near(comp.recoil, 0.85, "comp recoil")
		near(comp.alertRadius, issued.alertRadius * 1.05, "comp alert")
		local ten = M.stats({ Magazine = "m590_tube_10" })
		expect.equal(ten.magazineSize, 10, "10 shells")
		near(ten.reloadTime, issued.reloadTime * 1.15, "10 reload")
		local twelve = M.stats({ Magazine = "m590_tube_12" })
		expect.equal(twelve.magazineSize, 12, "12 shells")
		near(twelve.reloadTime, issued.reloadTime * 1.3, "12 reload")
		near(twelve.moveSpeed, 0.95, "12 move")
		near(M.stats({ Underbarrel = "m590_grip_vertical" }).recoilRecovery, 1.2, "grip")
		near(M.stats({ Underbarrel = "m590_laser" }).hipSpread, issued.hipSpread * 0.7, "laser")
		near(
			M.stats({ Underbarrel = "m590_sidesaddle" }).reloadTime,
			issued.reloadTime / 1.15,
			"side-saddle: 15% faster"
		)
		local pistol = M.stats({ Stock = "m590_stock_pistol" })
		near(pistol.adsTime, 0.9, "pistol ADS")
		near(pistol.recoilRecovery, 0.85, "pistol recovery")
		local collapsed = M.stats({ Stock = "m590_stock_collapsed" })
		near(collapsed.moveSpeed, 1.1, "collapsed move")
		near(collapsed.recoilRecovery, 0.9, "collapsed recovery")
		local dot = M.stats({ Optic = "reddot" })
		expect.equal(dot.adsTime < 1, true, "the red dot is faster in")
		near(dot.zoom, 1, "no magnification")
	end,
}
