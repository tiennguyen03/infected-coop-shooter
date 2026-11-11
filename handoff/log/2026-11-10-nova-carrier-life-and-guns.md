# The Carrier comes alive, a world map, cleaner guns (Nova, 2026-11-10)

**Changed:** Nova's list, all on `nova/lobby`, committed locally, not pushed. The balcony
fills the side-lift opening wall to wall, the coast burns bigger and redder (ember patches in
the terrain), and HARLAN replaces HRD everywhere it was painted. The Plot's silent plotter is
gone: Control's watch officer (a talking desk, `LobbyDesks` id `plot`) stands at a paper map
of the Harlan Corridor (`WorldMap`, `WorldMapData`, canon docs/lore/world_map.md); "Show me the
map." glides the camera over it. Six crew walk the ship and say a line as you pass
(`LobbyCrew`, `CrewService`, client `CrewWalk`). Every NPC wears the lore's kit (`NpcBody`
kit), and Pike on the ship wear the screening band, a chemlight and the tourniquet
(`PikeBody`). The M16, MP5, M249, Mossberg and M110 are rebuilt in `guns.py` and re-uploaded.
**Verified:** ZCS Dev Studio playtests: the map, the officer's talk and camera, the walkers'
routes swept clear of walls and desks, bubbles, the kit close up, the new guns on the rack.
Tests 131 pass, lint and types clean. Not checked: fires in screenshots (captures don't
render particles), the new guns in a hand in the match, anything on a live server.
**Heads-up:** Tien's area touched: `guns.py`, `MeshAssets` (five new mesh ids; grip origin and
muzzles unchanged), `ASSET_IDS.md`, `Attributes` (`CrewTag`, `CrewId`, `CrewRoute`),
`Config.Lobby.Crew` and `.WorldMap`. A full asset build also re-exported the ship and Lantern;
those exports were reverted (unchanged source), only their fingerprints were added.
`docs/ROADMAP.md` still says HRD and Credits (Tien's file: HARLAN and merits now).
**Next:** Nova playtests, then push. The Pike kit on the match body (PlayerSetup) if Tien
wants it; earning merits from runs.
