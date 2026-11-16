--!strict
-- The squad status panel's rules (client SquadPanelUI; pure, tests/SquadPanel.spec.luau):
-- what one row shows for a squadmate's replicated state, when it flashes, and the order of
-- the rows. Times are server time (workspace:GetServerTimeNow()); 0 means "not set".

local SquadPanel = {}

export type Status = "Normal" | "Low" | "Downed" | "Dead" | "Standby"
export type BarKind = "health" | "bleed" | "revive" | "none"

export type Input = {
	state: string?, -- the SquadState attribute; nil before the member's first body
	health: number,
	maxHealth: number,
	shield: number,
	bleedOutAt: number,
	reviver: string,
	reviveEndsAt: number,
	respawnAt: number,
}

export type Settings = {
	LowFraction: number,
	BleedOutSeconds: number,
	ReviveHold: number,
}

export type View = {
	status: Status,
	barKind: BarKind,
	bar: number, -- 0..1: health, bleed-out time left, or revive progress
	shield: number, -- 0..1 of max health
	text: string,
	ticking: boolean, -- a countdown is running: refresh on a timer
}

export type Entry = { key: string, callsign: string, userId: number }

local function fraction(value: number, max: number): number
	if max <= 0 then
		return 0
	end
	return math.clamp(value / max, 0, 1)
end

function SquadPanel.view(input: Input, now: number, settings: Settings): View
	if input.state == "Downed" then
		local left = if input.bleedOutAt > 0 then math.max(input.bleedOutAt - now, 0) else 0
		local reviving = input.reviver ~= ""
		if reviving and input.reviveEndsAt > 0 then
			return {
				status = "Downed",
				barKind = "revive",
				bar = 1 - fraction(input.reviveEndsAt - now, settings.ReviveHold),
				shield = 0,
				text = "REVIVING",
				ticking = true,
			}
		end
		return {
			status = "Downed",
			barKind = "bleed",
			bar = fraction(left, settings.BleedOutSeconds),
			shield = 0,
			text = if reviving
				then "REVIVING"
				elseif left > 0 then `DOWN {math.ceil(left)}s`
				else "DOWN",
			ticking = left > 0,
		}
	end
	if input.state == "Dead" then
		local left = if input.respawnAt > 0 then math.max(input.respawnAt - now, 0) else 0
		return {
			status = "Dead",
			barKind = "none",
			bar = 0,
			shield = 0,
			text = if left > 0 then `DEAD {math.ceil(left)}s` else "DEAD",
			ticking = left > 0,
		}
	end
	if input.state ~= "Alive" then
		return {
			status = "Standby",
			barKind = "none",
			bar = 0,
			shield = 0,
			text = "",
			ticking = false,
		}
	end
	local health = fraction(input.health, input.maxHealth)
	return {
		status = if health < settings.LowFraction then "Low" else "Normal",
		barKind = "health",
		bar = health,
		shield = fraction(input.shield, input.maxHealth),
		text = "",
		ticking = false,
	}
end

-- Whether the row flashes on this change: went down, died, or lost `bigHitFraction` of max
-- health in one hit while standing. A member seen for the first time never flashes.
function SquadPanel.flashes(
	oldState: string?,
	oldHealth: number,
	newState: string?,
	newHealth: number,
	maxHealth: number,
	bigHitFraction: number
): boolean
	if newState ~= oldState then
		return oldState ~= nil and (newState == "Downed" or newState == "Dead")
	end
	if newState ~= "Alive" or maxHealth <= 0 then
		return false
	end
	return (oldHealth - newHealth) / maxHealth >= bigHitFraction
end

-- The rows to show, in a stable order: the squad's callsign order, then the key. The
-- viewer's own entry is left out; at most `limit` rows.
function SquadPanel.order(
	entries: { Entry },
	callsigns: { string },
	viewerUserId: number,
	limit: number
): { Entry }
	local rank: { [string]: number } = {}
	for index, callsign in callsigns do
		rank[callsign] = index
	end
	local shown: { Entry } = {}
	for _, entry in entries do
		if entry.userId ~= viewerUserId then
			table.insert(shown, entry)
		end
	end
	local last = #callsigns + 1
	table.sort(shown, function(a, b)
		local rankA, rankB = rank[a.callsign] or last, rank[b.callsign] or last
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a.key < b.key
	end)
	for index = #shown, limit + 1, -1 do
		shown[index] = nil
	end
	return shown
end

return SquadPanel
