--!strict
local AttachmentRules = require("../src/shared/Rules/AttachmentRules")
local Record = require("../src/shared/Rules/Record")
local expect = require("./expect")

-- Three optics as Config.Optics gives them; only the rifle takes them.
local OPTICS: AttachmentRules.Optics = {
	reddot = {
		id = "reddot",
		displayName = "Red dot",
		description = "",
		compatibleGuns = { "service_rifle" },
		zoomMultiplier = 1,
		adsTimeMultiplier = 0.75,
		meritCost = 150,
	},
	compm2 = {
		id = "compm2",
		displayName = "CompM2",
		description = "",
		compatibleGuns = { "service_rifle" },
		zoomMultiplier = 1.5,
		adsTimeMultiplier = 1,
		meritCost = 250,
	},
	acog = {
		id = "acog",
		displayName = "ACOG",
		description = "",
		compatibleGuns = { "service_rifle" },
		zoomMultiplier = 3,
		adsTimeMultiplier = 1.6,
		meritCost = 400,
	},
}

local function owning(merits: number, owned: { string }): Record.Record
	local record = Record.new(merits)
	record.owned = owned
	return record
end

return {
	["buying an optic you can afford takes its cost and puts it on the record"] = function()
		local after, ok, reason = AttachmentRules.buy(owning(300, {}), "compm2", OPTICS)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "reason")
		expect.equal(after.merits, 50, "merits left")
		expect.equal(table.find(after.owned, "compm2") ~= nil, true, "owned")
	end,
	["buying an optic you cannot afford is refused and changes nothing"] = function()
		local before = owning(399, {})
		local after, ok, reason = AttachmentRules.buy(before, "acog", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "short", "reason")
		expect.equal(after.merits, 399, "merits")
		expect.equal(#after.owned, 0, "owned")
	end,
	["buying an optic already owned is refused"] = function()
		local after, ok, reason = AttachmentRules.buy(owning(1000, { "reddot" }), "reddot", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "owned", "reason")
		expect.equal(after.merits, 1000, "merits")
	end,
	["buying something that is not an optic is refused"] = function()
		local _, ok, reason = AttachmentRules.buy(owning(1000, {}), "smg", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "unknown", "reason")
	end,
	["the stored buy keeps merits the match paid since the lobby read the record"] = function()
		local stored = Record.encode(owning(500, {}))
		local saved, reason = AttachmentRules.buyStored(stored, "acog", OPTICS, 0)
		expect.equal(reason, nil, "reason")
		local after = Record.decode(saved, 0)
		expect.equal(after.merits, 100, "merits")
		expect.equal(table.find(after.owned, "acog") ~= nil, true, "owned")
	end,
	["equipping an owned optic on a gun that takes it is allowed"] = function()
		local ok, reason =
			AttachmentRules.canEquip(owning(0, { "acog" }), "service_rifle", "acog", OPTICS)
		expect.equal(ok, true, "ok")
		expect.equal(reason, nil, "reason")
	end,
	["equipping an optic you do not own is refused"] = function()
		local ok, reason = AttachmentRules.canEquip(owning(0, {}), "service_rifle", "acog", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "not owned", "reason")
	end,
	["equipping an optic on a gun it does not fit is refused"] = function()
		local ok, reason = AttachmentRules.canEquip(owning(0, { "acog" }), "smg", "acog", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "incompatible", "reason")
	end,
	["equipping an unknown optic is refused"] = function()
		local ok, reason =
			AttachmentRules.canEquip(owning(0, { "nope" }), "service_rifle", "nope", OPTICS)
		expect.equal(ok, false, "ok")
		expect.equal(reason, "unknown", "reason")
	end,
	["a fitting is allowed only when every optic on it is owned and fits"] = function()
		local record = owning(0, { "reddot" })
		expect.equal(
			(
				AttachmentRules.fittedAllowed(
					record,
					{ service_rifle = { Optic = "reddot" } },
					OPTICS
				)
			),
			true,
			"owned"
		)
		expect.equal(
			(AttachmentRules.fittedAllowed(record, { service_rifle = { Optic = "acog" } }, OPTICS)),
			false,
			"not owned"
		)
		expect.equal(
			(AttachmentRules.fittedAllowed(record, { smg = { Optic = "reddot" } }, OPTICS)),
			false,
			"incompatible"
		)
		expect.equal(
			(
				AttachmentRules.fittedAllowed(
					record,
					{ service_rifle = { Barrel = "suppressor" } },
					OPTICS
				)
			),
			true,
			"other slots are not this rule's"
		)
		expect.equal((AttachmentRules.fittedAllowed(record, nil, OPTICS)), true, "bare")
	end,
	["each optic reads as locked, owned or equipped"] = function()
		local record = owning(0, { "reddot", "compm2" })
		expect.equal(AttachmentRules.state(record, "compm2", "acog", OPTICS), "locked", "acog")
		expect.equal(AttachmentRules.state(record, "compm2", "reddot", OPTICS), "owned", "reddot")
		expect.equal(
			AttachmentRules.state(record, "compm2", "compm2", OPTICS),
			"equipped",
			"compm2"
		)
	end,
	["the optics a gun takes come cheapest first, and none for a gun that takes none"] = function()
		local list = AttachmentRules.forGun(OPTICS, "service_rifle")
		expect.equal(#list, 3, "count")
		expect.equal(list[1].id, "reddot", "first")
		expect.equal(list[2].id, "compm2", "second")
		expect.equal(list[3].id, "acog", "third")
		expect.equal(#AttachmentRules.forGun(OPTICS, "smg"), 0, "smg")
	end,
	["the unlocked counter counts the gun's optics on the record"] = function()
		local have, total =
			AttachmentRules.unlocked(owning(0, { "acog", "smg" }), "service_rifle", OPTICS)
		expect.equal(have, 1, "have")
		expect.equal(total, 3, "total")
	end,
}
