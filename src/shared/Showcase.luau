--!strict
-- The Loadout screen's models (LoadoutMenu's inspect view and row shapes; docs/STYLES.md
-- section 5 > Loadout screen). Mesh templates live on the server only (MeshAssets), so at boot
-- the server puts one look-only Model per item into ReplicatedStorage.Showcase, named by the
-- item's id, built from the item's own row: a gun's Model (WeaponDefinitions), a grenade's
-- Model, a call-in's Show pieces (CallInDefinitions). The client takes a copy with `get`; an
-- item with no model yet (or whose mesh has not loaded) gets a plain stand-in: a gun-sized
-- block, a grenade, a vehicle's own parts body (VehicleBody), or a case banded in the
-- call-in's colour. The Carrier's desk screens (lobby DeskScreen) show the same models.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local VehicleBody = require(ReplicatedStorage.Shared.VehicleBody)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local Showcase = {}

Showcase.FOLDER = "Showcase"

local OLIVE = Color3.fromRGB(74, 80, 58)
local STEEL = Color3.fromRGB(58, 60, 64)

local function lookOnly(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function block(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
)
	local part = Instance.new("Part")
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	lookOnly(part)
	part.Parent = model
	return part
end

-- The stand-in for an item with no model (built on the client, never stored).
local function standIn(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	if WeaponDefinitions.exists(id) then
		local size = MeshAssets.getSize(WeaponDefinitions.get(id).Model)
			or Vector3.new(0.25, 0.8, 2.8)
		block(model, size, CFrame.new(0, size.Y / 2, 0), STEEL)
	elseif WeaponDefinitions.Grenades[id] then
		-- A frag: the body, its spoon and the ring.
		block(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.25, 0), OLIVE, Enum.PartType.Ball)
		block(model, Vector3.new(0.12, 0.28, 0.08), CFrame.new(0.17, 0.5, 0), STEEL)
		block(
			model,
			Vector3.new(0.14, 0.12, 0.12),
			CFrame.new(0, 0.55, 0),
			STEEL,
			Enum.PartType.Cylinder
		)
	else
		-- A vehicle call-in (its Config row has a `Vehicle` block) shows its own body, the
		-- one the match drives and the motor pool parks (VehicleBody, anchored parts).
		local row = CallInDefinitions.get(id)
		local tuning = row and (Config.CallIns :: any)[row.ConfigKey]
		local vehicle = tuning and tuning.Vehicle
		local body = vehicle and VehicleBody.build(vehicle.Body, CFrame.new(), true)
		if body then
			for _, part in body:GetDescendants() do
				if part:IsA("BasePart") then
					lookOnly(part)
				end
			end
			body.Name = id
			return body
		end
		-- A slung case with a band in the call-in's colour and a handle.
		block(model, Vector3.new(1.4, 1.1, 2.2), CFrame.new(0, 0.55, 0), OLIVE)
		block(
			model,
			Vector3.new(1.46, 1.16, 0.3),
			CFrame.new(0, 0.55, 0),
			if row then row.Color else STEEL
		)
		block(model, Vector3.new(0.16, 0.16, 0.9), CFrame.new(0, 1.2, 0), STEEL)
	end
	return model
end

-- A copy of item `id`'s model to show (the stored one, or a stand-in). Client or server.
function Showcase.get(id: string): Model
	local folder = ReplicatedStorage:FindFirstChild(Showcase.FOLDER)
	local stored = folder and folder:FindFirstChild(id)
	if stored and stored:IsA("Model") then
		return stored:Clone()
	end
	return standIn(id)
end

-- Fires `callback(id)` when an item's stored model arrives (the meshes load after boot).
function Showcase.onArrived(callback: (id: string) -> ()): RBXScriptConnection?
	local folder = ReplicatedStorage:FindFirstChild(Showcase.FOLDER)
	if not folder then
		return nil
	end
	return folder.ChildAdded:Connect(function(child)
		callback(child.Name)
	end)
end

-- --------------------------------------------------------------- server: building them
type Piece = { Mesh: string, Height: number? }

local function build(folder: Folder, id: string, pieces: { Piece })
	local model = Instance.new("Model")
	model.Name = id
	for _, piece in pieces do
		local part = MeshAssets.waitFor(piece.Mesh, Config.LoadoutScreen.TemplateWait)
		if not part then
			return -- a piece missing: the client keeps the stand-in
		end
		part:ClearAllChildren()
		lookOnly(part)
		part.CFrame = CFrame.new(0, piece.Height or 0, 0)
			* CFrame.new(MeshAssets.getOffset(piece.Mesh))
		part.Parent = model
		if not model.PrimaryPart then
			model.PrimaryPart = part
		end
	end
	model.Parent = folder
end

function Showcase.init()
	if not RunService:IsServer() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = Showcase.FOLDER
	folder.Parent = ReplicatedStorage
	for _, id in WeaponDefinitions.allIds() do
		task.spawn(build, folder, id, { { Mesh = WeaponDefinitions.get(id).Model } })
		-- The gun with each optic it takes on (the Loadmaster's EDIT): "<gun>+<optic>".
		local optics: { string } = WeaponDefinitions.options(id).Optic or {}
		for _, opticId in optics do
			local mesh = WeaponDefinitions.dressed(id, opticId)
			if mesh ~= WeaponDefinitions.get(id).Model then
				task.spawn(
					build,
					folder,
					WeaponDefinitions.dressedId(id, opticId),
					{ { Mesh = mesh } }
				)
			end
		end
	end
	for id, grenade in WeaponDefinitions.Grenades do
		local mesh = grenade.Model
		if mesh then
			task.spawn(build, folder, id, { { Mesh = mesh } })
		end
	end
	for id, row in CallInDefinitions.Rows do
		local show = row.Show
		if show then
			task.spawn(build, folder, id, show)
		end
	end
end

return Showcase
