# Backlog

Tien's one page: what is waiting, being built, and needs a decision. Plain words, newest
state, one row per thing. Updated in the same commit as the work that changes it; keep it
under 10k.
Last updated: 2026-11-19 (trimmed; safe saves added under Try it).

**Try it** = built, waiting for you to play and say yes/no. **Building** = in progress.
**Your call** = needs your decision. **Later** = not started.

To play everything under "Try it": Studio, Checkpoint Delta, Rojo serving
`claude/test-mix-5` (#92), Stop then Play. Nothing is live until its PR is merged and
published from `main`. Older work already in main: [PLAYTEST_CHECKS.md](PLAYTEST_CHECKS.md).

## 1. Try it (built, not yet in main)

Merging #92 (Integration 5, "Create a merge commit") brings in #86 and #88-#91 at once.

| PR | What | What to look at |
|---|---|---|
| #86 Integration 4 (played 2026-11-18) | Nova's ATV crate and model, M16A4 optics, Kit Mods, the gun wall back; the Visitor; the Warden hunts; the big grey Delta (off); Carrier counts, days board, seller idles | your notes (Warden not a boss, Brutes too easy) are answered by the rows below; the big map is a skeleton. **Nova:** the ATV crate is open at the bottom in flight; the ATV can't climb ramps |
| #88 Breaches | Being loud builds an alert; at the top a siren, Control names the side, a red arrow, a big horde floods in over 10 s, then a quiet stretch. The main objective always gets one (`docs/sprints/FUN_BREACHES.md`) | F1 > INFECTED > BREACHES > Breach now; in a normal run: quiet, tension, spike, relief? too often or too big? can you tell where they come from? |
| #89 Scarcity | Fewer spare mags; the Resupply flare waits 90 s after a pallet; the dead leave an AMMO pouch (hold E); the squad shares reinforcements (3 solo, 6 for four): the helicopter drops you back after 8 s, none left = dead until extraction (`docs/sprints/FUN_SCARCITY.md`) | F1 > PLAYER > SCARCITY and "Kill me"; do you run dry before the second pallet; does dying hurt in a good way; are 3 solo right |
| #90 Dangerous Infected | Brute: armoured front, charges and knocks the squad down; Runners in packs pounce and pin you; Hockers spit three globs and lob over cover; a Walker crowd grabs and slows (`docs/sprints/FUN_ENEMIES.md`) | F1 > INFECTED > THE MOVES; can you see the charge and pounce coming; is a pin scary but fair; hard enough solo with bots? "Moves off" if too much |
| #91 The Warden as a boss | An entrance (dive, shake, roar, boss bar, his music); bigger, no flinch, a heavy walk; at 66% and 33% he roars and calls Brutes; the Quake (jump or roll the rings) and the Rampage; charges smash small cover (`docs/sprints/FUN_WARDEN.md`) | F1 > THE WARDEN > "In front of me", then the stage, Quake and Rampage buttons. Boss now? walk heavy, not goofy? shakes too much? music audible? fight length with the squad |
| #94 Safe saves (built on #92) | Nothing you see changes. Every save has a version, so new saved things never wipe a player; a save the game cannot read is never written over and shows SAVE OFFLINE under the wallet (`docs/SAVES.md`) | play the lobby once after merging: merits, kit and Loadout still there, no SAVE OFFLINE (it also shows in Studio without API access) |
| Attachment system v2 (`nova/attachment-system-v2`, Nova) | The M16A4's EDIT: seven slots, each option bought once with merits; ammo types change the round. Stats only | buy and fit a few; a clash (suppressed barrel + muzzle brake); the drum, AP on a Brute, the laser |
| The Mossberg on v2 (`nova/attachment-rollout-mossberg`, Nova; waits for #97) | Seven slots; four shells: buckshot, slug (one big hit at range), Dragon's Breath (sets them burning), breaching (opens hut and shed walls). Stats only | buy a slug and a full choke: refused, with why; burn a crowd; breach a hut wall (2 shots, 1 with the breaching muzzle). **Next, one PR each:** MP5 (9mm, subsonic and the suppressor), M249 (belt, tracer-heavy), M110 + M2010 together (7.62), the Fifty (.50 BMG), M17 + Revolver (sidearm slots); then the visuals on every gun, trader-only attachments |
| Playtest fixes (`nova/playtest-fixes`, Nova) | A Studio match starts with your Loadmaster Loadout; Runners no longer shove you or lift you on a pile (the Infected pass through soldiers); the red dot and CompM2 show a red dot when aimed; the red dot rides higher, the front post under the dot | Studio with API access on: do you spawn with your kit; get swarmed by Runners; does a horde now feel too easy to walk through; aim with the red dot and CompM2: dot size and brightness |

## 2. Look at the pictures (Blender proposals, not in game)

| PR | What | Honest state |
|---|---|---|
| #19 | Bloat, Shedder, Crawler, Kite, Growth (Desktop `Infected_roster`) | Bloat good; Shedder reads like a knight; Kite weak from the front |
| #26 | Mile 14 v2: 640 x 900, six-lane interstate, skyline (Desktop `Mile14_v2`) | 3.7x v1's detail, frame rate not measured; wrecks clip the median; fields empty |

## 3. Building now

| What | Notes |
|---|---|
| New key layout: E interact, V stim, F shove, C/Ctrl crouch, Z prone, X flare | one table for all keys (`docs/OWNER.md`) |
| Vehicles (Nova) | driver's hands on the bars, faster, the motor sergeant's radio lines, more vehicles as maps grow |
| Optics for the other guns (Nova) | the M16's three are done; each other gun needs a `Fit` and a mesh per optic |
| Checkpoint Delta revamp in Blender (pictures first) | layers along the highway, multi-storey buildings; Desktop `Delta_v2` |
| The big map, next steps | after #92 is played: roaming packs, road fights, stops every 150-250 studs, cover; then judge the size (~1,200 if still empty); then Delta v2 in the middle, real art two areas at a time |
| Next after #92 is played | difficulty levels; a four-player test with Nova and friends plus a performance check; a first-time player pass |

## 4. Your call

| # | Question | My pick |
|---|---|---|
| 1 | Where does difficulty ramp too fast: waves before the Warden, the Warden, or extraction? | tell me; that part gets retuned |
| 2 | Is Delta "the army checkpoint on the highway out of the city, overrun from the inside; take it back so the helicopter can land"? | yes |
| 4 | Sniper: right-click scopes in from third person too? | yes |
| 5 | Bring names back over teammates' heads? | decide after seeing the outline and panel |
| 6 | One key (interact) for rewards and revive? | yes unless the prompts fight |
| 7 | Full squad restock right before the Warden: too generous? | keep, judge by playing |
| 8 | Doorman: a smooth turn and a muzzle flash? | yes |
| 9 | Tab packs: sizes and Robux prices (placeholders 100 / 550 / 1200) | decide with Nova |
| 10 | Shedder and Kite: another Blender pass before the game? | yes |
| 11 | Mile 14: v1, v2, or v2's skyline on v1's frame? | look at the pictures first |
| 12 | Generator to 4.8; light-tower collision as two boxes | older calls still open |
| 13 | The big map's river runs east-west, the map room's paper map has it down the west side: call it a side river that joins it? | yes |
| 14 | Big map on for everyone after you play it, or a test until the Infected are spread for it? | a test until then |

Decided: game picks the main objective for now; two side objectives per run; tabs will buy
guns and upgrades; keep HARLAN; yellow stamina bar; shove is free; the Open Cloud key stays
(2026-11-11). Kit Mods allowed (2026-11-18). Plain words for players done (2026-11-19,
`docs/LORE.md` > Naming).

## 5. Only you can do

- Delete the broken place "Stage 1 (tmp)" (create.roblox.com, Co-op Zombie Shooter, Places, ⋯, Remove).
- Never press Publish in a Studio window connected to the test mix; publish only from `main`.
- Archive the old CZS and "Shooterr" experiences; rotate the group Open Cloud key.

## 6. Ideas to discuss (Tien and Nova, 2026-11-16 and 11-17)

First goal before any of these: one small game loop done and solid (lobby, mission,
extract, back or keep going).

- **Squads by invite:** a party UI in the lobby; the party picks the mission; the trip plays
  as a cutscene of the squad flying off. Replaces standing on a shared helipad.
- **A real map of where the Infected are** on the lobby's coverage board, not just percentages.
- **Longer missions, 15-20 minutes, mostly travel** (drop on one side, main objective on the
  far side). Being tried with the big map (`docs/sprints/DELTA_XL.md`).
- **Boss parts to build special weapons:** a rare fragment per boss; a full set builds a
  special gun. A reward that lasts.
- **Find bad collisions** (stuck spots, invisible walls, floating props) before map two.
- **In-game UI clutter** (first pass done: the objective meter and one left column).
- **More weapons, highly customizable** (attachments).
- **The Visitor's stock:** five items, one stock for everyone, changes weekly, permanent
  sidegrades for 1,500-2,500 merits (`docs/sprints/CARRIER_V2.md` > The Visitor). To design:
  the items and prices; then the weekly stock and his buy screen.
- **More fun call-ins:** heavy weapons with their own ammo, an exosuit, artillery, more
  vehicles, squad vehicle or helicopter upgrades.
- **Something to fill the "shop" gap** (where players spend on new gear over time).
- **Redo the sound effects** with a paid sound tool; the Infected sounds are getting old.

## 7. Later (not started), in the order I would do them

1. Phone and controller: sprint button, call-ins, the Anvil, crate and objective prompts.
2. A ping button (middle mouse) to mark a spot or enemy.
3. Difficulty levels chosen in the lobby.
4. Bloat and Crawler in the game.
5. A real four-player test with Nova and two friends.
6. Choosing the mission in the lobby (after Mile 14 is in).
7. Delta's second signature objective, Open the Gate.
8. Checkpoint Delta v2 and Mile 14 in the game once the pictures are approved.

Smaller: a held grenade / marker model; bot throw animation; revolver hammer; secondary guns
earn merits; gore stumps off the Runner's and Brute's arms; image ids for the merits and tabs
icons; the lobby panels' duplicate merits text; support weapons, incendiary and stun
grenades; Warden fight length and gas timing; bot radio lines; lobby debrief panel; a relaxed
rifle pose and jump clip for the lobby; performance on a low-end device and with two clients.

The longer plan: [ROADMAP.md](ROADMAP.md). What shipped: [HISTORY.md](HISTORY.md).
