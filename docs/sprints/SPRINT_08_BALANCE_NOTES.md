# Balance Notes

## Date
2026-06-12

## Build Tested
Sprint 8 tuning build (all 7 MVP sprints + Sprint 8 pass). All static checks clean.
Mechanical systems verified in playtests through Sprint 7; the Sprint 8 value changes
below are code-complete but the three REAL runs still need a human player.

## Values Changed (Sprint 8 pass)

| Value | Old | New | Reason |
|---|---|---|---|
| Infected health | 50 | 40 | 4 shots at base 10 dmg; spec target 35-45 |
| Spawn interval (base) | 3s | 2s | First-contact pacing; spec 1.5-2.5s |
| Initial spawn | none | 5 at run start (1.5s in) | "Player sees enemies quickly" |
| Difficulty model | step (+25% HP, +20% dmg per minute step) | continuous +8%/min HP (cap 2.25x), +4%/min dmg (cap 1.75x) | Spec scaling tables; smoother, capped |
| Max alive | 8 + 2/min, cap 40 | schedule: 14 (to 1:00), 25 (to 3:00), 40 (to 5:00), 60 after | Spec enemy-count table |
| Min spawn interval | 0.75s | 0.6s | Late-run pressure |
| Objective hold | 30s | 45s | Spec recommendation |
| Objective pressure | none | +25% spawn rate while active + 10-Infected wave around zone on appear | "Objective creates danger" |
| Ammo cache spawn distance | 8-16 | 12-20 | Spec; tempts movement |
| Death screen | 3 stats | + "Items collected" | Spec requirement |
| Shoot sound | Rocket shot.wav (boom) | snap.mp3 @ 2.1x pitch, ±0.15 variance | Player feedback: boom was obnoxious |
| Weapon | none (shots from chest) | part-built rifle at right hip; shots from Muzzle | Player feedback |

Items: all five already matched the spec's recommended values — no changes.

## Run 1 Results (Baseline — TO FILL, play a real run)
- Time to first level-up:
- Level at 3:00:
- Items at 3:00:
- Objective completed:
- Time survived:
- Kills:
- Level reached:
- Items collected:
- Death cause:
- Notes:

## Run 2 Results (after first tuning reaction)
- (same fields)

## Run 3 Results (verification)
- (same fields)

## Expected numbers (for comparison while playing)
- First level-up: 60-120s (10 kills x 10 XP = level 2)
- Enemy HP: 40 at 0:00 -> ~50 at 3:00 -> ~58 at 5:00 (5-6 shots)
- Alive enemies: ~5 early, 14 by 1:00, 25 by 3:00, 40 by 5:00, 60 late
- Objective at 3:00, 45s hold, wave of 10 spawns around it

## What Felt Good
(fill after runs)

## What Felt Bad
(fill after runs)

## Bugs Found / Fixed
- FIXED: stale item-selection overlay could survive a run restart (now closes on respawn)
- FIXED: shots originated at head/chest height with no visible weapon

## Remaining Concerns
- 60 alive Infected not yet profiled for performance — if frames drop, lower
  `Config.Difficulty.MaxAliveLate` first, per spec
- Idle-player testing can't validate "fun"; needs the three real runs

## Recommended Next Sprint
Sprint 9: Enemy Variety V1 (Walker / Runner / Brute) — only after the three runs pass.
