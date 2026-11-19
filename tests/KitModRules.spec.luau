--!strict
local KitModRules = require("../src/shared/Rules/KitModRules")
local Record = require("../src/shared/Rules/Record")
local expect = require("./expect")

-- Two working mods and one switched off, as Config.KitMods gives them.
local MODS: KitModRules.Mods = {
	stims = {
		id = "stims",
		displayName = "Extra stim",
		description = "",
		maxRank = 3,
		costPerRank = { 100, 200, 300 },
		effectPerRank = 1,
		effect = "StimsCarried",
		enabled = true,
	},
	rolls = {
		id = "rolls",
		displayName = "Extra roll",
		description = "",
		maxRank = 3,
		costPerRank = { 50, 60, 70 },
		effectPerRank = 1,
		effect = "StaminaRolls",
		enabled = true,
	},
	cooldown = {
		id = "cooldown",
		displayName = "Faster call-ins",
		description = "",
		maxRank = 3,
		costPerRank = { 100, 100, 100 },
		effectPerRank = -8,
		effect = "CallInCooldown",
		enabled = false,
	},
}

local function holding(merits: number, owned: { string }): Record.Record
	local record = Record.new(merits)
	record.owned = owned
	return record
end

return {
	["a mod no rank has been bought for is rank 0"] = function()
		expect.equal(KitModRules.rankOf({}, "stims", 3), 0, "rank")
	end,
	["the rank is the highest unbroken rank owned"] = function()
		local owned = { "stims@1", "stims@2", "rolls@1", "rolls@3", "smg" }
		expect.equal(KitModRules.rankOf(owned, "stims", 3), 2, "stims")
		expect.equal(
			KitModRules.rankOf(owned, "rolls", 3),
			1,
			"rolls: rank 3 without rank 2 does not count"
		)
	end,
	["spending when you can afford the next rank takes its cost and raises the rank"] = function()
		local after, ok, reason = KitModRules.buyRank(holding(250, { "stims@1" }), "stims", 2, MODS)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "reason")
		expect.equal(after.merits, 50, "merits left")
		expect.equal(KitModRules.rankOf(after.owned, "stims", 3), 2, "rank")
	end,
	["spending when you cannot afford the next rank is refused and changes nothing"] = function()
		local after, ok, reason = KitModRules.buyRank(holding(99, {}), "stims", 1, MODS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "short", "reason")
		expect.equal(after.merits, 99, "merits")
		expect.equal(#after.owned, 0, "owned")
	end,
	["a mod at its rank cap is refused"] = function()
		local owned = { "rolls@1", "rolls@2", "rolls@3" }
		local after, ok, reason = KitModRules.buyRank(holding(1000, owned), "rolls", 4, MODS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "maxed", "reason")
		expect.equal(after.merits, 1000, "merits")
	end,
	["a disabled mod is refused"] = function()
		local _, ok, reason = KitModRules.buyRank(holding(1000, {}), "cooldown", 1, MODS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "disabled", "reason")
	end,
	["a rank beyond the mod's max rank is refused"] = function()
		local _, ok, reason = KitModRules.buyRank(holding(1000, { "stims@1" }), "stims", 4, MODS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "beyond max", "reason")
	end,
	["only the next rank can be bought: a skip or a repeat is refused"] = function()
		local record = holding(1000, { "stims@1" })
		local _, skipOk, skip = KitModRules.buyRank(record, "stims", 3, MODS)
		expect.equal(skipOk, false, "skip ok")
		expect.equal(skip, "not next", "skip")
		local _, repeatOk, again = KitModRules.buyRank(record, "stims", 1, MODS)
		expect.equal(repeatOk, false, "repeat ok")
		expect.equal(again, "not next", "repeat")
	end,
	["an unknown mod is refused"] = function()
		local _, ok, reason = KitModRules.buyRank(holding(1000, {}), "nope", 1, MODS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "unknown", "reason")
	end,
	["the stored buy keeps merits the match paid since the lobby read the record"] = function()
		local stored = Record.encode(holding(300, { "stims@1" }))
		local saved, reason = KitModRules.buyRankStored(stored, "stims", 2, MODS, 0)
		expect.equal(reason, nil, "reason")
		local after = Record.decode(saved, 0)
		expect.equal(after.merits, 100, "merits")
		expect.equal(KitModRules.rankOf(after.owned, "stims", 3), 2, "rank")
	end,
	["the stored buy refuses on the stored rank, not the one the lobby saw"] = function()
		local stored = Record.encode(holding(1000, { "stims@1", "stims@2" }))
		local saved, reason = KitModRules.buyRankStored(stored, "stims", 2, MODS, 0)
		expect.equal(saved, nil, "nothing written")
		expect.equal(reason, "not next", "reason")
	end,
	["the next rank's cost, none at the cap"] = function()
		expect.equal(KitModRules.nextCost(MODS.stims, 0), 100, "rank 1")
		expect.equal(KitModRules.nextCost(MODS.stims, 2), 300, "rank 3")
		expect.equal(KitModRules.nextCost(MODS.stims, 3), nil, "maxed")
	end,
	["a bonus adds each enabled mod's effect times its rank, and nothing from a disabled one"] = function()
		local ranks = { stims = 2, rolls = 3, cooldown = 3 }
		expect.equal(KitModRules.bonus(ranks, MODS, "StimsCarried"), 2, "stims")
		expect.equal(KitModRules.bonus(ranks, MODS, "StaminaRolls"), 3, "rolls")
		expect.equal(KitModRules.bonus(ranks, MODS, "CallInCooldown"), 0, "disabled")
		expect.equal(KitModRules.bonus({}, MODS, "StimsCarried"), 0, "none")
	end,
	["a rank above the max counts only to the max"] = function()
		expect.equal(KitModRules.bonus({ stims = 9 }, MODS, "StimsCarried"), 3, "capped")
	end,
	["ranks go into one attribute string and come back"] = function()
		local text = KitModRules.encode({ stims = 2, rolls = 1, cooldown = 0 })
		expect.equal(text, "rolls=1;stims=2", "encoded, sorted, zeros left out")
		local back = KitModRules.decode(text)
		expect.equal(back.stims, 2, "stims")
		expect.equal(back.rolls, 1, "rolls")
		expect.equal(next(KitModRules.decode("junk;=;a=x")), nil, "junk")
	end,
	["every mod's ranks from the record"] = function()
		local ranks = KitModRules.ranks({ "stims@1", "rolls@1", "rolls@2" }, MODS)
		expect.equal(ranks.stims, 1, "stims")
		expect.equal(ranks.rolls, 2, "rolls")
		expect.equal(ranks.cooldown, 0, "cooldown")
	end,
}
