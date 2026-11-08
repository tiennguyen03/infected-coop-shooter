# Handoff — Infected Co-op Shooter (VS Code + Claude Code terminal)

Start here when picking the project up in a fresh Claude Code session.
Last updated: 2026-11-08, start of the foundation work on branch `foundation`: the owner
asked for the "do now" items of the code review (`docs/ARCHITECTURE.md` F1-F5) before more
features. Plan: `docs/superpowers/plans/2026-11-08-foundation-f1-f5.md`; F1 (renames)
F2 (`Lifecycle` hooks, boot list) and F3 (`Attributes` / `Messages`
contract) done. Last verified
commit on `main`: the open perimeter (solo playtest).

## What this is

Roblox 4-player co-op shooter (Helldivers-style loadout power, grounded military bio-horror
setting). **Final
product is 4-player co-op**; the current build is single-player. Full loop works: spawn → fight → kills fill Resupply → flare (3) → pallet (re-arm + 1 of 3
supply cards) → Hold Position objective (site crate: 1 of 3 field upgrades) → extraction →
OPERATION COMPLETE → restart. Service rifle with a magazine, 4 call-ins on keys 1/2, 12 field
upgrades, 4 Infected forms (Walker, Runner, Brute, Hocker), Weller with Q dash / E breach /
Combat Momentum, server-authoritative everything.

Repo: https://github.com/tiennguyen03/infected-coop-shooter — folder `~/infected-coop-shooter`.

Read in this order:
1. `CLAUDE.md` — conventions, commands, workflow + doc-sync rules (short; always loaded).
2. This file — current state + what to do next.
3. `docs/HISTORY.md` — what shipped so far, with links to each sprint doc.
4. `docs/STYLES.md` — visual style guide (icons, UI, low-poly 3D, VFX, perf budgets).
5. `docs/PLAN.md` — scope rules + roadmap. `docs/LORE.md` — setting/naming.
6. `docs/MULTIPLAYER_READINESS.md` — co-op rules + debt register, before touching run flow.

## Current state (verified 2026-11-07 in a live playtest)

- 2026-11-07: **Sprint 18, loadout rework shipped and playtested**
  (`docs/sprints/SPRINT_18_LOADOUT.md`). The item economy, XP orbs and levels are gone;
  power is the loadout: service rifle with a 30-round magazine (R reloads, pallets re-arm),
  call-ins on keys 1/2 (Magpie, Tripline by default; Anvil, Pen Coil through the dev panel
  until the Armory exists), pallet cards Medkit / Restock / Armour Plate, twelve field
  upgrades in six slots from the Primary's site crate, flat threat curve with
  `Config.PlayerCountScaling`, realistic time-to-kill (Walker 3 body / 1 head). New:
  `LoadoutService`, `CallInService`, `LoadoutUI`, `WeaponDefinitions`, `CallInDefinitions`,
  `UpgradeDefinitions`. Deleted: XPOrbService, XPService, PassiveItemService,
  AmmoCacheService, PlagueRatService, ItemService, ItemDefinitions, ItemBarUI, XPBarUI,
  `docs/ITEMS_REFERENCE.md`. The 24 item icons stay uploaded; call-ins reuse them, the
  cards have none yet.
- 2026-11-07: **Infected skin v2 uploaded and verified** (`docs/STYLES.md` §2/§7,
  `docs/CHARACTERS.md` A). No zombie green: pallor / flesh / bruise / wound / pus palette
  rows, boils, lesions and blotches as geometry, milky eyes in a wound rim, octagonal tapered
  limbs with joint caps. Palette v4 texture + 23 new limb meshes wired in `MeshAssets`
  (`assets/3d/ASSET_IDS.md`); checked in a playtest (all four forms dress, no missing
  templates) and in an edit-mode lineup. Art-director pass done before upload (four
  one-line fixes applied). Later pass, not blocking: rotate lesion cores, thinner eye rims,
  Brute to `pallor_d` + bruise patches if it reads purple under the stage light.
- 2026-11-07: **Delta rework shipped and playtested** (`docs/LEVELS.md` A + B, STYLES §6).
  Building kit from plain Parts (`ArenaService.buildBuilding`, 10 models / 342 parts),
  composite colliders on the existing meshes (194 of a 256 budget), ruin v2 and guard tower
  v3, tall hesco Pens ring, Scrapes on cribbing, perches with ramps, 12 in-house props (all
  uploaded, `assets/3d/ASSET_IDS.md`), ground patches; `StreamingEnabled` 384/128 with
  atomic rigs; `EnemyService` spawn filter (40 dev Walkers: none on a roof) and vertical
  chase through `PathfindingService` for up to 10; `BotService` unstick teleport;
  `StanceService` prone (hip 0.3, stand refused under a ceiling; bodies standing over you no
  longer count as a ceiling). Perf: 60 fps with 40 Walkers, server script lane 1.6 ms/frame.
  Not yet walked: the A13 route list (R1-R7), the staircase and vertical-chase tests, the
  low-end device pass; do them in the first play session on this build.
- 2026-11-07: **The Warden, Delta's Index host, shipped and playtested** (Sprint 19,
  `docs/sprints/SPRINT_19_WARDEN.md`). Primary complete → `RunState Index` →
  `IndexService.start()`: he spawns at the Gate (scale 1.9, 7,000 hp, +33% per extra
  living player), walks the main road with radio lines, then hunts. Six welded plate
  meshes with their own health (rounds into a plate do 25%, into a bared limb 150%);
  Bash / Charge / Gas Canister / Guard with handset tells on the new `BossBarUI`;
  Riot Call at 60% and 25%. Kill → priority pallet, heal, re-arm, `Extract`. Dev: F1
  `Warden (Gate)` / `Warden here`.
- 2026-11-07: **Warden v2 body + animation set shipped and playtested** (Sprint 19 doc
  > *v2*). The owner did not want "a Brute model with riot armor slapped on top", so the
  Warden was designed live in Blender through the Blender MCP and approved, then ported:
  his own file `assets/3d/build/warden.py` (one file per singular asset, owner rule),
  upright asymmetric silhouette (left side shield + shoulder dome + riot collar, right
  side the bare MP), 18 meshes re-uploaded (2,604 tris with plates,
  `assets/3d/ASSET_IDS.md`), shield rebuilt as a fist-grip plate so it reads in any pose.
  Seven Mixamo clips retargeted and published (`warden_walk/run/idle/guard/bash/riot/
  death`, `assets/animations/ASSET_IDS.md`) and wired in `IndexService` (walk rate-scaled,
  idle only when the root is still, guard as an upper-body overlay cancelled on every
  action change, bash timed to the windup, run while charging, roar on Riot Call, death
  clip). Verified in a playtest with the published ids: all 21 parts dressed, each clip
  seen, 60 fps.
- 2026-11-07: **Open perimeter** (`docs/LEVELS.md` A15): the four solid walls are gone;
  a see-through quarantine fence with wire and watchtowers stands at the edge, the ground,
  a berm, the broken highway and the road to the city run on past it, an invisible
  collider behind the fence stops the squad. Studio boot no longer drops the first body
  through the world (the Baseplate stays solid 5 s).
- 2026-11-07: **Map placement fix + Blender map view + ladder climb** (`docs/LEVELS.md`
  A12b, `assets/3d/README.md` > *The map in Blender*): `assets/3d/build/delta_map.py`
  rebuilds Delta in Blender from the `ArenaService` tables and paints any piece across a
  slope, in the Warden lane, on the LZ pad or inside a building red; 48 pieces moved (0
  left), a ramp up the Compound's east container, boot warns on any new straddle. Ladders
  play Roblox's stock climb clip (`ladder_climb`).
- 2026-11-07: **Balance pass + downed slide fix** (Sprint 18 doc > *Balance pass*): a
  third fewer spawns, 9 magazines, cheaper and steadier pallets; a downed body no longer
  or prone body no longer slides (the prone lift never reached the AnimationConstraint
  rig; body parts now leave collision while prone or downed, `ProneBody` group, and
  rejoin only once the root has risen, so spamming C no longer drops you through the floor).
- 2026-11-07: **M16 pass shipped** (Sprint 18 doc > *M16 pass*): the service rifle is
  full auto at 750 rpm with a bloom on a held trigger, same damage, 7 magazines; bots
  0.30 s. TTK roughly halved. Watch the Brute (260 -> 360 if it melts). Backlog:
  dismemberment (`docs/PROGRESSION.md` > Backlog).
- 2026-11-07: **Warden kit expansion + shield fix shipped** (Sprint 19 doc > *Kit
  expansion and the shield*). Shield strapped along the outer forearm (was a slanted plate
  past the fist). Four new attacks from the systems-designer pass: Ground Pound (ring on
  the ground, AoE knockdown), Shield Sweep (180°, shove), Overhead Slam (punishes a
  planted body), Stomp (a hugger, any side); reactions-then-bands selection with a beat
  between attacks and a no-repeat rule; Guard is a reaction to plate fire. Player
  knockdown state (`Squad.knock`, `KnockedUntil`, `KnockdownController`, fall + get-up
  clips), `Config.Knockdown`. Bug fixed: the roll never dodged the Warden (`damagePlayer`
  "melee" kind). Bots step out of marked danger shapes. Seven more clips published.
  Watched live with the owner playing: every attack fired in one fight, no errors; a
  player knockdown has not been seen on screen yet (God mode).
- 2026-11-07: **Skinned Weller switched off** (`Config.Player.SkinnedBody = false`; players
  wear the tapered rigid body the bots wear). The owner saw the helmet, carrier and
  rifle turn away from the body: measured on the live character, the hidden rig parts
  (driven by the R15 Motor6D clips, and what the gear and rifle weld to) and the skin's
  bones diverge 30-120 degrees while animating; they agree only in the idle pose. The
  skinned body stays built and uploaded; see open work for what it needs before it comes
  back.
- 2026-11-07: **Skinned-body movement fix.** The owner reported the player "sliding",
  "barely controllable", "like two players colliding". Root cause: `buildSkinnedBody`
  scaled the imported rig with `Model:ScaleTo(0.01)`, which leaves the character Model's
  scale factor at 0.01, and a Humanoid scales its movement forces by its character's
  scale: the body took ~1.5 s to reach walking speed and slid to a stop. The scaled parts
  are now re-homed in a fresh Model (scale 1). Measured with every controller off: 0 →
  16 studs/s within 0.1 s and an instant stop (was 9 studs/s²). Rule: never leave a
  character Model with a scale factor other than 1 (`Model:GetScale()`).
- 2026-11-07: **Weller is a skinned mesh** (`Config.Player.SkinnedBody = true`;
  `docs/CHARACTERS.md` C, `assets/3d/README.md` "Skinned Weller"). One 944-tri body with
  the R15 bone tree over a hidden 15-part rig: `MeshAssets.buildSkinnedBody` loads the two
  uploaded Model assets at boot, welds the skin to the root, renames the importer's
  motors to the stock joint names and installs the result as `StarterPlayer.StarterCharacter`;
  helmet and Pike carrier weld on as rigid gear. Verified in a playtest as an NPC on its own
  Humanoid (R15 clips bend the skin at elbows and knees, feet on the ground at HipHeight
  2.19, stock motor names, gear seated). Art-director pass: ship after the hand fix (fists
  were boxing gloves; fixed and re-uploaded). The rigid fallback (tapered limbs, pads,
  fist hands) is uploaded too and is what the bots wear. Played as the player: spawns
  skinned from the first life (PlayerSetup respawns the pre-boot stock body), helmet and
  carrier on, rifle in hand, prone drops and stands back up on the renamed `Root` motor,
  death and restart respawn skinned. Not yet looked at closely: sprint / roll / vault
  clips on the skin, the hit boxes under fire from a Hocker.
- Static checks clean (stylua / selene / rojo build) at the skinned Weller commit; luau-lsp
  reports pre-existing nits only (Animations.luau, MeshAssets.dressModel narrowing).
- 2026-11-05: decided the final product is **4-player co-op**. `src/` audited; 13 single-
  player shortcuts logged in `docs/MULTIPLAYER_READINESS.md` with a planned fix each, and
  all 6 co-op design decisions are answered there. No code changed yet.
- 2026-11-07: **body + map redesign started.** Build sheets for every body in
  `docs/CHARACTERS.md`, the Delta/Mile 14/Kestrel layout spec in `docs/LEVELS.md`. Walker,
  Runner, Brute and Hocker wear the v2 limb sets and the player wears Weller (palette v3
  texture in `MeshAssets`; the other four Chosen are built, not uploaded). Delta is relaid
  to `docs/LEVELS.md` A1-A2 (LZ insert, the Gate, bus line, the Pens ring, Depot columns,
  alternate pad) with the Infected nudge rule. Still to build, in order: the rest of the
  roster (Bloat, Shedder, Crawler), the Index hosts (the Warden first, A6), Kilo; the
  LEVELS.md items that need systems (A5/A7/A9/A10) land with those systems.
- 2026-11-07: **sound day.** Six sound banks (one upload each, `SoundBanks` +
  generated `SoundBankData`): boot steps synced to the locomotion clips (footfall phases
  measured in Studio, `Config.Audio.Footsteps.Phases`), body-shot/headshot impacts at the
  hit point, the player's pain grunt, and per-form Infected vocals with no-repeat random
  variants (`EnemyService` → `WorldSounds`, 3D on the head, replicated). Pipeline and
  the bank table: `assets/audio/README.md > Banks`.
- 2026-11-07: **bot squadmates v1, tuned.** Three bots (Cole, Reyes, Cross) fill the squad in solo
  (`server/BotService`, `Config.Bots`) on the `server/Squad` roster. Tuned to support, not
  carry: ~27 DPS each (three bots ~ one player), 0.35 s reaction to a new target. With an
  idle player they no longer clear a 10 Walker + Brute wave (one went down).
- 2026-11-07: **movement weight, roll, slide.** `client/MomentumController` eases the
  body's velocity toward the input (`Config.Movement.Momentum`), so starts, stops and
  reversals take time. Sprint + LeftControl rolls (melee immunity via `CoverMoveService`),
  sprint + C slides (`Config.Movement.Roll` / `Slide`, `MovementController.tryDash`).
- 2026-11-07: **feel pass.** Crosshair hit marker replaces damage numbers (`HitMarkerUI`,
  `Config.HitMarker`; only the attacker sees it: `DamageDealt` now carries the attacker).
  Vault 0.55 s / climb 1.1 s. Infected melee skips a body mid-vault/climb
  (`CoverMoveService`, `CoverMove` remote, rate-limited window). Footsteps halved.
- 2026-11-07: **surface materials.** The map's ground, roads, concrete and nine
  one-material meshes use Roblox built-in materials instead of flat colour (rules in
  `docs/STYLES.md` §6 "Color and texture"). Multi-colour meshes and bodies still use the
  flat palette; a textured palette is the open follow-up.
- 2026-11-07: **movement set.** Crouch (LeftControl) and prone (C) stances
  (`client/StanceController`, speeds and transition times in `Config.Player.Stances`,
  camera pivot per stance in `Config.Camera.PivotHeight`); vault/climb in place of the
  jump (`client/MovementController`, `Config.Movement`: Space or sprinting into cover
  goes over jersey/hesco and onto bunker/humvee/container, never T-walls or buses;
  `PlayerSetup` zeroes JumpPower); Walkers climb hesco-height and Runners
  container-height cover (`EnemyDefinitions.ClimbHeight`, `EnemyService` tryClimb, root
  anchored and carried along `Shared.Ledge`). Clip table: `assets/animations/README.md`.
  Spare clips downloaded for later: zombie_crawl (Crawler), zombie_stumble (flinch),
  zombie_scream (Hocker windup).

## Open work, in priority order

- **Foundation backlog (2026-11-08 code review, `docs/ARCHITECTURE.md`).** Ranked concerns
  and items F1-F11: renames, lifecycle hooks, shared attribute/message constants, the open
  co-op debt (#3/#5/#9), CI + unit tests, then stage data split before objective pools,
  weapon/upgrade hooks, class interface, save service, lobby place, and how private match
  servers and the shared Containment Board scale. **The owner, 2026-11-08: do F1-F5 now**,
  "I want our foundation to be strong before we drift off into more niche features"
  (branch `foundation`, plan in `docs/superpowers/plans/`).
- **The Warden shipped 2026-11-07** (`docs/sprints/SPRINT_19_WARDEN.md` > Open work):
  handset hiss + squelch tell clip and his own vocals (audio pipeline), Gate dressing
  (chain, spray, MP roster) and the insert / wipe radio lines, a 4-player phone pass on
  phase 2. First real fight on this build: 100-120 s is the target; retune
  `Config.Index.Warden` plate health if it drags. Art-director later pass on the v2
  body: see the Sprint 19 doc > *v2* > open.
- **Perimeter: measure on a low-end device** (`docs/LEVELS.md` A15): ~458 extra
  instances (fence, wire, towers) measured 60 fps on the dev PC only; first cut if it costs
  is the wire on N/E/W. A performance-reviewer pass on it is owed.
- **Warden kit: watch for** a player knockdown in a real fight (fall + get-up clips,
  controls locked; only bots were knocked down on screen), the fight length, and the
  Sweep's shove on a laggy client.
- **Owner also said "there's other problems"** with the current build beyond the player
  body and the Warden look, not yet listed. Ask for them at the start of the next session
  before building anything new.
- **Skinned Weller is off (2026-11-07).** To bring it back: make the skin's bones follow
  the hidden rig (per frame after the animation step, `Bone.Transform` from each hidden
  part's CFrame and the bind-pose offset), or re-export the FBX so the bone rest frames
  match the R15 Motor6D C0/C1 frames; then weld gear to parts that match the skin. Check
  with the probe: part CFrame vs `Bone.TransformedWorldCFrame` under 5 degrees while
  the walk and aim clips play. Also keep `Model:GetScale() == 1`.
  Art-director later pass: carrier straps to z 0.80, a 75/25 loop either side of the elbow
  and knee rings, toe step on the boot. The other four Chosen stay rigid until a class
  system exists (build `_pc_skin_body` for them then).
- **Infected skin v2 shipped 2026-11-07** (owner direction: no "zombie green"). Open from
  the art-director pass, for the next body sprint: `Limb.lesion` cores rotated ~20°, eye rim
  `+0.06`, Walker rib slab bars varied, Brute `pallor_d` base if it still reads purple in
  game, Hocker heron pose as an idle clip (not buildable inside the R15 boxes).
- **Backlog (2026-11-07): reload clip and sound.** The magazine shipped in Sprint 18; the
  reload still has no animation and no sound (generate `reload_1..2` into a `player_weapon`
  bank with the rifle shot). Also open from Sprint 18: icons for the supply and upgrade cards (`wire.js` now only
  writes the id table; add an IconId field when they land), Hollow Point
  stagger cadence, the Armory (call-in choice before the drop).
- **Backlog (owner, 2026-11-07, after the movement set playtest).** Hit marker, faster
  vault/climb, climb immunity and quieter footsteps shipped (feel pass, HISTORY). Left, in
  the owner's order:
  1. **Realistic time-to-kill.** Shots-to-kill per form should read like real bullets into a
     body, and differ per weapon once there is more than one; retune `Weapon.Damage` and
     the roster `MaxHealth` together (systems-designer call; flat curve per the spine).
  2. **More Infected vocal variety.** Three idle / two attack lines per form is thin; add
     variants to each bank (`generate.py` `SOUNDS` + `BANKS`, re-upload the bank).
  3. **Low-health feedback (owner, 2026-11-07).** As health drops the screen greys out
     (`ColorCorrectionEffect` saturation toward -1, a dark vignette), a heartbeat loop fades
     in and speeds up, and the world's sound muffles (a low-pass `EqualizerSoundEffect` on
     the world `SoundGroup`); all of it eases back as health returns. Client-only, one
     module keyed on the local humanoid's health fraction, thresholds in Config; heartbeat
     clip via the sound pipeline. Downed (Squad) is the floor of the same effect.
  5. **Movement keys rework (owner, 2026-11-07).** Shift+Ctrl roll and Shift+C slide are
     too many chords. Owner is weighing sprint as the default speed (no walk, or walk on a
     key) so roll and slide become single keys. Decide with the systems designer before
     touching `SprintController` / `StanceController` / `MovementController` bindings.
  4. **Map rework shipped 2026-11-07** (`docs/LEVELS.md` A/B built in `ArenaService`).
     Performance review passed (60 fps at 40 Walkers; spawn raycast now ignores bodies,
     one engine Path per Infected). Left: bots are not in a collision group against the
     `Ladder` trusses, the bot slot clamp is not implemented, a failed ComputeAsync keeps
     its pathing slot, 10 permanent PointLights (6 skyline fires) and continuous fire
     emitters predate this round and break the STYLES light/particle budget; A13 walk-
     through still owed (routes, staircases, vertical chase, 2-client streaming, device
     simulator, interior darkness check).

0. **Progression (designed 2026-11-06):** `docs/PROGRESSION.md` — three-stage first loop
   (Checkpoint Delta, Mile 14, Aid Station Kestrel), player-started hold at one of three
   sites, a boss per stage, Stand Down, the nine-form Infected roster. **Built so far:**
   behaviour hooks in `EnemyDefinitions` + `EnemyProjectileService`, and the Hocker on
   Delta (verified 2026-11-06; wears the Walker limb set with a throat sac until it has its
   own mesh). **Next per the build order:** stage definitions + run state machine with
   Delta as the only stage, then Mile 14 + Bloat. Design subagents in `.claude/agents/`
   (lore-developer, systems-designer, level-designer, playtest-critic) argue the design
   before code; the lore developer owns canon.
   **Direction (decided 2026-11-06, in PROGRESSION.md):** Helldivers 2 structure on the
   roguelike run. Build order from PROGRESSION.md > Technical plan: Resupply (done
   2026-11-07; F10 fills the pool, F throws the flare) → ADS, hitscan rifle and headshots
   (done 2026-11-07) → run state machine + Operation
   (= Co-op Sprint A) → objective pools on Delta → the Warden → Containment Board → stage
   definitions. Owner still to pick "sortie" vs "drop" for a stage.
   **Roblox's own Studio MCP** (`Roblox_Studio`, added 2026-11-06, local scope) is a second
   server: use it only for `generate_animation` (returns a published id; its clips play on
   our R15 rigs, extra bones ignored), `open_cloud_invoke` and camera-positioned
   `screen_capture`. The `robloxstudio` server stays the one that drives playtests.
   **Animations shipped 2026-11-06, verified in a playtest** (`assets/animations/`,
   `AnimationController`, per-type Infected clips, hold-E breach ghost). All 15 clips are
   published through Open Cloud (ids in `Config.Animations.Ids`, `assets/animations/
   ASSET_IDS.md`), so they play outside Studio too. Polish later: a hollow breach ring.
1. **Co-op Sprint A shipped 2026-11-07** (`docs/sprints/SPRINT_17_COOP_A.md`): `Squad` roster, run state machine, reset split, spawn pads, run-end screens + ready-up, downed/revive (F), bot squadmates. **Loadout rework shipped 2026-11-07 (Sprint 18).** **The Warden shipped 2026-11-07 (Sprint 19).** **Next per the spine:** objective pools on Delta; Co-op Sprint B (register rows 3/5/7/9, extraction rule) and the lobby place (decision 7) after.
   Planned after it (owner, 2026-11-07): a **lobby place** with a main menu where parties
   queue and teleport together into the match (`docs/MULTIPLAYER_READINESS.md` decision 7);
   number keys 1-4 take call-ins and the flare (decision 8).
   (the `Squad` member abstraction that bots reuse, run state machine, downed/revive, four
   LZ pads, reset split, client screens; seven playtest-verified steps). The spine it
   serves: `docs/PROGRESSION.md > The spine` (decided 2026-11-07: loadout power, call-ins,
   field upgrades, flat curve, bot squadmates after Sprint A).
2. **Sprint 13 Full MVP Balance + Fun Test** — still OPEN. Needs 3 natural human playtests;
   tune `src/shared/Config.luau` only. Plan: `docs/sprints/SPRINT_13_FULL_MVP_BALANCE_TEST.md`.
   This is the gate for calling the MVP done (criteria in `docs/PLAN.md`).
3. **Stage 1 "Checkpoint Delta" shipped 2026-11-06** (`ArenaService`: 600 x 600 studs,
   the central checkpoint plus four outer districts (Suburb north, Depot east, Scrapyard
   south, Barracks west), ten hills on five height levels, a highway embankment the full
   width with a bridge over the main road, roads, helipad, 138 dressing pieces from 14
   character-scale Blender meshes, three burning ruins; objective zone on the Compound's
   lower tier). **Sky shipped** (`SkyService`: burnt-orange outbreak sky, smoke-stained
   clouds, a ring of burning city silhouettes outside the walls; values in
   `docs/STYLES.md > Stage 1 sky`). Verified in a playtest (Infected climb every slope,
   the tent roof slope is walkable: tent / guard tower / comm tower use
   PreciseConvexDecomposition collision, the rest Box or Hull). **Player body shipped**: the Assault class wears
   the `pc_assault_*` limb set (`PlayerSetup` -> `MeshAssets.dressModel`; avatar appearance
   off). K-9 / Epidemiologist / Recon / Engineer bodies are built and previewed in Blender,
   not uploaded (no class system yet). Pipeline `assets/3d/README.md`. Next: react to the
   owner's playtest, rock outcrops / a sunken road for more cover, class selection.
4. **Generated SFX pipeline (2026-11-06, banks 2026-11-07):** `assets/audio/build/
   generate.py` makes sounds from text prompts with Stable Audio Open Small, run in Docker
   (`generate.sh`; Docker Desktop must be running; ~1 min per sound on CPU). Shipped: the
   rifle shot (`SoundFX` `shoot`) and the six banks (steps, hits, four Infected forms).
   Next: the remaining single prompts (xp/level/item pickups, crate, mine, drone, airstrike,
   fire, shock, dash, breach, objective, extraction) as one or two more banks, then the
   reload bank with the backlog item above (`assets/audio/README.md`).
5. **Live Blender control (blender-mcp) — set up and socket-verified 2026-11-05**
   (`.mcp.json` + add-on; `assets/3d/README.md` > Live Blender). Not yet used from a Claude
   Code session (needs a restart to load the tools). Shipped meshes still go through the
   headless build script.
6. **Post-MVP roadmap** (`docs/PLAN.md` order): Co-op Sprints A/B, second playable
   character from LORE.md ("The Chosen"), elite enemies, bosses, stage progression. All new
   visual work (Blender low-poly assets, VFX, UI) follows `docs/STYLES.md`.

Minor loose ends: get an explicit `VerifyCleanup` PASS printout in a fresh playtest;
track down the harmless `rbxassetid://203785492 … Asset type does not match` warning
(a wrong-typed sound/texture reference, not an item icon); rifle `tool.Grip` tilt may want
a nudge.

## Dev environment

Toolchain is Rokit-managed (`rokit.toml`): rojo 7.6.1, StyLua 2.5.2, selene 0.31.0,
luau-lsp 1.68.0. Binaries in `~/.rokit/bin` — add to PATH if a tool is "missing":

```bash
export PATH="$HOME/.rokit/bin:$PATH"
```

Sync to Studio (keep this running in a terminal tab):

```bash
rojo serve default.project.json
```

Then in Roblox Studio open the test place ("Chance of Drops Testing", place id
15581035561), Rojo plugin → Connect (localhost:34872). After any `default.project.json`
change, restart `rojo serve` and reconnect.

Static checks after every change:

```bash
stylua src
```

```bash
selene src
```

```bash
rojo build -o build.rbxlx
```

VS Code: `.vscode/extensions.json` recommends Luau LSP, StyLua, selene and Rojo
extensions; `.vscode/settings.json` points them at the Rokit binaries.

## Roblox Studio MCP (live verification)

Server `robloxstudio` (`@chrrxs/robloxstudio-mcp@latest --auto-install-plugin`) is
configured at user scope in `~/.claude.json`, so it is available in any Claude Code session.
Studio must be open with the MCP plugin connected. Tools: `solo_playtest`, `execute_luau`
(targets `server` / `client-1`), `grep_scripts`, `get_script_source`, `get_runtime_logs`,
`capture_screenshot`, `upload_asset`, `manage_instance`.

Hard-won gotchas:
- **Studio MCP gotchas found 2026-11-07.** (1) A runtime error inside `execute_luau`
  comes back as "Unknown error" with no message: wrap the body in `pcall` and return the
  error string. (2) `Player.Character.Archivable` is false, so `Character:Clone()` returns
  nil; set it true around the clone. (3) If `solo_playtest` returns "Unknown error" and
  `get_connected_instances` shows a stale standalone "Server" instance, drive play with
  the other server's `mcp__Roblox_Studio__start_stop_play` (studio id from
  `list_roblox_studios`) and keep using `mcp__robloxstudio__execute_luau` with
  `instance_id` of the COD.rbxl instance. (4) Measuring movement: disable the
  PlayerModule controls and `UnbindFromRenderStep("Momentum")` on the client, drive
  `Humanoid:Move` yourself and sample `AssemblyLinearVelocity`; a healthy body reaches
  WalkSpeed within 0.1 s. A hand-built minimal rig in the same spot is the reference.
- **Studio MCP gotchas found in the Warden v2 session (2026-11-07).** (5) When a stale
  instance is listed, every `robloxstudio` tool needs `instance_id` (here
  `instance:75r-q99`) or it returns "Unknown error"; `solo_playtest start` also needs
  `mode: "play"`, and `execute_luau` takes the peer as `target` (`server` / `client-1`),
  not as part of the instance id. (6) A playtest can boot into `Ended Wiped`; fire
  `RestartRun` and wait for `RunState Explore` before any spawn command. (7) Client-side
  `AnimationTrack.Animation.Name` is always "Animation" for server-loaded tracks: identify
  tracks by `Length` on the client, by name on the server. (8) A server Humanoid driven by
  `MoveTo` reports `MoveDirection` = 0; test "moving" with the root's
  `AssemblyLinearVelocity`. (9) Published animation ids go into `Config.Animations.Ids`
  with the `rbxassetid://` prefix; a bare number fails with "unknown AssetId protocol".
  (10) The owner may be playing the same Studio playtest you drive (their F1 commands and
  call-ins show in the logs): read, do not hijack the camera or restart the run under
  them. To photograph a body without them: `UnbindFromRenderStep("OTSCamera")` on
  client-1 and set `CurrentCamera` Scriptable. (11) `execute_luau` with a `task.wait`
  over ~30 s returns "Unknown error": wait in 10 s slices. (12) Vector3 values do not
  JSON-serialise in a returned table: format them as strings.
- **`execute_luau` runs in an isolated VM.** `require()` returns a fresh, un-`init()`ed
  module copy — calling service functions from eval hits nil remotes. Drive the real game by
  firing the `DevCommand` RemoteEvent from `client-1`; use eval only to read Instance/
  attribute state. Stateless modules (GroundUtil) are fine in eval.
- **Dev tools v2 (2026-11-07).** In game, F1 opens the dev panel (cursor freed; grouped
  Player / Run / Infected / Squad / Teleport / Checks) with a live info line (fps, RunState,
  Infected, GOD, SPAWNS OFF). Hotkeys with the panel closed: F2 god, F3 clear Infected, F4
  10 Walkers, F5 restart, F6 fill Resupply, F7 spawning on/off. Teleports run client-side.
- DevCommand commands (fire from `client-1`): God (toggle; player attribute DevGod skips
  enemy damage), Heal (also revives), DownPlayer(botName?), RevivePlayer(botName?),
  KillPlayer, DownBot, KillBots, SetBots(n), ToggleSpawns (workspace DevSpawnsOff),
  ActivateObjective (hold zone now), ForceObjectiveComplete, ForceMissionSuccess, ForceWipe,
  RestartRun, FillResupply, SpawnEnemy(type, count), ClearEnemies, SetCallIn(slot, id),
  GiveUpgrade(id), ClearUpgrades, RefillAmmo, RestockCallIns, SetWeapon(id),
  DropUpgradeCrate, DropSupplyCrate, PrintRunState, VerifyCleanup (expects a dead run: in a
  live run it reports the armed objective zone and natural spawns). Pick a card via the
  `Resupply` remote (client fires "pick", crateId, cardId within 5.5 studs of the card) or
  walk the character into it. Call-ins: `CallIn` remote (slot, landingPoint). Teleport the
  character from `client-1` (`root.CFrame = ...`); `Humanoid:MoveTo` loses to live input.
  For a deterministic test: God + ToggleSpawns + SetBots 0, then spawn exactly what you need.
- A running playtest never picks up synced code — always Stop → Play after a sync. Studio
  MCP sometimes can't tear down a wedged playtest; manual Stop → Play fixes it.
- `grep_scripts` / `get_script_source` return "Unknown error" when Rojo isn't connected or
  when the playtest has ended (peers gone). Check `solo_playtest` status first.
- NEVER create script instances in Studio for files Rojo manages (duplicates break boot).
- **Measuring footfall phases** (`Config.Audio.Footsteps.Phases`): on `client-1`, anchor
  the live character's root, load each locomotion clip from `Config.Animations.Ids` onto
  its Animator at `Action4` priority, play it looped alone, sample `TimePosition / Length`
  and `LeftFoot`/`RightFoot` `Position.Y - root.Position.Y` every Heartbeat for two loops,
  and take the phase where each foot first drops within 0.06 studs of its minimum. The
  character must be alive (a dead R15 has broken joints, so the feet never move) and the
  scripted `MoveTo` route does not work while the control module runs.

## Security / housekeeping (do not relax)

- Never print or commit API keys. The Open Cloud key lives outside the repo in
  `~/.claude.json` (robloxstudio MCP env). `upload_asset` uses it from its own env — never
  read or echo it.
- `assets/icons/*.png` is gitignored; only SVG sources are committed.
- Commit attribution: end commit messages with
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` (or whatever model is running).
- `gh` CLI is not installed; push with plain `git push` (credentials are cached).
- If Claude Code's auto permission mode starts refusing Bash/MCP with "claude-opus-4-8 is
  temporarily unavailable, so auto mode cannot determine the safety of…", that is an
  Anthropic-side classifier outage — switch to **bypass permissions** (Shift+Tab) to unblock.
- Doc-sync: every commit that touches src/ or assets/ also updates this file's state lines +
  `docs/HISTORY.md` (+ the feature doc). A PreToolUse hook (`.claude/hooks/doc-sync-check.js`)
  blocks commits that stage code without docs; `[no-docs]` in the message bypasses it.
