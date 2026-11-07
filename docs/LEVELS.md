# Levels: Checkpoint Delta redesign, Mile 14, Aid Station Kestrel

Layout spec from the level designer, 2026-11-07, for the operations structure in
`docs/PROGRESSION.md`. Frame: 600 x 600, origin centre, +X east, +Z north (ArenaService
convention). Positions are (x, z) of a piece's bounds centre; y only where it matters. Ground
is raycast.

Status (2026-11-07): **Delta A1/A2 built** in `ArenaService` (spawn on the LZ, the Gate line +
booth + siren light, the bus line with the new `env_bus`, the Pens terrace + hesco ring +
tents, the Overlook summit cleared, the Depot columns + generator + alternate pad, the Ridge
whiteboard) and the **nudge rule** in `EnemyService`. Not built: everything that needs a
system that does not exist yet (A5 Primary props and points, A6 the Warden, A7 stores crates
and Secondaries, A9 per-site spawn points, A10 Containment band dressing, the siren sound),
and Mile 14 / Kestrel (section C).

Two engine facts that drive every site:

1. **No pathfinding.** A closed wall is a safe room; a stuck Infected fills the max-alive cap
   and starves the spawner. Every site has 3+ open approaches, and the one code change this
   spec depends on is a **nudge rule** in `EnemyService` repath: if an Infected moved < 1 stud
   since the last repath and its target is > attackRange away, `MoveTo(position + 8 studs
   perpendicular to the target, alternating sign)`.
2. **Hocker geometry.** Plants at 40 studs, throws to 55, needs a clear line from +7 studs
   above its head. Hesco (4.6) and sandbags (4) stop Walkers, not spit. Buses (12.5) and
   T-walls (12.5) stop both. Low cover = melee funnel, tall cover = Hocker shadow.

## Checkpoint Delta as it stands

Reads well: the comm tower on the 16 tier is visible from anywhere; the main road under the
bridge gives a spine; the Compound hold with four climbable slopes is a real fight; the four
outer districts each have a silhouette. Dead space: the south-west Barracks, the origin spawn
pad (the run starts in the middle of nowhere), the Scrapyard south of the Inner Gate. Three
changes first: (1) start and end at the helipad so the LZ is known from minute one and the
walk south to the Gate is the stage's main street; (2) turn the far checkpoint into a real
Gate: a full T-wall line across z = -274 with one 24-wide lane, buses queued inside it, the
Warden spawning beyond it; (3) pull the Parade Terrace against the west wall and ring it in
hesco with three mouths, so the Pens is a low funnel site that plays nothing like the Compound.

---

# A. Checkpoint Delta

## A1. Keep / cut / add

| Keep (works) | Why |
|---|---|
| All hills except ParadeTerrace; levels 0/8/12/14/16 | Height set is right; everything climbable |
| Main road x=-30, north road z=200, bridge x -46..-14 (underside 10.5) | The spine; the Warden walks it |
| Compound dressing as built | The Secure fight works today |
| Helipad (-90,-90) 40x40 | Becomes insert + extract |
| Depot pad concrete x155..285, z-5..105; Suburb ruins; Ridge ruin (burning) + tower | Silhouettes per district |

| Cut / move | Why |
|---|---|
| Origin `SpawnPad` part + SpawnLocation at (0,2.5,0) | Insert is at the pad. SpawnLocation moves to (-90, 0.6, -90). The 44x44 Apron concrete stays as "the Apron" (boss ground) |
| Checkpoint booth at (-30,-112) | Sits in the road; the Warden must pass. Move to (-58,-120) yaw 0 |
| Far checkpoint (-30,-262) + its 4 T-walls | Replaced by the Gate line at z=-274. Old z crossed the SouthRise slope foot (-266.6) |
| Hesco x3 at (-180, 100..114) | Belonged to the old terrace; cut |
| Container (270,100) Depot | Alt pad goes there |
| Wreck (20,-200) Scrapyard | Bus line goes there |
| Overlook guard tower (116,-116) | Off the summit to (142,-100) on the ground; the 40x40 top is freed for a 4-player hold |
| ParadeTerrace (-235,120) | Move to (-250,120): west edge 6 studs from the arena wall, which closes its west side |

## A2. Final landmark list

| Landmark | Centre | Bounds (top) | Level | Built from | Job |
|---|---|---|---|---|---|
| Helipad "the LZ" | (-90,-90) | x-110..-70, z-110..-70 | 0 | pad + H + ring (as built); 3 lamps; add jersey (-100,-116) 0, (-80,-116) 0; keep (-60,-70) | Insert, extraction. Open S/W, embankment N (Hocker gallery), road E |
| Inner Gate | (-30,-112) | lane x-42..-18 | 0 | T-walls (-54,-112),(-46,-112),(-14,-112),(-6,-112) yaw 0; booth (-58,-120) yaw 0; bunker (-52,-98) yaw 0; container (-8,-84) yaw 70; jersey (10,-78) yaw 80 | Screening lane; flare spot 1; stores #4; the Warden's second checkpoint |
| the Apron | (0,0) | 44x44 concrete | 0 | as built; container (30,-10) yaw -15; wreck (-27,28) on the road | Boss ground (A6) |
| Screening Compound | (70,70) | x25..115, z25..115 | 8 | as built | Site 1 |
| Compound upper tier | (94,94) | x82..106, z82..106 | 16 | comm tower (94,94), T-walls (84,100),(84,92) yaw 90, hesco (100,84) | Restore Comms, Record B, the lookout south |
| Ridge | (-100,45) | x-130..-70, z23..67 | 8 | ruin (-104,48) burning; tower (-78,30); jersey (-82,60) yaw 20; whiteboard Part 6x4x0.3 at (-87,11,48) facing +X; stores crate (-90,8.3,40); Record A at (-90,8,56) | Stores #2, story spot 1, Record A, flare spot 3 |
| the Pens | (-250,120) | x-285..-215, z90..150 | 6 | hill 70x60 h6 + ParadePad (-250,6.15,120) 56x46; 20 hesco ring (A3); tents (-266,102),(-266,120),(-266,138) yaw 0; lamps (-218,160),(-200,120) | Site 2, Sanitize |
| Overlook | (105,-105) | x85..125, z-125..-85 | 14 | bunker (104,-108) yaw 180 (opening south); tower moved to (142,-100); jerseys (60,-80) 30, (60,-110) 30 | Site 3 |
| Highway | z=-45 | x-300..300, z-54..-36 | 12 | as built | Hocker gallery over the LZ, Overlook and Apron; the ridge route W-E |
| Depot | (210,40) | pad x155..285, z-5..105 | 0 | A4 table | Stores #1/#3, Confirm Casualties, generator, alt pad |
| the Gate | (-30,-274) | wall x-300..300; lane x-42..-18 | 0 | 71 T-walls at z=-274, centres x=-294+8k, skip k=32,33,34; booth (-54,-262) yaw 0 (boom along the wall, tip at x-43); siren = lamp post (-10,-264) + 1.5x1.5x1 Part at y 11 + looping Sound + red PointLight | Index entry, Open the Route, Silence the Alarm |
| Bus line | (-4,-196) | x-9.5..1.5, z-263..-129 | 0 | 3x env_bus yaw 90 at (-4,-150),(-4,-196),(-4,-242); 4th bus (40,-205) yaw 60 | Hocker-proof cover on the Gate approach; Bus 7 = (-4,-242): story spot 2 + Sealed Bus |
| Outside the wire | z-275..-298 | the strip | 0 | Contained humvee (-62,-288) yaw 30 (A10) | Warden spawn (-30,-290); Open the Route point (-30,-288) |
| Suburb / Scrapyard / Barracks outer | as built | | 10/8/0 | NorthBluff tower, SouthRise tower, ruins | Misdrop crates: (20,250) Suburb, (-250,-20) Barracks, (235,12,-205) Depot Mound |

## A3. The three sites

**Site 1: Screening Compound** (zone (50,8.5,50) 46x46, as today)
- Approaches: 4 slopes. Direct: W slope (foot x15) and S slope (foot z15). Indirect: N slope
  through the tents (42,88/104) and wreck (62,104); E slope through the containers (100,44/55).
  Upper tier slopes (x,z >= 72) drop Infected onto the zone's NE corner.
- Cover: hesco column (34,40..54) W; T-walls (55,34),(63,34) + bunker (86,34) S; containers E.
- Hocker stands: upper tier SW corner (84,16,84), 45 from centre (the main threat); ground W
  (8,0,50); ground S (50,0,8).
- Squad holds: zone centre to the T-wall line; one player on the W hesco. Escape: N slope.
- Spawn arcs: A = W/S ground x-5..15 z20..80 and x20..80 z-5..15; B = N/E ground z130..145
  x40..110 and x130..145 z30..100.

**Site 2: the Pens** (zone (-240,6.5,120) 46x46)
- Hesco ring on the terrace top, 3 studs in from the edge: N row z=147, S row z=93,
  x = -283,-276.4,-269.8,-263.2 | -236.8,-230.2,-223.6,-217 (8 each; mouth x-260..-240);
  E column x=-218 yaw 90, z = 100,106.5 | 133.5,140 (4; mouth z110..130). West: the arena wall.
- Approaches: exactly three mouths N, E, S. Tents (roof walkable) on the west half are
  climbable cover inside.
- Hocker stands (outside the ring, lobbing over hesco): N (-250,170), E (-190,120), S (-250,70).
  The squad must step through a mouth to kill one: that is the Pens' cost.
- Squad holds: the yard east of the tents (-236,120); solo holds the SW tent corner (-256,108).
  Escape: E mouth to the Ridge, N mouth to the NorthBluff tower.
- Spawn points: N (-250,165),(-235,170); E (-195,120),(-190,135),(-190,105); S (-250,75),(-262,72).

**Site 3: the Overlook** (zone (105,14.5,-105) 28x28)
- Approaches: 4 slopes, all in view. The N slope foot (z-68.2) meets the highway's S slope
  foot (z-68.4): a continuous ridge route to the deck.
- Cover: the bunker (104,-108) opening south; nothing else on top. Jerseys at (60,-80),(60,-110).
- Sight lines: everything. Gate lane 207 studs SSW, Depot aisles 110 E, LZ 195 W.
- Hocker stands: highway deck (105,12,-52) 51 from centre; ground E (150,0,-105); mid-slope.
- Squad holds: in and behind the bunker. Escape: N slope onto the deck, west to the bridge.
- Spawn arcs: A = highway deck z-52..-40, x80..130 (Hocker-weighted); B = S/E ground
  x90..150 z-150..-135 and x140..150 z-130..-80.

## A4. Depot (replaces the existing Depot block)

| Piece | Position | Yaw | Note |
|---|---|---|---|
| container olive/rust/olive/rust | (172,20),(172,44); (198,20),(198,44) | 90 | columns A, B (22 along z) |
| container olive/rust/rust/olive | (224,20),(224,44); (250,20),(250,44) | 90 | columns C, D. Aisles A1 x177..193, A2 x203..219, A3 x229..245, open N and S, 2-stud slit mid-column |
| T-walls | (170,-10),(178,-10),(186,-10) | 0 | generator blast screen (as built) |
| generator | (178,-2) | 0 | Lights On prop |
| hesco row | (170..191,70) x4 | 0 | yard N fence west half (as built) |
| container rust | (214,100) | 0 | N fence east half |
| alt helipad | (255,85) | | 40x40 pad + H; marker (255,0.6,85) for Light the Pad |
| tower (280,40), checkpoint (160,120), tents (215,140),(240,140), lamp (160,90), bunker (235,-205), wreck (180,-150) | as built | | |
| stores crates | A1 (185,0.3,32); A3 (237,0.3,32) | | #1 always; #3 at Held+ |

## A5. Primary placements

| Primary | Where | Props / points |
|---|---|---|
| Secure the Site | any of the 3 sites | zones as in A3 |
| Sanitize | the Pens | interact points at the tents' east faces (-254,6,102/120/138); on ignite burn the tent + wave of 8 split across the three mouths |
| Recover the Record | Ridge to comm tower | A (-90,8,56); B (88,16,88). Carrier walk ~230 studs; the highway deck shells the road crossing |
| Restore Comms | Compound upper tier | prop (88,16,88); survive 60 s on the 24x24 tier |
| Confirm Casualties | Depot aisles | pen x165..257, z0..64; 6 marked Brutes at aisle ends (185,2),(185,62),(211,2),(211,62),(237,2),(237,62) |
| Open the Route | the Gate | 4 jersey barriers across the lane at z-274, x-39,-33,-27,-21 (only when drawn); 3 shootable lock blocks at (-36,2.9,-274),(-30,2.9,-274),(-24,2.9,-274); point beyond (-30,0,-288) |
| Evacuate | never at Delta | |

## A6. Index entry: the Warden

- Spawn (-30,-290). Waypoints: (-30,-274) Gate lane, (-30,-200), (-30,-112) Inner Gate lane,
  (-30,-45) under the bridge, (-30,0) Apron, then free chase.
- Lane: 24 wide at both gates (x-42..-18), 16-wide road elsewhere: lamps at x=-42, buses at
  x >= -9.5, nothing else within 10 studs. Bridge underside 10.5 vs a 2x R15 at ~10.4 (D3).
- First seen: from the Compound upper tier or the bridge parapet the whole road; from the
  Overlook over the Scrapyard; from the LZ when it clears the Inner Gate. Health bar
  billboard MaxDistance 1000.
- Boss ground: the Apron plus open ground x-20..25, z-36..25. The container (30,-10) is the
  one line-breaker; the Compound W slope the retreat up, the road under the bridge south.

## A7. Pads, stores, Secondaries

| Thing | Position |
|---|---|
| Main pad (insert + extract) | (-90,0.6,-90), hold zone 28x28 as today |
| Alternate pad | (255,0.6,85) on the Depot pad; painted at Contained, else after Light the Pad |
| Stores crates | #1 Depot A1 (185,0.3,32); #2 Ridge (-90,8.3,40); #3 Depot A3 (237,0.3,32) [Held+]; #4 Inner Gate bunker (-52,0.3,-98) [Contained] |
| Silence the Alarm | siren at the Gate (-10,-264) |
| Lights On | generator (178,-2) |
| Light the Pad | (255,0.6,85) |
| Sealed Bus | Bus 7 (-4,-242); Runner burst spawns at (-20,-242),(12,-242) |
| Misdrop | one of (20,250), (-250,-20), (235,12,-205) |
| Headcount story spots | 1 Ridge whiteboard (-87,11,48); 2 Bus 7 "NEG" decal on its west flank (-10,6,-242); 3 the Pens' tent 2 door (-254,6,120) |

## A8. Resupply guidance

Good flare spots: **Inner Gate pocket (-52,-98)** (bunker U, T-wall line N, bus line E;
fallback up the highway S slope); **Depot aisle A2 (211,32)** (containers three sides, two
mouths); **Ridge top (-100,8,45)** (ruin W, tower SE, four short slopes). Bad: **the LZ**
(open four sides, the deck above is a 45-stud Hocker gallery); **the Overlook summit** (no
fallback); **under the bridge** (the pallet's sky raycast lands it on the deck above).

## A9. Spawn rings

- Ambient: around players, 35-50 (code as is) plus the nudge rule.
- Site waves: replace the random 25-35 ring with per-site point lists (A3).
- Extraction at the LZ: N deck (-90,12,-45) Hocker-weighted; S (-90,-150); W (-150,-90);
  E road (-30,-100). Alt pad: N (255,140); S deck (255,12,-45); W aisle (211,32).
- Warden call: no extra wave; the Index walks alone.

## A10. Containment band dressing

| Band | Lamps lit | Fires | Sound | Pads / stores | Gate |
|---|---|---|---|---|---|
| Lost | none | Ridge (-104,48), Suburb (-120,240), Barracks (-250,-60) | siren loops | 2 stores | wall only |
| Contested | none | same | siren loops (Secondary can silence) | 2 | wall only |
| Held | MainRoad group: x=-42 at z -230,-180,-80,-20,60,120,180,240 | Ridge smoke only | silent | 3 (+Depot A3) | wall only |
| Contained | all: + LZ (-114,-114),(-66,-114),(-114,-66); District (60,210),(200,210),(160,90),(260,-120),(-170,60),(-170,-100),(-218,160),(-200,120) | none inside the walls | wind | 4 (+bunker); alt pad painted | intact humvee (-62,-288) yaw 30: wreck mesh, TextureID cleared, Color olive, two SpotLights raking the lane |

---

# B. New environment pieces (reuse first)

| Piece | Size (studs) | Pivot | Collision | Derive from | Needed by |
|---|---|---|---|---|---|
| **env_bus** | 42 x 12.5 x 10 (L x H x W) | bottom centre | Box | env_container (box + 4 wheel blocks + window band) ~400 tris | Delta bus line (4), Mile 14 the Jam (24). The one mesh that matters |
| **env_water_tower** | 16 x 48 x 16 | bottom | Box | env_comm_tower + tank cylinder | Mile 14 landmark + Restore Comms |
| **env_hospital_bed** | 6 x 2.8 x 3 | bottom | Box | crate + 4 legs ~120 tris | Kestrel Ward rows (18) |
| **env_bleachers** | 40 x 8 x 12, four 2-stud steps | bottom | none (the hill wedge under it is the ramp) | stacked boxes ~120 tris | Kestrel |
| env_generator (optional) | 8 x 5 x 4.5 | bottom | Box | box + exhaust stack ~150 tris; Parts until then | Delta Depot, Mile 14 Toll, Kestrel Field |
| env_fuel_pump (optional) | 3 x 6 x 2 | bottom | Box | ~100 tris; Parts until then | Mile 14 Rest Stop (4) |
| env_tent_medical | = env_tent | | | swatch variant (white + red facet) | Kestrel Triage |
| Parts, no mesh | siren head, lock blocks, whiteboards/signs, fire stairs (wedges), canopy, alt helipads, Ward walls (env_twall rows) | | | | |

Toll booth = env_checkpoint as is. PA speaker = lamp post + box. Convoy cargo truck = container.

---

# C. Mile 14 and Aid Station Kestrel

## C1. Mile 14 (full dark)

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

# D. The three things most likely wrong on first playtest

1. **Infected stuck on the Pens ring / Depot columns / Ward walls.** Hold a Secure at the
   Pens for 60 s, screenshot from 80 studs up over (-250,120). Wrong = clusters pressed against
   the outer hesco faces, enemy count flat at max-alive. Fix: the nudge rule and spawn points
   at the mouths; if still bad, drop the N and S rows' outer two pieces.
2. **Floating or sunk dressing on hill edges.** The Pens hesco and the Gate T-wall line are
   the risk. Two head-height screenshots: along the Gate line from (-200,2,-285) looking east,
   and along the Pens N row from (-290,8,147). Fix: move the piece 2 studs onto the flat.
3. **The Warden's walk.** A 2x R15 is ~10.4 tall; the bridge underside is 10.5; Open the
   Route's barrier line must be gone before it spawns. Force the Index with the squad on the
   Apron; screenshot from (0,6,-20) looking SSW as it comes under the bridge. Fix: thin the
   deck to 1.0 (underside 11), or Scale 1.9 for the Warden; keep x-42..-18 free at z -274 and
   -112.

Bonus: flare under the bridge at (-30,-45); if the pallet lands on the deck above, land it by
a raycast from the flare's resting point + 2, not from the sky.

Everything here is table edits to `src/server/ArenaService.luau` (HILLS, DRESSING, a loop for
the Gate line, `buildHelipad` taking a position), a SpawnLocation move, the nudge rule in
`src/server/EnemyService.luau`, and per-site spawn points in the coming StageDefinitions. Net
dressing delta at Delta: about +110 instances, one new mesh (env_bus) required.
