# Item Icon Style Guide — moved

The icon style and pipeline now live in [docs/STYLES.md](../docs/STYLES.md) (section 4),
alongside the rest of the game's visual direction (palette, UI, low-poly 3D rules for
Blender assets, VFX, performance budgets).

Summary (2026-11-05):

- All 24 icons were redrawn in one generated faceted low-poly style. The generator
  `assets/icons/build/icons.js` is the source of truth; `*.svg` are its outputs.
- `node assets/icons/build/icons.js sheet` renders everything plus a contact sheet.
- `node assets/icons/build/upload.js` uploads PNGs via Open Cloud and records ids in
  `build/uploaded_ids.json`; `node assets/icons/build/wire.js` writes them into
  `ItemDefinitions.luau` and `ASSET_IDS.md`.
- The old two-style split (13 plated 256 px + 11 flat 64 px glyphs) is gone.
