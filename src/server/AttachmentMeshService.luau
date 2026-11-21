--!strict
-- The attachment models (Shared.Attachments.VisualRegistry.MODELS), built once at boot with
-- InsertService:CreateMeshPartAsync (the only path that gives a MeshPart its real bounds;
-- MeshAssets) into ReplicatedStorage.AttachmentMeshes, where every client's VisualApplier
-- copies them. A model that fails to load (a removed asset, or third-party loading off in the
-- experience's settings) is warned once and stays stats only. Nothing is rendered here.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualRegistry = require(ReplicatedStorage.Shared.Attachments.VisualRegistry)

local AttachmentMeshService = {}

AttachmentMeshService.FOLDER = "AttachmentMeshes"

local function build(folder: Folder, name: string, model: VisualRegistry.Model)
	local ok, part = pcall(function()
		return InsertService:CreateMeshPartAsync(
			model.meshId,
			Enum.CollisionFidelity.Box,
			Enum.RenderFidelity.Automatic
		)
	end)
	if not ok or not part then
		warn(`AttachmentMeshService: {name} ({model.meshId}) did not load: {part}`)
		return
	end
	local mesh = part :: MeshPart
	mesh.Name = name
	if model.textureId then
		mesh.TextureID = model.textureId
	end
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	mesh.Massless = true
	mesh.Parent = folder
end

function AttachmentMeshService.init()
	local folder = Instance.new("Folder")
	folder.Name = AttachmentMeshService.FOLDER
	folder.Parent = ReplicatedStorage
	for name, model in VisualRegistry.MODELS do
		task.spawn(build, folder, name, model)
	end
end

return AttachmentMeshService
