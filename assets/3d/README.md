# assets/3d — the Blender project for all game meshes

One Blender project holds every asset: **`arena_survivor.blend`**. Collections inside it:

| Collection | Contents |
|---|---|
| `Props` | service-spawned items (ammo crate, repulsor mine), the gore pieces (`build/gore.py`) and set dressing: cot, generator, light tower, fuel bladder, pallet, body bag, dumpster, plank, portable toilet, chainlink panel, concertina, the four cars and the cargo truck. Still built but unused in game: drone, drone beacon, plague rat |
| `Weapons` | the held rifle |
| `Pickups` | XP orb (unused in game) |
| `Environment` | mission set dressing, all built to the 5-stud character (`CHAR_H`, `DOOR_H`, `STOREY`, `COVER_H`, `RUIN_*` constants): barrier, sandbags, tower, ruin, containers, humvee wreck, T-wall, hesco (+ tall), comm tower, tent, checkpoint, dead tree, lamp post, transit bus, crib stack, deck plate |
| `City` | the six skyline towers and their `_lit` twins (`build/city.py`) |
| `Chosen` | player limb sets `pc_<class>_<limb>` (`PC_CLASSES`). Only `pc_assault_*` is used: every player and bot wears it as the anonymous Pike soldier. The k9 / epi / recon / engineer sets are retired (the Chosen) but still built. Also the skinned body `pc_assault_skinned` and its rigid gear (switched off, below) |
| `Infected` | enemy limb sets `inf_<walker|runner|brute|hocker>_<limb>` (one builder per form in `INFECTED_TYPES`, from `docs/CHARACTERS.md`), the Warden (`build/warden.py`) |
| `_Reference` | a 5-stud human block for scale; never exported |

The `.blend` is **generated** by `build/build_assets.py`. Every asset is described in code
(boxes, cylinders, icospheres painted with palette swatches), so edits made by hand in Blender
are overwritten by the next build. **One file per singular asset** (owner): a boss or a body
gets its own `build/<name>.py` exposing `register(ba)`, which `build_assets.py` imports and
calls at the end of its asset list (`warden.py` is the pattern); sets of related things share
one file (`props.py`, `city.py`, `gore.py`, the Infected roster in `build_assets.py`). Design
new bodies in live Blender first (below) so the owner can direct the shape before it is
ported into a build file.

## Rebuild everything

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python assets/3d/build/build_assets.py
```

Outputs:

- `arena_survivor.blend` — the project
- `palette.png` + `palette.md` — the one shared texture and its swatch map (61 of 64 cells;
  the order is every exported mesh's UV layout, so rows are only ever appended or replaced
  in place)
- `export/<asset>.fbx` — one FBX per asset (Y-up, 1 unit = 1 stud)
- `build/previews/<asset>.png` + `lineup_chars.png` + `lineup_env.png` (the environment next
  to the 5-stud figure) — Workbench renders to check the look

Add `-- --only <name> [<name>...]` to build a subset. `--only` saves `arena_survivor.blend`
and the lineups with only those assets; run a full build afterwards.

## Current assets

| Name | Tris | Pivot | Notes |
|---|---|---|---|
| prop_ammo_crate | 108 | bottom center | resupply pallet / requisition crate |
| prop_repulsor_mine | 168 | bottom center | MineService |
| wpn_rifle | 188 | grip | PlayerSetup welds it to the hand; now only the fallback for a gun whose mesh is not uploaded |
| veh_shrike_hull / veh_shrike_rotor | 920 / 124 | fuselage centre / hub | the Shrike gunship (`build/aircraft.py`, in-game size, nose toward -Z): AirStrikeService flies the hull along the gun run and spins the rotor at `Config.CallIns.Shrike.RotorHub` (`RotorSpin`), tracers from `GunMuzzle`; falls back to a plain hull Part while the meshes are missing |
| wpn_m16 / wpn_mp5 / wpn_m249 / wpn_mossberg / wpn_m110 / wpn_m17 | 260 / 216 / 248 / 328 / 376 / 156 | grip | the six original guns (`build/guns.py`), same convention as the sample guns below |
| wpn_revolver / wpn_sniper / wpn_goose | 248 / 540 / 396 | grip | the sample guns (`build/guns.py`, built at in-game size, not 0.65x); MeshAssets carries each `offset` (bounds centre from the grip) and `muzzle`; a gun row names its mesh in `Config.Weapons.<id>.Model` |
| env_barrier_jersey | 72 | bottom | 6 x 2.75 x 2 concrete traffic barrier |
| env_sandbag_bunker | 552 | bottom | 12 x 10 U-emplacement, COVER_H (4) walls; colliders: 3 walls, open top and +Z |
| env_guard_tower | 564 | bottom | 10 x 10 timber tower, deck at 14, 27 overall, rail gate on the ladder (+Y) side; colliders: legs, deck, rails + TrussPart ladder |
| env_ruin_building | ~900 | bottom | 30 x 20 block on 10-stud storeys, 4 x 8 doorway, windows sill 4 / head 9.4, back wall one storey with a 6-wide breach, slab top 10; colliders make it enterable (26) or a sealed shell (5) |
| env_container_olive / _rust | 408 | bottom | ISO container 21.5 x 8.7 x 9.3 |
| env_wreck_humvee | 392 | bottom | burnt truck 16.5 x 7.8 x 6.5, hood = COVER_H |
| env_twall | 84 | bottom | concrete blast wall 8 x 12 |
| env_hesco | 240 | bottom | gabion 6 x 4.5 x 4.4 |
| env_hesco_tall | 360 | bottom | double-height gabion 6.2 x 8.9 x 4.7 (the Pens ring) |
| env_crib_stack | 168 | bottom | timber cribbing 1.2 x 2.8 x 2.6 under the Scrapes' T-walls |
| env_deck_plate | 84 | bottom | steel plate 12 x 0.33 x 5 for container roof chains |
| env_comm_tower | 528 | bottom | 40-stud lattice mast, Delta's landmark (Box + composite colliders) |
| env_tent | 124 | bottom | 16 x 12 olive tent, ridge at 8, walkable roof slope (Box + composite colliders) |
| env_checkpoint | 192 | bottom | guard booth + 14-stud boom (Box + composite colliders) |
| env_dead_tree | 96 | bottom | 14-stud bare tree (Hull collision) |
| env_lamp_post | 76 | bottom | 13-stud street light (Hull collision) |
| env_bus | 712 | bottom | 42-stud transit bus, 12.5 tall (Hocker-proof cover) |
| env_city_* (+ `_lit`) | 960-1,870 a tower | bottom (`_lit`: the tower origin) | the skyline (`city.py`, [STYLES.md](../../docs/STYLES.md) §7) |
| prop_cot | 108 | bottom | field cot 6.5 x 2.1 x 3 |
| prop_generator | 172 | bottom | towed generator 8 x 5.2 x 4.5 |
| prop_light_tower | 260 | bottom | mast light tower 4.7 x 18 x 3.9 |
| prop_fuel_bladder | 92 | bottom | collapsible fuel bladder 11 x 3 x 7.4 |
| prop_pallet | 228 | bottom | wooden pallet 4 x 0.57 x 4 |
| prop_body_bag | 44 | bottom | 6.6 x 0.95 x 2.2 |
| prop_dumpster | 164 | bottom | 7.5 x 4.4 x 4.2 (a Walker step: climb 5 up, 4.6 more to a 9 roof) |
| prop_plank | 48 | bottom | 10 x 0.4 x 2 |
| prop_car_sedan | 896 | bottom | silver three-box sedan 14.9 x 4.6 x 6.6 (roof 4.4: VAULT side-on), rear tyre flat; 2 colliders |
| prop_car_hatch | 968 | bottom | maroon hatchback 12.9 x 5.6 x 8.2: driver window smashed, door open, roof rack with a tarp and a suitcase; 2 colliders |
| prop_car_pickup | 948 | bottom | rusted pickup 18.1 x 5.4 x 7: open bed (stand in it at 2.6), mattress and a crate, cab 5.4; 5 colliders |
| prop_car_van | 948 | bottom | white panel van 17.8 x 7.2 x 7.2 (CLIMB only), side door open on a dark interior; 2 colliders |
| prop_cargo_truck | 856 | bottom | army cargo truck 24.3 x 9.8 x 9.8: cab 8, bed deck 2.9-3.7, CRAWL-UNDER between the axles; 5 colliders |
| prop_portable_toilet | 92 | bottom | 4.3 x 8.45 x 4.4 |
| prop_chainlink_panel | 268 | bottom | fence panel 12 x 7 x 0.3 (see-through) |
| prop_concertina | 288 | bottom | razor wire coil 12.1 x 2.9 x 2.9 |
| inf_walker_* / inf_runner_* / inf_brute_* / inf_hocker_* | per body in [STYLES.md](../../docs/STYLES.md) §7 (caps `BODY_TRI_CAP`) | center | the 15 R15 limb MeshParts of each Infected (`MeshAssets.dressInfected`) |
| inf_warden_* / inf_warden_plate_* | STYLES §7 (cap 5,000) | center | the Warden: 12 limb meshes with sided upper arm / lower arm / hand (`warden.SIDED`, `MeshAssets.limbMeshName`) plus six plates welded on by `IndexService.buildPlates` (helmet, chest, back, shoulder `_l` / `_r`, shield) |
| inf_gore_stump, inf_gore_chunk_a/b/c | small | origin / center | stump welded at a joint when a limb comes off (GoreService); chunks thrown at body hits (client GoreFX). `gore.py`, a small `loft` kit |
| pc_assault_* | ~650 per body | center | the Pike soldier's 15 R15 limb MeshParts (`PlayerSetup` -> `MeshAssets.dressModel`); tapered forearms and shins with joint caps (`PC_TAPER`) |
| pc_assault_skinned, pc_assault_gear_helmet / _carrier | 944 (+ gear 228) | HRP centre | switched off (below); still registered in `MeshAssets` |
| ref_inf_* / ref_pc_* | — | bottom | assembled preview figures, never exported |
| Unused in game | | | `prop_drone`, `prop_drone_beacon`, `pick_xp_orb`, `prop_plague_rat` (retired features; still built and registered in `MeshAssets`, no service clones them); `pc_k9/epi/recon/engineer_*` (built, never uploaded) |

All far under the budgets in `docs/STYLES.md` §6. Dressing positions live in
`ArenaService.DRESSING` / `PROPS` (x/z of the bounds centre + yaw; ground height is found by
raycast so pieces sit on the hills; `lift`, `floor`, `shell`, `shadow`, `perch` per entry).
Collision is either the mesh's own Box/Hull or a list of invisible collider boxes in
`MeshAssets` (`colliders`, written in the build's design coordinates: the build prints
`offset <name>`, the bounds centre in Roblox axis order, for every asset). Mesh pivots do not
survive import (a MeshPart is centred on its bounds). Every `env_*` preview renders with the
5-stud reference figure beside it: check scale there before uploading. A mesh registered with
`meshId = ""` is skipped at boot and listed in the server log until its id is pasted in.

### Infected and player bodies (limb swap, not a custom rig)

The bodies stay stock R15 rigs from `CreateHumanoidModelFromDescription` (free walk
animation, Humanoid physics). Each limb is modelled in Blender inside the R15 limb's box
(`R15_LIMB` in the build script, centred on the limb's origin). At boot `EnemyService` clones
the bare rig once per type and `MeshAssets.dressInfected` swaps every limb MeshPart for the
type's mesh: same name, same centre (`offset` corrects the bounds-centre shift), rig
attachments moved over, then `Humanoid:BuildRigFromAttachments()` rebuilds the joints (modern
rigs get `AnimationConstraint`s, not Motor6Ds). Spawns clone the dressed template, so
per-spawn cost is a plain Clone. Posture is baked in: `Builder.shift_all` / `rotate_all` hang
a limb off its fixed R15 joint, so a limb may leave its box and the printed `offset` moves
with it. To restyle a form, change its `<type>_limb(L, limb)` builder in `INFECTED_TYPES`,
rebuild, re-upload the changed limbs, update the ids in `MeshAssets`. The build prints
`body inf_<type>` with the whole-body triangle count against `BODY_TRI_CAP`.

`Limb` helpers: `oct(r, h, loc, swatch, r_top)` an octagonal limb segment, tapered when
`r_top` differs (flats face the box sides; r 0.54 fills a 1.0 box, 0.36-0.42 is a healthy
limb); `cap(r, loc, swatch)` a rounded joint cap (bone knobs on the Infected); `hip_inset`
the narrow collar at the top of an upper leg; `boil(r, loc, n)` a pustule with a `pus_l`
head pushed out along the surface normal `n`; `cluster(count, r, loc, n, spread)` a fixed
spiral of boils; `lesion(w, h, loc, face)` an inflamed rim round a raw core on one face
(`front`/`back`/`left`/`right`/`top`/`bottom`); `blotch(w, h, loc, face, swatch)` a flat
discolouration; `eyes(..., rim)` the milky eyes in a wound rim. A boil or cap that pokes out
grows the MeshPart `Size` and shifts the printed `offset`. Roblox deduplicates identical
meshes across uploads (the Hocker's legs share the Walker's mesh ids).

Player bodies use the same mechanism (`_pc_limb`, `PC_CLASSES["assault"]`): `PlayerSetup`
turns off `StarterPlayer.LoadCharacterAppearance` so characters spawn as bare R15 rigs, then
`MeshAssets.dressModel(character, "pc_assault_")` swaps the limbs before the rifle welds to
the hand.

**Upload order when the palette changes:** `palette.png` first, then the FBX, then the
`MeshAssets` size/offset from the `dims`/`offset` lines the build prints. Limbs painted with
new cells on an old texture render those cells black.

## Skinned Weller (switched off)

`pc_assault_skinned` is one skinned mesh on an R15 armature (`RIGGED`, `_pc_skin_body`),
assembled at boot by `MeshAssets.buildSkinnedBody` when `Config.Player.SkinnedBody` is true.
It is false: the hidden rig parts and the skin's bones diverged under the R15 clips, so gear
and rifle floated off the body ([HISTORY.md](../../docs/HISTORY.md), 2026-11-07). Players
wear the rigid `pc_assault_*` set. The build still writes `export/pc_assault_skinned.fbx`,
`_mesh.fbx` and `_parts.fbx`; the code path and its notes stay in `MeshAssets` and
`PlayerSetup`. Rule for any future skinned body: the importer's rig is in centimetres and
`Model:ScaleTo(0.01)` leaves the scale factor at 0.01, which scales the Humanoid's movement
forces down; the character must end with `GetScale() == 1` (`buildSkinnedBody` re-homes the
parts in a fresh Model).

## Small set pieces live in `build/props.py`

Vehicles, gates, barriers, walls, containers and every `prop_*` dressing piece share one
file, registered with `props.register(ba)`. `build_assets.py` keeps the palette, the
Builder, service-spawned items, structures and landmarks (ruin, guard tower, comm tower,
tent, sandbag bunker, dead tree, lamp post) and the bodies. `props.profile()` extrudes a side
silhouette (the cars); `props.panel()` lays glass on a sloped edge. Cars are built to the
5-stud figure (roof 4.4-7.2) with composite colliders.

## The distant city lives in `build/city.py`

Six skyline towers (`env_city_office`, `_residential`, `_deco`, `_glass`, `_ruined`,
`_midrise`) built floor by floor with `city.facade()` (glass core, a spandrel ring per
storey, piers on the bay grid), plus `parapet`, `roof_slab`, `plant`, `tank`, `mast`. Each
tower registers a `<name>_lit` twin: the lit-window slabs from the same seeded pass, on the
tower's origin (pivot `origin`, not re-seated), so one placement lines both up through their
`offset`s. SkyService places them ([STYLES.md](../../docs/STYLES.md) §7).

## Z-fighting pass (`Builder.resolve_zfight`)

Two faces in one plane flicker in Roblox. `Builder.finish` finds coplanar, same-facing,
overlapping faces of different swatches in every Environment / Props / Pickups / Weapons /
City mesh (bodies and the rat excluded) and moves the smaller primitive (by surface area)
0.05 out along the face normal, repeating until none are left. The build log prints
`z-fight <name>: N primitives pushed forward`; a mesh listed there for the first time changed
and needs a re-upload. Still model details proud (0.03+) so the pass has little to do.

## Getting a mesh into Roblox

1. **Upload** the FBX with the Studio MCP `upload_asset` tool (`assetType: "Model"`,
   `groupId` 270506601: the group owns every asset), and `palette.png` once as a `Decal`.
   Open Cloud imports FBX at 100x and clamps any axis to 2048; that is fine, the MeshPart is
   scaled by `Size`.
2. **Read the MeshId** in Studio edit mode:
   `InsertService:LoadAsset(<modelAssetId>)` → the MeshPart inside → `.MeshId`. Record
   mesh id, model id, in-game Size and placement note in `ASSET_IDS.md`.
3. **Register** it in `src/shared/MeshAssets.luau` (`MESHES[name] = { meshId, size }`). At
   server boot `MeshAssets.init()` builds one template per entry with
   `InsertService:CreateMeshPartAsync(meshId, CollisionFidelity.Box, RenderFidelity.Automatic)`
   (positional arguments; the options-table form errors) and sets the palette `TextureID`.
   Do **not** create MeshParts through Rojo `model.json`: the live sync sets `MeshId`
   without the mesh bounds (`MeshSize` stays 0) and the mesh renders at the wrong scale.
4. **Use** it: the owning service calls `MeshAssets.clone(name)` and keeps its old Part as
   the fallback when that returns nil. Place at `ground + Size.Y / 2`.
5. Verify in a playtest (`solo_playtest`, screenshot).

## Live Blender (blender-mcp)

Claude drives the open Blender window through the **blender-mcp** bridge: the "MCP for
Blender" add-on (installed in Blender 5.2, auto-starts a socket server on `localhost:9876`)
plus the `blender-mcp` MCP server registered in `.mcp.json` (`uvx blender-mcp`). Blender must
be open for the tools to work. Build and look in the live scene (owner), but every asset that
ships is still written into a build file and rebuilt, so the `.blend` stays reproducible.
Re-install the add-on from https://github.com/ahujasid/blender-mcp/blob/main/addon.py if
Blender is reinstalled.

## The map in Blender (`build/delta_map.py`, `delta_map.blend`)

Checkpoint Delta is built from plain Parts by `src/server/ArenaService.luau` (exact
collision, built-in materials, streaming, the building kit); nothing of the map is imported
as a mesh. `delta_map.py` is the way to **see** the layout while placing things: it reads
the layout tables straight out of `src/server/Missions/Delta.luau` (Delta's mission data
file since the mission data split; `HILLS`, `DRESSING`, `PROPS`,
`RAMPS`, `PATCHES`, `BUILDINGS`, plus the loops that add the Gate line, the Pens ring and the
perch containers), rebuilds the same ground in a fresh Blender scene and stands the real
environment meshes (`export/*.fbx`) on it at the height the game's raycast would find. Every
piece that breaks a placement rule ([LEVELS.md](../../docs/LEVELS.md) A12b) is painted red and
listed on stdout.

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python assets/3d/build/delta_map.py
```

writes `assets/3d/delta_map.blend` and `build/previews/map_{whole,core,lz_gate,suburb,
depot,barracks,scrapyard,oblique}.png` (top-down Workbench renders). Open the `.blend` in the
live Blender (`bpy.ops.wm.open_mainfile`) and the MCP `look` tool frames any object
(`target=["HelipadLZ"]`, `["Overlook"]`, a building name).

The loop: edit the numbers in `Missions/Delta.luau` -> rebuild the view -> look -> playtest.
Or move a piece in the Blender viewport, then in the live Blender run
`exec(open("assets/3d/build/delta_map.py").read()); write_back()`: every static entry's
object carries `arena_table` / `arena_index`, and the moved ones have their `x` / `z` /
`yaw` rewritten in place in the Luau. Entries the Luau generates in loops are `arena_locked`
(edit the loop). `Missions/Delta.luau` stays the single source of truth.

## Style rules

See `docs/STYLES.md` §6 (flat shading, single palette texture, triangle caps, pivots,
naming, MeshPart settings, scene performance budget).
