--!strict
-- All gameplay tuning values live here. Systems read from this module so
-- balance changes never require touching system code.

local Config = {
	Player = {
		MaxHealth = 100,
		WalkSpeed = 16,
		SprintSpeed = 24,
	},

	-- Over-the-shoulder camera (client-side, scriptable).
	Camera = {
		ShoulderOffset = Vector2.new(2.5, 0.5), -- right / up offset from the character
		Distance = 10, -- studs behind the shoulder pivot
		MinDistance = 6, -- mouse wheel zoom limits
		MaxDistance = 16,
		Sensitivity = 0.25, -- degrees of rotation per pixel of mouse movement
		MaxPitch = 75, -- degrees up/down
	},

	Weapon = {
		Damage = 6, -- DPS stays 60 with the faster fire rate (same time-to-kill)
		FireCooldown = 0.1, -- seconds between shots (10/sec)
		ProjectileSpeed = 180, -- studs per second
		ProjectileLifetime = 3, -- seconds before despawn
		ProjectileSize = Vector3.new(0.4, 0.4, 1.4),
		MaxAimDistance = 1000, -- how far the aim raycast reaches
	},

	-- XP and leveling (Sprint 4). Orb value comes from the enemy type
	-- (EnemyDefinitions.XPReward). Reaching the next level requires
	-- BaseThreshold * ThresholdGrowth^(level-1).
	XP = {
		MagnetRadius = 12, -- studs: orb starts flying toward the player
		CollectRadius = 3, -- studs: orb is absorbed and grants XP
		OrbFlySpeed = 40, -- studs per second while magnetized
		OrbLifetime = 60, -- seconds before an uncollected orb despawns
		BaseThreshold = 100,
		ThresholdGrowth = 1.25,
	},

	-- Item rarities (Sprint 14). Weights drive per-card rarity rolls.
	ItemRarities = {
		Common = { DisplayName = "Common", Color = Color3.fromRGB(170, 170, 170), Weight = 70 },
		Uncommon = { DisplayName = "Uncommon", Color = Color3.fromRGB(80, 220, 120), Weight = 25 },
		Legendary = { DisplayName = "Legendary", Color = Color3.fromRGB(255, 75, 75), Weight = 5 },
	},
	-- Every Nth level-up guarantees at least one Uncommon-or-better card.
	RarityGuaranteeEvery = 4,

	-- Items (Sprint 5). Definitions in shared/ItemDefinitions.luau; full spec
	-- in docs/ITEMS_MVP.md. Level-up offers ChoicesPerLevel distinct items.
	Items = {
		ChoicesPerLevel = 3,
		HollowPoint = {
			BleedChancePerStack = 0.15,
			BleedDuration = 3, -- seconds; reapplying refreshes, never stacks
			BleedTickDamage = 4, -- damage per second
		},
		Adrenaline = {
			HealthFraction = 0.3, -- active while health is below this fraction
			MoveSpeedPerStack = 0.2,
			FireRatePerStack = 0.2,
		},
		Drone = {
			ProcChancePerStack = 0.1, -- per enemy kill
			Duration = 20, -- seconds
			Damage = 6, -- per drone shot
			FireInterval = 0.6, -- seconds between shots
			MaxActivePerPlayer = 3,
			TargetRange = 60, -- studs
			FollowHeight = 5, -- studs above the player
			FollowRadius = 4, -- studs beside the player
			ProjectileSpeed = 120,
		},
		AmmoCache = {
			BaseInterval = 25, -- seconds between cache spawns at 1 stack
			IntervalReductionPerStack = 3, -- seconds faster per extra stack
			MinInterval = 10,
			CacheLifetime = 20, -- seconds before an untouched cache despawns
			CollectRadius = 4, -- studs
			SpawnDistanceMin = 12, -- studs from the player
			SpawnDistanceMax = 20,
			BuffDuration = 8, -- seconds
			BuffBonus = 0.25, -- +25% for Damage/FireRate/MoveSpeed buffs
			ShieldHP = 25, -- temporary max-health boost for the Shield buff
		},
		Kevlar = {
			ShieldPerStack = 20, -- temp max health per stack on each level-up
			ShieldCap = 80, -- max concurrent shield from this item
			Duration = 15, -- seconds each grant lasts
		},
		Vampire = {
			KillsPerHeal = 12, -- credited kills per heal
			HealPerStack = 10,
		},
		Ricochet = {
			ChancePerStack = 0.12,
			ChanceCap = 0.6,
			DamageFactor = 0.5, -- of the triggering hit
			Range = 20, -- studs from the hit
			MaxTargets = 3, -- hard cap (1 + stacks/3 up to this)
		},
		Shrapnel = {
			ShotsPerBurst = 6, -- every Nth player-fired shot
			DamageFactor = 0.6,
			MaxExtra = 5, -- extra projectiles cap (1 stack = 2)
		},
		Incendiary = {
			ChancePerStack = 0.15,
			ChanceCap = 0.6,
			Radius = 8,
			Duration = 5,
			DamagePerSecond = 5,
			MaxPools = 6, -- per player; oldest removed
		},
		Mine = {
			BaseInterval = 18, -- seconds; -3 per extra stack
			IntervalPerStack = 3,
			MinInterval = 9,
			BaseDamage = 30, -- +5 per extra stack
			DamagePerStack = 5,
			MaxDamage = 45,
			TriggerRadius = 5,
			BlastRadius = 10,
			Lifetime = 25,
			MaxMines = 5, -- per player; oldest removed
		},
		ShockCoil = {
			BaseCooldown = 12, -- seconds; -2 per extra stack
			CooldownPerStack = 2,
			MinCooldown = 6,
			BaseDamage = 18, -- +4 per extra stack
			DamagePerStack = 4,
			MaxDamage = 30,
			Radius = 14,
			SlowFactor = 0.7, -- enemy WalkSpeed multiplier while slowed
			SlowDuration = 2,
		},
		HunterMark = {
			Interval = 10, -- seconds between marks
			Duration = 6,
			Range = 70, -- studs; marks the highest-health enemy
			BonusPerStack = 0.2, -- extra damage taken by the marked target
			BonusCap = 1,
		},
		AirSupport = {
			BaseKillRequirement = 30, -- kills per strike at 1 stack
			ReductionPerStack = 5, -- fewer kills per extra stack
			MinKillRequirement = 10,
			WarningDelay = 1.5, -- seconds the red marker shows before impact
			BlastRadius = 16, -- studs
			BlastDamage = 60,
			SearchRange = 100, -- studs around the player to find a cluster
		},
	},

	-- Hold Position objective V1. Pays out through XPService on completion.
	Objective = {
		AppearDelay = 180, -- seconds after server start before the zone appears
		RequiredSeconds = 45, -- total accumulated seconds inside the zone
		PressureWave = { Walker = 8, Runner = 2 }, -- spawned around the zone on appear
		PressureBruteAfter = 210, -- also +1 Brute if the run is older than this (seconds)
		XPReward = 500,
		ZoneSize = Vector3.new(30, 1, 30),
		ZonePosition = Vector3.new(60, 0.5, 60), -- sits on the baseplate surface
		SyncInterval = 0.1, -- seconds between progress updates to the UI
	},

	-- Extraction phase (Sprint 12): starts when the objective completes. Fixed
	-- test location far from the objective at (60,_,60); ~212 studs away.
	Extraction = {
		HoldDuration = 30, -- accumulated seconds inside the zone to win
		ZoneSize = Vector3.new(28, 1, 28),
		ZonePosition = Vector3.new(-90, 0.6, -90),
		SyncInterval = 0.1,
		PressureWave = { Walker = 12, Runner = 4, Brute = 1 },
		SpawnFactor = 0.8, -- spawn interval multiplier while extracting (+20%)
	},

	-- Difficulty scaling (Sprint 8 tuning): continuous per-minute scaling
	-- with caps, per docs/PLAN.md Sprint 8 targets. No enemy speed scaling.
	Difficulty = {
		HealthPerMinute = 0.08, -- +8% enemy max health per elapsed minute
		HealthCap = 2.25,
		DamagePerMinute = 0.04, -- +4% enemy contact damage per minute
		DamageCap = 1.75,
		SpawnIntervalDecayPerMinute = 0.85, -- spawn interval multiplier per minute
		MinSpawnInterval = 0.6, -- seconds
		-- Population cap ramps with run time: { upToSeconds, maxAlive }.
		MaxAliveSchedule = { { 75, 14 }, { 180, 22 }, { 300, 32 }, { 480, 45 } },
		MaxAliveLate = 60, -- after the schedule (lower this first if perf drops)
		ObjectiveSpawnFactor = 0.8, -- spawn interval multiplier while objective active
	},

	-- Spawn director phases (Sprint 9): type weights per run-time window,
	-- plus fairness caps. Enemy stats live in shared/EnemyDefinitions.luau.
	Spawning = {
		Phases = {
			{ Until = 75, Weights = { Walker = 100 } },
			{ Until = 180, Weights = { Walker = 80, Runner = 20 } },
			{ Until = 300, Weights = { Walker = 65, Runner = 25, Brute = 10 } },
			{ Until = 480, Weights = { Walker = 55, Runner = 30, Brute = 15 } },
			{ Until = math.huge, Weights = { Walker = 45, Runner = 35, Brute = 20 } },
		},
		MaxRunnerRatio = 0.35, -- Runners may be at most this share of alive enemies
		BruteCapSchedule = { { 300, 1 }, { 480, 2 } }, -- { upToSeconds, max Brutes }
		BruteCapLate = 3,
	},

	-- The Infected. Base values at difficulty step 0; see Difficulty above.
	Zombies = {
		SpawnInterval = 2, -- base seconds between spawns (decays per minute)
		InitialCount = 5, -- Walkers spawned right at run start
		MinSpawnDistance = 35, -- studs from the player
		MaxSpawnDistance = 50,
		CorpseLifetime = 1.5, -- seconds before a dead zombie is removed
	},
}

return Config
