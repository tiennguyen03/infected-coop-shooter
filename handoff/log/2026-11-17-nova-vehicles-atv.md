# Vehicles: the ATV and the motor pool (Nova + Claude, 2026-11-17)

**Changed:** the first vehicle. The ATV is a call-in: bought at the new Vehicles desk (the
motor sergeant, the motor pool at the aft end of the Carrier's hangar), signed into a slot,
thrown; the helicopter brings it in on a sling. One drives (no gun), one rides the back and
fires their primary (not through the driver); E on and off, a prompt per seat; it runs the
Infected down (Brute and Warden stop it), takes damage through its riders, smokes, burns and
blows. A bot walks over and takes the back seat when a player drives. `docs/PROGRESSION.md` >
The ATV; `VehicleService`, `VehiclePhysics`, `VehicleBody`, `Rules/Vehicle` (spec first),
`VehicleController`, `CallInArrivalFX` "sling", lobby `MotorPool` and the `vehicles` desk.
In Studio the starting loadout carries the ATV on key 4 (`Config.CallIns.StudioCallIn`).
**Verified:** Nova played it in Match Dev: called in, drove, rammed, both seats, a bot boards
and sits, the Warden knocks riders off, no errors. Tests (492), lint, types, both builds. The
performance reviewer's fixes are in. Not seen: the motor pool in the lobby, the wreck's blast,
a 2-player drive, the MicroProfiler numbers it asked for.
**Heads-up:** Tien, small hooks in your files: `CallInService` (a row with a `Vehicle` block),
`ProjectileServer` (driver refused, gunner arc, rounds pass through `Vehicles`), `KitService`
and `RequisitionService` (no kit from a seat but the stim), `BotService` (riding bots, `BoardAt`,
a sit clip), `Squad` (no revive from a seat), `EnemyProjectileService.damagePlayer` (4th arg
`vehicleDamage`), `EnemyDefinitions` (`VehicleDamage`, `RamStop`), `LoadoutService.usePrimary`,
and the client controllers stand still on the character's `Riding` attribute.
**Next:** the driver's hands on the bars, faster, an engine sound, the sergeant's radio lines,
a Blender mesh, more vehicles as the maps grow.
