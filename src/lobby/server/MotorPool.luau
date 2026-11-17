--!strict
-- The motor pool at the aft end of the hangar (Nova 2026-11-17; FallowLayout.MotorPool; plan
-- by the level designer; docs/sprints/LOBBY_V1_FALLOW.md > Motor pool). The motor sergeant
-- (DeskService, desk "vehicles") stands at its front; behind her three painted bays, the ATV
-- parked in the middle one (the same VehicleBody build the match drives, anchored), lashed
-- to the deck; tool chests, a tyre rack, a fuel point and one light. Nothing overlaps:
-- pieces touch or stand apart (docs/OWNER.md, nothing clips).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleBody = require(ReplicatedStorage.Shared.VehicleBody)

local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local MotorPool = {}

local PAINT = Color3.fromRGB(214, 196, 92) -- deck-marking yellow
local STEEL = Color3.fromRGB(61, 69, 77)
local CHAIN = Color3.fromRGB(120, 124, 128)
local CHEST = Color3.fromRGB(150, 46, 40)
local RUBBER = Color3.fromRGB(32, 34, 36)
local PALLET = Color3.fromRGB(122, 98, 66)
local CAN = Color3.fromRGB(99, 110, 66)
local EXTINGUISHER = Color3.fromRGB(190, 40, 36)
local FLOOD = Color3.fromRGB(255, 226, 190)

local LINE = 0.3 -- painted line width
local PAINT_HIGH = 0.1 -- painted line thickness (stands on the floor)

local function bayLines(
	folder: Folder,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	floor: number
)
	local y = floor + PAINT_HIGH / 2
	local paint = { collide = false, material = Enum.Material.SmoothPlastic, shadow = false }
	local width = x1 - x0
	-- The two end lines run the full width; the side lines run between them (they touch).
	for _, z in { z0 + LINE / 2, z1 - LINE / 2 } do
		Build.part(
			folder,
			"BayLine",
			Vector3.new(width, PAINT_HIGH, LINE),
			CFrame.new((x0 + x1) / 2, y, z),
			PAINT,
			paint
		)
	end
	local inner = (z1 - z0) - LINE * 2
	for _, x in { x0 + LINE / 2, x1 - LINE / 2 } do
		Build.part(
			folder,
			"BayLine",
			Vector3.new(LINE, PAINT_HIGH, inner),
			CFrame.new(x, y, (z0 + z1) / 2),
			PAINT,
			paint
		)
	end
end

-- A chain from `from` to `to` (a thin bar; looks only).
local function chain(folder: Folder, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	Build.part(
		folder,
		"Chain",
		Vector3.new(0.15, 0.15, length),
		CFrame.lookAt((from + to) / 2, to),
		CHAIN,
		{ collide = false, material = Enum.Material.Metal, shadow = false }
	)
end

local function parkedVehicle(folder: Folder, floor: number)
	local spot = Layout.MotorPool.parked
	local body = VehicleBody.get(spot.vehicle)
	if not body then
		return
	end
	local centre = Vector3.new(spot.centre.X, floor + body.rest, spot.centre.Z)
	local frame = CFrame.lookAlong(centre, spot.facing)
	local model = VehicleBody.build(spot.vehicle, frame, true)
	if not model then
		return
	end
	model.Name = "ParkedATV"
	model.Parent = folder
	-- Lashed down at sea: a pad-eye on the deck off each corner, past the wheels, and a chain
	-- up to the bottom edge of that end's fender (VehicleBody: the fenders end 3.4 from the
	-- centre, 0.65 up; the wheels stop 3.35 out, so no chain passes through one).
	local eyeY = floor + 0.06
	for _, side in { -1, 1 } do
		for _, ahead in { -1, 1 } do -- -1: the front (the frame's -Z)
			local eye = frame * CFrame.new(side * 3.5, 0, ahead * 4.2)
			local at = Vector3.new(eye.Position.X, eyeY, eye.Position.Z)
			Build.part(
				folder,
				"PadEye",
				Vector3.new(0.6, 0.12, 0.6),
				CFrame.new(at),
				STEEL,
				{ collide = false, material = Enum.Material.Metal, shadow = false }
			)
			chain(
				folder,
				at + Vector3.new(0, 0.06, 0),
				(frame * CFrame.new(side * 1.8, 0.65, ahead * 3.4)).Position
			)
		end
	end
end

local function chests(folder: Folder, floor: number)
	for _, spot in Layout.MotorPool.chests do
		local chest = Build.part(
			folder,
			"ToolChest",
			Vector3.new(3, 4, 2),
			CFrame.new(spot.X, floor + 2, spot.Z),
			CHEST,
			{ material = Enum.Material.Metal }
		)
		-- Drawer fronts on the face toward the walkway (+Z), proud of it.
		for row = 0, 3 do
			Build.part(
				folder,
				"Drawer",
				Vector3.new(2.6, 0.7, 0.05),
				chest.CFrame * CFrame.new(0, -1.4 + row * 0.9, 1.025),
				STEEL,
				{ collide = false, material = Enum.Material.Metal, shadow = false }
			)
		end
	end
end

local function tyreRack(folder: Folder, floor: number)
	local rack = Layout.MotorPool.tyreRack
	local x, z0, z1 = rack.x, rack.z0, rack.z1
	local length = z1 - z0
	local midZ = (z0 + z1) / 2
	for _, px in { x - 2, x + 2 } do
		for _, pz in { z0 + 0.15, z1 - 0.15 } do
			Build.part(
				folder,
				"RackPost",
				Vector3.new(0.3, 6, 0.3),
				CFrame.new(px, floor + 3, pz),
				STEEL,
				{ material = Enum.Material.Metal }
			)
		end
	end
	-- Two shelves between the posts (they meet the posts' inner faces), four tyres on each.
	for _, shelfTop in { floor + 0.8, floor + 3.2 } do
		Build.part(
			folder,
			"RackShelf",
			Vector3.new(3.7, 0.2, length - 0.6),
			CFrame.new(x, shelfTop - 0.1, midZ),
			STEEL,
			{ material = Enum.Material.Metal }
		)
		for k = 0, 3 do
			Build.part(
				folder,
				"Tyre",
				Vector3.new(0.9, 2.2, 2.2),
				CFrame.new(x, shelfTop + 1.1, z0 + 2.6 + k * 2.9),
				RUBBER,
				{ shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber }
			)
		end
	end
end

local function fuelPoint(folder: Folder, floor: number)
	local at = Layout.MotorPool.fuel
	local top = floor + 0.57
	Build.part(
		folder,
		"Pallet",
		Vector3.new(4, 0.57, 4),
		CFrame.new(at.X, floor + 0.285, at.Z),
		PALLET,
		{ material = Enum.Material.Wood }
	)
	for col = 0, 2 do
		for row = 0, 1 do
			Build.part(
				folder,
				"JerryCan",
				Vector3.new(0.6, 1.7, 1.25),
				CFrame.new(at.X - 1.2 + col * 1.2, top + 0.85, at.Z - 0.8 + row * 1.6),
				CAN,
				{ material = Enum.Material.Metal }
			)
		end
	end
	-- The extinguisher on its post beside the pallet.
	local postX = at.X + 2.5
	Build.part(
		folder,
		"ExtinguisherPost",
		Vector3.new(0.3, 4, 0.3),
		CFrame.new(postX, floor + 2, at.Z),
		STEEL,
		{ material = Enum.Material.Metal }
	)
	Build.part(
		folder,
		"Extinguisher",
		Vector3.new(0.5, 1.4, 0.5),
		CFrame.new(postX + 0.4, floor + 2.2, at.Z),
		EXTINGUISHER,
		{ material = Enum.Material.Metal }
	)
end

local function light(folder: Folder)
	local fixture = Build.part(
		folder,
		"HangarLight",
		Vector3.new(4, 0.6, 1.2),
		CFrame.new(Layout.MotorPool.light),
		FLOOD,
		{ material = Enum.Material.Neon, collide = false }
	)
	local lamp = Instance.new("PointLight")
	lamp.Color = FLOOD
	lamp.Range = 50
	lamp.Brightness = 1.2
	lamp.Shadows = false
	lamp.Parent = fixture
end

-- Builds the motor pool into `folder` (DeskService, for the "vehicles" desk).
function MotorPool.build(folder: Folder)
	local floor = Layout.HangarY
	local pool = Layout.MotorPool
	for _, bay in pool.bays do
		bayLines(folder, bay.x0, bay.x1, pool.bayZ0, pool.bayZ1, floor)
	end
	parkedVehicle(folder, floor)
	chests(folder, floor)
	tyreRack(folder, floor)
	fuelPoint(folder, floor)
	light(folder)
end

return MotorPool
