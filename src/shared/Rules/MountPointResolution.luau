--!strict
-- Which mount on a gun's model an attachment slot's part goes on (tests/
-- MountPointResolution.spec.luau; the attachment visuals, Nova 2026-11-20). Pure: the schema
-- (Shared.Attachments.MountPoints) names each slot's mount, the gun's row names where its
-- mounts sit (Config.Weapons.<gun>.Mounts); this only looks one up.
--   (mount) | (nil, "slot": no such slot | "none": the slot puts nothing on the gun (ammo)
--   | "missing": this gun's model has no such mount; the applier skips it)

local MountPointResolution = {}

-- A mount: where on the gun (its grip's space, the same as its Sight points), and any turn.
export type Mount = { at: any, yaw: number? }
export type Mounts = { [string]: Mount }
-- Slot id -> its mount's name, or false: the slot has no part on the gun.
export type Schema = { slots: { [string]: string | false } }

function MountPointResolution.resolve(
	slotId: string,
	mounts: Mounts?,
	schema: Schema
): (Mount?, string?)
	local mountName = schema.slots[slotId]
	if mountName == nil then
		return nil, "slot"
	end
	if mountName == false then
		return nil, "none"
	end
	local mount = mounts and mounts[mountName :: string]
	if not mount then
		return nil, "missing"
	end
	return mount, nil
end

return MountPointResolution
