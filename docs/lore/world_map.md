# The Harlan Corridor: the Plot's map

Canon as of 2026-11-10 (lore developer; owner approved "make changes however you feel is
best"). The paper map on the Plot's table ([LORE.md > The Carrier](../LORE.md#the-carrier)).
It is the only world map in the game; anything that names a place outside a mission map
takes it from here.

## The land in one paragraph

The coast runs east to west along the bottom. The Carrier holds station offshore, south of
Delta. Route 9 runs north from the coast road through the five districts to the dam: Delta
(the screening gate nearest the sea), Mile 14 (where Route 9 crosses County Road 40, fourteen
miles short of Harlan), Kestrel (the town, its high school the aid station), the Yard (the
rail yard on the edge of Harlan town) and the Reservoir (the dam, the lake and the research
station). The Harlan River runs out of the dam spillway down the west side of the corridor to
the sea; the rail line runs down the east side from the Yard to the port at Marlow. The
quarantine line is two fences, west and east, from the coast to the hills. Outside it the two
coast towns, Brennan and Marlow, have had their Burn, and so has a belt of forest west of
Mile 14: that is the skyline burning beyond the walls.

## Schematic (10 x 7 grid; x 0 west to 10 east, y 0 south to 7 north)

Rectangles are `{x0, y0, x1, y1}`; points are `{x, y}`. Labels are short for SurfaceGui text.

**Regions**

| Name | Kind | Box | Label |
|---|---|---|---|
| sea | water | 0, 0, 10, 0.9 | OPEN WATER |
| delta | district | 3.1, 0.9, 7.0, 2.2 | DELTA |
| mile14 | district | 3.1, 2.2, 7.1, 3.6 | MILE 14 |
| kestrel | district | 3.1, 3.6, 7.2, 4.9 | KESTREL |
| yard | district | 3.2, 4.9, 7.2, 5.9 | THE YARD |
| reservoir | district | 3.4, 5.9, 7.2, 7.0 | RESERVOIR |
| lake | water | 4.0, 6.3, 6.4, 7.0 | HARLAN RESERVOIR |
| brennan | burn zone (town) | 2.0, 0.9, 3.0, 1.8 | BRENNAN - BURNED |
| marlow | burn zone (town) | 7.4, 0.9, 8.8, 2.6 | MARLOW - BURNED |
| westburn | burn zone | 1.8, 2.4, 3.0, 4.2 | BURNED |
| westforest | forest | 0.3, 4.2, 3.0, 6.8 | STATE FOREST |
| ridge | forest | 7.4, 3.4, 9.6, 6.8 | HIGH RIDGE |

**Points**

| Name | Kind | At | Label |
|---|---|---|---|
| carrier | ship (grease-pencil mark) | 6.8, 0.4 | CARRIER |
| gate | site | 5.2, 2.1 | THE GATE |
| kestrelhs | site | 4.5, 4.2 | KESTREL HS |
| harlan | town | 6.2, 5.5 | HARLAN |
| station | site | 5.8, 6.1 | STATION |
| port | site | 7.8, 1.0 | PORT |

**Lines**

| Name | Kind | Points | Label |
|---|---|---|---|
| route9 | road (main) | 5.0,0.9 5.1,1.6 5.2,2.2 5.4,2.9 5.1,3.8 4.8,4.4 5.2,5.0 5.6,5.6 5.4,6.1 | ROUTE 9 |
| county40 | road | 1.0,3.1 3.0,3.0 5.4,2.9 7.5,3.1 9.8,3.4 | CO RD 40 |
| coastrd | road | 0.5,1.2 2.9,1.3 5.0,1.0 7.8,1.2 9.5,1.4 | COAST RD |
| rail | rail | 5.6,6.1 6.2,5.4 6.8,4.4 6.9,3.0 7.3,1.8 7.8,1.0 | RAIL |
| river | river | 4.9,6.3 4.3,5.4 3.7,4.4 3.8,3.2 4.0,2.0 3.9,0.9 | HARLAN RIVER |
| dam | dam | 4.6,6.3 5.4,6.3 | DAM |
| cordonW | cordon | 3.1,0.9 3.1,3.6 3.2,5.0 3.6,7.0 | QUARANTINE LINE |
| cordonE | cordon | 7.0,0.9 7.1,3.5 7.2,4.9 7.2,7.0 | QUARANTINE LINE |
| border1 | district border | 3.1,2.2 7.0,2.2 | (none) |
| border2 | district border | 3.1,3.6 7.1,3.6 | (none) |
| border3 | district border | 3.2,4.9 7.2,4.9 | (none) |
| border4 | district border | 3.4,5.9 7.2,5.9 | (none) |
| lantern | grease-pencil track | 6.8,0.4 5.6,1.2 5.1,1.6 | HELO |

**Title, legend, stamp**

- Title: HARLAN CORRIDOR. Under it: QUARANTINE AREA - SHEET 1.
- Legend: ROAD, RAIL, RIVER, QUARANTINE LINE, DISTRICT BORDER, BURNED.
- North arrow: N, top right.
- Stamp (bottom corner, red): HARLAN CONTROL - PLOT COPY - DO NOT REMOVE.
- Grease pencil on the paper (the map is used, not printed clean): the five district names
  are the printed map's; the cordon, the district borders, BURNED, the helicopter track and the
  CARRIER mark are grease pencil over it. One pencilled note in the margin: CONTAINED IS NOT
  CLEAN.

## Rules

- The order south to north never changes: coast, Delta, Mile 14, Kestrel, the Yard, the
  Reservoir. The Carrier is always south, offshore.
- Mile 14 is fourteen miles short of Harlan town by Route 9 (its hand-amended sign).
- Brennan, Marlow and the west forest are outside the line and already burned; no mission
  goes there. A new district goes inside the line, between the fences.
- The map is paper. No lights, no moving markers. The Containment Board is the live thing.
