# Every desk on the Loadmaster's look (Claude, 2026-11-17)

**Changed:** owner: "Any NPC interaction UI should be using the Prototype 2 UI... the same as
the Loadmaster." Choice 1 at the Quartermaster, the Call-ins sergeant and the motor sergeant
now opens one screen built like the Loadout (`src/lobby/client/DeskScreen.luau`): what the
desk sells in the Loadout's columns with each item's shape, the picked one turning in 3D over
its stat bars, their line under the header in their own voice, BUY at the bottom right
(Enter / gamepad Y). The talk panel of every desk is one build in the menu dress
(`DeskTalk.luau`, used by `DeskDialogUI`, `ArmsRackUI`, `LoadmasterUI`). The Loadout's frame,
rows and inspect panel moved to `src/client/KitView.luau`; `LoadoutMenu` builds from it.
`Showcase` shows a vehicle call-in as its `VehicleBody` (the ATV turns in its own shape in the
Loadout too). The Gunsmith (EDIT) takes its gun from `Showcase` and has the cream corners.
Wording: `Rules/DeskOffer` (spec first).
**Verified:** stylua, selene, both builds, 502 Lune tests, luau-lsp on match and lobby. Not
seen in Studio (the owner was playtesting).
**Heads-up:** Nova: `LoadoutMenu` was refactored onto `KitView` with the same behaviour; check
the Loadmaster's LOADOUT still looks the same. `Config.Lobby.DeskScreen.Enabled = false` puts
back the rack camera, the call-in pallets and `DeskShop` (kept as the old path).
**What to check in the lobby place:** each desk's talk panel (cream rows under the mouse, keys
1-3); "Show me the guns." / "the call-ins." / "the vehicles." open the screen with the right
lists (Quartermaster: PRIMARY, SIDEARM, GRENADE; Call-ins: eight call-ins; Vehicles: the ATV
turning); BUY with enough merits (the line changes to their "bought" line, the badge to ON
RECORD, the wallet drops), BUY short (dimmed, their "short" line); Back returns to the talk;
the Loadmaster's LOADOUT and EDIT unchanged; a phone-sized window gets the compact layout.
**Next:** a Studio pass with screenshots; if the owner misses the rack camera, a "LOOK ON THE
RACK" button on the screen could open it.
