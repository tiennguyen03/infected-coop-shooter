--!strict
-- The missions (docs/ARCHITECTURE.md F6): one data file per mission in this folder, each
-- returning a MissionTypes.Mission. ArenaService builds `current()`. An operation's order is
-- Config.Operation.Missions; the mission-to-mission transition will move `current` along it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MissionTypes = require(script.MissionTypes)

local Missions = {}

local byId: { [string]: MissionTypes.Mission } = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and child.Name ~= "MissionTypes" then
		local mission = (require :: any)(child) :: MissionTypes.Mission
		byId[mission.Id] = mission
	end
end

-- A place built for one mission says so on its Workspace (its Rojo project sets
-- Attributes.Mission: the Mile 14 place); otherwise the operation's first.
local tagged = workspace:GetAttribute(Attributes.Mission)
local currentId: string = if typeof(tagged) == "string" and byId[tagged]
	then tagged
	else Config.Operation.Missions[1]

-- The mission with `id`, or nil.
function Missions.get(id: string): MissionTypes.Mission?
	return byId[id]
end

-- The mission being played (the first of the operation until the transition exists).
function Missions.current(): MissionTypes.Mission
	local mission = byId[currentId]
	assert(mission, `[Missions] no mission file for '{currentId}' (Config.Operation.Missions)`)
	return mission
end

return Missions
