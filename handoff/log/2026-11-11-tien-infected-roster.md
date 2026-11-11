# Infected roster proposal (Tien's agent, 2026-11-11)

**Changed:** nothing a player sees. The five unbuilt common Infected (Bloat, Shedder,
Crawler, Kite, Growth) now exist as a look proposal in the v2 style:
`assets/3d/build/infected_roster.py`, pictures `assets/3d/build/previews/infected_v2_<form>.png`
and `lineup_infected_roster.png` (all nine forms to scale), described in `docs/STYLES.md` §7
"Infected roster". Stacks on the v2 proposal branch (`claude/infected-remake-look`).
`build_assets.py` registers the meshes only with `-- --infected-roster`.
**Verified:** built and looked at in live Blender (scene `InfectedRoster`), then rebuilt
headless from the file (the committed previews). Triangles at or under the sheet targets
(1,866 / 2,332 / 536 / 600 / 1,200). No `src` change. Not checked: anything in game; the
`-- --infected-roster` path was only checked to register and build its 52 meshes in memory
(no FBX exported, nothing uploaded).
**Heads-up:** the Shedder still reads a little like plate armour in flat light; the Kite and
Growth sit exactly on their caps. Asymmetric meshes need the X mirror before upload, as v2.
**Next:** owner picks per form. Building one into a stage needs its own design call (Crawler
hip height and clip, Kite mover, Growth sacs as spawners) before any upload.
