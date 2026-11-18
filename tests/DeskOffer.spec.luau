--!strict
local DeskOffer = require("../src/shared/Rules/DeskOffer")
local expect = require("./expect")

local TALK = {
	bought = "It's yours.",
	short = "You're short.",
	refused = "Try me later.",
}

return {
	["kit on the record shows ON YOUR RECORD and no BUY"] = function()
		local offer = DeskOffer.offer(true, 300, 1000)
		expect.equal(offer.state, "owned")
		expect.equal(offer.canBuy, false)
		expect.equal(offer.status, "ON YOUR RECORD")
		expect.equal(offer.badge, "ON RECORD")
	end,

	["issued-free kit reads as on the record even before the record arrives"] = function()
		local offer = DeskOffer.offer(false, 0, 0)
		expect.equal(offer.state, "owned")
		expect.equal(offer.canBuy, false)
	end,

	["kit the soldier can pay for offers BUY at its price"] = function()
		local offer = DeskOffer.offer(false, 400, 1000)
		expect.equal(offer.state, "buy")
		expect.equal(offer.canBuy, true)
		expect.equal(offer.dim, false)
		expect.equal(offer.button, "BUY · 400 MERITS")
		expect.equal(offer.status, "NOT ON YOUR RECORD")
		expect.equal(offer.badge, "400 MERITS")
	end,

	["short of merits: BUY is dimmed but still pressable so the server answers"] = function()
		local offer = DeskOffer.offer(false, 400, 399)
		expect.equal(offer.state, "short")
		expect.equal(offer.canBuy, true)
		expect.equal(offer.dim, true)
		expect.equal(offer.button, "BUY · 400 MERITS (SHORT)")
	end,

	["exactly enough merits is not short"] = function()
		expect.equal(DeskOffer.offer(false, 400, 400).state, "buy")
	end,

	["no price: not for issue, nothing to press"] = function()
		local offer = DeskOffer.offer(false, nil, 5000)
		expect.equal(offer.state, "closed")
		expect.equal(offer.canBuy, false)
		expect.equal(offer.badge, "NOT FOR ISSUE")
	end,

	["the person at the desk answers a buy in their own words"] = function()
		expect.equal(DeskOffer.answer(TALK, nil), "It's yours.")
		expect.equal(DeskOffer.answer(TALK, "short"), "You're short.")
		expect.equal(DeskOffer.answer(TALK, "save down"), "Try me later.")
	end,

	["a desk with no lines still answers in plain words"] = function()
		expect.equal(DeskOffer.answer(nil, nil), "On your record.")
		expect.equal(DeskOffer.answer(nil, "short"), "Not enough merits.")
		expect.equal(DeskOffer.answer(nil, "busy"), "Try again in a minute.")
	end,

	["columns keep the Loadout's order and drop empty sections"] = function()
		local columns = DeskOffer.columns({
			{ title = "PRIMARY", ids = { "rifle", "smg" }, column = 1 },
			{ title = "SIDEARM", ids = { "pistol" }, column = 2 },
			{ title = "GRENADE", ids = {}, column = 2 },
			{ title = "CALL-INS", ids = {}, column = 3 },
		})
		expect.equal(#columns, 2, "columns")
		expect.equal(#columns[1], 1, "first column sections")
		expect.equal(columns[1][1].title, "PRIMARY")
		expect.equal(#columns[2], 1, "second column sections")
		expect.equal(columns[2][1].title, "SIDEARM")
	end,

	["a desk that sells one kind of kit gets one column"] = function()
		local columns = DeskOffer.columns({
			{ title = "PRIMARY", ids = {}, column = 1 },
			{ title = "VEHICLES", ids = { "atv" }, column = 3 },
		})
		expect.equal(#columns, 1)
		expect.equal(columns[1][1].ids[1], "atv")
	end,
}
