--!strict
-- The Plot's paper map (owner, 2026-11-10: "change the desk in there to a paper map and
-- actually create the world map"): the Harlan Corridor from WorldMapData (canon:
-- docs/lore/world_map.md) laid on a chart table as thin flat parts and printed labels. The
-- base sheet is printed (districts, water, forest, roads, rail, river, labels); the cordon,
-- the district borders, the burned towns and Lantern's track are grease pencil over it.
-- North points away from someone standing on the table's west side (the Plot door side),
-- so the map reads the right way up as you walk in. Static: built once, nothing moves.
-- The client's map view (DeskDialogUI, the watch officer's "Show me the map.") looks down
-- on the part named "WorldMapSheet".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)
local WorldMapData = require(script.Parent.WorldMapData)

local WorldMap = {}

local MAP = Config.Lobby.WorldMap
local S = MAP.StudsPerUnit -- studs per map unit
local MAP_W, MAP_H = 10, 7 -- map units, west-east and south-north

local PAPER = Color3.fromRGB(226, 218, 196)
local INK = Color3.fromRGB(58, 52, 46)
local PENCIL_RED = Color3.fromRGB(184, 38, 28)
local PENCIL = Color3.fromRGB(60, 60, 70)

local FILL: { [string]: Color3 } = {
	water = Color3.fromRGB(160, 182, 192),
	district = Color3.fromRGB(212, 202, 172),
	burn = Color3.fromRGB(96, 74, 64),
	forest = Color3.fromRGB(150, 164, 126),
}

-- Width, colour and dash (studs on, studs off; nil = solid) per line kind.
local STROKE: { [string]: { width: number, color: Color3, dash: { number }? } } = {
	road = { width = 0.14, color = Color3.fromRGB(96, 88, 78) },
	rail = { width = 0.09, color = Color3.fromRGB(34, 34, 34), dash = { 0.35, 0.2 } },
	river = { width = 0.2, color = Color3.fromRGB(84, 124, 156) },
	dam = { width = 0.34, color = Color3.fromRGB(70, 70, 70) },
	cordon = { width = 0.16, color = PENCIL_RED },
	border = { width = 0.07, color = Color3.fromRGB(110, 98, 86), dash = { 0.4, 0.25 } },
	pencil = { width = 0.08, color = PENCIL, dash = { 0.3, 0.2 } },
}

local sheet: BasePart
local folder: Folder

-- A map point (x east, y north) on the sheet's top, raised by `lift`.
local function at(x: number, y: number, lift: number): Vector3
	local top = sheet.CFrame * CFrame.new(0, sheet.Size.Y / 2, 0)
	-- Map north runs along the table's +X, map east along its +Z.
	return (top * CFrame.new((y - MAP_H / 2) * S, lift, (x - MAP_W / 2) * S)).Position
end

local function flat(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local part = Build.part(folder, name, size, cframe, color, {
		material = material or Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	part.CanQuery = false
	part.CanTouch = false
	return part :: any -- Build.part makes a Part
end

-- A label lying on the map, reading from the table's west side (its top toward map north).
local function label(
	text: string,
	x: number,
	y: number,
	height: number,
	color: Color3,
	pencil: boolean?
)
	local width = math.max(#text * height * 0.62, height)
	local centre = at(x, y, 0.09)
	-- Lying flat; the label's +Z (text top) points to map north (+X world).
	local cframe = CFrame.lookAt(centre, centre + Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
	local part = flat("MapLabel", Vector3.new(width, height, 0.02), cframe, PAPER)
	part.Transparency = 1
	Build.text(part, Enum.NormalId.Front, text, {
		color = color,
		font = if pencil then Enum.Font.PermanentMarker else Enum.Font.GothamBold,
		size = 100,
		pixelsPerStud = 60,
	})
end

local function region(r: WorldMapData.Region)
	local x0, y0, x1, y1 = r.box[1], r.box[2], r.box[3], r.box[4]
	local centre = at(
		(x0 + x1) / 2,
		(y0 + y1) / 2,
		0.02 + (if r.kind == "water" and r.name ~= "sea" then 0.02 else 0)
	)
	flat(
		"MapRegion",
		Vector3.new((y1 - y0) * S, 0.02, (x1 - x0) * S),
		CFrame.new(centre) * sheet.CFrame.Rotation,
		FILL[r.kind] or PAPER
	)
	local pencil = r.kind == "burn"
	-- Water names sit along the top of their box, districts a little above centre; a crowded
	-- one gives its own spot (labelAt).
	local ly = if r.kind == "water" and r.name ~= "sea"
		then y1 - 0.13
		elseif r.kind == "district" then (y0 + y1) / 2 + 0.12
		else (y0 + y1) / 2
	local spot = r.labelAt
	label(
		r.label,
		if spot then spot[1] else (x0 + x1) / 2,
		if spot then spot[2] else ly,
		if r.name == "reservoir"
			then 0.32
			elseif r.kind == "district" then 0.42
			elseif r.kind == "water" and r.name ~= "sea" then 0.2
			else 0.26,
		if pencil then PENCIL_RED elseif r.kind == "water" then Color3.fromRGB(56, 84, 110) else INK,
		pencil
	)
end

local function segment(a: Vector3, b: Vector3, width: number, color: Color3)
	local length = (b - a).Magnitude
	if length < 0.01 then
		return
	end
	flat("MapStroke", Vector3.new(width, 0.02, length), CFrame.lookAt((a + b) / 2, b), color)
end

local function line(l: WorldMapData.Line, lift: number)
	local stroke = STROKE[l.kind]
	if not stroke then
		return
	end
	local p = l.points
	for i = 1, #p - 2, 2 do
		local a, b = at(p[i], p[i + 1], lift), at(p[i + 2], p[i + 3], lift)
		local dash = stroke.dash
		if dash then
			local length = (b - a).Magnitude
			local dir = (b - a).Unit
			local d = 0
			while d < length do
				local e = math.min(d + dash[1], length)
				segment(a + dir * d, a + dir * e, stroke.width, stroke.color)
				d = e + dash[2]
			end
		else
			segment(a, b, stroke.width, stroke.color)
		end
	end
	local text = l.label
	if text then
		-- The label beside the line's middle point.
		local mid = math.floor(#p / 4) * 2 + 1
		local spot = l.labelAt
		label(
			text,
			if spot then spot[1] else p[mid] + 0.15,
			if spot then spot[2] else p[mid + 1] + 0.12,
			0.2,
			if l.kind == "cordon" then PENCIL_RED else stroke.color,
			l.kind == "cordon" or l.kind == "pencil"
		)
	end
end

local function point(pt: WorldMapData.Point)
	local centre = at(pt.x, pt.y, 0.08)
	if pt.carrier then
		-- The ship, as a pencilled hull shape off the coast.
		flat(
			"MapCarrier",
			Vector3.new(0.3, 0.03, 0.9),
			CFrame.new(centre) * sheet.CFrame.Rotation,
			PENCIL
		)
	else
		local dot: Part = flat(
			"MapDot",
			Vector3.new(0.03, 0.22, 0.22),
			CFrame.new(centre) * sheet.CFrame.Rotation * CFrame.Angles(0, 0, math.pi / 2),
			INK
		)
		dot.Shape = Enum.PartType.Cylinder
	end
	label(
		pt.label,
		if pt.labelAt then pt.labelAt[1] elseif pt.carrier then pt.x + 0.55 else pt.x + 0.35,
		if pt.labelAt then pt.labelAt[2] elseif pt.carrier then pt.y + 0.18 else pt.y - 0.18,
		0.22,
		if pt.carrier then PENCIL else INK,
		pt.carrier
	)
end

function WorldMap.build(parent: Instance)
	folder = Build.folder(parent, "WorldMap")
	local base = Layout.ChartTable
	local length, width = MAP_W * S, MAP_H * S
	local height = MAP.TableHeight
	-- The table: a dark wood top on four legs, the sheet over it with a margin.
	flat(
		"MapTable",
		Vector3.new(width + 1.6, 0.5, length + 1.6),
		base * CFrame.new(0, height - 0.25, 0),
		Color3.fromRGB(58, 44, 34),
		Enum.Material.Wood
	).CanCollide =
		true
	for _, corner in
		{
			Vector3.new(-width / 2, 0, -length / 2),
			Vector3.new(width / 2, 0, -length / 2),
			Vector3.new(-width / 2, 0, length / 2),
			Vector3.new(width / 2, 0, length / 2),
		}
	do
		flat(
			"MapTableLeg",
			Vector3.new(0.5, height - 0.5, 0.5),
			base * CFrame.new(corner + Vector3.new(0, (height - 0.5) / 2, 0)),
			Color3.fromRGB(46, 36, 28),
			Enum.Material.Wood
		)
	end
	sheet = flat(
		"WorldMapSheet",
		Vector3.new(width + 0.6, 0.04, length + 0.6),
		base * CFrame.new(0, height + 0.02, 0),
		PAPER,
		Enum.Material.SmoothPlastic
	)
	sheet.CanQuery = true -- the map view finds it

	for _, r in WorldMapData.Regions do
		region(r)
	end
	for _, l in WorldMapData.Lines do
		line(l, if l.kind == "cordon" or l.kind == "pencil" then 0.07 else 0.05)
	end
	for _, pt in WorldMapData.Points do
		point(pt)
	end

	-- Title, sheet line, legend, stamp and the margin note.
	label(WorldMapData.Title, 1.7, 6.55, 0.55, INK)
	label(WorldMapData.Subtitle, 1.7, 6.05, 0.22, INK)
	label("N", 9.75, 6.72, 0.4, INK)
	segment(at(9.75, 6.0, 0.05), at(9.75, 6.45, 0.05), 0.08, INK)
	for i, text in WorldMapData.Legend do
		label(text, 9.15, 0.75 + i * 0.3, 0.15, INK)
	end
	label(WorldMapData.Stamp, 1.9, 0.45, 0.22, PENCIL_RED)
	label(WorldMapData.Margin, 8.45, 6.2, 0.24, PENCIL, true)
	-- Masking tape at the sheet's corners.
	for _, corner in { { 0, 0 }, { MAP_W, 0 }, { 0, MAP_H }, { MAP_W, MAP_H } } do
		flat(
			"MapTape",
			Vector3.new(0.5, 0.03, 0.9),
			CFrame.new(at(corner[1], corner[2], 0.06))
				* sheet.CFrame.Rotation
				* CFrame.Angles(0, math.rad(35), 0),
			Color3.fromRGB(214, 200, 150)
		)
	end
end

return WorldMap
