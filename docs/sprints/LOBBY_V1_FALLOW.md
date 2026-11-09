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
  rising aft to the deck through an open well, invisible walls at every edge, the sea, the coast to
  the north with the Burn's smoke columns standing over it. A clear afternoon
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
| Server | `src/lobby/server/`: `Main.server`, `FallowLayout`, `Build`, `FallowBuilder`, `PikeBody`, `NpcBody`, `DeskService`, `ContainmentBoard`, `PlotService`, `LaunchService` |
| Client | `src/lobby/client/`: `Main.client`, `LaunchUI`, `DeskDialogUI` |
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
- **Art**: the art director's build sheet for the Fallow and the desk crew; Lantern mesh;
  sounds (rotor spool on lift, ship PA tone, the plotter's grease pencil, a low radio net).
- **Day/night cycle** (owner and Nova, an idea for later): drive `Config.Lobby.Sky` over time,
  light the deck floodlight housings and the Burn's orange at night.
- **The Plot's launch and recovery radio lines** (LORE.md > The Fallow) are not played yet.
- **Other teams' callsigns** (not all Pike) are open with the lore developer.
- **The match's animations in the lobby** (unarmed idle and walk): the Pike body uses Roblox's
  default R15 set on the ship today.
- `Config` split by domain (F10) is not done: the lobby loads the match's tuning too.
