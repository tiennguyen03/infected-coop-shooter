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
seats) by helicopter ("Helo" on the radio) into a district of the Harlan corridor before its scheduled fire
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
| Insert | The helicopter lands at the pad; squad spawns; Control reads the main objective and the Burn timer (14:00) | spawn at four pads round the LZ (`Config.Run`); the main objective's card (name, why, where) and Control's brief; no Burn timer |
| Explore | Loot stores, earn Resupply, find field upgrades; clock runs (`Config.Difficulty`) | Resupply and the loadout built; no stores |
| Primary | One main objective from the mission's pool, at one of its sites; the squad starts it by reaching it. Side objectives are found on the ground | built on Delta: five main and four side objectives (Objective pools below); `Config.Objectives.Enabled = false` puts back the single hold zone after 180 s |
| Index | Completing the Primary calls the boss from its canon entry | the Warden on Delta |
| Call the bird | Green smoke at a pad; Helo inbound 90 s; squad holds the LZ; anyone outside is left (Dead for the mission) | 30 s hold, every living player on the pad, run ends |
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

**Stamina** (owner 2026-11-11; `Config.Stamina`, `Rules/Stamina`, client-owned like sprint):
100, sprinting drains 12/s (~8 s from full), back at 22/s after 1 s without spending (empty to
full ~5.5 s). A roll costs 20, a slide 10 (any stamina left is enough; it floors at zero);
vault, climb and shove are free. At zero the soldier is **winded**: no sprint, roll or slide
until 25 (~2.1 s), then a held Shift sprints again. Downed or knocked down nothing drains; a
respawn or a new run refills it. Bots have none.

**Keys:** Shift twice rolls; holding C or Ctrl while sprinting slides until the key is let go.
**Slides keep momentum** (owner 2026-11-11; `Config.Movement.Slide`, `Rules/Slide`): a slide
starts at the speed going in + 6 (at least 24, at most 40 studs/s), loses 17/s to friction and
gains 60/s x the slope's sine from the floor under it: flat from a sprint is the old ~0.95 s,
about 16 degrees downhill holds its speed, steeper gains up to 40, uphill dies in about half the
time. It ends at 14 studs/s (or after 6 s); speed still above the walk or sprint speed bleeds
off at 40/s instead of snapping. One stamina cost on entry, however long the hill.
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

**Throwing** (owner 2026-11-11: things "activate before the actual animation plays"): the
grenade, every thrown call-in and the flare leave the hand at the throw clip's release, not
when the key comes up.
- **Timing:** `Config.Animations.Throws` has a row per throw clip (`Start`, `Release`,
  `Speed`, over `Default`); `Rules/ThrowTiming` turns it into the wind-up. `grenade_throw`
  is 2.77 s with the release at 2.0 s (the hand's fastest frame in the retargeted clip); it
  plays from 1.3 s at 1.4x, so the wind-up is 0.5 s. A new throw clip gets its own row.
- **Client:** the clip starts the moment the key comes up (`AnimationController.playThrow`)
  and replicates to the squad; a second throw waits for the first to leave the hand.
- **Server:** `ThrowWindUp.begin` holds the real throw back for the wind-up (less up to
  `ThrowMaxLag` 0.1 s of the thrower's ping), one throw at a time per soldier. The grenade,
  the charge or the pool is spent **at the release**: downed, knocked down or dead during the
  wind-up throws nothing and costs nothing.
- **From the hand:** the grenade and the flare fly from the thrower's `RightHand` to the mark
  (remote `Thrown`, drawn by `ThrowFX`; `Grenade.Flight` and `Requisition.FlareFlight`,
  0.45 s) and the real one appears where it lands; the frag's 0.8 s fuse still starts on
  landing. A call-in's marker starts at the hand too (`CallInArrivalFX`).
- **With arrivals:** a call-in's `Arrival.Time` and a fire mission's `Delay` count from the
  release, so key to effect is the 0.5 s wind-up plus what it was.
- **Not there:** no prop in the hand during the wind-up (no model exists); bots throw
  nothing yet; dev `FireCallIn` skips the wind-up.

### Guns

Numbers in `Config.Weapons.<Gun>`, rows in `WeaponDefinitions`. Semi guns fire once per click.

| Gun (real) | Role | Mode, rpm (`FireCooldown`) | Dmg | Mag + reserve at insert / re-armed | Reload | Hip / ADS | Bloom per shot / max | Range | Pierce |
|---|---|---|---|---|---|---|---|---|---|
| **M16A4 Service Rifle** (baseline) | all-rounder, 3-5 round bursts | auto, 750 (0.08) | 20 | 30 + 120 / 240 | 2.2 | 1.5 / 0.3 | 0.3 / 3.5 | 400 | 0 |
| **MP5 SMG** | best hip-fire; chews Runners, weak on Brutes | auto, 800 (0.075) | 14 | 30 + 120 / 210 | 1.8 | 0.9 / 0.6 | 0.15 / 2.0 | 150 | 0 |
| **M249 LMG** | 100-round belt, no reload in a hold; slow to aim moving | auto, 800 (0.075) | 20 | 100 + 150 / 300 | 5.5 | 3.0 / 0.5 | 0.15 / 2.5 | 400 | 0 |
| **Mossberg 590 Shotgun** | point-blank, one decision per pull | pump, 80 (0.75) | 11 x 8 pellets | 8 + 20 / 40 | 3.5 | 5.0 / 3.5 | 0 | 45 | 0 |
| **M110 DMR** | one-taps Walkers, hits two in a line; poor up close | semi, 300 (0.2) | 60 | 20 + 40 / 80 | 2.6 | 4.0 / 0.1 | 1.2 / 3.0 (recovery 8) | 600 | 1 |
| **M17 Pistol** (sidearm) | backup when the primary runs dry | semi, 400 (0.15) | 25 | 17 + 34 / 68 | 1.5 | 1.2 / 0.5 | 0.6 / 2.5 | 120 | 0 |
| **S&W 686 Revolver** (sidearm, sample) | panic button: one round per Walker, staggers a Brute | semi, 150 (0.4) | 55 | 6 + 18 / 30 | 2.8 | 1.8 / 0.4 | 1.5 / 3.5 (recovery 10) | 150 | 0 |
| **M2010 ESR Sniper** (sample) | one round per kill, Brute in 2, through four in a line; useless from the hip | bolt, 48 (1.25) | 140 | 5 + 15 / 30 | 3.2 | 6.0 / 0.05 | 0 | 800 | 3 |
| **Goose, M3 recoilless** (sample "RPG", primary slot; later the call-in) | a visible rocket at 220 studs/s: 400 to the Infected struck, then the frag's blast 120 in 6 studs, no friendly fire | single, reload 6 s | 400 + blast | 1 + 1 / 1 | 6.0 | 2.0 / 0.25 | 0 | 300 | 0 |

- ADS move factor: rifle 0.6, SMG 0.85, LMG 0.35, shotgun 0.7, DMR 0.5, pistol 0.9. ADS
  pulls the camera to 5 studs over the shoulder at FOV 55 (`Weapon.ADS`); in first person each
  gun aims through its own sights at its own zoom, the M2010 (6x), M110 (3.5x) and Goose (3x)
  through a scope picture (`Weapons.<id>.Sight`; docs/STYLES.md > First person); the client sends
  an `aiming` flag with each shot and the server picks the cone.
- Headshot x3.0 (per gun, `HeadshotMultiplier`); the Brute overrides to 1.25 (plated skull).
  Tracers are client-drawn.
- Rounds to kill body / head: rifle Walker 3 / 1, Brute 13 / 11; SMG 4 / 2, 19 / 15; DMR
  1 / 1, 5 / 4; shotgun one pull for every form but the Brute (3). Ammo reins in the DMR
  (100 x 60 is the M16's 270 x 20).
- A soldier lands with about half the reserve (`ReserveStart` on the gun's row,
  2026-11-10; was the full `ReserveMax`), so the first pallet is wanted; a pallet or the
  Index kill fills it to `ReserveMax`. The Goose keeps its one spare round.
- Bots fire the rifle slower (`Bots.FireCooldown` 0.30: three bots on sustained fire ~ one
  player), same magazine, infinite reserve.
- Bots walk (2026-11-11): straight to the formation slot when it is close and in sight, else
  along a path, sprinting when far. They teleport only when far from the leader and stalled
  (or out of the world), to a spot no living player faces. Rules in `Rules/BotBrain`,
  numbers in `Config.Bots`.
- Bots use a soldier's kit through the players' server paths (no kill credit): a stim at
  40% health; a frag (3 carried) at 4+ Infected with no squad member near the blast; one
  fire mission each (Hammer, Anvil, Hammer by slot) at 8+ Infected or a Brute / boss, 180 s
  per bot, 45 s between any two, announced on the radio subtitle. A Restock card taken by
  any player refills their frags and stims; an Aid Bag refills a treated bot's stims.
- Bots in a boss fight (`Config.Bots.Boss`, switch `Enabled`): while the boss is within 60
  studs of the leader they leave formation for posts 32 studs from the boss, 40 degrees
  apart on the leader's side, and back off as he comes; they run 5 studs clear of a
  telegraphed disc or line, step out of caustic puddles, stim at 60% health, and revive only
  when the boss is 26+ studs from the downed body.
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
- The lobby (`nova/lobby`, docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): the
  Loadmaster hosts the same menu as the **Loadout** (owner's name, 2026-11-09; `mount` options
  title / hint / confirm), `LoadmasterService` validates with the same Rules module, keeps
  each soldier's Loadout in a DataStore (a stand-in for F9) and passes it in teleport data.

### Call-ins

`CallInDefinitions`, numbers in `Config.CallIns`; no friendly fire. Four slots, keys 1-4;
each holds charges that refill one at a time. The helicopter crew kicks support weapons and supply
out of the door; fire missions are someone on the net. HUD names and radio: [LORE.md](LORE.md)
> The Arms Room. Call-ins must be things a real army fields (OWNER.md).

| Kind | Name (designation) | What it does | Charges / cooldown | Built |
|---|---|---|---|---|
| Support | **Gun** (M240B) | 40 dmg, 650 rpm, pierce 1, 100 + 100 belt, 7 s reload, ADS move 0.3; takes the long-gun slot until empty, downed (drops at the body) or replaced | 1 / 240 | no |
| Support | **Goose** (M3 recoilless) | 2 single shots; 400 direct, 120 in 6 studs | 1 / 120 | no |
| Support | **Thumper** (M32) | 6-round drum, 0.5 s apart, 70 in 7 studs, 24 rounds | 1 / 180 | no |
| Support | **Kettle** (M9 projector) | 15-stud cone, 10 per 0.1 s, fire pools, 20 s of fuel | 1 / 180 | no |
| Fire mission | **Hammer** (81 mm mortar) | 6 shells 1 s apart, 80 in 12 studs, scatter 4 | 1 / 120 | yes |
| Fire mission | **Anvil** (105 mm battery) | marked through binoculars on any ground in the line of sight, up to 400 studs; one shell 5 s later, 500 in 20 studs, shake felt map-wide | 1 / 180 | yes |
| Fire mission | **Shrike** (helicopter gun run) | 10 bursts stepping 4 studs along the throw, 120 in 5 studs each, 4 s delay | 1 / 150 | yes |
| Emplacement | **Doorman** (tripod sentry MG) | 45 s, 20 dmg every 0.15 s, range 70, one per player | 1 / 150 | yes |
| Emplacement | **Tripline** (AP mines) | 6 mines on an arc, 80 in 10 studs, 90 s, 12 per player | 2 / 60 | yes |
| Emplacement | **Concertina** (wire) | 16 x 3 strip for 60 s: 0.4x slow, 5 dps; never vaultable | 2 / 90 | yes |
| Supply | **Speedball** (ammo bundle) | 4 re-arms (a player again only after stepping out), no lure wave | 1 / 180 | yes |
| Supply | **Aid Bag** (medical drop) | every soldier within 6 studs: full heal, stims refilled, +25 plate; once each | 1 / 180 | yes |

Every built call-in is thrown (`Kind "throw"`, `ThrowUtil` clamp) except the Anvil, which is
marked through binoculars (below). Services:
`AirStrikeService` (Hammer, Anvil share `fireMission`, patterns from `Rules/StrikePattern`;
Shrike's `gunRun` under a Part gunship at 45 studs), `SentryService` (Doorman: a ray from the
gun's pivot to the nearest visible Infected; its body is `Config.CallIns.Doorman.Model`, 2 =
the modelled gun whose pivot is 2.6 up, 1 = the Part tripod at 3.2), `MineService` (Tripline), `ConcertinaService`,
`SupplyDropService` (Speedball, Aid Bag land quiet). The support weapons
need the support-weapon carry and the explosive projectile hook (ARCHITECTURE F7). Dev:
`SetCallIn <slot> <id>`, `FireCallIn <id>` (20 studs ahead, no slot or charge).
Retired 2026-11-08: Magpie (drones) and Pen Coil (shock pulse), too sci-fi; see HISTORY.md.

### Binoculars

Owner: "the anvil should be like binoculars and can be called anywhere within your line of
sight". A call-in whose row says `AimMode = "Binoculars"` (default `"Throw"`; only the Anvil
today) is not thrown.

- **Use:** the slot key raises the binoculars (0.4 s): the eye goes to the head, the view
  narrows to 16 degrees behind a black mask with a reticle, the gun is put away. A ring on the
  ground (the blast) and a post show where the round will land: the first surface under the
  crosshair, or the foot of a wall or a body. The readout gives the range in metres and
  MARK SET, OUT OF RANGE, NO LINE OF SIGHT or NO GROUND. Left click (gamepad R2) fires the
  mission; right click (gamepad B), the slot key again or any other kit key lowers them.
  Then the Anvil's own delay and arrival run on the mark; nothing is thrown (its
  `Arrival.Throw` is 0).
- **Server:** the client says when they go up and come down (`CallInSpot`) and sends the
  mark over `CallIn`. `CallInService` takes it only from binoculars that have been up for the
  raise, and measures it again from the soldier's own head (`SpotUtil`, `Rules/Spotting`):
  within `MaxRange`, on ground, nothing but the Infected and the squad in the way, with a few
  studs of slack. A refused mark spends no charge. There is no minimum range (`MinRange` 0:
  no friendly fire today).
- **What the squad sees:** the body carries the `Spotting` attribute while they are up;
  every client's `BinocularPose` raises its arms and a pair of binoculars to its eyes and
  hides its gun. **Placeholder:** the arms are posed in code over the playing clip and the
  binoculars are Parts; a real raise / hold / lower clip and a modelled prop are still to make.
- **Values:** `Config.CallIns.Binoculars` (range, view, raise and lower times, the server's
  slack, the pose angles, the keys), overridden by a row's own `Binoculars` block (the Anvil:
  `MaxRange = 400`).
- **Bots** carry no call-ins yet; `CallInService.spotFor(character, id, point)` is their way
  in (raise, check from the head, fire; no view).

### Call-in arrivals

Owner: "Hammer and Anvil look like the same thing". Each call-in now comes in its own way
between the throw and the effect: its own shape on the ground, its own timing, colour and
sound. All of them start the same: the thrown marker (or the kit itself) flies the aim arc
for 0.45 s and lands (not the Anvil: it is marked through binoculars, so its ring and smoke
start on the mark at once).

| Call-in | Style | On the ground | In the air | Sound | When it lands |
|---|---|---|---|---|---|
| **Hammer** | `mortar` | red smoke; a small diamond where each round will fall, bright in its last second | a thin round dropping near straight down (84 degrees), seen 0.3 s | tubes thump far behind the thrower 2.4 s ahead of each round; a short high whistle | quick pale-yellow flash, low pale dust, a sharp crack |
| **Anvil** | `shell` | dark red smoke; one dashed ring that starts 2.2 blast radii out and closes on the blast's edge, pulsing faster | one heavy round on a flatter line (60 degrees) from behind the spotter with a smoke trail, seen 0.7 s | a long low falling whistle from 1.5 s out | slow deep-orange flash, a 34-stud column of dark earth, 4 s of smoke, burnt ground for 10 s, a deeper boom |
| **Shrike** | `gunrun` | orange smoke; a ladder of rungs across the lane, lit one after another the way the gunship flies, each gone as the bursts pass | the gunship (server) and a rake of extra tracers from its gun | the cannon from the air, every second burst | dust spurts walking the lane |
| **Doorman** | `case` | blue smoke | an olive case under a cross-shaped cargo chute, swaying, 1.5 s | a thud, then a clank | the chute folds beside it; the gun stands at 2.2 s |
| **Tripline** | `scatter` | no smoke (nothing comes from the air) | six charges hop out of the satchel to their places | the arming click | a blink at each mine as it arms, 0.95 s |
| **Concertina** | `unroll` | no smoke | the coil splits into two drums that roll out to the ends paying out a strand, with dust | three rattles | the wire stands at 1.05 s |
| **Speedball** | `tumble` | yellow smoke | the bundle tumbles down from 50 studs with no chute in 0.75 s | the landing thump | one bounce, dust, ready at 1.5 s |
| **Aid Bag** | `streamer` | pink smoke | the bag comes down steadily from 38 studs under a 9-stud red and white streamer | the landing thump | the streamer falls across the ground; ready at 1.8 s |

- **Where the values live:** each call-in's row has an `Arrival` block (`Style` plus any
  value it changes) over `Config.CallIns.Arrivals.Defaults`; `Rules/Arrival` merges them and
  holds the curves (the fall, the drift, the hop, the round's line, the gunship's pass). A row
  without one arrives as a plain thrown marker. No system lists call-in names.
- **Who does what:** `CallInService` tells every client once per throw (remote
  `CallInArrival`: id, thrower, point, direction, and a fire mission's impact points) and
  holds an emplacement or a bundle back for its `Arrival.Time`; `CallInArrivalFX` (client)
  draws the rest from Parts, Beams, Trails and particle bursts, on the same clock (it holds
  while paused). Damage, the blast flash that shakes the camera, the blast sound (its clip,
  pitch and flash colour from the row) and the gunship stay on the server.
- **Timing that changed:** Doorman works 2.2 s after the throw, Tripline 0.95 s, Concertina
  1.05 s (all three were instant); Speedball 1.5 s and Aid Bag 1.8 s (were 0.9 s). Fire
  missions keep their `Delay`.
- **Budget:** at most 8 arrivals drawn at once per client (`MaxActive`); the biggest (Anvil)
  is 22 Parts; smoke and dust are bursts of 2 to 20 particles, no lights.
- **Switch:** `Config.CallIns.Arrivals.Enabled = false` puts back the flat red discs, the
  stock blast, the one shared whistle and the instant kit.
- **Needs an in-game look (none of it has been seen running):** `handoff/log/2026-11-10-tien-callin-arrivals.md`.

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
- Three cards, the same for everyone (`Crates.SupplyCards`; what each gives is its row in
  `Crates.Cards`, and the card text is built from the row): **Medkit** (full heal, stims
  back), **Restock** (every call-in slot full, grenades and stims too), **Armour Plate** (+75
  armour soaked before health, cap 100; was 50, which a full heal always beat). One pick
  per player per pallet; the pallet closes at 90 s. No rarity, no upgrades from pallets.
- **Taking a card** (owner 2026-11-11: never by walking over it; `Requisition.Pick`,
  `Rules/Reward`, `RewardPanel`): every crate has a label and, when it is worth a walk, a
  light pillar. Within 9 studs hold **E** 0.3 s (gamepad X, tap on touch) and
  a panel of up to three big cards opens at screen centre: key, kind, icon, name, one plain
  line with its numbers, and "REPLACES ..." when a field upgrade would push one out. Pick
  with a click or tap, keys 1-3, or the gamepad; the card flashes, a line under the mission
  line names what was taken and the squad gets "<callsign> took <card>". E again, Backspace,
  gamepad B, a click beside the cards or walking 12 studs off closes it without a pick, and
  the crate can be opened again. The game does not pause and the player can be hit. The
  server checks the crate, the offer, one pick per player, reach and "not down". The panel
  and the crate's label show who has taken theirs. `Pick.WalkOver = true` restores the old
  world cards.
- **Bots** take no panel: one within 14 studs of a pallet takes the supply card covering
  what it misses most (today that is health: a Medkit below 75%), once per pallet.
- Playtest targets per drop: 5-7 drops per 12 min solo, picks within 20 s, at most one death
  per three drops, consecutive drops 60+ studs apart, pool minus cost at throw not always ~0
  (else there is no "when" decision). Fixes if missed: an overflow bonus (throw at 1.5x cost
  for a fourth card); or `Wave 14`, `LureRadius 160` if drops camp a corner.
- Pallets must keep landing through the Index fight.

### Field upgrades

`UpgradeDefinitions`, flags on `LoadoutService`, numbers in `Config.Upgrades`. Slots: Grenade,
Weapon, Kit and one per carried call-in (`CallIn1`-`CallIn4`; the upgrade moves with its
call-in); a new pick in a filled slot replaces it. Each changes how a tool works, never a
percentage, and must stay legible next to the flat curve. Sources: the Primary's two site crates
(a FIELD UPGRADE crate when the hold zone appears; the **OBJECTIVE REWARD** crate when the
hold ends, `Objective.CompleteCrate`, 10 studs beside the first), so both picks are made
before the Index arrives; later Stores and Secondary crates (3-5 per mission). Each offers
3 the player does not hold, ones for an empty slot before ones that would replace a pick
(`Rules/Reward.upgradeOffer`); a short offer is filled with supply cards. Until 2026-11-10
the second set came on the Index pallet, with only the extraction left to use it.

**The Main objective's reward** (2026-11-11; `Crates.Kinds.objective`): as the crate lands
every living soldier is restocked without picking anything (`Squad`: full health, ammo,
every call-in charge, grenades, stims, +50 armour), then each player picks one field
upgrade from it (open for 180 s). The 500 into the Resupply pool is unchanged. Crate kinds
(label, life, pillar, squad share) are rows in `Crates.Kinds`; `RequisitionService.dropCrate`
takes the kind.

| Slot | Lore name | Effect |
|---|---|---|
| Grenade | Bait Charge | a frag lures the Infected inside 18 studs for 3 s before it goes |
| Weapon | Through-and-Through | a round carries into the next Infected (any gun) |
| Weapon | Hollow Point | the hit Infected stops for 0.6 s (any gun) |
| Kit | Last Stand | fire from the ground while downed (hip, spread x2) |
| Kit | Spare Tourniquet | stand up on your own 4 s after going down, once per mission (as the two revives are: `Squad.resetMission`), no revive spent |
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
  quiet pallet at the corpse: re-arm, full heal, the three supply cards
  (`Index.Warden.Drop.Cards`; `"upgrade"` puts the field upgrades back there).

## Operation: the Burn, extraction, scoring (not built)

- **The Burn** (mission timer, 840 s for 1-4 players; more players split objectives, time is
  the one resource more-not-tougher does not hand out). Only the Burn counts down on the HUD;
  run time stays a plain readout. At 0:00 the incendiaries land: burning dressing, no more
  pallets, spawn interval x0.5, more alive and +2 Brute/Hocker caps (`Config.Overrun`,
  reserved), the helicopter takes 120 s instead of 90. The run goes on; extracting after the Burn
  scores Partial. Calling the bird freezes the timer.
- **Extraction today** (`Config.Extraction`, 2026-11-10): a 60 s hold (was 30). On the
  call Walker 12, Runner 4, Brute 1 round the pad and spawn interval x0.8; when the hold
  reaches 30 s a second wave of 12 phase-weighted Infected (+3 per extra player) rings the
  pad, Control calls it on the radio and the spawn interval goes to x0.6 (`Waves` rows:
  `At`, `Count`, `PerExtraPlayer`, `SpawnFactor`; `Rules/ExtractionWaves`). A wave is tied
  to the hold's progress, so it never lands while the squad is off the pad.
- **Extraction, designed.** A 90 s hold; on call Walker 10 Runner 4 (+3 Walkers per extra player), a
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

## Objective pools (first slice built on Delta, 2026-11-11)

Each drop draws one **main objective** and two **side objectives** from the map's own pool
(`ObjectiveService`; rows, pools and sites in `src/shared/ObjectiveDefinitions.luau`, read as
`Config.Objectives.Rows` / `.Maps`; one module per objective in `src/server/Objectives/`).

- **Two kinds.** A **shared** objective can appear on any map that lists it and gives it
  sites. A **signature** objective belongs to one map, is built round that map's landmarks and
  story, and is never offered elsewhere. Every map has at least one signature main objective.
- **Adding** an objective is a row plus its module; adding a map is one pool row (`Main` and
  `Side` with weights, `Sites` per objective). Nothing else lists objectives.
  `tests/ObjectiveDefinitions.spec.luau` fails CI when a pool names a missing objective, a map
  has no signature main objective, or a listed objective lacks a site or a site field it needs.
- **Known before the drop, found on the ground.** The main objective is drawn at insert (never
  the same twice in a row on a server; the lobby may name one in the launch data, `objective`
  in `Rules/Handoff`) and shown on a card with its reason and place. The squad starts it by
  reaching it. A side objective shows only when a squad member comes within
  `RevealRadius` (80) of it or Control calls it out (`RevealAfter` 90 s, the second at 180 s).
- **Each has a reason** the player reads: `Brief` (Control at insert or on finding it), `Why`
  (on the HUD the whole time, 8 words at most), `Done` (Control, what changed). The reward is
  the consequence. Plain words only (OWNER.md).
- **The frame**, once at insert: "Clear this checkpoint so the helicopter can land and we can
  hold the district." Finishing the main objective pays 500 Resupply, drops the field-upgrade
  crate and wakes the Warden: "That woke the Gate sergeant. He still guards this post. The
  Warden is coming up the road." Side objectives are optional; failing one costs nothing.
- **Bots** follow their leader as always, so they stand in a hold with them and shoot marked
  Infected; they never press E and never carry.
- Dev: `SetMainObjective <id> [site]`, `SetSideObjective <id> [site]`, `RedrawObjectives`,
  `ListObjectives` (docs/STUDIO_MCP.md).

### Shared

| Id | Role | Rule | Reward beyond the main objective's |
|---|---|---|---|
| `secure_site` Secure the Site | main | 45 s accumulated in the zone | |
| `restore_comms` Restore Comms | main | hold E 10 s on the radio set (letting go starts over), then 60 s accumulated within 20 studs; a wave with 2 Hockers when it comes on | |
| `confirm_casualties` Confirm Casualties | main | kill 3 outlined heavy Infected (+1 per extra player) that stand at the site when the squad arrives | |
| `recover_record` Recover the Record | main | hold E to pick up, carry to the drop point; the carrier cannot sprint; dropped when downed; players only | |
| `lights_on` Lights On | side | hold E 8 s at a generator | the 5 nearest lamp posts light; 300 Resupply |
| `misdrop` Misdrop | side | reach the pallet within 4 min of learning of it | the pallet: a supply crate |
| `clear_spitters` Clear the Spitters | side | kill 3 outlined Hockers (+1 per extra player) within 2 min of reaching them | 600 Resupply |
| Light the Pad, Sample Run, Headcount, Recover Logs | side | designed, not built: hold E at a marked pad (extraction can be called there); bag a marked heavy and carry it to the LZ; visit the story spots; pick up a recorder | |

### Checkpoint Delta (sites: LEVELS.md A5, A7)

| Objective | Kind | Where | State |
|---|---|---|---|
| Sanitize the Pens (`sanitize`) | signature main | the three screening tents at the Pens: hold E 3 s at each fuel can, any order; each fire flushes 4 Runners and 3 Walkers | built |
| Open the Gate | signature main | break the 3 locks on the Gate, then reach the point beyond; the Warden walks in through it | designed, not built (needs shootable props) |
| Secure the Site | shared main | the Screening Compound, the Pens, the Overlook | built |
| Restore Comms | shared main | the comm tower (Compound upper tier) | built |
| Confirm Casualties | shared main | Brutes at the Depot's aisle ends | built |
| Recover the Record | shared main | the Ridge to the comm tower | built |
| Silence the Alarm (`silence_alarm`) | signature side | the Gate siren: hold E 4 s on its switch; roaming spawns within 140 studs happen 40% as often; 150 Resupply | built |
| Sealed Bus | signature side | Bus 7 on the Gate bus line: hold E, a Runner burst, kill all | designed, not built |
| Lights On | shared side | the Depot generator | built |
| Misdrop | shared side | the Suburb, the Barracks, the Depot mound | built |
| Clear the Spitters | shared side | the highway west of the pad, the bus line | built |

Never on Delta: Evacuate ("CLEARED 0").

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

### The words (built objectives; source: `ObjectiveDefinitions`)

`{place}` is the drawn site, `{to}` where a carried item goes.

| Objective | Brief (Control) | Why (HUD) | Done (Control) |
|---|---|---|---|
| Secure the Site | We lost the perimeter at {place}. Take it back and hold it so the helicopter can land. | Control needs the perimeter back to land | Perimeter is ours again. The helicopter has a way in. |
| Sanitize the Pens | The checkpoint's screening tents at the Pens are full of people who never got cleared. They will get up. Burn all three before the airstrike. | Bodies in the screening tents will get up | The tents are burning. Nobody in the Pens is getting back up. |
| Restore Comms | We are blind past the Gate and can't call the helicopter in. Get the radio mast at {place} working, then hold it. | No mast, no way to call the helicopter | Signal is back. We can see past the Gate and call the helicopter. |
| Confirm Casualties | Heavy Infected are massing in {place}. Left alone they overrun the landing pad. Put them down. | The heavies will overrun the landing pad | The heavies are down. The landing pad is safe from that side. |
| Recover the Record | The checkpoint's screening record is at {place}. We need to know who got through. Carry it to {to}. | Control must know who got through the checkpoint | Record sent. Now we know who got through before it fell. |
| Silence the Alarm | The Gate siren has been running since the checkpoint fell, and it is drawing every Infected in the district. Shut it off. | The Gate siren is drawing Infected to you | Siren is off. Fewer of them will come to the Gate now. |
| Lights On | You are fighting blind and the helicopter needs light to find you. The generator at {place} still works. Start it. | The helicopter needs light to find you | Lights are on. The helicopter can see you, so supplies come sooner. |
| Misdrop | The helicopter put a supply pallet down in the wrong place: {place}. Get to it before the Infected swarm it. | Your supplies landed in the wrong place | Pallet is yours. Take what you need. (Late: "Too late. The Infected swarmed the pallet. It is gone.") |
| Clear the Spitters | Spitters at {place} are shelling the landing pad, so the helicopter can't drop supplies. Kill them fast. | Spitters are shelling the helicopter's landing pad | Spitters are down. The supply drop we were holding is yours. (Late: "Out of time. The Spitters dug in. No supply drop.") |

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
- **Objectives:** Objective pools > Checkpoint Delta.
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
- **Plates** (one rule): helmet 300, chest 400 (was 500 until 2026-11-10), back 400 (the flank), shoulders 300 each,
  shield 600. A round into a plate does 25% to the plate and nothing to the body; a round into
  a limb whose plate is gone does 150%. At half a plate cracks (yellow pip); at zero it flies
  off, he staggers 1.5 s. HUD order: HELM, CHEST, BACK, L SHLD, R SHLD, SHIELD.
- **Attacks**, each announced by his words ("WARDEN: ...") on the boss bar. Where you stand picks
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
type; `EnemyProjectileService` owns lobs and puddles and makes no parts: clients draw the
spit, docs/STYLES.md §8). Still to add as forms need them:
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
