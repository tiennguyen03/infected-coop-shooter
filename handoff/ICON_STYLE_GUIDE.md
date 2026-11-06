# Item Icon Style Guide + Pipeline

Open task (2026-11-05): make all 24 item icons uniform. Two styles exist today because they
were authored in different sessions. Confirm with the user which direction before redrawing
(the pending question is in `handoff/README.md`). Default if told "just do it": redraw the
11 outliers in the house style below.

## House style (13 icons — the standard)

- `viewBox="0 0 256 256"`.
- `<defs>` with a vertical `linearGradient id="bg"`: `#262a2e` (top) → `#17191c` (bottom).
- Plate: `<rect x="8" y="8" width="240" height="240" rx="28" fill="url(#bg)"
  stroke="<accent>" stroke-width="6"/>` where `<accent>` is the item's `Color` from
  `src/shared/ItemDefinitions.luau` (as hex).
- Art centered inside the plate, roughly 160–190 px tall, with ~30 px breathing room from
  the border. Flat-shaded shapes, 4–6 px strokes, rounded joins, one or two subtle gradient
  fills or `opacity` highlights for depth. Muted military palette (greys `#2b3036`/`#566069`/
  `#9aa4ad`) with the item's accent color as the single saturated element.
- No text. No drop shadows or filters (resvg renders them inconsistently).
- Reference examples: `vampire_serum.svg`, `kevlar_plate_carrier.svg`, `shock_coil.svg`.

In house style: adrenaline_injector, air_support_authorization, emergency_ammo_cache,
hollow_point_rounds, hunters_mark_optics, incendiary_gel, kevlar_plate_carrier,
repulsor_mine_kit, ricochet_rounds, shock_coil, shrapnel_magazine, tactical_drone_beacon,
vampire_serum.

## Outliers (11 icons — flat 64×64 glyphs, no plate)

ballistic_weave, cheap_drone_parts, combat_stimulants, field_dressing, field_manual,
high_grain_powder, lightweight_boots, military_rations, plague_rat_charm, scavenger_pouch,
signal_antenna.

Style: single-colour fill + dark `#0e2238` 2.5 px outline, no background, no gradient. They
read fine but look lighter/cartoonier than the plated set when shown side by side on the
level-up cards. The glyph *subjects* are good — keep the subject, redraw at 256 with the plate.

## Pipeline (SVG → Roblox)

1. Edit/create `assets/icons/<item_id>.svg`.
2. Render PNGs (script lives outside the repo; `@resvg/resvg-js` is installed there):

```bash
node "$HOME/svg2png-tmp/render.js" "$HOME/roguelike-arena-survivor/assets/icons" <item_id> [<item_id> ...]
```

   Writes `<item_id>.png` at 256 px wide next to the SVG. PNGs are gitignored.
3. Upload each PNG with the robloxstudio MCP `upload_asset` tool: `assetType: "Decal"`,
   `userId: 67169996` (creator PEPPERROCKET). Use the returned **image** id, not the decal id.
4. Set `IconId = "rbxassetid://<imageId>"` for the item in `src/shared/ItemDefinitions.luau`
   and update the row in `assets/icons/ASSET_IDS.md`.
5. `stylua src && selene src`, then Stop → Play in Studio and check the level-up cards
   (`DevCommand` → ForceLevelUp, or GrantItem to see the item bar). First-load lag can show
   a blank card for a second; that is not a wiring bug.
6. Commit (SVG + ItemDefinitions + ASSET_IDS) and push.

If `~/svg2png-tmp` is missing, recreate it: `mkdir ~/svg2png-tmp && cd ~/svg2png-tmp &&
npm init -y && npm i @resvg/resvg-js` and restore `render.js`:

```js
const { Resvg } = require("@resvg/resvg-js");
const fs = require("fs"), path = require("path");
const dir = process.argv[2];
for (const id of process.argv.slice(3)) {
  const svg = fs.readFileSync(path.join(dir, id + ".svg"), "utf8");
  const png = new Resvg(svg, { fitTo: { mode: "width", value: 256 } }).render().asPng();
  fs.writeFileSync(path.join(dir, id + ".png"), png);
  console.log("rendered " + id + ".png");
}
```
