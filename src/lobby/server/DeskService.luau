--!strict
-- The hangar desks (LobbyDesks, placed by FallowLayout.Desks): a crew figure behind a
-- counter, the desk's stencil over it, its props, and a "Talk" prompt (F). The prompt carries
-- the desk id; the client shows the line (DeskDialogUI), or the desk's own screen (ArmsRackUI,
-- LoadmasterUI). Buying waits for the save service (docs/ARCHITECTURE.md F9).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local ArmsRack = require(script.Parent.ArmsRack)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)
local NpcBody = require(script.Parent.NpcBody)

local DeskService = {}

local COUNTER = Color3.fromRGB(84, 88, 92)
local CRATE = Color3.fromRGB(86, 92, 66)
local WIRE = Color3.fromRGB(120, 124, 126)

-- Each figure's look (NpcBody.Dress): body colours and `items`, Roblox catalog asset ids of any
-- kind a body wears (layered shirts and pants, hats, hair, vests, glasses...). The codes in the
-- comments are the picks page's (Nova, 2026-11-11: first try of the suggestions).
local ARMY = NpcBody.Army
local SHIP = NpcBody.Ship
local DRESS: { [string]: NpcBody.Dress } = {
	-- Woodland shirt and pants, olive patrol cap, reading glasses (A3 A4 K1 O1).
	arms_room = {
		shirt = ARMY.shirt,
		trousers = ARMY.trousers,
		items = { 16125110410, 16125087437, 13418346088, 119588777391950 },
	},
	-- Green flight suit, a headset (F1 E4); no hair (Nova).
	loadmaster = {
		shirt = SHIP.shirt,
		trousers = SHIP.trousers,
		items = { 105079389547650, 15946756199 },
	},
	-- Woodland shirt and pants, a headset (A3 A4 E3), short black hair (R3).
	fires = {
		shirt = ARMY.shirt,
		trousers = ARMY.trousers,
		items = { 16125110410, 16125087437, 15987281035, 14763641985 },
	},
	-- Woodland top and pants, tan patrol cap (A1 A2 K2).
	engineers = {
		shirt = ARMY.shirt,
		trousers = ARMY.trousers,
		items = { 9482682978, 9482717204, 13418356502 },
	},
	-- Military shirt, combat pants, a headset (A6 A9 E5).
	plot = {
		shirt = ARMY.shirt,
		trousers = ARMY.trousers,
		items = { 130988807898132, 74956577347922, 10154340203 },
	},
}

-- Props per desk, relative to the person's feet and facing (X right, Z forward).
local function props(folder: Folder, id: string, frame: CFrame)
	local function prop(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		options: Build.PartOptions?
	)
		Build.part(folder, name, size, frame * CFrame.new(offset), color, options)
	end
	if id == "arms_room" then
		-- The whole corner: the glass counter, the long-gun wall, the fence (ArmsRack,
		-- FallowLayout.ArmsRoom).
		ArmsRack.build(folder)
	elseif id == "loadmaster" then
		-- Slung cases waiting for the door.
		prop("Case", Vector3.new(4, 3, 3), Vector3.new(-5, 1.5, 5), CRATE)
		prop("Case", Vector3.new(4, 3, 3), Vector3.new(-5, 4.5, 5), CRATE)
		prop("Case", Vector3.new(4, 3, 3), Vector3.new(5, 1.5, 6), CRATE)
		prop(
			"Sling",
			Vector3.new(0.2, 6, 0.2),
			Vector3.new(5, 6, 6),
			Color3.fromRGB(150, 130, 60),
			{ collide = false }
		)
	elseif id == "fires" then
		prop(
			"RadioSet",
			Vector3.new(2.4, 1.6, 1.2),
			Vector3.new(0, 4.2, 2),
			Color3.fromRGB(60, 64, 50)
		)
	elseif id == "engineers" then
		-- Spools of wire.
		for index, x in { -4.5, -2, 4 } do
			prop(
				"Spool",
				Vector3.new(2.2, 3, 3),
				Vector3.new(x, 1.5, 4 + index % 2),
				WIRE,
				{ shape = Enum.PartType.Cylinder, material = Enum.Material.DiamondPlate }
			)
		end
	end
end

function DeskService.init()
	local folder = Build.folder(Workspace, "Desks")
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, desk in LobbyDesks do
		byId[desk.id] = desk
	end

	for _, place in Layout.Desks do
		local desk = byId[place.id]
		if not desk then
			warn(`[DeskService] no LobbyDesks entry for {place.id}`)
			continue
		end
		local _, torso = NpcBody.build(
			folder,
			desk.title,
			place.feet,
			place.facing,
			DRESS[desk.id] or NpcBody.Ship
		)
		local frame = CFrame.lookAt(place.feet, place.feet + place.facing)
		props(folder, desk.id, frame)

		-- The counter in front of the person, the stencil over it (or over the person when the
		-- place has no counter: the Plot's watch officer works at the map table).
		if place.counter == false then
			Build.sign(torso, desk.title, desk.who, 4)
		else
			local counter = Build.part(
				folder,
				"Counter",
				Vector3.new(7, 3.4, 1.4),
				frame * CFrame.new(0, 1.7, -2.4),
				COUNTER
			)
			Build.sign(counter, desk.title, desk.who, 6.5)
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = desk.title
		prompt.KeyboardKeyCode = Config.Keys.Interact
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = place.reach or Config.Lobby.DeskPromptDistance
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute(Attributes.DeskId, desk.id)
		prompt.Parent = torso
	end
end

return DeskService
