# assets/3d — the Blender project for all game meshes

One Blender project holds every asset: **`arena_survivor.blend`**. Open it in Blender to look
at or hand-tweak anything. Collections inside it:

| Collection | Contents |
|---|---|
| `Props` | world objects dropped by services: ammo crate, repulsor mine, drone, drone beacon, plague rat |
| `Weapons` | held tools (rifle) |
| `Pickups` | XP orb |
| `Environment` | Stage 1 set dressing, all built to the 5-stud character (`CHAR_H`, `DOOR_H`, `STOREY`, `COVER_H` constants in the script): barrier, sandbags, tower, ruin, containers, humvee wreck, T-wall, hesco, comm tower, tent, checkpoint, dead tree, lamp post |
| `Chosen` | player limb sets `pc_<class>_<limb>` for assault (Weller), k9 (Cole), epi (Reyes), recon (Cross), engineer (Kane) (`PC_CLASSES`, `_pc_limb`, the shared `_pc_carrier`); only assault is uploaded and worn in game |
| `Infected` | enemy limb sets: `inf_<walker|runner|brute|hocker>_<limb>`, 9 limbs per type (left/right share), one builder function per type (`walker_limb`...) from the sheets in `docs/CHARACTERS.md` |
| `_Reference` | a 5-stud human block for scale; never exported |

The `.blend` is **generated** by `build/build_assets.py`. Every asset is described in code
(boxes, cylinders, icospheres painted with palette swatches), so edits made by hand in Blender
will be overwritten the next time the build runs. To change an asset, edit its function in
the script and rebuild; to keep a hand-made asset, add it to a new `.blend` next to this one
or ask to have it ported into the script.

## Rebuild everything

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python assets/3d/build/build_assets.py
```

Outputs:

- `arena_survivor.blend` — the project
- `palette.png` + `palette.md` — the one shared texture and its swatch map
- `export/<asset>.fbx` — one FBX per asset (Y-up, 1 unit = 1 stud)
- `build/previews/<asset>.png` + `lineup.png` — Workbench renders to check the look

Add `-- --only wpn_rifle prop_drone` to build a subset.

## Current assets

| Name | Tris | Pivot | Replaces |
|---|---|---|---|
| prop_ammo_crate | 108 | bottom center | AmmoCacheService crate part (2.6 x 1.6 x 1.8) |
| prop_repulsor_mine | 168 | bottom center | MineService disc part (2 studs across) |
| prop_drone | 280 | center | DroneService body part (1.1 x 0.35 x 1.1) |
| prop_drone_beacon | 172 | bottom center | (new) beacon pickup / objective dressing |
| wpn_rifle | 188 | grip | PlayerSetup `attachRifle` part rifle |
| pick_xp_orb | 80 | center | XPOrbService sphere part |
| prop_plague_rat | 204 | bottom | PlagueRatService body+head+tail parts |
| env_barrier_jersey | 72 | bottom | 6 x 2.75 x 2 concrete traffic barrier |
| env_sandbag_bunker | 552 | bottom | 12 x 10 U-emplacement, COVER_H (4) walls |
| env_guard_tower | 564 | bottom | 10 x 10 timber tower, deck at 14, 27 overall (PreciseConvexDecomposition collision) |
| env_ruin_building | 816 | bottom | 30 x 20 two-storey block (10.5-stud storeys, real doorway), sealed |
| env_container_olive / _rust | 408 | bottom | ISO container 21.5 x 8.7 x 9.3 |
| env_wreck_humvee | 392 | bottom | burnt truck 16.5 x 7.8 x 6.5, hood = COVER_H |
| env_twall | 84 | bottom | concrete blast wall 8 x 12 |
| env_hesco | 240 | bottom | gabion 6 x 4.5 x 4.4 |
| env_comm_tower | 528 | bottom | 40-stud lattice mast, the Stage 1 landmark (PreciseConvexDecomposition collision) |
| env_tent | 124 | bottom | 16 x 12 olive tent, ridge at 8, walkable roof slope (PreciseConvexDecomposition collision) |
| env_checkpoint | 192 | bottom | guard booth + 14-stud boom (PreciseConvexDecomposition collision) |
| env_dead_tree | 96 | bottom | 14-stud bare tree (Hull collision) |
| env_lamp_post | 76 | bottom | 13-stud street light (Hull collision) |
| inf_walker_* / inf_runner_* / inf_brute_* / inf_hocker_* | 0.8-1.1k per body | center | the 15 R15 limb MeshParts of each Infected (`MeshAssets.dressInfected`); v2 2026-11-07 |
| pc_assault_* | ~600 per body | center | Weller, the player's 15 R15 limb MeshParts (`PlayerSetup` -> `MeshAssets.dressModel`); v2 2026-11-07 |
| pc_k9_* / pc_epi_* / pc_recon_* / pc_engineer_* | ~600 per body | center | Cole, Reyes, Cross, Kane: built + previewed, not uploaded (no class system yet) |
| ref_inf_* / ref_pc_* | — | bottom | assembled preview figures, never exported |

All far under the budgets in `docs/STYLES.md` section 6. Dressing positions live in
`ArenaService.DRESSING` (x/z of the bounds centre + yaw; ground height is found by raycast so
pieces sit on the hills). Buildings are solid blocks: the Infected have no pathfinding, so
enterable interiors would be safe spots. Mesh pivots do not survive import (a MeshPart is
centred on its bounds). Every `env_*` preview renders with the 5-stud reference figure beside
it: check scale there before uploading.

### Infected and player bodies (limb swap, not a custom rig)

The enemies stay stock R15 rigs from `CreateHumanoidModelFromDescription` (free walk
animation, Humanoid physics). Each limb is modelled in Blender inside the R15 limb's box
(`R15_LIMB` in the build script, centred on the limb's origin; front/top details may protrude
~0.1). At boot `EnemyService` clones the bare rig once per type and `MeshAssets.dressInfected`
swaps every limb MeshPart for the type's mesh: same name, same centre (`offset` corrects the
bounds-centre shift), rig attachments moved over, then `Humanoid:BuildRigFromAttachments()`
rebuilds the joints (modern rigs get `AnimationConstraint`s, not Motor6Ds). Spawns clone the
dressed template, so per-spawn cost is a plain Clone. To restyle a type, change its swatch
function in `INFECTED_TYPES` (one `<type>_limb(L, limb)` builder per form; `Limb` wraps the
primitives at the limb origin, `Builder.rotate_all` tilts a whole limb such as the Hocker's
head), rebuild, re-upload the 9 limbs, update the ids in `MeshAssets`. Roblox deduplicates
identical meshes across uploads (the Hocker's legs share the Walker's mesh ids).

Player bodies use the same mechanism (`_pc_limb`, `PC_CLASSES`): `PlayerSetup` turns off
`StarterPlayer.LoadCharacterAppearance` so characters spawn as bare R15 rigs, then
`MeshAssets.dressModel(character, "pc_assault_")` swaps the limbs before the rifle welds to
the hand. The build prints `offset <name>` (bounds centre, Roblox axis order) for every
centre-pivot limb; copy it into the `MeshAssets` entry.

## Getting a mesh into Roblox (the pipeline that shipped 2026-11-06)

1. **Upload** the FBX with the Studio MCP `upload_asset` tool (`assetType: "Model"`), and
   `palette.png` once as a `Decal`. Open Cloud imports FBX at 100x (1 Blender unit = 100
   studs); that is fine, the MeshPart is scaled by `Size`.
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
   the fallback when that returns nil. Mesh pivots are at the bottom in Blender but a
   MeshPart is centred on its bounds, so place at `ground + Size.Y / 2`.
5. Verify in a playtest (`solo_playtest`, grant the item, screenshot).

## Live Blender (blender-mcp) — set up 2026-11-05

Claude drives the open Blender window through the open-source **blender-mcp** bridge: the
"MCP for Blender" add-on (installed in Blender 5.2, auto-starts a socket server on
`localhost:9876`) plus the `blender-mcp` MCP server, registered for this repo in `.mcp.json`
(`uvx blender-mcp`). Blender must be open for the tools to work; the MCP tools appear in a
Claude Code session started after `.mcp.json` existed.

Verified: a raw `get_scene_info` over the socket returned the `arena_survivor.blend` objects.

Rules once live: Claude may inspect and prototype in the open scene, but every asset that
ships is still written into `build/build_assets.py` and rebuilt, so the `.blend` stays
reproducible (no hand-edited geometry as the only source). Re-install the add-on from
https://github.com/ahujasid/blender-mcp/blob/main/addon.py if Blender is reinstalled.

## Style rules

See `docs/STYLES.md` section 6 (flat shading, single palette texture, triangle caps, pivots,
naming, MeshPart settings, scene performance budget).
