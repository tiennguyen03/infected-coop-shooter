--!strict
local Dismember = require("../src/shared/Rules/Dismember")
local expect = require("./expect")

local JOINTS: { [string]: Dismember.JointSpec } = {
	Elbow = {
		Counts = { "LowerArm", "Hand" },
		Falls = { "LowerArm", "Hand" },
		Fraction = 0.35,
		Limb = "Arm",
	},
	Shoulder = {
		Counts = { "UpperArm" },
		Falls = { "UpperArm", "LowerArm", "Hand" },
		Fraction = 0.5,
		Limb = "Arm",
	},
	Knee = {
		Counts = { "LowerLeg", "Foot" },
		Falls = { "LowerLeg", "Foot" },
		Fraction = 0.5,
		Limb = "Leg",
	},
	Hip = {
		Counts = { "UpperLeg" },
		Falls = { "UpperLeg", "LowerLeg", "Foot" },
		Fraction = 0.6,
		Limb = "Leg",
	},
}

return {
	["a limb part name splits into its side and the rest"] = function()
		local side, base = Dismember.sideOf("LeftLowerArm")
		expect.equal(side, "Left", "side")
		expect.equal(base, "LowerArm", "base")
		side, base = Dismember.sideOf("RightFoot")
		expect.equal(side, "Right", "side")
		expect.equal(base, "Foot", "base")
	end,
	["a part with no side is not a limb"] = function()
		local side, base = Dismember.sideOf("UpperTorso")
		expect.equal(side, nil, "side")
		expect.equal(base, nil, "base")
		side, base = Dismember.sideOf("Head")
		expect.equal(side, nil, "side")
		expect.equal(base, nil, "base")
	end,
	["a hit fills the joint above the part"] = function()
		expect.equal(Dismember.jointFor(JOINTS, "Hand"), "Elbow", "hand")
		expect.equal(Dismember.jointFor(JOINTS, "LowerArm"), "Elbow", "lower arm")
		expect.equal(Dismember.jointFor(JOINTS, "UpperArm"), "Shoulder", "upper arm")
		expect.equal(Dismember.jointFor(JOINTS, "Foot"), "Knee", "foot")
		expect.equal(Dismember.jointFor(JOINTS, "UpperLeg"), "Hip", "upper leg")
		expect.equal(Dismember.jointFor(JOINTS, "Torso"), nil, "no joint")
	end,
	["a form only loses the limbs it lists"] = function()
		local brute = { Arms = true, Legs = false }
		expect.equal(Dismember.canSever(brute, "Arm"), true, "brute arm")
		expect.equal(Dismember.canSever(brute, "Leg"), false, "brute leg")
		expect.equal(Dismember.canSever({}, "Arm"), false, "nothing listed")
		expect.equal(Dismember.canSever({ Arms = true, Legs = true }, "Tail"), false, "other limb")
	end,
	["damage adds up until the joint's share of max health"] = function()
		local total, severed = Dismember.hit(nil, 20, 100, 0.35)
		expect.equal(total, 20, "first hit")
		expect.equal(severed, false, "first hit holds")
		total, severed = Dismember.hit(total, 14, 100, 0.35)
		expect.equal(total, 34, "second hit")
		expect.equal(severed, false, "second hit holds")
		total, severed = Dismember.hit(total, 1, 100, 0.35)
		expect.equal(severed, true, "reaching the share breaks it")
		expect.equal(total, -math.huge, "spent")
	end,
	["a joint breaks once"] = function()
		local total, severed = Dismember.hit(-math.huge, 500, 100, 0.35)
		expect.equal(severed, false, "already gone")
		expect.equal(total, -math.huge, "stays spent")
	end,
}
