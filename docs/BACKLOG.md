# Backlog

The one page to open to see what is waiting, what is being built, and what needs you.
Plain words, newest state. Updated in the same commit as the work that changes it.
Last updated: 2026-11-18 (breaches, fun sprint 1). Earlier: 2026-11-18 (the Visitor). (Integration 2, #63, was playtested by Tien and merged to main on
Last updated: 2026-11-18 (scarcity added under Try it).
Last updated: 2026-11-18 (the Visitor). (Integration 2, #63, was playtested by Tien and merged to main on
Last updated: 2026-11-18 (Warden aggressive added under Try it). Earlier: 2026-11-17. (Integration 2, #63, was playtested by Tien and merged to main on
Last updated: 2026-11-18 (the big map). (Integration 2, #63, was playtested by Tien and merged to main on
2026-11-17: call-ins land, Warden in the objective, the Loadmaster screen, one main
seller, call-in display, board in the ring, review fixes, Nova's ATV. The "Try it" rows for
#56, #58 and the ATV are now in main.)

How to read it: **Try it** = built, waiting for you to play and say yes/no. **Building** =
in progress. **Your call** = blocked on a decision from you. **Later** = not started.

To play everything under "Try it" at once: Studio, Checkpoint Delta, Rojo on port 34874
(the test mix), Stop then Play. Nothing here is in the live game until its PR is merged and
published from `main`.

## 1. Try it (built, not yet played)

| PR | What | What to look at |
|---|---|---|
| Breaches (`claude/fun-breaches`, fun sprint 1 of 4) | Being loud (shooting, blasts, call-ins) builds an alert; at the top a breach: a siren and screams from one side, Control names the side, a red BREACH arrow, then a big mixed horde floods in from there over 10 s. Then a quiet stretch to breathe. Bigger and more often later in the run; the main objective always gets one partway (`docs/sprints/FUN_BREACHES.md`) | F1 > INFECTED > BREACHES > Breach now; the strip under the F1 title shows the alert. Then play a normal run: does it feel like quiet, tension, spike, relief; are breaches too often or too big; can you always tell where they come from. Off: `Config.Breaches.Enabled = false` |
| Scarcity (`claude/fun-scarcity`) | Mistakes cost something: fewer spare magazines, the Resupply flare waits 90 s after a pallet, a dead teammate or bot leaves an AMMO pouch (hold E), and the squad shares a few reinforcements per mission (3 solo, 6 for four players): when you die the helicopter drops you back beside a teammate after 8 s; when they run out you stay dead until extraction. Bots don't use them (`docs/sprints/FUN_SCARCITY.md`; off: `Config.Scarcity.Enabled = false`) | F1 > PLAYER > SCARCITY (reinforcements left, spare mags) and "Kill me"; do you run dry before the second pallet; does dying feel bad in a good way; are 3 reinforcements solo too many or too few |
| Dangerous Infected (`claude/fun-enemies`) | Each Infected forces a different answer: the Brute has an armoured front (shoot his back or blow him up) and charges, knocking the squad down and apart; Runners come in packs, pounce and pin you until a squadmate shoots them off; Hockers spit three globs at once and lob over your cover; a crowd of Walkers grabs and slows you. Tougher numbers all round (`docs/sprints/FUN_ENEMIES.md`) | F1 > INFECTED > THE MOVES: one button per form. Can you always see the charge and the pounce coming; does the Brute now take a squad's attention; is a pin scary but fair; do the puddles move you; is the run hard enough solo with bots. "Moves off" (or `Config.InfectedMoves.Enabled = false`) if it is too much |
| Warden aggressive (`claude/warden-aggressive`) | The Warden hunts: leaps at whoever strays from the squad (a yellow ring where they stood, then he lands on it), walks faster, throws gas from the start, a rage below 30% (gas at everyone, more leaps); his back is a weak spot; less health; the spinning Bash is now a shield punch (`docs/sprints/WARDEN_AGGRESSIVE.md`) | F1 > THE WARDEN > "In front of me" (F9), then "To the rage". Does he feel dangerous; can you always see the leap coming; does the shield punch and the leap look heavy, not goofy (they were keyed blind); is 5,000 hp now too little |
| #77 Carrier v2 in the lobby | The revamped ship in the lobby: frames, pipes, deck gear, Easter eggs, every seller posed in their own corner, the map room open, a hidden nook under the ramp, the burning city straight ahead (`docs/sprints/CARRIER_V2.md` > In the lobby; `Config.Lobby.CarrierV2.Enabled` turns it off) | not yet seen in Studio; the poses are set blind and may need nudging; the sellers' idle loops are still to make |
| The Visitor (`claude/the-visitor`) | The hidden seller in the nook under the ramp: a man in a long raincoat with a red ESCORT REQUIRED badge, hands in his pockets, his head following you; talk to him (no sign, find him from the port side behind the ramp). Dialog only, he sells nothing yet; a deck hand now says "Nobody's under the ramp." | his lines and the first-meeting line; the head turn (smooth, not creepy-wrong); the coat and badge read at a glance; can you talk to him through the tarp (you should not) |
| Carrier follow-ups (`claude/carrier-followups`) | The call-in tallies on the hull and the MISSIONS HOME board are numbers now ("HAMMER 1,284"), and they go up for real as squads use call-ins and come home; the DAYS SINCE board counts up every day; every seller plays their own little idle loop (sip of tea, pen toss, hammock rock...) | the lobby: do the numbers read the right way round; do the sellers' moves look natural on their seats (they were keyed blind); in a published game, after a run, the numbers on the Carrier went up |
| #77 Carrier v2 in the lobby | The revamped ship in the lobby: frames, pipes, deck gear, Easter eggs, every seller posed in their own corner, the map room open, a hidden nook under the ramp, the burning city straight ahead (`docs/sprints/CARRIER_V2.md` > In the lobby; `Config.Lobby.CarrierV2.Enabled` turns it off) | not yet seen in Studio; the poses are set blind and may need nudging; the idle loops are in the Carrier follow-ups row above |
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
| #56 | Call-ins hold the crowd they land on (Hammer, Anvil, Shrike) | spawn 25 Walkers, call each strike, count kills; does it look like a magnet |
| #58 | The Warden comes partway through the main objective and is its last act | each objective's checklist in the PR; is he too much on top of the objective |
| Spit puddle PR | The Hocker's spit pool is an uneven puddle (not a circle), spreads out, bubbles, fumes, shrinks away | dev menu: spawn 1 Hocker, let it spit near you; is it a puddle now; still clear on dark ground; does the edge match where it hurts |
| NPC UI PR | Every desk looks like the Loadmaster: the Quartermaster, Call-ins and Vehicles open the same big screen with the item turning in 3D, its stats and BUY; the talk panels match | lobby place: buy something at each desk; does BUY feel clear; do you miss the camera on the gun wall (one switch brings it back) |
| Optic PR | M16A4 optics at the Loadmaster's EDIT: Red dot 150, CompM2 2x 250, ACOG 4x 400 merits, bought once | in a match, aim with each: is the ACOG too slow, is 2x right for the CompM2 (the real one is 1x) |
| ATV PR | The ATV: a call-in from the new Vehicles desk at the back of the hangar, slung in by the helicopter; one drives, one shoots off the back; runs the Infected down | Nova played the match side; the motor pool in the lobby is unseen |
| Objective meter PR | Objective progress is a big yellow bar under the objective line ("HOLDING 23 of 60s", red "PAUSED" when you step out); the squad panel and objective list no longer cover each other | Restore Comms at the mast: step in and out; a side objective takes the bar while you work on it |
| Kit Mods PR | Kit Mods at the Loadmaster: a KIT MODS tab, ranked buffs for merits (Extra stim, Extra roll; two greyed) | **decide first** (Your call 13); then buy a rank, check stims and the stamina bar in a match |
| Rack PR | The Quartermaster's GTA gun wall is back (the desk screen had replaced it); Call-ins and Vehicles keep the desk screen | talk to the Quartermaster, "Show me the guns.": the camera on the wall, hover, click a gun, Q to the counter |
| Big map PR | Checkpoint Delta grown to 1,800 x 1,800 as grey blocks: today's base in the middle, eight areas round it (farms, truck stop, water works, camp, rail yard, houses, interchange, fuel farm), a river with a ford and two bridges; you drop at a far corner and the helicopter's pickup is only called when the main objective is done | F1 > RUN > "Big map on"; walk or drive the loop; is it too empty, too far, is the river readable; how long a run takes. The Infected are not yet spread for a big map (`docs/sprints/DELTA_XL.md` > What breaks) |

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
| Vehicles: the ATV, follow-ups (Nova) | driver's hands on the bars, faster, the motor sergeant's radio lines, more vehicles as maps grow (the ATV wears Nova's model since 2026-11-17) |
| Optics for the other guns (Nova) | the M16's three are on the gun (2026-11-18); each other gun needs a `Fit` and a mesh per optic |
| Checkpoint Delta revamp in Blender (proposal, pictures first) | layers along the highway, multi-storey buildings, consistent vehicles; Desktop `Delta_v2` when done |
| The big map, next steps | spawning for a big map (Infected thinned out far away, none stuck in the river), then Delta v2 in the middle, then real art two areas at a time |

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
| 13 | Kit Mods (Nova's PR): permanent ranked buffs bought with merits. OWNER.md says power is the loadout, never stat items, and merits buy new options, never stronger versions. Allow them? | your rule; if yes, the OWNER.md lines change with it |
| 13 | Big map: its river runs east-west north of the checkpoint, but the map room's paper map has the river down the west side. Call it a side river that joins it ("the river")? | yes |
| 14 | Big map: switch it on for everyone after you have played it, or keep it a test until the Infected are spread for it (step 3)? | keep it a test until step 3 |

Decided 2026-11-11 (no longer open): game picks the main objective for now, lobby choice
later; two side objectives per run; tabs will buy guns and upgrades; keep HARLAN; yellow
stamina bar; shove is free; the Open Cloud key stays.

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
