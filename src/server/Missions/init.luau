--!strict
-- The missions (docs/ARCHITECTURE.md F6): one data file per mission in this folder, each
-- returning a MissionTypes.Mission. ArenaService builds `current()`. Which one this server
-- builds is settled once, the first time this module is required, before the map exists:
--   1. the lobby's launch record, stored in MemoryStore under this reserved server's
--      PrivateServerId (LaunchService.send; Rules/MissionPick.launchRecord)
--   2. the Workspace's Mission attribute (a Studio test: set it in the Properties panel;
--      mile14.project.json sets it for the Mile 14 Dev place)
--   3. MissionCatalog.DEFAULT (Checkpoint Delta)
-- A failed or missing read warns and falls through: a match always boots.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MissionCatalog = require(ReplicatedStorage.Shared.MissionCatalog)
local MissionPick = require(ReplicatedStorage.Shared.Rules.MissionPick)
local MissionTypes = require(script.MissionTypes)

local Missions = {}

local byId: { [string]: MissionTypes.Mission } = {}
for _, child in script:GetChildren() do
	-- A mission's plain-data file (Mile14Data) is read by its mission, not a mission itself.
	if
		child:IsA("ModuleScript")
		and child.Name ~= "MissionTypes"
		and string.sub(child.Name, -4) ~= "Data"
	then
		local mission = (require :: any)(child) :: MissionTypes.Mission
		byId[mission.Id] = mission
	end
end

-- The lobby's launch record for this server, or nil (not a reserved server, none stored,
-- or MemoryStore failed twice).
local function storedLaunch(): unknown
	local serverId = game.PrivateServerId
	if serverId == "" then
		return nil
	end
	local map = MemoryStoreService:GetHashMap(Config.Missions.LaunchMap)
	for attempt = 1, 2 do
		local ok, value = pcall(function()
			return map:GetAsync(serverId)
		end)
		if ok then
			return value
		end
		if attempt == 2 then
			warn(`[Missions] couldn't read the launch record: {value}; building the default`)
		else
			task.wait(1)
		end
	end
	return nil
end

local stored = storedLaunch()
local tagged = workspace:GetAttribute(Attributes.Mission)
local currentId = MissionPick.choose(stored, tagged, os.time(), MissionCatalog)
local source = if typeof(stored) == "table" and (stored :: any).mission == currentId
	then "launch"
	elseif tagged == currentId then "tag"
	else "default"
print(`[Missions] building {currentId} (from {source})`)

-- The mission with `id`, or nil.
function Missions.get(id: string): MissionTypes.Mission?
	return byId[id]
end

-- The mission this server builds.
function Missions.current(): MissionTypes.Mission
	local row = MissionCatalog.get(currentId)
	local mission = row and byId[row.Id]
	assert(mission, `[Missions] no mission file for '{currentId}' (MissionCatalog)`)
	return mission
end

return Missions
