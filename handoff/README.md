# Handoff — Roguelike Arena Survivor (VS Code + Claude Code terminal)

Start here when picking the project up in a fresh Claude Code session.
Last updated: 2026-11-06 (progression redesign). Last verified commit on `main`: `8e49b71`.

## What this is

Roblox roguelike (Risk of Rain 2-style loop, grounded military bio-horror setting). **Final
product is 4-player co-op**; the current build is single-player. Full loop works: spawn → fight → level up → pick 1 of 3 items → Hold Position
objective → extraction → OPERATION COMPLETE → restart. 24 items, 4 Infected forms (Walker, Runner, Brute, Hocker), Assault
class with Q dash / E breach / Combat Momentum, server-authoritative everything.

Repo: https://github.com/tiennguyen03/risk-of-blox — folder `~/roguelike-arena-survivor`.

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

## Open work, in priority order

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
   roguelike run. Build order from PROGRESSION.md > Technical plan: Resupply (supply-drop
   draft replacing the pause level-up) → ADS + headshots → run state machine + Operation
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
1. **Plan Co-op Sprint A** from the decided design in `docs/MULTIPLAYER_READINESS.md`
   (run state machine, no-pause level-up, downed/revive, spawn pads, reset split, client
   screens). Verify with the Studio MCP `multiplayer_playtest` tool.
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
4. **Generated SFX pipeline (2026-11-06):** `assets/audio/build/generate.py` makes sounds
   from text prompts with Stable Audio Open Small, run in Docker (`generate.sh`; Windows
   Smart App Control blocks PyTorch on the host; ~3 min per sound on CPU). The rifle shot is
   generated, uploaded and wired (`SoundFX` `shoot`, with a built-in fallback). Next: run the
   other 31 prompts, upload, wire the new events (`assets/audio/README.md`).
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
- DevCommand commands: GiveXP, ForceLevelUp, GrantItem(itemId, stacks), ClearItems,
  SpawnEnemy(type, count), ClearEnemies, KillPlayer, RestartRun, PrintRunState,
  VerifyCleanup, ForceObjectiveComplete, ForceMissionSuccess. Pick an item via the
  `ItemSelection` remote (client fires chosen item id).
- A running playtest never picks up synced code — always Stop → Play after a sync. Studio
  MCP sometimes can't tear down a wedged playtest; manual Stop → Play fixes it.
- `grep_scripts` / `get_script_source` return "Unknown error" when Rojo isn't connected or
  when the playtest has ended (peers gone). Check `solo_playtest` status first.
- NEVER create script instances in Studio for files Rojo manages (duplicates break boot).

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
