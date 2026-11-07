# Sprint 18 — Loadout rework: call-ins, magazine, pallets as ammo, field upgrades, flat curve

**Status: shipped 2026-11-07, verified in a solo playtest (results under the checklist).** Implements the spine in `docs/PROGRESSION.md` > *Loadout, pallets
and field upgrades (spine v1)* from the 2026-11-07 systems-designer and lore-developer
passes. The Risk of Rain item economy (24 items, rarity, XP orbs, levels) is gone; power is
the loadout. `docs/ITEMS_REFERENCE.md` is deleted with it. Register rows 4 and 7 and
decision 2 in `docs/MULTIPLAYER_READINESS.md` are superseded.

## What shipped, by step

| # | Step | Done | Where |
|---|---|---|---|
| 1 | Shared data: `WeaponDefinitions` (service rifle from `Config.Weapon`: Damage 20, 30-round mag, 2.2 s reload, 120 reserve, headshot x3), `CallInDefinitions` (Magpie, Tripline, Anvil, Pen Coil; lore names, `Kind` throw/self, `ConfigKey`), `UpgradeDefinitions` (3 supply cards + 12 field upgrades with `Slot`), `Config.CallIns / Upgrades / Crates / PlayerCountScaling / Overrun`, flat `Config.Difficulty`, new spawn phases, `EnemyDefinitions.SupplyValue` + realistic health (W55 R35 B260 H75) and damage (W10 R8 B30 H15); `Remotes` gains `Reload` and `CallIn`, loses `ItemsUpdate`. | Done | `src/shared/` |
| 2 | Delete the old economy: `XPOrbService`, `XPService`, `PassiveItemService`, `AmmoCacheService`, `PlagueRatService`, `ItemService`, `ItemDefinitions`, `XPBarUI`, `ItemBarUI`; every reference (grep-clean for XPOrbs, XPGainMult, OrbMagnetMult, XPRequired, Config.XP/Progression/Items/ItemRarities, ItemsCollected, IncomingDamageMult). `ItemEffectService` is now only the damage entry point, kill credit, kill listeners and the hit broadcast. Mesh keys `pick_xp_orb` / `prop_plague_rat` stay in `MeshAssets` unused. | Done | `src/server/`, `src/client/` |
| 3 | `LoadoutService` (replaces `ItemService`): per player weapon, magazine + reserve, `consumeRound` / `startReload` / `cancelReload` / `refillAmmo`, two call-in slots (`setCallIn` swaps and drops the old call-in's upgrade), six upgrade slots (`giveUpgrade`, a call-in upgrade resolves to the slot carrying that call-in), `rollUpgradeOffer`, the Armour Plate shield (`addShield` / `absorb`). Published as Player attributes `Weapon Mag Reserve ReloadUntil CallIn1 CallIn2 Upgrade<Slot> Shield`. Combat Reload is instant at `Upgrades.CombatReload.MomentumStacks`. | Done | `src/server/LoadoutService.luau` |
| 4 | `ProjectileServer`: weapon from the loadout, magazine gate, Last Stand (downed firing, hip spread x2), Through-and-Through (the ray continues past the body), Hollow Point (`EnemyService.stagger`), exported `hitMultiplier(part, humanoid, headshot)`; `BotService` uses it (the Brute's plate now applies to bot rounds) and carries the rifle's magazine with an infinite reserve. `EnemyProjectileService.damagePlayer` soaks on the shield before health. `CoverMoveService` accepts `"slide"` and cancels the reload on every move. | Done | `src/server/ProjectileServer.luau`, `BotService.luau`, `EnemyProjectileService.luau`, `CoverMoveService.luau` |
| 5 | `CallInService`: keys 1/2, charges per slot (`Config.CallIns.<Key>.Charges`, one refill per `Cooldown`), throw landing via `ThrowUtil` like the flare, dispatch with the call-in's upgrade flag: `DroneService.deployBeacon` (Magpie: 2 drones follow the thrower 30 s; Last Flight keeps them on a paused clock while the owner is down, otherwise they hold where the owner fell), `MineService.layArc` (Tripline: 6 mines on an 8-stud 160-degree arc; Daisy Chain: the key blows every armed mine for free), `AirStrikeService.fireMission` (Anvil: 3 shells; Walk It In: 5 shells stepping 8 studs), `ShockCoilService.pulse` (Pen Coil; Ground Strap revives downed squadmates in reach). Slows moved into `EnemyService.slow`; lures are a list (flare + Bait Charge). `AssaultClassService`: Flare Straps (`IncendiaryService.spawnTrail`), Smoke Dash (the `CoverMoveUntil` window), Bait Charge (3 s fuse, lure); `BreachDamage 80`. `Squad`: Spare Tourniquet (`selfReviveAt`, `SelfReviveAt` attribute, `revive(member, by, free)`). Published as `CallIn<n>Charges` / `CallIn<n>ReadyAt`. | Done | `src/server/CallInService.luau` and the five services |
| 6 | Pallets: `RequisitionService` fed by `EnemyService.addKillListener` (any distance) and `Objective.SupplyReward`; `dropCrate(position, facing, kind, loud)` shared by the flare pallet (supply cards, loud) and the Primary's site crate (`ObjectiveService.activate`, upgrade cards, quiet); re-arm every living player within `RearmRadius` once per crate; Medkit / Restock / Armour Plate applied on pick; `Resupply "cards"` is now `(crateId, kind, choices, positions)`. `DifficultyService` + `EnemyService` read `Config.PlayerCountScaling` (spawn interval, max alive, heavy caps per extra living player). | Done | `src/server/RequisitionService.luau`, `ObjectiveService.luau`, `DifficultyService.luau`, `EnemyService.luau` |
| 7 | Client: `WeaponController` (R reload, auto-reload on dry, no shot while reloading or dry, Last Stand downed firing), `AbilityController` (1/2 call-ins at the crosshair, throw clip; flare stays on 3), `AbilityUI` (call-in tiles with charge pips and the next-charge timer), new `LoadoutUI` (ammo counter beside the crosshair, loadout strip top left), `ResupplyUI` (cards from `UpgradeDefinitions` by kind, no rarity, meter pulse on a kill, bar at -50), `HealthBarUI` (bar at -24, shield overlay), `RunEndUI` (no level / items lines), `DevTestPanel` (LOADOUT and FIELD UPGRADES sections), `DevTestService` (`SetCallIn GiveUpgrade ClearUpgrades RefillAmmo RestockCallIns SetWeapon DropUpgradeCrate DropSupplyCrate`; `PrintRunState` shows the loadout, `VerifyCleanup` checks drones / mines / pools / strike effects / full magazine / no shield / no upgrades). | Done | `src/client/`, `src/server/DevTestService.luau` |

Static checks: `stylua`, `selene` (0 warnings), `rojo build`, `luau-lsp analyze` (only the
pre-existing errors in `MeshAssets`, `ArenaService` 334-341, `Animations`).

## Judgment calls

- **Magpie follows the thrower** (the follow-up design note wins over the first draft's
  beacon-anchored Overwatch Drone): the beacon prop stays on the ground 4 s as the launch
  marker. Damage 6 at 0.6 s, two drones, so a Magpie is roughly a third of a player.
- **Hollow Point staggers on every hit** (`EnemyService.slow(humanoid, 0, 0.6)`), the
  simplest reading of "the hit Infected stops". Watch for chain-stunning (backlog).
- **A downed owner's drones hold position** without Last Flight rather than vanishing, so
  the upgrade's value is the follow and the paused clock, not the drones' survival.
- **Upgrade crates skip players with nothing to take** (no "cards" message) rather than
  showing an empty row; the Primary's crate drops quietly because the pressure wave is the
  fight.
- **Defibrillator costs a revive** (`Squad.revive` without `free`) per the systems note;
  the Spare Tourniquet is the one free stand-up.
- **The dev panel swaps slots**: `SetCallIn` to a call-in already in the other slot swaps
  the two (and their upgrades) instead of duplicating it.
- **`Config.Overrun` is reserved**: nothing reads it until the Burn exists.
- **BotService damage stays `Config.Bots.Damage`** (20) with the headshot multiplier from
  `WeaponDefinitions` through `hitMultiplier`; reserve infinite as decided.

## Register rows that close

`docs/MULTIPLAYER_READINESS.md` rows 4 and 7 superseded, row 5's player-count half done
(the pause-aware clock stays open), decision 2 superseded.

## Verification checklist (Studio, the integrator)

Solo `solo_playtest`, `DevCommand` fired from `client-1`
(`Remotes.get("DevCommand"):FireServer(...)`), output via `get_runtime_logs`; the screen via
`capture_screenshot`. Expected results in brackets.

1. **Boot.** Play → no red output; `PrintRunState` [player line: `service_rifle mag 30/120,
   shield 0, call-ins magpie(1) tripline(2), upgrades []`; bots alive 3]. HUD: ammo `30 / 120`
   beside the crosshair, strip `1 Magpie  2 Tripline  Dash: -  Breach: -  Rifle: -  Kit: -
   Magpie: -  Tripline: -`, tiles `[1] Magpie` 1 pip, `[2] Tripline` 2 pips, HP bar at the
   bottom with Resupply above it, no XP bar.
2. **Magazine.** `SpawnEnemy Walker 10`; hold fire [counter drops to 0, "DRY [R]", then
   "RELOADING" and the bar for 2.2 s, then `30 / 90`]; press R mid-magazine [reload];
   sprint + C (slide) during a reload [the reload cancels, counter unchanged]. Walker dies
   in 3 body shots or 1 headshot; Brute (`SpawnEnemy Brute 1`) in 13 / 11.
3. **Call-ins.** Press 1 [beacon prop lands at the crosshair, two drones lift off and
   follow; tile pip goes dim, timer counts 90 s; "CombatDrone" x2 under `workspace.Drones`,
   gone after 30 s]. Press 2 twice [6 mines per throw on an arc, 12 under
   `workspace.Mines`; a Walker walking in blows one]. `SetCallIn 1 anvil`, press 1 [three
   red discs, shells 3 s later; `StrikeEffects` empties]. `SetCallIn 2 pen_coil`, press 2
   twice near Infected [ring, damage, slowed bodies; third press does nothing]. `RestockCallIns`
   [pips full].
4. **Flare → pallet.** `FillResupply` (F6), press 3 [flare lands at the crosshair, meter
   shows `SUPPLY DROP 0:20`, Infected walk to it]; pallet lands [wave spawns, three cards
   Medkit / Restock / Armour Plate]. Fire a magazine first, then walk to the pallet
   [`RE-ARMED` notice, `30 / 120`]; walk into Armour Plate [HP bar gets a blue overlay and
   `+50`; a hit takes shield first]. Kill a Walker [meter pulses, pool +10].
5. **Upgrade crate.** `ActivateObjective` [hold zone + a `FIELD KIT` crate at the site with
   three upgrade cards]; take one [strip slot fills with the lore name; `GiveUpgrade` for the
   same slot replaces it]. `DropUpgradeCrate` [crate 12 studs ahead, quiet].
6. **Upgrades.** `GiveUpgrade fire_trail` + Q [three fire pools along the dash].
   `GiveUpgrade smoke_dash` + Q next to Walkers [no melee for 1.5 s after]. `GiveUpgrade
   lure_charge` + E [Infected walk to the charge, 3 s fuse]. `GiveUpgrade
   through_and_through` [a round kills two lined-up Walkers]. `GiveUpgrade hollow_point`
   [hit Walkers stop briefly]. `GiveUpgrade combat_reload` at 5 Momentum + R [instant].
   `GiveUpgrade last_stand`, `DownPlayer` [LMB still fires from the ground, wider spread].
   `GiveUpgrade tourniquet`, `DownPlayer` [stands up alone after 4 s; `member ... revives
   used 0`; a second down waits for a revive]. `SetCallIn 1 magpie`, `GiveUpgrade escort`,
   press 1, `DownPlayer` [drones keep following; after Heal they still have their time].
   `GiveUpgrade command_detonation`, press 2, press 2 again [all mines blow, no charge
   spent]. `SetCallIn 2 pen_coil`, `GiveUpgrade defibrillator`, `DownBot`, stand next to
   it, press 2 [bot stands up]. `SetCallIn 1 anvil`, `GiveUpgrade walking_barrage`, press 1
   [five discs in a line]. `ClearUpgrades` [strip empty].
7. **Objective → extraction.** `ForceObjectiveComplete` [pool +500], `ForceMissionSuccess`
   [results screen without level / items lines]; READY → `VerifyCleanup` [PASS: no drones,
   mines, pools, strike effects, resupply objects; magazine full; shield 0; no upgrades].
8. **Co-op (2-client `multiplayer_playtest`, optional now).** Spawn interval and max alive
   grow with the second player; each player sees their own cards; a re-arm is per player;
   Last Stand / Tourniquet / Defibrillator / Last Flight with a real downed player.

## Open

- `assets/icons/build/wire.js` still writes `IconId` into the deleted `ItemDefinitions`;
  retarget to `CallInDefinitions` / `UpgradeDefinitions` before the next icon batch.
- Card icons: the supply cards and the field upgrades have no icons yet (abbreviation
  plates); the call-ins reuse the old item icons.
- Hollow Point stagger cadence; Magpie damage (6) against the first draft (20).
- The Armory (choosing call-ins before the drop) does not exist; the dev panel swaps slots.

## Verification results (2026-11-07, solo playtest on main)

Driven from `client-1` with the remotes and DevCommands while the owner also played:
boot clean (HUD: ammo counter, loadout strip, call-in tiles, no XP bar); magazine counts
down per shot, the dry magazine refuses shots, R reloads in 2.2 s and moves 30 rounds from
the reserve, auto-reload on dry; Magpie (2 drones, 1 charge, 90 s), Tripline (6 mines per
throw, 2 charges, third refused), Anvil (3 shells), Pen Coil (2 charges) all fire with the
right charge bookkeeping; flare → pallet in 20 s → cards Medkit / Restock / Armour Plate;
walking up to a pallet re-arms (RE-ARMED notice, 10 → 30 rounds); the upgrade crate offers
three upgrade cards and a pick fills the slot; all 12 `GiveUpgrade` ids land in their slot;
Flare Straps leaves 3 pools on a dash; Last Stand fires while downed; Spare Tourniquet stands
the player up alone after 4 s at 50% health; Ground Strap stands up a downed bot;
ForceObjectiveComplete adds 500 supply; ForceMissionSuccess → Extracted → READY → new run
with a full magazine, no shield, no upgrades. Not yet run: the 2-client checks (Last Flight,
per-player cards). Perf: 60 fps with 20 Walkers plus mines and drones; the script lane is
within 0.2 ms/frame of the pre-sprint capture.
