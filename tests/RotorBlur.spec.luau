--!strict
local RotorBlur = require("../src/shared/Rules/RotorBlur")
local expect = require("./expect")

local SETTINGS: RotorBlur.Settings = {
	start = 6, -- seconds before lift the blur begins
	full = 1.5, -- seconds before lift it is complete
	bladeFade = 0.6, -- blades never fade past this
	disc = 0.8, -- the disc's transparency when complete
}

return {
	["long before lift the blades are solid and the disc is hidden"] = function()
		local blade, disc = RotorBlur.at(10, SETTINGS)
		expect.equal(blade, 0, "blade")
		expect.equal(disc, 1, "disc")
	end,
	["at the start of the blur nothing has changed yet"] = function()
		local blade, disc = RotorBlur.at(6, SETTINGS)
		expect.equal(blade, 0, "blade")
		expect.equal(disc, 1, "disc")
	end,
	["once complete the blades stay visible and the disc is at its faint best"] = function()
		local blade, disc = RotorBlur.at(1.5, SETTINGS)
		expect.near(blade, 0.6, 1e-9, "blade")
		expect.near(disc, 0.8, 1e-9, "disc")
		local laterBlade, laterDisc = RotorBlur.at(0, SETTINGS)
		expect.near(laterBlade, 0.6, 1e-9, "blade at lift")
		expect.near(laterDisc, 0.8, 1e-9, "disc at lift")
	end,
	["halfway through it is halfway (eased curves meet in the middle)"] = function()
		local blade, disc = RotorBlur.at(3.75, SETTINGS)
		expect.near(blade, 0.3, 1e-9, "blade")
		expect.near(disc, 0.9, 1e-9, "disc")
	end,
	["it builds gently: a quarter of the way in, less than a quarter has happened"] = function()
		local blade = RotorBlur.at(6 - 4.5 * 0.25, SETTINGS)
		expect.equal(blade > 0 and blade < 0.6 * 0.25, true, `blade {blade}`)
	end,
	["the blur only ever grows toward lift"] = function()
		local lastBlade, lastDisc = RotorBlur.at(8, SETTINGS)
		for step = 1, 80 do
			local remaining = 8 - step * 0.1
			local blade, disc = RotorBlur.at(remaining, SETTINGS)
			expect.equal(blade >= lastBlade, true, `blade at {remaining}`)
			expect.equal(disc <= lastDisc, true, `disc at {remaining}`)
			lastBlade, lastDisc = blade, disc
		end
	end,
}
