# Lobby: the Call-ins display (Claude, 2026-11-16)

**Changed:** behind the Call-ins sergeant a row of pallets along the starboard hull shows every
call-in he sells: a crate of Hammer shells, binoculars on a map table (Anvil), a scale model of
the Shrike on a stand, the Doorman tripod gun, Tripline's six charges, a coil of Concertina
wire, the Speedball bundle, the Aid Bag. A lit board over them has a plate per call-in: its
name, and for you ON YOUR RECORD (yellow) or its price. "Show me the call-ins." opens a view
like the rack: hover lifts and glows a piece, click or arrows frame it with its card and BUY,
Backspace steps back. Files: new `CallInDisplay` (server) and `CallInDisplayUI` (client);
`Display = { Prop, Width }` on each `Config.CallIns` row, `Config.Lobby.CallInDisplay`,
`FallowLayout.CallInDisplay` (origin, length, depth: move it by data), `LobbyDesks` `display`
labels, a hook in `DeskDialogUI`, one line in the lobby `Main.client`.
**Verified:** stylua, selene, both builds, 440 Lune tests, both type checks. Not seen in game:
the prop shapes, the mesh scales (the Shrike at 0.13, the mines at 0.45) and the camera
framing are all first guesses.
**Heads-up:** Nova: the wire spools behind the sergeant are gone (the display replaces them);
an invisible barrier keeps soldiers out of the row. `DeskShop` stays as the fallback list.
**Next:** in Studio: look at the row from the walk, open the view, hover and click every piece,
buy the Doorman, check its plate turns to ON YOUR RECORD; tune `Display.Width`, the prop
builders and the camera from what you see.
