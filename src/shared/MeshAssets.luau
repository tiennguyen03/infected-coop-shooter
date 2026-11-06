--!strict
-- MeshAssets: low-poly MeshPart templates for the props/weapons/pickups built in Blender
-- (assets/3d). The server builds each template once at boot with
-- InsertService:CreateMeshPartAsync, which is the only path that gives a MeshPart its real
-- mesh bounds (a MeshPart created by setting MeshId through Rojo sync renders at the wrong
-- scale: MeshSize stays 0). Services call `MeshAssets.clone(name)` and fall back to their old
-- placeholder Part when it returns nil (template missing or still loading), so a slow asset
-- fetch never breaks gameplay. Asset ids are recorded in assets/3d/ASSET_IDS.md.

local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MeshAssets = {}

-- Shared palette texture (assets/3d/palette.png as an Image asset).
local PALETTE_TEXTURE = "rbxassetid://87519201884536"

type MeshDef = { meshId: string, size: Vector3 }

-- `size` is the in-game size in studs (the mesh is scaled to it). Blender sizes are in
-- assets/3d/README.md; rifle is 0.65x and drone 0.8x of the Blender size.
local MESHES: { [string]: MeshDef } = {
	pick_xp_orb = { meshId = "rbxassetid://95196197176639", size = Vector3.new(1, 1, 1) },
	prop_ammo_crate = {
		meshId = "rbxassetid://70908704628683",
		size = Vector3.new(2.86, 1.68, 1.92),
	},
	prop_repulsor_mine = {
		meshId = "rbxassetid://122106813224951",
		size = Vector3.new(1.9, 0.97, 2),
	},
	prop_drone = { meshId = "rbxassetid://132929388031760", size = Vector3.new(1.94, 0.43, 1.94) },
	prop_drone_beacon = {
		meshId = "rbxassetid://117405323536844",
		size = Vector3.new(1.56, 3.21, 1.36),
	},
	wpn_rifle = { meshId = "rbxassetid://86613539481097", size = Vector3.new(0.195, 0.84, 2.9) },
}

local templates: { [string]: MeshPart } = {}
local warned: { [string]: boolean } = {}

local function buildTemplate(folder: Folder, name: string, def: MeshDef)
	local ok, result = pcall(function()
		-- Positional form: (meshId, collisionFidelity, renderFidelity). The options-table
		-- form documented elsewhere fails here with "Argument 3 missing or nil".
		return InsertService:CreateMeshPartAsync(
			def.meshId,
			Enum.CollisionFidelity.Box,
			Enum.RenderFidelity.Automatic
		)
	end)
	if not ok or typeof(result) ~= "Instance" then
		warn(`MeshAssets: could not build {name}: {tostring(result)}`)
		return
	end
	local part = result :: MeshPart
	part.Name = name
	part.TextureID = PALETTE_TEXTURE
	part.Size = def.size
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	templates[name] = part
end

-- Server only. Templates fill in asynchronously; clone() returns nil until a template is ready.
function MeshAssets.init()
	if not RunService:IsServer() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MeshTemplates"
	folder.Parent = ServerStorage
	for name, def in MESHES do
		task.spawn(buildTemplate, folder, name, def)
	end
end

function MeshAssets.clone(name: string): MeshPart?
	local template = templates[name]
	if template then
		return template:Clone()
	end
	if not warned[name] then
		warned[name] = true
		warn(`MeshAssets: template {name} not ready or missing; using placeholder`)
	end
	return nil
end

return MeshAssets
