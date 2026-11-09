# Infected Co-op Shooter - plan: pillars, scope, roadmap

## Vision

A 4-player co-op shooter on Roblox in a grounded military bio-horror setting: Pike, four
anonymous soldiers, fly into fallen positions of the Harlan corridor, complete objectives,
kill the district's boss and extract. Helldivers 2 is the structure (loadout, call-ins,
missions, extraction), never its names, factions or look. Single-player with bots is the
current build target; every system is built for up to 4 players
([MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md)). Owner rules: [OWNER.md](OWNER.md).

Guiding rule (CLAUDE.md): the simplest solution that creates a playable game; playability >
stability > clean architecture > visual polish.

## Design pillars

Every design decision, by the team or by a subagent, is tested against these. If a feature
serves none of them it is cut; if two conflict, the earlier one wins.

1. **Always a reason to move.** Loot, a site, a log, a route up. Standing still is a choice
   the game punishes gently and never the best plan.
2. **Pressure is a clock the player can read.** Difficulty rises with time, never with a
   hidden trigger. The player decides when to commit (start the hold) and feels the cost
   of waiting.
3. **Every Infected form is one rule.** A new enemy teaches one thing at a glance (it
   throws, it bursts, it splits). Silhouette and behaviour match; no palette swaps.
4. **Loadouts create stories.** Guns, call-ins and field upgrades combine into missions the
   player can describe afterwards. A percentage is filler; a tool that changes how you play
   is content.
5. **Four players, one run.** Everything is per player or per run, scales by headcount, and
   reads the same on a low-end phone and a desktop.

## Out of scope (decided)

- Hero characters or classes: players are Pike soldiers (owner, 2026-11-08).
- Stat items, rarity, XP and levels: power is the loadout (owner, 2026-11-07).
- Sci-fi kit (drones, lasers, shock coils): call-ins are what a real army fields
  (owner, 2026-11-08).
- New missions before objective pools and the operation flow work on Delta (build order in
  [PROGRESSION.md](PROGRESSION.md)).
- Matchmaking strangers across lobby servers until player counts need it
  ([ARCHITECTURE.md](ARCHITECTURE.md)).

## Roadmap

The MVP sprints 1-7 (move, shoot, enemies, waves, XP, upgrades, polish) shipped and were later
replaced by the loadout spine; see [HISTORY.md](HISTORY.md).

1. **Content:** the build order in [PROGRESSION.md](PROGRESSION.md) > Build order (objective
   pools, the operation and the Burn, the Containment Board, Mile 14, Kestrel).
2. **Foundation:** the F6-F11 items in [ARCHITECTURE.md](ARCHITECTURE.md), each right before
   the feature that needs it.
3. **Co-op:** the lobby place and loadout screens (Nova), then private match servers
   ([MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) decision 7).
