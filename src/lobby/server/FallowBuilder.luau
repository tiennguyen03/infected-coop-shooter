--!strict
-- Builds the Fallow (docs/LORE.md > The Fallow): a reactivated helicopter carrier holding
-- station off the Harlan coast on a clear afternoon. Hull, flight deck with the open well and
-- its ramp, the island (hull number painted out, HRD sprayed over it), the hangar deck, the
-- Plot's walls and chart table, the screening lane where soldiers arrive, the sea, the coast
-- with the Burn's smoke along it, and the sky (Config.Lobby.Sky). Desks (DeskService), the
-- board (PlotService) and the birds on their spots (LaunchService) build their own pieces
-- from FallowLayout. Blocks only: the art director's build sheet replaces them later.
-- docs/STYLES.md: ShadowMap with GlobalShadows (lobby.project.json sets Technology), only
-- large pieces cast shadows, four lights (three in the hangar, one in the Plot), Shadows off,
-- Range <= 56. No two faces share a plane (they flicker): surface pieces sit on, not in.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local FallowBuilder = {}

local HULL = Color3.fromRGB(70, 74, 78)
local DECK = Color3.fromRGB(50, 52, 55)
local ISLAND = Color3.fromRGB(86, 90, 94)
local HANGAR_FLOOR = Color3.fromRGB(64, 66, 68)
local HANGAR_WALL = Color3.fromRGB(96, 100, 102)
local PLOT_WALL = Color3.fromRGB(40, 40, 42)
local PAINT = Color3.fromRGB(214, 214, 208)
local YELLOW = Color3.fromRGB(230, 189, 96)
local CONCRETE = Color3.fromRGB(122, 120, 114)
local LAND = Color3.fromRGB(78, 84, 70)
local SMOKE = Color3.fromRGB(64, 62, 60)
local BURN = Color3.fromRGB(255, 110, 30)
local FLOOD = Color3.fromRGB(255, 226, 190)
local LAMP_HOUSING = Color3.fromRGB(200, 198, 186)
local PLOT_RED = Color3.fromRGB(255, 60, 50)

local BOW = 30 -- the flight deck runs this far past the hull's square end, over a raked bow
local FLOOR = 0.2 -- the hangar floor plate's thickness, on top of the hull block

local W = Layout.HalfWidth
local L = Layout.HalfLength
local DECK_Y = Layout.DeckY
local DECK_BOTTOM = DECK_Y - Layout.DeckThickness
local HANGAR_Y = Layout.HangarY
local HULL_TOP = HANGAR_Y - FLOOR

local function pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

local function clearTemplate()
	-- A new place starts with a Baseplate and a SpawnLocation; the ship replaces both.
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
			child:Destroy()
		end
	end
end

local function buildHull(ship: Folder)
	-- Below the hangar floor, and the closed spaces fore and aft of the hangar.
	-- The hull block stops a floor plate below the hangar surface; the plate (HangarFloor)
	-- and everything standing on the hangar deck start at HULL_TOP, so no face is shared.
	Build.box(ship, "Hull", Vector3.new(-W, -10, -L), Vector3.new(W, HULL_TOP, L), HULL)
	Build.box(
		ship,
		"AftSpaces",
		Vector3.new(-W, HULL_TOP, -L),
		Vector3.new(W, DECK_BOTTOM, Layout.HangarAft),
		HULL
	)
	Build.box(
		ship,
		"ForeSpaces",
		Vector3.new(-W, HULL_TOP, Layout.HangarFore),
		Vector3.new(W, DECK_BOTTOM, L),
		HULL
	)

	-- The raked bow under the deck overhang.
	local bow = Build.part(
		ship,
		"Bow",
		Vector3.new(W * 2 - 0.4, DECK_BOTTOM + 10, BOW),
		CFrame.new(0, (DECK_BOTTOM - 10) / 2, L + BOW / 2) * CFrame.Angles(math.pi, 0, 0),
		HULL,
		{ wedge = true }
	)
	bow.Name = "Bow"

	-- Hangar sides: starboard solid, port open to the sea between Z -40 and 0 (a side lift).
	Build.box(
		ship,
		"HangarStarboard",
		Vector3.new(W - 2, HULL_TOP, Layout.HangarAft),
		Vector3.new(W, DECK_BOTTOM, Layout.HangarFore),
		HANGAR_WALL
	)
	Build.box(
		ship,
		"HangarPortAft",
		Vector3.new(-W, HULL_TOP, Layout.HangarAft),
		Vector3.new(-W + 2, DECK_BOTTOM, -40),
		HANGAR_WALL
	)
	Build.box(
		ship,
		"HangarPortFore",
		Vector3.new(-W, HULL_TOP, 0),
		Vector3.new(-W + 2, DECK_BOTTOM, Layout.HangarFore),
		HANGAR_WALL
	)
	Build.barrier(ship, Vector3.new(-W - 1, HANGAR_Y, -40), Vector3.new(-W + 1, DECK_BOTTOM, 0))
	Build.box(
		ship,
		"SideLiftEdge",
		Vector3.new(-W, HULL_TOP, -40),
		Vector3.new(-W + 2, HANGAR_Y, 0),
		YELLOW,
		{
			material = Enum.Material.SmoothPlastic,
		}
	)
	-- The hangar floor plate on the hull block.
	Build.box(
		ship,
		"HangarFloor",
		Vector3.new(-W + 2, HULL_TOP, Layout.HangarAft),
		Vector3.new(W - 2, HANGAR_Y, Layout.HangarFore),
		HANGAR_FLOOR,
		{ material = Enum.Material.DiamondPlate }
	)
end

local function buildDeck(ship: Folder)
	local well = Layout.Well
	local function slab(name: string, x0: number, x1: number, z0: number, z1: number)
		Build.box(
			ship,
			name,
			Vector3.new(x0, DECK_BOTTOM, z0),
			Vector3.new(x1, DECK_Y, z1),
			DECK,
			{ material = Enum.Material.Asphalt }
		)
	end
	-- Four slabs around the open well.
	slab("DeckAft", -W, W, -L, well.z0)
	slab("DeckWellPort", -W, well.x0, well.z0, well.z1)
	slab("DeckWellStarboard", well.x1, W, well.z0, well.z1)
	slab("DeckFore", -W, W, well.z1, L + BOW)

	-- The ramp from the hangar floor (foot at well.z1) up aft to the deck (well.z0), with
	-- rails. A WedgePart rises toward +Z, so it is turned half round.
	local rise = DECK_Y - HANGAR_Y
	local run = well.z1 - well.z0
	Build.part(
		ship,
		"Ramp",
		Vector3.new(well.x1 - well.x0, rise, run),
		CFrame.new((well.x0 + well.x1) / 2, HANGAR_Y + rise / 2, (well.z0 + well.z1) / 2)
			* CFrame.Angles(0, math.pi, 0),
		HANGAR_FLOOR,
		{ wedge = true, material = Enum.Material.DiamondPlate }
	)
	local slope = math.atan2(rise, run)
	local railLength = math.sqrt(rise * rise + run * run)
	for _, x in { well.x0 + 0.3, well.x1 - 0.3 } do
		Build.part(
			ship,
			"RampRail",
			Vector3.new(0.4, 3, railLength),
			CFrame.new(x, HANGAR_Y + rise / 2 + 1.5, (well.z0 + well.z1) / 2)
				* CFrame.Angles(slope, 0, 0),
			YELLOW,
			{ material = Enum.Material.SmoothPlastic }
		)
	end
	-- The well's open edges on the deck: the fore edge drops to the ramp's foot.
	Build.box(
		ship,
		"WellRail",
		Vector3.new(well.x0, DECK_Y, well.z1),
		Vector3.new(well.x1, DECK_Y + 3, well.z1 + 0.4),
		YELLOW,
		{ material = Enum.Material.SmoothPlastic }
	)
	for _, x in { well.x0, well.x1 } do
		Build.box(
			ship,
			"WellRail",
			Vector3.new(x - 0.2, DECK_Y, well.z0),
			Vector3.new(x + 0.2, DECK_Y + 3, well.z1),
			YELLOW,
			{ material = Enum.Material.SmoothPlastic }
		)
	end

	-- Markings: the centre line down the spots (broken where a spot circle is painted, so
	-- two coats never share a plane), and the deck-edge safety rail.
	local lineX = Layout.Spots[1].helo.X
	for z = -L + 6, well.z0 - 6, 12 do
		local onSpot = false
		for _, spot in Layout.Spots do
			if z + 6 > spot.helo.Z - 15 and z < spot.helo.Z + 15 then
				onSpot = true
			end
		end
		if onSpot then
			continue
		end
		Build.box(
			ship,
			"CentreLine",
			Vector3.new(lineX - 0.3, DECK_Y, z),
			Vector3.new(lineX + 0.3, DECK_Y + 0.05, z + 6),
			PAINT,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
	for _, x in { -W + 0.2, W - 0.2 } do
		Build.part(
			ship,
			"EdgeRail",
			Vector3.new(0.3, 1.2, L * 2 + BOW),
			CFrame.new(x, DECK_Y + 0.6, BOW / 2),
			Color3.fromRGB(150, 150, 150),
			{ collide = false }
		)
	end
	-- Invisible walls keep soldiers aboard.
	local top = DECK_Y + 14
	Build.barrier(ship, Vector3.new(-W - 1, DECK_Y, -L - 1), Vector3.new(-W, top, L + BOW + 1))
	Build.barrier(ship, Vector3.new(W, DECK_Y, -L - 1), Vector3.new(W + 1, top, L + BOW + 1))
	Build.barrier(ship, Vector3.new(-W, DECK_Y, -L - 1), Vector3.new(W, top, -L))
	Build.barrier(ship, Vector3.new(-W, DECK_Y, L + BOW), Vector3.new(W, top, L + BOW + 1))

	-- Floodlight poles along the port edge, over the aft spots (unlit by day; a night cycle
	-- lights them later).
	for _, z in { -125, -25 } do
		Build.box(
			ship,
			"FloodPole",
			Vector3.new(-W + 0.5, DECK_Y, z - 0.5),
			Vector3.new(-W + 1.5, DECK_Y + 12, z + 0.5),
			HULL
		)
		Build.part(
			ship,
			"FloodLamp",
			Vector3.new(1.4, 1, 1.4),
			CFrame.new(-W + 1, DECK_Y + 12.5, z) * CFrame.Angles(0, 0, math.rad(-35)),
			LAMP_HOUSING,
			{ collide = false }
		)
	end
end

local function buildIsland(ship: Folder)
	local island = Layout.Island
	local block = Build.box(
		ship,
		"Island",
		Vector3.new(island.x0, DECK_Y, island.z0),
		Vector3.new(island.x1, island.top, island.z1),
		ISLAND
	)
	block.Name = "Island"
	local midZ = (island.z0 + island.z1) / 2
	local length = island.z1 - island.z0
	-- Bridge windows.
	Build.part(
		ship,
		"BridgeWindows",
		Vector3.new(0.2, 4, length - 4),
		CFrame.new(island.x0 - 0.1, island.top - 7, midZ),
		Color3.fromRGB(20, 26, 30),
		{ material = Enum.Material.Glass, transparency = 0.1 }
	)
	-- The old hull number painted out, HRD sprayed over the patch.
	local patch = Build.part(
		ship,
		"PaintedOut",
		Vector3.new(0.2, 12, 28),
		CFrame.new(island.x0 - 0.12, DECK_Y + 17, midZ),
		Color3.fromRGB(78, 82, 86)
	)
	Build.text(
		patch,
		Enum.NormalId.Left,
		"HRD",
		{ size = 220, color = Color3.fromRGB(226, 224, 216), font = Enum.Font.PermanentMarker }
	)
	-- A door at deck level.
	Build.part(
		ship,
		"IslandDoor",
		Vector3.new(0.2, 7, 4),
		CFrame.new(island.x0 - 0.1, DECK_Y + 3.5, island.z0 + 6),
		Color3.fromRGB(44, 46, 48)
	)
	-- Mast and yard.
	Build.part(
		ship,
		"Mast",
		Vector3.new(1.5, 22, 1.5),
		CFrame.new((island.x0 + island.x1) / 2, island.top + 11, midZ),
		HULL
	)
	Build.part(
		ship,
		"Yard",
		Vector3.new(10, 0.6, 0.6),
		CFrame.new((island.x0 + island.x1) / 2, island.top + 16, midZ),
		HULL
	)
	-- Three floodlights on the island face, over the forward spots (unlit by day).
	for _, z in { island.z0 + 6, midZ, island.z1 - 6 } do
		Build.part(
			ship,
			"FloodLamp",
			Vector3.new(1, 1.4, 1.4),
			CFrame.new(island.x0 - 0.7, island.top - 2, z) * CFrame.Angles(0, 0, math.rad(35)),
			LAMP_HOUSING,
			{ collide = false }
		)
	end
end

local function buildHangar(ship: Folder)
	-- Three working lights under the deck: over the desks by the spawn, at the ramp's foot,
	-- and at the Plot door.
	for _, position in
		{
			Vector3.new(0, DECK_BOTTOM - 1, 106),
			Vector3.new(-8, DECK_BOTTOM - 1, 62),
			Vector3.new(0, DECK_BOTTOM - 1, 10),
		}
	do
		local fixture = Build.part(
			ship,
			"HangarLight",
			Vector3.new(4, 0.6, 1.2),
			CFrame.new(position),
			FLOOD,
			{ material = Enum.Material.Neon, collide = false }
		)
		pointLight(fixture, FLOOD, 50, 1.2)
	end
	-- Hangar bay stencils on the bulkheads.
	local aft = Build.box(
		ship,
		"BayStencil",
		Vector3.new(-12, HANGAR_Y + 8, Layout.HangarAft),
		Vector3.new(12, HANGAR_Y + 14, Layout.HangarAft + 0.1),
		HANGAR_WALL,
		{ collide = false }
	)
	Build.text(aft, Enum.NormalId.Back, "HANGAR BAY 1", { size = 90, color = YELLOW })
end

local function buildPlot(ship: Folder)
	local plot = Layout.Plot
	local top = DECK_BOTTOM
	local x0, x1 = plot.x0, plot.x0 + 1
	Build.box(
		ship,
		"PlotWall",
		Vector3.new(x0, HANGAR_Y, plot.z0),
		Vector3.new(x1, top, plot.doorZ0),
		PLOT_WALL
	)
	Build.box(
		ship,
		"PlotWall",
		Vector3.new(x0, HANGAR_Y, plot.doorZ1),
		Vector3.new(x1, top, plot.z1),
		PLOT_WALL
	)
	local lintel = Build.box(
		ship,
		"PlotLintel",
		Vector3.new(x0, HANGAR_Y + 10, plot.doorZ0),
		Vector3.new(x1, top, plot.doorZ1),
		PLOT_WALL
	)
	Build.text(lintel, Enum.NormalId.Left, "THE PLOT", { size = 70, color = PAINT })
	Build.box(
		ship,
		"PlotWall",
		Vector3.new(x1, HANGAR_Y, plot.z0),
		Vector3.new(plot.x1, top, plot.z0 + 1),
		PLOT_WALL
	)
	Build.box(
		ship,
		"PlotWall",
		Vector3.new(x1, HANGAR_Y, plot.z1 - 1),
		Vector3.new(plot.x1, top, plot.z1),
		PLOT_WALL
	)

	-- The chart table: the corridor under tape and grease pencil.
	local base = Layout.ChartTable
	local tableTop = Build.part(
		ship,
		"ChartTable",
		Vector3.new(8, 0.6, 14),
		base * CFrame.new(0, 3.3, 0),
		Color3.fromRGB(196, 184, 150),
		{ material = Enum.Material.SmoothPlastic }
	)
	Build.text(
		tableTop,
		Enum.NormalId.Top,
		"HARLAN CORRIDOR\n\nRESERVOIR\n|\nTHE YARD\n|\nKESTREL\n|\nMILE 14\n|\nDELTA\n\ncoast",
		{ size = 34, color = Color3.fromRGB(70, 50, 40), font = Enum.Font.PermanentMarker }
	)
	for _, corner in
		{
			Vector3.new(-3.5, 0, -6.5),
			Vector3.new(3.5, 0, -6.5),
			Vector3.new(-3.5, 0, 6.5),
			Vector3.new(3.5, 0, 6.5),
		}
	do
		Build.part(
			ship,
			"TableLeg",
			Vector3.new(0.5, 3, 0.5),
			base * CFrame.new(corner + Vector3.new(0, 1.5, 0)),
			HULL
		)
	end
	-- One red working light.
	local lamp = Build.part(
		ship,
		"PlotLamp",
		Vector3.new(2, 0.4, 2),
		CFrame.new((plot.x0 + plot.x1) / 2, top - 0.5, (plot.z0 + plot.z1) / 2),
		PLOT_RED,
		{ material = Enum.Material.Neon, collide = false }
	)
	pointLight(lamp, PLOT_RED, 30, 2)
end

local function buildLane(ship: Folder)
	local lane = Layout.Lane
	for _, x in { lane.x0, lane.x1 } do
		Build.box(
			ship,
			"LaneBarrier",
			Vector3.new(x - 0.6, DECK_Y, lane.z0),
			Vector3.new(x + 0.6, DECK_Y + 2.5, lane.z1),
			CONCRETE,
			{ material = Enum.Material.Concrete }
		)
	end
	-- The screening arch halfway down the lane: hose, hands, eyes, band.
	local archZ = (lane.z0 + lane.z1) / 2
	for _, x in { lane.x0 + 1, lane.x1 - 1 } do
		Build.part(
			ship,
			"ArchPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(x, DECK_Y + 4.5, archZ),
			HULL
		)
	end
	local beam = Build.part(
		ship,
		"ArchSign",
		Vector3.new(lane.x1 - lane.x0, 2, 0.4),
		CFrame.new((lane.x0 + lane.x1) / 2, DECK_Y + 9, archZ),
		Color3.fromRGB(40, 42, 44)
	)
	Build.text(beam, Enum.NormalId.Front, "SCREENING", { size = 80, color = YELLOW })
	Build.part(
		ship,
		"HoseReel",
		Vector3.new(1.4, 2.4, 2.4),
		CFrame.new(lane.x0 + 1.6, DECK_Y + 1.2, archZ - 3),
		Color3.fromRGB(150, 40, 36),
		{ shape = Enum.PartType.Cylinder }
	)
end

-- Where soldiers spawn: the fore end of the hangar, facing the desks and the ramp.
local function buildSpawn(ship: Folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HangarSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = Layout.Spawn
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = ship
end

local function buildWorld(ship: Folder)
	local sky = Config.Lobby.Sky
	Build.part(ship, "Sea", Vector3.new(2048, 1, 2048), CFrame.new(0, -0.5, 400), sky.Sea, {
		material = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	-- The coast to the north, and the Burn's smoke standing over it: a low fire line at the
	-- foot of each column (the orange shows at night once there is a night).
	Build.part(
		ship,
		"Coast",
		Vector3.new(2048, 24, 120),
		CFrame.new(0, 10, Layout.CoastZ),
		LAND,
		{ material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
	)
	for index, x in { -700, -380, -120, 260, 610 } do
		local base = Vector3.new(x, 22, Layout.CoastZ - 40)
		Build.part(ship, "Burn", Vector3.new(60 + index * 10, 4, 24), CFrame.new(base), BURN, {
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
		-- Three puffs per column, each higher, wider and fainter.
		for step = 1, 3 do
			local width = 30 + step * 24 + index * 4
			Build.part(
				ship,
				"Smoke",
				Vector3.new(width, width, width),
				CFrame.new(base + Vector3.new(step * 18, step * 46, 0)),
				SMOKE,
				{
					shape = Enum.PartType.Ball,
					material = Enum.Material.SmoothPlastic,
					transparency = 0.2 + step * 0.15,
					collide = false,
					shadow = false,
				}
			)
		end
	end

	-- A clear afternoon (Config.Lobby.Sky). Templates arrive with their own effects; the
	-- Fallow's sky replaces them so the place looks the same however it was created.
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("Sky")
			or child:IsA("PostEffect")
			or child:IsA("Clouds")
		then
			child:Destroy()
		end
	end
	Lighting.ClockTime = sky.ClockTime
	Lighting.GeographicLatitude = sky.GeographicLatitude
	Lighting.Brightness = sky.Brightness
	Lighting.Ambient = sky.Ambient
	Lighting.OutdoorAmbient = sky.OutdoorAmbient
	Lighting.ColorShift_Top = sky.ColorShiftTop
	Lighting.ExposureCompensation = sky.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = sky.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = sky.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = sky.EnvironmentSpecularScale
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = sky.Atmosphere.Density
	atmosphere.Offset = sky.Atmosphere.Offset
	atmosphere.Color = sky.Atmosphere.Color
	atmosphere.Decay = sky.Atmosphere.Decay
	atmosphere.Glare = sky.Atmosphere.Glare
	atmosphere.Haze = sky.Atmosphere.Haze
	atmosphere.Parent = Lighting
	-- Engine clouds live under Terrain.
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = sky.Clouds.Cover
	clouds.Density = sky.Clouds.Density
	clouds.Parent = Workspace.Terrain
end

function FallowBuilder.init()
	clearTemplate()
	local ship = Build.folder(Workspace, "Fallow")
	buildHull(ship)
	buildDeck(ship)
	buildIsland(ship)
	buildHangar(ship)
	buildPlot(ship)
	buildLane(ship)
	buildSpawn(ship)
	buildWorld(ship)
end

return FallowBuilder
