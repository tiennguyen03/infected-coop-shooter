# Mile 14 design pack and Blender first look (Claude for Tien, 2026-11-09)

**Changed:** nothing in the game. The design team (lore, systems, level, art agents) designed
Mile 14: a new common form, the Possum (bodies on the road that get up), and a new boss, the
Driver (the lead-bus driver still belted to his torn-off seat; vents gas, gas flashes off
burning pumps). The level designer fixed seven breaks in the old layout. Built live in Blender:
`possum_limb` in `build_assets.py`, `assets/3d/build/driver.py`, 18 interstate meshes in
`highway.py`, the mission laid out in `mile14_map.py` / `assets/3d/mile14_map.blend`.
**Verified:** full headless asset build passes (Possum 1,428 tris, Driver 2,156, all under
cap); renders in `assets/3d/build/previews/map14_*.png` and `mile14_lineup_draft.png`. Not
checked: anything in Roblox (nothing uploaded), the clips on the new bodies, placement checks
on the Mile 14 layout.
**Heads-up:** the design is a proposal; CHARACTERS/LORE/PROGRESSION/LEVELS are unchanged
until the owner approves (`docs/sprints/SPRINT_20_MILE14.md` has the decision list). The full
headless build rewrites every FBX and preview with new timestamps; only the new assets were
committed.
**Next:** owner decisions; then the common Bloat sheet, collider lists, uploads, and the
IndexService split so the Driver can share the Warden's frame.
