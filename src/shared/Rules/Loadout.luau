--!strict
-- The Arms Room rules (docs/PROGRESSION.md > Loadout): pure, unit-tested with Lune
-- (tests/Loadout.spec.luau). A loadout is one primary, one secondary, one grenade and one
-- call-in per slot, all different. The catalog (what is on offer) is passed in, so the
-- same rules serve the in-run menu (LoadoutService.apply) and the lobby's Loadmaster
-- (LoadmasterService), and re-check a Loadout arriving as teleport data (HandoffService).

local Loadout = {}

export type Loadout = {
	primary: string,
	secondary: string,
	grenade: string,
	callIns: { string }, -- [slot] = call-in id
	-- What is fitted to each gun (the Loadmaster's EDIT, Nova 2026-11-11): [gun id][slot] =
	-- option ("service_rifle" -> "Barrel" -> "suppressor"). Kept per gun, carried or not; nil
	-- or missing = bare.
	attachments: Attachments?,
}

export type Attachments = { [string]: { [string]: string } }

export type Catalog = {
	primaries: { string }, -- the first is the default
	secondaries: { string },
	grenades: { string },
	callIns: { string }, -- every call-in on offer, in menu order
	preferredCallIns: { string }?, -- the default's first slots (unknown ids are skipped)
	slots: number,
	-- What each gun can take: [gun id][slot] = the options (WeaponDefinitions.options).
	attachments: { [string]: { [string]: { string } } }?,
}

export type GateState = {
	phase: string, -- RunStates name
	lzDistance: number, -- studs from the LZ pad
	calmFor: number, -- seconds since this soldier last dealt or took damage
	alive: boolean, -- standing (not downed, not dead)
}

export type GateSettings = {
	lzRadius: number,
	calmSeconds: number,
}

-- Phases where the field is not in play: the menu is always open.
local OPEN_PHASES = { Lobby = true, Insert = true, Ended = true }

-- How many call-in slots a loadout fills: the slot count, or fewer on a short catalog.
local function slotCount(catalog: Catalog): number
	return math.min(catalog.slots, #catalog.callIns)
end

function Loadout.default(catalog: Catalog): Loadout
	local callIns: { string } = {}
	local wanted = slotCount(catalog)
	local function add(id: string)
		if
			#callIns < wanted
			and table.find(catalog.callIns, id)
			and not table.find(callIns, id)
		then
			table.insert(callIns, id)
		end
	end
	local preferred: { string } = catalog.preferredCallIns or {}
	for _, id in preferred do
		add(id)
	end
	for _, id in catalog.callIns do
		add(id)
	end
	return {
		primary = catalog.primaries[1],
		secondary = catalog.secondaries[1],
		grenade = catalog.grenades[1],
		callIns = callIns,
	}
end

-- A copy that shares no tables with `loadout`.
function Loadout.copy(loadout: Loadout): Loadout
	local attachments: Attachments? = nil
	if loadout.attachments then
		local copied: Attachments = {}
		for gun, slots in loadout.attachments do
			copied[gun] = table.clone(slots)
		end
		attachments = copied
	end
	return {
		primary = loadout.primary,
		secondary = loadout.secondary,
		grenade = loadout.grenade,
		callIns = table.clone(loadout.callIns),
		attachments = attachments,
	}
end

-- What is fitted to `gun` in `slot`, or nil.
function Loadout.fitted(attachments: Attachments?, gun: string, slot: string): string?
	local slots = attachments and attachments[gun]
	return slots and slots[slot]
end

-- The attachments as one attribute string ("gun.Slot=option;..."), sorted, and back. The
-- player's Fitted attribute (LoadoutService) carries it to every client.
function Loadout.encodeFitted(attachments: Attachments?): string
	local parts = {}
	local list: Attachments = attachments or {}
	for gun, slots in list do
		for slot, option in slots do
			table.insert(parts, `{gun}.{slot}={option}`)
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function Loadout.decodeFitted(text: string): Attachments
	local attachments: Attachments = {}
	for entry in string.gmatch(text, "[^;]+") do
		local gun, slot, option = string.match(entry, "^([^.=]+)%.([^.=]+)=(.+)$")
		if gun and slot and option then
			attachments[gun] = attachments[gun] or {}
			attachments[gun][slot] = option
		end
	end
	return attachments
end

-- (true, nil) or (false, reason). `loadout` is untrusted (it comes off a remote).
function Loadout.validate(loadout: unknown, catalog: Catalog): (boolean, string?)
	if typeof(loadout) ~= "table" then
		return false, "malformed"
	end
	local candidate = loadout :: { [string]: unknown }
	local function pick(key: string, list: { string }): boolean
		local value = candidate[key]
		return typeof(value) == "string" and table.find(list, value) ~= nil
	end
	if not pick("primary", catalog.primaries) then
		return false, "primary"
	end
	if not pick("secondary", catalog.secondaries) then
		return false, "secondary"
	end
	if not pick("grenade", catalog.grenades) then
		return false, "grenade"
	end
	local callIns = candidate.callIns
	if typeof(callIns) ~= "table" then
		return false, "call-ins"
	end
	local list = callIns :: { [unknown]: unknown }
	local wanted = slotCount(catalog)
	local seen: { [string]: boolean } = {}
	local count = 0
	for _ in list do
		count += 1
	end
	if count ~= wanted then
		return false, "call-ins"
	end
	for slot = 1, wanted do
		local id = list[slot]
		if typeof(id) ~= "string" or not table.find(catalog.callIns, id) then
			return false, "call-ins"
		end
		if seen[id] then
			return false, "duplicate call-in"
		end
		seen[id] = true
	end
	-- Attachments: only options the catalog lists for that gun and slot.
	local attachments = candidate.attachments
	if attachments ~= nil then
		if typeof(attachments) ~= "table" then
			return false, "attachments"
		end
		local offered = catalog.attachments or {}
		for gun, slots in attachments :: { [unknown]: unknown } do
			local gunOffers = typeof(gun) == "string" and offered[gun]
			if not gunOffers or typeof(slots) ~= "table" then
				return false, "attachments"
			end
			for slot, option in slots :: { [unknown]: unknown } do
				local options = typeof(slot) == "string" and gunOffers[slot]
				if not options or typeof(option) ~= "string" or not table.find(options, option) then
					return false, "attachments"
				end
			end
		end
	end
	return true, nil
end

-- The slots whose call-in differs between two loadouts (a changed slot starts empty with
-- its cooldown running), ascending.
function Loadout.changedSlots(old: { string }, new: { string }): { number }
	local changed = {}
	for slot = 1, math.max(#old, #new) do
		if old[slot] ~= new[slot] then
			table.insert(changed, slot)
		end
	end
	return changed
end

-- May this soldier change loadout now? (true, nil) or (false, reason).
function Loadout.canChange(state: GateState, settings: GateSettings): (boolean, string?)
	if OPEN_PHASES[state.phase] then
		return true, nil
	end
	if not state.alive then
		return false, "down"
	end
	if state.lzDistance > settings.lzRadius then
		return false, "away from the LZ"
	end
	if state.calmFor < settings.calmSeconds then
		return false, "in contact"
	end
	return true, nil
end

return Loadout
