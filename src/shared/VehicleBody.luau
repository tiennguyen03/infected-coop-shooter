--!strict
-- Vehicle bodies (docs/PROGRESSION.md > The ATV): the Model a vehicle call-in drives. The
-- match's VehicleService, the arrival's slung stand-in (CallInArrivalFX "sling") and the
-- Carrier's display (the lobby's motor pool) all build from here, so all three are the same
-- ATV. A body with `meshes` wears them (the owner's model, assets/3d/build/atv.py); until
-- they load, or where they cannot, it is built from Parts in the palette (STYLES section 2).
-- MeshAssets' templates are server-only, so `publish` copies them to ReplicatedStorage for
-- the clients' stand-in.
--
-- Frame: the origin is the chassis' centre; forward is -Z (the LookVector, so a Seat faces
-- the way it drives), up +Y. The chassis is the only part with mass and collision; every
-- other piece is welded to it, massless. The wheels are looks only (the suspension is rays,
-- VehiclePhysics): each hangs on a Weld whose C0 every client moves for itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeshAssets = require(script.Parent.MeshAssets)

local VehicleBody = {}

-- The clients' copies of the vehicle meshes (published by the server).
local CLIENT_FOLDER = "VehicleMeshes"

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
	wheelLift: number, -- the highest a wheel's centre is drawn (chassis frame Y)
	-- MeshAssets names: the body (offset from the chassis centre) and one wheel about its
	-- hub, built as a right-side wheel (outer face +X).
	meshes: { body: string, wheel: string }?,
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
	-- Measured on the owner's model (atv.py prepare, 2026-11-17): tyres of radius 1 on a
	-- 4.81 wheelbase and a 3.28 track; the saddle's top 0.95 up at z 0..0.5, the rear rack's
	-- deck 1.55 up behind the raised back, its rail's top 1.83 up at the tail. The Part body
	-- (the fallback) is drawn on the same wheels.
	atv = {
		wheelRadius = 1,
		wheelWidth = 0.9,
		wheels = {
			{ mount = Vector3.new(-1.64, 0.3, -2.405), front = true },
			{ mount = Vector3.new(1.64, 0.3, -2.405), front = true },
			{ mount = Vector3.new(-1.64, 0.3, 2.405), front = false },
			{ mount = Vector3.new(1.64, 0.3, 2.405), front = false },
		},
		driver = Vector3.new(0, 0.85, 0.25),
		gunner = Vector3.new(0, 1.45, 2.35),
		hook = Vector3.new(0, 1.83, 3.25),
		size = Vector3.new(3, 1.3, 6.6),
		bumper = 3.95,
		-- The springs hold a wheel's centre 0.23 under the chassis centre (mount 0.3, travel
		-- 1, sag 196.2 / 420 = 0.47), so the centre stands a radius plus that over the ground.
		rest = 1.23,
		-- The fenders' undersides (1.18 up) less a hair, less the radius: the highest a
		-- wheel's centre is drawn, so a compressed spring never pushes a tyre into them.
		wheelLift = 0.15,
		meshes = { body = "veh_atv_body", wheel = "veh_atv_wheel" },
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
	part.CastShadow = false -- small moving pieces: no shadow (the big panels turn it back on)
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
	-- The middle of the side, clear of the wheels.
	label.Size = UDim2.fromScale(0.36, 0.4)
	label.Position = UDim2.fromScale(0.32, 0.3)
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

-- Defined after `build`, which reads better first.
local partBody: (Model, BasePart) -> ()
local partWheel: (Body, BasePart) -> BasePart

-- A piece that only shows: no collision, queries, touch or mass; anchored with the chassis.
local function lookOnly(part: BasePart, root: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = root.Anchored
end

-- A copy of mesh `name`: MeshAssets' template on the server, the published copy on a client.
local function meshOf(name: string): MeshPart?
	if RunService:IsServer() then
		return MeshAssets.clone(name)
	end
	local folder = ReplicatedStorage:FindFirstChild(CLIENT_FOLDER)
	local template = folder and folder:FindFirstChild(name)
	return if template and template:IsA("MeshPart") then template:Clone() else nil
end

-- Server: yields until every body's meshes are loaded (or `timeout` passes), so a build at
-- boot (the motor pool's display) wears them.
function VehicleBody.waitForMeshes(timeout: number)
	for _, body in VehicleBody.Bodies do
		local meshes = body.meshes
		if meshes then
			for _, name in { meshes.body, meshes.wheel } do
				local copy = MeshAssets.waitFor(name, timeout)
				if copy then
					copy:Destroy()
				end
			end
		end
	end
end

-- Server: copies every body's meshes to ReplicatedStorage once loaded, for the clients'
-- builds (the arrival's slung stand-in). Yields; call from a task.
function VehicleBody.publish(timeout: number)
	-- Parented first and filled as each mesh loads, so a slow one never holds back the rest.
	local folder = Instance.new("Folder")
	folder.Name = CLIENT_FOLDER
	folder.Parent = ReplicatedStorage
	for _, body in VehicleBody.Bodies do
		local meshes = body.meshes
		if meshes then
			for _, name in { meshes.body, meshes.wheel } do
				local copy = MeshAssets.waitFor(name, timeout)
				if copy then
					copy.Parent = folder
				end
			end
		end
	end
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
	-- Always the root of its assembly, riders included: with the meshes the engine picked the
	-- seated soldier's HumanoidRootPart, so the ATV jumped to the rider when they got on and
	-- moved as part of the character (Nova, 2026-11-17).
	root.RootPriority = 127
	-- Heavier than its riders, so a seated soldier does not tip it.
	root.CustomPhysicalProperties = PhysicalProperties.new(3, 0.6, 0.1)
	root.Parent = model
	model.PrimaryPart = root

	-- The meshes when both are loaded; otherwise the Part body below.
	local meshes = body.meshes
	local shell = if meshes then meshOf(meshes.body) else nil
	local wheelMesh = if meshes and shell then meshOf(meshes.wheel) else nil
	if shell and meshes and wheelMesh then
		lookOnly(shell, root)
		shell.Name = "Body"
		shell.CastShadow = true
		shell.CFrame = root.CFrame * CFrame.new(MeshAssets.getOffset(meshes.body))
		if not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = shell
			weld.Parent = shell
		end
		shell.Parent = model
		root.Transparency = 1
	else
		if shell then
			shell:Destroy()
		end
		wheelMesh = nil
		-- A riser on the chassis lifts the bodywork clear of the wheels; fenders over each
		-- axle, the tank between them (the driver's seat on it), the raised back seat on the
		-- rear deck, the roll bar behind it, a brush guard on the front rack. Pieces touch,
		-- never overlap. Only the big panels cast a shadow. (Drawn for the first body's
		-- wheels: on the measured ones the seats sit low in it.)
		partBody(model, root)
	end

	-- The wheels: the mesh, or a tyre and a spoke (so the spin shows), on a Weld from the
	-- chassis at their rest height; VehicleController moves the welds' C0. A left wheel
	-- turns half round in C1, which nothing else writes.
	for index, wheel in body.wheels do
		-- At rest the ground is `rest` under the centre, so the wheel's centre is a radius up.
		local centre = Vector3.new(wheel.mount.X, body.wheelRadius - body.rest, wheel.mount.Z)
		local tyre: BasePart
		local turn = CFrame.identity
		if wheelMesh and meshes then
			tyre = wheelMesh:Clone()
			lookOnly(tyre, root)
			local half = if wheel.mount.X < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			turn = half * CFrame.new(MeshAssets.getOffset(meshes.wheel))
		else
			tyre = partWheel(body, root)
		end
		tyre.Name = `Wheel{index}`
		tyre.CFrame = root.CFrame * CFrame.new(centre) * turn
		tyre:SetAttribute("Mount", wheel.mount)
		tyre:SetAttribute("Front", wheel.front)
		local spoke = tyre:FindFirstChild("Spoke") :: BasePart?
		if spoke then
			local outward = if wheel.mount.X < 0 then -1 else 1
			spoke.CFrame = tyre.CFrame * CFrame.new(outward * (body.wheelWidth / 2 + 0.05), 0, 0)
		end
		if not anchored then
			local weld = Instance.new("Weld")
			weld.Name = "Axle"
			weld.Part0 = root
			weld.Part1 = tyre
			weld.C0 = CFrame.new(centre)
			weld.C1 = turn:Inverse()
			weld.Parent = tyre
			if spoke then
				local hub = Instance.new("WeldConstraint")
				hub.Part0 = tyre
				hub.Part1 = spoke
				hub.Parent = spoke
			end
		end
		tyre.Parent = model
	end
	if wheelMesh then
		wheelMesh:Destroy()
	end

	if not anchored then
		seat(model, root, "DriverSeat", "VehicleSeat", body.driver)
		seat(model, root, "GunnerSeat", "Seat", body.gunner)
	end
	return model
end

-- The first body, from Parts (the fallback while the meshes load or where they cannot).
function partBody(model: Model, root: BasePart)
	local shade = piece(model, root, "Riser", Vector3.new(2.8, 0.3, 6), at(0, 0.8, 0), OLIVE_DARK)
	shade.CastShadow = true
	for _, panel in
		{
			piece(model, root, "FrontFender", Vector3.new(4.4, 0.3, 2.4), at(0, 1.1, 2.2), OLIVE),
			piece(model, root, "RearFender", Vector3.new(4.4, 0.3, 2.5), at(0, 1.1, -2.15), OLIVE),
			piece(model, root, "Tank", Vector3.new(1.8, 0.8, 1.9), at(0, 1.35, 0.05), OLIVE),
		}
	do
		panel.CastShadow = true
	end
	piece(
		model,
		root,
		"DriverPad",
		Vector3.new(1.3, 0.25, 1.4),
		at(0, 1.875, -0.15),
		POLYMER,
		Enum.Material.Fabric
	)
	piece(model, root, "Stem", Vector3.new(0.3, 0.8, 0.3), at(0, 1.65, 1.25), STEEL_DARK)
	piece(model, root, "Bars", Vector3.new(2.4, 0.2, 0.2), at(0, 2.15, 1.25), STEEL_DARK)
	piece(
		model,
		root,
		"BackCushion", -- never "GunnerSeat": that name is the Seat itself (VehicleService finds it)
		Vector3.new(1.5, 0.6, 1.4),
		at(0, 1.55, -2),
		POLYMER,
		Enum.Material.Fabric
	)
	piece(model, root, "RollBarL", Vector3.new(0.25, 2, 0.25), at(-1.3, 2.25, -3), STEEL_DARK)
	piece(model, root, "RollBarR", Vector3.new(0.25, 2, 0.25), at(1.3, 2.25, -3), STEEL_DARK)
	piece(model, root, "RollBarTop", Vector3.new(2.85, 0.25, 0.25), at(0, 3.375, -3), STEEL_DARK)
	piece(model, root, "RackFront", Vector3.new(3.2, 0.15, 0.15), at(0, 1.325, 3.2), STEEL_DARK)
	piece(model, root, "RackBack", Vector3.new(3.2, 0.15, 0.15), at(0, 1.325, 2.4), STEEL_DARK)
	piece(model, root, "RackL", Vector3.new(0.15, 0.15, 0.65), at(-1.525, 1.325, 2.8), STEEL_DARK)
	piece(model, root, "RackR", Vector3.new(0.15, 0.15, 0.65), at(1.525, 1.325, 2.8), STEEL_DARK)
	-- The brush guard: two uprights on the front rail and a bar across their tops.
	piece(model, root, "GuardL", Vector3.new(0.15, 0.6, 0.15), at(-1.1, 1.7, 3.2), STEEL_DARK)
	piece(model, root, "GuardR", Vector3.new(0.15, 0.6, 0.15), at(1.1, 1.7, 3.2), STEEL_DARK)
	piece(model, root, "GuardTop", Vector3.new(2.35, 0.15, 0.15), at(0, 2.075, 3.2), STEEL_DARK)
	piece(model, root, "JerryCan", Vector3.new(0.5, 0.8, 0.9), at(-1.7, 1.65, -2.7), OLIVE)
	for _, side in { -1, 1 } do
		piece(
			model,
			root,
			"Headlight",
			Vector3.new(0.5, 0.3, 0.1),
			at(side * 0.9, 1.1, 3.45),
			LAMP,
			Enum.Material.Neon
		)
	end
	stencil(root, Enum.NormalId.Left)
	stencil(root, Enum.NormalId.Right)
end

-- A tyre (a cylinder along X) and its spoke, both placed by the caller: the first body's wheel.
function partWheel(body: Body, root: BasePart): BasePart
	local tyre = Instance.new("Part")
	tyre.Shape = Enum.PartType.Cylinder
	tyre.Size = Vector3.new(body.wheelWidth, body.wheelRadius * 2, body.wheelRadius * 2)
	tyre.Color = RUBBER
	tyre.Material = Enum.Material.Rubber
	lookOnly(tyre, root)
	local spoke = Instance.new("Part")
	spoke.Name = "Spoke"
	spoke.Size = Vector3.new(0.1, body.wheelRadius * 1.3, 0.35)
	spoke.Color = STEEL_DARK
	spoke.Material = Enum.Material.Metal
	lookOnly(spoke, root)
	spoke.Parent = tyre
	return tyre
end

return VehicleBody
