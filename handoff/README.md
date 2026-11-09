# Handoff — Infected Co-op Shooter (VS Code + Claude Code terminal)

Start here when picking the project up in a fresh Claude Code session.
Last updated: 2026-11-09 (cloud sessions on pull request #1: foundation work, collaborator
setup). Last playtest-verified commit on `main`: the Warden commit, 2026-11-07 (solo +
2-client). **Start the next session by merging and playtesting #1 (Open work, Foundation
backlog), then the Warden silhouette redesign the owner asked for.**

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
  `Warden (Gate)` / `Warden here`. 16 meshes uploaded (`assets/3d/ASSET_IDS.md`).
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
- Static checks run in CI on every push since 2026-11-08 (`.github/workflows/checks.yml`:
  StyLua, Selene, Rojo build, luau-lsp type check, the Lune tests in `tests/`); all green,
  the three pre-existing type errors are fixed.
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

- **Second developer (Nova) has no sounds or animations (2026-11-09).** Roblox loads audio
  and animations only in the uploader's games or games granted access; code cannot get
  around it. Setup without a group, step by step: `docs/COLLABORATING.md` (friends, Edit
  collaborator, one place per developer inside the owner's experience). In Studio the
  `[AssetAccess]` line in Output says whether this place can load them. Owner to do the
  setup; the check itself has not run in Studio yet.
- **Foundation backlog (`docs/ARCHITECTURE.md`, items F1-F11).** Done 2026-11-08/09 in
  cloud sessions on pull request #1, CI green but **not playtested**: F5 (CI + tests), the
  F1 renames (`DamageService`, `Config.Zombies` folded), the icon scripts, three type fixes,
  the asset access check. First thing on the PC: push local work, merge #1, sync, Play, one
  full run to extraction with the Output clean. Still open: the rest of F1 (dated
  comments), F2-F4, rule-logic tests for F5, and F6-F11 before the feature each one names.
  The owner decides where they slot against the Warden redesign below.
- **NEXT: the Warden silhouette redesign (owner, 2026-11-07).** After playing the shipped
  Warden the owner said: "I like how he looks, I like the direction with the riot armor. I
  just don't like that it's essentially just a Brute model with riot armor slapped on top
  of it." Asked for: design him live in Blender through the Blender MCP (`mcp__blender__*`:
  `get_addon_status`, `execute_blender_code`, `look`) so the owner can see renders and
  direct changes before anything is ported to `build_assets.py`. State: the live Blender
  scene was cleared (default cube removed); nothing built yet. Direction drafted, not yet
  approved: upright and tall where the Brute is hunched; asymmetric (left side one armoured
  mass of shield + shoulder dome + raised riot collar, right side the bare man); head sunk
  into the collar so helmet and shoulders read as one dome; long legs with shin guards;
  duty belt with canisters; the brassard. Keep the canon (fused helmet with cracked
  visor, chest plate with the open handset, shield grown into the left forearm, six
  breakable plates, scale 1.9) and the 5,000-tri boss cap. Build from low-poly primitives
  with the STYLES §2 swatches, show front / side / three-quarter renders, iterate with the
  owner, then port the approved shapes into `warden_limb` / `_warden_plate` and re-upload
  (`assets/3d/ASSET_IDS.md`). The Blender MCP only runs on the owner's PC (its `.mcp.json`
  path is Windows). The `art-director` agent was missing from one PC session's Agent list
  but is present in cloud sessions; check before relying on it.
- **Owner also said "there's other problems"** with the build beyond the player body and
  the Warden look, not yet listed. Ask for them before building anything new.
- **Warden follow-ups** (`docs/sprints/SPRINT_19_WARDEN.md` > Open work): handset hiss +
  squelch tell clip and his own vocals (audio pipeline), an upright walk / shield-square
  charge clip instead of the mutant set, Gate dressing (chain, spray, MP roster) and the
  insert / wipe radio lines, a 4-player phone pass on phase 2. First real fight: 100-120 s
  is the target; retune `Config.Index.Warden` plate health if it drags.
- **Next on the roadmap** (`docs/PROGRESSION.md` > Technical plan, the spine): objective
  pools on Delta (do F6, the stage data split, first), then Co-op Sprint B (register rows
  3/5/9, extraction rule; = F4) and the lobby place (`docs/MULTIPLAYER_READINESS.md`
  decision 7, after F9), then Mile 14 + the Bloat, Kestrel, Stand Down.
- **Sprint 13 Full MVP Balance + Fun Test** — still open, the gate for calling the MVP done.
  Needs 3 natural human playtests; tune `src/shared/Config.luau` only. Plan:
  `docs/sprints/SPRINT_13_FULL_MVP_BALANCE_TEST.md`.
- **Owner's feel backlog (2026-11-07), in the owner's order:**
  1. **Realistic time-to-kill.** Shots-to-kill per form should read like real bullets into a
     body, and differ per weapon once there is more than one; retune `Weapon.Damage` and
     the roster `MaxHealth` together (systems-designer call; flat curve per the spine).
  2. **More Infected vocal variety.** Three idle / two attack lines per form is thin; add
     variants to each bank (`generate.py` `SOUNDS` + `BANKS`, re-upload the bank).
  3. **Low-health feedback.** As health drops the screen greys out (`ColorCorrectionEffect`
     saturation toward -1, a dark vignette), a heartbeat loop fades in and speeds up, and
     the world's sound muffles (a low-pass `EqualizerSoundEffect` on the world
     `SoundGroup`); all of it eases back as health returns. Client-only, one module keyed on
     the local humanoid's health fraction, thresholds in Config; heartbeat clip via the
     sound pipeline. Downed (Squad) is the floor of the same effect.
  4. **Movement keys rework.** Shift+Ctrl roll and Shift+C slide are too many chords. Owner
     is weighing sprint as the default speed (no walk, or walk on a key) so roll and slide
     become single keys. Decide with the systems designer before touching
     `SprintController` / `StanceController` / `MovementController` bindings.
- **Sprint 18 leftovers:** the reload has no animation and no sound (generate `reload_1..2`
  into a `player_weapon` bank with the rifle shot); icons for the supply and upgrade cards
  (the icon pipeline is ready: name each icon after its card id and `icons.js` / `wire.js`
  take the row's Color and write its IconId); Hollow Point stagger cadence; the Armory
  (call-in choice before the drop).
- **Delta loose ends** (map rework, `docs/LEVELS.md` A/B): bots are not in a collision group
  against the `Ladder` trusses, the bot slot clamp is not implemented, a failed ComputeAsync
  keeps its pathing slot, 10 permanent PointLights (6 skyline fires) and continuous fire
  emitters break the STYLES light/particle budget; the A13 walk-through is still owed
  (routes, staircases, vertical chase, 2-client streaming, device simulator, interior
  darkness check). From the Stage 1 playtest: rock outcrops / a sunken road for more cover.
- **Skinned Weller is off (2026-11-07).** To bring it back: make the skin's bones follow
  the hidden rig (per frame after the animation step, `Bone.Transform` from each hidden
  part's CFrame and the bind-pose offset), or re-export the FBX so the bone rest frames
  match the R15 Motor6D C0/C1 frames; then weld gear to parts that match the skin. Check
  with the probe: part CFrame vs `Bone.TransformedWorldCFrame` under 5 degrees while
  the walk and aim clips play. Also keep `Model:GetScale() == 1`.
  Art-director later pass: carrier straps to z 0.80, a 75/25 loop either side of the elbow
  and knee rings, toe step on the boot. The other four Chosen stay rigid until a class
  system exists (build `_pc_skin_body` for them then; class selection comes with F8).
- **Infected skin v2 follow-ups** (art-director pass): `Limb.lesion` cores rotated ~20°, eye
  rim `+0.06`, Walker rib slab bars varied, Brute `pallor_d` base if it still reads purple
  in game, Hocker heron pose as an idle clip (not buildable inside the R15 boxes).
- **Sound pipeline** (`assets/audio/README.md`; `generate.py` in Docker, Docker Desktop must
  be running, ~1 min per sound on CPU): the remaining prompts (crate, mine, drone,
  airstrike, fire, shock, dash, breach, objective, extraction) as one or two more banks,
  plus the reload bank above.
- **Polish later:** a hollow breach ring.
- **Post-MVP roadmap** (`docs/PLAN.md` order): second playable character from LORE.md ("The
  Chosen"), elite enemies, stages 4 and 5. All new visual work follows `docs/STYLES.md`.

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

**Roblox's own Studio MCP** (`Roblox_Studio`, added 2026-11-06, local scope) is a second
server: use it only for `generate_animation` (returns a published id; its clips play on our
R15 rigs, extra bones ignored), `open_cloud_invoke` and camera-positioned `screen_capture`.
The `robloxstudio` server stays the one that drives playtests.

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
