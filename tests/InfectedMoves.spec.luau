--!strict
local InfectedMoves = require("../src/shared/Rules/InfectedMoves")
local expect = require("./expect")

local ARMOUR: InfectedMoves.ArmourSettings = {
	frontShare = 0.35,
	backMultiplier = 1.25,
	frontDot = 0.5,
	backDot = -0.5,
}

local GRAB: InfectedMoves.GrabSettings = {
	crowd = 3,
	slow = 0.6,
	slowPerExtra = 0.1,
	minFactor = 0.3,
}

return {
	-- Facing: the hit point's offset from the struck part's centre, in the body's own
	-- frame (forward, right). The face a round lands on is the side it came from.
	["a hit on the front face is front"] = function()
		expect.equal(InfectedMoves.facing(1, 0.2, ARMOUR), "front")
	end,
	["a hit on the side face is side"] = function()
		expect.equal(InfectedMoves.facing(0.1, 1, ARMOUR), "side")
		expect.equal(InfectedMoves.facing(0.1, -1, ARMOUR), "side")
	end,
	["a hit on the back face is back"] = function()
		expect.equal(InfectedMoves.facing(-1, 0.3, ARMOUR), "back")
	end,
	["a hit at the centre counts as side"] = function()
		expect.equal(InfectedMoves.facing(0, 0, ARMOUR), "side")
	end,

	-- Armour: the plated front soaks, the back pays more, legs never plated.
	["the front of the torso takes the front share"] = function()
		expect.near(InfectedMoves.armour("front", "UpperTorso", ARMOUR), 0.35, 1e-9)
	end,
	["the head from the front is plated too"] = function()
		expect.near(InfectedMoves.armour("front", "Head", ARMOUR), 0.35, 1e-9)
	end,
	["the back takes the back multiplier"] = function()
		expect.near(InfectedMoves.armour("back", "UpperTorso", ARMOUR), 1.25, 1e-9)
	end,
	["the side takes full damage"] = function()
		expect.equal(InfectedMoves.armour("side", "LeftUpperArm", ARMOUR), 1)
	end,
	["legs and feet take full damage from the front"] = function()
		expect.equal(InfectedMoves.armour("front", "LeftUpperLeg", ARMOUR), 1)
		expect.equal(InfectedMoves.armour("front", "RightLowerLeg", ARMOUR), 1)
		expect.equal(InfectedMoves.armour("front", "LeftFoot", ARMOUR), 1)
	end,
	["legs from behind take only full damage, not the back bonus"] = function()
		expect.equal(InfectedMoves.armour("back", "LeftUpperLeg", ARMOUR), 1)
	end,

	-- The grab: a crowd round a soldier slows them; one or two Walkers do not.
	["fewer than the crowd does not grab"] = function()
		expect.equal(InfectedMoves.grabFactor(2, GRAB), 1)
		expect.equal(InfectedMoves.grabFactor(0, GRAB), 1)
	end,
	["the crowd grabs at the base slow"] = function()
		expect.near(InfectedMoves.grabFactor(3, GRAB), 0.6, 1e-9)
	end,
	["each body past the crowd slows more"] = function()
		expect.near(InfectedMoves.grabFactor(5, GRAB), 0.4, 1e-9)
	end,
	["the grab never goes below the floor"] = function()
		expect.near(InfectedMoves.grabFactor(30, GRAB), 0.3, 1e-9)
	end,

	-- Range gates for the big moves.
	["a move starts only inside its band"] = function()
		expect.equal(InfectedMoves.inBand(10, 6, 18), true)
		expect.equal(InfectedMoves.inBand(5, 6, 18), false)
		expect.equal(InfectedMoves.inBand(19, 6, 18), false)
		expect.equal(InfectedMoves.inBand(6, 6, 18), true)
	end,

	-- The charge's length: past the target by the overrun, never longer than the most.
	["the charge runs past the target by the overrun"] = function()
		expect.equal(InfectedMoves.chargeLength(20, 10, 40), 30)
	end,
	["the charge is capped at its distance"] = function()
		expect.equal(InfectedMoves.chargeLength(38, 10, 40), 40)
	end,

	-- Scatter: who the charge hits is thrown to the side of its line they stand on.
	["scatter throws a body on the right to the right"] = function()
		local x, z = InfectedMoves.scatter(0, 1, 1, 0.5)
		-- charging along +z; a body to the +x side goes +x (and a little along the charge)
		expect.equal(x > 0, true, "x")
		expect.equal(z > 0, true, "z")
	end,
	["scatter throws a body on the left to the left"] = function()
		local x = InfectedMoves.scatter(0, 1, -1, 0.5)
		expect.equal(x < 0, true, "x")
	end,
	["scatter picks a side for a body dead on the line"] = function()
		local x, z = InfectedMoves.scatter(0, 1, 0, 0.5)
		expect.near(math.abs(x), 1 / math.sqrt(1.25), 1e-6, "x")
		expect.near(z, 0.5 / math.sqrt(1.25), 1e-6, "z")
	end,

	-- The pounce arc: from start to landing, Arc studs high in the middle.
	["the pounce starts at the start and ends at the landing"] = function()
		local x0, y0, z0 = InfectedMoves.arc(0, 0, 0, 10, 0, 0, 4, 0)
		expect.equal(x0, 0)
		expect.equal(y0, 0)
		expect.equal(z0, 0)
		local x1, y1 = InfectedMoves.arc(0, 0, 0, 10, 0, 0, 4, 1)
		expect.equal(x1, 10)
		expect.near(y1, 0, 1e-9)
	end,
	["the pounce peaks at half way"] = function()
		local x, y = InfectedMoves.arc(0, 0, 0, 10, 2, 0, 4, 0.5)
		expect.equal(x, 5)
		expect.near(y, 5, 1e-9) -- 1 (the mid height) + 4
	end,

	-- The Hocker's barrage: one glob on the mark, the rest either side across the line.
	["one glob lands on the mark"] = function()
		local spots = InfectedMoves.barrage(1, 7, 1, 0)
		expect.equal(#spots, 1)
		expect.equal(spots[1].x, 0)
		expect.equal(spots[1].z, 0)
	end,
	["three globs land on the mark and either side"] = function()
		local spots = InfectedMoves.barrage(3, 7, 1, 0)
		expect.equal(#spots, 3)
		expect.equal(spots[1].x, 0)
		-- the line runs along +x, so the side globs sit at +-7 on z
		expect.near(spots[2].z, 7, 1e-9)
		expect.near(spots[3].z, -7, 1e-9)
		expect.near(spots[2].x, 0, 1e-9)
	end,
	["a fourth glob steps out further"] = function()
		local spots = InfectedMoves.barrage(4, 7, 0, 1)
		expect.equal(#spots, 4)
		expect.near(math.abs(spots[4].x), 14, 1e-9)
	end,
}
