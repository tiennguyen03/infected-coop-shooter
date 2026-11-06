# Roguelike Arena Survivor - MVP Plan

## Vision

Create a Roblox roguelike inspired by the progression loop and replayability of games like
Risk of Rain 2, but with original mechanics, characters, items, and progression systems.

The first version should focus on discovering the core fun loop as quickly as possible.

Do NOT build multiplayer *features* yet (lobby, voting, revive). But the final product is
**4-player co-op**, so every system is designed for up to 4 players from day one: state is per
player or explicitly per run, never "the player". Rules, debt register and open decisions:
[MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md).

Do NOT build multiple characters yet.

Do NOT build a large map yet.

Do NOT build complex item synergies yet.

The goal is to create the smallest possible playable game that proves the combat and
progression loop is fun.

---

# MVP Core Loop

Player spawns into arena. Player kills enemies. Enemies grant XP. Player levels up.
Player chooses 1 of 3 upgrades. Enemies continue spawning. Enemy difficulty scales over time.
Player survives as long as possible. Game ends on death. Player can start another run.

---

# Technical Constraints

## Architecture

- Use Rojo project structure.
- Use strict Luau when practical.
- Keep systems modular.
- Avoid large monolithic scripts.
- All gameplay values should be configurable through modules.

## Development Priority

Always prioritize:

1. Playability
2. Stability
3. Clean architecture
4. Visual polish

Never sacrifice gameplay progress for polish.

---

# Sprint 1 - Foundation

**Goal:** Create a playable character that can move and shoot.

### Player Controller
- Roblox third-person camera
- WASD movement
- Jump
- Sprint using Shift

### Weapon System
- Left click shoots projectile
- Projectile moves forward
- Projectile damages enemies
- Projectile despawns after duration

### Health System
- Player has health
- Damage can be applied
- Death state exists

**Acceptance Criteria:** Player can move, sprint, shoot. Projectile travels correctly and
damages enemies. Player can die.

---

# Sprint 2 - Enemy System

**Goal:** Create a basic enemy and combat loop.

### Enemy Type 1: Melee Blob
- Spawn, find nearest player, chase player, damage player on contact

### Enemy Health
- Enemy health, enemy death, enemy destruction

### Damage Feedback
- Floating damage numbers
- Enemy health bar

**Acceptance Criteria:** Enemy spawns, chases player, takes damage, dies. Player can kill
enemies. Combat loop feels functional.

---

# Sprint 3 - Wave Spawning

**Goal:** Create endless combat.

### Spawn Director
- Spawn enemies periodically, around player, prevent spawning too close

### Difficulty Scaling
- Every minute increase: enemy health, enemy damage, enemy spawn rate

### Timer
- Display run time

**Acceptance Criteria:** Game continues indefinitely. Enemies become more dangerous over time.

---

# Sprint 4 - XP System

**Goal:** Reward kills.

### XP Orbs
- Enemy death drops XP orb. Player walks near orb. Orb flies into player. XP granted.

### Level System
- XP bar, current level, level thresholds

**Acceptance Criteria:** Killing enemies increases XP. Player can level up.

---

# Sprint 5 - Upgrade Selection

**Goal:** Create the first roguelike progression system.

### On Level Up
- Pause gameplay. Show 3 upgrade choices. Player selects one. Resume gameplay.

### Initial Upgrades
- **Damage Up:** +10% damage
- **Health Up:** +20 max health
- **Fire Rate Up:** +10% attack speed

**Acceptance Criteria:** Player levels up, chooses 1 of 3 upgrades, stats update immediately.

---

# Sprint 6 - Run Progression

**Goal:** Create survival gameplay.

### Scaling
- Every minute increase: spawn budget, enemy health, enemy damage

### Run Stats
- Track: time survived, enemies killed, level reached

### Death Screen
- Display run stats + restart button

**Acceptance Criteria:** Run starts, progresses, ends, can restart.

---

# Sprint 7 - Polish Pass

**Goal:** Make MVP enjoyable.

### Effects
- Muzzle flash, hit particles, death particles

### UI
- Improve health bar, XP bar, upgrade menu

### Audio
- Shooting, hit, enemy death, level up sounds

**Acceptance Criteria:** Game feels responsive. Visual and audio feedback exists.

---

# MVP Success Criteria

The MVP is complete when:

- Player can survive indefinitely if skilled
- Enemy difficulty scales over time
- Leveling works
- Upgrades work
- Runs feel different depending on upgrade choices
- Death and restart work
- Core gameplay loop is fun for at least 10 minutes

---

# Future Milestones (After MVP)

Do NOT begin these until MVP is complete.

- **Character System:** multiple playable characters (commando-style shooter, shotgun,
  sniper, engineer). Character identities come from [LORE.md](LORE.md) ("The Chosen"):
  Mason Cole (K-9 handler), Dr. Elena Reyes (epidemiologist), Ava Cross (recon),
  Victor Kane (field engineer)
- **Item System:** replace simple stat upgrades with collectible items (chain lightning,
  crits, explosive bullets, drones, healing)
- **Elite Enemies:** stronger enemy variants
- **Boss System:** timed boss encounters
- **Stage Progression:** multiple maps, teleporters, biome progression
- **Co-op (the final product):** Co-op Sprint A (run state machine, per-player level-up,
  downed/revive, spawn pads) then Sprint B (squad objective rules, player-count difficulty,
  shared pickups). Plan: [MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md)

---

# Important Rule

Whenever making implementation decisions: choose the simplest solution that creates a
playable game. Do not over-engineer systems before they are needed.
