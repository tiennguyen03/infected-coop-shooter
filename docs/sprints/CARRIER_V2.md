# Carrier v2: the lobby ship revamp (2026-11-16; in the lobby 2026-11-18)

**State:** owner-approved (2026-11-17) and **built into the lobby** (2026-11-18, branch
`claude/carrier-v2-in-lobby`): `CarrierV2` places everything v2 adds over the existing ship from
the generated `CarrierV2Data`; the 45 kit meshes are uploaded to the group. **Not yet seen in a
Studio playtest** (the owner was playing; Studio tools not used). Off with
`Config.Lobby.CarrierV2.Enabled = false` (the ship as before). See "In the lobby" below.

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
  city yet; this proposal puts it on the coast STRAIGHT AHEAD of the Carrier (code +Z, owner 2026-11-17), at the foot of
  Route 9 below Checkpoint Delta ("the army checkpoint on the highway out of the city"). The
  green hills and Burn sites that stood ahead are gone from v2: the city is there. The lore developer adds it to the world map when the
  owner approves.
- The map room is labelled MAP ROOM, not THE PLOT, because THE PLOT is on the owner's list of made-up
  words to change (BACKLOG Q3). Owner confirmed 2026-11-17 (the lobby renamed it in PR #67).

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
  with a hoop and the memorial net on the aft bulkhead. The future seller hides in a nook under
  the ramp. Helicopter 20 on jacks is gone: the motor pool took its floor.
- **Flight deck:** bigger yellow boarding rings ("BOARD HERE"), the separate square gone; a red foul
  line; flood masts; tie-downs and chocks; the island dressed (vents, lights, flags, life rings,
  door); a ship's crane and boat; a deck-gear park (crash crane, tractor, pallets, drums); a
  stores-drop box forward; containers; pipe rails with posts instead of yellow slabs.
- **Shore:** the burning city STRAIGHT AHEAD, off the bow where the hills were (owner 2026-11-17),
  filling the view from the whole flight deck and the lookout at the bow.

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
| Hidden nook (future seller) | under the ramp's high end, X -29.5..-10.5, Z 20..44; way in X -29.5..-22 at Z 20 (the rest hung with a tarp) | nothing sells there yet; see Vendor corners |
| Spots 1-4 | helo X -12, Z -150 + 45 i | boarding is the yellow ring (PR #55) |
| City | ahead: quay Z 560, X -1000..900; towers Z 640..720, X -700..760 | laid out as if to port, turned onto the bow (`shore_v2`) |

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
| `prop_vendor_restricted` | sealed cases, locker, folding chair with raincoat, chessboard drum, document case, caged bulb | 1 | 472 | (-23.5, 20, 21.5) yaw -90 |

Vendor corner pieces are drawn in the person's frame: origin at their feet, +x the way they face.
The posed people (`npc_carrier_*`, 216-276 tris each) and `ref_carrier_atv` are **pose
references only**: registered with `register(ba, npcs=True)` from `carrier_v2`, never exported,
not counted. In game the sellers stay the lobby's own R15 figures as they look now (`NpcBody`,
their Dress and catalog items; owner 2026-11-17: "the regular R15, not the Blender-made one, but
put them in the same pose and maybe some animations"). The stand-ins use the same blocky 5-stud
proportions as R15 (legs 2, torso 2, head 1), so the poses carry over.

The Doorman on the show floor is the uploaded `ref_doorman`; the city towers are the match's
uploaded `env_city_*` (office, residential, deco, glass, ruined, midrise), 15 of them at X -640
to -720, scaled 0.62, several tilted, each with burnt gashes. Fire, smoke and searchlights
(`fx_fire`, `fx_smoke`, `fx_beam`) are Blender stand-ins for particles and Beams in game, not meshes.

## Easter eggs (11; helicopter 20 gave its floor to the motor pool)

| # | What | Where (X, Y, Z) | Mesh |
|---|---|---|---|
| 1 | Ship's cat asleep in a mortar crate, "DO NOT LOAD THE CAT" (the sapper feeds her) | call-ins floor (26.6, 20, 112.2) | `egg_carrier_cat` |
| 2 | The net: cargo net of wrist bands, helmets and green chemlights, "STILL ON THE LIST" | aft bulkhead (-22, 21, -99.9) | `egg_carrier_memorial` |
| 3 | Districts' board "MISSIONS HOME": Delta, Mile 14, Kestrel, the Yard, Reservoir, each with a **painted number** of missions home (owner 2026-11-18: numbers, not chalk marks; counted for real, see Counts below) | on two posts at the map room's walk edge (4, 22.6, 22) | `egg_carrier_scoreboard` |
| 4 | "DAYS SINCE ONE GOT ABOARD 214 / KEEP IT THAT WAY"; **counts up for real** (owner 2026-11-17; built 2026-11-18): whole UTC days since `Config.Lobby.DaysSince.Start` ("2026-04-18", 214 days before 2026-11-18; `Rules/Tally.daysSince`), one digit a tile, painted on start and every `RefreshSeconds` (an hour); 999 at most | screening lane (24, 40, -133.2) | `egg_carrier_dayssign` |
| 5 | Broken arcade cabinet, "OUT OF ORDER" | crew corner (-14.5, 20, 137.4) | `egg_carrier_arcade` |
| 6 | Call-in counts stencilled on the hull: HAMMER, ANVIL, SHRIKE, DOORMAN, each with a **painted number** under the name, e.g. 1,284 (owner 2026-11-18: "some equipment might be used hundreds of times"; counted for real, see Counts below) | over the call-ins floor, X 33 | text |
| 7 | (dropped 2026-11-17: helicopter 20 on jacks; its floor is the motor pool. `egg_carrier_queen_marks` stays in the kit, unplaced) | | |
| 8 | Stolen road signs "HARLAN 14", "CHECKPOINT DELTA" | fore bulkhead (-2, 29.2, 139.9), (8.5, 32.8, 139.9) | `egg_carrier_roadsign` |
| 9 | "NOT ON ISSUE" shelf: bat with nails, crossbow, chainsaw | Arms Room (-28.4, 20, 111.1) | `egg_carrier_notissue` |
| 10 | Lookout's post: big binoculars on the city, chair, flask, skyline log "STILL STANDING" with towers crossed off | the bow, port corner (-24, 40, 204), facing the city ahead | `egg_carrier_lookout` |
| 10b | One tower still signals short-long-short in lit windows | glass tower ahead (-205, ~264, 690) | Parts |
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
| **Call-ins** (starboard, feet (27, 105) facing -X) | **The sapper sergeant.** Cleared roads into the city with a mine roller before it fell; nine fingers and all the time in the world, he sells you a mortar like a man selling a car he actually likes, and he feeds the ship's cat. | an upturned mortar-bomb crate he sits on; a crate-table at his right hand with a 105 shell case cut down for his pencils, the hand-cranked field telephone and his wire cutters; a hand-painted MIND THE COILS board; one caged bulb on a cord; the cat in her crate by his boots; an unlit cigarette behind his ear | **sitting**: on the crate, forearms on his knees, a tin mug in the hand with the short finger, waving you over with the other | amber bulb (255, 140, 50) |
| **Loadout** (ramp foot, feet (-2, 88) facing +Z) | **The Loadmaster.** Rides the door on every lift and naps in a cargo-net hammock between them; wakes up loud, remembers every face he has flown, and keeps the count of everyone he brought back on a door off a dead helicopter. | a cargo-net hammock on two yellow stanchions; flight bag under it; a cool box he uses as a desk (mug, clipboard); the salvaged cabin door with FLOWN BACK and the tally in grease pencil; TODAY'S LIFTS board beside him | **lounging**: sits sideways in the hammock, one boot on the deck, one arm behind his head, pointing you at the board with the grease pencil; idle: rocks the hammock with his boot | cabin blue (110, 170, 255) clipped to the post |
| **Vehicles** (motor pool front, feet (9, -48) facing +Z) | **The motor sergeant.** Fixed city buses at the depot before her reserve unit was called up; came aboard on the last convoy with a toolbox and a stray dog that would not get off the truck. She writes down which ATVs come back, and asks after the drivers second, but she asks. | two stacked tyres she sits on; a bench with a vice, a clamp work lamp bent over it, her log book and a thermos; a carburettor in her lap; the dog asleep on a folded tarp with water in a hubcap; tool chests behind | **tinkering**: sits on the tyres bent over the part in her lap, wrench in hand, looking up at you; idle: wipes her hands on the rag, scratches the dog | hard white work lamp (236, 244, 255) |
| **Map room** (open floor, feet (26.8, -3) facing -X) | **Control's watch officer.** Grew up on a street in the city dead ahead; the postcard pinned to the board's corner is that street before. She has had the watch for 214 days, sleeps on a camp cot behind the board, and talks in places and times because it is easier than names. | a swivel chair tipped back; a stool with three steel mugs (all cold) and the sound-powered phone; a gooseneck lamp; the folded cot and her pack; the postcard on the board | **feet up**: tipped back in the chair, boots crossed on the map table's end, mug resting on her chest, one earcup on; idle: sits up to tap a district on the map | the map room's red, plus a small warm lamp on the stool |
| **Hidden nook** (FUTURE, under the ramp's high end, X -29.5..-10.5, Z 20..44; way in at the port end of its aft face) | **The visitor** (no sign, no job title on show; owner idea, not built: a rotating seller of experimental government weapons; owner 2026-11-17: "hidden in like the corner of the ship"). Comes aboard now and then on a helicopter that is not one of ours, with cases nobody else is cleared to open; polite, patient, no rank and no unit, and the Quartermaster will not stand near him. | a tarp hung across the ramp's back with a 7.5-stud gap at the port end, a netted pallet in front of it; inside, two sealed cases under seal tape and a locked tall case; a folding chair with his raincoat over it; a chessboard on a drum, a game half played against nobody; a document case; one cold bulb on a cord | **waiting**: stands just inside the gap, hands in his raincoat pockets, head slightly tilted. When he is away the nook is empty except the cases | cold dim (170, 214, 226); nothing else lit |

**No lit cigarette** (owner 2026-11-17: the question went unanswered, so the safe choice): no
lit cigarette, no smoke, no ashtray. The sapper keeps an unlit cigarette behind his ear, holds a
tin mug of tea, and his shell case holds pencils.

**Finding the hidden nook.** The ramp's top third (Z 20..44) becomes a plate over a room 20 wide,
24 deep and 12-20 tall; the solid wedge stays from Z 44 to the foot. Its sides are walled. From
the spawn walk you see only a tarp behind the ramp and a pallet in front of it; walk down the
port side toward the lift balcony and the gap at the port end opens, with the cold bulb inside.
The gap is 7.5 studs wide and the room is 20 x 24, so four players fit once they find it.

### Counts (eggs 3, 4, 6; built 2026-11-18)

- **What is counted.** The match (`server/TallyService`) counts every call-in a player fires
  (`CallInService`, after the charge is spent; bots and dev-panel fires are not counted) and, when
  the squad extracts, one mission home for the mission played (`Missions.current().Id`: `delta`,
  `mile14`). At run end (`RunManager.endRun`) the run's counts are added in one `UpdateAsync`
  to the one shared key (DataStore `Config.Lobby.Tallies.Store` "CarrierTallies", key "totals",
  a table `{ ["callin:hammer"] = n, ["mission:delta"] = n, ... }`, merged by `Rules/Tally.merge`);
  a server shut down mid-run adds what it has on close. A failed save is warned once and dropped.
- **What is painted.** Lettering rows in `CarrierV2Data` carry a `count` tag (the generator's
  `T(..., count=...)`); `CarrierV2` hands those cards to the lobby's `TallyBoards`, which paints
  the start value plus the stored count on start and every `Config.Lobby.Tallies.RefreshSeconds`
  (5 min). A call-in's start value is its own Config row's `Tally` (every row in
  `Config.CallIns` has one, through `CallInDefinitions`); a district's is
  `Config.Lobby.Tallies.Districts[<mission id>]` (the old chalk counts, 11, 6, 4, 2, 0). Without
  the store (Studio without API access) the start values show.
- **Layout.** Each number sits under its call-in's name on the hull. On MISSIONS HOME the names
  moved to the board's low-Z half and the numbers to the high-Z half, so from the walk (facing +X,
  +Z is the right) it reads "DELTA ... 11"; the Blender preview, mirrored, shows the numbers first.
  The board mesh lost its chalk strokes (re-uploaded, new model id). The days tiles are numbered
  left to right as read from the lane (hundreds at X 22.5); before, the three fixed digits were
  placed right to left and would have read "412" in game.

### Poses and idle animations (for the lobby, R15)

**Built 2026-11-18:** one hand-keyed loop per seller (`assets/animations/build/seller_idles.luau`,
uploaded to the group; `Config.Animations.Ids.seller_*`), played by `NpcPose` on top of the held
pose in place of the Rthro breathing idle; off with `Config.Lobby.CarrierV2.Idles = false`. What
each does is the table below, trimmed to one loop (the Quartermaster's sip and the Loadmaster's
pencil tap are left out). Not yet seen on the rigs.


Each seller is their existing lobby R15 figure, placed at the feet above, posed like the stand-in
and playing one short looping idle. How to build them with the project's animation pipeline
(`assets/animations/README.md`): `retarget.py` turns Mixamo FBX clips into R15 Motor6D keyframe
JSON (`src/shared/AnimationClips/`), `AnimationBuilder` makes a KeyframeSequence from it, and
`build_rbxm.luau` writes an `.rbxm` to upload to the group (Boomin Dev Studios, 270506601). Two
routes per clip: (a) a Mixamo clip that is close (Sitting Idle, Sitting Talking, Leaning, Lying
Down) retargeted as-is, or (b) a small hand-keyed clip in the same JSON format (3-4 keyframes of
joint angles copied from the stand-in's joint points in `carrier_kit.npc_*`). Seated figures need
the root lowered onto the seat (`HipHeight` / the root's offset), and the ProximityPrompt stays
where soldiers stand, not on the seat.

| Seller | Hold pose | Loop (about 4-8 s, Looped, Priority Idle) |
|---|---|---|
| The Quartermaster | perched on the stool, both elbows on the glass, clipboard under the left hand | turns a page on the clipboard; every other loop lifts the tin mug from the side table, sips, puts it back |
| The sapper sergeant | sitting on the crate, forearms on his knees, mug in the right hand | slow sip of tea, a glance at the cat, the left hand comes up in a lazy wave when a soldier is near |
| The Loadmaster | sitting sideways in the hammock, one boot on the deck | sways the hammock with the boot; settles back with an arm over his eyes; every so often taps the board with the grease pencil |
| The motor sergeant | sitting on the tyres, the part in her lap | wipes the part with the rag, turns it; reaches down and scratches the dog's head |
| Control's watch officer | tipped back, boots crossed on the map table | tosses a pen up and catches it; now and then sits up to tap the map, then tips back |
| The visitor (future) | standing, hands in his coat pockets | stands still; only his head turns slowly to follow the nearest player in range (a Neck look-at in code, not a clip) |

## Budgets: today vs v2 (measured by `carrier_v2.report`)

| | Today | v2 ship (11-16) | v2 ship with vendor corners, hidden nook (11-18) | v2 shore (city ahead) |
|---|---|---|---|---|
| Parts | 129 | 323 | 319 (9 stripe runs as one piece each) | (in the ship count) |
| Mesh instances / unique meshes | 44 / 16 | 245 / 65 | 241 / 69 | 30 / 10 |
| Triangles drawn | 16,558 | 49,490 | 49,522 | 24,070 |
| Unique mesh triangles (download) | 5,178 | 21,178 | 23,538 | 9,314 |
| Lights | 5 | 18 | 24 | 0 |
| Text labels | 17 | 84 | 94 | 0 |

The six vendor corners add 2,812 triangles; dropping helicopter 20 (body, trim, its jacks, engine
stand and chests moved) gave about the same back, so the ship's total did not grow. The posed
people are not counted (the game's rigs).

**PC first (owner 2026-11-18: "I don't really care about phone performance").** The detail
stays: no helicopters dropped, no phone cut list. In the lobby the ship draws about 42,400
triangles (today's 16,558 plus 25,856 from v2's 206 placed meshes) and the city 24,070, with 335
new Parts (each hazard band its own Part) and 53 lettering cards. What keeps it sensible on a
normal PC: every v2 mesh and Part casts no shadow; only 11 floor props collide (a box each);
seven new lights, all small (Range 14) with Shadows off, so the hangar has nine lights and the
map room three; the city's fire and smoke are 28 particle emitters at a low rate
(`Config.Lobby.CarrierV2.FireRate`). If a PC still stutters, the cheapest cuts are the city's
emitter rate, then the 31 pipe runs (every other bay), then the far skyline cards.

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

## In the lobby (2026-11-18)

How it is built (`claude/carrier-v2-in-lobby`; the old step list is done as below):

- **One generator, one placer.** `carrier_v2.py export_luau()` writes
  `src/lobby/server/CarrierV2Data.luau` (Parts, kit-mesh placements, lettering, lights, the city's
  fire and smoke) and `src/shared/CarrierKitMeshes.luau` (each kit mesh's uploaded model, size,
  bounds offset, `solid`). `src/lobby/server/CarrierV2.luau` builds them into `Workspace.CarrierV2`.
  Groups and meshes the lobby already builds are left out (`SKIP_GROUPS`, `SKIP_MESHES`: hull
  shells, deck slabs, the lane, the ArmsRack corner, the desk signs, the call-in show floor,
  MotorPool's chests and fuel point, the boarding rings, the birds, the chart table and board).
- **Meshes without Studio.** `build_assets.py -- --carrier-v2 --only <names>` exports the FBX;
  `node assets/3d/build/upload_models.js <names>` uploads each as a Model to the group (Open Cloud,
  the key from the robloxstudio MCP entry, never printed) into `build/carrier_uploaded.json`;
  `MeshAssets.register` + the new `modelId` path load each model's MeshPart with
  `InsertService:LoadAsset` (no MeshId to read in Studio). CarrierV2 boots before MeshAssets to
  register them and places them once they load.
- **FallowBuilder (v2 on):** the Plot's walls and lintel are gone (open map room); the ramp is a
  wedge from Z 44 to the foot plus a sloped `RampPlate` above, so the hidden nook opens under it;
  the yellow well rails turn invisible (v2's pipe rails show; the old blocks still hold you);
  the two flood poles give way to v2's masts; the coast's hills and Burn sites are not built (the
  city stands there).
- **Sellers (DeskService, NpcPose):** the same R15 figures and looks; the Quartermaster's feet
  move to X -26.6 (his stool); Call-ins, Loadout and Vehicles lose their counters (their corners
  stand in) and the Loadmaster's old cases and the Call-ins radio block go; each seller is posed
  once by turning its Motor6Ds (`NpcPose`: seated, leaning, feet up), `Config.Lobby.CarrierV2.Poses`.
  Each then plays their own looping idle (Poses and idle animations above).
- **Lettering** is SurfaceGui text on invisible cards (53); the call-in numbers, MISSIONS HOME and the
  days tiles are painted by `TallyBoards` (Counts above).

To change the ship: edit `carrier_v2.py` / `carrier_kit.py`, run
`blender --background --python assets/3d/build/carrier_v2.py -- --export-luau`, then `stylua src`;
a new or changed kit mesh also needs the FBX export and `upload_models.js <name> --force`, then
`--export-luau` again for its id.

**What to check in Studio (not done yet):** each corner's pose (the angles in `NpcPose` are set
from the Blender stand-ins, not seen on the R15 rig: a seller sunk into a seat or floating is a
`root` tweak), that every kit mesh loaded (Output: `MeshAssets: could not build`), the text
orientation on the floor stencils, the walk into the hidden nook from the port side, the open map
room, boarding still from every ring, and the city ahead from the deck.

## Still weak

- The city in game uses the palette, not the pictures' haze, so the far towers read sharper and
  closer; the fire is particles now (untuned, unseen). The tower silhouettes repeat (six meshes).
- The hangar is still one long hall; no overhead cable trays or hatches.
- The call-in show floor is #61's row (`CallInDisplay`); v2's own call-in props and placards
  are not placed (they could become each row's `Display.Prop` later).
- The sellers' poses and idle loops are set blind, unseen on the rigs (a limb through the glass
  or the hammock is a number in `NpcPose` or `seller_idles.luau`).
- The city is not yet in `docs/lore/world_map.md` (the lore developer, now that it is approved).
- The pictures use flat ambient light, so the vendor lights look softer than they will in game.

## Owner answers (2026-11-17)

1. City: **straight ahead**, where the hills were (done in v2).
2. **MAP ROOM** confirmed (the lobby renamed it in PR #67).
3. **Keep all 11** remaining Easter eggs; the days board **counts up for real** later (egg 4).
4. Sellers: **the lobby's own R15 figures**, posed like the stand-ins, with idle animations.
5. Cigarette: **none lit**; unlit behind the ear.
6. Future seller: **hidden in a corner**, no sign (the nook under the ramp).
7. Helicopter 20: **dropped**.
