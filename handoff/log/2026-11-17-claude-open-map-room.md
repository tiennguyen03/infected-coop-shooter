# Map room opened up (Claude, 2026-11-17)

**Changed:** the walls, door and "THE PLOT" lintel round the map room under the island are
gone (owner: awkward to walk in and out of, cramped with a full lobby). The map table stands
in open hangar floor and is reachable from any side; the Containment Board now stands on two
end posts with flat feet; the red lamp and the map light still hang from the deckhead.
Players read "MAP ROOM": the watch officer's sign and two of her lines, the runner's name tag
and one line. Files: `FallowBuilder.buildPlot`, `FallowLayout.Plot` (door fields and the
unused `Board.plotter` removed), `PlotService` (posts), `LobbyDesks`, `LobbyCrew`.
**Verified:** stylua, selene, both rojo builds, Lune tests, luau-lsp for both places. Not
played (the owner was playtesting; no Studio MCP used).
**Heads-up:** Nova: code still says "Plot" (desk id `plot`, `PlotService`, `FallowLayout.Plot`);
only player text changed.
**Next:** walk round the table in Studio and check the board's posts and the red lamp read
right in the open hangar.
