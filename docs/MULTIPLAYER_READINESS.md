# Multiplayer readiness — 4-player co-op is the final product

Decided 2026-11-05. The shipped game is **4-player co-op** (one shared run, one server, up to
4 players). We build and balance single-player with bots first, but **nothing new may assume
one player**; any single-player shortcut goes in the debt register below with a planned fix.

## The rule for all new code (summary in CLAUDE.md)

- State is **per player** (keyed by `Player`, cleaned up on `PlayerRemoving`) or explicitly
  **per run** (one shared value, documented as such). Never "the player".
- Never `Players:GetPlayers()[1]`. Pass the `Player` in; iterate when it is really everyone.
- A service registers its hooks with `Lifecycle.register`: `onPlayerReset` touches only that
  player's state, `onRunStart` only run state. Mixing the two is a bug.
- Anything that pauses, ends, restarts, or awards must say *whom* it affects. Default to
  per player; broadcast (`FireAllClients`) only for things every client must see.
- Spawn/count/difficulty numbers take the live player count as an input (`Config` holds a
  per-player term; 1 player = the solo values).
- Client UI reads only `LocalPlayer` state unless the value is run-wide by design (run timer,
  objective state).

## Already fine (keep it this way)

Per-player attributes (Kills, Weapon/Primary/Secondary, Mag/Reserve/ReloadUntil/SwapUntil,
Grenade/Grenades/Stims, CallIn1-4 + charges, Upgrade<Slot>, Shield, Callsign), per-player
loadouts and Arms Room picks (kept across runs), calm timers and card offers
(`LoadoutService`, `CallInService`, `RequisitionService`), per-player fire rate, kit
(`KitService`: grenade gap, shove cooldown, stim), callsigns handed out in join order (Pike
One to Four; bots take the free ones at run start, `Squad.freeCallsigns`), per-player
mine, sentry and wire caps, every `PlayerRemoving` handler, kill credit via
`DamageService.dealDamage`, enemy targeting = nearest living member, HUDs reading
`LocalPlayer` only.

## Co-op rules in force

- **Run flow:** the server owns `Lobby → Insert → Explore → Primary → Index → Extract → Ended`
  (`RunStates`); per member `Alive / Downed / Dead`. The run ends when every member is dead
  or extraction completes; start and restart use the ready-up (decision 4) and reset every
  player. Run-end screens follow `RunState` / `RunResult`, not respawn.
- **Hold:** any living member (player or bot) in the zone runs it; the HUD shows `n / living`.
- **Extraction:** runs only while every living player is on the pad (downed players and bots
  do not hold it up); otherwise "WAITING FOR SQUAD (n / m)". One helper, `Squad.zoneCount`.
- **Hits:** `DamageDealt` goes to the attacking player only; a bot's hit to nobody; kills to
  everyone.
- **Clock:** `DifficultyService.getElapsed` adds time only while the field is not paused
  (the HUD timer stays wall-clock). `GamePaused` is only the run-end freeze.
- **Spawns:** the Infected spawn around living players only; four spawn pads, one per member.
- **Dev commands** target the invoking player.
- **Knockdown** (the Warden's Pound and Stomp, `Squad.knock`): `KnockedUntil` /
  `KnockGraceUntil` on each character, clips on that client, bots read the attribute.

## Debt register

Open: none. The 13 items of the 2026-11-05 audit are fixed (Co-op Sprint A,
[SPRINT_17_COOP_A.md](sprints/SPRINT_17_COOP_A.md); foundation F4) or superseded by the
loadout rework ([SPRINT_18_LOADOUT.md](sprints/SPRINT_18_LOADOUT.md)); see
[HISTORY.md](HISTORY.md). New single-player shortcuts are not allowed; if one is unavoidable,
add a row: `# | Sev (B blocks co-op, M per-player bookkeeping, C client) | Where | Problem |
Planned shape | Fix when`.

## Design decisions (owner, 2026-11-05 unless dated)

1. **Level-up in co-op.** Retired 2026-11-07 with XP and levels; see HISTORY.md.
2. **XP is shared.** Retired 2026-11-07: every kill credits its `SupplyValue` to the squad's
   one shared Resupply pool at any distance ([PROGRESSION.md](PROGRESSION.md) > Pallets).
3. **Death: downed, revivable, respawn at the start of the next mission.** At 0 HP a member
   is *Downed*: bleed-out timer, the Infected ignore them and they take no damage (a rescue
   target, not a snack); the pressure is the timer and the teammate having to stop shooting.
   A teammate holds F next to them to revive (bots revive on their own). Timer out = *Dead*,
   spectate; the dead respawn when the next mission starts. Until missions chain, dead =
   spectate to run end. Numbers in `Config.Downed` (max revives per run included).
4. **Run ownership: anyone can request, short ready-up timer.** The first request opens a
   countdown; the run starts when it expires or everyone readies. Restart works the same way.
5. **Items are per owner.** Inventories stay per player. A world pickup that a player's own
   kit spawns is owner-only. Resupply pallets, stores and the supply call-ins (Speedball, Aid
   Bag) are shared by design: a shared trigger, personal effects.
6. **Difficulty per extra player: more Infected, not tougher Infected.** Spawn rate,
   max-alive and heavy caps scale with living player count (`Config.PlayerCountScaling`);
   HP/damage per Infected do not. **Exception (2026-11-07):** an Index host is one body, so
   its body and plate health scale (`Config.Index.Warden.HealthPerExtraPlayer`, 0.33 per extra
   living player at spawn) and its Riot Call adds Walkers per extra player.
7. **A lobby place with a main menu; the party teleports into a private match (2026-11-07).**
   Players land in a lobby place: main menu, party up (invite or matchmade squad of up to 4),
   pick a loadout, ready. The party is teleported together (`TeleportService:TeleportAsync`
   to a reserved server) into the match place, which is today's game. Nova is building the
   lobby and loadout screens. Rules that keep this cheap:
   - **The match server never assumes who is coming.** The expected party, each member's
     loadout and the squad's operation choice arrive as teleport data
     (`player:GetJoinData().TeleportData`), read in one place (`RunManager`), with a
     Studio/solo fallback to the defaults. Late joiners and missing players are normal.
   - **`Lobby` state in the match = staging, not the menu.** It waits for the party to load
     (or a timeout), then the ready-up/Insert flow runs.
   - **A run ends by returning the party to the lobby** (teleport back with results) once
     meta progression exists; until then RESTART stays in-match.
   - **Persistent progress (unlocks, Containment Board) is saved by the server that earns
     it** (DataStore, keyed by UserId), never trusted from teleport data.
   - **Disk layout:** a second Rojo project (`lobby.project.json`) sharing `src/shared`, with
     its own `src/lobby/` client and server.
   Server flow and scaling: [ARCHITECTURE.md](ARCHITECTURE.md) > Sessions.
8. **Keys (2026-11-07, updated 2026-11-08).** F = interact (revive, pickups, prompts); 1-4
   call-ins, 5 the Resupply flare. Movement chords are undecided; do not change them without
   the owner ([OWNER.md](OWNER.md)).

Verification for co-op work: the `multiplayer_playtest` Studio MCP tool (2+ clients);
single-player must keep working throughout.
