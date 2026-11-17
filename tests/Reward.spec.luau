--!strict
local Reward = require("../src/shared/Rules/Reward")
local expect = require("./expect")

-- A "random" that always takes the first one left, so offers are predictable.
local function first(_count: number): number
	return 1
end

local function last(count: number): number
	return count
end

local CANDIDATES: { Reward.Candidate } = {
	{ Id = "bait", Slot = "Grenade" },
	{ Id = "pierce", Slot = "Weapon" },
	{ Id = "stop", Slot = "Weapon" },
	{ Id = "stand", Slot = "Kit" },
	{ Id = "tourniquet", Slot = "Kit" },
}

local CARDS: { [string]: Reward.Effects } = {
	medkit = { Heal = true, Stims = true },
	restock = { CallIns = true, Grenades = true, Stims = true },
	armour_plate = { Plate = 75 },
}
local SUPPLY = { "medkit", "restock", "armour_plate" }

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

local function pick(overrides: { [string]: any }): (boolean, string?)
	local input: any = {
		open = true,
		offer = { "medkit", "restock" },
		cardId = "medkit",
		picked = false,
		canAct = true,
		distance = 5,
		radius = 9,
	}
	for key, value in overrides do
		input[key] = if value == "none" then nil else value
	end
	return Reward.checkPick(input)
end

return {
	["an upgrade offer has `count` different cards"] = function()
		local offer = Reward.upgradeOffer(CANDIDATES, {}, 3, first)
		expect.equal(#offer, 3, "count")
		expect.equal(offer[1] ~= offer[2] and offer[2] ~= offer[3] and offer[1] ~= offer[3], true)
	end,
	["an upgrade the player already holds is never offered"] = function()
		local held = { Weapon = "pierce", Kit = "stand", Grenade = "bait" }
		for _, random in { first, last } do
			local offer = Reward.upgradeOffer(CANDIDATES, held, 5, random)
			expect.equal(#offer, 2, "count")
			expect.equal(has(offer, "pierce"), false, "pierce")
			expect.equal(has(offer, "stand"), false, "stand")
			expect.equal(has(offer, "bait"), false, "bait")
		end
	end,
	["upgrades for an empty slot come before ones that would replace a pick"] = function()
		-- Weapon is filled: "stop" would replace "pierce", so it is offered last.
		local offer = Reward.upgradeOffer(CANDIDATES, { Weapon = "pierce" }, 3, last)
		expect.equal(has(offer, "stop"), false, "three empty-slot cards exist")
		local four = Reward.upgradeOffer(CANDIDATES, { Weapon = "pierce" }, 4, last)
		expect.equal(four[4], "stop", "the replacement fills the last seat")
	end,
	["a short pool gives a short offer, and none gives none"] = function()
		expect.equal(#Reward.upgradeOffer({ CANDIDATES[1] }, {}, 3, first), 1)
		expect.equal(#Reward.upgradeOffer({}, {}, 3, first), 0)
	end,
	["a short offer is padded with supply cards, in their order"] = function()
		local offer = Reward.pad({ "bait" }, SUPPLY, 3)
		expect.equal(#offer, 3, "count")
		expect.equal(offer[1], "bait")
		expect.equal(offer[2], "medkit")
		expect.equal(offer[3], "restock")
	end,
	["a full offer is not padded and never grows past count"] = function()
		local offer = Reward.pad({ "a", "b", "c" }, SUPPLY, 3)
		expect.equal(#offer, 3)
		expect.equal(offer[3], "c")
		expect.equal(#Reward.pad({}, SUPPLY, 2), 2)
	end,

	["a pick in reach of an open crate is allowed"] = function()
		local ok, reason = pick({})
		expect.equal(ok, true)
		expect.equal(reason, nil)
	end,
	["a pick on a crate that closed is refused"] = function()
		local ok, reason = pick({ open = false })
		expect.equal(ok, false)
		expect.equal(reason, "gone")
	end,
	["a second pick on the same crate is refused"] = function()
		local ok, reason = pick({ picked = true })
		expect.equal(ok, false)
		expect.equal(reason, "taken")
	end,
	["a card that was not offered to this player is refused"] = function()
		local ok, reason = pick({ cardId = "armour_plate" })
		expect.equal(ok, false)
		expect.equal(reason, "not_offered")
		local none, noneReason = pick({ offer = "none" })
		expect.equal(none, false)
		expect.equal(noneReason, "not_offered")
	end,
	["a downed player cannot pick"] = function()
		local ok, reason = pick({ canAct = false })
		expect.equal(ok, false)
		expect.equal(reason, "down")
	end,
	["a pick from out of reach is refused; the edge is in reach"] = function()
		local ok, reason = pick({ distance = 9.1 })
		expect.equal(ok, false)
		expect.equal(reason, "far")
		expect.equal((pick({ distance = 9 })), true)
	end,

	["a hurt bot takes the heal"] = function()
		local need: Reward.Need = { Heal = 0.6 }
		expect.equal(Reward.botChoice(SUPPLY, CARDS, need, 0.25), "medkit")
	end,
	["a bot that needs nothing takes nothing"] = function()
		expect.equal(Reward.botChoice(SUPPLY, CARDS, { Heal = 0.1 }, 0.25), nil)
		expect.equal(Reward.botChoice(SUPPLY, CARDS, {}, 0.25), nil)
	end,
	["a bot takes the card that covers its biggest need"] = function()
		local need: Reward.Need = { Heal = 0.3, CallIns = 1, Stims = 0.5 }
		expect.equal(Reward.botChoice(SUPPLY, CARDS, need, 0.25), "restock")
		expect.equal(Reward.botChoice(SUPPLY, CARDS, { Plate = 1 }, 0.25), "armour_plate")
	end,
	["a bot never takes a card with no supply effect (a field upgrade)"] = function()
		expect.equal(Reward.botChoice({ "bait", "pierce" }, CARDS, { Heal = 1 }, 0.25), nil)
	end,

	["the effects line names every part of the reward, in plain words"] = function()
		local line = Reward.effectsLine({
			Heal = true,
			Ammo = true,
			CallIns = true,
			Grenades = true,
			Stims = true,
			Plate = 50,
		})
		expect.equal(line, "Full health, ammo, call-ins, grenades, stims, +50 armour")
	end,
	["the effects line leaves out what the reward does not give"] = function()
		expect.equal(Reward.effectsLine({ Heal = true, Plate = 0 }), "Full health")
		expect.equal(Reward.effectsLine({}), "")
	end,
}
