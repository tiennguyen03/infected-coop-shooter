--!strict
-- All gameplay tuning values live here. Systems read from this module so
-- balance changes never require touching system code.

local ObjectiveDefinitions = require(script.Parent.ObjectiveDefinitions)

local Config = {
	-- The keyboard (owner 2026-11-11, docs/OWNER.md). Every binding and every on-screen key
	-- hint reads this table (Rules/KeyBindings.label turns a key into its hint), so a hint
	-- cannot disagree with its key. One key, one action: tests/KeyBindings.spec.luau, which
	-- also lists the overlaps that are meant. Middle mouse stays free for a ping button.
	Keys = {
		Interact = Enum.KeyCode.E, -- hold to revive, and anything else walked up to and used
		Stim = Enum.KeyCode.V,
		Shove = Enum.KeyCode.F,
		Crouch = { Enum.KeyCode.C, Enum.KeyCode.LeftControl }, -- either key
		Prone = Enum.KeyCode.Z,
		Flare = Enum.KeyCode.X, -- the Resupply flare
		Camera = Enum.KeyCode.T, -- first / third person
		Sprint = Enum.KeyCode.LeftShift,
		Vault = Enum.KeyCode.Space, -- vault, climb, stand up
		SwapGun = Enum.KeyCode.Q,
		Grenade = Enum.KeyCode.G,
		Reload = Enum.KeyCode.R,
		CallIns = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four },
		Loadout = Enum.KeyCode.B, -- the Arms Room menu
		-- Roll and slide have no key of their own (owner 2026-11-11): Sprint twice rolls, and
		-- holding a Crouch key while sprinting slides (MovementController; StanceController
		-- does not crouch then).
	},

	Player = {
		MaxHealth = 100,
		WalkSpeed = 16,
		SprintSpeed = 24,
		-- The soldier's look (Nova, 2026-11-11: "not really a fan of how he looks"; "the new look
		-- should change in match as well"): Roblox's default R15 body wearing catalog items
		-- (Shared.AvatarLook), on players and bots in the match and on the ship. Enabled = false
		-- puts the Pike limb body (PLAYER_BODY, dressModel) back. Picks page codes: a tactical
		-- vest with an olive shirt, slim combat pants, an AVS plate carrier, a black FAST helmet
		-- (T3 A9 P2 H4). Not R1: that "buzzcut" is a novelty piece worn over the face.
		Look = {
			Enabled = true,
			PlayerFace = true, -- each player wears their own avatar's head, face and skin tone (bots: the default)
			Items = {
				135730034330771,
				74956577347922,
				108890568133405,
				92700467676199,
			},
			Skin = Color3.fromRGB(176, 140, 112),
			Shirt = Color3.fromRGB(86, 92, 66), -- under the clothing
			Trousers = Color3.fromRGB(60, 62, 56),
		},
		-- Stances: Keys.Crouch toggles crouch, Keys.Prone toggles prone; sprint, a vault
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

	-- Stamina (Rules/Stamina; client SprintController owns it, StaminaUI shows it, the same
	-- trust as sprint itself). A full bar is ~8 s of sprint; empty to full is ~5.5 s. At
	-- zero the body is winded: no sprint, roll or slide until WindedRecover (~2.1 s).
	-- Vault, climb and shove are free; downed or knocked down nothing drains. Bots have none.
	Stamina = {
		Max = 100,
		SprintDrain = 12, -- per second while sprinting and moving
		Regen = 22, -- per second
		RegenDelay = 1, -- seconds after the last drain or spend before it comes back
		WindedRecover = 25, -- winded ends here
		RollCost = 20,
		SlideCost = 10, -- paid once on entry, however long the hill
		BarHideAfter = 2, -- seconds full before the bar fades out
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
		-- Keys.Sprint twice: a short roll along the move direction. Infected melee skips
		-- the body for the roll (CoverMoveService, same window as a vault).
		-- Sprint twice within DoubleTap seconds rolls (the first press is the sprint).
		Roll = { Duration = 0.8, Speed = 25, Cooldown = 1, DoubleTap = 0.3 },
		-- Sprint + hold a Keys.Crouch key: a slide that lasts while the key is down (never
		-- shorter than MinHold) and keeps the body's momentum (Rules/Slide). It starts at the
		-- speed going in plus EntryBoost, loses Friction per second, and the floor adds
		-- SlopeAccel x the slope's sine: flat from a sprint is 30 -> 14 in ~0.95 s, a 16
		-- degree downhill holds its speed, steeper gains up to MaxSpeed, uphill dies in
		-- about half the time. Over at MinSpeed or MaxDuration; speed above the walk or
		-- sprint speed then bleeds off at ExitDecel instead of snapping. No immunity; it
		-- covers ground, the roll dodges. The clip plays over ClipDuration and holds its
		-- pose at ClipHoldAt (a fraction of it) while the slide outlasts it.
		Slide = {
			EntryBoost = 6, -- studs/s on top of the speed going in
			MinEntrySpeed = 24, -- studs/s; a slide never starts slower
			Friction = 17, -- studs/s per second
			SlopeAccel = 60, -- studs/s per second on a sheer drop, scaled by the slope
			MaxSpeed = 40,
			MinSpeed = 14,
			MaxDuration = 6, -- seconds; the longest hill ends here
			MinHold = 0.35, -- seconds; a tap still slides this long
			ExitDecel = 40, -- studs/s per second back down to the walk or sprint speed
			FloorProbe = 6, -- studs under the root that count as the floor
			ClipDuration = 0.95,
			ClipHoldAt = 0.6,
			Cooldown = 1.2,
		},
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
	-- can see, revive, stim, throw frags and call fire missions.
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
		CatchUpBeyond = 45, -- further than this: sprint flat out to catch up
		CatchUpSpeed = 30,
		-- A bot walks to its slot. In a straight line while the slot is within DirectWithin,
		-- on its level (DirectMaxRise) and in sight; otherwise along a PathfindingService path
		-- (doors, stairs, ramps), asked for again no sooner than PathInterval after the last
		-- and only once the slot has moved PathRegoal; one request per PathStagger across all
		-- bots.
		DirectWithin = 16,
		DirectMaxRise = 4,
		DirectGiveUp = 1.5, -- seconds stalled on the straight line (low cover) before it paths
		NearLeader = 8, -- the slot is out of reach but the leader is this close: stand
		PathInterval = 1,
		PathRegoal = 6,
		PathStagger = 0.3,
		PathAgentRadius = 1.5, -- fits a 4-wide door
		PathAgentHeight = 5,
		PathWaypointSpacing = 4,
		PathWaypointReach = 3, -- studs: the next waypoint counts as reached
		-- The last resort (Rules/BotBrain.shouldTeleport): further than TeleportMinDistance
		-- from the leader and moved less than StuckDistance for StuckSeconds
		-- (NoPathStuckSeconds once PathFailLimit paths in a row were not found), or FallBelow
		-- studs under the leader (out of the world). It reappears in the first formation slot
		-- (or TeleportBehind studs behind the leader) no living player is facing
		-- (TeleportViewDot: the cosine of the half view angle), then not again for
		-- TeleportCooldown.
		TeleportMinDistance = 30,
		StuckSeconds = 6,
		NoPathStuckSeconds = 3,
		StuckDistance = 3,
		PathFailLimit = 3,
		FallBelow = 80,
		TeleportBehind = 18,
		TeleportViewDot = 0.3,
		TeleportCooldown = 10,
		-- Consumables: a bot carries a soldier's stims and frags (Config.Stim.Carried,
		-- Config.Grenade.Carried) per run; a Restock card taken by any player refills them.
		-- It looks for a throw every ScanInterval while it has a target, over the nearest
		-- ScanMax Infected.
		ScanInterval = 1,
		ScanMax = 30,
		StimBelow = 0.4, -- share of health at or under which it stims
		StimCooldown = 8,
		Grenade = {
			MinCluster = 4, -- Infected inside the frag's Radius
			FriendMargin = 4, -- studs past the Radius kept clear of every squad member
			Cooldown = 12, -- seconds between two throws by one bot
		},
		-- Boss fights (the Warden; any Infected whose EnemyDefinitions row is a Boss). While
		-- the boss is within Engage of a bot's leader the bot leaves its formation slot for a
		-- post StandOff from the boss on the leader's side, the slots SpreadDegrees apart
		-- (Rules/BotBrain.standOff), and backs off as he comes. StandOff is past every close
		-- attack (the Pound reaches 12 x ScaleReach 1.9 = 23 studs) and inside the rifle's
		-- Range. Enabled = false: slots, StimBelow and ReviveSafeRadius only, as before.
		Boss = {
			Enabled = true,
			Engage = 60,
			StandOff = 32,
			SpreadDegrees = 40, -- 22 studs between neighbours at StandOff; a charge is 19 wide
			Slack = 5, -- closer than this to the post: stand
			StimBelow = 0.6, -- stims earlier than StimBelow while the boss is engaged
			ReviveClear = 26, -- no revive while the boss is this close to the downed body
			PuddleMargin = 3, -- steps this far past the edge of a caustic puddle it stands in
			ScanInterval = 0.5, -- seconds between looks for a boss on the field
			-- A telegraphed disc or line (IndexService danger attributes): the bot runs
			-- DodgeMargin past its edge at DodgeSpeed. These two apply with Enabled off too.
			DodgeMargin = 5,
			DodgeSpeed = 30,
		},
		-- Fire missions: each bot carries one (Kit, by bot slot; CallInDefinitions ids with a
		-- ring Aim), thrown at MinCluster Infected inside its BlastRadius or at a heavy (an
		-- Infected with MaxHealth of HeavyHealth or more: a Brute, a boss). Never with a squad
		-- member inside its Aim radius + FriendMargin. One per bot every Cooldown, none in the
		-- first FirstDelay of a run, and SquadGap between any two bots' missions. Radio is the
		-- subtitle: callsign, then the call-in's name. Placeholder line (lore developer).
		CallIn = {
			Kit = { "hammer", "anvil", "hammer" },
			MinCluster = 8,
			HeavyHealth = 250,
			FriendMargin = 6,
			Cooldown = 180,
			FirstDelay = 45,
			SquadGap = 45,
			Radio = "%s: %s on the way. Stay clear of the mark.",
		},
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
	-- prone, no moving or firing, not a target, takes no damage. A squadmate holds Keys.Interact next
	-- to them (bots revive on their own) to stand them up; the timer running out kills.
	Downed = {
		BleedOutSeconds = 30,
		ReviveHold = 3, -- seconds of holding Keys.Interact
		ReviveRadius = 8, -- studs
		ReviveHealthFraction = 0.5,
		DownedHealth = 1,
		MaxRevives = 2, -- per mission; the next lethal hit after that kills outright
		CrawlSpeed = 3, -- studs/s: a downed body crawls on hands and knees toward cover or help
	},
	-- The revive animation (ReviveAnimService, Shared.ReviveAnimation, Rules/ReviveAnim;
	-- docs/PROGRESSION.md > Downed and revive). Looks only: the hold, the radius and what
	-- interrupts a revive stay in Downed above. The kneel and the lying body are existing
	-- clips; the arms are solved onto the casualty's chest each frame on every client.
	ReviveAnimation = {
		Enabled = true, -- false: the reviver stands and holds the interact key, the body crawls (as before)
		KneelSeconds = 0.3, -- down onto the knee
		StandSeconds = 0.3, -- back up when the hold is let go
		LieSeconds = 0.35, -- the casualty rolls from all fours onto their back
		FinishSeconds = 0.9, -- the pull-up once the revive lands
		PullShare = 0.6, -- share of FinishSeconds the reviver's hand stays on the casualty
		RecoverSeconds = 1.0, -- the casualty's get-up clip is fitted to this
		BotHoldSeconds = 0.6, -- a bot stands still this long into its pull-up or get-up
		MoveBreakSpeed = 2, -- studs/s: walking (or crawling) faster than this breaks the pose...
		MoveResumeSpeed = 0.5, -- ...until the body is slower than this again
		-- The kneel point (Rules/ReviveAnim.kneelPoints), in the lying casualty's root space,
		-- flat: the chest of the lying pose and the direction from feet to head.
		Chest = { X = 0.9, Z = 0.7 },
		BodyAxis = { X = 0.86, Z = 0.51 },
		KneelDistance = 1.9, -- studs from the chest to the reviver's root
		KneelTurn = 30, -- degrees the reviver turns left of the chest: the kneel clip's shoulders face right
		MaxNudge = 8, -- studs (the prompt reaches 8): further than this from both kneel points, the reviver kneels where they stand
		NudgeSeconds = 0.25, -- the slide to the kneel point...
		NudgeSpeed = 14, -- ...never faster than this, studs/s
		GroundTolerance = 1.5, -- studs the floor at a kneel point may differ from the floor underfoot
		-- The treat: both hands press a dressing into the chest.
		PressRate = 1.5, -- presses per second
		PressDepth = 0.22, -- studs the hands travel
		PressLean = 7, -- degrees the upper body leans into each press
		HandGap = 0.16, -- studs each hand sits to its side of the chest's centre
		HandLift = 0.12, -- studs the palms sit above the chest surface
		HandLength = 0.3, -- studs from the wrist to the palm
		BlendSeconds = 0.25, -- the arms ease onto the chest and off it
		ReachSlack = 1.15, -- a chest further than the arm's length times this is out of reach...
		-- ...and the hands work at this point in front of the knee instead (root space).
		FallbackTarget = Vector3.new(0.6, -2.0, -1.6),
		ElbowOut = Vector3.new(1, 0.8, 0.4), -- which way the right elbow points (root space; the left is mirrored)
		-- The rifle rides across the back while both hands work (each client moves its own
		-- copy of the grip weld; the shot origin is not touched on the server). false: the
		-- rifle stays in the right hand and only the left hand treats.
		SlingRifle = true,
		Sling = {
			Position = Vector3.new(0.35, -0.3, 0.65), -- the grip, in the upper torso's space
			Barrel = Vector3.new(-0.45, 0.9, 0), -- where the muzzle points: up past the left shoulder
		},
		-- The casualty: the last frame of the knockdown clip, held. That frame sits low on a
		-- standing root, so the body is raised to rest on the floor.
		CasualtyLift = 1.0, -- studs
		CasualtyNod = 5, -- degrees the head rocks with each press
		-- A soft cloth-and-gear rustle from the reviver while they work.
		Sound = { Bank = "player_gear", Group = "roll", Interval = 1.3, Volume = 0.22 },
	},
	-- Knocked down (the Warden's Pound and Stomp; Squad.knock): KnockedUntil on the
	-- character. No moving, firing, abilities or reloading; still a target for the Infected.
	-- Seconds per attack live on the attack; the get-up is the last GetUp seconds of it.
	Knockdown = {
		GetUp = 1.0,
		Grace = 1.0, -- after standing: no second knockdown (its damage still lands)
	},
	-- Squad status panel (client SquadPanelUI, Rules/SquadPanel; owner 2026-11-11: no
	-- floating health bars, squadmates' status in a side panel). One row per other squad
	-- member on the left edge under the top-left HUD. Offsets are 1080p pixels (HudTheme).
	SquadPanel = {
		Enabled = true,
		-- true restores the old floating bars: the billboard over a hurt Infected and
		-- Roblox's own bar over squadmates. Names: Roblox's name tag over squadmates.
		OverheadBars = false,
		OverheadNames = false,
		Top = 176, -- under the health stack, the ability circles and the resupply line
		Width = 190,
		RowHeight = 32,
		RowGap = 8,
		MaxRows = 3,
		LowFraction = 0.3, -- under this share of health the row turns red
		BigHitFraction = 0.25, -- losing this share of max health in one hit flashes the row
		FlashSeconds = 0.45,
		TickSeconds = 0.25, -- countdown refresh, only while someone is down or dead
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

	-- The wallet readout (owner 2026-11-11; shared WalletReadout): merits and tabs as a mark and
	-- a number each, in the Carrier's top bar and on the match's results screen. The marks are
	-- the icon generator's glyphs (assets/icons/build/icons.js, ids in assets/icons/ASSET_IDS.md).
	Wallet = {
		-- The decals' thumbnails: their image ids are not resolved yet (ASSET_IDS.md).
		MeritsIcon = "rbxthumb://type=Asset&id=117675850420015&w=150&h=150", -- the medal
		TabsIcon = "rbxthumb://type=Asset&id=107657168929182&w=150&h=150", -- the steel tag
		Size = 20, -- px at 1080p: the mark and its number
		CountSeconds = 0.6, -- a changed balance counts to the new one over this long
		PulseScale = 0.35, -- the mark swells by this much as a change lands, then settles
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
		-- Keys.Camera (or the right stick click) toggles it; the wheel past MinDistance goes in, the
		-- wheel back out leaves it. The eye rides the Head, a little forward of its centre;
		-- the soldier's own body is hidden on this client, and FirstPersonView shows the held
		-- gun with gloved hands and sleeves, its own reload, kick, sway and bob.
		-- The crosshair fades out down the sights so the iron sights or scope do the aiming.
		FirstPerson = {
			GamepadKey = Enum.KeyCode.ButtonR3,
			EyeForward = 0.45, -- studs ahead of the head's centre
			EyeUp = 0.1,
			-- Where the gun sits (at the hip, down the sights) comes from the gun's own sight:
			-- Weapon.Sights and Weapons.<id>.Sight below.
			Sway = 0.6, -- how much of a camera turn the gun lags behind (eases back)
			AdsSway = 0.25, -- the share of that lag left down the sights (they stay lined up)
			Bob = 0.06, -- studs the gun bobs at a full walk (none down the sights)
			KickBack = 0.18, -- studs a shot pushes the gun back
			AdsKick = 0.4, -- the share of KickBack left down the sights (the rear sight is close)
			KickPitch = 4, -- degrees a shot tips the muzzle up
			SwapDip = 0.7, -- studs the gun drops out of view and back during a Q swap
			-- The viewmodel shrunk toward the eye (same look, nothing cuts into it). It grows
			-- past this only as far as a close rear sight needs to stay NearMargin times
			-- outside the camera's near plane (Rules/Sight.viewScale).
			Scale = 0.4,
			NearMargin = 1.25,
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
		-- First person: what every gun's `Sight` (Weapons.<id>.Sight) falls back on, and the
		-- scope picture (Rules/Sight, FirstPersonView, ScopeView; docs/STYLES.md > First person).
		-- A row's Sight names its mesh's Rear and Front sight points (from the grip, barrel
		-- along -Z; taken from assets/3d/build/guns.py) and may override Kind ("irons" |
		-- "scope"), Hold, EyeRelief and Zoom. Third person keeps ADS above for every gun.
		Sights = {
			Zoom = 1.35, -- irons: the view this many times larger than the hip (FOV 70 -> 55)
			ScopeZoom = 4, -- a scope that names none
			-- Studs from the eye back from the rear sight, at the gun's real size, by Hold:
			-- a cheek on the stock, or a pistol at arm's length.
			EyeRelief = { long = 0.35, sidearm = 1.0, shoulder = 0.35 },
			ScopeRelief = 0.3, -- the eye behind a scope's eyepiece
			-- Where the grip (the right hand) sits from the eye at the hip, by Hold: a long gun
			-- low right, a sidearm closer and nearer the middle, a launcher on the shoulder.
			Hold = {
				long = Vector3.new(0.89, -1.03, -2.12),
				sidearm = Vector3.new(0.55, -0.8, -1.7),
				shoulder = Vector3.new(0.62, -0.78, -1.15),
			},
			-- Sights and shot agree here: the spec fails a gun whose sight line stands so far
			-- off its bore that the two differ visibly at this range (studs).
			ZeroDistance = 100,
			ScopeTime = 0.25, -- seconds into or out of a scope (irons: ADS.EnterTime)
			-- The scope picture: a round lens on the screen's centre, black around it.
			Scope = {
				Lens = 0.4, -- lens radius as a share of the screen's height
				Rows = 44, -- strips the black round the lens is cut into (ScopeView)
				Shadow = { 0.25, 0.5, 0.75 }, -- transparency of the soft rings inside the rim
				ShadowWidth = 0.035, -- each ring's width as a share of the lens radius
				Line = 1, -- pixels: the fine crosshair
				Post = 4, -- pixels: the three heavy posts
				PostGap = 0.3, -- the posts stop this share of the radius short of the centre
				Ticks = 4, -- range marks each way along the fine crosshair
				TickStep = 0.055, -- their spacing as a share of the radius
				Dot = 4, -- pixels: the red centre dot
				-- The own tracer is drawn from this far out (studs): at the barrel it would
				-- streak across the magnified lens.
				TracerStart = 30,
			},
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
			-- The flip-up peep's centre and the A2 post's tip (guns.py m4_rear_sight, m4_front_sight).
			Sight = { Rear = Vector3.new(0, 0.615, 0.04), Front = Vector3.new(0, 0.615, -1.345) },
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
			-- The drum's peep and the hooded post's tip.
			Sight = {
				Rear = Vector3.new(0, 0.585, 0.05),
				Front = Vector3.new(0, 0.585, -0.85),
				Zoom = 1.25,
			},
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
			-- The leaf's peep on the feed cover and the eared post by the muzzle.
			Sight = { Rear = Vector3.new(0, 0.68, 0.03), Front = Vector3.new(0, 0.68, -1.68) },
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
			-- No rear sight: the back of the receiver's top channel, level with the bead's centre.
			Sight = {
				Rear = Vector3.new(0, 0.5, 0.05),
				Front = Vector3.new(0, 0.5, -1.79),
				Zoom = 1.2,
			},
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
			-- The scope's eyepiece and objective, on its axis.
			Sight = {
				Kind = "scope",
				Rear = Vector3.new(0, 0.64, 0.17),
				Front = Vector3.new(0, 0.64, -0.79),
				Zoom = 3.5,
			},
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
			-- The rear notch's tops and the front post's top.
			Sight = {
				Hold = "sidearm",
				Rear = Vector3.new(0, 0.45, 0.11),
				Front = Vector3.new(0, 0.45, -0.43),
				Zoom = 1.15,
			},
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
			-- The front blade's top, sighted over the hammer spur: on this mesh the spur (top
			-- 0.463 at z 0.1) stands 0.013 above the rear notch (0.45 at z -0.02) and hides it
			-- from the eye, so the line clears the spur by 0.013 (the red insert shows over it)
			-- until the mesh is rebuilt with a lower hammer; then Rear is the notch.
			Sight = {
				Hold = "sidearm",
				Rear = Vector3.new(0, 0.476, 0.1),
				Front = Vector3.new(0, 0.45, -0.69),
				Zoom = 1.15,
			},
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
			-- The scope's eyepiece and objective, on its axis.
			Sight = {
				Kind = "scope",
				Rear = Vector3.new(0, 0.62, 0.23),
				Front = Vector3.new(0, 0.62, -0.97),
				Zoom = 6,
			},
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
			-- The 3x sight on the tube's left: its eyepiece and objective.
			Sight = {
				Kind = "scope",
				Hold = "shoulder",
				Rear = Vector3.new(-0.3, 0.54, -0.23),
				Front = Vector3.new(-0.3, 0.54, -0.6),
				Zoom = 3,
			},
			Price = 900, -- merits at the Quartermaster's rack (Rules/Record)
			ArmsOrder = 7,
			Sound = "goose",
		},
	},

	-- The soldier's kit beside the guns (KitService; docs/PROGRESSION.md > Loadout). Keys.Grenade throws a
	-- grenade (Carried; a pallet re-arm refills them), Keys.Shove shoves, Keys.Stim uses a stim (a Medkit card
	-- refills them). A Restock card refills grenades and stims with the call-ins.
	Grenade = {
		Carried = 3,
		ThrowGap = 0.8, -- seconds between two throws
		Flight = 0.45, -- seconds in the air from the hand to the mark; a row's own Flight wins
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
		-- Throw timing, one row per throw clip (Rules/ThrowTiming; docs/PROGRESSION.md >
		-- Throwing): the clip plays from Start seconds in at Speed, and the grenade, marker or
		-- flare leaves the hand when the clip reaches Release (the server waits that long,
		-- ThrowWindUp). A clip without a row gets Default.
		Throws = {
			Default = { Start = 0, Release = 0.3, Speed = 1 },
			-- 2.77 s clip: pin pulled until 1.0, the arm goes back from 1.3, the hand is at its
			-- fastest (the release) at 2.0 (measured from the retargeted clip's keyframes). The
			-- pin pull is skipped: 0.5 s from the key coming up to the release.
			grenade_throw = { Start = 1.3, Release = 2.0, Speed = 1.4 },
		},
		-- The thrower's own clip starts a ping before the server hears of the throw: up to
		-- this many seconds of that come off the server's wait. 0 = the full wind-up always.
		ThrowMaxLag = 0.1,
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
			roll = "sprint_roll", -- Shift twice
			slide = "running_slide", -- sprint + hold C or LeftControl
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
		FlareFlight = 0.45, -- seconds the flare is in the air from the hand to the mark
		DropDelay = 20, -- seconds from flare to pallet (the lure window)
		-- Taking a card (owner 2026-11-11: never by walking over it). Walk up to the crate,
		-- hold Key for Hold seconds, and a panel of big cards opens (RewardPanel); pick with
		-- a click or tap, keys 1-3 or the gamepad. Walking past CloseRadius closes it without
		-- a pick. The key is the interact key (owner 2026-11-11: E interact, V stim, F shove).
		Pick = {
			WalkOver = false, -- true: the old way back (small cards in the world, walk into one)
			Key = Enum.KeyCode.E, -- becomes Config.Keys.Interact once claude/keybinds merges
			-- The open panel's card keys, left to right; it swallows them, so they fire no
			-- call-in meanwhile. Becomes Config.Keys.CallIns once claude/keybinds merges.
			CardKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three },
			GamepadKey = Enum.KeyCode.ButtonX,
			Hold = 0.3, -- seconds the key is held to open the panel
			Radius = 9, -- studs from the crate: the prompt shows and a pick is taken
			Slack = 3, -- server tolerance on top of Radius (latency)
			CloseRadius = 12, -- the open panel closes beyond this
			ConfirmSeconds = 0.45, -- the taken card flashes this long before the panel goes
			PanelScale = 1, -- the whole panel, on top of the HUD scale (0.8: smaller, see more fight)
			Dim = 0.8, -- transparency of the dark layer behind the panel (1: none)
		},
		CardSpacing = 4.5, -- Pick.WalkOver only: studs between the three cards
		PickRadius = 2.5, -- Pick.WalkOver only: walk this close to a card to take it
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

	-- Crates and their cards (RequisitionService, Rules/Reward). A crate of a kind shows each
	-- player up to CardsPerPlayer cards in a panel; one pick per player per crate. No rarity.
	--   supply: a Resupply pallet (and the Warden's): the three supply cards.
	--   upgrade: the site crate when the hold starts: field upgrades the player does not
	--     hold, ones for an empty slot first.
	--   objective: the Main objective's reward when the hold ends: the same field-upgrade
	--     choice, and on landing every living soldier gets Squad (no pick needed).
	-- A field-upgrade offer short of CardsPerPlayer is filled with supply cards, so a crate
	-- is never empty.
	Crates = {
		CardsPerPlayer = 3,
		SupplyCards = { "medkit", "restock", "armour_plate" }, -- card order, left to right
		-- What each supply card gives (Rules/Reward Effects); the card text is built from
		-- these rows (UpgradeDefinitions).
		Cards = {
			medkit = { Heal = true, Stims = true },
			restock = { CallIns = true, Grenades = true, Stims = true },
			-- 75 (was 50): beside a full heal, half a health bar was never the pick.
			armour_plate = { Plate = 75 }, -- soaked before health (EnemyProjectileService)
		},
		ShieldCap = 100, -- the most armour a soldier carries
		Kinds = {
			supply = { Label = "RESUPPLY", Lifetime = 90, Beacon = false },
			upgrade = { Label = "FIELD UPGRADE", Lifetime = 120, Beacon = true },
			objective = {
				Label = "OBJECTIVE REWARD",
				Lifetime = 180,
				Beacon = true,
				Squad = {
					Heal = true,
					Ammo = true,
					CallIns = true,
					Grenades = true,
					Stims = true,
					Plate = 50,
				},
			},
		},
		Beacon = { Height = 70, Width = 0.7, Transparency = 0.55 }, -- the light pillar over a crate
		-- A bot takes a supply card when it is missing at least this much of what the card
		-- gives (today: health); bots have no call-ins, stims or upgrades to refill.
		BotNeed = 0.25,
		BotRadius = 14, -- studs from the crate: a bot this close takes its card
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
		-- Binoculars (Rules/Spotting, SpotUtil; docs/PROGRESSION.md > Binoculars): a row with
		-- `AimMode = "Binoculars"` (default "Throw") is not thrown. Its key raises binoculars
		-- (BinocularController: the view, the mark on the ground, the range; BinocularPose: the
		-- arms and the prop on every client), fire marks any ground the eye can see, and the
		-- server checks the mark again from the soldier's head (CallInService). A row's own
		-- `Binoculars` block overrides any value here.
		Binoculars = {
			MaxRange = 300, -- studs from the eye to the mark
			MinRange = 0, -- studs; nearer marks are refused (0 = none: no friendly fire today)
			FieldOfView = 16, -- degrees through the glass (the hip view is 70)
			Raise = 0.4, -- seconds up to the eyes; no mark is taken before
			Lower = 0.25,
			MinSlope = 0.6, -- the surface's normal.Y; steeper counts as a wall and the mark drops to its foot
			SightLift = 1.5, -- studs above the mark the line of sight is checked to (grass, kerbs)
			GroundProbe = 4, -- studs above and below the mark searched for ground
			-- What the server forgives: the client's eye and the server's head never quite agree.
			Slack = { Range = 8, Sight = 4, Ground = 3, Raise = 0.15 },
			MetresPerStud = 0.28, -- the range readout
			ConfirmKey = Enum.KeyCode.ButtonR2, -- gamepad; the mouse is left click, touch a tap
			CancelKey = Enum.KeyCode.ButtonB, -- gamepad; the mouse is right click, or the slot's key again
			MaskWidth = 1.7, -- the view's width in screen heights (two barrels side by side)
			MaskHeight = 0.86, -- its height as a share of the screen's
			-- The arms (procedural, no clip yet): the upper arms come up Raise degrees, roll
			-- Roll in toward the face, and the elbows bend Bend.
			Pose = { Raise = 105, Roll = 50, Bend = 100 },
			PropOffset = CFrame.new(0, 0.15, -0.85), -- the binoculars from the Head's centre
		},
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
		-- Anvil (105 mm battery, AirStrikeService): marked through binoculars, anywhere in the
		-- line of sight; one heavy shell Delay seconds after the mark.
		Anvil = {
			Price = 0, -- merits on the Carrier (Rules/Record, KitPrices); issued free
			Desk = "fires", -- the Carrier desk that sells it (DeskShop)
			Charges = 1,
			Cooldown = 180,
			AimMode = "Binoculars", -- "Throw" puts it back in the hand (then add ThrowDistance = 35)
			Binoculars = { MaxRange = 400 }, -- over Config.CallIns.Binoculars
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
			-- line from behind the spotter, a tall column of dark earth, smoke and burnt ground.
			Arrival = {
				Style = "shell",
				Throw = 0, -- nothing is thrown: the ring and the smoke start on the mark at once
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
			-- The body: 2 = the modelled gun (doorman.py, MeshAssets dep_doorman_*), 1 = the
			-- Part tripod (also what stands while the meshes have not loaded). Model 2's
			-- numbers, from doorman.py: the cradle turns YawHeight above the ground, the gun
			-- tips at the trunnion PitchHeight up (it sees and fires from there; the Part body
			-- does from 3.2), the muzzle is MuzzleReach ahead of the trunnion, and the gun
			-- tips no further than PitchLimit degrees up or down (look only).
			Model = 2,
			YawHeight = 1.9,
			PitchHeight = 2.6,
			MuzzleReach = 3.52,
			PitchLimit = 40,
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
		-- The crate the hold's end drops (Crates.Kinds): "objective" restocks the squad and
		-- offers a field upgrade; "upgrade" is the plain crate; "" for none.
		CompleteCrate = "objective",
		CompleteCrateOffset = 10, -- studs from the site crate, toward the nearest soldier
		ZoneSize = Vector3.new(46, 1, 46), -- Sprint 13 tune: bigger, room to kite while holding
		ZonePosition = Vector3.new(50, 8.5, 50), -- on the Compound's lower tier (ArenaService HILLS)
		SyncInterval = 0.1, -- seconds between progress updates to the UI
	},

	-- The objective pools (docs/PROGRESSION.md > Objective pools; ObjectiveService, the
	-- modules in src/server/Objectives, Rules/Objectives). Each drop draws one main objective
	-- (known before the squad moves; never the same twice in a row on a server) and SideCount
	-- side objectives the squad finds on the ground, from the map's own pool. The objectives'
	-- rows (words, tuning) and each map's pool and sites are ObjectiveDefinitions, read here
	-- as Rows and Maps: a new objective or map is a row there, never a list anywhere else.
	-- Enabled = false restores the single hold zone of Config.Objective above (appears after
	-- its AppearDelay at its ZonePosition; no side objectives).
	Objectives = {
		Enabled = true,
		-- Every objective prompt and "Hold E ..." step line (owner 2026-11-11: E interacts).
		InteractKey = Enum.KeyCode.E, -- becomes Config.Keys.Interact once claude/keybinds merges
		SideCount = 2,
		GraceSeconds = 0, -- after the squad lands, before reaching the main objective starts it
		SiteCrateOffset = 6, -- studs from the main objective to the field-upgrade crate it brings
		-- A side objective shows (HUD, marker, Control's brief) when a living squad member
		-- comes this close to it, or when Control calls it out: the first RevealAfter seconds
		-- after landing, each further one that much later again.
		RevealRadius = 80,
		RevealAfter = 90,
		BriefSeconds = 8, -- the main objective's card at insert stays this long
		RadioGap = 4.5, -- seconds between Control's lines (insert, the Warden's line)
		SyncInterval = 0.25, -- seconds between HUD updates at most
		DoneSeconds = 6, -- a finished or failed side objective stays on the HUD this long
		MarkerDistance = 1200, -- studs a world marker is seen from
		MetresPerStud = 0.28,
		LampColor = Color3.fromRGB(255, 176, 64), -- Lights On: sodium
		-- Said once at insert, before the main objective's brief.
		Frame = "Pike, Control. Clear this checkpoint so the helicopter can land and we can hold the district.",
		Rows = ObjectiveDefinitions.Rows,
		Maps = ObjectiveDefinitions.Maps,
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
		-- Which bodies Walker, Runner, Brute and Hocker wear (MeshAssets): 2 = the remade set
		-- (`inf_v2_*`, owner 2026-11-11), 1 = the first bodies (`inf_<form>_*`). The fallback
		-- switch: set 1 to go back, no revert. The Warden has one body and ignores this.
		BodyVersion = 2,
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
		-- How a spit looks (owner 2026-11-11: "just a yellow circle"; bile and pus, no green,
		-- no cartoon yellow). Drawn on each client (SpitFX; curves in Rules/SpitShape); the
		-- server keeps the arc, the hit and the puddle damage (EnemyProjectileService).
		-- Enabled = false: the old server-made ball and disc in the projectile's own Color.
		SpitFX = {
			Enabled = true,
			-- The tell, on top of the sac swell and the windup voice: the head goes back
			-- over the windup and snaps forward on the spit, bile running from the mouth.
			Tell = {
				HeadBack = 16, -- degrees
				Lunge = 10, -- degrees forward on the spit
				Recover = 0.3, -- seconds back to level
				DroolInterval = 0.14, -- seconds between drops from the mouth
			},
			-- In flight: an ellipsoid along its path (never a ball), a smaller darker blob
			-- dragging behind, a strand between and after them, drops falling off.
			Glob = {
				Color = Color3.fromRGB(142, 104, 44), -- amber-brown bile
				TailColor = Color3.fromRGB(98, 34, 30), -- dark red clot
				Reflectance = 0.12, -- wet
				Stretch = 1.5, -- length over width at rest
				SpeedStretch = 0.012, -- more per stud/s
				MaxStretch = 2.4,
				Wobble = 0.22, -- +/- share of the stretch
				WobbleRate = 6, -- per second
				TailSize = 0.55, -- of the glob
				TailLag = 0.7, -- glob lengths behind
				StrandLife = 0.12, -- seconds the strand hangs in the air (about 5 studs of it)
				StrandWidth = 0.55, -- of the glob's size, tapering to nothing
				StrandColor = Color3.fromRGB(104, 44, 30),
				DripInterval = 0.11, -- seconds between drops off one glob
			},
			-- Every drop (drool, drip, splash) is one of these; MaxPerSecond caps the drool
			-- and drips of all spits together (splash bursts are per impact).
			Drops = {
				Color = Color3.fromRGB(126, 90, 38),
				DarkColor = Color3.fromRGB(88, 30, 28),
				Size = 0.32, -- studs
				MaxPerSecond = 40,
			},
			Impact = {
				Burst = 12, -- drops thrown off the surface
				BurstSpeed = 16, -- studs/s
				SplatColor = Color3.fromRGB(96, 66, 30),
				SplatSize = 2.2, -- blotch diameter, of the projectile's Size
				SplatLobes = 3, -- smaller discs round the blotch (an uneven edge)
				SplatLife = 2.5, -- seconds; fades over the last half
				MaxSplats = 6, -- alive at once; the oldest goes first
			},
			-- The damaging pool: the core disc is exactly the damage radius; a darker rim
			-- under it marks the edge; it bubbles, and fades out as its damage ends.
			Pool = {
				Color = Color3.fromRGB(134, 98, 40),
				EdgeColor = Color3.fromRGB(72, 28, 24),
				EdgeWidth = 0.4, -- studs of rim outside the core
				Transparency = 0.25,
				Grow = 0.25, -- seconds to spread out
				StartSize = 0.3, -- share of full size it lands at
				Fade = 1, -- seconds, at the end of its life
				BubbleInterval = 0.28, -- seconds between bubbles in one pool
				BubbleColor = Color3.fromRGB(206, 186, 112), -- pus
			},
			-- Splashed (inside the impact's SplashRadius): the screen edges smear with bile.
			Smear = {
				Enabled = true,
				Color = Color3.fromRGB(110, 78, 30),
				Strength = 0.5, -- opacity at the screen edge
				Time = 0.8, -- seconds to clear
			},
		},
		PathfindingMax = 10,
		PathfindInterval = 0.5,
		PathfindVerticalGap = 4,
		PathfindBuildingRadius = 40,
		PathAgentRadius = 1.5, -- fits a 4-wide door
		PathAgentHeight = 5,
		PathWaypointSpacing = 4, -- studs between waypoints (the kit's stairs are 9-stud storeys)
		PathWaypointReach = 3, -- studs: the next waypoint counts as reached
		-- Spacing (EnemySpacing; Rules/Spacing): the Infected still pass through each other
		-- physically, so this steering is what keeps a horde from stacking on one point.
		-- Straight chase only (not paths, climbs, lures, Hockers or bosses). Not yet tuned
		-- in a playtest. Enabled = false is the old behaviour exactly.
		Spacing = {
			Enabled = true,
			-- Studs of personal space at Scale 1 (x the form's Scale, or the form's own
			-- EnemyDefinitions.SpacingRadius). Bigger = a looser horde, fewer round a player.
			Radius = 1.5,
			RadiusVariation = 0.2, -- +- share per body, so the crowd is not a grid
			CellSize = 6, -- studs: grid cell; at least the two biggest radii plus a step
			RebuildInterval = 0.2, -- seconds between grid refills (server cost)
			MaxNeighbours = 32, -- bodies one goal looks at (server cost)
			HeightGap = 6, -- studs: a body this far above or below is on another floor
			Steer = {
				Lookahead = 8, -- studs a goal sits ahead (more than any form covers a repath)
				Strength = 0.4, -- share of an overlap given way per repath; above 0.5 jitters
				BehindWeight = 0.3, -- share of that given to a body behind (front holds its place)
				MaxPush = 3, -- studs: the most neighbours move one goal
				BlockSlack = 0.15, -- share of the two radii a body may walk into a neighbour
				TravelMinPull = 0.4, -- share of the advance kept in any crowd, beyond EngageDistance
				RingFraction = 0.8, -- attack ring radius as a share of AttackRange (under 1 = can hit)
				EngageDistance = 24, -- studs from the target inside which ranks hold and wait
				RingSpread = 50, -- degrees a body's approach curves round its target
				RingPeriod = 9, -- seconds over which that curve drifts
				SwayAngle = 10, -- degrees of weave far from the target (0 = straight lines)
				SwayPeriod = 5,
				Deadzone = 0.3, -- studs: smaller steps are not taken (no shuffling on the spot)
				WaitStep = 2, -- studs: a crowded body stepping less is waiting, not stuck on cover
			},
		},
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
				PrimaryComplete = "That woke the Gate sergeant. He still guards this post. The Warden is coming up the road.",
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
	-- Players read "the Carrier"; identifiers keep the old name (docs/LORE.md > Naming).
	Lobby = {
		-- The match a squad launches into: Config.Places (Match, or a Dev pair's).
		-- Music on the Carrier (LobbyMusic): licensed tracks from Roblox's audio library, free for
		-- any experience, picked for an overcast, waiting-to-go-in mood (Nova, 2026-11-10). Low in
		-- the mix (OWNER.md: no harsh sound); fades out as your Lantern lifts.
		-- Sounds of a working ship (Nova, 2026-11-11: "noises that one would hear on a boat. people
		-- moving around, crew mumbling"; client ShipAmbience). Pro Sound Effects clips from Roblox's
		-- audio library (licensed for any experience), low in the mix (OWNER.md: no harsh sound),
		-- in their own SoundGroup, faded out with the music when the Lantern lifts. Roblox has no
		-- walls for sound, so each area has its own bed and the two cross-fade by where you stand.
		Ambience = {
			Volume = 1, -- the Ambience SoundGroup once faded in
			FadeInSeconds = 4,
			FadeOutSeconds = 2.5, -- as the Lantern lifts
			DeckHeight = 36, -- a soldier's root above this (studs) is on the flight deck
			CrossFadeSeconds = 2.5, -- hangar <-> deck
			-- One loop per area, everywhere in it (no position).
			Beds = {
				Hangar = {
					Id = "rbxassetid://9112739336", -- Aircraft Carrier Ambience 3: hallway, loop (36 s)
					Volume = 0.3,
				},
				Deck = {
					Id = "rbxassetid://9117340070", -- Pier Light Dock Creak 2: motor idle, waves, wind (61 s)
					Volume = 0.35,
				},
			},
			-- Loops at FallowLayout.Ambience points (the key), heard from Near to Far studs, only
			-- in their Area.
			Spots = {
				plot = {
					Id = "rbxassetid://9113063523", -- Aircraft Carrier Bridge 3: radio chatter, voices (92 s)
					Volume = 0.45,
					Near = 6,
					Far = 30,
					Area = "Hangar",
				},
				walla = {
					Id = "rbxassetid://9114012248", -- Crowd Murmur 1: interior, quiet walla (36 s)
					Volume = 0.3,
					Near = 10,
					Far = 45,
					Area = "Hangar",
				},
			},
			-- Now and then one of these from a random point of its Area's key.
			OneShots = {
				{ Id = "rbxassetid://9119630175", Volume = 0.3, Area = "Hangar" }, -- Steel Door 4
				{ Id = "rbxassetid://9126003568", Volume = 0.25, Area = "Hangar" }, -- Steel Lockers, slam
				{ Id = "rbxassetid://9116725218", Volume = 0.25, Area = "Hangar" }, -- Metal Latches 17
				{ Id = "rbxassetid://9119077202", Volume = 0.2, Area = "Hangar" }, -- Ship Horn, carrier interior
				{ Id = "rbxassetid://9113060656", Volume = 0.3, Area = "Deck" }, -- Carrier flight deck PA
			},
			OneShotGap = { 9, 22 }, -- seconds between one-shots (random in the range)
			OneShotNear = 10,
			OneShotFar = 70,
			CrewStepLength = 2.4, -- studs a walking crew member covers per footstep (Footsteps bank)
			CrewStepVolume = 0.3,
			CrewStepFar = 30, -- studs
		},
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
		-- The soldier on the ship looks and moves like the match's (owner, 2026-11-11): the match's
		-- idle and walk clips (client SoldierMoves, the shared SoldierLocomotion; the clips are
		-- Config.Animations.Assault, not repeated here) and the signed primary in the hands
		-- (PikeBody, the match's PlayerSetup.attachRifle).
		-- Owner 2026-11-11 (second pass): "standing up straight with the gun at a resting position
		-- in a sling across his chest", not the match's hunched rifle walk, and no hand floating
		-- off a short gun. Roblox's Rthro idle and walk (owner's pick; Roblox's own, free to use),
		-- the gun welded across the chest (PikeBody) and both hands put on it in code every frame
		-- on every client (SlingHands), so they sit on whatever gun is carried.
		Soldier = {
			Enabled = true, -- false: Roblox's stock animations and no rifle, as before
			CarryRifle = true, -- false: the clips with empty hands
			ClipWait = 8, -- seconds a client waits for the clips before keeping the stock Animate
			-- A slow stride on the ship, a sprint while Keys.Sprint (or SprintPad) is held (owner
			-- 2026-11-11: "a little too fast, he should have a slow stride and then have a
			-- seperate sprint animation on the shift key").
			WalkSpeed = 6.5, -- studs a second (the Rthro walk at about 1.1)
			SprintSpeed = 15, -- studs a second (the Rthro run at about 1.4)
			SprintPad = Enum.KeyCode.ButtonL3, -- the gamepad's sprint
			Animations = {
				Idle = "rbxassetid://2510196951", -- Rthro Idle
				Walk = "rbxassetid://2510202577", -- Rthro Walk
				Run = "rbxassetid://2510198475", -- Rthro Run, above RunAbove
			},
			-- Ground speed each clip was made for (measured 2026-11-11, the planted foot's
			-- speed): rate = speed / this, within MinRate..MaxRate.
			WalkClipSpeed = 5.7,
			RunClipSpeed = 10.5,
			RunAbove = 9, -- studs a second: faster than this plays the run (the sprint)
			MinRate = 0.6,
			MaxRate = 1.6,
			-- The gun across the chest, in the upper torso's space (front -Z, right +X): the
			-- grip low on the right, the muzzle down past the left hip, the gun's top toward the
			-- face and out from the chest.
			Sling = {
				Position = Vector3.new(0.45, -0.2, -0.8),
				Barrel = Vector3.new(-0.8, -0.6, 0),
				Up = Vector3.new(-0.5, 0.7, -0.5),
			},
			Hands = {
				HandLength = 0.3, -- studs from the wrist to the palm
				-- The left hand on the handguard: this share of the way from the grip to the
				-- muzzle, held within Along studs.
				LeftShare = 0.55,
				LeftAlong = { 0.5, 1.2 },
				LeftUp = 0.06, -- studs above the bore line
				-- Where the elbows point, in the upper torso's space.
				RightPole = Vector3.new(1, -0.7, 0.5),
				LeftPole = Vector3.new(-1, -0.7, 0.4),
				BlendSeconds = 0.3, -- hands ease onto the gun
			},
		},
		-- The walking crew (LobbyCrew, CrewWalk): pace, stride and when they speak.
		Crew = {
			WalkSpeed = 5.5, -- studs a second (a soldier walks Soldier.WalkSpeed)
			Pause = 4, -- seconds standing at each end of the route
			BubbleDistance = 12, -- studs: a soldier this close hears a line
			BubbleSeconds = 4,
			BubbleCooldown = 14, -- seconds before the same one speaks again
			-- Roblox's Rthro idle and walk for the crew (NpcBody, CrewWalk; owner 2026-11-11: the
			-- stock walk "looks silly"; it is made for 14 studs/s and played at a third of that).
			-- Roblox's own clips, free to use.
			Animations = {
				Idle = "rbxassetid://2510196951", -- Rthro Idle
				Walk = "rbxassetid://2510202577", -- Rthro Walk (made for 5.7 studs/s)
			},
			WalkClipSpeed = 0.96, -- the walk's playback rate at WalkSpeed (5.5 / 5.7)
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
		-- Players read "the helicopter" / "Helo"; this key keeps the old name (docs/LORE.md > Naming).
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
