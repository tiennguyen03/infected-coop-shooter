--!strict
-- The match side of the lobby <-> match trip (docs/LOBBY_MATCH_HANDOFF.md, Rules/Handoff).
-- Reads each joining player's teleport data once (who the lobby sent, their squad slot and
-- loadout, the operation) and sends the squad home to the lobby with the run's result.
-- RunManager is the only caller (MULTIPLAYER_READINESS decision 7: one place reads the data).
--
-- Studio: teleports do not run, so join data is empty and the match plays as a direct join.
-- To stand in for the lobby there, put a teleport-data table as JSON in the ServerStorage
-- attribute MockTeleportData before Play (Studio only; read once per player).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Handoff = require(ReplicatedStorage.Shared.Rules.Handoff)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Lifecycle = require(script.Parent.Lifecycle)

local HandoffService = {}

local joins: { [Player]: Handoff.Join } = {}
-- The trip home in flight: its options (one reserved place, reused for a player's retry) and
-- how often each player has been retried after TeleportInitFailed.
local homeOptions: TeleportOptions? = nil
local retries: { [Player]: number } = {}

local function loadoutCheck(): Handoff.LoadoutCheck
	local catalog = ArmsRoom.catalog()
	return {
		default = ArmsRoom.default(),
		isValid = function(loadout: unknown): boolean
			return (Loadout.validate(loadout, catalog))
		end,
	}
end

local function joinData(player: Player): unknown
	if RunService:IsStudio() then
		local mock = ServerStorage:GetAttribute(Attributes.MockTeleportData)
		if typeof(mock) == "string" and mock ~= "" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, mock)
			if ok then
				return decoded
			end
			warn("[Handoff] MockTeleportData is not valid JSON; playing as a direct join")
		end
		return nil
	end
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	return if ok then data else nil
end

-- What `player` arrived with (read once; Handoff.readJoin's defaults when they came direct).
function HandoffService.joinFor(player: Player): Handoff.Join
	local join = joins[player]
	if not join then
		join = Handoff.readJoin(joinData(player), player.UserId, loadoutCheck())
		joins[player] = join
	end
	return join
end

-- True when anyone in this server was sent by the lobby.
function HandoffService.fromLobby(): boolean
	for _, player in Players:GetPlayers() do
		if HandoffService.joinFor(player).fromLobby then
			return true
		end
	end
	return false
end

-- The operation the squad picked in the lobby (the default on a direct join).
function HandoffService.operation(): string
	for _, player in Players:GetPlayers() do
		local join = HandoffService.joinFor(player)
		if join.fromLobby then
			return join.operation
		end
	end
	return Handoff.DEFAULT_OPERATION
end

-- True when the squad can be sent home: the lobby is published (Config.Places.Lobby), this
-- is a live server (teleports never run in Studio) and the squad came from the lobby.
function HandoffService.canReturn(): boolean
	return Config.Places.Lobby ~= 0 and not RunService:IsStudio() and HandoffService.fromLobby()
end

-- Teleports everyone here to the lobby carrying `result` (Handoff.result). Yields through the
-- retries; true once the teleport went out, false when every try failed (nobody moved).
function HandoffService.sendHome(result: Handoff.Result): boolean
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(result)
	homeOptions = options
	table.clear(retries)
	for attempt = 1, Config.Handoff.Retries + 1 do
		local players = Players:GetPlayers()
		if #players == 0 then
			return true
		end
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(Config.Places.Lobby, players, options)
		end)
		if ok then
			return true
		end
		warn(`[Handoff] trip home failed (try {attempt}): {err}`)
		task.wait(Config.Handoff.RetryDelay)
	end
	homeOptions = nil
	return false
end

function HandoffService.init()
	Lifecycle.register("HandoffService", {
		onPlayerRemoving = function(player: Player)
			joins[player] = nil
			retries[player] = nil
		end,
	})
	-- A player whose trip home failed after it started gets retried on the same options.
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		local options = homeOptions
		if not options or not player.Parent then
			return
		end
		local tries = (retries[player] or 0) + 1
		retries[player] = tries
		warn(`[Handoff] {player.Name}'s trip home failed ({message}); retry {tries}`)
		if tries > Config.Handoff.Retries then
			return
		end
		task.delay(Config.Handoff.RetryDelay, function()
			if player.Parent then
				pcall(function()
					TeleportService:TeleportAsync(Config.Places.Lobby, { player }, options)
				end)
			end
		end)
	end)
end

return HandoffService
