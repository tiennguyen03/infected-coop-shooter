# The ATV arrives in a crate (Nova + Claude, 2026-11-17)

**Changed:** Tien's idea. The helo no longer hovers and lowers the ATV: it flies straight
over the mark without stopping, the crate under its skids, and lets go so the crate falls
straight down and lands when the server's ATV appears. The walls fall open flat, the lid
kicks off behind, the boards fade after 4 s. Arrival style `crate` in `CallInArrivalFX`
(`sling` is still there); the crate is the vehicle's own size (`Rules/Arrival.crateSize`,
spec first, with `flyover` and `hinge`), or a `Crate` on the Vehicle block. Row:
`Config.CallIns.ATV.Arrival`. Control's Inbound and Down lines redrafted for the crate.
**Verified:** Studio: called in, the crate lands, opens and fades (5.5 x 4 x 8.5, the lid 12.3
studs behind); Nova saw it land "as expected". Tests (495), lint, types, both builds. Not
seen: the fall itself in a screenshot (the camera would not hold still), 2 players.
**Heads-up:** the two radio lines are my draft: the lore developer updates LORE.md (still the
sling) once Nova approves them. Boarding fixes in the same branch (see the ATV model note).
**Next:** Nova to approve the radio lines; a crate stencil or straps if it reads plain.
