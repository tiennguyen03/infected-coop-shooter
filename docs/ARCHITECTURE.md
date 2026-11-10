# Architecture review and foundation backlog

From a code review with the owner (2026-11-08): what the codebase gets right, what will hurt
as the game grows to the scope in [PROGRESSION.md](PROGRESSION.md), and the foundation work in
priority order. Each item is one playtest-verified step. When an item ships, mark it done
here and add the HISTORY row.

## Keep doing

- **Server authority.** Every `OnServerEvent` handler checks argument types and the
  sender's state. Fire: type, rate (with jitter slack), origin within 10 studs of the root,
  a round in the magazine. Resupply pick: the card was offered to that player, they can
  act, they stand within `PickRadius`. Dev commands: Studio or the creator only.
- **One config, one remote list, one damage entry point** (`Config`, `Remotes`,
  `DamageService.dealDamage`), plus typed attribute and message names (`Attributes`,
  `Messages`).
- **Lifecycle hooks** (`Lifecycle.register`) instead of a hand-kept reset list; `Main` boots
  from one `BOOT` list and names a failing `init()`.
- **Strict Luau, StyLua, Selene, luau-lsp, Rojo, Lune tests for pure rules, CI on every push.**
- **Per-player state** keyed by `Player` and cleaned on `PlayerRemoving`.
- **Asset loading at boot is guarded** (`pcall` around `InsertService` in `MeshAssets`).
- **A branch per feature and a commit per working step**, merged to `main` by PR, so a
  regression can be bisected.

## Open concerns

1. **`ArenaService` is 2,379 lines mixing Delta's layout data with build logic.** Two more
   missions are next, and objective pools need per-mission site and landmark data. (F6)
2. **Upgrades are wired in by name.** Field upgrades are checked with `hasUpgrade(...)` at 8
   call sites across `ProjectileServer`, `LoadoutService`, `KitService` and `CallInService`.
   Guns and call-ins will be added, swapped and cut (Nova's loadout screens), so each new item
   would mean editing combat code. (F7)
3. **Frame cost in co-op.** The server runs 18 separate `Heartbeat`/render connections and
   the client 15. (F11, measure first)

Resolved 2026-11-08 by F1-F5: the hand-kept reset list, unchecked attribute and message
strings, all-or-nothing boot, naming drift after the loadout rework, no tests or CI, every
hit broadcast to every client.

## Foundation backlog

### Done (2026-11-08, [plan](superpowers/plans/2026-11-08-foundation-f1-f5.md))

| # | Item |
|---|---|
| F1 | Renames and comment cleanup (`ItemEffectService` → `DamageService`, `Config.Zombies` folded in, `wire.js` fixed) |
| F2 | Lifecycle hooks (`src/server/Lifecycle.luau`, `Main` `BOOT` list) |
| F3 | Shared state contract (`src/shared/Attributes.luau`, `src/shared/Messages.luau`; `luau-lsp analyze` in CI) |
| F4 | Open co-op debt: hold and extraction for N players, pause-proof clock, hits to the attacker only ([MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md)) |
| F5 | Safety net (`tests/`, `src/shared/Rules/`, `.github/workflows/ci.yml`) |

### Do right before the feature that needs it

| # | Item | Before | Notes |
|---|---|---|---|
| F6 | **Mission data split** (concern 1): a generic builder plus one data file per mission (`StageDefinitions`, PROGRESSION build order). | objective pools (next on the roadmap) | **Step 1 done 2026-11-09:** Delta's layout tables moved to `src/server/Missions/Delta.luau` (shapes in `Missions/MissionTypes`, registry `Missions`, order in `Config.Operation.Missions`); ArenaService builds `Missions.current()`. **Next:** Delta's bespoke builders and its Config positions (LZ, spawn pads, objective zone, Warden entry, sky) into the mission file, then a clearable mission model for the transition |
| F7 | **Weapon and upgrade hooks** (concern 2): each definition carries its behaviour (`onFire`, `onHit`, `onKill`, ...); combat code calls them generically. Also the support-weapon carry and the explosive projectile hook. | the support-weapon call-ins or the next new gun | |
| F9 | **Save service**: one server module for per-player data (ProfileStore or similar: session locking, no data loss on crash), a version number in the save format from day one. | unlocks or the Containment Board | the board itself is below |
| F10 | **Lobby place** ([MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) decision 7) and split `Config` by domain so the lobby loads no match-only tuning. | after F9 | lobby v1 built (Nova, `src/lobby/`) and the start place; teleports in and home per `docs/LOBBY_MATCH_HANDOFF.md`; it saves each signed Loadout (`LoadmasterService`, DataStore `LoadmasterLoadouts`, versioned) as a stand-in F9 should absorb; the `Config` split not started |
| F11 | **One frame scheduler**: merge the per-system `Heartbeat` connections into one ordered step (concern 3). | when the MicroProfiler shows script time is the problem | measure first |

Retired 2026-11-08: F8 (class interface for the Chosen); the class system is gone, see
[HISTORY.md](HISTORY.md).

## Sessions and the shared war map (how the final product scales)

**Every squad gets its own server.** Each Roblox server is a separate machine with its own
Workspace, so a private server per squad is a private map, enemy set and run. One
experience holds both places and they share DataStores and MemoryStore.

1. **Lobby place.** Menu, war map, party up, loadout. Many parties share one lobby server.
2. **Reserve and teleport.** On ready, the lobby reserves a private server of the match place
   (`TeleportService:ReserveServer`, or `TeleportAsync` with `TeleportOptions`) and sends the
   party together; loadout and operation choice ride as teleport data.
3. **Match server.** Today's game. It builds its mission from code at start (nothing carries
   between squads), runs one squad's operation, takes no strangers.
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
