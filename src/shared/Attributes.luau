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
	ReadyCount = "ReadyCount",
	ReadyNeeded = "ReadyNeeded",
	ReadyUpEndsAt = "ReadyUpEndsAt",
	ObjectiveActive = "ObjectiveActive",
	ObjectiveCompleted = "ObjectiveCompleted",
	ExtractionActive = "ExtractionActive",
	IndexActive = "IndexActive",
	ResupplyActive = "ResupplyActive",
	ResupplyCost = "ResupplyCost",
	ResupplyPool = "ResupplyPool",
	ResupplyDropIn = "ResupplyDropIn",
	DevSpawnsOff = "DevSpawnsOff",
	-- workspace: the Warden's telegraphed danger shape, read by the bots
	BossDanger = "BossDanger",
	BossDangerKind = "BossDangerKind",
	BossDangerDir = "BossDangerDir",
	BossDangerLength = "BossDangerLength",
	BossDangerRadius = "BossDangerRadius",
	BossDangerUntil = "BossDangerUntil",

	-- Player: loadout, combat and dev state (LoadoutService, AssaultClassService, ...)
	Weapon = "Weapon",
	Mag = "Mag",
	Reserve = "Reserve",
	ReloadUntil = "ReloadUntil",
	Shield = "Shield",
	Kills = "Kills",
	MomentumStacks = "MomentumStacks",
	MoveSpeedMult = "MoveSpeedMult",
	FireRateMult = "FireRateMult",
	DamageMult = "DamageMult",
	Ready = "Ready",
	DevGod = "DevGod",
	Bloom = "Bloom",
	LastShotAt = "LastShotAt", -- local only: the client stamps each of its own shots
	UpgradeKit = "UpgradeKit",
	UpgradeCallInA = "UpgradeCallInA",
	UpgradeCallInB = "UpgradeCallInB",

	-- Character: squad state, knockdown, stance (Squad, StanceService, CoverMoveService)
	SquadState = "SquadState",
	BleedOutAt = "BleedOutAt",
	SelfReviveAt = "SelfReviveAt",
	Reviver = "Reviver",
	KnockedUntil = "KnockedUntil",
	KnockGraceUntil = "KnockGraceUntil",
	CoverMoveUntil = "CoverMoveUntil",
	RootDrop = "RootDrop",
	StandHipHeight = "StandHipHeight",
	StanceSettle = "StanceSettle",

	-- Enemy models and the Warden's plates (EnemyService, IndexService)
	EnemyType = "EnemyType",
	BaseWalkSpeed = "BaseWalkSpeed",
	GuardFactor = "GuardFactor",
	PlateHealth = "PlateHealth",
	PlateMax = "PlateMax",
	Cracked = "Cracked",
	Exposed = "Exposed",
	Flank = "Flank",

	-- Names built from a slot or a clip, so they stay in one place too.
	-- Player: the upgrade in a field-upgrade slot (UpgradeDefinitions.SLOTS).
	upgrade = function(slot: string): string
		return "Upgrade" .. slot
	end,
	-- Player: the call-in in slot 1 or 2, its charges and when the next charge lands.
	callIn = function(slot: number): string
		return `CallIn{slot}`
	end,
	callInCharges = function(slot: number): string
		return `CallIn{slot}Charges`
	end,
	callInReadyAt = function(slot: number): string
		return `CallIn{slot}ReadyAt`
	end,
	-- Player: a PlayerStatsService multiplier ("MoveSpeed" -> MoveSpeedMult, "FireRate",
	-- "Damage"); the fixed names above are what the readers use.
	statMult = function(stat: string): string
		return stat .. "Mult"
	end,
	-- ReplicatedStorage.Shared: a Studio preview id for an unpublished animation clip.
	animPreview = function(clip: string): string
		return "Anim_" .. clip
	end,
})

return Attributes
