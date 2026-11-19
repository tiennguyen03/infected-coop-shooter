--!nocheck
-- The Carrier sellers' looping idles (docs/sprints/CARRIER_V2.md > Poses and idle animations),
-- hand-keyed as numbers: no Mixamo clip sits on a stool or in a hammock.
--   lune run assets/animations/build/seller_idles.luau
-- Writes src/shared/AnimationClips/<clip>.json (git-ignored, the table retarget.py writes), so
-- AnimationBuilder previews them in Studio and build_rbxm.luau builds them for upload
-- (upload_animations.js; ids in Config.Animations.Ids and ASSET_IDS.md).
--
-- The hold pose is not in the clip: NpcPose turns each seller's Motor6D C0s once (seated,
-- leaning, feet up), and a clip's Transform plays on top of it. So every clip moves away from
-- and back to zero (the held pose); a track names only the limbs it moves. A key is
-- { t, { rx, ry, rz } } in degrees about the posed joint's own axes (R15: +X right, +Y up,
-- -Z forward), and for LowerTorso an optional third entry { x, y, z } studs (the hips).
--   shoulder / elbow / hip rx +  -> the limb swings forward and up
--   UpperTorso rx -              -> lean forward; ry + turns the chest to the left
--   Head rx +                    -> look up; ry + looks to the left
--   left arm rz -                -> out to the side (right arm: rz +)
-- Each track starts and ends at zero; keys are eased (smoothstep) and sampled at FPS, so the
-- linear keyframes build_rbxm writes still move smoothly. The chest breathes on top of all.
-- Same output format as keyed.luau (PR #83, the Warden's clips); the two can share helpers
-- once both are in main.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local OUT = "src/shared/AnimationClips"
local FPS = 15
local BREATH = 1.2 -- degrees the chest rises a breath (UpperTorso rx)
local BREATH_SECONDS = 4 -- about one breath this long; rounded so the loop closes

local ORDER = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot" }

local ZERO = { 0, 0, 0 }

-- A to-and-fro: `a` and `b` alternating from `t0` every `step` seconds, `n` times.
local function wiggle(t0, step, n, a, b)
	local keys = {}
	for i = 0, n - 1 do
		table.insert(keys, { t0 + i * step, if i % 2 == 0 then a else b })
	end
	return keys
end

local function concat(...)
	local out = {}
	for _, list in { ... } do
		for _, key in list do
			table.insert(out, key)
		end
	end
	return out
end

local CLIPS = {
	-- The Quartermaster on his stool, elbows on the glass: taps the pencil, looks up over his
	-- glasses at whoever is there, turns a page on the clipboard under his left hand.
	seller_quartermaster = {
		duration = 8,
		tracks = {
			RightLowerArm = concat(
				{ { 1.4, ZERO } },
				wiggle(1.6, 0.2, 4, { 8, 0, 0 }, ZERO),
				{ { 2.4, ZERO } }
			),
			Head = {
				{ 2.8, ZERO },
				{ 3.3, { 12, 0, 0 } },
				{ 4.6, { 12, -5, 0 } },
				{ 5.1, ZERO },
			},
			LeftUpperArm = {
				{ 5.1, ZERO },
				{ 5.6, { 8, 15, 0 } },
				{ 6.1, { 4, -10, 0 } },
				{ 6.6, ZERO },
			},
			LeftLowerArm = {
				{ 5.1, ZERO },
				{ 5.6, { 20, 0, 0 } },
				{ 6.1, { 10, 0, 0 } },
				{ 6.6, ZERO },
			},
		},
	},
	-- The sapper sergeant on his crate (mug in the right hand, an unlit cigarette behind his
	-- ear, no smoke): a slow sip of tea, a glance down at the cat on his left, a lazy wave.
	seller_sapper = {
		duration = 8,
		tracks = {
			RightUpperArm = { { 0.8, ZERO }, { 1.6, { 25, 0, 0 } }, { 2.6, { 25, 0, 0 } }, { 3.3, ZERO } },
			RightLowerArm = { { 0.8, ZERO }, { 1.6, { 45, 0, 0 } }, { 2.6, { 45, 0, 0 } }, { 3.3, ZERO } },
			Head = {
				{ 0.8, ZERO },
				{ 1.7, { 10, 0, 0 } },
				{ 2.5, { 10, 0, 0 } },
				{ 3.3, ZERO },
				{ 3.8, ZERO },
				{ 4.3, { -15, 40, 0 } },
				{ 5.2, { -15, 40, 0 } },
				{ 5.8, ZERO },
			},
			LeftUpperArm = concat(
				{ { 6.0, ZERO } },
				wiggle(6.3, 0.3, 4, { 0, 0, -12 }, { 0, 0, 10 }),
				{ { 7.6, ZERO } }
			),
			LeftLowerArm = concat(
				{ { 6.0, ZERO } },
				wiggle(6.3, 0.3, 4, { 0, 0, -15 }, { 0, 0, 15 }),
				{ { 7.6, ZERO } }
			),
		},
	},
	-- The Loadmaster sideways in the hammock: rocks it with the boot on the deck, then
	-- settles back with his arm over his eyes.
	seller_loadmaster = {
		duration = 9,
		tracks = {
			LowerTorso = {
				{ 1.1, { 3, 0, 0 }, { 0, 0, -0.2 } },
				{ 2.2, { -3, 0, 0 }, { 0, 0, 0.2 } },
				{ 3.3, { 3, 0, 0 }, { 0, 0, -0.2 } },
				{ 4.4, ZERO },
				{ 5.5, { 2, 0, 0 }, { 0, 0, -0.12 } },
				{ 6.6, { -2, 0, 0 }, { 0, 0, 0.12 } },
				{ 7.7, { 1, 0, 0 }, { 0, 0, -0.05 } },
			},
			RightUpperLeg = { { 0.9, { -8, 0, 0 } }, { 2.0, { 6, 0, 0 } }, { 3.1, { -8, 0, 0 } }, { 4.2, ZERO } },
			RightUpperArm = { { 4.4, ZERO }, { 5.2, { 85, 0, -20 } }, { 7.4, { 85, 0, -20 } }, { 8.4, ZERO } },
			RightLowerArm = { { 4.4, ZERO }, { 5.2, { 90, 0, 0 } }, { 7.4, { 90, 0, 0 } }, { 8.4, ZERO } },
			Head = { { 4.8, ZERO }, { 5.4, { 8, 0, 0 } }, { 7.4, { 8, 0, 0 } }, { 8.2, ZERO } },
		},
	},
	-- The motor sergeant on her tyres, the part in her lap: wipes it, turns it over, then
	-- reaches down to her left and scratches the dog's head.
	seller_motor_sergeant = {
		duration = 8,
		tracks = {
			RightUpperArm = concat(
				{ { 0.4, ZERO } },
				wiggle(0.8, 0.4, 4, { 0, 12, 0 }, { 0, -8, 0 }),
				{ { 2.4, ZERO } }
			),
			RightLowerArm = concat(
				{ { 0.4, ZERO } },
				wiggle(0.8, 0.4, 4, { 10, 0, 0 }, { -5, 0, 0 }),
				{ { 2.4, ZERO } }
			),
			LeftHand = { { 2.6, ZERO }, { 3.1, { 0, 35, 0 } }, { 3.6, { 0, 35, 0 } }, { 4.0, ZERO } },
			RightHand = { { 2.6, ZERO }, { 3.1, { 0, 35, 0 } }, { 3.6, { 0, 35, 0 } }, { 4.0, ZERO } },
			UpperTorso = { { 4.2, ZERO }, { 4.9, { -10, 15, -8 } }, { 6.4, { -10, 15, -8 } }, { 7.1, ZERO } },
			Head = { { 4.2, ZERO }, { 4.9, { -10, 25, 0 } }, { 6.4, { -10, 25, 0 } }, { 7.1, ZERO } },
			LeftUpperArm = { { 4.2, ZERO }, { 4.9, { -40, 0, -15 } }, { 6.4, { -40, 0, -15 } }, { 7.1, ZERO } },
			LeftLowerArm = concat(
				{ { 4.2, ZERO } },
				wiggle(4.9, 0.3, 5, { -35, 0, 0 }, { -25, 0, 0 }),
				{ { 6.4, { -35, 0, 0 } }, { 7.1, ZERO } }
			),
		},
	},
	-- Control's watch officer tipped back, boots on the map table: tosses her pen up and
	-- catches it, then sits up to tap a district on the map and tips back again.
	seller_watch_officer = {
		duration = 8,
		tracks = {
			RightUpperArm = {
				{ 0.6, ZERO },
				{ 1.0, { 40, 0, 0 } },
				{ 1.9, { 40, 0, 0 } },
				{ 2.4, ZERO },
				{ 3.6, ZERO },
				{ 4.4, { 85, 0, 0 } },
				{ 5.7, { 85, 0, 0 } },
				{ 6.5, ZERO },
			},
			RightLowerArm = concat({
				{ 0.6, ZERO },
				{ 1.0, { 60, 0, 0 } },
				{ 1.15, { 90, 0, 0 } },
				{ 1.3, { 60, 0, 0 } },
				{ 1.8, { 75, 0, 0 } },
				{ 1.9, { 60, 0, 0 } },
				{ 2.4, ZERO },
				{ 3.6, ZERO },
			}, wiggle(4.4, 0.25, 5, { 15, 0, 0 }, { 30, 0, 0 }), { { 5.7, { 15, 0, 0 } }, { 6.5, ZERO } }),
			Head = {
				{ 0.9, ZERO },
				{ 1.3, { 20, 0, 0 } },
				{ 1.8, { 8, 0, 0 } },
				{ 2.3, ZERO },
				{ 3.4, ZERO },
				{ 4.2, { -15, 0, 0 } },
				{ 5.8, { -15, 0, 0 } },
				{ 6.6, ZERO },
			},
			UpperTorso = { { 3.4, ZERO }, { 4.2, { -28, 0, 0 } }, { 5.8, { -28, 0, 0 } }, { 6.6, ZERO } },
		},
	},
}

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
	return qmul(qmul(axis(1, 0, 0, r[1]), axis(0, 1, 0, r[2])), axis(0, 0, 1, r[3]))
end

local function round(v, places)
	local m = 10 ^ places
	return math.floor(v * m + 0.5) / m
end

-- --- sampling

-- The track's value at `t`: { rx, ry, rz, x, y, z }, eased between its keys, zero at both ends.
local function sample(track, duration, t)
	local keys = { { 0, ZERO, ZERO } }
	for _, key in track or {} do
		table.insert(keys, { key[1], key[2], key[3] or ZERO })
	end
	table.insert(keys, { duration, ZERO, ZERO })
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a[1] and t <= b[1] then
			local span = b[1] - a[1]
			local u = if span > 0 then (t - a[1]) / span else 1
			u = u * u * (3 - 2 * u)
			local out = {}
			for j = 1, 3 do
				out[j] = a[2][j] + (b[2][j] - a[2][j]) * u
				out[j + 3] = a[3][j] + (b[3][j] - a[3][j]) * u
			end
			return out
		end
	end
	return { 0, 0, 0, 0, 0, 0 }
end

local function check(name, spec)
	for part, track in spec.tracks do
		assert(table.find(ORDER, part), `{name}: no part {part}`)
		local last = 0
		for _, key in track do
			assert(key[1] > last and key[1] < spec.duration, `{name}.{part}: key at {key[1]} out of order`)
			last = key[1]
		end
	end
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
	check(name, spec)
	local breaths = math.max(1, math.floor(spec.duration / BREATH_SECONDS + 0.5))
	local frames = math.floor(spec.duration * FPS + 0.5)
	local keyframes = {}
	for f = 0, frames do
		local t = f / FPS
		local poses = {}
		for _, part in ORDER do
			local v = sample(spec.tracks[part], spec.duration, t)
			if part == "UpperTorso" then
				v[1] -= BREATH * math.sin(2 * math.pi * breaths * t / spec.duration)
			end
			local q = euler(v)
			poses[part] = {
				round(v[4], 4),
				round(v[5], 4),
				round(v[6], 4),
				round(q[1], 5),
				round(q[2], 5),
				round(q[3], 5),
				round(q[4], 5),
			}
		end
		table.insert(keyframes, { t = round(t, 4), poses = poses })
	end
	local clip = {
		name = name,
		fps = FPS,
		loop = true,
		upperBody = false,
		duration = spec.duration,
		groundSpeed = 0,
		keyframes = keyframes,
	}
	fs.writeFile(OUT .. "/" .. name .. ".json", serde.encode("json", clip))
	print(`{name}: {#keyframes} keyframes, {spec.duration} s`)
end
