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
			-- Crawl spaces (StanceService, 2026-11-07): prone drops the HipHeight so the root
			-- (2 tall, the body's only collider) fits under a 2.8 gap; standing needs this
			-- much clear above the prone root, else the body stays down.
			ProneHipHeight = 0.3,
			ProneHeadroom = 4,
		},
		-- Skinned body (2026-11-07): with SkinnedBody true PlayerSetup installs
		-- MeshAssets.buildSkinnedBody(SkinnedTemplate) (the one-mesh Weller from
		-- assets/3d/export/pc_assault_skinned.fbx over its hidden 15-part rig; notes in
		-- assets/3d/README.md "Skinned Weller") as StarterPlayer.StarterCharacter, so every
		-- character spawns as that rig and the limb swap (dressModel) is skipped. Bots keep
		-- the limb-swap body either way. False = tapered rigid limbs for players too.
		SkinnedBody = true,
		SkinnedTemplate = "pc_assault_skinned",
		-- Rigid gear welded onto the skinned body at spawn: MeshAssets template -> limb part
		-- (the rifle stays a Tool on RightHand). Each template is built at the limb's centre,
		-- so its MeshAssets `offset` places it like a limb mesh.
		SkinnedGear = {
			{ mesh = "pc_assault_gear_helmet", part = "Head" },
			{ mesh = "pc_assault_gear_carrier", part = "UpperTorso" },
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

	-- Bot squadmates (BotService, 2026-11-07): the other Chosen fill the squad in solo, one
	-- fewer per real player. Server-side bodies on the Squad roster: the Infected target
	-- them, they follow the nearest player in formation and shoot the nearest Infected they
	-- can see. Downed/revive and call-ins come with Sprint A step 6 and the loadout rework.
	Bots = {
		Count = 3, -- bots when one player is on; squad size caps at 4
		Names = { "Cole", "Reyes", "Cross" },
		MaxHealth = 100,
		WalkSpeed = 16,
		RunSpeed = 24, -- used when the formation slot is far
		ThinkInterval = 0.1, -- seconds between decisions per bot
		-- Formation slots in the leader's frame (studs; +Z is behind, +X to the right).
		Slots = {
			Vector3.new(-7, 0, 6),
			Vector3.new(7, 0, 6),
			Vector3.new(0, 0, 10),
		},
		FollowSlack = 4, -- closer than this to the slot: stand
		RunBeyond = 16, -- further than this: run
		TeleportBeyond = 80, -- further than this (stuck, fell behind): reappear in the slot
		-- Stuck on a doorway or a stair (2026-11-07): moved less than StuckDistance toward a
		-- far slot for StuckSeconds -> reappear in the slot at floor level.
		StuckSeconds = 3,
		StuckDistance = 1,
		-- Loadout rework 2026-11-07: a bot fires the service rifle (same Damage, magazine and
		-- reload as the player: WeaponDefinitions) at a third of the player's rate, so three
		-- bots roughly equal one player; its reserve is infinite. Fallback if they carry: 0.55.
		Range = 90, -- studs; the Infected beyond this are ignored
		FireCooldown = 0.45, -- seconds between shots (the player: 0.15)
		Damage = 20, -- per round (the player: 20)
		Spread = 3, -- degrees, half-angle
		HeadshotChance = 0.1, -- share of shots aimed at the head
		ReactionTime = 0.35, -- seconds between spotting a new target and the first shot
		RespawnSeconds = 10, -- a dead bot rejoins at its slot after this
		ReviveSearch = 60, -- studs: a bot goes to revive a downed squadmate this close
		ReviveSafeRadius = 12, -- ...unless an Infected is this close to the downed body
	},

	-- Downed / revive (decision #3, Squad). A lethal hit downs a member instead of killing:
	-- prone, no moving or firing, not a target, takes no damage. A squadmate holds F next
	-- to them (bots revive on their own) to stand them up; the timer running out kills.
	Downed = {
		BleedOutSeconds = 30,
		ReviveHold = 3, -- seconds of holding F
		ReviveRadius = 8, -- studs
		ReviveHealthFraction = 0.5,
		DownedHealth = 1,
		MaxRevives = 2, -- per run; the next lethal hit after that kills outright
		CrawlSpeed = 3, -- studs/s: a downed body crawls on hands and knees toward cover or help
	},

	-- Run flow (RunManager, Shared.RunStates). Co-op Sprint A.
	Run = {
		InsertSeconds = 3, -- Insert -> Explore: the squad lands before the first wave
		-- After a run ends, the first READY opens this countdown; the next run starts when it
		-- runs out or every player is ready (solo: at once). Decision #4.
		ReadyUpSeconds = 10,
		-- Four landing pads around the LZ helipad (offsets from Config.Extraction.ZonePosition),
		-- one per squad member: players take the lowest free pad, bots the rest (Squad).
		SpawnPads = {
			Vector3.new(-9, 0, -9),
			Vector3.new(9, 0, -9),
			Vector3.new(-9, 0, 9),
			Vector3.new(9, 0, 9),
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

	-- The service rifle (WeaponDefinitions.service_rifle reads these). Realistic time-to-kill
	-- (loadout rework 2026-11-07): Walker 3 body / 1 head, Runner 2 / 1, Hocker 4 / 2,
	-- Brute 13 / 11 at the flat curve.
	Weapon = {
		Damage = 20,
		FireCooldown = 0.15, -- 6.7 rounds/s; DPS 133
		-- Magazine (loadout rework): the server owns Mag / Reserve per player, refuses a shot on
		-- empty, R reloads (cancelled by a roll, a slide or going down). Pallets re-arm.
		MagazineSize = 30,
		ReloadTime = 2.2, -- seconds
		ReserveStart = 120, -- rounds in reserve at insert
		ReserveMax = 120,
		-- The rifle is hitscan (2026-11-07): one raycast per shot, damage lands the same
		-- frame. Range caps the ray; the tracer is client-drawn feedback only.
		Range = 400,
		TracerDuration = 0.06,
		HeadshotMultiplier = 3.0, -- on a Head hit (EnemyDefinitions may override per form)
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
			sprint_roll = "rbxassetid://80433355485535",
			running_slide = "rbxassetid://138341516012248",
			downed_crawl = "rbxassetid://131142341976869",
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
			slide = "running_slide", -- sprint + C
			climb = "climb_ledge", -- onto bunker / humvee / container
			downed = "downed_crawl", -- downed (Squad): on all fours, crawling
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
			downed_crawl = 4, -- estimate: the Mixamo clip was exported in place
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
		BreachDamage = 80, -- 45 before the loadout rework (realistic TTK)
	},

	-- Resupply (docs/PROGRESSION.md > Loadout, pallets and field upgrades): every kill credits
	-- its form's SupplyValue to one run-wide pool, any distance (no orbs since the loadout
	-- rework); a player throws the red flare when the pool covers the cost and a pallet lands
	-- DropDelay seconds later. The pallet is the ammo box: anyone who walks up to it is re-armed
	-- once (full magazine + reserve), and its three cards are the supply cards in Crates.
	Requisition = {
		BaseCost = 500,
		CostGrowth = 1.35, -- per drop, run-wide
		CostCap = 3000,
		CostPerExtraPlayer = 0.8, -- 4 players: cost x3.4
		FlareCooldown = 20, -- seconds after a pallet lands before the next flare
		FlareThrowDistance = 35, -- studs, same arc as the breach charge
		DropDelay = 20, -- seconds from flare to pallet (the lure window)
		CardLifetime = 60, -- unpicked cards vanish
		CardSpacing = 4.5, -- studs between the three cards
		PickRadius = 2.5, -- walk this close to a card to take it
		RearmRadius = 6, -- studs from the pallet: full magazine + reserve, once per player per pallet
		MaxCrates = 4, -- oldest pallet closes when a fifth lands (perf)
		Lure = {
			Radius = 120, -- Infected inside walk to the flare, not the player, until it lands
			Wave = 10, -- spawned in a ring around the pallet as it lands
			WavePerExtraPlayer = 3,
			SpawnFactor = 0.7, -- spawn interval multiplier after a landing
			SpawnFactorDuration = 30,
		},
	},

	-- Pallet cards (loadout rework 2026-11-07): every pallet shows each player the same three
	-- supply cards (UpgradeDefinitions, Kind "supply"); walk into one to take it. Upgrade
	-- crates (the Primary's site crate today; Stores and Secondary crates later) show
	-- CardsPerPlayer field upgrades instead. No rarity.
	Crates = {
		CardsPerPlayer = 3,
		SupplyCards = { "medkit", "restock", "armour_plate" }, -- card order, left to right
		ArmourPlate = 50, -- hit points of Shield soaked before health (EnemyProjectileService)
		ShieldCap = 100, -- two plates at most
	},

	-- Call-ins (CallInDefinitions; keys 1 and 2). Charges refill one at a time every Cooldown
	-- seconds; a Restock card fills them. No friendly fire: only the Infected are hurt.
	CallIns = {
		-- Magpie (Drone Beacon): thrown; Drones follow the thrower for Duration seconds and shoot
		-- the nearest Infected in TargetRange.
		Magpie = {
			Charges = 1,
			Cooldown = 90,
			ThrowDistance = 35,
			Drones = 2,
			Duration = 30,
			Damage = 6,
			FireInterval = 0.6,
			TargetRange = 60,
			FollowHeight = 5,
			FollowRadius = 4,
			ProjectileSpeed = 120,
			MaxDronesPerPlayer = 4,
		},
		-- Tripline (Mines): thrown; Mines land on an arc bulging away from the thrower and blow
		-- when an Infected steps within TriggerRadius.
		Tripline = {
			Charges = 2,
			Cooldown = 60,
			ThrowDistance = 35,
			Mines = 6,
			ArcRadius = 8, -- studs from the landing point to each mine
			ArcDegrees = 160, -- the arc's span
			TriggerRadius = 5,
			BlastRadius = 10,
			Damage = 80,
			Lifetime = 90,
			MaxMines = 12, -- per player; the oldest goes first
		},
		-- Anvil (Fire Mission): marks a point; after WarningDelay, Shells land ShellInterval apart.
		Anvil = {
			Charges = 1,
			Cooldown = 150,
			ThrowDistance = 35,
			WarningDelay = 3,
			Shells = 3,
			ShellInterval = 1,
			BlastRadius = 12,
			BlastDamage = 80,
			Scatter = 3, -- studs each shell lands off the mark
		},
		-- Pen Coil (Shock Coil): a pulse around the user that damages and slows.
		PenCoil = {
			Charges = 2,
			Cooldown = 25,
			Radius = 14,
			Damage = 25,
			SlowFactor = 0.4, -- Infected WalkSpeed multiplier while slowed
			SlowDuration = 3,
		},
	},

	-- Field upgrades (UpgradeDefinitions): one per slot, a new pick replaces. Each is a flag
	-- read by the service that owns the tool; the numbers it needs are here.
	Upgrades = {
		FireTrail = {
			PoolsPerDash = 3,
			Radius = 6,
			Duration = 5,
			DamagePerSecond = 8,
			MaxPools = 9,
		},
		SmokeDash = { ImmunitySeconds = 1.5 }, -- Infected melee cannot find the body after the dash
		LureCharge = { Radius = 18, FuseTime = 3 }, -- the charge baits the Infected until it blows
		ThroughAndThrough = { Pierce = 1 }, -- Infected a round passes through after the first
		HollowPoint = { StaggerSeconds = 0.6 }, -- the hit Infected stops for this long
		CombatReload = { MomentumStacks = 5 }, -- reload is instant at this many Momentum stacks
		LastStand = { SpreadMultiplier = 2 }, -- fire from the ground while downed, hip only
		Tourniquet = { Seconds = 4 }, -- self-revive once per sortie, this long after going down
		WalkingBarrage = { Shells = 5, Step = 8 }, -- Anvil shells walk Step studs along the throw
		Escort = {}, -- Magpie drones stay with a downed owner and their clock pauses
		CommandDetonation = {}, -- press the Tripline key again to blow every armed mine
		Defibrillator = {}, -- a Pen Coil pulse revives downed squadmates in its radius
	},

	-- Hold Position objective V1. Pays SupplyReward into the Resupply pool on completion and
	-- drops an upgrade crate at the site when it activates (field upgrade source).
	Objective = {
		AppearDelay = 180, -- seconds after server start before the zone appears
		RequiredSeconds = 45, -- total accumulated seconds inside the zone
		PressureWave = { Walker = 8, Runner = 4 }, -- spawned around the zone on appear
		PressureBruteAfter = 0, -- also +1 Brute if the run is older than this (seconds)
		SupplyReward = 500,
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

	-- Flat threat curve (the spine, 2026-11-07): no per-minute health or damage growth. The
	-- Infected get scarier by composition (Spawning phases) and count, not by numbers.
	Difficulty = {
		HealthPerMinute = 0,
		HealthCap = 1,
		DamagePerMinute = 0,
		DamageCap = 1,
		SpawnIntervalDecayPerMinute = 0.93, -- spawn interval multiplier per minute
		MinSpawnInterval = 1.0, -- seconds
		-- Population cap ramps with run time: { upToSeconds, maxAlive }.
		MaxAliveSchedule = { { 75, 10 }, { 180, 14 }, { 300, 20 }, { 480, 26 } },
		MaxAliveLate = 30, -- after the schedule (lower this first if perf drops)
		ObjectiveSpawnFactor = 0.7, -- spawn interval multiplier while objective active
	},

	-- More players, more Infected, not tougher Infected (MULTIPLAYER_READINESS decision 6).
	-- Per living player beyond the first (DifficultyService, EnemyService).
	PlayerCountScaling = {
		SpawnIntervalPerExtraPlayer = 0.8, -- spawn interval multiplier per extra player
		MaxAlivePerExtraPlayer = 3,
		HeavyCapPerExtraPlayer = 1, -- Brute / Hocker caps
		MaxAliveHardCap = 44,
	},

	-- The Burn (PROGRESSION.md > Operation): when the mission timer runs out. Reserved for
	-- OperationService; nothing reads it yet.
	Overrun = {
		Weights = { Walker = 30, Runner = 34, Brute = 18, Hocker = 18 },
		SpawnFactor = 0.5,
		MaxAliveBonus = 6,
		HeavyCapBonus = 2,
	},

	-- Spawn director phases (Sprint 9): type weights per run-time window,
	-- plus fairness caps. Enemy stats live in shared/EnemyDefinitions.luau.
	Spawning = {
		Phases = {
			{ Until = 75, Weights = { Walker = 100 } },
			{ Until = 180, Weights = { Walker = 75, Runner = 25 } },
			{ Until = 300, Weights = { Walker = 60, Runner = 28, Brute = 12 } },
			{ Until = 480, Weights = { Walker = 50, Runner = 30, Brute = 12, Hocker = 8 } },
			{ Until = math.huge, Weights = { Walker = 38, Runner = 30, Brute = 16, Hocker = 16 } },
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

	-- Stage 1 building kit (ArenaService.buildBuilding; docs/LEVELS.md section B, 2026-11-07).
	-- Studs. A storey is 9 with a 0.6 slab (8.4 clear: a 2x Brute needs a room built taller,
	-- like the Shed's 12.5); doors 4 x 8; windows 5 wide at sill 3.2 / head 8.6 (a vault over
	-- the sill, under the head); stairs are WedgeParts at ~33 degrees; every roof has a 1.2
	-- parapet; upper floors up to LipMaxHeight (= Movement.ClimbMaxHeight) get a climb lip
	-- outside; corridors and catwalks are never narrower than CorridorMin.
	Arena = {
		-- Invisible composite-collider Parts the dressing may place (docs/LEVELS.md A8);
		-- ArenaService warns at boot past it.
		ColliderBudget = 256,
		Kit = {
			Storey = 9,
			WallThickness = 0.6,
			Slab = 0.6,
			Door = { Width = 4, Height = 8 },
			Window = { Width = 5, Sill = 3.2, Head = 8.6 },
			Breach = { Height = 6 },
			StairAngle = 33,
			StairWidth = 5,
			Parapet = 1.2,
			LipDepth = 2.5,
			LipMaxHeight = 10.5,
			LadderGap = 3, -- the parapet / lip opening where an outside ladder lands
			CorridorMin = 6,
		},
		-- Built-in materials per building type (docs/STYLES.md §6): engine textures, no upload.
		Materials = {
			concrete = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(112, 110, 102) },
			cinder = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(146, 148, 136) }, -- CMU block
			brick = { Material = Enum.Material.Brick, Color = Color3.fromRGB(118, 86, 70) },
			wood = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(98, 80, 58) }, -- barracks huts
			metal = { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(86, 90, 92) }, -- the Shed
			panel = { Material = Enum.Material.Metal, Color = Color3.fromRGB(168, 168, 162) }, -- painted: kiosk, canopy
			render = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(158, 148, 126) }, -- the Parade
			slab = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(104, 102, 98) },
			roof = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(84, 82, 78) },
			ladder = { Material = Enum.Material.Metal, Color = Color3.fromRGB(58, 60, 64) },
			catwalk = { Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(92, 94, 98) },
		},
	},

	-- Vertical chase (EQ-B1, 2026-11-07): the Infected have no pathfinding except here. A
	-- melee form whose target stands more than PathfindVerticalGap above it, within
	-- PathfindBuildingRadius of a kit building, follows a PathfindingService path (stairs,
	-- doors, ramps) recomputed no more than every PathfindInterval; at most PathfindingMax
	-- bodies path at once, the rest (and any failed path) chase straight as before.
	Enemies = {
		PathfindingMax = 10,
		PathfindInterval = 0.5,
		PathfindVerticalGap = 4,
		PathfindBuildingRadius = 40,
		PathAgentRadius = 1.5, -- fits a 4-wide door
		PathAgentHeight = 5,
		PathWaypointSpacing = 4, -- studs between waypoints (the kit's stairs are 9-stud storeys)
		PathWaypointReach = 3, -- studs: the next waypoint counts as reached
	},

	Zombies = {
		SpawnInterval = 2, -- base seconds between spawns (decays per minute)
		InitialCount = 5, -- Walkers spawned right at run start
		MinSpawnDistance = 35, -- studs from the player
		MaxSpawnDistance = 50,
		-- A spawn point must be open ground (2026-11-07): not on dressing, a perch, a roof or
		-- inside a building footprint (+ margin). Tries this many candidates, then takes the last.
		SpawnAttempts = 6,
		SpawnBuildingMargin = 2,
		CorpseLifetime = 1.5, -- seconds before a dead zombie is removed
		MaxPuddles = 8, -- caustic puddles alive at once (perf); the oldest goes first
		ThroatSacSwell = 1.8, -- Hocker sac size multiplier at the end of the windup
	},
}

return Config
