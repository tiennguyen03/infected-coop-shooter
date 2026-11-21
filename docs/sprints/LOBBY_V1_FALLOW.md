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
  spot ring, its inner disc, the number and the spot sign each have their own height.
  Keep to this when adding pieces.
- **The loop** (Nova: walking past the birds to the desks and back every run made no
  sense): everyone spawns at the fore end of the hangar facing aft, passes the desks (Arms
  Room and Call-ins face each other across the walk, the Loadmaster at the ramp's foot),
  climbs the ramp, which rises aft, and comes up on the deck facing the spots, spot 4 nearest.
  The Plot is a short detour aft past the ramp's foot. The screening lane stays as
  scenery where recovered teams will walk off (nobody spawns there).
- **The Pike body** (`PikeBody`): soldiers wear the match's body, the same limb swap as the
  match (`MeshAssets.dressModel` with `PlayerSetup.BODY`; the match's `PlayerSetup` and the
  client `PaletteController` are mapped into the lobby, not copied), no avatar clothing or
  accessories. Roblox's default walking sound (the "Running" Sound the engine puts in each
  root part) is muted for every character (`DefaultStepMute`); the match's synced footsteps
  (`FootstepController`) are not in the lobby yet.
- **The soldier moves and is armed like the match's** (owner, 2026-11-11; built, static checks
  only, **not yet seen in game**). Client `SoldierMoves` plays the match's rifle idle and
  four-way walk blend (`Config.Animations.Assault`) through `src/shared/SoldierLocomotion`,
  the same code the match's `AnimationController` now drives (rule `Rules/MoveBlend`); each
  client animates its own character on the Animator, so everyone sees it. `PikeBody` calls
  the match's `PlayerSetup.attachRifle` after the limb swap, and `LoadmasterService` sets the
  player's `Weapon` attribute to the signed primary, so the gun in the hands follows the
  Loadout (the default rifle until one is signed). The pose is the match's own rifle idle
  (no separate slung or low-ready clip). No sprint, aim, stances, roll or vault on the ship;
  a jump holds the pose it left the deck in. If the idle or walk clip does not load within
  `Config.Lobby.Soldier.ClipWait` seconds (a place the group does not own), the stock
  Animate script stays. Switches: `Config.Lobby.Soldier.Enabled`, `.CarryRifle`.
  **To check in the lobby place:** the idle and walk play and other clients see them; the
  rifle sits in the hands as in the match and changes after signing a different primary;
  no hotbar slot; the rifle does not get in the way at the rack or the Loadout screen; a
  respawn (fall off the deck) comes back armed and animated.
- **Known warning**: `rbxassetid://203785492 … Asset type does not match requested type`
  shows in the lobby's output as it does in the match's (handoff "Minor loose ends"). No file
  in the repo names that id; it is not from lobby code and does not affect play.
- **Four Lantern spots** (`LaunchService`, rule `Rules/Manifest`): a Lantern (`LanternBird`,
  see Lantern below) on each numbered spot and a yellow ring round it. **The ring is the boarding zone** (owner 2026-11-16: "the area should be within the circle, not a random square"): stand anywhere inside it, round the bird, to board (`Config.Lobby.Launch.BoardRadius` 14, read by the painted ring and by the server's radius test `Manifest.onSpot`, so they match exactly; the bird's collider fills only its own body, so the ring stays walkable round it; the `HELO · SPOT n` sign stands on the ring's edge by the door, `FallowLayout.Spots[n].sign`; not yet seen in game).
  The first aboard starts a 20 s countdown and gets a squad-size picker (SOLO / 2 /
  3 / FULL, `Messages.Launch.Squad`, `Manifest.setSquad`; owner 2026-11-10): once that many
  are aboard (4 if nobody picks) the countdown drops to 3 s (`FullCountdown`), so a solo soldier
  lifts 3 s after picking SOLO. The ring empty clears it and the pick, a fifth soldier is left off. At zero the server teleports everyone
  aboard together (`TeleportAsync` into one server reserved per lift, `ReserveServer`, reused
  by every retry; teleport data `Handoff.departure`: slot = boarding order, each soldier's
  signed Loadout, plus `spot`), two
  retries, then "Lantern couldn't lift". In Studio teleports can't run: the panel says so and
  the spot resets after 6 s. Screen: `LaunchUI` (spot, who is aboard against the squad size, countdown, the picker for the
  first aboard).
- **Three hangar desks** (`DeskService`, data `LobbyDesks`): Arms Room (the port fore corner),
  Call-ins (the sapper sergeant, starboard; was the Engineers), Loadmaster
  (slung cases at the foot of the ramp). The Fires desk was folded into Call-ins (owner
  2026-11-16: "we don't need the Fire Support office... the Quartermaster is the main guy who
  sells stuff"; not yet seen in game). **The Call-ins display** (2026-11-16, owner: "similar to how the
  Quartermaster is... the Doorman laying on the floor"; `CallInDisplay`, `CallInDisplayUI`; not
  yet seen in game): behind the sergeant, every call-in he sells on its own pallet in a row along
  the starboard hull (`FallowLayout.CallInDisplay`, data only: origin, length, depth): a crate of
  Hammer shells, the Anvil's binoculars on a map table, a scale model of the Shrike on a stand,
  the Doorman tripod gun, Tripline's six charges by their satchel, a coil of Concertina wire, the
  Speedball ammo bundle, the Aid Bag. Each comes from its Config row's `Display = { Prop, Width }`
  (no Display: a stencilled crate, `Config.Lobby.CallInDisplay.DefaultProp`), using the uploaded
  meshes where they exist (`dep_doorman_*`, `prop_ammo_crate`, `prop_repulsor_mine`,
  `veh_shrike_*` shrunk) and Parts otherwise. A plate over each on a lit board gives its name and,
  for each soldier, ON YOUR RECORD or its price. "Show me the call-ins." turns the camera onto the
  row like the rack: hover lifts and glows, click (or the arrows) frames a piece with its card
  (name, designation, status, BUY, what it does, uses and recharge); Backspace steps back. The
  `DeskShop` list stays as the fallback while the row is not built. R15 crew figures in working dress, a counter, a sign, an F "Talk" prompt. The
  **Every desk talks the same way** (dialog rewrite 2026-11-10, Nova and Tien: "too cryptic,
  no personality"; lines and voices by the lore developer, `LobbyDesks` `talk`, voice sheets
  in docs/lore/desk_crew.md): a greeting picked at random from four, then 1 their kit, 2 a
  question, 3 leave (click or keys 1-3), plus their own bought / short / refused lines. The
  Quartermaster talks through `ArmsRackUI`, the Loadmaster through `LoadmasterUI`, Call-ins,
  Vehicles and the Plot through `DeskDialogUI`; all three build the same talk panel
  (`DeskTalk`, the Loadout's menu dress since 2026-11-17).
- **The desk screens** (2026-11-17, owner: "any NPC interaction UI should be using the
  Prototype 2 UI... the same as the Loadmaster"; not yet seen in game): choice 1 at the
  Call-ins and Vehicles desks opens `DeskScreen`, the Loadout screen's look (`KitView`). The
  Quartermaster keeps the GTA gun wall (Nova, 2026-11-18: the desk screen had replaced it by
  accident; `Config.Lobby.DeskScreen.KeepOwnView = { arms_room = true }`, take him off the list
  to put him on the desk screen). The desk screen:
  what the desk sells in the Loadout's columns with each item's shape, the picked one turning
  in 3D over its stat bars, the person's line under the header in their own voice, and BUY
  (Enter, gamepad Y) in the footer; Back steps back to the talk. Buying is unchanged: the same
  `Record` remote, the server decides (`RecordService`). Look: docs/STYLES.md section 5 > The
  desk screens. `Config.Lobby.DeskScreen.Enabled = false` puts back the camera on the rack, the
  call-in pallets and the plain `DeskShop` list (the rack and pallets stay in the world either
  way).
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
  pencilled track, a title, a legend and a red Plot stamp; about 150 flat parts, built once.
  **Open floor since 2026-11-17** (owner: the walls were "too awkward to walk in and out of"
  and a full lobby would be cramped): no walls, door or lintel; the table stands at X 19 in
  open hangar floor, walked up to from any side (the map reads the right way up from its west
  side); the board stands on two end posts with flat feet (`PlotService`); the red lamp and the
  map light still hang from the deckhead. Players read it as **MAP ROOM** (the officer's sign,
  her lines, the runner's; code keeps "Plot"). The officer stands across the table (26.8, -3) and her prompt reaches 18 studs (`DeskPlace.reach`) to cover the table.
  A white light set flush in the deckhead over the table lights the paper (a hanging lamp
  blocked the map view). While the map is up the talk panel moves to the left edge and the
  map to the right of the screen (the panel covered the map).  **The numbers are placeholders**
  (`Config.Containment.Districts`: Delta 25, the rest 0) until the save service.

- **The walking crew** (2026-11-10, Nova: "give the fallow some life"; roles and lines by the
  lore developer, docs/lore/ship_company.md): six of the ship's company and Army staff -
  plane director (yellow), deck hand (blue), hangar mechanic (green), map room runner, screening
  medic (white smock), lane sentry - walk there and back along `FallowLayout.Crew`, pausing
  at each end. `CrewService` places NpcBody figures once (tag `Crew`, route as an attribute);
  each client walks its own copy (`CrewWalk`: one `BulkMoveTo` a frame on the anchored roots,
  the stock R15 walk and idle played locally once the body is dressed (`CrewReady`), nothing
  replicates) and shows a line over a head when a soldier comes within
  `Config.Lobby.Crew.BubbleDistance` (lines in `LobbyCrew`). No prompts, no collision. Routes
  checked clear of walls and desks in a playtest.
- **R15 crew** (2026-11-10, Nova: "all the npcs to have r15 models like the player instead of
  just being regular blocks"): every desk figure, walker and Lantern's crew chief is a real R15
  rig (`Players:CreateHumanoidModelFromDescription`, one cached rig cloned). Since the second
  pass of 2026-11-11 it is Roblox's default R15 avatar dressed per figure (see Figures and how
  they move); the crew limb meshes of 2026-11-10 are retired. The joints are rigid Motor6Ds (NpcBody `joint`): the stock rig now ships physics
  joints (AnimationConstraint + BallSocket), which made every limb a body the server simulated
  while each client moved only the walker's root, dragging and correcting limbs every frame
  (lag, fixed the same day). The root is anchored and the Humanoid's state machine is off, so
  a figure is one anchored assembly with no physics; desk figures breathe with the stock R15 idle (server), walkers
  are walked by each client. No Humanoid name or health shows; nothing collides. Without the
  meshes a figure keeps the stock R15 body in its colours.
- **Kit on the bodies** (2026-11-10, Nova: "personality"; details by the lore developer,
  docs/lore/desk_crew.md, ship_company.md, docs/CHARACTERS.md): `NpcBody.build` takes a kit
  list of named block accessories (`KIT` in NpcBody). The Quartermaster: reading glasses (two
  lenses on a thin frame; the old solid bar read as a unibrow and the cord hung in the air), a
  clipboard, keys. The Loadmaster: flight helmet pushed up with the visor raised, harness and
  tether, a grease pencil. The sapper sergeant at Call-ins: belt
  gloves, red wire cutters, a wire coil. The watch officer: one-cup headset, a steel mug, a
  rank tab. Lantern's crew chief: gloves and harness. The walking crew: ear defenders, a
  chock and chain, a rag, a clipboard, a mask and blue gloves, a helmet with a slung rifle and
  a white MP brassard. Each piece is welded to one R15 limb, in that limb's own space, so it
  moves with the animation. Every Pike on the ship
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
open door facing out of the ring; no layout change.

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
  down) at the aft edge of the door facing out of the door. Numbers per spot are fixed and out of order
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
- **Where** (owner 2026-11-16: the Quartermaster is the main seller, one desk for call-ins, the
  Loadmaster only signs Loadouts): the desk is each item's own row, `Desk = "<LobbyDesks id>"`,
  or with none the default for its kind, `Config.Lobby.Sellers` (`KitPrices.deskOf`): every gun
  and grenade on the Quartermaster's rack (`ArmsRack` and `ArmsRackUI` show only what his desk
  sells), every call-in at Call-ins (Hammer, Anvil, Shrike, Doorman, Tripline, Concertina,
  Speedball, Aid Bag). No row names a desk today; a desk that sells nothing shows no panel. `DeskShop` is the panel: each
  call-in with what it is, ON YOUR RECORD or BUY · N MERITS (dim "(SHORT)"), the merits, a
  refusal note; it stays up while you stand at the desk.
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
- **Earning merits** (2026-11-10): the match pays them onto this record when a mission ends
  (docs/LOBBY_MATCH_HANDOFF.md > Merits). The match's B Arms Room still offers every gun.
- **Tabs** (2026-11-10, the hard currency; docs/OWNER.md): the record is version 2 and also
  holds `tabs` and the last 50 Robux receipt ids (a version 1 save reads with 0 tabs). The
  rack header and the desk panels show "N MERITS  ·  N TABS". `TabsService` answers
  `MarketplaceService.ProcessReceipt`: a pack from `Config.Tabs.Products` is paid through
  `RecordService.grantReceipt` (`SaveSlot.update`, UpdateAsync; the receipt id is saved with
  the tabs, so a repeat pays nothing) and only then answered PurchaseGranted. While a receipt
  is being paid the soldier's waiting save is written first and a BUY is refused, so no other
  save lands over the tabs. A record that could not be **read** on join (a DataStore error) is
  never saved over: the soldier can buy for that visit, none of it is kept. Every
  `ProductId` is 0 (no product exists on Roblox), nothing prompts a purchase and nothing is
  sold for tabs.

- **Talk** (F on the Quartermaster, `ArmsRackUI` for a desk with a `rack` in `LobbyDesks`): a
  greeting, then 1 "Show me the guns." (the camera on the rack, below; since 2026-11-18 he
  keeps it while the other desks use the desk screen), 2 "How do I get merits?", 3 "That's all." Wording by the lore developer: BUY and a price in
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
  body hidden for this player). The cursor aims at invisible boxes, one per piece (the `Hits`
  folder: the piece's outline plus a quarter stud, never past its place, refitted when its mesh
  loads; they stay put, so the hover never flickers as a gun slides out). The cursor's ray is
  `ScreenPointToRay` (mouse positions are GUI coordinates, under the top bar: the first cut
  used `ViewportPointToRay` and picked 58 px above the cursor); the gun under it slides 0.6 out with a soft yellow rim. A click frames it in
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
    105  Call-ins (27)
     88  Loadmaster (-2), facing the spawn
     80  ┌ramp foot (hangar)┐ well X -30..-10
     20  └ramp top (deck)───┘ comes up facing aft
     21  the Visitor (-25.5), v2 only: in the nook under the ramp's high end, no sign
     50..-10                        ┌island┐ X 22..34 (deck); Plot under it (hangar,
                                    └──────┘  X 4..33, Z -10..30, open floor)
    -15  spot 4 (helo X -12, ring radius 14, sign X 2)
    -48  Vehicles: motor sergeant (9), facing the spawn (hangar)
    -52..-78  motor pool bays X -20..-8, -6..6 (the ATV, 0,-64), 12..24
    -60  spot 3
   -100  ── hangar bulkhead (aft) ──
   -105  spot 2
   -150  spot 1                     screening lane X 19..29, Z -172..-136 (scenery)
   -180  stern ───────────────────────────────
```

Deck surface y 40, hangar floor y 20, sea y 0. Every position is in `FallowLayout`.

## Motor pool (2026-11-17: built, seen in a Studio playtest)

Nova: "the NPC in charge of vehicles in the open space on the other side of the hangar".
Layout by the level designer (`FallowLayout.MotorPool`; `MotorPool` builds it from
`DeskService` for the desk `vehicles`):

- **The motor sergeant** (desk VEHICLES, `LobbyDesks`; lines in docs/lore/desk_crew.md)
  stands at (9, -48) behind the standard counter, facing the soldiers coming round the Plot.
  She sells every row with `Desk = "vehicles"` (today the ATV, 400 merits) on the desk screen
  (`DeskScreen`: a VEHICLES list, the ATV turning as its own body); it is signed into a call-in slot at the Loadmaster.
- **Three painted bays** across the aft hangar, Z -78..-52: X -20..-8 and 12..24 empty for
  later vehicles, and the ATV in the middle one on the spawn's centre line (0, -64), nose to
  the spawn, so it shows down the aisle past the Loadmaster. It is the match's own build
  (`Shared.VehicleBody`, anchored). Lashing chains were tried and taken out: four straight
  bars from the deck to the fenders read as legs, the ATV on stilts.
- **Dressing:** two red tool chests behind her (9, -56) and (9, -60); a tyre rack of eight in
  the starboard aft corner (X 28..32.6, Z -96..-82); a fuel point on a pallet with six jerry
  cans and an extinguisher in the port aft corner (-28, -90); one hangar light over the bays
  (0, 37, -64; the lobby's 13th light). About 50 Parts and the ATV's 30.

## Music (2026-11-10)

`LobbyMusic` (client) plays a shuffled playlist of four licensed tracks from Roblox's audio
library (free for any experience, nothing uploaded): "A Light Dies Out On The Water", "Lost In
Time" (ambient mix, APM), "Fading Hope", "Silhouette Dream" (ambience version, APM); about 10
minutes before it repeats. Low in the mix (`Config.Lobby.Music.Volume` 0.22 on its own
`Music` SoundGroup, so a volume setting can follow; OWNER.md: no harsh sound), 3 s between
tracks, a 4 s fade in on arrival, a 2.5 s fade out when your Lantern lifts (the rotor takes
over before the teleport's fade), back on a failed lift. Tracks were picked by name and mood,
not by ear: swap them in `Config.Lobby.Music.Tracks`.


## Ship sounds (2026-11-11)

Nova: "noises that one would hear on a boat. people moving around, crew mumbling, give some
life to it". `ShipAmbience` (client) plays Pro Sound Effects clips from Roblox's audio library
(licensed for any experience; all real aircraft-carrier and crew recordings), every one a row
of `Config.Lobby.Ambience`, low in the mix in an `Ambience` SoundGroup that fades in on arrival
and out with the music when the Lantern lifts. Nothing replicates.
- **Beds**, one per area, everywhere in it: the hangar plays a carrier hallway loop (movement,
  distant voices), the flight deck a motor idle with wind and water. Roblox sound passes through
  walls, so the beds cross-fade over 2.5 s by height (root above Y 36: the deck), and every
  other sound belongs to an area and is silent outside it.
- **Spots**, loops at anchors (`FallowLayout.Ambience`, invisible parts FallowBuilder puts in
  `Fallow.Ambience`): the carrier bridge's radio chatter and voices in the Plot; crew talking
  low by the desks and aft past the ramp. Each starts at a random point in its clip.
- **One-shots** every 9 to 22 s from a random anchor of their area: a steel door, lockers,
  latches, a carrier's interior horn in the hangar; the flight-deck loudspeaker on the island.
- **Crew footsteps**: the walking crew (`CrewWalk`) step on the deck every 2.4 studs with the
  match's Footsteps bank (hard surface).
Picked by description, not by ear: swap a clip in `Config.Lobby.Ambience`.

## Figures and how they move (2026-11-11)

Nova: the crew's walk "looks silly and dont fit the vibe", the soldier's lobby walk is hunched
and a hand floats off the SMG; "standing up straight with the gun at a resting position in a
sling across his chest"; the crew's block eyes "dont look right" on the R15 bodies.
- **Clips**: Roblox's Rthro idle and walk (owner's pick over a Mixamo download), for the crew
  (`Config.Lobby.Crew.Animations`) and the soldier (`Config.Lobby.Soldier.Animations`, plus the
  Rthro run above 12 studs/s). Measured on our rig: the stock walk is made for 14 studs/s (the
  crew played it at 0.45, slow motion), the Rthro walk for 5.7 and the run for 10.5. The crew
  walk at 5.5 studs/s at rate 0.96; the soldier's rate is kept within 0.6 to 1.6.
- **The sling**: PikeBody moves the Tool's `RightGrip` weld onto the upper torso
  (`Soldier.Sling`: grip low right, muzzle down past the left hip, the top toward the face);
  `SlingHands` (client, every soldier) solves both arms onto the carried gun after the
  Animator each frame: the right palm on the grip, the left on the handguard part-way to the
  muzzle, so it fits any gun. Two-bone IK, the method of Tien's revive arms, kept separate.
- **The crew are Roblox's default R15 avatar** (Nova, second pass: "just make them default r15
  models and then we can just change clothing/attributes as needed on each"; the crew limb
  meshes, the face/hair/headgear meshes and the block kit are gone). `NpcBody.Dress` per figure
  (`DeskService`, `CrewService`, `LanternBird`): body colours (head and arms skin, picked by
  name; torso the shirt; legs the trousers) and optional catalog ids `shirtId`, `pantsId`,
  any catalog `items`, applied with `Humanoid:ApplyDescriptionAsync` through `Shared.AvatarLook`
  (each id's kind is looked up once: layered shirt, pants, jacket; hat, hair, face, front,
  shoulder accessory; classic 2D shirt or pants). First outfits are the suggestions from the
  picks page (https://claude.ai/artifact/EmC4Vf5rWuvPCBAZDoGRZ7): coveralls and ear
  defenders on the deck crew, woodland uniforms and patrol caps on the Army desks, flight
  suits on the Loadmaster and crew chief, a plate carrier and helmet on the lane sentry.
- **The soldier's look** (Nova: "not really a fan of how he looks"; "the new look should change
  in match as well"): `Config.Player.Look`, catalog items on the default R15 body for players
  and bots in the match (`PlayerSetup`, `BotService`) and on the ship (`PikeBody`): a tactical
  vest over an olive shirt, combat pants and a black FAST helmet (the AVS plate carrier is
  out: rigid, it poked through the shirt's vest; shirts layer over pants), a
  buzzcut (dropped: that catalog piece covers the face). Each player wears their own avatar's
  head, face and skin tone (`Look.PlayerFace`; bots keep the default face). `Look.Enabled = false`
  puts the Pike limb body back.
- **Slow stride, sprint on Shift** (second pass): `Soldier.WalkSpeed` 6.5, `SprintSpeed` 15
  while `Keys.Sprint` or `Soldier.SprintPad` is held (the Rthro run above 9 studs/s).
## Files

| Place | File |
|---|---|
| Project | `lobby.project.json` (shares `src/shared`; `src/lobby/shared` as `ReplicatedStorage.Lobby`; maps the match's `src/server/PlayerSetup.luau` into the lobby server and `src/client/HudTheme.luau`, `PaletteController.luau`, `LoadoutMenu.luau` into the lobby client; sets `Lighting.Technology`) |
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `FallowArt`, `PikeBody`, `NpcBody`, `DeskService`, `ContainmentBoard`, `PlotService`, `LaunchService`, `LanternBird`, `ArmsRack`, `LoadmasterService`, `OpticService` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI`, `ArmsRackUI`, `LoadmasterUI`, `DeskShop`, `RecordClient`, `LobbyMusic`, `ShipAmbience`, `SlingHands`, `HoldStill`, `RadarSpin`, `LanternSpool`, `SoldierMoves` |
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `FallowArt`, `PikeBody`, `NpcBody`, `DeskService`, `VisitorBody`, `ContainmentBoard`, `PlotService`, `LaunchService`, `LanternBird`, `ArmsRack`, `LoadmasterService` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI`, `ArmsRackUI`, `LoadmasterUI`, `DeskShop`, `RecordClient`, `LobbyMusic`, `ShipAmbience`, `SlingHands`, `HoldStill`, `RadarSpin`, `LanternSpool`, `SoldierMoves`, `VisitorLook` |
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
   Plot, climb the ramp to the spots, stand inside a spot's ring (panel + countdown; in Studio it ends with the
   "Teleports don't run in Studio" line).
4. Test places: Nova's own test experience, start place ZCS Dev (83558708746036), launches
   into Match Dev (108949482095254) and that match flies home to ZCS Dev (`Config.Places.Dev`).
   The group experience opens on the lobby (87556879379942) and launches into Checkpoint
   Delta (125769854992316): `docs/LOBBY_MATCH_HANDOFF.md`.
5. Launch for real: publish the place, join it from the Roblox app (with a friend for a
   two-person bird), board a spot. You should land in a match server together.

## Boarding since loop sprint 2 (2026-11-20)

Squads form in the squad panel (P) and fly from the Mission Board in the map room
(PROGRESSION.md > Missions). The helicopter spots stay as scenery; their rings no longer board
(`Config.Lobby.Launch.RingsBoard = false`; `true` puts the old boarding back) and the sign
reads "Pick a mission in the map room". Both ways fly through `LaunchService.send`.

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
  sidearm, grenade, up to four call-ins. **EDIT** (2026-11-11, Nova): a gun that takes
  attachments has an EDIT button on its row (`LoadoutMenu` option `edit`); it opens `GunsmithUI`:
  the rack's copy of the gun turning in a viewport, a list per slot (`Config.Attachments.Slots`:
  the Barrel, NONE or the suppressor), the suppressor shown on the muzzle as it is picked, DONE
  or BACK. The row then reads e.g. "M16A4 +SUP". What is fitted is signed with the rest (the
  Loadout's `attachments`, saved, flown to the match). **Optic** (2026-11-18, Nova; the M16A4
  only): under the Barrel, "X/3 OPTICS UNLOCKED" and NONE, Red dot, CompM2, ACOG; a locked
  optic is greyed with `BUY · <price>`, an owned one reads OWNED, the fitted one is lit
  EQUIPPED. BUY and picking an optic go to `OpticService` (the `Optic` remote): the server
  buys onto the record and signs the fitting at once (`LoadmasterService.fit`); the row only
  changes when it answers, and BACK keeps a fitted optic (rules and numbers:
  [PROGRESSION.md > Attachments](../PROGRESSION.md#attachments)). Verified live in ZCS Dev
  2026-11-18: buy, refused buys (owned, short), refused fits (not owned, wrong gun), fit. The soldier is held still (`HoldStill`, shared with
  the rack); BACK or Backspace steps out. Prototype: the whole catalog may be signed for.
  **Bigger, with the item in 3D** (2026-11-16, owner; not yet seen in game): the screen fills
  most of the display (1560x880 at 1080p, a tabbed layout on a phone), each row shows the
  item's shape, and an inspect panel shows the hovered or picked item turning in 3D over its
  stat bars (guns, call-ins, grenades); Enter or gamepad Y signs. Models from
  `Shared.Showcase` (booted in both places), numbers from `Rules/ArmsStats` and
  `Rules/KitCard`; layout in `docs/STYLES.md` §5 > The Loadout screen. Stand-ins: the Hammer,
  Anvil and Aid Bag (a case in their colour) and the frag (a plain grenade) have no model yet.
  **KIT MODS tab** (2026-11-18, Nova; for the owner to decide, PROGRESSION.md > Kit Mods):
  LOADOUT | KIT MODS beside BACK, the Loadout screen's own tab buttons (`LoadmasterUI`). KIT
  MODS covers the lists with `KitModsTab`: a row per mod with its name, what it does, RANK n/3
  and pips, the next rank's price and BUY (red when affordable), MAXED, or greyed COMING SOON
  for a mod not switched on. BUY goes to `KitModService` on the `KitMods` remote; the row
  changes when the server answers. Seen in ZCS Dev (the panel, refusals: disabled, not next,
  beyond max, short); a bought rank not yet (no test merits on the dev record).
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
- **Real board numbers** wait for the save service (F9).
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
- **The lobby soldier, after a look in game**: a relaxed carry (slung or low-ready clip) if
  the match's rifle idle reads too ready for the ship, a jump clip, the match's footsteps.
- `Config` split by domain (F10) is not done: the lobby loads the match's tuning too.
