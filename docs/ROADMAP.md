# Roadmap: from one mission to a game people come back to (2026-11-09)

Owner's ask: plan "the operations from the lobby, picking loadouts, loading into the game, how
we keep players playing, player progression, how to make it play and feel more satisfying"
before building more. Written from four design calls on the same day (systems designer, UI/UX
designer, playtest critic, lore developer). **Nothing here is canon until the owner decides**;
the decisions are listed at the end with a recommendation each. Rules that bind all of it:
[OWNER.md](OWNER.md) (power is the loadout, never stats; the run is the story; grounded; our
names; modular per-item rows).

## Where the game stands (playtest critic)

- **What works, keep leaning on it:** the kill (limp bodies thrown by the killing hit, limbs
  off, flinch, per-gun kick); the flare lure into a loud pallet landing (the best pacing beat);
  aimed call-ins, the Anvil shake, the Shrike helicopter; the Warden walking up the road and
  losing his plates; guns that genuinely play differently.
- **Why a player would not come back, worst first:**
  1. Run 2 is run 1 again: same site, same 3:00 trigger, same boss, everything unlocked.
  2. The first three minutes have no reason to move: a hidden 180 s timer, Walkers only.
  3. Rewards land when you need nothing (the first pallet at full ammo; the Warden's upgrade
     cards with 30 s of extraction left); one field-upgrade pick per run.
  4. Solo doesn't feel like a squad: bots never call anything in (they do since 2026-11-11:
     frags, stims, Hammer / Anvil), the radio is text only.
  5. The middle of the Warden fight drags (130 s+ solo); extraction (30 s) ends before it builds.
  6. The results screen erases the run: four numbers, nothing that happened.

## The shape we're building toward

```
 LOBBY (the Carrier)           MATCH (one server, one operation, ~40 min)          LOBBY
 kit sheet (B / any desk) ─►  Delta ─ ride ─► Mile 14 ─ ride ─► Kestrel ─► STAND DOWN ─► debrief
 board a Lantern, READY       each ride: tally + CONTINUE / STAND DOWN vote,        merits paid, 
 fade to black + rotor        change loadout, the dead come back                    Service Record,
                              Stand Down after any mission = the 20-30 min session  the board moves
```

- **An operation** is three missions on one match server; players teleport only lobby -> match
  and back ([LOBBY_MATCH_HANDOFF.md](LOBBY_MATCH_HANDOFF.md)). A squad can **Stand Down after
  any mission** (the short session) and keeps what it banked.
- **Between missions (the ride, 30-40 s):** a tally (outcome, secondaries, merits earned,
  containment), then CONTINUE or STAND DOWN (majority; solo decides). Ammo, grenades, stims,
  call-ins refill; **field upgrades carry** (the reason to continue); the Resupply pool carries
  up to one pallet's cost; revives and the pallet price reset per mission; the clock starts at
  each mission's `ClockStart` (Delta 0, mission 2 120 s, mission 3 240 s, + band offset). The
  loadout can change on the ride (owned items only); the in-mission LZ Arms Room retires.
- **The dead come back** when the next pallet lands, roped in beside it (4 per mission,
  squad-wide), instead of spectating for ten minutes. A wipe ends the operation; extracted
  missions keep their pay.
- **A mission's beats (12-14 min):** insert (quiet) -> first pallet ~1:15 -> Secondary 1 and
  its upgrade crate -> the Primary (the squad starts it) -> the Index and its pallet ->
  Secondary 2 or the bird -> extraction (60 s, two waves) -> the ride.

## Progression (systems designer + lore developer)

- **Merits** (the soft currency; owner 2026-11-10, was "Credits"), kept on your **Service
  Record**: paid **when a mission ends**, never per kill. Win 120, Partial 60, Loss 0, each
  Secondary +30 (`Config.Merits`; built 2026-11-10, `MeritService`). Paid to every squad
  member, dead or alive (bots earn nothing; solo pays the same). Not built yet: Stand Down
  +100 (x0.25 in a Secured district), and Secondaries (none is tracked, so they pay 0). A
  perfect operation ~640, a typical first one ~250.
- **What merits buy:** guns, sidearms, grenades and call-ins, bought at the Carrier's desks. Each
  item's row carries its `Price` (0 = on issue): no list of names anywhere. **Field
  upgrades are never sold** (finds inside a run).
- **Tabs** (the hard currency; owner 2026-11-10): bought with Robux in packs
  (`Config.Tabs.Products`) or granted by events, kept on the same record next to merits.
  **Tabs never buy power:** cosmetics and conveniences only. Built so far: the balance on the
  record and on the Carrier's panels, and the receipt handler that pays a pack once
  (`TabsService`). Not built: the Roblox products (every `ProductId` is 0), a way to buy a
  pack, and anything to spend tabs on.
- **On issue from the start:** M16A4, Mossberg 590, M17, Frag; Hammer, Tripline, Doorman,
  Concertina, Speedball (five call-ins for four slots: a choice from run 1).
- **Prices:** MP5 100 · revolver 150 · Aid Bag 150 · M110 200 · M249 300 · Anvil 300 ·
  Shrike 400 · M2010 400 · later Goose/Thumper/Kettle 300-500, Incendiary 150, Stun 200.
  First unlock after the first Delta win (~15 min); fifth ~3 operations; everything ~5
  operations for a good squad, 8-10 for a new player (one weekend).
- **Grade:** real US Army enlisted grades (PV1 ... SGM) earned by windows brought home, shown on
  the name tape in the lobby and on the scoreboard only. **Cosmetic: it gates nothing and adds
  nothing.** On the radio you are still "Pike Three".
- **The Carrier's desks are shops** (owner and Nova, 2026-11-09: there is no ship to upgrade like
  Helldivers, so the Carrier sells kit instead). A locked item shows its price ("300 MERITS")
  and a BUY button; bought once, it's yours for good. Only guns, grenades and call-ins are sold:
  no cosmetics and no one-run consumables for now (owner, 2026-11-09).

## Reasons to come back (systems designer + lore developer)

- **The Containment Board** (shared by everyone): districts move through Lost / Contested /
  Held / Contained, which changes the map you play. Needs `PointsPerPercent` tuned to the
  player count and a slow decay ("the Infected push back") so a big player base doesn't
  Secure Delta in an hour.
- **FRAGO** (daily, per soldier, same for everyone that day, seeded by date; +100 merits) and
  **Corridor Order** (weekly, every team, tied to the board; +300). Examples: "Two Secondaries
  on Delta today"; "Mile 14 to Held by Sunday".
- **Variety:** objective pools (designed in PROGRESSION), then grounded mission modifiers in
  Lost districts ("battery displaced": no Anvil; fog; heavy hosts; net jammed).
- **Never:** login streaks that punish a missed day, limited-time guns, paid power, loot
  boxes, per-kill grind, stat upgrades, a battle pass now, ship upgrades.
- **Names (lore developer):** HRD on the ship = **Harlan Recovery Detachment** (already canon in
  LORE "Pike"). Other window teams on the Carrier are polearms (Halberd, Glaive, Lance, Bill,
  Partisan, Spontoon, Voulge); on your own net your team is always Pike. Desks get their own
  clerk voice ("Signed for. One Goose. Bring the tube back.").

## The player journey (UI/UX designer)

- **One kit sheet, many ways in:** B or a KIT button anywhere in the lobby, each desk opens it at
  its own column, a LOADOUT button on the boarding panel. One saved loadout ("last used",
  auto-applied); presets later. The rack stays for browsing and inspecting.
- **Boarding panel:** seat rows ("PIKE ONE · name · gun · four call-in icons · READY ✓"), READY,
  everyone ready = 5 s lift, 30 s otherwise.
- **Transitions (owner 2026-11-09: "fine with the Roblox loading screen for now"):** fade to
  black with the helicopter sound, Roblox's own loading screen while the place teleports, then
  fade in on the pad with the drop-off sound. Between missions on the same server: the same
  fade and rotor, the next map is built, fade in with the drop-off. No custom ride card or
  teleport screen. The tally and the CONTINUE / STAND DOWN vote are a simple panel before the
  fade; staging keeps its one line ("WAITING FOR SQUAD 2/3").
- **No tutorial level:** a one-line hint the first time each action is possible ("HOLD [G] to
  aim"), and Control's radio lines.
- **Results that tell the run:** STAND DOWN / SQUAD WIPED, mission rows, a squad table (kills,
  revives given, times downed, call-ins, one award each: "Kept the squad up"), containment
  25% -> 37%, merits counting up to the next item. Lobby arrival card: what's newly on issue,
  OPEN KIT / CARRY ON.
- **In-match readability:** objective, LZ and pallet world markers; a squad roster with downed
  arrows; "HAMMER · inbound 4s" then "HAMMER · 7 down"; extraction "ON THE PAD 2/3".

## Order of work

Each step is small and playtestable on its own. **Phase 1 needs no lobby and no save: you can
feel it this week.**

**Phase 1: make one mission feel great** (Tien + Claude, match side)
1. Kill burst colour + a kill-confirm sound. **Built 2026-11-10** (dark blood burst; a soft
   tick for the killer, `Config.Audio.KillConfirm`); needs a listen in a playtest.
2. The start becomes a choice: the site marker shows early, the squad starts the Primary;
   one of the three laid-out sites picked at random; a Misdrop crate ~0:30.
3. Rewards that land: starting reserve about half (the first pallet matters); the Warden's
   upgrade cards at the hold's end, not at extraction; Warden chest plate 500 -> 400 (fight
   100-120 s). **Built 2026-11-10, not yet playtested** (PROGRESSION > Guns, Field upgrades).
4. Extraction 30 -> 60 s with a second wave; revives per mission. **Built 2026-11-10, not
   yet playtested** (PROGRESSION > Operation).
5. Readability: world markers, squad roster, call-in inbound/kill cards.
6. Results that tell the run (squad table, awards).
7. Voiced Control for five beats (insert, site up, pallet inbound, Index moving, bird inbound),
   soft clips.

**Phase 2: the operation** (Tien + Claude)
8. Chain three missions on one server (Delta three times as a stand-in): the tally panel,
   CONTINUE / STAND DOWN, fade to black with the rotor, fade in with the drop-off, carry and
   reset rules, the loadout on the ride.
9. The dead return on the next pallet.

**Phase 3: lobby <-> match live** (Nova lobby side; Tien publishes)
10. Nova: send the `Rules/Handoff` shape, reserve once per lift, boarding panel with seat rows
    and READY, the kit sheet in the lobby, the fade-to-black + rotor on lift, arrival debrief.
11. Publish both places, `Config.Places.Lobby`, the live round trip.

**Phase 4: progression** (Tien + Claude save + match; Nova desks)
12. Save service (ARCHITECTURE F9, versioned profile), merits paid at mission end (built
    2026-11-10 on the lobby's record), `Price` on item rows.
13. Lobby: desks open items, NOT ON ISSUE rows, the saved loadout, grade on the name tape.

**Phase 5: reasons to return**
14. Containment Board writes for real (with decay); the Plot shows it.
15. FRAGO, then the Corridor Order.
16. Objective pools in full; Mile 14 + its Index, then Kestrel; Second Pass; modifiers.

## Decisions for the owner (recommendation first)

1. **Stand Down after any mission** (the short session)? **Yes.**
2. **The dead come back on the next pallet** (4 per mission)? **Yes.**
3. **Field upgrades carry across the operation?** **Yes.**
4. **Merits only from missions, never per kill?** **Yes.** (Two currencies, merits and tabs: decided by the owner, 2026-11-10; `docs/OWNER.md`.)
5. **Starting kit and prices** as above? **Yes, tune by playtest.**
6. **Grades cosmetic only** (no levels that add anything)? **Yes.**
7. **One kit sheet behind every desk and on B** (not four desk menus)? **Yes.**
8. **Loadout changes only on the ride; retire the in-mission LZ Arms Room**? **Yes, once the
   lobby ships.** (Touches Nova's files: agree it with him.)
9. **No tutorial level, first-time hints instead?** **Yes.**
10. **The Goose moves from the primary slot to a support call-in before pricing**? **Yes**
    (a rocket as a primary breaks "sidegrade").
11. **Names:** the Carrier, merits and tabs (decided by the owner); Service Record, FRAGO, Corridor Order, polearm team callsigns, HRD =
    Harlan Recovery Detachment. **Yes** (lore developer writes the canon once approved).

## Loose ends found while planning

- Nova's lobby lore names the default gun the M4A1 carbine; the game issues the M16A4.
  Recommend the M16A4 (modelled and tuned).
- Nova's lobby lore calls HRD's meaning open; main's LORE already says Harlan Recovery
  Detachment. Keep main's.
- The Primary objective "Recover the Record" shares the word: on screens always say "Service
  Record" in full for the meta one.
- The Mile 14 design pack lives only on Tien's machine (branch `claude/mile14`, never pushed).
