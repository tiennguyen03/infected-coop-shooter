# STYLES.md — Visual Style Guide

Read this before any visual work: icons, UI, VFX, Blender assets, enemy models, maps.
Gameplay rules in [PLAN.md](PLAN.md) and tone in [LORE.md](LORE.md) win over anything here.
Performance wins over fidelity: the game must run smooth on low-end devices first.

Last updated: 2026-11-05 (icon set v2, all 24 redrawn in one style).

---

## 1. Art direction in one line

**"Field-kit low poly."** Grounded military gear and a broken world, built from big flat-shaded
facets, a muted desaturated base palette, and exactly one saturated accent color per object.
Readable at a glance, cheap to render, nothing fantasy.

What it is NOT: cartoon outlines, gradients, glossy PBR, glow filters, fine detail, neon.

Reference feel: Synty / Kenney style low-poly props, but darker and more military.

---

## 2. Master palette

Every material has three tones, used as flat facets: **l** (light, faces the key light),
**m** (mid, side faces), **d** (dark, faces away). The same hex values are used in the icon
generator, in UI code, and should be the swatches of the shared 3D palette texture.

### Base / neutrals

| Name | l | m | d | Use |
|---|---|---|---|---|
| gun (steel) | `#9aa4ae` | `#636d77` | `#3d454d` | weapons, metal parts, optics |
| dark (polymer) | `#4b5159` | `#30353b` | `#1f2327` | rubber, plastic, vests, bases |
| olive | `#8e9862` | `#636e42` | `#41492b` | crates, pouches, uniforms |
| tan (coyote) | `#c9ac7c` | `#9e835a` | `#6e5a3c` | pouches, cardboard, cords |
| brass | `#e6bd60` | `#bf9136` | `#845f20` | cartridges, labels |
| white (medical/paper) | `#f2f4f6` | `#c9ced4` | `#99a1a9` | bandages, pills, pages |
| red (blood/danger) | `#e85a5a` | `#b93434` | `#7e2020` | blood, warning stripes |

### Environment (for future 3D work; same 3-tone rule)

| Name | l | m | d | Use |
|---|---|---|---|---|
| concrete | `#a9a7a0` | `#7c7a74` | `#54524d` | walls, barriers, rubble |
| asphalt | `#5c5e62` | `#3e4044` | `#26282b` | roads, lots |
| rust | `#a8603c` | `#7a4328` | `#4d2a18` | wrecks, old steel |
| foliage (dead) | `#7f8a4a` | `#596232` | `#3a4120` | overgrowth, sandbags |
| infected skin | `#8ea383` | `#62745a` | `#3f4c3a` | Walker base tint |
| infected (runner) | `#b1b06a` | `#7f7e44` | `#53522a` | Runner yellow tint |
| infected (brute) | `#5b6a5a` | `#3b473b` | `#222a22` | Brute dark tint |

### Signal / accent colors (saturated, used sparingly)

| Name | Hex | Use |
|---|---|---|
| friendly blue | `#3fa7d6` | drones, beacons, player tech |
| warning orange | `#e87828` | fire, airstrike warning |
| objective yellow | `#e6bd60` | objective zones, extraction |
| infected green | `#78aa46` | infection, plague |
| shield blue | `#4e84c4` | shields |
| heal pink | `#d28282` | healing |

Rarity colors live in `Config.ItemRarities` (Common `170,170,170`, Uncommon `80,220,120`,
Legendary `255,75,75`). Item accents live in `ItemDefinitions.Color`; that single value is
the item's identity across icon, card, bar slot, and any 3D pickup.

### Accent derivation

Given an accent hex `c`: `l = mix(c, white, 0.30)`, `m = c`, `d = mix(c, black, 0.38)`.
The icon generator does this automatically (`tone()` in `assets/icons/build/icons.js`).

---

## 3. Lighting and shading rules (2D and 3D)

- Key light from the **top-left** (2D) / sun high and from the front-left (3D). Top faces
  are lightest, left faces mid, right/underside dark.
- **No outlines.** Shapes separate by tone contrast, not by strokes.
- **No gradients, no glow, no drop shadows, no blur.** A single flat ground-shadow ellipse is
  the only shadow in icons.
- One or two "highlight" facets (the `l` tone) are enough to sell form. Don't paint.
- Keep facet count low: if a shape needs more than ~8 polygons to read, simplify the shape.

---

## 4. Item icons (2D)

Source of truth: `assets/icons/build/icons.js`. Each icon is a small function that returns
SVG primitives; the script writes `assets/icons/<id>.svg` + `.png` (PNGs are gitignored).

### Canvas and plate

- `viewBox 0 0 256 256`, exported PNG 256×256 RGBA.
- Plate: full-bleed `#171a1e`, with a lighter diagonal facet `#1e2227` over the top-left
  half, clipped to a 24 px rounded square, plus a 3 px inner edge stroke `#2a3038`.
  In-game `UICorner` (8 px on cards, 6 px on bar slots) rounds it further, so the art must
  not rely on the plate corners.
- Ground shadow: ellipse at `cx=128, cy≈206–212`, `rx 64–96`, `ry 10–12`, `#07090b` at
  55% opacity. Objects "sit" on it with their base at `y≈196–208`.

### Subject

- One object, centered, occupying roughly 60–75% of the canvas width and height.
- Keep at least ~24 px clear from the plate edge (nothing crosses `x<24`, `x>232`,
  `y<24`, `y>232`).
- Material tones from the palette above; exactly one accent material (the item's
  `ItemDefinitions.Color`) used on the part that explains the item (fluid, lamp, stripe,
  flame, tag). Secondary saturated colors only when the subject demands it (brass, blood).
- Boxes use the shared isometric helper (`isoBox`), cylinders use `cylinder`, round things
  use `facetEllipse` (visible facets, 8–14 sides). Right axis `(0.866,-0.5)`, left axis
  `(-0.866,-0.5)`.
- No text, no letters, no logos. Stencil marks are abstract bars.
- Readability test: shrink to 40 px. If you can't name the object, simplify.

### Renderer constraints (resvg)

- Supported: `rect`, `polygon`, `polyline`, `circle`, `ellipse`, `g transform`, `opacity`.
- **Do not** use `clipPath` on groups (resvg 2.x panics), filters, masks, text, or fonts.
  Clip by geometry instead (see the ballistic weave lattice).

### Pipeline

```bash
node assets/icons/build/icons.js sheet          # render all + build/contact_sheet.png
node assets/icons/build/icons.js <id> [<id>...] # render a subset
node assets/icons/build/upload.js <id> [...]    # Open Cloud upload -> prints decal/image ids
node assets/icons/build/wire.js                 # writes IconId into ItemDefinitions + ASSET_IDS.md
```

`upload.js` reads `ROBLOX_OPEN_CLOUD_API_KEY` from the environment or from the robloxstudio
MCP entry in `~/.claude.json`. The key is never printed. The key needs **asset:read +
asset:write** for the creator (user 67169996). If uploads return `401 Invalid API Key`, the
key has expired: make a new one at create.roblox.com → Open Cloud → API Keys, paste it into
`~/.claude.json`, and restart Claude Code so the MCP server picks it up.

Use the **image** id in `IconId` (`rbxassetid://<imageId>`), not the decal id. `upload.js`
tries to resolve it over the web, but fresh assets need auth there, so `imageId` is usually
`null` in `uploaded_ids.json`. Resolve in Studio (edit mode, MCP `execute_luau`):

```lua
local d = game:GetObjects("rbxassetid://<decalId>")[1]
print(d.Texture) -- rbxassetid://<imageId>
```

then fill the `imageId` fields and run `wire.js`.

After wiring: `stylua src && selene src`, Stop → Play in Studio, `DevCommand` ForceLevelUp
to see three cards, GrantItem to see bar slots. Commit SVG sources + generator + Luau +
ASSET_IDS.md. The old AI image-prompt doc was deleted 2026-11-06; subjects live in the generator.

---

## 5. UI

- Backgrounds: `rgb(28,30,34)` panels; cards tint toward the rarity color
  (`rarity:Lerp(rgb(28,30,34), 0.82)`). Icon slots `rgb(32,34,38)`.
- Text: `rgb(240,240,240)` primary, Gotham family (`GothamBold` for names, `GothamBlack`
  for big numbers, `Gotham` for body). Rarity label in the rarity color, 12 px uppercase.
- Corners: 10 px cards/panels, 8 px icons on cards, 6 px bar slots. Strokes: rarity color,
  2 px Common / 3 px Uncommon / 4 px Legendary.
- Bars: health green→red, XP in friendly blue, shield in shield blue.
- Damage numbers: white normal, red bleed, orange burn, light blue shock, yellow crit
  (if ever added). Numbers pop and fade; no outlines heavier than 1 px.
- UI stays **code-generated** (disk is the single source of truth). No hand edits in Studio.
- Never block the center of the screen except for the level-up card row and death /
  success screens, which pause the game.

---

## 6. 3D assets (Blender → Roblox)

Project: `assets/3d/arena_survivor.blend`, generated by `assets/3d/build/build_assets.py`
(see `assets/3d/README.md`). Every asset is code; rebuild rather than hand-edit.

### Budgets (triangles, hard caps)

| Asset class | Target | Cap |
|---|---|---|
| small clutter (cans, debris, pickups) | 30–120 | 200 |
| prop (crate, barrier, sign) | 100–300 | 500 |
| weapon (held) | 300–600 | 800 |
| Infected rig (Walker/Runner) | 1,000–2,000 | 3,000 |
| Brute / elite | 2,000–3,500 | 5,000 |
| vehicle / large set piece | 1,000–3,000 | 5,000 |

Lower is always acceptable. Add triangles only where the silhouette needs them.

### Modeling rules

- **Flat shading everywhere** (Blender: Shade Flat, no Auto Smooth, no subdivision). Low
  facet counts on cylinders (8–12 sides). Hard edges are the look.
- Model in **studs**: Blender scene unit scale `0.28` so 1 Blender unit = 1 stud
  (Roblox 1 stud ≈ 0.28 m). **Scale table** (constants in the build script, 2026-11-06):
  character 5, door 7.2 x 3.6, storey 10.5, window sill 3.2 / head 7.6, chest-high cover
  4.0, ISO container 21.5 x 8.7 x 9.3, truck ~16 x 8 x 6.5. Every environment preview
  renders with the 5-stud reference beside it. A standard R15 character is ~5 studs tall; doors ~7; a crate
  ~3. Apply all transforms before export.
- Pivot: props at the bottom center; weapons at the grip point (where the hand holds it);
  characters at the floor between the feet. Forward = -Y in Blender → export with
  `-Z Forward, Y Up` so it faces -Z in Roblox.
- Naming: `snake_case` with a class prefix: `prop_ammo_crate`, `wpn_rifle_m4`,
  `inf_walker`, `env_barrier_jersey`, `pick_xp_orb`. Mesh name = file name = MeshPart name.

### Color and texture

- **One shared palette texture** for everything: a flat swatch grid (e.g. `palette.png`,
  128×128, 8×8 cells of 16 px each) holding the palette above (3 tones per material).
  Each face's UVs collapse to a single point inside its swatch. One texture ⇒ one material
  ⇒ one draw-call batch per mesh type. Keep the palette file in `assets/3d/palette.png` and
  its swatch map in `assets/3d/palette.md`.
- Single-color props may skip the texture and use the MeshPart `Color` with
  `Material = SmoothPlastic` instead; cheaper still.
- No normal maps, no roughness/metalness maps, no `SurfaceAppearance`, no transparency on
  geometry (glass = opaque tinted facets).

### Export / import

- Export FBX per asset: selected objects only, mesh only, apply scale, no animation unless
  rigging, no embedded textures (palette is uploaded once and referenced by `TextureID`).
- Import via Open Cloud `upload_asset` (Model) + `src/shared/MeshAssets.luau` templates built
  with `CreateMeshPartAsync` at server boot (steps in `assets/3d/README.md`); never through
  Rojo `model.json` (wrong scale). Each template has:
  `Anchored = true` (static), `CastShadow = false` for clutter under ~2 studs,
  `CollisionFidelity = Box` (or `Hull` for walkable geometry; never `PreciseConvex`
  for clutter), `RenderFidelity = Automatic`, `CanQuery = false` and `CanTouch = false`
  for pure decoration.
- Reuse by cloning one source MeshPart: identical `MeshId` shares geometry on the GPU.

### Performance budget (whole scene, the real priority)

- Lighting `Technology = ShadowMap` (not Future), `GlobalShadows` on; only large
  objects cast shadows. At most 4–6 dynamic lights alive at once (muzzle flashes die in
  <0.1 s).
- `StreamingEnabled = true` once maps exceed the current arena.
- Particles: palette-colored flat sprites, emit bursts (`Emit(n)`) not continuous rates;
  cap concurrent burst emitters (death bursts ≤ 1 per enemy, rate-limited at 40+ alive).
- Keep live Instance counts low: enemies ≤ 60, projectiles pooled (already done),
  decals and debris despawn within 10 s.
- Measure before and after with the MicroProfiler (MCP `capture_micro_profiler`) and the
  memory breakdown; a new asset class that costs >1 ms/frame on a mid phone is rejected.

---

## 7. Enemies (Infected) and characters

- Infected share one body style: low-poly humanoid, torn uniform/civilian blocks in the
  dark/olive/tan materials, skin in the infected tint rows above (Walker green-grey, Runner
  yellowed and 0.9× scale, Brute dark and 2× scale). Blood as flat `red.m` facets, never
  gore detail.
- Eyes: two small `infected green` facets so they read at distance in the dark.
- Build: one mesh per R15 limb inside the stock limb box, swapped onto the stock rig at boot
  (`assets/3d/README.md` > Infected bodies). Walker = olive fatigues + helmet + vest,
  Runner = tan civilian + hair + white shirt plate, Brute = dark armour + plate helmet +
  pauldrons + pack. Shipped 2026-11-06.
- The Chosen (player characters, see LORE.md): realistic silhouettes, one signature color
  patch per character (e.g. K-9 handler = tan, Epidemiologist = white, Recon = dark,
  Engineer = olive), gear in the palette, face left simple. Built 2026-11-06 as limb sets
  (`PC_CLASSES` in the build script): Assault = grey fatigues, olive plate carrier, helmet
  with NVG mount, friendly-blue patch (worn in game); K-9 = olive + tan carrier + patrol
  cap; Epidemiologist = white jacket + respirator + goggles; Recon = all dark + hood +
  boonie brim; Engineer = light-olive coveralls + orange hard hat. Previews in
  `assets/3d/build/previews/ref_pc_*.png`.
- Weapons: `gun` and `dark` materials, one accent facet (sight, mag tape) in the owning
  item's or character's accent color.

### Stage 1 "Checkpoint Delta" (shipped 2026-11-06)

Risk of Rain 2 layout rules, zombie-checkpoint dressing: open ground and five levels of
height (ground 0, Ridge/Compound 8, highway embankment 12 with a bridge over the main
road, Overlook knoll 14, Compound upper tier 16), every rise a ~40-degree embankment
(parts, not meshes: exact collision, the Infected climb them; the only overhang is the
bridge), the objective on the high ground, one landmark (the 40-stud comm tower on the
top tier) visible from anywhere, roads for orientation, extraction on a painted helipad.
The arena is 600 x 600 studs: the checkpoint in the middle (Compound, Ridge, Overlook,
highway) and four outer districts, each with its own hill and silhouette: the Suburb
(north, ruined houses on the North Bluff, a burning ruin), the Depot (east, container yard
on a concrete pad, the Depot Mound), the Scrapyard (south, wrecks and barriers, the South
Rise), the Barracks (west, parade terrace, tents, a burning ruin). The Infected spawn
around the players, so the outer districts are optional ground, not dead space.

Collision: environment meshes default to Box (cheapest, fine for crates, walls, containers,
sealed buildings). A mesh the player can stand on or walk through at an angle (the tent's
roof slope, the lattice towers) uses PreciseConvexDecomposition; thin poles (dead tree,
lamp post) use Hull. Set per mesh in `MeshAssets.MESHES.fidelity`.

Ground palette: dust
`rgb(94,88,76)`, hills `rgb(104,96,80)`, slopes `rgb(88,80,66)`, asphalt `rgb(58,60,64)`,
concrete `rgb(122,120,114)`, road paint `rgb(214,214,208)`. Layout in
`src/server/ArenaService.luau` (`HILLS`, `DRESSING`).

#### Stage 1 sky (`src/server/SkyService.luau`)

The first evening of the outbreak: a low sun through a smoke-stained sky, the city beyond
the perimeter burning. Everything is engine settings plus ~30 static parts, no skybox
textures. Lighting: ClockTime 17.6, latitude 30, Brightness 1.8, ColorShift top
`rgb(230,140,70)` / bottom `rgb(110,60,40)`, fog `rgb(176,104,66)` 260-1500. Atmosphere:
Density 0.36, Offset 0.2, Color `rgb(214,112,58)`, Decay `rgb(92,38,28)`, Glare 0.7,
Haze 6 (the haze is what turns the stock blue skybox orange; drop it and the sky goes
green-grey). Terrain Clouds: Cover 0.72, Density 0.6, Color `rgb(104,66,48)`. Outside the
walls a ring of 23 flat `DistantCity` silhouettes (`rgb(44,40,42)`, 470-560 studs out,
60-220 tall, clustered north-east) with slow smoke columns and fire glow on six of them;
`SkyService.burn(part)` puts the same fire + smoke on a dressing piece (`burning = true`
in `ArenaService.DRESSING`). Smoke is the stock `smoke_main` particle at rate 5,
14-22 s life, a light westerly drift; fire is `fire_main` with one PointLight. Budget: nine
emitters in the whole scene.

### Body animation (shipped 2026-11-06)

Mixamo motion capture retargeted onto the stock R15 rig (pipeline and clip table:
`assets/animations/README.md`). The Assault reads as a soldier: hunched low-ready idle that
scans, rifle walk, leaning sprint, shouldered aim while the trigger is held, a short recoil
per shot, a flinch on damage, a fall on death (the rig stays jointed). Upper-body clips
(aim, fire, hit, breach throw) leave the legs to the locomotion clip. Each Infected type
has its own gait (Walker shuffle, Runner sprint, Brute lumber), an attack swing and a death
fall; locomotion rate scales with ground speed so feet do not slide
(`Config.Animations.MoveClipSpeed`). The breach ghost is a Neon disc in the accent orange
(`rgb(255,150,60)`, transparency 0.75) plus a ball at the landing point; it fills the view
when the player stands inside it, so a hollow ring is a later polish item.

---

## 8. VFX and world feedback

- Objective / extraction zones: flat ring + low translucent cylinder in `objective yellow`.
- Airstrike warning: flat disc in `warning orange`, blast = expanding faceted sphere,
  no stock fire textures.
- Fire ground: faceted orange/yellow triangles on the floor, flicker by scale not by light.
- Shock: 2–3 segment jagged lines in `shield blue`, 0.1 s lifetime.
- Hunter's Mark: red chevron billboard above the target (matches the icon).

---

## 9. Checklist before committing any visual asset

1. Uses only palette hex values (plus the item's accent).
2. Flat shaded, no outline/gradient/filter.
3. Reads at the size it will be shown (40 px icon, 30 studs distance for props).
4. Within its triangle cap; MeshPart settings applied; pivot and naming correct.
5. Measured: no new per-frame cost beyond the budget above.
6. Source committed (SVG/.blend/.fbx), rendered or uploaded outputs recorded in
   `assets/icons/ASSET_IDS.md` (icons) or `assets/3d/ASSET_IDS.md` (meshes).

---

## 10. Decisions log

- 2026-11-05: Replaced the two mixed icon styles (13 "dark plate + border" + 11 flat 64 px
  glyphs) with one generated faceted set. Border color dropped in favor of the rarity
  stroke already on the cards. Generator is the source of truth, not hand-edited SVGs.
- 2026-11-05: Committed to low-poly flat-shaded 3D for all future assets with a single
  shared palette texture, driven by performance goals and the planned Blender workflow.
