# Carrier v2 proposal (Claude, 2026-11-16)

**Changed:** nothing in game. A Blender proposal for the lobby ship: today's Carrier rebuilt as a
"before" and revamped (frames, pipes, doors, desks as places, map room, aft hangar life, deck
gear, rails, bigger boarding rings), a burning city off port, 12 Easter eggs. New
`assets/3d/build/carrier_v2.py` (scene + 63 previews), `carrier_kit.py` (about 50 kit pieces,
opt-in `build_assets.py -- --carrier-v2`), `docs/sprints/CARRIER_V2.md`.
**Verified:** looked at every view in live Blender (eye level at each desk, deck, shore, eggs,
top-downs, before/after pairs). Not in Studio, not measured on a device.
**Heads-up:** Nova: the step list to put it in the lobby is in the doc and builds on #55
(`Spot.sign`, ring boarding), #57 (`callins` desk) and #61 (`FallowLayout.CallInDisplay`). The
ship draws about 3x today's triangles, over STYLES' cap; cuts are listed. Previews are mirrored
left-right like every ship preview.
**Next:** owner looks at Desktop `Carrier_v2` and answers the four questions in the doc;
performance-reviewer on the budgets; then Nova builds it.
