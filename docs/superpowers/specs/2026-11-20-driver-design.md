# The Driver: Mile 14's boss (design refresh, 2026-11-20; WAITING FOR THE OWNER)

Refreshed by the systems designer from `docs/sprints/SPRINT_20_MILE14.md` > The Driver
(2026-11-09, never approved), against the Warden rework (`docs/sprints/FUN_WARDEN.md`,
`WARDEN_AGGRESSIVE.md`) and the v2 map. Loop sprint 2b. Nothing is built until the owner says yes.

## Who he is
The lead-bus driver who kept the bus sealed and never unbuckled, still strapped into his torn-off
seat. The Warden hunts you; the Driver is slow and takes the ground. Every hit vents gas onto the
road, and fire turns that gas into a flash that hurts him badly, so the fight is about *where he
stands when the gas goes up*: pull him onto burning buses and incendiary pools. Front and back are
the Warden's reversed: the swollen belly is the weak spot in front, the seat armours his back.

## Entrance
Always out of a bus. Burn the Buses: the lead bus at (-16, 12, -400). Other objectives: the
unburnt bus nearest the site's `BossFrom`, then a straight walk to it (`WalkTimeout` 45 s, then he
hunts). Control: "Something's moving in a bus." The bus rocks 3 s, the horn blares once (a
200-stud noise: sleepers wake), the glass blows out (20 and a shove within 10), he steps down,
2 s bellow, the boss bar and music.

## Stages
| Stage | At | What changes |
|---|---|---|
| 1 | 100% | Crush, Seat Ram, Retch; Vent every 12% lost |
| 2 "Last Stop" | 66% | air-brake bellow + 200-stud noise; the 2 nearest unburnt buses within 120 open (4 Walkers + 2 Runners each, +2 Walkers per extra player; burnt buses stay shut); Exhale; Vent every 10%; walk 9 |
| 3 "Unbuckled" | 33% | the buckle flies, a Seat Throw at once, back armour gone; walk 13; gas trail; Vent every 8%; Retch 5 s |

## Attacks
| Attack | Who | Tell | Hit | Counter |
|---|---|---|---|---|
| Crush | front, 8 studs, 90 deg | belly drops, 1.1 s | 40 + 1.5 s knockdown | roll / step aside |
| Seat Ram (1-2) | behind, 8 | belt creak, lean, 0.8 s | 30 + knockdown, thrown 12 | don't hug his back |
| Retch | 25-60 away or perched 4+ | throat heave, 1.0 s | lob 20 + bile puddle (7 r, 8 s, 12/s) | move |
| Vent | on health lost | pulls the buckle, belly swells, 0.8 s | gas patch 10 r, 14 s, 10/s (max 4) | leave, ignite, or pop the belly |
| Exhale (2+) | 10-30 in front | rising hiss, 1.3 s | 2 s cone 35 long 40 deg sweeping 50 deg (8/s), then 4 gas patches; 12 s cooldown | to the side, or pop the belly |
| Seat Throw (once, 3) | furthest within 70 or a perched one | rips the seat off, red 10-stud ring, 1.8 s | 50 + 1.5 s knockdown; the seat stays as cover | leave the ring |
| Gas trail (3) | behind him | none | a puff every 1.5 s (5 r, 6 s, 10/s; max 6) | |
| Death | | 2 s swell | 30 to soldiers / 60 to Infected within 14, then a cloud (18 r, 30 s, 15/s) over his reward crate | ignite it or wait |

**Gas and fire:** Infected are immune to gas. Gas touching fire (a burning bus, an incendiary
pool, any blast) flashes once and clears: soldiers in it +4 studs take 40 and a 1 s knockdown,
Infected 150; he takes 4% of his max health and staggers 2 s (one flash per 4 s; a chain is one).
**Weak spot:** the belly, x1.5 always, x3 while it swells; 350 belly damage during a swell pops
it (the attack cancels, a small patch under his own feet, 2 s stagger). Head x2. Never
dismembers. The seat takes back hits at 0.25 until stage 3.

## Numbers
7,000 HP, +50% per extra player (17,500 for four), scale 1.9, walk 8, supply 400. Target
100-130 s solo with bots, 2.5-3 min with four, adds included; fire about a quarter of his health in
a good fight. **Drop hook:** the buckle (`Fragment = "driver"`, later read by `Unlock`), maybe a
bonus fragment for dying inside a flash. Weapons not designed here.

## Build (4 steps)
1. Generalize `IndexService` from the Warden to a boss type (Delta's Warden re-checked by
   playing); upload `driver.py`'s meshes; the Driver with Crush, Retch, the bar and the lead-bus
   burst on Burn the Buses.
2. Gas (`GasService`): Vent, the belly, flashes from every fire source, the death cloud.
3. The stages: doors and Exhale, then Unbuckled (Seat Throw, trail, back opens) and Seat Ram.
4. Feel: clips, his own sound bank, music, radio, dev panel, the fragment hook, performance review.

## Owner questions (designer's pick first)
1. Burst from the bus nearest each objective (pick), or always walk from the lead bus (660
   studs from the toll plaza)?
2. Fire as his signature lever, 4% and a stagger per flash? (pick: yes)
3. 7,000 HP, slower and longer than the Warden's 5,000? (pick: yes, tune after playing)
