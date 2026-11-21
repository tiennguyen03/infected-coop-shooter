# LATER.md: designed, not built

Designs moved out of [PROGRESSION.md](PROGRESSION.md) and LEVELS.md on 2026-11-19 so the live spec stays
short. None of this is in the game. Read it only when building one of these, and check it
against `docs/OWNER.md` and `docs/ROADMAP.md` first: later owner decisions may replace it.
The extraction that is built today is in PROGRESSION.md > Extraction.

Contents: [Operation](#operation-the-burn-extraction-scoring-not-built) ·
[Levels on Mile 14 and Kestrel](#levels-on-the-unbuilt-maps-moved-from-levelsmd-section-c) ·
[Mile 14 and Kestrel objectives](#mile-14-designed-not-built) ·
[Mile 14, Kestrel, Harlan missions](#mile-14-not-built) · [Build order](#build-order-what-is-left)

## Operation: the Burn, extraction, scoring (not built)

- **The Burn** (mission timer, 840 s for 1-4 players, 1,200 s on the big Delta map:
  `Config.DeltaXL.BurnSeconds`, docs/sprints/DELTA_XL.md; more players split objectives, time is
  the one resource more-not-tougher does not hand out). Only the Burn counts down on the HUD;
  run time stays a plain readout. At 0:00 the incendiaries land: burning dressing, no more
  pallets, spawn interval x0.5, more alive and +2 Brute/Hocker caps (`Config.Overrun`,
  reserved), the helicopter takes 120 s instead of 90. The run goes on; extracting after the Burn
  scores Partial. Calling the bird freezes the timer.
- **Extraction, designed.** A 90 s hold; on call Walker 10 Runner 4 (+3 Walkers per extra player), a
  second phase-weighted wave of 12 at 45 s, spawn interval x0.6. Progress accrues only while
  every living player is on the pad (MULTIPLAYER_READINESS #3). Secondaries do not shorten it.
  Alternate pads come from "Light the Pad".
- **Secondaries** reward a Secondary crate on site and +3 containment; no timer extension, no
  Resupply.
- **Score per mission:** Win (Primary done, extracted before the Burn) 12; Partial (Primary
  done, extracted or wiped after the Burn) 6; Loss (wiped before the Primary) 0; each
  Secondary +3. Perfect operation = 18 per district.

## Objectives on the unbuilt maps

### Mile 14 (designed, not built)

| Objective | Kind | Idea |
|---|---|---|
| Open the Route | signature main | the lead bus blocks the road; destroy 3 props, reach the point beyond (the Bloat is inside) |
| Burn the Buses | signature main | the sealed buses of the Jam: fire at three, each flushes what is inside |
| Recover the Record, Restore Comms, Confirm Casualties, Secure the Site | shared main | the toll log to the Overpass; the water tower; Hockers on the deck; its three sites |
| Kill the Horn | signature side | a bus horn drawing them (its Silence the Alarm) |
| Sealed Bus (the Jam), toll booth recorder | signature side | |
| Lights On, Misdrop, Clear the Spitters | shared side | Toll Plaza generator; outer areas; Hockers on the Overpass |

### Aid Station Kestrel (designed, not built)

| Objective | Kind | Idea |
|---|---|---|
| Evacuate the Holdouts | signature main | a transponder in the Ward: 2-3 survivors follow the nearest player to the pad alive |
| Clear the Ward | signature main | the Ward's bed rows: burn three, each flushes a wave |
| Recover the Record, Restore Comms, Confirm Casualties, Secure the Site | shared main | the manifest to the roof; the roof mast; Bloats in the Ward; its three sites |
| Kill the PA | signature side | the PA loop drawing them |
| Lights On, Misdrop, Light the Pad | shared side | the Field generator; outer areas; the Triage Lot |


## Missions not built

### Mile 14 (not built)

- **Was:** the evacuation convoy out of Harlan, stalled where the highway crosses the county
  road. Buses sealed with the bitten aboard; the drivers went over the rail.
- **Sites:** the Overpass (high, narrow, two approaches, Hockers arc up); the Toll Plaza
  (lane barriers make chokepoints, booths block sight); the Rest Stop (low, open on all
  sides, pumps burn when hit).
- **Primaries:** Secure, Sanitize (sealed buses), Recover the Record, Restore Comms (water
  tower), Confirm Casualties (Hockers on the deck), Open the Route (lead bus), Evacuate (diner).
- **Index:** the Bloat bursts out of the lead bus in the Jam and comes down the ramp. Its
  death cloud sits on the main route.
- **Story spots:** highway sign hand-amended "HARLAN 14 – NO ENTRY – QUARANTINE IN EFFECT";
  toll booth radio log ending "they're opening the buses, don't let them".
- **Band dressing:** Lost: full dark, pumps burning, stuck horn. Held: Toll floodlights,
  pumps out, one lane cleared through the Jam. Contained: lane lights, sign amended "ROUTE
  OPEN – HOLD SOUTH", a convoy truck idling at the toll.

### Aid Station Kestrel (not built)

- **Was:** a high school turned forward aid station. Triage kept treating the bitten; the
  wards became the outbreak. Beds in rows, every one empty, every restraint cut.
- **Sites:** the Ward (enclosed, two mouths, Shedders among the beds, no room to kite); the
  Triage Lot (tents as cover, open to the field, Hockers lob from the bleachers); the Roof
  (highest, one stair up, Runners climb everything).
- **Primaries:** Secure, Sanitize (Ward beds), Evacuate (the "ALIVE INSIDE" payoff), Recover
  the Record, Restore Comms (roof), Confirm Casualties (Bloats in the Ward). Not Open the Route.
- **Index:** the Patient comes out of the Morgue's isolation bay and arrives through the
  Triage Lot.
- **Story spots:** triage whiteboard "BITTEN → WARD B", "WARD B" crossed out, "ALL" written
  over; gym roof painted "ALIVE INSIDE" for the helos, paint still fresh.
- **Band dressing:** Lost: tents burning, PA looping. Held: Field lights, PA silent, hesco at
  the Ward doors. Contained: generator hum, a medical tent re-pitched with a Stores crate,
  "EVAC'D" painted under "ALIVE INSIDE".

### Harlan Yard and Harlan Reservoir Station (canon, not scheduled)

Harlan Yard (rail yard; Index the Lineman; Kites first appear). Harlan Reservoir Station (the
dam and research station; Index the Specimen; Growths everywhere). When they exist the
operation is five missions and Second Pass moves after the Reservoir.


## Build order (what is left)

Done: data-driven enemies, Resupply and the loadout, ADS and headshots, the run state machine
(`Lobby → Insert → Explore → Primary → Index → Extract → Ended`, Co-op Sprint A), bots, the
Warden. Next, each one playtest-verified feature:

1. **Objective pools.** First slice built 2026-11-11, unplayed (Objective pools above). Left on
   Delta: Open the Gate, Sealed Bus, Light the Pad, Sample Run, Headcount, Recover Logs.
2. **Operation.** `RunManager` adds next mission / Stand Down / Second Pass with mission
   index and pass count; `OperationService` owns the Burn and overrun; extraction becomes the
   called 90 s hold with waves.
3. **Containment Board.** `WarMapService` (one shared DataStore board, after F9), band
   overrides at mission load, the board screen between runs.
4. **Mission definitions.** `src/shared/StageDefinitions.luau`: landmark/hill/dressing
   tables, lighting, sites, Index entry, pads, stores, spawn phases, form unlocks, band
   dressing; `ArenaService` builds whichever is active. Then Mile 14 + Bloat, Kestrel +
   Shedder/Crawler + Patient, Stand Down and Second Pass, Harlan Yard and the Reservoir.

Co-op Sprint B (shared-pickup rules, event routing) threads through as each system is touched.

Not scheduled:
- **Meta between runs:** the Containment Board plus unlocks (call-ins, field upgrades, guns;
  launch target 5 primaries + 3 sidearms, 4 throwables, 2 heavy call-ins, 2 specials; +3-4
  guns per drop). Today every call-in is unlocked from run 1.
- **Bots:** vaulting, the other call-ins (Shrike, emplacements, supply), a voiced radio line.
- **Sound:** Control's voiced radio lines, the Burn, pickup one-shots
  (`assets/audio/README.md`).

## Levels on the unbuilt maps (moved from LEVELS.md section C)

### C. Mile 14 and Aid Station Kestrel (not built)

#### C1. Mile 14 (full dark)

**First pass built** (2026-11-11, `src/server/Missions/Mile14.luau`, played in Mile 14 Dev): the deck in two halves (HighwayS, HighwayN) with the Culvert between, the Jam (22 buses, none over the Culvert), the Toll Plaza lot with its four booths and jersey pairs, the Rest Stop diner and lot, and woods (Nova: "some wooded areas in it") on the east shoulder south, the west shoulder north, behind the Toll Plaza and behind the Rest Stop, now real woods (`build/trees.py`: tall and young pines, a broadleaf now and then, a shrub for every third tree) and brush along both foots of the deck to creep past the Jam; night lighting (`Config.NightSky`, [STYLES.md > Mile 14's night](STYLES.md#mile-14s-night)). Not yet: the Overpass, the off-ramp, pumps and canopy, the water tower, placed sleepers, objectives. Played quiet: [PROGRESSION.md > Awareness](PROGRESSION.md#awareness-the-quiet-missions).

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

#### C2. Aid Station Kestrel (dawn)

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

