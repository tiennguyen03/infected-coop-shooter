--!strict
-- Versions and migrations for every per-player save (docs/SAVES.md: the save shapes and the
-- steps to change one). Pure, unit-tested with Lune (tests/SaveSchema.spec.luau).
--
-- Each save kind has a schema: its current `version` and one `step` per version, step i
-- turning a version i-1 save into a version i one (a save with no version is version 0). A
-- stored save is read by running every step from its version up to the current one, so any
-- older save, today's unversioned ones included, comes out in the current shape. Steps only
-- add or rename: a field this code does not know is carried along untouched, and a currency
-- is never lowered.
--
-- `read` says what was stored: "empty" (no save yet), "ok" (migrated, the copy returned),
-- "newer" (written by newer code than this, during a rollout) or "junk" (not a save this code
-- understands). Only "empty" and "ok" may be written over (`writable`, `over`); a "newer" or
-- "junk" save is left exactly as it is and the session is read-only.

local SaveSchema = {}

export type Save = { [string]: any }
-- Turns a save one version older into this version; nil when it cannot (junk).
export type Step = (save: Save) -> Save?
export type Schema = {
	name: string,
	version: number,
	steps: { Step }, -- steps[i]: version i-1 -> version i
	valid: (save: Save) -> boolean, -- the current shape's must-haves, checked after migration
}
export type Status = "empty" | "ok" | "newer" | "junk"

-- The soldier's record (Rules/Record; DataStore Config.Lobby.Save.RecordStore, "r_<UserId>").
SaveSchema.Record = {
	name = "record",
	version = 2,
	steps = {
		-- 0 -> 1: an unversioned record. Merits and kit as they were.
		function(save: Save): Save?
			if typeof(save.merits) ~= "number" then
				return nil
			end
			if save.owned == nil then
				save.owned = {}
			end
			return save
		end,
		-- 1 -> 2: tabs (the hard currency) and Robux receipts paid; a value already there is kept.
		function(save: Save): Save?
			if save.tabs == nil then
				save.tabs = 0
			end
			if save.receipts == nil then
				save.receipts = {}
			end
			return save
		end,
	},
	valid = function(save: Save): boolean
		return typeof(save.merits) == "number" and save.merits == save.merits
	end,
} :: Schema

-- The Loadmaster's signed Loadout (Rules/LoadoutSave; DataStore Config.Lobby.Save.Store,
-- "u_<UserId>"). Whether the Loadout is still legal is the caller's check (today's catalog).
SaveSchema.Loadout = {
	name = "loadout",
	version = 1,
	steps = {
		-- 0 -> 1: a bare Loadout is wrapped; a table that already holds one is stamped.
		function(save: Save): Save?
			if typeof(save.loadout) == "table" then
				return save
			end
			if typeof(save.primary) == "string" then
				return { loadout = save }
			end
			return nil
		end,
	},
	valid = function(save: Save): boolean
		return typeof(save.loadout) == "table"
	end,
} :: Schema

-- The stored version: a whole number at or above 0, 0 when missing; nil when junk.
local function versionOf(save: Save): number?
	local version = save.version
	if version == nil then
		return 0
	end
	if typeof(version) ~= "number" or version ~= version or version < 0 then
		return nil
	end
	if version ~= math.floor(version) or version == math.huge then
		return nil
	end
	return version
end

-- What is stored, and (for "ok") a migrated copy in the current shape. The stored value is
-- never changed.
function SaveSchema.read(schema: Schema, stored: unknown): (Status, Save?)
	if stored == nil then
		return "empty", nil
	end
	if typeof(stored) ~= "table" then
		return "junk", nil
	end
	local from = versionOf(stored :: Save)
	if from == nil then
		return "junk", nil
	end
	if from > schema.version then
		return "newer", nil
	end
	local save: Save? = table.clone(stored :: Save)
	for version = from + 1, schema.version do
		save = schema.steps[version](save :: Save)
		if save == nil then
			return "junk", nil
		end
		save.version = version
	end
	local current = save :: Save
	current.version = schema.version
	if not schema.valid(current) then
		return "junk", nil
	end
	return "ok", current
end

-- Whether a server may write over this stored value: no save yet, or one this code reads.
function SaveSchema.writable(schema: Schema, stored: unknown): boolean
	local status = SaveSchema.read(schema, stored)
	return status == "empty" or status == "ok"
end

-- The value to store: the stored save, migrated, with `fields` written over it (every field
-- this code does not know is kept), stamped with the current version. nil when the stored
-- value may not be written over ("newer" or "junk").
function SaveSchema.over(schema: Schema, stored: unknown, fields: Save): Save?
	local status, migrated = SaveSchema.read(schema, stored)
	if status ~= "empty" and status ~= "ok" then
		return nil
	end
	local out: Save = if migrated then migrated else {}
	for key, value in fields do
		out[key] = value
	end
	out.version = schema.version
	return out
end

return SaveSchema
