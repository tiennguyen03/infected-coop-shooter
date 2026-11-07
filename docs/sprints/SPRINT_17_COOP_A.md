# Sprint 17 — Co-op Sprint A: squad members, run state machine, downed/revive, pads

**Status: in progress. Step 1 (run state machine) done and playtest-verified 2026-11-07. Step 3 started early for the bots: `Squad` exists (players + bots, Alive/Dead from the humanoid) and drives Infected targeting and enemy splash; the rest of step 3 (XP, objective/extraction zones, Requisition, spawn ring, dev loops) still uses `GetPlayers`.** Execute in order; each step is one
playtest-verified commit. Design decisions it implements: `docs/MULTIPLAYER_READINESS.md`
decisions 1-6 and register rows 1, 4, 6, 8, 10, 11, 12, 13; the spine in
`docs/PROGRESSION.md` (bot squadmates come next sprint on the `Squad` abstraction below).

## 1. `src/server/Squad.luau` — the one roster every system asks

```luau
export type MemberKind = "player" | "bot"
export type MemberState = "Alive" | "Downed" | "Dead" | "Extracted"
export type Member = {
	id: string, -- "p:<UserId>" | "b:<slot>", stable across respawns
	kind: MemberKind,
	owner: Player?, -- nil for bots
	name: string,
	padIndex: number, -- 1..4, lowest free slot on join
	character: Model?, humanoid: Humanoid?, root: BasePart?,
	state: MemberState,
	bleedOutAt: number?, -- os.clock, Downed only
	reviver: Member?, -- who is holding the revive
	revivesUsed: number,
	ready: boolean, -- ready-up vote (players only)
}
```

- **API.** Queries `members()`, `living()` (Alive), `active()` (Alive or Downed), `roots()`,
  `owners()`, `livingOwners()`, `fromPlayer`, `fromCharacter`, `fromHumanoid`,
  `nearestLiving(position): (Member?, number)`, `forEach`, `canAct(member)` (Alive, not
  paused). Transitions `down`, `kill`, `revive(member, by)`, `extract`, `resetMember`.
  Listener arrays (`onStateChanged(fn(member, old, new))`, `onMemberAdded`,
  `onMemberRemoved`), same pattern as `ObjectiveService.onComplete`; never BindableEvent
  (deep-copies tables, breaks Member identity).
- **Per-owner stays per-owner.** Inventory, items, class, XP/Level, stat mults,
  `IncomingDamageMult`, `OrbMagnetMult` stay attributes/tables on the Player.
  `ownerAttribute(member, name, default)` reads them or returns the default for a bot.
  Squad itself owns only downed/bleed-out/revive bookkeeping, pad slot, ready vote.
- **Spawning.** `bindCharacter(member, model)` (sets character/humanoid/root, connects
  `Died` → `kill` as the safety net), `spawnMember` (player: `LoadCharacterAsync`, pivot to
  `ArenaService.getSpawnPad(padIndex)`; bot: next sprint clones a rig into the same bind
  path), `spawnAll()`. `addBot(slot, model)` is the reserved entry. A late joiner spawns
  Alive at a free pad.
- **Replication.** Attributes `SquadState`, `BleedOutAt`, `Reviver` on the character model
  (bots included), mirrored on the Player so client UI reads `LocalPlayer` only.
- **Downed.** `Health = Config.Downed.DownedHealth`, `WalkSpeed/JumpPower = 0`,
  `PlatformStand = true`, rifle stays. Squad's Heartbeat steps bleed-out; expiry → `kill`
  (Health 0 → `Died` → death clip). `revivesUsed >= MaxRevives` turns `down` into `kill`.
- **Revive.** `ProximityPrompt` ("HOLD E — REVIVE", `HoldDuration = Config.Downed.ReviveHold`,
  `MaxActivationDistance = ReviveRadius`) on the downed root; hold began/ended set
  `reviver`; `Triggered` re-checks distance → `revive` (Health = MaxHealth ×
  `ReviveHealthFraction`, stand up). Bots call `Squad.revive` directly.
- Requires only Config/Remotes/Players/ArenaService, so any service can require it without
  a cycle. `Squad.init()` in `Main.server.luau` after ArenaService, before PlayerSetup.

## 2. Run state machine (`RunManager`)

`src/shared/RunStates.luau`: `Lobby | Insert | Explore | Primary | Index | Extract | Ended`,
`LIVE = {Explore, Primary, Index, Extract}`, `current()` / `isLive()` from
`workspace:GetAttribute("RunState")`. Shared so services and clients read it without
requiring RunManager (RunManager requires services, never the reverse). Workspace attributes
`RunState`, `RunResult` ("" | "Extracted" | "Wiped"; replaces `Extracted`),
`ReadyUpEndsAt` (0 = none).

- Boot → Lobby. The first character spawning opens the countdown (`Config.Run.ReadyUpSeconds
  10`) so solo still just starts. `RestartRun` remote = "ready": in Lobby/Ended opens the
  countdown if none and marks the member ready; all ready or expiry → `startRun()`.
- `startRun()` → Insert: run resets (Enemy, EnemyProjectile, XPOrb, Drone, Projectile,
  AmmoCache, Incendiary, Mine, ShockCoil, PlagueRat, Requisition, ItemEffect.reset,
  AssaultClass.reset, Objective, Extraction), then `resetPlayer(owner)` for every
  `Squad.owners()` (AssaultClass, ItemEffect, Item, PassiveItem, XP, PlayerStats,
  ProjectileServer), `Squad.resetMember` + `spawnAll()`, `PauseService.setPaused(false)`,
  `DifficultyService.restart()`. After `Config.Run.InsertSeconds 3` → Explore:
  `EnemyService.startSortie()` (initial wave leaves `reset()`), `ObjectiveService.arm()`
  (the 180 s timer leaves `reset()`/`init()`).
- Explore → Primary on a new `ObjectiveService.onActivated`; Primary → Index → Extract on
  `ObjectiveService.onComplete` (RunManager calls `ExtractionService.start()`; remove
  ExtractionService's own subscription). Index is a passthrough until the Warden.
- Extract → Ended/Extracted on a new `ExtractionService.onComplete`. `endRun(result)`: active
  members → Extracted, `PauseService.setPaused(true)` (its only remaining use),
  `EnemyService.clearAll()`, attributes set. Any live state → Ended/Wiped when
  `#Squad.active() == 0` (on state change and member removal).
- `EnemyService.spawnLoop` and the objective heartbeat gate on `RunStates.isLive()`.
  `RunManager.startRun()` is public for dev tools. `MissionSuccess` remote removed; clients
  key on the attributes.

## 3. Downed / revive (decision #3)

`Config.Downed = { BleedOutSeconds 30, ReviveHold 3, ReviveRadius 8, ReviveHealthFraction
0.5, DownedHealth 1, MaxRevives 2 }`, `Config.Run = { ReadyUpSeconds, InsertSeconds,
SpawnPads }`.

- `EnemyProjectileService.damagePlayer`: `member = Squad.fromHumanoid(humanoid)`; return
  unless `member.state == "Alive"` (downed bodies take no damage; bots are damaged the same
  way); `incomingMult = Squad.ownerAttribute(member, "IncomingDamageMult", 1)`; if the hit
  would reach 0 → `Squad.down(member)` else `TakeDamage`. `livePlayerHumanoids()` →
  `Squad.living()` (splash, puddles).
- Targeting: `nearestPlayerRoot` → `Squad.nearestLiving(position)`. **Downed members are
  not targets** (a rescue, not a snack; the pressure is the timer and the reviver not
  shooting). All downed → Infected idle until bleed-out wipes the squad, which is correct.
- Act gates: `ProjectileServer.onFireRequest`, `AssaultClassService.canAct`,
  `RequisitionService.onFlare` use `Squad.canAct`. Client `AbilityController` suppresses
  breach aim while a revive prompt is shown (`ProximityPromptService.PromptShown/Hidden`).
- Client: `DeathScreenUI` repurposed. Downed: bleed-out countdown from `BleedOutAt`, "<name>
  reviving" from `Reviver`. Dead: small "K.I.A. — spectating" banner (camera follows the
  nearest living member; optional polish). Results screen only on `RunState == Ended`, with
  READY + the `ReadyUpEndsAt` countdown, hidden when the state leaves Ended.
  `MissionSuccessUI` shows on Ended + Extracted, hides on the attribute change; both drop
  their `CharacterAdded` hooks. Respawn at the next stage start is a no-op this sprint.

## 4. Spawn pads

`ArenaService`: remove the `SpawnLocation`; `buildHelipad` adds four invisible anchored
`SpawnPad1..4` at `Config.Run.SpawnPads` offsets around the H (e.g. `(±9, 0, ±9)` from
`Config.Extraction.ZonePosition`); `ArenaService.getSpawnPad(index): CFrame`.
`member.padIndex` = lowest free slot; `Squad.spawnMember` pivots the fresh character there
(`CharacterAutoLoads` stays false).

## 5. Reset split (register #8)

- `ItemEffectService`: new `reset()` clears `bleeds`, `lastDamager`, `lastDamageKind`
  (enemy-keyed run state); `resetPlayer` keeps `adrenalineApplied`, `killsTowardStrike`,
  `killsTowardHeal`, `kevlarShield`, `nextMarkAt`, `clearMark`, `Kills`.
- `AssaultClassService`: new `reset()` clears `chargeFolder`; `resetPlayer` keeps momentum,
  cooldowns, `MomentumStacks`, `setBonus`.
- `ProjectileServer`: new `resetPlayer(player)` clears `shotCount` and `lastFireTime`;
  `reset()` keeps projectiles + folder sweep.
- `XPOrbService`: magnet → `Squad.nearestLiving`; collection grants `XPService.addXP` to
  every `Squad.livingOwners()` (#4), listeners fire once. `ObjectiveService` /
  `ExtractionService.isAnyPlayerInZone` iterate `Squad.living()`.
  `RequisitionService.livingPlayers` → `Squad.livingOwners()`.
  `EnemyService.randomSpawnPosition` picks from `Squad.living()` (#6). `GroundUtil` keeps
  `GetPlayers` for its ignore list; its humanoid-model loop already covers bots.

## 6. DevTestService (#11)

Delete `firstPlayer`; `player` required on `giveXP/forceLevelUp/grantItem/clearItems/
killPlayer`. `KillPlayer` → `Squad.kill`; add `DownPlayer`, `RevivePlayer`, `StartRun`,
`EndRun`. `RestartRun` → `RunManager.startRun()`. `printRunState` prints
`RunState/RunResult` and loops `Squad.members()`; `verifyCleanup` loops `Squad.owners()`
and checks `RunResult`.

## 7. Steps (each: static checks, Stop → Play, verify, commit with docs)

1. **Done 2026-11-07.** `RunStates` + `RunManager` attributes over the existing flow;
   objective/extraction subscriptions move into RunManager (`ObjectiveService.onActivated` /
   `arm()`, `ExtractionService.onComplete`); `MissionSuccess` removed; first wave and the
   objective timer start on Explore (`EnemyService.startSortie`), spawns gate on
   `RunStates.isLive()`; all players dead → Ended/Wiped. Verified solo: Lobby → Insert →
   Explore (3.0 s) → Primary (zone at 180 s) → Index → Extract → Ended/Extracted, success
   screen shows and clears on restart, no enemies during Insert, KillPlayer → Ended/Wiped,
   `VerifyCleanup` PASS.
2. **Done 2026-11-07.** ItemEffectService/AssaultClassService gained run-level reset(); ProjectileServer.resetPlayer; RunManager.startRun resets every service once and every player, respawns all; RESTART only honoured once the run is Ended. Verified solo: restart refused mid-run, items/level/kills back to zero, bots rebuilt, VerifyCleanup PASS. Reset split. Verify solo: `RestartRun` then `VerifyCleanup` PASS; `GrantItem
   shrapnel_magazine` burst count restarts after a restart.
3. **Done 2026-11-07.** Squad (players + bots) now drives Infected targeting, enemy splash, XP orbs (nearest living member collects, every living player gets the XP), the objective and extraction zones, Requisition offers, the spawn ring and the wipe check (players only). Verified with multiplayer_playtest, 2 clients: 2 bots instead of 3, identical shared XP, P1 dead -> run continues, no Infected on the body, dead P1 earns no XP while P2 gets 90, P2 dead -> Ended/Wiped, RESTART from client-2 respawns both. `Squad` (players only, Alive/Dead via `Died`) replacing every `GetPlayers` target /
   placement / XP / zone site; DevTestService member loops. Verify with
   `multiplayer_playtest`, 2 clients: Infected chase the nearest living; `KillPlayer` on
   client-1 → they switch to client-2; orbs grant XP to both (`Level` attributes); spawns
   ring only the living.
4. **Done 2026-11-07.** Four invisible SpawnLocations SpawnPad1..4 on the LZ at Config.Run.SpawnPads; Squad.padFor hands each member the lowest free slot and points the player's RespawnLocation at it (a server PivotTo after spawn was overridden by the client, so the engine places them); bots land on the remaining pads at run start. Verified with 2 clients: Player1 lands at (-9,-9), Player2 at (9,9) from the LZ, RESTART from either respawns both on their pads. Spawn pads + `spawnAll` + start resets every member. Verify 2 clients land on different
   pads; `RestartRun` from either respawns both with clean attributes.
5. Run end + ready-up + client screens on `RunState`. Verify: kill client-1 → no screen on
   client-2; kill both → Ended, both see K.I.A.; one READY → countdown → both respawn;
   `ForceMissionSuccess` → both see OPERATION COMPLETE, both screens clear on restart
   (closes #12, #13).
6. Downed/revive. Verify solo: `DownPlayer` → overlay timer → Dead → Ended; 2 clients:
   client-2 holds E within 8 studs → client-1 up at 50% HP, Infected ignored the downed
   body meanwhile; `MaxRevives` exhausted → straight to Dead.
7. Docs: this file's status, HISTORY row, handoff state, register rows closed.

## Judgment calls (owner)

- **Lobby place (owner, 2026-11-07, `docs/MULTIPLAYER_READINESS.md` decision 7).** The
  match's `Lobby` state is staging for a party that will arrive by teleport; the ready-up
  in section 2 is the in-match fallback. Read any expected party from teleport data in
  `RunManager` only; never assume who is coming.
- **Decided (owner, 2026-11-07): revive and other interactions go on F.** F throws the
  Resupply flare today, so the flare moves (G, or a call-in slot when the loadout rework
  lands). E stays breach only; the prompt-suppresses-breach rule in section 3 is dropped.
- The ready-up opens automatically on the first join so solo stays frictionless.
- Spectate camera scope (follow nearest living member, or stay free).
- Extraction. **Recommended, owner to confirm:** the Helldivers 2 / Deep Rock model. The
  operation succeeds if at least one member is on the pad when Lantern lifts; members on
  the pad are Extracted, everyone else is Left Behind. Left Behind costs that player only
  (carried samples/intel, reduced share) once meta progression exists. This sprint:
  success if anyone extracts, per-member Extracted / Left Behind state, no reward effect yet.
- Seam left for the bot sprint: `ItemEffectService.dealDamage(attacker: Player, …)` and
  `lastDamager` are Player-keyed; bot kills need `attacker: Member`. Nothing in A blocks it.

## Register rows that close

1 (run state machine, all-dead, ready-up), 4 (shared XP), 6 (spawn placement from the
living), 8 (reset split), 10 (pads), 11 (dev tools), 12 (downed overlay / final screen on
run end), 13 (success screen on state change). 3, 5, 7, 9 stay Sprint B.
