# Fun sprint 1 of 4: breaches and the pressure rhythm (2026-11-18)

Owner, after playing Checkpoint Delta a lot: "it's not really that challenging or fun." The
spawn director was a steady trickle: a body every few seconds round the squad, more as the
run goes on. Nothing ever goes wrong and nothing ever lets up. This PR gives the run a
rhythm (quiet, tension, spike, relief) and makes being loud cost something.

Built on #86 (`claude/test-mix-4`). The other three sprint PRs (dangerous Infected, the
Warden as a boss, scarcity) do not touch this one.

## Design (systems designer's call)

**One alert meter per run, shared by the squad.** It goes up when the squad is loud and comes
down when they go quiet. Players read it through Control's radio, never a bar on the HUD
(the dev strip shows the number).

| Raises the alert | How much (`Config.Breaches.Sources`) |
|---|---|
| A shot with any Infected in earshot (the gun's `Noise` reach) | 0.25 per shot at reach 110, scaled by the gun's reach (a suppressor is quieter); all guns together at most 5 a second |
| A blast (frag, the Goose) | 10 |
| A call-in going off (fire missions, the Shrike, a sentry, wire, a supply drop) | 12, or the call-in row's own `BreachAlert` |
| An Infected first coming within 30 studs of a squad member ("spotted") | 1.5, once per body |
| Time alone (tension builds even when careful) | 0.15 a second early, 0.5 late |

Quiet for 8 s: the alert falls 4 a second. Late in the run it never falls below 35% of the
threshold: the map stays tense.

**The breach.** At the threshold (150 early, 90 at full pressure):
1. **Warning (4 s):** a far-off siren and Infected screams from that side (heard from where
   they come), Control: "Big group breaking through to your north-east. Brace!", and a red
   BREACH arrow on every screen pointing at that side (14 s).
2. **Flood (10 s):** a horde of the run's mix (the same type weights and Brute/Hocker caps as
   the trickle) pours in from one side, 65 studs out, 16 wide. Size: 10, +4 per extra living
   player, +10 at full pressure, at most 32, never past the live cap (44).
3. **Relief (50 s early, 30 s late):** nothing raises the alert, the trickle drops to 40%.
   Control: "That's the worst of it. Catch your breath." once three quarters of the horde
   is down.
4. **Calm:** the alert starts again from zero.

**Pressure** (0 to 1 over 12 minutes of run time) is the escalation knob: a lower threshold,
a shorter relief, a bigger horde, a higher floor. A loud squad sees roughly a breach every
two minutes early and every minute and a half late; a careful one fewer.

**The trickle follows the phase** (`Trickle`, multiplier on the spawn interval): Calm 1.6
(fewer), Tension 1 (as before), Breach 3 (the horde is the fight), Relief 2.5. While the main
objective, the Warden or extraction runs, the trickle stays as those were tuned.

**Objectives.** The main objective (and the old single hold) brings one breach at 40% of its
work, at its site, called by Control: "They heard the work. Big group coming in from the
south. Hold the site!" If the Warden is on the field then, it waits until he is down.

**Never:** in the first 60 s of a run, while the Warden is on the field, during extraction,
on a quiet (awareness) mission (Mile 14 has its own rules), or with dev spawning stopped.

**Co-op.** One meter per run (more guns fill it faster, up to the same per-second cap); the
horde grows per living player, not per bot. The squad's middle is the average of the living
members, players and bots.

## Why these numbers

- The shot cap (5 a second) is what keeps four M249s from breaching every 20 seconds; with
  it a sustained fight fills the early meter in about a minute.
- 150 early leaves room for the first contact and the insert to play as before; 60 s of grace
  covers the drop.
- A 10-body horde on top of the trickle is about double what is usually alive at minute
  two: a real spike, not a wipe. 32 is about three quarters of the hard cap.

## Off switches

- `Config.Breaches.Enabled = false`: the old steady trickle, no breaches, nothing else changes.
- `Config.Breaches.Objective.Enabled = false`: no objective breach.
- `Trickle` all 1: breaches stay, the trickle is as before.

## Not done here

- A HUD alert meter (Control's lines carry it for now; a meter would be a ui-ux-designer call).
- Breaches on the big map (they work, but 65 studs is small on 1,800 x 1,800; untested).
- Patrols that spot you (needs awareness on Delta: a later step).
