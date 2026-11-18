--!strict
local PuddleShape = require("../src/shared/Rules/PuddleShape")
local expect = require("./expect")

local SETTINGS: PuddleShape.Settings = {
	lobes = 6,
	coreSize = 0.84,
	coreSquash = 0.92,
	lobeMin = 0.38,
	lobeMax = 0.52,
	lobeSquash = 0.72,
	reachMin = 0.9,
	reachMax = 1.04,
	spreadLag = 0.12,
}

local SEEDS = 200
local DIRECTIONS = 72

-- How far out from the middle the puddle reaches along `angle` (share of the radius).
local function edge(blobs: { PuddleShape.Blob }, angle: number): number
	local x, z = math.cos(angle), math.sin(angle)
	local out = 0
	for step = 1, 240 do
		local r = step / 200
		if PuddleShape.covers(blobs, x * r, z * r) then
			out = r
		end
	end
	return out
end

return {
	["the same seed lays the same puddle, another seed another"] = function()
		local a = PuddleShape.layout(42, SETTINGS)
		local b = PuddleShape.layout(42, SETTINGS)
		local c = PuddleShape.layout(43, SETTINGS)
		expect.equal(#a, 1 + SETTINGS.lobes, "core and lobes")
		for index, blob in a do
			expect.equal(blob.x, b[index].x, "same x")
			expect.equal(blob.angle, b[index].angle, "same turn")
		end
		expect.equal(a[2].x ~= c[2].x, true, "another seed moves the lobes")
	end,
	["the core sits in the middle and spreads first"] = function()
		local core = PuddleShape.layout(7, SETTINGS)[1]
		expect.equal(core.x, 0, "x")
		expect.equal(core.z, 0, "z")
		expect.equal(core.delay, 0, "no lag")
		expect.near(core.long, SETTINGS.coreSize, 1e-9, "size")
	end,
	["no blob reaches past reachMax (about the damage radius)"] = function()
		for seed = 1, SEEDS do
			for _, blob in PuddleShape.layout(seed, SETTINGS) do
				local reach = math.sqrt(blob.x * blob.x + blob.z * blob.z) + blob.long
				expect.equal(reach <= SETTINGS.reachMax + 1e-9, true, `seed {seed} reach {reach}`)
				expect.equal(blob.short <= blob.long, true, "short is the shorter axis")
				expect.equal(blob.delay >= 0 and blob.delay <= SETTINGS.spreadLag, true, "lag")
			end
		end
	end,
	["the puddle covers most of the damage area in every direction"] = function()
		for seed = 1, SEEDS do
			local blobs = PuddleShape.layout(seed, SETTINGS)
			for step = 0, DIRECTIONS - 1 do
				local out = edge(blobs, step / DIRECTIONS * math.pi * 2)
				expect.equal(out >= 0.75, true, `seed {seed} direction {step} reaches {out}`)
			end
		end
	end,
	["the edge is uneven, not a circle"] = function()
		for seed = 1, 20 do
			local blobs = PuddleShape.layout(seed, SETTINGS)
			local least, most = math.huge, 0
			for step = 0, DIRECTIONS - 1 do
				local out = edge(blobs, step / DIRECTIONS * math.pi * 2)
				least = math.min(least, out)
				most = math.max(most, out)
			end
			expect.equal(most - least >= 0.06, true, `seed {seed} edge from {least} to {most}`)
		end
	end,
	["covers reads a turned ellipse"] = function()
		local blob: PuddleShape.Blob =
			{ x = 1, z = 0, long = 0.5, short = 0.1, angle = math.pi / 2, delay = 0 }
		expect.equal(PuddleShape.covers({ blob }, 1, 0.45), true, "along the long axis")
		expect.equal(PuddleShape.covers({ blob }, 1.3, 0), false, "past the short axis")
	end,
}
