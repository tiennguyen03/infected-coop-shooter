--!strict
-- Lantern spots on the Fallow's flight deck (docs/MULTIPLAYER_READINESS.md decision 7): a
-- bird on each numbered spot inside a yellow ring. Whoever stands inside the ring is
-- aboard (Rules/Manifest: boarding order, up to Config.Lobby.Launch.Capacity); the first
-- aboard starts the countdown and may pick the squad size (LaunchUI); a full bird (all four,
-- or the size picked) shortens it to Config.Lobby.Launch.FullCountdown. When it runs out, the server reserves
-- one private server of the match place and teleports everyone aboard into it together, with
-- the shared handoff as teleport data (Rules/Handoff.departure: boarding order, each soldier's
-- signed Loadout from LoadmasterService, plus the spot; the match re-checks the Loadouts and
-- never trusts it for progress).
-- Teleports do not run in Studio: there the spot reports it and resets.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Handoff = require(ReplicatedStorage.Shared.Rules.Handoff)
local Manifest = require(ReplicatedStorage.Shared.Rules.Manifest)
local Messages = require(ReplicatedStorage.Shared.Messages)
local MissionCatalog = require(ReplicatedStorage.Shared.MissionCatalog)
local MissionPick = require(ReplicatedStorage.Shared.Rules.MissionPick)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Build = require(script.Parent.Build)
local LanternBird = require(script.Parent.LanternBird)
local LoadmasterService = require(script.Parent.LoadmasterService)
local Layout = require(script.Parent.FallowLayout)

local LaunchService = {}

local LAUNCH = Config.Lobby.Launch
local SETTINGS: Manifest.Settings = {
	capacity = LAUNCH.Capacity,
	countdown = LAUNCH.Countdown,
	fullCountdown = LAUNCH.FullCountdown,
}

local YELLOW = Color3.fromRGB(230, 189, 96)
local PAINT = Color3.fromRGB(214, 214, 208)
local RING_BAND = 0.8 -- studs of yellow paint at the ring's edge

type SpotState = {
	spot: Layout.Spot,
	bird: Model, -- carries Attributes.LiftAt for the clients (LanternSpool)
	manifest: Manifest.Manifest,
	lifting: boolean,
	restUntil: number, -- os.clock; the spot takes no one until then
	sent: { [Player]: string }, -- the last manifest message each soldier aboard was sent
}

local states: { SpotState } = {}
local launchRemote: RemoteEvent

local function buildSpot(parent: Instance, spot: Layout.Spot): Model
	local deck = Layout.DeckY
	local radius = LAUNCH.BoardRadius
	-- The painted spot circle and its number. The ring is the boarding zone (owner
	-- 2026-11-16): stand anywhere inside it, round the bird, to board (Manifest.onSpot).
	Build.part(
		parent,
		"SpotRing",
		Vector3.new(0.1, radius * 2, radius * 2),
		CFrame.new(spot.helo + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		YELLOW,
		{ shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, collide = false }
	)
	Build.part(
		parent,
		"SpotInner",
		Vector3.new(0.1, radius * 2 - RING_BAND * 2, radius * 2 - RING_BAND * 2),
		CFrame.new(spot.helo + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(50, 52, 55),
		{ shape = Enum.PartType.Cylinder, material = Enum.Material.Asphalt, collide = false }
	)
	local number = Build.part(
		parent,
		"SpotNumber",
		Vector3.new(8, 0.05, 8),
		CFrame.new(spot.helo.X, deck + 0.3, spot.helo.Z + radius + 4) * CFrame.Angles(0, math.pi, 0),
		PAINT,
		{ transparency = 1, collide = false }
	)
	Build.text(number, Enum.NormalId.Top, tostring(spot.index), { size = 140, color = PAINT })

	local bird = LanternBird.build(parent, spot.helo, Config.Lobby.Lantern.BirdNumbers[spot.index])

	-- The sign on the ring's edge by the bird's door, where soldiers walk up to it.
	local sign = Build.part(
		parent,
		"SpotSign",
		Vector3.new(1, 0.1, 1),
		CFrame.new(spot.sign + Vector3.new(0, 0.3, 0)),
		YELLOW,
		{ transparency = 1, collide = false }
	)
	sign.CanQuery = false
	local how = if LAUNCH.RingsBoard
		then "Stand in the circle to board"
		else "Pick a mission in the map room"
	Build.sign(sign, `HELO · SPOT {spot.index}`, how, 5)
	return bird
end

-- Soldiers standing inside a spot's ring right now, as UserIds.
local function present(spot: Layout.Spot): { number }
	local ids: { number } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - spot.helo
			if
				Manifest.onSpot(
					offset.X,
					offset.Y,
					offset.Z,
					LAUNCH.BoardRadius,
					LAUNCH.BoardHeight
				)
			then
				table.insert(ids, player.UserId)
			end
		end
	end
	return ids
end

local function playersFor(ids: { number }): { Player }
	local list: { Player } = {}
	for _, id in ids do
		local player = Players:GetPlayerByUserId(id)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function tell(state: SpotState, now: number)
	local aboard = playersFor(state.manifest.aboard)
	local names: { string } = {}
	for _, player in aboard do
		table.insert(names, player.DisplayName)
	end
	local secondsLeft = if state.manifest.liftAt
		then math.max(0, state.manifest.liftAt - now)
		else 0
	local squad = state.manifest.squad or 0
	local lead = state.manifest.aboard[1]
	local key = `{table.concat(names, ",")}|{state.manifest.liftAt}|{squad}`
	for _, player in aboard do
		if state.sent[player] ~= key then
			state.sent[player] = key
			launchRemote:FireClient(
				player,
				Messages.Launch.Manifest,
				state.spot.index,
				names,
				secondsLeft,
				squad,
				player.UserId == lead
			)
		end
	end
	-- Anyone told before who is no longer aboard stepped off.
	for player in state.sent do
		if not table.find(aboard, player) then
			state.sent[player] = nil
			if player.Parent then
				launchRemote:FireClient(player, Messages.Launch.Cleared)
			end
		end
	end
end

local function fail(players: { Player }, reason: string)
	for _, player in players do
		if player.Parent then
			launchRemote:FireClient(player, Messages.Launch.Failed, reason)
		end
	end
end

-- Fly `party` into one new private server of the mission's match place (a catalog row's own
-- Place, else the shared match place or a Dev pair's), together, with the shared handoff as
-- teleport data. Before the teleport, the mission and the party are stored in MemoryStore
-- under the reserved server's PrivateServerId (Rules/MissionPick.launchRecord), so the
-- match builds the mission at boot and no client can change it; a failed write still flies
-- (the match then builds the default and says so in its log). `spot` is the pad number for
-- the match's logs (nil from the Mission Board). Returns false and the reason to show when
-- nobody flew (always in Studio: teleports don't run there).
function LaunchService.send(party: { Player }, missionId: string, spot: number?): (boolean, string?)
	if RunService:IsStudio() then
		return false,
			"Teleports don't run in Studio. Publish the lobby and launch from the live game."
	end
	local row = MissionCatalog.get(missionId)
	if not row then
		return false, "That mission isn't on the board."
	end
	local ids: { number } = {}
	for _, player in party do
		table.insert(ids, player.UserId)
	end
	local data =
		Handoff.departure(Handoff.DEFAULT_OPERATION, ids, LoadmasterService.loadoutsFor(party))
	data.spot = spot or 0 -- extra for the match's logs; readJoin ignores it
	local placeId = row.Place or Config.Places.Dev[game.PlaceId] or Config.Places.Match
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(data)
	local label = if spot then `spot {spot}` else `board {missionId}`
	-- One private server per launch, reserved once and reused for every retry, so a retry
	-- never splits the squad across two servers.
	local code: string? = nil
	local lastError = ""
	for _ = 0, LAUNCH.Retries do
		if not code then
			local ok, reserved, privateId = pcall(function()
				return TeleportService:ReserveServer(placeId)
			end)
			if ok then
				code = reserved
				-- A documented TeleportOptions property the luau-lsp definitions do not list.
				local reserve: any = options
				reserve.ReservedServerAccessCode = reserved
				-- The mission, stored for the match to read at boot (Missions/init).
				local stored, err = pcall(function()
					MemoryStoreService:GetHashMap(Config.Missions.LaunchMap):SetAsync(
						privateId,
						MissionPick.launchRecord(missionId, ids),
						Config.Missions.LaunchSeconds
					)
				end)
				if not stored then
					warn(
						`[LaunchService] {label}: couldn't store the mission ({err}); the match builds the default`
					)
				end
			else
				lastError = tostring(reserved)
				warn(`[LaunchService] {label} reserve failed: {lastError}`)
				task.wait(LAUNCH.RetryDelay)
				continue
			end
		end
		-- Only those still in the server go (a soldier who left mid-countdown is dropped).
		local going: { Player } = {}
		for _, player in party do
			if player.Parent then
				table.insert(going, player)
			end
		end
		if #going == 0 then
			return true
		end
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, going, options)
		end)
		if ok then
			return true
		end
		lastError = tostring(err)
		warn(`[LaunchService] {label} teleport failed: {lastError}`)
		task.wait(LAUNCH.RetryDelay)
	end
	return false, "The helicopter couldn't lift. Try again."
end

local function lift(state: SpotState)
	state.lifting = true
	local party = playersFor(state.manifest.aboard)
	for _, player in party do
		launchRemote:FireClient(player, Messages.Launch.Lifting, state.spot.index)
	end
	table.clear(state.sent)

	-- The pad rings fly to Checkpoint Delta, as before the Mission Board (loop sprint 2 moves
	-- them onto the board's party).
	local ok, reason = LaunchService.send(party, MissionCatalog.DEFAULT, state.spot.index)
	if not ok then
		fail(party, reason or "The helicopter couldn't lift. Try again.")
	end

	state.manifest = Manifest.new()
	state.restUntil = os.clock() + LAUNCH.Cooldown
	state.lifting = false
end

-- The bird's lift time for the clients, in server time (the manifest counts on os.clock).
-- Rewritten only when it moves (a full bird shortens the countdown), cleared at rest.
local function publishLift(state: SpotState, now: number)
	local liftAt = state.manifest.liftAt
	local value = if liftAt then Workspace:GetServerTimeNow() + (liftAt - now) else nil
	local current = state.bird:GetAttribute(Attributes.LiftAt)
	local moved = if value and typeof(current) == "number"
		then math.abs(value - current) > 0.25
		else value ~= current
	if moved then
		state.bird:SetAttribute(Attributes.LiftAt, value)
	end
end

local function scan()
	local now = os.clock()
	for _, state in states do
		if state.lifting then
			continue
		end
		-- The rings board only with RingsBoard on (loop sprint 2: squads form in the party
		-- panel and fly from the Mission Board; the birds stay as scenery).
		local ids = if not LAUNCH.RingsBoard or now < state.restUntil
			then {}
			else present(state.spot)
		state.manifest = Manifest.update(state.manifest, ids, now, SETTINGS)
		tell(state, now)
		publishLift(state, now)
		if Manifest.due(state.manifest, now) then
			task.spawn(lift, state)
		end
	end
end

function LaunchService.init()
	launchRemote = Remotes.get("Launch")
	local folder = Build.folder(Workspace, "Spots")
	for _, spot in Layout.Spots do
		local bird = buildSpot(folder, spot)
		table.insert(states, {
			spot = spot,
			bird = bird,
			manifest = Manifest.new(),
			lifting = false,
			restUntil = 0,
			sent = {},
		})
	end

	-- A teleport that fails after TeleportAsync returned (the place is down, a full server)
	-- arrives here; the soldier stays on the Fallow.
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		warn(`[LaunchService] {player.Name} teleport failed: {message}`)
		fail({ player }, "The helicopter couldn't lift. Try again.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, state in states do
			state.sent[player] = nil
		end
	end)
	-- The first aboard picks the squad size; the rule refuses anyone else and any bad size.
	launchRemote.OnServerEvent:Connect(function(player: Player, kind: unknown, size: unknown)
		if kind ~= Messages.Launch.Squad or typeof(size) ~= "number" then
			return
		end
		local now = os.clock()
		for _, state in states do
			if not state.lifting and Manifest.isAboard(state.manifest, player.UserId) then
				state.manifest =
					Manifest.setSquad(state.manifest, player.UserId, size, now, SETTINGS)
				tell(state, now)
				publishLift(state, now)
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= LAUNCH.ScanInterval then
			elapsed = 0
			scan()
		end
	end)
end

return LaunchService
