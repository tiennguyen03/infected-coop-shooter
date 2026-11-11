# Levels: Checkpoint Delta, Mile 14, Aid Station Kestrel

Layout spec from the level designer for the three missions of an operation
([PROGRESSION.md](PROGRESSION.md)). Frame: 600 x 600, origin centre, +X east, +Z north
(ArenaService convention). Positions are (x, z) of a piece's bounds centre; y only where it
matters. Ground is raycast. Visual rules (materials, colours, sky) are in
[STYLES.md](STYLES.md) §6-7.

**Status.** Built in `ArenaService`: section A (Checkpoint Delta) and the building kit
(B1-B2), with the systems they need (`EnemyService` spawn filter + vertical chase,
`BotService` unstick, `StanceService` crawl, StreamingEnabled), and the Warden (A6). Not
built: A5 Primary props and points, A7 stores crates and Secondaries, per-site spawn points,
and Mile 14 / Kestrel (section C).

Two engine facts that drive every site:

1. **Almost no pathfinding.** A closed wall is a safe room; a stuck Infected fills the
   max-alive cap and starves the spawner. Every site has 3+ open approaches; the **nudge
   rule** in `EnemyService` repath (moved < 1 stud since the last repath with the target out
   of reach: `MoveTo` 8 studs perpendicular, alternating sign) and the **climb** (A8) get a
   body round and over cover. The one exception is the **vertical chase** (`Config.Enemies`):
   up to 10 melee forms whose target stands 4+ studs above them near a kit building follow a
   PathfindingService path through doors and up stairs; everything else chases straight.
   **Spacing** (`Config.Enemies.Spacing`, `EnemySpacing`, `Rules/Spacing`; not yet tuned in a
   playtest): bodies still pass through each other physically, but the straight chase steers
   each one off its neighbours and onto an attack ring round its target, and a body behind
   another near the target waits or slides round instead of walking through it. Beyond
   `EngageDistance` a body always keeps `TravelMinPull` of its advance, so a doorway queue
   never locks; paths, climbs, the nudge, lures, Hockers and bosses move as before.
2. **Hocker geometry.** Plants at 40 studs, throws to 55, needs a clear line from +7 studs
   above its head. Hesco (4.6) and sandbags (4) stop Walkers, not spit. Buses (12.5) and
   T-walls (12.5) stop both. Low cover = melee funnel, tall cover = Hocker shadow.

---

# A. Checkpoint Delta

Insert and extract on the LZ helipad; the walk south to the Gate is the mission's main
street; the Gate is a full T-wall line with one lane and the Warden beyond it; the Pens is a
low hesco funnel that plays nothing like the Compound.

## A2. Landmarks

| Landmark | Centre | Bounds (top) | Level | Built from | Job |
|---|---|---|---|---|---|
| Helipad "the LZ" | (-90,-90) | x-110..-70, z-110..-70 | 0 | pad + H + ring; 3 lamps; jerseys (-100,-116),(-80,-116),(-60,-70); perch container (-124,-82) + ramp | Insert, extraction. Open S/W, embankment N (Hocker gallery), road E |
| Inner Gate | (-30,-112) | lane x-42..-18 | 0 | T-walls (-54,-112),(-46,-112),(-14,-112),(-6,-112); booth (-58,-120); bunker (-52,-98) yaw 0; container (-8,-84) yaw 70; jersey (10,-78) yaw 80 | Screening lane; flare spot 1; stores #4; the Warden's second checkpoint |
| the Apron | (0,0) | 44x44 concrete | 0 | containers (30,-10) yaw -15 and (-10,-10) yaw 90, 40 apart, each with a ramp (A9); wreck (-27,28) on the road | Boss ground (A6) |
| Screening Block (B-1) | (-2,70) | x-14..10, z61..79 | 0 / 9 / 18 | kit: 2 storeys, catwalk to the Compound at 9, roof hatch ladder | Overwatch on the Warden walk; Recover Logs desk |
| Screening Compound | (70,70) | x25..115, z25..115 | 8 | the Shelf (78,52) block top 14 + ramp | Site 1 |
| Compound upper tier | (94,94) | x82..106, z82..106 | 16 | comm tower (94,94), T-walls (84,100),(84,92) yaw 90, hesco (100,84) | Restore Comms, Record B |
| Ridge | (-100,45) | x-130..-70, z23..67 | 8 | ruin (-104,48) burning, enterable; tower (-78,30) with ladder; jersey (-82,60); whiteboard (-87,11,48) | Stores #2, story spot 1, Record A, flare spot 3 |
| the Lines (B-2) | (-240,60) | x-285..-195, z52..68 | 0 / 9 | kit: 3 huts 30x16 shoulder to shoulder, end doors in line (a 90-stud tube), middle hut ladder to the roofs | The Barracks' walk-through; rooftop route R7 |
| the Armoury | (-210,0) | x-218..-202, z-6..6 | 0 / 9 | kit: 16x12, one door S, slit windows, roof ladder N | Barracks stores / cover |
| the Pens | (-257,120) | x-300..-215, z90..150 | 6 | ParadePad (-250,6.15,120) 56x46; 24 tall hesco (A3); tents (-266,102/120/138); lamps (-218,160),(-200,120) | Site 2, Sanitize |
| Overlook | (105,-105) | x85..125, z-125..-85 | 14 | bunker (104,-108) yaw 180; tower (150,-100) with ladder; jerseys (60,-80),(60,-110) | Site 3 |
| Highway | z=-45 | x-300..300, z-54..-36 | 12 | deck container perch (-130,-45) + ramp; deck gantry at x 40 floor 23.5 off container (56,-45) + ramp (A9); jersey line at z -38.5 (x 64, 72, 84, 118, 126) | Hocker gallery; the ridge route W-E; R2 |
| the Pumps (B-6) | (130,-155) | canopy x116..144, z-163..-147; kiosk x144..156, z-160..-150 | 0 / 9 / 10.5 | kit: kiosk (door W, ladder E, no parapet) + walkable canopy on 4 columns over 2 pump islands | Scrapyard north edge cover; a Hocker shadow |
| Depot | (210,40) | pad x155..285, z-5..105 | 0 | A4 table + the Shed (B-3) + the Stack (A9) | Stores #1/#3, Confirm Casualties, generator, alt pad |
| the Shed (B-3) | (196,86) | x180..212, z74..98 | 0 / 6.5 / 12.5 | kit: 12.5 clear (Brute room), vehicle door S at x 198..210, doors N and E, mezzanine W up a flight, roof off the container (174,86) | Confirm Casualties Brutes |
| the Gate | (-30,-274) | wall x-294..290 (the perimeter fence closes the ends); lane x-42..-18 | 0 | 71 T-walls at z=-274 (x=-294+8k, k 0..73, skip k=32..34), every ninth casting a shadow; the Scrapes at x -150 and x 114 (A10); booth (-54,-262); siren lamp (-14,-264) | Index entry, Open the Route, Silence the Alarm |
| Bus line | (-4,-196) | x-9.5..1.5, z-263..-129 | 0 | 3x env_bus yaw 90 at (-4,-150),(-4,-196),(-4,-242); 4th bus (40,-205) yaw 60 | Hocker-proof cover on the Gate approach; Bus 7 story spot |
| Suburb: the Parade (B-5) | (124,178) | x100..148, z170..186 | 0 / 9 | kit: 4 shops facing the north road, front door + broken shopfront (sill 1) + back door each, party-wall doors, one 48-stud roof; dumpster (108,167) is the Walker step | R6 Suburb Run |
| Suburb: the church (B-4) | (60,262) | x50..70, z246..278 | 0 / 7 / 14 / 20 | kit: 14-stud nave, choir loft over the south end up an east flight, inside ladder loft -> roof, belfry 8x8 on the roof (arches, ladder N) top 20 | The Suburb's lookout; story spot |
| Outer hills | as built | | 10/8/12 | NorthBluff, SouthRise and Depot-mound towers (ladders), ruins | Misdrop crates: (20,250) Suburb, (-250,-20) Barracks, (235,12,-205) Depot Mound |

Main road x=-30, north road z=200, bridge x -46..-14 (underside 10.5): the spine the Warden
walks. Hill levels 0/6/8/12/14/16; everything climbable or ramped.

## A3. The three sites

**Site 1: Screening Compound** (zone (50,8.5,50) 46x46)
- Approaches: 4 slopes. Direct: W slope (foot x15) and S slope (foot z15). Indirect: N slope
  through the tents (42,88/104) and wreck (62,104); E slope through the containers (100,44/55).
  Upper tier slopes (x,z >= 72) drop Infected onto the zone's NE corner. The Screening
  Block's catwalk lands on the W edge at (26,9,70); the Shelf (78,52) overlooks the E edge.
- Cover: hesco column (34,40..54) W; T-walls (55,34),(63,34) + bunker (86,34) S; containers E.
- Hocker stands: upper tier SW corner (84,16,84); ground W (8,0,50); ground S (50,0,8).
- Squad holds: zone centre to the T-wall line; one player on the W hesco or the Shelf.

**Site 2: the Pens** (zone (-240,6.5,120) 46x46)
- Tall hesco ring (8.88: Walkers never climb it, Runners do) on the terrace top: N row z=146,
  S row z=94, x = -295.5,-289.6,-283,-276.4,-269.8,-263.2 | -238.3,-231.7,-225.1,-218.5 (10
  each; mouth x-260..-241.4); E column x=-219 yaw 90, z = 100,106.5 | 133.5,140 (mouth
  z110..130). West: the perimeter fence on the terrace edge, the boundary collider behind it
  (A15).
- Approaches: exactly three mouths N, E, S. Tents (roof walkable) on the west half are
  climbable cover inside.
- Hocker stands (outside the ring, lobbing over hesco): N (-250,170), E (-190,120), S (-250,70).
- Squad holds: the yard east of the tents (-236,120); solo holds the SW tent corner (-256,108).
- Spawn points: N (-250,165),(-235,170); E (-195,120),(-190,135),(-190,105); S (-250,75),(-262,72).

**Site 3: the Overlook** (zone (105,14.5,-105) 28x28)
- Approaches: 4 slopes, all in view. The N slope foot (z-68.2) meets the highway's S slope
  foot (z-68.4): a continuous ridge route to the deck.
- Cover: the bunker (104,-108), opening south (A14 #9).
- Hocker stands: highway deck (105,12,-52); ground E (150,0,-105); the Pumps' canopy (130,10.5,-155).
- Squad holds: in and behind the bunker. Escape: N slope onto the deck, west to the bridge.

## A4. Depot

| Piece | Position | Yaw | Note |
|---|---|---|---|
| container olive/rust/olive/rust | (172,20),(172,44); (198,20),(198,44) | 90 | columns A, B (22 along z) |
| container olive/rust/rust/olive | (224,20),(224,44); (250,20),(250,44) | 90 | columns C, D. Aisles A1 x177..193, A2 x203..219, A3 x229..245 |
| the Stack | (250,32) lift 9.55 | 90 | a third rust container across column D's pair, top 19.4; ramps (250,1.65) ground -> lower top and (250,15) lower top -> the Stack |
| T-walls | (170,-10),(178,-10),(186,-10) | 0 | generator blast screen |
| generator | (178,-2) | 0 | Lights On prop |
| hesco row | (170..191,70) x4 | 0 | yard N fence west half |
| container rust | (174,86) | 90 | against the Shed's west wall (x 169.4..178.6): climb 9.55 -> parapet 13.7 |
| the Shed | (196,86) | | B-3 |
| alt helipad | (255,85) | | 40x40 pad + H; marker (255,0.6,85) for Light the Pad |
| cargo truck | (242,-10) | | the south line; crawl under it into the yard |
| tower (280,40), checkpoint (160,120), tents (215,140),(240,140), lamp (160,90), bunker (235,-205), wreck (180,-150) | as built | | |
| stores crates | A1 (185,0.3,32); A3 (237,0.3,32) | | #1 always; #3 at Held+ |

## A5. Main objective placements (`ObjectiveDefinitions` > `Maps.delta.Sites`)

| Main objective | Where | Props / points | State |
|---|---|---|---|
| Secure the Site | any of the 3 sites | zones as in A3 | built |
| Sanitize the Pens | the Pens | fuel cans at the tents' east faces (-254,7.1,102/120/138) | built |
| Recover the Record | Ridge to comm tower | A (-90,8.25,56); B (88,16.5,88), delivered within 9 studs | built |
| Restore Comms | Compound upper tier | radio set (88,17.2,88); hold within 20 studs of it | built |
| Confirm Casualties | Depot aisles | marked Brutes at the aisle ends (185,2),(185,62),(211,2),(211,62),(237,2),(237,62), drawn in a random order; starts within 75 studs of (211,32). The Shed points (190,86),(202,80) are not used yet: a spawn there needs a floor height | built |
| Open the Gate | the Gate | 4 jersey barriers across the lane at z-274, x-39,-33,-27,-21; 3 lock blocks at (-36,2.9,-274),(-30,2.9,-274),(-24,2.9,-274); point beyond (-30,0,-288) | not built |
| Recover Logs (side) | Screening Block | the desk, ground floor SW corner under the window (-10,1.3,64.5); the NW corner is the stair run | not built |
| Evacuate | never at Delta | | |

The props are plain code-built Parts (fuel cans, the radio set, the ledger, the siren switch);
no new meshes.

## A6. Index entry: the Warden (`Config.Index.Warden`, `IndexService`)

- Spawn (-30,-290). Waypoints: (-30,-274) Gate lane, (-30,-200), (-30,-112) Inner Gate lane,
  (-30,-45) under the bridge, (-30,0) Apron, then free chase.
- Lane: 24 wide at both gates (x-42..-18), 16-wide road elsewhere: lamps at x=-42, buses at
  x >= -9.5, nothing else within 10 studs. Bridge underside 10.5; he is scale 1.9 (~9.9
  tall) and walks under it. Open the Route's barrier line must be gone before he spawns.
- Boss ground: the Apron plus open ground x-20..25, z-36..25. Two perches 40 apart
  ((30,-10) and (-10,-10), ramped: A9) are the line-breakers; the Screening Block's west
  windows (storey 2, y 9..17.6) overlook the whole walk from the Inner Gate; the Compound W
  slope the retreat up, the road under the bridge south.

## A7. Pads, stores, side objectives

| Thing | Position |
|---|---|
| Main pad (insert + extract) | (-90,0.6,-90), hold zone 28x28 |
| Alternate pad | (255,0.6,85) on the Depot pad; overwatched from the Stack |
| Stores crates (not built) | #1 Depot A1 (185,0.3,32); #2 Ridge (-90,8.3,40); #3 Depot A3 (237,0.3,32) [Held+]; #4 Inner Gate bunker (-52,0.3,-98) [Contained] |
| Silence the Alarm (built) | siren at the Gate (-14,-264); its switch box on the post's north face (-14,3,-263.1) |
| Lights On (built) | generator (178,-2); the switch point on its south face (178,3,1.2); lights the 5 nearest lamp posts within 320 studs |
| Light the Pad | (255,0.6,85) |
| Sealed Bus | Bus 7 (-4,-242); Runner burst spawns at (-20,-242),(12,-242) |
| Misdrop (built) | one of (20,250) the Suburb, (-250,-20) the Barracks, (235,12,-205) the Depot mound |
| Clear the Spitters (built) | one of the highway deck west of the pad (-175,12,-45), the bus line (-25,0,-160); the Hockers stand 6-18 studs round it |
| Headcount story spots | 1 Ridge whiteboard (-87,11,48); 2 Bus 7 "NEG" decal (-10,6,-242); 3 the Pens' tent 2 door (-254,6,120); 4 the church loft (60,7,251) |

## A8. Traversal rules and composite colliders

Every piece carries a traversal class from `Ledge.find` and `Config.Movement` (Reach 3.2,
VaultMaxHeight 5, ClimbMaxHeight 10.5, VaultDepth 6.5, Headroom 5; prone root 0.3-2.3):

| Class | Rule | Pieces (top) |
|---|---|---|
| WALK | top under 1.0 | single pallet 0.57, plank 0.4; body bags have no collision |
| dead band | 1.0-1.2 | build nothing with collision at this height |
| VAULT | 1.2-5, thinner than 6.5 with ground behind | cot 2.1, pallet stack 2.28, jersey 2.75, hesco 4.58, dumpster side-on 4.4, sedan / hatch side-on 4.4-4.6, bunker walls 4, humvee hood/steps, window sills |
| CLIMB-low | 1.2-5, deeper than 6.5 | fuel bladder 3.03, dumpster and sedan end-on |
| CLIMB | 5-10.5, flat top | generator 5.2, pickup cab 5.4 (bed 2.6), bunker roof-line 6.3, humvee 7.1, van 7.2, truck bed 5.7 and cab 8, toilet 8.45, tall hesco 8.88, container 9.55, ruin slab 10, hut and shop roofs 9 (+1.2 parapet) |
| WALL | over 10.5, or a top under 0.6 thick | T-wall 12.5, bus 12.75, chainlink (bullets pass), lamp, tree, light tower |
| CRAWL-UNDER | gap 2.8+, no more than 5 deep, open both ends; prone, players only | the Scrapes 2.8, cargo truck bed 2.9 (between the axles), checkpoint boom 3.97 |
| HIDE | a Hocker shadow: taller than 7 and 3 deep | buses, T-walls, buildings, the canopy |

- **Who climbs what:** Walker `ClimbHeight` 5 (about 4.6 in practice), Runner 10.5 (about
  9.6), Brute nothing (`EnemyDefinitions`). Bots climb nothing: every crawl or climb route
  keeps a walk-around within 40 studs (ramps, slopes, doors).
- **Walker staircase rule:** no piece within 3.2 of one more than 5 taller unless the step
  between them is 5 or less.
- **Concertina is never vaulted** (owner). Wire is CanQuery off, so `Ledge.find` never sees
  it, and JumpPower is 0: the body stops or walks round the end.
- **Composite colliders** (`MeshAssets.MESHES[*].colliders`, placed by
  `MeshAssets.addColliders`): the mesh is CanCollide/CanQuery false and a list of invisible
  anchored boxes is the body. Sandbag bunker 3 walls (open top and the +Z side); humvee 3
  steps (bumper 2.5, hood 4, roof 7.1); ruin 26 boxes (enterable ground floor, 4 x 8 door,
  windows sill 4 / head 9.4, back wall one storey with a 6-wide breach, slab 10) with a
  5-box sealed `shell` for the outer ruins; guard tower legs/deck/rails + a TrussPart ladder
  (deck 14, rail gate on the ladder side); checkpoint booth + boom; comm tower 2 boxes; tent
  hull + 2 wedge roofs; vehicles 2-5 boxes each. Budget 256 (`Config.Arena.ColliderBudget`,
  counted and warned at boot: `[ArenaService] dressing placed: N pieces, M colliders`).
- **Ladders** are TrussParts in the `Ladder` collision group, non-collidable with `Enemy`:
  the squad climbs, the Infected walk through.

## A9. Routes and perches

Routes: **R1 Main Street** (LZ - road - under the bridge - Apron - Compound); **R2 the Deck**
(highway top, the drop off the bridge parapet, the deck container perch, the gantry); **R3 the
Yard Run** (Depot container roofs, the Stack 19.4, the Shed roof); **R4 the Barracks Walk**
(the Armoury, the Lines tube, the vault line to the Pens); **R5 the Queue** (the bus line,
the Gate, the Scrapes); **R6 Suburb Run** (the Parade shops front to back, the church loft
and belfry); **R7 Back Way** (the Lines' roofs west to east, down to the Ridge).

Perches: never inside a hold zone, and every one has a pallet ramp (`ArenaService.RAMPS`,
WedgeParts at the kit's 33 degrees) so a Walker can follow and no perch is a free camp.

| Perch | Top | Ramp (thin end -> top) |
|---|---|---|
| LZ north-west container (-124,-82) | 9.55 | from the south, (-124,-101) -> (-124,-86.6) |
| Deck container (-130,-45) | 21.55 | along the deck from the west, x -155.7 -> -141 |
| the Shelf (78,52) | 14 | from the east on the hill, x 91.2 -> 82 |
| Compound E container (100,44) | 17.55 | from the west on the hill, x 74.5 -> 89 |
| Apron containers (30,-10) yaw -15 and (-10,-10) yaw 90 | 9.55 | the north face of (30,-10); the east face of (-10,-10) |
| the Stack (250,32) | 19.4 | two flights up column D's south end: (250,-5.7) -> (250,9) -> (250,21) |
| Deck gantry (40,-45) | 23.5 | container (56,-45) on the deck (top 21.55, a Walker step) ramped from the east x 81.8 -> 67; a truss on the west face for the squad |
| Guard towers (5) | 14 | TrussPart ladder on the +Z face, rail gate at the top |
| Building roofs | 9 (huts, shops, Armoury, kiosk), 12.5 (Shed), 14 / 20 (church, belfry), 18 (Screening Block) | B: ladders, climb lips, the Shed's container, the Parade's dumpster |

## A10. Crawl spaces: the Scrapes

Two Gate T-walls stand on cribbing (`lift = 2.8`; crib blocks from `buildPerches`): k=18 at
x -150 and k=51 at x 114, z -274. The gap is 2.8 high and 2.6 deep, open both ends. Prone
drops the body's HipHeight to `Config.Player.Stances.ProneHipHeight` (0.3: the 2-stud root
fits under 2.8) through `StanceService`; standing up needs `ProneHeadroom` (4) clear above the
root, checked on the client and the server, else the body stays down. Players only: no
Infected or bot goes prone. The Index comes through the lane; the squad has two more ways in.

## A11. Props by district

`ArenaService.PROPS` (~130 placements) use the `prop_*` meshes in `assets/3d/README.md`.
Each district has an identity: the LZ light tower + generator + pallets + body bags + the
supply cargo truck (-143,-120); the Screening Block's body-bag row and concertina; the
Compound's cots and light tower; the Ridge's chainlink and cots in the ruin (`floor = 8`);
the Inner Gate's concertina and light tower; cars on the highway deck; the Overlook's
generator; the Suburb's cars, dumpsters, planks and the church's body bags; the Depot's
pallets, dumpster, fuel bladder and chainlink; the Pumps' fuel bladders and a car; the
Scrapyard's cars, dumpsters, planks and the concertina inside the Gate; the Lines' nine cots
(`floor = 0`), toilets and generator; the Pens' body bags; the Armoury's pallets. Cars are
sedans, hatchbacks, pickups and vans 2:2:1:1 (vans at the Gate queue and the Scrapyard).
**Pallets are stacks of four beside their source, never singles** (lift 0 / 0.57 / 1.14 /
1.71). A prop whose mesh id is not in `MeshAssets` is skipped and listed at boot.

## A12b. Placement rules (slopes and overlaps)

Every dressing piece is placed by one raycast at its centre, so a footprint across an
embankment sinks or floats. Two checks enforce the rules: `assets/3d/build/delta_map.py`
rebuilds the layout in Blender and paints a breaking piece red, and `ArenaService.placePiece`
raycasts a piece's four corners at boot and warns past `Config.Arena.StraddleTolerance`
(0.35). Both should read 0.

| Rule | Value |
|---|---|
| Footprint | the rotated box from the mesh size (`MeshAssets`) |
| From a slope foot | edge 2+ studs outside the slope band (lamps, trees 1+) |
| From a crest | edge 1+ inside for pieces up to 5 tall, 2+ for taller ones |
| On a slope | nothing with a base; only the kit's own ramps |
| At a hill foot | Mud / Rock sheets only |
| Hold zones, pads | A3 cover only; the LZ pad and the alt helipad stay bare |
| Overlaps | no piece inside another (owner); meant overlaps: the cots inside the ruin, the siren on its lamp post, roads over pads |

Exceptions: perch containers whose own pallet ramp runs under them carry `perch = true` and
skip the check; a piece whose raycast lands on its own parts or a neighbour carries `floor`
(the Gate lamp post `floor = 0`, the Depot perch container `floor = 0.28`).

Open (owner calls): generator to 4.8 so it vaults; light-tower collision as two boxes (its
18-tall Box is an invisible wall in the air).

## A15. The perimeter

The map must not feel walled in (owner). A barrier the player believes in at the edge, the
world carrying on past it, and the invisible wall right behind the visible barrier so the
player never touches empty air. No soft out-of-bounds warning: there is no way out.

| Edge | What you see | Built from (`ArenaService.PERIMETER`, `FENCE`, `buildPerimeter`) |
|---|---|---|
| All | the quarantine fence just inside the edge | `prop_chainlink_panel` every 12 at +-299.6 with `prop_concertina` on top; each panel stands on the lowest ground under its ends (`placeFence`), so on a slope its posts sink in |
| North | fence and towers; the Suburb running on as ruins | towers z 312 x -180/-60/60/180; shell ruins (-150,360), (40,380), (200,350); 6 dead trees |
| East | fence and towers; the highway running on and breaking off | towers x 312 z 180/60/-150; the embankment (top, road, both slopes) to x 400, a fallen deck slab, a container under it; 2 containers, 4 trees in the field |
| West | fence on an earth berm | berm x -304..-350 (top 10) in two runs with the highway gap; towers on the crest (-327, z 180/60/-150); `PensFill` levels the Pens terrace (6) out to the berm |
| South | the outer wire past the Gate, the road to the city | 4 unlit light towers z -308; a 24-wide road z -300..-700; 2 buses, a humvee, 2 containers queued z -345..-420; the Gate's T-wall line carries on at x +-306/314/322 |
| Corners | | towers at (+-312, +-312) |
| Highway ends | a roadblock on the deck at x +-296 | 3 jerseys + wire (inside the play space: real cover); the fence skips z -73..-17 there |

- **What stops the squad:** four invisible Parts in `TestArena`, 2 thick and
  `Config.Arena.BoundaryHeight` (80) tall, inner face at 300; CanQuery / CanTouch off so
  bullets, the camera and the vault / climb checks ignore them.
- **Past the edge everything is `decor`** (no collision, no queries, no shadow, colliders
  skipped) and lives in its own Persistent model `workspace.Perimeter`, so the far fence
  never streams out. Ground slabs run 700 out; dressing thins with distance, then fog and
  the DistantCity ring ([STYLES.md](STYLES.md) §7).
- **Spawns** are clamped inside `Config.Arena.SpawnInset` (292) in
  `EnemyService.groundPositionNear`.
- **Budget:** ~458 instances in `Perimeter`, +0 composite colliders, +0 shadow casters, no
  new meshes. 60 fps on the dev PC; not yet measured on a low-end device. If it costs, cut
  the wire on N/E/W first (-~148 coils), then the scenery.
- The Studio Baseplate is hidden at once and destroyed after 5 s (deleting it at boot
  dropped the first player through the world).

## A12. Ground

`ArenaService.PATCHES`: thin (0.24) no-collision, no-query sheets (colours in
[STYLES.md](STYLES.md) §6). Darker Ground verges 8 wide along both roads; Mud at the hill
feet (Compound W/S, Ridge S, Overlook N, the Pens, the Lines, the Shed's yard, the Pumps'
forecourt, the churchyard) and as puddles along the main road; Rock in the Scrapyard, the
Depot's south-east, the Suburb's north-west and north-east corners and at the Depot-mound
and SouthRise feet.

## A13. Verification still owed

Done: building and dressing counts at boot under budget, `Ladder` / `Enemy` groups, the
spawn filter (item 7), 60 fps with 40 Walkers (item 8), prone and stand. Still owed:

1. Top-down screenshots at y 400 (whole map) and y 120 over each district; compare with A2.
2. Walk every route R1-R7 as the player: reachable / blocked at each step; every door,
   stair, ladder and ramp; the Scrapes prone (and that standing under them is refused).
3. Staircase test: 10 Walkers (`DevCommand spawn Walker 10`) per perch; each must arrive
   by its ramp; the Shelf, the Stack and the gantry are the ones to watch.
4. Vertical chase: stand on the Screening Block's first floor, the Shed mezzanine and the
   church loft with Walkers below; up to 10 should path in through the door and up the
   flight.
5. Sight-line screenshots: the Screening Block west windows over the Inner Gate; the
   belfry over the Suburb; the gantry over the Apron.
6. Hocker shadow raycasts under the canopy, inside the Parade and behind the buses.
9. Streaming: join, run LZ -> Depot -> Suburb, check nothing pops in late within 128 studs
   and the skyline never disappears.

## A14. Open engineering questions

Built and closed: crawl clearance, ladders, spawn raycast past dressing tops, vault headroom,
bot unstick, vertical chase (PathfindingService, <= 10 bodies, AgentRadius 1.5), streaming
(client scripts tolerate a folder that has not streamed in). Still open:

1. Crawl: the prone clip is authored for a standing root; the Root Motor6D lift keeps the
   body on the ground, untested in game.
3. Nudge oscillation on long cover (keep the side for 3 nudges).
7. Perch vs Warden cheese (systems).
8. Carry rules (carriers vault, never climb or crawl): no carry system yet.
9. Which side of the bunker mesh is open: check in game (the colliders assume +Z).

---

# B. The building kit

## B1. Kit rules (`Config.Arena.Kit`, `ArenaService.buildBuilding`)

| Rule | Value |
|---|---|
| B1 storey | 9, slab 0.6 (8.4 clear: a 2x Brute enters only rooms built taller, the Shed at 12.5) |
| B2 door | 4 x 8 |
| B3 window | 5 wide, sill 3.2, head 8.6 (vault the sill, under the head); a `breach` is a hole from the floor; a `gap` is open full height |
| B4 the 8-stud rule | no solid outside run longer than 8 without an opening: ground floors always have a way in |
| B5 stairs | WedgeParts at 33 degrees, 5 wide, head-clearance hole cut in the slab above (`Config.Movement.Headroom`) |
| B6 climb lips | a 2.5 cornice outside every upper floor no higher than 10.5: mantle from the street, vault a window in |
| B7 roofs | flat, 1.2 parapet, reached by ladder or climb; outside ladders get a parapet / lip gap of 3 (`Config.Arena.Kit.LadderGap`) |
| B8 corridors and catwalks | 6 minimum (`CorridorMin`) |
| B9 interiors | Hocker cover; no hold zone inside a building; one atomic Model per building |

Materials per type are in `Config.Arena.Materials` ([STYLES.md](STYLES.md) §6). Footprints
are kept for the spawn filter (`ArenaService.insideBuilding`) and the vertical chase
(`ArenaService.buildingDistance`).

## B2. The seven buildings (`ArenaService.BUILDINGS`)

| # | Building | Centre | Size | Levels | Ways in / up |
|---|---|---|---|---|---|
| B-1 | Screening Block | (-2,70) | 24x18, 2 storeys | 0, 9, 18 | doors S and W; stairs along the N wall; first-floor E door onto the catwalk to the Compound (26,9,70); roof hatch ladder (S wall, inside); lips at 9 |
| B-2 | the Lines | (-270/-240/-210,60) | 3 x 30x16 | 0, 9 | E/W doors in line; ladder on the middle hut's N face; no parapets (roof to roof) |
| B-3 | the Shed | (196,86) | 32x24, 12.5 clear | 0, 6.5, 12.5 | vehicle door S (12 x 10), doors N and E; mezzanine W up a flight; roof from the container (174,86) |
| B-4 | Church + belfry | (60,262) + (60,252) | 20x32, 14 nave; belfry 8x8 | 0, 7, 14, 20 | door S 6 x 10; loft over the S end up the E flight; inside ladder loft -> roof (W wall); belfry arches, ladder N |
| B-5 | the Parade | (124,178) | 48x16 | 0, 9 | 4 front doors + 4 shopfronts (sill 1) N, 4 back doors S, party-wall doors; roof 9 (dumpster (108,167) for Walkers) |
| B-6 | the Pumps | kiosk (150,-155), canopy (130,-155) | 12x10 + 28x16 canopy | 0, 9, 10.5 | kiosk door W, ladder E; kiosk roof (no parapet) steps onto the canopy |
| -- | the Armoury | (-210,0) | 16x12 | 0, 9 | door S, slit windows, ladder N |

## B3. Environment pieces still to build (reuse first)

| Piece | Size (studs) | Pivot | Collision | Derive from | Needed by |
|---|---|---|---|---|---|
| **env_water_tower** | 16 x 48 x 16 | bottom | Box | env_comm_tower + tank cylinder | Mile 14 landmark + Restore Comms |
| **env_hospital_bed** | 6 x 2.8 x 3 | bottom | Box | crate + 4 legs ~120 tris | Kestrel Ward rows (18) |
| **env_bleachers** | 40 x 8 x 12, four 2-stud steps | bottom | none | stacked boxes ~120 tris | Kestrel |
| env_tent_medical | = env_tent | | | swatch variant (white + red facet) | Kestrel Triage |
| Parts, no mesh | siren head, lock blocks, whiteboards/signs, canopy, alt helipads, Ward walls (env_twall rows), pallet ramps | | | | |

Toll booth = env_checkpoint as is. PA speaker = lamp post + box. Convoy cargo truck =
container. Built pieces are listed in `assets/3d/README.md`.

---

# C. Mile 14 and Aid Station Kestrel (not built)

## C1. Mile 14 (full dark)

**First pass built** (2026-11-11, `src/server/Missions/Mile14.luau`, played in Mile 14 Dev): the deck in two halves (HighwayS, HighwayN) with the Culvert between, the Jam (22 buses, none over the Culvert), the Toll Plaza lot with its four booths and jersey pairs, the Rest Stop diner and lot, and woods (Nova: "some wooded areas in it") on the east shoulder south, the west shoulder north, behind the Toll Plaza and behind the Rest Stop, dead trees standing in until a living tree is modelled. Not yet: the Overpass, the off-ramp, pumps and canopy, the water tower, night lighting, placed sleepers, objectives. Played quiet: [PROGRESSION.md > Awareness](PROGRESSION.md#awareness-the-quiet-missions).

| Landmark | Centre | Bounds | Level | Built from |
|---|---|---|---|---|
| Highway deck "the Jam" | x=0 | x-30..30, full z; hills HighwayS z-300..-60 and HighwayN z-20..300, open N/S ends | 12 | asphalt + dashes; 24 buses nose to tail, lanes x=-14 and x=14, z every 48 from -276 to 276, yaw 90, 6-stud gap each; 2 containers as cargo trucks (10,12,140),(10,12,-100) with stores crates |
| the Culvert | z=-40 | the 40-wide gap under a deck 40x18 at 12, piers each side | 0 | the one E-W crossing under the Jam |
| Rest Stop | (-170,-170) | concrete 120x100 | 0 | diner = ruin building (-170,-200); 4 pumps from (-140,-160), 6 apart, under a canopy 30x1x14 at y 9; stores crate (-190,0.3,-222); alt pad (-200,-130) |
| Off-ramp | (-40,-150) | W slope of HighwayS, asphalt z-170..-130 | 0 to 12 | lamp posts at its foot |
| Toll Plaza | (160,60) | hill 120x80 h6, x100..220 | 6 | 4 checkpoint booths at x=160, z=32,48,64,80 yaw 90 (lanes 16 wide E-W); jersey pairs at lane mouths; generator (120,6,30); main pad (240,6,60) |
| Overpass | z=60 | hill E x60..300 and W x-300..-60, 36 wide, h24; span 80x36 over the deck at 24 (underside 22.5) | 24 | two stair ramps (wedges 12 rise, 18 long) from the span to the deck, N and S |
| Water tower | (250,-230) | | 0 | env_water_tower; Restore Comms prop at (250,0,-220) |

Routes: Rest Stop > off-ramp > along the Jam (central gap plus shoulders) > Overpass stairs.
Secret: the Culvert. Sites: **Overpass span** (zone 28x28 at (0,24.5,60); Hockers on the deck
12 below lob up); **Toll Plaza** (zone 46x46 at (160,6.5,56); booths block sight, lanes
funnel); **Rest Stop** (zone 46x46 at (-160,0.6,-170); pumps burn when hit; the off-ramp is
the Hocker gallery). Primaries: Sanitize = buses (14,-84),(14,12),(14,108); Record = booth 2
(160,6,48) to the span centre; Comms = water tower; Casualties = 6 Hockers on the deck
z-150..150; Open the Route = lead bus (-14,12,-276), point (0,12,-292); Evacuate = diner door
(-150,0,-200) to the main pad. Index: the Bloat from the lead bus > off-ramp (-40,-150) > Rest
Stop lot (-150,-160) > free chase. Pads: main (240,6,60); alt (-200,0,-130). Bands: Lost pumps
burn, horn loops; Held toll floodlights, one lane cleared (remove 4 buses z-36..108 lane
x=14); Contained lane lights, container "truck" at the toll (200,6,100).

## C2. Aid Station Kestrel (dawn)

| Landmark | Centre | Bounds | Level | Built from |
|---|---|---|---|---|
| the Field | (40,-180) | 160x100 | 0 | painted LZ at (40,0.6,-180) (main pad), field lines; the lowest ground |
| Bleachers | (-60,-180) | hill 20x100 h8 along the Field's W edge | 8 | env_bleachers x2 (no collision) over the E wedge; hesco at the ends |
| Triage Lot | (-150,-170) | concrete 100x80 | 0 | 6 medical tents in 2 rows x=-180/-120, z=-200/-170/-140; stores crate (-170,0.3,-215); alt pad (-130,-120); generator (-100,-215) |
| the Ward (gym) | (100,60) | walls x70..130, z35..85 of env_twall; doors 12 wide on N and S walls | 6 | on hill "Campus" (100,60) 140x110 h6; 18 beds in 3 rows at x=82/100/118, z 42..78; open sky, 12.5 walls |
| the Morgue | (220,-20) | 2 ruins (205,-20),(238,-20) yaw 90 + loading dock 30x4x12 at (220,2,-45) with a wedge ramp S | 0 | isolation bay = the 8-stud gap between the blocks |
| Main Block | (-120,100) | 2 ruins (-135,100),(-105,100); roof plate 62x0.5x21 at y 24.6 | 24.6 | fire stair on the S face: 2 wedges 18 long rising 12 each with a 6x6 landing; Comms prop (-120,25,100); pharmacy crate (-88,0.3,88) |
| Campus road | z=0 | asphalt 600x16 | 0 | Morgue > Field > Triage spine |

Sites: **the Ward** (zone 46x46 at (100,6.5,60); two mouths, beds break the floor into 3
aisles, Shedders drop Crawlers in the aisles); **Triage Lot** (zone 46x46 at (-150,0.6,-170);
Hockers climb the bleacher bank and lob W); **the Roof** (zone 28x28 at (-120,25,100); the
stair landing is the choke). Primaries: Sanitize = beds (82,6,42),(100,6,60),(118,6,78);
Evacuate = 3 survivors at the Ward N door (100,6,88) to the Field; Record = triage whiteboard
(-150,0,-120) to the roof; Comms = roof; Casualties = 6 Bloats in the Ward; not Open the
Route. Index: the Patient out of the bay (220,0,-20) > campus road > the Field's N edge
(40,-120) > Triage Lot (-130,-160) > free chase. Pads: main Field (40,0.6,-180); alt Triage
(-130,-120). Bands: Lost tents burn, PA loops; Held Field lamps, hesco pairs narrow both Ward
doors to 6; Contained a 7th medical tent at (-150,-100) with a stores crate.

---

# D. Risks to check in a playtest

1. **Infected stuck on the Pens ring / Depot columns / Ward walls.** Hold a Secure at the
   Pens for 60 s, screenshot from 80 studs up over (-250,120). Wrong = clusters pressed against
   the outer hesco faces, enemy count flat at max-alive. Fix: the nudge rule and spawn points
   at the mouths; if still bad, drop the N and S rows' outer two pieces.
2. **Floating or sunk dressing on hill edges.** The Pens hesco and the Gate T-wall line are
   the risk. Two head-height screenshots: along the Gate line from (-200,2,-285) looking east,
   and along the Pens N row from (-290,8,147). Fix: move the piece 2 studs onto the flat.
3. **Flare under the bridge** at (-30,-45): if the pallet lands on the deck above, land it by
   a raycast from the flare's resting point + 2, not from the sky.
