--!strict
-- The Harlan Corridor as drawn on the Plot's paper map (canon: docs/lore/world_map.md, the
-- lore developer, 2026-11-10). Map units: a 10 x 7 grid, x 0-10 west to east, y 0-7 south to
-- north (the coast at the bottom, the dam at the top). WorldMap lays it on the chart table.
-- Printed things are the base sheet; `pencil` things are grease pencil drawn over it.

export type Region = {
	name: string,
	kind: string, -- "water" | "district" | "burn" | "forest"
	box: { number }, -- { x0, y0, x1, y1 }
	label: string,
	labelAt: { number }?, -- where the label sits when the centre is crowded
}

export type Line = {
	kind: string, -- "road" | "rail" | "river" | "dam" | "cordon" | "border" | "pencil"
	points: { number }, -- x1, y1, x2, y2, ...
	label: string?,
	labelAt: { number }?,
}

export type Point = { x: number, y: number, label: string, carrier: boolean?, labelAt: { number }? }

local WorldMapData = {}

WorldMapData.Regions = {
	{ name = "sea", kind = "water", box = { 0, 0, 10, 0.9 }, label = "OPEN WATER" },
	{ name = "delta", kind = "district", box = { 3.1, 0.9, 7.0, 2.2 }, label = "DELTA" },
	{ name = "mile14", kind = "district", box = { 3.1, 2.2, 7.1, 3.6 }, label = "MILE 14" },
	{ name = "kestrel", kind = "district", box = { 3.1, 3.6, 7.2, 4.9 }, label = "KESTREL" },
	{ name = "yard", kind = "district", box = { 3.2, 4.9, 7.2, 5.9 }, label = "THE YARD" },
	{
		name = "reservoir",
		kind = "district",
		box = { 3.4, 5.9, 7.2, 7.0 },
		label = "RESERVOIR",
		labelAt = { 4.6, 6.12 },
	},
	{ name = "lake", kind = "water", box = { 4.0, 6.3, 6.4, 7.0 }, label = "HARLAN RESERVOIR" },
	{ name = "brennan", kind = "burn", box = { 2.0, 0.9, 3.0, 1.8 }, label = "BRENNAN - BURNED" },
	{ name = "marlow", kind = "burn", box = { 7.4, 0.9, 8.8, 2.6 }, label = "MARLOW - BURNED" },
	{ name = "westburn", kind = "burn", box = { 1.8, 2.4, 3.0, 4.2 }, label = "BURNED" },
	{ name = "westforest", kind = "forest", box = { 0.3, 4.2, 3.0, 6.8 }, label = "STATE FOREST" },
	{ name = "ridge", kind = "forest", box = { 7.4, 3.4, 9.6, 6.8 }, label = "HIGH RIDGE" },
} :: { Region }

WorldMapData.Points = {
	{ x = 6.8, y = 0.4, label = "CARRIER", carrier = true },
	{ x = 5.2, y = 2.1, label = "THE GATE", labelAt = { 5.75, 2.05 } },
	{ x = 4.5, y = 4.2, label = "KESTREL HS" },
	{ x = 6.2, y = 5.5, label = "HARLAN" },
	{ x = 5.8, y = 6.1, label = "STATION", labelAt = { 6.55, 6.1 } },
	{ x = 7.8, y = 1.0, label = "PORT" },
} :: { Point }

WorldMapData.Lines = {
	{
		kind = "road",
		points = {
			5.0,
			0.9,
			5.1,
			1.6,
			5.2,
			2.2,
			5.4,
			2.9,
			5.1,
			3.8,
			4.8,
			4.4,
			5.2,
			5.0,
			5.6,
			5.6,
			5.4,
			6.1,
		},
		label = "ROUTE 9",
		labelAt = { 5.85, 4.8 },
	},
	{
		kind = "road",
		points = { 1.0, 3.1, 3.0, 3.0, 5.4, 2.9, 7.5, 3.1, 9.8, 3.4 },
		label = "CO RD 40",
		labelAt = { 8.6, 3.0 },
	},
	{
		kind = "road",
		points = { 0.5, 1.2, 2.9, 1.3, 5.0, 1.0, 7.8, 1.2, 9.5, 1.4 },
		label = "COAST RD",
		labelAt = { 1.4, 1.02 },
	},
	{
		kind = "rail",
		points = { 5.6, 6.1, 6.2, 5.4, 6.8, 4.4, 6.9, 3.0, 7.3, 1.8, 7.8, 1.0 },
		label = "RAIL",
		labelAt = { 7.35, 2.45 },
	},
	{
		kind = "river",
		points = { 4.9, 6.3, 4.3, 5.4, 3.7, 4.4, 3.8, 3.2, 4.0, 2.0, 3.9, 0.9 },
		label = "HARLAN RIVER",
		labelAt = { 4.25, 5.15 },
	},
	{ kind = "dam", points = { 4.6, 6.3, 5.4, 6.3 }, label = "DAM", labelAt = { 5.0, 6.48 } },
	{
		kind = "cordon",
		points = { 3.1, 0.9, 3.1, 3.6, 3.2, 5.0, 3.6, 7.0 },
		label = "QUARANTINE LINE",
		labelAt = { 2.3, 4.45 },
	},
	{ kind = "cordon", points = { 7.0, 0.9, 7.1, 3.5, 7.2, 4.9, 7.2, 7.0 } },
	{ kind = "border", points = { 3.1, 2.2, 7.0, 2.2 } },
	{ kind = "border", points = { 3.1, 3.6, 7.1, 3.6 } },
	{ kind = "border", points = { 3.2, 4.9, 7.2, 4.9 } },
	{ kind = "border", points = { 3.4, 5.9, 7.2, 5.9 } },
	{
		kind = "pencil",
		points = { 6.8, 0.4, 5.6, 1.2, 5.1, 1.6 },
		label = "HELO",
		labelAt = { 6.05, 0.72 },
	},
} :: { Line }

WorldMapData.Title = "HARLAN CORRIDOR"
WorldMapData.Subtitle = "QUARANTINE AREA - SHEET 1"
WorldMapData.Legend = { "ROAD", "RAIL", "RIVER", "QUARANTINE LINE", "DISTRICT BORDER", "BURNED" }
WorldMapData.Stamp = "HARLAN CONTROL - PLOT COPY - DO NOT REMOVE"
WorldMapData.Margin = "CONTAINED IS NOT CLEAN"

return WorldMapData
