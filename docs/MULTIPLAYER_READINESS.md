# Multiplayer readiness — 4-player co-op is the final product

Decided 2026-11-05. The shipped game is a **4-player co-op** roguelike (one shared run, one
server, up to 4 players). We are still building and balancing single-player first (that is
the fastest way to find the fun), but from now on **nothing new may assume one player**, and
the single-player shortcuts listed below are tracked debt with a planned fix, not accepted
design.

Audit source: a full read of `src/` on 2026-11-05 (line numbers are from that tree and will
drift; the file and symbol names are the stable pointers).

## The rule for all new code (also in CLAUDE.md)

- State is **per player** (keyed by `Player`, cleaned up on `PlayerRemoving`) or explicitly
  **per run** (one shared value, documented as such). Never "the player".
- Never `Players:GetPlayers()[1]`. Pass the `Player` in; iterate when it is really everyone.
- A per-player reset (`resetPlayer(player)`) touches only that player's state. A run reset
  (`reset()`) touches only run state. Mixing the two is a bug.
- Anything that pauses, ends, restarts, or awards must say *whom* it affects. Default to
  per player; broadcast (`FireAllClients`) only for things every client must see.
- Spawn/count/difficulty numbers take the live player count as an input (`Config` may hold a
  per-player term, default 1 player = today's values).
- Client UI reads only `LocalPlayer` state unless the value is run-wide by design (run timer,
  objective state).

## Already fine (keep it this way)

Per-player attributes (XP/Level/XPRequired, stat Mults, Kills, ItemsCollected,
MomentumStacks), per-player inventories and offers (`ItemService`), per-player fire-rate and
ability validation, per-player drone/rat caps, every `PlayerRemoving` handler, kill credit via
the one damage entry point `ItemEffectService.dealDamage`, enemy targeting = nearest living
player, HUDs reading `LocalPlayer` only.

## Debt register

Severity: **B** = blocks co-op (architecture change), **M** = per-player bookkeeping missing or
leaking, **C** = client assumption. "Fix when" says the sprint that must clear it; nothing new
may add to this list.

| # | Sev | Where | Problem today | Planned shape | Fix when |
|---|---|---|---|---|---|
| 1 | B | `RunManager` | Death ends the run; `RestartRun` from any dead/extracted player resets global services but only the requester's per-player state, and respawns only the requester. No "all dead" handling. | Run state machine owned by the server: `Lobby → Running → Ended`. Per-player `Alive / Downed / Dead` state. Run ends when every player is dead or extraction completes. Restart = vote or host, resets every player. | Co-op Sprint A |
| 2 | B | `PauseService`, `ItemService`, `AssaultClassService`, client `CameraController`/`WeaponController`/`AbilityController`/`AbilityUI` | One player's level-up pauses the whole world via a single global boolean; another player's pick unpauses it. | Decision pending (see Open design decisions #1). Either per-player "choosing" state with no world pause, or a ref-counted pause. Either way the flag becomes per-player data, not one bool. | Co-op Sprint A |
| 3 | B | `ObjectiveService`, `ExtractionService` | One zone, any single player inside counts, completion/pause broadcast to all. | Keep shared objective (co-op goal) but define the rule: N-of-players in zone, or any one. Extraction needs a "waiting for squad" state. | Co-op Sprint B |
| 4 | M | `XPOrbService`, `ObjectiveService` | Orb XP goes to the nearest player only; objective XP goes in full to everyone. Inconsistent. | Decision pending (#2). Likely shared XP: every orb pickup grants every living player. | Co-op Sprint A |
| 5 | M | `DifficultyService`, `EnemyService`, `Config` MaxAlive schedule | Nothing scales with player count; run clock ignores pause. | Add `PlayerCountScaling` to Config (HP, spawn rate, max-alive per extra player). Clock = accumulated unpaused time. | Co-op Sprint B |
| 6 | M | `EnemyService` spawn placement | Spawns around a random player without checking they are alive. | Pick from living players only. | Any sprint (small) |
| 7 | M | `AmmoCacheService` | Any player can take another player's crate. | Decide: owner-only or shared pickups (lean shared, co-op friendly). | Co-op Sprint B |
| 8 | M | `ItemEffectService.resetPlayer`, `AssaultClassService.resetPlayer`, `ProjectileServer.reset` | Per-player reset wipes humanoid-keyed/global tables; run reset clears per-player `shotCount` but not `lastFireTime`. | Split strictly per the rule above. | Co-op Sprint A |
| 9 | M | `ItemEffectService` damage/death events | Every hit and kill is `FireAllClients`; each client plays every player's hit sounds. | Hit numbers to the damager only; death VFX to all but sound distance-attenuated or owner-only. | Co-op Sprint B |
| 10 | M | `ArenaService` | One `SpawnLocation` at the origin. | 4 spawn pads in a cluster; respawn/revive at a teammate. | Co-op Sprint A |
| 11 | M | `DevTestService` | Falls back to `GetPlayers()[1]`; run-state printouts inspect one player. | Dev commands target the invoking player; printouts loop players. | Any sprint (small) |
| 12 | C | `DeathScreenUI` | Hardcodes "Extracted: No"; Restart button resets the server's run for everyone. | Death screen becomes a spectate/downed screen; final screen only on run end. | Co-op Sprint A |
| 13 | C | `MissionSuccessUI` | Shown to all, hidden only on the local `CharacterAdded`, so non-requesters keep it up after restart. | Hide on the run-state change event, not on respawn. | Co-op Sprint A |

## Open design decisions (need the owner's call before Co-op Sprint A)

1. **Level-up in co-op.** Options: (a) no world pause, the chooser keeps moving and picks from
   a non-blocking card row; (b) brief slow-mo for everyone; (c) choices bank up and are taken
   at a safe moment (end of wave / in the objective zone). Recommendation: (a), it is what
   co-op roguelikes converge on and it removes `PauseService` from gameplay entirely.
2. **XP sharing.** Options: shared (every orb gives all living players full XP) vs. individual
   (nearest player). Recommendation: shared. Keeps the squad level-aligned and removes
   orb-stealing.
3. **Death.** Options: (a) downed + revive by a teammate within a window, dead until next
   objective completes otherwise; (b) permanent death, spectate until run ends; (c) respawn
   at the objective. Recommendation: (a) with respawn-on-objective as the safety valve.
4. **Run ownership.** Who starts/restarts: host (first joiner), majority vote, or anyone.
   Recommendation: anyone can *request*, run starts after a short ready-up timer.
5. **Items.** Per-player inventories stay (already true). Decide whether world pickups
   (crates) are per-owner or shared. Recommendation: shared.
6. **Difficulty.** Per extra player: more enemies (spawn rate + cap), not more HP per enemy,
   so the game stays snappy. Numbers in `Config.PlayerCountScaling`.

## Sequencing

Single-player MVP balance (Sprint 13) stays first. Then **Co-op Sprint A** (run state machine,
per-player pause/choosing, death/downed, spawn pads, reset split, client screens) and
**Co-op Sprint B** (objective/extraction rules, difficulty scaling, shared pickups, event
routing). Both are designed with the `multiplayer_playtest` Studio MCP tool (2+ clients)
as the verification step; single-player must keep working throughout.
