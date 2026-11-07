# Handoff — Infected Co-op Shooter (VS Code + Claude Code terminal)

Start here when picking the project up in a fresh Claude Code session.
Last updated: 2026-11-07 (Co-op Sprint A step 4: spawn pads). Last verified commit on `main`: the Sprint A step 4 commit (playtested).

## What this is

Roblox 4-player co-op shooter (Helldivers-style loadout power, grounded military bio-horror
setting). **Final
product is 4-player co-op**; the current build is single-player. Full loop works: spawn → fight → earn Resupply → flare → pallet → walk into 1 of 3 cards → Hold Position
objective → extraction → OPERATION COMPLETE → restart. 24 items, 4 Infected forms (Walker, Runner, Brute, Hocker), Assault
class with Q dash / E breach / Combat Momentum, server-authoritative everything.

Repo: https://github.com/tiennguyen03/infected-coop-shooter — folder `~/infected-coop-shooter`.

Read in this order:
1. `CLAUDE.md` — conventions, commands, workflow + doc-sync rules (short; always loaded).
2. This file — current state + what to do next.
3. `docs/HISTORY.md` — what shipped so far, with links to each sprint doc.
4. `docs/STYLES.md` — visual style guide (icons, UI, low-poly 3D, VFX, perf budgets).
5. `docs/PLAN.md` — scope rules + roadmap. `docs/LORE.md` — setting/naming.
6. `docs/MULTIPLAYER_READINESS.md` — co-op rules + debt register, before touching run flow.

## Current state (verified 2026-11-05 in a live playtest)

- Sprint 15 (Assault Class V1 + held gun + Common Item Pack 1) **live-verified**: rifle is a
  real equipped `Tool`, cooldowns freeze during item-selection pause, fire pools/rats/
  airstrikes sit on the floor (`shared/GroundUtil`), rats move as one model (no after-
  images), full run to OPERATION COMPLETE.
- Sprint 16 (Plague Rat Charm) verified earlier.
- All 24 item icons (v2 uniform style) uploaded to Roblox and wired
  (`assets/icons/ASSET_IDS.md`).
- Static checks clean (stylua / selene / luau-lsp / rojo build) at `ca95c58`.
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
- 2026-11-07: **bot squadmates v1.** Three bots (Cole, Reyes, Cross) fill the squad in solo
  (`server/BotService`, `Config.Bots`) on the new `server/Squad` roster. They are strong:
  the squad cleared 10 Walkers + a Brute in 18 s unaided; tune `Config.Bots` (Damage, FireCooldown, Range) after the owner plays with them.
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

- **Backlog (owner, 2026-11-07): Infected skin direction.** The owner does not want "zombie
  green" skin. Target is Resident Evil bio-horror: lesions, pustules, exposed flesh, wet
  reds and pale bruised skin, with the `rebuilt` (scar) and `strain` (caustic fluid) rows
  doing the work. Means a new skin row set in `docs/STYLES.md` §2 replacing the three
  `infected` tints, and a re-paint pass on the four v2 Infected builders (geometry stays).
  Not scheduled; do it in one pass with the next body sprint.
- **Backlog (owner, 2026-11-07): rifle reload.** A magazine, R to reload, a reload clip and
  a reload sound (generate `reload_1..2` into a `player_weapon` bank with the rifle shot).
  Goes with the ammo economy decision in PROGRESSION; not before Co-op Sprint A.
- **Backlog (owner, 2026-11-07, after the movement set playtest).** Hit marker, faster
  vault/climb, climb immunity and quieter footsteps shipped (feel pass, HISTORY). Left, in
  the owner's order:
  1. **Realistic time-to-kill.** Shots-to-kill per form should read like real bullets into a
     body, and differ per weapon once there is more than one; retune `Weapon.Damage` and
     the roster `MaxHealth` together (systems-designer call; flat curve per the spine).
  2. **More Infected vocal variety.** Three idle / two attack lines per form is thin; add
     variants to each bank (`generate.py` `SOUNDS` + `BANKS`, re-upload the bank).
  3. **Publish the roll and slide clips.** `sprint_roll` is retargeted and plays as a Studio
     preview only (`Config.Animations.Ids.sprint_roll = ""`). `running_slide` (Mixamo
     "Running Slide", FBX without skin, 30 fps) still has to be downloaded into
     `assets/animations/source/mixamo/running_slide.fbx`: Chrome blocked the second
     automatic download from mixamo.com. Then retarget both and publish them in one pass
     (`assets/animations/README.md` steps 2-4). Until then the slide plays standing upright (owner flagged it 2026-11-07: "not like I'm sliding on the ground").
  5. **Movement keys rework (owner, 2026-11-07).** Shift+Ctrl roll and Shift+C slide are
     too many chords. Owner is weighing sprint as the default speed (no walk, or walk on a
     key) so roll and slide become single keys. Decide with the systems designer before
     touching `SprintController` / `StanceController` / `MovementController` bindings.
  4. **Rework the map for the movement set.** Delta was laid out for a body that walks
     around cover; now it vaults, climbs and is climbed over. Redo `docs/LEVELS.md` with
     more climbable cover (containers, humvees, bunkers, stacked hesco), routes that use
     height, and Infected approach lines that go over low cover (level-designer call).

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
1. **Co-op Sprint A in progress (steps through 2 done 2026-11-07):** `docs/sprints/SPRINT_17_COOP_A.md`
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
- **`execute_luau` runs in an isolated VM.** `require()` returns a fresh, un-`init()`ed
  module copy — calling service functions from eval hits nil remotes. Drive the real game by
  firing the `DevCommand` RemoteEvent from `client-1`; use eval only to read Instance/
  attribute state. Stateless modules (GroundUtil) are fine in eval.
- DevCommand commands: GiveXP, ForceLevelUp, FillResupply, GrantItem(itemId, stacks), ClearItems,
  SpawnEnemy(type, count), ClearEnemies, KillPlayer, RestartRun, PrintRunState,
  VerifyCleanup, ForceObjectiveComplete, ForceMissionSuccess. Pick a card via the
  `Resupply` remote (client fires "pick", crateId, itemId) or walk the character into it.
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
