--!strict
-- Breaches and the pressure rhythm (docs/PROGRESSION.md > Breaches; Config.Breaches; the
-- rules in Shared.Rules.Breach). One alert meter per run, shared by the squad (1 to 4 players
-- and their bots): shots with Infected in earshot and blasts (EnemyService noise listener),
-- call-ins going off (CallInService), and each Infected that first comes close to a squad
-- member raise it; going quiet lets it fall. At the threshold a breach: a warning heard from
-- one side (WorldSounds at that side), Control's line naming the side, an arrow on every
-- screen (remote Breach, client BreachUI), then a horde of the run's mix from that side over
-- FloodSeconds, never past the live cap. A relief follows where nothing builds. The roaming
-- trickle follows the phase (EnemyService.setTrickle): fewer in the calm and the relief.
-- The main objective (or the single hold) calls one breach at its site partway
-- (ObjectiveService -> BreachService.objective). Nothing breaches while the Warden is on the
-- field, during extraction, on a quiet (awareness) mission or with dev spawning stopped.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Breach = require(ReplicatedStorage.Shared.Rules.Breach)
local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyService = require(script.Parent.EnemyService)
local Lifecycle = require(script.Parent.Lifecycle)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local WorldSounds = require(script.Parent.WorldSounds)

local BreachService = {}

local STEP = 0.25 -- seconds between director ticks
local SPOT_EVERY = 0.5 -- seconds between looks for fresh contact

local B = Config.Breaches
local S: Breach.Settings = B :: any

local breachRemote: RemoteEvent
local noticeRemote: RemoteEvent

local state = Breach.new()
local generation = 0 -- bumped every run: a horde still arriving never lands in the next one
local pendingSite: Vector3? = nil -- an objective's breach waiting for a clear field
local seen: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local horde: { Model } = {}
local hordeTotal = 0
local hordeArrived = false
local reliefSaid = true
local tensionSaid = false
local sinceStep, sinceSpot = 0, 0

local function enabled(): boolean
	return B.Enabled == true
end

-- The fights that bring their own pressure: the Warden, extraction. The meter waits.
local function heldBack(): boolean
	return workspace:GetAttribute(Attributes.IndexActive) == true
		or workspace:GetAttribute(Attributes.ExtractionActive) == true
end

-- No director at all: not in a live run, a paused field, a quiet mission, dev spawns off.
local function idle(): boolean
	return not enabled()
		or not RunStates.isLive()
		or PauseService.isPaused()
		or EnemyService.aware()
		or workspace:GetAttribute(Attributes.DevSpawnsOff) == true
end

local function say(text: string)
	noticeRemote:FireAllClients(text, Messages.Notice.Radio)
end

-- A loud moment worth `amount` (`capped`: gunfire, which shares the per-second cap).
function BreachService.loud(amount: number, capped: boolean?)
	if idle() or heldBack() then
		return
	end
	Breach.add(S, state, amount, os.clock(), capped == true)
end

-- A call-in went off: its row's BreachAlert, else Sources.CallIn.
function BreachService.callIn(cfg: any)
	local amount = if type(cfg) == "table" and type(cfg.BreachAlert) == "number"
		then cfg.BreachAlert
		else B.Sources.CallIn
	BreachService.loud(amount, false)
end

-- The main objective reached Objective.At of its work: one breach at `site` as soon as the
-- field allows (not while the Warden stands on it).
function BreachService.objective(site: Vector3)
	if enabled() and B.Objective.Enabled then
		pendingSite = site
	end
end

local function onNoise(_position: Vector3, reach: number, kind: string, heard: number)
	if heard <= 0 then
		return -- nobody heard it
	end
	local sources = B.Sources
	if kind == "shot" then
		BreachService.loud(sources.Shot * reach / sources.ShotReach, true)
	elseif kind == "blast" then
		BreachService.loud(sources.Blast, false)
	end
end

-- The middle of the living squad (players and bots).
local function squadMiddle(): Vector3?
	local sum, count = Vector3.zero, 0
	for _, member in Squad.living() do
		local root = member.root
		if root then
			sum += root.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

-- A breach now: round `site` (an objective) or the squad's middle, from a random side.
local function startBreach(site: Vector3?, line: string): boolean
	local center = site or squadMiddle()
	if not center then
		return false
	end
	local now = os.clock()
	local elapsed = DifficultyService.getElapsed()
	Breach.start(S, state, now, elapsed)
	generation += 1
	local thisGeneration = generation
	tensionSaid = false
	reliefSaid = false
	hordeArrived = false
	table.clear(horde)

	local angle = math.random() * math.pi * 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = EnemyService.groundNear(center + direction * B.Distance, 0, 1)
	for _, sound in B.WarningSounds do
		WorldSounds.at(side, sound.Bank, sound.Group, sound.Volume)
	end
	say((string.gsub(line, "{side}", Breach.compass(direction.X, direction.Z))))
	breachRemote:FireAllClients(Messages.Breach.Warn, side, B.Marker.Seconds)

	local cap = Config.PlayerCountScaling.MaxAliveHardCap
	local count =
		Breach.hordeSize(S, DifficultyService.getExtraPlayers(), elapsed, EnemyService.count(), cap)
	hordeTotal = count
	print(
		`[BreachService] breach {state.breaches}: {count} from the {Breach.compass(
			direction.X,
			direction.Z
		)}`
	)
	task.spawn(function()
		PauseService.wait(B.WarnSeconds)
		local times = Breach.arrivals(count, B.FloodSeconds)
		local last = 0
		for _, at in times do
			PauseService.wait(at - last)
			last = at
			if thisGeneration ~= generation or not RunStates.isLive() then
				return
			end
			if EnemyService.count() < cap then
				local model = EnemyService.spawnPicked(EnemyService.groundNear(side, 0, B.Spread))
				if model then
					table.insert(horde, model)
				end
			end
		end
		hordeArrived = true
	end)
	return true
end

-- Dev menu "Breach now": a breach round the squad at once (none while one is running).
function BreachService.breachNow(): string
	if not RunStates.isLive() then
		return "no live run"
	end
	if state.phase == "Breach" then
		return "a breach is already running"
	end
	return if startBreach(nil, B.Radio.Breach) then "breach" else "no living squad"
end

-- Each Infected that first comes within SpotRange of a living squad member.
local function lookForContact()
	local range = B.Sources.SpotRange
	local living = Squad.living()
	for _, model in CollectionService:GetTagged("Enemy") do
		if not model:IsA("Model") or seen[model] then
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			continue
		end
		for _, member in living do
			local memberRoot = member.root
			if memberRoot and (memberRoot.Position - root.Position).Magnitude <= range then
				seen[model] = true
				BreachService.loud(B.Sources.Spotted, false)
				break
			end
		end
	end
end

local function hordeAlive(): number
	local alive = 0
	for _, model in horde do
		local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			alive += 1
		end
	end
	return alive
end

local function publish()
	local threshold = Breach.threshold(S, DifficultyService.getElapsed())
	workspace:SetAttribute(
		Attributes.BreachAlert,
		math.floor(state.alert / math.max(threshold, 1) * 100 + 0.5) / 100
	)
	workspace:SetAttribute(Attributes.BreachPhase, state.phase)
	workspace:SetAttribute(
		Attributes.BreachPressure,
		math.floor(Breach.pressure(S, DifficultyService.getElapsed()) * 100 + 0.5) / 100
	)
end

local function tick(dt: number)
	if not enabled() then
		EnemyService.setTrickle(1)
		return
	end
	if idle() then
		return
	end
	sinceSpot += dt
	if sinceSpot >= SPOT_EVERY then
		sinceSpot = 0
		lookForContact()
	end
	local now = os.clock()
	local elapsed = DifficultyService.getElapsed()
	if not heldBack() then
		local site = pendingSite
		if site and state.phase ~= "Breach" then
			pendingSite = nil
			startBreach(site, B.Radio.Objective)
		else
			local early = elapsed < B.FirstAfter
			if Breach.step(S, state, dt, now, elapsed, early) then
				startBreach(nil, B.Radio.Breach)
			end
		end
	end
	if state.phase == "Tension" and not tensionSaid then
		tensionSaid = true
		say(B.Radio.Tension)
	end
	if not reliefSaid and hordeArrived and hordeAlive() <= hordeTotal * B.ReliefLineAt then
		reliefSaid = true
		say(B.Radio.Relief)
	end
	-- The trickle follows the phase; the objective, the Warden and extraction keep their own
	-- tuned pressure (only a breach thins it there).
	local trickle = Breach.trickle(S, state.phase)
	if
		state.phase ~= "Breach"
		and (heldBack() or workspace:GetAttribute(Attributes.ObjectiveActive) == true)
	then
		trickle = 1
	end
	EnemyService.setTrickle(trickle)
	publish()
end

function BreachService.reset()
	state = Breach.new()
	generation += 1
	pendingSite = nil
	table.clear(seen)
	table.clear(horde)
	hordeTotal = 0
	hordeArrived = false
	reliefSaid = true
	tensionSaid = false
	EnemyService.setTrickle(1)
	breachRemote:FireAllClients(Messages.Breach.Clear)
	publish()
end

function BreachService.init()
	breachRemote = Remotes.get("Breach")
	noticeRemote = Remotes.get("BuffNotice")
	Lifecycle.register("BreachService", {
		onRunStart = BreachService.reset,
	})
	EnemyService.addNoiseListener(onNoise)
	RunService.Heartbeat:Connect(function(dt)
		sinceStep += dt
		if sinceStep >= STEP then
			local step = sinceStep
			sinceStep = 0
			tick(step)
		end
	end)
end

return BreachService
