--!strict
-- Every Instance attribute the game reads or writes (docs/ARCHITECTURE.md F3). Server and
-- client share state through attributes; a name spelled one way on the writer and another
-- on the reader reads nil and fails silently, so every read and write goes through this
-- table: a misspelt key is a type error (the table is frozen and sealed). The values are
-- the attribute names themselves and never change meaning; add a name here, never inline.

local Attributes = table.freeze({
	-- workspace: run state (RunManager is the only writer of RunState / RunResult)
	RunState = "RunState",
	RunResult = "RunResult",
	RunStartTime = "RunStartTime",
	GamePaused = "GamePaused",
	-- workspace: the breach director (BreachService, Config.Breaches; the dev strip reads them):
	-- the alert as a share of the breach threshold, the phase (Calm / Tension / Breach /
	-- Relief), the run's pressure 0..1
	BreachAlert = "BreachAlert",
	BreachPhase = "BreachPhase",
	BreachPressure = "BreachPressure",
	-- client only, on the local Player: a cutscene holds the soldier (InsertionCutscene); no firing
	-- or using kit while it is set
	Cinematic = "Cinematic",
	-- workspace: when this run's insertion cutscene starts (server time; RunManager writes it a
	-- moment after Insert begins so every client is ready, InsertionCutscene reads it)
	InsertStartsAt = "InsertStartsAt",
	-- workspace, set by the place's Rojo project (mile14.project.json): the mission this place
	-- builds (Missions.current). Studio: set it on Workspace to test a mission; a live server
	-- reads the lobby's launch record first (Missions/init)
	Mission = "Mission",
	-- a soldier's character: their night vision is on (NightVisionService writes it from the
	-- client's toggle; every client lowers that body's goggles, client NightVision)
	NightVision = "NightVision",
	-- the goggles accessory: its frame in the head's space as modelled (lowered), set when it
	-- is fitted (Shared.Goggles)
	GoggleBase = "GoggleBase",
	ReadyCount = "ReadyCount",
	ReadyNeeded = "ReadyNeeded",
	ReadyUpEndsAt = "ReadyUpEndsAt",
	-- workspace: the lobby trip (HandoffService, RunManager): staging waits for the squad the
	-- lobby sent; at run end READY means "back to the Carrier" and the squad flies home
	SquadExpected = "SquadExpected",
	SquadArrived = "SquadArrived",
	StagingEndsAt = "StagingEndsAt",
	ReturnsHome = "ReturnsHome",
	Homebound = "Homebound",
	-- ServerStorage, Studio only: teleport data as JSON standing in for the lobby
	MockTeleportData = "MockTeleportData",
	ObjectiveActive = "ObjectiveActive",
	ObjectiveCompleted = "ObjectiveCompleted",
	ExtractionActive = "ExtractionActive",
	-- workspace: the big map is built (server DeltaXL writes; Config.DeltaXL)
	DeltaXL = "DeltaXL",
	-- workspace, Vector3: where this run's squad landed (DeltaXL writes when the draw picks a
	-- corner; ArenaService's pads and the insertion cutscene read it; none = the LZ)
	DropPoint = "DropPoint",
	-- workspace, Vector3: the mission's own landing pad (ArenaService at boot, from the mission file),
	-- for the client's insertion cutscene when no DropPoint is set
	MissionLanding = "MissionLanding",
	-- workspace, Vector3: the helicopter's pickup, set when the main objective is done
	-- (DeltaXL writes; ExtractionService reads; none = the LZ)
	PickupPoint = "PickupPoint",
	-- spawn interval multiplier while extracting (ExtractionService writes, EnemyService reads)
	ExtractionSpawnFactor = "ExtractionSpawnFactor",
	IndexActive = "IndexActive",
	ResupplyActive = "ResupplyActive",
	ResupplyCost = "ResupplyCost",
	ResupplyPool = "ResupplyPool",
	ResupplyDropIn = "ResupplyDropIn",
	ResupplyFlareCooling = "ResupplyFlareCooling", -- workspace: true while the flare cooldown runs (RequisitionService)
	ResupplyFlareReadyAt = "ResupplyFlareReadyAt", -- workspace: server time the flare cooldown ends, 0 = none (RequisitionService)
	-- Reinforcements (ReinforceService, Config.Scarcity.Reinforce): the squad's pool on the
	-- workspace; on a dead Player, when the helicopter drops them (server time, 0 = none) and
	-- beside whom (a callsign, "" = none).
	ReinforceLeft = "ReinforceLeft",
	ReinforceTotal = "ReinforceTotal",
	ReinforceAt = "ReinforceAt",
	ReinforceTo = "ReinforceTo",
	DevSpawnsOff = "DevSpawnsOff",
	DevMovesOff = "DevMovesOff", -- workspace: true turns Config.InfectedMoves off for the session (dev panel)
	-- lobby: a Lantern bird model's lift time (server time, workspace:GetServerTimeNow()) while
	-- its spot counts down; nil otherwise (LaunchService writes, LanternSpool reads)
	LiftAt = "LiftAt",
	-- workspace: the Warden's telegraphed danger shape, read by the bots
	BossDanger = "BossDanger",
	BossDangerKind = "BossDangerKind",
	BossDangerDir = "BossDangerDir",
	BossDangerLength = "BossDangerLength",
	BossDangerRadius = "BossDangerRadius",
	BossDangerUntil = "BossDangerUntil",

	-- Player: loadout, combat and dev state (LoadoutService, KitService, Squad, ...)
	Weapon = "Weapon", -- the gun in hand (Primary or Secondary); Mag / Reserve are its rounds
	Primary = "Primary",
	Secondary = "Secondary",
	Grenade = "Grenade", -- the grenade type carried
	Grenades = "Grenades", -- grenades left
	Stims = "Stims", -- stims left
	SwapUntil = "SwapUntil", -- server time the Q swap finishes (0 when not swapping)
	Mag = "Mag",
	Reserve = "Reserve",
	ReloadUntil = "ReloadUntil",
	Shield = "Shield",
	Kills = "Kills",
	-- true while this player carries an objective item (Objectives/RecoverRecord): no sprint
	Carrying = "Carrying",
	Callsign = "Callsign", -- "Pike One" ... (Squad): the name the HUD and the radio use
	MoveSpeedMult = "MoveSpeedMult",
	Ready = "Ready",
	-- the merits the mission that just ended paid this player (MeritService; RunEndUI shows
	-- it): the amount, -1 when it could not be saved, nil while a run is live
	MeritsEarned = "MeritsEarned",
	-- workspace, string: the city war line for this mission's end ("MILE 14 +1.5%"; "" for none):
	-- WarService at run end, RunEndUI shows it under the merits
	WarLine = "WarLine",
	-- workspace (lobby place), string: the city war board as JSON, [{ name, percent, open, secured,
	-- opensWith }] in board order (ContainmentBoard.read, every Config.Containment.RefreshSeconds);
	-- the Mission Board's cards read it
	WarBoard = "WarBoard",
	-- the merits and tabs on this player's record as the match last read it at a mission's end
	-- (MeritService; RunEndUI shows the wallet): nil until then, or when the read failed
	MeritsHeld = "MeritsHeld",
	-- Player (lobby, server-set): true when this visit is read-only because a save could not be
	-- read, or is newer than this server's code (SaveSlot; docs/SAVES.md). WalletUI shows it.
	SaveOffline = "SaveOffline",
	TabsHeld = "TabsHeld",
	DevGod = "DevGod",
	Bloom = "Bloom",
	-- Player: what is fitted to each of their guns, Rules/Loadout.encodeFitted
	-- ("gun.Slot=option;..."; LoadoutService in the match, LoadmasterService on the ship)
	Fitted = "Fitted",
	-- Player: the Kit Mod ranks held (match: KitModService from the record; lobby:
	-- KitModService after a buy), Rules/KitModRules.encode ("stim_carry=2;sprint_roll=1").
	-- LoadoutService (stims carried) and SprintController (stamina) read it.
	KitRanks = "KitRanks",
	LastShotAt = "LastShotAt", -- local only: the client stamps each of its own shots
	UpgradeKit = "UpgradeKit",

	-- Character: squad state, knockdown, stance (Squad, StanceService, CoverMoveService)
	SquadState = "SquadState",
	-- a player's character is crouched (StanceService, from the Stance remote): the Infected
	-- see it less far (Config.Awareness.Sight.Crouch)
	Crouching = "Crouching",
	BleedOutAt = "BleedOutAt",
	SelfReviveAt = "SelfReviveAt",
	Reviver = "Reviver",
	-- ReplicatedStorage.SquadRoster (the folder's name, kept here so writer and reader share
	-- one spelling): one entry per squad member, player or bot, always replicated (bodies
	-- stream out). Squad writes SquadState, BleedOutAt, Reviver, Callsign and Shield there
	-- too, plus these; the client's SquadPanelUI reads them. Times are server time, 0 = none.
	SquadRoster = "SquadRoster",
	SquadUserId = "SquadUserId", -- the player's UserId, 0 for a bot
	SquadHealth = "SquadHealth",
	SquadMaxHealth = "SquadMaxHealth",
	ReviveEndsAt = "ReviveEndsAt", -- when the revive in progress completes
	RespawnAt = "RespawnAt", -- when a dead bot rejoins or a dead player is reinforced
	-- The revive animation (ReviveAnimService): "" | "treat" | "finish" on the reviver,
	-- "treated" | "recover" on the casualty; where the reviver kneels and what they face.
	ReviveRole = "ReviveRole",
	ReviveKneel = "ReviveKneel", -- CFrame: the kneel point and heading
	ReviveChest = "ReviveChest", -- Vector3: the casualty's chest, to face again after a step
	KnockedUntil = "KnockedUntil",
	-- a soldier's character (players and bots): the seat they ride in, "driver" or "gunner"
	-- (VehicleService writes it; the client controllers stand still while it is set)
	Riding = "Riding",
	-- a bot's character: where to walk to take a vehicle's back seat (Vector3; VehicleService
	-- writes it while a player drives with the back seat free, BotService walks there)
	BoardAt = "BoardAt",
	-- a vehicle Model (VehicleService, Config.CallIns.<Key>.Vehicle): its call-in id, the
	-- UserId of the soldier who called it (0 = none), and its health now and full
	VehicleId = "VehicleId",
	VehicleOwner = "VehicleOwner",
	VehicleHealth = "VehicleHealth",
	VehicleMaxHealth = "VehicleMaxHealth",
	KnockGraceUntil = "KnockGraceUntil",
	-- Dangerous Infected (Config.InfectedMoves, EnemyService): on a soldier's character, true
	-- while a Runner pins them; on a Runner's model, true while it pins someone (bots shoot
	-- it first); on a soldier's character, the speed factor a Walker crowd's grab leaves.
	Pinned = "Pinned",
	Pinning = "Pinning",
	Grabbed = "Grabbed",
	CoverMoveUntil = "CoverMoveUntil",
	RootDrop = "RootDrop",
	StandHipHeight = "StandHipHeight",
	StanceSettle = "StanceSettle",
	-- Character (a player's or a bot's): true while the binoculars are up (CallInService);
	-- every client's BinocularPose raises the arms and the prop on that body.
	Spotting = "Spotting",

	-- Enemy models and the Warden's plates (EnemyService, IndexService)
	EnemyType = "EnemyType",
	BaseWalkSpeed = "BaseWalkSpeed",
	GuardFactor = "GuardFactor",
	PlateHealth = "PlateHealth",
	PlateMax = "PlateMax",
	Cracked = "Cracked",
	Exposed = "Exposed",
	Flank = "Flank",
	WeakSpot = "WeakSpot", -- a plate's share of each round passed to the body (the Warden's back)

	-- Blast visuals (AirStrikeService, KitService, MineService): the server tags each blast
	-- flash part with the CollectionService tag BlastTag (a tag, not an attribute, kept here
	-- so writer and reader share one spelling) and sets BlastPower (the call-in or grenade block's ShakePower)
	-- and, for the Anvil, BlastGlobal (shake added at any distance). CameraController reads
	-- them for the screen shake.
	BlastTag = "Blast",
	BlastPower = "BlastPower",
	BlastGlobal = "BlastGlobal",

	-- A crate's ProximityPrompt carries the crate's id (RequisitionService), read by the
	-- client's ResupplyUI to open that crate's cards.
	CrateId = "CrateId",
	-- Lobby place: a desk's ProximityPrompt carries its desk id (LobbyDesks), read by the
	-- client's DeskDialogUI.
	DeskId = "DeskId",
	-- Lobby place: a walking crew member (CrewService) carries the tag CrewTag (a tag, kept
	-- here so writer and reader share one spelling), its LobbyCrew id and its route
	-- ("x,y,z;x,y,z"), read by the client's CrewWalk.
	CrewTag = "Crew",
	CrewId = "CrewId",
	CrewRoute = "CrewRoute",
	-- Lobby place: true on a crew figure (NpcBody) once its body is dressed and its joints
	-- rebuilt, so a client's animations bind to the final rig.
	CrewReady = "CrewReady",
	-- Lobby place: an Arms Room piece (ArmsRack) and its display's back carry which display
	-- they are on ("wall" or "cabinet") and the way they face (Vector3); a piece also its
	-- length and height (Vector2, studs). Read by the client's ArmsRackUI to frame them.
	RackDisplay = "RackDisplay",
	RackFace = "RackFace",
	RackSpan = "RackSpan",

	-- Names built from a slot or a clip, so they stay in one place too.
	-- Player: the upgrade in a field-upgrade slot (UpgradeDefinitions.SLOTS).
	upgrade = function(slot: string): string
		return "Upgrade" .. slot
	end,
	-- Player: the call-in in slot 1-4 (Config.CallIns.Slots), its charges and when the next
	-- charge lands.
	callIn = function(slot: number): string
		return `CallIn{slot}`
	end,
	callInCharges = function(slot: number): string
		return `CallIn{slot}Charges`
	end,
	callInReadyAt = function(slot: number): string
		return `CallIn{slot}ReadyAt`
	end,
	-- Player: a PlayerStatsService multiplier ("MoveSpeed" -> MoveSpeedMult); the fixed
	-- name above is what the readers use.
	statMult = function(stat: string): string
		return stat .. "Mult"
	end,
	-- ReplicatedStorage.Shared: a Studio preview id for an unpublished animation clip.
	animPreview = function(clip: string): string
		return "Anim_" .. clip
	end,
})

return Attributes
