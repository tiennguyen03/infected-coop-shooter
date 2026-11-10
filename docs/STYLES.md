# STYLES.md — Visual Style Guide

Read this before any visual work: icons, UI, VFX, Blender assets, enemy models, missions.
Gameplay rules in [PLAN.md](PLAN.md) and tone in [LORE.md](LORE.md) win over anything here.
Performance wins over fidelity: the game must run smooth on low-end devices first. What
shipped when is in [HISTORY.md](HISTORY.md).

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
generator, in UI code, and in the shared 3D palette texture.

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

### Environment and bodies (same 3-tone rule)

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

No zombie green on skin (owner). Strain green lives only where the agent is working: open
seams, the Hocker's throat and sac, Bloat veins, Warden seams. `assets/3d/palette.md` is the
generated cell map (61 of 64 cells); rows are only appended or replaced in place.

### Signal / accent colors (saturated, used sparingly)

| Name | Hex | Use |
|---|---|---|
| friendly blue | `#3fa7d6` | squadmates, beacons, player tech |
| warning orange | `#e87828` | fire, strike warning |
| objective yellow | `#e6bd60` | objective zones, extraction |
| infected green | `#78aa46` | infection, plague (UI / icons / VFX only, never bodies) |
| shield blue | `#4e84c4` | shields |
| heal pink | `#d28282` | healing |

There is no rarity. A card is a **supply** card (olive `107,122,74`) or a **field upgrade**
(`63,167,214`). Accents live in `CallInDefinitions.Color` and `UpgradeDefinitions.Color`; that
one value is the tool's identity across icon, card, HUD and any 3D prop.

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

## 4. Icons (2D)

Source of truth: `assets/icons/build/icons.js`. Each icon is a small function that returns
SVG primitives; the script writes `assets/icons/<id>.svg` + `.png` (PNGs are gitignored).
Icons show on call-in and field-upgrade cards through `IconId` on each
`CallInDefinitions` / `UpgradeDefinitions` row.

### Canvas and plate

- `viewBox 0 0 256 256`, exported PNG 256×256 RGBA.
- Plate: full-bleed `#171a1e`, with a lighter diagonal facet `#1e2227` over the top-left
  half, clipped to a 24 px rounded square, plus a 3 px inner edge stroke `#2a3038`.
  The art must not rely on the plate corners.
- Ground shadow: ellipse at `cx=128, cy≈206–212`, `rx 64–96`, `ry 10–12`, `#07090b` at
  55% opacity. Objects "sit" on it with their base at `y≈196–208`.

### Subject

- One object, centered, occupying roughly 60–75% of the canvas width and height.
- Keep at least ~24 px clear from the plate edge (nothing crosses `x<24`, `x>232`,
  `y<24`, `y>232`).
- Material tones from the palette above; exactly one accent material (the tool's `Color`)
  used on the part that explains the item (fluid, lamp, stripe, flame, tag). Secondary
  saturated colors only when the subject demands it (brass, blood).
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
node assets/icons/build/wire.js                 # rewrites assets/icons/ASSET_IDS.md from uploaded_ids.json
```

`upload.js` reads `ROBLOX_OPEN_CLOUD_API_KEY` from the environment or from the robloxstudio
MCP entry in `~/.claude.json` (never printed; needs asset:read + asset:write). It uploads as
user 67169996 (`ROBLOX_CREATOR_USER_ID`); game assets belong to the group (`groupId`
270506601, [OWNER.md](OWNER.md)). `401 Invalid API Key` means the key expired: make a new
one at create.roblox.com → Open Cloud → API Keys, paste it into `~/.claude.json`, restart
Claude Code.

Use the **image** id in `IconId` (`rbxassetid://<imageId>`), not the decal id. Fresh assets
usually leave `imageId` `null` in `uploaded_ids.json`; resolve it in Studio edit mode (MCP
`execute_luau`), fill the field, run `wire.js`:

```lua
local d = game:GetObjects("rbxassetid://<decalId>")[1]
print(d.Texture) -- rbxassetid://<imageId>
```

Then paste the image id into the definition row, Stop → Play, and check the card. Commit
SVG sources + generator + Luau + ASSET_IDS.md.

---

## 5. UI

**HUD language: Prototype 2's HUD, adapted to a squad shooter** (owner). The
`ui-ux-designer` agent owns the spec; its reference screenshots are in
`.superpowers/ui-refs/prototype2/` (git-ignored, local). Code: `src/client/HudTheme.luau`
holds every rule below; every HUD script builds its ScreenGui through `HudTheme.gui` (one
UIScale) and its text through `HudTheme.label`.

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

- No always-on loadout strip: an upgrade shows as a card when it lands and as a diamond on
  its ability circle.
- Not built yet: world markers (objective, LZ, pallet diamonds with distance) and a squad
  roster; both need the server to publish positions and squad state.
- Cards in the world (pallet billboards) keep their layout.
- UI stays **code-generated** (disk is the single source of truth). No hand edits in Studio.
- Never block the centre of the screen except for the run-end screens.

---

### The Arms Room counter (2026-11-09)

The rack (`docs/sprints/LOBBY_V1_FALLOW.md` > Arms Room counter) is a wall behind a wire cage,
not a lit display: no spotlights, turntables or display lighting. The one feedback is the
hovered gun sliding 0.6 studs off its pegs with a faint yellow rim (`Highlight`, fill 0.85,
outline 0.3, `HudTheme.Color.Yellow`). The card follows the HUD: `HudTheme` track panel and
outline, GothamBlack name, dim designation, yellow ON YOUR RECORD, stat bars as a 6 px white track
with a yellow fill. BUY and a price in MERITS may show (owner, 2026-11-09); words never used on it: sell,
lock, unlock, shop, store, wares.

## 6. 3D assets (Blender → Roblox)

Project: `assets/3d/arena_survivor.blend`, generated by `assets/3d/build/build_assets.py`
and the per-asset files beside it (see `assets/3d/README.md`). Every asset is code; rebuild
rather than hand-edit. Design new bodies in live Blender and look at them before porting.

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
- **No two surfaces in one plane** (owner: nothing clips or flickers). A window, panel or
  patch laid flush on a face flickers in Roblox. Set details 0.03+ proud;
  `Builder.finish` also pushes the smaller of any coplanar, overlapping, different-swatch
  pair 0.05 forward (`resolve_zfight`). Part-built geometry follows the same rule: roofs
  overhang their walls as eaves, floors stop inside them, overlapping ground patches step
  up 0.003 each. No piece placed inside another.
- Model in **studs**: Blender scene unit scale `0.28` so 1 Blender unit = 1 stud
  (Roblox 1 stud ≈ 0.28 m). **Scale table** (constants in the build script): character 5,
  door 7.2 x 3.6, storey 10.5, window sill 3.2 / head 7.6, chest-high cover 4.0, ISO
  container 21.5 x 8.7 x 9.3, truck ~16 x 8 x 6.5. The ruin and the Part-built building kit
  use the kit grid ([LEVELS.md](LEVELS.md) B1: storey 9 / ruin 10, door 4 x 8, window sill
  3.2 / head 8.6), sized to the vault and climb heights. Every environment preview renders
  with the 5-stud reference beside it. Apply all transforms before export.
- Pivot: props at the bottom center; weapons at the grip point (where the hand holds it);
  characters at the floor between the feet. Forward = -Y in Blender → export with
  `-Z Forward, Y Up` so it faces -Z in Roblox.
- Naming: `snake_case` with a class prefix: `prop_ammo_crate`, `wpn_rifle`, `inf_walker_head`,
  `env_barrier_jersey`, `pc_assault_hand`. Mesh name = file name = MeshPart name.

### Color and texture

- **One shared palette texture** for everything: `assets/3d/palette.png`, 128×128, 8×8
  cells of 16 px, 3 tones per material, swatch map in `assets/3d/palette.md`. Each face's UVs
  collapse to a single point inside its swatch. One texture ⇒ one material ⇒ one draw-call
  batch per mesh type.
- **Surface materials.** Flat colour read as plastic, so surfaces carry Roblox's built-in
  materials (engine textures: no upload, scaled down on low graphics settings, they also
  drive the footstep surface). Arena Parts get theirs from their colour in
  `ArenaService.surfaceMaterial`: dust/hills/slopes Ground, roads Asphalt, pads/walls
  Concrete, generator Metal; road paint stays SmoothPlastic. A mesh whose swatches are tones
  of one material drops the palette texture (a `TextureID` hides the material) and takes a
  `surface = { material, color }` in `MeshAssets.MESHES`: T-wall and jersey Concrete, rust
  container CorrodedMetal, olive container and lamp post Metal, hesco/sandbags/tent Fabric,
  dead tree Wood (their small accent swatches are lost; accepted). Multi-colour meshes
  (vehicles, ruin, towers, checkpoint, bodies, props) keep the palette.
- **Buildings and ground.** The kit buildings ([LEVELS.md](LEVELS.md) B) are plain Parts in
  built-in materials per type, `Config.Arena.Materials`: Concrete for cinder block
  (146,148,136), rendered shopfronts (158,148,126) and the Armoury (112,110,102); Brick
  (118,86,70) for the church; WoodPlanks (98,80,58) for the Lines' huts and the pallet
  ramps (110,88,60); CorrodedMetal (86,90,92) for the Shed; Metal (168,168,162) for
  painted panel (the Pumps) and (58,60,64) for ladders and rails; DiamondPlate (92,94,98)
  for the catwalk and the deck gantry; slabs (104,102,98) and roofs (84,82,78) Concrete.
  Ground wear is thin no-collision sheets (`ArenaService.PATCHES`): Mud (70,60,48), Rock
  (96,92,86), a darker Ground (74,68,58) verge. Base ground: dust `rgb(94,88,76)`, hills
  `rgb(104,96,80)`, slopes `rgb(88,80,66)`, asphalt `rgb(58,60,64)`, concrete
  `rgb(122,120,114)`, road paint `rgb(214,214,208)`. The rust container is darker
  (92,50,30).
- No normal maps, no roughness/metalness maps, no `SurfaceAppearance`, no transparency on
  geometry (glass = opaque tinted facets).

### Export / import

- Export FBX per asset: selected objects only, mesh only, apply scale, no animation unless
  rigging, no embedded textures (palette is uploaded once and referenced by `TextureID`).
- Import via Open Cloud `upload_asset` (Model) + `src/shared/MeshAssets.luau` templates built
  with `CreateMeshPartAsync` at server boot (steps in `assets/3d/README.md`); never through
  Rojo `model.json` (wrong scale). Each template has:
  `Anchored = true` (static), `CastShadow = false` for clutter under ~2 studs,
  `CollisionFidelity = Box` (or `Hull` for thin poles: dead tree, lamp post; never
  `PreciseConvex`), `RenderFidelity = Automatic`, `CanQuery = false` and `CanTouch = false`
  for pure decoration. A piece the body moves through or onto (bunker, humvee, ruin,
  towers, tent, checkpoint, vehicles) lists **composite colliders** instead (`colliders =
  {{ size, offset, yaw?, class? }}` in design coordinates; the build prints each asset's
  `offset`): the MeshPart turns CanCollide off and `MeshAssets.addColliders` parents
  invisible boxes (or a TrussPart ladder) to it, the whole thing an atomic Model. 256 such
  boxes is the ceiling for a mission (`Config.Arena.ColliderBudget`).
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
- Static practical lights: at most 20 in a mission and 12 inside any 150-stud circle, all
  `Shadows = false`, Range ≤ 56 (floodlight SpotLights, sodium and fire PointLights).
  Distant scenery carries no lights, only Neon.
- `StreamingEnabled = true` (`default.project.json`: target radius 384, min 128). The arena
  terrain and the skyline (`workspace.TestArena`) are `Persistent`; buildings and dressing
  live beside it in `workspace.Buildings` / `workspace.Dressing` (a Persistent model's
  descendants never stream out), where each building, collider piece, enemy and bot rig is
  an `Atomic` Model so nothing half-streams.
- Particles: palette-colored flat sprites, emit bursts (`Emit(n)`) not continuous rates;
  cap concurrent burst emitters (death bursts ≤ 1 per enemy, rate-limited at 40+ alive).
- Keep live Instance counts low: enemies ≤ 60, projectiles pooled, decals and debris despawn
  within 10 s.
- Measure before and after with the MicroProfiler (MCP `capture_micro_profiler`) and the
  memory breakdown; a new asset class that costs >1 ms/frame on a mid phone is rejected.

---

## 7. Enemies (Infected) and characters

Per-body build sheets live in [CHARACTERS.md](CHARACTERS.md): who each form was, what it
still wears, the silhouette ladder, the strain's two colours (`rebuilt`, `strain`).

**The Infected are blocky Roblox bodies** (owner: a rounded sculpted redesign was built and
rejected 2026-11-08). One mesh per R15 limb swapped onto the stock rig
(`assets/3d/README.md` > Infected and player bodies), built in `build_assets.py`
(`INFECTED_TYPES`). Built: Walker, Runner, Brute, Hocker, and the Warden (`build/warden.py`).
Not built: Bloat, Shedder, Crawler, Kite, Growth, the other Index hosts, Kilo.

- Skin from the §2 body rows: Walker and Hocker `pallor`, Runner `wound` flayed under
  `rebuilt.l` tendons (0.9× scale), Brute `bruise` (2× scale). Damage is geometry, not paint:
  `Limb.boil` / `cluster` (pus domes with a `pus.l` head), `lesion` (a `flesh.d` rim round a
  `wound` core), `blotch` (a flat `bruise` patch). Blood as flat `red.m` facets only where a
  tear is fresh.
- Eyes: two small milky `pus.l` facets in a `wound` rim (`wound.d` on the Runner's red face).
  Never green.
- Limbs: healthy limbs are octagonal tapered segments (`Limb.oct`, 70-80% of the R15 box)
  under a rounded joint cap (`Limb.cap`: a bone knob) so bent joints swing through their
  neighbour; upper legs take a `hip_inset` collar; swollen limbs (Walker hands, Brute
  forearms) fill the box.
- Posture is baked into the limb meshes (`shift_all` / `rotate_all` hang a limb off its
  fixed R15 joint; MeshAssets offsets the part by the bounds centre, so limbs may leave
  their R15 box). Walker (the civilian): right shoulder sloped 0.3 lower, head down 18 deg
  and forward, a `foliage.d` blanket slab to mid-thigh at the back, `concrete.d` trousers,
  a `white.l` screening band with one red stripe. Runner (the garrison soldier): upper torso
  pitched 20 deg forward, traps up to the jaw, head jutting and sunk, arms hung 0.45 ahead on
  forearms 0.55 longer (hands at the knees), a stepped spine, dog tags hanging plumb. Brute:
  torso 2.6 x 1.2, stepped bone slabs per shoulder rising 0.4 above the crown with the head
  sunk 0.45, arms hung 0.42 outboard on forearms 1.0 longer (fists at the shin), trousers
  low over short legs, the pack split in two. Hocker: head thrown back 22 deg on a split
  jaw, a stepped notch down the chest, a `white.l` surgical mask, soaked shirt, knees bent
  18 deg. 1,524 / 2,008 / 2,172 / 1,484 tris (caps in `BODY_TRI_CAP`). Previews:
  `ref_inf_<form>.png`, `_side.png`, `_back.png`.
- Hocker sac: `strain.m` SmoothPlastic, swells 1.8x over the 0.8 s windup; its spit is a
  Neon ball of the same colour and the puddle a flat Neon disc at 0.45 transparency.
- Gore (owner: limbs come off when shot): a severed limb leaves a flat raw stump
  (`inf_gore_stump`: `flesh.d` rim, `wound` face, a `rebuilt.l` bone end) and hits throw
  small low-poly chunks; no blood spray, no pools, no interior detail. Stumps sit at the
  joint, so on an offset limb (Runner, Brute arms) the stump is a little off the shoulder.
- **The Warden** (Index host, 2,588 tris + six plates 572, cap 5,000): `bruise` skin on the
  Brute bone shelf, olive MP uniform, `white` brassard with `dark.d` bars on the right arm,
  `dark` riot plates with `dark.l` edges, `gun.l` visor and shield window, `strain.l` seams
  and eyes, one red handset lamp. Plates are separate welded MeshParts so a break is
  geometry leaving the body; the crack state is a HUD pip (objective yellow), not a mesh.
  The boss bar uses `wound` for the body, `gun.l` for a plate, objective yellow for a crack
  and a tell, friendly blue for the stun.

**Players are anonymous Pike soldiers** (Pike One to Four; bots Two to Four in solo). Every
player and bot wears the one limb set `pc_assault_*` (grey fatigues, `dark` Pike carrier,
helmet with NVG mount, friendly-blue shoulder patch), swapped on by
`MeshAssets.dressModel`; the forearms and shins taper with joint caps. The Chosen are
retired: the build script still builds four more limb sets (`PC_CLASSES` k9 / epi / recon /
engineer) that the game never loads, and the skinned body (`pc_assault_skinned` + gear) is
switched off (`Config.Player.SkinnedBody = false`, see `assets/3d/README.md`).

- Weapons: `gun` and `dark` materials, one accent facet (sight, mag tape) in the owning
  item's accent color.

### Mission 1 "Checkpoint Delta"

Layout, landmarks, traversal and dressing rules are in [LEVELS.md](LEVELS.md) A. Style
intent: open ground and several levels of height, one landmark (the comm tower) visible from
anywhere, roads for orientation, extraction on a painted helipad. Layout code is
`src/server/ArenaService.luau`.

#### Sky and skyline (`src/server/SkyService.luau`)

The first evening of the outbreak: a low sun through a smoke-stained sky, the city beyond
the perimeter burning. Gloomy but readable: an Infected reads as a shape at 90 studs.
Everything is engine settings plus static parts, no skybox textures. Lighting: ClockTime
16.9, latitude 30, Brightness 2.3, Ambient `rgb(96,84,80)`, OutdoorAmbient
`rgb(150,126,112)`, ColorShift top `rgb(255,176,110)` / bottom `rgb(96,72,62)`, Exposure
0.15, EnvironmentDiffuse 0.8 / Specular 0.25, ShadowSoftness 0.4; no Fog settings (an
Atmosphere overrides them). Atmosphere: Density 0.3, Offset 0.15, Color `rgb(205,104,58)`,
Decay `rgb(110,44,32)`, Glare 0.5, Haze 5.2 (below ~4 the sky goes yellow-brown).
ColorCorrection Brightness 0.03, Contrast 0.14, Tint `rgb(255,240,228)`; Bloom 0.35 / 20 /
threshold 1.7 (Neon, fire and the sun bloom; geometry does not). Terrain Clouds: Cover 0.65,
Density 0.5, Color `rgb(128,86,64)`.

The skyline is modelled towers, never flat slabs (owner). `DistantCity`: 23 towers 470-560
studs out, clustered north-east (`SkyService.SKYLINE`), six types from
`assets/3d/build/city.py`, each built floor by floor on the character's grid (storey 10, bay
4-9), 960-1,870 tris, placed at 0.75-1.05 scale with the long face toward the arena. Each
tower's `_lit` twin holds its lit windows as Neon slabs: sodium in most, fluorescent in a
quarter, fire orange in the six burning ones (smoke and fire at 60% height). 46 MeshParts,
### The Fallow, the lobby ship (art pass 2026-11-09, uploaded 2026-11-09)

Build sheet and decisions: `docs/sprints/LOBBY_V1_FALLOW.md` > Ship art; meshes in
`assets/3d/build/fallow.py`. Read: a carrier because the deck overhangs the hull (sponsons,
catwalks, safety nets), the bow tapers and flares under a square deck end, and the island
steps up to bridge, Pri-Fly, funnels and mast. Shells are one-material meshes in Metal: hull
(100,106,112), island (116,122,128), lighter so it stands off the Asphalt deck; trims keep the
palette. The one loud mark is the HRD spray (island, both bow sides, the deck's bow end);
canvas tubs (`tan_d`), raft canisters (`white_l`) and the hose station (`red`) are small
accents. The v1 `BridgeWindows` Part (Glass, transparency 0.1) broke the no-transparency rule;
the island mesh replaces it with opaque `glass` and FallowArt removes the Part. Budget: ~8,000
tris for the whole ship with 18 instanced catwalk bays (cap 18,000).

### Lantern, the lift bird (art pass 2026-11-09, uploaded 2026-11-09)

Canon: `docs/LORE.md` > Lantern; sheet and decisions: `docs/sprints/LOBBY_V1_FALLOW.md` >
Lantern; meshes in `assets/3d/build/lantern.py`. Vehicles take the prefix `veh_` (collection
`Vehicles`). Read from 40 studs: the dark open door (the interior is `dark` / `dark_d` on
purpose), the long thin boom with a fin taller than the rotor, the amber lamp. Shell Metal
(104,110,80), faded olive; trim on the palette; the one loud mark is HRD, the number is white
stencil. 1,912 tris a bird with both rotors (vehicle cap 5,000). Light: one PointLight per bird
(amber, Range 12, Shadows off), on only while its spot counts down. **Exception to "no
transparency on geometry"**: the rotor blur discs (two flat cylinders a bird, fading
in to 0.8 transparent over the last 6 s before lift while the blades fade to 0.6, never out;
`Rules/RotorBlur`) are VFX, like the breach ghost.

~42k tris, no lights, no collision or queries. `SkyService.burn(part)` puts the same fire +
smoke on a dressing piece (`burning = true` in `ArenaService.DRESSING`). Smoke is the stock
`smoke_main` particle at rate 5, 14-22 s life, a light westerly drift; fire is `fire_main`,
with a PointLight (Range 36, Brightness 1.6, no shadows) only on burning dressing in the
arena. Budget: nine emitters in the whole scene.

### Body animation

Mixamo motion capture retargeted onto the stock R15 rig (pipeline and clip table:
`assets/animations/README.md`). The soldier: hunched low-ready idle that scans, rifle jog and
sprint that blend four directions, shouldered aim while the trigger is held, a short recoil
per shot, a flinch on damage, a fall on death. Upper-body clips (aim, fire, hit, reload,
throw) leave the legs to the locomotion clip. Each Infected type has its own gait, attack,
flinch and death; locomotion rate scales with ground speed so feet do not slide
(`Config.Animations.MoveClipSpeed`). The grenade ghost (hold G) is a Neon ring in the accent
orange (`rgb(255,150,60)`) plus a ball at the landing point.

---

## 8. VFX and world feedback

- Tracers: a 0.12-stud Neon line in `rgb(255,214,120)` from muzzle to impact, alive
  `Config.Weapon.TracerDuration` (0.06 s), client-side only. Headshot numbers are white and
  a third larger than hit numbers.
- Objective / extraction zones: flat ring + low translucent cylinder in `objective yellow`.
- Strike warning: flat disc in `warning orange`, blast = expanding faceted sphere,
  no stock fire textures.
- Fire ground: faceted orange/yellow triangles on the floor, flicker by scale not by light.
- Camera kick (`CameraController`): every own shot pushes the view up
  `Config.Weapons.<id>.Kick.Pitch` degrees plus a random +/- `Yaw`, eased back over `Recover`
  (0.12 s, ~95% gone) on top of the aim, so the aim never drifts. M16A4 0.9 / 0.3, MP5
  0.5 / 0.2, M249 1.1 / 0.5, Mossberg 4.0 / 0.8, M110 2.6 / 0.4, M17 1.6 / 0.3; aiming down
  sights scales it by `Config.Camera.Kick.AdsScale` (0.6).
- Blast shake: every server blast flash carries the CollectionService tag
  `Attributes.BlastTag` ("Blast") and a `BlastPower` from that grenade's or call-in's own
  Config block (`ShakePower`: Frag 3, Hammer 3.5, Anvil 6, Shrike 2, Tripline 3 degrees;
  `Config.Camera.Shake.DefaultPower` 2.5 for a call-in that names none, so loadout changes
  need no camera edits). The client adds `Rules/Feel.shake` (linear falloff to 0 at 60 studs
  from the camera focus), sums blasts up to a 6-degree cap, decays over 0.45 s and jitters
  pitch and roll by it. A block with `ShakeGlobal` (the Anvil, 1.0) is felt anywhere.
- Low-health feedback (`src/client/LowHealthFX.luau`, numbers in `Config.Audio.LowHealth`):
  under 35% health one eased intensity (0 at the threshold, 1 at zero health or downed, 0
  dead) greys the screen (its own `LowHealthCC` ColorCorrection, saturation to -0.8,
  SkyService's grade untouched), darkens the edges (four black gradient strips 40% deep,
  0.55 opaque at full, under the HUD), fades in a quickening heartbeat (1.0x to 1.6x) and
  muffles the World SoundGroup (equalizer, high -30 dB, mid -12 dB). UI stings, breathing
  and the heartbeat stay clear. Sits under HealthBarUI's red pulse.

---

## 9. Checklist before committing any visual asset

1. Uses only palette hex values (plus the item's accent).
2. Flat shaded, no outline/gradient/filter; no coplanar faces, nothing inside another piece.
3. Reads at the size it will be shown (40 px icon, 30 studs distance for props).
4. Within its triangle cap; MeshPart settings applied; pivot and naming correct.
5. Measured: no new per-frame cost beyond the budget above.
6. Source committed (SVG / generator), uploaded ids recorded in
   `assets/icons/ASSET_IDS.md` (icons) or `assets/3d/ASSET_IDS.md` (meshes).

---

## 10. Decisions log

Decisions that still hold, one line each. The story behind them is in [HISTORY.md](HISTORY.md).

- 2026-11-05: One generated faceted icon set; the generator is the source, not hand SVGs.
- 2026-11-05: Low-poly flat-shaded 3D with one shared palette texture, for performance.
- 2026-11-07: Built-in Roblox materials on arena Parts and one-material meshes (owner wants
  texture); measured, no frame cost.
- 2026-11-07: No zombie green on bodies: pallor / flesh / bruise / wound / pus, damage as
  geometry, strain green only on seams and sacs (owner).
- 2026-11-08: Brighter sky (owner: too gloomy); Bloom only on Neon and fire.
- 2026-11-08: Cars built to the character's scale from side profiles with real glass
  (`props.py`; owner: "redo all the cars").
- 2026-11-08: Skyline is modelled towers with lit-window twins, not slabs (owner: "goofy").
- 2026-11-08: No coplanar faces and no pieces inside each other (owner: "clipping").
- 2026-11-08: Limbs come off when shot, with a flat stump and chunks; no blood spray (owner).
- 2026-11-08: The Infected stay blocky Roblox bodies; the rounded redesign was rejected
  (owner: "I like the regular blocky body").
- 2026-11-08: Players are anonymous Pike soldiers; the Chosen are retired (owner).
- 2026-11-08: HUD follows Prototype 2's HUD (owner).
