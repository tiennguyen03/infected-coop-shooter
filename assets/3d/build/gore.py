"""Gore pieces for the dismemberment (owner, 2026-11-08; GoreService, GoreFX): the stump
welded where a limb came off and three flesh chunks thrown at body hits. The Infected
bodies themselves stay the blocky v2 limb sets in build_assets.py (owner: "I like the
blocky Roblox style"). Pale, raw and bone; the red only where it is fresh.
"""

import math


class Surf:
    """A loft's rings, kept so details can be placed on its surface. A ring is
    (z, rx, ry_front, ry_back, cx, cy); front is -Y."""

    def __init__(self, rings):
        self.rings = [tuple(r) + (0.0,) * (6 - len(r)) for r in rings]

    def ring_at(self, z):
        rs = self.rings
        if z <= rs[0][0]:
            return rs[0]
        for a, b in zip(rs, rs[1:]):
            if a[0] <= z <= b[0]:
                t = (z - a[0]) / max(b[0] - a[0], 1e-6)
                return tuple(a[i] + (b[i] - a[i]) * t for i in range(6))
        return rs[-1]

    def on(self, z, ang, out=0.02):
        """(point, normal, yaw degrees) on the surface at height z, azimuth `ang` degrees
        (0 front, 90 the character's right, 180 back), pushed `out` along the normal."""
        _, rx, ryf, ryb, cx, cy = self.ring_at(z)
        a = math.radians(ang)
        ry = ryf if math.cos(a) >= 0 else ryb
        x, y = cx + rx * math.sin(a), cy - ry * math.cos(a)
        nx, ny = math.sin(a) / max(rx, 1e-3), -math.cos(a) / max(ry, 1e-3)
        nl = math.hypot(nx, ny)
        nx, ny = nx / nl, ny / nl
        return (x + nx * out, y + ny * out, z), (nx, ny, 0.0), math.degrees(math.atan2(nx, -ny))


def loft(b, rings, swatch, sides=10, cap_bottom=True, cap_top=True, o=(0, 0, 0)):
    """A tube through rings (z, rx, ry_front, ry_back, cx, cy) listed bottom to top. `swatch`
    is one name or one per band. Returns the Surf (in limb coordinates, without `o`)."""
    bm = b.bm
    surf = Surf(rings)
    loops = []
    for z, rx, ryf, ryb, cx, cy in surf.rings:
        ring = []
        for k in range(sides):
            a = 2 * math.pi * (k + 0.5) / sides
            ry = ryf if math.cos(a) >= 0 else ryb
            ring.append(bm.verts.new((o[0] + cx + rx * math.sin(a), o[1] + cy - ry * math.cos(a), o[2] + z)))
        loops.append(ring)
    bands = [swatch] * (len(loops) - 1) if isinstance(swatch, str) else list(swatch)
    for i, (lo, hi) in enumerate(zip(loops, loops[1:])):
        faces = [bm.faces.new((lo[k], lo[(k + 1) % sides], hi[(k + 1) % sides], hi[k])) for k in range(sides)]
        b._paint_faces(faces, bands[i])
    if cap_bottom:
        b._paint_faces([bm.faces.new(tuple(reversed(loops[0])))], bands[0])
    if cap_top:
        b._paint_faces([bm.faces.new(tuple(loops[-1]))], bands[-1])
    return surf


def gore_stump(b):
    """The end left where a limb came off (InfectedGoreService welds it at the joint): a raw
    disc, a bone end, a torn rim. 0.4 across at scale 1."""
    loft(b, [(-0.05, 0.2, 0.2, 0.2), (0.04, 0.21, 0.21, 0.21)], "flesh_d", sides=8)
    loft(b, [(0.04, 0.16, 0.16, 0.16), (0.07, 0.15, 0.15, 0.15)], "wound", sides=8)
    b.cyl(0.06, 0.14, (0.02, 0.0, 0.12), segs=6, swatch="rebuilt_l")
    for k in range(5):
        a = k * 2 * math.pi / 5
        b.box((0.07, 0.05, 0.09), (math.cos(a) * 0.19, math.sin(a) * 0.19, 0.06), rot=(0, 0, math.degrees(a)), swatch="pallor")


def gore_chunk(b, kind):
    """A thrown flesh chunk (0.25-0.35 across): skin on one face, raw meat on the others."""
    if kind == "a":
        b.ico(0.16, (0, 0, 0), subdiv=0, swatch="wound")
        b.box((0.22, 0.05, 0.18), (0, -0.12, 0.02), rot=(0, 0, 10), swatch="pallor")
    elif kind == "b":
        b.box((0.3, 0.12, 0.2), (0, 0, 0), rot=(12, 8, 20), swatch="flesh_d")
        b.box((0.26, 0.04, 0.16), (0, -0.07, 0.01), rot=(12, 8, 20), swatch="wound")
    else:
        b.cyl(0.05, 0.3, (0, 0, 0), segs=5, rot=(0, 90, 15), swatch="rebuilt_l")  # a bone shard
        b.ico(0.09, (0.1, 0, 0.01), subdiv=0, swatch="wound")


def register(ba):
    """Adds the gore pieces to build_assets' ASSETS table."""
    ba.ASSETS["inf_gore_stump"] = (gore_stump, "Props", "origin")
    for kind in ("a", "b", "c"):
        ba.ASSETS[f"inf_gore_chunk_{kind}"] = ((lambda b, k=kind: gore_chunk(b, k)), "Props", "center")
