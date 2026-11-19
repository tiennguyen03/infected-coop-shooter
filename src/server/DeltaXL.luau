--!strict
-- Checkpoint Delta XL, the grey test map (docs/sprints/DELTA_XL.md; Config.DeltaXL; layout
-- Shared.DeltaXLLayout). Today's Delta stays in the middle; this builds the eight areas
-- round it out of plain grey Parts (no uploads), opens the base's fence, moves the skyline
-- to the south, and owns the run's two big-map points:
--
--   the drop     a corner far from the main objective (Rules/DropPickup), chosen when the
--                objectives are drawn (ObjectiveService.prepare, as the run starts): the
--                squad's pads and the insertion cutscene follow Attributes.DropPoint
--   the pickup   chosen only when the main objective is done (ObjectiveService.finishMain):
--                ExtractionService lands the helicopter at Attributes.PickupPoint
--
-- Streaming: the ground, roads, river, bridges, flyover, edge walls and every landmark live
-- in the Persistent model workspace.DeltaXL (always loaded on every client); houses, vehicles,
-- tents and the rest are in workspace.DeltaXLBlocks and stream in and out by distance.
--
-- On at boot with Config.DeltaXL.Enabled, or for the rest of a session with `apply` (the dev
-- panel). It cannot be switched off without a restart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local DropPickup = require(ReplicatedStorage.Shared.Rules.DropPickup)
local Layout = require(ReplicatedStorage.Shared.DeltaXLLayout)
local ArenaService = require(script.Parent.ArenaService)
local Lifecycle = require(script.Parent.Lifecycle)
local Missions = require(script.Parent.Missions)
local MissionTypes = require(script.Parent.Missions.MissionTypes)
local SkyService = require(script.Parent.SkyService)
local Squad = require(script.Parent.Squad)

local DeltaXL = {}

type Look = { Material: Enum.Material, Color: Color3 }

local LOOKS: { [string]: Look } = {
	ground = { Material = Enum.Material.Ground, Color = Color3.fromRGB(94, 88, 76) },
	asphalt = { Material = Enum.Material.Asphalt, Color = Color3.fromRGB(58, 60, 64) },
	dirt = { Material = Enum.Material.Ground, Color = Color3.fromRGB(84, 74, 60) },
	earth = { Material = Enum.Material.Ground, Color = Color3.fromRGB(92, 80, 62) },
	bank = { Material = Enum.Material.Mud, Color = Color3.fromRGB(70, 60, 48) },
	gravel = { Material = Enum.Material.Pebble, Color = Color3.fromRGB(90, 86, 80) },
	concrete = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(128, 126, 120) },
	metal = { Material = Enum.Material.Metal, Color = Color3.fromRGB(104, 108, 112) },
	dark = { Material = Enum.Material.Metal, Color = Color3.fromRGB(52, 54, 58) },
	rust = { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(110, 74, 52) },
	wood = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 90, 66) },
	canvas = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(124, 118, 96) },
	water = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(58, 72, 70) },
	story = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 160, 60) },
}

local built = false

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	look: string,
	class: string?
): BasePart
	local piece = ArenaService.makePart(name, size, cframe, LOOKS[look].Color, class)
	piece.Material = LOOKS[look].Material
	piece.Parent = parent
	return piece
end

-- No collision, no queries, no shadow: water and scenery past the edge.
local function quiet(piece: BasePart): BasePart
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	return piece
end

-- A box from its x / z extents, bottom y0 and top y1.
local function box(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number,
	look: string
): BasePart
	return part(
		parent,
		name,
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		look
	)
end

-- A WedgePart `width` wide and `length` long, `rise` tall from bottom y0, rising toward
-- `toward` ("+x" | "-x" | "+z" | "-z").
local function ramp(
	parent: Instance,
	name: string,
	centre: Vector2,
	width: number,
	length: number,
	y0: number,
	rise: number,
	toward: string,
	look: string
): BasePart
	local yaw = ({ ["+z"] = 0, ["+x"] = 90, ["-z"] = 180, ["-x"] = -90 } :: { [string]: number })[toward]
		or 0
	return part(
		parent,
		name,
		Vector3.new(width, rise, length),
		CFrame.new(centre.X, y0 + rise / 2, centre.Y) * CFrame.Angles(0, math.rad(yaw), 0),
		look,
		"WedgePart"
	)
end

--------------------------------------------------------------------------------------------
-- The ground, the river, the crossings
--------------------------------------------------------------------------------------------

local function buildGround(model: Instance)
	local H, B = Layout.Half, Layout.BaseHalf
	local river = Layout.River
	-- Top at 0 like the base's floor; nothing overlaps it (the river is a gap between slabs).
	box(model, "Ground", -H, H, -H, -B, -1, 0, "ground")
	box(model, "Ground", -H, -B, -B, B, -1, 0, "ground")
	box(model, "Ground", B, H, -B, B, -1, 0, "ground")
	box(model, "Ground", -H, H, B, river.z0, -1, 0, "ground")
	box(model, "Ground", -H, H, river.z1, H, -1, 0, "ground")
end

local function buildRiver(model: Instance)
	local H = Layout.Half
	local river = Layout.River
	local ford = river.ford
	local z0, z1, bank = river.z0, river.z1, river.bank
	box(model, "RiverBed", -H, H, z0, z1, river.bed - 2, river.bed, "bank")
	-- Steep banks (12: past anyone's climb) everywhere but the ford.
	for _, span in { { -H, ford.x0 }, { ford.x1, H } } do
		box(model, "Bank", span[1], span[2], z0, z0 + bank, river.bed, 0, "bank")
		box(model, "Bank", span[1], span[2], z1 - bank, z1, river.bed, 0, "bank")
		quiet(
			box(
				model,
				"Water",
				span[1],
				span[2],
				z0 + bank,
				z1 - bank,
				river.water - 0.4,
				river.water,
				"water"
			)
		).Transparency =
			0.35
	end
	-- The ford: a shallow bed the dirt track crosses, shores sloping into it, and ramps up
	-- from the channel either side so anyone who fell in can walk out here.
	local mid = (z0 + z1) / 2
	local fordX = (ford.x0 + ford.x1) / 2
	local fordW = ford.x1 - ford.x0
	box(model, "Ford", ford.x0, ford.x1, z0, z1, river.bed, ford.bed, "bank")
	ramp(
		model,
		"FordShore",
		Vector2.new(fordX, z0 + bank / 2),
		fordW,
		bank,
		ford.bed,
		-ford.bed,
		"-z",
		"dirt"
	)
	ramp(
		model,
		"FordShore",
		Vector2.new(fordX, z1 - bank / 2),
		fordW,
		bank,
		ford.bed,
		-ford.bed,
		"+z",
		"dirt"
	)
	local inner = z1 - z0 - 2 * bank
	local climb = ford.bed - river.bed
	ramp(
		model,
		"FordRamp",
		Vector2.new(ford.x0 - ford.approach / 2, mid),
		inner,
		ford.approach,
		river.bed,
		climb,
		"+x",
		"bank"
	)
	ramp(
		model,
		"FordRamp",
		Vector2.new(ford.x1 + ford.approach / 2, mid),
		inner,
		ford.approach,
		river.bed,
		climb,
		"-x",
		"bank"
	)
	quiet(
		box(
			model,
			"FordWater",
			ford.x0,
			ford.x1,
			z0 + bank,
			z1 - bank,
			ford.bed + 0.2,
			ford.bed + 0.4,
			"water"
		)
	).Transparency =
		0.35
	-- Boat ramps: along one bank inside the channel, rising to the ground at x1.
	for _, boat in river.ramps do
		local width = 10
		local z = if boat.bank == "south" then z0 + bank + width / 2 else z1 - bank - width / 2
		local toward = if boat.x1 > boat.x0 then "+x" else "-x"
		ramp(
			model,
			"BoatRamp",
			Vector2.new((boat.x0 + boat.x1) / 2, z),
			width,
			math.abs(boat.x1 - boat.x0),
			river.bed,
			-river.bed,
			toward,
			"concrete"
		)
	end
end

local function buildBridges(model: Instance)
	for _, bridge in Layout.Bridges do
		local deck = Instance.new("Model")
		deck.Name = bridge.name
		box(deck, "Deck", bridge.x0, bridge.x1, bridge.z0, bridge.z1, -1, 0.2, "asphalt")
		box(
			deck,
			"Rail",
			bridge.x0,
			bridge.x0 + 1,
			bridge.z0,
			bridge.z1,
			0.2,
			0.2 + bridge.rail,
			"concrete"
		)
		box(
			deck,
			"Rail",
			bridge.x1 - 1,
			bridge.x1,
			bridge.z0,
			bridge.z1,
			0.2,
			0.2 + bridge.rail,
			"concrete"
		)
		local towers = bridge.towers
		if towers then
			-- Landmark: a portal frame at each end, either side of the road.
			for _, z in { bridge.z0 - 5, bridge.z1 + 5 } do
				box(
					deck,
					"Tower",
					bridge.x0 - 5,
					bridge.x0,
					z - 2.5,
					z + 2.5,
					0,
					towers,
					"concrete"
				)
				box(
					deck,
					"Tower",
					bridge.x1,
					bridge.x1 + 5,
					z - 2.5,
					z + 2.5,
					0,
					towers,
					"concrete"
				)
				box(
					deck,
					"TowerBeam",
					bridge.x0,
					bridge.x1,
					z - 2,
					z + 2,
					towers - 5,
					towers - 1,
					"concrete"
				)
			end
		end
		deck.Parent = model
	end
end

local function buildFlyover(model: Instance)
	local fly = Layout.Flyover
	local over = Instance.new("Model")
	over.Name = "Flyover"
	local z0, z1 = fly.z - fly.width / 2, fly.z + fly.width / 2
	local top = fly.height + 0.2
	box(over, "Deck", fly.x0, fly.x1, z0, z1, top - 2, top, "asphalt")
	box(over, "Parapet", fly.x0, fly.x1, z0, z0 + 1, top, top + 3, "concrete")
	box(over, "Parapet", fly.x0, fly.x1, z1 - 1, z1, top, top + 3, "concrete")
	for _, x in fly.pillars do
		box(over, "Pillar", x - 3, x + 3, fly.z - 15, fly.z + 15, 0, top - 2, "concrete")
	end
	ramp(
		over,
		"Ramp",
		Vector2.new(fly.x0 - fly.ramp / 2, fly.z),
		fly.width,
		fly.ramp,
		0,
		top,
		"+x",
		"asphalt"
	)
	ramp(
		over,
		"Ramp",
		Vector2.new(fly.x1 + fly.ramp / 2, fly.z),
		fly.width,
		fly.ramp,
		0,
		top,
		"-x",
		"asphalt"
	)
	over.Parent = model
end

-- N-S roads are cut where an E-W road crosses them and at their `skip` ranges, so no two
-- road faces ever overlap (owner: nothing flickers).
local function buildRoads(model: Instance)
	local roads = Instance.new("Model")
	roads.Name = "Roads"
	local crossings: { Layout.Road } = {}
	for _, road in Layout.Roads do
		if road.z0 == road.z1 then
			table.insert(crossings, road)
			box(
				roads,
				road.name,
				math.min(road.x0, road.x1),
				math.max(road.x0, road.x1),
				road.z0 - road.width / 2,
				road.z0 + road.width / 2,
				0,
				0.2,
				road.surface
			)
		end
	end
	for _, road in Layout.Roads do
		if road.z0 == road.z1 then
			continue
		end
		local cuts: { { number } } = {}
		for _, skip in road.skip or ({} :: { { number } }) do
			table.insert(cuts, { skip[1], skip[2] })
		end
		for _, cross in crossings do
			if
				road.x0 >= math.min(cross.x0, cross.x1)
				and road.x0 <= math.max(cross.x0, cross.x1)
			then
				table.insert(cuts, { cross.z0 - cross.width / 2, cross.z0 + cross.width / 2 })
			end
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local from = math.min(road.z0, road.z1)
		local to = math.max(road.z0, road.z1)
		for _, cut in cuts do
			if cut[1] > from then
				box(
					roads,
					road.name,
					road.x0 - road.width / 2,
					road.x0 + road.width / 2,
					from,
					math.min(cut[1], to),
					0,
					0.2,
					road.surface
				)
			end
			from = math.max(from, cut[2])
		end
		if to > from then
			box(
				roads,
				road.name,
				road.x0 - road.width / 2,
				road.x0 + road.width / 2,
				from,
				to,
				0,
				0.2,
				road.surface
			)
		end
	end
	roads.Parent = model
end

local function buildRail(model: Instance)
	local rail = Layout.Rail
	local track = Instance.new("Model")
	track.Name = "Rail"
	local H = Layout.Half
	local function line(x: number, z0: number, z1: number, bedCut: { number }?)
		local spans: { { number } } = if bedCut
			then { { z0, bedCut[1] }, { bedCut[2], z1 } }
			else { { z0, z1 } }
		for _, span in spans do
			box(
				track,
				"Bed",
				x - rail.bed / 2,
				x + rail.bed / 2,
				span[1],
				span[2],
				0,
				0.15,
				"gravel"
			)
		end
		for _, side in { -1, 1 } do
			local rx = x + side * rail.gauge / 2
			box(track, "Rail", rx - 0.2, rx + 0.2, z0, z1, 0.15, 0.55, "dark")
		end
	end
	line(rail.x, -H, H, rail.skip)
	for _, siding in rail.sidings do
		line(siding.x, siding.z0, siding.z1, nil)
	end
	track.Parent = model
end

-- The invisible walls at the edge and what is seen past them: earth banks N, E and W, the
-- highway running on south toward the coast.
local function buildEdge(model: Instance)
	local H = Layout.Half
	local height = Config.DeltaXL.BoundaryHeight
	for _, wall in
		{
			{ Vector3.new(2, height, 2 * H + 40), Vector3.new(H + 1, height / 2, 0) },
			{ Vector3.new(2, height, 2 * H + 40), Vector3.new(-H - 1, height / 2, 0) },
			{ Vector3.new(2 * H + 40, height, 2), Vector3.new(0, height / 2, H + 1) },
			{ Vector3.new(2 * H + 40, height, 2), Vector3.new(0, height / 2, -H - 1) },
		}
	do
		local piece = part(model, "Boundary", wall[1], CFrame.new(wall[2]), "concrete")
		piece.Transparency = 1
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
	end
	local span = 2 * H + 120
	quiet(ramp(model, "EdgeBank", Vector2.new(0, H + 32), span, 60, 0, 30, "+z", "earth"))
	quiet(ramp(model, "EdgeBank", Vector2.new(H + 32, 0), span, 60, 0, 30, "+x", "earth"))
	quiet(ramp(model, "EdgeBank", Vector2.new(-H - 32, 0), span, 60, 0, 30, "-x", "earth"))
	quiet(box(model, "OuterGround", -H - 2, H + 2, -H - 600, -H - 2, -1, 0, "ground"))
	quiet(box(model, "OuterRoad", -42, -18, -H - 600, -H - 2, 0, 0.2, "asphalt"))
end

--------------------------------------------------------------------------------------------
-- Blocks, houses, lamps, story spots
--------------------------------------------------------------------------------------------

local function buildBlock(persistent: Instance, streamed: Instance, entry: Layout.Block)
	local parent = if entry.landmark then persistent else streamed
	local y0 = entry.y or 0
	local look = entry.look or "concrete"
	local piece: BasePart
	if entry.shape == "cylinder" then
		piece = part(
			parent,
			entry.name,
			Vector3.new(entry.h, entry.w, entry.w),
			CFrame.new(entry.x, y0 + entry.h / 2, entry.z) * CFrame.Angles(0, 0, math.rad(90)),
			look
		)
		local cylinder = piece :: Part
		cylinder.Shape = Enum.PartType.Cylinder
	else
		piece = part(
			parent,
			entry.name,
			Vector3.new(entry.w, entry.h, entry.d),
			CFrame.new(entry.x, y0 + entry.h / 2, entry.z)
				* CFrame.Angles(0, math.rad(entry.yaw or 0), 0),
			look,
			if entry.ramp then "WedgePart" else nil
		)
	end
	if entry.burning then
		-- Fire and smoke sit on top of the piece (SkyService.burn reads an upright box).
		local top = quiet(
			part(
				parent,
				entry.name .. "Fire",
				Vector3.new(entry.w * 0.6, 2, entry.d * 0.6),
				CFrame.new(entry.x, y0 + entry.h - 1, entry.z),
				look
			)
		)
		top.Transparency = 1
		SkyService.burn(top)
	end
end

-- An enterable grey house from the kit: a door in each wall (a 10-wide gap on the south wall
-- of a wide one), windows every 9 studs, an inside stair to the upper floor.
local function houseSpec(entry: Layout.House): MissionTypes.BuildingSpec
	type Openings = { MissionTypes.Opening }
	local function wall(length: number, middle: MissionTypes.Opening?): Openings
		local list: Openings = {}
		if middle then
			table.insert(list, middle)
		end
		local clear = if middle then (middle.width or 4) / 2 + 2.5 else -10
		local at = 9
		while at <= length / 2 - 4 do
			for _, sign in { -1, 1 } do
				if at > clear + 2.5 then
					table.insert(list, { kind = "window", at = sign * at })
				end
			end
			at += 9
		end
		if not middle then
			table.insert(list, { kind = "window", at = 0 })
		end
		return list
	end
	local door: MissionTypes.Opening = { kind = "door", at = 0 }
	-- A two-storey house's stair ends by the east wall at the north side: its side doors sit
	-- toward the south.
	local sideDoor: MissionTypes.Opening =
		{ kind = "door", at = if entry.storeys > 1 then -entry.d / 2 + 3.5 else 0 }
	local walls = {}
	for storey = 1, entry.storeys do
		local ground = storey == 1
		walls[storey] = {
			south = wall(
				entry.w,
				if ground and entry.wide
					then { kind = "gap", at = 0, width = 10 }
					elseif ground then door
					else nil
			),
			-- the stair runs along the north wall: no door there on a two-storey house
			north = wall(entry.w, if ground and entry.storeys == 1 then door else nil),
			east = wall(entry.d, if ground then sideDoor else nil),
			west = wall(entry.d, if ground then sideDoor else nil),
		}
	end
	local stairs: { MissionTypes.StairSpec }? = nil
	if entry.storeys > 1 then
		stairs = {}
		for storey = 1, entry.storeys - 1 do
			table.insert(
				stairs :: { MissionTypes.StairSpec },
				{ side = "north", at = -entry.w / 2 + 1, dir = 1, storey = storey }
			)
		end
	end
	return {
		name = entry.name,
		x = entry.x,
		z = entry.z,
		yaw = entry.yaw,
		width = entry.w,
		depth = entry.d,
		storeys = entry.storeys,
		storeyHeight = entry.storeyHeight,
		material = entry.material,
		walls = walls :: any,
		stairs = stairs,
	}
end

local function buildLamps(streamed: Instance)
	for _, at in Layout.Lamps do
		-- Named like the base's lamp mesh so Lights On lights it.
		part(
			streamed,
			"env_lamp_post",
			Vector3.new(0.6, 14, 0.6),
			CFrame.new(at[1], 7, at[2]),
			"dark"
		)
	end
end

local function buildStorySpots(streamed: Instance)
	if not Config.DeltaXL.StoryMarkers then
		return
	end
	for _, spot in Layout.Spots do
		quiet(
			part(
				streamed,
				`Story_{spot.area}`,
				Vector3.new(1.5, 1.5, 1.5),
				CFrame.new(spot.x, 0.75, spot.z),
				"story"
			)
		)
	end
end

local function build()
	local model = Instance.new("Model")
	model.Name = "DeltaXL"
	-- Always loaded: the ground under everyone, the river and every landmark (streaming
	-- radius is 384; the map is 1,800 across).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	buildGround(model)
	buildRiver(model)
	buildBridges(model)
	buildFlyover(model)
	buildRoads(model)
	buildRail(model)
	buildEdge(model)
	local streamed = Instance.new("Folder")
	streamed.Name = "DeltaXLBlocks"
	for _, entry in Layout.Blocks do
		buildBlock(model, streamed, entry)
	end
	model.Parent = workspace
	streamed.Parent = workspace
	-- After the ground is in the workspace: the kit raycasts it.
	for _, entry in Layout.Houses do
		ArenaService.buildBuilding(streamed, houseSpec(entry))
	end
	buildLamps(streamed)
	buildStorySpots(streamed)
	local persistentParts, streamedParts = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			persistentParts += 1
		end
	end
	for _, item in streamed:GetDescendants() do
		if item:IsA("BasePart") then
			streamedParts += 1
		end
	end
	print(
		`[DeltaXL] the big map is built: {persistentParts} always-loaded parts, {streamedParts} streamed parts, {#Layout.Houses} houses`
	)
end

--------------------------------------------------------------------------------------------
-- The run's points
--------------------------------------------------------------------------------------------

local function flat(position: Vector3): DropPickup.Point
	return { x = position.X, z = position.Z }
end

local function points(list: { Layout.Point }): { DropPickup.Point }
	local out = {}
	for _, point in list do
		table.insert(out, { x = point.x, z = point.z })
	end
	return out
end

-- Whether the big map is built in this server.
function DeltaXL.active(): boolean
	return built
end

-- The drop for a main objective at `main`: a far corner. The squad's pads move there and
-- every living member already standing is put on theirs (a run's first drop, a dev redraw).
function DeltaXL.chooseDrop(main: Vector3): (Vector3, string)
	local index = DropPickup.drop(
		flat(main),
		points(Layout.Drops),
		Config.DeltaXL.DropMinDistance,
		math.random()
	)
	local drop = Layout.Drops[index]
	local at = Vector3.new(drop.x, drop.y, drop.z)
	workspace:SetAttribute(Attributes.DropPoint, at)
	ArenaService.moveSpawnPads()
	for _, member in Squad.living() do
		local root = member.root
		local body = root and root.Parent
		if body and body:IsA("Model") then
			body:PivotTo(Squad.spawnCFrame(member))
		end
	end
	print(`[DeltaXL] drop: {drop.name} ({drop.x}, {drop.z})`)
	return at, drop.name
end

-- The sites of the drawn side objectives (one list of site positions per objective):
-- Rules/DropPickup.sides from this run's drop.
function DeltaXL.planSides(main: Vector3, options: { { Vector3 } }): DropPickup.SidePlan
	local dropAt = workspace:GetAttribute(Attributes.DropPoint)
	local drop = if typeof(dropAt) == "Vector3" then flat(dropAt) else flat(main)
	local flatOptions = {}
	for _, sites in options do
		local list = {}
		for _, position in sites do
			table.insert(list, flat(position))
		end
		table.insert(flatOptions, list)
	end
	return DropPickup.sides(drop, flat(main), flatOptions, Config.DeltaXL.Sides, math.random())
end

-- The pickup, now that the main objective at `main` is done (`warden`: where he stands, if
-- up). ExtractionService reads it.
function DeltaXL.choosePickup(main: Vector3, warden: Vector3?): (Vector3, string)
	local dropAt = workspace:GetAttribute(Attributes.DropPoint)
	local drop = if typeof(dropAt) == "Vector3" then flat(dropAt) else flat(main)
	local index, mode = DropPickup.pickup(
		flat(main),
		drop,
		points(Layout.Pickups),
		Config.DeltaXL.Pickup :: DropPickup.PickupRules,
		math.random(),
		if warden then flat(warden) else nil
	)
	local pickup = Layout.Pickups[index]
	local at = Vector3.new(pickup.x, pickup.y, pickup.z)
	workspace:SetAttribute(Attributes.PickupPoint, at)
	print(`[DeltaXL] pickup ({mode}): {pickup.name} ({pickup.x}, {pickup.z})`)
	return at, pickup.name
end

-- Builds the big map now (Config.DeltaXL.Enabled at boot, or the dev panel). Returns what
-- happened.
function DeltaXL.apply(): string
	if built then
		return "the big map is already on"
	end
	if Missions.current().Id ~= "delta" then
		return "the big map is Checkpoint Delta's: not this mission"
	end
	built = true
	workspace:SetAttribute(Attributes.DeltaXL, true)
	ArenaService.openPerimeter()
	build()
	SkyService.skylineSouth()
	return "the big map is on: restart the run to drop at a corner"
end

function DeltaXL.init()
	Lifecycle.register("DeltaXL", {
		onRunStart = function()
			workspace:SetAttribute(Attributes.PickupPoint, nil)
		end,
	})
	if Config.DeltaXL.Enabled then
		print(`[DeltaXL] {DeltaXL.apply()}`)
	end
end

return DeltaXL
