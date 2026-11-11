# Lobby v1: the Fallow

Owner: Nova. Branch `nova/lobby`. Status: **playtested in Studio by Nova 2026-11-09**:
spawn, deck, ramp, desks, the Plot and the boarding countdown all work; the sunny sky and the
flicker fix confirmed by Nova. Then the loop was reworked (hangar spawn, ramp turned to rise
toward the spots) and soldiers given the Pike body. A real launch from a published place was
verified 2026-11-10 in Nova's test experience (ZCS Dev -> Match Dev, a signed Loadout arrived;
see Loadmaster and Loadout). Since 2026-11-10 the lobby sends the agreed `Rules/Handoff`
shape and the match reads it in Tien's `HandoffService` (docs/LOBBY_MATCH_HANDOFF.md).

The lobby place (docs/MULTIPLAYER_READINESS.md decision 7, docs/ARCHITECTURE.md F10) as a
walkable ship you can launch from: the Fallow, a helicopter carrier off the Harlan coast on a
clear afternoon (setting in docs/LORE.md > The Fallow). Many parties share one lobby server; each
squad boards a Lantern on the deck and is teleported together into a private server of the
match place.

## What v1 has

- **The ship** (`FallowBuilder`, plain anchored Parts, no meshes yet): hull and raked bow,
  70 x 390 flight deck, the island (bridge windows, hull number painted out, HARLAN sprayed over
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
  emitters in all (`Config.Lobby.Sky.Burn`). **Gloomy since 2026-11-10** (Tien): an overcast,
  cold late afternoon (`Config.Lobby.Sky`: ClockTime 17.3, Brightness 1.5, heavy grey clouds
  0.88, a grey haze, soft shadows, a cold grey-green sea, a drained cool `ColorCorrection` and a
  `Bloom` that only lifts fire, Neon and lamps); the hangar desks still read clearly. ShadowMap with
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
  to board. The first aboard starts a 20 s countdown and gets a squad-size picker (SOLO / 2 /
  3 / FULL, `Messages.Launch.Squad`, `Manifest.setSquad`; owner 2026-11-10): once that many
  are aboard (4 if nobody picks) the countdown drops to 3 s (`FullCountdown`), so a solo soldier
  lifts 3 s after picking SOLO. The box empty clears it and the pick, a fifth soldier is left off. At zero the server teleports everyone
  aboard together (`TeleportAsync` into one server reserved per lift, `ReserveServer`, reused
  by every retry; teleport data `Handoff.departure`: slot = boarding order, each soldier's
  signed Loadout, plus `spot`), two
  retries, then "Lantern couldn't lift". In Studio teleports can't run: the panel says so and
  the spot resets after 6 s. Screen: `LaunchUI` (spot, who is aboard against the squad size, countdown, the picker for the
  first aboard).
- **Four hangar desks** (`DeskService`, data `LobbyDesks`): Arms Room (the port fore corner),
  Engineers (wire spools, starboard), Loadmaster (slung cases at the foot of the ramp), Fires
  (at the Plot door). Block crew figures in working dress, a counter, a sign, an F "Talk" prompt. The
  **Every desk talks the same way** (dialog rewrite 2026-11-10, Nova and Tien: "too cryptic,
  no personality"; lines and voices by the lore developer, `LobbyDesks` `talk`, voice sheets
  in docs/lore/desk_crew.md): a greeting picked at random from four, then 1 their kit, 2 a
  question, 3 leave (click or keys 1-3), plus their own bought / short / refused lines. The
  Quartermaster talks through `ArmsRackUI`, the Loadmaster through `LoadmasterUI`, Fires and
  the Engineers through `DeskDialogUI` (1 opens their `DeskShop`).
- **The Plot** (`PlotService`, `ContainmentBoard`, rule `Rules/Containment`): the red-lit
  map room under the island with the Containment Board on a lit perspex panel (five
  districts: percent and band word). It rereads the board every 60 s and wipes and rewrites a
  changed number. **Since 2026-11-10** (Nova: "replace him with someone real"; canon by the
  lore developer): the silent plotter is gone; **Control's watch officer** (a major, the voice
  on your radio; `LobbyDesks` id `plot`, a desk with `counter = false`) stands between the
  table and the board and talks like every desk; "Show me the map." glides the camera over
  the **paper map** (`WorldMap` + `WorldMapData`, canon docs/lore/world_map.md): the Harlan
  Corridor on a 10 x 7 grid at 1.4 studs a unit (`Config.Lobby.WorldMap`) - five districts
  with borders, the river and dam, Route 9, County Road 40, the coast road, the rail line, the
  grease-pencil quarantine line, burned towns, forests, the Carrier offshore with Lantern's
  pencilled track, a title, a legend and a red Plot stamp; about 150 flat parts, built once. **The numbers are placeholders**
  (`Config.Containment.Districts`: Delta 25, the rest 0) until the save service.

- **The walking crew** (2026-11-10, Nova: "give the fallow some life"; roles and lines by the
  lore developer, docs/lore/ship_company.md): six of the ship's company and Army staff -
  plane director (yellow), deck hand (blue), hangar mechanic (green), Plot runner, screening
  medic (white smock), lane sentry - walk there and back along `FallowLayout.Crew`, pausing
  at each end. `CrewService` places NpcBody figures once (tag `Crew`, route as an attribute);
  each client walks its own copy (`CrewWalk`: one `BulkMoveTo` a frame, a leg and arm swing,
  nothing replicates) and shows a line over a head when a soldier comes within
  `Config.Lobby.Crew.BubbleDistance` (lines in `LobbyCrew`). No prompts, no Humanoids, no collision. Routes
  checked clear of walls and desks in a playtest.
- **Kit on the bodies** (2026-11-10, Nova: "personality"; details by the lore developer,
  docs/lore/desk_crew.md, ship_company.md, docs/CHARACTERS.md): `NpcBody.build` takes a kit
  list of named block accessories (`KIT` in NpcBody). The Quartermaster: glasses on a cord, a
  clipboard, keys. The Loadmaster: flight helmet pushed up with the visor raised, harness and
  tether, a grease pencil. Fires: a headset round her neck, a notebook. The Engineers: belt
  gloves, red wire cutters, a wire coil. The watch officer: one-cup headset, a steel mug, a
  rank tab. Lantern's crew chief: gloves and harness. The walking crew: ear defenders, a
  chock and chain, a rag, a clipboard, a mask and blue gloves, a helmet with a slung rifle and
  a white MP brassard. Kit on an arm (`RightArm_...`) swings with it. Every Pike on the ship
  (`PikeBody`) wears the white screening band with its yellow stripe on the left wrist, a
  green chemlight on the left shoulder strap and the tourniquet high on the right arm; the
  match body (PlayerSetup, Tien's) does not yet.

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
  sides and at the deck's bow end, HARLAN sprayed over each, as on the island.
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
  boom; olive_d patches for the HARLAN mark; mast and lamp pedestal), `veh_lantern_rotor` (four
  blades drooped 2.5 degrees, 38 across, white tips) and `veh_lantern_tail_rotor` (two blades,
  spins about X). No pilots: the glass is opaque, so they would never be seen.
- **Parts** (`LanternBird`): three invisible colliders (cabin with skids, boom, fin); the amber
  lamp behind the mast with a PointLight (Range 12, off at rest); the bird's number stencilled
  on both nose doors and the fin, HARLAN on the boom and the port cabin side (SurfaceGui); two
  blur discs, hidden at rest; the crew chief (`NpcBody.Aircrew`: sage flight suit, helmet, visor
  down) at the aft edge of the door facing the box. Numbers per spot are fixed and out of order
  (`Config.Lobby.Lantern.BirdNumbers` 22, 24, 21, 23: a bird and a spot are not tied).
- **Turning** (owner: still on deck, spool on countdown): `LaunchService` publishes
  `Attributes.LiftAt` (server time) on the counting bird; `LanternSpool` on every client lights
  the lamp, spools the rotor to 40 rpm over the first two thirds of the countdown, builds the
  blur over the last 6 s (`Rules/RotorBlur` + spec, eased; owner 2026-11-10: the old swap at
  3 s made the blades look gone): the blades fade only to 0.6 while the discs thicken to 0.8,
  complete 1.5 s before lift. Then it lifts the bird 4 studs, nose 5 degrees down,
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
desk closes this panel; `DeskDialogUI` hides its panel when the Quartermaster opens). Second
fix: "Show me the rack." hung for good when the place had no `PlayerModule` (the lobby has
none), leaving the panel up with the keys unbound; the rack now holds the Humanoid still when
there is no PlayerModule, and the keys unbind only once the rack is open. The armorer is
renamed **the Quartermaster** (owner, 2026-11-09).

The owner's ask (after a GTA gun counter): give the Quartermaster a use as the place the guns live.
The rack is where guns are **bought** (merits, onto the soldier's record; owner and Tien,
2026-11-09), not equipped: equipping is the Loadmaster's (below).

**Buying on the Carrier (2026-11-10; guns Studio-verified, grenades and call-ins built):**
- **The record** (`Rules/Record` + spec): merits and the kit bought: guns, grenades and
  call-ins (Nova: merits, all three buyable). A new soldier starts with
  `Config.Lobby.Save.StartMerits` (1000). Prices sit on each item's own row, read through
  `KitPrices`: guns `Config.Weapons.<Gun>.Price` (Service Rifle and Pistol 0, issued free; SMG
  300, Revolver 350, Shotgun 400, DMR 500, LMG 600, Sniper 700, Goose 900), grenades
  `Config.Grenade.<Name>.Price` (Frag 0), call-ins `Config.CallIns.<Name>.Price` (Hammer,
  Anvil, Shrike, Tripline 0; Concertina 250, Speedball 300, Aid Bag 300, Doorman 400). No
  Price = not for sale. A Loadout is allowed only when both guns, the grenade and every
  call-in are on the record.
- **Where:** guns and grenades on the Quartermaster's rack; call-ins at the desk on their row
  (`Desk`): Fires (Hammer, Anvil, Shrike), the Engineers (Doorman, Tripline, Concertina), the
  Loadmaster (Speedball, Aid Bag, under "What can you drop me?"). `DeskShop` is the panel: each
  call-in with what it is, ON YOUR RECORD or BUY · N MERITS (dim "(SHORT)"), the merits, a
  refusal note; Fires and the Engineers stay up while you stand at the desk.
- **Server** (`RecordService`): loads the record on join (`SaveSlot`, DataStore
  `PikeRecords`, key `r_<UserId>`), sends it on the `Record` remote (`Messages.Record`), checks
  each BUY with the rule and saves. `SaveSlot` is the shared save helper (spaced writes, flush
  on leave/shutdown, one log line and no saving when the DataStore is unavailable);
  `LoadmasterService` uses it too.
- **The rack** (`ArmsRackUI`, `RecordClient`): the header shows the merits; the card shows ON
  YOUR RECORD, or NOT ON YOUR RECORD with the price and BUY · N MERITS (dim "(SHORT)" when
  short). He answers with the lore developer's lines ("Signed. It's on your record..." /
  "You're short. Bring me merits.").
- **The Loadmaster** signs only for kit on the record: the Loadout locks the rest (guns,
  grenades, call-ins: dim, the price in yellow, cannot be picked, SIGN FOR IT greyed;
  `LoadoutMenu.mount` option `locked`, `handle.refresh`), the server refuses a forged one ("not
  on record"), and a saved Loadout naming anything no longer on the record falls back to the
  default.
- **Not built:** earning merits (only the starting grant): a run's pay is the systems
  designer's call and the match would save it (the record is per UserId in the same
  experience). The match's B Arms Room still offers every gun.

- **Talk** (F on the Quartermaster, `ArmsRackUI` for a desk with a `rack` in `LobbyDesks`): a
  greeting, then 1 "Show me the guns." (the rack), 2 "How do I get merits?", 3 "That's all." Wording by the lore developer: BUY and a price in
  MERITS may show; never shop, store, wares, sell, lock or unlock.
- **The corner** (`ArmsRack`, `FallowLayout.ArmsRoom`; Nova 2026-11-10: "use that entire
  corner for him", "the glass case would act as the desk, like in GTA"): the Arms Room fills
  the hangar's port fore corner (X -33..-23.6, Z 111..140), fenced off with wire at the ends
  of a 16-stud **glass counter** (Z 116..132) the Quartermaster stands behind (-26, 124). The
  counter holds sidearms, melee and grenades on a felt bed tilted toward the soldier, two rows
  deep, in labelled sections (sidearms 10 places, melee 4, grenades 10); no melee weapon exists
  yet, so its section is empty. Behind him the **long-gun wall** on the hull: a board 26 x 9.6
  with a lamp over it and a gun rail under each of 8 rows, 4 guns a row (32 places, 7 used). Each
  gun lies or hangs as its own held mesh (its row's `Model`; a block silhouette until it loads,
  or for the frag), muzzles to the soldier's left. A new gun needs no edit, only a row.
- **Looking** (all local to the player, so four can look at once): "Show me the guns." frames
  the wall from over the counter; Q or the button swaps to the counter, seen from above through
  the glass (movement off, the prompt off, the Quartermaster, his sign and the soldier's own
  body hidden for this player). The cursor aims at invisible boxes, one per place (the `Hits`
  folder, the size of the whole place), so the hover never flickers or picks a neighbour as a
  gun slides out; the gun under it slides 0.6 out with a soft yellow rim. A click frames it in
  the screen the card leaves free (left of the card, under the header, over the buttons): far
  enough back for its whole length to fit that width, and no more than 40% of the screen's
  height (it used to fit the whole screen and then shift, leaving half the gun off screen). The
  card on the right: name, the real gun, ON YOUR RECORD or NOT ON YOUR RECORD with the price
  and BUY, its line, six bars from `Rules/ArmsStats`; the frag shows its numbers without bars.
  ◀ ▶ (or arrow keys, A/D, the d-pad) step through every piece on both displays; Back (or
  Backspace, B) steps back to that piece's display, and again to walk away. Tuning in
  `Config.Lobby.Rack`.

## Plan view (studs; +Z bow, +X starboard)

```
 Z  210  bow ───────────────────────────────
    140  ── hangar bulkhead (fore) ──
    125  HANGAR: spawn (0, 125), facing aft
    124  Arms Room: the port fore corner, counter at X -23.6 (Quartermaster -26)
    105  Engineers (27)
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

## Music (2026-11-10)

`LobbyMusic` (client) plays a shuffled playlist of four licensed tracks from Roblox's audio
library (free for any experience, nothing uploaded): "A Light Dies Out On The Water", "Lost In
Time" (ambient mix, APM), "Fading Hope", "Silhouette Dream" (ambience version, APM); about 10
minutes before it repeats. Low in the mix (`Config.Lobby.Music.Volume` 0.22 on its own
`Music` SoundGroup, so a volume setting can follow; OWNER.md: no harsh sound), 3 s between
tracks, a 4 s fade in on arrival, a 2.5 s fade out when your Lantern lifts (the rotor takes
over before the teleport's fade), back on a failed lift. Tracks were picked by name and mood,
not by ear: swap them in `Config.Lobby.Music.Tracks`.

## Files

| Place | File |
|---|---|
| Project | `lobby.project.json` (shares `src/shared`; `src/lobby/shared` as `ReplicatedStorage.Lobby`; maps the match's `src/server/PlayerSetup.luau` into the lobby server and `src/client/HudTheme.luau`, `PaletteController.luau`, `LoadoutMenu.luau` into the lobby client; sets `Lighting.Technology`) |
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `FallowArt`, `PikeBody`, `NpcBody`, `DeskService`, `ContainmentBoard`, `PlotService`, `LaunchService`, `LanternBird`, `ArmsRack`, `LoadmasterService` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI`, `ArmsRackUI`, `LoadmasterUI`, `DeskShop`, `RecordClient`, `LobbyMusic`, `HoldStill`, `RadarSpin`, `LanternSpool` |
| Art | `assets/3d/build/fallow.py` (12 `env_fallow_*` meshes), `lantern.py` (4 `veh_lantern_*`); `MeshAssets` entries; `Config.Lobby.Ship`, `Config.Lobby.Lantern`; attribute `LiftAt`; rule `Rules/ArmsStats` (+ spec), `Config.Lobby.Rack` |
| Shared | `src/lobby/shared/LobbyDesks`; rules `src/shared/Rules/Manifest`, `Rules/Containment`, `Rules/Handoff` (main's, the teleport data both places share); `Config.Lobby`, `Config.Places`, `Config.Containment`; remotes `Launch` + `Messages.Launch`, `Loadout` (shared with the match); attribute `DeskId` |
| Match side | `HandoffService` reads the teleport data and `RunManager.receive` applies the signed Loadout (2026-11-09; `JoinData` retired); `LoadoutMenu.mount` options (title, hint, confirm) |

## How to test it

1. In Studio open a lobby place: Nova's ZCS Dev (his test experience), or the start place
   "Co-op Zombie Shooter" (the real lobby; publish there from `main` only). Never connect
   this project in a match place (`docs/STUDIO_MCP.md` > Places and publishing). The old
   `Lobby (dev)` place (125769854992316) is now the real match, Checkpoint Delta.
2. `rojo serve lobby.project.json --port 34873` (a different port from the match's 34872),
   Rojo plugin > set the port > Connect, Play.
3. Check: spawn in the hangar in the Pike body, talk to each desk (F), read the board in the
   Plot, climb the ramp to the spots, stand in a boarding box (panel + countdown; in Studio it ends with the
   "Teleports don't run in Studio" line).
4. Test places: Nova's own test experience, start place ZCS Dev (83558708746036), launches
   into Match Dev (108949482095254) and that match flies home to ZCS Dev (`Config.Places.Dev`).
   The group experience opens on the lobby (87556879379942) and launches into Checkpoint
   Delta (125769854992316): `docs/LOBBY_MATCH_HANDOFF.md`.
5. Launch for real: publish the place, join it from the Roblox app (with a friend for a
   two-person bird), board a spot. You should land in a match server together.

## Open (next steps, in order)

- **Re-check the new loop and the Pike body** (the steps above). Since 2026-11-10 a lift reserves its server
  with `TeleportService:ReserveServer` and passes the access code (set through a cast: the
  luau-lsp definitions lack `ReservedServerAccessCode`); re-check a live launch after
  publishing both places.
## Loadmaster and Loadout (2026-11-09: prototype built; verified live end to end)

Owner and Tien: the Loadmaster at the foot of the ramp is where a soldier equips; the menu is
called **Loadout**. Lines by the lore developer (merits, the record, `LobbyDesks` `kit`).

- **Talk** (F on the Loadmaster, `LoadmasterUI`): a greeting, then 1 "Set up my Loadout." 2
  "What can you drop me?" (his supply shop) 3 "That's all." (click or keys 1-3, Modal mouse, one
  dialog at a time).
- **Loadout**: choice 1 opens the match's `LoadoutMenu` (mapped into the lobby project) with
  the lobby's words (`LoadoutMenu.mount` options: title LOADOUT, SIGN FOR IT): primary,
  sidearm, grenade, up to four call-ins. The soldier is held still (`HoldStill`, shared with
  the rack); BACK or Backspace steps out. Prototype: the whole catalog may be signed for.
- **Server** (`LoadmasterService`): checks the request with the match's rules and catalog
  (`Rules/Loadout`, `ArmsRoom`), keeps one signed Loadout per player, answers on the `Loadout`
  remote. **Kept between visits** (2026-11-10): saved in the DataStore `LoadmasterLoadouts`
  (key `u_<UserId>`, `Rules/LoadoutSave` + spec, versioned), loaded on join (sent to the client
  as `Loadout.Signed`, so the screen opens on it, and it rides the Lantern even without a visit
  to the desk), writes spaced 6 s and flushed on leave/shutdown (`Config.Lobby.Save`). A failed
  or Studio-blocked DataStore means the default Loadout and one log line; Studio needs Game
  Settings > Security > Enable Studio Access to API Services to test it. Verified live by Nova
  2026-11-10 (a signed Loadout came back after leaving and rejoining). A stand-in for F9. `LaunchService` sends them in `Handoff.departure`.
- **Match**: Tien's `HandoffService` (`Handoff.readJoin`) gives each soldier the Loadout they
  signed, re-validated against the match catalog; no data or a bad Loadout falls back to the
  default. Untestable in Studio (no teleports). The first version (2026-11-10, its own shape
  read by a `JoinData` module) was verified live in Nova's test experience; the `Rules/Handoff`
  version needs the same live check. A publish made before Rojo synced the dev pair
  launched toward the real match (another experience) and failed with "Lantern couldn't
  lift": republish after the sync.

- **Make the lobby the experience's start place** (owner's call): today players still join
  the match place directly (docs/LOBBY_MATCH_HANDOFF.md > Decisions).
- **The debrief panel** (`DebriefUI`, docs/LOBBY_MATCH_HANDOFF.md > Nova step 5): the result
  of a run, shown once when the squad flies home (BACK TO THE CARRIER is built match side).
- **Earning merits** (the record only has the starting grant): how many a run pays is the
  systems designer's; the match would add them to the record. **Real board numbers** wait for
  the save service (F9).
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
- **Arms Room, later**: the Quartermaster's taskings; the match's B Arms Room limited to the
  record (or off for lobby runs).
- **Lore, to approve** (lore developer, Arms Room pass): "the rack" as the Quartermaster's word for
  the wall; "taskings" as the in-world word for desk side work ("on issue" became "on your
  record", approved 2026-11-09 with merits). HRD was replaced by HARLAN (Task Force Harlan) on 2026-11-10 (Tien disliked HRD; LORE.md > The mark: HARLAN). Canon names the default gun the M4A1 Carbine; the game's
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
