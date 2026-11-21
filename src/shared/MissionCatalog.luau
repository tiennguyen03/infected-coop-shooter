--!strict
-- The missions a squad can pick on the Carrier's Mission Board (docs/PROGRESSION.md >
-- Missions; design: docs/superpowers/specs/2026-11-20-game-loop-design.md). One row per
-- mission: a new mission or an event mission is a row here, a layout file in
-- src/server/Missions/<Layout> and a pool in ObjectiveDefinitions.Maps. Nothing else names a
-- mission. Plain data (tests/MissionCatalog.spec.luau loads it outside Studio).
-- The lobby reads it for the board (MissionBoardService, MissionBoardUI); the match builds
-- the row the lobby launched (Missions/init, Rules/MissionPick).

export type Row = {
	Id: string,
	Name: string, -- on the card
	District: string, -- the city district it fights for (Config.Containment.Districts' name)
	Layout: string, -- src/server/Missions/<Layout>
	Pool: string, -- ObjectiveDefinitions.Maps key
	Boss: string, -- who ends the main objective ("warden")
	Blurb: string, -- the card's line, plain words
	Players: { number }, -- { min, max } soldiers
	Window: { From: number, To: number }?, -- os.time() range it can be picked in; nil = always
	Place: number?, -- its own match place; nil = the shared match place (Config.Places)
	Pay: { Win: number?, Partial: number? }?, -- its own merits; nil = Config.Merits (loop sprint 4)
}

local MissionCatalog = {}

MissionCatalog.DEFAULT = "delta" -- built when nothing else says which

MissionCatalog.Rows = {
	delta = {
		Id = "delta",
		Name = "Checkpoint Delta",
		District = "DELTA",
		Layout = "Delta",
		Pool = "delta",
		Boss = "warden",
		Blurb = "The army checkpoint on the highway out. Take it back so the helicopter can land.",
		Players = { 1, 4 },
	},
	mile14 = {
		Id = "mile14",
		Name = "Mile 14",
		District = "MILE 14",
		Layout = "Mile14",
		Pool = "mile14",
		Boss = "warden", -- a stand-in until the Driver (owner, 2026-11-20)
		Blurb = "A dead convoy at night. Land at the toll plaza, get to the rest stop. Stay quiet.",
		Players = { 1, 4 },
		Pay = { Win = 140, Partial = 70 }, -- quieter and longer than Delta, and it pays for it
	},
} :: { [string]: Row }

-- The board's order, left to right.
MissionCatalog.Order = { "delta", "mile14" } :: { string }

function MissionCatalog.get(id: string): Row?
	return MissionCatalog.Rows[id]
end

-- Whether `row` can be picked at `now` (os.time()). Only its Window for now; the city war's
-- unlocks come with the live board (loop sprint 3).
function MissionCatalog.isOpen(row: Row, now: number): boolean
	local window = row.Window
	if window == nil then
		return true
	end
	return now >= window.From and now <= window.To
end

return MissionCatalog
