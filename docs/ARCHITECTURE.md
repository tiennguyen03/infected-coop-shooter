# Architecture review and foundation backlog

Written 2026-11-08 from a code review with the owner (cloud session, no code changed). It
records what the codebase gets right, what will hurt as the game grows to the planned scope
in [PROGRESSION.md](PROGRESSION.md), and the foundational work to do about it, in priority
order. Each item is one playtest-verified step, like a sprint step. When an item ships, mark
it done here and add the HISTORY row; do not delete it.

## Keep doing (verified in the review)

- **Server authority.** Every `OnServerEvent` handler checks argument types and the
  sender's state. Fire: type, rate (with jitter slack), origin within 10 studs of the root,
  a round in the magazine. Resupply pick: the card was offered to that player, they can
  act, they stand within `PickRadius`. Dev commands: Studio or the creator only.
- **One config, one remote list, one damage entry point.** Keep all three.
- **Strict Luau, StyLua, Selene, Rojo, git.** The professional Roblox setup.
- **Per-player state** keyed by `Player` and cleaned on `PlayerRemoving`.
- **Asset loading at boot is guarded** (`pcall` around `InsertService` in `MeshAssets`).

## Concerns, ranked

1. **The run reset is a hand-maintained list.** `RunManager.startRun` calls 17 service
   resets by name and `resetPlayer` 6 more. A service missing from the list leaks state into
   the next run with no warning. The planned campaign needs three scopes (run, sortie,
   operation) with some state carried between sorties, which a list cannot express.
2. **Server and client share state through unchecked strings.** The server sets 37 distinct
   player/workspace attribute names (about 215 lines in `src/` touch attributes), and remote
   payloads carry their kind as a string (`"flare"`, `"pick"`, `"show"`). A typo on either
   side reads nil silently; the type checker cannot see it.
3. **`ArenaService` is 2,016 lines mixing Delta's layout data with build logic.** Four more
   stages are planned, and objective pools need per-stage site and landmark data.
4. **Boot is all-or-nothing and order-dependent.** `Main.server.luau` starts 29 services in
   a hand-ordered list; one `init()` error silently stops every service after it.
5. **Naming drift after the loadout rework.** `ItemEffectService` is the damage entry point
   though items are gone; `Config.Zombies` holds spawn tuning beside `Config.Spawning` and
   `Config.Enemies`; `assets/icons/build/wire.js` still writes into the deleted
   `ItemDefinitions`; 76 dated comments in `src/` narrate history that belongs in git and the
   sprint docs.
6. **Upgrades are wired in by name.** 12 field upgrades are checked with `hasUpgrade(...)` at
   13 call sites across `ProjectileServer`, `LoadoutService`, `AssaultClassService`,
   `CallInService`. The Armory plans 16+ weapons at launch; each new item would mean editing
   combat code.
7. **No automated tests and no CI.** Static checks run only when someone remembers.
8. **Network and frame cost in co-op.** Every hit is `FireAllClients` (debt register #9);
   the server runs 15 separate `Heartbeat` connections and the client 8.
9. **Large commits on `main`.** The Warden commit touched 62 files, the skinned body 118.
   Use a branch per feature and a commit per working step so a regression can be bisected.

## Foundation backlog, in priority order

### Do now (before more content)

| # | Item | Done when |
|---|---|---|
| F1 | **Done 2026-11-08** (branch `foundation`). **Renames and comment cleanup** (concern 5). `ItemEffectService` → `DamageService`; fold `Config.Zombies` into `Config.Spawning` / `Config.Enemies`; fix or delete `wire.js`'s ItemDefinitions write; cut dated history from comments, keep the "why". Update every doc that names them. | static checks clean, solo playtest boots and a run completes |
| F2 | **Done 2026-11-08** (`src/server/Lifecycle.luau`, `Main` `BOOT` list). **Lifecycle hooks** (concerns 1, 4). Services register `onRunStart`, `onSortieStart`, `onOperationStart`, `onPlayerReset`, `onPlayerRemoving` with one registry; `RunManager` calls the registry, not services by name. `Main` starts services from a list and logs which `init()` failed and stops loudly. | no service is reset by name in `RunManager`; restart after a wipe and after an extraction both leave no state behind (2-client playtest) |
| F3 | **Done 2026-11-08** (`src/shared/Attributes.luau`, `src/shared/Messages.luau`). **Shared state contract** (concern 2). A shared module declares every attribute name and every remote message kind as typed constants, like `Remotes.REMOTE_NAMES`; all reads and writes use it. | `grep 'Attribute("'` in `src/` returns only that module |
| F4 | **Open co-op debt**: [MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) #3 (hold and extraction rule for N players, "waiting for squad"), #5 (difficulty clock ignores pause), #9 (hit events to the attacker only). Co-op Sprint B. | 2-client playtest of hold, extraction and hit markers |
| F5 | **Safety net** (concern 7). GitHub Actions job: `stylua --check src`, `selene src`, `rojo build`. Unit tests for pure rules (magazine and reload, call-in charges, plate damage, difficulty curve) with Lune or Jest-Lua, run outside Studio and in CI. | CI green on a push; a deliberately broken rule fails a test |

### Do right before the feature that needs it

| # | Item | Before | Notes |
|---|---|---|---|
| F6 | **Stage data split** (concern 3): a generic builder plus one data file per stage (PROGRESSION technical plan step 8, `StageDefinitions`). | objective pools (next on the roadmap), not Mile 14 | pools place objectives at each stage's three sites and named landmarks |
| F7 | **Weapon and upgrade hooks** (concern 6): each definition carries its behaviour (`onFire`, `onHit`, `onKill`, ...); combat code calls them generically. | the Armory or a second gun | |
| F8 | **Class interface**: one shared interface every Chosen implements; today's `AssaultClassService` becomes the first implementation. | the second playable Chosen | |
| F9 | **Save service**: one server module for per-player data (ProfileStore or similar: session locking, no data loss on crash), a version number in the save format from day one. | unlocks or the Containment Board | the board itself is below |
| F10 | **Lobby place** ([MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) decision 7) and split `Config` by domain so the lobby loads no match-only tuning. | after F9 | flow below |
| F11 | **One frame scheduler**: merge the per-system `Heartbeat` connections into one ordered step (concern 8). | when the MicroProfiler shows script time is the problem | measure first |

## Sessions and the shared war map (how the final product scales)

**Every squad gets its own server.** Each Roblox server is a separate machine with its own
Workspace, so a private server per squad is a private map, enemy set and run. One
experience holds both places and they share DataStores and MemoryStore.

1. **Lobby place.** Menu, war map, party up, loadout. Many parties share one lobby server.
2. **Reserve and teleport.** On ready, the lobby reserves a private server of the match place
   (`TeleportService:ReserveServer`, or `TeleportAsync` with `TeleportOptions`) and sends the
   party together; loadout and operation choice ride as teleport data.
3. **Match server.** Today's game. It builds its stage from code at start (an advantage:
   nothing carries between squads), runs one squad's operation, takes no strangers.
4. **Home.** At the end it saves results itself and teleports the squad back to the lobby.

Rules: teleports fail sometimes (retry; a match starts with whoever arrived); teleports do
not work in Studio (test in a published private copy); never trust teleport data for
progress. Matchmaking strangers across lobby servers needs a queue in MemoryStore that any
lobby server can read and pull four players from.

**The Containment Board.** [PROGRESSION.md](PROGRESSION.md) plans one DataStore key per
district written with `UpdateAsync` and read at run start and once a minute. Correct and
enough at launch. Its ceiling: one key accepts a write about every 6 seconds, so every squad
on one district queues behind one key; a few dozen concurrent squads are fine, a popular game
throttles. The fix when player counts call for it:
- match servers add contributions to a MemoryStore counter (far more throughput);
- one server holding a MemoryStore lock copies the totals into the DataStore every minute or so;
- MessagingService broadcasts board events ("Delta is Contained") to every running server.

Check the current DataStore, MemoryStore and MessagingService limits in the Roblox Creator
Documentation before building either version; they change.

Order: F9 and the board inside today's single place first, then F10. The match server then
only learns two things: read teleport data in one place (`RunManager`) and send the squad home.
