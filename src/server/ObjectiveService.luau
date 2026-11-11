--!strict
-- The mission's objectives (docs/PROGRESSION.md > Objective pools).
--
-- The pools (Config.Objectives.Enabled): at insert the service draws one main objective
-- from the map's pool (ObjectiveDefinitions; never the same twice in a row on this server;
-- the lobby may name one in the launch data) at one of its sites on that map, shows the
-- squad its card and has Control read the brief. The squad starts it by reaching it. Side
-- objectives are drawn too but stay unknown until a squad member comes near one or Control
-- calls it out. Each objective is a module in src/server/Objectives played through one
-- interface (Objectives/Types); this service never names one. Finishing the main objective
-- pays Config.Objective.SupplyReward, drops the field-upgrade crate and calls the Warden
-- (RunManager's onComplete), exactly as the single hold did.
--
-- All state here is per run and shared by the squad (1 to 4 players and their bots);
-- nothing is per player. The one thing that outlives a run is `lastMain`.
--
-- The single hold (Config.Objectives.Enabled = false, or a map with no pool): one zone at
-- Config.Objective.ZonePosition after AppearDelay, as before the pools.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Messages = require(ReplicatedStorage.Shared.Messages)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local ObjectiveDefinitions = require(ReplicatedStorage.Shared.ObjectiveDefinitions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStates = require(ReplicatedStorage.Shared.RunStates)
local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local DifficultyService = require(script.Parent.DifficultyService)
local EnemyService = require(script.Parent.EnemyService)
local Missions = require(script.Parent.Missions)
local ObjectiveModules = require(script.Parent.Objectives)
local ObjectiveTypes = require(script.Parent.Objectives.Types)
local PauseService = require(script.Parent.PauseService)
local RequisitionService = require(script.Parent.RequisitionService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

local ObjectiveService = {}

local objectiveRemote: RemoteEvent
local noticeRemote: RemoteEvent
-- RunManager registers here: Explore -> Primary on activation, the Warden on completion.
local completionListeners: { () -> () } = {}
local activationListeners: { () -> () } = {}

local completed = false -- the main objective (or the single hold) is done this run
-- Bumped on every run reset so a pending timer from a previous run never fires into the
-- new one.
local runGeneration = 0

local MARKER_MAIN = Color3.fromRGB(230, 189, 96)
local MARKER_SIDE = Color3.fromRGB(240, 240, 240)

--------------------------------------------------------------------------------------------
-- The pools
--------------------------------------------------------------------------------------------

-- One drawn objective. A side objective is "hidden" (not built, not on the HUD) until found.
type Slot = {
	slot: string, -- "main" | "side1" | "side2" ...
	role: string, -- "main" | "side"
	index: number, -- side objectives: 1, 2, ... (when Control calls it out)
	id: string,
	row: ObjectiveDefinitions.Row,
	site: ObjectiveDefinitions.Site,
	position: Vector3,
	state: string, -- "hidden" | Rules.State
	started: boolean,
	objective: ObjectiveTypes.Objective?,
	folder: Folder?,
	hideAt: number?, -- os.clock when a finished one leaves the HUD
	gone: boolean, -- finished and off the HUD
}

local board: { Slot } = {}
local armed = false -- the squad has landed (Explore): reaching and stepping are live
local sinceArm = 0 -- seconds of live field since then
local sinceSync = 0
local lastSignature = ""
local radioFreeAt = 0 -- os.clock when Control's next line may start
-- The main objective this server played last: the next draw skips it. Never reset.
local lastMain: string? = nil
-- Dev picks for the next draw (DevTestService).
local forcedMain: string? = nil
local forcedSide: string? = nil
local forcedSite: number? = nil
local revealAll = false

local function vector(vec: ObjectiveDefinitions.Vec): Vector3
	return Vector3.new(vec[1], vec[2], vec[3])
end

local function currentMap(): ObjectiveDefinitions.Map?
	return Config.Objectives.Maps[Missions.current().Id]
end

-- Whether this run plays the pools (else the single hold).
local function pooled(): boolean
	return Config.Objectives.Enabled and currentMap() ~= nil
end

local function mainSlot(): Slot?
	for _, slot in board do
		if slot.role == "main" then
			return slot
		end
	end
	return nil
end

-- Control's lines are read one at a time, RadioGap apart, so none talks over the last.
local function say(text: string?)
	if not text or text == "" then
		return
	end
	local now = os.clock()
	local wait = math.max(radioFreeAt - now, 0)
	radioFreeAt = now + wait + Config.Objectives.RadioGap
	local generation = runGeneration
	task.delay(wait, function()
		if generation == runGeneration then
			noticeRemote:FireAllClients(text, Messages.Notice.Radio)
		end
	end)
end

local function line(slot: Slot, text: string?): string?
	return text and Rules.fill(text, slot.site.Name, slot.site.ToName)
end

local function positionOf(slot: Slot): Vector3
	local objective = slot.objective
	return if objective then objective.position() else slot.position
end

local function entryOf(slot: Slot): Rules.Entry
	local progress: ObjectiveTypes.Progress = { step = "", done = 0, total = 0, unit = "" }
	local objective = slot.objective
	if slot.state == "pending" or not objective then
		progress.step = `Go to {slot.site.Name}`
	else
		progress = objective.progress()
	end
	return {
		slot = slot.slot,
		role = slot.role,
		id = slot.id,
		name = slot.row.Name,
		why = slot.row.Why,
		place = slot.site.Name,
		step = progress.step,
		done = progress.done,
		total = progress.total,
		unit = progress.unit,
		timeLeft = progress.timeLeft,
		state = slot.state :: Rules.State,
		position = positionOf(slot),
	}
end

local function entries(): { Rules.Entry }
	local list = {}
	for _, slot in board do
		if slot.state ~= "hidden" and not slot.gone then
			table.insert(list, entryOf(slot))
		end
	end
	return list
end

-- Sends the board when anything a player can see changed (whole seconds, whole studs).
local function sync(force: boolean?)
	local list = entries()
	local parts = {}
	for _, entry in list do
		table.insert(
			parts,
			string.format(
				"%s|%s|%s|%s|%d|%d|%d|%d|%d|%d",
				entry.slot,
				entry.id,
				entry.state,
				entry.step,
				math.floor(entry.done),
				entry.total,
				math.ceil(entry.timeLeft or -1),
				math.floor(entry.position.X),
				math.floor(entry.position.Y),
				math.floor(entry.position.Z)
			)
		)
	end
	local signature = table.concat(parts, ";")
	if force or signature ~= lastSignature then
		lastSignature = signature
		objectiveRemote:FireAllClients(Messages.ObjectiveUpdate.Board, list)
	end
end

-- The crates a main objective brings: field upgrades when it starts, and the CompleteCrate
-- beside it when it ends (picked before the Warden arrives).
local function dropCrate(center: Vector3, offset: number, kind: string)
	if kind == "" then
		return
	end
	local nearest = Squad.nearestLiving(center)
	local nearestRoot = nearest and nearest.root
	local toward = if nearestRoot
		then Vector3.new(nearestRoot.Position.X - center.X, 0, nearestRoot.Position.Z - center.Z)
		else Vector3.zAxis
	local facing = if toward.Magnitude > 0.01 then toward.Unit else Vector3.zAxis
	task.spawn(
		RequisitionService.dropCrate,
		center + facing * offset,
		facing,
		(kind :: any) :: RequisitionService.CrateKind,
		false
	)
end

-- The main objective is done (or the single hold): the reward, the crate, then the Warden.
-- `after` seconds let Control's Done line be heard before his.
local function finishMain(center: Vector3, crateOffset: number, after: number)
	if completed then
		return
	end
	completed = true
	workspace:SetAttribute(Attributes.ObjectiveActive, false)
	workspace:SetAttribute(Attributes.ObjectiveCompleted, true)
	RequisitionService.addRequisition(Config.Objective.SupplyReward)
	dropCrate(center, crateOffset, Config.Objective.CompleteCrate)
	print("[ObjectiveService] Main objective complete -> the Warden")
	local generation = runGeneration
	task.delay(after, function()
		if generation ~= runGeneration then
			return
		end
		for _, listener in completionListeners do
			listener()
		end
	end)
end

local function finish(slot: Slot, state: Rules.State)
	if not Rules.isOpen(slot.state :: Rules.State) then
		return
	end
	slot.state = state
	slot.hideAt = os.clock() + Config.Objectives.DoneSeconds
	print(`[ObjectiveService] {slot.row.Name} ({slot.slot}) {state}`)
	if state == "failed" then
		say(line(slot, slot.row.Failed))
	else
		say(line(slot, slot.row.Done))
		if slot.role == "main" then
			finishMain(
				positionOf(slot),
				Config.Objective.CompleteCrateOffset,
				Config.Objectives.RadioGap
			)
		elseif (slot.row.Supply or 0) > 0 then
			RequisitionService.addRequisition(slot.row.Supply or 0)
		end
	end
	sync(true)
end

-- Builds the slot's objective at its site (props, marker). False when its module is missing.
local function build(slot: Slot): boolean
	local module = ObjectiveModules.module(slot.row.Module)
	if not module then
		warn(`[ObjectiveService] no module "{slot.row.Module}" for {slot.id}`)
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = `Objective_{slot.slot}`
	folder.Parent = workspace
	slot.folder = folder
	slot.objective = module.new({
		role = slot.role,
		label = if slot.role == "main" then "MAIN OBJECTIVE" else "SIDE OBJECTIVE",
		color = if slot.role == "main" then MARKER_MAIN else MARKER_SIDE,
		row = slot.row,
		site = slot.site,
		position = slot.position,
		folder = folder,
		complete = function()
			finish(slot, "done")
		end,
		fail = function()
			finish(slot, "failed")
		end,
	})
	slot.state = "pending"
	return true
end

-- The squad reached it: its fight begins. The main objective brings the pressure the hold
-- always did (faster spawns, a wave, the field-upgrade crate) and moves the run to Primary.
local function start(slot: Slot)
	local objective = slot.objective
	if slot.state ~= "pending" or not objective then
		return
	end
	slot.state = "active"
	slot.started = true
	if slot.role == "main" then
		workspace:SetAttribute(Attributes.ObjectiveActive, true)
		local wave = slot.row.Wave or (Config.Objective.PressureWave :: { [string]: number })
		for typeName, count in wave do
			EnemyService.spawnWave(typeName, count, slot.position)
		end
		if DifficultyService.getElapsed() >= Config.Objective.PressureBruteAfter then
			EnemyService.spawnWave("Brute", 1, slot.position)
		end
		dropCrate(slot.position, Config.Objectives.SiteCrateOffset, "upgrade")
		for _, listener in activationListeners do
			listener()
		end
	end
	print(`[ObjectiveService] {slot.row.Name} ({slot.slot}) started at {slot.site.Name}`)
	objective.begin()
	sync(true)
end

-- A side objective becomes known: Control's brief, its marker, its place on the HUD.
local function reveal(slot: Slot)
	if slot.state ~= "hidden" then
		return
	end
	if not build(slot) then
		slot.state = "failed"
		slot.gone = true
		return
	end
	say(line(slot, slot.row.Brief))
	sync(true)
end

local function near(position: Vector3, radius: number): boolean
	local _, distance = Squad.nearestLiving(position)
	return distance <= radius
end

local function teardown()
	for _, slot in board do
		local objective = slot.objective
		if objective then
			local ok, err = (pcall :: any)(objective.cleanup)
			if not ok then
				warn(`[ObjectiveService] {slot.id} cleanup failed: {err}`)
			end
		end
		if slot.folder then
			slot.folder:Destroy()
		end
	end
	table.clear(board)
	armed = false
	sinceArm = 0
	lastSignature = ""
	workspace:SetAttribute(Attributes.ObjectiveActive, false)
end

local function newSlot(
	name: string,
	role: string,
	index: number,
	id: string,
	siteIndex: number?
): Slot?
	local map = currentMap()
	local row = Config.Objectives.Rows[id]
	local sites = map and map.Sites[id]
	if not row or not sites or #sites == 0 then
		warn(`[ObjectiveService] {id} cannot be played on {Missions.current().Id}`)
		return nil
	end
	local chosen = if siteIndex and sites[siteIndex]
		then siteIndex
		else Rules.pick(#sites, math.random())
	local site = sites[chosen]
	return {
		slot = name,
		role = role,
		index = index,
		id = id,
		row = row,
		site = site,
		position = vector(site.Position),
		state = "hidden",
		started = false,
		objective = nil,
		folder = nil,
		hideAt = nil,
		gone = false,
	}
end

-- Draws this run's objectives. `requested` is a main objective asked for from outside (the
-- lobby's launch data): played only if this map's pool offers it.
local function draw(requested: string?)
	local map = currentMap()
	if not map then
		return
	end
	local mainId: string? = nil
	if forcedMain and Rules.offers(map.Main, forcedMain) then
		mainId = forcedMain
	elseif Rules.offers(map.Main, requested) then
		mainId = requested
	else
		mainId = Rules.draw(map.Main, lastMain, math.random())
	end
	if mainId then
		lastMain = mainId
		local slot = newSlot("main", "main", 0, mainId, if forcedMain then forcedSite else nil)
		if slot and build(slot) then
			table.insert(board, slot)
		end
	end
	local rolls = {}
	for _ = 1, Config.Objectives.SideCount do
		table.insert(rolls, math.random())
	end
	local sideForced = if forcedSide and Rules.offers(map.Side, forcedSide) then forcedSide else nil
	for index, id in Rules.drawSides(map.Side, Config.Objectives.SideCount, rolls, sideForced) do
		local siteIndex = if id == sideForced and not forcedMain then forcedSite else nil
		local slot = newSlot(`side{index}`, "side", index, id, siteIndex)
		if slot then
			table.insert(board, slot)
		end
	end
end

local function stepBoard(deltaTime: number)
	if #board == 0 or not armed or PauseService.isPaused() or not RunStates.isLive() then
		return
	end
	sinceArm += deltaTime
	local now = os.clock()
	local settings = Config.Objectives
	for _, slot in board do
		if slot.state == "hidden" then
			if
				revealAll
				or near(slot.position, settings.RevealRadius)
				or sinceArm >= Rules.revealAt(slot.index, settings.RevealAfter)
			then
				reveal(slot)
			end
		end
		if slot.state == "pending" then
			local radius = slot.row.StartRadius
			local waited = slot.role ~= "main" or sinceArm >= settings.GraceSeconds
			if waited and (radius <= 0 or near(positionOf(slot), radius)) then
				start(slot)
			end
		elseif slot.state == "active" then
			local objective = slot.objective
			if objective then
				local ok, err = (pcall :: any)(objective.step, deltaTime)
				if not ok then
					-- A broken objective never holds the run up: the main one counts as done.
					warn(`[ObjectiveService] {slot.id} failed in step: {err}`)
					finish(slot, if slot.role == "main" then "done" else "failed")
				end
			end
		end
	end
	-- A finished objective leaves the HUD after a moment.
	for _, slot in board do
		if not slot.gone and slot.hideAt and now >= slot.hideAt then
			slot.gone = true
		end
	end
	sinceSync += deltaTime
	if sinceSync >= settings.SyncInterval then
		sinceSync = 0
		sync()
	end
end

-- RunManager, on Insert: the draw, the main objective's card and Control's lines, while the
-- squad lands. The single hold has nothing to say here.
function ObjectiveService.brief(requested: string?)
	if not pooled() or #board > 0 or completed then
		return
	end
	draw(requested)
	local main = mainSlot()
	say(Config.Objectives.Frame)
	if main then
		objectiveRemote:FireAllClients(
			Messages.ObjectiveUpdate.Brief,
			main.row.Name,
			main.row.Why,
			main.site.Name
		)
		say(line(main, main.row.Brief))
		print(`[ObjectiveService] main objective: {main.row.Name} at {main.site.Name}`)
	end
	sync(true)
end

-- How many side objectives the squad finished this run (the result sent home).
function ObjectiveService.sidesDone(): number
	local count = 0
	for _, slot in board do
		if slot.role == "side" and slot.state == "done" then
			count += 1
		end
	end
	return count
end

--------------------------------------------------------------------------------------------
-- The single hold (Config.Objectives.Enabled = false)
--------------------------------------------------------------------------------------------

local zonePart: BasePart?
local progress = 0
local heartbeatConnection: RBXScriptConnection?
local timeSinceSync = 0

local function createZone(): BasePart
	local part = Instance.new("Part")
	part.Name = "ObjectiveZone"
	part.Size = Config.Objective.ZoneSize
	part.Position = Config.Objective.ZonePosition
	part.Anchored = true
	part.CanCollide = false
	-- CanQuery off so weapon raycasts pass through the zone; GetPartsInPart
	-- still works with the zone itself as the query region.
	part.CanQuery = false
	part.Transparency = 0.5
	part.Color = Color3.fromRGB(255, 220, 0)
	part.Material = Enum.Material.Neon

	local marker = Instance.new("BillboardGui")
	marker.Name = "ObjectiveMarker"
	marker.Size = UDim2.fromOffset(220, 50)
	marker.StudsOffset = Vector3.new(0, 10, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 1000

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "OBJECTIVE"
	label.TextColor3 = Color3.fromRGB(255, 220, 0)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = marker

	marker.Parent = part
	part.Parent = workspace
	return part
end

-- The Gate lamp post's siren head (ArenaService) carries the alarm loop.
local siren: Sound? = nil

local function startSiren()
	local head = workspace:FindFirstChild("Siren", true)
	if head and head:IsA("BasePart") then
		siren = WorldSounds.loopOn(head, "ambience", "amb_siren")
	end
end

local function stopSiren()
	if siren then
		siren:Destroy()
		siren = nil
	end
end

local function clearHold()
	stopSiren()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if zonePart then
		zonePart:Destroy()
		zonePart = nil
	end
end

local function completeHold()
	if completed then
		return
	end
	clearHold()
	objectiveRemote:FireAllClients(
		Messages.ObjectiveUpdate.Completed,
		Config.Objective.RequiredSeconds
	)
	-- The second upgrade crate lands beside the site crate, toward the nearest soldier.
	finishMain(Config.Objective.ZonePosition, Config.Objective.CompleteCrateOffset, 0)
end

local function onHoldHeartbeat(deltaTime: number)
	local zone = zonePart
	if completed or not zone or PauseService.isPaused() then
		return
	end

	-- Any living member (player or bot) holds the zone; the HUD shows how many players are in.
	local anyone, playersIn, playersLiving = Squad.zoneCount(zone)
	if anyone then
		progress += deltaTime
	end

	timeSinceSync += deltaTime
	if timeSinceSync >= Config.Objective.SyncInterval then
		timeSinceSync = 0
		objectiveRemote:FireAllClients(
			Messages.ObjectiveUpdate.Progress,
			math.min(progress, Config.Objective.RequiredSeconds),
			playersIn,
			playersLiving
		)
	end

	if progress >= Config.Objective.RequiredSeconds then
		completeHold()
	end
end

local function activateHold()
	if completed or zonePart then
		return
	end
	zonePart = createZone()
	startSiren()
	objectiveRemote:FireAllClients(Messages.ObjectiveUpdate.Started, 0)
	heartbeatConnection = RunService.Heartbeat:Connect(onHoldHeartbeat)
	-- Pressure: faster spawns while active + a typed wave around the zone.
	workspace:SetAttribute(Attributes.ObjectiveActive, true)
	for typeName, count in Config.Objective.PressureWave :: { [string]: number } do
		EnemyService.spawnWave(typeName, count, Config.Objective.ZonePosition)
	end
	if DifficultyService.getElapsed() >= Config.Objective.PressureBruteAfter then
		EnemyService.spawnWave("Brute", 1, Config.Objective.ZonePosition)
	end
	-- The site crate: field upgrade cards facing the nearest living member (quiet: the
	-- pressure wave above is the fight).
	dropCrate(Config.Objective.ZonePosition, 0, "upgrade")
	print("[ObjectiveService] Objective active")
	for _, listener in activationListeners do
		listener()
	end
end

--------------------------------------------------------------------------------------------
-- Both
--------------------------------------------------------------------------------------------

-- RunManager subscribes: Primary -> Index -> Extract when the main objective is done.
function ObjectiveService.onComplete(listener: () -> ())
	table.insert(completionListeners, listener)
end

-- RunManager: Explore -> Primary when the main objective starts.
function ObjectiveService.onActivated(listener: () -> ())
	table.insert(activationListeners, listener)
end

-- Dev shortcut: the main objective is done now (works even before it starts).
function ObjectiveService.forceComplete()
	local main = mainSlot()
	if main and Rules.isOpen(main.state :: Rules.State) then
		finish(main, "done")
	elseif pooled() then
		finishMain(Config.Objective.ZonePosition, 0, 0)
	else
		completeHold()
	end
end

-- Dev: start the main objective now, wherever the squad is (the single hold: bring the
-- zone in instead of after Config.Objective.AppearDelay).
function ObjectiveService.activateNow()
	if pooled() then
		if #board == 0 then
			ObjectiveService.brief(nil)
		end
		armed = true
		local main = mainSlot()
		if main then
			start(main)
		end
		return
	end
	runGeneration += 1
	activateHold()
end

-- RunManager, on Explore: the squad has landed. The pools: objectives can be reached and
-- found from now. The single hold: the timer that brings the zone in.
function ObjectiveService.arm()
	if pooled() then
		if #board == 0 then
			ObjectiveService.brief(nil)
		end
		armed = true
		return
	end
	local generation = runGeneration
	task.delay(Config.Objective.AppearDelay, function()
		if generation == runGeneration then
			activateHold()
		end
	end)
end

-- Dev: draw again now, with `mainId` and / or `sideId` picked and `siteIndex` choosing the
-- picked one's site (all nil = a fresh random draw). Every side objective is known at once
-- so each can be tried in a minute. Returns what was drawn, or why not.
function ObjectiveService.redraw(mainId: string?, sideId: string?, siteIndex: number?): string
	if not pooled() then
		return "the pools are off (Config.Objectives.Enabled) or this map has none"
	end
	if completed then
		return "the main objective is already done this run: RestartRun first"
	end
	local map = currentMap() :: ObjectiveDefinitions.Map
	if mainId and not Rules.offers(map.Main, mainId) then
		return `no main objective "{mainId}" on this map ({ObjectiveService.list()})`
	end
	if sideId and not Rules.offers(map.Side, sideId) then
		return `no side objective "{sideId}" on this map ({ObjectiveService.list()})`
	end
	local live = RunStates.isLive()
	teardown()
	EnemyService.setQuiet(nil)
	runGeneration += 1 -- drops Control's queued lines from the last draw
	radioFreeAt = 0
	forcedMain, forcedSide, forcedSite = mainId, sideId, siteIndex
	revealAll = true
	-- A redraw may land on the same main objective again: it is the dev's pick.
	if not mainId then
		lastMain = nil
	end
	ObjectiveService.brief(nil)
	forcedMain, forcedSide, forcedSite = nil, nil, nil
	armed = live
	local names = {}
	for _, slot in board do
		table.insert(names, `{slot.slot} = {slot.id} at {slot.site.Name}`)
	end
	return table.concat(names, ", ")
end

-- Dev: the ids this map offers, for the commands above.
function ObjectiveService.list(): string
	local map = currentMap()
	if not map then
		return "no pool on this map"
	end
	local main, side = {}, {}
	for _, pick in map.Main do
		table.insert(main, `{pick.Id} ({#map.Sites[pick.Id]} sites)`)
	end
	for _, pick in map.Side do
		table.insert(side, `{pick.Id} ({#map.Sites[pick.Id]} sites)`)
	end
	return `main: {table.concat(main, ", ")}; side: {table.concat(side, ", ")}`
end

function ObjectiveService.reset()
	runGeneration += 1 -- cancels pending timers and queued radio lines from the last run
	teardown()
	clearHold()
	completed = false
	progress = 0
	timeSinceSync = 0
	sinceSync = 0
	radioFreeAt = 0
	revealAll = false
	workspace:SetAttribute(Attributes.ObjectiveCompleted, false)
	objectiveRemote:FireAllClients(Messages.ObjectiveUpdate.Completed, 0) -- hides the hold's line
	objectiveRemote:FireAllClients(Messages.ObjectiveUpdate.Board, {})
end

function ObjectiveService.init()
	Lifecycle.register("ObjectiveService", {
		onRunStart = ObjectiveService.reset,
	})
	objectiveRemote = Remotes.get("ObjectiveUpdate")
	noticeRemote = Remotes.get("BuffNotice")
	-- A client that has just loaded asks for the board it missed.
	objectiveRemote.OnServerEvent:Connect(function(player: Player, kind: unknown)
		if kind == Messages.ObjectiveUpdate.Request and #board > 0 then
			objectiveRemote:FireClient(player, Messages.ObjectiveUpdate.Board, entries())
		end
	end)
	RunService.Heartbeat:Connect(stepBoard)
end

return ObjectiveService
