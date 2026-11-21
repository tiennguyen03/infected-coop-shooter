--!strict
-- The city war from the match (loop sprint 3; rules: Rules/War; docs/PROGRESSION.md > The
-- Containment Board). At a run's end the mission's district gets its points (Win 3,
-- Partial 1, Loss 0: per mission, not per player) on the one shared board, with one
-- UpdateAsync (Rules/War.merge), so many servers ending together each add their share. The
-- lobby reads the same key (ContainmentBoard). Only this server writes, once a run: clients
-- never send progress. A failed save is warned once and dropped. The results screen shows
-- the line (Attributes.WarLine).
-- Callers: RunManager (`flush` at run end), MeritService (`securedHere`: a Secured district
-- pays Config.War.SecuredPay of its merits).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local War = require(ReplicatedStorage.Shared.Rules.War)
local Lifecycle = require(script.Parent.Lifecycle)
local Missions = require(script.Parent.Missions)

local WarService = {}

local CFG = Config.War
local warned = false

-- Rules/War's settings: Config.War plus the board's districts (Config.Containment).
function WarService.settings(): War.Settings
	local settings = table.clone(CFG) :: any
	settings.Districts = Config.Containment.Districts
	return settings
end

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(`[WarService] the war board was not saved (logged once): {message}`)
	end
end

local function save(add: { [string]: number })
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(CFG.Store)
	end)
	if not ok then
		warnOnce(tostring(store))
		return
	end
	local settings = WarService.settings()
	for try = 0, CFG.Retries do
		local done, err = pcall(function()
			store:UpdateAsync(CFG.Key, function(old: unknown): ...any
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
	local points = if CFG.Enabled then War.points(outcome, WarService.settings()) else 0
	workspace:SetAttribute(
		Attributes.WarLine,
		War.gainText(district, points, WarService.settings())
	)
	if points > 0 then
		task.spawn(save, { [district] = points })
	end
end

-- Whether this mission's district is Secured on the board (read once at boot; false until the
-- read lands, or when it fails).
local secured = false
function WarService.securedHere(): boolean
	return secured
end

function WarService.init()
	task.spawn(function()
		local ok, raw = pcall(function()
			return DataStoreService:GetDataStore(CFG.Store):GetAsync(CFG.Key)
		end)
		if ok then
			local board = War.merge(raw, {}, os.time(), WarService.settings())
			local record = board.districts[Missions.row().District]
			secured = record ~= nil and record.secured == true
		end
	end)
	Lifecycle.register("WarService", {
		onRunStart = function()
			workspace:SetAttribute(Attributes.WarLine, "")
		end,
	})
end

return WarService
