# Roguelike Arena Survivor

Single-player Roblox roguelike (Risk of Rain 2-inspired loop, original mechanics).
Full sprint plan and scope rules: [docs/PLAN.md](docs/PLAN.md). Read it before adding features —
it defines what is explicitly out of scope (no multiplayer, no multiple characters, no large
maps, no complex item synergies until the MVP is done).

Setting and tone: [docs/LORE.md](docs/LORE.md) — grounded military zombie apocalypse (no
magic/fantasy), playing as specialist operatives ("The Chosen") saving who can still be
saved. Use it for naming, flavor text, enemy/objective theming, and future character design.
Lore never overrides gameplay: if they conflict, gameplay wins. In-game, enemies are "the
Infected" (model name `Infected`), not generic monsters.

## Guiding rule

Choose the simplest solution that creates a playable game. Priority order:
playability > stability > clean architecture > visual polish.

## Project layout (Rojo)

| Disk | Roblox |
|---|---|
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared/` | `ReplicatedStorage.Shared` |

- `Main.server.luau` / `Main.client.luau` are the only entry points. Every other file is a
  ModuleScript exposing `init()`, required and started from Main in dependency order.
- All gameplay tuning values go in `src/shared/Config.luau` — never hardcode balance numbers
  in system code.
- RemoteEvents are declared in `src/shared/Remotes.luau` (server creates, client waits).
  Add new remote names to `REMOTE_NAMES` there.

## Conventions

- `--!strict` at the top of every file.
- Server is authoritative: never trust client-reported positions/damage. Clients send intent
  (e.g. fire direction); the server validates (cooldowns, origin sanity) and simulates.
- Enemies are Models tagged `"Enemy"` (CollectionService) with a Humanoid child.
- Damage is applied via `Humanoid:TakeDamage`.
- Use `os.clock()` for cooldown/lifetime timing, `task.delay`/`task.spawn` over `wait`/`spawn`.

## Commands

Run these from the project root. Tools are managed by Rokit (`rokit.toml`); if a tool is
missing, `~/.rokit/bin` may not be on PATH — run `rokit install` from the project root.

- `rojo serve` — start the sync server (user connects from the Rojo plugin in Studio).
- `rojo build -o build.rbxlx` — validate the project compiles into a place file.
- `selene src` — lint (run after every change).
- `stylua src` — format (run after every change).
- `rojo sourcemap default.project.json -o sourcemap.json` then
  `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` —
  type checking (requires `globalTypes.d.luau` from the luau-lsp repo; skip if absent).

## AI workflow rules (hard-won + community practice)

- Build ONE feature per prompt/turn, then verify, then move on. Don't one-shot multiple
  systems — quality and debuggability collapse.
- Sync silently breaking is the top time-waster. Before relying on Studio state, confirm
  Rojo is connected (Rojo panel in Studio, or `grep_scripts` via MCP for a string you just
  added). After any `default.project.json` change, `rojo serve` must be restarted and
  reconnected.
- NEVER create script instances in Studio via MCP for files Rojo manages — Rojo's copy +
  the created one = duplicates, and deleting "the duplicate" by path can leave the empty
  one (this killed a whole session's server boot once). If Rojo is disconnected, fix the
  connection instead of pushing scripts manually; use MCP `set_script_source` only as a
  last resort on existing instances, never `create_object` for synced scripts.
- Roblox copies StarterPlayerScripts at playtest join: a running playtest never picks up
  new code. Always stop and re-Play after a sync.
- Verify with the robloxstudio MCP loop: `start_playtest` → `eval_server_runtime` /
  `eval_client_runtime` (read `LogService:GetLogHistory()` for errors) →
  `capture_screenshot` for visual features → `stop_playtest`.
- UI in this project is code-generated (keeps disk as the single source of truth). If a
  UI ever needs hand-editing in Studio, that's a deliberate exception to discuss first.

## Verifying changes

There is no automated test runner. Verification = `selene src` + `rojo build` passing, then a
manual playtest in Studio (user presses Play, or via the Studio MCP server if connected).
Print statements from Main confirm both bootstraps ran.

## Sprint status

- [x] Sprint 1 — Foundation: movement (Roblox default), Shift sprint, hold-LMB projectile
      weapon, health/death via Humanoid, training dummies as damage targets
- [x] Feature — over-the-shoulder camera (`CameraController`): mouse locked center with
      crosshair, right-shoulder offset, character yaw follows camera (AutoRotate off).
      Built-in shift-lock disabled in `default.project.json` since Shift = sprint.
- [x] Feature — Hold Position objective V1 (`ObjectiveService` + `ObjectiveUI`): one zone
      appears at 180s, 30s accumulated standing time (pauses outside, never resets), pays
      500 XP once. XP is banked on the player's `XP` attribute until Sprint 4 builds the
      real XP system — migrate it then. Deliberately not a framework; see the V1 spec
      constraints before generalizing.
- [x] Sprint 2 — Enemy system: `EnemyService` Infected (green R15 rigs via
      `CreateHumanoidModelFromDescription`, chase nearest player with `MoveTo`, contact
      damage via range+cooldown check, population-cap spawner). Damage feedback:
      `DamageNumberUI` (client, driven by `DamageDealt` remote fired from
      `ProjectileServer`) + per-enemy health bar billboard (server, shows after first
      damage). Infected share an `Enemy` collision group (no collide with each other,
      so no zombie towers) and hide name/default-health via `DisplayDistanceType.None`.
- [x] Sprint 3 — Wave spawning: `DifficultyService` (stateless getters derive scaling
      from elapsed time: +25% enemy HP and +20% damage per minute, spawn interval decays
      0.85x/step floored at 0.75s, population cap +2/step capped at 40) drives
      `EnemyService`; `RunTimerUI` (client) reads the `RunStartTime` workspace attribute.
      Also: weapon tuned to 0.167s cooldown / 180 stud/s projectiles (user request).
- [x] Sprint 4 — XP system: `XPService` (XP/Level/XPRequired as player attributes,
      threshold = 100 * 1.25^(level-1), all awards via `XPService.addXP`) +
      `XPOrbService` (orbs drop on Infected death, magnetize within 12 studs, collect
      at 3) + `XPBarUI` (client, bottom center, attribute-driven). Hold Position
      objective now pays its 500 XP through XPService.
- [~] Sprint 5 — Item selection on level-up. Spec: [docs/ITEMS_MVP.md](docs/ITEMS_MVP.md)
      (supersedes the original plain stat upgrades — level-up offers 3 random ITEMS, pick
      1, stacks allowed). DONE (verified in playtest): `PlayerStatsService` (Damage/
      FireRate/MoveSpeed multipliers as attributes, wired into projectile damage, both
      fire-cooldown checks, and sprint speed), `PauseService` soft pause (enemies/
      projectiles/orbs/objective freeze, cursor unlocks), `ItemService` (inventory +
      offer queue + pick validation), `ItemEffectService` (bleed DoT, red damage
      numbers), `ItemSelectionUI` + `ItemBarUI`, Hollow Point Rounds fully working with
      uploaded icon art. Adrenaline Injector (below 30% HP: +20% move/fire rate per
      stack, evaluated by `ItemEffectService.stepAdrenaline`) and Tactical Drone Beacon
      (kill-proc via `lastDamager` attribution; `DroneService` drones hover/retarget/
      fire through the generic `ProjectileServer.fire()` API, so drone shots get damage
      numbers and proc on-hit items; cap 3/player) both verified. Emergency Ammo Cache
      (`AmmoCacheService`: timed crate drops, proximity pickup, random 8s buff —
      Damage/FireRate/MoveSpeed via PlayerStatsService or Shield as timed max-health
      boost; `BuffNotice` remote + `BuffNoticeUI`) and Air Support Authorization
      (`AirStrikeService`: kill counter in ItemEffectService, densest-cluster targeting,
      red warning disc, 1.5s delay, AoE blast that credits kills back to the player)
      both verified. ALL 5 ITEMS DONE — Sprint 5 complete. Icon art exists: SVG sources + 256px PNGs in `assets/icons/` (one
      per item, designed from [docs/ICON_PROMPTS.md](docs/ICON_PROMPTS.md)). To use them
      in-game: upload the PNGs as Decals (MCP `upload_asset` needs
      `ROBLOX_OPEN_CLOUD_API_KEY` with asset:write in the MCP server env, or Studio Bulk
      Import by hand), then set each item's `IconId = "rbxassetid://<id>"` in
      `shared/ItemDefinitions.luau` — the UIs switch from placeholder plates to images
      automatically.
- [x] Sprint 6 — Run progression: `RunManager` (CharacterAutoLoads off — death ends the
      run; `RestartRun` remote rebuilds it: every stateful service exposes
      `reset`/`resetPlayer`, difficulty clock restarts, objective reschedules via a run
      generation counter) + `DeathScreenUI` (K.I.A. + time survived / Infected killed /
      level reached + RESTART). Kills tracked as a player attribute by ItemEffectService.
- [x] Sprint 7 — Polish: `SoundFX` (client, rbxasset built-in sounds: shoot/hit/death/
      level-up — no uploads needed), muzzle flash + shot sound in WeaponController,
      hit/bleed/death particle bursts in DamageNumberUI (death events broadcast via the
      DamageDealt remote with kind "death"), zero-damage stock Explosion for airstrike
      flash/boom, `HealthBarUI` (bottom center above the XP bar, green→red, tracks
      Shield max-health changes).

- [~] Sprint 8 — Core loop validation & balance pass (spec given in chat 2026-06-12;
      values recorded in [docs/BALANCE_NOTES.md](docs/BALANCE_NOTES.md)): continuous
      per-minute difficulty scaling with caps, max-alive schedule (14/25/40/60), initial
      5-Infected wave, objective hold 45s + pressure wave + 25% faster spawns while
      active, Infected HP 40, rifle model (PlayerSetup `attachRifle`, shots from the
      `Muzzle` part), snappier pitched shot sound, "Items collected" on death screen.
      CODE DONE + static checks clean. PENDING: the three real playtest runs (human
      player required) and the resulting tuning reactions — fill in BALANCE_NOTES.md.
- [~] Sprint 9 — Enemy Variety V1 (spec in chat 2026-06-12): `shared/EnemyDefinitions`
      (Walker 35HP/9.5spd/8dmg/10xp from 0:00; Runner 22HP/17spd/6dmg/12xp from 1:15,
      0.9x scale, yellow tint; Brute 160HP/6.5spd/22dmg/35xp from 3:00, 2x scale via
      Model:ScaleTo, dark tint). One shared chase/melee behavior; per-type stats on the
      zombie record (attack range/cooldown/damage/xp). Spawn director: phase weights in
      `Config.Spawning.Phases` + Brute cap schedule (1/2/3) + Runner ≤35% of horde.
      Max-alive: 14/22/32/45→60. XP orbs carry per-type value (bigger orb ≥20 XP).
      Objective wave now 8 Walkers + 2 Runners (+1 Brute past 3:30). Enemy models are
      named by type, all tagged "Enemy". CODE DONE + checks clean; PENDING live
      verification (Test 1-6 in the sprint spec) — user playtest required.
- [~] Sprint 10 — Item Expansion (spec in chat 2026-06-12; notes in
      [docs/ITEM_EXPANSION_NOTES.md](docs/ITEM_EXPANSION_NOTES.md)): pool 5→13. New:
      Kevlar (level-up shield), Vampire Serum (heal/12 kills), Ricochet (instant chain),
      Shrapnel (every 6th shot extra rounds, in ProjectileServer), Incendiary Gel + Mine
      Kit + Shock Coil (new services), Hunter's Mark (central damage debuff). KEY
      ARCHITECTURE: `ItemEffectService.dealDamage(attacker, humanoid, amount, position,
      kind)` is now the ONE damage entry point — all sources route through it so Hunter's
      Mark + kill credit + damage numbers are consistent. `XPService.addLevelUpListener`
      (was setLevelUpHandler) supports multiple listeners. New items use placeholder
      icons (no art). Weapon retuned: FireCooldown 0.1 / Damage 6 (DPS 60, same TTK) per
      user request. CODE DONE + checks clean; PENDING live verification.
- [~] Sprint 11 — Integration hardening + dev tools (spec in chat 2026-06-12; notes in
      [docs/INTEGRATION_TEST_NOTES.md](docs/INTEGRATION_TEST_NOTES.md)): `DevTestService`
      (server) + `DevTestPanel` (client, F1-F9, creator/Studio-only). Commands: GiveXP,
      ForceLevelUp, GrantItem (accepts snake_case or alias), ClearItems, SpawnEnemy,
      ClearEnemies, KillPlayer, RestartRun, PrintRunState, VerifyCleanup. Gated by
      `RunService:IsStudio() or UserId==67169996` via the `DevCommand` remote. Drives the
      real services (no parallel logic). Exposed `RunManager.resetRun`,
      `EnemyService.clearAll`/`.count`, `ItemEffectService.getActiveMarkCount`. To run dev
      commands via MCP: `require(game.ServerScriptService.Server.DevTestService).spawnEnemy(...)`.
      VERIFIED in a live playtest 2026-06-12: Tests A-F all PASS (startup, enemy spawn/
      death/XP, item grant+clear+stat restore, damage routing with Hunter's Mark +60% at
      x3, full restart cleanup). Found+fixed a projectile-reset race — object-pool resets
      now also `folder:ClearAllChildren()` to sweep strays. Sprint 11 complete.
