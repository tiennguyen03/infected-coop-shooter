# Backlog

The one page to open to see what is waiting, what is being built, and what needs you.
Plain words, newest state. Updated in the same commit as the work that changes it.
Last updated: 2026-11-11.

How to read it: **Try it** = built, waiting for you to play and say yes/no. **Building** =
in progress. **Your call** = blocked on a decision from you. **Later** = not started.

To play everything under "Try it" at once: Studio, Checkpoint Delta, Rojo on port 34874
(the test mix), Stop then Play. Nothing here is in the live game until its PR is merged and
published from `main`.

## 1. Try it (built, not yet played)

| PR | What | What to look at |
|---|---|---|
| #14 | Kill feedback: dark blood burst, soft tick on a kill | does a kill feel better; is the tick annoying |
| #15 | Rewards crate after the hold, 60 s extraction with a second wave, Warden chest plate 400 | extraction length, the second wave |
| #16 | Economy: missions pay merits; tabs stored | merits arrive in the lobby after extracting |
| #18 | Each call-in arrives its own way | which arrivals feel slow |
| #20 | New dev menu (tabs) and the light ally outline | F1; outline through walls, yellow when downed |
| #21 | Stamina bar; slides keep momentum on hills | sprint length, winded wait, slides on ramps |
| #22 | Bots walk (no teleport) and use stims, frags, fire missions | doors, stairs; do you ever see a teleport |
| #23 | Infected spread out instead of stacking | corridors and doors; is the horde now too easy |
| #24 | Remade Walker, Runner, Brute, Hocker in game | damage on the correct side, stumps, hitboxes |
| #25 | Throws leave the hand when the animation releases | half-second wind-up feel; no object in the hand yet |
| #27 | Hocker spit: head rears, bile glob, splat, pool | drops look like drops; pool visible on dark ground |
| #28 | Anvil aimed through binoculars, anywhere you can see | the arm pose and prop are placeholders |

Merge order when you are happy: #18 before #25 and #28; #16 before the merits/tabs counter;
#17 is replaced by #24.

## 2. Look at the pictures (Blender proposals, not in game)

| PR | What | Pictures | Honest state |
|---|---|---|---|
| #19 | Bloat, Shedder, Crawler, Kite, Growth | Desktop `Infected_roster` | Bloat good; Shedder reads like an armoured knight and needs another pass; Kite is weak from the front |
| #26 | Mile 14 v2: bigger (640 x 900), six-lane interstate, skyline | Desktop `Mile14_v2` | about 3.7x the detail of v1, frame rate not measured; some wrecks clip the median wall; fields are empty |

## 3. Building now

| What | Notes |
|---|---|
| Doorman turret: new 3D model | Blender; switch on its Config row to flip back |
| Bots survive the Warden; Aid Bag refills bot stims | added to PR #22 |
| Plain names: the Carrier, the helicopter, "Warden" on his lines | player-facing text only |
| Lobby soldier matches the in-game soldier | animations, outfit, rifle |
| Merits and tabs counter with icons | lobby corner and the end-of-run screen; on top of #16 |

## 4. Your call

| # | Question | My pick |
|---|---|---|
| 1 | Where does difficulty ramp too fast: waves before the Warden, the Warden, or extraction? | tell me which; the systems designer retunes that part |
| 2 | Tab packs: sizes and Robux prices (placeholders 100 / 550 / 1200) | decide with Nova |
| 3 | What tabs buy (you said guns and upgrades, balanced) | list it when you know |
| 4 | Shedder and Kite: another Blender pass before they go in game? | yes |
| 5 | Mile 14: v1, v2, or v2's skyline on v1's smaller frame? | look at the pictures first |
| 6 | Bloat's wound shows fat, not bone; Crawler's raw ring is at the rear | keep both |
| 7 | Should a refused Anvil mark show a message; should controller and phone get call-in buttons? | yes to both, later |
| 8 | Generator to 4.8, light-tower collision as two boxes, roll/slide keys | older calls still open |

## 5. Only you can do

- Delete the broken place "Stage 1 (tmp)": create.roblox.com, Co-op Zombie Shooter, Places, ⋯, Remove.
- Rotate the group Open Cloud key (create.roblox.com, Open Cloud, API Keys): make a new one, delete the old.
- Do not press Publish in a Studio window connected to the test mix. Publish only from `main`.
- Archive the old CZS and "Shooterr" experiences.

## 6. Later (not started)

- A held grenade / marker model so something is in the hand during the throw.
- Throw animation and grenade flight for bots.
- Secondary guns earn merits (they pay 0 today because use is not tracked).
- Gore stumps sit off the Runner's and Brute's arms.
- Support weapons (Gun, Thumper, Kettle), incendiary and stun grenades.
- Objective pools on Delta; Mile 14 in game with its boss.
- Warden follow-ups: fight length 100-120 s, Gate dressing, insert/wipe radio lines; his gas canister throw timing.
- Radio lines for bots (lore writer, plain names).
- Lobby: debrief panel.
- Performance measurements on a low-end device and with 2 clients.
- Phone: a sprint button (the stamina bar never shows without one).

The longer plan in phases: [ROADMAP.md](ROADMAP.md). What shipped: [HISTORY.md](HISTORY.md).
