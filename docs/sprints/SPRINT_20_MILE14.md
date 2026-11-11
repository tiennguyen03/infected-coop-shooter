# Sprint 20: Mile 14 design pack and first 3D look (2026-11-09)

The owner asked the design team for the next mission, Mile 14 (new enemies, a new boss, a map
that looks different from Delta), with every 3D piece designed in Blender. This page holds the
team's proposal. **Not canon until the owner approves:** CHARACTERS, LORE, PROGRESSION and
LEVELS still describe the old plan, so apply each decision there once it is approved.
Nothing in the game changed. The meshes are built but not uploaded.

Renders (`assets/3d/build/previews/`): `map14_cast.png` (the Driver on the ramp, Possums on
the shoulder), `map14_first_view.png` (from the main pad), `map14_span_north.png`,
`map14_reststop.png`, `map14_oblique.png`, `mile14_lineup_draft.png` (the new bodies next to
the Delta roster).

## Owner decisions (one recommendation each)

| # | Decision | Recommendation | Why |
|---|---|---|---|
| 1 | New common form: a body on the road that gets up (lore name **the Possum**) | yes | The highway's horror moment ("the body in the lane got up"). Lore and systems proposed it independently |
| 2 | Rename the Index from "the Bloat" to **the Driver** and redesign him | yes | The old design was "a common Bloat half again as large", which breaks the bosses-are-their-own-design rule |
| 3 | Common Bloat on Mile 14? | **no** (systems), keep it Kestrel's | Lore said yes; systems said no (two gas makers crowd `MaxPuddles` 8; Kestrel keeps an identity). The engineer sides with systems |
| 4 | The Possum pins a soldier | not in v1 | v1 wakes and hunts; a pin needs a co-op rescue rule and bot support |
| 5 | Fire burns gas off with a flash (pumps now, Incendiary and Kettle later via `Ignites` on the item row); the frag does not ignite | yes | The moment players will retell |
| 6 | Driver 9,000 HP, a 75-90 s fight | accept, measure in a playtest | |
| 7 | The level designer's layout fixes (below) and the new kit | yes | The old C1 had 7 placement breaks |
| 8 | Overpass gets 4 approaches; the water tower is not climbable; the Culvert is too low for a Brute or the Driver; ground is dead grass | yes | 3+ approaches rule; no free camp; "the Brute couldn't follow us in" |
| 9 | Driver trousers navy (`paint_navy`), Possum trousers `concrete_d` | yes | Asphalt reads black |
| 10 | Build the art now and the mission in game after build order items 1-3 (PLAN: no new missions before objective pools work on Delta) | yes | |

## The Possum (common form, Mile 14 on)

- **Was:** a bitten convoy passenger. The convoy medics laid the worst cases on the hard shoulder
  under foil blankets and tagged them black (expectant). Nobody came back.
- **Rule:** it spawns lying down among the real dead and stays still until a soldier comes within
  9 studs, it is hit, or a lure reaches it. Then it rises (0.7 s) and hunts. After 30 s it rises
  anyway. Tell: a wet breath within 25 studs, the foil crackle, and **one bare foot** (every
  dead body wears two shoes).
- **Numbers:** 40 HP, speed 13, 15 damage, range 4, cooldown 1.0, headshot default, supply 12,
  cost 1.5, climb 5. Cap `{ {180, 2} }`, late 4. Limbs come off like a Walker's.
- **New hook:** `Behaviour.Dormant = { WakeRadius = 9, WakeOnHit = true, WakeOnLure = true,
  RiseTime = 0.7, Timeout = 30 }`. Dormant holds the `knockdown_back` last frame; waking plays
  `getup_back` into `downed_crawl`. Bots skip `Dormant` targets; sentries shoot them. The
  HumanoidRootPart gets `CanQuery = false`, or shots above the crawling body count as hits.
- **Look (built, `possum_limb` in `build_assets.py`):** pallor; a pressure sore, lividity and
  an ear gone to rebuilt on the side it lay on; tan cardigan over a pus-soaked shirt; the gold
  foil wrapped round the left shoulder, front and back; elbow and knee calluses; the black
  triage tag strapped to the right forearm; one shoe, one bare foot. 1,428 tris (cap 2,000).
  Stock limb lengths: the pose comes from the clips, not the mesh.

## The Driver (Mile 14 Index host)

- **Was:** the lead-bus driver. He chained his bus shut and stayed belted in with the keys.
  The toll booth's "they're opening the buses, don't let them" was meant for him. He was bitten
  through the cab partition and never unbuckled.
- **Look (built, `driver.py`):** an "h" outline. The torn-off driver's seat towers behind him
  (welded to the LowerTorso). A two-lobe belly is pinched by the lap belt and hangs between
  bowed knees. A small capped head juts forward. Grey transit shirt with a name badge, navy
  trousers, a glove on the right hand, the bus keys on the left wrist. Parts:
  `inf_driver_part_seat` / `_belly` (swells 1.15x over the vent tell) / `_buckle` (flies off
  at death). 2,156 tris with the parts (cap 5,000), scale 1.6.
- **Entry:** he bursts out of the lead bus's windscreen (-14,12,-270). Path: west shoulder
  (-24,12,-248), landing (-48,12,-238), ramp top (-56,12,-226), ramp foot (-56,0,-168), lot
  (-132,0,-160), then a free chase. Walk timeout 75 s.
- **Kit:** 9,000 HP, +33% per extra living player; headshot x2; walks at 7 (9 after the
  phase); never dismembers; supply 400.
  - **Vent:** every 12% of health lost (8% after the phase). Tell: 0.8 s of both hands
    pulling the buckle while the belly swells, then an air-brake hiss. Leaves a gas patch:
    8 radius, 12 s, 10 dps, at most 4.
  - **Crush:** a soldier within 7 studs and 90 degrees in front. 1.1 s windup, 40 damage,
    1.5 s knockdown; a roll dodges it.
  - **Retch:** a soldier 25-55 away, or perched 4 or more above his feet. 1.0 s windup, a lob
    (speed 45, splash 5, 20 damage) leaving a puddle (7 radius, 8 s, 12 dps). Cooldown 7 s,
    5 s after the phase.
  - **Phase at 50%, "Passengers":** 6 Walkers and 2 Runners (+3 Walkers per extra player),
    in the `Warden.Phases[].RiotCall` shape.
  - **Death:** 2.0 s swell, then a burst (30 to soldiers, 60 to Infected within 14). He sits
    back down in his seat in the road. **The cloud:** 20 radius, 40 s, 15 dps, 8 up and down.
    Infected are unharmed by it. The priority pallet lands inside the cloud.
  - **Flash:** any of his gas touching fire (a burning pump, any item with `Ignites`) flashes
    once: 50 to everything inside +4, 300 to the Driver, and clears the gas.
  - **Pressure while up:** `SpawnFactor` 1.5, `MaxAliveReduction` 8, caps Brute 0, Hocker 1,
    Possum 0.
- **Where you kill him matters:**
  - In the lot (default), shoot a pump to flash the cloud and reach the pallet now.
  - On the span, the Jam 12 below stays clear, but the crossing is gassed for 40 s.
  - At the toll, extraction waves walk through gas.
- **Sound bank (soft, owner rule):** keys jangling on every footfall, belt creak (tell),
  low air-brake hiss (vent), a closed-mouth bellow, and at death a buckle ping and a long exhale.
- **Radio (Control):**
  - Insert: "Pike, Control. Mile 14. Twenty-four buses, every one sealed. Open what I tell
    you to."
  - Index call: "Control copies. Lead bus is open. Index is the driver, still belted in. Pick
    where he dies."
  - Kill: "Index down. Control copies. Stay out of his air, Pike. Pallet inbound."
  - Possum (optional): "Watch the blankets. Not all of them are dead."

## Pressure mix (mission time; `StageDefinitions.Mile14.Phases`)

| Until (s) | Walker | Runner | Brute | Hocker | Possum |
|---|---|---|---|---|---|
| 60 | 80 | 20 | 0 | 0 | 0 |
| 180 | 55 | 22 | 0 | 8 | 15 |
| 360 | 45 | 25 | 8 | 10 | 12 |
| 600 | 38 | 27 | 10 | 13 | 12 |
| after | 32 | 30 | 12 | 16 | 10 |

Caps:
- Hocker `{ {180, 2}, {480, 3} }`, late 4.
- Brute `{ {360, 1} }`, late 2.

Per-site weights (W / R / B / H / P):
- Overpass span 30 / 35 / 5 / 25 / 5.
- Toll Plaza 40 / 25 / 20 / 5 / 10.
- Rest Stop 45 / 30 / 10 / 15 / 0.

## The map (level designer's C1 rewrite)

The layout lives in `assets/3d/build/mile14_map.py` (tables in the ArenaService shape) until
Mile 14 gets mission data.

**Fixes to the old C1:**
- The Toll Plaza moves north to (180,175), with the main pad on it at (225,6,175).
- The span is 126 long on pier bents at level 26.
- The Culvert is a 10-wide, 7-clear tube.
- The Jam is broken up: 14 buses (4 burnt), a jackknifed semi, trucks and cars, with crossing
  gaps.
- Booths are a new `env_toll_booth`.
- The Rest Stop zone moves off the diner.
- The Held band no longer removes Sanitize buses.

**Landmarks:**
- the Jam (12) with guardrail crests and a median parapet;
- the Overpass (26) with two stairs from the Jam;
- the Culvert;
- the Rest Stop with the fuel canopy, pumps, diner and diner sign;
- the Toll Plaza with its canopy;
- the water tower on a knoll (185,-125);
- the Drop (a bus on its side below a torn rail: "the drivers went over the rail");
- the Halt (NW tents and cars);
- the HARLAN 14 gantry (z 150) and the EXIT 14 gantry (z -100).

The level designer's full tables (sites, approaches, Hocker stands, spawns, Primary and
Secondary placements, stores, story spots, bands, budget, the 10-step verification list) were
handed back in the session. The positions are encoded in `mile14_map.py`; the rest goes into
LEVELS C1 when the owner approves.

## Code needed before Mile 14 runs in game

- `IndexService`: split the Warden-only frame (`TYPE_NAME`, `cfg()`) so a second Index
  reuses entry, boss bar, phases, `endFight` and the pallet. `EnemyService` reads
  `Config.Index.Warden.Pressure` directly at two places; it should read the active Index.
- `EnemyProjectileService.spawnPuddle`: boss gas must not count against `MaxPuddles`, and the
  vertical reach becomes a field on the gas spec.
- `BotService`: leave live gas and puddle discs.
- Per-mission phases on mission time (build order item 4); `Config.Overrun.Weights` per mission.
- Pumps that burn when hit (new interaction).
- `ArenaService.DRESSING` needs a `roll` field (the bus on its side).
- Vertical chase needs to work for a non-building footprint (the span).
- Land the nudge-oscillation fix (LEVELS A14 #3) before the 43-stud bus sides.
- Clips: Possum (faster four-legged run if `downed_crawl` reads wrong at 13). Driver: waddle,
  buckle pull, crush fall, retch, sit-down death.

## Built this sprint (assets only)

- Bodies: `possum_limb` (`build_assets.py`, `INFECTED_TYPES`), `driver.py` (the Driver and
  his three parts).
- Kit, `highway.py` (18 meshes):
  - overpass span, bridge bent (full and low), guardrail, parapet;
  - sign gantry, water tower, highway light;
  - toll booth, toll canopy, fuel canopy, fuel pump, diner sign;
  - semi cab, box trailer, burnt bus, mile marker, traffic cone.
- `mile14_map.py` and `assets/3d/mile14_map.blend`: the whole mission in Blender for judging.

Not yet done:
- The billboard and the diner (kit Parts in game; a grey box stand-in in the map view).
- Collider lists and `MeshAssets` entries, uploads.
- The common Bloat sheet (Kestrel).
- The placement checks from `delta_map.py` are not wired into `mile14_map.py` yet.

## Mile 14 v2 (proposal, 2026-11-11)

Owner: "make it bigger and better detailed, not hyperdetailed but looks good for a Roblox
game, and add a background, something like the skyscrapers we had". A second layout to compare
with the one above, built and looked at in Blender. **Nothing in the game changed; nothing is
uploaded.** Layout: `assets/3d/build/mile14_v2.py` (same table shape as `mile14_map.py`; run
it headless to rebuild `assets/3d/mile14_v2.blend` and the previews).

Previews (`assets/3d/build/previews/mile14_v2_*.png`): `overview` (top-down, places named),
`skyline` (from the span, north), `insert` (main pad), `toll`, `span` (south over the
jackknife), `jackknife`, `reststop`, `weigh`, `altpad`, `oblique` (from above, not eye height).

**Size (studs):**

| | v1 | v2 |
|---|---|---|
| Frame | 600 x 600 | 640 x 900 |
| Interstate deck (level 12) | 60 x 600 | 110 x 900, plus a 170 x 160 toll apron |
| Paved ground off the road | Rest Stop 130 x 100, Toll 140 x 66 | Rest Stop 235 x 165, Weigh Station 190 x 120, admin lot 78 x 98 |
| Ways between deck and ground | 1 ramp, the Culvert | 4 ramps, the Culvert (110 long), slopes |
| Ways onto the span | 2 stairs | 4 interchange ramps, the county road both ways |

**Places, south to north (x, z):**
- South barricade (z -440) and the lead bus (-16, -418): Open the Route, the Driver's entry.
  He comes down the Rest Stop's south ramp (-63, -330) into the lot.
- **Rest Stop** (site, zone 46 x 46 at (-190, -255)), west, ground level: diner, fuel canopy
  and 4 pumps, truck bays, alt pad (-262, -195). An exit ramp and an entry ramp.
- **Weigh Station** (new), east, ground level: scale house, a truck on the scale, a queue.
  Two ramps. The water tower knoll is south-east of it (225, -370).
- The Culvert (z -70) and the Drop (-84, -38).
- **The jackknife** (new choke point, z -20): a fuel tanker across the west carriageway, its
  cab folded into the median, a van trailer across the east one. Three gaps (both shoulders
  about 8 wide, one in the median), or go round by the interchange ramps or the Culvert.
- **Overpass span** (site, zone 28 x 28 at (0, 26, 80)): the county road now runs to both
  edges; four ramps down to the deck.
- HARLAN 14 gantries (z 200), one per carriageway.
- **Toll Plaza** (site, zone 46 x 46 at (0, 12, 260)): now across the interstate, 8 booths
  under two canopies at z 310, checkpoint dressing. **Main pad** (insert, extract) on the
  admin lot beside it (130, 12, 310).
- The Halt (-200, 250), north barricade (z 440).

**What changed from v1:**
- Two 3-lane carriageways with shoulders and a 20-wide grass median (v1: one 60-wide deck).
- 24 buses still (20 in the inner lanes, 2 at the booths, 1 in the Rest Stop, the Drop's);
  the other lanes hold seeded civilian traffic with gaps to cross.
- The Toll Plaza moved from its own hill onto the interstate; the Weigh Station, the jackknife
  and the interchange ramps are new.
- Lane lines, edge lines, services signs, billboards, crash litter, cars run out into fields.
- **Backdrop:** Harlan to the north, where the road goes: 36 towers (the six `city.py` types
  and their lit-window twins) in three arcs 880-1,400 studs from the Toll Plaza, tallest
  downtown. The jam carries on past both barricades. The frame's edge is hidden by sound
  walls (north and south) and a pine line (east and west), all without collision.
- New kit pieces in `highway.py` (tris): `env_tanker_trailer` 564, `env_sound_wall_24` 120,
  `env_pine_stand` 396, `env_billboard` 424, `env_scale_house` 192, `prop_road_sign` 96,
  `env_lane_dashes_96` 96, `prop_road_debris` 108. All under their class caps.

**Counts (the build prints them):**

| | v1 | v2 |
|---|---|---|
| Dressing instances in play | 251 | 666 (597 inside the frame) |
| Tris in play | 54,368 | 200,876 (167,408 inside the frame) |
| Edge (walls, pines) | none | 108 instances, 30,624 tris |
| Skyline | 6 towers | 72 MeshParts, 63,684 tris (Delta's: 46, about 42k) |
| Distinct meshes | 33 | 58 (largest 1,872 tris; vehicle cap 5,000) |
| Parts | 17 + earthworks | 61 + 45 earthwork + 4 sign panels |

STYLES has no whole-scene tri cap, so the number to judge is the 123 cars and trucks (114k tris, about 900
each). If a low-end device struggles, thin the cars first (`skip` in `_jam_vehicles`).

**Not checked:** nothing was tried in Studio. No colliders, no collider count against the 256
budget, no `MeshAssets` entries, no placement checks (`delta_map.py`'s), no pathing or spawn
points, no lights. The site and pad positions are the level designer's v1 ideas moved to fit,
not re-reviewed by the design agents. Previews are lit as dusk so shapes read; the mission is
full dark.

**Review of the previews (2026-11-11, pictures and tables only, no Blender):** the counts above
match the tables. Seen or measured, not fixed:
- The five wrecks in the median sit on the parapet line (x 0): sedan (4, -236), van (-5, -140),
  hatch (-4, -356) and humvee (5, 46) pass through a parapet, the pickup (3, 172) through the
  light pole at z 168 (visible in `skyline`). Move them or open the parapet run there.
- Harlan covers the northern 128 degrees only; south, east and west the horizon is pines and
  bare sky. The fields between the places are flat and nearly empty (`oblique`).
- The ground slab's edge shows from high up (`oblique`), not from eye height in any preview.
- `weigh` is framed against a truck cab; the Weigh Station itself is not really shown.
- The 8 new kit pieces have no per-piece preview and no FBX in `export/`; their tri counts
  were re-added by hand from the builders, not re-measured.
