--!strict
-- Which 3D model each attachment option wears on the gun (attachment visuals, Nova 2026-11-20),
-- one typed record per option. The option's own row names its model (Config.AttachmentsV2
-- .Options.<id>.Visual, Config.Optics.<id>.Visual); MODELS below are the free Creator Store
-- meshes they name (free only, never paid; assets/3d/ASSET_IDS.md lists them). The record's
-- mount is its slot's (Shared.Attachments.MountPoints). An option with no Visual, or whose
-- model is not here, is stats only (docs/PROGRESSION.md > Attachments lists the missing ones).
-- AttachmentMeshService builds each model once on the server; VisualApplier puts them on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MountPoints = require(script.Parent.MountPoints)

local VisualRegistry = {}

-- A model's long axis lies along the gun (`forward`: a scope, a muzzle device), hangs below
-- it (`down`: a grip, a bipod's legs) or across it (`side`). `length` is the studs that long
-- axis is scaled to (the gun's scale: the M16A4 is 3.1 long). `anchor`: the face that meets the
-- mount (`bottom`: sits on the rail; `top`: hangs under it; `back`: out from the muzzle).
-- Each mesh comes facing the gun's way (seen in Studio 2026-11-20): it is scaled along that
-- axis, never turned. The CompM2 found (Aimpoint1, 76899261380970) is not a valid mesh asset.
export type Model = {
	assetId: number, -- the Creator Store asset (free)
	meshId: string,
	textureId: string?,
	long: "forward" | "down" | "side",
	length: number,
	anchor: "bottom" | "top" | "back",
	source: string, -- its name and creator, for the record
}

VisualRegistry.MODELS = {
	att_acog = {
		assetId = 430309581,
		meshId = "rbxassetid://430309559",
		long = "forward",
		length = 0.5,
		anchor = "bottom",
		source = "Meshes/ACOG by pablospanish",
	},
	att_flash_hider = {
		assetId = 430309776,
		meshId = "rbxassetid://430309763",
		long = "forward",
		length = 0.22,
		anchor = "back",
		source = "Meshes/FLASHHIDER by pablospanish",
	},
	att_vertical_grip = {
		assetId = 10865495614,
		meshId = "rbxassetid://10865495504",
		long = "down",
		length = 0.38,
		anchor = "top",
		source = "Grip Mesh by turohabaneero",
	},
	att_bipod = {
		assetId = 430309677,
		meshId = "rbxassetid://430309657",
		long = "side",
		length = 0.8,
		anchor = "top",
		source = "Meshes/BIPOD by pablospanish",
	},
} :: { [string]: Model }

export type Entry = {
	option: string,
	model: string, -- a MODELS key
	slot: string,
	mount: string, -- MountPoints
}

local ENTRIES: { [string]: Entry } = {}
local function add(id: string, row: any)
	local model = row.Visual
	local mount = row.Slot and MountPoints.SCHEMA.slots[row.Slot]
	if type(model) == "string" and VisualRegistry.MODELS[model] and type(mount) == "string" then
		ENTRIES[id] = { option = id, model = model, slot = row.Slot, mount = mount }
	end
end
for id, row in Config.AttachmentsV2.Options :: { [string]: any } do
	add(id, row)
end
for id, row in Config.Optics :: { [string]: any } do
	add(id, { Visual = row.Visual, Slot = "Optic" })
end
VisualRegistry.Entries = ENTRIES

function VisualRegistry.get(optionId: string?): Entry?
	return if optionId then ENTRIES[optionId] else nil
end

return VisualRegistry
