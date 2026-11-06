# assets/3d — the Blender project for all game meshes

One Blender project holds every asset: **`arena_survivor.blend`**. Open it in Blender to look
at or hand-tweak anything. Collections inside it:

| Collection | Contents |
|---|---|
| `Props` | world objects dropped by services: ammo crate, repulsor mine, drone, drone beacon |
| `Weapons` | held tools (rifle) |
| `Pickups` | XP orb |
| `Environment` | (empty for now) arena set dressing |
| `Infected` | (empty for now) enemy bodies |
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

All far under the budgets in `docs/STYLES.md` section 6.

## Getting a mesh into Roblox

1. Studio → Avatar/3D Importer (Home tab → Import 3D) → pick `export/<asset>.fbx`.
2. In the import dialog set **Scale Unit = Studs**, uncheck anything about rigs/animations,
   keep "Merge meshes" off (each FBX is already one mesh). Import.
3. Upload `palette.png` once as a Decal (`assets/icons/build/upload.js` style, or Studio Bulk
   Import) and set every MeshPart's `TextureID` to its image id. Record the ids in
   `assets/3d/ASSET_IDS.md`.
4. On the MeshPart: `Anchored` as needed, `CollisionFidelity = Box`,
   `RenderFidelity = Automatic`, `CastShadow = false` for small clutter.
5. Put the MeshPart in `ReplicatedStorage.Assets.<name>` (Rojo-managed folder TBD) and have
   the owning service clone it instead of building a Part. Keep the old Part as the fallback
   until the clone is verified in a playtest.

## Style rules

See `docs/STYLES.md` section 6 (flat shading, single palette texture, triangle caps, pivots,
naming, MeshPart settings, scene performance budget).
