--!strict
-- The Containment Board's data, as the lobby reads it (docs/PROGRESSION.md > The Containment
-- Board). Lobby v1 returns the placeholder percents from Config.Containment.Districts. The
-- shared DataStore read (one key per district, UpdateAsync on the writer side) replaces the
-- body of `read` when the save service lands (docs/ARCHITECTURE.md F9); callers don't change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ContainmentBoard = {}

export type District = {
	name: string,
	percent: number,
}

-- Every district in board order. Yields once it reads a DataStore; callers run it off the
-- main thread.
function ContainmentBoard.read(): { District }
	local districts: { District } = {}
	for _, entry in Config.Containment.Districts do
		table.insert(districts, { name = entry.name, percent = entry.percent })
	end
	return districts
end

return ContainmentBoard
