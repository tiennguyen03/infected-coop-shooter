--!strict
-- The ammo families on every gun (Nova, 2026-11-20): 5.56, 9mm, 12-gauge, 7.62, .50 BMG,
-- .357. Each type is defined once per caliber family and every gun of that family takes it;
-- a shared family scales each gun's own damage (DamageScale) so the MP5 and the M17 keep their
-- own tuning on the same FMJ. Read from the shipped Config rows. Written before the rows.
local DoT = require("../src/shared/Rules/DoT")
local WallBreach = require("../src/shared/Rules/WallBreach")
local expect = require("./expect")
local G = require("./gunFixture")

local Config = G.Config
local AMMO = G.AMMO_SLOT
local ROWS = Config.AttachmentsV2.Ammo

local function near(actual: number, expected: number, label: string)
	expect.near(actual, expected, 1e-6, label)
end

-- Each family: its guns, its rounds.
local FAMILIES: { [string]: { guns: { string }, ammo: { string } } } = {
	["5.56"] = {
		guns = { "service_rifle", "lmg" },
		ammo = { "ammo_556_fmj", "ammo_556_ap", "ammo_556_hp" },
	},
	["9mm"] = {
		guns = { "smg", "pistol" },
		ammo = { "ammo_9mm_fmj", "ammo_9mm_hp", "ammo_9mm_ap", "ammo_9mm_subsonic" },
	},
	["12ga"] = {
		guns = { "shotgun" },
		ammo = {
			"ammo_12ga_buckshot",
			"ammo_12ga_slug",
			"ammo_12ga_dragons_breath",
			"ammo_12ga_breaching",
		},
	},
	["7.62"] = {
		guns = { "dmr", "sniper" },
		ammo = { "ammo_762_fmj", "ammo_762_ap", "ammo_762_hp", "ammo_762_subsonic" },
	},
	[".50 BMG"] = { guns = { "fifty" }, ammo = { "ammo_50_standard", "ammo_50_ap" } },
	[".357"] = { guns = { "revolver" }, ammo = { "ammo_357_standard", "ammo_357_plus_p" } },
}

-- The damage a round lands from gun `gunId`: the row's own, or the gun's scaled.
local function expectedDamage(gunId: string, id: string): number
	local row = ROWS[id]
	if row.DamageScale then
		return G.row(gunId).Damage * row.DamageScale
	end
	return row.Damage
end

return {
	["each family's guns take each of its rounds, one base each, free"] = function()
		for caliber, family in FAMILIES do
			for _, gunId in family.guns do
				expect.equal(G.row(gunId).Caliber, caliber, `{gunId} caliber`)
				local ids = G.idsIn(gunId, AMMO)
				for _, id in family.ammo do
					expect.equal(ROWS[id].Caliber, caliber, `{id} caliber`)
					expect.equal(table.find(ids, id) ~= nil, true, `{gunId} takes {id}`)
				end
				local bases = 0
				for _, id in ids do
					if ROWS[id].Base then
						bases += 1
						expect.equal(ROWS[id].Price, 0, `{id} free`)
					end
				end
				expect.equal(bases, 1, `{gunId} one base round`)
			end
		end
	end,
	["each round overrides damage, count, head, armour pen and alert per round, not per gun"] = function()
		for _, family in FAMILIES do
			for _, gunId in family.guns do
				local issued = G.stats(gunId, {})
				for _, id in family.ammo do
					local row = ROWS[id]
					local stats = G.stats(gunId, { [AMMO] = id })
					near(stats.damage, expectedDamage(gunId, id), `{gunId} {id} damage`)
					expect.equal(stats.projectileCount, row.Projectiles, `{gunId} {id} count`)
					near(stats.headshotMultiplier, row.HeadshotMultiplier, `{gunId} {id} head`)
					near(stats.armorPenetration, row.ArmourPenetration, `{gunId} {id} pen`)
					near(
						stats.alertRadius,
						issued.alertRadius * row.AlertMultiplier,
						`{gunId} {id} alert`
					)
					near(stats.range, issued.range * row.RangeMultiplier, `{gunId} {id} range`)
					expect.equal(stats.projectileBehavior, row.Behaviour, `{gunId} {id} behaviour`)
					expect.equal(
						stats.magazineSize,
						issued.magazineSize,
						`{gunId} {id}: rounds are rounds`
					)
				end
			end
		end
	end,
	["the base round of each gun is the gun as issued"] = function()
		for _, family in FAMILIES do
			for _, gunId in family.guns do
				local issued = G.stats(gunId, {})
				for _, id in G.idsIn(gunId, AMMO) do
					if ROWS[id].Base then
						local stats = G.stats(gunId, { [AMMO] = id })
						for field, value in issued :: any do
							if typeof(value) == "number" then
								near((stats :: any)[field], value, `{gunId} {id} {field}`)
							end
						end
					end
				end
			end
		end
	end,
	["one 9mm FMJ, two guns' own damage"] = function()
		near(G.stats("smg", { [AMMO] = "ammo_9mm_fmj" }).damage, G.row("smg").Damage, "MP5")
		near(G.stats("pistol", { [AMMO] = "ammo_9mm_fmj" }).damage, G.row("pistol").Damage, "M17")
		local hpSmg = G.stats("smg", { [AMMO] = "ammo_9mm_hp" }).damage / G.row("smg").Damage
		local hpPistol = G.stats("pistol", { [AMMO] = "ammo_9mm_hp" }).damage
			/ G.row("pistol").Damage
		near(hpSmg, hpPistol, "HP scales both the same")
	end,
	["buckshot 8, slug 1, Dragon's Breath 8 that burn"] = function()
		expect.equal(
			G.stats("shotgun", { [AMMO] = "ammo_12ga_buckshot" }).projectileCount,
			8,
			"buck"
		)
		expect.equal(G.stats("shotgun", { [AMMO] = "ammo_12ga_slug" }).projectileCount, 1, "slug")
		local dragon = G.stats("shotgun", { [AMMO] = "ammo_12ga_dragons_breath" })
		expect.equal(dragon.projectileCount, 8, "dragon")
		expect.equal(dragon.projectileBehavior, "incendiary", "incendiary")
		local burn = dragon.burn :: any
		local state = DoT.new()
		expect.equal(
			DoT.add(state, 0, burn.damage, burn.seconds, Config.DoT.MaxStacks),
			true,
			"incendiary -> a fire DoT"
		)
	end,
	["tracer rounds are tracer behaviour, louder; the M249's heavier still"] = function()
		local rifle = G.stats("service_rifle", { [AMMO] = "ammo_556_tracer" })
		local belt = G.stats("lmg", { [AMMO] = "ammo_556_tracer_heavy" })
		expect.equal(rifle.projectileBehavior, "tracer", "rifle tracer")
		expect.equal(belt.projectileBehavior, "tracer", "belt tracer")
		expect.equal(
			ROWS.ammo_556_tracer_heavy.AlertMultiplier > ROWS.ammo_556_tracer.AlertMultiplier,
			true,
			"more tracers in the belt, louder"
		)
	end,
	["breaching rounds open a light wall"] = function()
		local stats = G.stats("shotgun", { [AMMO] = "ammo_12ga_breaching" })
		expect.equal(stats.projectileBehavior, "breaching", "behaviour")
		expect.equal(
			WallBreach.hitsToBreak(stats.breachPower :: number, Config.WallBreach.Toughness)
				< math.huge,
			true,
			"it opens one"
		)
	end,
	["subsonic is quieter through the suppressor than FMJ is"] = function()
		for _, pair in
			{
				{ "smg", "ammo_9mm" },
				{ "pistol", "ammo_9mm" },
				{ "dmr", "ammo_762" },
				{ "sniper", "ammo_762" },
			}
		do
			local gunId, prefix = pair[1], pair[2]
			local fmj = G.stats(gunId, { Barrel = "suppressor", [AMMO] = `{prefix}_fmj` })
			local sub = G.stats(gunId, { Barrel = "suppressor", [AMMO] = `{prefix}_subsonic` })
			expect.equal(sub.projectileBehavior, "subsonic", `{gunId} behaviour`)
			expect.equal(sub.alertRadius < fmj.alertRadius, true, `{gunId} quieter`)
		end
	end,
	[".50 AP goes through plates; .357 +P hits harder and kicks"] = function()
		local ap = G.stats("fifty", { [AMMO] = "ammo_50_ap" })
		expect.equal(ap.armorPenetration > 0.5, true, "AP")
		local plus = G.stats("revolver", { [AMMO] = "ammo_357_plus_p" })
		local std = G.stats("revolver", { [AMMO] = "ammo_357_standard" })
		expect.equal(plus.damage > std.damage, true, "+P harder")
		expect.equal(plus.recoil > std.recoil, true, "+P kicks")
	end,
}
