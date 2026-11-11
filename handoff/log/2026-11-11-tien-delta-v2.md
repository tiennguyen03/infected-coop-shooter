# Checkpoint Delta v2 proposal (Tien + Claude, 2026-11-11)

**Changed:** nothing a player sees. A proposal for a rebuilt Checkpoint Delta, in Blender only:
a highway through the Gate, an outside (Approach, Screening Lot, the Pens, Bus Park) and a base
behind it (Yard, Barracks, Command Post and the Mast, Motor Pool deck, the Stacks, the Shed, two
pads), with 2 and 3 storey buildings, a walk over the road, a bridge, a pit and a channel. The
bus and humvee are rebuilt to the cars' standard; an SUV and an ambulance are new. Files:
`assets/3d/build/delta_v2.py`, `assets/3d/build/delta_kit.py`, the `--delta-v2` flag in
`build_assets.py`, `docs/sprints/DELTA_V2.md`, previews `delta_v2_*.png`.
**Verified:** built and looked at in live Blender, view by view, against today's map rebuilt
from `Missions/Delta.luau`; the headless run renders all 41 previews; the overlap check finds
nothing; triangle counts are in the doc. **Not checked:** anything in Studio (colliders,
spawns, pathing, lights, frame rate); `build_assets.py -- --delta-v2` was not run end to end
(the kit was built through `delta_v2.py`); no Luau changed, so the Luau checks were not rerun.
**Heads-up:** `build_assets.py --only` now skips any `--flag`, not just `--force`. The
generator rewrites `assets/3d/palette.md` with the same content (line endings only); do not
commit that. `assets/3d/delta_v2.blend` is written by the headless run and is not committed.
**Next:** the owner looks and answers the questions at the end of the doc; then the step list
there (kit upload, `Delta.luau`, colliders, spawns, a live pathing test).
