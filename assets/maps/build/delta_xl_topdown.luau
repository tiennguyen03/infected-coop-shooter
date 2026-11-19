--!strict
-- The big map from above, drawn from the data the game builds from (Shared.DeltaXLLayout,
-- the delta_xl objective sites in Shared.ObjectiveDefinitions). Run from the repo root:
--   lune run assets/maps/build/delta_xl_topdown
-- Writes docs/sprints/images/delta_xl_topdown.svg (open it in any browser).

local fs = require("@lune/fs")

local Layout = require("../../../src/shared/DeltaXLLayout")
local Definitions = require("../../../src/shared/ObjectiveDefinitions")

local SCALE = 0.55
local MARGIN = 40
local H = Layout.Half
local SIZE = 2 * H * SCALE + 2 * MARGIN

local out: { string } = {}
local function add(text: string)
	table.insert(out, text)
end

local function sx(x: number): number
	return MARGIN + (x + H) * SCALE
end
local function sz(z: number): number
	return MARGIN + (H - z) * SCALE
end
local function fmt(n: number): string
	return string.format("%.1f", n)
end

local function rect(x0: number, z0: number, x1: number, z1: number, fill: string, extra: string?)
	add(
		`<rect x="{fmt(sx(math.min(x0, x1)))}" y="{fmt(sz(math.max(z0, z1)))}" width="{fmt(
			math.abs(x1 - x0) * SCALE
		)}" height="{fmt(math.abs(z1 - z0) * SCALE)}" fill="{fill}" {extra or ""}/>`
	)
end

local function text(x: number, z: number, label: string, size: number, color: string, anchor: string?)
	add(
		`<text x="{fmt(sx(x))}" y="{fmt(sz(z))}" font-family="Helvetica, Arial, sans-serif" font-size="{size}" fill="{color}" text-anchor="{anchor
			or "middle"}">{label}</text>`
	)
end

local LOOK: { [string]: string } = {
	concrete = "#8a8780",
	metal = "#7d8287",
	dark = "#45484c",
	rust = "#7a5440",
	wood = "#7a6448",
	canvas = "#8c866c",
	earth = "#6b5d47",
}

add(
	`<svg xmlns="http://www.w3.org/2000/svg" width="{fmt(SIZE)}" height="{fmt(SIZE + 70)}" viewBox="0 0 {fmt(
		SIZE
	)} {fmt(SIZE + 70)}">`
)
add(`<rect width="100%" height="100%" fill="#1d1f21"/>`)
-- Ground and the middle square.
rect(-H, -H, H, H, "#5e584c")
rect(-Layout.BaseHalf, -Layout.BaseHalf, Layout.BaseHalf, Layout.BaseHalf, "#6c6656")
-- The squares.
for _, area in Layout.Areas do
	rect(area.x0, area.z0, area.x1, area.z1, "none", `stroke="#3b3a35" stroke-width="1" stroke-dasharray="6 6"`)
end
-- The river and its crossings.
local river = Layout.River
rect(-H, river.z0, H, river.z1, "#3a4a49")
rect(river.ford.x0, river.z0, river.ford.x1, river.z1, "#7d6d55")
for _, boat in river.ramps do
	local z0 = if boat.bank == "south" then river.z0 + river.bank else river.z1 - river.bank - 10
	rect(boat.x0, z0, boat.x1, z0 + 10, "#8a8780")
end
-- Roads, rail.
for _, road in Layout.Roads do
	local color = if road.surface == "dirt" then "#7d6d55" else "#3a3c40"
	if road.z0 == road.z1 then
		rect(road.x0, road.z0 - road.width / 2, road.x1, road.z0 + road.width / 2, color)
	else
		rect(road.x0 - road.width / 2, road.z0, road.x0 + road.width / 2, road.z1, color)
	end
end
-- Today's base roads, for orientation.
rect(-38, -300, -22, 300, "#3a3c40")
rect(-300, 192, 300, 208, "#3a3c40")
rect(-300, -54, 300, -36, "#4a4c50")
local rail = Layout.Rail
rect(rail.x - rail.bed / 2, -H, rail.x + rail.bed / 2, H, "#59554e")
for _, siding in rail.sidings do
	rect(siding.x - rail.bed / 2, siding.z0, siding.x + rail.bed / 2, siding.z1, "#59554e")
end
for _, bridge in Layout.Bridges do
	rect(bridge.x0, bridge.z0, bridge.x1, bridge.z1, "#9a9790", `stroke="#d8d4c8" stroke-width="1"`)
end
local fly = Layout.Flyover
rect(fly.x0 - fly.ramp, fly.z - fly.width / 2, fly.x1 + fly.ramp, fly.z + fly.width / 2, "#55575c")
rect(fly.x0, fly.z - fly.width / 2, fly.x1, fly.z + fly.width / 2, "#9a9790", `stroke="#d8d4c8" stroke-width="1"`)
-- Blocks and houses.
for _, block in Layout.Blocks do
	local fill = LOOK[block.look or "concrete"] or "#8a8780"
	if block.landmark then
		fill = "#c9a25a"
	end
	if block.shape == "cylinder" then
		add(
			`<circle cx="{fmt(sx(block.x))}" cy="{fmt(sz(block.z))}" r="{fmt(block.w / 2 * SCALE)}" fill="{fill}" stroke="#222" stroke-width="0.5"/>`
		)
	else
		local w, d = block.w * SCALE, block.d * SCALE
		add(
			`<rect x="{fmt(sx(block.x) - w / 2)}" y="{fmt(sz(block.z) - d / 2)}" width="{fmt(w)}" height="{fmt(
				d
			)}" fill="{fill}" stroke="#222" stroke-width="0.4" transform="rotate({fmt(-(block.yaw or 0))} {fmt(
				sx(block.x)
			)} {fmt(sz(block.z))})"/>`
		)
	end
	if block.burning then
		add(`<circle cx="{fmt(sx(block.x))}" cy="{fmt(sz(block.z))}" r="6" fill="#e0602a" opacity="0.85"/>`)
	end
end
for _, house in Layout.Houses do
	rect(
		house.x - house.w / 2,
		house.z - house.d / 2,
		house.x + house.w / 2,
		house.z + house.d / 2,
		"#b3ada0",
		`stroke="#f2ecdc" stroke-width="1"`
	)
end
-- The base's fence and its gaps.
local B = Layout.BaseHalf
for along = -294, 294, 12 do
	for _, panel in { { along, B }, { along, -B }, { B, along }, { -B, along } } do
		if not Layout.inFenceGap(panel[1], panel[2]) then
			add(`<circle cx="{fmt(sx(panel[1]))}" cy="{fmt(sz(panel[2]))}" r="1.6" fill="#c8c8c0"/>`)
		end
	end
end
-- Story spots.
for _, spot in Layout.Spots do
	add(`<circle cx="{fmt(sx(spot.x))}" cy="{fmt(sz(spot.z))}" r="2.6" fill="#f0a830"/>`)
end
-- Objective sites (the big map's outer ones; the base keeps its own).
local outerColor = { secure_site = "#f2d16b", restore_comms = "#7ec4f0", confirm_casualties = "#e07070" }
for id, sites in Definitions.Maps.delta_xl.Sites do
	for _, site in sites do
		local x, z = site.Position[1], site.Position[3]
		local color = outerColor[id] or "#ffffff"
		add(
			`<rect x="{fmt(sx(x) - 4)}" y="{fmt(sz(z) - 4)}" width="8" height="8" fill="none" stroke="{color}" stroke-width="1.6" transform="rotate(45 {fmt(
				sx(x)
			)} {fmt(sz(z))})"/>`
		)
	end
end
-- Drops and pickups.
for index, drop in Layout.Drops do
	add(
		`<path d="M {fmt(sx(drop.x))} {fmt(sz(drop.z) - 10)} L {fmt(sx(drop.x) + 9)} {fmt(sz(drop.z) + 7)} L {fmt(
			sx(drop.x) - 9
		)} {fmt(sz(drop.z) + 7)} Z" fill="#4fd17a" stroke="#0d2a17" stroke-width="1"/>`
	)
	text(drop.x, drop.z - 30, `I{index}`, 12, "#4fd17a")
end
for index, pickup in Layout.Pickups do
	add(
		`<circle cx="{fmt(sx(pickup.x))}" cy="{fmt(sz(pickup.z))}" r="8" fill="none" stroke="#5fb8ff" stroke-width="2"/>`
	)
	text(pickup.x, pickup.z - 4, "H", 10, "#5fb8ff")
	text(pickup.x, pickup.z - 32, `X{index - 1}`, 12, "#5fb8ff")
end
-- Area names.
for _, area in Layout.Areas do
	local cx = (area.x0 + area.x1) / 2
	text(cx, area.z1 - 40, string.upper(area.name), 15, "#efe9da")
	text(cx, area.z1 - 72, area.landmark, 11, "#c9a25a")
end
text(-30, H - 14, "N ^  hills", 11, "#bbb")
text(-30, -H + 20, "v  the coast road to the city (skyline south only)", 11, "#bbb")
text(-H + 4, river.z1 + 14, "the river (12 deep): ford, highway bridge, rail bridge", 10, "#9fc0bd", "start")
-- Legend.
local ly = SIZE + 20
local legend = {
	{ "#4fd17a", "I1-I4 drops (a corner 900+ from the main objective)" },
	{ "#5fb8ff", "X0-X4 pickups (chosen when the main objective is done)" },
	{ "#c9a25a", "landmarks (always loaded)" },
	{ "#f2ecdc", "enterable houses" },
	{ "#f0a830", "story spots" },
}
for index, entry in legend do
	local x = MARGIN + ((index - 1) % 3) * 330
	local y = ly + math.floor((index - 1) / 3) * 22
	add(`<rect x="{x}" y="{y - 10}" width="12" height="12" fill="{entry[1]}"/>`)
	add(`<text x="{x + 18}" y="{y}" font-family="Helvetica, Arial, sans-serif" font-size="12" fill="#ddd">{entry[2]}</text>`)
end
add("</svg>")

fs.writeFile("docs/sprints/images/delta_xl_topdown.svg", table.concat(out, "\n"))
print("wrote docs/sprints/images/delta_xl_topdown.svg")
