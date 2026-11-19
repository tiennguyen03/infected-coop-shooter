# The Warden, aggression pass (2026-11-18, `claude/warden-aggressive`)

Owner and Nova: "Warden boss sucks, doesn't feel thrilling, he kind of is just a bullet
sponge." Owner: "he needs to be more aggressive. Maybe some more animations. Some of his
animations look goofy, like he does that spinning thing."

## Design note (systems designer pass)

**Recommendation:** make him hunt, not hold more health. Give him a way to reach anyone at
any range, cut the seconds he stands still, cut his health about a third, and give good aim
a place to go (his back).

**Why he was a sponge (measured from Config, solo squad: a player and three bots):**

| What | Before | Effect |
|---|---|---|
| His walk vs the soldier's | 8 vs 16 studs/s (sprint 24) | backing off at a walk keeps him out of reach forever |
| Anything past 45 studs | nothing in phase 1 (the Canister was phase 2+) | a squad at range is never threatened |
| Charge | 19-45 studs, every 10 s | the only gap-closer, a straight line |
| Seconds between attacks | windup 0.9-1.4 + recovery 0.6-2.6 + a 1.0 s walk | a Bash cycle was about 2.5 s with 1 s of walking |
| Damage to kill | body 7,000 + plates 2,300 at 25% (= 9,200 rifle damage to strip) | about 16,000 rifle damage; at the squad's ~370 a second that is 44 s of perfect fire, 2-3 minutes in practice, most of it walking backwards |
| The Bash clip | Mixamo Power Slash | turns him a full 360° (the "spinning thing"); the Bash is his most frequent move |

**The plan (built):**

| Change | Key | Old -> new | Player-facing |
|---|---|---|---|
| Leap at the straggler | `Index.Warden.Leap` (new) | 22-70 studs, cooldown 9 / 7 / 5 s by phase, 0.8 s crouch + 0.8 s flight, 9.5-stud ring, 35 + 1.2 s knocked down | the ring lands where you stood when he crouched: move and he hits nothing; stay with the squad (`Rules/WardenBrain.isolated`) |
| Faster feet | `EnemyDefinitions.Warden.WalkSpeed`, `Phases[].WalkSpeed` | 8 / 8 / 11 -> 12 / 13 / 15 | still slower than a walking soldier, but backing off no longer wins on its own |
| Canister every phase | `Canister.MinPhase` | 2 -> 1 | hanging back gets a puddle at your feet |
| Charge reaches further | `Charge.MaxRange` | 45 -> 60 | |
| Less standing | `AttackGap`, recoveries, `SpawnDelay` | 1.0/0.7/0.4 -> 0.5/0.35/0.15; Bash 0.6 -> 0.4, Sweep 0.8 -> 0.6, Slam 1.2 -> 0.9, Charge 0.8 -> 0.5, Canister 0.5 -> 0.3; 1.5 -> 0.8 | he keeps coming |
| Bash, no spin | `Animations.Infected.Warden.attack`, `Bash.Windup` | warden_bash -> warden_shove (a keyed shield punch); 0.9 -> 0.7 s | a heavy step and the shield driven out |
| Rage at 30% | `Phases[2]` (`Rage = true`, `Below` 0.25 -> 0.3) | walk 15, leap every 5 s, the Volley | his words turn to "WEAPONS FREE", Control warns he jumps whoever is alone |
| Volley (rage only) | `Index.Warden.Volley` (new) | a canister at every member within 70, every 12 s | the whole squad moves |
| Weak spot: his back | `Plates.Back.WeakSpot` = 0.5, `WeakSpot` (new) | the back plate takes rounds whole (not 25%) and half goes through to his body; breaking it staggers him 3 s | flank him: the headshot marker pops; Control names it 10 s in |
| Less health | `EnemyDefinitions.Warden.MaxHealth`, plates | 7,000 -> 5,000; helmet 300 -> 200, chest 400 -> 300, shoulders 300 -> 200, shield 600 -> 400 (back stays 400) | about 10,400 rifle damage to strip everything and kill (was ~16,000) |

**Target fight:** 60-90 s for a solo squad, more of it spent moving than shooting.

**Not built, and why:** grab-and-throw (holding a player's body against their own client
physics is a large job and fights the knockdown we already have; the Leap gives the same
"he got me" moment); a separate weak-spot mesh (the back plate already sits over his radio
pack and has its own pip).

## How it works

- `Rules/WardenBrain` (spec first, `tests/WardenBrain.spec.luau`): `phase` (health ->
  phase), `isolated` (the member furthest on average from the rest), `farPick` (after the
  melee kit passes: the Volley in the rage, the Leap, the Charge, the Canister).
- `IndexService`: the Leap is a windup (crouch clip, ring via `BossUpdate "zone"`, bots read
  the danger disc), then an anchored arc to the ring (`stepLeap`), a disc on landing
  (`landLeap`). The Volley reuses the Canister's projectile. The weak spot is the plate
  attribute `WeakSpot` (`ProjectileServer.hitMultiplier`, `DamageService` via `Plates.hit`).
- Clips: `assets/animations/build/keyed.luau` writes `warden_shove` and `warden_leap` as
  joint angles over his idle's first frame; uploaded through Open Cloud with
  `build/upload_animations.js` (group 270506601).
- Dev: F1 > THE WARDEN > "In front of me" (F9), "To the rage" (new, `RageWarden`).

## Not yet seen

Built from static checks and specs only: the keyed clips were never watched in Studio
(poses set from numbers), the leap's arc over cover and the landing height on slopes, and
the numbers. Fallbacks: `Config.Animations.Infected.Warden.attack = "warden_bash"` puts the
old Bash clip back; `Config.Index.Warden.Leap.Enabled = false` turns the
Leap off.
