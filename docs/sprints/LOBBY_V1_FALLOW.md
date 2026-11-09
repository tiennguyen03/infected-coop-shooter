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
- **Four Lantern spots** (`LaunchService`, rule `Rules/Manifest`): a block-built helo on
  each numbered spot and a yellow boarding box beside its starboard door. Stand in the box
  to board. The first aboard starts a 20 s countdown, a full bird (4) cuts it to 5 s, the
  box empty clears it, a fifth soldier is left off. At zero the server teleports everyone
  aboard together (`TeleportAsync`, a reserved server, teleport data `{spot, party}`), two
  retries, then "Lantern couldn't lift". In Studio teleports can't run: the panel says so and
  the spot resets after 6 s. Screen: `LaunchUI` (spot, who is aboard, countdown).
- **Four hangar desks** (`DeskService`, data `LobbyDesks`): Arms Room (cage, port side),
  Engineers (wire spools, starboard), Loadmaster (slung cases at the foot of the ramp), Fires
  (at the Plot door). Block crew figures in working dress, a counter, a sign, an F "Talk" prompt. The
  line shows in `DeskDialogUI` with what the desk will issue; **nothing is issued yet**.
- **The Plot** (`PlotService`, `ContainmentBoard`, rule `Rules/Containment`): the red-lit
  map room under the island with the chart table and the Containment Board on a lit perspex
  panel (five districts: percent and band word) and a plotter behind it. It rereads the board
  every 60 s and wipes and rewrites a changed number. **The numbers are placeholders**
  (`Config.Containment.Districts`: Delta 25, the rest 0) until the save service.

## Ship art (2026-11-09: built, not uploaded, not playtested)

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
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `FallowArt`, `PikeBody`, `NpcBody`, `DeskService`, `ContainmentBoard`, `PlotService`, `LaunchService` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI`, `RadarSpin` |
| Art | `assets/3d/build/fallow.py` (12 `env_fallow_*` meshes); `MeshAssets` entries; `Config.Lobby.Ship` |
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
- **Ship art: upload and playtest** (needs Roblox Studio with its MCP): upload the 12
  `assets/3d/export/env_fallow_*.fbx` as Models, read each MeshId, paste them into the
  `env_fallow_*` entries in `MeshAssets` and record them in `assets/3d/ASSET_IDS.md`, then check
  in the `Lobby (dev)` place: the hull hides its blocks with no gaps, the bow patches lie flat,
  the radar turns, the balcony is walkable and walled, no water shows inside the bow.
- **Art, next**: the Lantern helo sheet (art director: shared by the lobby and the match, after
  the lore developer names the airframe; the cube helos are what the deck view lands on now);
  the desk crew; sounds (rotor spool on lift, ship PA tone, the plotter's grease pencil, a low
  radio net); a vertical rib over each hull seam (the sheet's 0.4-proud frame).
- **Lore flags from the art pass** (lore developer): the sponson mounts (built as
  canvas-covered); a name on the transom or painted out; what flies from the flagstaff; the
  Lantern's airframe.
- **Day/night cycle** (owner and Nova, an idea for later): drive `Config.Lobby.Sky` over time,
  light the deck floodlight housings at night.
- **Sea extras** (optional): spray at the bow, a foam line along the waterline, a stern wake
  (a few burst emitters, inside the STYLES particle budget).
- **The Plot's launch and recovery radio lines** (LORE.md > The Fallow) are not played yet.
- **Other teams' callsigns** (not all Pike) are open with the lore developer.
- **The match's animations in the lobby** (unarmed idle and walk): the Pike body uses Roblox's
  default R15 set on the ship today.
- `Config` split by domain (F10) is not done: the lobby loads the match's tuning too.
