--!strict
-- Places the Carrier's walking crew (LobbyCrew, routes in FallowLayout.Crew) once, standing
-- at the start of their route, tagged for the client's CrewWalk, which walks each client's
-- own copy (nothing replicates after the build, the way RadarSpin turns the radar). Blocks
-- from NpcBody in their working dress; no Humanoid, no prompt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local LobbyCrew = require(ReplicatedStorage.Lobby.LobbyCrew)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)
local NpcBody = require(script.Parent.NpcBody)

local CrewService = {}

local SHIP_TROUSERS = Color3.fromRGB(40, 44, 54)
local ARMY = NpcBody.Army

-- Flight deck jerseys by job (the coloured shirt is how a deck crew reads at a distance).
local DRESS: { [string]: NpcBody.Dress } = {
	director = {
		shirt = Color3.fromRGB(214, 176, 40),
		trousers = SHIP_TROUSERS,
		cover = Color3.fromRGB(214, 176, 40),
	},
	deckhand = {
		shirt = Color3.fromRGB(46, 92, 170),
		trousers = SHIP_TROUSERS,
		cover = Color3.fromRGB(46, 92, 170),
	},
	mechanic = {
		shirt = Color3.fromRGB(58, 120, 64),
		trousers = Color3.fromRGB(70, 74, 64),
		cover = Color3.fromRGB(58, 120, 64),
	},
	runner = NpcBody.Ship,
	medic = { shirt = Color3.fromRGB(222, 222, 216), trousers = ARMY.trousers },
	sentry = { shirt = ARMY.shirt, trousers = ARMY.trousers }, -- helmeted (KIT)
}

-- What each one carries (NpcBody kit; docs/lore/ship_company.md).
local KIT: { [string]: NpcBody.Kit } = {
	director = { "earDefenders" },
	deckhand = { "chocks" },
	mechanic = { "rag" },
	runner = { "clipboard" },
	medic = { "blueGloves", "mask" },
	sentry = { "helmet", "slungRifle", "brassard" },
}

-- "x,y,z;x,y,z;..." for the client (attributes hold no arrays).
local function encode(route: { Vector3 }): string
	local points = {}
	for _, p in route do
		table.insert(points, `{p.X},{p.Y},{p.Z}`)
	end
	return table.concat(points, ";")
end

function CrewService.init()
	local folder = Build.folder(Workspace, "Crew")
	for _, crew in LobbyCrew do
		local route = Layout.Crew[crew.id]
		if not route or #route < 2 then
			warn(`[CrewService] no route for {crew.id}`)
			continue
		end
		local model = NpcBody.build(
			folder,
			crew.role,
			route[1],
			route[2] - route[1],
			DRESS[crew.id] or NpcBody.Ship,
			KIT[crew.id],
			false -- each client walks and animates them (CrewWalk)
		)
		-- Walkers never block or shove a soldier (they move on each client, not in physics).
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
			end
		end
		model:SetAttribute(Attributes.CrewId, crew.id)
		model:SetAttribute(Attributes.CrewRoute, encode(route))
		CollectionService:AddTag(model, Attributes.CrewTag)
	end
end

return CrewService
