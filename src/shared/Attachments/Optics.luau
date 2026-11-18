--!strict
-- The optics as typed records (Nova, 2026-11-18: the M16A4's optic slot), one per row of
-- Config.Optics: every number comes from that row, and no list of optic names lives here or
-- anywhere else. Rules/AttachmentRules takes `Optics.Rows` for buying and fitting,
-- Rules/AttachmentMerge applies an optic's multipliers, and WeaponDefinitions.options offers
-- an optic in the Optic slot of each gun it lists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AttachmentRules = require(ReplicatedStorage.Shared.Rules.AttachmentRules)

local Optics = {}

export type Optic = AttachmentRules.Optic & {
	model: string?, -- its mesh (MeshAssets) once uploaded; nil = not shown on the gun yet
}

local ROWS: { [string]: Optic } = {}
for id, row in Config.Optics do
	ROWS[id] = {
		id = id,
		displayName = row.Name,
		description = row.Description,
		compatibleGuns = table.clone(row.Guns),
		zoomMultiplier = row.ZoomMultiplier,
		adsTimeMultiplier = row.AdsTimeMultiplier,
		meritCost = row.Price,
		model = row.Model,
	}
end

Optics.SLOT = AttachmentRules.SLOT
-- Every optic by id, the shape Rules/AttachmentRules takes.
Optics.Rows = (ROWS :: any) :: AttachmentRules.Optics

function Optics.get(id: string?): Optic?
	return if id then ROWS[id] else nil
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
