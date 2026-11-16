--!strict
local ReviveAnim = require("../src/shared/Rules/ReviveAnim")
local expect = require("./expect")

-- A casualty lying along +X (feet to head) with the chest 1 stud toward the head.
local KNEEL: ReviveAnim.KneelSettings = {
	chestX = 1,
	chestZ = 0,
	axisX = 1,
	axisZ = 0,
	distance = 2,
	turn = 0,
	maxNudge = 5,
}

local TIMES: ReviveAnim.Times = {
	kneel = 0.3,
	finish = 0.9,
	pullShare = 0.6,
	nudgeSeconds = 0.25,
	nudgeSpeed = 10,
}

return {
	["the chest sits at its offset from the root, turned with the body"] = function()
		local x, z = ReviveAnim.chest(10, 20, 0, KNEEL)
		expect.near(x, 11, 1e-9, "x")
		expect.near(z, 20, 1e-9, "z")
		-- Yaw 90 degrees (a quarter turn to the left): local +X points along world -Z.
		local tx, tz = ReviveAnim.chest(10, 20, math.pi / 2, KNEEL)
		expect.near(tx, 10, 1e-9, "turned x")
		expect.near(tz, 19, 1e-9, "turned z")
	end,
	["the two kneel points sit either side of the chest, across the body"] = function()
		local points = ReviveAnim.kneelPoints(0, 0, 0, KNEEL)
		expect.equal(#points, 2, "count")
		for _, point in points do
			expect.near(point.x, 1, 1e-9, "beside the chest, not along the body")
			expect.near(math.abs(point.z), 2, 1e-9, "distance from the chest")
		end
		expect.near(points[1].z + points[2].z, 0, 1e-9, "opposite sides")
	end,
	["a kneel point faces the chest"] = function()
		for _, point in ReviveAnim.kneelPoints(3, -4, 0.7, KNEEL) do
			local cx, cz = ReviveAnim.chest(3, -4, 0.7, KNEEL)
			-- The look vector of a body with this yaw is (-sin, -cos).
			local lookX, lookZ = -math.sin(point.yaw), -math.cos(point.yaw)
			expect.near(point.x + lookX * KNEEL.distance, cx, 1e-6, "x")
			expect.near(point.z + lookZ * KNEEL.distance, cz, 1e-6, "z")
		end
	end,
	["a bladed kneel is turned left of the chest by its turn"] = function()
		local turned = table.clone(KNEEL)
		turned.turn = 0.5
		local straight = ReviveAnim.kneelPoints(3, -4, 0.7, KNEEL)
		for index, point in ReviveAnim.kneelPoints(3, -4, 0.7, turned) do
			expect.near(point.yaw - straight[index].yaw, 0.5, 1e-9, "yaw")
			expect.near(point.x, straight[index].x, 1e-9, "same place")
		end
	end,
	["facing looks from one point at another"] = function()
		expect.near(ReviveAnim.facing(0, 0, 0, -5), 0, 1e-9, "toward -Z is yaw 0")
		expect.near(ReviveAnim.facing(0, 0, -5, 0), math.pi / 2, 1e-9, "toward -X")
		expect.near(ReviveAnim.facing(0, 0, 5, 0), -math.pi / 2, 1e-9, "toward +X")
	end,
	["the reviver takes the nearer side"] = function()
		local points = ReviveAnim.kneelPoints(0, 0, 0, KNEEL)
		local near = ReviveAnim.pick(points, 1, 3, { false, false }, KNEEL)
		expect.equal(near ~= nil and points[near :: number].z > 0, true, "the +Z side")
		local far = ReviveAnim.pick(points, 1, -3, { false, false }, KNEEL)
		expect.equal(far ~= nil and points[far :: number].z < 0, true, "the -Z side")
	end,
	["a blocked side is skipped for the other one"] = function()
		local points = ReviveAnim.kneelPoints(0, 0, 0, KNEEL)
		local near = ReviveAnim.pick(points, 1, 1, { false, false }, KNEEL) :: number
		local blocked = { false, false }
		blocked[near] = true
		local other = ReviveAnim.pick(points, 1, 1, blocked, KNEEL)
		expect.equal(other, 3 - near, "the other side")
	end,
	["with both sides blocked, or too far to slide, the reviver stays put"] = function()
		local points = ReviveAnim.kneelPoints(0, 0, 0, KNEEL)
		expect.equal(ReviveAnim.pick(points, 1, 1, { true, true }, KNEEL), nil, "both blocked")
		expect.equal(ReviveAnim.pick(points, 1, 8, { false, false }, KNEEL), nil, "too far")
	end,
	["the slide takes its base time, longer for a longer way, never slower than its speed"] = function()
		expect.near(ReviveAnim.nudgeSeconds(1, TIMES), 0.25, 1e-9, "short")
		expect.near(ReviveAnim.nudgeSeconds(5, TIMES), 0.5, 1e-9, "long")
	end,
	["the reviver kneels, then treats; walking breaks the kneel"] = function()
		expect.equal(ReviveAnim.phase("treat", 0, false, TIMES), "kneel", "start")
		expect.equal(ReviveAnim.phase("treat", 0.29, false, TIMES), "kneel", "still going down")
		expect.equal(ReviveAnim.phase("treat", 0.3, false, TIMES), "treat", "down")
		expect.equal(ReviveAnim.phase("treat", 2, false, TIMES), "treat", "mid revive")
		expect.equal(ReviveAnim.phase("treat", 2, true, TIMES), "walk", "moving")
	end,
	["the finish is a pull, then standing"] = function()
		expect.equal(ReviveAnim.phase("finish", 0, false, TIMES), "pull", "start")
		expect.equal(ReviveAnim.phase("finish", 0.5, false, TIMES), "pull", "pulling")
		expect.equal(ReviveAnim.phase("finish", 0.6, false, TIMES), "stand", "standing")
		expect.equal(
			ReviveAnim.phase("finish", 0.5, true, TIMES),
			"pull",
			"moving does not stop it"
		)
	end,
	["the casualty lies while treated and rises when revived"] = function()
		expect.equal(ReviveAnim.phase("treated", 1, false, TIMES), "lie", "treated")
		expect.equal(ReviveAnim.phase("treated", 1, true, TIMES), "walk", "crawling away")
		expect.equal(ReviveAnim.phase("recover", 0.2, false, TIMES), "rise", "revived")
	end,
	["no role, no phase"] = function()
		expect.equal(ReviveAnim.phase("", 1, false, TIMES), "none", "empty")
		expect.equal(ReviveAnim.phase("nonsense", 1, false, TIMES), "none", "unknown")
	end,
	["a press goes down and comes back once per cycle"] = function()
		expect.near(ReviveAnim.press(0, 2), 0, 1e-9, "start of a cycle")
		expect.near(ReviveAnim.press(0.25, 2), 1, 1e-9, "bottom")
		expect.near(ReviveAnim.press(0.5, 2), 0, 1e-9, "next cycle")
		for step = 0, 40 do
			local depth = ReviveAnim.press(step / 40, 2)
			expect.equal(depth >= 0 and depth <= 1, true, "in range")
		end
	end,
	["the pull reaches out, holds, and lets go by the end"] = function()
		expect.near(ReviveAnim.pull(0, TIMES), 0, 1e-9, "start")
		expect.near(ReviveAnim.pull(0.3, TIMES), 1, 1e-9, "holding")
		expect.near(ReviveAnim.pull(0.9, TIMES), 0, 1e-9, "end")
		expect.near(ReviveAnim.pull(2, TIMES), 0, 1e-9, "after")
		local last = 0
		for step = 0, 10 do
			local weight = ReviveAnim.pull(step / 10 * 0.15, TIMES)
			expect.equal(weight >= last, true, "rises on the way in")
			last = weight
		end
	end,
	["approach moves toward the target by at most the step and never past it"] = function()
		expect.near(ReviveAnim.approach(0, 1, 0.25), 0.25, 1e-9, "up")
		expect.near(ReviveAnim.approach(1, 0, 0.25), 0.75, 1e-9, "down")
		expect.near(ReviveAnim.approach(0.9, 1, 0.25), 1, 1e-9, "clamped")
	end,
	["ease is smooth, clamped and monotone"] = function()
		expect.near(ReviveAnim.ease(-1), 0, 1e-9, "below")
		expect.near(ReviveAnim.ease(0.5), 0.5, 1e-9, "middle")
		expect.near(ReviveAnim.ease(2), 1, 1e-9, "above")
	end,
}
