--!strict
-- The optics as typed records (Nova, 2026-11-18: the M16A4's optic slot), one per row of
-- Config.Optics: every number comes from that row, and no list of optic names lives here or
-- anywhere else. Rules/AttachmentRules takes `Optics.Rows` for buying and fitting,
-- Rules/AttachmentMerge applies an optic's multipliers, and WeaponDefinitions.options offers
-- an optic in the Optic slot of each gun it lists. Each optic's `fits` (Config.Optics rows'
-- Fit) name, per gun, the mesh of that gun with the optic on and its sight on that mesh;
-- WeaponDefinitions.dressed puts them together.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AttachmentRules = require(ReplicatedStorage.Shared.Rules.AttachmentRules)

local Optics = {}

-- A gun with this optic on: its mesh (MeshAssets) and its sight's points on that mesh.
export type Fit = {
	model: string,
	sight: { Rear: Vector3, Front: Vector3, Kind: string? },
}

-- A red-dot sight's dot (Config.Optics rows' Reticle; DotSightView draws it).
export type Reticle = { size: number, glow: number, color: Color3 }

export type Optic = AttachmentRules.Optic & {
	fits: { [string]: Fit }, -- by gun id
	reticle: Reticle?,
}

local ROWS: { [string]: Optic } = {}
for id, row in Config.Optics do
	local fits: { [string]: Fit } = {}
	for gunId, fit in row.Fit do
		fits[gunId] = { model = fit.Model, sight = table.clone(fit.Sight) }
	end
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		description = row.Description,
		compatibleGuns = table.clone(row.Guns),
		zoomMultiplier = row.ZoomMultiplier,
		adsTimeMultiplier = row.AdsTimeMultiplier,
		meritCost = row.Price,
		fits = fits,
		reticle = if row.Reticle
			then { size = row.Reticle.Size, glow = row.Reticle.Glow, color = row.Reticle.Color }
			else nil,
	}
end

Optics.SLOT = AttachmentRules.SLOT
-- Every optic by id, the shape Rules/AttachmentRules takes.
Optics.Rows = (ROWS :: any) :: AttachmentRules.Optics

function Optics.get(id: string?): Optic?
	return if id then ROWS[id] else nil
end

-- Gun `gunId` with optic `id` on (nil: no such optic, or it does not fit that gun).
function Optics.fit(id: string?, gunId: string): Fit?
	local optic = Optics.get(id)
	if not optic or not AttachmentRules.fits(optic, gunId) then
		return nil
	end
	return optic.fits[gunId]
end

-- The optic ids gun `gunId` takes, cheapest first.
function Optics.idsFor(gunId: string): { string }
	local ids: { string } = {}
	for _, optic in AttachmentRules.forGun(Optics.Rows, gunId) do
		table.insert(ids, optic.id)
	end
	return ids
end

return Optics
