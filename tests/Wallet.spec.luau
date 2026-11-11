--!strict
local Wallet = require("../src/shared/Rules/Wallet")
local expect = require("./expect")

return {
	["under ten thousand the count is exact"] = function()
		expect.equal(Wallet.format(0), "0", "zero")
		expect.equal(Wallet.format(7), "7", "one digit")
		expect.equal(Wallet.format(950), "950", "hundreds")
		expect.equal(Wallet.format(1000), "1,000", "a thousand")
		expect.equal(Wallet.format(9999), "9,999", "the last exact one")
	end,
	["ten thousand and up is in thousands, one decimal"] = function()
		expect.equal(Wallet.format(10000), "10k", "no .0")
		expect.equal(Wallet.format(12400), "12.4k", "the owner's example")
		expect.equal(Wallet.format(12449), "12.4k", "the rest is dropped")
		expect.equal(Wallet.format(99999), "99.9k", "never rounded up")
		expect.equal(Wallet.format(100000), "100k", "no decimal from 100k")
		expect.equal(Wallet.format(125900), "125k", "floored")
		expect.equal(Wallet.format(999999), "999k", "the last k")
	end,
	["millions and billions"] = function()
		expect.equal(Wallet.format(1000000), "1M", "a million")
		expect.equal(Wallet.format(1250000), "1.2M", "one decimal")
		expect.equal(Wallet.format(250000000), "250M", "no decimal from 100M")
		expect.equal(Wallet.format(3400000000), "3.4B", "billions")
		expect.equal(Wallet.format(1e15), "999B+", "capped")
	end,
	["a count is never shown as more than is held"] = function()
		expect.equal(Wallet.format(19999), "19.9k", "not 20k")
		expect.equal(Wallet.format(1999999), "1.9M", "not 2M")
		expect.equal(Wallet.format(12.9), "12", "fractions are dropped")
	end,
	["junk reads as zero"] = function()
		expect.equal(Wallet.format(-5), "0", "negative")
		expect.equal(Wallet.format(0 / 0), "0", "not a number")
		expect.equal(Wallet.format("12" :: any), "0", "not a number type")
		expect.equal(Wallet.format(nil :: any), "0", "nil")
		expect.equal(Wallet.format(math.huge), "999B+", "infinite")
	end,
	["the count-up starts at the old count and lands on the new one"] = function()
		expect.equal(Wallet.countUp(1000, 1120, 0), 1000, "start")
		expect.equal(Wallet.countUp(1000, 1120, 1), 1120, "end")
		expect.equal(Wallet.countUp(1000, 1120, 5), 1120, "past the end")
		expect.equal(Wallet.countUp(1000, 1120, -1), 1000, "before the start")
		expect.equal(Wallet.countUp(1000, 1120, 0 / 0), 1120, "junk lands")
	end,
	["the count-up moves fast first, in whole numbers, and never overshoots"] = function()
		expect.equal(Wallet.countUp(0, 100, 0.5), 75, "eased out")
		expect.equal(Wallet.countUp(0, 3, 0.4) % 1, 0, "whole")
		local last = 0
		for step = 0, 10 do
			local shown = Wallet.countUp(0, 37, step / 10)
			expect.equal(shown >= last and shown <= 37, true, `step {step}`)
			last = shown
		end
	end,
	["the count-up runs down too"] = function()
		expect.equal(Wallet.countUp(1000, 400, 0.5), 550, "a buy")
		expect.equal(Wallet.countUp(1000, 400, 1), 400, "lands")
	end,
}
