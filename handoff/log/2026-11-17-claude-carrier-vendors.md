# Carrier v2: vendor corners, open map room (Claude, 2026-11-17)

**Changed:** nothing in game. The Carrier v2 proposal (PR #62) now has a corner for every seller,
each with its own props, pose and light: the Quartermaster on his stool under a reading lamp,
the sapper sergeant smoking on a mortar crate, the Loadmaster in a cargo-net hammock, the motor
sergeant on her tyres with a dog, Control's watch officer with her boots on the map table, and a
restricted cage for a future visitor who sells experimental weapons. The map room has no walls.
Helicopter 20 is gone (Nova's motor pool has its floor). Merged `origin/main` (vehicles, motor
pool, one main seller) into `claude/carrier-v2`. `carrier_kit.py`: six `prop_vendor_*` pieces,
posed stand-ins `npc_carrier_*` (pictures only, `register(ba, npcs=True)`), `ref_carrier_atv`;
`carrier_v2.py`: `VENDORS` views, `render_vendors()`; 11 `vendor_*` pictures, all 62 previews
re-rendered.
**Verified:** looked at each corner at eye level and the hangar from above in live Blender. Not in
Studio (owner playtesting), not on a device. Ship triangles 49,478 (was 49,490).
**Heads-up:** Nova: steps 9b and 9c in the doc are the lobby changes (two counters off, the
Quartermaster's feet, delete the Plot walls). The character lines are a proposal; the lore
developer writes them into `docs/lore/desk_crew.md` once the owner says yes. Check Roblox's rules
on showing a cigarette (fallback in the doc).
**Next:** owner looks at Desktop `Carrier_v2/vendor_*.png` and answers the doc's questions 5-7.
