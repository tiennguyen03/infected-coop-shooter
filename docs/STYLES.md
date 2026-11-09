# STYLES.md — Visual Style Guide

Read this before any visual work: icons, UI, VFX, Blender assets, enemy models, maps.
Gameplay rules in [PLAN.md](PLAN.md) and tone in [LORE.md](LORE.md) win over anything here.
Performance wins over fidelity: the game must run smooth on low-end devices first.

Last updated: 2026-11-08 (Infected posture v3: blocky lore-accuracy pass, §7).

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
| pallor (infected skin) | `#bdb5b2` | `#8f8786` | `#5e5759` | pale bruised skin: Walker, Hocker, every sheet that says `infected skin` |
| flesh (exposed / swollen) | `#dba89e` | `#b27b73` | `#7b4f50` | swollen hands, goitres, fevered throats, lesion rims (`flesh.d`), Bloat |
| bruise | `#8e7a8f` | `#65506b` | `#3f3046` | deep bruise: Brute skin, blotches on every form |
| wound | `#c4464a` | `#8e2630` | `#561620` | raw flesh: Runner skin, lesion cores, the eye rim |
| pus | `#efe2a8` | `#d2bd6c` | `#977f3c` | boils and pustules, milky eyes (`pus.l`), weep strips and soaked cloth (`pus.d`) |
| rebuilt (strain tissue) | `#dccbbb` | `#b09686` | `#73584e` | closed wounds, bone overgrowth, membranes, seams |
| strain (fluid) | `#d2e276` | `#bed73c` | `#768525` | sacs, bellies, open seams, anything about to burst; never skin |
| glass | `#5d6c78` (`glass_l`) | `#36424c` | — | vehicle and window glass; `glass_l` is the sky-reflection strip; never `dark_d` (the tyre colour) |
| paint | | maroon `#6a3a38`, navy `#4f5f73` | | faded civilian car paint (`paint_maroon`, `paint_navy`) |

Skin v2 (art director, 2026-11-07): the old green-grey / yellow / dark-green infected tints
are retired (their palette cells now hold `pallor` / `flesh` / `bruise`). Strain green lives
only where the agent is working: open seams, the Hocker's throat and sac, Bloat veins, Warden
seams. `assets/3d/palette.md` is the generated cell map (61 of 64 cells; `concrete` has its
`l`/`d` swatches for the building kit; the vehicle glass and paints were appended 2026-11-08).

### Signal / accent colors (saturated, used sparingly)

| Name | Hex | Use |
|---|---|---|
| friendly blue | `#3fa7d6` | drones, beacons, player tech |
| warning orange | `#e87828` | fire, airstrike warning |
| objective yellow | `#e6bd60` | objective zones, extraction |
| infected green | `#78aa46` | infection, plague |
| shield blue | `#4e84c4` | shields |
| heal pink | `#d28282` | healing |

Rarity is gone (loadout rework 2026-11-07): a card is a **supply** card (olive
`107,122,74`) or a **field upgrade** (`63,167,214`). Accents live in `CallInDefinitions.Color`
and `UpgradeDefinitions.Color`; that single value is the tool's identity across icon, card,
HUD strip, and any 3D prop.

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
- Material tones from the palette above; exactly one accent material (the tool's
  `CallInDefinitions.Color` / `UpgradeDefinitions.Color`) used on the part that explains the
  item (fluid, lamp, stripe, flame, tag). Secondary saturated colors only when the subject demands it (brass, blood).
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
node assets/icons/build/wire.js                 # rewrites ASSET_IDS.md from uploaded_ids.json (nothing in src/ reads icon ids yet; add IconId to CallInDefinitions / UpgradeDefinitions when cards get icons)
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

**HUD language (2026-11-08, after Prototype 2's HUD; owner direction "the UI should resemble
Prototype 2").** Research and per-element spec by the `ui-ux-designer` agent; the 18
reference screenshots it looked at are in `.superpowers/ui-refs/prototype2/` (git-ignored,
local). Code: `src/client/HudTheme.luau` holds every rule below; every HUD script builds its
ScreenGui through `HudTheme.gui` (one UIScale) and its text through `HudTheme.label`.

- **No panels behind HUD text.** Text is white (240,240,240) with a black stroke at 0.55.
  Panels only on the notification cards, the results screen and the world cards.
- **Shapes:** hard-edged rectangles, no corner radius on bars or cards. Circles only for the
  ability icons and the boss emblem. A 45-degree square is the "upgraded" mark.
- **Strokes:** 1 px. Bar outline white at 0.75; a "hot" outline (low health) is red.l at 0.
- **Palette roles:** text (240,240,240), dim text (150,154,160); health red.m (185,52,52)
  with a red.l (232,90,90) top facet (a hard-step UIGradient, the one gradient allowed on the
  HUD: §3 exception); damage trail white at 0.2; shield the white secondary bar; track
  (18,19,22) at 0.3; enemies, alerts and "returning" red.l; places, bonus targets, charges
  and "ready" objective yellow (230,189,96); squadmates friendly blue (63,167,214); menus
  (22,8,8) at 0.1 with red.m 1 px boxes and a cream (232,222,196) selected / button fill with
  dark text. No green on the HUD (green is the strain).
- **Type:** `Enum.Font` only. GothamBlack for headlines and numbers, GothamBold for HUD
  lines, Gotham for second lines. Fixed TextSize, never TextScaled: 36-40 banners and
  headers, 26 ammo, 22 mission line, 18 second lines, 16 names, 14 labels, 11-12 minimum.
  Caps for verbs, targets and labels, lowercase for linking words, the key word coloured
  with RichText (`HudTheme.tint`). Menu headers take the `//` prefix.
- **Scale and safe areas:** one UIScale per HUD ScreenGui, `clamp(viewport.Y / 1080, 0.62,
  1)`, set on ViewportSize change. 16 px edge margin. Touch-only devices (no keyboard) move
  the mission line and subtitles to top centre, clear of the thumbstick and buttons.
- **Motion:** appear 0.18 s Quad Out (fade + 8 px rise or a 40 px slide for cards),
  disappear 0.3 s fade; the health trail holds 0.35 s then shrinks 0.25 s; pulses are
  computed at 15 Hz, not tweened. Nothing on the HUD runs per frame except the crosshair
  (and the ammo bar while a reload runs).

**Layout (1080p offsets):**

| Element | Where | What |
|---|---|---|
| Health stack (`HealthBarUI`) | top left (16,12) | 400x16 red bar, white damage trail; shield 400x6 white bar under it with a "+N" tag; low health: red outline + red edge vignette pulsing; downed: dim fill, vignette held |
| Abilities (`AbilityUI`) | top left (16,44) | seven 38 px circles G / V / E / 1-4 (frag, shove, stim, the call-ins): key letter, name under (PC); cooling: white fill rising, seconds; grenades, stims and call-in charges as yellow squares under the circle, the circle dims when empty; a diamond marks an upgrade in the slot |
| Resupply (`ResupplyUI`) | top left (16,108) | 14 pt line + 240x4 bar with quarter ticks; ready: "RESUPPLY READY [5] FLARE" with the bar pulsing; inbound: "PALLET 0:14", bar drains |
| Run timer (`RunTimerUI`) | top centre (0,8) | 16 pt, no panel |
| Ammo (`LoadoutUI`) | crosshair (+40,+40) | the gun in hand 12 pt above it with "[Q] PISTOL" dim (the other gun); magazine GothamBlack 26 + " / reserve" 16 dim; yellow low, "RELOADING" + bar, red "DRY [R]"; attribute-driven |
| Arms Room (`LoadoutMenu`, hosted by `LoadoutUI` on B) | centre, 760 wide, DisplayOrder 110 (above the results) | menu style: (22,8,8) at 0.08 with a red.m 1 px box, "//ARMS ROOM" 30, a dim 12 pt rule line; columns PRIMARY / SIDEARM + GRENADE / CALL-INS of 26 px rows (name 14 bold left, designation 11 right), the pick in the cream fill with dark text, call-ins badged "[n]" by slot; the hovered item's line under the columns; cream DEPLOY LOADOUT bottom right, the server's refusal in red.l above it; height grows with the longest list |
| Mission line (`MissionLine`, driven by `ObjectiveUI` / `ExtractionUI`) | lower centre (0.5, 0.8) | "SECURE the AREA" / "HOLD the LZ" / "WAITING FOR SQUAD n/m" / red "RETURN to the LZ", a second line, a 300x3 bar; extraction outranks the objective |
| Subtitles (`BuffNoticeUI.subtitle`) | under the mission line | "CONTROL: radio line" (BuffNotice kind radio), the Warden's "HANDSET: ..." tells |
| Notification cards (`BuffNoticeUI.card`) | top right (-16,12), y 120 during a boss | dark strip, red-outlined square, bold title; pickups, picks, the flare call, an upgrade landing; max 3 |
| Boss bar (`BossBarUI`) | top right (-16,12) | name in red right-aligned, 380x16 faceted body bar ending in a round emblem (blue while stunned), six 56x6 plate bars with labels |
| Downed / K.I.A. (`RunEndUI`) | centre (0.5, 0.22) | "DOWNED" 40 red + 360x4 bleed-out bar + line; "K.I.A." + line; no panel |
| Results (`RunEndUI`) | full screen | menu style: dark red field, corner L-brackets, "//OPERATION COMPLETE" yellow or "//SQUAD WIPED" red, stats in a red-outlined box, cream READY |
| Crosshair / hit marker | centre | unchanged |

- The always-on loadout strip is gone: an upgrade shows as a card when it lands and as a
  diamond on its ability circle.
- Not built yet (designer's D4 / D5): world markers (objective, LZ, pallet diamonds with
  distance) and a squad roster; both need the server to publish positions and squad state.
- Cards in the world (pallet billboards) keep their layout.
- UI stays **code-generated** (disk is the single source of truth). No hand edits in Studio.
- Never block the centre of the screen except for the run-end screens.

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
- **No two surfaces in one plane** (owner 2026-11-08: they "clip through each other"). A
  window, panel or patch laid flush on a face flickers in Roblox. Set details 0.03+ proud;
  `Builder.finish` also pushes the smaller of any coplanar, overlapping, different-swatch
  pair 0.05 forward (`resolve_zfight`: static pieces and the city). Part-built geometry
  follows the same rule: roofs overhang their walls as eaves, floors stop inside them,
  overlapping ground patches step up 0.003 each.
- Model in **studs**: Blender scene unit scale `0.28` so 1 Blender unit = 1 stud
  (Roblox 1 stud ≈ 0.28 m). **Scale table** (constants in the build script, 2026-11-06):
  character 5, door 7.2 x 3.6, storey 10.5, window sill 3.2 / head 7.6, chest-high cover
  4.0, ISO container 21.5 x 8.7 x 9.3, truck ~16 x 8 x 6.5. The ruin v2 (2026-11-07) and the
  Part-built building kit use their own grid (`docs/LEVELS.md` B1: storey 9 / ruin 10, door
  4 x 8, window sill 3.2 / head 8.6) sized to the vault and climb heights. Every environment preview
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
- **Surface materials (2026-11-07).** Flat colour read as plastic, so surfaces now carry
  Roblox's built-in materials (engine textures: no upload, scaled down on low graphics
  settings, they also drive the footstep surface). Arena Parts get theirs from their
  colour in `ArenaService.surfaceMaterial`: dust/hills/slopes Ground, roads Asphalt,
  pads/walls Concrete, generator Metal; road paint stays SmoothPlastic. A mesh whose
  swatches are tones of one material drops the palette texture (a `TextureID` hides the
  material) and takes a `surface = { material, color }` in `MeshAssets.MESHES`: T-wall
  and jersey Concrete, rust container CorrodedMetal, olive container and lamp post Metal,
  hesco/sandbags/tent Fabric, dead tree Wood. Their small accent swatches (stencil band,
  reflectors) are lost; accepted. Multi-colour meshes (bus, humvee, ruin, towers,
  checkpoint, characters, Infected, props) keep the palette until a textured palette
  (detail painted into each swatch, real UVs) replaces the flat one.
- **Buildings and ground (2026-11-07).** The kit buildings (`docs/LEVELS.md` B) are plain
  Parts in built-in materials per type, `Config.Arena.Materials`: Concrete for cinder block
  (146,148,136), rendered shopfronts (158,148,126) and the Armoury (112,110,102); Brick
  (118,86,70) for the church; WoodPlanks (98,80,58) for the Lines' huts and the pallet
  ramps (110,88,60); CorrodedMetal (86,90,92) for the Shed; Metal (168,168,162) for
  painted panel (the Pumps) and (58,60,64) for ladders and rails; DiamondPlate (92,94,98)
  for the catwalk and the deck gantry; slabs (104,102,98) and roofs (84,82,78) Concrete.
  Ground wear is thin no-collision sheets (`ArenaService.PATCHES`): Mud (70,60,48) at the
  hill feet and as road puddles, Rock (96,92,86) in the yards, a darker Ground (74,68,58)
  verge along both roads. The rust container is darker (92,50,30). No new meshes for any
  of this.
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
  for pure decoration. A piece the body moves through or onto (bunker, humvee, ruin,
  towers, tent, checkpoint) lists **composite colliders** instead (`colliders = {{ size,
  offset, yaw?, class? }}` in design coordinates; the build prints each asset's `offset`):
  the MeshPart turns CanCollide off and `MeshAssets.addColliders` parents invisible boxes
  (or a TrussPart ladder) to it, the whole thing an atomic Model. ~256 such boxes is the
  ceiling for the stage.
- Reuse by cloning one source MeshPart: identical `MeshId` shares geometry on the GPU.
- The palette texture can fail on a client's first request ("Asset content representation
  is being generated"); a MeshPart never retries, so `src/client/PaletteController.luau`
  re-applies it once it loads. Palette meshes carry a grey base colour (rgb 118,122,128) so
  a failed texture reads grey, never black; `dressModel` removes any BodyColors.

### Performance budget (whole scene, the real priority)

- Lighting `Technology = ShadowMap` (not Future), `GlobalShadows` on; only large
  objects cast shadows: jerseys, bunkers, hesco and all but every ninth Gate T-wall cast
  none (`MeshDef.castShadow`, `Dressing.shadow`). At most 4–6 dynamic lights alive at once
  (muzzle flashes die in <0.1 s).
- Static practical lights: at most 20 in a stage and 12 inside any 150-stud circle, all
  `Shadows = false`, Range ≤ 56 (floodlight SpotLights, sodium and fire PointLights).
  Distant scenery carries no lights, only Neon (2026-11-08).
- `StreamingEnabled = true` (2026-11-07, `default.project.json`: target radius 384, min
  128). The arena terrain and the skyline (`workspace.TestArena`) are `Persistent`;
  buildings and dressing live beside it in `workspace.Buildings` / `workspace.Dressing`
  (a Persistent model's descendants never stream out), where each building, collider piece,
  enemy and bot rig is an `Atomic` Model so nothing half-streams.
- Particles: palette-colored flat sprites, emit bursts (`Emit(n)`) not continuous rates;
  cap concurrent burst emitters (death bursts ≤ 1 per enemy, rate-limited at 40+ alive).
- Keep live Instance counts low: enemies ≤ 60, projectiles pooled (already done),
  decals and debris despawn within 10 s.
- Measure before and after with the MicroProfiler (MCP `capture_micro_profiler`) and the
  memory breakdown; a new asset class that costs >1 ms/frame on a mid phone is rejected.

---

## 7. Enemies (Infected) and characters

Per-body build sheets live in [CHARACTERS.md](CHARACTERS.md) (lore developer, 2026-11-07):
the strain's two colours (`rebuilt` and `strain` rows above), the silhouette ladder, who each
form was and what it still wears. Bodies rebuilt to those sheets are listed at the end of
this section; the bullets below describe the 2026-11-06 build still worn by the rest.

- Infected share one body style: low-poly humanoid, torn uniform/civilian blocks in the
  dark/olive/tan materials, skin in the v2 rows above (Walker and Hocker `pallor`, Runner
  `wound` flayed under `rebuilt.l` tendons and 0.9× scale, Brute `bruise` and 2× scale).
  Damage is geometry, not paint: `Limb.boil` / `cluster` (pus domes with a `pus.l` head),
  `lesion` (a `flesh.d` rim round a `wound` core), `blotch` (a flat `bruise` patch). Blood as
  flat `red.m` facets only where a tear is fresh. Gore line (owner 2026-11-08 asked for
  limbs that come off): a severed limb leaves a flat raw stump (`inf_gore_stump`: `flesh.d`
  rim, `wound` face, a `rebuilt.l` bone end) and hits throw small low-poly chunks; no blood
  spray, no pools, no interior detail.
- Limb geometry v2 (2026-11-07): healthy limbs are octagonal tapered segments (`Limb.oct`,
  70-80% of the R15 box) under a rounded joint cap (`Limb.cap`: bone knob on the Infected)
  so bent joints swing through their neighbour; upper legs take a `hip_inset` collar; swollen
  limbs (Walker hands, Brute forearms) fill the box. The stock rig and clips are untouched.
- Posture v3 (2026-11-08, lore-accuracy pass, still blocky): each form stands its own way,
  baked into the limb meshes (`shift_all` / `rotate_all` hang a limb off its fixed R15 joint;
  MeshAssets offsets the part by the bounds centre, so limbs may leave their R15 box).
  Walker: right shoulder sloped 0.3 lower (wedge on the torso, own `_r` upper arm), head down
  18 deg and forward, the `foliage.d` blanket a slab on the lower torso hanging to mid-thigh
  at the back, trousers `concrete.d` (`asphalt` read black next to the shoes), screening band
  0.32 tall in `white.l` with one red stripe. Runner: upper torso pitched 20 deg forward at the
  waist, traps up to the jaw (no neck), head jutting forward and sunk, arms hung 0.45 ahead of
  the joint on forearms 0.55 longer (hands at the knees), a five-block stepped spine, dog tags
  hanging plumb. Brute: torso 2.6 x 1.2, two stepped bone slabs per shoulder rising 0.4 above
  the crown with the head sunk 0.45 in the trench, sided arms hung 0.42 outboard on forearms
  1.0 longer (fists at the shin, worn flat underneath), trousers riding low over short legs,
  the pack split in two halves. Hocker: head thrown back 22 deg about the neck, a stepped
  notch 0.44 deep down the chest front, the surgical mask a `white.l` band, knees bent 18 deg
  (thigh forward, shin back to the foot). 1,524 / 2,008 / 2,172 / 1,484 tris. Previews:
  `ref_inf_<form>.png`, `_side.png`, `_back.png`. Gore stumps sit at the joint, so on an
  offset limb (Runner, Brute arms) the stump is a little off the visible shoulder.
- Eyes: two small milky `pus.l` facets set in a `wound` rim (`wound.d` on the Runner's red
  face). Never green: the `infected green` accent is for UI/icons/VFX, not bodies.
- Hocker (2026-11-06): wears the Walker set with a caustic yellow-green throat sac
  (`strain.m`, SmoothPlastic, swells 1.8x over the 0.8 s windup); its spit is a Neon
  ball of the same colour and the puddle a flat Neon disc at 0.45 transparency. Own limb set
  (head thrown back on a split jaw, soaked shirt, surgical mask) since 2026-11-07.
- Build: one mesh per R15 limb inside the stock limb box, swapped onto the stock rig at boot
  (`assets/3d/README.md` > Infected bodies). Walker = olive fatigues + helmet + vest,
  Runner = tan civilian + hair + white shirt plate, Brute = dark armour + plate helmet +
  pauldrons + pack. Shipped 2026-11-06.
- Weller (the body the camera sits behind) is one skinned mesh since 2026-11-07: a 944-tri
  body with the R15 bone tree over a hidden 15-part rig, so elbows, knees and the waist
  bend as a band of skin instead of a box corner swinging through the next limb
  (`assets/3d/README.md` > Skinned Weller). Helmet and carrier stay rigid gear. One extra
  skinned draw per player; the hidden limbs do not render.
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
- Redesign (2026-11-07, CHARACTERS.md): the Walker is the civilian and the Runner the
  garrison soldier (swapped from the bullets above); the Assault is Isaac Weller, a fifth
  Chosen; all five wear the same `dark` Pike carrier with a coloured square on the left
  shoulder and back (Weller blue, Cole tan, Reyes white, Cross black/grey border, Kane
  orange). Index hosts: **the Warden** built 2026-11-07 (`inf_warden_*` 2,588 tris + six
  `inf_warden_plate_*` 572 tris, cap 5,000): `bruise` skin on the Brute bone shelf, olive
  MP uniform, `white` brassard with `dark.d` bars on the right arm, `dark` riot plates
  with `dark.l` edges, `gun.l` visor and shield window, `strain.l` seams and eyes, one
  red handset lamp. Plates are separate welded MeshParts so a break is geometry leaving
  the body; the crack state is a HUD pip (objective yellow), not an overlay mesh. The
  boss bar (`BossBarUI`) uses the §5 panel grey, `wound` for the body, `gun.l` for a
  plate, objective yellow for a crack and a tell, friendly blue for the stun.
  Rebuilt to the sheets so far: **Walker, Runner, Brute, Hocker** (`inf_<type>_*`,
  36 limbs; the first rebuild was uploaded and verified in a playtest 2026-11-07; skin v2 +
  limb geometry v2 uploaded and verified the same day (palette v4 texture, 23 changed limbs;
  ids in `assets/3d/ASSET_IDS.md`); posture v3 2026-11-08 (29 limbs re-uploaded, above);
  1.5-2.2k tris per body against the sheet targets 1.8k / 2.2k / 3.0k / 2.2k. Upload order matters when the palette changes: `palette.png` first, then the
  `inf_*` FBX, then `MeshAssets` size/offset from the `dims`/`offset` lines the build
  prints; limbs painted with new cells on an old texture render those cells black, while the new
  texture on the old limbs only recolours cells 25-27), and **the five Chosen** (`PC_CLASSES` rebuilt with the shared Pike carrier; Weller's
  set uploaded and worn in game, the other four built and previewed). Not built: Bloat,
  Shedder, Crawler, Kite, Growth, the Index hosts, Kilo.

### Stage 1 "Checkpoint Delta" (shipped 2026-11-06, relaid 2026-11-07)

Layout as of 2026-11-07 follows [LEVELS.md](LEVELS.md) section A (insert and extract on the
LZ, the Gate T-wall line and bus line to the south, the Pens hesco ring to the west); the
notes below describe the pieces and the dressing rules, which did not change. New piece:
`env_bus` (42 x 12.5 x 10, white with a steel stripe, one window blown out).

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
the perimeter burning. Gloomy but readable: an Infected reads as a shape at 90 studs (owner
2026-11-08: "a little too gloomy"; tuned live in Studio). Everything is engine settings plus
static parts, no skybox textures. Lighting: ClockTime 16.9, latitude 30, Brightness 2.3,
Ambient `rgb(96,84,80)`, OutdoorAmbient `rgb(150,126,112)`, ColorShift top
`rgb(255,176,110)` / bottom `rgb(96,72,62)`, Exposure 0.15, EnvironmentDiffuse 0.8 /
Specular 0.25, ShadowSoftness 0.4; no Fog settings (an Atmosphere overrides them).
Atmosphere: Density 0.3, Offset 0.15, Color `rgb(205,104,58)`, Decay `rgb(110,44,32)`,
Glare 0.5, Haze 5.2 (the haze turns the stock blue skybox orange; below ~4 the sky goes
yellow-brown). ColorCorrection Brightness 0.03, Contrast 0.14, Tint `rgb(255,240,228)`;
Bloom 0.35 / 20 / threshold 1.7 (Neon, fire and the sun bloom; geometry does not). Terrain
Clouds: Cover 0.65, Density 0.5, Color `rgb(128,86,64)`. Outside the
perimeter fence (`docs/LEVELS.md` A15: no solid walls since 2026-11-07; the ground and
scenery run on past it to 700) the `DistantCity`: 23 modelled towers 470-560 studs out,
clustered north-east (owner 2026-11-08: the flat slabs looked "goofy"; `SkyService.SKYLINE`).
Six types from `assets/3d/build/city.py` (office slab, apartment block, stepped deco tower,
glass curtain wall, a burned-out shell, a wide mid-rise), each built floor by floor on the
character's grid (storey 10, bay 4-9): glass core, a spandrel ring per storey, piers,
setbacks, parapet, rooftop plant / tanks / masts, 960-1,870 tris. Placed at a uniform
0.75-1.05 scale (a storey still reads 8-12) with the long face toward the arena and a yaw
jitter. Each tower's `_lit` twin mesh holds its lit windows, one slab per window, painted
Neon: sodium in most, fluorescent in a quarter, fire orange in the six burning ones (smoke
and fire at 60% height). 46 MeshParts, ~42k tris in all, no lights, no collision or queries;
`SkyService.burn(part)` puts the same fire + smoke on a dressing piece (`burning = true`
in `ArenaService.DRESSING`). Smoke is the stock `smoke_main` particle at rate 5,
14-22 s life, a light westerly drift; fire is `fire_main`, with a PointLight (Range 36,
Brightness 1.6, no shadows) only on the burning dressing in the arena: the skyline fires'
glow is the particles' LightEmission. Budget: nine emitters in the whole scene.

### Body animation (shipped 2026-11-06)

Mixamo motion capture retargeted onto the stock R15 rig (pipeline and clip table:
`assets/animations/README.md`). The Assault reads as a soldier: hunched low-ready idle that
scans, rifle jog and sprint that blend four directions so strafing and backpedalling look
right (2026-11-06), shouldered aim while the trigger is held, a short recoil
per shot, a flinch on damage, a fall on death (the rig stays jointed). Upper-body clips
(aim, fire, hit, breach throw) leave the legs to the locomotion clip. Each Infected type
has its own gait (Walker shuffle, Runner sprint, Brute lumber), an attack swing and a death
fall; locomotion rate scales with ground speed so feet do not slide
(`Config.Animations.MoveClipSpeed`). The breach ghost is a Neon disc in the accent orange
(`rgb(255,150,60)`, transparency 0.75) plus a ball at the landing point; it fills the view
when the player stands inside it, so a hollow ring is a later polish item.

---

## 8. VFX and world feedback

- Tracers (2026-11-07): a 0.12-stud Neon line in `rgb(255,214,120)` from muzzle to impact,
  alive `Config.Weapon.TracerDuration` (0.06 s), client-side only. Headshot numbers are
  white and a third larger than hit numbers.

- Objective / extraction zones: flat ring + low translucent cylinder in `objective yellow`.
- Airstrike warning: flat disc in `warning orange`, blast = expanding faceted sphere,
  no stock fire textures.
- Fire ground: faceted orange/yellow triangles on the floor, flicker by scale not by light.
- Shock: 2–3 segment jagged lines in `shield blue`, 0.1 s lifetime.
- Hunter's Mark: red chevron billboard above the target (matches the icon).
- Camera kick (2026-11-09, `CameraController`): every own shot pushes the view up
  `Config.Weapons.<id>.Kick.Pitch` degrees plus a random +/- `Yaw`, eased back over `Recover`
  (0.12 s, ~95% gone) on top of the aim, so the aim never drifts. M16A4 0.9 / 0.3, MP5
  0.5 / 0.2, M249 1.1 / 0.5, Mossberg 4.0 / 0.8, M110 2.6 / 0.4, M17 1.6 / 0.3; aiming down
  sights scales it by `Config.Camera.Kick.AdsScale` (0.6).
- Blast shake (2026-11-09): every server blast flash (frag, Hammer, Anvil, Shrike burst,
  Tripline) carries the CollectionService tag `Attributes.BlastTag` ("Blast") and a
  `BlastPower` (`Config.Camera.Shake.Power`: Frag 3, Hammer 3.5, Anvil 6, Shrike 2, Tripline
  3 degrees). The client adds `Rules/Feel.shake` (linear falloff to 0 at 60 studs from the
  camera focus), sums blasts up to a 6-degree cap, decays over 0.45 s and jitters pitch and
  roll by it. The Anvil also sets `BlastGlobal` (1.0) felt anywhere on the map.

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
- 2026-11-07: Owner wants texture, not plain colour. Built-in Roblox materials on the arena
  Parts and on one-material meshes (§6 "Color and texture"); measured 60 fps, no frame
  cost. Next: a textured palette for the multi-colour meshes.
- 2026-11-07: Owner direction for the Infected: no "zombie green". Built as skin v2 and
  uploaded (§2 rows, §7): pallor / flesh / bruise / wound / pus, boils, lesions and blotches
  as geometry, milky eyes in a wound rim; `rebuilt`/`strain` stay the strain's two colours,
  strain only on seams and the Hocker's throat. Limbs went octagonal and tapered with joint
  caps at the same time (§7).
- 2026-11-08: Owner: too gloomy, and "redo all the cars". Sun raised, haze thinned,
  ColorCorrection and a threshold-1.7 Bloom added (Neon and fire only, not a glow filter on
  geometry); the skyline got lit windows and crowns, its PointLights went. Cars rebuilt to
  the character's scale from extruded side profiles (`assets/3d/build/props.py`: sedan,
  hatch, pickup, van, plus an army cargo truck you crawl under), with real glass
  (`glass` rows); every small set piece moved into `props.py`.
- 2026-11-08: Owner: background buildings "goofy", and pieces "clipping through each
  other". The skyline is now modelled towers (`city.py`) with lit-window twins instead of
  slabs, Neon bars and a window texture (`city_windows.py` retired). Clipping was two
  things: coplanar faces flickering (172 spots in 13 meshes, fixed in the generator and
  re-uploaded; roof and floor edges in the Part buildings) and pieces placed inside each
  other (light tower in the checkpoint, wire through a generator, a container on a ramp,
  body bags, the Screening Block desk in the stairs), all moved.
- 2026-11-08: Limbs fall off when shot (owner), with a flat stump and chunks (gore line
  above). A rounded low-poly Infected redesign was built and tried the same day; the owner
  prefers the blocky Roblox bodies ("I like the regular blocky body"), so the v2 blocky sets
  stay. The lore-accuracy pass on them is built (posture v3, §7).
