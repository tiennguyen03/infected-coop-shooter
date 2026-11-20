--!strict
-- A breaching round on a wall (Rules/WallBreach; the Mossberg's breaching shell, Nova
-- 2026-11-20). Written before the rule.
local WallBreach = require("../src/shared/Rules/WallBreach")
local expect = require("./expect")

local SETTINGS: WallBreach.Settings = {
	Names = { "Wall" },
	Materials = { "WoodPlanks", "CorrodedMetal" },
	MaxThickness = 1,
	Toughness = 2,
	Hole = { Width = 4, Height = 8 },
	MinPiece = 0.2,
}

local function piece(list: { WallBreach.Piece }, index: number): WallBreach.Piece
	local found = list[index]
	if not found then
		error(`no piece {index} (of {#list})`, 2)
	end
	return found
end

local function same(
	p: WallBreach.Piece,
	u0: number,
	u1: number,
	y0: number,
	y1: number,
	label: string
)
	expect.near(p.u0, u0, 1e-6, `{label} u0`)
	expect.near(p.u1, u1, 1e-6, `{label} u1`)
	expect.near(p.y0, y0, 1e-6, `{label} y0`)
	expect.near(p.y1, y1, 1e-6, `{label} y1`)
end

return {
	["a thin wall of a light material breaks; concrete, brick and thick walls hold"] = function()
		expect.equal(WallBreach.breakable("Wall", 0.6, "WoodPlanks", SETTINGS), true, "a hut")
		expect.equal(WallBreach.breakable("Wall", 0.6, "CorrodedMetal", SETTINGS), true, "the Shed")
		expect.equal(WallBreach.breakable("Wall", 0.6, "Concrete", SETTINGS), false, "concrete")
		expect.equal(WallBreach.breakable("Wall", 2, "WoodPlanks", SETTINGS), false, "too thick")
		expect.equal(WallBreach.breakable("Slab", 0.6, "WoodPlanks", SETTINGS), false, "a floor")
	end,
	["the breaching muzzle opens a wall in one shot, a standard muzzle in two"] = function()
		expect.equal(WallBreach.hitsToBreak(2, SETTINGS.Toughness), 1, "breaching muzzle")
		expect.equal(WallBreach.hitsToBreak(1, SETTINGS.Toughness), 2, "standard muzzle")
		expect.equal(WallBreach.hitsToBreak(0, SETTINGS.Toughness), math.huge, "no push, never")
	end,
	["hits add up on the wall"] = function()
		local damage, broken = WallBreach.struck(0, 1, SETTINGS.Toughness)
		expect.equal(broken, false, "the first standard hit cracks it")
		damage, broken = WallBreach.struck(damage, 1, SETTINGS.Toughness)
		expect.equal(broken, true, "the second opens it")
		local _, once = WallBreach.struck(0, 2, SETTINGS.Toughness)
		expect.equal(once, true, "the breaching muzzle: one")
		local same0, never = WallBreach.struck(0, 0 / 0, SETTINGS.Toughness)
		expect.equal(never, false, "NaN pushes nothing")
		expect.equal(same0, 0, "and adds nothing")
	end,
	["a door-sized hole from the floor at the hit, the rest of the wall kept"] = function()
		-- A wall 20 long, 9 tall (centred: u -10..10, y -4.5..4.5), hit 3 along.
		local pieces = WallBreach.cut(20, 9, 3, SETTINGS)
		expect.equal(#pieces, 3, "left, right, over the hole")
		same(piece(pieces, 1), -10, 1, -4.5, 4.5, "left")
		same(piece(pieces, 2), 5, 10, -4.5, 4.5, "right")
		same(piece(pieces, 3), 1, 5, 3.5, 4.5, "over the hole")
	end,
	["a hit by the end slides the hole inside the wall"] = function()
		local pieces = WallBreach.cut(20, 9, 9.5, SETTINGS)
		expect.equal(#pieces, 2, "no right piece")
		same(piece(pieces, 1), -10, 6, -4.5, 4.5, "left")
		same(piece(pieces, 2), 6, 10, 3.5, 4.5, "over the hole")
	end,
	["a piece shorter than the hole goes whole in height"] = function()
		-- The strip over a door (1 tall): nothing over the hole.
		local pieces = WallBreach.cut(20, 1, 0, SETTINGS)
		expect.equal(#pieces, 2, "left and right only")
		same(piece(pieces, 1), -10, -2, -0.5, 0.5, "left")
		same(piece(pieces, 2), 2, 10, -0.5, 0.5, "right")
	end,
	["a wall narrower than the hole goes, and slivers are not kept"] = function()
		expect.equal(#WallBreach.cut(3, 9, 0, SETTINGS), 1, "only the bit over the hole")
		expect.equal(#WallBreach.cut(3, 8, 0, SETTINGS), 0, "all of it")
		-- Hit 0.1 from a wall end: the hole slides in, and no 0.1 sliver is left.
		local pieces = WallBreach.cut(4.1, 8, 0, SETTINGS)
		expect.equal(#pieces, 0, "slivers dropped")
	end,
}
