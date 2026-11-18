# Handoff: where the project is right now

Shared by everyone who works on the game (Tien, Nova, and each person's coding agent).
**Start of a session:** read this page, then every note in `handoff/log/` newer than your
last one. **End of a session:** edit this page in place (never append history here) and add
one note to `handoff/log/` (format in `handoff/log/README.md`). History lives in
`docs/HISTORY.md`; this page is only "now".

Last updated: 2026-11-18 by Nova + Claude (Kit Mods at the Loadmaster, on `nova/loadmaster-kit-mods`).
Last updated: 2026-11-18 by Nova + Claude (the M16A4 optic slot, on `nova/m16a4-optic-slot`).
Last updated: 2026-11-17 by Claude (the map room opened up, on `claude/open-map-room`).
Last updated: 2026-11-17 by Tien + Claude (the Hocker's spit pool as an uneven puddle, on `claude/spit-puddle`).
Last updated: 2026-11-17 by Tien + Claude (the objective meter and the HUD layout pass, on `claude/objective-progress-visible`).
Last updated: 2026-11-17 by Claude (every desk on the Loadmaster's look, on `claude/npc-ui-prototype2`).

## The game today (on `main`)

The full loop works in solo with bots: drop on Checkpoint Delta → fight the Infected →
Resupply flare and pallet cards → the main objective, one of five drawn per drop and started
by reaching it (field upgrades at its start and end), with two side objectives to find
(`docs/PROGRESSION.md` > Objective pools; unplayed), with the Warden (boss) coming partway
through it as its last act (on `claude/boss-in-objectives`, unplayed; `Config.Objectives.Boss.Enabled
= false` is the old order) → extraction by helicopter → OPERATION COMPLETE → ready up.
On `claude/reward-pick` (stacked on `claude/rewards-extraction`, unplayed): cards are picked
from a panel opened at the crate (hold E), and the hold's end drops an objective reward crate
that restocks the squad.

- **Squad:** anonymous soldiers Pike One to Four; bots Pike Two to Four in solo; downed and
  revive (hold E), with a revive animation: kneel, sling the rifle, press a dressing, pull
  them up (`Config.ReviveAnimation`; **not yet seen in game**, see open work). Bots walk and
  path to the leader (teleport only when stuck) and use stims, frags and one fire mission each
  (not yet seen in a playtest).
  No floating health bars or name tags; squadmates' health, armour, DOWN /
  REVIVING / DEAD on a panel on the left edge (`SquadPanelUI`, `Config.SquadPanel`).
- **Kit:** six real guns (M16A4, MP5, M249, Mossberg 590, M110, M17) plus three samples in the
  dev panel (S&W 686 revolver, M2010 sniper, the Goose rocket), each with its own Blender model
  and own shot and reload sounds; Q swap, G frag (hold to aim, release to throw), F shove,
  V stim, four call-ins on 1-4 (Hammer, Anvil, Shrike, Doorman, Concertina, Speedball, Aid
  Bag, Tripline; thrown ones are held to aim with an arc and a landing marker, every throw leaves the
  hand at the throw clip's release 0.5 s after the key, the Anvil is
  marked through binoculars anywhere in the line of sight (arms and prop are stand-ins), the Shrike is a
  modelled attack helicopter, a fire mission's mark holds the Infected on it until the rounds land
  (`Config.CallIns.Landing`, 2026-11-16, **not yet played**), the Doorman a modelled tripod gun not yet seen in game:
  `Config.CallIns.Doorman.Model = 1` puts the old one back), flare on X, the Arms Room on B (stand-in until Nova's lobby screen).
- **Vehicles** (2026-11-17, Nova; on `nova/vehicles-atv`, **not yet played**): the ATV, a
  call-in slung in under the helo; a driver and a back-seat gunner on their primary; runs the
  Infected down (`docs/PROGRESSION.md` > The ATV). Bought at the new Vehicles desk at the
  hangar's aft end (the motor pool, `docs/sprints/LOBBY_V1_FALLOW.md` > Motor pool).
- **Kit Mods** (2026-11-18, Nova; on `nova/loadmaster-kit-mods`, **for Tien to decide**: it
  breaks OWNER.md "never stat items"): a KIT MODS tab at the Loadmaster sells ranked soldier
  buffs for merits, kept on the record; Extra stim and Extra roll work, two more are greyed
  (`docs/PROGRESSION.md` > Kit Mods). **Nova:** `RecordService`'s buy is now
  `change(player, label, edit)` (the same save), `LoadmasterUI` has the tab bar, new
  `KitModsTab`; `LoadoutService.freshState` takes the player.
- **Optics** (2026-11-18, Nova; on `nova/m16a4-optic-slot`): the M16A4's EDIT at the
  Loadmaster has an Optic slot: Red dot, CompM2, ACOG, bought once with merits and kept on the
  record, fitted on the `Optic` remote (`OpticService`); zoom and ADS time change in the match
  (`Rules/AttachmentMerge`, `CameraController`; not yet seen aiming in game). The optics are
  not drawn on the gun until the free models are downloaded and uploaded
  (`assets/3d/ASSET_IDS.md` > Optics). Other guns: the next PR (`Config.Optics` rows' `Guns`).
- **Keys:** every key is a row of `Config.Keys` and every hint reads it (table: `docs/OWNER.md`);
  a key written into client or server code fails the tests. E interact, C or Ctrl crouch, Z prone.
- **Movement:** sprint on a stamina bar (8 s; a roll costs 20, a slide 10; winded at zero),
  slides that keep momentum and run on downhill (`docs/PROGRESSION.md` > The soldier). Built
  2026-11-11 on static checks and specs only: **not yet played**, the numbers want tuning.
- **Infected:** Walker, Runner, Brute, Hocker (the remade bodies since 2026-11-11;
  `Config.Enemies.BodyVersion = 1` puts the first ones back), dismemberment, the Warden with
  plates. They spread round a target instead of stacking on it
  (`Config.Enemies.Spacing`; **built from static checks only, not yet played**: `Enabled = false`
  is the old chase). Spit (Hocker, Warden) is drawn on each client: `SpitFX`, not yet seen
  in game (`handoff/log/2026-11-11-tien-hocker-spit.md`). Its ground pool is an uneven
  puddle instead of a disc since 2026-11-17 (owner; `Rules/PuddleShape`, on
  `claude/spit-puddle`, unplayed; `handoff/log/2026-11-17-claude-spit-puddle.md`).
- **Feel:** camera kick, blast shake, limp bodies thrown by the killing hit, hit flinch,
  a dark blood kill burst and a soft kill-confirm tick for the killer,
  low-health grey/heartbeat/muffle, reload clip. Every per-item feel value sits on the gun's
  or call-in's own Config row.
- **Lobby (Nova):** the Carrier (still "the Fallow" in code), `lobby.project.json` +
  `src/lobby/`: hangar desks, the Loadmaster's saved Loadout, helicopter spots that lift a squad
  into one reserved match server (`docs/sprints/LOBBY_V1_FALLOW.md`). You board by standing anywhere
  inside the yellow ring round a helicopter (2026-11-16, owner; **not yet seen in game**; **Nova:**
  the square box is gone, `Spot.board` is now `Spot.sign`, `BoardHalfSize` is now `BoardRadius`,
  the check is `Manifest.onSpot`). Three desks since 2026-11-16
  (owner; **not yet seen in game**): the Quartermaster sells every gun and grenade, the Call-ins
  desk (the sapper sergeant, was the Engineers) every call-in, the Loadmaster only signs Loadouts;
  the Fires desk is gone (**Nova:** desk id `engineers` is now `callins`; `LoadmasterUI`'s
  `soldAt("loadmaster")` now returns nothing, so its drop panel stays hidden). Behind the Call-ins
  sergeant every call-in is laid out on a pallet, picked and bought like the rack
  (`CallInDisplay`, `CallInDisplayUI`, rows' `Display`; **not yet seen in game**; **Nova:** new
  files in your `src/lobby/`, one line in `Main.client`, a hook in `DeskDialogUI`; the wire
  spools behind him gave way to it). The soldier on the ship
  uses the match's idle and walk and carries the signed primary (2026-11-11, **not yet seen in
  game**; **Nova:** small edits in your `PikeBody`, `LoadmasterService`, lobby `Main.client`,
  new `SoldierMoves`; off with `Config.Lobby.Soldier.Enabled = false`; what to check is in
  the lobby doc > What v1 has).
  **Carrier v2 is in the lobby** (2026-11-18, PR off `claude/carrier-v2-in-lobby`, **not yet seen
  in Studio**): `CarrierV2` dresses the ship from generated data, the kit meshes are uploaded,
  the map room is open, a hidden nook under the ramp, the city straight ahead, the sellers posed
  in their corners (idle loops still to make); off with `Config.Lobby.CarrierV2.Enabled = false`.
  **Nova:** touches your `FallowBuilder`, `FallowLayout`, `DeskService`, lobby `Main`; what to
  check: `docs/sprints/CARRIER_V2.md` > In the lobby.
  **Nova:** the Loadout screen (`LoadoutMenu`) was rebuilt
  bigger with each item turning in 3D and its stats (2026-11-16, not yet seen in game; what to
  check: `handoff/log/2026-11-16-claude-loadmaster-screen.md`). The map room (the Plot in
  code) has no walls since 2026-11-17 (owner: awkward to walk in and out of, cramped with a
  full lobby; on `claude/open-map-room`, **not yet seen in game**): the map table stands in open
  hangar floor, the board on two posts, and players read "MAP ROOM" (**Nova:** the walls are
  gone from `FallowBuilder.buildPlot`, `FallowLayout.Plot` lost its door fields, the desk
  title and the runner's role/lines in `LobbyDesks`/`LobbyCrew` changed).
  check: `handoff/log/2026-11-16-claude-loadmaster-screen.md`). **Every desk now looks like the
  Loadmaster** (2026-11-17, owner; on `claude/npc-ui-prototype2`, **not yet seen in game**):
  the Quartermaster's guns, the Call-ins sergeant's call-ins and the motor sergeant's ATV open
  on the Loadout's look with BUY (`DeskScreen`), and every desk's talk panel is one build in
  the menu dress (`DeskTalk`); `Config.Lobby.DeskScreen.Enabled = false` is the old views.
  **Nova:** the Loadout's frame, rows and inspect panel moved out of `LoadoutMenu` into
  `src/client/KitView.luau` (mapped into the lobby; `LoadoutMenu` behaves the same), the
  Gunsmith takes its gun from `Showcase` instead of the rack, and `Showcase` shows a vehicle
  call-in as its `VehicleBody` (what to check: `handoff/log/2026-11-17-claude-npc-ui.md`).
- **Economy:** merits (soft) are paid when a mission ends (Win 120, Partial 60, Loss 0) onto
  the record the Carrier's desks spend from; tabs (hard, Robux or events, never power) are a
  balance on the same record with nothing to buy yet (`docs/OWNER.md`, `docs/ROADMAP.md` >
  Progression). Both show as the wallet readout (a medal and a steel tag, a number each): in
  the Carrier's top bar and on the results screen (`WalletReadout`; not seen in game yet, and
  the two glyphs show as decal thumbnails until their image ids are resolved:
  `assets/icons/ASSET_IDS.md`).
- **Names (owner, 2026-11-11; Nova, this touches lobby text):** players read "the Carrier",
  "the helicopter" / "Helo" (signs `HELO · SPOT n`, the map's pencil track, the Loadmaster is
  the "Helicopter crew chief") and "Warden"; never "Fallow", "Lantern" or "Handset" in a
  string. Files, Config keys and sound keys keep the old words (`docs/LORE.md` > Naming).
- **Roblox:** the group Boomin Dev Studios (270506601) owns the game "Co-op Zombie Shooter" and
  every sound and animation. Its start place 87556879379942 holds the **lobby**; the match is
  "Checkpoint Delta" 125769854992316 (`Config.Places`).
- **Checks:** stylua, selene, rojo build, 499 Lune tests (rules plus the source-wiring spec, which also reads the lobby's remotes and refuses key literals), luau-lsp, CI on every push.
- **HUD layout** (2026-11-17, owner: "I couldn't see the indicator", Nova: "the in game UI is
  clutter and overstack each other"; **not yet seen in game**): objective progress is a big
  yellow meter under the objective line, HOLDING / red PAUSED, and shows a side objective
  while the squad works on it; the squad panel and the objective list share one left column,
  the mission line, meter and radio subtitles one stack, so none overlaps (`docs/STYLES.md`
  §5 > Nothing stacks on anything). **Nova:** a new HUD element that can grow joins one of
  those flows (`HudTheme.inLeftColumn`, `MissionLine.attach`); `MissionLine.set` takes a table
  now; `Config.SquadPanel.Top` is gone (`Config.Hud.LeftColumnTop`).
- **Checks:** stylua, selene, rojo build, 494 Lune tests (rules plus the source-wiring spec, which also reads the lobby's remotes and refuses key literals), luau-lsp, CI on every push.
- **Checks:** stylua, selene, rojo build, 502 Lune tests (rules plus the source-wiring spec, which also reads the lobby's remotes and refuses key literals), luau-lsp, CI on every push.

## Who owns what

| Area | Owner | Files (bugs here go to them) |
|---|---|---|
| Lobby place, loadout and weapon selection screens | Nova | `src/lobby/`, `lobby.project.json`, `LoadoutMenu`, `LoadoutUI`, `ArmsRoom`, `Rules/Loadout`, `LoadoutService.apply` |
| Everything else | Tien (+ Claude) | |

Claim work in the table below before starting it; delete the row when it ships.

## Open work, in priority order

**The owner's one-page view of everything open (try it, building, your call, later): [docs/BACKLOG.md](../docs/BACKLOG.md).** Update it in the same commit as the work.

The plan beyond this table, in phases, with the owner's open decisions: [docs/ROADMAP.md](../docs/ROADMAP.md).

| # | What | Owner | Notes |
|---|---|---|---|
| 1 | Lobby: debrief panel, the Carrier rename; buying is built on `nova/lobby` (merits, not Credits: Nova 2026-11-10; guns and grenades at the Quartermaster's rack, call-ins at the one Call-ins desk since 2026-11-16 (`Config.Lobby.Sellers`, a row's own `Desk` overrides); the Loadmaster signs only for kit on the record); merits are earned on missions and the record holds tabs (Tien, 2026-11-10: `RecordService.grantReceipt`, `SaveSlot.update`, `TabsService`, the balance lines in `RecordClient` / `ArmsRackUI` / `DeskShop`). 2026-11-10: desk dialog rewritten (four voices, random greetings, the same 3-choice talk at every desk), a gloomy overcast sky, lobby music (licensed library, `LobbyMusic`); ship sounds on `nova/lobby-audio` (2026-11-11, `ShipAmbience`: carrier hallway and deck beds, the Plot's radio, crew walla, doors and a horn now and then, crew footsteps; picked by description, Nova to listen); the crew and the soldier on Rthro clips, the soldier's gun slung across the chest with both hands on it (`SlingHands`), a slow stride with a sprint on Shift, every NPC and the soldier (lobby and match, players and bots: `Config.Player.Look`, Tien heads-up) on Roblox's default R15 avatar wearing catalog items (`Shared.AvatarLook`; first try of the picks page's suggestions); night vision on N in the match (`NightVision`, for Nova's night area), the goggles seen flipping down on the helmet on `nova/nvg-flip` (2026-11-11, `Shared.Goggles`; the soldier's helmet is now a plain FAST plus separate PVS-31 goggles; played, works); bots spread out in a loose formation on `nova/mile14` (`Config.Bots.Loose`; heads-up Tien: `BotService.follow` asks `spreadPosition` instead of the slot); the suppressor on `nova/mile14` (EDIT at the Loadmaster, `GunsmithUI`, `Config.Attachments`, docs/PROGRESSION.md > Attachments; heads-up Tien: the Loadout gained `attachments`, `LoadoutMenu` an `edit` option, `PlayerSetup` the suppressor part, `ShotTracer` a 5th argument); Mile 14 started on `nova/mile14` (2026-11-11: its own place Mile 14 Dev on `mile14.project.json`, a first layout, the Infected's five awareness states and gun noise, docs/PROGRESSION.md > Awareness; heads-up Tien: `EnemyService`, `ProjectileServer`, `BotService`, `KitService`, `StanceService` gained noise and stance hooks, all inert off Mile 14); the insertion cutscene on `nova/insertion-cutscene` (`InsertionCutscene`, Nova to playtest; heads-up Tien: RunManager's Insert timing and the brief now wait for it) on `nova/lobby-figures` (2026-11-11, Nova to playtest); the balcony gap closed, the coast burning harder, HARLAN replaces HRD, the Plot's watch officer and paper map, six crew walking the ship, kit on every figure and the Pike's band, chemlight and tourniquet, the five long guns rebuilt and re-uploaded (M16, MP5, M249, Mossberg, M110: tapered stocks, curved magazines, trigger guards; same grip origin and muzzles); the Arms Room fills the port fore corner (glass counter, long-gun wall; rack hover and zoom fixed); the Plot opened up (stand at the map); every NPC is an R15 crew figure; first person in the match on T with arms, gun, reload and real sights on every gun (2026-11-11, Tien + Claude: the sight pictures reworked per gun, `Weapons.<id>.Sight` + `Rules/Sight`, scope pictures with zoom on the M2010, M110 and Goose; **not yet seen in game**: run the dev sight tour, F10, and check the list in `handoff/log/2026-11-11-tien-first-person-views.md`; Nova ran it 2026-11-11: fine but the M249, MP5 and M16, whose eye sat beside the sights because Roblox mirrors the gun meshes left-right; fixed on `nova/scopes` with `MeshAssets.shownPoint`, played: fixed) (Nova; heads-up Tien: `CameraController`, `FirstPersonView`, `WeaponController` shot origin in first person, `Config.Camera.FirstPerson`). **Models still need work** (Nova, 2026-11-10): every NPC is now an R15 crew body (one plain dress mesh, coloured per figure) but faces and kit are still small blocks, the revolver, M2010, Goose and M17 were not reworked, and the rebuilt guns are unseen in a hand in the match | Nova | `docs/LOBBY_MATCH_HANDOFF.md` > What's next; `docs/ROADMAP.md` (merits, tabs, the Carrier) |
| 1a | Look at the revive animation and tune it | Tien + Claude | Built without a playtest (the owner was playing). Check list in `handoff/log/2026-11-11-tien-revive-animation.md`; every pose number is in `Config.ReviveAnimation`, `Enabled = false` is the off switch |
| 1a2 | Vehicles: play the ATV (built 2026-11-17, unplayed), then an engine sound, a Blender mesh, the motor sergeant's radio lines, more vehicles once the maps grow | Nova + Claude | check list in `handoff/log/2026-11-17-nova-vehicles-atv.md`; **Tien heads-up:** small hooks in your files (`CallInService`, `ProjectileServer`, `KitService`, `RequisitionService`, `BotService`, `Squad` revive, `EnemyProjectileService.damagePlayer` 4th arg, `LoadoutService.usePrimary`, the client movement/stance/sprint/ability/weapon gates on the `Riding` attribute) |
| 1a3 | Look at the objective meter and the HUD layout (2026-11-17, unplayed) | Tien + Claude | check list in `handoff/log/2026-11-17-claude-objective-meter.md`; numbers in `Config.Objectives.Meter` and `Config.Hud` |
| 1b | Play the away-review fixes (2026-11-16, `claude/review-fixes`, unplayed) | Tien + Claude | check list in `handoff/log/2026-11-16-claude-review-fixes.md`; Nova: the lobby now buys through `SaveSlot.update` |
| 2 | Tune the feel by playing it | Tien | the 2026-11-11 reward panel, unplayed: is the panel readable and small enough during a fight, is E right, does the objective reward feel better than a pallet, is the full call-in restock before the Warden too much (`Config.Requisition.Pick`, `Config.Crates`); the 2026-11-10 rewards pass, unplayed: half reserve at insert, the second upgrade crate at the hold's end, the 60 s extraction and its second wave (`Config.Extraction.Waves`); Infected spacing first (`Config.Enemies.Spacing`: `Radius`, `Steer.EngageDistance`, `Steer.Strength`; fewer bodies reach a player at once now, so check the damage still bites; what to look for: `handoff/log/2026-11-11-tien-infected-spacing.md`); kick and shake strength, the low-health look (overlaps HealthBarUI's red pulse), the crawl; heartbeat asset was in moderation |
| 3 | Checklist pass of every call-in and gun | Tien + Claude | dev `FireCallIn <id>`, `SetWeapon <id>`; each call-in's new arrival has not been seen in Studio yet (list: `handoff/log/2026-11-10-tien-callin-arrivals.md`), nor have the Anvil's binoculars (`handoff/log/2026-11-11-tien-anvil-binoculars.md`); throw timing (0.5 s wind-up, release from the hand) is unplayed and needs tuning (`handoff/log/2026-11-11-tien-throw-sync.md`); Gore stumps sit off the Runner/Brute arms; Brute/Walker hitboxes; the remade Infected have not been seen in game (which side the wounds are on, the bigger head boxes: `docs/STYLES.md` §7 "Infected v2") |
| 4 | Mission flow: lobby -> match -> three missions -> lobby | Tien + Claude | Both sides joined up and published 2026-11-09 (`docs/LOBBY_MATCH_HANDOFF.md`; publishing: `docs/STUDIO_MCP.md` > Places and publishing). **Tien:** the live test with a friend. Next on the match: the rest of Delta's facts (F6), the mission-to-mission transition, Mile 14 |
| 5 | Support weapons (Gun, Thumper, Kettle), incendiary + stun grenades | open | the revolver, sniper and Goose are in the Arms Room and on the lobby's rack (2026-11-09); a new gun shows up by having a row with `ArmsOrder`; guns are modelled in Blender (`guns.py`) when no free model is in hand |
| 6 | Performance measurements | open | 2-client network + MicroProfiler during an Anvil into 20, low-end device at low health (`docs/STUDIO_MCP.md`) |
| 7 | Owner calls waiting | Tien | generator to 4.8, light-tower collision as two boxes (movement keys decided 2026-11-11: Shift twice rolls, hold C or Ctrl slides) |
| 8 | Objective pools: **play the first slice** (2026-11-11, unplayed; checklist in the PR and `handoff/log/2026-11-11-tien-objective-pools.md`; dev `SetMainObjective <id>`), and the Warden inside each main objective (2026-11-16, unplayed; per-objective checklist in `handoff/log/2026-11-16-claude-boss-in-objectives.md`; dev `WardenNow`), then Open the Gate and the unbuilt side objectives, then Mile 14 + its boss | Tien + Claude | `docs/PROGRESSION.md` > Objective pools; the dev panel has no buttons for the new commands yet (`claude/dev-menu`) |
| 9 | Warden follow-ups | open | time the fight with the chest plate at 400 (target 100-120 s), Gate dressing, insert/wipe radio lines (`docs/sprints/SPRINT_19_WARDEN.md`) |
| 10 | Housekeeping | Tien | rotate the group Open Cloud key (it was pasted in chat); archive the old CZS and "Shooterr" experiences |

## Where to look

- Rules for everyone (humans and agents): `AGENTS.md`. What the owner wants: `docs/OWNER.md`.
- Machine setup and live testing in Studio: `docs/STUDIO_MCP.md`.
- New developer: `onboarding/README.md`.
- Design: `docs/PROGRESSION.md` (run, enemies, loadout), `docs/STYLES.md` (look, budgets),
  `docs/LEVELS.md` (maps), `docs/LORE.md` (setting), `docs/MULTIPLAYER_READINESS.md` (co-op).
