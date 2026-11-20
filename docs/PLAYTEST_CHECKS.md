# Playtest checks: built, not yet looked at

What to look at in Studio for work that was built without a playtest. Folded here from the
session notes in `handoff/log/` when they were pruned (2026-11-19); the full notes are in git
history. Delete a section once it has been played and tuned. Newer check lists live in the
newest `handoff/log/` notes and each feature's `docs/sprints/` page.

## Call-in arrivals (2026-11-10)

Dev `FireCallIn <id>` for each of the eight. Off: `Config.CallIns.Arrivals.Enabled = false`.

- Every one: the thrown marker leaves the hand and lands on the aim point; the smoke colour reads.
- Hammer vs Anvil side by side read as different things: diamonds visible on the ground,
  rounds visible coming in (0.3 s and 0.7 s may be too short), whistle pitches (1.5 / 0.55)
  not harsh; the Anvil's column and burnt disc do not clip on a slope; the dust is a flat dome.
- Shrike: rungs run in the direction of flight, tracers start at the gunship's gun, the cannon
  is not too loud over the rotor.
- Doorman: chute panels and lines sit right; the swap from case to tripod at 2.2 s is hidden
  by the dust. Model: the ammo can on the gun's left, the sensor on its right (if swapped, take
  `Deployables` out of `MIRROR_X_COLLECTIONS` and re-upload); barrel at the target, feet on the
  ground (`Config.CallIns.Doorman.Model = 1` is the Part tripod).
- Tripline charges land where the mines appear; Concertina drums roll the right way to the
  wire's ends.
- Speedball, Aid Bag: the stand-in swaps for the bundle without a pop; the landing thump lines up.
- Pause mid-arrival holds; two players both see it; an Anvil plus a Hammer on a low-end device.
- Balance: Doorman, Tripline, Concertina take 2.2 / 0.95 / 1.05 s; Speedball and Aid Bag
  1.5 / 1.8 s (were 0.9).

## The Anvil's binoculars (2026-11-11)

- The mask leaves one clean window at every window size; the reticle centred; the readout off the HUD.
- 16 degrees is usable; body and gun hidden while up and back after; first person (T) before and after.
- The ring sits under the crosshair, drops to the foot of a wall, turns grey past 400 studs,
  behind cover and at the sky. No shot on the confirming click.
- The arms (never seen): `Config.CallIns.Binoculars.Pose` and `PropOffset`, on a teammate and
  the dressed body. A second player sees the raise and lower; going down lowers them.

## Throws leave the hand at the release (2026-11-11)

Tune `Config.Animations.Throws.grenade_throw` (Start 1.3, Release 2.0, Speed 1.4): does the
hand open as the thing leaves, is 0.5 s too slow under pressure; `ThrowMaxLag` 0.1,
`Grenade.Flight` and `Requisition.FlareFlight` 0.45. No prop in the hand yet; bots do not throw.

## Revive animation (2026-11-11)

All numbers in `Config.ReviveAnimation`; `Enabled = false` is off. In this order: (1) the
casualty on their back rests on the floor (`CasualtyLift`); (2) the reviver's hands on the
chest, elbows right (`KneelDistance`, `KneelTurn`, `ElbowOut`); (3) the slung rifle on the
back (`Sling`; `SlingRifle = false` treats one-handed); (4) the lying pose on a second client
and on a bot; (5) the slide and turn to the kneel point (`NudgeSeconds`, `MaxNudge`); (6) the
pull-up and get-up (`FinishSeconds`, `RecoverSeconds`); (7) the rustle sound.

## Infected spacing (2026-11-11)

`Config.Enemies.Spacing`; `Enabled = false` is the old chase. A ring round you, not a stack;
fewer bodies hit at once, so check the damage still bites. Jitter in a packed crowd: lower
`Steer.Strength`, raise `Steer.Deadzone`. Crowd too far or thin: lower `Radius`, raise
`Steer.BlockSlack`. Queues stalling at doors or stairs: raise `Steer.TravelMinPull`, lower
`Steer.EngageDistance`. Bodies behind low cover not climbing: lower `Steer.WaitStep`.

## Hocker spit and the puddle (2026-11-11, 2026-11-17)

Dev menu, one Hocker. The head rears back and snaps forward; drop size; the smear strength;
`Config.Enemies.SpitFX.Enabled = false` is the old ball. The pool is an uneven puddle: dome
height (`Pool.Depth`), the rim on dark ground at night, how faint the fumes are, whether the
edge dips (down to about 0.77x the radius) read as safe where they still hurt (`Pool.Shape`).

## Objectives and the Warden inside them (2026-11-11, 2026-11-16)

Dev `SetMainObjective <id>`, then play or "Complete hold" / `WardenNow`. Props sit right; 3
Brutes fair solo; the side objectives reveal at a good moment. With the Warden inside:

- sanitize: burn two tents, he walks to the third can; its prompt is off within 14 studs; pull
  him away and burn it; HUD "Kill the Warden"; kill: done line, reward crate, extraction.
- secure_site: he comes at 22 s; the bar stops while he is in the zone; killing him first says
  "The Warden is down. Finish the job."
- restore_comms: he comes at 30 s of the hold; the hold stops within 20 studs of the mast.
- confirm_casualties: he comes at half the heavies. recover_record: a third of the way, he
  goes for the carrier; drop it and he switches.
- Time the fight inside each (target 100-120 s). `Config.Objectives.Boss.Enabled = false` is
  the old order.

## Objective meter and HUD layout (2026-11-17)

Restore Comms: HOLDING moves each second at the mast, red PAUSED within 2 s of stepping out.
Clear the Spitters: the bar switches to the side objective on a kill, back to the main 4 s
later. Solo with bots: squad panel, then the objective list, nothing overlapping; a long
Control line wraps under the meter. Phone emulator: the stack at top centre. On a 667-wide
phone a long mission line can touch a notification card. Tune `Config.Objectives.Meter.Width`.

## Away-review fixes (2026-11-16)

Buy in the lobby right after a mission pays; prone under a Brute; 3 Hockers (the head rears);
Anvil binoculars plus a Warden knockdown; Space in the cutscene (solo: brief at once, ~3 s to
the first wave); two upgrade crates open with the same card; a roof with bots; the flare key
during its cooldown.

## The Loadout screen and the desk screens (2026-11-16, 2026-11-17; lobby place)

- The Loadout at the Loadmaster: size at 1080p and in the phone emulator, each gun turning
  side on and in view, the row shapes (`RowSilhouettes = false` if they show wrong), the
  Doorman's three pieces stacked right, gamepad A / Y / L1-R1.
- Each desk's talk panel (cream rows, keys 1-3); "Show me the call-ins." / "the vehicles."
  open the screen with the right lists; BUY with enough merits (their "bought" line, ON RECORD,
  the wallet drops) and short (dimmed, their "short" line); Back returns to the talk; the
  Loadmaster's LOADOUT and EDIT unchanged. `Config.Lobby.DeskScreen.Enabled = false` is the old views.

## The ATV (2026-11-17)

Nova played the match side. Not seen: the motor pool in the lobby, the wreck's blast, a
two-player drive, MicroProfiler numbers while driving.
