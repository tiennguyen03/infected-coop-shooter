--!strict
-- Every gun on attachment system v2 (Nova, 2026-11-20: the rollout to the whole kit): each gun's
-- slots, the pairs refused (Rules/AttachmentMerge, Rules/AttachmentUnlock) and the pairs only
-- warned about (Rules/GunCompatibility), read from the shipped Config rows. Written before the
-- rows.
local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local AttachmentUnlock = require("../src/shared/Rules/AttachmentUnlock")
local GunCompatibility = require("../src/shared/Rules/GunCompatibility")
local expect = require("./expect")
local G = require("./gunFixture")

local Config = G.Config
local AMMO = G.AMMO_SLOT

-- Each gun's slots (the brief's table): long guns 6-7, sidearms 3-4. The Goose stays out.
local SLOTS: { [string]: { string } } = {
	service_rifle = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Underbarrel", "Stock" },
	smg = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Underbarrel", "Stock" },
	lmg = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Stock" },
	shotgun = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Underbarrel", "Stock" },
	dmr = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Underbarrel", "Stock" },
	sniper = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Stock" },
	fifty = { "Optic", "Barrel", "Muzzle", "Magazine", AMMO, "Stock" },
	pistol = { "Optic", "Barrel", "Magazine", AMMO },
	revolver = { "Optic", "Barrel", AMMO },
}

local function refused(gunId: string, fitting: { [string]: string }, a: string, b: string)
	local stats, reason = G.merge(gunId, fitting)
	expect.equal(stats, nil, `{gunId}: {a} with {b} merged`)
	local text = tostring(reason)
	if text ~= `incompatible:{a}:{b}` and text ~= `incompatible:{b}:{a}` then
		error(`{gunId}: {a} with {b} refused for {text}`)
	end
	local catalog = G.catalog
	local slotA, slotB = G.entry(a).slot, G.entry(b).slot
	local ok, why =
		AttachmentUnlock.canEquip(G.richRecord(), gunId, slotA, a, { [slotB] = b }, catalog)
	expect.equal(ok, false, `{gunId}: fit {a} next to {b}`)
	expect.equal(why, `incompatible:{b}`, "the reason names the other")
	expect.equal(
		typeof(AttachmentMerge.clashReason(G.entry(a), G.entry(b))),
		"string",
		`a reason for {a} with {b}`
	)
end

local function allowed(gunId: string, fitting: { [string]: string })
	local stats, reason = G.merge(gunId, fitting)
	if not stats then
		error(`{gunId} refused: {reason}`)
	end
end

local function warningsFor(gunId: string, fitting: { [string]: string }): { string }
	return GunCompatibility.warnings(gunId, fitting, G.catalog)
end

return {
	["every gun but the Goose takes its slots, 2 to 4 options each (5 rounds on the M2010)"] = function()
		for gunId, wanted in SLOTS do
			local row = G.row(gunId)
			expect.equal(type(row.Family), "string", `{gunId} family`)
			expect.equal(type(row.Caliber), "string", `{gunId} caliber`)
			for _, slot in wanted do
				local ids = G.idsIn(gunId, slot)
				local most = if slot == AMMO and gunId == "sniper" then 5 else 4
				if #ids < 2 or #ids > most then
					error(`{gunId} {slot}: {#ids} options`)
				end
			end
			for slot in Config.AttachmentsV2.Slots do
				if not table.find(wanted, slot) then
					expect.equal(#G.idsIn(gunId, slot), 0, `{gunId} takes no {slot}`)
				end
			end
		end
		expect.equal(G.row("goose").Family, nil, "the Goose stays off v2")
	end,
	["the issued parts change nothing on any gun"] = function()
		for gunId in SLOTS do
			local issued = G.stats(gunId, {})
			local fitting: { [string]: string } = {}
			for slot in Config.AttachmentsV2.Slots do
				for _, id in G.idsIn(gunId, slot) do
					if G.entry(id).base then
						fitting[slot] = id
					end
				end
			end
			local based = G.stats(gunId, fitting)
			for field, value in issued :: any do
				if typeof(value) == "number" then
					expect.near((based :: any)[field], value, 1e-6, `{gunId} {field}`)
				else
					expect.equal((based :: any)[field], value, `{gunId} {field}`)
				end
			end
		end
	end,
	["every clash on every gun names a real part and says why"] = function()
		for _, list in { G.catalog.options, G.catalog.ammo } do
			for id, entry in list :: { [string]: any } do
				for _, other in entry.incompatibleWith do
					local ok, found = pcall(G.entry, other)
					expect.equal(ok, true, `{id} names {other}`)
					expect.equal(
						typeof(AttachmentMerge.clashReason(entry, found)),
						"string",
						`{id} says why not {other}`
					)
				end
			end
		end
	end,
	-- Shotgun (real-world: a full choke is not made for slugs or burning magnesium).
	["shotgun: Dragon's Breath and slugs refuse the full choke; buckshot takes it"] = function()
		refused(
			"shotgun",
			{ Barrel = "m590_barrel_choke", [AMMO] = "ammo_12ga_dragons_breath" },
			"ammo_12ga_dragons_breath",
			"m590_barrel_choke"
		)
		refused(
			"shotgun",
			{ Barrel = "m590_barrel_choke", [AMMO] = "ammo_12ga_slug" },
			"ammo_12ga_slug",
			"m590_barrel_choke"
		)
		allowed("shotgun", { Barrel = "m590_barrel_choke", [AMMO] = "ammo_12ga_buckshot" })
	end,
	-- 9mm, the MP5 and the M17: subsonic without a suppressor is a warning, never a refusal.
	["9mm subsonic without a suppressor: allowed, with a warning"] = function()
		for _, gunId in { "smg", "pistol" } do
			allowed(gunId, { [AMMO] = "ammo_9mm_subsonic" })
			local said = warningsFor(gunId, { [AMMO] = "ammo_9mm_subsonic" })
			expect.equal(#said, 1, `{gunId} warns`)
			expect.equal(
				#warningsFor(gunId, { Barrel = "suppressor", [AMMO] = "ammo_9mm_subsonic" }),
				0,
				`{gunId} suppressed: no warning`
			)
			expect.equal(
				#warningsFor(gunId, { [AMMO] = "ammo_9mm_fmj" }),
				0,
				`{gunId} FMJ: no warning`
			)
		end
	end,
	["7.62 subsonic without a suppressor warns too"] = function()
		expect.equal(#warningsFor("dmr", { [AMMO] = "ammo_762_subsonic" }), 1, "M110")
		expect.equal(
			#warningsFor("sniper", { Barrel = "suppressor", [AMMO] = "ammo_762_subsonic" }),
			0,
			"M2010 suppressed"
		)
	end,
	-- The M2010 (real-world: the .300 Win Mag kick through a light stock is uncontrollable).
	["M2010: magnum rounds refuse the lightweight stock"] = function()
		refused(
			"sniper",
			{ Stock = "sr_stock_light", [AMMO] = "ammo_762_magnum" },
			"ammo_762_magnum",
			"sr_stock_light"
		)
		allowed("sniper", { Stock = "sr_stock_adjustable", [AMMO] = "ammo_762_magnum" })
		allowed("sniper", { Stock = "sr_stock_light", [AMMO] = "ammo_762_fmj" })
	end,
	["the magnum round is the M2010's alone"] = function()
		local stats, reason = G.merge("dmr", { [AMMO] = "ammo_762_magnum" })
		expect.equal(stats, nil, "not in the M110")
		expect.equal(reason, "gun:ammo_762_magnum", "the reason")
		expect.equal(
			table.find(G.idsIn("dmr", AMMO), "ammo_762_magnum"),
			nil,
			"not offered on the M110"
		)
	end,
	-- The Fifty (real-world: AP .50 BMG needs the full barrel to stabilise).
	["the Fifty: AP refuses any barrel shorter than standard"] = function()
		refused(
			"fifty",
			{ Barrel = "m82_barrel_20", [AMMO] = "ammo_50_ap" },
			"ammo_50_ap",
			"m82_barrel_20"
		)
		allowed("fifty", { Barrel = "m82_barrel_29", [AMMO] = "ammo_50_ap" })
		allowed("fifty", { Barrel = "m82_barrel_20", [AMMO] = "ammo_50_standard" })
	end,
	["the Fifty takes no grip: its kick stays its kick"] = function()
		expect.equal(#G.idsIn("fifty", "Underbarrel"), 0, "no underbarrel")
	end,
	-- The suppressed barrel leaves no thread for a muzzle device, on every gun that has both.
	["the suppressed barrel refuses every muzzle device"] = function()
		for gunId, wanted in SLOTS do
			if
				table.find(G.idsIn(gunId, "Barrel"), "suppressor") and table.find(wanted, "Muzzle")
			then
				for _, muzzle in G.idsIn(gunId, "Muzzle") do
					if not G.entry(muzzle).base then
						refused(
							gunId,
							{ Barrel = "suppressor", Muzzle = muzzle },
							"suppressor",
							muzzle
						)
					end
				end
			end
		end
	end,
	-- The M249's magazine slot is the belt box.
	["M249: the belt box, 100 issued, 200 or a soft pouch"] = function()
		expect.equal(G.stats("lmg", {}).magazineSize, 100, "issued")
		expect.equal(G.stats("lmg", { Magazine = "lmg_belt_200" }).magazineSize, 200, "the 200 box")
		local pouch = G.stats("lmg", { Magazine = "lmg_belt_pouch" })
		expect.equal(pouch.magazineSize < 100, true, "the pouch holds less")
		expect.equal(pouch.reloadTime < G.stats("lmg", {}).reloadTime, true, "and reloads faster")
	end,
	["the M249 shares 5.56 but fires its own tracer-heavy belt"] = function()
		local ids = G.idsIn("lmg", AMMO)
		for _, id in { "ammo_556_fmj", "ammo_556_ap", "ammo_556_hp", "ammo_556_tracer_heavy" } do
			expect.equal(table.find(ids, id) ~= nil, true, `M249 takes {id}`)
		end
		expect.equal(table.find(ids, "ammo_556_tracer"), nil, "not the rifle's tracer")
		expect.equal(
			table.find(G.idsIn("service_rifle", AMMO), "ammo_556_tracer_heavy"),
			nil,
			"the M16 keeps its own"
		)
	end,
	["the revolver: no magazine, the ammo is its only behaviour slot"] = function()
		expect.equal(#G.idsIn("revolver", "Magazine"), 0, "fixed cylinder")
		local barrel = G.stats("revolver", { Barrel = "r686_barrel_6" })
		local issued = G.stats("revolver", {})
		expect.equal(barrel.range > issued.range, true, "a long barrel reaches")
		expect.equal(barrel.projectileBehavior, "standard", "a barrel never changes the round")
	end,
}
