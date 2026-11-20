# Backlog

The one page to open to see what is waiting, what is being built, and what needs you.
Plain words, newest state. Updated in the same commit as the work that changes it.
Last updated: 2026-11-19 (tidied: "Try it" holds only what is not in main yet, #86 and the
four "make it fun" PRs, all joined in #92; Your call 3, plain words, done; Kit Mods allowed).

How to read it: **Try it** = built, waiting for you to play and say yes/no. **Building** =
in progress. **Your call** = blocked on a decision from you. **Later** = not started.

To play everything under "Try it" at once: Studio, Checkpoint Delta, Rojo serving
`claude/test-mix-5` (#92), Stop then Play. Nothing here is in the live game until its PR is
merged and published from `main`. Check lists for older work already in main:
[PLAYTEST_CHECKS.md](PLAYTEST_CHECKS.md).

## 1. Try it (built, not yet in main)

Merging #92 (Integration 5, "Create a merge commit") brings in #86 and #88-#91 at once.

| PR | What | What to look at |
|---|---|---|
| #86 Integration 4 (played by Tien 2026-11-18) | Nova's ATV crate and model, M16A4 optics, Kit Mods, the Quartermaster's gun wall back; the Visitor; the Warden hunts; the big grey Delta (off by default); Carrier counts, days board, seller idles | Tien's notes: the Warden still didn't feel like a boss and Brutes died too easily (the four rows below answer that); the big map is a skeleton to fill. **For Nova:** the ATV crate is open at the bottom while it flies over; the ATV can't climb ramps |
| #88 Breaches | Being loud (shooting, blasts, call-ins) builds an alert; at the top a breach: a siren and screams from one side, Control names the side, a red BREACH arrow, then a big mixed horde floods in from there over 10 s. Then a quiet stretch to breathe. Bigger and more often later in the run; the main objective always gets one partway (`docs/sprints/FUN_BREACHES.md`) | F1 > INFECTED > BREACHES > Breach now; the strip under the F1 title shows the alert. Then play a normal run: does it feel like quiet, tension, spike, relief; are breaches too often or too big; can you always tell where they come from. Off: `Config.Breaches.Enabled = false` |
| #89 Scarcity | Mistakes cost something: fewer spare magazines, the Resupply flare waits 90 s after a pallet, a dead teammate or bot leaves an AMMO pouch (hold E), and the squad shares a few reinforcements per mission (3 solo, 6 for four players): when you die the helicopter drops you back beside a teammate after 8 s; when they run out you stay dead until extraction. Bots don't use them (`docs/sprints/FUN_SCARCITY.md`; off: `Config.Scarcity.Enabled = false`) | F1 > PLAYER > SCARCITY (reinforcements left, spare mags) and "Kill me"; do you run dry before the second pallet; does dying feel bad in a good way; are 3 reinforcements solo too many or too few |
| #90 Dangerous Infected | Each Infected forces a different answer: the Brute has an armoured front (shoot his back or blow him up) and charges, knocking the squad down and apart; Runners come in packs, pounce and pin you until a squadmate shoots them off; Hockers spit three globs at once and lob over your cover; a crowd of Walkers grabs and slows you. Tougher numbers all round (`docs/sprints/FUN_ENEMIES.md`) | F1 > INFECTED > THE MOVES: one button per form. Can you always see the charge and the pounce coming; does the Brute now take a squad's attention; is a pin scary but fair; do the puddles move you; is the run hard enough solo with bots. "Moves off" (or `Config.InfectedMoves.Enabled = false`) if it is too much |
| #91 The Warden as a real boss | He arrives over the top (warning, ring, dive, screen shake, roar, the boss bar slams in, his own music); bigger, never flinches, turns heavily, a new heavy walk with boots you feel; at 66% and 33% he roars and calls Brutes; new big attacks: the Quake (shockwave rings: jump or roll them) and the Rampage (three charges in a row); his charges smash small cover; standing still makes you his leap target (`docs/sprints/FUN_WARDEN.md`) | F1 > THE WARDEN > "In front of me" (F9), then "To stage 2", "Quake now", "To stage 3", "Rampage now". Does he feel like a boss now; is the walk heavy, not goofy (keyed blind); are the shakes too much; is the music audible (it may sit in moderation for a while); how long does the fight take with the squad |
| Safe saves (`claude/save-versioning`, built on #92) | Nothing you can see changes: your merits, kit and Loadout are kept as they are. Underneath, every save now has a version so we can add new saved things (medals, district progress) without ever wiping a player, and a save the game cannot read is never written over: that visit shows "SAVE OFFLINE" under the wallet and keeps nothing (`docs/SAVES.md`) | Play the lobby once after merging: your merits, bought kit and signed Loadout should all still be there, and no SAVE OFFLINE line. If you ever see SAVE OFFLINE, tell Claude (it also shows in Studio without "Enable Studio Access to API Services") |

## 2. Look at the pictures (Blender proposals, not in game)

| PR | What | Pictures | Honest state |
|---|---|---|---|
| #19 | Bloat, Shedder, Crawler, Kite, Growth | Desktop `Infected_roster` | Bloat good; Shedder reads like an armoured knight and needs another pass; Kite is weak from the front |
| #26 | Mile 14 v2: bigger (640 x 900), six-lane interstate, skyline | Desktop `Mile14_v2` | about 3.7x the detail of v1, frame rate not measured; some wrecks clip the median wall; fields are empty |

## 3. Building now

| What | Notes |
|---|---|
| New key layout: E interact, V stim, F shove, C/Ctrl crouch, Z prone, X flare | one table for all keys; follow-ups on the open PRs |
| Vehicles: the ATV, follow-ups (Nova) | driver's hands on the bars, faster, the motor sergeant's radio lines, more vehicles as maps grow (the ATV wears Nova's model since 2026-11-17) |
| Optics for the other guns (Nova) | the M16's three are on the gun (2026-11-18); each other gun needs a `Fit` and a mesh per optic |
| Checkpoint Delta revamp in Blender (proposal, pictures first) | layers along the highway, multi-storey buildings, consistent vehicles; Desktop `Delta_v2` when done |
| The big map, next steps | fill it after the fun sprint is played (roaming packs, road fights, small stops every 150-250 studs, wrecks and cover); then judge the size (shrink to ~1,200 if still empty); then Delta v2 in the middle and real art two areas at a time || Next after #92 is played | difficulty levels; a four-player test with Nova and friends plus a performance check; a first-time player pass (tutorial / what confuses a newcomer); save versioning (building) |

## 4. Your call

| # | Question | My pick |
|---|---|---|
| 1 | Where does difficulty ramp too fast: waves before the Warden, the Warden, or extraction? | tell me which; that part gets retuned |
| 2 | Is this what Delta is? "The army checkpoint on the highway out of the city, where evacuees were screened. It was overrun from the inside. Take it back so the helicopter can land." | yes |
| 4 | Sniper: should right-click scope in from third person too? | yes |
| 5 | Names over teammates' heads: gone with the bars. Bring names back? | decide after seeing the outline and panel |
| 6 | Reward key is the interact key, same as revive. Keep one key for both? | yes unless the prompts fight |
| 7 | Full squad restock right before the Warden: too generous? | keep, judge by playing |
| 8 | Doorman: add a smooth turn and a muzzle flash? | yes |
| 9 | Tab packs: sizes and Robux prices (placeholders 100 / 550 / 1200) | decide with Nova |
| 10 | Shedder and Kite: another Blender pass before they go in game? | yes |
| 11 | Mile 14: v1, v2, or v2's skyline on v1's smaller frame? | look at the pictures first |
| 12 | Generator to 4.8, light-tower collision as two boxes | older calls still open |
| 13 | Big map: its river runs east-west north of the checkpoint, but the map room's paper map has the river down the west side. Call it a side river that joins it ("the river")? | yes |
| 14 | Big map: switch it on for everyone after you have played it, or keep it a test until the Infected are spread for it (step 3)? | keep it a test until step 3 |

Decided 2026-11-11 (no longer open): game picks the main objective for now, lobby choice
later; two side objectives per run; tabs will buy guns and upgrades; keep HARLAN; yellow
stamina bar; shove is free; the Open Cloud key stays. Decided 2026-11-18: Kit Mods allowed
(Tien; the OWNER.md lines change in #87). Done 2026-11-19 (Your call 3): the made-up words
players saw are plain words now (the sergeant, the main objective, "before the helicopter
leaves", MAP ROOM, the board WHAT WE HOLD, landing zone, the radio; `docs/LORE.md` > Naming).

## 5. Only you can do

- Delete the broken place "Stage 1 (tmp)": create.roblox.com, Co-op Zombie Shooter, Places, ⋯, Remove.
- Do not press Publish in a Studio window connected to the test mix. Publish only from `main`.
- Archive the old CZS and "Shooterr" experiences.

## Owner ideas to discuss later (2026-11-16)

- **Squads by invite, not by standing on a pad.** Invite friends from a party UI in the lobby;
  the party picks the mission (and objective); everyone is sent into that mission together,
  and the trip plays as a cutscene of the squad flying off in the helicopter. Replaces
  forming a squad by standing on a shared helipad.
- **A real map of where the Infected are.** The lobby's coverage board shows only
  percentages; it should show a visual map with where the Infected are thickest and what
  still needs clearing.

## Owner and Nova ideas to discuss (2026-11-17)

From Tien and Nova's chat. First goal before any of these: **one small game loop done**
(lobby → Checkpoint Delta or Mile 14 → extract → back to the lobby or keep going), solid.

- **Longer missions, 15–20 minutes, mostly travel.** Drop on one side of the map; side
  objective nearby; main objective on the far side; extraction halfway or all the way back.
  The maps are probably too small for that (ties into Delta v2 / Mile 14 v2). Nova: big maps
  are what make the running around work; maps may need to grow about 4x. To settle: 4x
  the ground area (each side about 2x) or 4x each side (16x the area); the second needs
  streaming and a phone frame-rate check.
- **Boss parts to build special weapons (Tien, not fully thought out).** Each boss has a
  rare chance to drop a weapon fragment; collect a full set to build a special item, e.g. a
  gun that needs the Warden's parts, another that needs another boss's. Lasting reward
  from a run (fits "rewards should last").
- **The Warden is a bullet sponge, not thrilling.** Built 2026-11-18: the Warden hunts (#86) and the Warden as a real boss (#91),
  under Try it.
- **Find bad collisions on the maps** (stuck spots, invisible walls, floating props) before
  map two goes in.
- **In-game UI is cluttered and overlaps** (first pass in progress: objective progress).
- **More weapons; highly customizable weapons** (attachments).
- **The Visitor's stock and items** (he stands and talks in the lobby since 2026-11-18; the
  rules are written: five items, one stock for everyone, changes every week, permanent
  unlocks for 1,500-2,500 merits, each a sidegrade with a drawback,
  `docs/sprints/CARRIER_V2.md` > The Visitor). Still to design: the item list and prices;
  then build the weekly stock and his buy screen.
- **More fun call-ins:** heavy weapons with their own limited ammo (no resupply), an
  exosuit, artillery, more vehicles; customizable squad vehicles or helicopter upgrades.
- **Something to fill the "shop" gap** (the place players spend on new gear over time).
- **Redo the sound effects** with a paid sound-generation tool; the Infected sounds are
  getting old.

## 6. Later (not started), in the order I would do them

1. Phone and controller: sprint button, call-ins, the Anvil, crate and objective prompts.
2. A ping button (middle mouse): mark a spot or an enemy for the squad.
3. Difficulty levels chosen in the lobby (more Infected, more side objectives, more merits).
4. Bloat and Crawler in the game.
5. A real four-player test with Nova and two friends.
6. Choosing the mission in the lobby (after Mile 14 is in the game).
7. Delta's second signature objective, Open the Gate (needs props that take gunfire).
8. Checkpoint Delta v2 and Mile 14 into the game once the pictures are approved.

Smaller: a held grenade / marker model; throw animation for bots; revolver model (lower
hammer); secondary guns earn merits; gore stumps off the Runner's and Brute's arms; proper
image ids for the merits and tabs icons; remove the lobby panels' duplicate merits text;
support weapons and incendiary / stun grenades; Warden follow-ups (fight length, his gas
canister throw timing); bot radio lines; lobby debrief panel; a relaxed rifle pose and a jump
clip for the lobby; performance measurements on a low-end device and with two clients.

The longer plan in phases: [ROADMAP.md](ROADMAP.md). What shipped: [HISTORY.md](HISTORY.md).
