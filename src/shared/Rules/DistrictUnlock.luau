--!strict
-- Kit that unlocks with missions won in a city district (loop sprint 4; design:
-- docs/superpowers/specs/2026-11-20-game-loop-design.md section 7; tests/DistrictUnlock.spec).
-- An item row may carry `Unlock = { District = "MILE 14", Wins = 3 }` next to its Price: the
-- sale opens once the soldier's record (`wins`, counted with the pay by MeritService) has that
-- many wins there. It is still bought once with merits, and it is a sidegrade, never a
-- stronger version (docs/OWNER.md). Boss fragments will reuse the same field later.

local DistrictUnlock = {}

export type Unlock = { District: string, Wins: number }

-- Whether `unlock` (nil = none) is met by `wins` (district name -> missions won).
function DistrictUnlock.met(unlock: Unlock?, wins: { [string]: number }): boolean
	if unlock == nil then
		return true
	end
	if typeof(unlock.District) ~= "string" or typeof(unlock.Wins) ~= "number" then
		return false
	end
	return (wins[unlock.District] or 0) >= unlock.Wins
end

-- What it takes, for the shop: "WIN 3 AT MILE 14 (1/3)" ("" when there is nothing to win).
function DistrictUnlock.text(unlock: Unlock?, wins: { [string]: number }): string
	if unlock == nil then
		return ""
	end
	local have = math.min(wins[unlock.District] or 0, unlock.Wins)
	return `WIN {unlock.Wins} AT {unlock.District} ({have}/{unlock.Wins})`
end

-- The line a refused buy shows: "Win 3 missions at MILE 14 first." ("" when nothing to win).
function DistrictUnlock.need(unlock: Unlock?): string
	if unlock == nil then
		return ""
	end
	if unlock.Wins == 1 then
		return `Win a mission at {unlock.District} first.`
	end
	return `Win {unlock.Wins} missions at {unlock.District} first.`
end

return DistrictUnlock
