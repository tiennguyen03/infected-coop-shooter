# PROGRESSION.md — the run: loadout, Resupply, missions, bosses, the Infected

Design doc for the run loop: Helldivers 2 structure (owner, 2026-11-06), our own names and
numbers. Canon and naming: [LORE.md](LORE.md). Tuning: `src/shared/Config.luau`. Map layout
(positions, pads, stores, sites): [LEVELS.md](LEVELS.md). What shipped: [HISTORY.md](HISTORY.md).
Pillars: [PLAN.md](PLAN.md). Co-op rules: [MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md).
Owner rules: [OWNER.md](OWNER.md). Designed but not built (the Burn, scoring, the old
build order, Mile 14, Kestrel): [LATER.md](LATER.md).

Names: one map is a **mission**; three missions are an **operation**. Code identifiers
(`Stage*`, `Operation*`) keep their names.

**Contents** (read only the section you need): [The loop](#the-loop) ·
[Attachments](#attachments) · [Kit Mods](#kit-mods) · [The soldier](#the-soldier) ·
[Downed and revive](#downed-and-revive) · [Reinforcements](#reinforcements-and-ammo-pouches) ·
[Guns](#guns) · [The Arms Room](#the-arms-room-loadout-menu-key-b) · [Call-ins](#call-ins) ·
[Binoculars](#binoculars) · [Call-in arrivals](#call-in-arrivals) ·
[The ATV](#the-atv-vehicle-call-in) · [Pallets](#pallets-resupply) ·
[Field upgrades](#field-upgrades) · [Threat curve](#threat-curve) · [Breaches](#breaches) ·
[Extraction](#extraction) · [Containment Board](#the-containment-board-bands-in-code-the-shared-board-not-built) · [Objective pools](#objective-pools) ·
[The Warden in the objective](#the-warden-in-the-main-objective) · [Missions](#missions) ·
[Awareness](#awareness-the-quiet-missions) · [Bosses](#index-hosts-bosses) ·
[The Warden](#the-warden) · [The Infected roster](#the-infected-roster) ·
[Moves](#moves) · [Hit feedback](#hit-feedback-on-the-infected)

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

Power is the loadout, never in-run stat growth: Helldivers 2, plus one Hades-style twist
(field upgrades). Retired for good: XP, levels, orbs, stat items and rarity, classes, Q dash,
E breach, Combat Momentum.

### Attachments

Fitted at the Loadmaster (EDIT on a gun, `GunsmithUI`), kept per gun, signed
and flown to the match with the Loadout (`Loadout.attachments`, `Attributes.Fitted` on the
player). One slot so far, the **Barrel**, and one option, the **suppressor**
(`Config.Attachments`; a gun takes one when its `Config.Weapons` row has `Suppressor`: every gun
but the revolver and the Goose). With it fitted a shot carries the row's `Suppressor.Noise`
instead of its `Noise` (pistol 12, MP5 15, M16 25, M110 30, M249 35, Mossberg 40, M2010 45: the
Infected hear it only close in, [Awareness](#awareness-the-quiet-missions)); the shot plays at
0.3 volume with no muzzle flash, and a dark cylinder sits on the muzzle (the shot leaves from its
end) in third and first person. No damage or range cost yet.

**Optic** (the M16A4 only, other guns next): the second slot. Three optics,
one row each in `Config.Optics` (typed records in `Shared.Attachments.Optics`; a new optic
appears by having a row that lists its guns). Numbers from the systems designer: the named
magnification is the final zoom on the M16's 1.35 irons, and each costs less than the gun it
competes with.

| Optic | Zoom | Into the sights | Merits |
|---|---|---|---|
| Red dot (the RMR) | x1.0 (1.35, the irons' picture) | x0.75 (0.11 s) | 150 |
| CompM2 (M68) | x1.5 (2.0) | x1.0 (0.15 s) | 250 |
| ACOG 4x | x3.0 (4.05) | x1.6 (0.24 s) | 400 |

Bought once with merits at the EDIT screen and kept for good: it goes on the soldier's record
like bought kit (`Rules/Record.owned`, the same UpdateAsync save as the Quartermaster's guns;
never tabs or Robux). The rules (buy, fit, the three states, the unlock count) are
`Rules/AttachmentRules` (spec first); the server is the lobby's `OpticService` on the `Optic`
remote, and the Loadmaster refuses to sign an optic not on the record or on a gun it does not
fit (`RecordService.allows`). On the gun, `Rules/AttachmentMerge` multiplies the gun's zoom and
its time into the sights (`CameraController`; in third person the shared ADS view narrows by
the optic's share). The CompM2 is a real 1x sight; 2x here is the owner's call (its multiplier
is 1.48 so the zoom stays at the 2x limit for a sight that is not a scope).

On the gun: each optic is the free model (`assets/3d/ASSET_IDS.md` > Optics) on
the M16's rail, one mesh per rifle and optic (`wpn_m16_acog`, `wpn_m16_compm2`,
`wpn_m16_reddot`, `assets/3d/build/optics.py`): the rifle without its flip-up backup sight, the
optic's mount on the rail, the glass left open. The red dot sits on a riser so its dot is 0.1 studs
above the irons' line (2026-11-20, a lower-third co-witness: the front post sits low in the
glass, under the dot; `optics.py` `REDDOT_LIFT`); the CompM2 and the ACOG ride a little
higher. Each row's `Fit` names that mesh and its sight on it; `WeaponDefinitions.dressed`
gives the gun in hand (`PlayerSetup`), the first-person sight line and zoom
(`CameraController`, `FirstPersonView`) and the EDIT screen's gun (`Showcase` "<gun>+<optic>").
The ACOG is a scope: aimed in first person it shows the scope picture, as the M110 does.
The red dot and the CompM2 show their dot (2026-11-20): aimed in first person, `DotSightView`
draws it at the screen's centre (the optic's axis, so no parallax), fading in over the last 30%
of the raise; its size, halo and colour are the optic's own `Reticle` row (no row, no dot).

**Attachment system v2** (Nova, 2026-11-20; the M16A4 is the reference gun, one PR per gun
after it). Up to seven slots per gun, each a row in `Config.AttachmentsV2.Slots`
(`Shared.Attachments.Schema`): Optic, Barrel, Muzzle, Magazine, Ammo type, Underbarrel, Stock.
A gun takes the slots of its row's `Family` ("rifle") and, in each, the options that list it.
Every option is a row (`Config.AttachmentsV2.Options`, `Shared.Attachments.Options`; the
optics stay `Config.Optics` rows), every ammo type a row (`Config.AttachmentsV2.Ammo`,
`Shared.Attachments.AmmoTypes`). Unlocked once with merits at the EDIT screen and kept on the
record (`Rules/AttachmentUnlock`, spec first; Price 0 = the issued part, always owned); never
tabs or Robux.

| Slot | M16A4 options (merits) |
|---|---|
| Optic | iron sights; Red dot 150, CompM2 250, ACOG 400 (above) |
| Barrel | Standard; Long 150 (+15% range, +10% recoil, -5% move); Short 150 (-15% range, -10% recoil, +5% move); Suppressed (free, as before: quiet, -20% range, -10% damage, no muzzle device) |
| Muzzle | Flash hider; Compensator 120 (-15% recoil, +5% alert); Muzzle brake 200 (-25% recoil, +10% alert) |
| Magazine | Standard 30; Extended 40, 150 (+20% reload); Drum 60, 300 (+50% reload, -10% move; not with the collapsed stock) |
| Ammo type | FMJ (20, x3 head); AP 200 (16, 80% armour pen); HP 200 (28, x4 head, no pen); Tracer 100 (20, +20% alert) |
| Underbarrel | none; Vertical grip 100 (+20% recoil recovery); Angled grip 100 (-10% ADS time); Laser 150 (-30% hip spread) |
| Stock | Standard; Adjustable 120 (+15% recovery, +10% ADS time); Collapsed 120 (-10% recovery, -15% ADS time) |

**The merge** (`Rules/AttachmentMerge.merge`, spec first): each option's deltas name a stat
and an op; multipliers on a stat multiply together and scale the gun's own value, additions
add after (`value x multipliers + additions`). The ammo type REPLACES the damage profile
(damage, rounds per shot, headshot, armour penetration, behaviour) and scales range and alert,
then the attachments apply on top of the new round (so the suppressed barrel's -10% bites on
HP too). Armour penetration is the share of a plate's cut ignored: the Brute's front
(`DamageService`) and the Warden's plates (`ProjectileServer.hitMultiplier`). A clash (the
suppressed barrel with a muzzle device, the drum with the collapsed stock, ammo of another
caliber, an option for another gun) is refused on the server and its reason shown.
`WeaponDefinitions.fitted` builds the carried gun's stats from the fitting: the match server
fires, reloads and makes noise with them; the client reads them only for its camera (ADS time,
kick) and walk. Saved with the signed Loadout (`Loadout.attachments[gun][slot]`, the ammo in
its slot), the same save as before. Stats only: the gun's model shows the optic and the
suppressor as before, nothing else yet (the tracer's beam and the laser's dot too).

### Kit Mods

Allowed by the owner 2026-11-18 (an exception to "never stat items"). A Kit Mod
is a passive buff on the soldier whatever gun they carry, bought rank by rank with merits
(never tabs) at the Loadmaster's KIT MODS tab and kept for good. The line with attachments:
if a bonus changes how one gun behaves, it is an attachment; if it is on the soldier whatever
the gun, it is a Kit Mod. Field upgrades stay per-mission picks.

| Mod (`Config.KitMods`) | Per rank (max 3) | Rank 1 / 2 / 3 (merits) | State |
|---|---|---|---|
| Extra stim (`stim_carry`) | +1 stim carried (`Config.Stim.Carried` 2 → up to 5) | 200 / 400 / 750 | working |
| Extra roll (`sprint_roll`) | +1 roll from a full bar: `Stamina.Max` + `RollCost` (100 → up to 160; ~1.7 s more sprint a rank) | 150 / 300 / 500 | working |
| Quicker call-ins (`callin_cooldown`) | -8 s call-in cooldown (the designer suggests ~5% a rank instead) | 250 / 500 / 850 | greyed, not wired |
| Faster revives (`revive_speed`) | +15% revive speed | 150 / 300 / 500 | greyed, not wired |

Prices from the systems designer (about 1 : 2 : 3.5 a rank; a full mod is 8-13 wins). One row
per mod; `Shared.KitMods` builds the typed records, and a service asks
`KitMods.bonusFor(player, effect)` for the effect it owns. Rules: `Rules/KitModRules` (spec
first): only the next rank, never past the cap, never a disabled mod, never short. Each rank
bought is an id on the merit record (`<mod>@<rank>`), bought in one UpdateAsync step with its
merits (lobby `KitModService` through `RecordService.change`, the Quartermaster's save path).
The match reads the ranks off the record on join (`src/server/KitModService`,
`MeritService.readRecord`) into the `KitRanks` attribute: `LoadoutService` carries the extra
stims (refills fill to the new count; the HUD shows it), `SprintController` grows the bar.
Bots have none. Dev: `SetKitRanks "stim_carry=2;sprint_roll=1"` (DevCommand).

### The soldier

Every player is a Pike soldier; no classes, no hero kit. A soldier carries a primary, the M17
sidearm, a grenade type and four call-ins (keys 1-4), picked in the **Arms Room** (B).
Q swaps long gun and sidearm (`Weapon.SwapTime` 0.5 s; no shot, no reload; a reload in
progress is dropped; each gun keeps its own magazine). G throws a grenade (3 carried; a
pallet refills). F shoves (15 dmg, 0.8 s stagger, 6-stud push, 1 s cooldown). V uses a stim
(2 carried, heals 60 over 1 s; Medkit refills). X throws the Resupply flare (always carried).
E is interact (hold it beside a downed squadmate to revive). C or LeftControl crouches, Z goes
prone, Shift sprints, Space vaults and climbs, T switches first and third person. Every key
is a row of `Config.Keys` and every hint reads it (the table: [OWNER.md](OWNER.md) > Rules
already decided).

**Stamina** (`Config.Stamina`, `Rules/Stamina`, client-owned like sprint):
100, sprinting drains 12/s (~8 s from full), back at 22/s after 1 s without spending (empty to
full ~5.5 s). A roll costs 20, a slide 10 (any stamina left is enough; it floors at zero);
vault, climb and shove are free. At zero the soldier is **winded**: no sprint, roll or slide
until 25 (~2.1 s), then a held Shift sprints again. Downed or knocked down nothing drains; a
respawn or a new run refills it. Bots have none.

**Keys:** Shift twice rolls; holding C or Ctrl while sprinting slides until the key is let go.
**Slides keep momentum** (`Config.Movement.Slide`, `Rules/Slide`): a slide
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

**Aiming throws:** G and every thrown call-in (CallInDefinitions Kind "throw") are held to aim and
thrown on release. A dotted arc from the hand and the item's own marker on the ground
(`Config.CallIns.<Name>.Aim`: a ring of Radius, or a strip of Length x Width along the throw,
`Across` for the wire) follow the crosshair. The flare (X) and the "self" call-ins still
fire on the press. `AbilityController`.

**Throwing:** the grenade, every thrown call-in and the flare leave the hand at the throw clip's release, not
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

### Downed and revive

The rules (bleed-out, hold E for `Config.Downed.ReviveHold`, radius, max revives) are in
[MULTIPLAYER_READINESS.md](MULTIPLAYER_READINESS.md) decision 3 and `Config.Downed`. What a
revive looks like (`Config.ReviveAnimation`, `Enabled = false` turns it off):

- **Reviver:** slides to a kneel point at the casualty's side (the nearer side of the chest;
  the other side when that one is walled off or taken; where they stand when neither will
  do or it is over `MaxNudge` away), drops to a knee facing them, slings the rifle across
  the back and presses a dressing into the chest with both hands. Letting go stands them up
  at once. When the revive lands a hand takes the casualty's arm and pulls them up.
- **Casualty:** rolls from all fours onto their back while someone is on them, head rocking
  with each press; drops back to the crawl when the reviver lets go; gets up with the
  get-up clip when revived (the Spare Tourniquet and dev revives too).
- Nobody is rooted (the rules did not change): a reviver who walks, or a casualty who
  crawls, breaks the pose until they are still again. A bot stands still for
  `BotHoldSeconds` into its pull-up or get-up.
- Players, bots and any mix of the two use the same code: `ReviveAnimService` (roles and
  the kneel point, server), `Shared.ReviveAnimation` (clips by the body's owner, arms on
  every client), `Rules/ReviveAnim` (kneel point and phases, tested).

### Reinforcements and ammo pouches

`Config.Scarcity` (`Reinforce`, `Pouch`), `ReinforceService`, `Rules/Scarcity`; the design
and numbers: `docs/sprints/FUN_SCARCITY.md`.

- **Reinforcements:** one pool per run for the squad, 2 + 1 per player who joined (solo 3,
  four players 6), shown as yellow squares at the top of the left column ("NO
  REINFORCEMENTS" in red when spent). A player who dies spends one; 8 s later the helicopter
  drops them beside the nearest standing player (else a bot), falling from 22 studs where
  the sky is open, with the insert kit and fresh revives (call-ins and upgrades kept). Their
  K.I.A. line counts down and names who they drop beside; squadmates read "DEAD 8s". Pool
  empty: dead until the squad extracts.
- **Wipe:** no player up and nobody to drop back to (nobody, bots included, up or down; or
  the pool empty with nobody inbound). Reinforcements off: every player dead, as before.
- **Bots** never spend the pool; they come back on their own after 30 s
  (`Reinforce.BotRespawnSeconds`; 10 with reinforcements off).
- **Ammo pouches:** any squadmate who dies (bots too) leaves a pouch labelled AMMO at the
  body for 120 s; each living player holds E 0.5 s on it once for 2 magazines of the long gun
  and 1 of the sidearm, up to the gun's max ("AMMO FULL" takes nothing).

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
- Rounds to kill body / head: rifle Walker 3 / 1; DMR Walker 1 / 1; shotgun one pull for
  every form but the Brute. The Brute (500, plated front, [Moves](#moves)): rifle 63 from the
  front, 20 from behind, 25 in the legs; shotgun 15 / 5 pulls; DMR 21 / 7. Ammo reins in the
  DMR (100 x 60 is the M16's 270 x 20).
- A soldier lands with about half the reserve (`ReserveStart` on the gun's row), so the
  first pallet is wanted; a pallet or the Index kill fills it to `ReserveMax`. The Goose
  keeps its one spare round.
- **Scarcity** (`Config.Scarcity.Ammo`, on): the table's reserves are replaced by
  each row's `Scarce` block, about two thirds: M16 and MP5 90 / 150, M249 100 / 200, Mossberg
  16 / 32, M110 40 / 60, M17 34 / 51, revolver 12 / 24, M2010 10 / 20, Goose unchanged
  (`docs/sprints/FUN_SCARCITY.md`). A fallen squadmate's ammo pouch adds magazines (below,
  Reinforcements and ammo pouches).
- Bots fire the rifle slower (`Bots.FireCooldown` 0.30: three bots on sustained fire ~ one
  player), same magazine, infinite reserve.
- Bots walk: straight to the formation slot when it is close and in sight, else
  along a path, sprinting when far. They teleport only when far from the leader and stalled
  (or out of the world), to a spot no living player faces. Rules in `Rules/BotBrain`,
  numbers in `Config.Bots`.
- Bots spread out: each holds a spot of its
  own 10-18 studs from its leader, in its own sector (behind-left, behind-right, behind, +-40
  degrees), 9 apart and in the leader's line of sight, and keeps it until the leader has moved
  18 studs (or it is 28 away, or the leader walks into it); then it picks again round him.
  `Config.Bots.Loose`, `BotBrain.respot` / `spreadSpot` / `spaced`. The old slots are where a
  teleport lands.
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
- The three sample guns are in the Arms Room like every gun: its lists are every
  row of the slot, ordered by the row's `ArmsOrder` (default 100; the first is the default
  gun), so a new gun appears by having a row. ADS move: revolver 0.85, sniper 0.4, Goose 0.4.
  Revolver Walker 1 / 1, Brute 5 / 4; sniper every form 1, Brute 2 / 2.
- Grenades: **Frag** (110 in 10 studs, 0.8 s fuse; one-shots a Hocker, not a Brute) is
  built. Later: **Incendiary** (3 fire pools, `IncendiaryService`) and **Stun** (0.4x slow
  3 s in 14 studs, `ShockCoilService.stunArea`).
- Feel: every gun, grenade and call-in carries its own `Kick`,
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
- The lobby (docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): the Loadmaster
  hosts the same menu as the **Loadout** (`mount` options title / hint / confirm), `LoadmasterService` validates with the same Rules module, keeps
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
| Fire mission | **Hammer** (81 mm mortar) | 6 shells 1 s apart, 80 in 12 studs, scatter 4; holds the Infected within 16 until 2 s after the first shell | 1 / 120 | yes |
| Fire mission | **Anvil** (105 mm battery) | marked through binoculars on any ground in the line of sight, up to 400 studs; one shell 5 s later, 500 in 20 studs, shake felt map-wide; holds the Infected within 20 until it lands | 1 / 180 | yes |
| Fire mission | **Shrike** (helicopter gun run) | 10 bursts stepping 4 studs along the throw, 120 in 5 studs each, 4 s delay; holds the Infected within 16 of the middle through the run | 1 / 150 | yes |
| Emplacement | **Doorman** (tripod sentry MG) | 45 s, 20 dmg every 0.15 s, range 70, one per player | 1 / 150 | yes |
| Emplacement | **Tripline** (AP mines) | 6 mines on an arc, 80 in 10 studs, 90 s, 12 per player | 2 / 60 | yes |
| Emplacement | **Concertina** (wire) | 16 x 3 strip for 60 s: 0.4x slow, 5 dps; never vaultable | 2 / 90 | yes |
| Supply | **Speedball** (ammo bundle) | 4 re-arms (a player again only after stepping out), no lure wave | 1 / 180 | yes |
| Supply | **Aid Bag** (medical drop) | every soldier within 6 studs: full heal, stims refilled, +25 plate; once each | 1 / 180 | yes |
| Vehicle | **ATV** (two-seat military ATV) | dropped in a crate by the helo; a driver and a back-seat gunner; runs the Infected down ([The ATV](#the-atv-vehicle-call-in)) | 1 / 180 | yes, not played |

Every built call-in is thrown (`Kind "throw"`, `ThrowUtil` clamp) except the Anvil, which is
marked through binoculars (below). Services:
`AirStrikeService` (Hammer, Anvil share `fireMission`, patterns from `Rules/StrikePattern`;
Shrike's `gunRun` under a Part gunship at 45 studs), `SentryService` (Doorman: a ray from the
gun's pivot to the nearest visible Infected; its body is `Config.CallIns.Doorman.Model`, 2 =
the modelled gun whose pivot is 2.6 up, 1 = the Part tripod at 3.2), `MineService` (Tripline), `ConcertinaService`,
`SupplyDropService` (Speedball, Aid Bag land quiet). The support weapons
need the support-weapon carry and the explosive projectile hook (ARCHITECTURE F7). Dev:
`SetCallIn <slot> <id>`, `FireCallIn <id>` (20 studs ahead, no slot or charge).
Retired as too sci-fi: Magpie (drones) and Pen Coil (shock pulse).

**Landing on the crowd** (`Rules/StrikeLanding`, `Config.CallIns.Landing`, switch
`Enabled`). From the key to the first impact the Infected would walk out of the blast, so a
fire mission's mark **holds** the Infected within its row's `Landing.Hold` (Hammer
16, the aim ring; Anvil 20; Shrike 16 round the lane's middle): they walk to the marker (the
lure the Resupply flare uses) until `HoldAfter` seconds after the first impact (Hammer 2,
three shells; Anvil 0.3; Shrike 1.4, the whole run), then chase again. Only what the mark is
on or walks into is held: the player still has to put it on a crowd. Blasts (fire missions,
Tripline trigger and blast) are measured flat along the ground and reach `Landing.Height`
(8) studs up or down (so a Brute's root, about 6 up, is reached). Damage has no falloff (flat inside the radius, as before). `Enabled = false`: no hold, the sphere.

### Binoculars

A call-in whose row says `AimMode = "Binoculars"` (default `"Throw"`; only the Anvil
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

Each call-in comes in its own way
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
| **ATV** | `crate` (`sling` is still a style) | yellow smoke | the helicopter (the insertion's) flies straight over the mark 46 up at 60 studs/s with the crate under its skids, never stopping; it lets go 1.4 s before the landing and the crate drops straight down | the rotor loop | the crate lands at 7.5 s (the real ATV appears inside), its walls fall open flat and the lid kicks off behind; the boards lie 4 s and fade. The crate is the vehicle's size plus 0.4 room, in half-stud steps (`Rules/Arrival.crateSize`: 5.5 x 4 x 8.5 for the ATV); a `Crate` on a Vehicle block sets one |

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
- **Timing:** Doorman works 2.2 s after the throw, Tripline 0.95 s, Concertina 1.05 s,
  Speedball 1.5 s, Aid Bag 1.8 s. Fire missions keep their `Delay`.
- **Budget:** at most 8 arrivals drawn at once per client (`MaxActive`); the biggest (Anvil)
  is 22 Parts; smoke and dust are bursts of 2 to 20 particles, no lights.
- **Switch:** `Config.CallIns.Arrivals.Enabled = false` puts back the flat red discs, the
  stock blast, the one shared whistle and the instant kit.
- **Needs an in-game look (none of it has been seen running):** [PLAYTEST_CHECKS.md](PLAYTEST_CHECKS.md) > Call-in arrivals.

### The ATV (vehicle call-in)

The first vehicle (Nova): a call-in slot, dropped in a crate on a fly-over (the arrivals
table). Transport for the bigger maps as well as a gun platform and a getaway. Built, **not
played**.

- **Getting it:** bought once (400 merits) from the motor sergeant at **Vehicles**, the aft
  end of the Carrier's hangar (docs/sprints/LOBBY_V1_FALLOW.md > Motor pool); signed into a
  call-in slot at the Loadmaster; thrown like any call-in. Its row is `Config.CallIns.ATV`;
  any row with a `Vehicle` block is a vehicle (`VehicleService`), no list of vehicle names.
- **Limits:** one per player, two per squad (two seats each carry the whole squad). Calling
  again scraps your own empty one; refused, with a radio line and no charge spent, when yours
  has people on it, the squad has two out, or the 6 x 4 x 9 landing box is not clear.
  `Rules/Vehicle.callCheck`. Cooldown 180 s from the throw.
- **Seats:** E (Keys.Interact) on its prompt: driver first, then the back. E again (B on a
  gamepad) gets off, to the side that is clear. The driver has no gun (stim only). The back
  seat fires their primary (put in hand when they sit) all round except 25 degrees either
  side of straight ahead; hip spread x1.5 above 8 studs/s. No grenades, call-ins, shove,
  flare, swap or reviving from a seat; a downed, knocked-down or dead rider falls off. In
  solo the nearest free bot within 25 studs takes the back seat when a player drives (bots
  never drive) and gets off with the driver.
- **Driving** (`VehiclePhysics`, `Rules/Vehicle`): ray suspension on four wheels and arcade
  tyres on one chassis; the driver's client simulates it (network owner), the server while
  nobody drives, and the server takes it back for 1 s above 1.25 x top speed. Top 55 studs/s
  (sprint 24, a Runner 17), reverse 16; measured in Studio 26 studs/s after 1 s, 39 after 2,
  46 after 3; steering 35
  degrees standing to 15 at top speed; no drive up ground steeper than 30 degrees (pallet ramps are 33). In the
  air it levels itself. Tipped past 70 degrees and stopped: hold E 1.5 s to flip it back.
- **Rams:** above 12 studs/s an Infected in front of the bumper (behind when reversing)
  takes 2.5 x speed (100 at 40 studs/s: a Walker, Runner or Hocker dies and is thrown limp,
  `EnemyService.noteBlast`); each costs 15% speed and 4 health. A row with `RamStop` (Brute,
  Warden) stops it dead: the ram's damage, a 1 s stagger, 40 to the ATV.
- **Health 400:** smoke at half, fire at a quarter. The Infected hurt it only through its
  riders: each hit on a rider also takes the attacker's `VehicleDamage` (Hocker spit 15,
  Brute 60, Warden 150; Walker and Runner 0). Our own fire never hurts it (rounds pass
  through, folder `Vehicles`). At 0 it burns 3 s and blows: 120 to the Infected within 10;
  anyone still aboard is thrown off, takes 20 and is knocked down 1.2 s.
- **HUD:** while riding, a panel over the bottom: the seat, the keys, the ATV's health.
- **Look** (Nova's own model; `docs/STYLES.md` §6 > The ATV): 7.5 long, 3.3 tall; tyres of radius 1 on a 4.81 wheelbase and a 3.28 track; the chassis
  stands 1.23 over the ground (`VehicleBody.Bodies.atv`, measured on the model). It wears the
  meshes once they load (the server copies them to the clients for the slung stand-in; the
  motor pool waits up to `Config.VehicleMeshes.Wait`); before that it is the first Part body.
- **How riders look** (client `VehiclePose`, the row's `Pose`; a placeholder until a riding
  clip is authored): both seats sit (hips and knees bent over the clip); the driver's hands
  reach the bars and the gun is put away (hidden on every client, and the first-person gun
  too); the back seat keeps the gun up. Bots in the back play the stock sit clip.
- **Testing:** in Studio the starting loadout carries the ATV in its last slot (key 4) when
  nothing was signed for (`Config.CallIns.StudioCallIn`; never in the live game, nil turns
  it off). Dev `FireCallIn atv` drops one with no slot or charge.
- **Engine:** while someone drives, a licensed library loop (Pro Sound Effects "Go Kart
  Engine Constant 2", asset 9112787518, a small 4-stroke) plays on the chassis, pitched 0.75
  standing to 1.35 at top speed, in the world sound group. The Infected hear it like a shot
  (`EnemyService.noise`): 35 studs standing, 85 at top speed (guns carry 70-140), so on a
  quiet mission driving trades stealth for speed. The row's `Engine` block.
- **Not in v1:** swapping seats, the driver's sidearm, grenades from the back, bots driving,
  other vehicles.

### Pallets (Resupply)

- The Resupply pool (one meter on every HUD) is fed by every kill's `SupplyValue` at any
  distance (Walker 10, Runner 12, Hocker 18, Brute 35) and by the Primary
  (`Objective.SupplyReward` 500).
- When the pool covers the cost (`Requisition.BaseCost` 300, x1.15 per drop, cap 1000, +40%
  per extra player) any living player throws the red flare (key X, 35 studs). For 20 s the
  Infected inside 120 studs walk to the flare; then the pallet lands loud (`Lure.Wave` 10, +3
  per extra player; spawn interval x0.7 for 30 s).
- **The pallet is the ammo box:** every living player within `RearmRadius` 6 is re-armed
  once (both guns full, grenades back).
- **The flare waits** 90 s after a pallet lands before it can be thrown again while scarcity
  is on (`Config.Scarcity.Resupply.FlareCooldown`; `Requisition.FlareCooldown` 20 when off):
  the pallet is the main refill, so when to throw it is the squad's call. The meter reads
  "RESUPPLY  FLARE IN 1:12" while the pool is paid for but the wait runs.
- Three cards, the same for everyone (`Crates.SupplyCards`; what each gives is its row in
  `Crates.Cards`, and the card text is built from the row): **Medkit** (full heal, stims
  back), **Restock** (every call-in slot full, grenades and stims too), **Armour Plate** (+75
  armour soaked before health, cap 100). One pick
  per player per pallet; the pallet closes at 90 s. No rarity, no upgrades from pallets.
- **Taking a card** (never by walking over it; `Requisition.Pick`,
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
(`Rules/Reward.upgradeOffer`); a short offer is filled with supply cards.

**The Main objective's reward** (`Crates.Kinds.objective`): as the crate lands
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
interval x0.8, +3 alive and +1 heavy per extra living player, hard cap 44). On top of that
the breaches below give it a rhythm instead of a steady trickle.

### Breaches

Design and numbers: [FUN_BREACHES.md](sprints/FUN_BREACHES.md); code `BreachService`,
`Rules/Breach`, `Config.Breaches` (`Enabled = false` is the old trickle).

- **The alert** (one per run, the squad's): shots with Infected in earshot, blasts, call-ins
  and each Infected first coming close raise it; 8 s of quiet and it falls. Time alone adds
  a little, and late in the run it never falls below a third of the threshold.
- **A breach** at the threshold: a siren and screams from one side, Control names the side,
  a red BREACH arrow on screen; 4 s later a horde of the run's mix floods in from that side
  over 10 s (10, +4 per extra player, +10 late, at most 32, never past the cap of 44).
- **The rhythm:** Calm (the trickle at about 60%) → Tension (Control: "You're making
  noise", the trickle as before) → Breach → Relief (30-50 s, nothing builds, the trickle at
  40%) → Calm. Pressure (run time, full at 12 minutes) lowers the threshold, shortens the
  relief and grows the horde.
- **The main objective** brings one breach at 40% of its work, at its site (after the Warden
  if he is on the field then).
- **Never** in a run's first 60 s, while the Warden is on the field, during extraction, on a
  quiet (awareness) mission.
- **Dev:** F1 > INFECTED > BREACHES > Breach now; the strip under the title reads
  "alert 45% Tension, pressure 30%".

### Stores and the priority pallet

- **Stores** (not built): free crates at the position's abandoned stock. Hold E 3 s to open,
  which is loud. Count per Containment band below; places in LEVELS.md.
- **Priority pallet** (built with the Warden, `IndexService.endFight`): an Index kill drops a
  quiet pallet at the corpse: re-arm, full heal, the three supply cards
  (`Index.Warden.Drop.Cards`; `"upgrade"` puts the field upgrades back there).

### Extraction

`Config.Extraction`, `Rules/ExtractionWaves`: a 60 s hold, progress only while every living
player is on the pad. On the call Walker 12, Runner 4, Brute 1 round the pad and spawn
interval x0.8; when the hold reaches 30 s a second wave of 12 phase-weighted Infected (+3 per
extra player) rings the pad, Control calls it and the spawn interval goes to x0.6 (`Waves`
rows: `At`, `Count`, `PerExtraPlayer`, `SpawnFactor`). A wave is tied to the hold's progress,
so it never lands while the squad is off the pad. The designed 90 s version and the Burn:
[LATER.md](LATER.md).

## Operation: the Burn, extraction, scoring

Designed, not built (code comments point here): the Burn timer, the designed 90 s
extraction, Secondaries' reward and the score per mission are in [LATER.md](LATER.md). The
extraction that is built: [Extraction](#extraction).

## The Containment Board (bands in code; the shared board not built)

Players read it as the board titled WHAT WE HOLD in the map room. The bands are code (`Config.Containment`, `Rules/Containment`, the lobby's `ContainmentBoard`); the shared DataStore board is not built.

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


## Objective pools

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
  hold the district." The Warden comes partway through the main objective and is its last
  act; finishing both pays 500 Resupply, drops the objective reward crate and calls the
  helicopter (below, The Warden in the main objective). Side objectives are optional;
  failing one costs nothing.
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

### The words

Each objective's Brief (Control), Why (HUD, 8 words at most) and Done (Control) lines live
in `src/shared/ObjectiveDefinitions.luau` only (`{place}` is the drawn site, `{to}` where a
carried item goes). Plain words (OWNER.md).

### The Warden in the main objective

The Warden is the main objective's last act (owner: part of the objective, not a separate
event), at
its site (`Config.Objectives.Boss`, each main row's `Boss` block in `ObjectiveDefinitions`,
`Rules/BossAct`, `ObjectiveService`, `IndexService.arrive`).

- **When.** He comes when the objective reaches `At` of its progress, and at the latest
  when its work is done. Once per run.
- **Where.** He walks in from open ground 55-70 studs from the objective's point
  (`EnterMin` / `EnterMax`, `EnemyService.groundNear`), or from the site's `BossFrom` when
  a site names one (a map that moves its sites moves him too: nothing is hard-coded). He
  walks to the objective, then fights as always (kit, phases, Riot Calls unchanged).
- **What he does to it** (one rule per objective, below): `Contest` stops the objective
  while he stands on it (the HUD says so and Control says it once); `Target = "carrier"`
  makes him hunt whoever carries the item.
- **Done.** The mission completes when the work is done **and** he is down, in either
  order. Work first: "That's done. The Warden is all that's left. Put him down." and the HUD
  reads "Kill the Warden" (its marker follows him). Him first: "The Warden is down. Finish the
  job." Then the objective's Done line, 500 Resupply and the objective reward crate at the
  objective, and the run goes straight to extraction. His own pallet, heal and re-arm at the
  corpse are unchanged. The run stays in Primary while he is up (no Index state).
- **Off switch.** `Config.Objectives.Boss.Enabled = false` restores the old order: work done
  -> reward -> the Warden from the Gate -> extraction. The single hold (pools off) always
  plays the old order.
- **Dev.** "Warden now (objective)" (RUN tab) and "To the objective" (THE WARDEN): DevCommand
  `WardenNow` brings him to the main objective now, starting it if the squad has not reached
  it. "Complete hold" finishes the work (he comes if he has not); "Kill the Warden" kills him.

| Objective | He comes | What he does |
|---|---|---|
| Sanitize the Pens | when the second tent burns (`At` 0.6) | walks to the last fuel can; it will not light while he is within 14 studs of it (its prompt goes off) |
| Secure the Site | halfway through the hold (0.5) | the hold stops while he stands in the zone (half its smaller side) |
| Restore Comms | 30 s into the 60 s hold (0.5) | the signal stops while he is within the hold's 20 studs of the mast |
| Confirm Casualties | when half the heavies are down (0.5) | comes to lead the rest; no other rule |
| Recover the Record | a third of the way carried (0.3) | hunts the carrier first (nearest member when nobody carries it) |

**Balance (systems pass).** He keeps his body and plates (`HealthFactor` 1): the Gate walk-in
(up to 75 s) is gone, so the mission is shorter even with the contest; the target fight
stays 100-120 s. A contest is never a reset: holds pause, never drain. Bots stand off 32
studs from him (`Config.Bots.Boss.StandOff`), outside a 20-stud mast radius and most of a
zone, so in solo the player pulls him off while the bots hold or the player kills him first;
with 4 players one kites, the rest work. While he is up both the objective's faster spawns
and his lighter field (`Config.Index.Warden.Pressure`) apply, as before.

**Later (not built):** he puts out a burning tent; he damages the mast (progress lost, not
paused); he walks in from the Gate lane to the site (needs pathing past buildings); a
per-objective arena (cover he can charge into near each site, Delta v2's level pass);
Mile 14's boss in its own objectives.

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

### Awareness (the quiet missions)

Nova's design: Mile 14 is played quiet, and going loud is rough. On a mission in `Config.Awareness.Missions` (Mile
14) every Infected is in one of five states (`Shared.Rules.Awareness`, `EnemyService`):

| State | Does | Notices |
|---|---|---|
| Sleeping | slumped, still | only noise close by (a third of its reach) or a soldier touching it |
| Idle | stands | a cone in front of its head, and noise |
| Wandering | shuffles round its post at 0.3 speed | further, and noise |
| Alerted | walks to what it heard or glimpsed at 0.6 speed, searches 12 s, then wanders there | further still |
| Chase | the old straight chase | loses the soldier after 8 s out of sight: searches the last spot |

- **Noise:** every shot carries its gun's `Noise` (studs): inside half a body comes for it
  (Chase), inside all of it goes to look (Alerted). Pistol 45, MP5 70, revolver 75, M16 110,
  Mossberg 120, M110 130, M249 140, M2010 200, the Goose 300 (the loudest; its blast adds
  `Explosion` 260 where it lands). Bots' shots too. A soldier running makes footsteps (16).
- **Sight:** a cone 60 degrees either side, 45 to 90 studs by state, about half at night,
  0.6 against a crouched soldier and 0.35 against a prone one. Seen builds notice (2.5 s at
  the edge, faster close in, at once inside 5 studs): any notice sends it to look, full notice
  is a Chase. A hit is always a Chase. A body that starts a Chase wakes the ones within 30 to
  look.
- **Spawning:** the start places `Population.Count` (70) round the map, more than 70 studs
  from the LZ: about half asleep, a quarter wandering, the rest standing. No roaming spawns
  while it is quiet; an objective's or a pallet's waves still come chasing. Going loud (the
  horn, spawns) and the suppressor are next (steps 2 and 4 of the plan).

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

### The Warden

`Config.Index.Warden`, `IndexService`, [SPRINT_19_WARDEN.md](sprints/SPRINT_19_WARDEN.md).

- **Entry.** He comes to the main objective partway through it (Objective pools > The
  Warden in the main objective). With `Config.Objectives.Boss.Enabled = false`
  he comes after it instead: he spawns beyond the Gate, the Gate opens (radio) and he walks
  the screening route: Gate lane, bus line, Inner Gate, under the bridge, the Apron, then the
  hunt (walk times out after 75 s). A member within 90 studs during the walk gets the
  sighting line. Radio lines: LORE.md.
- **Boss pass** ([FUN_WARDEN.md](sprints/FUN_WARDEN.md), not yet played): he
  arrives over the top (Control's warning, a 2.5 s ring, a dive onto it: 25 and knocked down
  inside 14 studs, the screen shakes, he roars, the boss bar slams in, his fight loop starts);
  never flinches from rounds; turns at 150°/s (260° through a windup, locked 0.35 s before the
  blow); a keyed heavy stride whose rate follows his speed, a boot and a camera shake on each
  heel strike; impacts shake the screen; every Charge draws its lane. Stage 2 (66%) opens the
  **Quake** (fists up 1.6 s, a 36-stud ring, then 2 rings at 26 studs/s: 30 and knocked down;
  jump, roll or be outside; every 14 s) and his charges go through props up to 8 studs a side
  (back next run). Stage 3 (33%) opens the **Rampage** (three Charges back to back at whoever
  is furthest). Whoever stands still 4 s is the Leap's first pick.
- **Body.** 5,000 hp at scale 2.2 ([WARDEN_AGGRESSIVE.md](sprints/WARDEN_AGGRESSIVE.md)),
  +50% per extra living player (the one exception to "more Infected, not tougher": one body
  cannot be more bodies). Headshot x2
  once the helmet is off. Walk 12 studs/s (13 below 66%, 15 in the rage; the soldier walks 16).
  The reach distances below were written at scale 1.9; at 2.2 each is about 16% longer.
- **Plates** (one rule): helmet 200, chest 300, back 400 (the flank and the weak spot),
  shoulders 200 each, shield 400. A round into a plate does 25% to the plate and nothing to
  the body; a round into a limb whose plate is gone does 150%. At half a plate cracks (yellow
  pip); at zero it flies off, he staggers 1.5 s. HUD order: HELM, CHEST, BACK, L SHLD, R SHLD,
  SHIELD.
- **Weak spot: his back** (the plate over his radio pack, `Plates.Back.WeakSpot`). A round
  into it counts whole (not 25%), pops the headshot marker, and three quarters of it goes
  through to his body; it ignores his guard; breaking it staggers him 3 s. Control names it 10 s into
  the fight.
- **Attacks**, each announced by his words ("WARDEN: ...") on the boss bar. Where you stand picks
  his move: **Bash** (0-15 studs, 70° arc, 40, 0.7 s windup; a shield punch with a step, no
  spin; roll through it); **Shield
  Sweep** (17 studs, 180°, 25 and a shove; get behind him); **Overhead Slam** (17 x 6 line at
  a body that stopped moving in reach, 60, 1.3 s; step aside); **Ground Pound** (23-stud ring
  drawn through the 1.4 s windup, 30 and 2.4 s knocked down; beat it with distance or a
  ledge, not the roll; he is stuck 2.6 s after); **Stomp** (a body within 7 studs: 8.5-stud
  disc, 20 and 1.8 s knocked down, 0.6 s; roll it); **Leap** (at the member furthest from the
  rest, 22-70 studs, every 9 s, 7 below 60%, 5 in the rage: a 0.8 s crouch with the
  9.5-stud ring already on the ground where they stood, 0.8 s in the air, 35 and 1.2 s
  knocked down; leave the ring, the roll does not beat it; stay together);
  **Charge** (19-60 studs, 1.2 s windup,
  45 studs at 40/s, 35; hard cover stuns him 3 s); **Gas Canister** (every phase; furthest
  member within 70 when that member is past his reach, 10 + a 9-stud puddle 6 s);
  **Volley** (the rage only: a canister at every member within 70, every 12 s); **Guard** (his
  plates took 150 inside 3 s: shield up 2.5 s, half speed, frontal plates take 25%; flank
  him). Out of reach the order is Volley, Leap, Charge, Canister (`Rules/WardenBrain.farPick`).
  He walks a beat between attacks (0.5 / 0.35 / 0.15 s by phase), never repeats one
  except the Bash, never chains two knockdowns (the Leap counts). Limb attacks miss a rolling
  body; the Pound, the Leap and the Charge do not. Knocked down: no moving, firing or
  abilities; 1 s immunity on the get-up (`Config.Knockdown`). Bots step out of the rings and
  the lines.
- **Phases** by body health (`Rules/WardenBrain.phase`): below 66% stage 2: the stage roar (everyone within 20 studs thrown back) and the **Riot Call** (6
  Walkers + 2 Runners + 1 Brute, +3 Walkers and +1 Brute per 2 extra players), walk 13, leap
  every 7 s, the Quake, charges through props; below 33% the **rage**: the roar, a
  second call (6 Walkers, 3 Runners, 2 Brutes), his words "WEAPONS FREE", Control's warning,
  walk 15, charges every 5 s, leaps every 5 s, the Volley, the Rampage. While he is up the wave
  loop spawns at x1.5 interval, 8 fewer alive, no ambient Brutes (his call still brings them).
- **Kill.** Priority pallet at the corpse, everyone alive healed and re-armed; extraction
  opens (with him in the objective: once its work is done too). Corpse stays 8 s.
- **Target fight** 90-120 s for a solo squad with the adds, 2-3 minutes for four players,
  more of it moving than shooting. Fallbacks: `Leap.Enabled = false`; `Animations.Infected.Warden.attack
  = "warden_bash"` puts the old spinning Bash clip back; the boss pass's switches are listed
  in FUN_WARDEN.md > Off switches.
- **Dev.** F1 > THE WARDEN: "In front of me" (F9; the full entrance, 30 studs ahead), "To
  stage 2 (the call)", "To stage 3 (the rage)", "Quake now", "Rampage now", "Kill him".

## The Infected roster

Ordered by how far the strain has gone in one body. Model name stays `Infected`; the slang
goes on the kill feed. Each form is one rule (pillar 3). Look: blocky Roblox bodies,
lore-accurate poses, no zombie green (OWNER.md); build sheets in [CHARACTERS.md](CHARACTERS.md).

| Form | Role | Look | First seen | Engine |
|---|---|---|---|---|
| Walker | slow melee; the crowd grabs | still a person, grey, old wounds closed | Delta | built, 60 HP |
| Runner | fast melee; pounces and pins, in packs | dense rebuilt muscle, tendons like cable | Delta | built, 40 HP |
| Brute | melee tank; plated front, charges | bone overgrowth, plated shoulders | Delta | built, 500 HP, headshot x1.25, legs never break |
| Hocker | ranged; barrage, lobs over cover | lobs caustic fluid; throat a swollen sac | Delta late | built, 80 HP |
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

Bodies (2026-11-20): the Infected pass through soldiers and each other, so a Runner never
shoves a soldier and a pile never lifts one into the air; they still stop at `AttackRange`
to hit. Soldiers (players and bots) sit in their own collision group (`SoldierCollision`,
`Config.Player.Collision`; `BlockInfected = true` makes the bodies solid again). The spit
casts in `ShotGroup`: other Infected never stop it, soldiers do.

### Moves

Each form forces its own answer, with a tell (a sound and a pose) before it lands. Numbers in
`Config.InfectedMoves` (`Enabled = false` turns them all off; each move has its own switch),
the before/after numbers and the reasoning in [FUN_ENEMIES.md](sprints/FUN_ENEMIES.md).

- **Brute: plated front and the charge.** Rounds on the head, torso or arms from the front do
  40%, in the back 125%, the side and legs 100%; blasts are never plated (the hit shows as a
  plate hit). At a soldier 14-40 studs off in the open: stops, leans back and bellows 1.1 s,
  then runs through them at 36 studs/s and 12 past: 25, knocked down 1.4 s, thrown off the
  side of the line. Hard cover stuns him 2.5 s. Answer: leave the line, cover, flank, explosives.
- **Runner: pounce and pin, in packs.** At 6-18 studs: a crouch and a shriek 0.55 s, a leap at
  where you stood (step aside or roll). Caught: 10, pinned on your back (knocked down, no
  shooting) up to 5 s, 8 a second, until a squadmate hits it or shoves it (F). Bots shoot a
  pinning Runner first; Control names who is pinned. The director's Runners come with 1-2
  pack-mates.
- **Hocker: barrage and lob.** Each spit is three globs (on you and 7 studs either side), each
  with a puddle (7 studs, 7 s, 12/s). With no clear line but open sky it lobs high over the
  cover (1.7 s flight). Backs off inside 70% of its 45-stud stand-off.
- **Walker: the grab.** A claw landing with 3+ Infected within 7 studs of you slows you to 60%
  (10% less per extra body, 30% floor) for 1.2 s; a roll slips it.
- Dev: F1 > INFECTED > THE MOVES places each form where its move fires; "Moves off" for the
  session.

## Hit feedback on the Infected

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

