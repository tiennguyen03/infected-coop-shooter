# The game loop: pick a mission, squad up, fight the city war (design, 2026-11-20)

Owner: Tien. Designed with the systems designer and the level designer (2026-11-20).
Status: design, approved in conversation piece by piece; this doc awaits the owner's read.

## Why

The owner has been shipping cool features (guns, attachments, the ATV, the Visitor) but the
game has no loop that ties them together: you can only play Checkpoint Delta, the map room
does nothing, and a squad forms by standing in a ring on the flight deck. He wants **one
simple loop that plays, built to scale**, so the gear chase has a purpose.

The direction (owner's words, condensed): players chase cool guns, loadouts, vehicles
(moddable later), the Visitor's experimental weapons, and later boss fragments and event
weapons (a Warframe touch). **The unifying purpose across every server is clearing the
Infected's coverage of the city** (Helldivers' shared war, an original city). Later: events
with special bosses and special weapons. Tone: Helldivers + Warframe, inspired by Resident
Evil and Prototype 2.

## Goals

- The loop: Carrier -> map room table -> pick a mission -> invite a squad from a UI -> play ->
  home with rewards -> spend -> pick again.
- Two missions: Checkpoint Delta (as today) and **Mile 14 on the Blender v2 layout** with its
  own objectives.
- A shared, cross-server city war the map room shows and every mission moves.
- Reasons to pick one mission over another.
- Scales to new missions, events and "DLC" as data, without new places to publish.

## Non-goals (this plan)

- Several missions chained on one server (superseded by 2026-11-18: mission -> Carrier ->
  next mission). Matchmaking with strangers. Joining a mission already running.
- The Driver (Mile 14's real boss), boss fragments, events, a third currency.
- Mile 14's full art: sprint 1 is a grey-block v2 frame; dressing comes in sprint 5.

## Anti-goals (a failure even if it works)

- Progress a client can fake, or a board that one server can overwrite.
- A new Roblox place per map (manual publishing per place, version drift between places).
- Stat power for money or grind: unlocks are new options, never stronger versions
  (`docs/OWNER.md`; Kit Mods' ranks stay the one exception).
- Delta playing differently after missions become data.
- Punishing a loss: a lost mission never pushes the war back.

## Constraints

- Server authoritative; up to 4 players; state per Player or per run (`AGENTS.md`).
- Tuning in `Config.luau`, per-item values on the item's own row; remotes, messages and
  attributes in their modules; pure rules in `src/shared/Rules/` with a spec first.
- DataStore and MemoryStore budgets: one war write per mission end per server.
- PC first (`docs/OWNER.md`); still measure frame rate on Mile 14 v2.
- Nova owns `src/lobby/` and the loadout screens. **Owner's call (2026-11-20): Claude builds
  the lobby side too; Nova reviews each PR**, with a heads-up in every `handoff/log/` note.
- Build on the current test mix (`claude/test-mix-6`: main + #86-#99), one PR per sprint.

## Approaches considered

1. **One match place builds any mission from a catalog (picked).** Maps are already built by
   code (`ArenaService` builds `Missions.current()`), so a second place adds only cost. A
   catalog row may name its own place for a map that ever truly needs one (hand-painted
   terrain), so nothing is locked in. Accepted cost: one Streaming setting for every map
   (target 384), and every mission's assets live in one place.
2. **A published place per map** (`mile14.project.json` today). Rejected: each place is a
   manual publish from `main`, places drift out of version, and each has its own Streaming,
   `Config.Places` id and return route. Ten missions plus events = a dozen places to keep in
   step.
3. **Teleport data carries the mission.** Rejected for the pick itself: a client can alter its
   join data. Loadouts keep riding in teleport data (already re-checked by the match).

Order of work considered: loop first (picked), Mile 14 art first (slower to a loop), war
board first (pointless with one mission).

## The design

### 1. The loop

1. Spawn on the Carrier; fix your kit at the desks.
2. Walk to the map room table (the Plot), press E: the **Mission Board** opens. The paper map
   with each district's percent and band, and one card per open mission.
3. Pick a card: you are a party of one, its leader. Invite from the **party panel**.
4. Everyone READY, the leader presses DEPLOY: fade, rotor sound, one reserved server, one
   teleport for the party. Empty seats get bots (as today).
5. Play the mission (pools, side objectives, boss, extraction: unchanged systems).
6. Fly home. The debrief shows merits, the district line ("MILE 14 +1.5%"), unlock progress.
7. Spend, back to the table.

The helicopter pad rings retire; the helicopter stays as the lift-off moment.

### 2. Mission catalog (scalability)

New `src/shared/MissionCatalog.luau`, one row per mission:

| Field | Example | Notes |
|---|---|---|
| `Id`, `Name`, `District` | "mile14", "Mile 14", "MILE 14" | District = a war district id |
| `Layout` | "Mile14" | the `src/server/Missions/<Layout>` module |
| `Pool` | "mile14" | `ObjectiveDefinitions.Maps` key |
| `Boss` | "warden" | Mile 14 uses the Warden as a stand-in (owner 2026-11-20) |
| `Pay` | `{ Win = 140, Partial = 70 }` | default `Config.Merits` |
| `Points` | nil | optional override of the war points |
| `Unlock` | nil | `{ District = "delta", Percent = 50 }`; Delta and Mile 14 open from day one (owner) |
| `Window` | nil | `{ From, To }` os.time; nil = always open (events) |
| `Lighting`, `Players` | "night", 1-4 | |
| `Place` | nil | optional own PlaceId; nil = the shared match place |

A new mission or event = a catalog row + a layout module + a pool row.
`Config.Operation.Missions` and `Handoff.DEFAULT_OPERATION` retire. `mile14.project.json`
retires once Mile 14 launches from the lobby (keep it until then for testing).

### 3. Passing the mission to the match

- The lobby calls `ReserveServer`, gets the access code and `PrivateServerId`, and writes
  `launch:<PrivateServerId> = { mission, party }` to a MemoryStore HashMap (10-minute
  expiry) before teleporting.
- The match reads the key at boot, before building the map, and builds that mission. It
  re-checks the row's `Unlock` and `Window` against the war record.
- Studio and a failed read: fall back to a `mission` field in `Rules/Handoff` launch data,
  then to the workspace `Mission` attribute, then to Delta.

### 4. Missions become data (Delta plays exactly as before)

Delta-only code moves onto the mission file (`MissionTypes.Mission` new fields):
`Size` (Delta 600 x 600, Mile 14 640 x 900; today `ArenaService` HALF = 300), `Landing`
(insert pad; today `Config.Extraction.ZonePosition`, read by `ArenaService.landingPoint`,
`buildHelipad`, `InsertionCutscene`, `LoadoutService`, `EnemyService.populate`), `Extract`
(defaults to `Landing`; read by `ExtractionService`), `AltPad` (hard-coded (255, 85) today),
`Boss = { Spawn, Waypoints, WaypointRadio }` (replaces `Config.Index.Warden.SpawnPosition` /
`Waypoints`), `Hold` (the single-hold fallback), `Population` posts, `Parts`, dressing `roll`.
The builders that run on every mission (`buildRoads`, `buildHighway`, `buildLandmarks`,
`buildPerches`, `buildGantry`, the alt helipad) move into Delta's data or are gated by it.
Objective modules lose their Delta words: `Sanitize`'s prompt words, `SilenceAlarm`'s
target name, `LightsOn`'s lamp names become row fields.

### 5. Mile 14 (v2 layout, night, quiet)

Identity: a one-way night walk down a dead evacuation convoy. Land at the Toll Plaza with
Harlan burning behind; reach the Rest Stop pad ~640 studs south past 24 sealed buses. Every
shot wakes the lane (Nova's awareness system), so the squad picks its route (the Jam, the
fields' cover, the Culvert under the deck) and when to go loud. The ATV is the getaway.

Frame x +-320, z +-450 (`assets/3d/build/mile14_v2.py` on `origin/claude/mile14-v2`).

- **Insert:** main pad (130, 12.6, 310), admin lot. **Extract (one-way, owner):** alt pad
  (-262, 0.4, -195), the Rest Stop.
- **Main pool** (`ObjectiveDefinitions.Maps.mile14`):
  - **Burn the Buses** (new row on the `Sanitize` module, weight 1.5): fuel cans at
    (-11.5, 12.6, -160), (20.5, 12.6, -246), (-11.5, 12.6, -366); position (16, 12, -246),
    StartRadius 60. Boss bursts from the lead bus (-16, 12, -400).
  - **Secure the Site:** Overpass span (0, 26.5, 80) 28x28; Toll Plaza (0, 12.5, 260) 46x46;
    Rest Stop (-190, 0.6, -255) 46x46. Hocker stands and boss origins per site as in the
    level designer's note (span: Hockers (-50,12,50), (50,12,110), (90,26,80), boss
    (-70,26,80); toll: (-80,12,300), (0,12,370), (110,12,270), boss (-80,12,236); rest stop:
    (-63,12,-160), (-50,12,-260), (-280,0,-290), boss (-70,0,-320)).
  - **Restore Comms:** radio at the water tower knoll (225, 8.6, -350).
  - **Confirm Casualties:** Weigh Station (150, 0.5, -185); spawns (80,0,-180), (160,0,-170),
    (215,0,-185), (240,0,-140), (160,0,-235), (95,0,-235).
  - **Recover the Record:** toll office door (154, 12.6, 341) to the span (0, 26.5, 80).
- **Side:** **Kill the Horn** (new row on `SilenceAlarm`, weight 1.5): bus at (16, 12, 186),
  hold E 4 s at the cab (21.5, 13, 168); a 200-stud noise pulse every 6 s until silenced
  (`Noise` row field through `EnemyService.noise`). **Lights On** (Weigh Station generator,
  switch (142, 3, -172.8)), **Misdrop** ((-200,0,250), (230,0,10), (-250,26,80)), **Clear
  the Spitters** ((0,12,-425), (-110,0,-50)).
- **Stores:** (62, 12.3, 330), (228, 0.3, -160), (-238, 0.3, -286). Flare drops on open sky
  only (no canopies).
- **Infected:** placed sleepers at named posts (the Jam, under the span, the Drop, the Halt,
  both lots); once loud, roaming and waves from beyond both barricades (0, 12, +-445) and
  the east and west pine lines.
- **Boss:** the Warden as a stand-in; the Driver is designed and built before players get
  Mile 14 for real (owner 2026-11-20; a later plan).
- **Cover (Claude's call):** v2's four fields are empty; v1's woods and brush (~120 trees)
  go into them in sprint 5, budgeted with the cars. Stealth needs cover.

### 6. The city war (shared by every server)

New pure `Rules/War` (spec first), `Config.War`, and a `WarService` in the match.

- Stored per district, one shared record per season: `{ pct, at, unlocked, secured }`.
- A mission brought home adds points to its district: **Win 3, Partial 1, Loss 0**, per
  mission, not per player; **2 points = 1%**. `merge(old, add, now)` applies decay since `at`,
  adds, clamps 0..100, sets `at`. `shown(rec, now)` applies the same decay for display.
- **Decay 0.25% an hour** (about 6% a day). **A loss never pushes the war back** (Claude's
  call: punishing losses keeps people off the hard districts).
- **50% opens the next district** (stays open for the season). **100% = Secured:** locked for
  the season, no decay, missions there pay x0.25.
- **Season: 4 weeks or until every open district is Secured** (Claude's call); the map resets
  to its start values; personal unlocks are kept. Store/key carry the season id (`War_S1`).
- Only the match server writes, once per run end, with UpdateAsync (the `TallyService`
  pattern, retries, BindToClose), capped by `MaxWritesPerServerHour = 6`. The lobby reads
  every 60 s (`Config.Containment.RefreshSeconds`). Clients never send progress.
- `PointsPerPercent` is tunable live (ConfigService) because the right speed depends on how
  many people play.
- The board's start values are today's placeholders (`Config.Containment.Districts`).
- **Seen in the map room:** districts shaded by band, red hatching shrinking as the percent
  rises, percent with a rising/falling arrow, locked districts read "CLOSED: MILE 14 TO 50%",
  the current Order pinned to the board.

### 7. Why pick one mission over another

- **HARLAN Orders:** one at a time (`Config.War.Orders` rows `{ Id, District, Target, Ends,
  Merits, PayBonus }`), e.g. "Push Mile 14 to 50% by Sunday": its card has a gold border and
  pays +25% while it runs; success pays every soldier +300 merits on their next Carrier visit,
  helped or not. The record keeps claimed Order ids.
- **District unlocks:** the record counts wins per district (`wins.<district>`, written by
  `MeritService` in the same UpdateAsync as the pay). Gun and attachment rows gain an optional
  `Unlock = { District = "mile14", Wins = 3 }` next to `Price`; the shop shows "3 MILE 14
  WINS · 400 MERITS". Still bought with merits; a sidegrade. Mile 14 gates night optics and
  suppressors, Delta breaching shells and heavy barrels (exact items: tuning). Boss fragments
  later reuse the field (`Unlock = { Fragments = "warden", Count = 5 }`).
- **Feel and pay:** Delta a stand-up fight at a fortified checkpoint; Mile 14 quiet, at night,
  pays more (Win 140 / Partial 70).

### 8. Party panel and invites

New lobby `PartyService` (state per leader, up to 4) and `PartyUI`.
- Same server: click a name, INVITE, they get ACCEPT / DECLINE.
- Friends elsewhere: `SocialService:PromptGameInvite` with `LaunchData = "party:<leaderId>"`;
  on arrival the lobby adds them if the leader is in that server, otherwise shows "Join
  <leader>" which teleports them to the leader's server.
- The leader's mission pick shows to the whole party. All READY (or 15 s after DEPLOY), then
  one reserve, one MemoryStore write and one teleport. Solo = a party of one + bots.

## Sprints (each ends playable; one PR each)

1. **Pick a mission.** Catalog; missions as data (Delta unchanged, checked by playing it);
   Mile 14 grey v2 frame (hills, parts, ramps, span, Culvert, pads, buses as blocks, the
   jackknife) with every objective above and the Warden stand-in; MemoryStore launch; the
   table prompt and Mission Board UI; `LaunchService` takes a mission id (pad rings still
   work this sprint).
2. **Party panel and invites.** `PartyService`, `PartyUI`, DEPLOY; the rings retire.
3. **The war goes live.** `Rules/War` + spec, `WarService` flush at run end, the board's real
   read, the map shading, the debrief line.
4. **Reasons to pick.** Orders, `wins.<district>` on the record (SaveSchema bump,
   `docs/SAVES.md`), `Unlock` on item rows and the shop text, per-mission pay.
5. **Seasons, events, Mile 14's art.** `Window`, featured mission, season reset, live tuning;
   Mile 14 v2 woods and brush first, then kit, signs, cars last, measured with the
   MicroProfiler after each batch (200k tris of dressing; 256 colliders; at most 20 lights).

## Calls made after the builder check (Claude, 2026-11-20; the owner can overturn any)

1. **Delta XL** stays a test switch (`Config.DeltaXL.Enabled`, backlog call 14) and is the
   same "delta" card, not a second one. The mission fields allow a landing and pickup
   **chosen at run time**: `Landing` / `Extract` may be a fixed point or the name of a picker
   (`DeltaXL.chooseDrop` / `choosePickup` today), and the XL hooks in `ArenaService`
   (`bigMap()`, `XL_AT_BOOT`) move onto Delta's mission data. Sprint 1 must leave XL working.
2. **Unlock order** is the board order (`Config.Containment.Districts`: Delta, Mile 14,
   Kestrel, The Yard, Reservoir). Delta and Mile 14 start open; Kestrel opens when Mile 14
   reaches 50%, and so on. A district with no mission yet is drawn on the map with "NO
   OPERATION YET", is never counted as open, and does not block the season's early end.
   A Secured district's mission can still be picked, at x0.25 pay and no war points.
3. **Sprint 1 launch, before the party panel:** DEPLOY on the Mission Board launches the
   picker alone with bots into the picked mission. The pad rings keep launching Delta as
   today until sprint 2 retires them. Sprint 2 replaces "alone" with "the party".
4. **Boss entry:** an objective's own boss origin (`BossFrom`, as in the boss-in-objectives
   work) wins when it has one; otherwise the mission's `Boss = { Spawn, Waypoints }` route.
   Mile 14's Restore Comms, Confirm Casualties and Recover the Record use the route; the
   route starts beyond the south barricade (0, 12, -445) and walks north up the lane.
5. **Mile 14's layout file:** the owner chose v2, so `src/server/Missions/Mile14.luau` is
   rewritten to the v2 frame (not a second layout), and the v2 generator
   (`origin/claude/mile14-v2`, PR #26) comes into sprint 1. Nova's awareness settings
   (`Config.Awareness.Missions.mile14`) keep their key and carry over; Nova's v1 woods return
   in sprint 5's cover pass. Nova reviews this in sprint 1's PR (heads-up in the log note).

## Left to the builder

File layout inside each sprint, UI layout of the board and party panel (through the
ui-ux-designer brief, Prototype 2), exact Order texts, which items each district unlocks,
the grey frame's block shapes, test cases beyond the named specs.

## Docs that change when this lands

`docs/PROGRESSION.md` > The Containment Board (the war paragraph), > Missions (Mile 14);
`docs/OWNER.md` > The game (the loop line, after the owner says yes); `docs/ROADMAP.md`
(the three-missions-on-one-server shape is superseded); `docs/LEVELS.md` (Mile 14 v2);
`docs/BACKLOG.md` §7 item 6.
