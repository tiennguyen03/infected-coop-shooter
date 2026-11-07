--!strict
-- All gameplay tuning values live here. Systems read from this module so
-- balance changes never require touching system code.

local Config = {
	Player = {
		MaxHealth = 100,
		WalkSpeed = 16,
		SprintSpeed = 24,
		-- Stances (2026-11-07): LeftControl toggles crouch, C toggles prone; sprint, a vault
		-- or a climb stands the body up. Speeds are factors of WalkSpeed (no sprint while low).
		Stances = {
			CrouchSpeedFactor = 0.5,
			ProneSpeedFactor = 0.25,
			-- Seconds the enter/exit clips take (their rate is scaled to this); no stance
			-- change while one plays.
			TransitionTime = { crouch = 0.45, prone = 0.8 },
		},
	},

	-- Vault / climb (2026-11-07) replaces the stock jump: Space, or sprinting into cover,
	-- sends the body over or onto whatever is in front of it. Heights are the ledge top
	-- above the feet. Jersey 2.75, hesco 4.6, bunker 6.3, humvee 7.1, container 9.6 pass;
	-- T-walls and buses (12.5) do not.
	Movement = {
		Reach = 3.2, -- studs ahead of the body that count as "in front"
		MinHeight = 1.2,
		VaultMaxHeight = 5, -- up to here the body goes over thin cover (vault clip)
		ClimbMaxHeight = 10.5, -- up to here it mantles onto the top (climb clip)
		VaultDepth = 6.5, -- cover thinner than this, with ground behind, is vaulted over
		Headroom = 5, -- clear studs needed above a landing to stand there
		VaultDuration = 0.55, -- seconds; the clip rate is scaled to match (0.9 before 2026-11-07)
		ClimbDuration = 1.1, -- (1.8 before 2026-11-07)
		-- Infected melee skips a body going over cover (CoverMoveService): the window is the
		-- move's duration plus Grace; a new window opens no sooner than Cooldown after the
		-- last one closed, so spamming the remote never gives standing immunity.
		CoverImmunity = { Grace = 0.15, Cooldown = 0.4 },
		-- Weight (client MomentumController, 2026-11-07): the body's velocity eases toward
		-- the input instead of snapping, so turning and stopping cost time and kiting
		-- takes footwork. Studs/s per second; Deceleration also applies when reversing.
		Momentum = {
			Acceleration = 60, -- 0 -> walk (16) in ~0.27 s, 0 -> sprint (24) in 0.4 s
			Deceleration = 75, -- walk -> stop in ~0.2 s; a full reversal ~0.45 s
		},
		-- Sprint + LeftControl: a short roll along the move direction. Infected melee skips
		-- the body for the roll (CoverMoveService, same window as a vault).
		Roll = { Duration = 0.8, Speed = 25, Cooldown = 1 },
		-- Sprint + C: a longer slide that bleeds speed from StartSpeed to EndSpeed. No
		-- immunity; it covers ground, the roll dodges.
		Slide = { Duration = 0.95, StartSpeed = 30, EndSpeed = 14, Cooldown = 1.2 },
		AutoVaultSprinting = true, -- sprinting into cover vaults without pressing Space
		Infected = {
			LowHeight = 5, -- a top above this uses the form's climbHigh clip (Runners)
			-- Climb time per form; the clip rate scales to it. A form without a row (or
			-- without EnemyDefinitions.ClimbHeight) never climbs.
			Duration = { Walker = 2.2, Runner = 1.2 },
		},
	},

	-- Hit marker (client HitMarkerUI): four ticks round the crosshair on your own hits,
	-- replacing floating damage numbers (2026-11-07). Seconds and pixels.
	HitMarker = {
		Duration = 0.16,
		KillDuration = 0.4,
		Gap = 7, -- from the crosshair centre to the inner end of a tick
		Length = 7,
		Thickness = 2,
		HeadshotScale = 1.35,
		KillScale = 1.6,
		Colors = {
			hit = Color3.fromRGB(255, 255, 255),
			headshot = Color3.fromRGB(255, 214, 90),
			kill = Color3.fromRGB(235, 60, 50),
		},
	},

	-- Over-the-shoulder camera (client-side, scriptable).
	Camera = {
		ShoulderOffset = Vector2.new(2.5, 0.5), -- right / up offset from the character
		Distance = 10, -- studs behind the shoulder pivot
		MinDistance = 6, -- mouse wheel zoom limits
		MaxDistance = 16,
		Sensitivity = 0.25, -- degrees of rotation per pixel of mouse movement
		MaxPitch = 75, -- degrees up/down
		-- Pivot height above the root part per stance (stand is roughly head height).
		PivotHeight = { stand = 2, crouch = 0.6, prone = -1.2 },
		PivotEaseTime = 0.25,
	},

	Weapon = {
		Damage = 12, -- Sprint 13 tune: punchier shots that matter vs late scaled HP
		FireCooldown = 0.15, -- slower fire (6.7/sec); DPS 80, up from 60
		-- The rifle is hitscan (2026-11-07): one raycast per shot, damage lands the same
		-- frame. Range caps the ray; the tracer is client-drawn feedback only.
		Range = 400,
		TracerDuration = 0.06,
		HeadshotMultiplier = 2.0, -- on a Head hit (EnemyDefinitions may override per form)
		-- Drones still fly projectiles (ProjectileServer.fire): their speed and lifetime.
		ProjectileSpeed = 180, -- studs per second
		ProjectileLifetime = 3, -- seconds before despawn
		ProjectileSize = Vector3.new(0.4, 0.4, 1.4),
		MaxAimDistance = 1000, -- how far the aim raycast reaches
		-- Spread (2026-11-07): half-angle of the cone a shot can land in, degrees. Hip fire
		-- puts a round about a stud off at 40 studs; aiming down sights (hold RMB) tightens it.
		HipSpread = 1.5,
		ADS = {
			Spread = 0.3,
			MoveSpeedFactor = 0.6, -- walk speed while aiming; sprint is off
			CameraDistance = 5, -- closer over the shoulder (Camera.Distance is the hip value)
			ShoulderOffset = Vector2.new(1.8, 0.4),
			FOV = 55, -- degrees (hip is the engine default, 70)
			EnterTime = 0.15, -- seconds to settle into or out of the sights
		},
	},

	-- Body animations: clip names from assets/animations (Mixamo, retargeted by
	-- assets/animations/build/retarget.py). Ids are the published Roblox animations
	-- (assets/animations/ASSET_IDS.md); "" = not published yet, Studio previews the
	-- retargeted clip instead (Shared.Animations).
	Animations = {
		Ids = {
			rifle_idle = "rbxassetid://122515718718000",
			rifle_walk = "rbxassetid://92413668101403",
			rifle_run = "rbxassetid://118498825159938",
			rifle_aiming_idle = "rbxassetid://118354711732287",
			firing_rifle = "rbxassetid://105703457997267",
			hit_reaction = "rbxassetid://133406752934021",
			death_from_the_front = "rbxassetid://83057356866086",
			grenade_throw = "rbxassetid://75927017628888",
			zombie_idle = "rbxassetid://73378661223074",
			zombie_walk = "rbxassetid://93977319969684",
			zombie_running = "rbxassetid://100013290488551",
			zombie_attack = "rbxassetid://132418428008740",
			zombie_death = "rbxassetid://114479010727665",
			mutant_walking = "rbxassetid://122206186131360",
			mutant_swiping = "rbxassetid://132433419557439",
			-- Generated by Roblox Studio's animation generator (not a Mixamo clip).
			hocker_spit = "rbxassetid://115163090345190",
			-- Mixamo Rifle 8-Way Locomotion Pack: walk and sprint in four directions.
			loco_walk_f = "rbxassetid://72453243039559",
			loco_walk_b = "rbxassetid://101874556606898",
			loco_walk_l = "rbxassetid://92769065015032",
			loco_walk_r = "rbxassetid://98171299647298",
			loco_run_f = "rbxassetid://96627253913116",
			loco_run_b = "rbxassetid://124184233710991",
			loco_run_l = "rbxassetid://107986387272761",
			loco_run_r = "rbxassetid://120945922251815",
			-- Movement set (2026-11-07): vault/climb, crouch, prone; Infected climbs and
			-- extras (Crawler move, flinch, Hocker scream) for later.
			vault_low = "rbxassetid://122259453837052",
			sprint_roll = "", -- Studio preview until published
			climb_ledge = "rbxassetid://87799425638897",
			climb_low = "rbxassetid://111567195502844",
			climb_high = "rbxassetid://97579324656436",
			crouch_idle = "rbxassetid://113612526967682",
			crouch_enter = "rbxassetid://71721301273830",
			crouch_exit = "rbxassetid://107144927642142",
			crouch_aim = "rbxassetid://71587042642064",
			crouch_walk_f = "rbxassetid://77839768187391",
			crouch_walk_b = "rbxassetid://138416813991518",
			crouch_walk_l = "rbxassetid://83640530264066",
			crouch_walk_r = "rbxassetid://112573925838638",
			prone_idle = "rbxassetid://106012212148241",
			prone_enter = "rbxassetid://128780493444612",
			prone_exit = "rbxassetid://109680376138254",
			prone_fire = "rbxassetid://133140641450239",
			prone_walk_f = "rbxassetid://98858185080842",
			prone_walk_b = "rbxassetid://88994657013818",
			zombie_crawl = "rbxassetid://101414875993165",
			zombie_stumble = "rbxassetid://78987755637091",
			zombie_scream = "rbxassetid://91289969066728",
		},
		-- The Chosen (one class for now): which clip plays for each state.
		Assault = {
			idle = "rifle_idle",
			-- Locomotion blends four directional clips by the direction of travel in the
			-- body's frame (the body faces the camera, so strafing and backpedalling read).
			walk = {
				forward = "loco_walk_f",
				back = "loco_walk_b",
				left = "loco_walk_l",
				right = "loco_walk_r",
			},
			run = {
				forward = "loco_run_f",
				back = "loco_run_b",
				left = "loco_run_l",
				right = "loco_run_r",
			},
			aim = "rifle_aiming_idle", -- held while the trigger is down (upper body)
			fire = "firing_rifle", -- recoil per shot (upper body)
			hit = "hit_reaction", -- flinch on damage (upper body)
			death = "death_from_the_front",
			breach = "grenade_throw", -- E: throwing the breach charge (upper body)
			-- Stances: each has an idle, a directional move blend and an aim overlay; enter
			-- and exit clips play over the switch.
			crouch = {
				idle = "crouch_idle",
				walk = {
					forward = "crouch_walk_f",
					back = "crouch_walk_b",
					left = "crouch_walk_l",
					right = "crouch_walk_r",
				},
				aim = "crouch_aim",
				enter = "crouch_enter",
				exit = "crouch_exit",
			},
			prone = {
				idle = "prone_idle",
				walk = { forward = "prone_walk_f", back = "prone_walk_b" }, -- sideways crawls forward
				aim = "prone_fire",
				enter = "prone_enter",
				exit = "prone_exit",
			},
			vault = "vault_low", -- over jersey / hesco
			roll = "sprint_roll", -- sprint + LeftControl
			slide = "running_slide", -- sprint + C (no id until the clip is downloaded)
			climb = "climb_ledge", -- onto bunker / humvee / container
		},
		-- The Infected, per type (EnemyDefinitions).
		Infected = {
			Walker = {
				move = "zombie_walk",
				attack = "zombie_attack",
				death = "zombie_death",
				climb = "climb_low",
			},
			Runner = {
				move = "zombie_running",
				attack = "zombie_attack",
				death = "zombie_death",
				climb = "climb_low",
				climbHigh = "climb_high", -- above EnemyDefinitions ClimbLowHeight
			},
			Brute = { move = "mutant_walking", attack = "mutant_swiping", death = "zombie_death" },
			Hocker = { move = "zombie_walk", attack = "hocker_spit", death = "zombie_death" },
		},
		-- Ground speed (studs/s) at which each locomotion clip plays at 1x; the track rate
		-- scales with the actual speed so feet do not slide.
		MoveClipSpeed = {
			rifle_walk = 12,
			rifle_run = 22,
			-- Measured by retarget.py from the pack's baked root motion.
			loco_walk_f = 13.3,
			loco_walk_b = 13.3,
			loco_walk_l = 13.3,
			loco_walk_r = 13.3,
			loco_run_f = 19.9,
			loco_run_b = 19.9,
			loco_run_l = 19.9,
			loco_run_r = 19.9,
			zombie_walk = 8,
			zombie_running = 16,
			mutant_walking = 6,
			crouch_walk_f = 5.6, -- measured by retarget.py
			crouch_walk_b = 5.6,
			crouch_walk_l = 5.6,
			crouch_walk_r = 5.6,
			-- The crawls were downloaded in place, so these are by eye.
			prone_walk_f = 4,
			prone_walk_b = 4,
			zombie_crawl = 6,
		},
		WalkRunThreshold = 20, -- studs/s: faster than this plays the run clip (walk 16, sprint 24)
	},

	-- Assault class (Sprint 15 / class V1). Default and only class for now.
	Assault = {
		MomentumDuration = 4, -- seconds; refreshed by kills
		MaxMomentumStacks = 5,
		DamagePerStack = 0.04, -- +4% damage per stack
		MoveSpeedPerStack = 0.04, -- +4% move speed per stack
		DashCooldown = 5,
		DashDistance = 18, -- studs
		DashDuration = 0.18, -- seconds
		BreachCooldown = 12,
		BreachThrowDistance = 35, -- studs
		BreachFuseTime = 0.8, -- seconds
		BreachRadius = 14, -- studs
		BreachDamage = 45,
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

	-- Automatic level growth (Resupply, 2026-11-06): a level no longer opens a draft; it
	-- grows the body. Growth stops at MaxLevel so items carry the late game.
	Progression = {
		HealthPerLevel = 3,
		DamagePerLevel = 0.03, -- +3% bullet damage per level
		MaxLevel = 40,
	},

	-- Resupply (docs/PROGRESSION.md > Resupply): kills fill one run-wide pool; a player throws
	-- the red flare when the pool covers the cost and a pallet lands DropDelay seconds later.
	Requisition = {
		BaseCost = 450,
		CostGrowth = 1.35, -- per drop, run-wide
		CostCap = 3000,
		CostPerExtraPlayer = 0.8, -- 4 players: cost x3.4
		FlareCooldown = 20, -- seconds after a pallet lands before the next flare
		FlareThrowDistance = 35, -- studs, same arc as the breach charge
		DropDelay = 20, -- seconds from flare to pallet (the lure window)
		CardLifetime = 60, -- unpicked cards vanish
		CardSpacing = 4.5, -- studs between the three cards
		PickRadius = 2.5, -- walk this close to a card to take it
		MaxCrates = 4, -- oldest pallet closes when a fifth lands (perf)
		Lure = {
			Radius = 120, -- Infected inside walk to the flare, not the player, until it lands
			Wave = 10, -- spawned in a ring around the pallet as it lands
			WavePerExtraPlayer = 3,
			SpawnFactor = 0.7, -- spawn interval multiplier after a landing
			SpawnFactorDuration = 30,
		},
	},

	-- Item rarities (Sprint 14): display only; roll weights per crate source are in Crates.
	ItemRarities = {
		Common = { DisplayName = "Common", Color = Color3.fromRGB(170, 170, 170) },
		Uncommon = { DisplayName = "Uncommon", Color = Color3.fromRGB(80, 220, 120) },
		Legendary = { DisplayName = "Legendary", Color = Color3.fromRGB(255, 75, 75) },
	},
	-- Crates: every pallet shows each player CardsPerPlayer cards rolled with its source's
	-- weights. Every GuaranteeEvery-th Resupply drop carries at least one Uncommon.
	Crates = {
		CardsPerPlayer = 3,
		GuaranteeEvery = 4,
		Weights = {
			Requisition = { Common = 70, Uncommon = 25, Legendary = 5 },
			Stores = { Common = 55, Uncommon = 38, Legendary = 7 },
			Secondary = { Common = 40, Uncommon = 50, Legendary = 10 },
			Boss = { Common = 0, Uncommon = 90, Legendary = 10 },
		},
	},

	-- Items (Sprint 5). Definitions in shared/ItemDefinitions.luau; full spec
	-- in docs/sprints/SPRINT_05_ITEMS_MVP.md.
	Items = {
		-- Common Item Pack 1 (Sprint 15) passive per-stack values.
		Passives = {
			HighGrainPowder = 0.08, -- + bullet damage
			CombatStimulants = 0.07, -- + fire rate
			LightweightBoots = 0.07, -- + move speed
			MilitaryRations = 12, -- + max HP
			FieldManual = 0.08, -- + XP gained
			ScavengerPouch = 0.15, -- + orb magnet range
			BallisticWeave = 0.06, -- - incoming damage
			BallisticWeaveCap = 0.5, -- max damage reduction
			FieldDressing = 8, -- HP healed on level-up
			SignalAntenna = 0.1, -- + drone & Hunter's Mark range
			CheapDroneParts = 0.1, -- + drone duration
		},
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
		PlagueRat = {
			ProcChancePerStack = 0.12,
			ChanceCap = 0.6,
			RatsPerStack = { 2, 3, 4, 5 }, -- index = min(stacks, 4)
			MaxActivePerPlayer = 15,
			Lifetime = 8, -- seconds
			TargetRange = 45, -- studs to acquire a target
			DamagePerSecond = 3,
			LatchDuration = 4, -- seconds latched per target
			MaxRetargets = 1,
			CrawlSpeed = 22, -- studs/sec toward target
			ContactRange = 2.2, -- studs to latch
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
		ZoneSize = Vector3.new(46, 1, 46), -- Sprint 13 tune: bigger, room to kite while holding
		ZonePosition = Vector3.new(50, 8.5, 50), -- on the Compound's lower tier (ArenaService HILLS)
		SyncInterval = 0.1, -- seconds between progress updates to the UI
	},

	-- Extraction phase (Sprint 12): starts when the objective completes. The helipad in the
	-- south-west corner, ~226 studs from the objective hill.
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
		-- Sprint 13 tune: ~0.75x counts (was 14/22/32/45/60) — less overwhelming.
		MaxAliveSchedule = { { 75, 11 }, { 180, 16 }, { 300, 24 }, { 480, 34 } },
		MaxAliveLate = 45, -- after the schedule (lower this first if perf drops)
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
			{ Until = math.huge, Weights = { Walker = 40, Runner = 30, Brute = 18, Hocker = 12 } },
		},
		-- Fairness caps by type. MaxShare: at most this share of alive enemies.
		-- CapSchedule: { upToSeconds, max alive of the type }, CapLate after the schedule.
		MaxShare = { Runner = 0.35 },
		CapSchedule = {
			Brute = { { 300, 1 }, { 480, 2 } },
			Hocker = { { 600, 2 } },
		},
		CapLate = { Brute = 3, Hocker = 3 },
	},

	-- The Infected. Base values at difficulty step 0; see Difficulty above.
	-- Sound (sound day 2026-11-07). Clips are packed per speaker in SoundBanks; a group is a
	-- clip name without its variant number. Volumes are per group (0-1, DefaultVolume when
	-- unlisted); 3D sounds roll off between the two distances (studs).
	Audio = {
		DefaultVolume = 0.6,
		Volumes = {
			step_hard = 0.5,
			step_soft = 0.5,
			bodyshot = 0.55,
			headshot = 0.8,
			hurt = 0.6,
			walker_idle = 0.5,
			walker_attack = 0.7,
			walker_hurt = 0.5,
			walker_death = 0.7,
			runner_idle = 0.45,
			runner_attack = 0.7,
			runner_hurt = 0.5,
			runner_death = 0.7,
			brute_idle = 0.65,
			brute_attack = 0.9,
			brute_hurt = 0.6,
			brute_death = 0.9,
			hocker_idle = 0.5,
			hocker_windup = 0.65,
			hocker_spit = 0.7,
			hocker_hurt = 0.5,
			hocker_death = 0.7,
		},
		-- Infected vocals and the player's pain grunts (server, WorldSounds).
		Voice = {
			RollOffMin = 12,
			RollOffMax = 160,
			IdleInterval = { 5, 11 }, -- seconds between one Infected's ambient lines (random in range)
			IdleGlobalGap = 0.35, -- seconds between ambient lines across the whole horde
			IdleMaxDistance = 140, -- studs from the nearest player beyond which ambient lines are skipped
			HurtCooldown = 0.45, -- seconds between pain grunts from one body (rapid fire, one grunt)
		},
		-- Boot steps (client, FootstepController).
		Footsteps = {
			RollOffMin = 6,
			RollOffMax = 40,
			MinInterval = 0.1, -- seconds; blocks a double step when the dominant clip switches
			WalkVolume = 0.35, -- multiplier on the surface group volume (halved 2026-11-07)
			RunVolume = 0.5,
			-- Footfall phases (fraction of the loop) per locomotion clip: when the phase
			-- crosses one, a foot has landed. Measured in Studio 2026-11-07 from the lowest
			-- points of the LeftFoot/RightFoot parts over one loop (left, then right); {0, 0.5}
			-- when a clip is unlisted.
			Phases = {
				loco_walk_f = { 0.43, 0.89 },
				loco_walk_b = { 0.44, 0.91 },
				loco_walk_l = { 0.48, 0.94 },
				loco_walk_r = { 0.40, 0.86 },
				loco_run_f = { 0.43, 0.90 },
				loco_run_b = { 0.41, 0.87 },
				loco_run_l = { 0.47, 0.93 },
				loco_run_r = { 0.43, 0.96 },
			},
		},
	},

	Zombies = {
		SpawnInterval = 2, -- base seconds between spawns (decays per minute)
		InitialCount = 5, -- Walkers spawned right at run start
		MinSpawnDistance = 35, -- studs from the player
		MaxSpawnDistance = 50,
		CorpseLifetime = 1.5, -- seconds before a dead zombie is removed
		MaxPuddles = 8, -- caustic puddles alive at once (perf); the oldest goes first
		ThroatSacSwell = 1.8, -- Hocker sac size multiplier at the end of the windup
	},
}

return Config
