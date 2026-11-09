# Sprint 21: sample guns (2026-11-09)

The owner asked for "a couple sample guns" made in Blender, with their own sounds and proper
TTK, plus "an RPG, just to see it for fun", reachable from the dev menu; Nova wires them into
the loadout screen. Numbers from the systems designer; gun table in
[PROGRESSION.md](../PROGRESSION.md) > Loadout.

| Row id | Gun | Slot | What it does | Mesh | Sound |
|---|---|---|---|---|---|
| `revolver` | S&W 686 .357 | secondary | 55 dmg, 150 rpm, 6 + 30: one round per Walker, staggers a Brute | `wpn_revolver` | `revolver` |
| `sniper` | M2010 ESR | primary | 140 dmg, bolt 48 rpm, 5 + 30, Pierce 3: one per kill, Brute in 2, useless from the hip | `wpn_sniper` | `sniper` |
| `goose` | M3 recoilless ("Goose", the RPG) | primary (for now) | a rocket at 220 studs/s: 400 to the Infected struck, then the frag's blast 120 in 6 studs; 1 + 1 rounds, 6 s reload; no friendly fire | `wpn_goose` | `goose` |

## How it works (per item, owner rule: modular loadouts)

- `Config.Weapons.<Gun>` may carry `Model` (the held mesh, default `wpn_rifle`), `Sound`
  (its clips in the `guns` bank: `<Sound>_shot`, `<Sound>_reload`; default the shared shot
  and the gear reload), and for a launcher `Explosive = { Radius, Damage, ShakePower }` plus
  `ProjectileSpeed`. `WeaponDefinitions.row` copies them; nothing names a gun elsewhere.
- **Mesh:** `PlayerSetup.attachRifle` dresses the Tool with the gun in hand's mesh and moves
  the Muzzle to the mesh's `muzzle` (MeshAssets), and re-dresses on every change of the
  `Weapon` attribute (Q swap, Arms Room, dev panel). A gun whose mesh is not uploaded wears the
  rifle. Bots keep the rifle.
- **Sound:** `SoundFX.gunshot(sound, position?)` plays the gun's `_shot` clip (2D for your
  own, 3D at another member's muzzle; `ShotTracer` now carries the gun's `Sound`);
  `LoadoutService.startReload` plays its `_reload` clip. Either falls back to the old sound
  while the `guns` bank has no id.
- **Rocket:** `ProjectileServer.fireRocket` sends a visible projectile (`Config.Weapon.RocketSize`
  / `RocketColor`) with an `onImpact` callback: direct damage to the Infected struck, then
  `KitService.blast` (the frag's flash, shake and damage, now public) at the impact point, or
  where it runs out of range.
- **Dev panel:** F1 > WEAPONS lists every row (`WeaponDefinitions.allIds`), Arms Room or not.

## Owner playtest fixes (2026-11-09)

- **Shotgun read as one bullet:** the server always fired 8 pellets in the cone, but the
  shooter's screen drew one tracer. The client now draws every pellet (`ShotCone.random`
  inside HipSpread/AdsSpread + bloom) and sends those directions with `FireWeapon`; the server
  takes each one within `Config.Weapon.PelletTolerance` of its own cone (`Rules/Spread`,
  spec in `tests/Spread.spec.luau`) and rolls its own for any other, so the tracers you see are
  the hits.
- **Rifle sound on the original guns:** only the sample guns had a `Sound`. The MP5, M249,
  Mossberg, M110 and M17 get their own shot + reload clips in the `guns` bank.
- **Silent rocket:** the Goose's impact now plays the frag's blast sound.
- **Every gun gets its own model** (owner: "just make them"): M16A4, MP5A3, M249, Mossberg
  590, M110 and M17 modelled in `guns.py` (lineup: `assets/3d/build/previews/guns_lineup.png`),
  uploaded to the group, each row's `Model` set. `wpn_rifle` is only the fallback now.

## For Nova (loadout screen)

The three rows exist but are not in `WeaponDefinitions.PRIMARIES` / `SECONDARIES`, so the Arms
Room does not list them yet. Add the ids there (or however the new loadout screen lists guns).
The systems designer's notes: show them only once they read well in hand; the Goose is meant
to become its planned call-in (1 charge, 120 s cooldown) once a support-weapon carry exists;
if the revolver crowds out the M17, cut `Revolver.ReserveMax` to 24.

## Verified

Static checks clean (stylua, selene, rojo build, 53 tests, luau-lsp). Live playtest
(2026-11-09): `SetWeapon` sniper / revolver / goose swaps the held mesh (each in the hand,
pointing forward, muzzle ahead); a Goose rocket fired at a Walker killed it, no errors.

## Not done

- Reload animations: all three use the rifle reload clip.
- The revolver is chunky for a placeholder; free models may replace any of the three.
