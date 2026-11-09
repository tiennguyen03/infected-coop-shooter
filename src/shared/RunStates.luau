--!strict
local Attributes = require(script.Parent.Attributes)
-- The run's phase, shared so services and clients read it without requiring RunManager
-- (RunManager requires services, never the reverse). RunManager is the only writer of the
-- workspace attributes RunState and RunResult ("" | "Extracted" | "Wiped").
-- Lobby -> Insert -> Explore -> Primary (hold active) -> Index (boss, passthrough until the
-- Warden) -> Extract -> Ended. docs/sprints/SPRINT_17_COOP_A.md section 2.

export type RunState = "Lobby" | "Insert" | "Explore" | "Primary" | "Index" | "Extract" | "Ended"
export type RunResult = "" | "Extracted" | "Wiped"

local RunStates = {}

-- States in which the field is in play: the Infected spawn and objectives tick.
RunStates.LIVE = {
	Explore = true,
	Primary = true,
	Index = true,
	Extract = true,
}

function RunStates.current(): RunState
	local state = workspace:GetAttribute(Attributes.RunState)
	if typeof(state) == "string" then
		return state :: RunState
	end
	return "Lobby"
end

function RunStates.result(): RunResult
	local result = workspace:GetAttribute(Attributes.RunResult)
	if typeof(result) == "string" then
		return result :: RunResult
	end
	return ""
end

function RunStates.isLive(): boolean
	return RunStates.LIVE[RunStates.current()] == true
end

return RunStates
