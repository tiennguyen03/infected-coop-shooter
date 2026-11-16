--!strict
-- The shape every objective module in this folder has (docs/PROGRESSION.md > Objective
-- pools). ObjectiveService draws an objective's row and site, builds a Context and calls
-- `new`; from then on it only talks to the Objective that comes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveDefinitions = require(ReplicatedStorage.Shared.ObjectiveDefinitions)

-- What the HUD shows for it right now.
export type Progress = {
	step: string, -- what to do, in plain words
	done: number,
	total: number, -- 0 = nothing to count (no bar)
	unit: string, -- "s" | "count" | ""
	timeLeft: number?, -- seconds, while a timer runs
}

export type Context = {
	role: string, -- "main" | "side"
	label: string, -- the world marker's first line: "MAIN OBJECTIVE" / "SIDE OBJECTIVE"
	color: Color3,
	row: ObjectiveDefinitions.Row,
	site: ObjectiveDefinitions.Site,
	position: Vector3, -- the site's Position
	-- Everything the objective builds goes in here; ObjectiveService destroys it when the
	-- run resets (so a burning tent or a lit radio stays for the rest of the mission).
	folder: Folder,
	complete: () -> (), -- call once: it is done
	fail: () -> (), -- call once: it can no longer be done (side objectives only)
}

export type Objective = {
	-- The squad reached it (row.StartRadius), or it was known at once: its fight begins.
	begin: () -> (),
	-- Every frame while it is started and neither done nor failed; the field is not paused.
	step: (deltaTime: number) -> (),
	progress: () -> Progress,
	-- Where its marker and the HUD's distance point now (it may move: a carried record).
	position: () -> Vector3,
	-- The run is resetting: undo anything left outside `folder` (attributes, lights, sounds).
	cleanup: () -> (),
}

-- `new` builds the objective's props and marker at the site. State lives in the closure:
-- one objective, one run, shared by the whole squad (1 to 4 players and their bots).
export type Module = {
	new: (context: Context) -> Objective,
}

return {}
