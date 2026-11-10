# Lobby v1: the Fallow

Owner: Nova. Branch `nova/lobby`. Status: **playtested in Studio by Nova 2026-11-09**:
spawn, deck, ramp, desks, the Plot and the boarding countdown all work; the sunny sky and the
flicker fix confirmed by Nova. Then the loop was reworked (hangar spawn, ramp turned to rise
toward the spots) and soldiers given the Pike body: built, not yet re-checked. A real launch
(published place) is still untested.

The lobby place (docs/MULTIPLAYER_READINESS.md decision 7, docs/ARCHITECTURE.md F10) as a
walkable ship you can launch from: the Fallow, a helicopter carrier off the Harlan coast on a
clear afternoon (setting in docs/LORE.md > The Fallow). Many parties share one lobby server; each
squad boards a Lantern on the deck and is teleported together into a private server of the
match place.

## What v1 has

- **The ship** (`FallowBuilder`, plain anchored Parts, no meshes yet): hull and raked bow,
  70 x 390 flight deck, the island (bridge windows, hull number painted out, HRD sprayed over
  it, mast), the hangar deck under it with an open side lift to port, a ramp from the hangar
  rising aft to the deck through an open well, invisible walls at every edge. **The sea** is a
  shallow sheet of Terrain water, 8 studs deep, 2560 studs to each side and astern
  (`Water.Extent`: at 1000 the edge of the world showed; out here the haze hides it), with
  small slow engine waves ("low tide", Nova) over a 4-stud layer of dark-tinted Terrain mud
  (`Config.Lobby.Sky.Water`, `Seabed`); the water is carved out of the hull's footprint (inset a stud) so it never
  shows through the hull. **The coast** is Terrain too, 900 studs past the bow, so land meets
  water at a real shoreline: a sand beach sloping under the water, a grass shelf 800 deep, a
  row of 40 grass and rock hills along the whole coast placed from a fixed seed (`Config.Lobby.Sky.Coast`, the same on
  every server; material colours tinted to the palette), rock outcrops at the waterline,
  and the Burn on four sites on the shore in front of the hills. Each site has the match's skyline fire and
  smoke particles (stock `fire_main` / `smoke_main`, westerly drift), scaled up for distance
  and enlarged at Nova's ask (fire 42, smoke 70, each site 180 studs of shoreline): 8
  emitters in all (`Config.Lobby.Sky.Burn`). A clear afternoon
  (`Config.Lobby.Sky`: ClockTime 14, engine clouds, light atmosphere). ShadowMap with
  GlobalShadows (`lobby.project.json` sets `Lighting.Technology`), so the hangar under the
  deck is in shade; only solid opaque parts bigger than clutter cast shadows
  (`Build.part`). Four lights, Shadows off, Range <= 56 (docs/STYLES.md): three in the hangar,
  one red in the Plot; the deck floodlights are unlit housings by day.
- **No shared planes.** Two faces in one plane flicker (z-fighting): the hangar floor plate
  sits on the hull block (`FLOOR` 0.2), the centre line breaks at each spot circle, and the
  spot ring, its inner disc, the number and the boarding box each have their own height.
  Keep to this when adding pieces.
- **The loop** (Nova: walking past the birds to the desks and back every run made no
  sense): everyone spawns at the fore end of the hangar facing aft, passes the desks (Arms
  Room and Engineers face each other across the walk, the Loadmaster at the ramp's foot),
  climbs the ramp, which rises aft, and comes up on the deck facing the spots, spot 4 nearest.
  Fires and the Plot are a short detour aft past the ramp's foot. The screening lane stays as
  scenery where recovered teams will walk off (nobody spawns there).
- **The Pike body** (`PikeBody`): soldiers wear the match's body, the same limb swap as the
  match (`MeshAssets.dressModel` with `PlayerSetup.BODY`; the match's `PlayerSetup` and the
  client `PaletteController` are mapped into the lobby, not copied), no avatar clothing or
  accessories, no rifle. The match's animation set is not in the lobby yet: the body moves
  with Roblox's default R15 animations. Roblox's default walking sound (the "Running" Sound
  the engine puts in each root part) is muted for every character (`DefaultStepMute`), so
  the ship has no footsteps until the match's synced ones come with its animations.
- **Known warning**: `rbxassetid://203785492 … Asset type does not match requested type`
  shows in the lobby's output as it does in the match's (handoff "Minor loose ends"). No file
  in the repo names that id; it is not from lobby code and does not affect play.
- **Four Lantern spots** (`LaunchService`, rule `Rules/Manifest`): a Lantern (`LanternBird`,
  see Lantern below) on each numbered spot and a yellow boarding box beside its starboard door. Stand in the box
  to board. The first aboard starts a 20 s countdown, a full bird (4) cuts it to 5 s, the
  box empty clears it, a fifth soldier is left off. At zero the server teleports everyone
  aboard together (`TeleportAsync`, a reserved server, teleport data `{spot, party}`), two
  retries, then "Lantern couldn't lift". In Studio teleports can't run: the panel says so and
  the spot resets after 6 s. Screen: `LaunchUI` (spot, who is aboard, countdown).
- **Four hangar desks** (`DeskService`, data `LobbyDesks`): Arms Room (cage, port side),
  Engineers (wire spools, starboard), Loadmaster (slung cases at the foot of the ramp), Fires
  (at the Plot door). Block crew figures in working dress, a counter, a sign, an F "Talk" prompt. The
  line shows in `DeskDialogUI` with what the desk will issue; **nothing is issued yet**. The
  Arms Room talks through its own counter (see Arms Room counter below).
- **The Plot** (`PlotService`, `ContainmentBoard`, rule `Rules/Containment`): the red-lit
  map room under the island with the chart table and the Containment Board on a lit perspex
  panel (five districts: percent and band word) and a plotter behind it. It rereads the board
  every 60 s and wipes and rewrites a changed number. **The numbers are placeholders**
  (`Config.Containment.Districts`: Delta 25, the rest 0) until the save service.

## Ship art (2026-11-09: built; uploaded and seen in a Studio playtest)

The owner's "ship upgrade": the art director's build sheet for the exterior, blocked out live
in Blender with the owner, then ported to `assets/3d/build/fallow.py`. Why v1 read as a barge:
the hull ran vertical from waterline to deck, so nothing overhung, and the island was one
box. The sheet fixes the silhouette, not the layout: every `FallowLayout` position is
unchanged.

- **Hull** in four sections, each a **shell** (one swatch, drawn as Metal (100,106,112)
  through `MeshAssets` `surface`, `render` Precise, casts shadows) and a **trim** (palette):
  `env_fallow_bow` (raked stem, flare from the waterline out to the square deck end; the
  165 -> 185 band above the knuckle is one plane so the painted-out hull number lies flat on it),
  `env_fallow_mid_port` / `_mid_stbd` (hull side to a knuckle at y 17, hangar plating, a lip
  below the deck top; the island sponson with knee braces to starboard, the lift opening to
  port), `env_fallow_stern` (square transom, aft sponsons, the screening lane's sponson).
  Trims: rub strake, boot-top, scuppers with rust, hawse pipes, the stern gallery and gate,
  flagstaff, canvas-covered gun tubs, folded whip antennas, the lane's decon tank and hose
  reel, the lift's guide frames.
- **Island** `env_fallow_island` (Metal (116,122,128), lighter than the hull so it stands off
  the deck) + `_island_trim`: base, an O4 level stepped back, the glassed Pri-Fly over the
  spots, the bridge and its wing, two capped funnels, a mast with legs, platform, yard and
  domes. Glass is opaque `glass` with a `glass_l` sky strip (STYLES §6).
- **Radar** `env_fallow_radar` on the mast platform (`FallowLayout.Radar`); each client turns
  it (`RadarSpin`, `Config.Lobby.Ship.RadarRpm` 6).
- **Catwalk bays** `env_fallow_catwalk` / `_rafts` (one 24-stud bay, instanced 18 times from
  `FallowLayout.Catwalks`, port bays turned 180 degrees): grating, rail, safety-net arms,
  wires and the net's outer rail at deck height; one bay in three carries four white raft
  canisters.
- **Budget**: 3,302 unique tris over 12 meshes; ~8,000 in the scene with the bays (cap
  18,000 for the ship).
- **Owner decisions (2026-11-09)**: the radar turns; the port lift is lowered to hangar
  level as a **walkable balcony** (`FallowLayout.Balcony`, Part deck and yellow rails, its own
  invisible walls; built now, mesh or not); the grey deck-top `EdgeRail` goes once the nets are
  up (white deck-edge lines replace it as paint); the old hull number is painted out on both bow
  sides and at the deck's bow end, HRD sprayed over each, as on the island.
- **How it lands** (`FallowArt`): Parts keep every collider. The balcony, deck-edge lines and
  deck-end patch build now. Each mesh group (hull, hull trim, island + radar, catwalks)
  replaces its blocks only when every mesh in it has loaded: the hull hides `Hull` and `Bow`
  (still colliding), shrinks `AftSpaces` / `ForeSpaces` inside the skin and adds the bow
  patches; the island hides `Island` and drops `BridgeWindows`, `Mast`, `Yard` and its
  floodlights. With no ids pasted in (today) the lobby looks as before plus the balcony. The
  sea carve steps in with the bow's taper.
- **Previews**: `assets/3d/build/previews/fallow_before_*.png` (v1),
  `fallow_built_quarter.png`, `fallow_built_portquarter.png`, `fallow_built_deck.png` (the
  built meshes assembled with the bays and radar), and one `env_fallow_*.png` per mesh.

## Lantern (2026-11-09: built; uploaded and seen in a Studio playtest)

The lift bird on each spot, from the lore developer's canon (docs/LORE.md > Lantern, owner
approved) and the art director's sheet, in `assets/3d/build/lantern.py` (collection
`Vehicles`, new prefix `veh_`). Placed by `LanternBird` on `spot.helo`, nose to the bow, the
open door facing the boarding box; no layout change.

- **Meshes** (1,912 tris a bird with both rotors; vehicle cap 5,000): `veh_lantern_body`
  (shell, Metal (104,110,80), Precise: boxy cabin with a 7.5-stud door opening, cockpit and
  windscreen slope, engine housing, tail cone, a boom thin against the 7.5-wide cabin, a tall
  fin raked aft above the rotor disc), `veh_lantern_trim` (dark interior so the door reads at
  40 studs: canvas bench and straps, bundles and a speedball; the door slid fully aft on its
  rails, the kick rail, the empty pintle swung inboard and lashed, the monkey strap; the tally,
  12 strokes and 9 crosses inside the door at the crew chief's shoulder; opaque cockpit glass;
  the bleached tide line on the lower cabin, skids and struts; exhausts; a soot streak on the
  boom; olive_d patches for the HRD; mast and lamp pedestal), `veh_lantern_rotor` (four
  blades drooped 2.5 degrees, 38 across, white tips) and `veh_lantern_tail_rotor` (two blades,
  spins about X). No pilots: the glass is opaque, so they would never be seen.
- **Parts** (`LanternBird`): three invisible colliders (cabin with skids, boom, fin); the amber
  lamp behind the mast with a PointLight (Range 12, off at rest); the bird's number stencilled
  on both nose doors and the fin, HRD on the boom and the port cabin side (SurfaceGui); two
  blur discs, hidden at rest; the crew chief (`NpcBody.Aircrew`: sage flight suit, helmet, visor
  down) at the aft edge of the door facing the box. Numbers per spot are fixed and out of order
  (`Config.Lobby.Lantern.BirdNumbers` 22, 24, 21, 23: a bird and a spot are not tied).
- **Turning** (owner: still on deck, spool on countdown): `LaunchService` publishes
  `Attributes.LiftAt` (server time) on the counting bird; `LanternSpool` on every client lights
  the lamp, spools the rotor to 40 rpm over the first two thirds of the countdown, swaps the
  blades for the blur discs for the last 3 s and lifts the bird 4 studs, nose 5 degrees down,
  over the last 1.5 s; cleared, everything returns. Tuning in `Config.Lobby.Lantern`.
- **Uploaded 2026-11-09** (ids in `assets/3d/ASSET_IDS.md`). If a mesh fails to load, the v1 block
  bird stays on the spot (it lifts on the countdown too, without a spinning rotor or lamp). The
  four meshes swap in together or not at all.
- **Previews**: `lantern_before.png`, `lantern_built_door.png`, `lantern_built_profile.png`,
  `lantern_built_board.png` (from the boarding box), one `veh_lantern_*.png` per mesh.

## Arms Room counter (2026-11-09: built; talk panel playtested)

Fixes 2026-11-09 (owner playtest): the choices also answer to the number keys 1-3 (they
are numbered on screen; before, only a click worked), the choices are `Modal` so the mouse is
free even zoomed into first person, and one desk dialog shows at a time (talking to another
desk closes this panel; `DeskDialogUI` hides its panel when the armorer opens).

The owner's ask (after a GTA gun counter): give the armorer a use as the place the guns live.
Loadout selection is not part of it; nothing is drawn yet.

- **Talk** (F on the armorer, `ArmsRackUI` instead of `DeskDialogUI` for a desk with a `rack`
  in `LobbyDesks`): his line and three choices, "Any work going?" (his answer: work comes from
  the Plot; no taskings yet), "Show me the rack." and "Carry on." Wording by the lore developer:
  nothing on the Fallow is bought or sold, so no price, buy, sell, lock, unlock, shop, store
  or wares anywhere.
- **The rack** (`ArmsRack`, `FallowLayout.ArmsRack`): a board on the hangar's port wall behind
  the cage (the cage lost its back row of bars and the old RifleRack block). Every catalog item
  hangs on two pegs in catalog order: the five long guns in a column, the pistol and the frag
  beside them. Stand-in block silhouettes per id; the Service Rifle swaps to `wpn_rifle` once
  loaded. A new gun model goes in by adding its mesh to `ArmsRack.MESH` (and `MeshAssets`).
- **Looking** (all local to the player, so four can look at once): the camera glides inside
  the cage to frame the whole board (movement off, the prompt off, the armorer hidden for this
  player only). The gun under the cursor slides 0.6 off its pegs with a soft yellow rim (a
  Highlight; the owner asked for the glow, the lore pass wanted none, so it stays faint). Click
  or tap frames that gun left of centre with its card on the right: name, the real gun, ON ISSUE
  (the default kit, `ArmsRoom.default()`) or NOT ON ISSUE with "Record not open", its line, and
  six bars from `Rules/ArmsStats` (damage per pull, fire rate, magazine, reload, range,
  aimed accuracy, each against the best on the rack); the frag shows its numbers without bars.
  ◀ ▶ (or arrow keys, A/D, the d-pad) step along the rack; Back (or Backspace, B) steps back to
  the board, and again to walk away. Tuning in `Config.Lobby.Rack`.
- **Previews**: `assets/3d/build/previews/rack_view.png` (what the camera frames, a hovered gun
  forward) and `rack_cage.png` (the cage from the walk).

## Plan view (studs; +Z bow, +X starboard)

```
 Z  210  bow ───────────────────────────────
    140  ── hangar bulkhead (fore) ──
    125  HANGAR: spawn (0, 125), facing aft
    105  Arms Room (-27) ←walk→ Engineers (27)
     88  Loadmaster (-2), facing the spawn
     80  ┌ramp foot (hangar)┐ well X -30..-10
     20  └ramp top (deck)───┘ comes up facing aft
     50..-10                        ┌island┐ X 22..34 (deck); Plot under it (hangar,
                                    └──────┘  X 14..33, Z -10..30), Fires (10, 18) at its door
    -15  spot 4 (helo X -12, box X 1)
    -60  spot 3
   -100  ── hangar bulkhead (aft) ──
   -105  spot 2
   -150  spot 1                     screening lane X 19..29, Z -172..-136 (scenery)
   -180  stern ───────────────────────────────
```

Deck surface y 40, hangar floor y 20, sea y 0. Every position is in `FallowLayout`.

## Files

| Place | File |
|---|---|
| Project | `lobby.project.json` (shares `src/shared`; `src/lobby/shared` as `ReplicatedStorage.Lobby`; maps the match's `src/server/PlayerSetup.luau` into the lobby server and `src/client/HudTheme.luau`, `PaletteController.luau` into the lobby client; sets `Lighting.Technology`) |
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `FallowArt`, `PikeBody`, `NpcBody`, `DeskService`, `ContainmentBoard`, `PlotService`, `LaunchService`, `LanternBird`, `ArmsRack` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI`, `ArmsRackUI`, `RadarSpin`, `LanternSpool` |
| Art | `assets/3d/build/fallow.py` (12 `env_fallow_*` meshes), `lantern.py` (4 `veh_lantern_*`); `MeshAssets` entries; `Config.Lobby.Ship`, `Config.Lobby.Lantern`; attribute `LiftAt`; rule `Rules/ArmsStats` (+ spec), `Config.Lobby.Rack` |
| Shared | `src/lobby/shared/LobbyDesks`; rules `src/shared/Rules/Manifest`, `Rules/Containment` (+ specs); `Config.Lobby`, `Config.Containment`; remote `Launch` + `Messages.Launch`; attribute `DeskId` |

## How to test it

1. In Studio open the group experience Co-op Zombie Shooter, Asset Manager > Places >
   right-click > **Add New Place**, name it `Lobby (dev)`, open it.
2. `rojo serve lobby.project.json --port 34873` (a different port from the match's 34872),
   Rojo plugin > set the port > Connect, Play.
3. Check: spawn in the hangar in the Pike body, talk to each desk (F), read the board in the
   Plot, climb the ramp to the spots, stand in a boarding box (panel + countdown; in Studio it ends with the
   "Teleports don't run in Studio" line).
4. Launch for real: publish the place, join it from the Roblox app (with a friend for a
   two-person bird), board a spot. You should land in a match server together.

## Open (next steps, in order)

- **Re-check the new loop and the Pike body** (the steps above). The one unverified API:
  `TeleportOptions.ShouldReserveServer` (documented, missing from the luau-lsp definitions,
  set through a cast in `LaunchService`). If the live launch errors there, switch to
  `TeleportService:ReserveServer` and pass the access code.
- **Make the lobby the experience's start place** (owner's call): today players still join
  the match place directly. The match ignores the teleport data; reading the party there is
  `RunManager`'s job (decision 7).
- **Back to the Fallow at run end** (decision 7: once meta progression exists).
- **Real board numbers** and **desk trades** wait for the save service (F9) and a name for
  the record currency (lore + systems designer).
- **Ship and Lantern art: full check** (uploaded and wired 2026-11-09; v2 the same day: the first
  upload showed every mesh mirrored left-right, so the island raft rack hung over the HRD patch
  and one-sided trim sat on the wrong side; `build_assets.MIRROR_X_COLLECTIONS` pre-mirrors
  the export. v2 seen in a playtest: island, both sides, ramp, catwalks, birds). Still to
  check in the `Lobby (dev)` place: the hull hides its blocks
  with no gaps, the bow patches lie flat, the radar turns, the balcony is walkable and walled,
  no water shows inside the bow; each bird shows its number, the crew chief stands in the door,
  and boarding a spot lights the lamp, spools, blurs and lifts it (and it settles back when the
  Studio lift fails). Count the lamp lights against the deck's (performance reviewer).
- **Arms Room counter: playtest** in `Lobby (dev)`: the choices, the glide, hover on each gun,
  inspect and stepping, Back twice, a second player looking at the same time, touch and gamepad;
  check the rifle mesh's orientation on the rack (turned by reasoning, not seen).
- **Arms Room, later**: Tien's gun meshes (`ArmsRack.MESH`); drawing a gun once the record
  opens (the card's button goes where the status line is); the armorer's taskings.
- **Lore, to approve** (lore developer, Arms Room pass): "the rack" as the armorer's word for
  the wall; "on issue" / "not on issue" as the standard words on every desk; "taskings" as the
  in-world word for desk side work. Canon names the default gun the M4A1 Carbine; the game's
  catalog issues the Service Rifle (M16A4) and has no carbine: one of them changes.
- **Lantern in the match** (insert, extraction, supply kicks out of the starboard door): the
  same four meshes; `LanternBird` and `LanternSpool` are lobby modules today.
- **Art, next**: the desk crew; sounds (rotor spool on lift, ship PA tone, the plotter's grease
  pencil, a low radio net, a door-rail rattle on a kick); a vertical rib over each hull seam
  (the sheet's 0.4-proud frame).
- **Lore flags from the Lantern sheet** (lore developer): canon says boom and fin "roughly
  double the fuselage length"; at the deck's 45-stud spot pitch it is built about as long again
  (fuselage 20, boom and fin 21): soften the line. Also to confirm: the lamp reads from below by
  its spill on the belly; the crew chief's dress; white grease pencil; the tally's counts; four
  blades.
- **Day/night cycle** (owner and Nova, an idea for later): drive `Config.Lobby.Sky` over time,
  light the deck floodlight housings at night.
- **Sea extras** (optional): spray at the bow, a foam line along the waterline, a stern wake
  (a few burst emitters, inside the STYLES particle budget).
- **The Plot's launch and recovery radio lines** (LORE.md > The Fallow) are not played yet.
- **Other teams' callsigns** (not all Pike) are open with the lore developer.
- **The match's animations in the lobby** (unarmed idle and walk): the Pike body uses Roblox's
  default R15 set on the ship today.
- `Config` split by domain (F10) is not done: the lobby loads the match's tuning too.
