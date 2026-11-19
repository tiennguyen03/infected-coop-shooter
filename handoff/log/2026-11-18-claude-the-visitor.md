# The Visitor, dialog only (Claude, 2026-11-18)

**Changed:** the hidden seller now stands in the nook under the ramp (Carrier v2 only): walk down
the port side behind the ramp, through the tarp's gap. A man in a long dark raincoat, a red
ESCORT REQUIRED badge, hands in his pockets, his head slowly following the nearest soldier.
No sign. Talk (E, 8 studs, needs a line of sight) opens the shared desk panel: a first-meeting
line once a visit, then a random greeting; "What do you sell?" (nothing this week), "Who are
you?", "Leave." (a parting line, then it closes). He sells nothing. The deck hand gained "Don't
go under the ramp. Nobody's under the ramp." Files: `LobbyDesks` (desk `visitor`, new optional
`first`, `farewell`, `unmarked`), `FallowLayout.Desks`, `DeskService`, `NpcPose`, new
`VisitorBody` (server) and `VisitorLook` (client), `DeskDialogUI`, `LobbyCrew`,
`Config.Lobby.Visitor`. Canon in `docs/lore/desk_crew.md` > The Visitor and `docs/LORE.md`;
his stock rules are in `docs/sprints/CARRIER_V2.md` > The Visitor (not built).
**Verified:** stylua, selene, both rojo builds, Lune tests, luau-lsp for match and lobby. Not
seen in Studio: the pose (set blind like the other sellers), the coat parts' fit on the rig,
the head turn's direction and speed, the prompt through the tarp.
**Heads-up:** Nova: this touches your `LobbyDesks`, `DeskService`, `DeskDialogUI`, `NpcPose`,
`FallowLayout`, `LobbyCrew` and lobby `Main.client` (one line). A desk with `unmarked = true`
gets no sign and a line-of-sight prompt. The first-meeting line is per visit (client memory):
the record has no flags; save it there if the owner wants it once for ever.
**Next:** look at him in Studio (feet, coat skirt, badge facing out, head turn sign); a catalog
raincoat if one fits; then the item list (systems designer + lore developer) and the weekly
stock.
