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
| #30 | Plain names: "Warden" on his lines, "Helo" / "the helicopter" | read the radio lines |
| #31 | Lobby soldier uses the in-game animations and carries your rifle | needs the lobby place; also check in-game walking still looks right |
| #32 | Merits and tabs counter with icons | lobby top bar; end-of-run screen |
| #33 | No floating health bars; squad panel on the left | do you want names back over teammates |
| #34 | New Doorman turret model | ammo can on its left, sensor on its right; does it look dark |
| #35 | First-person views fixed; real sniper scope | press F10 for the sight tour |
| #36 | Rewards picked from a big panel; better objective reward | crate next to a downed teammate; is the Warden too easy after the restock |
| #37 | Objectives: 5 main, 4 side, each with a reason | dev menu, RUN tab; props may float or sink |
| #38 | Roll is Shift twice; slide is holding C or Ctrl | accidental rolls when re-sprinting |
| #39 | Revive animation: kneel, treat, pull up | hands on the chest; the casualty not in the floor |

Merge order when you are happy: #18 before #25 and #28; #16 before #32; #15 before #36 and
#37; #21 before #38; #17 is replaced by #24. Several of these touch the same files; Claude
joins them at merge time (already done once in the test mix).

## 2. Look at the pictures (Blender proposals, not in game)

| PR | What | Pictures | Honest state |
|---|---|---|---|
| #19 | Bloat, Shedder, Crawler, Kite, Growth | Desktop `Infected_roster` | Bloat good; Shedder reads like an armoured knight and needs another pass; Kite is weak from the front |
| #26 | Mile 14 v2: bigger (640 x 900), six-lane interstate, skyline | Desktop `Mile14_v2` | about 3.7x the detail of v1, frame rate not measured; some wrecks clip the median wall; fields are empty |

## 3. Building now

| What | Notes |
|---|---|
| New key layout: E interact, V stim, F shove, C/Ctrl crouch, Z prone, X flare | one table for all keys; follow-ups on the open PRs |
| Checkpoint Delta revamp in Blender (proposal, pictures first) | layers along the highway, multi-storey buildings, consistent vehicles; Desktop `Delta_v2` when done |

## 4. Your call

| # | Question | My pick |
|---|---|---|
| 1 | Where does difficulty ramp too fast: waves before the Warden, the Warden, or extraction? | tell me which; that part gets retuned |
| 2 | Is this what Delta is? "The army checkpoint on the highway out of the city, where evacuees were screened. It was overrun from the inside. Take it back so the helicopter can land." | yes |
| 3 | Other made-up words players see: Index, NCOIC, the Primary, the Burn, THE PLOT, FIRES, Containment Board, LZ, "nets" | change all nine to plain words |
| 4 | Sniper: should right-click scope in from third person too? | yes |
| 5 | Names over teammates' heads: gone with the bars. Bring names back? | decide after seeing the outline and panel |
| 6 | Reward key is the interact key, same as revive. Keep one key for both? | yes unless the prompts fight |
| 7 | Full squad restock right before the Warden: too generous? | keep, judge by playing |
| 8 | Doorman: add a smooth turn and a muzzle flash? | yes |
| 9 | Tab packs: sizes and Robux prices (placeholders 100 / 550 / 1200) | decide with Nova |
| 10 | Shedder and Kite: another Blender pass before they go in game? | yes |
| 11 | Mile 14: v1, v2, or v2's skyline on v1's smaller frame? | look at the pictures first |
| 12 | Generator to 4.8, light-tower collision as two boxes | older calls still open |

Decided 2026-11-11 (no longer open): game picks the main objective for now, lobby choice
later; two side objectives per run; tabs will buy guns and upgrades; keep HARLAN; yellow
stamina bar; shove is free; the Open Cloud key stays.

## 5. Only you can do

- Delete the broken place "Stage 1 (tmp)": create.roblox.com, Co-op Zombie Shooter, Places, ⋯, Remove.
- Do not press Publish in a Studio window connected to the test mix. Publish only from `main`.
- Archive the old CZS and "Shooterr" experiences.

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
