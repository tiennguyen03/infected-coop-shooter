# Carrier v2: the lobby ship revamp (proposal, 2026-11-16)

**State:** proposal with pictures, built in Blender only. Nothing in `src/` changed and the lobby
still loads v1 (`docs/sprints/LOBBY_V1_FALLOW.md`). The owner approves the look first; then
Nova (or anyone) follows "Putting it in the lobby" below.

Owner's ask (2026-11-16): "revamp the lobby map in Blender. Don't completely change it, just
revamp it. Make it feel more like a ship... right now the Carrier seems too plain... on the shore
it should show a destroyed city with burning skyscrapers... little Easter eggs on the ship."

Second ask (2026-11-17): "there needs to be sections for the vendors, and make the sections look
cool. Like they have their own little corner and they're sitting there chilling, smoking a cig or
something like that. Try to make them all different... Make them feel like real characters trying
to help you." And: "Completely get rid of the plot walls... too awkward to walk in and out of...
people are gonna be cramped." See **Vendor corners** below; the map room is open floor.

Pictures: `assets/3d/build/previews/carrier_v2_*.png` (62) and `vendor_*.png` (11), copied to
Desktop `Carrier_v2`. Open `vendor_overview.png` first, then one `vendor_<corner>.png` each.
`pair_<view>_before/after` are the same camera on today's ship and on v2. **Every preview is the
mirror image of the game left to right** (Blender Y = game Z), like every earlier ship preview.

## Why today's Carrier reads plain

Rebuilt as a true "before" (`carrier_v2.today()`, same layout, meshes, lights and text as v1):

1. The hangar is one 66 x 240 x 18 box in one wall colour: no frames, no deckhead beams, no pipes,
   no doors, three lights. It reads as a warehouse, not the inside of a ship.
2. Each desk is a 7-stud counter on empty floor with a sign; nothing around it says what the
   person sells or does.
3. Half the hangar (aft of the map room, Z -100 to -10) and the forward flight deck (Z 80 to 210)
   are empty floor.
4. The flight deck is bare asphalt with one dashed line and four circles: nothing parked, tied
   down, lit or stored. The rails are solid yellow slabs.
5. The shore is green hills 900 studs ahead with smoke; nothing tells you what you are fighting for.

## Lore note (lore developer)

- The Carrier is a reserve-fleet helicopter carrier off the Harlan coast, hull number painted out,
  HARLAN sprayed on the island (canon, `docs/LORE.md`). v2 adds crew life, not new story: a ship
  that has been at this for 214 days.
- **The city on the shore** is the city the squad is retaking (owner's city campaign direction,
  2026-11-16). Players read it only as "the city". **Canon flag:** `docs/lore/world_map.md` has no
  city yet; this proposal puts it on the coast off the Carrier's port side (code -X), at the foot of
  Route 9 below Checkpoint Delta ("the army checkpoint on the highway out of the city"). The
  hills and Burn sites ahead (Z 900) stay. The lore developer adds it to the world map when the
  owner approves.
- The map room is labelled MAP ROOM, not THE PLOT, because THE PLOT is on the owner's list of made-up
  words to change (BACKLOG Q3). Owner's call.

## Level-design note (level designer)

Same footprint, routes and spots as v1 (`FallowLayout`): spawn, the three desks, the Arms Room,
the map table, the ramp, the four spots, the lift balcony. Nothing moves that the code reads. What
changes is how each space reads as a ship:

- **Hangar:** frames every 12 studs with deckhead beams, pipe runs along both hulls, watertight
  doors, fire stations, painted floor walkways with stencilled directions (CALL-INS, ARMS ROOM,
  RAMP, FLIGHT DECK, MAP ROOM), hazard edges on the ramp, sodium lights.
- **Desks:** each desk is a place. Arms Room: a cage to the deckhead with the gun wall (room for
  16), a kit shelf and ammo (Quartermaster sells guns, grenades, most kit). Call-ins: a show floor
  with every call-in as a real object and its placard (the Doorman sentry, Tripline mines, a crate
  of Hammer shells, Anvil binoculars on a map, Shrike, concertina wire, supply crate). Loadout:
  the Loadmaster's hoist, weighed cases and a TODAY'S LIFTS board. The Fires desk is gone; its
  wall holds the districts' tally board.
- **Map room:** open floor, no walls (owner 2026-11-17): a darker painted deck with a yellow border
  and MAP ROOM on the floor, a MAP ROOM sign hung from the deckhead on the walk side (read from
  both sides), the table, four consoles, the board of where the Infected are, the two clocks on
  the hull over the board, the tally board on two posts. Walk in from the walk, fore or aft.
- **Aft hangar:** Nova's motor pool (three painted bays, the ATV in the middle one, tool chests,
  the fuel point, a rack along the hull) with the motor sergeant at its front; the half court
  with a hoop and the memorial net on the aft bulkhead; the restricted cage (future vendor) in
  the port aft corner. Helicopter 20 on jacks is gone: the motor pool took its floor.
- **Flight deck:** bigger yellow boarding rings ("BOARD HERE"), the separate square gone; a red foul
  line; flood masts; tie-downs and chocks; the island dressed (vents, lights, flags, life rings,
  door); a ship's crane and boat; a deck-gear park (crash crane, tractor, pallets, drums); a
  stores-drop box forward; containers; pipe rails with posts instead of yellow slabs.
- **Shore:** the burning city off the port side, seen from the whole flight deck, the lift balcony
  and through the hangar's lift opening.

## Layout (top-downs)

`carrier_v2_topdown_flight_deck.png`, `carrier_v2_topdown_hangar.png` (labels), and their
`pair_topdown_*_before` pictures. Coordinates below are the game's (`FallowLayout`): X across
(+X is the island side), Y up (deck 40, hangar floor 20, sea 0), Z along (+Z is the bow).

| Space | Where (X, Z) | Notes for the planned changes |
|---|---|---|
| Spawn | (0, 120) | unchanged; crew corner and arcade behind it |
| Arms Room, Quartermaster | cage X -33..-22, Z 105..140; feet (-26.6, 124) on his stool | main seller (PR #57); gun wall room for 16 |
| Call-ins seller | feet (27, 105) facing -X, no counter; show floor X 17..33, Z 90..139 | PR #57 renamed the desk `callins`; PR #61's display row sits on this floor |
| Loadmaster | feet (-2, 88) facing +Z, no counter; hammock posts (-7.2, 88), (3.2, 88) | keeps loadouts; hoist (3.5, 84), cases (-7.5, 84.5) |
| Map room | `FallowLayout.Plot` X 4..33, Z -10..30, **no walls** | table unchanged; tally board on posts at X 4, Z 17..27 |
| Motor pool, motor sergeant | feet (9, -48) facing +Z; bays as `FallowLayout.MotorPool` | Nova's PR #65; her bench X 2.6..7.2, dog X 11..14 |
| Restricted cage (future) | X -33..-25, Z -73..-45, gate Z -61..-57 facing +X | nothing sells there yet; see Vendor corners |
| Spots 1-4 | helo X -12, Z -150 + 45 i | boarding is the yellow ring (PR #55) |
| City | quay X -560, Z -700..900; towers X -640..-720 | see "Shore" |

## Kit pieces (new meshes, `assets/3d/build/carrier_kit.py`)

All are in the game frame, pivot at the base. Count is how many v2 places; tris per copy.
Placement is in `carrier_v2.py` (`hangar_v2`, `flight_deck_v2`, `desks_v2`, `hangar_life_v2`,
`eggs_deck_v2`, `shore_v2`); first copy listed, the rest are in the code.

| Piece | What | Count | Tris | First placement (X, Y, Z) |
|---|---|---|---|---|
| `env_carrier_rib` | hull frame + deckhead beam stub | 32 | 72 | (-33, 20, -88), every 12 Z both hulls |
| `env_carrier_pipes` | pipe run along a hull bay | 31 | 104 | (33, 20, -94), between the ribs |
| `env_carrier_door` | watertight door with wheel | 7 | 184 | (15.5, 20, 140) fore bulkhead |
| `env_carrier_firestation` | hose reel, extinguisher, red board | 5 | 152 | (33, 20, 87) |
| `env_carrier_ramp_trim` | ramp pipe rails, hazard edge, cleats | 1 | 432 | (-20, 20, 80) |
| `env_carrier_deck_rail` | 10-stud deck-edge rail with posts | 24 | 96 | (-30.1, 40, 25) |
| `env_carrier_floodmast` | deck flood light mast | 5 | 180 | (-34, 40, -125) |
| `env_carrier_tiedown`, `_chock` | tie-down cross, wheel chock | 16, 8 | 48, 16 | round each spot |
| `env_carrier_island_kit` | vents, lamps, flags, life rings, door on the island | 1 | 1,464 | (0, 0, 0) |
| `env_carrier_ship_crane` | deck crane | 1 | 560 | (30.5, 40, -19) |
| `env_carrier_boat` | ship's boat in davits | 1 | 164 | (41, 26.5, 20) |
| `env_carrier_decon` | screening lane decon arch | 1 | 276 | (24, 40, -150) |
| `veh_carrier_tractor` | tow tractor | 3 | 412 | (27, 40, -92) |
| `veh_carrier_crash_crane` | crash crane | 1 | 404 | (27, 40, -64) |
| `prop_carrier_toolchest` | red tool chest | 3 | 164 | (9, 20, -56) |
| `prop_carrier_pallet_net` | netted pallet | 6 | 156 | (28, 40, -108) |
| `prop_carrier_crates`, `_drums` | crate stack, drum group | 3, 3 | 96, 348 | (26, 40, 132), (29, 40, -126) |
| `prop_carrier_engine_stand` | engine on a stand (motor pool bay 3) | 1 | 200 | (18, 20, -66) |
| `prop_carrier_blade_rack` | rack along the hull (stands in for the motor pool tyre rack) | 1 | 120 | (33, 20, -89) |
| `prop_carrier_hoist` | Loadmaster's hoist | 1 | 168 | (3.5, 20, 84) |
| `prop_carrier_scale_cases` | weighed cases on a scale | 1 | 96 | (-7.5, 20, 84.5) |
| `prop_carrier_console` | map-room console | 6 | 176 | (7, 20, -7.8) |
| `prop_carrier_kitshelf` | Arms Room kit shelf | 1 | 332 | (-28.2, 20, 139.6) |
| `prop_carrier_ammo_stack` | ammo boxes | 2 | 96 | (-30.6, 20, 134.5) |
| `prop_carrier_crew_corner` | bunks, lockers, kettle | 1 | 332 | (-3, 20, 139.9) |
| `prop_carrier_placard` | call-in name stand | 7 | 36 | (17.9, 20, 134) |
| `prop_callin_hammer` | crate of Hammer shells | 1 | 616 | (19.5, 20, 116) |
| `prop_callin_anvil` | binoculars, map, radio | 1 | 452 | (29.6, 20, 119) |
| `prop_callin_shrike` | Shrike on a stand | 1 | 416 | (29.5, 20, 134) |
| `prop_callin_tripline` | mines and wire | 1 | 536 | (21.5, 20, 125) |
| `prop_callin_concertina` | coil of wire | 1 | 336 | (28.6, 20, 92.2) |
| `prop_callin_supply` | supply crate | 1 | 156 | (21, 20, 96.5) |
| `env_shore_card_a/b/c` | flat far-skyline cards | 3, 4, 3 | 34-44 | X -860 and -1040 |
| `env_shore_waterfront` | quay, sheds, cranes | 5 | 572 | (-560, 0, -640), every 310 Z |
| `prop_vendor_quartermaster` | stool, reading lamp, bell, side table (kettle, mug, radio), photo, calendar | 1 | 620 | (-26.6, 20, 124) |
| `prop_vendor_callins` | seat crate, crate table, shell-case ashtray, field phone, cutters, MIND THE COILS board, caged bulb | 1 | 452 | (27, 20, 105) yaw 180 |
| `prop_vendor_loadmaster` | hammock on two stanchions, flight bag, cool box desk, salvaged cabin door, blue lamp | 1 | 392 | (-2, 20, 88) yaw 90 |
| `prop_vendor_motor_pool` | tyre seat, bench with vice, clamp lamp, log book, thermos, the dog on a tarp | 1 | 520 | (9, 20, -48) yaw 90 |
| `prop_vendor_watch` | swivel chair, stool with three mugs and phone, gooseneck lamp, folded cot, pack | 1 | 356 | (26.8, 20, -3) yaw 180 |
| `prop_vendor_restricted` | sealed cases, locker, folding chair with raincoat, chessboard drum, document case, caged bulb | 1 | 472 | (-25, 20, -59) |

Vendor corner pieces are drawn in the person's frame: origin at their feet, +x the way they face.
The posed people (`npc_carrier_*`, 216-276 tris each) and `ref_carrier_atv` are picture
stand-ins only: registered with `register(ba, npcs=True)` from `carrier_v2`, never exported, not
counted (the game draws its own rigs and the ATV from `VehicleBody`).

The Doorman on the show floor is the uploaded `ref_doorman`; the city towers are the match's
uploaded `env_city_*` (office, residential, deco, glass, ruined, midrise), 15 of them at X -640
to -720, scaled 0.62, several tilted, each with burnt gashes. Fire, smoke and searchlights
(`fx_fire`, `fx_smoke`, `fx_beam`) are Blender stand-ins for particles and Beams in game, not meshes.

## Easter eggs (11; helicopter 20 gave its floor to the motor pool)

| # | What | Where (X, Y, Z) | Mesh |
|---|---|---|---|
| 1 | Ship's cat asleep in a mortar crate, "DO NOT LOAD THE CAT" (the sapper feeds her) | call-ins floor (26.6, 20, 112.2) | `egg_carrier_cat` |
| 2 | The net: cargo net of wrist bands, helmets and green chemlights, "STILL ON THE LIST" | aft bulkhead (-22, 21, -99.9) | `egg_carrier_memorial` |
| 3 | Districts' tally board "MISSIONS HOME": Delta, Mile 14, Kestrel, the Yard, Reservoir | on two posts at the map room's walk edge (4, 22.6, 22) | `egg_carrier_scoreboard` |
| 4 | "DAYS SINCE ONE GOT ABOARD 214 / KEEP IT THAT WAY" | screening lane (24, 40, -133.2) | `egg_carrier_dayssign` |
| 5 | Broken arcade cabinet, "OUT OF ORDER" | crew corner (-14.5, 20, 137.4) | `egg_carrier_arcade` |
| 6 | Call-in tallies stencilled on the hull: HAMMER, ANVIL, SHRIKE, DOORMAN | over the call-ins floor, X 33 | text |
| 7 | (dropped 2026-11-17: helicopter 20 on jacks; its floor is the motor pool. `egg_carrier_queen_marks` stays in the kit, unplaced) | | |
| 8 | Stolen road signs "HARLAN 14", "CHECKPOINT DELTA" | fore bulkhead (-2, 29.2, 139.9), (8.5, 32.8, 139.9) | `egg_carrier_roadsign` |
| 9 | "NOT ON ISSUE" shelf: bat with nails, crossbow, chainsaw | Arms Room (-28.4, 20, 111.1) | `egg_carrier_notissue` |
| 10 | Lookout's post: big binoculars on the city, chair, flask, skyline log "STILL STANDING" with towers crossed off | port deck edge (-31.5, 40, 98) | `egg_carrier_lookout` |
| 10b | One tower still signals short-long-short in lit windows | glass tower (-690, ~264, -205) | Parts |
| 11 | Basketball hoop and half court | aft hangar (17, 20, -99.9) | `egg_carrier_hoop` |
| 12 | Two clocks, SHIP runs, CITY stopped and taped | map room, on the hull over the board (33, 34.5, 14) | `egg_carrier_clocks` |

## Vendor corners (2026-11-17)

Owner: each seller gets "their own little corner", "sitting there chilling", all different,
"real characters trying to help you"; plenty of room because four players will crowd them. One
kit mesh a corner (`prop_vendor_*`, table above), one posed stand-in each (`npc_carrier_*`),
one small light of its own colour. Pictures: `vendor_<corner>.png`; `vendor_overview.png` is the
hangar from above with labels; `vendor_hangar_walk.png` is the walk from the spawn.

**Lore note (lore developer role).** Who each person is stays canon (`docs/lore/desk_crew.md`):
rank, age, the one detail. What is new is a line of who they were before and why they help, and
the things they keep near them. **These lines are a proposal, not canon yet:** once the owner
says yes, the lore developer writes them into `desk_crew.md` (new canon: the motor sergeant's
bus depot and dog, the watch officer's home street, the future visitor). No names; jobs only.

**Level-design note (level designer role).** Every corner faces the main walk and backs onto a
hull, a bulkhead or its own kit, so nobody walks behind the seller. The open side is at least
14 studs across with nothing at knee height, room for four players to stand in a row and talk;
no counter except the Quartermaster's glass case (his corner was already open along X -22..0).
The Call-ins and Loadmaster counters are dropped (the seat crate and the cool box stand in), so
the soldiers see the whole person. The map room loses all its walls: you walk in from the walk,
fore or aft. Nothing in a corner overlaps the walk lines painted on the floor.

| Corner | Role, one line of character | Signature props | Pose (for animation later) | Light |
|---|---|---|---|---|
| **Arms Room** (port fore, feet (-26.6, 124) facing +X) | **The Quartermaster.** Thirty years behind cages like this; he counts every rifle out and every rifle back because once, long ago, a count came up short, and he would rather you leave with the right gun than the cheap one. | his high stool; a reading lamp on the glass turned onto his clipboard; a bell with RING ONCE; behind him a kettle on a hot plate, his tin mug and an old radio playing low; low on the gun wall a photo of his first arms room and a calendar with the days crossed off | **perched**: sits on the stool, leans on the glass on both elbows, reading glasses low, clipboard flat under his left hand, pencil in his right; idle: looks up over the glasses, taps the pencil | warm tungsten (255, 178, 102) under the lamp |
| **Call-ins** (starboard, feet (27, 105) facing -X) | **The sapper sergeant.** Cleared roads into the city with a mine roller before it fell; nine fingers and all the time in the world, he sells you a mortar like a man selling a car he actually likes, and he feeds the ship's cat. | an upturned mortar-bomb crate he sits on; a crate-table at his right hand with an ashtray cut from a 105 shell case full of ends, the hand-cranked field telephone and his wire cutters; a hand-painted MIND THE COILS board; one caged bulb on a cord; the cat in her crate by his boots | **sitting**: on the crate, forearms on his knees, a cigarette in the hand with the short finger, waving you over with the other; idle: a slow drag, flick ash into the shell case | amber bulb (255, 140, 50); the cigarette's ember |
| **Loadout** (ramp foot, feet (-2, 88) facing +Z) | **The Loadmaster.** Rides the door on every lift and naps in a cargo-net hammock between them; wakes up loud, remembers every face he has flown, and keeps the count of everyone he brought back on a door off a dead helicopter. | a cargo-net hammock on two yellow stanchions; flight bag under it; a cool box he uses as a desk (mug, clipboard); the salvaged cabin door with FLOWN BACK and the tally in grease pencil; TODAY'S LIFTS board beside him | **lounging**: sits sideways in the hammock, one boot on the deck, one arm behind his head, pointing you at the board with the grease pencil; idle: rocks the hammock with his boot | cabin blue (110, 170, 255) clipped to the post |
| **Vehicles** (motor pool front, feet (9, -48) facing +Z) | **The motor sergeant.** Fixed city buses at the depot before her reserve unit was called up; came aboard on the last convoy with a toolbox and a stray dog that would not get off the truck. She writes down which ATVs come back, and asks after the drivers second, but she asks. | two stacked tyres she sits on; a bench with a vice, a clamp work lamp bent over it, her log book and a thermos; a carburettor in her lap; the dog asleep on a folded tarp with water in a hubcap; tool chests behind | **tinkering**: sits on the tyres bent over the part in her lap, wrench in hand, looking up at you; idle: wipes her hands on the rag, scratches the dog | hard white work lamp (236, 244, 255) |
| **Map room** (open floor, feet (26.8, -3) facing -X) | **Control's watch officer.** Grew up on a street in the city off the port side; the postcard pinned to the board's corner is that street before. She has had the watch for 214 days, sleeps on a camp cot behind the board, and talks in places and times because it is easier than names. | a swivel chair tipped back; a stool with three steel mugs (all cold) and the sound-powered phone; a gooseneck lamp; the folded cot and her pack; the postcard on the board | **feet up**: tipped back in the chair, boots crossed on the map table's end, mug resting on her chest, one earcup on; idle: sits up to tap a district on the map | the map room's red, plus a small warm lamp on the stool |
| **Restricted cage** (FUTURE, port aft, X -33..-25, Z -73..-45) | **The visitor** (working title; owner idea, not built: a rotating seller of experimental government weapons). Comes aboard now and then on a helicopter that is not one of ours, with cases nobody else is cleared to open; polite, patient, no rank and no unit, and the Quartermaster will not stand near him. | a wire cage to head height with a padlocked gate, RESTRICTED / KEEP CLEAR; two sealed cases under seal tape and a locked tall case; a folding chair with his raincoat over it; a chessboard on a drum, a game half played against nobody; a document case; the hangar's one dead ceiling lamp overhead, a single cold bulb inside; the cage's back door goes into the hull | **waiting**: stands in the open gate, hands in his raincoat pockets, head slightly tilted; idle: moves one chess piece. When he is away the gate is shut and the chair empty | cold dim (170, 214, 226); nothing else lit |

Real-world rules: the owner asked for a cigarette. **Check Roblox's content rules on showing
tobacco before shipping it;** if it is not allowed, the fallback keeps the pose: an unlit
cigarette behind his ear and a match or a toothpick in his teeth, or a steaming tin mug in that
hand. The cigarette is two small boxes in `npc_carrier_sapper` (no smoke particles yet).

## Budgets: today vs v2 (measured by `carrier_v2.report`)

| | Today | v2 ship (11-16) | v2 ship with vendor corners (11-17) | v2 shore |
|---|---|---|---|---|
| Parts | 129 | 323 | 345 (9 stripe runs as one piece each) | (in the ship count) |
| Mesh instances / unique meshes | 44 / 16 | 245 / 65 | 240 / 69 | 30 / 10 |
| Triangles drawn | 16,558 | 49,490 | 49,478 | 24,070 |
| Unique mesh triangles (download) | 5,178 | 21,178 | 23,646 | 9,314 |
| Lights | 5 | 18 | 24 | 0 |
| Text labels | 17 | 84 | 96 | 0 |

The six vendor corners add 2,812 triangles; dropping helicopter 20 (body, trim, its jacks, engine
stand and chests moved) gave about the same back, so the ship's total did not grow. The posed
people are not counted (the game's rigs).

**Honest:** the ship draws about 3x today's triangles and is over STYLES' 18,000 ship cap. The
biggest share is not new: the four Lantern helicopters on the spots (`veh_lantern_trim` 1,436 a
copy). New weight: city towers, 31 pipe runs, 32 ribs, 24 rails, the island kit (1,464) and the
memorial (944). 24 lights in the pictures is over the 20 per place cap; in game use about 8 in
the hangar: the five vendor lights (small Range, Shadows off) and three sodium lamps, the other
fittings SurfaceLights or Neon. Run the performance-reviewer and
measure on a low-end phone before shipping; cuts in order: pipes every other bay, ribs as Parts,
rails as two Parts per run, city towers to cards past the near row.

## Rebuild and export

- Look in live Blender: `sys.path.insert(0, "<repo>/assets/3d/build")`, `import carrier_v2`,
  `carrier_v2.build_all()` makes scene `Carrier_v2` with collections `Cv2` (v2) and `Cv2_Today`
  (the before); `carrier_v2.show("v2"|"today")`, `carrier_v2.aim("<view>")`,
  `carrier_v2.render_previews()`, `carrier_v2.render_vendors()` (the 11 `vendor_*`). After editing the kit: `importlib.reload` both modules and
  `carrier_v2.drop_kit("<piece>")` before `build_all()`.
- Headless: `blender --background --python assets/3d/build/carrier_v2.py` (add `-- --no-render` to
  skip the 73 pictures) saves `assets/3d/carrier_v2.blend` (do not commit it).
- Export the kit with the rest of the meshes: `blender --background --python
  assets/3d/build/build_assets.py -- --carrier-v2` (opt-in flag; add `--only <names>` for some).
  `build_assets` rewrites `assets/3d/palette.png`/`palette.md`; restore them if only line endings changed.

## Putting it in the lobby (step list)

Land the open lobby PRs first and build on them: **#55** (boarding is the yellow ring,
`Config.Lobby.Launch.BoardRadius` 14; `Spot.board` is now `Spot.sign`, the `HELO · SPOT n` sign on
the ring edge), **#57** (Fires desk removed; desk id `engineers` is now `callins`, the
Quartermaster sells guns, grenades and kit), **#61** (call-in display: `FallowLayout.CallInDisplay`
origin (30.8, H, 105) facing -X, length 31, depth 3.6; each call-in's Config row has
`Display = { Prop, Width }`).

1. Owner approves the pictures (and answers the questions below). Lore developer adds the city to
   `docs/lore/world_map.md`.
2. Performance-reviewer on this doc's budgets; agree the cuts.
3. Move `--carrier-v2` into the normal build (register `carrier_kit` like `lantern`), export the
   approved pieces, upload to the group (Boomin Dev Studios), record ids in `Config` like the other
   `env_fallow_*`.
4. Add the coordinates above to `FallowLayout` as data tables (`Ribs`, `Pipes`, `Doors`,
   `FireStations`, `DeckGear`, `Eggs`, `Shore`), one row per piece. Do not move anything existing.
5. `FallowBuilder`: place each table through `FallowArt` meshes (no collision on overhead and
   wall pieces; collision on floor props players could walk into: tractor, crane, crates, drums,
   show-floor pieces, the vendor corners).
6. Call-ins: let #61's `CallInDisplay` place the real call-ins; use the `prop_callin_*` meshes as
   their `Display.Prop` (Hammer crate, Anvil binoculars, Tripline mines, concertina, Shrike) and
   the placards as its plates. Drop v2's own show-floor copies so there is one row.
7. Boarding: keep #55's ring and sign; v2's bigger "BOARD HERE" ring paint must use `BoardRadius`.
8. Shore: wrap the coast round to port (today it is only ahead at Z 900); near row = the uploaded
   `env_city_*` at 0.62 scale, far rows = the cards; fire as ParticleEmitters on 10-12 towers,
   smoke as 6 big emitters, 3 searchlight Beams; no lights on the shore.
9. Lighting: at most 8 lights in the hangar, Shadows off: the five vendor lights (Range 12 or
   less, their colours in the Vendor corners table) and three sodium lamps (paler orange, Range
   56 or less); every other fitting a SurfaceLight or Neon.
9b. Vendor corners (Nova, your files): in `FallowLayout.Desks` move the Quartermaster's `feet`
   to (-26.6, H, 124) and set `counter = false` on `callins` and `loadmaster` (their crate and
   cool box stand in); place each `prop_vendor_*` at its desk's `feet` and `facing` (+x of the
   mesh = facing). Each person's pose is an idle animation on its `NpcBody` (Pose column above;
   seated poses need the body lowered onto the seat); keep the `ProximityPrompt` reach from where
   soldiers stand, not from the seat. The motor sergeant's corner goes in front of `MotorPool`'s
   bays (her bench at X 2.6..7.2, the dog at X 11..14, both Z -49.6..-46). The restricted cage
   is scenery until the future vendor exists: gate shut, chair empty.
9c. Map room: delete the four `PlotWall` parts in `FallowBuilder.buildPlot` (owner: open floor);
   paint the floor and border instead; hang the MAP ROOM sign from the deckhead at X 4; put the
   tally board on two posts and the clocks on the hull over the board.
10. Text: stencils and signs as SurfaceGui text like today's signs; the tally board and count board
    stay static text for now (a live mission count is a later idea).
11. Live check with Studio MCP (`docs/STUDIO_MCP.md`): walk every route, every desk prompt, boarding
    from each ring, phone frame rate. Then publish the lobby place from `main`.

## Still weak

- The city reads as "burning" from the deck but the fire is flat orange cones and rectangles in
  Blender; it needs particles in game to sell it. The tower silhouettes repeat (six meshes).
- Over the triangle cap (above).
- The hangar is still one long hall; no overhead cable trays or hatches.
- Pictures show v2's own call-in floor, not #61's row; step 6 merges them.
- The people are blocky stand-ins posed with boxes; the game's NPC bodies and real idle
  animations will read better. The pictures use flat ambient light, so the vendor lights look
  softer than they will in game.

## Questions for the owner

1. City off the port side (seen from the whole deck and through the lift) or ahead where the
   hills are today?
2. MAP ROOM instead of THE PLOT? (The pictures and floor paint say MAP ROOM.)
3. Keep the 11 Easter eggs, or drop some (the arcade and the hoop are the lightest-hearted)?
4. "214 days": fine as a fixed number, or should it count real days later?
5. The cigarette: keep it if Roblox's rules allow it, or go straight to the fallback (unlit
   behind the ear, a match in his teeth)?
6. The future visitor's sign: no sign at all (recommended: the cage and RESTRICTED say enough),
   or a plain job title like "the contractor"?
7. OK to drop helicopter 20 for the motor pool, or bring it back somewhere on the flight deck?
