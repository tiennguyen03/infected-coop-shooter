--!strict
local StrikePattern = require("../src/shared/Rules/StrikePattern")
local expect = require("./expect")

return {
	["a still barrage puts every shell on the mark"] = function()
		local offsets = StrikePattern.offsets(6, 0, false)
		expect.equal(#offsets, 6, "count")
		for _, offset in offsets do
			expect.equal(offset, 0, "offset")
		end
	end,
	["Walk It In steps each shell further along the throw from the mark"] = function()
		local offsets = StrikePattern.offsets(6, 8, false)
		expect.equal(offsets[1], 0, "first")
		expect.equal(offsets[2], 8, "second")
		expect.equal(offsets[6], 40, "last")
	end,
	["a centred gun run is spread evenly either side of the mark"] = function()
		local offsets = StrikePattern.offsets(10, 4, true)
		expect.equal(#offsets, 10, "count")
		expect.equal(offsets[1], -18, "first")
		expect.equal(offsets[10], 18, "last")
		expect.equal(offsets[5] + offsets[6], 0, "symmetric")
	end,
	["a single centred shell lands on the mark"] = function()
		local offsets = StrikePattern.offsets(1, 4, true)
		expect.equal(offsets[1], 0, "only")
	end,
	["impact times start at the delay and step by the interval"] = function()
		local times = StrikePattern.impactTimes(6, 3, 1)
		expect.equal(times[1], 3, "first")
		expect.equal(times[6], 8, "last")
		local one = StrikePattern.impactTimes(1, 5, 1)
		expect.equal(#one, 1, "one shell")
		expect.equal(one[1], 5, "the 105 lands at the delay")
	end,
	["a point inside the wire strip is caught"] = function()
		-- strip along +X, 16 long, 3 wide, centred on the origin
		expect.equal(StrikePattern.inStrip(7.9, 1.4, 1, 0, 16, 3), true, "near the end")
		expect.equal(StrikePattern.inStrip(0, 0, 1, 0, 16, 3), true, "centre")
	end,
	["a point past the end or the side of the wire is not caught"] = function()
		expect.equal(StrikePattern.inStrip(8.1, 0, 1, 0, 16, 3), false, "past the end")
		expect.equal(StrikePattern.inStrip(0, 1.6, 1, 0, 16, 3), false, "off the side")
	end,
	["the strip follows its direction"] = function()
		-- strip along +Z: the long axis is Z now
		expect.equal(StrikePattern.inStrip(0, 7, 0, 1, 16, 3), true, "along")
		expect.equal(StrikePattern.inStrip(7, 0, 0, 1, 16, 3), false, "across")
	end,
	["supply visits run out at the bundle's count"] = function()
		local left, served = StrikePattern.visit(4)
		expect.equal(served, true, "served")
		expect.equal(left, 3, "left")
		local none, refused = StrikePattern.visit(0)
		expect.equal(refused, false, "empty bundle refuses")
		expect.equal(none, 0, "stays empty")
	end,
}
