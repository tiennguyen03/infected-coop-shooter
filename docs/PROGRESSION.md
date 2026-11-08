# PROGRESSION.md — operations, the Containment Board, Resupply, stages, the Infected

Design doc for the run loop (revised 2026-11-06 with the owner: Helldivers 2 structure on
top of the roguelike run; canon by the lore developer, numbers by the systems designer).
Canon lives in [LORE.md](LORE.md); tuning in `src/shared/Config.luau`; what has shipped in
[HISTORY.md](HISTORY.md). Pillars: [PLAN.md](PLAN.md). Co-op rules:
[MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md).

## The run in one paragraph

Harlan Control inserts the squad ("Pike") by helo ("Lantern") into a district of the Harlan
quarantine corridor ahead of its scheduled fire mission, **the Burn**. Each district is one
**mission**: Control gives a **Primary** objective drawn from the stage's pool and two
optional **Secondaries**. The squad explores, loots the position's abandoned **stores**,
earns **Resupply** pallets and **field upgrades** while the difficulty clock runs. Completing the
Primary calls the district's **Index** host (the boss). When the squad is ready it pops
green smoke and Lantern takes 90 seconds to arrive; the squad holds the LZ and boards. Three
missions (Delta, Mile 14, Kestrel) make an **operation**. Boarding at Kestrel is **Stand
Down**: the run ends on your terms, scored. Every mission brought home raises that district's
**containment %** on Control's **Containment Board**, the meta-progression across runs.

What stays from Risk of Rain 2: loot then commit, a continuous clock, a boss per stage, an
exit on your own terms. What comes from Helldivers 2: objective pools, a mission timer, a
called extraction, a war map the whole player base pushes. Names, places and numbers are ours.

One stage is a **mission**, and a set of missions an **operation** (owner 2026-11-08: the
Helldivers 2 convention; was "mission", decided 2026-11-06).

## The loop

| Step | What happens | Today |
|---|---|---|
| Insert | Lantern lands at the stage pad; squad spawns; Control reads the Primary, the Secondaries and the Burn timer (`Operation.MissionTimer`, 14:00) | spawn at a fixed point |
| Explore | Loot stores, earn Resupply, find field upgrades; clock runs (`Config.Difficulty`) | Resupply and the loadout shipped 2026-11-07 (no stores yet) |
| Primary | One of the stage's pool, placed at one of its three sites or a named landmark; the squad starts it when ready | hold zone appears at one spot after 180 s |
| Index | Completing the Primary calls the boss from its canon entry | the Warden on Delta (shipped 2026-11-07, `IndexService`) |
| Call the bird | Green smoke at a pad; Lantern inbound 90 s; squad holds the LZ; everyone inside boards, anyone outside is left (Dead for the mission) | 30 s hold, run ends |
| Next mission | Dead players respawn at the next pad; clock, Resupply pool and drop counter carry over | n/a |
| Stand Down | After Kestrel: board = run ends, scored; or ask for a **Second Pass** (same corridor, higher clock floor, later forms from drop, containment gains doubled) | n/a |

Failure: squad all dead = mission lost, operation over; containment from missions already
extracted still counts. The Burn running out does not end the run (see Operation).

## Loadout, pallets and field upgrades (spine v1, shipped 2026-11-07)

Power comes from the loadout, not from in-run growth: the Helldivers 2 model with one
Hades-style twist (field upgrades). The Risk of Rain item economy, XP orbs and levels are
gone (`docs/sprints/SPRINT_18_LOADOUT.md`). Lore names on the HUD ([LORE.md](LORE.md)).

- **Loadout.** A Chosen is a weapon, Q dash, E breach, the Momentum passive and two
  **call-in** slots on keys 1 and 2, chosen before the drop (the dev panel today, the Armory
  later). The rifle (`WeaponDefinitions.service_rifle`, from `Config.Weapon`) has a
  30-round magazine and a 240-round reserve (9 magazines): R reloads (2.2 s; a roll, a slide or going
  down cancels it), an empty magazine refuses the shot and asks for a reload. The server
  owns the magazine (`LoadoutService`).
- **Call-ins** (`CallInDefinitions`, numbers in `Config.CallIns`; no friendly fire). Each
  slot holds charges that refill one at a time:

  | Key | Lore name | Tool | Charges / cooldown | What it does |
  |---|---|---|---|---|
  | 1 (default) | **Magpie** | Drone Beacon | 1 / 90 s | thrown 35 studs; two of Lantern's quadcopters follow the thrower 30 s, Damage 6 every 0.6 s, range 60 |
  | 2 (default) | **Tripline** | Mines | 2 / 60 s | thrown; 6 charges on an 8-stud arc bulging away from you; trigger 5, blast 10, Damage 80, 90 s |
  | swap-in | **Anvil** | Fire Mission | 1 / 150 s | thrown marker; after 3 s the battery lands 3 shells 1 s apart, Damage 80 in 12 studs |
  | swap-in | **Pen Coil** | Shock Coil | 2 / 25 s | pulse around you: Damage 25 and a 0.4x slow for 3 s inside 14 studs |

- **Pallets are tactical.** The Resupply pool (one meter on every HUD) is fed by every
  kill's `SupplyValue` at any distance (Walker 10, Runner 12, Hocker 18, Brute 35) and by the
  Primary (`Objective.SupplyReward 500`); the meter pulses on a kill. When it covers the cost
  (`Requisition.BaseCost 300`, x1.15 per drop, cap 1000, +40% per extra player) any living
  player throws the red flare (key 3, 35 studs); for 20 s the Infected inside 120 studs walk
  to the flare, then the pallet lands loud (`Lure.Wave 10` +3 per extra player, spawn
  interval x0.7 for 30 s). **The pallet is the ammo box**: every living player who walks
  within `RearmRadius 6` is re-armed once (full magazine and reserve). Its three cards are
  the same for everyone (`Crates.SupplyCards`): **Medkit** (full heal), **Restock** (both
  call-in slots full), **Armour Plate** (+50 shield soaked before health, cap 100). One pick
  per player per pallet, cards vanish at 60 s. No rarity, no upgrades from pallets.
- **Field upgrades** (`UpgradeDefinitions`, flags on `LoadoutService`, numbers in
  `Config.Upgrades`). Six slots, one per tool (Dash, Breach, Rifle, Kit, call-in A, call-in
  B); a new pick in a filled slot replaces it. Sources: the Primary's site crate (lands when
  the hold zone appears; shows 3 you can still take), later Stores and Secondary crates and
  the Index pallet (3-5 per mission). Each changes how a tool works, never a percentage:

  | Slot | Lore name | Effect |
  |---|---|---|
  | Dash | Flare Straps | the dash leaves 3 fire pools (radius 6, 8/s for 5 s) |
  | Dash | Smoke Dash | Infected melee cannot find you for 1.5 s after the dash |
  | Breach | Bait Charge | the breach charge lures the Infected inside 18 studs for a 3 s fuse |
  | Rifle | Through-and-Through | a round carries into the next Infected |
  | Rifle | Hollow Point | the hit Infected stops for 0.6 s |
  | Kit | Combat Reload | reload is instant at 5 Momentum |
  | Kit | Last Stand | fire from the ground while downed (hip, spread x2) |
  | Kit | Spare Tourniquet | stand up on your own 4 s after going down, once per mission, no revive spent |
  | Anvil | Walk It In | 5 shells stepping 8 studs along the throw |
  | Magpie | Last Flight | the drones stay with a downed owner, their clock paused |
  | Tripline | Daisy Chain | press 2 again to blow every armed mine (no charge) |
  | Pen Coil | Ground Strap | the pulse stands up every downed squadmate in reach |

- **Flat threat curve.** `Config.Difficulty` health and damage at 1x; pressure is the spawn
  interval decay (3 s, x0.95/min to 1.5 s; balance pass 2026-11-07), the max-alive schedule (10 / 14 / 20 / 26, late 30),
  the phase mix (Walker-only to W38 R30 B16 H16) and the player count
  (`Config.PlayerCountScaling`: spawn interval x0.8, +3 alive and +1 heavy per extra
  living player, hard cap 44). `Config.Overrun` is reserved for the Burn.
- **Stores.** Free crates at the position's abandoned stock (Depot containers, Ridge
  armoury; convoy trucks, Rest Stop back room; pharmacy, triage stores). Hold E 3 s to open,
  which is loud. Not built.
- **Priority pallet.** An Index kill drops a pallet at the corpse: re-arm, full heal, three
  upgrade cards each. Shipped with the Warden (`IndexService.endFight`).

## Operation: the Burn, extraction, scoring

- **The Burn** (mission timer). `Operation.MissionTimer 840` for 1–4 players (more players
  split objectives; time is the one resource more-not-tougher does not hand out). Only the
  Burn counts down on the HUD; run time stays a plain readout (pillar 2). At 0:00 the
  incendiaries land: burning dressing, no more pallets (`Overrun.NoSupplyDrops`), spawn
  interval x0.5, max-alive +10, Brute/Hocker caps +2, Lantern takes 120 s instead of 90.
  The run does not end; extracting after the Burn scores Partial. Calling the bird freezes
  the timer.
- **Extraction.** `Extraction.HoldDuration 90`; on call Walker 10 Runner 4 (+3 Walkers per
  extra player), a second phase-weighted wave of 12 at 45 s, spawn interval x0.6. Progress
  accrues while any living player is inside. Secondaries do not shorten it; 90 s is the
  constant the squad plans around. Alternate pads come from the "Light the Pad" Secondary.
- **Secondaries** reward a Secondary crate on site and +3 containment; no timer extension,
  no Resupply.
- **Score per mission:** Win (Primary done, extracted before the Burn) 12; Partial (Primary
  done, extracted after the Burn or wiped after it) 6; Loss (wiped before the Primary) 0;
  each Secondary +3. Perfect operation = 18 per district.

## The Containment Board (war map)

Every district carries a containment % raised by every extracted mission. Delta starts at 25
(today's tuning); other districts at 0; the next district unlocks at 50 of the previous.
Perfect play reaches 100 in 6 operations; a first-timer in 10–12 (a weekend). The board is
**shared across all players** from the start (owner, 2026-11-06): one global DataStore key
per district, written with `UpdateAsync` so concurrent servers add, never overwrite; each
server reads the board at run start and once per minute. Containment means the district
stopped exporting hosts, not zero Infected.

| Band | % | `InitialCount` | Clock start | Brute / Hocker first spawn | Stores | Visible (cheap) |
|---|---|---|---|---|---|---|
| Lost | 0–24 | 8 | +60 s | 150 / 360 | 2 | as built: fires, lamps dark, siren/horn/PA looping |
| Contested | 25–49 | 5 | 0 | 180 / 480 | 2 | today |
| Held | 50–74 | 4 | 0 | 210 / 540 | 3 | main-road lamps lit, fires out, alarm silent, one extra Stores crate |
| Contained | 75–99 | 3 | 0 | 240 / 600 | 4 | all lamps, no fire inside the walls, permanent second pad, ambient swap |
| Secured | 100 | 3 | 0 | 240 / 600 | 4 | sweep ops, rewards x0.25 |

Per-stage dressing per band is in the stage sections. Build cost per band: a PointLight
toggle, `burning` flags, a fog tweak, a spawn table keyed by band, one ambient swap, one
extra helipad. Nothing new to model.

## Objective pools

Completing the Primary calls the Index from its canon entry. Each objective is one rule
(pillar 3) and is buildable with hold zone, kill count, interact-with-prop, carry, destroy,
survive, reach.

### Primaries

| Name | Radio brief | Player rule | Stages | Showcases |
|---|---|---|---|---|
| Secure the Site | "Re-establish the perimeter at [site]. Hold until Control confirms." | 45 s accumulated inside the zone (today's hold) | all, at the three sites | the stage's pressure mix |
| Sanitize | "Control wants fire at the pens, not confirmation. Three sites." | hold E at 3 marked props in any order; each ignites and spawns a wave | Delta Pens tents; Mile 14 sealed buses; Kestrel Ward bed rows | Runner; Shedder/Crawler flushed by fire |
| Recover the Record | "Recover Delta's screening record. Control needs to know who went north." | pick up at A, carry to B; carrier cannot sprint; dropped when downed | Delta Ridge → comm tower; Mile 14 toll log → Overpass; Kestrel manifest → roof | Runner, Hocker |
| Restore Comms | "Get the mast up. Control is blind north of the gate." | hold E 10 s (interruptible) at the high prop, then survive 60 s there | Delta comm tower; Mile 14 water tower; Kestrel roof | Hocker shelling high ground |
| Confirm Casualties | "Control is tracking six heavy hosts in the Depot. Put them down." | kill N marked (outlined) spawns at a landmark | Delta Brutes in the Depot; Mile 14 Hockers on the deck; Kestrel Bloats in the Ward | Brute / Hocker / Bloat |
| Open the Route | "The Gate is chained from outside. Open it; the next mission walks through here." | destroy 3 shootable props, then one player reaches the point beyond | Delta the Gate (Warden walks through); Mile 14 the lead bus (the Bloat is inside) | the boss entry |
| Evacuate the Holdouts | "Transponder in the Ward. Alive inside. Get them to the LZ." | 2–3 survivors follow the nearest player; must reach the pad alive | Kestrel (canon payoff), Mile 14 Rest Stop. Never Delta ("CLEARED 0") | Runner, Hocker puddles |

### Secondaries (two offered per mission)

| Name | Radio brief | Player rule | Stages | Effect beyond the crate |
|---|---|---|---|---|
| Silence the Alarm | "Something's still running the alarm at the Gate. It's drawing them." | hold E on the looping sound source | Delta siren; Mile 14 bus horn; Kestrel PA | spawn rate drops in its radius |
| Lights On | "Depot generator's intact. Get the lights on." | hold E 8 s at a generator | Delta Depot; Mile 14 Toll Plaza; Kestrel Field | the district's lamps light (preview of Held) |
| Light the Pad | "There's a second pad on the Depot apron. Mark it." | hold E at a marked pad | Delta Depot; Mile 14 Rest Stop; Kestrel Triage Lot | extraction can be called there |
| Sample Run | "Control wants tissue from a heavy host. Bag one." | kill the marked Brute/Bloat, hold E on the corpse, carry (no sprint) to the LZ | all | the next Requisition pallet shows 3 field-upgrade cards |
| Headcount | "Control has 212 names from the Delta roster. Confirm what's left." | reach and interact at the stage's 3 story spots | all | lore delivery, moves the player (pillar 1) |
| Clear the Spitters | "Hockers on the Overpass are shelling the toll lane." | kill N of one form before a short timer | Mile 14, Delta late | Resupply burst |
| Misdrop | "Lantern put a pallet in the Suburb. It's yours if you get there first." | reach a crate in an outer district within 4 min | all | the crate is the reward |
| Sealed Bus | "Bus 7 reads NEG on the manifest. Confirm it." | hold E on a chained bus; Runner burst; kill all | Delta Gate, Mile 14 the Jam | dark beat (it was never NEG) |
| Recover Logs | "Toll booth recorder is still live. Pull it." | walk-in pickup at one story spot | all | codex entry |

## Stages

Every stage is a 600 x 600 arena with up to five height levels, built in code from hills,
roads and dressing (see [STYLES.md](STYLES.md) > Stage 1). Each has four to six named
landmarks, three objective sites, one Index entry, one helo pad, two storytelling spots and
two to four stores. Lighting moves with the corridor: evening at Delta, full dark at Mile
14, dawn at Kestrel. The burning skyline beyond the walls is the districts that already got
their Burn.

### Stage 1 — Checkpoint Delta (exists; rename and add)

- **Was:** the corridor's southern screening gate. Civilians were held and checked here
  before being let north. It fell from the inside when the pens turned. Walls face out,
  bodies are inside.
- **Landmarks:** Screening Compound (was Compound: tents, tower, the current hold zone),
  the Pens (was Parade Terrace: tents inside hesco rows), the Depot, the Gate (the far
  checkpoint on the main road in the Scrapyard), Ridge, Overlook, the highway. Main route:
  Gate → main road north under the bridge → Compound. Add a hesco ring round the Pens and a
  line of buses at the Gate. Cut nothing.
- **Sites:** Screening Compound (high, climbable from every side, tower blocks lines); the
  Pens (low and flat, hesco lanes funnel the Infected into three mouths); the Overlook
  (tallest and narrow, Hockers below shell the summit).
- **Primaries:** Secure, Sanitize (Pens tents), Recover the Record, Restore Comms, Confirm
  Casualties (Brutes, Depot), Open the Route (the Gate). Not Evacuate.
- **Index:** the Warden walks out of the Gate and up the main road. Seen coming the whole way.
- **Helo:** the helipad (south-west); alternate pad on the Depot apron.
- **Stores:** Depot QM containers, Ridge barracks armoury.
- **Story spots:** burning Ridge barracks whiteboard "SCREENED 212 / CLEARED 0"; a Gate bus
  chained shut from outside, "NEG" sprayed then crossed out.
- **Band dressing:** Lost: as built, Gate siren looping. Held: main-road lamps lit, Ridge
  fire to smoke, siren silent. Contained: all lamps, Depot pad permanent, intact humvee with
  headlights at the Gate, wind instead of siren.

### Stage 2 — Mile 14

- **Was:** the evacuation convoy out of Harlan, stalled where the highway crosses the
  county road. Buses sealed with the bitten aboard; the drivers went over the rail.
- **Landmarks, low to high:** the Culvert (drainage channel under the highway, a sunken
  route the full width); the Rest Stop (fuel station and diner on the off-ramp); the Toll
  Plaza (lanes and booths on a fill, where the military restarted screening); the Highway
  deck, "the Jam" (convoy nose to tail); the Overpass (county road above the deck, two
  stairs down); a water tower beyond as the skyline landmark. Main route: Rest Stop → ramp →
  along the Jam → Overpass.
- **Sites:** the Overpass (high, narrow, two approaches, Hockers arc up); the Toll Plaza
  (lane barriers make chokepoints, booths block sight); the Rest Stop (low, open on all
  sides, pumps burn when hit).
- **Primaries:** Secure, Sanitize (sealed buses), Recover the Record, Restore Comms (water
  tower), Confirm Casualties (Hockers on the deck), Open the Route (lead bus), Evacuate (diner).
- **Index:** the Bloat bursts out of the lead bus in the Jam and comes down the ramp. Its
  death cloud sits on the main route.
- **Helo:** the Toll Plaza's lane apron, east end; alternate pad at the Rest Stop lot.
- **Stores:** convoy cargo trucks, Rest Stop back room.
- **Story spots:** highway sign hand-amended "HARLAN 14 – NO ENTRY – QUARANTINE IN EFFECT";
  toll booth radio log ending "they're opening the buses, don't let them".
- **Band dressing:** Lost: full dark, pumps burning, stuck horn. Held: Toll floodlights,
  pumps out, one lane cleared through the Jam. Contained: lane lights, sign amended "ROUTE
  OPEN – HOLD SOUTH", a convoy truck idling at the toll.

### Stage 3 — Aid Station Kestrel

- **Was:** a high school turned forward aid station. Triage kept treating the bitten; the
  wards became the outbreak. Beds in rows, every one empty, every restraint cut.
- **Landmarks, low to high:** the Field (sunken sports field, LZ painted on it); the
  Bleachers (four steps of height along the field); the Triage Lot (tents on the car park);
  the Ward (the gym: roof collapsed, bed rows, walls all round, two doors); the Morgue (bus
  garage and loading dock); the Main Block roof (highest, external fire stairs).
- **Sites:** the Ward (enclosed, two mouths, Shedders among the beds, no room to kite); the
  Triage Lot (tents as cover, open to the field, Hockers lob from the bleachers); the Roof
  (highest, one stair up, Runners climb everything).
- **Primaries:** Secure, Sanitize (Ward beds), Evacuate (the "ALIVE INSIDE" payoff), Recover
  the Record, Restore Comms (roof), Confirm Casualties (Bloats in the Ward). Not Open the Route.
- **Index:** the Patient comes out of the Morgue's isolation bay and arrives through the
  Triage Lot.
- **Helo:** the Field, on the painted LZ; alternate pad at the Triage Lot.
- **Stores:** pharmacy, triage stores.
- **Story spots:** triage whiteboard "BITTEN → WARD B", "WARD B" crossed out, "ALL" written
  over; gym roof painted "ALIVE INSIDE" for the helos, paint still fresh.
- **Band dressing:** Lost: tents burning, PA looping. Held: Field lights, PA silent, hesco at
  the Ward doors. Contained: generator hum, a medical tent re-pitched with a Stores crate,
  "EVAC'D" painted under "ALIVE INSIDE".

### Stages 4 and 5 (canon, not scheduled)

Harlan Yard (rail yard; Index the Lineman, an alpha Runner that drags a player and calls the
map; Kites first appear). Harlan Reservoir Station (the dam and the program's research
station; Index the Specimen, every form in one body; Growths everywhere). When they exist the
operation is five missions and Second Pass moves after the Reservoir.

## Index hosts (bosses)

One per district, called by completing the Primary, arriving from a canon entry so the
squad sees it coming. Each is the next rung of the strain; the Mile 14 Index becomes a common
form on Kestrel (the player learns it twice). An Index kill drops a priority pallet.

| Index | Stage | Body | Mechanic (one rule) |
|---|---|---|---|
| the Warden | Delta | MP Brute, riot plate grown into the bone | armoured: shoot the plates off, then the body (**built**, below) |
| the Bloat | Mile 14 | gas-swollen, pale belly, veins showing | area denial: bursts into a lingering cloud on death; kill it where you can afford the cloud |
| the Patient | Kestrel | the host that got the antiviral | regenerates in waves: damage windows between surges |
| the Lineman | Harlan Yard | a Runner the strain finished | drags a player; its call pulls the map |
| the Specimen | Reservoir | the station's live host | every mechanic above, in phases |

**Boss sound (decided by the owner 2026-11-08).** Every Index has its own sound bank, never a
regular form's: a bellow, its own footfalls, an impact per attack, a tell the squad learns
to hear, and a death. Its prompts share one sound profile (`assets/audio/build/generate.py`
`PROFILES`) so the clips sound like one body. The Warden's tell is his riot handset keying
open; his bank is `warden` (assets/audio/README.md).

### Index kit: the Warden (shipped 2026-11-07, `docs/sprints/SPRINT_19_WARDEN.md`)

Numbers in `Config.Index.Warden`; the service is `src/server/IndexService.luau`.

- **Entry.** Primary complete → `Index`. Control: "Index is moving at the Gate." He spawns
  at (-30,-290), the Gate opens (radio), and he walks the screening route: Gate lane, bus
  line ("He's checking buses. Plates first, then the body."), Inner Gate ("Flank when he
  guards."), under the bridge, the Apron, then the hunt. A member within 90 studs during
  the walk gets the sighting line. The walk times out after 75 s.
- **Body.** 7,000 hp at scale 1.9, +33% per extra living player (the one exception to
  "more Infected, not tougher Infected": one body cannot be more bodies). Headshot ×2.
- **Plates** (one rule): helmet 300, chest 500, back 400 (the flank), shoulders 300 each,
  shield 600. A round into a plate does 25% to the plate and nothing to the body; a
  round into a limb whose plate is gone does 150%. At half a plate cracks (yellow pip);
  at zero it flies off, he staggers 1.5 s, the limb is bare. Order on the HUD: HELM,
  CHEST, BACK, L SHLD, R SHLD, SHIELD. Radio on the first and the last plate.
- **Attacks**, each with the handset's words on the boss bar first. Where you stand picks
  his move (kit expansion 2026-11-07, `Config.Index.Warden`): **Bash** (0-15 studs, 70°
  arc, 40, 0.9 s windup; roll through it); **Shield Sweep** (17 studs, 180°, 25 and a
  shove; get behind him); **Overhead Slam** (a 17 x 6 line at a body that stopped moving
  in reach, 60, 1.3 s; step aside); **Ground Pound** (fists into the road: a 23-stud ring
  drawn on the ground through the 1.4 s windup, 30 and 2.4 s knocked down; the roll does
  not beat it, distance or a ledge does; he is stuck 2.6 s after); **Stomp** (a body
  within 7 studs on any side: 8.5-stud disc, 20 and 1.8 s knocked down, 0.6 s; roll it);
  **Charge** (19-45 studs, 1.2 s windup, 45 studs at 40/s, 35, hard cover stuns him 3 s);
  **Gas Canister** (phase 2+, or any phase at a perched member; furthest member within
  70, 10 + a 9-stud puddle 6 s); **Guard** (his plates took 150 inside 3 s: shield up
  2.5 s, half speed, frontal plates take 25%; flank him). He walks a beat between attacks
  (1.0 / 0.7 / 0.4 s by phase), never repeats one except the Bash, never chains two
  knockdowns. Limb attacks miss a rolling body; the Pound and the Charge do not. Knocked
  down: no moving, firing or abilities; the Infected still bite; 1 s of knockdown
  immunity on the get-up (`Config.Knockdown`). Bots step out of the ring and the lines.
- **Phases** by body health: below 60% the **Riot Call** (6 Walkers + 2 Runners round
  him, +3 Walkers per extra player, one body per frame); below 25% a second call, charges
  every 5 s, walk 11. While he is up the wave loop spawns at ×1.5 interval, 8 fewer
  alive, no Brutes (`Pressure`).
- **Kill.** "Gate's yours, Pike. Pallet inbound." Priority pallet (upgrade cards) at the
  corpse, everyone alive healed and re-armed, `Extract` and the pad lights. His corpse
  stays 8 s.
- **Target fight** 100-120 s for a squad that works the plates; retune plate health first.

## The Infected roster

Ordered by how far the strain has gone in one body. Model name stays `Infected`; the slang
goes on the kill feed. Each form is one rule (pillar 3). **Visual redesign pending:** every
form gets its own limb set (lore developer + [STYLES.md](STYLES.md) first), Hocker first.

| Form | Role | Look | First seen | Engine note |
|---|---|---|---|---|
| Walker | slow melee | still a person, grey, old wounds closed | S1 | exists |
| Runner | fast melee | dense rebuilt muscle, tendons like cable | S1 | exists |
| Brute | melee tank | bone overgrowth, plated shoulders | S1 | exists; 260 HP, headshot x1.25 (plated skull), no weak point |
| Hocker | ranged | lobs caustic fluid; throat a swollen sac | S1 late | shipped 2026-11-06 (Walker body + sac; own mesh first in the redesign) |
| Bloat | exploder, area denial | gas-swollen, pale belly, veins showing | S2 Index, common S3 | on-death cloud |
| Shedder | splitter | body seamed into segments, extra limbs | S3 | on-death spawns 2–3 Crawlers |
| Crawler | swarm | shed segment, fast, fragile | S3 (from Shedders) | small rig, no attack clip needed |
| Kite | flyer | shed tissue on ribbed membranes, dives | S4 | non-Humanoid mover (new) |
| Growth | stationary spawner | host rooted in place, makes Crawlers | S4 nests, S5 | no mover; burn interaction |

## Gunplay quick wins (ADS, headshots)

**ADS shipped 2026-11-07.** Shots now spread inside a cone (`Weapon.HipSpread 1.5` degrees
half-angle, about 1 stud off at 40 studs); holding RMB aims down sights: `Weapon.ADS` =
spread 0.3, walk x0.6 with sprint off, camera eased in to 5 studs over the shoulder, FOV 55,
mouse sensitivity scaled with the FOV, crosshair ring closes. The client sends an `aiming`
flag with each shot and the server picks the cone.

**Hitscan and headshots shipped 2026-11-07.** The rifle no longer flies a projectile: the
server raycasts once per shot (`Weapon.Range 400`) and the damage lands the same frame;
tracers are client-drawn (`Weapon.TracerDuration`, own shots instantly, others' shots via
the `ShotTracer` remote). A `Head` hit deals `Weapon.HeadshotMultiplier 3.0` (the Brute's
definition overrides to 1.25, bone overgrowth) and arrives as damage kind `"headshot"`:
white, larger number and a sharper placeholder sound until the sound day. Drones still fly
projectiles. Realistic time-to-kill since the loadout rework (`Weapon.Damage 20`, flat
curve): Walker 3 body / 1 head, Runner 2 / 1, Hocker 4 / 2, Brute 13 / 11. Since the M16
pass (2026-11-07) the rifle is full auto at 750 rpm (`Weapon.FireCooldown 0.08`) with a
bloom on a held trigger and 7 magazines; time-to-kill roughly halved (Walker 0.16 s body,
Brute 0.96 s). Bots fire the same rifle slower (`Bots.FireCooldown 0.30`: three bots on
sustained fire ~ one player) with the same magazine and an infinite reserve, and use `ProjectileServer.hitMultiplier` so the Brute's plate applies.

## Technical plan (debt first, then content)

1. **Data-driven enemy behaviour.** Done 2026-11-06: `Behaviour` (melee | projectile,
   `StandOff`, `Windup`, `Projectile` + `Puddle`), `BodySet`, `ThroatSac`; caps keyed by
   type; `EnemyProjectileService` owns lobs, puddles and `damagePlayer`. Still to add as
   forms need them: `onDeath` (cloud | split), `mover` (none | flyer), `HeadshotMultiplier`.
2. **Resupply and the loadout.** Done 2026-11-07 (Resupply, then the loadout rework the
   same day: `docs/sprints/SPRINT_18_LOADOUT.md`). `RequisitionService` (pool fed by every
   kill's `SupplyValue` through an `EnemyService` kill listener and by the objective, cost
   curve, key 3 throws the flare through `ThrowUtil`, lure via `EnemyService.setLure`,
   `dropCrate(position, facing, kind, loud)` for pallets and upgrade crates, re-arm within
   `RearmRadius`, supply or upgrade card offers, pick validation by distance);
   `LoadoutService` (weapon + magazine, call-in slots, six upgrade slots, shield);
   `CallInService` (charges, the `CallIn` remote, dispatch to `DroneService` / `MineService`
   / `AirStrikeService` / `ShockCoilService`); `WeaponDefinitions`, `CallInDefinitions`,
   `UpgradeDefinitions`; client `LoadoutUI` (ammo counter, loadout strip), `ResupplyUI`
   (meter above the HP bar, world cards as billboards on local anchor parts, walk-in pick).
   `PauseService` only freezes the run end. Not yet: stores crates, boss pallet, the
   Armory, pallet/rotor sounds.
3. **ADS and headshots.** Small; slots anywhere after 2.
4. **Run state machine + Operation.** `RunManager` owns `Insert → Explore → Primary → Index
   → Extract → (next mission | Stand Down | Second Pass)` per run with stage index and pass
   count; `OperationService` owns the Burn and overrun; extraction becomes a called 90 s
   hold with waves; downed/revive, spawn pads, reset split, client screens
   (= Co-op Sprint A). Delta is the only stage, which proves the machine.
5. **Objective pools.** `ObjectiveService` draws a Primary and two Secondaries from the
   stage's pool, places them at sites/landmarks, shows markers; the 180 s delay goes. First
   four Primaries: Secure, Sanitize, Confirm Casualties, Open the Route. First three
   Secondaries: Silence the Alarm, Light the Pad, Misdrop.
6. **Index kit.** A boss is an Infected definition with `Boss = true`, a health bar, an
   entry path and one mechanic hook. **The Warden shipped 2026-11-07** (`IndexService`,
   `EnemyService.spawnBoss`, `BossBarUI`); the Bloat and the Patient reuse the frame.
7. **Containment Board.** `WarMapService` (one shared DataStore board), band overrides at
   stage load, the board screen between runs.
8. **Stage definitions.** `src/shared/StageDefinitions.luau`: landmark/hill/dressing tables,
   lighting preset, sites, Index entry, pads, stores, spawn phases, form unlocks, band
   dressing. `ArenaService` builds whichever stage is active. Then Mile 14 + Bloat, Kestrel +
   Shedder/Crawler + Patient, Stand Down and Second Pass, stages 4 and 5.

Build order: 2 → 3 → 4 → 5 (on Delta) → 6 → 7 → 8. Each step is one playtest-verified
feature. Co-op Sprint B (shared-pickup rules, event routing) threads through 4–7 as each system is
touched; player-count scaling shipped with the loadout rework (`Config.PlayerCountScaling`).

First playtest of Resupply logs per drop: clock minute, pool minus cost at throw (always ~0
means no "when" decision exists), distance from the previous drop, seconds to last pick,
deaths within 30 s. Targets: 5–7 drops per 12 min solo, picks within 20 s, at most one death
per three drops, consecutive drops 60+ studs apart. Fixes if missed: an overflow bonus
(throw at 1.5x cost for a fourth card); or `Wave 14`, `LureRadius 160` if drops camp a corner.

## The spine (decided by the owner 2026-11-07; v1 shipped the same day)

Power comes from the loadout, not from in-run stat growth: the Helldivers 2 model, with
one Hades-style twist. The section *Loadout, pallets and field upgrades* above is the
shipped shape; this is the order and what is still open.

- **Meta between runs.** Containment Board plus unlocks: call-ins, Chosen, field upgrades,
  the Armory (weapon families with variants: launch 5 primaries + 3 sidearms, 4 throwables,
  2 heavy call-ins, 2 specials; +3-4 guns per drop). Not built: every call-in is unlocked
  from run 1 and the dev panel swaps slots.
- **Bot squadmates.** Shipped 2026-11-07 (`server/BotService` on `server/Squad`,
  `Config.Bots`): follow in formation, shoot the nearest visible Infected with the service
  rifle's magazine, revive, respawn after 10 s. Not yet: call-ins, vaulting.
- **Order.** Co-op Sprint A → bots → loadout rework (done) → the Warden → objective pools →
  Mile 14.

The 2026-11-07 systems-designer numbers for the old economy (doubled item magnitudes,
`Requisition.CostCap` 2000, additive-stacking fix in `PlayerStatsService`) were never
applied; the economy they tuned is gone. Two findings carry over: pallets must keep landing
through the Index window, and chosen upgrades must stay legible next to the flat curve.
Cut with the rework: Plague Rat (tone, invisible damage, perf), every stat item, Vampire
Rounds, Shrapnel, Hunter's Mark, Scavenger Pouch; the Rats call-in from the lore pass is
open for a later Armory page.

## Backlog (decided, not scheduled)

- **Loadouts.** Superseded by the spine above (call-in slots, not RoR2 alternates).
- **Sound day.** Done 2026-11-07 for the player, hits and four Infected forms
  (`assets/audio/README.md > Banks`); still to generate: Control's radio lines, Lantern's
  rotor, the Burn, the pickup and item one-shots.
- **Infected visual redesign.** Own limb sets per form, Hocker first; hollow breach ring.
- **Dismemberment (built 2026-11-08, `Config.Enemies.Dismember`, `GoreService`).** The
  joint above the part a round hits keeps a running damage total; at the form's MaxHealth x
  the joint's fraction (elbow 0.35, shoulder 0.5, knee 0.5, hip 0.6) it breaks on that hit,
  the killing hit included, and the parts below fall like a Warden plate with a raw stump
  left at the joint. Rounds still do full body damage: time-to-kill is unchanged. Arm lost:
  melee x0.6 per arm. Leg lost: 0.35 speed, never climbs again (a crawl clip is still to
  come: the body limps on the stump for now). Brute legs never break. A killing headshot
  throws the head; the neck never breaks on a living body. Blast kills (Anvil, Tripline)
  throw 2 extra groups. At most 20 loose groups, 4 s each, anchored after 1.5 s. Flesh
  chunks at every body hit are client-side (`GoreFX`, 2 a hit, 4 a headshot, 24 alive).
  The Index hosts never sever: their plates are the mechanic. (Systems designer.)
- **Hollow Point tuning.** The stagger lands on every hit; watch for chain-stunning a Brute
  at 12.5 rounds/s since the M16 pass (shorten `Upgrades.HollowPoint.StaggerSeconds` or add a per-body gap).

## Open questions (for the owner)

None open; both 2026-11-06 forks are decided above.
