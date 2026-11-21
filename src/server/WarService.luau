--!strict
-- The city war from the match (loop sprint 3; rules: Rules/War; docs/PROGRESSION.md > The
-- Containment Board). At a run's end the mission's district gets its points (Win 3,
-- Partial 1, Loss 0: per mission, not per player) on the one shared board, with one
-- UpdateAsync (Rules/War.merge), so many servers ending together each add their share. The
-- lobby reads the same key (ContainmentBoard). Only this server writes, at most
-- Config.War.MaxWritesPerServerHour times an hour, never from Studio unless StudioWrites is
-- on; a closing server waits up to ShutdownWait for a save still in flight. Clients never
-- send progress. A failed save is warned once and dropped. The board is read once at boot to
-- know whether this district is Secured (no more points; the line says SECURED). The results
-- screen shows the line (Attributes.WarLine).
-- Callers: RunManager (`flush` at run end).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local War = require(ReplicatedStorage.Shared.Rules.War)
local Lifecycle = require(script.Parent.Lifecycle)
local Missions = require(script.Parent.Missions)

local WarService = {}

local CFG = Config.War
local warned = false
local inFlight = 0
local writes: { number } = {} -- os.clock of this server's writes in the last hour
local secured = false -- this district on the board read at boot
local bootSeason = War.season(os.time(), CFG.SeasonStart, CFG.SeasonDays) -- the season of that read

-- Rules/War's settings: Config.War plus the board's districts (Config.Containment).
function WarService.settings(): War.Settings
	local settings = table.clone(CFG) :: any
	settings.Districts = Config.Containment.Districts
	return settings
end

-- This season's store (Rules/War.season: a new store every Config.War.SeasonDays).
function WarService.storeName(): string
	return War.storeAt(os.time(), CFG)
end

-- Whether this mission's district is Secured (read once at boot; false until it lands).
function WarService.securedHere(): boolean
	-- A Secured flag from last season means nothing on this season's fresh board.
	return secured and War.season(os.time(), CFG.SeasonStart, CFG.SeasonDays) == bootSeason
end

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(`[WarService] the war board was not saved (logged once): {message}`)
	end
end

local function store(): GlobalDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(WarService.storeName())
	end)
	if not ok then
		warnOnce(tostring(result))
		return nil
	end
	return result
end

-- Whether this server may write now: not from Studio (unless StudioWrites), and under the
-- hourly cap. Counts the write when it may.
local function mayWrite(): boolean
	if RunService:IsStudio() and not CFG.StudioWrites then
		return false
	end
	local now = os.clock()
	for index = #writes, 1, -1 do
		if now - writes[index] > 3600 then
			table.remove(writes, index)
		end
	end
	if #writes >= CFG.MaxWritesPerServerHour then
		warnOnce("this server reached MaxWritesPerServerHour")
		return false
	end
	table.insert(writes, now)
	return true
end

local function save(add: { [string]: number })
	local data = store()
	if not data then
		return
	end
	local settings = WarService.settings()
	for try = 0, CFG.Retries do
		local done, err = pcall(function()
			data:UpdateAsync(CFG.Key, function(old: unknown): ...any
				return War.merge(old, add, os.time(), settings)
			end)
		end)
		if done then
			return
		end
		local message = tostring(err)
		if string.find(string.lower(message), "studio", 1, true) or try == CFG.Retries then
			warnOnce(message)
			return
		end
		task.wait(CFG.RetryDelay)
	end
end

-- Run end: the mission's outcome ("win" | "partial" | "loss") moves its district. Does not
-- yield; the save runs on its own.
function WarService.flush(outcome: string)
	local district = Missions.row().District
	local settings = WarService.settings()
	local securedNow = WarService.securedHere()
	local points = if CFG.Enabled and not securedNow then War.points(outcome, settings) else 0
	workspace:SetAttribute(
		Attributes.WarLine,
		War.gainText(district, points, settings, securedNow and CFG.Enabled)
	)
	if points > 0 and mayWrite() then
		inFlight += 1
		task.spawn(function()
			pcall(save, { [district] = points })
			inFlight -= 1
		end)
	end
end

function WarService.init()
	Lifecycle.register("WarService", {
		onRunStart = function()
			workspace:SetAttribute(Attributes.WarLine, "")
		end,
	})
	task.spawn(function()
		local data = store()
		local ok, raw = pcall(function()
			return if data then data:GetAsync(CFG.Key) else nil
		end)
		if ok then
			local board = War.merge(raw, {}, os.time(), WarService.settings())
			local record = board.districts[Missions.row().District]
			secured = record ~= nil and record.secured == true
		end
	end)
	-- A server closing right after a run end still lands its points.
	game:BindToClose(function()
		local deadline = os.clock() + CFG.ShutdownWait
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.25)
		end
	end)
end

return WarService
