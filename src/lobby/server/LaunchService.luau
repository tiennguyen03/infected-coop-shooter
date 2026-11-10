--!strict
-- Lantern spots on the Fallow's flight deck (docs/MULTIPLAYER_READINESS.md decision 7): a
-- bird on each numbered spot and a boarding box beside its door. Whoever stands in the box is
-- aboard (Rules/Manifest: boarding order, up to Config.Lobby.Launch.Capacity); the first
-- aboard starts the countdown, a full bird shortens it. When it runs out, the server reserves
-- a private server of the match place and teleports everyone aboard together, with the spot
-- the party's UserIds and each soldier's signed Loadout (LoadmasterService) as teleport data
-- (Rules/LaunchData; the match re-checks the Loadouts and never trusts it for progress).
-- Teleports do not run in Studio: there the spot reports it and resets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local LaunchData = require(ReplicatedStorage.Shared.Rules.LaunchData)
local Manifest = require(ReplicatedStorage.Shared.Rules.Manifest)
local Messages = require(ReplicatedStorage.Shared.Messages)
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
	-- The painted spot circle and its number.
	Build.part(
		parent,
		"SpotRing",
		Vector3.new(0.1, 28, 28),
		CFrame.new(spot.helo + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		YELLOW,
		{ shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, collide = false }
	)
	Build.part(
		parent,
		"SpotInner",
		Vector3.new(0.1, 26.4, 26.4),
		CFrame.new(spot.helo + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(50, 52, 55),
		{ shape = Enum.PartType.Cylinder, material = Enum.Material.Asphalt, collide = false }
	)
	local number = Build.part(
		parent,
		"SpotNumber",
		Vector3.new(8, 0.05, 8),
		CFrame.new(spot.helo.X, deck + 0.3, spot.helo.Z + 18) * CFrame.Angles(0, math.pi, 0),
		PAINT,
		{ transparency = 1, collide = false }
	)
	Build.text(number, Enum.NormalId.Top, tostring(spot.index), { size = 140, color = PAINT })

	local bird = LanternBird.build(parent, spot.helo, Config.Lobby.Lantern.BirdNumbers[spot.index])

	-- The boarding box beside the door.
	local half = LAUNCH.BoardHalfSize
	local box = Build.part(
		parent,
		"BoardingBox",
		Vector3.new(half * 2, 0.1, half * 2),
		-- Above the spot ring it overlaps at the door side (ring top 0.11, inner 0.19).
		CFrame.new(spot.board + Vector3.new(0, 0.3, 0)),
		YELLOW,
		{ material = Enum.Material.SmoothPlastic, transparency = 0.6, collide = false }
	)
	Build.sign(box, `LANTERN · SPOT {spot.index}`, "Stand here to board", 5)
	return bird
end

-- Soldiers standing in a spot's boarding box right now, as UserIds.
local function present(spot: Layout.Spot): { number }
	local half = LAUNCH.BoardHalfSize
	local ids: { number } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - spot.board
			if
				math.abs(offset.X) <= half
				and math.abs(offset.Z) <= half
				and offset.Y >= 0
				and offset.Y <= LAUNCH.BoardHeight
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
	local key = `{table.concat(names, ",")}|{state.manifest.liftAt}`
	for _, player in aboard do
		if state.sent[player] ~= key then
			state.sent[player] = key
			launchRemote:FireClient(
				player,
				Messages.Launch.Manifest,
				state.spot.index,
				names,
				secondsLeft
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

local function lift(state: SpotState)
	state.lifting = true
	local party = playersFor(state.manifest.aboard)
	for _, player in party do
		launchRemote:FireClient(player, Messages.Launch.Lifting, state.spot.index)
	end
	table.clear(state.sent)

	if RunService:IsStudio() then
		fail(
			party,
			"Teleports don't run in Studio. Publish the lobby and launch from the live game."
		)
	else
		local data = LaunchData.encode(
			state.spot.index,
			state.manifest.aboard,
			LoadmasterService.loadoutsFor(party)
		)
		local matchPlaceId = Config.Lobby.DevMatchPlaceIds[game.PlaceId]
			or Config.Lobby.MatchPlaceId
		local options = Instance.new("TeleportOptions")
		-- A fresh private server of the match per launch. ShouldReserveServer is a documented
		-- TeleportOptions property the luau-lsp definitions do not list yet, hence the cast.
		local reserve: any = options
		reserve.ShouldReserveServer = true
		options:SetTeleportData(data)
		local sent = false
		local lastError = ""
		for _ = 0, LAUNCH.Retries do
			-- Only those still in the server go (a soldier who left mid-countdown is dropped).
			local going: { Player } = {}
			for _, player in party do
				if player.Parent then
					table.insert(going, player)
				end
			end
			if #going == 0 then
				sent = true
				break
			end
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(matchPlaceId, going, options)
			end)
			if ok then
				sent = true
				break
			end
			lastError = tostring(err)
			warn(`[LaunchService] spot {state.spot.index} teleport failed: {lastError}`)
			task.wait(LAUNCH.RetryDelay)
		end
		if not sent then
			fail(party, "Lantern couldn't lift. Try again.")
		end
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
		local ids = if now < state.restUntil then {} else present(state.spot)
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
		fail({ player }, "Lantern couldn't lift. Try again.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, state in states do
			state.sent[player] = nil
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
