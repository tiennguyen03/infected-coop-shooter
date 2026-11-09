# Sprint 22: aimed throws and the Shrike helicopter (2026-11-09)

Owner: "some of them need to be hold and release with trajectory indicators, for example the
air strike, so I actually will know where it lands. Also build the actual helicopter in
Blender for that one."

## Hold to aim, release to throw

- **Which:** the frag (G) and every call-in of Kind "throw" (Hammer, Anvil, Shrike, Doorman,
  Tripline, Concertina, Speedball, Aid Bag). One rule for every thrown thing, so nobody has
  to learn which key works which way. The Resupply flare (5) and "self" call-ins still fire
  on the press.
- **What you see while holding:** a dotted arc from the hand to the landing point
  (`Config.CallIns.AimArc`: beads, rise per stud of reach) and the item's own marker on the
  ground, following the crosshair. Release throws exactly there (same `ThrowUtil` maths as the
  server).
- **Per item** (owner rule: modular loadouts): `Config.CallIns.<Name>.Aim` =
  `{ Shape = "ring", Radius }` or `{ Shape = "strip", Length, Width, Across? }`. Hammer 16
  (where shells can land), Anvil 20, Shrike a 46 x 10 strip along the throw (the run), Doorman
  2, Tripline 8, Concertina a 16 x 3 strip across the throw, Speedball and Aid Bag 6. A row
  without `Aim` shows a small ring. The frag shows its blast radius.
- Code: `AbilityController` (`startAiming` / `updateAiming` / `release`); pressing another
  throw key while aiming switches to it.

## The Shrike gunship

- An attack helicopter in the AH-64 mould, modelled in Blender (`assets/3d/build/aircraft.py`):
  tandem glass cockpit, chin gun, stub wings with rocket pods and missiles, a long tail boom
  with a tail rotor, olive drab; 30 studs long. Two meshes: `veh_shrike_hull` and
  `veh_shrike_rotor` (origin at the hub), uploaded to the group.
- `AirStrikeService.gunshipPass` flies the hull along the run at `PassHeight`, spins the rotor
  (`RotorSpin` degrees per second at `RotorHub`) and fires the tracers from the chin gun
  (`GunMuzzle`). Without the meshes it falls back to the old plain hull.
- Preview: `assets/3d/build/previews/veh_shrike.png`.

## Verified

Static checks clean (stylua, selene, rojo build, 58 tests, luau-lsp). Live test in a separate
Studio: holding G shows the arc and the landing ring; a Shrike call-in flies the modelled
helicopter with its rotor turning and tracers from the nose; it cleans itself up; no errors.
Not verified live: holding 1-4 (Roblox test input cannot press number keys), so the strip
markers were checked only through the shared code path. Owner to try keys 1-4.

## Not done

- Lantern (the extraction helicopter) is still the old placeholder; it belongs in
  `aircraft.py` next.
- The arc is a straight parabola for every throw; the call-in canisters themselves still
  travel the old way on the server.
