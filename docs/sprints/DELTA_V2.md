# Checkpoint Delta v2: a base, not a field (proposal, 2026-11-11)

**Status: a proposal in Blender only.** Nothing the game loads has changed: no `src/` change,
no MeshAssets row, no upload, and it has **not been tried in Studio** (no colliders, spawns,
pathing, lights or frame rate checked). The owner looks first; the step list at the bottom is
what it takes to put it in the game.

Owner, 2026-11-11: "it kind of just feels like an open field with stuff ... the buildings are
all one story. Only verticality we have is like the road ... some of the car models are simple,
but some of them were more complex."

- Generator: `assets/3d/build/delta_v2.py`. Live Blender: `import delta_v2 as dv; dv.build();
  dv.build_today(); dv.show("v2")` (scene `Delta_v2`; `dv.show("today")` swaps to today's map
  rebuilt from `Missions/Delta.luau`). Headless: `blender --background --python
  assets/3d/build/delta_v2.py` renders every preview and writes `assets/3d/delta_v2.blend`
  (not committed).
- Kit: `assets/3d/build/delta_kit.py`, built by `build_assets.py` only with `-- --delta-v2`.
- Previews: `assets/3d/build/previews/delta_v2_*.png`. `topdown` has the names; each
  `pair_*_before` / `pair_*_after` is today and v2 from one viewpoint; `vehicles` is the audit
  sheet.

## Why today's Delta reads as a field

Seen by rebuilding it from its own data and looking from above and from eye height:

1. From above it is two crossing roads and about ten separate mounds and pads on bare dust,
   60 to 150 studs of empty ground between them; nothing (wall, lot, street) joins them.
2. At eye level ground and sky fill the frame. Height comes from earth mounds, not buildings:
   one 24x18 two-storey block, the rest huts and ruins.
3. The Gate is a wall at the south edge with buses standing on open dust: no road through it,
   no inside and outside.
4. The skyline is an even ring all round, so nothing says which way the city is.
5. Vehicles are two generations: profile-built cars (850 to 970 tris) next to a box-built bus
   (712 tris, 42x10x12.5, oversized) and a box humvee (392 tris).

## The layout

Studs; the frame stays 600x600, +X east, +Z north, the city is south. The highway (x -18..18)
runs the whole map and through the Gate at z -112. South of the Gate is outside (where
civilians were screened), north is the base.

| Layer | Place | Where | What it is |
|---|---|---|---|
| Outside | The Approach | x -18..18, z -300..-112 | Jam on the west carriageway, the east one clear (the Warden's road, spawn (10, -292)), sign gantry z -236, Bus 7 at (-11, -166) |
| Outside | Screening Lot, Screening Block, the Rows | x -140..-30, z -280..-130 | Frame tents, decon tents, a 2-storey block (-100..-56, -236..-216), body bags in rows |
| Outside | **The Pens** (Site 2) | x -264..-164, z -260..-148 | Hesco ring, three tents, chainlink runs; zone (-214, -204) |
| Outside | Bus Park, Impound, Inspection Bay, Customs House | x 40..260, z -290..-125 | Buses in bays, one rammed through the wall (breach x 80..112), a canopy (top 12), a 2-storey house |
| The line | **The Gate** | z -112, whole width | T-wall line; Gatehouse = two towers (x 14..32 each side, roof 21) joined by a walk over the road at 12; siren on the east tower |
| Base | The Yard | x -60..60, z -112..-10 | The boss ground: 120 wide, hesco bays for cover, Workshop to the east |
| Base | Barracks, Armoury | x -244..-100, z -100..-16 | Two 2-storey blocks facing a court, steel galleries at 9, a bridge between them |
| Base | Command Post, the Mast (**Site 1**, the Compound) | x -128..-56, z 4..128 | 3-storey CP (roof 27); the comm tower on a plinth at 9; zone (-104, 26) |
| Base | Tent Lines, parade square, LZ apron | x -260..-140, z 30..270 | Main pad (-190, 200); Flight Ops, 2 storeys and a cab |
| Base | Service bridge | z 14..28, x -78..66, deck 12 | Over the highway, from the Compound to the deck |
| Base | Motor Pool deck (**Site 3**, the Overlook) | x 66..146, z -6..48, deck 12 | Parking deck, parapet 3.2; zone (104, 12, 20) |
| Base | **The Depot**: the Stacks, the Shed, loading dock, generator yard, Depot apron | x 60..250, z -90..270 | Containers two high with plank ramps and catwalks; shed 13 clear with a mezzanine; dock pit at -4; generator (84, 92); alt pad (150, 216) |
| Edge | Channel, perimeter | x 262..278 at -6; walls at 292 | Three ramps, a culvert, two foot bridges; wall panels and guard towers |

Infected come in at six places: E1 city road (0, -296), E2 south-west wall (-292, -230),
E3 culvert (270, -268), E4 north gate (0, 292), E5 west breach (-292, 104), E6 east breach
(292, 176). Backdrop: the city only to the south (33 towers in three arcs, the jam running
back toward it), pines and far hills on the other three sides.

## Height you can use

| Structure | Height | Ways up | Cover up top | Why you leave |
|---|---|---|---|---|
| Gatehouse (2 towers and the walk over the road) | walk 12, roofs 21 | stairs inside each tower; ladder to each roof | parapet, tower rooms | Hocker lobs reach 12; Runners take the stairs; the Warden passes under (11.2 clear) |
| Barracks A and B | 9 | inside stairs, outside steel stair, the bridge | gallery rail, rooms | galleries are open to the court |
| Command Post | 9, 18, roof 27 | outside stairs, catwalk from the Mast | windows, roof parapet | one stair core: easy to get trapped |
| The Mast plinth | 9 | ramp west, steel stair east, catwalk | crates | open on every side |
| Service bridge | 12 | ramp west, the deck east | two wrecks, parapet | 14 wide, enemies from both ends |
| Motor Pool deck | 12 | vehicle ramp north, steel stair south, bridge, catwalk to the Stacks | parapet 3.2, parked trucks | four ways in for Runners |
| The Stacks | 9.55 and 19 | three plank ramps, catwalks, the catwalk from the deck | cross containers | planks are single file; Walkers cannot follow, Runners can |
| The Shed: mezzanine and roof | 6.5, roof 13 | stair inside; outside a plank onto a container, a steel stair on the east face | crates, roof parapet | the roof is open to Hocker lobs |
| Flight Ops, Screening Block, Customs House | 9 | stairs | windows | small, two doors each |
| Roofs by ladder: Screening Block, Barracks, Armoury, Flight Ops, Dispatch hut | 9 to 21 | ladder | parapet | squad only: bots and Infected do not climb |
| Down: loading dock pit, the channel | -4, -6 | ramps | walls | fire from above |

Rules kept from `docs/LEVELS.md`: Warden lanes 24 wide at gates and 16 elsewhere, 10.5 clear
overhead on his road; Walker steps 4.6, Runner 9.6; ladders are squad only; concertina is
never a vault; pallets in stacks. `dv.check()` finds no piece standing inside another.

## Vehicles and other old models

| Piece | Today | v2 |
|---|---|---|
| prop_car_sedan, hatch, pickup, van | 896, 968, 948, 948 | kept: this is the standard |
| prop_cargo_truck | 856 | kept |
| env_wreck_humvee | 392, boxes | rebuilt: `prop_humvee` 1,068 and `prop_humvee_burnt` 1,152 |
| env_bus | 712, boxes, 42x10x12.5 | rebuilt: `prop_bus` 1,096, 38x8.4, roof 10.5 |
| (none) | | new: `prop_car_suv` 1,060, `prop_ambulance` 1,072 |
| env_hesco | 240 a cell | `env_hesco_row_24` 276 for four cells |
| prop_pallet | 228, laid singly | `prop_pallet_stack` 192 |
| env_tent, env_checkpoint | 124, 192 | `env_screening_tent` 252, `env_decon_tent` 340; the hut gives way to the Gatehouse |
| chainlink and wire perimeter | 190 pieces, 105,640 tris | `env_wall_panel_24`, 168 a panel |

Also new: `env_sign_gantry`, `env_stair_steel_9` / `_12`, `env_catwalk_12`, `env_fuel_tank`,
`env_sat_dish`, `env_pine_stand`, `env_far_hill`, folding tables, luggage, warning sign, drum.

Honest notes: the new vehicles are 10 to 25% heavier than the kept cars (all far under the
5,000 cap). Buildings are still plain Parts; the Shed and the Gatehouse towers are the plainest
things on the map. The far hills are blocky.

## Budgets (measured in Blender, `dv.report()`)

| | Today | v2 |
|---|---|---|
| Mesh instances in play | 397, plus 190 perimeter pieces | 690 |
| Triangles in play | 197,256 (91,616 + 105,640 perimeter) | 180,648 (169,800 meshes + 10,848 in 913 Parts) |
| Outside the walls | (none) | 70 instances, 32,908 |
| Skyline | 46 instances, 42,264 | 66 instances, 59,916 |
| Distinct meshes | 32 | 48 |
| Largest mesh | prop_car_hatch, 968 | prop_humvee_burnt, 1,152 |

Today's Part count is not comparable (the blockout draws each building as one box). Every kit
piece is under its STYLES cap (clutter 200, prop 500, vehicle 5,000). In all, v2 draws about
273,000 triangles against today's 240,000. Not measured: frame rate, memory, colliders
(budget 256), lights (budget 20). Those need Studio.

## To put it in the game (none of this is done)

1. Owner picks: all of it, the layout with today's models, or parts.
2. Build the kit (`build_assets.py -- --delta-v2`), upload to the group, add MeshAssets rows.
3. Write the layout into `src/server/Missions/Delta.luau` (the generator's `PARTS` and
   `DRESSING` lists are in ArenaService's terms: kind, box, yaw) and teach ArenaService two
   new shapes: ground with holes (pit, channel) and ladders.
4. Colliders: one box per vehicle and container, walls as Parts; count against 256.
5. Spawns, pads, sites and objective props from the tables in `delta_v2.py` (`SITES`, `PADS`,
   `POINTS`, `ENTRIES`).
6. Pathing: enemies only chase upward near kit buildings today. The deck, bridge, galleries
   and Stacks need a live test with Walkers, Runners, a Brute, bots and the Warden.
7. Lighting: pick the 20 lights (Gate, pads, sites first); fog and sky toward the city.
8. performance-reviewer and a playtest before it replaces today's map; keep today's Delta
   behind a switch until the owner has played both.

## Questions for the owner

- Is the story right: Delta screened people leaving the city, and fell from inside?
- Is a playable outside (the Approach, south of the Gate) wanted, or should play start at the
  Gate?
- The sites moved and got names (the Compound, the Pens, the Overlook): fine?
- Which pad is the main one (the west LZ apron in v2)?
- Wall panels instead of the chainlink and wire perimeter?
- Buildings stay Parts (cheap, enterable), or become meshes later?
