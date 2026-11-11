# The Arms Room corner, a roomier Plot, R15 crew (Nova, 2026-11-10, second pass)

**Changed:** on `nova/lobby`, committed locally, not pushed. The Arms Room fills the hangar's
port fore corner: the Quartermaster behind a GTA-style glass counter (sidearms, melee, grenades
on a tilted felt bed; the melee section waits for melee weapons), the long guns on a 32-place
wall on the hull, wire fence at the counter's ends (`ArmsRack`, `FallowLayout.ArmsRoom`). The
rack screen: the cursor aims at fixed per-place boxes (`Hits`), a click frames the whole gun in
the space left of its card, Q swaps wall and counter. The Plot's west wall moved out 10 studs:
the map table sits mid-room with floor in front, the officer across it (18-stud `reach`), a
deckhead light over the paper, the talk panel moves aside in the map view; Fires moved out
beside the door, the runner rerouted. Every NPC is an R15 rig in a new crew body
(`assets/3d/build/crew.py`, nine `npc_crew_` meshes, worn untextured and coloured per figure)
with a face, hair, belt, headgear and kit welded to its limbs; desk figures idle, walkers walk
(stock R15 clips, `Config.Lobby.Crew.Animations`). The Quartermaster's glasses are rebuilt.
**Verified:** ZCS Dev playtests: both displays, hover and click framing on a rifle and a pistol,
Q and the button, the Plot's talk prompt from the table's front and the map view, the
Quartermaster, Loadmaster, mechanic (walking) and crew chief close up. Tests 131 pass, lint and
types clean. Not checked: a narrow (phone) screen on the rack, anything on a live server.
**Heads-up:** Tien's area touched: `MeshAssets` (nine `npc_crew_` entries, `limbOf`),
`ASSET_IDS.md`, `build_assets.py` (imports `crew.py`), `Attributes` (`RackDisplay`, `RackFace`,
`RackSpan`, `CrewReady`), `Config.Lobby.Rack` (`InspectHeightShare`, proportional `Margin`)
and `.Crew` (animations). The crew walk and idle are Roblox's stock R15 clips, not ours.
**Next:** a real face and kit as meshes for the crew (still small blocks), the four guns not
reworked (revolver, M2010, Goose, M17), melee weapons for the counter's empty section, Nova's
voice lines (record into `assets/audio/voice/`, then bank and wire them).

**Later the same day:** lobby lag fixed (crew rigs on rigid Motor6Ds), Arms Room hover fixed,
first person in the match (T: arms, gun, its own reload, kick, sway; shots from the barrel;
crosshair hides down the sights), real-world sights on all nine guns with a `sight` point per
gun. Nova playtested: okay overall. **Still needs work:** the scopes (M2010, M110, Goose's
optic) are only a ring and a crosshair, no zoom; `Config.Camera.FirstPerson.SightEye` may want
tuning. Next session: the scopes first.
