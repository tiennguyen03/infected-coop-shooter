# Items Reference — Roguelike Arena Survivor

All 13 items currently in the game. Generated from `src/shared/ItemDefinitions.luau`
(metadata) and `src/shared/Config.luau` → `Items` (tuning values). All items stack;
level-up offers 3 distinct choices. Last updated 2026-06-12.

| # | Name | Id | Rarity | Category | Stacks |
|---|------|----|--------|----------|--------|
| 1 | Hollow Point Rounds | `hollow_point_rounds` | Common | On-hit DoT | unlimited |
| 2 | Adrenaline Injector | `adrenaline_injector` | Common | Low-HP buff | unlimited |
| 3 | Tactical Drone Beacon | `tactical_drone_beacon` | Uncommon | On-kill summon | unlimited |
| 4 | Emergency Ammo Cache | `emergency_ammo_cache` | Common | Timed pickup buff | unlimited |
| 5 | Air Support Authorization | `air_support_authorization` | **Legendary** | Kill-count strike | unlimited |
| 6 | Kevlar Plate Carrier | `kevlar_plate_carrier` | Common | Level-up shield | unlimited |
| 7 | Vampire Serum | `vampire_serum` | Common | On-kill heal | unlimited |
| 8 | Ricochet Rounds | `ricochet_rounds` | Uncommon | On-hit chain | unlimited |
| 9 | Shrapnel Magazine | `shrapnel_magazine` | Common | Multishot | unlimited |
| 10 | Incendiary Gel | `incendiary_gel` | Uncommon | On-kill area | unlimited |
| 11 | Repulsor Mine Kit | `repulsor_mine_kit` | Uncommon | Timed trap | unlimited |
| 12 | Shock Coil | `shock_coil` | Uncommon | Periodic pulse | unlimited |
| 13 | Hunter's Mark Optics | `hunters_mark_optics` | Uncommon | Priority debuff | unlimited |

Rarities (Sprint 14): 6 Common · 6 Uncommon · 1 Legendary. Offer weights 70/25/5; see
[ITEM_RARITY_PLAN.md](ITEM_RARITY_PLAN.md).

---

## 1. Hollow Point Rounds
**Shots have a 15% chance per stack to inflict Bleed: 4 damage per second for 3 seconds.**
- Proc chance: +15% per stack (on projectile hit)
- Bleed: 4 dmg/sec for 3s; reapplying refreshes duration (never stacks damage)
- Icon: uploaded (`rbxassetid://138354803501340`)

## 2. Adrenaline Injector
**Below 30% health: +20% move speed and +20% fire rate per stack.**
- Activates while health < 30% of max
- +20% move speed and +20% fire rate per stack; removed when healed above threshold
- Icon: uploaded (`rbxassetid://73534221660878`)

## 3. Tactical Drone Beacon
**Kills have a 10% chance per stack to deploy a combat drone for 20 seconds.**
- Proc: +10% per credited kill
- Drone: 20s lifetime, 6 dmg/shot, fires every 0.6s, 60-stud target range
- Max 3 drones active per player
- Icon: uploaded (`rbxassetid://73375484822115`)

## 4. Emergency Ammo Cache
**A supply crate drops nearby every 25s (faster per stack). Grab it for a random 8s combat buff.**
- Spawn interval: 25s base, −3s per extra stack (min 10s); crate despawns after 20s
- Spawns 12–20 studs away; collect within 4 studs
- Random 8s buff: +25% Damage, +25% Fire Rate, +25% Move Speed, or +25 temp shield HP
- Icon: uploaded (`rbxassetid://116972182907671`)

## 5. Air Support Authorization
**Every 30 kills (fewer per stack), call an airstrike on the largest nearby Infected cluster.**
- Kill requirement: 30 base, −5 per extra stack (min 10)
- Targets densest cluster within 100 studs; 1.5s warning, then 60 dmg in a 16-stud blast
- Strike kills credit the player (feeds drones / further strikes)
- Icon: uploaded (`rbxassetid://136560283241343`)

## 6. Kevlar Plate Carrier
**Gain 20 shield per stack whenever you level up (max 80 from this item).**
- On each level-up: +20 temp max-health (shield) per stack, each grant lasts 15s
- Capped at 80 concurrent shield from this item
- Icon: placeholder (no art yet)

## 7. Vampire Serum
**Heal 10 HP per stack every 12 credited kills.**
- Every 12 credited kills: heal 10 HP per stack (no overheal above max)
- Drone / airstrike / fire / mine / shock kills count (all credit the player)
- Icon: placeholder

## 8. Ricochet Rounds
**Shots have a 12% chance per stack to bounce to a nearby Infected for 50% damage.**
- Proc: +12% per stack (cap 60%)
- Bounces to 1 target (1–2 stacks), 2 (3–5), 3 (6+); within 20 studs; 50% of the hit's damage
- Instant chain — cannot re-trigger procs or loop
- Icon: placeholder

## 9. Shrapnel Magazine
**Every 6th shot fires extra side projectiles for 60% damage.**
- Every 6th player gun shot: fire 1+stacks extra angled rounds (cap 5) at 60% damage
- Drone shots do not trigger it; shrapnel rounds can proc on-hit items
- Icon: placeholder

## 10. Incendiary Gel
**Kills have a 15% chance per stack to leave burning ground.**
- Proc: +15% per kill (cap 60%)
- Fire pool: 8-stud radius, 5 dmg/sec for 5s; max 6 pools per player (oldest removed)
- Fire kills do not spawn new pools (no runaway)
- Icon: placeholder

## 11. Repulsor Mine Kit
**Periodically drop a blast mine that detonates on nearby Infected.**
- Drops every 18s, −3s per extra stack (min 9s); mine lasts 25s
- Triggers on an Infected within 5 studs → 30 dmg (+5/stack, max 45) in a 10-stud blast
- Max 5 mines per player; never damages the player
- Icon: placeholder

## 12. Shock Coil
**Periodically shock and slow nearby Infected.**
- Pulse every 12s, −2s per extra stack (min 6s)
- 18 dmg (+4/stack, max 30) in a 14-stud radius + 30% slow for 2s
- Icon: placeholder

## 13. Hunter's Mark Optics
**Periodically mark a high-health Infected to take +20% damage per stack.**
- Every 10s: marks the highest-health Infected within 70 studs for 6s
- Marked target takes +20% damage per stack (cap +100%) from ALL player-owned sources
- One marked target per player at a time
- Icon: placeholder

---

### Notes
- "Icon: placeholder" = the 8 newer items (Sprint 10) use letter-plate placeholders; the
  first 5 have uploaded vector art (`assets/icons/`).
- All numbers above are subject to Sprint 13 balance tuning.
