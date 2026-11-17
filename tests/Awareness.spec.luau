--!strict
local Awareness = require("../src/shared/Rules/Awareness")
local expect = require("./expect")

local SETTINGS: Awareness.Settings = {
	Hearing = { Sleeping = 0.4, Idle = 1, Wandering = 1, Alerted = 1.2 },
	Sight = {
		Range = { Sleeping = 0, Idle = 40, Wandering = 50, Alerted = 60, Chase = 80 },
		HalfAngle = 60,
		Night = 0.5,
		Crouch = 0.6,
		Prone = 0.3,
		NoticeSeconds = 2,
		Instant = 4,
	},
	Touch = 3,
}

return {
	["a noise inside half its reach brings a chase"] = function()
		expect.equal(Awareness.hear(SETTINGS, "Idle", 20, 50), "Chase")
	end,
	["a noise inside its reach alerts"] = function()
		expect.equal(Awareness.hear(SETTINGS, "Wandering", 40, 50), "Alerted")
	end,
	["a noise past its reach does nothing"] = function()
		expect.equal(Awareness.hear(SETTINGS, "Idle", 60, 50), nil)
	end,
	["a sleeper hears less"] = function()
		-- reach 50 x 0.4 = 20: 15 alerts, 25 does not, 9 chases
		expect.equal(Awareness.hear(SETTINGS, "Sleeping", 15, 50), "Alerted")
		expect.equal(Awareness.hear(SETTINGS, "Sleeping", 25, 50), nil)
		expect.equal(Awareness.hear(SETTINGS, "Sleeping", 9, 50), "Chase")
	end,
	["a chasing body ignores noise"] = function()
		expect.equal(Awareness.hear(SETTINGS, "Chase", 1, 500), nil)
	end,
	["a loud enough noise chases from far off"] = function()
		-- Reach 1400 puts a body 600 away inside half of it.
		expect.equal(Awareness.hear(SETTINGS, "Wandering", 600, 1400), "Chase")
	end,
	["night, crouch and prone shorten sight"] = function()
		expect.near(Awareness.sightRange(SETTINGS, "Idle", "stand", false), 40, 1e-6)
		expect.near(Awareness.sightRange(SETTINGS, "Idle", "stand", true), 20, 1e-6)
		expect.near(Awareness.sightRange(SETTINGS, "Idle", "crouch", true), 12, 1e-6)
		expect.near(Awareness.sightRange(SETTINGS, "Idle", "prone", false), 12, 1e-6)
	end,
	["a sleeper sees nothing"] = function()
		expect.equal(Awareness.sightRange(SETTINGS, "Sleeping", "stand", false), 0)
	end,
	["the cone covers the front, not behind"] = function()
		-- Facing -Z; offsets (x, z) with their distance.
		local function seen(x: number, z: number, range: number): boolean
			return Awareness.inCone(SETTINGS, 0, -1, x, z, math.sqrt(x * x + z * z), range)
		end
		expect.equal(seen(0, -10, 40), true)
		expect.equal(seen(8, -10, 40), true)
		expect.equal(seen(10, 0, 40), false)
		expect.equal(seen(0, 10, 40), false)
		expect.equal(seen(0, -50, 40), false)
	end,
	["notice is quicker close in and instant at arm's length"] = function()
		local edge = Awareness.noticeRate(SETTINGS, 40, 40)
		local close = Awareness.noticeRate(SETTINGS, 10, 40)
		expect.near(edge, 0.5, 1e-6)
		expect.equal(close > edge, true, "closer notices faster")
		expect.equal(Awareness.noticeRate(SETTINGS, 3, 40), math.huge)
		expect.equal(Awareness.noticeRate(SETTINGS, 45, 40), 0)
	end,
	["a touch wakes"] = function()
		expect.equal(Awareness.touched(SETTINGS, 2), true)
		expect.equal(Awareness.touched(SETTINGS, 5), false)
	end,
	["the stronger reaction wins"] = function()
		expect.equal(Awareness.stronger("Alerted", "Chase"), "Chase")
		expect.equal(Awareness.stronger(nil, "Alerted"), "Alerted")
		expect.equal(Awareness.stronger(nil, nil), nil)
	end,
}
