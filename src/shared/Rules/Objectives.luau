--!strict
-- The objective pools (docs/PROGRESSION.md > Objective pools): what a mission draws, whether
-- the pools are sound, and how progress reads. Pure, unit-tested with Lune
-- (tests/Objectives.spec.luau; tests/ObjectiveDefinitions.spec.luau runs `validate` over the
-- real pools). ObjectiveService feeds it a map's pool from ObjectiveDefinitions and random
-- rolls in 0..1 (passed in so a draw can be tested); ObjectiveUI uses the text helpers.

local Objectives = {}

export type State = "pending" | "active" | "done" | "failed"

-- One objective as the HUD sees it (the ObjectiveUpdate "board" message carries a list).
export type Entry = {
	slot: string, -- "main" | "side1" | "side2" ...
	role: string, -- "main" | "side"
	id: string,
	name: string,
	why: string,
	place: string,
	step: string, -- what to do now, in plain words
	done: number,
	total: number,
	unit: string, -- "s" | "count" | ""
	timeLeft: number?, -- seconds, when a timer runs
	state: State,
	position: Vector3,
}

export type Pick = { Id: string, Weight: number }

-- The parts of ObjectiveDefinitions that `validate` reads.
export type Row = {
	Kind: string,
	Map: string?,
	Role: string,
	Module: string,
	Name: string,
	Brief: string,
	Why: string,
	Done: string,
	Needs: { string },
}
export type Map = {
	Main: { Pick },
	Side: { Pick },
	Sites: { [string]: { { [string]: any } } },
}

Objectives.WHY_WORDS = 8 -- a reason is read in a fight

-- An index 1..count from a roll in 0..1 (0 when there is nothing to pick).
function Objectives.pick(count: number, roll: number): number
	if count <= 0 then
		return 0
	end
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

local function weighted(picks: { Pick }, roll: number): number
	local total = 0
	for _, pick in picks do
		total += math.max(pick.Weight, 0)
	end
	if #picks == 0 then
		return 0
	end
	if total <= 0 then
		return Objectives.pick(#picks, roll)
	end
	local at = math.clamp(roll, 0, 1) * total
	for index, pick in picks do
		at -= math.max(pick.Weight, 0)
		if at < 0 then
			return index
		end
	end
	return #picks
end

-- One id from `pool` by weight, never `last` when the pool holds anything else (a server
-- never plays the same main objective twice in a row).
function Objectives.draw(pool: { Pick }, last: string?, roll: number): string?
	local candidates = {}
	for _, pick in pool do
		if pick.Id ~= last then
			table.insert(candidates, pick)
		end
	end
	if #candidates == 0 then
		candidates = pool
	end
	local pick = candidates[weighted(candidates, roll)]
	return pick and pick.Id
end

-- Up to `count` different ids from `pool` by weight, one roll each. `forced` (a dev pick)
-- comes first.
function Objectives.drawSides(
	pool: { Pick },
	count: number,
	rolls: { number },
	forced: string?
): { string }
	local left = table.clone(pool)
	local drawn = {}
	if forced then
		for index, pick in left do
			if pick.Id == forced then
				table.remove(left, index)
				break
			end
		end
		table.insert(drawn, forced)
	end
	while #drawn < count and #left > 0 do
		local index = weighted(left, rolls[#drawn + 1] or 0)
		table.insert(drawn, (table.remove(left, index) :: Pick).Id)
	end
	return drawn
end

-- Whether `id` is in `pool` (a main objective the lobby asked for, a dev pick).
function Objectives.offers(pool: { Pick }, id: unknown): boolean
	for _, pick in pool do
		if pick.Id == id then
			return true
		end
	end
	return false
end

local function words(text: string): number
	local count = 0
	for _ in string.gmatch(text, "%S+") do
		count += 1
	end
	return count
end

-- Everything wrong with the pools, in words (empty when sound): a map may list only
-- objectives that exist, in the right pool, with a weight; a signature objective only on its
-- own map; every map has a signature main objective of its own; and every objective a map
-- lists has at least one site there with everything that objective needs.
function Objectives.validate(rows: { [string]: Row }, maps: { [string]: Map }): { string }
	local problems = {}
	for id, row in rows do
		if row.Kind ~= "shared" and row.Kind ~= "signature" then
			table.insert(problems, `{id}: Kind must be "shared" or "signature"`)
		end
		if row.Role ~= "main" and row.Role ~= "side" then
			table.insert(problems, `{id}: Role must be "main" or "side"`)
		end
		if row.Kind == "signature" and (row.Map == nil or maps[row.Map] == nil) then
			table.insert(problems, `{id}: a signature objective names its map`)
		end
		if row.Kind == "shared" and row.Map ~= nil then
			table.insert(problems, `{id}: a shared objective belongs to no map`)
		end
		for _, field in { "Name", "Brief", "Why", "Done", "Module" } do
			local value = (row :: any)[field]
			if typeof(value) ~= "string" or value == "" then
				table.insert(problems, `{id}: no {field}`)
			end
		end
		if typeof(row.Why) == "string" and words(row.Why) > Objectives.WHY_WORDS then
			table.insert(problems, `{id}: Why is over {Objectives.WHY_WORDS} words`)
		end
	end
	for mapId, map in maps do
		local signatureMain = false
		local pools: { [string]: { Pick } } = { main = map.Main, side = map.Side }
		for role, pool in pools do
			local seen: { [string]: boolean } = {}
			for _, pick in pool do
				local id = pick.Id
				local row = rows[id]
				if seen[id] then
					table.insert(problems, `{mapId}: {id} is listed twice`)
				end
				seen[id] = true
				if not row then
					table.insert(problems, `{mapId}: no objective "{id}"`)
					continue
				end
				if row.Role ~= role then
					table.insert(
						problems,
						`{mapId}: {id} is a {row.Role} objective in the {role} pool`
					)
				end
				if typeof(pick.Weight) ~= "number" or pick.Weight <= 0 then
					table.insert(problems, `{mapId}: {id} needs a weight above 0`)
				end
				if row.Kind == "signature" then
					if row.Map ~= mapId then
						table.insert(
							problems,
							`{mapId}: {id} is {row.Map or "another map"}'s signature`
						)
					elseif role == "main" then
						signatureMain = true
					end
				end
				local sites = map.Sites[id]
				if not sites or #sites == 0 then
					table.insert(problems, `{mapId}: {id} has no site`)
					continue
				end
				for index, site in sites do
					local fields = { "Name", "Position" }
					table.move(row.Needs, 1, #row.Needs, 3, fields)
					for _, field in fields do
						if site[field] == nil then
							table.insert(problems, `{mapId}: {id} site {index} has no {field}`)
						end
					end
				end
			end
		end
		if not signatureMain then
			table.insert(problems, `{mapId}: no signature main objective`)
		end
	end
	table.sort(problems)
	return problems
end

-- A count for one player plus a share per living player beyond the first.
function Objectives.scaled(count: number, perExtraPlayer: number?, extraPlayers: number): number
	return count + (perExtraPlayer or 0) * math.max(extraPlayers, 0)
end

-- A hold's seconds after `deltaTime`: it adds up only while held, never resets, stops at `total`.
function Objectives.hold(progress: number, deltaTime: number, held: boolean, total: number): number
	if not held then
		return progress
	end
	return math.min(progress + deltaTime, total)
end

function Objectives.countdown(timeLeft: number, deltaTime: number): number
	return math.max(timeLeft - deltaTime, 0)
end

-- When Control calls out side objective `index` (1, 2, ...) if the squad has not found it:
-- seconds after landing.
function Objectives.revealAt(index: number, revealAfter: number): number
	return math.max(index, 1) * revealAfter
end

-- 0..1 for the progress bar; nil (no bar) when there is nothing to count.
function Objectives.fraction(done: number, total: number): number?
	if total <= 0 then
		return nil
	end
	return math.clamp(done / total, 0, 1)
end

function Objectives.progressText(done: number, total: number, unit: string): string
	if total <= 0 then
		return ""
	end
	local shown = math.min(math.floor(done), total)
	return if unit == "s" then `{shown} of {total}s` else `{shown} of {total}`
end

-- "m:ss", rounded up so a running timer never shows 0:00 early.
function Objectives.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Puts the drawn site's names into a line: "{place}" -> "the Pens", "{to}" -> where a
-- carried item goes.
function Objectives.fill(text: string, place: string, to: string?): string
	local function plain(value: string): string
		return (string.gsub(value, "%%", "%%%%"))
	end
	local filled = string.gsub(text, "{place}", plain(place))
	return (string.gsub(filled, "{to}", plain(to or place)))
end

function Objectives.metres(studs: number, metresPerStud: number): number
	return math.floor(studs * metresPerStud + 0.5)
end

-- Degrees to turn (right positive, -180..180) from the flat look direction to the flat
-- offset of the target; 0 when either is too short to point with.
function Objectives.bearing(lookX: number, lookZ: number, toX: number, toZ: number): number
	if lookX * lookX + lookZ * lookZ < 1e-6 or toX * toX + toZ * toZ < 1e-6 then
		return 0
	end
	local cross = lookX * toZ - lookZ * toX
	local dot = lookX * toX + lookZ * toZ
	return math.deg(math.atan2(cross, dot))
end

function Objectives.isOpen(state: State): boolean
	return state == "pending" or state == "active"
end

return Objectives
