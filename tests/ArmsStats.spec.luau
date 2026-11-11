--!strict
local ArmsStats = require("../src/shared/Rules/ArmsStats")
local expect = require("./expect")

local RIFLE: ArmsStats.Stats = {
	damage = 20,
	fireCooldown = 0.08,
	magazine = 30,
	reload = 2.2,
	range = 400,
	adsSpread = 0.3,
}
local SHOTGUN: ArmsStats.Stats = {
	damage = 12,
	pellets = 8,
	fireCooldown = 0.9,
	magazine = 6,
	reload = 4,
	range = 120,
	adsSpread = 3,
}
local PISTOL: ArmsStats.Stats = {
	damage = 18,
	fireCooldown = 0.2,
	magazine = 15,
	reload = 1.4,
	range = 200,
	adsSpread = 0.6,
}
local ALL = { RIFLE, SHOTGUN, PISTOL }

local function row(rows: { ArmsStats.Row }, label: string): ArmsStats.Row
	for _, r in rows do
		if r.label == label then
			return r
		end
	end
	error(`no row {label}`)
end

return {
	["every gun gets the same six rows in the same order"] = function()
		local rows = ArmsStats.rows(RIFLE, ALL)
		expect.equal(#rows, 6, "rows")
		local labels = {}
		for _, r in rows do
			table.insert(labels, r.label)
		end
		expect.equal(
			table.concat(labels, ","),
			"Damage,Fire rate,Magazine,Reload,Range,Accuracy",
			"order"
		)
	end,
	["damage counts every pellet of a trigger pull"] = function()
		local r = row(ArmsStats.rows(SHOTGUN, ALL), "Damage")
		expect.equal(r.text, "12 x 8", "text")
		expect.equal(r.fraction, 1, "the shotgun's 96 is the best pull")
	end,
	["fire rate reads in rounds per minute, scaled to the fastest"] = function()
		local r = row(ArmsStats.rows(RIFLE, ALL), "Fire rate")
		expect.equal(r.text, "750 rpm", "text")
		expect.equal(r.fraction, 1, "fastest")
		local pistol = row(ArmsStats.rows(PISTOL, ALL), "Fire rate")
		expect.near(pistol.fraction, 0.4, 0.001, "300 of 750")
	end,
	["a shorter reload is a longer bar"] = function()
		local pistol = row(ArmsStats.rows(PISTOL, ALL), "Reload")
		expect.equal(pistol.fraction, 1, "quickest")
		expect.equal(pistol.text, "1.4 s", "text")
		local shotgun = row(ArmsStats.rows(SHOTGUN, ALL), "Reload")
		expect.near(shotgun.fraction, 1.4 / 4, 0.001, "slowest")
	end,
	["a tighter cone is a longer accuracy bar"] = function()
		expect.equal(row(ArmsStats.rows(RIFLE, ALL), "Accuracy").fraction, 1, "tightest")
		expect.near(row(ArmsStats.rows(SHOTGUN, ALL), "Accuracy").fraction, 0.1, 0.001, "widest")
	end,
	["a bar never vanishes"] = function()
		local weak: ArmsStats.Stats = {
			damage = 1,
			fireCooldown = 10,
			magazine = 1,
			reload = 100,
			range = 1,
			adsSpread = 100,
		}
		for _, r in ArmsStats.rows(weak, { RIFLE, weak }) do
			expect.equal(r.fraction >= ArmsStats.MIN_FRACTION, true, r.label)
		end
	end,
	["range reads in studs"] = function()
		expect.equal(row(ArmsStats.rows(RIFLE, ALL), "Range").text, "400 studs", "text")
	end,
}
