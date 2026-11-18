# The ATV's own model (Nova + Claude, 2026-11-17)

**Changed:** the ATV wears Nova's model instead of the Part body: a sport quad with a tall
cowl, a low saddle and a rear rack with a rail, painted to Nova's colour reference (olive upper
panels, near-black lower body and seat, steel bars; no markings). The body is cut from Nova's
1.7M-tri OBJ into `assets/3d/source/atv_body.obj` (`assets/3d/build/atv.py -- --prepare`) and
painted in the build; the wheels are built from primitives (cut from the model they showed
through). ~12k tris an ATV, a budget exception Nova set. `VehicleBody` dresses the chassis
with the meshes (server templates; `publish` copies them for the clients' sling stand-in;
`waitForMeshes` for the motor pool), the Part body stays as the fallback. The body numbers
were re-measured on the model: tyre radius 1, ride height 1.23, the seats lower.
**Verified:** Studio (built-in MCP): called in, the match ATV and the motor pool's ATV wear
both meshes, the wheels are solid, no errors; Nova saw the first upload work. Tests (492), lint,
types, both builds. Not checked: driving feel on the narrower track and lower seats, the rider
pose on the lower saddle, the slung stand-in with the meshes.
**Heads-up:** the 70 MB `assets/3d/atvrbx.obj` is git-ignored; keep it to re-cut the body.
**Next:** drive it and tune the seats and rider pose to the new saddle if they float or clip.
