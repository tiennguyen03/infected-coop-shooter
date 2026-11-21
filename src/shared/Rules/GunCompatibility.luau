--!strict
-- Fittings that are allowed but worth a word (tests/GunCompatibility.spec.luau; the rollout to
-- every gun, Nova 2026-11-20). A refusal is Rules/AttachmentMerge's (incompatibleWith, both
-- ways, on the server); a warning never refuses anything: an option or a round may carry
-- `advice` = { unless = ids, text }, said when none of `unless` is fitted (subsonic rounds
-- without a suppressor: still loud, and less reach and punch for it). The menu shows it.

local GunCompatibility = {}

export type Advice = { unless: { string }, text: string }

type Entry = { advice: Advice? }
export type Catalog = { options: { [string]: any }, ammo: { [string]: any } }

-- What gun `gunId` with `fitting` ([slot] = id) should be told, in slot-name order.
function GunCompatibility.warnings(
	_gunId: string,
	fitting: { [string]: string },
	catalog: Catalog
): { string }
	local fitted: { string } = {}
	local slots: { string } = {}
	for slot, id in fitting do
		table.insert(fitted, id)
		table.insert(slots, slot)
	end
	table.sort(slots)
	local said: { string } = {}
	for _, slot in slots do
		local id = fitting[slot]
		local entry: Entry? = catalog.options[id] or catalog.ammo[id]
		local advice = entry and entry.advice
		if advice then
			local covered = false
			for _, other in advice.unless do
				if table.find(fitted, other) then
					covered = true
					break
				end
			end
			if not covered then
				table.insert(said, advice.text)
			end
		end
	end
	return said
end

return GunCompatibility
