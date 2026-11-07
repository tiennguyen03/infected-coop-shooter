# PROGRESSION.md — run structure, stages, bosses, the Infected roster

Design doc for the post-MVP run loop (decided 2026-11-06 with the owner, canon by the lore
developer). This is the frame the systems designer, level designer and engineer work in.
Canon lives in [LORE.md](LORE.md); tuning lives in `src/shared/Config.luau`; what has
actually shipped is in [HISTORY.md](HISTORY.md). Pillars: [PLAN.md](PLAN.md).

## The run in one paragraph

A helo drops the Chosen at the bottom of the Harlan quarantine corridor. Each stage is one
arena. The player explores, loots and levels while the difficulty clock runs, then walks to
one of the stage's objective sites and starts the hold when they are ready. Starting the
hold calls the stage boss. Clearing it opens extraction: the helo lands and lifts the squad
to the next stage. After the last stage of the loop the helo offers **Stand Down**: board it
and end the run on your terms (the obliterate), or stay and loop the corridor at a higher
clock with the later Infected forms mixed in from the start.

Risk of Rain 2 is the structural reference (loot then commit, a boss per stage, bosses that
become regulars, a continuous clock, an exit on your own terms). Names, places and numbers
are ours.

## The loop

| Step | What happens | Today |
|---|---|---|
| Drop | Helo lands at the stage's pad; squad spawns there | spawn at a fixed point |
| Explore | Loot, level, read the stage; clock runs (`Config.Difficulty`) | works |
| Commit | Player activates the hold at one of **three fixed sites** (one chosen per run) | zone appears at one fixed spot after 180 s |
| Hold | Hold zone + pressure wave + **the stage boss** arrives from its canon entry | hold + pressure wave, no boss |
| Extract | Helo lands at the pad; squad boards; next stage loads | `ExtractionService` ends the run |
| Loop / Stand Down | After stage 3: Stand Down (ends the run, scored) or loop at a higher clock | n/a |

First loop is **three stages**: Checkpoint Delta, Mile 14, Aid Station Kestrel. Harlan Yard
and Harlan Reservoir Station are canon and come later as stages 4 and 5 of the same
corridor; until then the loop point is after Kestrel.

## Stages

Every stage is a 600 x 600 arena with up to five height levels, built in code from hills,
roads and dressing (see [STYLES.md](STYLES.md) > Stage 1). Each has four to six named
landmarks, three objective sites, one boss entry, one helo pad and two storytelling spots.
Stage lighting moves with the corridor: evening at Delta, full dark at Mile 14, dawn at
Kestrel. Road signs count down the distance to Harlan.

### Stage 1 — Checkpoint Delta (exists; rename and add)

- **Was:** the corridor's southern screening gate. Civilians were held and checked here
  before being let north. It fell from the inside when the pens turned. Walls face out,
  bodies are inside.
- **Landmarks:** Screening Compound (was Compound: tents, tower, the current hold zone),
  the Pens (was Parade Terrace: tents inside hesco rows), the Depot, the Gate (the far
  checkpoint on the main road in the Scrapyard), Ridge, Overlook, the highway. Main route:
  Gate → main road north under the bridge → Compound. Add a hesco ring round the Pens and a
  line of buses at the Gate. Cut nothing.
- **Objective sites:** Screening Compound (high, climbable from every side, tower blocks
  lines); the Pens (low and flat, hesco lanes funnel the Infected into three mouths); the
  Overlook (tallest and narrow, Hockers below shell the summit).
- **Boss:** the Warden walks out of the Gate and up the main road. Seen coming the whole way.
- **Helo:** the helipad (south-west), extraction and Stand Down.
- **Story spots:** burning Ridge barracks whiteboard "SCREENED 212 / CLEARED 0"; a Gate bus
  chained shut from outside, "NEG" sprayed then crossed out.
- **Forms:** Walker 0:00, Runner ~2:00, Brute ~5:00, Hocker ~8:00.

### Stage 2 — Mile 14

- **Was:** the evacuation convoy out of Harlan, stalled where the highway crosses the
  county road. Buses sealed with the bitten aboard; the drivers went over the rail.
- **Landmarks, low to high:** the Culvert (drainage channel under the highway, a sunken
  route the full width); the Rest Stop (fuel station and diner on the off-ramp); the Toll
  Plaza (lanes and booths on a fill, where the military restarted screening); the Highway
  deck, "the Jam" (convoy nose to tail); the Overpass (county road above the deck, two
  stairs down); a water tower beyond as the skyline landmark. Main route: Rest Stop → ramp →
  along the Jam → Overpass.
- **Objective sites:** the Overpass (high, narrow, two approaches, Hockers arc up); the Toll
  Plaza (lane barriers make chokepoints, booths block sight); the Rest Stop (low, open on
  all sides, pumps burn when hit).
- **Boss:** the Bloat bursts out of the lead bus in the Jam and comes down the ramp. Its
  death cloud sits on the main route.
- **Helo:** the Toll Plaza's lane apron, east end.
- **Story spots:** highway sign hand-amended "HARLAN 14 – NO ENTRY – QUARANTINE IN EFFECT";
  toll booth radio log ending "they're opening the buses, don't let them".
- **Forms:** Walker, Runner, Brute, Hocker from 0:00; Hockers on the deck from ~3:00.

### Stage 3 — Aid Station Kestrel

- **Was:** a high school turned forward aid station. Triage kept treating the bitten; the
  wards became the outbreak. Beds in rows, every one empty, every restraint cut.
- **Landmarks, low to high:** the Field (sunken sports field, LZ painted on it); the
  Bleachers (four steps of height along the field); the Triage Lot (tents on the car park);
  the Ward (the gym: roof collapsed, bed rows, walls all round, two doors); the Morgue (bus
  garage and loading dock); the Main Block roof (highest, external fire stairs).
- **Objective sites:** the Ward (enclosed, two mouths, Shedders among the beds, no room to
  kite); the Triage Lot (tents as cover, open to the field, Hockers lob from the
  bleachers); the Roof (highest, one stair up, Runners climb everything).
- **Boss:** the Patient comes out of the Morgue's isolation bay and arrives through the
  Triage Lot.
- **Helo:** the Field, on the painted LZ.
- **Story spots:** triage whiteboard "BITTEN → WARD B", "WARD B" crossed out, "ALL" written
  over; gym roof painted "ALIVE INSIDE" for the helos, paint still fresh.
- **Forms:** Walker, Runner, Brute, Hocker from 0:00; Bloat common ~3:00; Shedder ~6:00.

### Stages 4 and 5 (canon, not scheduled)

Harlan Yard (rail yard; boss the Lineman, an alpha Runner that drags a player and calls the
map; Kites first appear). Harlan Reservoir Station (the dam and the program's research
station; boss the Specimen, every form in one body; Growths everywhere).

## Bosses

One per stage, called by starting the hold, arriving from a canon entry so the player sees
it coming. Each boss is the next rung of the strain, and the Stage 2 boss becomes a common
enemy on Stage 3 (the player learns it twice).

| Boss | Stage | Body | Mechanic (one rule) |
|---|---|---|---|
| the Warden | Delta | MP Brute, riot plate grown into the bone | armoured: shoot the plates off, then the body |
| the Bloat | Mile 14 | gas-swollen, translucent | area denial: bursts into a lingering cloud on death; kill it where you can afford the cloud |
| the Patient | Kestrel | the host that got the antiviral | regenerates in waves: damage windows between surges |
| the Lineman | Harlan Yard | a Runner the strain finished | drags a player; its call pulls the map |
| the Specimen | Reservoir | the station's live host | every mechanic above, in phases |

## The Infected roster

Ordered by how far the strain has gone in one body. Model name stays `Infected`; the slang
goes on the kill feed. Each form is one rule (pillar 3).

| Form | Role | Look | First seen | Engine note |
|---|---|---|---|---|
| Walker | slow melee | still a person, grey, old wounds closed | S1 | exists |
| Runner | fast melee | dense rebuilt muscle, tendons like cable | S1 | exists |
| Brute | melee tank | bone overgrowth, plated shoulders | S1 | exists |
| Hocker | ranged | lobs caustic fluid; throat a swollen sac | S1 late | projectile + stand-off AI |
| Bloat | exploder, area denial | gas-swollen, translucent | S2 boss, common S3 | on-death cloud |
| Shedder | splitter | body seamed into segments, extra limbs | S3 | on-death spawns 2–3 Crawlers |
| Crawler | swarm | shed segment, fast, fragile | S3 (from Shedders) | small rig, no attack clip needed |
| Kite | flyer | shed tissue on ribbed membranes, dives | S4 | non-Humanoid mover (new) |
| Growth | stationary spawner | host rooted in place, makes Crawlers | S4 nests, S5 | no mover; burn interaction |

## Technical plan (debt first, then content)

1. **Data-driven enemy behaviour.** `EnemyDefinitions` gains optional hooks per form:
   `attack` (melee | projectile), `onDeath` (cloud | split), `mover` (humanoid | none |
   flyer), `standOff` range. `EnemyService` reads them; no form-specific branches. This is
   the payment that makes the roster cheap. Walker through Shedder and four of five bosses
   are table entries plus a hook each.
2. **Stage definitions.** `src/shared/StageDefinitions.luau`: per stage the landmark/hill/
   dressing tables (what `ArenaService` builds), lighting preset (`SkyService`), the three
   objective sites, boss entry point, helo pad, spawn phases (`Config.Spawning` moves per
   stage), form unlock minutes. `ArenaService` builds whichever stage is active.
3. **Run state machine.** `RunManager` owns `Drop → Explore → Hold → Extract → (next stage |
   Stand Down | loop)`, per run, with the stage index and loop count. Co-op rules from
   [MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) apply (ready-up, stage respawn).
   The clock carries across stages; looping raises its floor.
4. **Boss kit.** A boss is an Infected definition with `boss = true`, a health bar, an
   entry path (walks in from a named point) and one mechanic hook. No separate boss service.
5. **Objective sites.** `ObjectiveService` picks one of the stage's three sites per run and
   shows a marker; the player activates it. The 180 s appear-delay goes away.

Build order: 1 → Hocker on Delta (proves the hooks) → 2 + 3 with Delta as the only stage
(proves the state machine) → Mile 14 + Bloat → Kestrel + Shedder/Crawler + Patient → Warden
→ Stand Down and loop → stages 4 and 5. Each step is one playtest-verified feature.

## Open questions (for the systems designer)

- Target stage length and the clock's floor per loop.
- How much the hold scales with player count (more-not-tougher).
- Whether bosses drop a guaranteed item (RoR2 does) or XP only.
- Stand Down scoring: what the end screen shows so it feels like a win.
