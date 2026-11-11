--!strict
-- Lantern's manifest on one deck spot of the Fallow (the lobby place, docs/sprints/
-- LOBBY_V1_FALLOW.md): pure, unit-tested with Lune (tests/Manifest.spec.luau). Whoever
-- stands on the spot is aboard, in boarding order, up to `capacity`. The first one aboard
-- starts the countdown; a full bird shortens it, never lengthens it; an empty spot clears
-- it. The first one aboard may set the squad size (1 to capacity, `setSquad`): the bird is
-- full once that many are aboard, so a solo soldier lifts on the short countdown. Ids are UserIds; times are whatever clock the caller uses (LaunchService: os.clock).

local Manifest = {}

export type Manifest = {
	aboard: { number },
	liftAt: number?,
	squad: number?, -- the size the first aboard picked; nil = capacity
}

export type Settings = {
	capacity: number,
	countdown: number, -- seconds from the first soldier aboard to lift
	fullCountdown: number, -- seconds to lift once the bird is full
}

function Manifest.new(): Manifest
	return { aboard = {}, liftAt = nil, squad = nil }
end

-- How many aboard make the bird full.
local function fullAt(manifest: Manifest, settings: Settings): number
	return manifest.squad or settings.capacity
end

-- `present` is everyone standing on the spot right now. Returns a new manifest; the one
-- given is not changed.
function Manifest.update(
	manifest: Manifest,
	present: { number },
	now: number,
	settings: Settings
): Manifest
	local here: { [number]: boolean } = {}
	for _, id in present do
		here[id] = true
	end

	local aboard: { number } = {}
	local listed: { [number]: boolean } = {}
	for _, id in manifest.aboard do
		if here[id] and #aboard < settings.capacity then
			table.insert(aboard, id)
			listed[id] = true
		end
	end
	for _, id in present do
		if not listed[id] and #aboard < settings.capacity then
			table.insert(aboard, id)
			listed[id] = true
		end
	end

	if #aboard == 0 then
		return { aboard = aboard, liftAt = nil, squad = nil }
	end
	local liftAt: number = manifest.liftAt or now + settings.countdown
	if #aboard >= fullAt(manifest, settings) then
		liftAt = math.min(liftAt, now + settings.fullCountdown)
	end
	return { aboard = aboard, liftAt = liftAt, squad = manifest.squad }
end

-- The first soldier aboard (`id`) sets how many the bird waits for. Returns a new manifest
-- and whether it was accepted (anyone else, or a size outside 1 to capacity, is refused and
-- the manifest comes back as it was). A size already reached shortens the countdown at once.
function Manifest.setSquad(
	manifest: Manifest,
	id: number,
	size: number,
	now: number,
	settings: Settings
): (Manifest, boolean)
	local valid = manifest.aboard[1] == id
		and size == math.floor(size)
		and size >= 1
		and size <= settings.capacity
	if not valid then
		return manifest, false
	end
	local liftAt = manifest.liftAt
	if liftAt and #manifest.aboard >= size then
		liftAt = math.min(liftAt, now + settings.fullCountdown)
	end
	return { aboard = table.clone(manifest.aboard), liftAt = liftAt, squad = size }, true
end

function Manifest.isAboard(manifest: Manifest, id: number): boolean
	return table.find(manifest.aboard, id) ~= nil
end

function Manifest.due(manifest: Manifest, now: number): boolean
	local liftAt = manifest.liftAt
	return liftAt ~= nil and #manifest.aboard > 0 and now >= liftAt
end

return Manifest
