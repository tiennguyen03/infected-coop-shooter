# Backlog

The one page to open to see what is waiting, what is being built, and what needs you.
Plain words, newest state. Updated in the same commit as the work that changes it.
Last updated: 2026-11-18 (tidied: everything Tien has played is in main or in #86; the "make it fun" sprint started).

How to read it: **Try it** = built, waiting for you to play and say yes/no. **Building** =
in progress. **Your call** = blocked on a decision from you. **Later** = not started.

Nothing here is in the live game until its PR is merged and published from `main`.

## 1. Try it (built, not yet played)

| PR | What | What to look at |
|---|---|---|
| #86 | Integration 4: Nova's ATV crate and model, M16A4 sights, Kit Mods, the gun wall back; the Visitor; the Warden hunts; the big grey Delta (off by default); Carrier counts, days board, seller idles | Played by Tien 2026-11-18; merge with "Create a merge commit" |

Tien's notes from playing #86 (2026-11-18):
- The Warden still doesn't move or feel like a boss; Brutes die too easily; Checkpoint Delta
  is "not really that challenging or fun" → the "make it fun" sprint (Building now).
- The big map is only a skeleton, mostly empty space → fill it after the fun sprint.
- **For Nova:** the ATV crate is open at the bottom while the helicopter flies over; the ATV
  can't climb ramps (not enough power or grip).

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
| **"Make it fun" sprint** (Claude, 2026-11-18), four PRs on top of #86 | 1. breaches and escalation (noise brings a horde from one side; quiet, tension, spike, relief); 2. dangerous enemies (Brute armoured front and charge, Runner pounce and pin, Hocker spits you out of cover, Walker crowds grab); 3. the Warden as a real boss (entrance, weight, stages, summons); 4. scarcity (less spare ammo, limited squad respawns). Then difficulty levels, then a four-player test with friends |
| The big map, next steps | fill it after the fun sprint (roaming packs, road fights, small stops every 150-250 studs, wrecks and cover); then judge the size (shrink to ~1,200 if still empty); | spawning for a big map (Infected thinned out far away, none stuck in the river), then Delta v2 in the middle, then real art two areas at a time |

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
| 13 | Big map: its river runs east-west north of the checkpoint, but the map room's paper map has the river down the west side. Call it a side river that joins it ("the river")? | yes |
| 14 | Big map: switch it on for everyone after you have played it, or keep it a test until the Infected are spread for it (step 3)? | keep it a test until step 3 |

Decided 2026-11-11 (no longer open): game picks the main objective for now, lobby choice
later; two side objectives per run; tabs will buy guns and upgrades; keep HARLAN; yellow
stamina bar; shove is free; the Open Cloud key stays. Decided 2026-11-18: Kit Mods allowed
(OWNER.md updated); the Visitor (5 items, weekly, items not designed yet); numbers instead of
tally marks; big Delta grey blocks first, 20-minute timer, pickup revealed after the main
objective; boss weapons from boss parts are discussed before any work.

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
- **The Warden is a bullet sponge, not thrilling.** Built 2026-11-18: see "Warden aggressive"
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
