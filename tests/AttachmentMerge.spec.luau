--!strict
local AttachmentMerge = require("../src/shared/Rules/AttachmentMerge")
local expect = require("./expect")

local BASE: AttachmentMerge.Stats = { zoom = 1.35, adsTime = 0.15 }

return {
	["a bare gun keeps its own zoom and ADS time"] = function()
		local stats = AttachmentMerge.apply(BASE, {})
		expect.equal(stats.zoom, 1.35, "zoom")
		expect.equal(stats.adsTime, 0.15, "adsTime")
	end,
	["an optic multiplies the gun's zoom and ADS time"] = function()
		local stats =
			AttachmentMerge.apply(BASE, { { zoomMultiplier = 3, adsTimeMultiplier = 1.6 } })
		expect.near(stats.zoom, 4.05, 1e-9, "zoom")
		expect.near(stats.adsTime, 0.24, 1e-9, "adsTime")
	end,
	["a modifier that names one stat leaves the other alone"] = function()
		local stats = AttachmentMerge.apply(BASE, { { adsTimeMultiplier = 0.75 } })
		expect.equal(stats.zoom, 1.35, "zoom")
		expect.near(stats.adsTime, 0.1125, 1e-9, "adsTime")
	end,
	["several attachments stack by multiplying"] = function()
		local stats = AttachmentMerge.apply(BASE, {
			{ zoomMultiplier = 2 },
			{ zoomMultiplier = 1.5, adsTimeMultiplier = 2 },
		})
		expect.near(stats.zoom, 4.05, 1e-9, "zoom")
		expect.near(stats.adsTime, 0.3, 1e-9, "adsTime")
	end,
	["a zero, negative or NaN multiplier is ignored"] = function()
		local stats = AttachmentMerge.apply(BASE, {
			{ zoomMultiplier = 0, adsTimeMultiplier = -1 },
			{ zoomMultiplier = 0 / 0 },
		})
		expect.equal(stats.zoom, 1.35, "zoom")
		expect.equal(stats.adsTime, 0.15, "adsTime")
	end,
	["the base is not changed"] = function()
		AttachmentMerge.apply(BASE, { { zoomMultiplier = 3 } })
		expect.equal(BASE.zoom, 1.35, "zoom")
	end,
}
