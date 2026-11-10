# PROGRESSION.md — the run: loadout, Resupply, missions, bosses, the Infected

Design doc for the run loop: Helldivers 2 structure (owner, 2026-11-06), our own names and
numbers. Canon and naming: [LORE.md](LORE.md). Tuning: `src/shared/Config.luau`. Map layout
(positions, pads, stores, sites): [LEVELS.md](LEVELS.md). What shipped: [HISTORY.md](HISTORY.md).
Pillars: [PLAN.md](PLAN.md). Co-op rules: [MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md).
Owner rules: [OWNER.md](OWNER.md).

Names (owner, 2026-11-08): one map is a **mission**; three missions are an **operation**.
Code identifiers (`Stage*`, `Operation*`) keep their names.

## The run in one paragraph

Harlan Control inserts Pike (four anonymous soldiers, Pike One to Four; bots fill empty
seats) by helo ("Lantern") into a district of the Harlan corridor before its scheduled fire
mission, **the Burn**. Each district is one **mission**: a **Primary** objective from the
mission's pool and two optional **Secondaries**. The squad explores, loots abandoned
**stores**, earns **Resupply** pallets and **field upgrades** while the difficulty clock
runs. Completing the Primary calls the district's **Index** host (the boss). When ready, the
squad pops green smoke, holds the LZ for 90 s and boards. Delta, Mile 14 and Kestrel make an
**operation**. Boarding at Kestrel is **Stand Down**: the run ends on your terms, scored.
Every mission brought home raises that district's **containment %** on the shared
**Containment Board**.

## The loop

| Step | What happens | Today |
|---|---|---|
| Insert | Lantern lands at the pad; squad spawns; Control reads the Primary, Secondaries and the Burn timer (14:00) | spawn at four pads round the LZ (`Config.Run`) |
| Explore | Loot stores, earn Resupply, find field upgrades; clock runs (`Config.Difficulty`) | Resupply and the loadout built; no stores |
| Primary | One from the mission's pool, at one of its three sites or a named landmark; the squad starts it | hold zone appears at one spot after 180 s (`Config.Objective`) |
| Index | Completing the Primary calls the boss from its canon entry | the Warden on Delta |
| Call the bird | Green smoke at a pad; Lantern inbound 90 s; squad holds the LZ; anyone outside is left (Dead for the mission) | 30 s hold, every living player on the pad, run ends |
| Next mission | Dead players respawn at the next pad; clock, Resupply pool and drop counter carry over | not built |
| Stand Down | After Kestrel: board = run ends, scored; or a **Second Pass** (same corridor, higher clock floor, later forms, containment gains doubled) | not built |

Failure: squad all dead = mission lost, operation over; containment from missions already
extracted still counts. The Burn running out does not end the run.

## Loadout, pallets and field upgrades

Power is the loadout, never in-run stat growth (owner, 2026-11-07): Helldivers 2, plus one
Hades-style twist (field upgrades). Retired 2026-11-07/08: XP, levels, orbs, stat items and
rarity, the class system and the Chosen, Q dash, E breach, Combat Momentum; see
[HISTORY.md](HISTORY.md).

### The soldier

Every player is a Pike soldier; no classes, no hero kit. A soldier carries a primary, the M17
sidearm, a grenade type and four call-ins (keys 1-4), picked in the **Arms Room** (B).
Q swaps long gun and sidearm (`Weapon.SwapTime` 0.5 s; no shot, no reload; a reload in
progress is dropped; each gun keeps its own magazine). G throws a grenade (3 carried; a
pallet refills). V shoves (15 dmg, 0.8 s stagger, 6-stud push, 1 s cooldown). E uses a stim
(2 carried, heals 60 over 1 s; Medkit refills). 5 throws the Resupply flare (always carried).
Every gun is hitscan at its real-world rate (the Goose fires a rocket); the server owns every
magazine (`LoadoutService`). A shotgun's pellets are drawn by the client and checked by the
server against its cone (`Rules/Spread`), so the pellets you see are the ones that hit. Each
gun row may name its held mesh (`Model`; every gun has one, `assets/3d/build/guns.py`), its
clips in the `guns` sound bank (`Sound`) and, for a launcher, `Explosive` +
`ProjectileSpeed`. Bots carry the service rifle.

**Aiming throws** (owner 2026-11-09: "hold and release ... so I actually know where it
lands"): G and every thrown call-in (CallInDefinitions Kind "throw") are held to aim and
thrown on release. A dotted arc from the hand and the item's own marker on the ground
(`Config.CallIns.<Name>.Aim`: a ring of Radius, or a strip of Length x Width along the throw,
`Across` for the wire) follow the crosshair. The flare (5) and the "self" call-ins still
fire on the press. `AbilityController`.

### Guns

Numbers in `Config.Weapons.<Gun>`, rows in `WeaponDefinitions`. Semi guns fire once per click.

| Gun (real) | Role | Mode, rpm (`FireCooldown`) | Dmg | Mag + reserve | Reload | Hip / ADS | Bloom per shot / max | Range | Pierce |
|---|---|---|---|---|---|---|---|---|---|
| **M16A4 Service Rifle** (baseline) | all-rounder, 3-5 round bursts | auto, 750 (0.08) | 20 | 30 + 240 | 2.2 | 1.5 / 0.3 | 0.3 / 3.5 | 400 | 0 |
| **MP5 SMG** | best hip-fire; chews Runners, weak on Brutes | auto, 800 (0.075) | 14 | 30 + 210 | 1.8 | 0.9 / 0.6 | 0.15 / 2.0 | 150 | 0 |
| **M249 LMG** | 100-round belt, no reload in a hold; slow to aim moving | auto, 800 (0.075) | 20 | 100 + 300 | 5.5 | 3.0 / 0.5 | 0.15 / 2.5 | 400 | 0 |
| **Mossberg 590 Shotgun** | point-blank, one decision per pull | pump, 80 (0.75) | 11 x 8 pellets | 8 + 40 | 3.5 | 5.0 / 3.5 | 0 | 45 | 0 |
| **M110 DMR** | one-taps Walkers, hits two in a line; poor up close | semi, 300 (0.2) | 60 | 20 + 80 | 2.6 | 4.0 / 0.1 | 1.2 / 3.0 (recovery 8) | 600 | 1 |
| **M17 Pistol** (sidearm) | backup when the primary runs dry | semi, 400 (0.15) | 25 | 17 + 68 | 1.5 | 1.2 / 0.5 | 0.6 / 2.5 | 120 | 0 |
| **S&W 686 Revolver** (sidearm, sample) | panic button: one round per Walker, staggers a Brute | semi, 150 (0.4) | 55 | 6 + 30 | 2.8 | 1.8 / 0.4 | 1.5 / 3.5 (recovery 10) | 150 | 0 |
| **M2010 ESR Sniper** (sample) | one round per kill, Brute in 2, through four in a line; useless from the hip | bolt, 48 (1.25) | 140 | 5 + 30 | 3.2 | 6.0 / 0.05 | 0 | 800 | 3 |
| **Goose, M3 recoilless** (sample "RPG", primary slot; later the call-in) | a visible rocket at 220 studs/s: 400 to the Infected struck, then the frag's blast 120 in 6 studs, no friendly fire | single, reload 6 s | 400 + blast | 1 + 1 | 6.0 | 2.0 / 0.25 | 0 | 300 | 0 |

- ADS move factor: rifle 0.6, SMG 0.85, LMG 0.35, shotgun 0.7, DMR 0.5, pistol 0.9. ADS
  pulls the camera to 5 studs over the shoulder at FOV 55 (`Weapon.ADS`); the client sends
  an `aiming` flag with each shot and the server picks the cone.
- Headshot x3.0 (per gun, `HeadshotMultiplier`); the Brute overrides to 1.25 (plated skull).
  Tracers are client-drawn.
- Rounds to kill body / head: rifle Walker 3 / 1, Brute 13 / 11; SMG 4 / 2, 19 / 15; DMR
  1 / 1, 5 / 4; shotgun one pull for every form but the Brute (3). Ammo reins in the DMR
  (100 x 60 is the M16's 270 x 20).
- Bots fire the rifle slower (`Bots.FireCooldown` 0.30: three bots on sustained fire ~ one
  player), same magazine, infinite reserve.
- The three sample guns (2026-11-09) are in the Arms Room like every gun: its lists are every
  row of the slot, ordered by the row's `ArmsOrder` (default 100; the first is the default
  gun), so a new gun appears by having a row. ADS move: revolver 0.85, sniper 0.4, Goose 0.4.
  Revolver Walker 1 / 1, Brute 5 / 4; sniper every form 1, Brute 2 / 2.
- Grenades: **Frag** (110 in 10 studs, 0.8 s fuse; one-shots a Hocker, not a Brute) is
  built. Later: **Incendiary** (3 fire pools, `IncendiaryService`) and **Stun** (0.4x slow
  3 s in 14 studs, `ShockCoilService.stunArea`).
- Feel (owner: part of the design): every gun, grenade and call-in carries its own `Kick`,
  `ShakePower` / `ShakeGlobal`, `Heavy` (staggers a Brute) and `ReloadClip` on its own row,
  with a default (`Config.Camera`). Never a hard-coded list of item names in a system.

### The Arms Room (loadout menu, key B)

Pick one primary, one sidearm, one grenade and four different call-ins (at most one support
weapon). Open during Insert / ready-up, or in a run within `Config.Loadout.LzRadius` 30 of
the LZ pad after `CalmSeconds` 5 without dealing or taking damage. A newly picked gun starts
full (re-picking the carried one keeps its ammo); a call-in that changes slot in a run starts
empty with its cooldown running (before the drop it starts full); a field upgrade follows its
call-in to its new slot. The pick survives a run restart. Once the lobby exists the loadout is
chosen there and the in-mission Arms Room is a stand-in (OWNER.md; Nova owns the screens).

Module boundary, so the lobby can host it:
- `src/shared/Rules/Loadout.luau` (pure, spec-tested): `default(catalog)`,
  `validate(loadout, catalog) -> (ok, reason)`, `canChange(state, settings)`,
  `changedSlots(old, new)`.
- `src/shared/ArmsRoom.luau`: the catalog from the definition modules; Tripline first by
  default, then `CallInDefinitions.Order` (default slots Tripline, Hammer, Anvil, Shrike).
- `src/client/LoadoutMenu.luau` (UI only: `mount(parent, onConfirm)` returns a handle with
  `set` / `status`; LoadoutUI hosts it on B).
- `LoadoutService.apply(player, loadout)` (server: validation plus the timing gate).
- Remote `Loadout`: `Messages.Loadout.Request` `{primary, secondary, grenade, callIns}` and
  `Messages.Loadout.Result` `(ok, reason)`. The server publishes `Primary`, `Secondary`,
  `Weapon`, `Grenade`, `Grenades`, `Stims`, `SwapUntil`, `CallIn1`-`CallIn4`.
- The lobby (ARCHITECTURE F10) validates with the same Rules module, saves through F9 and
  passes the table in teleport data.

### Call-ins

`CallInDefinitions`, numbers in `Config.CallIns`; no friendly fire. Four slots, keys 1-4;
each holds charges that refill one at a time. Lantern's crew kicks support weapons and supply
out of the door; fire missions are someone on the net. HUD names and radio: [LORE.md](LORE.md)
> The Arms Room. Call-ins must be things a real army fields (OWNER.md).

| Kind | Name (designation) | What it does | Charges / cooldown | Built |
|---|---|---|---|---|
| Support | **Gun** (M240B) | 40 dmg, 650 rpm, pierce 1, 100 + 100 belt, 7 s reload, ADS move 0.3; takes the long-gun slot until empty, downed (drops at the body) or replaced | 1 / 240 | no |
| Support | **Goose** (M3 recoilless) | 2 single shots; 400 direct, 120 in 6 studs | 1 / 120 | no |
| Support | **Thumper** (M32) | 6-round drum, 0.5 s apart, 70 in 7 studs, 24 rounds | 1 / 180 | no |
| Support | **Kettle** (M9 projector) | 15-stud cone, 10 per 0.1 s, fire pools, 20 s of fuel | 1 / 180 | no |
| Fire mission | **Hammer** (81 mm mortar) | 6 shells 1 s apart, 80 in 12 studs, scatter 4 | 1 / 120 | yes |
| Fire mission | **Anvil** (105 mm battery) | one shell after 5 s, 500 in 20 studs, shake felt map-wide | 1 / 180 | yes |
| Fire mission | **Shrike** (helicopter gun run) | 10 bursts stepping 4 studs along the throw, 120 in 5 studs each, 4 s delay | 1 / 150 | yes |
| Emplacement | **Doorman** (tripod sentry MG) | 45 s, 20 dmg every 0.15 s, range 70, one per player | 1 / 150 | yes |
| Emplacement | **Tripline** (AP mines) | 6 mines on an arc, 80 in 10 studs, 90 s, 12 per player | 2 / 60 | yes |
| Emplacement | **Concertina** (wire) | 16 x 3 strip for 60 s: 0.4x slow, 5 dps; never vaultable | 2 / 90 | yes |
| Supply | **Speedball** (ammo bundle) | 4 re-arms (a player again only after stepping out), no lure wave | 1 / 180 | yes |
| Supply | **Aid Bag** (medical drop) | every soldier within 6 studs: full heal, stims refilled, +25 plate; once each | 1 / 180 | yes |

Every built call-in is thrown (`Kind "throw"`, `ThrowUtil` clamp). Services:
`AirStrikeService` (Hammer, Anvil share `fireMission`, patterns from `Rules/StrikePattern`;
Shrike's `gunRun` under a Part gunship at 45 studs), `SentryService` (Doorman: a ray from the
muzzle to the nearest visible Infected), `MineService` (Tripline), `ConcertinaService`,
`SupplyDropService` (Speedball, Aid Bag fall 50 studs and land quiet). The support weapons
need the support-weapon carry and the explosive projectile hook (ARCHITECTURE F7). Dev:
`SetCallIn <slot> <id>`, `FireCallIn <id>` (20 studs ahead, no slot or charge).
Retired 2026-11-08: Magpie (drones) and Pen Coil (shock pulse), too sci-fi; see HISTORY.md.

### Pallets (Resupply)

- The Resupply pool (one meter on every HUD) is fed by every kill's `SupplyValue` at any
  distance (Walker 10, Runner 12, Hocker 18, Brute 35) and by the Primary
  (`Objective.SupplyReward` 500).
- When the pool covers the cost (`Requisition.BaseCost` 300, x1.15 per drop, cap 1000, +40%
  per extra player) any living player throws the red flare (key 5, 35 studs). For 20 s the
  Infected inside 120 studs walk to the flare; then the pallet lands loud (`Lure.Wave` 10, +3
  per extra player; spawn interval x0.7 for 30 s).
- **The pallet is the ammo box:** every living player within `RearmRadius` 6 is re-armed
  once (both guns full, grenades back).
- Three cards, the same for everyone (`Crates.SupplyCards`): **Medkit** (full heal, stims
  back), **Restock** (every call-in slot full, grenades and stims too), **Armour Plate** (+50
  shield soaked before health, cap 100). One pick per player per pallet; cards vanish at
  60 s. No rarity, no upgrades from pallets.
- Playtest targets per drop: 5-7 drops per 12 min solo, picks within 20 s, at most one death
  per three drops, consecutive drops 60+ studs apart, pool minus cost at throw not always ~0
  (else there is no "when" decision). Fixes if missed: an overflow bonus (throw at 1.5x cost
  for a fourth card); or `Wave 14`, `LureRadius 160` if drops camp a corner.
- Pallets must keep landing through the Index fight.

### Field upgrades

`UpgradeDefinitions`, flags on `LoadoutService`, numbers in `Config.Upgrades`. Slots: Grenade,
Weapon, Kit and one per carried call-in (`CallIn1`-`CallIn4`; the upgrade moves with its
call-in); a new pick in a filled slot replaces it. Each changes how a tool works, never a
percentage, and must stay legible next to the flat curve. Sources: the Primary's site crate
(lands when the hold zone appears; shows 3 you can still take) and the Index pallet; later
Stores and Secondary crates (3-5 per mission).

| Slot | Lore name | Effect |
|---|---|---|
| Grenade | Bait Charge | a frag lures the Infected inside 18 studs for 3 s before it goes |
| Weapon | Through-and-Through | a round carries into the next Infected (any gun) |
| Weapon | Hollow Point | the hit Infected stops for 0.6 s (any gun) |
| Kit | Last Stand | fire from the ground while downed (hip, spread x2) |
| Kit | Spare Tourniquet | stand up on your own 4 s after going down, once per mission, no revive spent |
| Hammer | Walk It In | the shells step 8 studs along the throw |
| Tripline | Daisy Chain | press the key again to blow every armed mine (no charge) |

Watch: Hollow Point staggers on every hit; at 12.5 rounds/s it can chain-stun a Brute
(shorten `Upgrades.HollowPoint.StaggerSeconds` or add a per-body gap).

### Threat curve

Flat: `Config.Difficulty` health and damage stay 1x. Pressure is the spawn interval (3 s,
x0.95 per minute to 1.5 s), the max-alive schedule (10 / 14 / 20 / 26, late 30), the phase mix
(Walker-only up to W38 R30 B16 H16) and the player count (`Config.PlayerCountScaling`: spawn
interval x0.8, +3 alive and +1 heavy per extra living player, hard cap 44).

### Stores and the priority pallet

- **Stores** (not built): free crates at the position's abandoned stock. Hold E 3 s to open,
  which is loud. Count per Containment band below; places in LEVELS.md.
- **Priority pallet** (built with the Warden, `IndexService.endFight`): an Index kill drops a
  pallet at the corpse: re-arm, full heal, three upgrade cards each.

## Operation: the Burn, extraction, scoring (not built)

- **The Burn** (mission timer, 840 s for 1-4 players; more players split objectives, time is
  the one resource more-not-tougher does not hand out). Only the Burn counts down on the HUD;
  run time stays a plain readout. At 0:00 the incendiaries land: burning dressing, no more
  pallets, spawn interval x0.5, more alive and +2 Brute/Hocker caps (`Config.Overrun`,
  reserved), Lantern takes 120 s instead of 90. The run goes on; extracting after the Burn
  scores Partial. Calling the bird freezes the timer.
- **Extraction.** A 90 s hold; on call Walker 10 Runner 4 (+3 Walkers per extra player), a
  second phase-weighted wave of 12 at 45 s, spawn interval x0.6. Progress accrues only while
  every living player is on the pad (MULTIPLAYER_READINESS #3). Secondaries do not shorten it.
  Alternate pads come from "Light the Pad".
- **Secondaries** reward a Secondary crate on site and +3 containment; no timer extension, no
  Resupply.
- **Score per mission:** Win (Primary done, extracted before the Burn) 12; Partial (Primary
  done, extracted or wiped after the Burn) 6; Loss (wiped before the Primary) 0; each
  Secondary +3. Perfect operation = 18 per district.

## The Containment Board (war map, not built)

Every district carries a containment % raised by every extracted mission. Delta starts at 25;
the others at 0; the next district unlocks at 50 of the previous. Perfect play reaches 100 in
6 operations; a first-timer in 10-12 (a weekend). The board is **shared across all players**
(owner, 2026-11-06): one global DataStore key per district, written with `UpdateAsync` so
concurrent servers add, never overwrite; each server reads it at run start and once per
minute (scaling plan: [ARCHITECTURE.md](ARCHITECTURE.md)). Contained means the district
stopped exporting hosts, not zero Infected.

| Band | % | `InitialCount` | Clock start | Brute / Hocker first spawn | Stores | Visible (cheap) |
|---|---|---|---|---|---|---|
| Lost | 0-24 | 8 | +60 s | 150 / 360 | 2 | fires, lamps dark, siren/horn/PA looping |
| Contested | 25-49 | 5 | 0 | 180 / 480 | 2 | today's tuning |
| Held | 50-74 | 4 | 0 | 210 / 540 | 3 | main-road lamps lit, fires out, alarm silent, one extra Stores crate |
| Contained | 75-99 | 3 | 0 | 240 / 600 | 4 | all lamps, no fire inside the walls, permanent second pad, ambient swap |
| Secured | 100 | 3 | 0 | 240 / 600 | 4 | sweep ops, rewards x0.25 |

Build cost per band: a PointLight toggle, `burning` flags, a fog tweak, a spawn table keyed by
band, one ambient swap, one extra helipad. Nothing new to model.

## Objective pools (not built; today: one hold zone)

Completing the Primary calls the Index. Each objective is one rule (pillar 3), built from hold
zone, kill count, interact-with-prop, carry, destroy, survive, reach. Props and points per map:
LEVELS.md.

### Primaries

| Name | Radio brief | Player rule | Missions | Showcases |
|---|---|---|---|---|
| Secure the Site | "Re-establish the perimeter at [site]. Hold until Control confirms." | 45 s accumulated inside the zone (today's hold) | all, at the three sites | the mission's pressure mix |
| Sanitize | "Control wants fire at the pens, not confirmation. Three sites." | hold E at 3 marked props in any order; each ignites and spawns a wave | Delta Pens tents; Mile 14 sealed buses; Kestrel Ward bed rows | Runner; Shedder/Crawler flushed by fire |
| Recover the Record | "Recover Delta's screening record. Control needs to know who went north." | pick up at A, carry to B; carrier cannot sprint; dropped when downed | Delta Ridge → comm tower; Mile 14 toll log → Overpass; Kestrel manifest → roof | Runner, Hocker |
| Restore Comms | "Get the mast up. Control is blind north of the gate." | hold E 10 s (interruptible) at the high prop, then survive 60 s there | Delta comm tower; Mile 14 water tower; Kestrel roof | Hocker shelling high ground |
| Confirm Casualties | "Control is tracking six heavy hosts in the Depot. Put them down." | kill N marked (outlined) spawns at a landmark | Delta Brutes in the Depot; Mile 14 Hockers on the deck; Kestrel Bloats in the Ward | Brute / Hocker / Bloat |
| Open the Route | "The Gate is chained from outside. Open it; the next mission walks through here." | destroy 3 shootable props, then one player reaches the point beyond | Delta the Gate (Warden walks through); Mile 14 the lead bus (the Bloat is inside) | the boss entry |
| Evacuate the Holdouts | "Transponder in the Ward. Alive inside. Get them to the LZ." | 2-3 survivors follow the nearest player; must reach the pad alive | Kestrel, Mile 14 Rest Stop. Never Delta ("CLEARED 0") | Runner, Hocker puddles |

### Secondaries (two offered per mission)

| Name | Radio brief | Player rule | Missions | Effect beyond the crate |
|---|---|---|---|---|
| Silence the Alarm | "Something's still running the alarm at the Gate. It's drawing them." | hold E on the looping sound source | Delta siren; Mile 14 bus horn; Kestrel PA | spawn rate drops in its radius |
| Lights On | "Depot generator's intact. Get the lights on." | hold E 8 s at a generator | Delta Depot; Mile 14 Toll Plaza; Kestrel Field | the district's lamps light (preview of Held) |
| Light the Pad | "There's a second pad on the Depot apron. Mark it." | hold E at a marked pad | Delta Depot; Mile 14 Rest Stop; Kestrel Triage Lot | extraction can be called there |
| Sample Run | "Control wants tissue from a heavy host. Bag one." | kill the marked Brute/Bloat, hold E on the corpse, carry (no sprint) to the LZ | all | the next pallet shows 3 field-upgrade cards |
| Headcount | "Control has 212 names from the Delta roster. Confirm what's left." | reach and interact at the mission's 3 story spots | all | lore delivery, moves the player (pillar 1) |
| Clear the Spitters | "Hockers on the Overpass are shelling the toll lane." | kill N of one form before a short timer | Mile 14, Delta late | Resupply burst |
| Misdrop | "Lantern put a pallet in the Suburb. It's yours if you get there first." | reach a crate in an outer district within 4 min | all | the crate is the reward |
| Sealed Bus | "Bus 7 reads NEG on the manifest. Confirm it." | hold E on a chained bus; Runner burst; kill all | Delta Gate, Mile 14 the Jam | dark beat (it was never NEG) |
| Recover Logs | "Toll booth recorder is still live. Pull it." | walk-in pickup at one story spot | all | codex entry |

## Missions

Every mission is a 600 x 600 map with up to five height levels, built in code (layout and
coordinates: [LEVELS.md](LEVELS.md); look: [STYLES.md](STYLES.md)). Each has four to six named
landmarks, three objective sites, one Index entry, one helo pad plus an alternate, two story
spots and two to four stores. Lighting moves with the corridor: evening at Delta, full dark at
Mile 14, dawn at Kestrel. The burning skyline is the districts that already got their Burn.

### Checkpoint Delta (built)

- **Was:** the corridor's southern screening gate. Civilians were held and checked here
  before being let north. It fell from the inside when the pens turned. Walls face out,
  bodies are inside.
- **Sites:** Screening Compound (high, climbable from every side, tower blocks lines); the
  Pens (low and flat, hesco lanes funnel the Infected into three mouths); the Overlook
  (tallest and narrow, Hockers below shell the summit).
- **Primaries:** Secure, Sanitize (Pens tents), Recover the Record, Restore Comms, Confirm
  Casualties (Brutes, Depot), Open the Route (the Gate). Not Evacuate.
- **Index:** the Warden walks out of the Gate and up the main road, seen coming the whole way.
- **Story spots:** burning Ridge barracks whiteboard "SCREENED 212 / CLEARED 0"; a Gate bus
  chained shut from outside, "NEG" sprayed then crossed out.
- **Band dressing:** Lost: Gate siren looping. Held: main-road lamps lit, Ridge fire to
  smoke, siren silent. Contained: all lamps, Depot pad permanent, intact humvee with
  headlights at the Gate, wind instead of siren.

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

## Index hosts (bosses)

One per district, called by completing the Primary, arriving from a canon entry so the squad
sees it coming. Each is the next rung of the strain; the Mile 14 Index becomes a common form
on Kestrel. An Index kill drops a priority pallet. Backstory: [LORE.md](LORE.md) > Index hosts.
Each boss is its own design with its own silhouette and build file, and its own sound bank
(a bellow, footfalls, an impact per attack, a learnable tell, a death) under one sound
profile (owner, 2026-11-07/08; `assets/audio/README.md`).

| Index | Mission | Mechanic (one rule) |
|---|---|---|
| the Warden | Delta | armoured: shoot the plates off, then the body (**built**, below) |
| the Bloat | Mile 14 | area denial: bursts into a lingering cloud on death; kill it where you can afford the cloud |
| the Patient | Kestrel | regenerates in waves: damage windows between surges |
| the Lineman | Harlan Yard | drags a player; its call pulls the map |
| the Specimen | Reservoir | every mechanic above, in phases |

A boss is an Infected definition with `Boss = true`, a health bar, an entry path and one
mechanic hook (`IndexService`, `EnemyService.spawnBoss`, `BossBarUI`); the Bloat and the
Patient reuse the frame. Index hosts never dismember: their plates are the mechanic.

### The Warden (built; `Config.Index.Warden`, `IndexService`, [SPRINT_19_WARDEN.md](sprints/SPRINT_19_WARDEN.md))

- **Entry.** He spawns beyond the Gate, the Gate opens (radio) and he walks the screening
  route: Gate lane, bus line, Inner Gate, under the bridge, the Apron, then the hunt (walk
  times out after 75 s). A member within 90 studs during the walk gets the sighting line.
  Radio lines: LORE.md.
- **Body.** 7,000 hp at scale 1.9, +33% per extra living player (the one exception to "more
  Infected, not tougher": one body cannot be more bodies). Headshot x2 once the helmet is off.
- **Plates** (one rule): helmet 300, chest 500, back 400 (the flank), shoulders 300 each,
  shield 600. A round into a plate does 25% to the plate and nothing to the body; a round into
  a limb whose plate is gone does 150%. At half a plate cracks (yellow pip); at zero it flies
  off, he staggers 1.5 s. HUD order: HELM, CHEST, BACK, L SHLD, R SHLD, SHIELD.
- **Attacks**, each announced by the handset's words on the boss bar. Where you stand picks
  his move: **Bash** (0-15 studs, 70° arc, 40, 0.9 s windup; roll through it); **Shield
  Sweep** (17 studs, 180°, 25 and a shove; get behind him); **Overhead Slam** (17 x 6 line at
  a body that stopped moving in reach, 60, 1.3 s; step aside); **Ground Pound** (23-stud ring
  drawn through the 1.4 s windup, 30 and 2.4 s knocked down; beat it with distance or a
  ledge, not the roll; he is stuck 2.6 s after); **Stomp** (a body within 7 studs: 8.5-stud
  disc, 20 and 1.8 s knocked down, 0.6 s; roll it); **Charge** (19-45 studs, 1.2 s windup,
  45 studs at 40/s, 35; hard cover stuns him 3 s); **Gas Canister** (phase 2+, or any phase
  at a perched member; furthest member within 70, 10 + a 9-stud puddle 6 s); **Guard** (his
  plates took 150 inside 3 s: shield up 2.5 s, half speed, frontal plates take 25%; flank
  him). He walks a beat between attacks (1.0 / 0.7 / 0.4 s by phase), never repeats one
  except the Bash, never chains two knockdowns. Limb attacks miss a rolling body; the Pound
  and the Charge do not. Knocked down: no moving, firing or abilities; 1 s immunity on the
  get-up (`Config.Knockdown`). Bots step out of the ring and the lines.
- **Phases** by body health: below 60% the **Riot Call** (6 Walkers + 2 Runners, +3 Walkers
  per extra player); below 25% a second call, charges every 5 s, walk 11. While he is up the
  wave loop spawns at x1.5 interval, 8 fewer alive, no Brutes.
- **Kill.** Priority pallet at the corpse, everyone alive healed and re-armed, extraction
  opens. Corpse stays 8 s.
- **Target fight** 100-120 s for a squad that works the plates; retune plate health first.

## The Infected roster

Ordered by how far the strain has gone in one body. Model name stays `Infected`; the slang
goes on the kill feed. Each form is one rule (pillar 3). Look: blocky Roblox bodies,
lore-accurate poses, no zombie green (OWNER.md); build sheets in [CHARACTERS.md](CHARACTERS.md).

| Form | Role | Look | First seen | Engine |
|---|---|---|---|---|
| Walker | slow melee | still a person, grey, old wounds closed | Delta | built, 55 HP |
| Runner | fast melee | dense rebuilt muscle, tendons like cable | Delta | built, 35 HP |
| Brute | melee tank | bone overgrowth, plated shoulders | Delta | built, 260 HP, headshot x1.25, legs never break |
| Hocker | ranged | lobs caustic fluid; throat a swollen sac | Delta late | built, 75 HP |
| Bloat | exploder, area denial | gas-swollen, pale belly, veins showing | Mile 14 Index, common Kestrel | on-death cloud |
| Shedder | splitter | body seamed into segments, extra limbs | Kestrel | on-death spawns 2-3 Crawlers |
| Crawler | swarm | shed segment, fast, fragile | Kestrel (from Shedders) | small rig, no attack clip needed |
| Kite | flyer | shed tissue on ribbed membranes, dives | Harlan Yard | non-Humanoid mover (new) |
| Growth | stationary spawner | host rooted in place, makes Crawlers | Yard nests, Reservoir | no mover; burn interaction |

Enemy behaviour is data-driven (`EnemyDefinitions`: `Behaviour` melee | projectile,
`StandOff`, `Windup`, `Projectile` + `Puddle`, `BodySet`, `HeadshotMultiplier`; caps keyed by
type; `EnemyProjectileService` owns lobs and puddles). Still to add as forms need them:
`onDeath` (cloud | split), `mover` (none | flyer).

## Hit feedback on the Infected (owner: it must feel satisfying)

- **Dismemberment** (`Config.Enemies.Dismember`, `GoreService`). The joint above the part a
  round hits keeps a running damage total; at the form's MaxHealth x the joint's fraction
  (elbow 0.35, shoulder 0.5, knee 0.5, hip 0.6) it breaks on that hit, the kill included; the
  parts below fall and a raw stump stays. Rounds still do full body damage: time-to-kill is
  unchanged. Arm lost: melee x0.6 per arm. Leg lost: 0.35 speed, crawls (`zombie_crawl`),
  never climbs. Brute legs never break. A killing headshot throws the head; the neck never
  breaks on a living body. Blast kills throw 2 extra groups. At most 20 loose groups, 4 s
  each. Flesh chunks per hit are client-side (`GoreFX`, 2 a hit, 4 a headshot, 24 alive).
- **Limp bodies** (`Config.Enemies.Ragdoll`). A dead Infected goes limp and the killing hit
  throws it (rounds scale with damage, blasts hardest); 8 limp at once, the rest play the
  death clip; bodies stay 4 s and let rounds through.
- **Flinch** (`Config.Enemies.Flinch`). A hit that does not kill flinches the body at most
  every 0.6 s; a headshot jerks harder and slows it for 0.15 s; the Brute flinches only from a
  `Heavy` gun (shotgun, DMR) or a blast.

## Build order (what is left)

Done: data-driven enemies, Resupply and the loadout, ADS and headshots, the run state machine
(`Lobby → Insert → Explore → Primary → Index → Extract → Ended`, Co-op Sprint A), bots, the
Warden. Next, each one playtest-verified feature:

1. **Objective pools.** `ObjectiveService` draws a Primary and two Secondaries from the
   mission's pool, places them at sites/landmarks, shows markers; the 180 s delay goes. First
   four Primaries: Secure, Sanitize, Confirm Casualties, Open the Route. First three
   Secondaries: Silence the Alarm, Light the Pad, Misdrop. Needs the mission data split (F6).
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
- **Bots:** call-ins and vaulting.
- **Sound:** Control's voiced radio lines, the Burn, pickup one-shots
  (`assets/audio/README.md`).
