# Dangerous Infected (the "make it fun" sprint, PR 2 of 4, 2026-11-18)

Owner, after playing Checkpoint Delta: "it's not really that challenging or fun", "Brutes die
too easily." Diagnosis: nothing threatens you, and every form is the same problem (point at
it, hold the trigger). This pass gives each form one move that forces its own answer, with a
tell before it so a hit is the player's fault, not the game's. Built on branch
`claude/fun-enemies` off `claude/test-mix-4` (#86). **Not yet played**: every number below
is a first guess from the systems-designer pass, meant to be tuned by playing.

Switch: `Config.InfectedMoves.Enabled = false` turns every move off (the forms keep their new
health and damage, which sit in `EnemyDefinitions` with the old value beside each). Each move
has its own `Enabled`. Dev panel F1 > INFECTED > THE MOVES > "Moves off" does the same for one
session.

## One answer per form

| Form | The move | The tell | The answer |
|---|---|---|---|
| **Brute** | Plated front: a round on the head, torso or arms from the front does 40%; one in the back 125%; the side and legs 100%; blasts never plated. **Charge** at a soldier 14-40 studs off in the open: a straight run at 36 studs/s through them and 12 past; everyone in 4.5 studs takes 25, is knocked down 1.4 s and thrown off the side of the line (the squad scatters). Hard cover stops him: stunned 2.5 s. | He stops, leans back 14 degrees and bellows for 1.1 s, turning to follow you | Get out of the line, or put cover between you and him; flank him while he is stunned or recovering; frags and call-ins (never plated) |
| **Runner** | **Pounce** at a soldier 6-18 studs off: 0.45 s in the air to where you stood. A hit (10) **pins** you on your back: no moving, shooting or abilities, 4 every 0.5 s, up to 5 s. Comes in packs of 2-3 from the spawn director. Faster (19, the soldier sprints 24). | It drops into a crouch and shrieks for 0.55 s | Step aside or roll as it leaves. Pinned: a squadmate shoots it (any hit throws it off) or shoves it (F). Bots shoot a pinning Runner before anything else. Control says who is pinned |
| **Hocker** | Each spit is a **barrage** of three globs: one on you, one 7 studs either side across the line, each leaving a bigger, longer puddle (7 studs, 7 s, 12/s). Behind cover with open sky over both ends it **lobs** high over the cover (1.7 s in the air). Stays further back (backs off inside 70% of its 45-stud stand-off). | Plants, its throat sac swells, its head rears back for 0.9 s (unchanged) | Move off the spot; you cannot sit behind one wall and wait it out; go and kill it |
| **Walker** | The crowd. A claw that lands with 3 or more Infected within 7 studs of you **grabs**: your speed drops to 60% (10% less per extra body, never below 30%) for 1.2 s, refreshed by each claw. | Each claw's swing and grunt (unchanged) | Do not let a horde close; a roll slips the claw; shove space open |

Control's radio lines (subtitles, plain words; `Config.InfectedMoves.Radio`):
- first charge of a run: "Big one charging. Get out of its line and hit it from behind."
- first lob of a run: "Spitter's lobbing over your cover. Move off the spot."
- every pin (at most every 6 s): "{name} is pinned. Shoot it off them."

## Numbers before and after

| Form | Health | Damage | Speed | Other |
|---|---|---|---|---|
| Walker | 55 → **60** | 10 → **12** | 9.5 → **10** | grab |
| Runner | 35 → **40** | 8 → **9** (pounce 10, pin 8/s) | 17 → **19** | packs of 2-3 |
| Brute | 260 → **500** | 30 → **35** (charge 25 + knockdown) | 6.5 → **7.5** | plated front 0.4, back x1.25 |
| Hocker | 75 → **80** | 15 → **18** a glob, x3 globs | 8 | range 55 → 65, stand-off 40 → 45, cooldown 3.0 → 3.5, windup 0.8 → 0.9, puddle 6 / 4 s / 8 → 7 / 7 s / 12 |

`Config.Enemies.MaxPuddles` 8 → 12 (three globs a spit).

Breakpoints kept on purpose: the M110 still one-taps a Walker (60), a rifle headshot still
kills a Walker, a rifle still kills a Runner in two body rounds, a frag (110) still kills a
Hocker.

**Rounds to kill a Brute** (body): rifle from the front 63, from behind 20, legs 25 (was 13
anywhere); shotgun 15 pulls front, 5 behind (was 3); M110 21 front, 7 behind (was 5); M2010 9
front, 3 behind (was 2); frags 5 (was 3).

## Why these numbers (systems pass)

- **Solo with three bots.** A player's rifle at 750 rpm into the plated front does about 100
  a second; the three bots (`Bots.FireCooldown` 0.3, rifle damage) add about 70: a Brute
  facing the squad dies in about 3 s of everyone firing, about 1.5 s from behind. That is
  long enough that he gets his charge off, short enough that he is not a sponge. Two Brutes
  late in a run (`CapLate` 3) with Runners pinning people is the "things going wrong" spike.
- **Four players.** Four rifles into his front is about 400 a second: 1.3 s. He is still
  quick to drop when four people focus him, but four people cannot all be safe from a charge
  that scatters them, and one stray who wanders off is the pounce's target. More bodies, not
  tougher ones, still holds (MULTIPLAYER_READINESS decision 6): the forms do not scale per
  player.
- **The pin is the co-op moment.** 8 a second for up to 5 s is 40 plus the 10 of the landing:
  a full-health soldier survives a whole pin, a hurt one goes down. Any hit on the Runner
  throws it off, so one squadmate looking round saves you; nobody looking is how you go down.
- **The charge never chains.** `Config.Knockdown.Grace` (1 s after standing) refuses a second
  knockdown, so a charge right after a pin only does its damage.

## How it works (for the next developer)

- `src/server/EnemyService.luau` > Big moves: a small state machine on the body
  (`zombie.move`: `chargeWindup` / `charge` / `pounceWindup` / `pounce` / `pin`). The root is
  anchored and driven through each stage (like the Warden's charge and the climb); a pouncing
  or pinning Runner is not solid while it lasts. `endMove` puts everything back (a pin lets go
  through `Squad.standUp`, the soldier plays the get-up now). A hit, a shove or any stagger on
  a pinning Runner ends the pin; a death ends any move.
- The Hocker's lob and barrage and the Walker's grab hang off their normal attacks
  (`stepProjectileZombie`, `attackIfTouching`). The grab is the character attribute `Grabbed`
  (a speed factor) read by `SprintController` and `BotService.follow`.
- The Brute's armour is in `DamageService.dealDamage` (`armoured`): the face a round landed
  on, in the body's own frame; reported to the shooter as a `plate` hit (the Warden's plate
  look). Blasts pass no part and are never plated.
- Runner packs: `EnemyService.spawnDirected`, called by the spawn loop's one spawn line
  (only the director's Runners; dev spawns and objective waves stay single).
- Pure maths: `src/shared/Rules/InfectedMoves.luau`, spec `tests/InfectedMoves.spec.luau`.
- `Squad.standUp(member, seconds)` cuts a knockdown short; clients get Impact `getup`
  (`AnimationController.getUpNow`); a long knockdown's fall clip now plays over at most 1.4 s
  and holds on the ground (players and bots).

## Not done / open

- **Not seen in game.** The poses (the Brute's lean back, the Runner's crouch and where it
  sits on a pinned body) are root tilts and offsets set blind; the pin's look needs a
  playtest. No new animation clips or sounds were made: the tells reuse each form's own
  voice groups (the Brute's bellow is its `idle`, the Runner's shriek its `attack`).
  A proper crouch, leap and pin clip per form, and a charge roar, are the follow-up (uploads
  through `assets/animations/build/` and the group's Open Cloud key).
- Bots do not dodge a charge or a pounce (they do step out of puddles); they will be knocked
  down and pinned and rely on you.
- The charge keeps the height it started at (like the Warden's); on a slope it may float or
  dip until it stops.
