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

-- Every mission file by its module name (a catalog row's Layout). A mission's plain-data file
-- (Mile14Data) is read by its mission, not a mission itself.
local byLayout: { [string]: MissionTypes.Mission } = {}
for _, child in script:GetChildren() do
	if
		child:IsA("ModuleScript")
		and child.Name ~= "MissionTypes"
		and string.sub(child.Name, -4) ~= "Data"
	then
		byLayout[child.Name] = (require :: any)(child) :: MissionTypes.Mission
	end
end

-- The catalog as the pick rule sees it: a row whose layout file is missing is never open,
-- so an event row added without its map falls through instead of stopping the boot.
local catalog = {
	DEFAULT = MissionCatalog.DEFAULT,
	get = MissionCatalog.get,
	isOpen = function(row: MissionCatalog.Row, now: number): boolean
		return byLayout[row.Layout] ~= nil and MissionCatalog.isOpen(row, now)
	end,
}

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
local currentId = MissionPick.choose(stored, tagged, os.time(), catalog)
local source = if typeof(stored) == "table" and (stored :: any).mission == currentId
	then "launch"
	elseif tagged == currentId then "tag"
	else "default"
print(`[Missions] building {currentId} (from {source})`)

-- The catalog row this server plays (its Pool, District, Name).
function Missions.row(): MissionCatalog.Row
	local row = MissionCatalog.get(currentId)
	assert(row, `[Missions] '{currentId}' is not in MissionCatalog`)
	return row
end

-- The mission this server builds: the row's Layout file.
function Missions.current(): MissionTypes.Mission
	local row = Missions.row()
	local mission = byLayout[row.Layout]
	assert(mission, `[Missions] no layout file '{row.Layout}' for '{currentId}'`)
	return mission
end

return Missions
