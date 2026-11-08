# Foundation F1-F5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "Do now" items of the code review (renames, lifecycle hooks, a shared state contract, the open co-op debt, CI + unit tests) so the codebase scales before more features.

**Architecture:** Server services stop being reset by name: they register lifecycle hooks with one registry and `Main` boots them from a list that fails loudly. Every attribute name and remote message kind lives in one shared module of typed constants. Pure game rules move into dependency-free shared modules that Lune unit tests run outside Studio, and a GitHub Actions job runs the static checks and the tests on every push.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7.1, StyLua 2.5.2, Selene 0.31.0, Lune (new, via Rokit), GitHub Actions.

**Spec:** `docs/ARCHITECTURE.md` > "Foundation backlog" F1-F5 (PR #1, 2026-11-08). Co-op debt detail: `docs/MULTIPLAYER_READINESS.md` register #3, #5, #9.

## Global Constraints

- `--!strict` in every Luau file; `stylua src && selene src && rojo build -o build.rbxlx` clean after every task.
- All tuning values in `src/shared/Config.luau`; remotes declared in `src/shared/Remotes.luau` (`REMOTE_NAMES`).
- Damage goes through one entry point (after F1: `DamageService.dealDamage`).
- State keyed by `Player`, cleaned on `PlayerRemoving`; never `GetPlayers()[1]`.
- One feature per commit, each verified in a Studio playtest (Studio MCP); every commit touching `src/` carries its docs (handoff in place, HISTORY row, feature doc) or the doc-sync hook blocks it.
- Work on branch `foundation`; never push or merge without the owner.
- History docs (`docs/sprints/*`, `docs/HISTORY.md` rows) are not rewritten by renames; living docs are.

## Review Focus

1. A run restarted after a **wipe** and after an **extraction** must leave no state from the last run (enemies, puddles, mines, drones, crates, objective, Warden, cooldowns, magazines). Owned by Task 2: a dev command `VerifyCleanup` after each restart, both paths.
2. A service whose `init()` errors must name itself in the log and stop boot loudly, not silently skip the rest. Owned by Task 2: temporarily make one `init()` error in a playtest and read the log.
3. An attribute read through the contract with a **typo** must fail at analysis time, not read nil at runtime. Owned by Task 3: the constants table is a frozen, typed table; `luau-lsp analyze` flags an unknown key.
4. With **two players**, one standing in the hold zone and one dead or far away, the hold and extraction must follow the decided rule and show "waiting for squad". Owned by Task 4: a 2-client playtest.
5. A deliberately broken rule (magazine refuses a reload with reserve left) must turn CI red. Owned by Task 5: break, push to a test branch or run the CI command locally, see the failure, revert.

---

### Task 1 (F1): Renames and comment cleanup

**Files:**
- Rename: `src/server/ItemEffectService.luau` -> `src/server/DamageService.luau` (module table `DamageService`), and every `require(...ItemEffectService)` / `ItemEffectService.` reference in `src/` (11 server files).
- Modify: `src/shared/Config.luau` (`Config.Zombies` removed: spawn keys `SpawnInterval, InitialCount, MinSpawnDistance, MaxSpawnDistance, SpawnAttempts, SpawnBuildingMargin` move into `Config.Spawning`; body keys `CorpseLifetime, BossCorpseLifetime, MaxPuddles, ThroatSacSwell` move into `Config.Enemies`); every `Config.Zombies.X` read (12 sites) follows its key.
- Modify: `assets/icons/build/wire.js` (stop writing `src/shared/ItemDefinitions.luau`, which no longer exists: write icon ids into a JSON next to the icons and print them; the game has no item icons to wire today).
- Modify: dated comments in `src/` (92 lines matching `20\d\d-\d\d-\d\d`): drop the date and the "was X before" narration, keep the reason. Owner quotes stay only where they are the reason.
- Docs: living docs that name the old symbols (`CLAUDE.md`, `docs/MULTIPLAYER_READINESS.md`, `docs/ARCHITECTURE.md` F1 marked done, `docs/PROGRESSION.md`, `handoff/README.md`); HISTORY row.

- [ ] Rename the module and references; `grep -rn ItemEffectService src` returns nothing.
- [ ] Move the Config keys; `grep -rn "Config.Zombies" src` returns nothing; selene + luau-lsp clean (an unmoved key is a type error).
- [ ] Fix `wire.js`; `node assets/icons/build/wire.js --help` (or a dry run) no longer references ItemDefinitions.
- [ ] Comment pass; `grep -rcE "20[0-9]{2}-[0-9]{2}-[0-9]{2}" src` totals 0.
- [ ] Static checks; solo playtest: boot, kill Infected (damage path), complete or force a run end, restart.
- [ ] Commit "F1: DamageService, Config.Zombies folded, wire.js, comments".

### Task 2 (F2): Lifecycle registry and loud boot

**Files:**
- Create: `src/server/Lifecycle.luau`
- Modify: `src/server/Main.server.luau` (boot from an ordered list of module names), `src/server/RunManager.luau` (no service reset by name), every service with run or player state (the 17 in `RunManager.startRun`, the 6 in `resetPlayer`, every `Players.PlayerRemoving` handler in `src/server`).

**Interfaces:**
- Produces:
  - `type Hooks = { onRunStart: (() -> ())?, onSortieStart: (() -> ())?, onOperationStart: (() -> ())?, onPlayerReset: ((Player) -> ())?, onPlayerRemoving: ((Player) -> ())? }`
  - `Lifecycle.register(name: string, hooks: Hooks)` - called from each service's `init()`; registration order = boot order.
  - `Lifecycle.runStart()`, `Lifecycle.sortieStart()`, `Lifecycle.operationStart()`, `Lifecycle.playerReset(player: Player)` - call every registered hook of that kind in order, each in `pcall`; an error is `warn`ed with the service name and the others still run.
  - `Lifecycle.init()` - connects `Players.PlayerRemoving` once and calls every `onPlayerRemoving`.
  - `Lifecycle.registered(): { string }` - names, for the boot log and `VerifyCleanup`.
- Boot: `Main` holds `local SERVICES = { "SkyService", "ArenaService", ... }` in today's order; for each: `require`, `pcall(module.init)`; on failure `error("[Server] " .. name .. ".init() failed: " .. err)` after printing which services did start.

- [ ] Write `Lifecycle.luau` with the interface above.
- [ ] Move each service's reset into `Lifecycle.register(...)` in its own `init()` (`EnemyService` -> `{ onRunStart = EnemyService.reset }`, `LoadoutService` -> `{ onPlayerReset = LoadoutService.resetPlayer, onPlayerRemoving = ... }`, etc.). Keep the order that matters: `Squad.resetRun` last (it registers last via a `late = true` flag or by registering from `RunManager` after the loop); `DifficultyService.restart` as its `onRunStart`.
- [ ] `RunManager.startRun` calls `Lifecycle.runStart()` then `Lifecycle.playerReset(player)` per player; the 23 named calls are gone.
- [ ] Every `Players.PlayerRemoving:Connect` in `src/server` except `Lifecycle` becomes an `onPlayerRemoving` hook.
- [ ] `Main` boots from the list. Verify the loud failure: temporarily `error("test")` in one `init()`, playtest, read the log line naming it, revert.
- [ ] 2-client playtest: wipe -> restart, and extract -> restart, `VerifyCleanup` clean after each; one player leaves mid-run, no errors.
- [ ] Commit "F2: lifecycle hooks, boot from a list".

### Task 3 (F3): Shared state contract

**Files:**
- Create: `src/shared/Attributes.luau` - every attribute name as a constant, grouped: `Attributes.Workspace` (RunState, RunResult, GamePaused, ...), `Attributes.Player` (Mag, Reserve, Weapon, ...), `Attributes.Character` (SquadState, KnockedUntil, RootDrop, ...), `Attributes.Enemy` (EnemyType, PlateHealth, ...); plus `Attributes.animPreview(clip: string): string` for the `Anim_` prefix. `table.freeze` on every group; values equal the current strings so nothing on disk or in a running place changes.
- Create: `src/shared/Messages.luau` - every remote message kind as constants per remote: `Messages.Resupply = { Flare = "flare", Pick = "pick", Called = "called", Cards = "cards", Picked = "picked", Closed = "closed" }`, `Messages.BossUpdate`, `Messages.Impact`, `Messages.ObjectiveUpdate`, `Messages.ExtractionUpdate`, `Messages.Stance`, `Messages.Ability`, `Messages.CoverMove`, `Messages.DamageDealt` kinds; frozen.
- Modify: every file with `Attribute("` (33 files) and every send / receive of a message kind; `StanceService`'s local `*_ATTRIBUTE` constants and `Animations.ATTRIBUTE_PREFIX` move into `Attributes`.
- Modify: `src/shared/Remotes.luau` comments point at `Messages`.

- [ ] Write both modules from the inventory (56 attribute names; the message kinds listed in `Remotes.REMOTE_NAMES` comments).
- [ ] Rewrite reads/writes. Done when `grep -rn 'Attribute("' src` lists only `Attributes.luau` and `grep -rnE '(FireServer|FireClient|FireAllClients)\(([a-z.]+, )?"' src` lists only `DevCommand` calls (dev command names stay strings: a dev tool, not game state).
- [ ] `luau-lsp analyze` on the whole tree: no new errors; a deliberate typo `Attributes.Player.Magg` errors, then revert.
- [ ] Solo playtest: fire, reload, call-in, resupply flare + pick, downed + revive, Warden fight start (boss bar, tells), extraction - all still work.
- [ ] Commit "F3: Attributes and Messages contract".

### Task 4 (F4): Open co-op debt #3, #5, #9

**Files:**
- Modify: `src/server/ObjectiveService.luau`, `src/server/ExtractionService.luau`, `src/client/ObjectiveUI.luau`, `src/client/ExtractionUI.luau` (#3); `src/server/DifficultyService.luau` (#5); `src/server/DamageService.luau`, `src/client/HitMarkerUI.luau` (#9); `src/shared/Config.luau` (rule values).
- Rules (decided here, owner may override; record in `docs/MULTIPLAYER_READINESS.md`):
  - #3 hold: progress runs while **at least one living member** stands in the zone (unchanged), and the UI shows how many are in (`n / living`). Extraction completes only when **every living member** is on the pad; while some are and some are not, progress pauses and the pad shows "Waiting for squad (n / living)". Downed members do not count as living for this; bots count when present.
  - #5: the difficulty clock is accumulated unpaused time (`DifficultyService` adds `dt` only while not paused; `RunStartTime` stays for the HUD timer).
  - #9: hit numbers and hit sounds go to the attacking player only (`FireClient(attacker, ...)`); kills (`"death"`) still go to everyone for the VFX, sound attenuated by distance on the client.
- [ ] Implement #5; verify: pause 20 s mid-run, the spawn interval did not advance.
- [ ] Implement #9; verify in a 2-client playtest: client 2 sees no hit numbers for client 1's hits; both see a kill.
- [ ] Implement #3; verify in a 2-client playtest: one player on the pad shows "Waiting for squad (1/2)" and no progress; both on the pad completes; one downed elsewhere and one on the pad completes.
- [ ] Mark #3, #5, #9 done in `docs/MULTIPLAYER_READINESS.md`; commit "F4: co-op debt #3 #5 #9".

### Task 5 (F5): CI and unit tests

**Files:**
- Modify: `rokit.toml` (add `lune = "lune-org/lune@<current stable>"`).
- Create: `src/shared/Rules/Magazine.luau`, `src/shared/Rules/CallInCharges.luau`, `src/shared/Rules/Plates.luau`, `src/shared/Rules/DifficultyCurve.luau` - pure functions with no `game` / Roblox datatypes, taking settings as arguments; the services call them instead of their inline math.
- Create: `tests/run.luau` (Lune runner: requires every `tests/*.spec.luau`, counts failures, exits 1 on any), `tests/Magazine.spec.luau`, `tests/CallInCharges.spec.luau`, `tests/Plates.spec.luau`, `tests/DifficultyCurve.spec.luau`.
- Create: `.github/workflows/ci.yml` - on push and pull_request: checkout, install Rokit tools (`CompeyDev/setup-rokit` action, pinned), `stylua --check src`, `selene src`, `rojo build -o build.rbxlx`, `lune run tests/run`.

**Interfaces (pure, exact values from Config passed in by the caller):**
- `Magazine.canFire(mag: number): boolean`; `Magazine.reload(mag: number, reserve: number, size: number): (number, number)` -> new mag, new reserve.
- `CallInCharges.tick(charges: number, max: number, nextAt: number?, now: number, cooldown: number): (number, number?)`.
- `Plates.absorb(plateHealth: number, damage: number, guardFactor: number): (number, number)` -> plate health left, damage passed to the body.
- `DifficultyCurve.spawnInterval(base: number, decayPerMinute: number, minInterval: number, unpausedSeconds: number): number`.

- [ ] Write each spec first (e.g. `reload(0, 240, 30) == 30, 210`; `reload(12, 10, 30) == 22, 0`; `reload(30, 240, 30) == 30, 240`; `spawnInterval(3, 0.95, 1.5, 0) == 3`; `spawnInterval(3, 0.95, 1.5, 3600) == 1.5`), run `lune run tests/run`, see them fail.
- [ ] Extract the rules from `LoadoutService`, `CallInService`, `IndexService`, `DifficultyService` into the modules; services call them; tests pass.
- [ ] CI workflow; verify locally with the same commands; break `Magazine.reload` on purpose, see the runner exit 1, revert.
- [ ] Solo playtest: reload, call-in recharge, plate breaks, spawn pacing unchanged.
- [ ] Commit "F5: Lune unit tests for the pure rules, GitHub Actions CI"; `docs/ARCHITECTURE.md` F1-F5 marked done with the HISTORY row.
