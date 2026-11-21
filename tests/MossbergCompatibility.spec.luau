--!strict
-- The Mossberg 590 on attachment system v2 (Nova, 2026-11-20): its seven slots and the pairs
-- that cannot go together, read from the shipped Config rows through Rules/AttachmentMerge and
-- Rules/AttachmentUnlock. Written before the rows.
local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local AttachmentUnlock = require("../src/shared/Rules/AttachmentUnlock")
local WallBreach = require("../src/shared/Rules/WallBreach")
local expect = require("./expect")
local M = require("./mossbergFixture")

local Config = M.Config
local AMMO = M.AMMO_SLOT

local DRAGON = "ammo_12ga_dragons_breath"
local SLUG = "ammo_12ga_slug"
local BREACHING = "ammo_12ga_breaching"
local BUCK = "ammo_12ga_buckshot"
local CHOKE = "m590_barrel_choke"
local SUPPRESSED = "suppressor"

local function refused(fitting: { [string]: string }, a: string, b: string)
	local stats, reason = M.merge(fitting)
	expect.equal(stats, nil, `{a} with {b} merged`)
	local text = tostring(reason)
	if text ~= `incompatible:{a}:{b}` and text ~= `incompatible:{b}:{a}` then
		error(`{a} with {b}: refused for {text}`)
	end
	-- The Loadmaster refuses it in either order, and the menu has a reason to say.
	local record = M.richRecord()
	local catalog = M.catalog
	local slotA = (catalog.options[a] or catalog.ammo[a]).slot
	local slotB = (catalog.options[b] or catalog.ammo[b]).slot
	local ok, why = AttachmentUnlock.canEquip(record, M.GUN, slotA, a, { [slotB] = b }, catalog)
	expect.equal(ok, false, `fit {a} next to {b}`)
	expect.equal(why, `incompatible:{b}`, "the reason names the other")
	ok = AttachmentUnlock.canEquip(record, M.GUN, slotB, b, { [slotA] = a }, catalog)
	expect.equal(ok, false, `fit {b} next to {a}`)
	local reasonText = AttachmentMerge.clashReason(
		catalog.options[a] or catalog.ammo[a],
		catalog.options[b] or catalog.ammo[b]
	)
	expect.equal(typeof(reasonText), "string", `a reason for {a} with {b}`)
end

return {
	["the Mossberg takes all seven slots"] = function()
		expect.equal(M.ROW.Family, "shotgun", "family")
		expect.equal(M.ROW.Caliber, "12ga", "caliber")
		local slots = 0
		for id, slot in Config.AttachmentsV2.Slots do
			expect.equal(table.find(slot.Families, "shotgun") ~= nil, true, `{id} takes shotguns`)
			expect.equal(#M.idsIn(id) >= 2, true, `{id} has a choice`)
			expect.equal(#M.idsIn(id) <= slot.MaxOptions, true, `{id} within MaxOptions`)
			slots += 1
		end
		expect.equal(slots, 7, "seven slots")
	end,
	["the options per slot"] = function()
		expect.equal(#M.idsIn("Optic"), 2, "irons, red dot")
		expect.equal(#M.idsIn("Barrel"), 4, "20, 14, full choke, and the suppressed barrel it had")
		expect.equal(#M.idsIn("Muzzle"), 3, "standard, compensator, breaching")
		expect.equal(#M.idsIn("Magazine"), 3, "8, 10, 12")
		expect.equal(#M.idsIn("Underbarrel"), 3, "grip, laser, side-saddle")
		expect.equal(#M.idsIn("Stock"), 3, "standard, pistol grip, collapsed")
		expect.equal(#M.idsIn(AMMO), 4, "four 12-gauge rounds")
	end,
	["each slot with a standard part has exactly one, free"] = function()
		for _, slot in { "Optic", "Barrel", "Muzzle", "Magazine", "Stock", AMMO } do
			local bases = 0
			for _, id in M.idsIn(slot) do
				local entry = M.catalog.options[id] or M.catalog.ammo[id]
				if (entry :: any).base then
					bases += 1
					expect.equal(entry.meritCost, 0, `{id} is free`)
				end
			end
			expect.equal(bases, 1, `{slot} base`)
		end
	end,
	["the standard parts change nothing"] = function()
		local issued = M.stats({})
		local based = M.stats({
			Optic = "m590_irons",
			Barrel = "m590_barrel_20",
			Muzzle = "m590_muzzle_standard",
			Magazine = "m590_tube_8",
			Stock = "m590_stock_standard",
			[AMMO] = BUCK,
		})
		for field, value in issued :: any do
			expect.equal((based :: any)[field], value, field)
		end
	end,
	["Dragon's Breath and a full choke: refused"] = function()
		refused({ Barrel = CHOKE, [AMMO] = DRAGON }, DRAGON, CHOKE)
	end,
	["a slug and a full choke: refused"] = function()
		refused({ Barrel = CHOKE, [AMMO] = SLUG }, SLUG, CHOKE)
	end,
	["Dragon's Breath and the suppressed barrel: refused"] = function()
		refused({ Barrel = SUPPRESSED, [AMMO] = DRAGON }, DRAGON, SUPPRESSED)
	end,
	["the suppressed barrel leaves no thread for a muzzle device"] = function()
		refused(
			{ Barrel = SUPPRESSED, Muzzle = "m590_muzzle_breacher" },
			SUPPRESSED,
			"m590_muzzle_breacher"
		)
		refused(
			{ Barrel = SUPPRESSED, Muzzle = "m590_muzzle_compensator" },
			SUPPRESSED,
			"m590_muzzle_compensator"
		)
	end,
	["buckshot through a full choke is the point of the choke"] = function()
		local stats = M.stats({ Barrel = CHOKE, [AMMO] = BUCK })
		local issued = M.stats({})
		expect.equal(stats.hipSpread < issued.hipSpread, true, "tighter from the hip")
		expect.equal(
			(stats.adsSpread :: number) < (issued.adsSpread :: number),
			true,
			"tighter aimed"
		)
	end,
	["breaching on the standard muzzle is allowed but takes two shots"] = function()
		local stats = M.stats({ Muzzle = "m590_muzzle_standard", [AMMO] = BREACHING })
		expect.equal(
			WallBreach.hitsToBreak(stats.breachPower :: number, Config.WallBreach.Toughness),
			2,
			"two shots"
		)
		local bare = M.stats({ [AMMO] = BREACHING })
		expect.equal(
			WallBreach.hitsToBreak(bare.breachPower :: number, Config.WallBreach.Toughness),
			2,
			"no muzzle fitted is the standard one"
		)
	end,
	["breaching through the breaching muzzle: one shot"] = function()
		local stats = M.stats({ Muzzle = "m590_muzzle_breacher", [AMMO] = BREACHING })
		expect.equal(
			WallBreach.hitsToBreak(stats.breachPower :: number, Config.WallBreach.Toughness),
			1,
			"one shot"
		)
	end,
	["the breaching muzzle without breaching rounds is a standard muzzle"] = function()
		local plain = M.stats({ Muzzle = "m590_muzzle_standard" })
		local breacher = M.stats({ Muzzle = "m590_muzzle_breacher" })
		for field, value in plain :: any do
			if field ~= "breachPower" then
				expect.equal((breacher :: any)[field], value, field)
			end
		end
		expect.equal(breacher.projectileBehavior, "standard", "buckshot never breaches")
	end,
	["every clash names a real part and says why"] = function()
		local catalog = M.catalog
		for _, list in { catalog.options, catalog.ammo } do
			for id, entry in list :: { [string]: any } do
				local mine = (entry.compatibleGuns and table.find(entry.compatibleGuns, M.GUN))
					or entry.caliberFamily == "12ga"
				if mine then
					for _, other in entry.incompatibleWith do
						local found = catalog.options[other] or catalog.ammo[other]
						expect.equal(found ~= nil, true, `{id} names {other}`)
						expect.equal(
							typeof(AttachmentMerge.clashReason(entry, found)),
							"string",
							`{id} says why not {other}`
						)
					end
				end
			end
		end
	end,
	["the M16A4's parts do not fit the Mossberg"] = function()
		local stats, reason = M.merge({ Magazine = "mag_drum" })
		expect.equal(stats, nil, "a rifle drum")
		expect.equal(reason, "gun:mag_drum", "the reason")
		stats, reason = M.merge({ [AMMO] = "ammo_556_fmj" })
		expect.equal(reason, "caliber:ammo_556_fmj", "5.56 in a 12-gauge")
	end,
}
