--!strict
-- Lantern's manifest on one deck spot of the Fallow (the lobby place, docs/sprints/
-- LOBBY_V1_FALLOW.md): pure, unit-tested with Lune (tests/Manifest.spec.luau). Whoever
-- stands on the spot is aboard, in boarding order, up to `capacity`. The first one aboard
-- starts the countdown; a full bird shortens it, never lengthens it; an empty spot clears
-- it. Ids are UserIds; times are whatever clock the caller uses (LaunchService: os.clock).

local Manifest = {}

export type Manifest = {
	aboard: { number },
	liftAt: number?,
}

export type Settings = {
	capacity: number,
	countdown: number, -- seconds from the first soldier aboard to lift
	fullCountdown: number, -- seconds to lift once the bird is full
}

function Manifest.new(): Manifest
	return { aboard = {}, liftAt = nil }
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
		return { aboard = aboard, liftAt = nil }
	end
	local liftAt: number = manifest.liftAt or now + settings.countdown
	if #aboard >= settings.capacity then
		liftAt = math.min(liftAt, now + settings.fullCountdown)
	end
	return { aboard = aboard, liftAt = liftAt }
end

function Manifest.isAboard(manifest: Manifest, id: number): boolean
	return table.find(manifest.aboard, id) ~= nil
end

function Manifest.due(manifest: Manifest, now: number): boolean
	local liftAt = manifest.liftAt
	return liftAt ~= nil and #manifest.aboard > 0 and now >= liftAt
end

return Manifest
