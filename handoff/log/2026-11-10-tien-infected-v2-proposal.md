# Infected v2 proposal (Tien's agent, 2026-11-10)

**Changed:** nothing a player sees yet. A remade look for Walker, Runner, Brute and Hocker
sits beside the current bodies for the owner to compare: `assets/3d/build/infected_v2.py`,
pictures in `assets/3d/build/previews/infected_v2_<form>.png` and `lineup_infected_v2.png`,
described in `docs/STYLES.md` §7 "Infected v2". The Warden is untouched. `build_assets.py`
registers the v2 meshes only with `-- --infected-v2`.
**Verified:** built and looked at in live Blender, then rebuilt headless from the file (same
shapes, the committed previews). Triangle counts under `BODY_TRI_CAP` (1,792 / 2,100 / 2,088 /
1,632). Static checks and Lune specs pass (no `src` change). Not checked: anything in game.
No FBX exported, nothing uploaded, `MeshAssets` untouched.
**Heads-up:** v2 heads and torsos are not symmetric: mirror them in X before upload. The
Walker's legs and arms and the Brute's arms are sided meshes. The previews render without
Workbench's specular sheen, so they are a little flatter than the `ref_inf_*` previews.
**Next:** owner picks per form (adopt, change, or drop). For an adopted form: build with
`--infected-v2`, upload, update `MeshAssets`, then check gore stumps, hitboxes and clips in a
playtest.
