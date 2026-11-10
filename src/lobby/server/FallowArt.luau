--!strict
-- The Fallow's ship art (docs/sprints/LOBBY_V1_FALLOW.md > Ship art; meshes in
-- assets/3d/build/fallow.py): the art director's build sheet, owner-approved 2026-11-09.
--
-- Two halves:
-- * Always built (Parts, gameplay): the port side lift lowered to hangar level as a walkable
--   balcony with rails and its own invisible walls, the white deck-edge lines, and the old
--   deck number painted out at the bow end of the deck with HARLAN sprayed over it (Task Force Harlan; was HRD until 2026-11-10).
-- * Built once the meshes are uploaded (MeshAssets entries with an id): the hull shells and
--   trims, the island, the radar, the catwalk bays. Each group replaces its block Parts only
--   when every mesh in it has loaded, so a missing upload leaves the v1 blocks as they were.
--   Collision never moves to a mesh: the hidden blocks keep colliding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local FallowArt = {}

local PAINT = Color3.fromRGB(214, 214, 208)
local YELLOW = Color3.fromRGB(230, 189, 96)
local HANGAR_FLOOR = Color3.fromRGB(64, 66, 68)
local PAINTED_OUT_DECK = Color3.fromRGB(40, 42, 44)
local PAINTED_OUT_HULL = Color3.fromRGB(99, 109, 119) -- the palette's `gun`, over the Metal shell
local SPRAY = Color3.fromRGB(226, 224, 216)

local W = Layout.HalfWidth
local DECK_Y = Layout.DeckY
local HANGAR_Y = Layout.HangarY
local DECK_BOTTOM = DECK_Y - Layout.DeckThickness

local HULL = { "env_fallow_bow", "env_fallow_mid_port", "env_fallow_mid_stbd", "env_fallow_stern" }
local HULL_TRIM = { "env_fallow_bow_trim", "env_fallow_mid_trim", "env_fallow_stern_trim" }
local ISLAND = { "env_fallow_island", "env_fallow_island_trim" }

-- The lift platform at hangar level: a DiamondPlate deck flush with the hangar floor, a rail
-- round its three open sides, and invisible walls just outside the rail.
local function buildBalcony(ship: Folder)
	local b = Layout.Balcony
	Build.box(
		ship,
		"Balcony",
		Vector3.new(b.x0, HANGAR_Y - 0.6, b.z0),
		Vector3.new(b.x1, HANGAR_Y, b.z1),
		HANGAR_FLOOR,
		{ material = Enum.Material.DiamondPlate }
	)
	local rail = { material = Enum.Material.SmoothPlastic }
	Build.box(
		ship,
		"BalconyRail",
		Vector3.new(b.x0, HANGAR_Y, b.z0),
		Vector3.new(b.x0 + 0.4, HANGAR_Y + 3, b.z1),
		YELLOW,
		rail
	)
	for _, z in { b.z0, b.z1 - 0.4 } do
		Build.box(
			ship,
			"BalconyRail",
			Vector3.new(b.x0 + 0.4, HANGAR_Y, z),
			Vector3.new(b.x1 - 0.2, HANGAR_Y + 3, z + 0.4),
			YELLOW,
			rail
		)
	end
	-- Outer wall, and the two ends from the rail back to the hull across the lift opening.
	Build.barrier(
		ship,
		Vector3.new(b.x0 - 1, HANGAR_Y, b.z0 - 2),
		Vector3.new(b.x0, DECK_BOTTOM, b.z1 + 2)
	)
	Build.barrier(ship, Vector3.new(b.x0, HANGAR_Y, b.z0 - 2), Vector3.new(-W, DECK_BOTTOM, b.z0))
	Build.barrier(ship, Vector3.new(b.x0, HANGAR_Y, b.z1), Vector3.new(-W, DECK_BOTTOM, b.z1 + 2))
end

-- White deck-edge lines (the safety nets' outer rail is the edge itself once the catwalks are
-- up), broken where the island stands and at the screening lane's deck edge; the old deck
-- number painted out at the bow end.
local function buildMarkings(ship: Folder)
	local island = Layout.Island
	local lane = Layout.Lane
	local runs = {
		{ x = -W + 1.2, spans = { { -180, 210 } } },
		{ x = W - 1.2, spans = { { -180, lane.z0 }, { lane.z1, island.z0 }, { island.z1, 210 } } },
	}
	for _, run in runs do
		for _, span in run.spans do
			Build.box(
				ship,
				"EdgeLine",
				Vector3.new(run.x - 0.3, DECK_Y, span[1]),
				Vector3.new(run.x + 0.3, DECK_Y + 0.05, span[2]),
				PAINT,
				{ material = Enum.Material.SmoothPlastic, collide = false }
			)
		end
	end
	local patch = Build.box(
		ship,
		"PaintedOutDeck",
		Vector3.new(-14, DECK_Y, 186),
		Vector3.new(14, DECK_Y + 0.03, 204),
		PAINTED_OUT_DECK,
		{ material = Enum.Material.Asphalt, collide = false }
	)
	Build.text(
		patch,
		Enum.NormalId.Top,
		"HARLAN",
		{ size = 300, color = SPRAY, font = Enum.Font.PermanentMarker }
	)
end

-- Places one uploaded mesh; nil when it is not uploaded or did not load in time.
local function place(art: Folder, name: string, cframe: CFrame): MeshPart?
	if not MeshAssets.isUploaded(name) then
		return nil
	end
	local part = MeshAssets.waitFor(name, Config.Lobby.Ship.TemplateWait)
	if not part then
		return nil
	end
	part.CFrame = cframe
	part.Parent = art
	return part
end

-- All of a group or none of it: half a hull would show the blocks through the gaps.
local function placeGroup(art: Folder, names: { string }): boolean
	local placed: { MeshPart } = {}
	for _, name in names do
		local part = place(art, name, CFrame.new(MeshAssets.getOffset(name)))
		if not part then
			for _, done in placed do
				done:Destroy()
			end
			return false
		end
		table.insert(placed, part)
	end
	return true
end

local function hide(part: Instance?)
	if part and part:IsA("BasePart") then
		part.Transparency = 1
		part.CastShadow = false
	end
end

-- The painted-out hull number on the bow's flat facet (FallowLayout.BowFacet), each side.
local function bowPatch(ship: Folder, side: number)
	local f = Layout.BowFacet
	local function mirror(v: Vector3): Vector3
		return Vector3.new(v.X * side, v.Y, v.Z)
	end
	local knuckle, top, fore = mirror(f.knuckle165), mirror(f.top165), mirror(f.knuckle185)
	local up = (top - knuckle).Unit
	local along = (fore - knuckle).Unit
	local normal = (up:Cross(along) * side).Unit -- outward on both sides
	local centre = knuckle + (fore - knuckle) * 0.5 + (top - knuckle) * 0.62 + normal * 0.15
	local patch = Build.part(
		ship,
		"PaintedOutBow",
		Vector3.new(0.2, 8, 16),
		CFrame.fromMatrix(centre, normal, up),
		PAINTED_OUT_HULL,
		{ collide = false, shadow = false }
	)
	Build.text(
		patch,
		Enum.NormalId.Right,
		"HARLAN",
		{ size = 160, color = SPRAY, font = Enum.Font.PermanentMarker }
	)
end

local function swapHull(ship: Folder)
	hide(ship:FindFirstChild("Hull")) -- still the floor support under the hangar plate
	hide(ship:FindFirstChild("Bow"))
	-- The closed spaces fore and aft of the hangar shrink inside the hull's skin.
	local aft = ship:FindFirstChild("AftSpaces")
	if aft and aft:IsA("BasePart") then
		aft.Size = Vector3.new(W * 2 - 2, aft.Size.Y, aft.Size.Z)
	end
	local fore = ship:FindFirstChild("ForeSpaces")
	if fore and fore:IsA("BasePart") then
		fore.Size = Vector3.new(W * 2 - 2, fore.Size.Y, 4)
		fore.CFrame = CFrame.new(0, fore.Position.Y, Layout.HangarFore + 2)
	end
	bowPatch(ship, 1)
	bowPatch(ship, -1)
end

local function swapIsland(ship: Folder)
	hide(ship:FindFirstChild("Island")) -- keeps colliding
	for _, child in ship:GetChildren() do
		local name = child.Name
		local onIsland = child:IsA("BasePart") and child.Position.X > Layout.Island.x0 - 2
		if
			name == "BridgeWindows"
			or name == "Mast"
			or name == "Yard"
			or (name == "FloodLamp" and onIsland)
		then
			child:Destroy()
		end
	end
end

local function placeCatwalks(ship: Folder, art: Folder)
	local any = false
	for _, bay in Layout.Catwalks do
		local name = if bay.rafts then "env_fallow_catwalk_rafts" else "env_fallow_catwalk"
		local pivot = CFrame.new(bay.side * Layout.CatwalkHullX, DECK_Y, bay.z)
		if bay.side < 0 then
			pivot *= CFrame.Angles(0, math.pi, 0) -- the bay is symmetric fore and aft
		end
		if place(art, name, pivot * CFrame.new(MeshAssets.getOffset(name))) then
			any = true
		end
	end
	if any then
		-- Carriers have no deck-top rail: the nets' outer rail is the edge (owner, 2026-11-09).
		for _, child in ship:GetChildren() do
			if child.Name == "EdgeRail" then
				child:Destroy()
			end
		end
	end
end

local function placeMeshes(ship: Folder)
	local art = Build.folder(ship, "ShipArt")
	if placeGroup(art, HULL) then
		swapHull(ship)
		placeGroup(art, HULL_TRIM)
	end
	if placeGroup(art, ISLAND) then
		swapIsland(ship)
		local radar = "env_fallow_radar"
		place(art, radar, CFrame.new(Layout.Radar) * CFrame.new(MeshAssets.getOffset(radar)))
	end
	placeCatwalks(ship, art)
	print(`[Lobby] Ship art: {#art:GetChildren()} meshes placed`)
end

function FallowArt.build(ship: Folder)
	buildBalcony(ship)
	buildMarkings(ship)
	-- Templates load asynchronously; the ship is playable on its blocks meanwhile.
	task.spawn(placeMeshes, ship)
end

return FallowArt
