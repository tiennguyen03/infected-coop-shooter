--!strict
local KitCard = require("../src/shared/Rules/KitCard")
local expect = require("./expect")

local function row(rows: { KitCard.Row }, label: string): KitCard.Row
	for _, r in rows do
		if r.label == label then
			return r
		end
	end
	error(`no row {label}`)
end

local function has(rows: { KitCard.Row }, label: string): boolean
	for _, r in rows do
		if r.label == label then
			return true
		end
	end
	return false
end

-- Call-in blocks shaped like Config.CallIns rows (only the fields the card reads).
local MORTAR = {
	Charges = 1,
	Cooldown = 120,
	Delay = 3,
	Shells = 6,
	BlastRadius = 12,
	BlastDamage = 80,
}
local SENTRY = {
	Charges = 1,
	Cooldown = 150,
	Duration = 45,
	Damage = 20,
	Range = 70,
	Arrival = { Time = 2.2 },
}
local WIRE = {
	Charges = 2,
	Cooldown = 90,
	Duration = 60,
	Length = 16,
	DamagePerSecond = 5,
	Arrival = { Time = 1.05 },
}
local AMMO = { Charges = 1, Cooldown = 180, Radius = 6, Lifetime = 90, Arrival = { Time = 1.5 } }

return {
	["cells: a share of the bar in whole segments, never empty unless zero"] = function()
		expect.equal(KitCard.cells(1, 10), 10, "full")
		expect.equal(KitCard.cells(0.5, 10), 5, "half")
		expect.equal(KitCard.cells(0.04, 10), 1, "a sliver still shows one")
		expect.equal(KitCard.cells(0, 10), 0, "nothing")
		expect.equal(KitCard.cells(1.7, 10), 10, "clamped")
		expect.equal(KitCard.cells(0.66, 10), 7, "rounded")
	end,
	["duration reads in seconds, then minutes"] = function()
		expect.equal(KitCard.duration(45), "45 s", "seconds")
		expect.equal(KitCard.duration(2.2), "2.2 s", "tenths")
		expect.equal(KitCard.duration(0.95), "1 s", "rounded to a tenth")
		expect.equal(KitCard.duration(120), "2 min", "whole minutes")
		expect.equal(KitCard.duration(150), "2 min 30 s", "minutes and seconds")
	end,
	["call-in stats are read from the row's own fields"] = function()
		local mortar = KitCard.callInStats(MORTAR)
		expect.equal(mortar.damage, 80, "BlastDamage")
		expect.equal(mortar.hits, 6, "Shells")
		expect.equal(mortar.radius, 12, "BlastRadius")
		expect.equal(mortar.arrives, 3, "Delay")
		expect.equal(mortar.lasts, nil, "no duration")
		local sentry = KitCard.callInStats(SENTRY)
		expect.equal(sentry.damage, 20, "Damage")
		expect.equal(sentry.reach, 70, "Range")
		expect.equal(sentry.arrives, 2.2, "Arrival.Time")
		expect.equal(sentry.lasts, 45, "Duration")
		local wire = KitCard.callInStats(WIRE)
		expect.equal(wire.perSecond, true, "DamagePerSecond")
		expect.equal(wire.damage, 5, "per second")
		expect.equal(wire.length, 16, "Length")
		expect.equal(KitCard.callInStats(AMMO).lasts, 90, "Lifetime")
	end,
	["a call-in card shows only what it has, in a fixed order"] = function()
		local all = { MORTAR, SENTRY, WIRE, AMMO }
		local labels = {}
		for _, r in KitCard.callIn(MORTAR, all) do
			table.insert(labels, r.label)
		end
		expect.equal(
			table.concat(labels, ","),
			"Damage,Blast radius,Charges,Cooldown,Arrives",
			"mortar rows"
		)
		local ammo = KitCard.callIn(AMMO, all)
		expect.equal(has(ammo, "Damage"), false, "no damage on an ammo drop")
		expect.equal(row(ammo, "Radius").text, "6 studs", "radius")
		expect.equal(row(ammo, "Lasts").text, "1 min 30 s", "lifetime")
	end,
	["call-in numbers print in plain words"] = function()
		local all = { MORTAR, SENTRY, WIRE, AMMO }
		expect.equal(row(KitCard.callIn(MORTAR, all), "Damage").text, "80 x 6", "shells")
		expect.equal(row(KitCard.callIn(WIRE, all), "Damage").text, "5 a second", "per second")
		expect.equal(row(KitCard.callIn(WIRE, all), "Length").text, "16 studs", "wire")
		expect.equal(row(KitCard.callIn(SENTRY, all), "Reach").text, "70 studs", "sentry")
		expect.equal(row(KitCard.callIn(MORTAR, all), "Cooldown").text, "2 min", "cooldown")
		expect.equal(
			row(KitCard.callIn(MORTAR, all), "Arrives").text,
			"3 s after the throw",
			"arrives"
		)
		expect.equal(row(KitCard.callIn(WIRE, all), "Charges").text, "2", "charges")
	end,
	["call-in bars compare against the roster: more is better, waits are shorter"] = function()
		local all = { MORTAR, SENTRY, WIRE, AMMO }
		expect.equal(row(KitCard.callIn(MORTAR, all), "Damage").fraction, 1, "480 is the most")
		expect.equal(row(KitCard.callIn(WIRE, all), "Charges").fraction, 1, "two charges")
		expect.near(row(KitCard.callIn(MORTAR, all), "Charges").fraction, 0.5, 1e-6, "one")
		expect.near(row(KitCard.callIn(WIRE, all), "Cooldown").fraction, 1, 1e-6, "shortest")
		expect.near(row(KitCard.callIn(AMMO, all), "Cooldown").fraction, 0.5, 1e-6, "90/180")
		expect.near(row(KitCard.callIn(WIRE, all), "Arrives").fraction, 1, 1e-6, "fastest")
	end,
	["a grenade card: damage, radius, fuse, throw"] = function()
		local frag = { Damage = 110, Radius = 10, FuseTime = 0.8, ThrowDistance = 35 }
		local rows = KitCard.grenade(frag, { frag })
		expect.equal(#rows, 4, "rows")
		expect.equal(row(rows, "Damage").text, "110", "damage")
		expect.equal(row(rows, "Blast radius").text, "10 studs", "radius")
		expect.equal(row(rows, "Fuse").text, "0.8 s after it lands", "fuse")
		expect.equal(row(rows, "Throw").text, "35 studs", "throw")
		expect.equal(row(rows, "Damage").fraction, 1, "the only grenade is the best")
	end,
	["stealth: the quietest gun gets the full bar"] = function()
		local quiet = KitCard.stealth(60, { 60, 120, 240 })
		expect.equal(quiet.label, "Stealth", "label")
		expect.equal(quiet.text, "heard at 60 studs", "text")
		expect.equal(quiet.fraction, 1, "quietest")
		expect.near(KitCard.stealth(240, { 60, 120, 240 }).fraction, 0.25, 1e-6, "loudest")
	end,
}
