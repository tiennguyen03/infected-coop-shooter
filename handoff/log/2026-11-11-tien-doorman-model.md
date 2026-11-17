# Doorman model (Tien's agent, 2026-11-11)

**Changed:** the Doorman is a modelled sentry gun instead of five grey Parts: a belt-fed
machine gun on a spade-foot tripod, sensor head beside the receiver, ammo can and brass belt,
battery box and sandbags. It turns in two pieces (the cradle yaws, the gun tips at its
trunnion, held to 40 degrees) and its tracers leave the modelled muzzle. Files:
`assets/3d/build/doorman.py` (new, registered in `build_assets.py`), `MeshAssets`
(`dep_doorman_base / _cradle / _gun`), `SentryService`, the Doorman row in `Config`.
**Verified:** in live Blender from every side and at 25 studs beside the 5-stud figure
(`assets/3d/build/previews/doorman_v2_*.png`); stylua, selene, both rojo builds, 135 Lune
tests, luau-lsp. The three meshes are uploaded to the group and their MeshIds read in Studio.
**Not seen in game:** no playtest was started (the owner may have been playing).
**Heads-up:** check in a playtest (dev `FireCallIn doorman`): the ammo can is on the gun's
LEFT and the sensor on its RIGHT (the export is pre-mirrored like the Fallow; if they are
swapped, take `Deployables` out of `MIRROR_X_COLLECTIONS` and re-upload); the barrel points
at the target, not away; the feet sit on the ground; the gun does not swing through its legs.
It now sees and fires from 2.6 studs up, not 3.2, so low cover blocks it sooner.
`Config.CallIns.Doorman.Model = 1` puts the Part tripod back (it is also what stands when a
mesh has not loaded). `build_assets.py -- --force` rewrites every FBX: do not commit that.
**Next:** a muzzle flash and a turn rate (it snaps to targets today); a deploy animation.
