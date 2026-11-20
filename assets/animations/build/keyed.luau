--!nocheck
-- Hand-keyed clips: moves no Mixamo download covers, authored as numbers.
--   lune run assets/animations/build/keyed.luau
-- Writes src/shared/AnimationClips/<clip>.json (git-ignored, the same table retarget.py writes),
-- so AnimationBuilder previews them in Studio and build_rbxm.luau builds them for upload.
--
-- Each clip starts and ends on a base pose (the first frame of BASE's retargeted clip, when
-- it exists; else the R15 rest) so it blends in and out of the body's idle. A key names
-- only the limbs it moves: { rx, ry, rz } degrees in the parent part's frame (Roblox axes:
-- +X right, +Y up, -Z forward), applied on top of the base pose, and for LowerTorso an
-- optional `pos` offset in studs (the hips: -y crouches, -z lunges forward). Signs:
--   shoulder / elbow / hip rx +  -> the limb swings forward (rx 180 = arm overhead)
--   knee rx -                    -> the shin folds back
--   UpperTorso rx -              -> lean forward; ry + turns the chest to his left
--   Head rx +                    -> look up
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local OUT = "src/shared/AnimationClips"
local FPS = 30

local ORDER = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot" }

-- --- quaternions { x, y, z, w }

local function qmul(a, b)
	return {
		a[4] * b[1] + a[1] * b[4] + a[2] * b[3] - a[3] * b[2],
		a[4] * b[2] - a[1] * b[3] + a[2] * b[4] + a[3] * b[1],
		a[4] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[4],
		a[4] * b[4] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
	}
end

local function axis(x, y, z, degrees)
	local half = math.rad(degrees) / 2
	local s = math.sin(half)
	return { x * s, y * s, z * s, math.cos(half) }
end

-- CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz.
local function euler(r)
	return qmul(qmul(axis(1, 0, 0, r[1] or 0), axis(0, 1, 0, r[2] or 0)), axis(0, 0, 1, r[3] or 0))
end

local function round(v, places)
	local m = 10 ^ places
	return math.floor(v * m + 0.5) / m
end

-- --- the clips

-- Both legs bent by `a` degrees at the hip (knee 2a, ankle a): feet stay roughly planted.
local function crouch(key, a)
	for _, side in { "Left", "Right" } do
		key[side .. "UpperLeg"] = { a }
		key[side .. "LowerLeg"] = { -2 * a }
		key[side .. "Foot"] = { a }
	end
	return key
end

-- One leg of the stride (warden_stride), named by which leg is doing what.
local function stride(front, back, key)
	key[front .. "UpperLeg"] = { 40 }
	key[front .. "LowerLeg"] = { -10 }
	key[front .. "Foot"] = { -18 }
	key[back .. "UpperLeg"] = { -28 }
	key[back .. "LowerLeg"] = { -35 }
	key[back .. "Foot"] = { 22 }
	return key
end

local function passing(lifted, planted, key)
	key[lifted .. "UpperLeg"] = { 30 }
	key[lifted .. "LowerLeg"] = { -62 }
	key[lifted .. "Foot"] = { 12 }
	key[planted .. "UpperLeg"] = { -4 }
	key[planted .. "LowerLeg"] = { -6 }
	key[planted .. "Foot"] = { 4 }
	return key
end

-- The shield arm (left) carried across his front through the whole stride.
local SHIELD_UPPER = { 32, 0, -12 }
local SHIELD_LOWER = { 82 }

local CLIPS = {
	-- The heavy walk (the boss pass, 2026-11-18; Config.Animations.Infected.Warden.move): a
	-- long, loaded stride. He leans into it, the hips sink hard on each heel strike (the
	-- step sound and the camera shake land there: Config.Index.Warden.Weight.StepMarks 0.25
	-- and 0.75), the shoulders counter-turn and roll onto the planted side, the shield stays
	-- across his front and the free arm swings. A loop: it starts and ends on the left
	-- passing pose (`loopPose`), not the idle.
	warden_stride = {
		base = "warden_idle",
		duration = 1.3,
		loop = true,
		loopPose = passing("Left", "Right", {
			LowerTorso = { 0, 0, 0, pos = { 0, 0.08, 0 } },
			UpperTorso = { -16, 0, 0 },
			Head = { 10, 0, 0 },
			LeftUpperArm = SHIELD_UPPER,
			LeftLowerArm = SHIELD_LOWER,
			RightUpperArm = { 4, 0, 10 },
			RightLowerArm = { 22 },
		}),
		keys = {
			{
				t = 0.325, -- left heel strike
				pose = stride("Left", "Right", {
					LowerTorso = { 3, -9, 0, pos = { 0, -0.42, 0 } },
					UpperTorso = { -20, 12, 5 },
					Head = { 12, -8, 0 },
					LeftUpperArm = SHIELD_UPPER,
					LeftLowerArm = SHIELD_LOWER,
					RightUpperArm = { 32, 0, 10 },
					RightLowerArm = { 30 },
				}),
			},
			{
				t = 0.65, -- right passing
				pose = passing("Right", "Left", {
					LowerTorso = { 0, 0, 0, pos = { 0, 0.08, 0 } },
					UpperTorso = { -16, 0, 0 },
					Head = { 10, 0, 0 },
					LeftUpperArm = SHIELD_UPPER,
					LeftLowerArm = SHIELD_LOWER,
					RightUpperArm = { 4, 0, 10 },
					RightLowerArm = { 22 },
				}),
			},
			{
				t = 0.975, -- right heel strike
				pose = stride("Right", "Left", {
					LowerTorso = { 3, 9, 0, pos = { 0, -0.42, 0 } },
					UpperTorso = { -20, -12, -5 },
					Head = { 12, 8, 0 },
					LeftUpperArm = SHIELD_UPPER,
					LeftLowerArm = SHIELD_LOWER,
					RightUpperArm = { -26, 0, 10 },
					RightLowerArm = { 34 },
				}),
			},
		},
	},
	-- The Shield Bash (Config.Index.Warden.Bash, StrikeAt 0.45 -> 0.63 s): he turns the
	-- shield shoulder back, sinks, then drives the shield straight out with a step. No spin:
	-- the Mixamo Power Slash it replaces turned him a full circle.
	warden_shove = {
		base = "warden_idle",
		duration = 1.4,
		keys = {
			{
				t = 0.3,
				pose = crouch({
					LowerTorso = { 0, 0, 0, pos = { 0, -0.35, 0.15 } },
					UpperTorso = { 5, 30, 0 },
					Head = { 0, -20, 0 },
					LeftUpperArm = { 35, 0, -10 },
					LeftLowerArm = { 85 },
					RightUpperArm = { -25, 0, 10 },
					RightLowerArm = { 30 },
				}, 22),
			},
			{
				t = 0.63,
				pose = {
					LowerTorso = { -6, 0, 0, pos = { 0, -0.55, -0.7 } },
					UpperTorso = { -15, -5, 0 },
					Head = { 10, 15, 0 },
					LeftUpperArm = { 85, 0, -5 },
					LeftLowerArm = { 8 },
					RightUpperArm = { -35, 0, 15 },
					RightLowerArm = { 40 },
					LeftUpperLeg = { 50 },
					LeftLowerLeg = { -55 },
					LeftFoot = { 10 },
					RightUpperLeg = { -20 },
					RightLowerLeg = { -25 },
					RightFoot = { 25 },
				},
			},
			{
				t = 0.85,
				pose = {
					LowerTorso = { -6, 0, 0, pos = { 0, -0.5, -0.65 } },
					UpperTorso = { -12, -3, 0 },
					Head = { 8, 12, 0 },
					LeftUpperArm = { 80, 0, -5 },
					LeftLowerArm = { 12 },
					RightUpperArm = { -30, 0, 15 },
					RightLowerArm = { 40 },
					LeftUpperLeg = { 48 },
					LeftLowerLeg = { -52 },
					LeftFoot = { 8 },
					RightUpperLeg = { -18 },
					RightLowerLeg = { -22 },
					RightFoot = { 22 },
				},
			},
		},
	},
	-- The Leap (Config.Index.Warden.Leap, StrikeAt 0.75 -> lands at 1.5 s): a deep gather
	-- with the arms swung back (the tell, played over Windup), the throw up, a tuck with
	-- both fists overhead through the flight (the server carries the root on its arc), and
	-- both fists into the ground on the landing, then he rises.
	warden_leap = {
		base = "warden_idle",
		duration = 2.0,
		keys = {
			{
				t = 0.55,
				pose = crouch({
					LowerTorso = { 0, 0, 0, pos = { 0, -0.85, 0.2 } },
					UpperTorso = { -35 },
					Head = { 25 },
					LeftUpperArm = { -50, 0, -10 },
					LeftLowerArm = { 25 },
					RightUpperArm = { -50, 0, 10 },
					RightLowerArm = { 25 },
				}, 55),
			},
			{
				t = 0.72,
				pose = {
					LowerTorso = { 0, 0, 0, pos = { 0, 0.4, 0 } },
					UpperTorso = { 10 },
					Head = { 10 },
					LeftUpperArm = { 150 },
					LeftLowerArm = { 10 },
					RightUpperArm = { 150 },
					RightLowerArm = { 10 },
					LeftUpperLeg = { -10 },
					LeftLowerLeg = { -5 },
					LeftFoot = { -30 },
					RightUpperLeg = { -10 },
					RightLowerLeg = { -5 },
					RightFoot = { -30 },
				},
			},
			{
				t = 1.05,
				pose = {
					LowerTorso = { 0, 0, 0, pos = { 0, 0.2, 0 } },
					UpperTorso = { 15 },
					Head = { -5 },
					LeftUpperArm = { 170, 0, 15 },
					LeftLowerArm = { 45 },
					RightUpperArm = { 170, 0, -15 },
					RightLowerArm = { 45 },
					LeftUpperLeg = { 65 },
					LeftLowerLeg = { -95 },
					LeftFoot = { 10 },
					RightUpperLeg = { 50 },
					RightLowerLeg = { -80 },
					RightFoot = { 10 },
				},
			},
			{
				t = 1.35,
				pose = {
					LowerTorso = { 0, 0, 0, pos = { 0, -0.2, 0 } },
					UpperTorso = { -20 },
					Head = { 5 },
					LeftUpperArm = { 125, 0, 10 },
					LeftLowerArm = { 20 },
					RightUpperArm = { 125, 0, -10 },
					RightLowerArm = { 20 },
					LeftUpperLeg = { 35 },
					LeftLowerLeg = { -45 },
					LeftFoot = { 10 },
					RightUpperLeg = { 30 },
					RightLowerLeg = { -40 },
					RightFoot = { 10 },
				},
			},
			{
				t = 1.5,
				pose = crouch({
					LowerTorso = { 0, 0, 0, pos = { 0, -1.0, 0.3 } },
					UpperTorso = { -55 },
					Head = { 30 },
					LeftUpperArm = { 55, 0, 10 },
					LeftLowerArm = { 5 },
					RightUpperArm = { 55, 0, -10 },
					RightLowerArm = { 5 },
				}, 62),
			},
			{
				t = 1.72,
				pose = crouch({
					LowerTorso = { 0, 0, 0, pos = { 0, -0.9, 0.25 } },
					UpperTorso = { -45 },
					Head = { 30 },
					LeftUpperArm = { 50, 0, 10 },
					LeftLowerArm = { 10 },
					RightUpperArm = { 50, 0, -10 },
					RightLowerArm = { 10 },
				}, 56),
			},
		},
	},
}

-- --- build

local function basePose(name)
	local poses = {}
	local path = OUT .. "/" .. name .. ".json"
	if name and fs.isFile(path) then
		local clip = serde.decode("json", fs.readFile(path))
		for part, v in clip.keyframes[1].poses do
			poses[part] = v
		end
	else
		print(`  base {name}: missing, keyed on the R15 rest pose`)
	end
	for _, part in ORDER do
		poses[part] = poses[part] or { 0, 0, 0, 0, 0, 0, 1 }
	end
	return poses
end

local function apply(base, offset)
	local out = {}
	for _, part in ORDER do
		local b = base[part]
		local r = offset and offset[part]
		if not r then
			out[part] = table.clone(b)
			continue
		end
		local q = qmul(euler(r), { b[4], b[5], b[6], b[7] })
		local pos = r.pos or { 0, 0, 0 }
		out[part] = {
			round(b[1] + pos[1], 4),
			round(b[2] + pos[2], 4),
			round(b[3] + pos[3], 4),
			round(q[1], 5),
			round(q[2], 5),
			round(q[3], 5),
			round(q[4], 5),
		}
	end
	return out
end

if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end
local names = {}
for name in CLIPS do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local spec = CLIPS[name]
	local base = basePose(spec.base)
	-- A loop starts and ends on its own loopPose; a one-shot on the base pose.
	local ends = spec.loopPose
	local keyframes = { { t = 0, poses = apply(base, ends) } }
	for _, key in spec.keys do
		table.insert(keyframes, { t = key.t, poses = apply(base, key.pose) })
	end
	table.insert(keyframes, { t = spec.duration, poses = apply(base, ends) })
	local clip = {
		name = name,
		fps = FPS,
		loop = spec.loop == true,
		upperBody = false,
		duration = spec.duration,
		groundSpeed = 0,
		keyframes = keyframes,
	}
	fs.writeFile(OUT .. "/" .. name .. ".json", serde.encode("json", clip))
	print(`{name}: {#keyframes} keyframes, {spec.duration} s`)
end
