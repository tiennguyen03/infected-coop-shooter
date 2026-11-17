--!strict
-- Vehicle bodies (docs/PROGRESSION.md > The ATV): the Model a vehicle call-in drives, built
-- from Parts in the palette (docs/STYLES.md section 2) until it has a mesh. The match's
-- VehicleService, the arrival's slung stand-in (CallInArrivalFX "sling") and the Carrier's
-- display (the lobby's motor pool) all build from here, so all three are the same ATV.
--
-- Frame: the origin is the chassis' centre; forward is -Z (the LookVector, so a Seat faces
-- the way it drives), up +Y. The chassis is the only part with mass and collision; every
-- other piece is welded to it, massless. The wheels are looks only (the suspension is rays,
-- VehiclePhysics): each hangs on a Weld whose C0 every client moves for itself.

local VehicleBody = {}

export type Wheel = {
	mount: Vector3, -- where its spring is fixed, chassis frame
	front: boolean, -- steers
}

export type Body = {
	wheelRadius: number,
	wheelWidth: number,
	wheels: { Wheel },
	driver: Vector3, -- the driver's seat part, chassis frame
	gunner: Vector3, -- the back seat
	hook: Vector3, -- where the sling line meets the roll bar
	size: Vector3, -- the chassis box
	bumper: number, -- distance from the centre to the front face (-Z)
	rest: number, -- how high the centre sits over flat ground at rest
}

-- Palette (docs/STYLES.md section 2).
local OLIVE = Color3.fromRGB(99, 110, 66)
local OLIVE_DARK = Color3.fromRGB(65, 73, 43)
local STEEL_DARK = Color3.fromRGB(61, 69, 77)
local POLYMER = Color3.fromRGB(48, 53, 59)
local RUBBER = Color3.fromRGB(32, 34, 36)
local LAMP = Color3.fromRGB(255, 236, 190)
local STENCIL = Color3.fromRGB(214, 209, 190)

-- Front is +f in these numbers; `at` turns it into the frame's -Z.
local function at(x: number, y: number, f: number): CFrame
	return CFrame.new(x, y, -f)
end

VehicleBody.Bodies = {
	atv = {
		wheelRadius = 1.1,
		wheelWidth = 0.9,
		wheels = {
			{ mount = Vector3.new(-2, 0.3, -2.25), front = true },
			{ mount = Vector3.new(2, 0.3, -2.25), front = true },
			{ mount = Vector3.new(-2, 0.3, 2.25), front = false },
			{ mount = Vector3.new(2, 0.3, 2.25), front = false },
		},
		driver = Vector3.new(0, 1.6, 0.15),
		gunner = Vector3.new(0, 1.45, 2),
		hook = Vector3.new(0, 3.2, 3),
		size = Vector3.new(3, 1.3, 6),
		bumper = 3.4,
		rest = 1.33,
	},
} :: { [string]: Body }

function VehicleBody.get(bodyId: string): Body?
	return VehicleBody.Bodies[bodyId]
end

local function piece(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * frame
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = root.Anchored
	if not root.Anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = model
	return part
end

local function stencil(root: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(300, 65)
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.5, 0.5)
	label.Position = UDim2.fromScale(0.25, 0.25)
	label.Text = "HARLAN"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = STENCIL
	label.TextTransparency = 0.25
	label.Parent = gui
	gui.Parent = root
end

local function seat(
	model: Model,
	root: BasePart,
	name: string,
	className: string,
	offset: Vector3
): Seat | VehicleSeat
	local part = Instance.new(className) :: any
	part.Name = name
	part.Size = Vector3.new(1.2, 0.2, 1.2)
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Transparency = 1
	part.CanCollide = false
	-- Nobody sits by walking into it: VehicleService seats them (Seat:Sit) on the prompt.
	part.CanTouch = false
	part.Massless = true
	part.Anchored = root.Anchored
	if className == "VehicleSeat" then
		part.HeadsUpDisplay = false
		part.MaxSpeed = 0
		part.Torque = 0
	end
	if not root.Anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = model
	return part
end

-- Builds body `bodyId` standing on its wheels with its centre at `frame`. `anchored`: a
-- display or a stand-in (no physics, no seats); otherwise a working vehicle (seats, an
-- unanchored chassis). Returns the Model (PrimaryPart = the chassis, "Chassis").
function VehicleBody.build(bodyId: string, frame: CFrame, anchored: boolean): Model?
	local body = VehicleBody.get(bodyId)
	if not body then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ATV"

	local root = Instance.new("Part")
	root.Name = "Chassis"
	root.Size = body.size
	root.CFrame = frame
	root.Color = OLIVE_DARK
	root.Material = Enum.Material.Metal
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = anchored
	root.CanTouch = false
	-- Heavier than its riders, so a seated soldier does not tip it.
	root.CustomPhysicalProperties = PhysicalProperties.new(3, 0.6, 0.1)
	root.Parent = model
	model.PrimaryPart = root

	-- Fenders over each axle, the tank between them (the driver's seat on it), the raised
	-- back seat on the rear deck, the roll bar behind it. Pieces touch, never overlap.
	piece(model, root, "FrontFender", Vector3.new(4.4, 0.3, 2.4), at(0, 0.8, 2.2), OLIVE)
	piece(model, root, "RearFender", Vector3.new(4.4, 0.3, 2.5), at(0, 0.8, -2.15), OLIVE)
	piece(model, root, "Tank", Vector3.new(1.8, 0.8, 1.9), at(0, 1.05, 0.05), OLIVE)
	piece(
		model,
		root,
		"DriverPad",
		Vector3.new(1.3, 0.25, 1.4),
		at(0, 1.575, -0.15),
		POLYMER,
		Enum.Material.Fabric
	)
	piece(model, root, "Stem", Vector3.new(0.3, 0.8, 0.3), at(0, 1.35, 1.25), STEEL_DARK)
	piece(model, root, "Bars", Vector3.new(2.4, 0.2, 0.2), at(0, 1.85, 1.25), STEEL_DARK)
	piece(
		model,
		root,
		"GunnerSeat",
		Vector3.new(1.5, 0.6, 1.4),
		at(0, 1.25, -2),
		POLYMER,
		Enum.Material.Fabric
	)
	piece(model, root, "RollBarL", Vector3.new(0.25, 2, 0.25), at(-1.3, 1.95, -3), STEEL_DARK)
	piece(model, root, "RollBarR", Vector3.new(0.25, 2, 0.25), at(1.3, 1.95, -3), STEEL_DARK)
	piece(model, root, "RollBarTop", Vector3.new(2.85, 0.25, 0.25), at(0, 3.075, -3), STEEL_DARK)
	piece(model, root, "RackFront", Vector3.new(3.2, 0.15, 0.15), at(0, 1.025, 3.2), STEEL_DARK)
	piece(model, root, "RackBack", Vector3.new(3.2, 0.15, 0.15), at(0, 1.025, 2.4), STEEL_DARK)
	piece(model, root, "RackL", Vector3.new(0.15, 0.15, 0.65), at(-1.525, 1.025, 2.8), STEEL_DARK)
	piece(model, root, "RackR", Vector3.new(0.15, 0.15, 0.65), at(1.525, 1.025, 2.8), STEEL_DARK)
	piece(model, root, "JerryCan", Vector3.new(0.5, 0.8, 0.9), at(-1.7, 1.35, -2.7), OLIVE)
	for _, side in { -1, 1 } do
		local lamp = piece(
			model,
			root,
			"Headlight",
			Vector3.new(0.5, 0.3, 0.1),
			at(side * 0.9, 0.8, 3.45),
			LAMP,
			Enum.Material.Neon
		)
		lamp.Transparency = 0.2
	end
	stencil(root, Enum.NormalId.Left)
	stencil(root, Enum.NormalId.Right)

	-- The wheels: a tyre and a spoke (so the spin shows) on a Weld from the chassis, at
	-- their rest height; VehicleController moves the welds.
	for index, wheel in body.wheels do
		-- At rest the ground is `rest` under the centre, so the wheel's centre is a radius up.
		local centre = Vector3.new(wheel.mount.X, body.wheelRadius - body.rest, wheel.mount.Z)
		local tyre = Instance.new("Part")
		tyre.Name = `Wheel{index}`
		tyre.Shape = Enum.PartType.Cylinder
		tyre.Size = Vector3.new(body.wheelWidth, body.wheelRadius * 2, body.wheelRadius * 2)
		tyre.Color = RUBBER
		tyre.Material = Enum.Material.Rubber
		tyre.CanCollide = false
		tyre.CanTouch = false
		tyre.CanQuery = false
		tyre.Massless = true
		tyre.Anchored = anchored
		tyre.CFrame = root.CFrame * CFrame.new(centre)
		tyre:SetAttribute("Mount", wheel.mount)
		tyre:SetAttribute("Front", wheel.front)
		local spoke = Instance.new("Part")
		spoke.Name = "Spoke"
		spoke.Size = Vector3.new(0.1, body.wheelRadius * 1.3, 0.35)
		spoke.Color = STEEL_DARK
		spoke.Material = Enum.Material.Metal
		spoke.CanCollide = false
		spoke.CanTouch = false
		spoke.CanQuery = false
		spoke.Massless = true
		spoke.Anchored = anchored
		local outward = if wheel.mount.X < 0 then -1 else 1
		spoke.CFrame = tyre.CFrame * CFrame.new(outward * (body.wheelWidth / 2 + 0.05), 0, 0)
		if anchored then
			spoke.Parent = tyre
		else
			local weld = Instance.new("Weld")
			weld.Name = "Axle"
			weld.Part0 = root
			weld.Part1 = tyre
			weld.C0 = CFrame.new(centre)
			weld.Parent = tyre
			local hub = Instance.new("WeldConstraint")
			hub.Part0 = tyre
			hub.Part1 = spoke
			hub.Parent = spoke
			spoke.Parent = tyre
		end
		tyre.Parent = model
	end

	if not anchored then
		seat(model, root, "DriverSeat", "VehicleSeat", body.driver)
		seat(model, root, "GunnerSeat", "Seat", body.gunner)
	end
	return model
end

return VehicleBody
