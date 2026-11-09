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

Per-player attributes (MoveSpeedMult, Kills, Weapon/Primary/Secondary, Mag/Reserve/
ReloadUntil/SwapUntil, Grenade/Grenades/Stims, CallIn1-4 + charges, Upgrade<Slot>, Shield,
Callsign), per-player loadouts, Arms Room picks (kept across runs), calm timers and card
offers (`LoadoutService`, `CallInService`, `RequisitionService`), per-player fire-rate,
kit (`KitService`: grenade gap, shove cooldown, stim) and Arms Room gate validation,
callsigns handed out per player in join order (Pike One to Four; bots take the free ones at
run start, `Squad.freeCallsigns`), per-player drone/mine/pool caps, every `PlayerRemoving` handler, kill credit via
the one damage entry point `DamageService.dealDamage`, enemy targeting = nearest living
member, HUDs reading `LocalPlayer` only.

## Debt register

Severity: **B** = blocks co-op (architecture change), **M** = per-player bookkeeping missing or
leaking, **C** = client assumption. "Fix when" says the sprint that must clear it; nothing new
may add to this list.

| # | Sev | Where | Problem today | Planned shape | Fix when |
|---|---|---|---|---|---|
| 1 | B | `RunManager` | Death ends the run; `RestartRun` from any dead/extracted player resets global services but only the requester's per-player state, and respawns only the requester. No "all dead" handling. | Run state machine owned by the server: `Lobby → Running → Ended`. Per-player `Alive / Downed / Dead` (#3). Run ends when every player is dead or extraction completes. Start/restart = request + ready-up timer (#4), resets every player. | Done 2026-11-07 (Sprint A step 5) |
| 2 | B | `PauseService`, `ItemService`, `AssaultClassService`, client `CameraController`/`WeaponController`/`AbilityController`/`AbilityUI` | ~~One player's level-up pauses the whole world.~~ Done 2026-11-07: level-up no longer pauses; the draft is a world pallet (Resupply). `GamePaused` remains only for the run-end freeze. | Decided (#1), shipped as Resupply. | Done |
| 3 | B | `ObjectiveService`, `ExtractionService` | One zone, any single player inside counts, completion/pause broadcast to all. | Hold: any living member (player or bot) in the zone runs it; the HUD shows `n / living` players in. Extraction: runs only while every living player is on the pad (downed players and bots do not hold it up); some on it shows "WAITING FOR SQUAD (n / m)" (`ExtractionUpdate` `waiting`). One helper, `Squad.zoneCount`. | Done 2026-11-08 (foundation F4, 2-client verified) |
| 4 | M | ~~`XPOrbService`, `ObjectiveService`~~ | ~~Orb XP goes to the nearest player only; objective XP goes in full to everyone.~~ Superseded 2026-11-07 by the loadout rework: no orbs, no levels; every kill credits its `SupplyValue` to the shared Resupply pool at any distance. | n/a | Superseded (Sprint 18) |
| 5 | M | `DifficultyService`, `EnemyService`, `Config` MaxAlive schedule | ~~Nothing scales with player count;~~ run clock ignores pause. | Decided (#6): `Config.PlayerCountScaling` scales spawn rate, max-alive and heavy caps per living player, not HP/damage (done 2026-11-07, Sprint 18). Clock = accumulated unpaused time: `DifficultyService.getElapsed` adds time only while the field is not paused (the HUD timer stays wall-clock). | Done 2026-11-08 (foundation F4) |
| 6 | M | `EnemyService` spawn placement | Spawns around a random player without checking they are alive. | Pick from living players only. | Done 2026-11-07 (Sprint A step 3) |
| 7 | M | ~~`AmmoCacheService`~~ | ~~Any player can take another player's crate.~~ Superseded 2026-11-07: `AmmoCacheService` deleted; the pallet re-arms every living player within `Requisition.RearmRadius` once each (loadout rework). | n/a | Superseded (Sprint 18) |
| 8 | M | `DamageService.resetPlayer`, `AssaultClassService.resetPlayer`, `ProjectileServer.reset` | Per-player reset wipes humanoid-keyed/global tables; run reset clears per-player `shotCount` but not `lastFireTime`. | Split strictly per the rule above. | Done 2026-11-07 (Sprint A step 2) |
| 9 | M | `DamageService` damage/death events | Every hit and kill is `FireAllClients`; each client plays every player's hit sounds. | Hits (`DamageDealt`) go to the attacking player only (marker, spark, hit sound); a bot's hit to nobody; kills to everyone (the death burst; the death cry is the body's own 3D sound). | Done 2026-11-08 (foundation F4, 2-client verified) |
| 10 | M | `ArenaService` | One `SpawnLocation` at the origin. | 4 spawn pads in a cluster; revive happens in place, stage-start respawn at the pads. | Done 2026-11-07 (Sprint A step 4) |
| 11 | M | `DevTestService` | Falls back to `GetPlayers()[1]`; run-state printouts inspect one player. | Dev commands target the invoking player; printouts loop players. | Done 2026-11-07 (Sprint A step 7) |
| 12 | C | `DeathScreenUI` | Hardcodes "Extracted: No"; Restart button resets the server's run for everyone. | Downed overlay (timer, "teammate reviving"), spectate on Dead, final screen only on run end. | Done 2026-11-07 (Sprint A step 6) |
| 13 | C | `MissionSuccessUI` | ~~Shown to all, hidden only on the local `CharacterAdded`.~~ Done 2026-11-07 (Sprint A step 1): shown and hidden on `RunState`/`RunResult`. | Hide on the run-state change event, not on respawn. | Done |

## Design decisions (decided by the owner 2026-11-05)

1. **Level-up in co-op: no world pause.** Superseded 2026-11-06 by Resupply
   ([PROGRESSION.md](PROGRESSION.md)): the draft moves into the world (pallet with personal
   cards, one pick per player), levels become automatic growth. `PauseService` leaves
   gameplay entirely (extraction/success can keep a run-end freeze).
2. **XP is shared.** Superseded 2026-11-07 by the loadout rework
   ([PROGRESSION.md](PROGRESSION.md) > Loadout, pallets and field upgrades): there is no XP
   and no level. Every kill credits its `SupplyValue` to the squad's one Resupply pool at
   any distance; the pool is the only in-run resource and it is shared.
3. **Death: downed, revivable, respawn at the start of the next stage.** A player at 0 HP
   drops to a *Downed* state with a bleed-out timer; a teammate standing next to them for a
   short hold revives them. Owner's concern: late game, a downed player just gets eaten.
   Claude's call to cover it: **the Infected ignore downed players and downed players take no
   damage** (they are a rescue target, not a snack), the pressure is the timer and the
   teammate having to stop shooting. If the timer runs out the player is *Dead* and spectates;
   dead players **respawn when the next stage starts**, not when an objective completes.
   Until stage progression exists (post-MVP), a run is one stage, so dead = spectate to run
   end and revive is the only recovery. Numbers (bleed-out seconds, revive hold, max revives)
   in `Config.Downed`.
4. **Run ownership: anyone can request, short ready-up timer.** The first request opens a
   countdown; the run starts when it expires or everyone readies. Restart after a run ends
   works the same way.
5. **Items are per owner.** Inventories stay per player (already true). World pickups
   (ammo crates, future class drops) are **owner-only**: only the player whose item spawned it
   can collect it. Reason: future classes should have distinct, self-built kits. Resupply
   pallets and stores are the exception by design: a shared trigger, personal cards.
6. **Difficulty per extra player: more Infected, not tougher Infected.** Spawn rate and
   max-alive scale with living player count; HP/damage per Infected do not. Numbers in
   `Config.PlayerCountScaling`, with 1 player = today's values. **Exception (2026-11-07):**
   an Index host is one body, so its body and plate health scale
   (`Config.Index.Warden.HealthPerExtraPlayer`, 0.33 per extra living player at spawn) and
   its Riot Call adds Walkers per extra player.
7. **A lobby place with a main menu; the party teleports into a private match (owner,
   2026-11-07).** Players land in a separate lobby place: main menu, party up (invite or
   matchmade squad of up to 4), pick class and loadout, ready. The party is teleported
   together (`TeleportService:TeleportAsync` to a reserved server) into the match place,
   which is today's game. Rules that keep this cheap later:
   - **The match server never assumes who is coming.** The expected party, each member's
     class and loadout, and the squad's operation choice arrive as teleport data
     (`player:GetJoinData().TeleportData`), read in one place (`RunManager`), with a
     Studio/solo fallback to today's defaults. Late joiners and missing players are normal.
   - **`Lobby` state in the match = staging, not the menu.** It waits for the party to load
     (or a timeout), then the ready-up/Insert flow runs. The menu itself lives only in the
     lobby place.
   - **A run ends by returning the party to the lobby** (`TeleportAsync` back with results
     as teleport data) once meta progression exists; until then RESTART stays in-match.
   - **Persistent progress (unlocks, Containment Board) is saved by the server that earns
     it** (DataStore, keyed by UserId), never trusted from teleport data.
   - **Disk layout:** a second Rojo project (`lobby.project.json`) sharing `src/shared`; its
     own `src/lobby/` client and server. v1 built 2026-11-09, not playtested: the Fallow,
     launch by boarding a Lantern spot (docs/sprints/LOBBY_V1_FALLOW.md). The match does not
     read the teleport data yet.
8. **Keys (owner, 2026-11-07).** F = interact (revive, pickups, prompts). The number row
   1-4 is free: call-in slots and the Resupply flare move there with the loadout rework
   (proposal: 1-2 call-ins, 3 flare, 4 spare). Movement chords are under review (handoff
   backlog: sprint-by-default).

## Sequencing

All eight decisions are made. Decision 7 (lobby place) is built after Co-op Sprint A; Sprint A only has to honour its rules (party arrives as teleport data, `Lobby` is staging). Single-player MVP
balance (Sprint 13) is still the recommended first step. **Co-op Sprint A** (run state machine,
per-player pause/choosing, death/downed, spawn pads, reset split, client screens) and
**Co-op Sprint B** (objective/extraction rules, difficulty scaling, shared pickups, event
routing). Both are designed with the `multiplayer_playtest` Studio MCP tool (2+ clients)
as the verification step; single-player must keep working throughout.

## Addendum 2026-11-07: knockdown

The Warden's Pound and Stomp knock bodies down (`Squad.knock`). The state is an attribute
on each character (`KnockedUntil`, `KnockGraceUntil`), the clips play on that client
(`Impact "knockdown"` to the owner) and bots read the attribute: nothing is keyed to one
player. A Pound that catches all four is 30 each and 2.4 s down with him stuck for 2.6 s
and the next pick never a knockdown; the Riot Call adds are what bites a downed squad.
