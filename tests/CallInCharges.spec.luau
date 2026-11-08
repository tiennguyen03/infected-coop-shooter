--!strict
local CallInCharges = require("../src/shared/Rules/CallInCharges")
local expect = require("./expect")

return {
	["using the last charge starts the recharge timer"] = function()
		local ok, charges, nextAt = CallInCharges.use(1, nil, 100, 60)
		expect.equal(ok, true, "ok")
		expect.equal(charges, 0, "charges")
		expect.equal(nextAt, 160, "nextAt")
	end,
	["an empty slot refuses and keeps its timer"] = function()
		local ok, charges, nextAt = CallInCharges.use(0, 150, 100, 60)
		expect.equal(ok, false, "ok")
		expect.equal(charges, 0, "charges")
		expect.equal(nextAt, 150, "nextAt")
	end,
	["a second use keeps the running timer"] = function()
		local _, charges, nextAt = CallInCharges.use(2, 130, 100, 60)
		expect.equal(charges, 1, "charges")
		expect.equal(nextAt, 130, "nextAt")
	end,
	["a charge lands when the timer runs out and the next one is queued"] = function()
		local charges, nextAt = CallInCharges.tick(0, 2, 160, 160, 60)
		expect.equal(charges, 1, "charges")
		expect.equal(nextAt, 220, "nextAt")
	end,
	["the last charge to land stops the timer"] = function()
		local charges, nextAt = CallInCharges.tick(1, 2, 160, 161, 60)
		expect.equal(charges, 2, "charges")
		expect.equal(nextAt, nil, "nextAt")
	end,
	["nothing lands before the timer"] = function()
		local charges, nextAt = CallInCharges.tick(0, 2, 160, 159, 60)
		expect.equal(charges, 0, "charges")
		expect.equal(nextAt, 160, "nextAt")
	end,
}
