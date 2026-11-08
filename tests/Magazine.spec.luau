--!strict
local Magazine = require("../src/shared/Rules/Magazine")
local expect = require("./expect")

return {
	["fires only with a round loaded and no reload running"] = function()
		expect.equal(Magazine.canFire(1, false), true)
		expect.equal(Magazine.canFire(0, false), false)
		expect.equal(Magazine.canFire(12, true), false)
	end,
	["a dry reload takes a full magazine from the reserve"] = function()
		local mag, reserve = Magazine.reload(0, 240, 30)
		expect.equal(mag, 30, "mag")
		expect.equal(reserve, 210, "reserve")
	end,
	["a partial reload tops up and takes only what is needed"] = function()
		local mag, reserve = Magazine.reload(18, 240, 30)
		expect.equal(mag, 30, "mag")
		expect.equal(reserve, 228, "reserve")
	end,
	["a short reserve loads what is left"] = function()
		local mag, reserve = Magazine.reload(12, 10, 30)
		expect.equal(mag, 22, "mag")
		expect.equal(reserve, 0, "reserve")
	end,
	["a reload starts only when it would change something"] = function()
		expect.equal(Magazine.canReload(30, 240, 30, false), false, "full magazine")
		expect.equal(Magazine.canReload(10, 0, 30, false), false, "no reserve")
		expect.equal(Magazine.canReload(10, 240, 30, true), false, "already reloading")
		expect.equal(Magazine.canReload(10, 240, 30, false), true, "short magazine")
	end,
}
