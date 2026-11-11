--!strict
-- All gameplay tuning values live here. Systems read from this module so
-- balance changes never require touching system code.

local Config = {
	Player = {
		MaxHealth = 100,
		WalkSpeed = 16,
		SprintSpeed = 24,
		-- Stances: LeftControl toggles crouch, C toggles prone; sprint, a vault
		-- or a climb stands the body up. Speeds are factors of WalkSpeed (no sprint while low).
		Stances = {
			CrouchSpeedFactor = 0.5,
			ProneSpeedFactor = 0.25,
			-- Seconds the enter/exit clips take (their rate is scaled to this); no stance
			-- change while one plays.
			TransitionTime = { crouch = 0.45, prone = 0.8 },
			-- Crawl spaces (StanceService): prone drops the HipHeight so the root
			-- (2 tall, the body's only collider) fits under a 2.8 gap; standing needs this
			-- much clear above the prone root, else the body stays down.
			ProneHipHeight = 0.3,
			ProneHeadroom = 4,
		},
		-- Skinned body: with SkinnedBody true PlayerSetup installs
		-- MeshAssets.buildSkinnedBody(SkinnedTemplate) (the one-mesh Weller from
		-- assets/3d/export/pc_assault_skinned.fbx over its hidden 15-part rig; notes in
		-- assets/3d/README.md "Skinned Weller") as StarterPlayer.StarterCharacter, so every
		-- character spawns as that rig and the limb swap (dressModel) is skipped. Bots keep
		-- the limb-swap body either way. False = tapered rigid limbs for players too.
		-- Off: the hidden rig (Motor6D clips) and the skin's bones diverge
		-- 30-120 degrees while animating, so welded gear and the rifle float away from the
		-- body. Back on only after the bind poses are matched (handoff/README.md open work).
		SkinnedBody = false,
		SkinnedTemplate = "pc_assault_skinned",
		-- Rigid gear welded onto the skinned body at spawn: MeshAssets template -> limb part
		-- (the rifle stays a Tool on RightHand). Each template is built at the limb's centre,
		-- so its MeshAssets `offset` places it like a limb mesh.
		SkinnedGear = {
			{ mesh = "pc_assault_gear_helmet", part = "Head" },
			{ mesh = "pc_assault_gear_carrier", part = "UpperTorso" },
		},
	},

	-- Vault / climb replaces the stock jump: Space, or sprinting into cover,
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
		VaultDuration = 0.55, -- seconds; the clip rate is scaled to match
		ClimbDuration = 1.1,
		-- Infected melee skips a body going over cover (CoverMoveService): the window is the
		-- move's duration plus Grace; a new window opens no sooner than Cooldown after the
		-- last one closed, so spamming the remote never gives standing immunity.
		CoverImmunity = { Grace = 0.15, Cooldown = 0.4 },
		-- Weight (client MomentumController): the body's velocity eases toward
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
	-- replacing floating damage numbers. Seconds and pixels.
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
		-- The burst everyone sees where an Infected dies: dark blood, STYLES `wound` mid
		-- fading to `wound` dark. Never green (owner).
		KillBurst = {
			Color = Color3.fromRGB(142, 38, 48),
			ColorEnd = Color3.fromRGB(86, 22, 32),
			Count = 14,
		},
	},

	-- Bot squadmates (BotService): generic Pike soldiers fill the squad in solo, one
	-- fewer per real player. Server-side bodies on the Squad roster: the Infected target
	-- them, they follow the nearest player in formation and shoot the nearest Infected they
	-- can see. Downed/revive and call-ins come with Sprint A step 6 and the loadout rework.
	Bots = {
		Count = 3, -- bots when one player is on; squad size caps at 4
		-- The squad's radio callsigns (Squad): players take the lowest free one as they join
		-- (solo: Pike One), bots the rest in order (solo: Pike Two to Four).
		Callsigns = { "Pike One", "Pike Two", "Pike Three", "Pike Four" },
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
		-- Stuck on a doorway or a stair: moved less than StuckDistance toward a
		-- far slot for StuckSeconds -> reappear in the slot at floor level.
		StuckSeconds = 3,
		StuckDistance = 1,
		-- A bot fires the service rifle (same Damage, magazine and reload as the player:
		-- WeaponDefinitions) slower than the player, so three bots on sustained fire (3 x ~67
		-- DPS burst) roughly equal one player; its reserve is infinite. Fallback 0.35 if they
		-- carry too hard.
		Range = 90, -- studs; the Infected beyond this are ignored
		FireCooldown = 0.30, -- seconds between shots (the player: 0.08)
		Damage = 20, -- per round (the player: 20)
		Spread = 3, -- degrees, half-angle
		HeadshotChance = 0.1, -- share of shots aimed at the head
		ReactionTime = 0.35, -- seconds between spotting a new target and the first shot
		RespawnSeconds = 10, -- a dead bot rejoins at its slot after this
		ReviveSearch = 60, -- studs: a bot goes to revive a downed squadmate this close
		ReviveSafeRadius = 12, -- ...unless an Infected is this close to the downed body
	},

	-- The outline every squadmate (player or bot) wears, seen through walls (AllyOutline,
	-- owner 2026-11-11). A thin line, no fill; it changes colour while they are downed.
	AllyOutline = {
		Enabled = true,
		Color = Color3.fromRGB(150, 205, 235), -- pale blue: reads as "friend", unlike any Infected colour
		DownedColor = Color3.fromRGB(230, 189, 96), -- the HUD yellow: needs a revive
		Transparency = 0.45, -- of the line (0 = solid): kept light on purpose
		DownedTransparency = 0.1,
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
		MaxRevives = 2, -- per mission; the next lethal hit after that kills outright
		CrawlSpeed = 3, -- studs/s: a downed body crawls on hands and knees toward cover or help
	},
	-- Knocked down (the Warden's Pound and Stomp; Squad.knock): KnockedUntil on the
	-- character. No moving, firing, abilities or reloading; still a target for the Infected.
	-- Seconds per attack live on the attack; the get-up is the last GetUp seconds of it.
	Knockdown = {
		GetUp = 1.0,
		Grace = 1.0, -- after standing: no second knockdown (its damage still lands)
	},

	-- Run flow (RunManager, Shared.RunStates). Co-op Sprint A.
	-- The operation: its missions in play order, each one data file in src/server/Missions
	-- (docs/LOBBY_MATCH_HANDOFF.md, docs/ARCHITECTURE.md F6). One mission until Mile 14 is
	-- built in game; the mission-to-mission transition walks this list.
	Operation = {
		Missions = { "delta" },
	},

	-- The experience's places (docs/LOBBY_MATCH_HANDOFF.md). Both the lobby and the match read
	-- them here. The lobby is the start place (2026-11-09: the places' contents were swapped).
	-- Lobby 0 would mean no trip home: READY restarts in the match.
	Places = {
		Lobby = 87556879379942, -- "Co-op Zombie Shooter", the start place: the Fallow
		Match = 125769854992316, -- "Checkpoint Delta"
		-- Test pairs, lobby place -> match place: a launch from one of these lobbies goes to its
		-- own match and that match flies home to it, so testing never needs the real places
		-- republished (Nova's own test experience).
		Dev = {
			[83558708746036] = 108949482095254, -- ZCS Dev -> Match Dev
		} :: { [number]: number },
	},

	-- The trip between the lobby and the match (HandoffService).
	Handoff = {
		ReturnAfterSeconds = 60, -- after a run ends, the squad flies home this long after the results screen opens
		Retries = 2, -- teleport retries before giving up
		RetryDelay = 2, -- seconds between them
	},

	-- Merits, the soft currency (owner 2026-11-10; docs/OWNER.md): what one mission pays every
	-- real player in the squad, dead or alive, when it ends (MeritService, Rules/Economy).
	-- Never per kill. Bots earn nothing. Saved on the record the lobby reads (Rules/Record,
	-- Config.Lobby.Save.RecordStore).
	Merits = {
		Win = 120, -- the squad extracted
		Partial = 60, -- wiped after the Primary was done
		Loss = 0, -- wiped before it
		Secondary = 30, -- added per Secondary done (no mission tracks Secondaries yet: pays 0)
		Retries = 2, -- extra attempts after a failed save
		RetryDelay = 1, -- seconds between them
		SettleSeconds = 6, -- the trip home waits this long at most for the pay to be saved
	},

	-- Tabs, the hard currency (owner 2026-11-10; docs/OWNER.md): bought with Robux or granted
	-- by events; they buy cosmetics and conveniences, never power. Nothing is sold for tabs yet.
	Tabs = {
		-- Robux packs (TabsService, Rules/Economy.tabsFor): one developer product each.
		-- ProductId 0 = not created on Roblox yet; such a pack can never be bought or paid.
		Products = {
			{ ProductId = 0, Tabs = 100 },
			{ ProductId = 0, Tabs = 550 },
			{ ProductId = 0, Tabs = 1200 },
		},
		ReceiptsKept = 50, -- Robux receipts remembered per record, so one never pays twice
	},

	Run = {
		InsertSeconds = 3, -- Insert -> Explore: the squad lands before the first wave
		-- A squad from the lobby: the run starts when everyone the lobby sent has a body, or
		-- this long after the first one arrived (bots fill the seats of anyone missing).
		StagingSeconds = 30,
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
		-- First person (Nova, 2026-11-10: "a first person toggle for players in the match"):
		-- T (or the right stick click) toggles it; the wheel past MinDistance goes in, the
		-- wheel back out leaves it. The eye rides the Head, a little forward of its centre;
		-- the soldier's own body is hidden on this client, and FirstPersonView shows the held
		-- gun with gloved hands and sleeves, its own reload, kick, sway and bob.
		-- The crosshair fades out down the sights so the iron sights or scope do the aiming.
		FirstPerson = {
			Key = Enum.KeyCode.T,
			GamepadKey = Enum.KeyCode.ButtonR3,
			EyeForward = 0.45, -- studs ahead of the head's centre
			EyeUp = 0.1,
			GunHip = CFrame.new(0.9, -0.95, -2.6), -- the gun's centre from the eye, at the hip
			GunAds = CFrame.new(0, 0, -2.1), -- down the sights: centred, this far ahead
			SightEye = 1.2, -- down the sights: the rear sight this far ahead of the eye (full size)
			SightDrop = 0.55, -- a gun without modelled irons: its centre this share of its height low
			Sway = 0.6, -- how much of a camera turn the gun lags behind (eases back)
			Bob = 0.06, -- studs the gun bobs at a full walk (none down the sights)
			KickBack = 0.18, -- studs a shot pushes the gun back
			KickPitch = 4, -- degrees a shot tips the muzzle up
			Scale = 0.4, -- the viewmodel shrunk toward the eye (same look, nothing cuts into it)
		},
		-- Per-shot kick (CameraController): each gun's Weapons.<id>.Kick pushes the view up by
		-- Pitch degrees plus a random +/- Yaw, eased back over Recover seconds (never a
		-- permanent aim change). Aiming down sights scales it by AdsScale.
		Kick = { AdsScale = 0.6 },
		-- Blast shake (CameraController): every server blast part tagged Attributes.BlastTag
		-- carries BlastPower (degrees at the centre, falling to 0 at Radius studs from the
		-- camera focus). Blasts add up to Cap degrees and decay exponentially over Decay
		-- seconds; a block with ShakeGlobal (the Anvil) adds it wherever the soldier stands.
		Shake = {
			Radius = 60,
			Cap = 6,
			Decay = 0.45,
			-- Each grenade / call-in block carries its own ShakePower (and ShakeGlobal, felt at
			-- any distance), so a call-in added or swapped in a loadout brings its own shake;
			-- DefaultPower covers one that names none.
			DefaultPower = 2.5,
		},
	},

	-- Shooting shared by every gun (the per-gun numbers are in Weapons below). Hitscan: one
	-- raycast per round, damage lands the same frame; the tracer is client-drawn feedback.
	Weapon = {
		-- Bloom recovers at the gun's BloomRecovery once this long has passed without a shot.
		-- Server-owned (ProjectileServer), mirrored to the crosshair ring (`Bloom` attribute).
		BloomRecoveryDelay = 0.1,
		TracerDuration = 0.06,
		-- Q swaps long gun and sidearm (LoadoutService): no shot and no reload for this long.
		SwapTime = 0.5,
		-- Simulated projectiles (ProjectileServer.fire): unused since the drones were retired,
		-- kept for slow-round weapons (the planned Thumper). Speed and lifetime.
		ProjectileSpeed = 180, -- studs per second
		ProjectileLifetime = 3, -- seconds before despawn
		ProjectileSize = Vector3.new(0.4, 0.4, 1.4),
		-- Degrees a shotgun pellet the client drew may sit outside the server's cone (aim and
		-- bloom drift between the two) before the server rolls its own.
		PelletTolerance = 0.75,
		-- A launcher's rocket (a gun row with Explosive): bigger and smoky orange.
		RocketSize = Vector3.new(0.7, 0.7, 2.4),
		RocketColor = Color3.fromRGB(255, 140, 50),
		MaxAimDistance = 1000, -- how far the aim raycast reaches
		-- Aiming down sights (hold RMB): the camera; spread and walk factor are per gun.
		ADS = {
			CameraDistance = 5, -- closer over the shoulder (Camera.Distance is the hip value)
			ShoulderOffset = Vector2.new(1.8, 0.4),
			FOV = 55, -- degrees (hip is the engine default, 70)
			EnterTime = 0.15, -- seconds to settle into or out of the sights
		},
	},

	-- The guns (WeaponDefinitions rows read these; docs/PROGRESSION.md > Loadout has the
	-- table and the reasoning). Real-world fire rates: FireCooldown = 60 / rpm. Spreads are
	-- half-angles in degrees: hip, ADS, then BloomPerShot per round up to BloomMax on top,
	-- recovering at BloomRecovery degrees per second. AdsMoveFactor scales the walk while
	-- aiming (sprint is off). Reserve is rounds beyond the loaded magazine: a soldier lands
	-- with ReserveStart (about half, so the first pallet matters) and a pallet fills it to
	-- ReserveMax. Pellets: rounds per trigger pull (Damage is per pellet). Pierce: Infected
	-- a round passes through after the first. FireMode "semi": one round per click.
	Weapons = {
		-- M16A4, the baseline: Walker 3 body / 1 head, Brute 13 / 11; burst DPS 250. Bloom
		-- makes a held trigger spray at range, so 3-5 round bursts are the skill. Re-armed:
		-- 30 + 240 = 9 mags, the Warden fight never runs it dry at the pallet costs below.
		ServiceRifle = {
			FireMode = "auto",
			Damage = 20,
			FireCooldown = 0.08, -- 750 rpm
			MagazineSize = 30,
			ReloadTime = 2.2,
			ReserveStart = 120,
			ReserveMax = 240,
			HipSpread = 1.5, -- about a stud off at 40 studs
			AdsSpread = 0.3,
			BloomPerShot = 0.3, -- ADS: 3 rounds stay on a head at 40 studs
			BloomMax = 3.5,
			BloomRecovery = 12,
			AdsMoveFactor = 0.6,
			Range = 400,
			HeadshotMultiplier = 3.0, -- EnemyDefinitions may override per form
			Kick = { Pitch = 0.9, Yaw = 0.3, Recover = 0.12 }, -- degrees up, +/- degrees, seconds
			Model = "wpn_m16",
			Price = 0, -- merits at the Quartermaster's rack (Rules/Record); issued free
			ArmsOrder = 1, -- Arms Room position in its slot (rack, menu); the first is the default
		},
		-- MP5: the best hip-fire; chews Runners, weak on Brutes (Walker 4 / 2, Brute 19 / 15).
		Smg = {
			FireMode = "auto",
			Damage = 14,
			FireCooldown = 0.075, -- 800 rpm
			MagazineSize = 30,
			ReloadTime = 1.8,
			ReserveStart = 120,
			ReserveMax = 210,
			HipSpread = 0.9,
			AdsSpread = 0.6,
			BloomPerShot = 0.15,
			BloomMax = 2.0,
			BloomRecovery = 12,
			AdsMoveFactor = 0.85,
			Range = 150,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 0.5, Yaw = 0.2, Recover = 0.12 },
			Model = "wpn_mp5",
			Price = 300, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 2,
			Sound = "smg",
		},
		-- M249: a 100-round belt, no reload inside a hold; slow to aim on the move.
		Lmg = {
			FireMode = "auto",
			Damage = 20,
			FireCooldown = 0.075, -- 800 rpm
			MagazineSize = 100,
			ReloadTime = 5.5,
			ReserveStart = 150,
			ReserveMax = 300,
			HipSpread = 3.0,
			AdsSpread = 0.5,
			BloomPerShot = 0.15,
			BloomMax = 2.5,
			BloomRecovery = 12,
			AdsMoveFactor = 0.35,
			Range = 400,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 1.1, Yaw = 0.5, Recover = 0.12 },
			Model = "wpn_m249",
			Price = 600, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 3,
			Sound = "lmg",
		},
		-- Mossberg 590: point-blank, one decision per pull; one pull drops every form but the
		-- Brute (3).
		Shotgun = {
			Heavy = true, -- staggers a Brute (Config.Enemies.Flinch)
			FireMode = "semi", -- pump
			Damage = 11, -- per pellet
			Pellets = 8,
			FireCooldown = 0.75, -- 80 rpm
			MagazineSize = 8,
			ReloadTime = 3.5,
			ReserveStart = 20,
			ReserveMax = 40,
			HipSpread = 5.0,
			AdsSpread = 3.5,
			BloomPerShot = 0,
			BloomMax = 0,
			BloomRecovery = 12,
			AdsMoveFactor = 0.7,
			Range = 45,
			HeadshotMultiplier = 1.5,
			Kick = { Pitch = 4.0, Yaw = 0.8, Recover = 0.12 },
			Model = "wpn_mossberg",
			Price = 400, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 4,
			Sound = "shotgun",
		},
		-- M110: one-taps Walkers, hits two in a line, poor up close. Ammo reins it in
		-- (100 x 60 is the M16's 270 x 20).
		Dmr = {
			Heavy = true, -- staggers a Brute (Config.Enemies.Flinch)
			FireMode = "semi",
			Damage = 60,
			Pierce = 1,
			FireCooldown = 0.2, -- 300 rpm
			MagazineSize = 20,
			ReloadTime = 2.6,
			ReserveStart = 40,
			ReserveMax = 80,
			HipSpread = 4.0,
			AdsSpread = 0.1,
			BloomPerShot = 1.2,
			BloomMax = 3.0,
			BloomRecovery = 8,
			AdsMoveFactor = 0.5,
			Range = 600,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 2.6, Yaw = 0.4, Recover = 0.12 },
			Model = "wpn_m110",
			Price = 500, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 5,
			Sound = "dmr",
		},
		-- M17: the sidearm, backup when the primary runs dry.
		Pistol = {
			FireMode = "semi",
			Damage = 25,
			FireCooldown = 0.15, -- 400 rpm
			MagazineSize = 17,
			ReloadTime = 1.5,
			ReserveStart = 34,
			ReserveMax = 68,
			HipSpread = 1.2,
			AdsSpread = 0.5,
			BloomPerShot = 0.6,
			BloomMax = 2.5,
			BloomRecovery = 12,
			AdsMoveFactor = 0.9,
			Range = 120,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 1.6, Yaw = 0.3, Recover = 0.12 },
			Model = "wpn_m17",
			Price = 0, -- merits at the Quartermaster's rack (Rules/Record); issued free
			ArmsOrder = 1,
			Sound = "pistol",
		},
		-- Sample guns (2026-11-09, dev menu; the Arms Room lists them once Nova's loadout work
		-- does). Each wears its own Blender mesh (`Model`, MeshAssets wpn_*) and plays its own
		-- clips from the `guns` sound bank (`Sound`: <Sound>_shot, <Sound>_reload).
		-- S&W 686 .357: one round per Walker or Runner, staggers a Brute; six shots and a slow
		-- reload rein it in (Walker 1 / 1, Brute 5 / 4).
		Revolver = {
			Heavy = true, -- staggers a Brute (Config.Enemies.Flinch)
			FireMode = "semi", -- double action
			Damage = 55,
			FireCooldown = 0.4, -- 150 rpm
			MagazineSize = 6,
			ReloadTime = 2.8, -- speedloader
			ReserveStart = 18,
			ReserveMax = 30,
			HipSpread = 1.8,
			AdsSpread = 0.4,
			BloomPerShot = 1.5,
			BloomMax = 3.5,
			BloomRecovery = 10,
			AdsMoveFactor = 0.85,
			Range = 150,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 3.0, Yaw = 0.6, Recover = 0.18 },
			Model = "wpn_revolver",
			Price = 350, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 2,
			Sound = "revolver",
		},
		-- M2010 ESR: one round per form but the Brute (2), through three more in a line. One
		-- decision per bolt; useless from the hip (Walker 1 / 1, Brute 2 / 2).
		Sniper = {
			Heavy = true,
			FireMode = "semi", -- bolt action
			Damage = 140,
			Pierce = 3,
			FireCooldown = 1.25, -- 48 rpm (bolt cycle)
			MagazineSize = 5,
			ReloadTime = 3.2,
			ReserveStart = 15,
			ReserveMax = 30,
			HipSpread = 6.0,
			AdsSpread = 0.05,
			BloomPerShot = 0, -- the bolt cycle outlasts any bloom
			BloomMax = 0,
			BloomRecovery = 12,
			AdsMoveFactor = 0.4,
			Range = 800,
			HeadshotMultiplier = 3.0,
			Kick = { Pitch = 5.0, Yaw = 0.8, Recover = 0.25 },
			Model = "wpn_sniper",
			Price = 700, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 6,
			Sound = "sniper",
		},
		-- M3 recoilless ("Goose", the squad's RPG): a visible rocket. A direct hit kills anything
		-- but the Warden; the blast (the frag's, no friendly fire) drops every form but the Brute
		-- in 6 studs. Two rounds: a Brute answer, not a call-in (Hammer 6 x 80, Anvil 500).
		Goose = {
			Heavy = true,
			FireMode = "semi",
			Damage = 400, -- the Infected struck directly; the blast hits everyone else in Radius
			FireCooldown = 1.0, -- one round loaded: ReloadTime is the real rate
			MagazineSize = 1,
			ReloadTime = 6.0, -- breech open, round in, close
			ReserveStart = 1,
			ReserveMax = 1,
			HipSpread = 2.0,
			AdsSpread = 0.25,
			BloomPerShot = 0,
			BloomMax = 0,
			BloomRecovery = 12,
			AdsMoveFactor = 0.4,
			Range = 300, -- the rocket's reach: about 1.4 s of flight
			HeadshotMultiplier = 1.0,
			Kick = { Pitch = 7.0, Yaw = 1.2, Recover = 0.35 },
			ProjectileSpeed = 220, -- studs/s
			Explosive = { Radius = 6, Damage = 120, ShakePower = 4 },
			Model = "wpn_goose",
			Price = 900, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 7,
			Sound = "goose",
		},
	},

	-- The soldier's kit beside the guns (KitService; docs/PROGRESSION.md > Loadout). G throws a
	-- grenade (Carried; a pallet re-arm refills them), V shoves, E uses a stim (a Medkit card
	-- refills them). A Restock card refills grenades and stims with the call-ins.
	Grenade = {
		Carried = 3,
		ThrowGap = 0.8, -- seconds between two throws
		-- M67 frag: one-shots a Hocker, not a Brute. Thrown like the flare (ThrowUtil).
		Frag = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			ThrowDistance = 35, -- studs
			FuseTime = 0.8, -- seconds after it lands
			Radius = 10, -- studs
			ShakePower = 3, -- camera shake at the centre (Config.Camera.Shake)
			Damage = 110,
		},
	},
	Shove = {
		Damage = 15,
		StaggerSeconds = 0.8, -- the shoved Infected stops this long (EnemyService.stagger)
		Push = 6, -- studs the body is driven back
		PushTime = 0.15, -- seconds the push takes
		Reach = 6, -- studs in front of the shover
		ConeDot = 0.5, -- hits inside ~60 degrees either side of facing
		Cooldown = 1,
	},
	Stim = {
		Carried = 2,
		Heal = 60, -- health over Duration
		Duration = 1,
		Ticks = 10,
	},

	-- The Arms Room (LoadoutMenu, LoadoutService.apply; key B): open any time during Insert or
	-- the ready-up, or in a run within LzRadius of the LZ pad (Extraction.ZonePosition) after
	-- CalmSeconds without dealing or taking damage.
	Loadout = {
		LzRadius = 30,
		CalmSeconds = 5,
	},

	-- Body animations: clip names from assets/animations (Mixamo, retargeted by
	-- assets/animations/build/retarget.py). Ids are the published Roblox animations
	-- (assets/animations/ASSET_IDS.md); "" = not published yet, Studio previews the
	-- retargeted clip instead (Shared.Animations).
	Animations = {
		Ids = {
			rifle_idle = "rbxassetid://76024363213369",
			rifle_walk = "rbxassetid://101797268528882",
			rifle_run = "rbxassetid://72963898258528",
			rifle_aiming_idle = "rbxassetid://128119603771479",
			firing_rifle = "rbxassetid://77772063124666",
			hit_reaction = "rbxassetid://71190789040778",
			death_from_the_front = "rbxassetid://117232963941888",
			grenade_throw = "rbxassetid://135829170379650",
			zombie_idle = "rbxassetid://93519395672825",
			zombie_walk = "rbxassetid://84395260822727",
			zombie_running = "rbxassetid://90874642054379",
			zombie_attack = "rbxassetid://137158591918391",
			zombie_death = "rbxassetid://106732257760037",
			mutant_walking = "rbxassetid://87623042676660",
			mutant_swiping = "rbxassetid://112744832038035",
			-- Generated by Roblox Studio's animation generator (not a Mixamo clip).
			hocker_spit = "rbxassetid://137955187022018",
			-- Mixamo Rifle 8-Way Locomotion Pack: walk and sprint in four directions.
			loco_walk_f = "rbxassetid://78103707995231",
			loco_walk_b = "rbxassetid://108758446382758",
			loco_walk_l = "rbxassetid://117572315623758",
			loco_walk_r = "rbxassetid://140275967812667",
			loco_run_f = "rbxassetid://95517367637290",
			loco_run_b = "rbxassetid://75864917408831",
			loco_run_l = "rbxassetid://77114545256341",
			loco_run_r = "rbxassetid://108853467256462",
			-- Movement set: vault/climb, crouch, prone; Infected climbs and
			-- extras (Crawler move, flinch, Hocker scream) for later.
			vault_low = "rbxassetid://126365636804289",
			sprint_roll = "rbxassetid://73602023144459",
			running_slide = "rbxassetid://102225735779030",
			downed_crawl = "rbxassetid://83813930560417",
			climb_ledge = "rbxassetid://84669447813348",
			climb_low = "rbxassetid://94346824729226",
			climb_high = "rbxassetid://96623071276150",
			crouch_idle = "rbxassetid://129624355115061",
			crouch_enter = "rbxassetid://106211458491449",
			crouch_exit = "rbxassetid://110117195900966",
			crouch_aim = "rbxassetid://122462211246090",
			crouch_walk_f = "rbxassetid://112397909891018",
			crouch_walk_b = "rbxassetid://114584149612719",
			crouch_walk_l = "rbxassetid://134630178658286",
			crouch_walk_r = "rbxassetid://86294659485928",
			prone_idle = "rbxassetid://78498982896471",
			prone_enter = "rbxassetid://129925546864069",
			prone_exit = "rbxassetid://98441017657401",
			prone_fire = "rbxassetid://93924530617601",
			prone_walk_f = "rbxassetid://125434385709902",
			prone_walk_b = "rbxassetid://87672925084525",
			zombie_crawl = "rbxassetid://122812221621763",
			-- Satisfying pass (2026-11-09, Mixamo, uploaded under the group)
			zombie_hit = "rbxassetid://73020069431259",
			rifle_reload = "rbxassetid://74976087886072",
			zombie_stumble = "rbxassetid://127020146924186",
			zombie_scream = "rbxassetid://102836607626705",
			-- The Warden: Mixamo Sword And Shield pack (shield on the left arm).
			-- Empty id = Studio preview from the retargeted table until published.
			warden_walk = "rbxassetid://88039140105645",
			warden_run = "rbxassetid://124560134155707",
			warden_idle = "rbxassetid://80323984709285",
			warden_guard = "rbxassetid://107270709566918",
			warden_bash = "rbxassetid://92321137098192",
			warden_riot = "rbxassetid://82671281154344",
			warden_death = "rbxassetid://95172490448336",
			warden_pound = "rbxassetid://118552013249732",
			warden_sweep = "rbxassetid://78954856861431",
			warden_slam = "rbxassetid://80930861193470",
			warden_stomp = "rbxassetid://137160328942631",
			warden_hit = "rbxassetid://92513440124088",
			knockdown_back = "rbxassetid://98193119951691",
			getup_back = "rbxassetid://136455455125454",
			-- Roblox's stock R15 climb (the Animate script's ClimbAnim): played on a ladder
			-- (TrussPart) while the Humanoid is in its Climbing state; not a Mixamo clip
			ladder_climb = "rbxassetid://507765644",
		},
		-- The Pike soldier (every player and bot): which clip plays for each state.
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
			-- R (upper body), played at the rate that fits the gun's ReloadTime. A gun can name
			-- its own clip with ReloadClip in its Config.Weapons row; this is the default.
			reload = "rifle_reload",
			death = "death_from_the_front",
			throw = "grenade_throw", -- G (frag) and the throw call-ins: the throw (upper body)
			knockdown = "knockdown_back", -- the Warden's Pound / Stomp: the fall (Config.Knockdown)
			getup = "getup_back", -- and the get-up, the last Knockdown.GetUp seconds
			ladder = "ladder_climb", -- on a TrussPart ladder (Humanoid Climbing state)
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
				crawl = "zombie_crawl", -- a leg gone (GoreService -> EnemyService.cripple)
				hit = "zombie_hit", -- flinch on a hit that does not kill (upper body)
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
				crawl = "zombie_crawl",
				hit = "zombie_hit",
			},
			Brute = {
				move = "mutant_walking",
				attack = "mutant_swiping",
				death = "zombie_death",
				hit = "zombie_hit",
			},
			Hocker = {
				move = "zombie_walk",
				attack = "hocker_spit",
				death = "zombie_death",
				crawl = "zombie_crawl",
				hit = "zombie_hit",
			},
			-- The Warden stands upright: his own set. idle plays whenever he stands still,
			-- guard is an upper-body overlay (shield up) over the walk, charge loops during
			-- the Gate Charge, riot on each Riot Call, throw on the Gas Canister (upper body).
			Warden = {
				move = "warden_walk",
				attack = "warden_bash",
				death = "warden_death",
				idle = "warden_idle",
				guard = "warden_guard",
				charge = "warden_run",
				riot = "warden_riot",
				throw = "grenade_throw",
				pound = "warden_pound",
				sweep = "warden_sweep",
				slam = "warden_slam",
				stomp = "warden_stomp",
				hit = "warden_hit", -- a plate coming off
			},
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
			-- Downloaded in place (no root motion to measure), so by eye.
			warden_walk = 6,
			warden_run = 16,
		},
		WalkRunThreshold = 20, -- studs/s: faster than this plays the run clip (walk 16, sprint 24)
		LadderClipSpeed = 10, -- studs/s of climb at which the ladder clip plays at rate 1
	},

	-- Resupply (docs/PROGRESSION.md > Loadout, pallets and field upgrades): every kill credits
	-- its form's SupplyValue to one run-wide pool, any distance (no orbs since the loadout
	-- rework); a player throws the red flare when the pool covers the cost and a pallet lands
	-- DropDelay seconds later. The pallet is the ammo box: anyone who walks up to it is re-armed
	-- once (full magazine + reserve), and its three cards are the supply cards in Crates.
	Requisition = {
		-- Sized for the M16's ammo burn: a first pallet around 1:15 and pallets keep coming
		-- through the Warden fight (steeper costs left the squad empty for ~85 s there).
		BaseCost = 300,
		CostGrowth = 1.15, -- per drop, run-wide
		CostCap = 1000, -- late run: a pallet about every 2 min
		CostPerExtraPlayer = 0.4, -- 4 players: cost x2.2 (matches their ~x2 kill income)
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

	-- Pallet cards: every pallet shows each player the same three
	-- supply cards (UpgradeDefinitions, Kind "supply"); walk into one to take it. Upgrade
	-- crates (the Primary's site crate today; Stores and Secondary crates later) show
	-- CardsPerPlayer field upgrades instead. No rarity.
	Crates = {
		CardsPerPlayer = 3,
		SupplyCards = { "medkit", "restock", "armour_plate" }, -- card order, left to right
		ArmourPlate = 50, -- hit points of Shield soaked before health (EnemyProjectileService)
		ShieldCap = 100, -- two plates at most
	},

	-- Call-ins (CallInDefinitions; Slots slots on keys 1-4). Charges refill one at a time every
	-- Cooldown seconds; a Restock card fills them. No friendly fire: only the Infected are hurt.
	CallIns = {
		-- A thrown call-in (CallInDefinitions Kind "throw") is held to aim and thrown on release
		-- (AbilityController): an arc from the hand and its row's `Aim` marker on the ground show
		-- where it lands and what it covers. Aim.Shape "ring" (Radius) or "strip" (Length along
		-- the throw, Width; Across = true lays it across). A row without Aim shows a small ring.
		AimArc = { Beads = 18, Rise = 0.3, MinRise = 3 }, -- the arc: beads, apex height per stud of reach
		Slots = 4, -- call-in slots per soldier (keys 1-4; the flare is key 5)
		-- Arrivals (Rules/Arrival; docs/PROGRESSION.md > Call-in arrivals): what the squad sees
		-- and hears between a call-in's throw and its effect. Each row's `Arrival` block names
		-- a Style (how CallInArrivalFX draws it on every client) and overrides any value in
		-- Defaults; a row without one arrives as a plain thrown marker. `Time` holds the kit
		-- back on the server (CallInService); fire missions keep their own Delay.
		Arrivals = {
			-- false: nothing is drawn, nothing waits, and the fire missions go back to the flat
			-- red discs, the stock blast and the one shared whistle.
			Enabled = true,
			MaxActive = 8, -- arrivals drawn at once on a client; the oldest goes first
			Defaults = {
				Style = "thrown", -- the marker flies and lands, nothing more
				Time = 0, -- seconds from the throw until the kit works (emplacements, supply)
				Throw = 0.45, -- seconds the thrown marker is in the air
				ThrownSize = Vector3.new(0.5, 0.9, 0.5), -- the thing thrown
				-- `Smoke = <colour>` on a row: marker smoke where it lands, for SmokeTime.
				SmokeTime = 6,
				-- Incoming rounds ("mortar", "shell"): the whistle starts Whistle seconds before
				-- the impact; the round is seen for its last Fall seconds, coming in Angle degrees
				-- above the ground from Distance studs; Report > 0 = the tube is heard that long
				-- before its round lands.
				Whistle = 0.8,
				WhistlePitch = 1,
				WhistleVolume = 0.7,
				Fall = 0.4,
				Angle = 75,
				Distance = 120,
				ShellSize = Vector3.new(0.5, 0.5, 6),
				Report = 0,
				ReportPitch = 1.7,
				ReportVolume = 0.12,
				-- The strike on the ground: Dust is the colour thrown up (DustCount puffs,
				-- DustSize studs); Column > 0 a pillar of earth that high and ColumnWidth wide;
				-- Linger seconds of smoke after; Scorch seconds the burnt ground stays; Close =
				-- how many blast radii out the warning ring starts.
				Dust = Color3.fromRGB(158, 131, 90),
				DustCount = 10,
				DustSize = 5,
				Column = 0,
				ColumnWidth = 6,
				Linger = 0,
				Scorch = 0,
				Close = 1,
				-- The blast itself (server, AirStrikeService): the clip in the callins bank, its
				-- pitch and volume, the flash ball's colour and seconds.
				BlastSound = "anvil_blast",
				BlastPitch = 1,
				BlastVolume = 1,
				Flash = Color3.fromRGB(255, 140, 40),
				FlashTime = 0.45,
				-- A gun run ("gunrun"): the gunship comes in Approach seconds before the first
				-- burst; lane marks MarkSpacing apart; every GunEvery-th burst plays GunSound
				-- (guns bank) and each draws Tracers extra rounds landing up to TracerSpread
				-- studs off the line.
				Approach = 1.5,
				MarkSpacing = 6,
				GunSound = "lmg_shot",
				GunPitch = 0.75,
				GunVolume = 0.5,
				GunEvery = 2,
				Tracers = 2,
				TracerSpread = 1.5,
				-- Things dropped ("case", "tumble", "streamer"): from Height studs; Settle seconds
				-- on the ground before the kit works; Sway studs side to side on the way down;
				-- Hop studs (a bounce, or a tossed charge's rise); Spin degrees a second while it
				-- tumbles; Streamer and Chute sizes in studs.
				Height = 45,
				Settle = 0.25,
				Sway = 1,
				Hop = 1.2,
				Spin = 540,
				Streamer = 9,
				Chute = 8,
			},
		},
		-- Hammer (81 mm mortar section, AirStrikeService): marks a point; the first shell lands
		-- Delay seconds after the throw, then one every ShellInterval, each Scatter studs off
		-- the mark at most. Walk It In steps them Config.Upgrades.WalkingBarrage.Step apart.
		Hammer = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			Desk = "fires", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 120,
			ThrowDistance = 35,
			Delay = 3,
			Shells = 6,
			ShellInterval = 1,
			BlastRadius = 12,
			ShakePower = 3.5,
			BlastDamage = 80,
			Scatter = 4,
			Aim = { Shape = "ring", Radius = 16 }, -- Scatter + BlastRadius: where shells can land
			-- A cross where each round will land; the tubes thump far off, then each round
			-- drops near straight down with a short high whistle: a quick pale flash, low dust.
			Arrival = {
				Style = "mortar",
				Smoke = Color3.fromRGB(214, 69, 51),
				Report = 2.4,
				Whistle = 0.45,
				WhistlePitch = 1.5,
				WhistleVolume = 0.5,
				Fall = 0.3,
				Angle = 84,
				Distance = 90,
				ShellSize = Vector3.new(0.35, 0.35, 4),
				Dust = Color3.fromRGB(201, 172, 124),
				DustCount = 8,
				DustSize = 5,
				BlastSound = "tripline_blast",
				BlastPitch = 1.15,
				BlastVolume = 0.9,
				Flash = Color3.fromRGB(255, 226, 150),
				FlashTime = 0.3,
			},
		},
		-- Anvil (105 mm battery, AirStrikeService): one heavy shell Delay seconds after the throw.
		Anvil = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			Desk = "fires", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 180,
			ThrowDistance = 35,
			Delay = 5,
			Shells = 1,
			ShellInterval = 1,
			BlastRadius = 20,
			ShakePower = 6,
			ShakeGlobal = 1.0, -- felt anywhere on the map
			BlastDamage = 500,
			Scatter = 0,
			Aim = { Shape = "ring", Radius = 20 }, -- the blast
			-- One ring closing on the mark; a long falling whistle, one heavy round on a flat
			-- line from behind the thrower, a tall column of dark earth, smoke and burnt ground.
			Arrival = {
				Style = "shell",
				Smoke = Color3.fromRGB(176, 48, 36),
				Whistle = 1.5,
				WhistlePitch = 0.55,
				WhistleVolume = 0.9,
				Fall = 0.7,
				Angle = 60,
				Distance = 220,
				ShellSize = Vector3.new(1.2, 1.2, 10),
				Dust = Color3.fromRGB(62, 52, 44),
				DustCount = 20,
				DustSize = 9,
				Column = 34,
				ColumnWidth = 9,
				Linger = 4,
				Scorch = 10,
				Close = 2.2,
				BlastPitch = 0.8,
				Flash = Color3.fromRGB(255, 120, 30),
				FlashTime = 0.7,
			},
		},
		-- Shrike (helicopter gun run, AirStrikeService): Delay seconds after the throw, Bursts
		-- impacts centred on the mark, Step studs apart along the throw, BurstInterval apart.
		Shrike = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			Desk = "fires", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 150,
			ThrowDistance = 35,
			Delay = 4,
			Bursts = 10,
			Step = 4,
			BurstInterval = 0.15,
			BlastRadius = 5,
			ShakePower = 2,
			BlastDamage = 120,
			PassHeight = 45, -- the helicopter's flight height over the mark (look only)
			PassLead = 60, -- studs before the first burst and past the last that it is seen
			-- The gunship (aircraft.py, MeshAssets veh_shrike_*): offsets from the hull's origin
			-- (Roblox axes, nose toward -Z) to the rotor hub and the chin gun's muzzle; the rotor
			-- turns RotorSpin degrees per second. The pass falls back to a plain hull Part
			-- while the meshes are missing.
			RotorHub = Vector3.new(0, 3.35, -1.5),
			GunMuzzle = Vector3.new(0, -1.75, -11.4),
			RotorSpin = 1440,
			Aim = { Shape = "strip", Length = 46, Width = 10 }, -- the run: Step x (Bursts - 1) + 2 x BlastRadius
			-- A lane of arrows running the way the gunship flies; the cannon is heard from the
			-- air, a rake of tracers walks the lane and each burst kicks up a spurt of dust.
			Arrival = {
				Style = "gunrun",
				Smoke = Color3.fromRGB(196, 110, 52),
				SmokeTime = 5,
				Dust = Color3.fromRGB(201, 172, 124),
				DustCount = 4,
				DustSize = 3,
			},
		},
		-- Doorman (tripod sentry MG, SentryService): stands where it lands for Duration; every
		-- FireInterval it shoots the nearest Infected in Range it can see.
		Doorman = {
			Price = 400, -- merits on the Carrier (Rules/Record, KitPrices)
			Desk = "engineers", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 150,
			ThrowDistance = 25,
			Duration = 45,
			Damage = 20,
			FireInterval = 0.15,
			Range = 70,
			MaxPerPlayer = 1, -- a second Doorman replaces the first
			Aim = { Shape = "ring", Radius = 2 }, -- where the tripod stands
			-- A slung case comes down under a cross-shaped cargo chute onto blue smoke, thuds,
			-- and the gun stands up out of it.
			Arrival = {
				Style = "case",
				Time = 2.2,
				Smoke = Color3.fromRGB(96, 150, 220),
				SmokeTime = 3,
				Height = 45,
				Settle = 0.3,
				Sway = 1.2,
			},
		},
		-- Tripline (Mines): thrown; Mines land on an arc bulging away from the thrower and blow
		-- when an Infected steps within TriggerRadius.
		Tripline = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			Desk = "engineers", -- the Carrier desk that sells it (DeskShop)
			Charges = 2,
			Cooldown = 60,
			ThrowDistance = 35,
			Mines = 6,
			ArcRadius = 8, -- studs from the landing point to each mine
			ArcDegrees = 160, -- the arc's span
			TriggerRadius = 5,
			ShakePower = 3,
			BlastRadius = 10,
			Damage = 80,
			Lifetime = 90,
			MaxMines = 12, -- per player; the oldest goes first
			Aim = { Shape = "ring", Radius = 8 }, -- ArcRadius: the mines' arc
			-- The satchel lands and the charges hop out of it to their places on the arc, each
			-- blinking once as it arms. No smoke: nothing comes from the air.
			Arrival = {
				Style = "scatter",
				Time = 0.95,
				ThrownSize = Vector3.new(1.2, 0.6, 0.9),
				Hop = 2.5,
			},
		},
		-- Concertina (wire, ConcertinaService): a Length x Width strip laid across the throw,
		-- centred where it lands, for Duration. Infected inside walk at SlowFactor and take
		-- DamagePerSecond (dealt every TickInterval).
		Concertina = {
			Price = 250, -- merits on the Carrier (Rules/Record, KitPrices)
			Desk = "engineers", -- the Carrier desk that sells it (DeskShop)
			Charges = 2,
			Cooldown = 90,
			ThrowDistance = 30,
			Duration = 60,
			Length = 16,
			Width = 3,
			SlowFactor = 0.4,
			DamagePerSecond = 5,
			TickInterval = 0.5,
			MaxPerPlayer = 4, -- the oldest strip goes first
			Aim = { Shape = "strip", Length = 16, Width = 3, Across = true }, -- the wire, laid across the throw
			-- The coil lands and springs open: two drums roll out to the ends paying out a
			-- strand, rattling and kicking dust, and the wire stands up behind them.
			Arrival = {
				Style = "unroll",
				Time = 1.05,
				ThrownSize = Vector3.new(0.7, 1.5, 1.5), -- the coil, a drum on its side
				Dust = Color3.fromRGB(201, 172, 124),
				DustCount = 2,
				DustSize = 2,
			},
		},
		-- Speedball (ammo bundle, SupplyDropService): drops where it lands, no lure wave; each
		-- living player walking within Radius is re-armed (full magazine and reserve), Visits
		-- times in all. A player re-arms again only after stepping out of the radius.
		Speedball = {
			Price = 300, -- merits on the Carrier (Rules/Record, KitPrices)
			Desk = "loadmaster", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 180,
			ThrowDistance = 25,
			Visits = 4,
			Radius = 6,
			Lifetime = 90,
			Aim = { Shape = "ring", Radius = 6 }, -- the re-arm radius
			-- Kicked out of the door onto yellow smoke: no chute, it tumbles down fast, hits,
			-- bounces once and settles in its own dust.
			Arrival = {
				Style = "tumble",
				Time = 1.5,
				Smoke = Color3.fromRGB(232, 181, 75),
				SmokeTime = 4,
				Height = 50,
				Fall = 0.75,
				Settle = 0.25,
				Hop = 1.2,
				Spin = 540,
			},
		},
		-- Aid Bag (medical drop, SupplyDropService): every soldier within Radius, once each:
		-- full heal, stims refilled, +Plate shield (Config.Crates.ShieldCap still caps it).
		AidBag = {
			Price = 300, -- merits on the Carrier (Rules/Record, KitPrices)
			Desk = "loadmaster", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 180,
			ThrowDistance = 25,
			Radius = 6,
			Plate = 25,
			Lifetime = 60,
			Aim = { Shape = "ring", Radius = 6 }, -- the heal radius
			-- A soft drop onto pink smoke: the bag comes down steadily under a long red and
			-- white streamer that flutters above it and falls across it when it lands.
			Arrival = {
				Style = "streamer",
				Time = 1.8,
				Smoke = Color3.fromRGB(210, 130, 130),
				SmokeTime = 5,
				Height = 38,
				Sway = 0.8,
				Streamer = 9,
			},
		},
		-- The supply drops' old fall (server-side), used only while Arrivals.Enabled is false.
		Drop = { Height = 50, FallTime = 0.9 },
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
		LureCharge = { Radius = 18, FuseTime = 3 }, -- Bait Charge: the frag baits the Infected until it blows
		ThroughAndThrough = { Pierce = 1 }, -- Infected a round passes through after the first
		HollowPoint = { StaggerSeconds = 0.6 }, -- the hit Infected stops for this long
		LastStand = { SpreadMultiplier = 2 }, -- fire from the ground while downed, hip only
		Tourniquet = { Seconds = 4 }, -- self-revive once per mission, this long after going down
		WalkingBarrage = { Step = 8 }, -- Hammer shells walk Step studs along the throw
		CommandDetonation = {}, -- press the Tripline key again to blow every armed mine
	},

	-- Hold Position objective V1. Pays SupplyReward into the Resupply pool on completion and
	-- drops an upgrade crate at the site when it activates (field upgrade source), and a
	-- second one when the hold ends: picked before the Index arrives, not after it falls.
	Objective = {
		AppearDelay = 180, -- seconds after server start before the zone appears
		RequiredSeconds = 45, -- total accumulated seconds inside the zone
		PressureWave = { Walker = 8, Runner = 4 }, -- spawned around the zone on appear
		PressureBruteAfter = 0, -- also +1 Brute if the run is older than this (seconds)
		SupplyReward = 500,
		CompleteCrate = "upgrade", -- the crate the hold's end drops; "" for none
		CompleteCrateOffset = 10, -- studs from the site crate, toward the nearest soldier
		ZoneSize = Vector3.new(46, 1, 46), -- Sprint 13 tune: bigger, room to kite while holding
		ZonePosition = Vector3.new(50, 8.5, 50), -- on the Compound's lower tier (ArenaService HILLS)
		SyncInterval = 0.1, -- seconds between progress updates to the UI
	},

	-- Extraction phase (Sprint 12): starts when the Index falls. The helipad in the
	-- south-west corner, ~226 studs from the objective hill. PressureWave lands on the call;
	-- each Waves row lands when the hold's progress reaches At (Rules/ExtractionWaves).
	Extraction = {
		HoldDuration = 60, -- accumulated seconds inside the zone to win
		ZoneSize = Vector3.new(28, 1, 28),
		ZonePosition = Vector3.new(-90, 0.6, -90),
		SyncInterval = 0.1,
		PressureWave = { Walker = 12, Runner = 4, Brute = 1 },
		SpawnFactor = 0.8, -- spawn interval multiplier while extracting (+20%)
		-- Count: phase-weighted Infected (Spawning.Phases) in a ring round the pad, plus
		-- PerExtraPlayer per living player beyond the first. SpawnFactor replaces the one
		-- above from that wave on.
		Waves = {
			{ At = 30, Count = 12, PerExtraPlayer = 3, SpawnFactor = 0.6 },
		},
		WaveRadio = "Second wave closing on the pad. Hold it, Pike.", -- shown as "CONTROL: ..."
	},

	-- Flat threat curve (the spine): no per-minute health or damage growth. The
	-- Infected get scarier by composition (Spawning phases) and count, not by numbers.
	Difficulty = {
		HealthPerMinute = 0,
		HealthCap = 1,
		DamagePerMinute = 0,
		DamageCap = 1,
		-- A slow ramp and a 1.5 s floor: about 40 bodies a minute late in the run before the
		-- hold and extraction multipliers.
		SpawnIntervalDecayPerMinute = 0.95, -- spawn interval multiplier per minute
		MinSpawnInterval = 1.5, -- seconds
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
		SpawnInterval = 3, -- base seconds between spawns (decays per minute, Difficulty)
		InitialCount = 5, -- Walkers spawned right at run start
		MinSpawnDistance = 35, -- studs from the player
		MaxSpawnDistance = 50,
		-- A spawn point must be open ground: not on dressing, a perch, a roof or inside a
		-- building footprint (+ margin). Tries this many candidates, then takes the last.
		SpawnAttempts = 6,
		SpawnBuildingMargin = 2,
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
	-- Sound. Clips are packed per speaker in SoundBanks; a group is a
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
			-- player gear (server, on the body: the squad hears each other's kit)
			reload = 0.45,
			dry_fire = 0.5,
			knockdown = 0.7,
			downed = 0.7,
			revive = 0.6,
			roll = 0.45,
			vault = 0.45,
			dash = 0.45,
			breach = 0.9,
			low_health = 0.35,
			-- call-ins
			pallet_land = 0.9,
			flare_burn = 0.35,
			callin_throw = 0.5,
			tripline_arm = 0.45,
			tripline_blast = 0.85,
			anvil_incoming = 0.7,
			anvil_blast = 1,
			pen_coil = 0.7,
			magpie_hover = 0.18,
			-- the Warden (his own bank, docs/PROGRESSION.md "Boss sound")
			warden_handset = 0.75,
			warden_impact = 0.9,
			warden_pound = 1,
			warden_swing = 0.8,
			warden_step = 0.55,
			warden_plate = 0.8,
			warden_roar = 0.9,
			warden_canister = 0.7,
			warden_death = 1,
			-- radio and interface (client, 2D)
			radio_in = 0.35,
			objective_complete = 0.45,
			card_pick = 0.55,
			kia = 0.5,
			ui_click = 0.35,
			-- ambience
			lantern_rotor = 0.9,
			amb_city = 0.18,
			amb_wind = 0.12,
			amb_siren = 0.5,
		},
		-- Groups heard across the map use Far instead of Voice (WorldSounds).
		Far = { RollOffMin = 30, RollOffMax = 400 },
		FarGroups = {
			breach = true,
			pallet_land = true,
			tripline_blast = true,
			anvil_incoming = true,
			anvil_blast = true,
			warden_pound = true,
			warden_roar = true,
			warden_death = true,
			lantern_rotor = true,
			amb_siren = true,
		} :: { [string]: boolean },
		-- Kill confirm (client HitMarkerUI): a soft 2D tick for the player who landed the
		-- kill, on top of the red kill marker. The radio keypad click pitched up, so it does
		-- not read as a menu click or as the wet hit sound.
		KillConfirm = {
			Bank = "ui_radio",
			Group = "ui_click",
			Volume = 0.3,
			Pitch = 1.4, -- PlaybackSpeed
			PitchVary = 0.05, -- random +/- per tick
			MinGap = 0.07, -- seconds; kills closer together than this share one tick
		},
		-- The ragged breathing loop below this health fraction (client, LowHealthSound).
		LowHealthFraction = 0.3,
		-- Low-health feedback (client, LowHealthFX): below Start (a health fraction) the screen
		-- greys and darkens at the edges, a heartbeat fades in and speeds up, and the World
		-- SoundGroup muffles; intensity runs 0 at Start to 1 at zero health (Rules/Feel
		-- lowHealth), 1 while downed, 0 dead. Everything eases toward it over Ease seconds.
		LowHealth = {
			Start = 0.35,
			Saturation = -0.8, -- ColorCorrection saturation at full intensity
			Vignette = 0.55, -- edge darkness opacity at full intensity
			-- World muffle, dB at full intensity. EqualizerSoundEffect has fixed bands (no
			-- cutoff setting): high above ~4 kHz, mid ~400 Hz-4 kHz, low left alone.
			MuffleHigh = -30,
			MuffleMid = -12,
			HeartbeatId = "rbxassetid://117572779728629", -- assets/audio/build/heartbeat.py
			HeartbeatVolume = 0.8,
			RateMin = 1.0, -- heartbeat PlaybackSpeed at the threshold
			RateMax = 1.6, -- and at zero health / downed
			Ease = 0.4, -- seconds to ease toward the target intensity
		},
		-- The Warden's boots: one step clip every this many seconds while he walks.
		WardenStepInterval = 0.75,
		-- Anvil: the incoming rush starts this long before each shell lands.
		AnvilIncomingLead = 0.8,
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
			WalkVolume = 0.35, -- multiplier on the surface group volume
			RunVolume = 0.5,
			-- Footfall phases (fraction of the loop) per locomotion clip: when the phase
			-- crosses one, a foot has landed. Measured in Studio from the lowest
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

	-- Stage 1 building kit (ArenaService.buildBuilding; docs/LEVELS.md section B).
	-- Studs. A storey is 9 with a 0.6 slab (8.4 clear: a 2x Brute needs a room built taller,
	-- like the Shed's 12.5); doors 4 x 8; windows 5 wide at sill 3.2 / head 8.6 (a vault over
	-- the sill, under the head); stairs are WedgeParts at ~33 degrees; every roof has a 1.2
	-- parapet; upper floors up to LipMaxHeight (= Movement.ClimbMaxHeight) get a climb lip
	-- outside; corridors and catwalks are never narrower than CorridorMin.
	Arena = {
		-- Invisible composite-collider Parts the dressing may place (docs/LEVELS.md A8);
		-- ArenaService warns at boot past it.
		ColliderBudget = 256,
		-- The perimeter (docs/LEVELS.md A15): the solid walls are gone; an invisible
		-- collider stands just behind the fence line, and Infected spawns are clamped inside
		-- SpawnInset so none lands in the fence band or outside it.
		BoundaryHeight = 80,
		SpawnInset = 292,
		StraddleTolerance = 0.35, -- studs of ground-height spread across a dressing footprint before boot warns (and the Blender view paints it red)
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

	-- Vertical chase (EQ-B1): the Infected have no pathfinding except here. A
	-- melee form whose target stands more than PathfindVerticalGap above it, within
	-- PathfindBuildingRadius of a kit building, follows a PathfindingService path (stairs,
	-- doors, ramps) recomputed no more than every PathfindInterval; at most PathfindingMax
	-- bodies path at once, the rest (and any failed path) chase straight as before.
	Enemies = {
		-- Dismemberment (systems designer 2026-11-08; docs/PROGRESSION.md > Dismemberment;
		-- GoreService). The joint above the part a round hits keeps a running damage total;
		-- at MaxHealth x Fraction the joint breaks on that hit (the kill included) and the
		-- parts below it fall like a Warden plate. Rounds still do full body damage.
		Dismember = {
			Enabled = true,
			-- Part names without the Left/Right prefix. Counts: parts whose hits fill the total.
			Joints = {
				Elbow = {
					Counts = { "LowerArm", "Hand" },
					Falls = { "LowerArm", "Hand" },
					Fraction = 0.35,
					Limb = "Arm",
				},
				Shoulder = {
					Counts = { "UpperArm" },
					Falls = { "UpperArm", "LowerArm", "Hand" },
					Fraction = 0.5,
					Limb = "Arm",
				},
				Knee = {
					Counts = { "LowerLeg", "Foot" },
					Falls = { "LowerLeg", "Foot" },
					Fraction = 0.5,
					Limb = "Leg",
				},
				Hip = {
					Counts = { "UpperLeg" },
					Falls = { "UpperLeg", "LowerLeg", "Foot" },
					Fraction = 0.6,
					Limb = "Leg",
				},
			},
			Forms = { -- a form not listed never severs (the Index hosts: their plates are it)
				Walker = { Arms = true, Legs = true },
				Runner = { Arms = true, Legs = true },
				Hocker = { Arms = true, Legs = true },
				Brute = { Arms = true, Legs = false, SeverStagger = 0.6 },
			},
			ArmLostDamage = 0.6, -- melee damage multiplier per arm lost
			CrawlSpeed = 0.35, -- of WalkSpeed once a leg is gone; never climbs again
			HeadPopOnKill = true, -- a killing Head hit throws the head
			SeverStagger = 0.3, -- seconds the body stops when a joint breaks
			Impulse = 25, -- studs/s along the round, plus half that upward
			BlastKillSevers = 2, -- extra random groups thrown on a blast kill (Anvil, Tripline)
			BlastImpulse = 45,
			MaxLoosePieces = 20, -- loose groups in the world; the oldest goes first
			PieceLifetime = 4, -- seconds
			SettleAnchor = 1.5, -- a piece is anchored after this long (no more physics)
			-- Client flesh chunks per hit (GoreFX; the attacker's screen only).
			Chunks = { Body = 2, Headshot = 4, MaxAlive = 24, Lifetime = 1.2, Speed = 14 },
		},
		CorpseLifetime = 4, -- seconds before a dead Infected is removed (satisfying pass 2026-11-09)
		-- Limp bodies (satisfying pass): a dead Infected's joints go loose and the killing hit
		-- throws it (Rules/Feel.knockback). Only MaxBodies at once; past that the death clip.
		-- A body is anchored after Settle seconds (no more physics). Bosses never go limp.
		Ragdoll = {
			MaxBodies = 8,
			Settle = 2.5,
			SettleSpeed = 2, -- studs/s: below this a part is anchored at Settle; faster ones keep falling
			MaxUp = 18, -- studs/s: the upward part of a throw never exceeds this
			UpShare = 0.4, -- upward speed as a share of the throw
			Push = { Blast = 40, PerDamage = 0.5, Max = 30 }, -- studs/s (Feel.knockback)
		},
		-- Hit flinch (satisfying pass): a hit that does not kill plays the form's `hit` clip
		-- (Config.Animations.Infected) at most once per Cooldown, so full auto never stun-locks.
		-- A headshot plays it harder and slows the body briefly. HeavyOnly forms flinch only
		-- from a blast or a gun whose Config.Weapons row has Heavy = true.
		Flinch = {
			Cooldown = 0.6,
			HeadshotSpeed = 1.3,
			HeadshotSlow = 0.4, -- WalkSpeed factor
			HeadshotSlowTime = 0.15,
			HeavyOnly = { Brute = true },
		},
		BossCorpseLifetime = 8, -- an Index host's body stays long enough to read
		MaxPuddles = 8, -- caustic puddles alive at once (perf); the oldest goes first
		ThroatSacSwell = 1.8, -- Hocker sac size multiplier at the end of the windup
		PathfindingMax = 10,
		PathfindInterval = 0.5,
		PathfindVerticalGap = 4,
		PathfindBuildingRadius = 40,
		PathAgentRadius = 1.5, -- fits a 4-wide door
		PathAgentHeight = 5,
		PathWaypointSpacing = 4, -- studs between waypoints (the kit's stairs are 9-stud storeys)
		PathWaypointReach = 3, -- studs: the next waypoint counts as reached
	},

	-- The Index (Sprint 19): the Warden, Delta's boss (IndexService; docs/PROGRESSION.md
	-- "Index kit: the Warden"). Spawns beyond the Gate when the Primary completes and walks
	-- the screening lane to the Apron, then hunts. Body and plate health scale per extra
	-- living player (HealthPerExtraPlayer: the one exception to MULTIPLAYER_READINESS
	-- decision 6). Distances in studs, times in seconds; damage per hit before
	-- Difficulty.DamageMultiplier. Numbers: systems designer, scale 1.9 (art).
	Index = {
		Warden = {
			SpawnPosition = Vector3.new(-30, 0, -290), -- beyond the Gate (LEVELS A6)
			Waypoints = { -- the lane in: the Gate, the bus line, the Inner Gate, the Apron
				Vector3.new(-30, 0, -274),
				Vector3.new(-30, 0, -200),
				Vector3.new(-30, 0, -112),
				Vector3.new(-30, 0, -45),
				Vector3.new(-30, 0, 0),
			},
			WaypointRadio = { [2] = "BusLine", [3] = "InnerGate" }, -- Radio key read on reaching a waypoint
			WaypointReach = 6,
			WalkTimeout = 75, -- the hunt starts anyway after this long on the lane
			SightingRange = 90, -- a living member this close during the walk: the sighting line
			SpawnDelay = 1.5, -- stands still after spawning
			GateOpenDelay = 3,
			HideDelay = 2.5, -- boss bar stays this long after the fight
			TellHold = 1.6, -- seconds a tell line stays on the boss bar
			RiotCallSpacing = 1, -- frames between the bodies of a Riot Call (one burst would hitch)
			RiotCallHold = 2.0, -- seconds he stands and roars on a Riot Call (the riot clip)
			IdleSpeed = 1, -- studs/s of root speed below which the idle clip plays over the walk
			SyncInterval = 0.2,
			HealthPerExtraPlayer = 0.33,
			ScaleReach = 1.9, -- the body's scale: reach distances below are at scale 1
			ArmouredMultiplier = 0.25, -- a round into a plate (the plate takes it, not the body)
			ExposedMultiplier = 1.5, -- a round into a limb whose plate is gone
			-- Plates: { Limb = the R15 part it welds to, Mesh = assets/3d piece, Health }.
			-- Flank: full damage even while he guards (the back).
			Plates = {
				Helmet = { Limb = "Head", Mesh = "inf_warden_plate_helmet", Health = 300 },
				Chest = { Limb = "UpperTorso", Mesh = "inf_warden_plate_chest", Health = 400 },
				Back = {
					Limb = "UpperTorso",
					Mesh = "inf_warden_plate_back",
					Health = 400,
					Flank = true,
				},
				ShoulderL = {
					Limb = "LeftUpperArm",
					Mesh = "inf_warden_plate_shoulder_l",
					Health = 300,
				},
				ShoulderR = {
					Limb = "RightUpperArm",
					Mesh = "inf_warden_plate_shoulder_r",
					Health = 300,
				},
				Shield = { Limb = "LeftLowerArm", Mesh = "inf_warden_plate_shield", Health = 600 },
			},
			PlateOrder = { "Helmet", "Chest", "Back", "ShoulderL", "ShoulderR", "Shield" }, -- boss bar pips
			CrackFraction = 0.5, -- a plate below this fraction reads cracked
			PlateBreakStagger = 1.5,
			PlateBreakImpulse = 30, -- studs/s the plate flies off at
			PlateDebris = 5, -- seconds a fallen plate lies there
			-- Shield Bash: close, frontal arc. Roll out of it.
			Bash = {
				Range = 8,
				Windup = 0.9,
				ArcDegrees = 70, -- narrower since the Sweep: Bash = step aside, Sweep = get behind
				Damage = 40,
				Cooldown = 3,
				Recovery = 0.6,
				StrikeAt = 0.45, -- fraction of the bash clip where the blow lands (rate-scaled to Windup)
			},
			-- Gate Charge: a straight line at speed; hard cover in the way stuns him (WallStun).
			Charge = {
				MinRange = 19, -- leaves the ring just past the Bash to the Pound
				MaxRange = 45,
				Windup = 1.2,
				Distance = 45,
				Speed = 40,
				Width = 5,
				Damage = 35,
				Cooldown = 10,
				FirstDelay = 6, -- seconds after spawning before the first charge
				Recovery = 0.8,
				WallStun = 3,
				Probe = 3, -- studs ahead of the root (at scale 1) the charge looks for hard cover
				HitHeight = 8, -- height difference inside which the charge still hits a body
			},
			-- Gas Canister (phase 2+): lobbed at the furthest member in range; a puddle.
			Canister = {
				MinPhase = 2,
				MaxRange = 70,
				Windup = 1,
				Damage = 10,
				Cooldown = 8,
				Recovery = 0.5,
				Projectile = {
					Speed = 50,
					Size = 1.2,
					Color = Color3.fromRGB(156, 170, 72),
					SplashRadius = 5,
					Lead = 0.5,
					Puddle = { Radius = 9, Duration = 6, DamagePerSecond = 12 },
				},
			},
			-- Guard: shield over the visor. Slow, frontal plates take PlateDamageFactor; flank him.
			-- A reaction: his plates took TriggerPlateDamage inside TriggerWindow seconds.
			Guard = {
				TriggerPlateDamage = 150,
				TriggerWindow = 3,
				Duration = 2.5,
				Cooldown = 9,
				SpeedFactor = 0.5,
				PlateDamageFactor = 0.25,
			},
			-- Kit expansion (systems-designer pass): where you stand picks his move.
			-- Beat (IndexService.chooseAttack): seconds he walks between one recovery ending
			-- and the next decision, by phase. The pause is what makes a rhythm, not a spam.
			AttackGap = { 1.0, 0.7, 0.4 },
			-- Close-band weights among ready attacks; a crowd (CrowdCount members inside the
			-- shape) doubles Sweep and Pound. Never the same attack twice in a row except the
			-- Bash; a knockdown attack is never followed by another.
			CloseWeights = { bash = 3, sweep = 2, pound = 1 },
			CrowdCount = 2,
			HugRange = 3.5, -- a body this close (any side) is "in his boots": the Stomp
			PlantedSpeed = 4, -- studs/s; a body slower than this in reach is planted: the Slam
			PerchHeight = 4, -- a body this far above his feet: no Pound or melee; Canister in any phase
			-- Ground Pound: both fists into the road. Everyone on the ground inside Radius is
			-- knocked down. Not dodged by the roll (the ground moves): get out, or get up a
			-- ledge. The client draws the ring on the ground through the windup.
			Pound = {
				MinRange = 6, -- trigger ring, just past the Bash
				MaxRange = 10,
				Radius = 12,
				HitHeight = 4,
				Windup = 1.4,
				Recovery = 2.6, -- longer than Knockdown: he can never follow his own pound
				Cooldown = 16, -- Phases override (PoundCooldown)
				Damage = 30,
				Knockdown = 2.4,
				StrikeAt = 0.55, -- fraction of the clip where the fists land (rate-scaled to Windup)
			},
			-- Shield Sweep: the shield across the whole front. Get behind him or out of reach.
			Sweep = {
				Range = 9,
				ArcDegrees = 180,
				Windup = 1.1,
				Recovery = 0.8,
				Cooldown = 8,
				Damage = 25,
				Pushback = 40, -- studs/s shove away from him (client Impact "push")
				StrikeAt = 0.5,
			},
			-- Overhead Slam: at a body that stopped moving in reach. Narrow: a step aside beats it.
			Slam = {
				Length = 9,
				Width = 3,
				Windup = 1.3,
				Recovery = 1.2,
				Cooldown = 10,
				Damage = 60,
				StrikeAt = 0.5,
			},
			-- Stomp: a boot for anyone in his boots, any side. Fast and small; the roll beats it.
			Stomp = {
				Radius = 4.5,
				Windup = 0.6,
				Recovery = 2.0,
				Cooldown = 6,
				Damage = 20,
				Knockdown = 1.8,
				StrikeAt = 0.45,
			},
			-- Phases, entered at or below a body fraction; each opens with a Riot Call
			-- (spawnWave round him, 25-35 studs) and may retune him.
			Phases = {
				{
					Below = 0.6,
					RiotCall = { Walker = 6, Runner = 2 },
					WalkersPerExtraPlayer = 3,
					PoundCooldown = 11,
				},
				{
					Below = 0.25,
					RiotCall = { Walker = 6, Runner = 2 },
					WalkersPerExtraPlayer = 3,
					ChargeCooldown = 5,
					PoundCooldown = 8,
					WalkSpeed = 11,
				},
			},
			-- The field while he is up: fewer ambient spawns, a smaller horde, no Brutes.
			Pressure = { SpawnFactor = 1.5, MaxAliveReduction = 8, Caps = { Brute = 0 } },
			-- The priority pallet on death: a full heal, a re-arm and a quiet pallet with the
			-- supply cards (Cards; "upgrade" puts the field upgrades back here, as before
			-- Objective.CompleteCrate took them). His SupplyValue goes to the Resupply pool.
			Drop = { Offset = 6, Cards = "supply" },
			-- Radio lines (lore developer), shown as notices. Insert and wipe lines
			-- belong to RunManager flows later.
			Radio = {
				PrimaryComplete = "Control copies. That's the Primary. Index is moving at the Gate.",
				GateOpen = "Gate's open. Contact in the lane, big. It's wearing riot plate.",
				Sighting = "Eyes on. That's the Gate NCOIC. Control, Index confirmed.",
				BusLine = "Bus line. He's checking buses. Plates first, then the body.",
				InnerGate = "Inner Gate. He's working his second checkpoint. Flank when he guards.",
				FirstPlate = "Plate's off. That's bone under it. Keep working the seams.",
				LastPlate = "Last plate. He's just a man again. Put him down.",
				RiotCall = "...all posts, Gate. Crowd at the wire. Send the reserve...",
				Kill = "Index down. Control copies. Gate's yours, Pike. Pallet inbound.",
			},
		},
	},

	-- The Containment Board (docs/PROGRESSION.md > The Containment Board). Read by the
	-- lobby's Plot today; the shared DataStore behind it waits for the save service (F9).
	Containment = {
		-- Band minimums in percent (Rules/Containment).
		Bands = {
			{ name = "Lost", min = 0 },
			{ name = "Contested", min = 25 },
			{ name = "Held", min = 50 },
			{ name = "Contained", min = 75 },
			{ name = "Secured", min = 100 },
		},
		-- Board order and the placeholder percent each district shows until F9 lands
		-- (Delta starts at 25, everything else at 0).
		Districts = {
			{ name = "DELTA", percent = 25 },
			{ name = "MILE 14", percent = 0 },
			{ name = "KESTREL", percent = 0 },
			{ name = "THE YARD", percent = 0 },
			{ name = "RESERVOIR", percent = 0 },
		},
		RefreshSeconds = 60, -- the Plot rereads the board this often
	},

	-- The lobby place: the Fallow (docs/sprints/LOBBY_V1_FALLOW.md, LORE.md > The Fallow).
	Lobby = {
		-- The match a squad launches into: Config.Places (Match, or a Dev pair's).
		-- Music on the Carrier (LobbyMusic): licensed tracks from Roblox's audio library, free for
		-- any experience, picked for an overcast, waiting-to-go-in mood (Nova, 2026-11-10). Low in
		-- the mix (OWNER.md: no harsh sound); fades out as your Lantern lifts.
		Music = {
			Tracks = {
				"rbxassetid://115363600284265", -- A Light Dies Out On The Water (173 s)
				"rbxassetid://134330051136419", -- Lost In Time, ambient mix (APM, 120 s)
				"rbxassetid://106618631548737", -- Fading Hope (115 s)
				"rbxassetid://134520859422418", -- Silhouette Dream, ambience version (APM, 197 s)
			},
			Volume = 0.22, -- the Music SoundGroup's volume once faded in
			FadeInSeconds = 4,
			FadeOutSeconds = 2.5, -- as the Lantern lifts
			GapSeconds = 3, -- silence between tracks
		},
		-- The walking crew (LobbyCrew, CrewWalk): pace, stride and when they speak.
		Crew = {
			WalkSpeed = 5, -- studs a second (a soldier walks 16)
			Pause = 4, -- seconds standing at each end of the route
			BubbleDistance = 12, -- studs: a soldier this close hears a line
			BubbleSeconds = 4,
			BubbleCooldown = 14, -- seconds before the same one speaks again
			-- Roblox's stock R15 clips for the crew (NpcBody, CrewWalk): not ours, free to use.
			Animations = {
				Idle = "rbxassetid://507766388",
				Walk = "rbxassetid://507777826",
			},
			WalkClipSpeed = 0.45, -- the stock walk's playback rate at WalkSpeed (it is cut for 16)
		},
		-- The Plot's paper map (WorldMap, WorldMapData; canon docs/lore/world_map.md).
		WorldMap = {
			StudsPerUnit = 1.4, -- the 10 x 7 map grid at 1.4 studs a unit: a 14 x 9.8 sheet
			TableHeight = 3.4, -- studs from the hangar floor to the sheet
		},
		-- What the lobby keeps per soldier between visits (SaveSlot; a stand-in for the F9 save
		-- service): the Loadmaster's signed Loadout (LoadmasterService, Rules/LoadoutSave) and the
		-- record, merits and guns bought (RecordService, Rules/Record). Gun prices sit on each
		-- gun's own row (Config.Weapons.<Gun>.Price).
		Save = {
			Store = "LoadmasterLoadouts", -- DataStore name; keys are "u_<UserId>"
			RecordStore = "PikeRecords", -- DataStore name; keys are "r_<UserId>"
			StartMerits = 1000, -- a new soldier's merits (missions pay more: Config.Merits)
			MinWriteGap = 6, -- seconds between saves per soldier; the newest pick wins
			Retries = 2, -- extra attempts after a failed DataStore call
			RetryDelay = 1,
		},
		Launch = {
			Spots = 4, -- numbered Lantern spots on the flight deck
			Capacity = 4, -- soldiers per bird (one squad)
			Countdown = 20, -- seconds from the first soldier aboard to lift
			FullCountdown = 3, -- seconds to lift once the bird is full (all 4, or the squad size picked)
			BoardHalfSize = 6, -- the boarding box beside each bird's door, half-extent in studs
			BoardHeight = 8, -- studs above the deck a soldier still counts as on the box
			ScanInterval = 0.25, -- seconds between manifest checks
			Retries = 2, -- extra teleport attempts after a failure
			RetryDelay = 2,
			Cooldown = 6, -- seconds a spot rests after a lift or a failed one
		},
		-- Lantern, the lift bird on each spot (LanternBird, LanternSpool; docs/LORE.md > Lantern).
		Lantern = {
			BirdNumbers = { 22, 24, 21, 23 }, -- stencilled number per spot: a bird and a spot are not tied
			RotorRpm = 40, -- main rotor speed at the end of the spool
			SpoolShare = 2 / 3, -- the rotor reaches RotorRpm this far into the countdown
			TailRatio = 4.6, -- tail rotor turns this many times per main rotor turn
			-- The blur builds over the last seconds (Rules/RotorBlur, eased): the blades fade only part
			-- way while the disc thickens, so the rotor reads as fast, never as gone (owner, 2026-11-10).
			BlurStart = 6, -- seconds before lift the blur begins
			BlurFull = 1.5, -- seconds before lift it is complete
			BladeFade = 0.6, -- the blades' transparency when complete (still seen)
			BlurTransparency = 0.8, -- the disc's transparency when complete
			LiftSeconds = 1.5, -- the bird rises and dips its nose over the last seconds
			Rise = 4, -- studs
			Dip = 5, -- degrees nose down
			LampColor = Color3.fromRGB(255, 176, 64),
			LampRange = 12, -- STYLES light budget: Shadows off, Range <= 56
			LampBrightness = 1,
		},
		-- The Fallow's meshes (FallowArt; docs/sprints/LOBBY_V1_FALLOW.md > Ship art).
		Ship = {
			TemplateWait = 30, -- seconds FallowArt waits for an uploaded mesh before keeping the blocks
			RadarRpm = 6, -- the air-search radar on the mast turns (client only)
		},
		-- The Arms Room (ArmsRack, ArmsRackUI): the camera on its displays and the gun card.
		Rack = {
			CameraSeconds = 0.6, -- the camera's glide between views
			SlideSeconds = 0.15, -- a gun sliding off its pegs
			SlideOut = 0.6, -- studs a hovered or framed gun comes forward
			GlowFill = 0.85, -- hover highlight transparency (a soft rim, not a lit display)
			GlowOutline = 0.3,
			RackFov = 50, -- field of view on the whole rack
			MaxRackDistance = 18, -- the wall's overview stands back over the counter
			InspectFov = 40,
			MinInspectDistance = 2.2,
			InspectHeightShare = 0.4, -- a framed piece is at most this share of the screen's height
			Margin = 0.08, -- air round what the camera frames, a share of its size
			PlayFov = 70, -- restored when you step away
		},
		DeskPromptDistance = 10, -- studs a soldier can talk to a desk from
		DialogSeconds = 8, -- a desk's line stays up this long
		-- The Fallow's sky: a clear afternoon at sea (owner and Nova, 2026-11-09). One table
		-- so a day/night cycle can later drive these values instead of FallowBuilder.
		-- Gloomy (Tien, 2026-11-10): an overcast, cold late afternoon on a grey sea, the sun low
		-- and hidden, the coast fires glowing through a grey haze. Still readable: the hangar desks
		-- and the deck markings must read at a glance (the match was once "too gloomy").
		Sky = {
			ClockTime = 17.3,
			GeographicLatitude = 30,
			Brightness = 1.5,
			Ambient = Color3.fromRGB(88, 94, 104),
			OutdoorAmbient = Color3.fromRGB(118, 126, 138),
			ColorShiftTop = Color3.fromRGB(196, 206, 220),
			ExposureCompensation = -0.05,
			ShadowSoftness = 0.75, -- overcast: soft, faint shadows
			EnvironmentDiffuseScale = 0.8,
			EnvironmentSpecularScale = 0.2,
			Atmosphere = {
				Density = 0.36,
				Offset = 0.12,
				Color = Color3.fromRGB(148, 156, 166),
				Decay = Color3.fromRGB(78, 86, 98),
				Glare = 0,
				Haze = 2.2,
			},
			Clouds = { Cover = 0.88, Density = 0.8, Color = Color3.fromRGB(112, 118, 126) },
			-- Colour grade: a little drained and cold. Bloom only lifts fire, Neon and lamps (the
			-- threshold keeps geometry out of it, STYLES "Bloom only on Neon and fire").
			ColorCorrection = {
				Brightness = 0,
				Contrast = 0.08,
				Saturation = -0.22,
				Tint = Color3.fromRGB(232, 238, 248),
			},
			Bloom = { Intensity = 0.4, Size = 22, Threshold = 1.6 },
			-- The sea: a shallow sheet of Terrain water (engine waves) over a dark seabed
			-- part that gives it depth. Low tide (Nova): small, slow waves.
			Water = {
				WaveSize = 0.12, -- 0..1
				WaveSpeed = 8,
				Color = Color3.fromRGB(38, 58, 64), -- a cold grey-green sea under the overcast
				Reflectance = 0.25, -- 0..1, how much sky it mirrors
				Transparency = 0.3, -- 0..1
				Depth = 8, -- studs of water below y 0 (keep a multiple of 4: the voxel size)
				-- How far the sea runs to each side and astern (Nova: at 1000 the edge of the
				-- world showed). Out here the haze hides the edge. A multiple of 512.
				Extent = 2560,
			},
			-- The seabed under the water: a layer of tinted Terrain mud (gives the water its
			-- depth; a part could not cover the whole sea).
			Seabed = Color3.fromRGB(16, 28, 32),
			-- The coast is Terrain (a sand beach into the water, grass land, rock and grass
			-- hills); these tint the engine materials toward the game's muted palette.
			Coast = {
				Seed = 1985, -- the hills are placed from this seed, the same every server
				Hills = 40, -- along the whole coast (Water.Extent each side)
				Outcrops = 24, -- rock outcrops at the waterline
				Sand = Color3.fromRGB(176, 162, 128),
				Grass = Color3.fromRGB(88, 98, 68),
				Rock = Color3.fromRGB(102, 100, 94),
				Ground = Color3.fromRGB(94, 88, 76),
			},
			-- The Burn on the coast (docs/STYLES.md: the match's skyline fire and smoke, scaled
			-- for distance). Four sites, one fire and one smoke emitter each: 8 emitters.
			-- Nova: bigger fires (was FireSize 18, SmokeSize 34, a 90-stud line); 2026-11-10: bigger
			-- and redder again, "the world is really burning and the Carrier is all we have left":
			-- six sites (FallowLayout.BurnSites, 12 emitters), each on scorched terrain with glowing
			-- CrackedLava embers the Bloom lifts along the shore (no extra particles or lights).
			Burn = {
				FireSize = 64,
				FireRate = 30,
				SmokeSize = 110,
				SmokeRate = 5,
				Width = 220, -- studs of shoreline each site burns along
				Ember = Color3.fromRGB(255, 62, 24), -- the CrackedLava terrain colour (the embers)
				EmberDepth = 40, -- studs inland the burnt ground runs
				EmberPatches = 9, -- scorched Basalt blobs per site, each with a CrackedLava heart
			},
		},
	},
}

return Config
