# The Warden as a real boss (2026-11-18, `claude/fun-warden`, "make it fun" sprint PR 3 of 4)

Owner, after playing the aggression pass (#83): "The Warden doesn't even really feel like a
boss. I see the leap, but he kind of just doesn't move like a boss."

## Design note (systems designer pass)

**Diagnosis.** The aggression pass fixed *what* he does, not *how it reads*. He spawns
quietly out of sight, flinches on every bullet like a Walker (a 0.6 s hit clip, Action2), snaps
to face his target at the start of every windup (the old "spinning" look, in a smaller form),
walks a scaled-up Mixamo clip whose rate never matched his speed (the boots slide), and his
two thresholds only roar and spawn Walkers. Nothing about him says "the ground shakes when
this one moves".

**Recommendation:** presence (an arrival, music, camera shake), weight (no flinch, capped
turning, a heavy keyed stride matched to his speed), and stages that change the fight (Brutes,
a new big attack each stage, cover stops being safe). Health only rescaled for four players.

| What | Key (`Config.Index.Warden`) | Old -> new | Player-facing |
|---|---|---|---|
| Entrance | `Entrance` (new) | appeared at his spawn | Control: "something big just came over the wall"; a yellow ring 2.5 s with the ground rumbling and his fight loop starting; he dives in from 110 studs up onto it (25 + 1.5 s knockdown inside 14 studs), the screen shakes for everyone, he roars 2.4 s and the boss bar slams in |
| Size | `ScaleReach`, `EnemyDefinitions.Warden.Scale` | 1.9 -> 2.2 | he reads bigger; every reach is 16% longer with the body |
| No flinch | `Weight.NoFlinch` | flinched every 0.6 s | rounds never interrupt him; only a plate coming off staggers him |
| Turning | `Weight.TurnRate` 150°/s, `WindupTurnRate` 260°/s, `TrackLock` 0.35 s | instant snap | he swings round, tracks you through a windup and commits 0.35 s before the blow: step aside late |
| Heavy walk | `Animations.Infected.Warden.move = "warden_stride"`, `Weight.StepMarks`, `RateMin/Max` | `warden_walk`, rate fixed at spawn | a keyed loaded stride (sinking hips, counter-turned shoulders, shield across his front); the clip rate follows his real speed; a boot and a camera shake on each heel strike (1.2° at his feet, nothing past 45 studs) |
| Impacts | `Weight.ImpactShake` 3.5° / 70 studs | none | the Pound, Stomp, Slam, a landing, a wall, a Quake ring, smashed cover shake the screen |
| Fight loop | `Music` (new) | none | a low drone with a slow pulse from the warning to his death, louder and faster each stage (`assets/audio/build/warden_drone.js`) |
| Stage 2 at 66% | `Phases[1]` (`Below` 0.6 -> 0.66) | 6 Walkers + 2 Runners | the stage roar (everyone within 20 studs thrown back, screen shake) and 6 Walkers, 2 Runners, **1 Brute** (+3 Walkers, +1 Brute per 2 extra players); opens the **Quake** and charges through small cover (`Smash`) |
| Quake (new) | `Quake` | none | fists up 1.6 s with a 36-stud ring on the ground, then 2 rings run out at 26 studs/s, 0.75 s apart: 30 + 1.2 s knockdown each; jump it, roll it or be outside. For a crowd round him (2+) or anyone inside out of his reach. Every 14 s |
| Stage 3 at 33% (the rage) | `Phases[2]` (`Below` 0.3 -> 0.33) | 6 Walkers + 2 Runners | the roar and 6 Walkers, 3 Runners, **2 Brutes**; opens the **Rampage** |
| Rampage (new) | `Rampage` | none | three Charges back to back, each at whoever is furthest from where the last ended, a red lane on the ground for each; a wall ends it |
| Cover breaks | `Smash` | a charge into anything stunned him | from stage 2 a charge goes through props up to 8 studs a side (they fly apart; back next run); walls still stun him |
| Charge lanes | `Weight.Markers` | bots only | every Charge draws its lane on the ground (red) |
| Standing still | `Camp` (new) | the Leap went for the straggler | whoever has not moved 3 studs in 4 s is the Leap's first pick (`Rules/WardenBrain.camper`) |
| Weak spot | `Plates.Back.WeakSpot` | 0.5 -> 0.75 | three quarters of each round into his back goes through to the body |
| Health for 4 | `HealthPerExtraPlayer` | 0.33 -> 0.5 | solo with bots stays 5,000 (60-90 s plus the adds); four players get 12,500 for a 2-3 minute fight |

**Target fight:** solo with bots 90-120 s including the two summons; four players 2-3 minutes.
Danger comes from the Quake, the Rampage and the adds, not from more health.

**Not built, and why:** a new roar clip (the riot clip already reads as a roar; keyed blind
clips are a risk until someone watches them); a grab; destroying building walls (only props
up to `Smash.MaxSize` break, so the map can't be holed); the Barrage idea (a marker under
everyone) left for a later stage: the Quake and Camp already punish standing still.

## How it works

- `Rules/WardenBrain` (spec first): `farPick` gains the Quake (a crowd even in reach; anyone in
  the rings out of reach) and the Rampage (the rage, in the charge band, before the Volley);
  `turnToward` (capped, short way round), `summon`, `smashable`, `crossed` (a ring's hit
  test), `camper`.
- `IndexService`: the entrance is a pending "entrance" while he waits anchored above, then a
  `dive` leap with its own ring and blow (`startEntranceFall`, `landLeap`), the bar shown on
  landing (`showBar`). `turn` runs each frame with `Humanoid.AutoRotate` off. `updateIdle`
  sets the walk clip rate and fires a boot on each `StepMarks` crossing. `startQuake` /
  `stepQuake`; the Rampage chains in `endCharge`; `smashTarget` / `smash` / `restoreSmashed`.
  New BossUpdate kinds: `incoming`, `shake`, `quake`, `line` (`Messages.BossUpdate`).
- `EnemyService`: the boss handle carries its walk track; bosses skip the flinch.
- Client `BossPresence` (new): the fight loop, shakes (`CameraController.shake`, new), the
  Quake rings (28 bars per ring, tweened) and Charge lanes. `BossBarUI`: the slam-in and a
  punch on each stage; tell lines for the Quake and the Rampage.
- Assets: `warden_stride` keyed in `assets/animations/build/keyed.luau` (loop support added),
  uploaded 128664443037961; the loop `assets/audio/build/warden_drone.js` (node, no model),
  uploaded with the new `assets/audio/build/upload_audio.js`, 122577606238229 (moderation
  may hold it for a while; the fight is silent until then).
- Dev: F1 > THE WARDEN > "In front of me" (F9, now the full entrance 30 studs ahead), "To
  stage 2 (the call)", "To stage 3 (the rage)", "Quake now", "Rampage now".

## Off switches

`Entrance.Enabled`, `Weight.NoFlinch`, `Weight.TurnRate = 0` (instant turn as before),
`Weight.Markers`, `Music.Enabled`, `Quake.Enabled`, `Rampage.Enabled`, `Smash.Enabled`,
`Camp.Enabled`; `Animations.Infected.Warden.move = "warden_walk"` for the old walk;
`ScaleReach` and `EnemyDefinitions.Warden.Scale` back to 1.9 together.

## Not yet seen

Built from static checks and specs only (no Studio this sprint): the stride was keyed blind,
the dive's look, the ring visuals, the drone's mix against gunfire, whether the shakes are too
strong, whether 2.2 scale fits the lanes, and every number.
