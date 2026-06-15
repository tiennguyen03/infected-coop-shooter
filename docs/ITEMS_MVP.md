# ITEMS_MVP.md

# MVP Item Trial Pack

This document defines the first 5 sample items for the game.

These items are intended to be the first real test of the run-building system.

The goal is NOT to create a full item catalog yet.

The goal is to test whether picking items on level-up makes runs feel exciting, memorable, and different from one another.

For now, items are awarded only through the level-up selection screen.

Do NOT implement chest drops, world pickups, vendors, or rarity systems yet unless explicitly requested.

---

# Design Goals

These first 5 items should:

- Be easy to understand
- Be exciting to receive
- Be mechanically distinct
- Encourage different playstyles
- Be simple enough to implement in the MVP
- Stack in a clean and predictable way

At least some of these items should create visible gameplay moments the player can notice immediately.

Avoid boring items like:

- +5 damage
- +10 HP
- +3% crit

Those can exist later, but they should not define the first impression of the item system.

---

# Item Presentation Rules

Each item should have:

- Id
- Name
- Short description
- Icon placeholder
- Stack count
- One gameplay effect
- Clear stacking behavior

Suggested data structure:

```lua
{
    Id = "hollow_point_rounds",
    Name = "Hollow Point Rounds",
    Description = "Shots have a chance to inflict Bleed.",
    MaxStacks = nil,
}
```

Use one centralized item definitions module.

Do NOT hardcode item logic inside UI scripts.

---

# The First 5 Sample Items

## 1. Hollow Point Rounds

### Theme

Modified ammunition designed to tear through infected tissue.

### Effect

Each projectile hit has a 15% chance to apply Bleed for 3 seconds.

Bleed deals damage over time once per second.

### Suggested Numbers

- Proc chance per stack: +15%
- Bleed duration: 3 seconds
- Bleed tick damage: 4 damage per second

### Stacking

Each stack adds +15% bleed chance.

Example:

- 1 stack = 15%
- 2 stacks = 30%
- 3 stacks = 45%

Optional later:

Additional stacks may increase bleed damage, but do NOT do that in MVP V1.

### Why this is good

- Easy to understand
- Works with every gun
- Gives visible combat feedback
- Introduces the idea of proc-based items

---

## 2. Adrenaline Injector

### Theme

Emergency stimulant that kicks in when the player is near death.

### Effect

When player health is below 30% of max health:

- Gain bonus movement speed
- Gain bonus fire rate

### Suggested Numbers

Per stack:

- +20% movement speed
- +20% fire rate

### Stacking

Each stack adds to both bonuses.

Example:

- 1 stack = +20% move speed, +20% fire rate
- 2 stacks = +40% move speed, +40% fire rate

### Why this is good

- Creates clutch moments
- Rewards risky situations
- Very noticeable when active
- Changes player behavior

---

## 3. Tactical Drone Beacon

### Theme

Portable military beacon that calls in temporary automated support.

### Effect

On enemy kill, 10% chance to deploy a combat drone for 20 seconds.

Drone behavior:

- Follows player
- Targets nearby infected
- Fires small projectiles automatically

### Suggested Numbers

- Proc chance per stack: +10%
- Drone duration: 20 seconds
- Drone damage: 6 per shot
- Drone fire interval: 0.6 seconds
- Max active drones:
  - MVP V1: unlimited if naturally spawned, or cap at 3 if needed for stability

### Stacking

Each stack:

- Adds +10% proc chance
- Optional later: slightly increases drone duration

MVP V1:

Just increase spawn chance only.

### Why this is good

- Feels powerful
- Summons are fun
- Highly visible
- Supports the “build an army” fantasy even before character classes are finalized

---

## 4. Emergency Ammo Cache

### Theme

Field supply drops that keep the player moving and reward repositioning.

### Effect

Every 25 seconds, spawn an Ammo Cache near the player.

When the player touches the cache, grant one random temporary buff:

- Damage Boost
- Fire Rate Boost
- Move Speed Boost
- Temporary Shield

### Suggested Numbers

Spawn interval:

- 25 seconds base
- Minimum cap later if needed

Buff duration:

- 8 seconds

Buff values:

- Damage Boost: +25% damage
- Fire Rate Boost: +25% fire rate
- Move Speed Boost: +25% move speed
- Temporary Shield: +25 shield HP

### Stacking

Each stack reduces cache spawn interval by 3 seconds.

Example:

- 1 stack = every 25s
- 2 stacks = every 22s
- 3 stacks = every 19s

Do not allow interval to go below 10 seconds.

### Why this is good

- Encourages movement
- Creates mini-objectives during combat
- Feels thematic
- Gives immediate, visible rewards

---

## 5. Air Support Authorization

### Theme

The player has military clearance to call in lethal support.

### Effect

Every 30 kills, call an airstrike on the largest nearby zombie cluster.

Airstrike behavior:

- Place a red warning marker on the ground
- Short delay
- Explosive strike hits area
- Damages all enemies in blast radius

### Suggested Numbers

- Kill requirement: 30 kills
- Warning delay: 1.5 seconds
- Blast radius: 16 studs
- Blast damage: 60

### Stacking

Each stack reduces the kill requirement by 5.

Example:

- 1 stack = every 30 kills
- 2 stacks = every 25 kills
- 3 stacks = every 20 kills

Do not reduce below 10 kills.

### Why this is good

- Big spectacle item
- Satisfying payoff
- Memorable
- Feels very military and fits the apocalypse tone

---

# Suggested MVP Item Mix

If the full 5-item implementation feels too large for one sprint, implement in this order:

## Highest Priority

1. Hollow Point Rounds
2. Adrenaline Injector
3. Tactical Drone Beacon

## Medium Priority

4. Emergency Ammo Cache

## Lower Priority

5. Air Support Authorization

Reason:

The first three provide a great test of:

- status effects
- conditional passives
- summons

That is enough to prove the item concept.

---

# Item Selection UI

## Goal

Whenever the player levels up, the game pauses and presents 3 item choices.

The player picks 1.

That item is added to their run inventory.

Duplicates are allowed unless explicitly blocked later.

For MVP:

- 3 random choices from the current item pool
- Player picks one
- Chosen item stack increases by 1
- Apply effect immediately

---

# Top-of-Screen Item Bar

## Goal

Display the player's currently owned items in a clean, readable strip at the top of the screen.

This is a run-history UI: the player should be able to glance at the top and instantly see what kind of build they currently have.

## Layout

Position:

- Top center of screen

Arrangement:

- Horizontal row

Each item slot should contain:

- Item icon
- Small stack number in the corner if stack > 1

Optional:

- On hover, show item name + short description
- For gamepad/mobile support this can be added later

## MVP V1 Rules

- Show all acquired items
- Update immediately when new item is acquired
- Reuse icon placeholders for now if necessary
- If there are many items later, this can wrap into 2 rows or become scrollable, but not needed now

## Suggested Visual Style

- Dark semi-transparent background strip
- Small framed icon boxes
- White item name in tooltip
- Stack count in bottom-right or top-right corner
- Clean military-tech UI feel

## Example

```text
[ Hollow Point x2 ] [ Drone Beacon x1 ] [ Adrenaline x1 ]
```

---

# UI Scope for MVP

For now, implement:

1. Level-up item selection panel
2. Top-of-screen acquired item bar

Do NOT implement:

- Item encyclopedia
- Full inventory screen
- Drag-and-drop inventory
- Rarity borders unless easy
- Detailed comparison screens

Keep it simple.

---

# Technical Architecture Notes

Suggested modules:

- ItemDefinitions.luau
- ItemService.luau
- ItemEffectService.luau or equivalent
- ItemSelectionUI.luau
- ItemBarUI.luau

Suggested responsibilities:

## ItemDefinitions

Stores item metadata:

- name
- description
- icon id / placeholder
- tags

## ItemService

Owns:

- player item inventory
- stack counts
- adding items
- querying owned items

## ItemEffectService

Hooks into gameplay systems and applies item effects.

Example:

- on projectile hit -> evaluate Hollow Point
- on player health changed -> evaluate Adrenaline Injector
- on enemy kill -> evaluate Drone Beacon / Air Support Authorization
- timed interval -> evaluate Emergency Ammo Cache

## ItemBarUI

Reads replicated player item state and displays icons/stacks at the top of screen.

---

# Implementation Rule

Build the simplest working version first.

Prioritize:

1. Correct functionality
2. Clear feedback
3. Stability

Do not over-engineer for a giant future catalog yet.

The purpose of this item pack is to answer one question:

"Does choosing powerful, distinct items make the run dramatically more fun?"
