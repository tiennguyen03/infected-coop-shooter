"""The rest of the Infected roster in the v2 look. A PROPOSAL, not what the game loads.

Bloat, Shedder, Crawler, Kite and Growth (docs/CHARACTERS.md A), built to stand beside the
remade Walker, Runner, Brute and Hocker of infected_v2.py as one family: blocky shapes,
palette swatches only, no green skin, a face with dark sockets and milky eyes, one big wound
with bone in it, pustules big enough to break the outline, one bad side (the right, +X).
Strain green only where the lore puts it: Bloat veins and navel, Shedder seams, the Crawler's
raw ring and mouth, the Kite's keel and wing vein, the Growth's veins and sacs.

These forms are for later stages. Nothing here is exported, uploaded or spawned.

Meshes (`register(ba)` adds them to build_assets' ASSETS table, only when asked):

    blender --background --python assets/3d/build/build_assets.py -- --infected-roster --only <names>

- Bloat, Shedder, Crawler: R15 limb sets `inf_v2_<form>_<limb>` (`_l` / `_r` where `SIDED`).
- Kite: `inf_v2_kite_body`, `_wing_l`, `_wing_r`, `_tail` (wing origin = its hinge).
- Growth: `inf_v2_growth_mat`, `_host`, `_sac` (placed three times), `_root` (twice).
- `ref_inf_v2_<form>`: the assembled figure, previews only.

The Bloat's navel sphere is an attached Part in game, like the Hocker's sac; the previews
mount one. Previews (each form from the front, its bad side and the back, at its game scale
beside the 5-stud reference; then all nine forms in one row):

    blender --background --python assets/3d/build/infected_roster.py

writes `previews/infected_v2_<form>.png` for the five and `previews/lineup_infected_roster.png`.
In live Blender: `import infected_roster; infected_roster.live()`.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import infected_v2 as V2  # noqa: E402  (growth / knob / gash / sockets, the v2 figures)

BA = None  # the build_assets module, bound by _bind()

ARMS = ("upper_arm", "lower_arm", "hand")
LEGS = ("upper_leg", "lower_leg", "foot")
SIDED = {
    "bloat": ARMS + LEGS,  # arms held out, knees bowed out; the bandage is on the left forearm
    "shedder": ARMS,  # the right forearm is coming off at the elbow seam
    "crawler": ARMS,  # the arms reach out to the sides
}
# Body scale in game (CHARACTERS.md; the four built forms from EnemyDefinitions). Meshes are
# built at scale 1; the previews apply these.
SCALE = {
    "walker": 1.0, "runner": 0.9, "brute": 2.0, "hocker": 1.0,
    "bloat": 1.1, "shedder": 1.15, "crawler": 0.45, "kite": 1.0, "growth": 1.0,
}
TRI_CAP = {"bloat": 2400, "shedder": 2800, "crawler": 700, "kite": 600, "growth": 1200}
TROUSERS = "concrete_d"  # as the v2 Walker: `asphalt` reads black next to the shoes
KITE_HOVER = 4.2  # studs off the ground in the previews


# ------------------------------------------------------------------ shared shapes
def strut(L, p, q, t, swatch, w=None):
    """A box bar from `p` to `q`: `t` thick, `w` wide across (horizontal)."""
    d = (q[0] - p[0], q[1] - p[1], q[2] - p[2])
    n = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2) or 1e-6
    a = math.degrees(math.acos(max(-1.0, min(1.0, d[2] / n))))
    c = math.degrees(math.atan2(d[0], -d[1])) if (abs(d[0]) + abs(d[1])) > 1e-6 else 0.0
    mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2)
    L.box((w or t, t, n), mid, swatch=swatch, rot=(a, 0, c))


def shell(L, rings, paint, loc=(0, 0, 0), chamfer=0.78, caps=("gun", "gun")):
    """`Builder.prism` with a swatch per face: rings = [(z, rx, ry), ...] bottom to top,
    `paint(band, k)` names the swatch of face k (0 front, 1 front-right, 2 right, 3 back-right,
    4 back, 5 back-left, 6 left, 7 front-left) of each band."""
    bm, b = L.b.bm, L.b
    rv = []
    for z, rx, ry in rings:
        c = chamfer
        pts = ((-rx * c, -ry), (rx * c, -ry), (rx, -ry * c), (rx, ry * c), (rx * c, ry), (-rx * c, ry), (-rx, ry * c), (-rx, -ry * c))
        rv.append([bm.verts.new((loc[0] + x, loc[1] + y, loc[2] + z)) for x, y in pts])
    for i, (lo, hi) in enumerate(zip(rv, rv[1:])):
        for k in range(8):
            f = bm.faces.new((lo[k], lo[(k + 1) % 8], hi[(k + 1) % 8], hi[k]))
            b._paint_faces([f], paint(i, k))
    b._paint_faces([bm.faces.new(tuple(reversed(rv[0])))], caps[0])
    b._paint_faces([bm.faces.new(tuple(rv[-1]))], caps[1])


def plate(L, pts, t, swatch, side=None):
    """A flat slab `t` thick through the 3D outline `pts` (extruded along Z)."""
    bm, b = L.b.bm, L.b
    top = [bm.verts.new((x, y, z + t / 2)) for x, y, z in pts]
    bot = [bm.verts.new((x, y, z - t / 2)) for x, y, z in pts]
    n = len(pts)
    faces = [bm.faces.new(tuple(top)), bm.faces.new(tuple(reversed(bot)))]
    b._paint_faces(faces, swatch)
    sides = [bm.faces.new((bot[k], bot[(k + 1) % n], top[(k + 1) % n], top[k])) for k in range(n)]
    b._paint_faces(sides, side or swatch)


def seam(L, r, z, lips=(-1, 1)):
    """A Shedder seam round a limb: a wet strain groove between two pale lips."""
    L.oct(r * 0.8, 0.2, (0, 0, z), swatch="strain_d")
    for s in lips:
        L.oct(r + 0.06, 0.07, (0, 0, z + s * 0.11), swatch="rebuilt_l")


def cuff(L, r, z, strap=(1, 0)):
    """A cut restraint cuff: tan leather, a steel buckle at the front, the strap cut short."""
    L.oct(r, 0.22, (0, 0, z), swatch="tan_d")
    L.box((0.18, 0.1, 0.18), (0, -r + 0.02, z), swatch="gun_l")
    L.box((0.12, 0.07, 0.34), (strap[0] * (r - 0.02), strap[1] * (r - 0.02), z - 0.2), swatch="tan_d")


def _local(limb, p, sx=1):
    """A figure-space point (hip at z=0, right side) in `limb`'s own space."""
    x, y, z = BA.R15_POSE[limb]
    return (p[0] - sx * x, p[1] - y, p[2] - z)


# ------------------------------------------------------------------ Bloat
# The passenger from the sealed bus: a sphere on legs. The belly is one faceted ball across
# both torso meshes (split at the waist joint), drum-pale across the front with strain veins
# running out from the navel. The shirt no longer closes: one tan flap and its buttons on the
# left, torn away on the right, where the skin has split in a long tear and a clump of pustules
# sits on the shoulder. Arms out for balance, the bite bandage on the left forearm, knees bowed.
# The belly's width is in the mesh (like the v2 Brute's torso), not in BodyWidthScale.
BLOAT_C = (0.0, -0.25, -0.15)  # belly centre, figure space
BLOAT_R = (1.72, 1.5, 1.5)
BLOAT_SPLIT = -0.3  # the waist joint, as a fraction of the belly's height
BLOAT_UP = (-0.3, 0.0, 0.3, 0.58, 0.82, 0.96)
BLOAT_LOW = (-0.96, -0.8, -0.55, -0.3)
BLOAT_SPLAY = 42  # degrees the arms are held out from the shoulder
BLOAT_ARM_OUT = 0.1
BLOAT_BOW = 10  # degrees the thigh swings out from the hip
BLOAT_SINK = 0.24  # the head sits this far down in the top of the belly
NAVEL_R = 0.42


def _belly_s(t):
    return math.sqrt(max(0.0, 1.0 - t * t))


def _belly_front(x, t, out=0.03):
    """A point on the belly's front face (figure space)."""
    return (x, BLOAT_C[1] - BLOAT_R[1] * _belly_s(t) - out, BLOAT_C[2] + BLOAT_R[2] * t)


def _belly_back(x, t, out=0.03):
    return (x, BLOAT_C[1] + BLOAT_R[1] * _belly_s(t) + out, BLOAT_C[2] + BLOAT_R[2] * t)


def _belly_diag(t, sx=1, out=0.0):
    """Centre of the front-right (sx=1) or front-left face at height t, and its facing (deg)."""
    s = _belly_s(t)
    az = math.atan2(BLOAT_R[1], BLOAT_R[0])
    k = 0.89 * s
    p = (BLOAT_C[0] + sx * (BLOAT_R[0] * k + out * math.sin(az)), BLOAT_C[1] - BLOAT_R[1] * k - out * math.cos(az), BLOAT_C[2] + BLOAT_R[2] * t)
    return p, sx * math.degrees(az)


def _bloat_belly(L, limb):
    upper = limb == "upper_torso"
    oz = BA.R15_POSE[limb][2]
    split_z = BLOAT_C[2] + BLOAT_R[2] * BLOAT_SPLIT

    def mine(z):
        return (z >= split_z) == upper

    def at(p):
        return (p[0], p[1], p[2] - oz)

    def paint_up(i, k):
        if k in (4, 5, 6) and i >= 1:
            return "tan"  # the shirt: back and left side, ridden up over the belly
        if k == 7 and i >= 2:
            return "tan"
        if k in (7, 0, 1) and i <= 1:
            return "pallor_l"  # drum-tight and bloodless across the front
        return "flesh" if i < 4 else "flesh_d"

    def paint_low(i, k):
        if i <= 1:
            return TROUSERS
        return "pallor_l" if k in (7, 0, 1) else "flesh"

    ts = BLOAT_UP if upper else BLOAT_LOW
    rings = [(BLOAT_C[2] + BLOAT_R[2] * t - oz, BLOAT_R[0] * _belly_s(t), BLOAT_R[1] * _belly_s(t)) for t in ts]
    shell(L, rings, paint_up if upper else paint_low, loc=(BLOAT_C[0], BLOAT_C[1], 0), caps=("flesh", "flesh_d") if upper else (TROUSERS, "flesh"))

    # strain veins out from the navel (the tell: a pale belly with green veins)
    navel = (0.0, -0.12)
    veins = (
        ((-0.45, 0.1), (-1.05, 0.26)), ((-0.2, 0.3), (-0.5, 0.6)), ((0.2, 0.28), (0.3, 0.66)),
        ((0.5, 0.05), (1.0, 0.2)), ((0.55, -0.3), (1.05, -0.42)), ((0.15, -0.5), (0.4, -0.78)),
        ((-0.35, -0.42), (-0.75, -0.7)), ((-0.6, -0.16), (-1.2, -0.2)),
    )
    for mid, end in veins:
        for a, b_ in ((navel, mid), (mid, end)):
            p, q = _belly_front(*a), _belly_front(*b_)
            if mine((p[2] + q[2]) / 2):
                strut(L, at(p), at(q), 0.08, "strain_d", w=0.1)
    for x0, x1 in ((-0.7, -0.9), (0.1, 0.2), (0.8, 1.0)):  # and down the back, from under the shirt
        p, q = _belly_back(x0, 0.05), _belly_back(x1, -0.5)
        for a, b_ in ((p, ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2 + 0.06, (p[2] + q[2]) / 2)), (((p[0] + q[0]) / 2, (p[1] + q[1]) / 2 + 0.06, (p[2] + q[2]) / 2), q)):
            if mine((a[2] + b_[2]) / 2):
                strut(L, at(a), at(b_), 0.08, "strain_d", w=0.1)
    if not upper:
        L.box((1.1, 0.12, 0.16), at(_belly_front(0, -0.62, out=0.0)), swatch="dark", rot=(-38, 0, 0))  # the belt, under the overhang
        L.box((0.24, 0.14, 0.2), at(_belly_front(0, -0.62, out=0.03)), swatch="brass", rot=(-38, 0, 0))
        return

    # the shirt that no longer closes: the left flap, buttons popped
    strut(L, at(_belly_front(-1.0, 0.72, 0.05)), at(_belly_front(-1.12, 0.12, 0.06)), 0.1, "tan_d", w=0.34)
    for t in (0.6, 0.36):
        L.box((0.12, 0.1, 0.12), at(_belly_front(-0.98, t, 0.12)), swatch="brass_l")
    strut(L, at(_belly_front(0.55, 0.9, 0.05)), at(_belly_front(0.75, 0.62, 0.06)), 0.1, "tan_d", w=0.4)  # what is left of the right one
    strut(L, at(_belly_back(0, 0.86, 0.0)), at(_belly_back(0, 0.14, 0.02)), 0.1, "flesh_l", w=0.42)  # split down the back seam
    for x in (-0.25, 0.25):
        strut(L, at(_belly_back(x, 0.86, 0.02)), at(_belly_back(x * 1.3, 0.14, 0.04)), 0.1, "tan_d", w=0.1)

    # the bad side: the skin has split where it could not stretch
    (px, py, pz), az = _belly_diag(0.04, 1)
    n = (math.sin(math.radians(az)), -math.cos(math.radians(az)))
    for w, h, k, sw in ((0.74, 1.12, 0.0, "flesh_d"), (0.48, 0.94, 0.045, "wound"), (0.2, 0.72, 0.09, "wound_d")):
        L.box((w, 0.1, h), at((px + n[0] * k, py + n[1] * k, pz)), swatch=sw, rot=(0, 0, az))
    for dz, w in ((0.26, 0.3), (-0.12, 0.36)):  # fat, not bone: pale lobes pushing out of the tear
        L.box((w, 0.14, 0.22), at((px + n[0] * 0.12, py + n[1] * 0.12, pz + dz)), swatch="pus_l", rot=(0, 0, az))
    V2.growth(L, 0.26, at((px + n[0] * 0.12, py + n[1] * 0.12, pz - 0.6)), n=(n[0], n[1], -0.3))
    # the clump on the right shoulder
    V2.growth(L, 0.44, at((1.02, -0.45, 1.0)), n=(0.4, -0.5, 0.8))
    V2.growth(L, 0.32, at((1.36, 0.1, 0.72)), n=(0.8, 0.2, 0.5))
    V2.growth(L, 0.27, at((0.8, 0.4, 1.12)), n=(0.1, 0.5, 0.8))
    V2.growth(L, 0.2, at((1.5, -0.6, 0.4)), n=(0.7, -0.6, 0.3))


def _bloat_splay(L, limb, sx):
    """Swings an arm limb out about the shoulder (the whole arm turns as one piece)."""
    pivot = 0.83 - BA.R15_POSE[limb][2]
    L.b.rotate_all((0, -sx * BLOAT_SPLAY, 0), cent=(0, 0, pivot))
    L.b.shift_all((sx * BLOAT_ARM_OUT, 0, 0))


def bloat_limb(L, limb, side=None):
    skin = "flesh"
    sx = 1 if side == "r" else -1
    bad = side == "r"
    if limb == "head":
        L.box((0.96, 0.92, 0.72), (0, 0, 0.02), swatch=skin)  # small, on top
        for x in (-0.5, 0.5):
            L.box((0.34, 0.66, 0.5), (x, -0.14, -0.14), swatch="flesh_l")  # cheeks blown out
        L.oct(0.7, 0.3, (0, 0.04, -0.44), swatch="flesh_l", r_top=0.6)  # the roll where the neck was
        L.box((1.02, 0.6, 0.3), (0, 0.2, 0.36), swatch="dark")  # hair cap
        L.box((0.6, 0.4, 0.14), (-0.2, -0.26, 0.42), swatch="dark")
        V2.sockets(L, z=0.1, y=-0.465, dx=0.22, w=0.3, h=0.14, eye=(0.18, 0.06))  # eyes swollen to slits
        L.box((0.14, 0.12, 0.14), (0, -0.5, -0.04), swatch=skin)  # nose
        L.box((0.36, 0.1, 0.24), (0, -0.47, -0.24), swatch="dark_d")  # a small round mouth, open
        L.box((0.26, 0.1, 0.06), (0, -0.49, -0.15), swatch="white_d")
        L.lesion(0.4, 0.4, (0.34, 0.0, 0.385), face="top")  # bare scalp on the bad side
        V2.growth(L, 0.2, (0.62, -0.2, -0.36), n=(0.7, -0.5, -0.2))
        L.b.shift_all((0, -0.16, -BLOAT_SINK))
    elif limb in ("upper_torso", "lower_torso"):
        _bloat_belly(L, limb)
    elif limb == "upper_arm":
        if bad:
            V2.knob(L, 0.46, (0, 0, 0.2), skin)
            L.oct(0.42, 0.8, (0, 0, -0.22), swatch=skin, r_top=0.46)
            L.oct(0.5, 0.12, (0, 0, 0.3), swatch="tan_d")  # the sleeve's torn hem
            L.lesion(0.44, 0.46, (0.4, 0, -0.2), face="right")
        else:
            L.cap(0.47, (0, 0, 0.2), swatch="tan")
            L.oct(0.44, 0.7, (0, 0, -0.1), swatch="tan", r_top=0.47)  # short sleeve, tight
            L.oct(0.48, 0.1, (0, 0, -0.44), swatch="tan_d")
            L.oct(0.42, 0.2, (0, 0, -0.56), swatch=skin)
        _bloat_splay(L, limb, sx)
    elif limb == "lower_arm":
        V2.knob(L, 0.44, (0, 0, 0.18), skin)
        L.oct(0.5, 0.86, (0, 0, -0.14), swatch="flesh_l", r_top=0.44)  # swollen toward the hand
        if bad:
            V2.growth(L, 0.24, (0.34, -0.2, -0.1), n=(0.8, -0.5, 0.1))
            V2.growth(L, 0.18, (0.3, 0.26, -0.36), n=(0.8, 0.5, 0))
            L.blotch(0.4, 0.5, (0, -0.47, -0.2), swatch="bruise")
        else:
            L.oct(0.54, 0.46, (0, 0, -0.14), swatch="white")  # the bite bandage
            L.oct(0.55, 0.08, (0, 0, 0.0), swatch="white_d")
            L.box((0.44, 0.3, 0.3), (0, -0.42, -0.16), swatch="red")  # bled through
            L.box((0.24, 0.3, 0.16), (0.04, -0.44, -0.16), swatch="red_d")
        _bloat_splay(L, limb, sx)
    elif limb == "hand":
        L.box((0.98, 0.9, 0.36), (0, 0, 0.0), swatch="flesh_l")  # a fat paddle
        for x in (-0.33, 0.0, 0.33):
            L.box((0.28, 0.5, 0.26), (x, -0.16, -0.26), swatch=skin)  # short fat fingers
        L.blotch(0.5, 0.4, (0, 0.1, 0.19), face="top", swatch="bruise")
        _bloat_splay(L, limb, sx)
    elif limb == "upper_leg":
        L.oct(0.5, 1.2, (0, 0, 0.02), swatch=TROUSERS, r_top=0.5)
        L.box((0.12, 0.6, 0.9), (sx * 0.46, 0, 0.0), swatch="flesh")  # the trouser split up the thigh
        L.box((0.14, 0.3, 0.5), (sx * 0.47, 0, -0.05), swatch="flesh_l")
        L.b.rotate_all((0, -sx * BLOAT_BOW, 0), cent=(0, 0, BA.R15_HIP_UP))
    elif limb == "lower_leg":
        L.cap(0.44, (0, 0, 0.26), swatch=TROUSERS)
        L.oct(0.4, 1.0, (0, 0, -0.1), swatch=TROUSERS, r_top=0.46)
        L.oct(0.44, 0.12, (0, 0, -0.5), swatch="flesh_l")  # a swollen ankle over the shoe
        knee_out = 0.921 * math.sin(math.radians(BLOAT_BOW))
        shin = math.degrees(math.asin(knee_out / 1.009))  # back in to the foot
        L.b.rotate_all((0, sx * shin, 0), cent=(0, 0, BA.R15_ANKLE_DOWN))
    elif limb == "foot":
        L.shoe()


def _navel(b):
    p = _belly_front(0.0, -0.12, out=NAVEL_R * 0.45)
    b.ico(NAVEL_R, p, swatch="strain", subdiv=1)
    b.box((0.2, 0.08, 0.16), (p[0] + 0.12, p[1] - NAVEL_R * 0.94, p[2] + 0.12), swatch="strain_l")


# ------------------------------------------------------------------ Shedder
# The Kestrel ward patient, partitioned: a tall thin stack of pale blocks, each a little out of
# line with the next, a wet strain seam between every two. The hospital gown is soaked through
# in a band at each seam, so the stack reads from the front; from behind the gown hangs open on
# a bare spine. Two small arms folded on the ribs (the next Crawlers). Cut restraint cuffs on
# wrists and ankles. Bad side: the right forearm hangs off its elbow seam on two cords, and the
# lower chest seam gapes on the right.
SHED_W, SHED_D = 1.3, 0.8
SHED_NECK = 0.5  # the head stands this much higher, on a seamed neck
SHED_ARM_IN = 0.5  # arms hung this far inboard, against the narrow chest
SHED_REACH = 0.4  # forearms longer by this
SHED_HANG = 0.26  # the right forearm has dropped this far out of its seam
SHED_SEGS = ((0.33, 0.85, 0.07), (-0.23, 0.25, -0.07), (-0.85, -0.31, 0.05))  # z0, z1, x
SHED_CUP = 0.8  # each block narrows to this at its bottom: a stack of cups


def shedder_limb(L, limb, side=None):
    skin = "pallor_l"  # bloodless; the lower cup of each limb a tone down
    W, D = SHED_W, SHED_D
    sx = 1 if side == "r" else -1
    bad = side == "r"
    if limb == "head":
        L.box((0.86, 0.92, 0.8), (0, 0, 0.14), swatch="pallor_l")  # bald, narrow skull
        L.box((0.7, 0.8, 0.2), (0, 0, 0.62), swatch="pallor_l")
        L.box((0.12, 0.84, 0.1), (0.04, 0, 0.71), swatch="strain_d")  # the skull seam, front to back
        L.box((0.12, 0.1, 0.4), (0.04, -0.43, 0.5), swatch="strain_d")
        L.box((0.12, 0.1, 0.5), (0.04, 0.43, 0.42), swatch="strain_d")
        for x in (-0.07, 0.15):
            L.box((0.07, 0.88, 0.08), (x, 0, 0.73), swatch="rebuilt_l")
        L.box((0.9, 0.12, 0.12), (0, -0.45, 0.34), swatch="pallor_d")  # brow
        V2.sockets(L, z=0.18, y=-0.47, dx=0.22, w=0.28)
        L.box((0.44, 0.4, 0.66), (0, -0.3, -0.38), swatch="dark_d")  # the mouth: open and black
        L.box((0.4, 0.08, 0.08), (0, -0.48, -0.1), swatch="white_d")
        for x in (-0.32, 0.32):
            L.box((0.2, 0.7, 0.66), (x, -0.1, -0.38), swatch="pallor_d")  # the cheeks stretched down
        L.box((0.72, 0.8, 0.16), (0, -0.08, -0.76), swatch=skin)  # jaw hanging to the collar
        L.oct(0.25, 0.6 + SHED_NECK, (0, 0.14, -0.7 - SHED_NECK / 2), swatch=skin)  # the neck
        L.oct(0.2, 0.18, (0, 0.14, -0.9 - SHED_NECK / 2), swatch="strain_d")
        for s in (-1, 1):
            L.oct(0.32, 0.07, (0, 0.14, -0.9 - SHED_NECK / 2 + s * 0.11), swatch="rebuilt_l")
        V2.growth(L, 0.17, (0.28, 0.2, -0.64 - SHED_NECK / 2), n=(0.9, 0.2, 0.2))
        L.b.shift_all((0, 0, SHED_NECK))
    elif limb == "upper_torso":
        for i, (z0, z1, x) in enumerate(SHED_SEGS):
            h, zc = z1 - z0, (z0 + z1) / 2
            w = W - 0.1 * i
            c = SHED_CUP
            L.prism([(z0, w / 2 * c, D / 2 * c), (z1, w / 2, D / 2)], swatch="pallor" if i == 1 else skin, loc=(x, 0, 0), sides=4)  # one block of the stack
            L.box((w * 0.94, 0.1, h), (x, -D / 2 + 0.02, zc), swatch="white", rot=(-5, 0, 0))  # the gown front
            L.box((0.3, 0.1, h * 0.9), (x, D / 2 * (1 + c) / 2, zc), swatch="wound", rot=(5, 0, 0))  # the spine, bare
            for k in (-0.2, 0.22):
                L.box((0.24, 0.2, 0.17), (x, D / 2 * (1 + c) / 2 + 0.05, zc + k * h), swatch="rebuilt_l")
        for z in (0.29, -0.27):  # the seams: a wet groove, pale lips, the gown soaked through
            L.box((W - 0.4, D - 0.3, 0.2), (0, 0, z), swatch="strain_d")
            L.box((W + 0.1, D + 0.08, 0.07), (0, 0.02, z + 0.07), swatch="rebuilt_l")
            L.box((W + 0.14, 0.12, 0.24), (0, -D / 2 - 0.03, z + 0.2), swatch="pus_d")
            L.box((W + 0.16, 0.12, 0.09), (0, -D / 2 - 0.05, z + 0.11), swatch="strain_d")
        L.box((0.6, 0.14, 0.2), (0.07, -D / 2 - 0.02, 0.76), swatch="white_d")  # neckline
        L.box((0.8, 0.06, 0.08), (0.07, D / 2 + 0.03, 0.74), swatch="white_l")  # the one tie still done up
        # the lower seam gapes on the bad side
        L.box((0.56, D + 0.04, 0.34), (0.44, 0, -0.27), swatch="wound_d")
        L.box((0.16, 0.16, 0.4), (0.3, 0.2, -0.27), swatch="rebuilt_l")
        for y in (-0.34, 0.0):
            L.box((0.06, 0.06, 0.4), (0.68, y, -0.27), swatch="strain")
        V2.growth(L, 0.2, (0.7, -0.3, -0.52), n=(0.8, -0.5, 0))
        # the second pair of arms, folded on the lower ribs
        for s, zw in ((1, -0.5), (-1, -0.36)):
            a, e, wr = (s * 0.62, -0.3, 0.14), (s * 0.74, -0.58, -0.52), (s * 0.12, -0.62, zw)
            strut(L, a, e, 0.2, "rebuilt")
            strut(L, e, wr, 0.17, "rebuilt")
            L.box((0.22, 0.16, 0.2), (wr[0] - s * 0.12, wr[1], wr[2]), swatch="rebuilt_l")
    elif limb == "lower_torso":
        L.box((W - 0.16, D * 0.86, 0.4), (0, 0, 0), swatch=skin)
        L.box((W - 0.5, D - 0.3, 0.2), (0, 0, 0.2), swatch="strain_d")  # the waist seam
        L.box((W - 0.12, D + 0.06, 0.06), (0, 0.03, 0.12), swatch="rebuilt_l")
        L.box((W, 0.12, 0.3), (0, -D / 2 - 0.05, 0.16), swatch="pus_d")
        L.box((W + 0.02, 0.12, 0.09), (0, -D / 2 - 0.07, 0.2), swatch="strain_d")
        L.box((W - 0.06, 0.1, 1.0), (0, -D / 2 - 0.03, -0.42), swatch="white")  # the gown, to mid-thigh
        for s in (-1, 1):
            L.box((0.1, D * 0.62, 0.9), (s * (W / 2 - 0.06), -0.14, -0.38), swatch="white")
        L.box((W - 0.04, 0.12, 0.1), (0, -D / 2 - 0.04, -0.87), swatch="white_d")  # hem
        L.box((0.4, 0.14, 0.2), (-0.4, -D / 2 - 0.05, -0.72), swatch="white_l")  # the Kestrel ID band
        L.box((0.4, 0.15, 0.06), (-0.4, -D / 2 - 0.055, -0.72), swatch="red")
        L.box((0.36, 0.1, 0.4), (0, D / 2, 0), swatch="wound")
        L.box((0.26, 0.2, 0.17), (0, D / 2 + 0.06, 0.0), swatch="rebuilt_l")
    elif limb == "upper_arm":
        L.oct(0.3, 0.3, (0, 0, 0.32), swatch=skin if bad else "white", r_top=0.22)  # shoulder (the gown's sleeve)
        L.oct(0.2, 0.36, (0, 0, 0.14), swatch="pallor", r_top=0.28)  # two cups...
        L.oct(0.2, 0.06, (0, 0, -0.07), swatch="strain_d")
        L.oct(0.2, 0.3, (0, 0, -0.2), swatch=skin, r_top=0.28)
        L.oct(0.32, 0.07, (0, 0, -0.33), swatch="rebuilt_l")  # ...and the upper lip of the elbow seam
        L.b.shift_all((-sx * SHED_ARM_IN, 0, 0))
    elif limb == "lower_arm":
        r = SHED_REACH
        seam(L, 0.26, 0.28, lips=(-1,))
        L.oct(0.2, 0.7 + r, (0, 0, -0.18 - r / 2), swatch="pallor", r_top=0.28)
        cuff(L, 0.3, -0.38 - r, strap=(sx, 0))
        if bad:  # out of the seam: raw, hanging on two cords round the bone
            L.oct(0.22, 0.1, (0, 0, 0.4), swatch="wound")
            L.box((0.13, 0.13, SHED_HANG + 0.3), (0, 0.04, 0.4 + SHED_HANG / 2), swatch="rebuilt_l")
            for x, y in ((0.15, -0.1), (-0.13, 0.13)):
                L.box((0.06, 0.06, SHED_HANG + 0.2), (x, y, 0.4 + SHED_HANG / 2), swatch="strain")
        L.b.shift_all((-sx * SHED_ARM_IN, 0, -SHED_HANG if bad else 0))
    elif limb == "hand":
        L.box((0.56, 0.36, 0.32), (0, 0, 0), swatch=skin)
        for x in (-0.22, -0.07, 0.08, 0.23):
            L.box((0.11, 0.15, 0.56), (x, -0.04, -0.4), swatch=skin)  # long fingers
        L.box((0.58, 0.13, 0.18), (0, -0.04, -0.72), swatch="rebuilt_l")
        L.b.shift_all((-sx * SHED_ARM_IN, 0, -SHED_REACH - (SHED_HANG if bad else 0)))
    elif limb == "upper_leg":
        L.hip_inset(0.34, skin, r_hip=0.3)
        L.oct(0.25, 0.46, (0, 0, 0.2), swatch="pallor", r_top=0.36)
        L.oct(0.25, 0.06, (0, 0, -0.05), swatch="strain_d")
        L.oct(0.25, 0.34, (0, 0, -0.2), swatch=skin, r_top=0.34)
        L.oct(0.36, 0.07, (0, 0, -0.37), swatch="rebuilt_l")
    elif limb == "lower_leg":
        seam(L, 0.3, 0.38, lips=(-1,))
        L.oct(0.23, 0.82, (0, 0, -0.1), swatch="pallor", r_top=0.32)
        cuff(L, 0.33, -0.44, strap=(0, 1))
    elif limb == "foot":
        L.box((0.72, 0.98, 0.24), (0, 0, 0), swatch="pallor_d")  # bare
        L.box((0.76, 0.24, 0.17), (0, -0.4, -0.03), swatch="rebuilt_l")  # toes


# ------------------------------------------------------------------ Crawler
# A segment shed from a Shedder: one block of torso carried flat between two long bone arms,
# elbows above its back, claws on the ground. A knob of a head with a strain slit for a mouth.
# The legs are knots. Where it broke off (the rear end) is a raw strain ring round a stub of
# spine, a scrap of gown still caught on it. Knee-high at scale 0.45.
CRAWL_PITCH = 68  # degrees the torso lies forward from the waist
CRAWL_SHOULDER = (0.98, -1.3, 0.0)  # figure space, right side
CRAWL_ELBOW = (1.9, -1.1, 0.62)
CRAWL_WRIST = (2.2, -1.95, -2.05)
CRAWL_FLOOR = -2.32  # figure z the claws stand on


def crawler_limb(L, limb, side=None):
    sx = 1 if side == "r" else -1

    def loc(p):
        q = _local(limb, p)
        return (sx * q[0], q[1], q[2])

    if limb == "head":
        L.box((0.9, 0.9, 0.8), (0, 0, 0), swatch="rebuilt")  # a knob
        L.box((0.96, 0.14, 0.16), (0, -0.42, 0.24), swatch="rebuilt_l")  # brow
        V2.sockets(L, z=0.06, y=-0.455, dx=0.22, rim="wound_d", w=0.28, h=0.2, eye=(0.14, 0.08))
        L.box((0.7, 0.14, 0.2), (0, -0.44, -0.22), swatch="strain_d")  # the slit
        L.b.shift_all((0, -1.76, 0.22 - BA.R15_POSE["head"][2]))
    elif limb == "upper_torso":
        L.box((1.5, 0.8, 1.4), (0, 0, 0), swatch="rebuilt")  # the segment: rebuilt back...
        L.box((1.3, 0.1, 1.1), (0, -0.4, 0), swatch="pallor")  # ...skin belly
        for z in (-0.4, 0.0, 0.4):
            L.box((0.26, 0.2, 0.22), (0, 0.44, z), swatch="rebuilt_l")  # spine
        V2.growth(L, 0.26, (0.5, 0.4, 0.2), n=(0.4, 1, 0), head=None)
        L.b.rotate_all((CRAWL_PITCH, 0, 0), cent=(0, 0, BA.R15_WAIST_DOWN))
    elif limb == "lower_torso":
        L.box((1.3, 0.76, 0.4), (0, 0, 0), swatch="rebuilt")
        L.box((1.42, 0.88, 0.14), (0, 0, -0.16), swatch="strain_d")  # the raw ring where it broke off
        L.box((1.1, 0.6, 0.1), (0, 0, -0.22), swatch="wound")
        L.box((0.24, 0.24, 0.3), (0, 0.1, -0.32), swatch="rebuilt_l")  # the stub of spine
        L.box((0.5, 0.06, 0.8), (-0.3, -0.4, -0.4), swatch="white")  # a scrap of gown
        L.b.rotate_all((CRAWL_PITCH, 0, 0), cent=(0, 0, 0.2))
    elif limb == "upper_arm":
        L.ico(0.46, loc(CRAWL_SHOULDER), swatch="wound", subdiv=0)  # raw where the arm grew out
        strut(L, loc(CRAWL_SHOULDER), loc(CRAWL_ELBOW), 0.5, "rebuilt")
    elif limb == "lower_arm":
        L.ico(0.44, loc(CRAWL_ELBOW), swatch="rebuilt_l", subdiv=0)
        strut(L, loc(CRAWL_ELBOW), loc(CRAWL_WRIST), 0.42, "rebuilt")
    elif limb == "hand":
        wx, wy, wz = CRAWL_WRIST
        L.box((0.5, 0.5, 0.34), loc((wx, wy, wz - 0.05)), swatch="rebuilt_d")
        for dx, dy in ((0.5, -0.3), (0.05, -0.6), (-0.4, -0.35)):  # claws, splayed
            strut(L, loc((wx, wy, wz - 0.05)), loc((wx + dx * 1.2, wy + dy * 1.2, CRAWL_FLOOR + 0.1)), 0.22, "rebuilt_l")
    elif limb == "upper_leg":
        L.ico(0.36, (0, 0, 0), swatch="rebuilt_d", subdiv=0)  # a knot
        L.b.shift_all((0, 0.5, 0.42))
    elif limb == "lower_leg":
        L.box((0.26, 0.26, 0.4), (0, 0, 0), swatch="rebuilt_d")
        L.b.shift_all((0, 0.6, 0.95))
    elif limb == "foot":
        L.box((0.2, 0.2, 0.2), (0, 0, 0), swatch="rebuilt")
        L.b.shift_all((0, 0.62, 1.42))


FORMS = {"bloat": bloat_limb, "shedder": shedder_limb, "crawler": crawler_limb}


# ------------------------------------------------------------------ Kite
# A flyer: a bone wedge with the keel open underneath (ribs across a wet strain channel), a
# face at the point, a stepped spine. The wings are skin stretched on four finger bones, a
# strain vein along the leading one. Bad side: the right wing is torn and its last finger
# broken short, pustules at its root. The tail is a strip of spine with hi-vis caught on it.
KITE_RINGS = ((-1.25, 0.34, 0.14), (-0.55, 0.66, 0.3), (0.35, 0.46, 0.26), (1.25, 0.1, 0.08))  # tail to nose
KITE_WING_AT = (0.46, 0.1, 0.12)  # right wing hinge, from the body centre
KITE_TAIL_AT = (0.0, 1.2, 0.0)
KITE_RIBS = ((-14, 3.0), (12, 2.9), (38, 2.5), (63, 1.9))  # degrees back from straight out, length
KITE_DIHEDRAL = 0.2  # rise per stud of span


def kite_body(L):
    def paint(i, k):
        if k == 0:
            return "strain_d"  # the keel, wet
        if k == 4:
            return "rebuilt"
        return "wound" if k in (1, 7) else "rebuilt_d"

    shell(L, KITE_RINGS, paint, caps=("rebuilt_d", "rebuilt_l"))
    L.b.rotate_all((90, 0, 0))  # lay it along Y, nose forward
    for y, w in ((0.7, 0.9), (0.2, 1.0), (-0.3, 0.74)):
        L.box((w, 0.12, 0.12), (0, y, -0.29 + 0.03 * abs(y - 0.4)), swatch="rebuilt_l")  # ribs across the keel
    for y, z, w in ((0.66, 0.31, 0.26), (0.16, 0.33, 0.22), (-0.34, 0.27, 0.17)):
        L.box((w, 0.3, 0.16), (0, y, z), swatch="rebuilt_l")  # stepped spine
    for x in (-0.19, 0.19):  # the face at the point
        L.box((0.22, 0.26, 0.1), (x, -0.78, 0.17), swatch="bruise_d", rot=(-11, 0, 0))
        L.box((0.12, 0.14, 0.1), (x, -0.8, 0.2), swatch="pus_l", rot=(-11, 0, 0))
    L.box((0.26, 0.5, 0.12), (0, -0.9, -0.1), swatch="dark_d")  # the mouth
    L.box((0.34, 0.62, 0.08), (0, -0.86, -0.24), swatch="rebuilt_l", rot=(-16, 0, 0))  # jaw hanging
    V2.growth(L, 0.26, (0.5, 0.42, 0.22), n=(0.5, 0, 0.8))


def kite_wing(L, side):
    sx = 1 if side == "r" else -1
    bad = side == "r"
    tips = []
    for i, (deg, length) in enumerate(KITE_RIBS):
        if bad and i == 3:
            length = 1.25  # broken short
        a = math.radians(deg)
        tips.append((sx * length * math.cos(a), length * math.sin(a), length * KITE_DIHEDRAL))
    root = (0.0, 0.0, 0.0)
    for i, (a, b_) in enumerate(zip(tips, tips[1:])):  # the membrane, scalloped between the fingers
        k = 0.8 if not (bad and i == 1) else 0.42  # torn through on the bad wing
        mid = tuple((a[j] + b_[j]) / 2 * k for j in range(3))
        plate(L, [root, a, mid, b_], 0.05, "rebuilt_l", side="rebuilt")
    strut(L, root, tips[0], 0.17, "rebuilt")  # the leading finger: the arm it was
    for tip in tips[1:]:
        strut(L, root, tip, 0.11, "rebuilt_d")
    lead = tips[0]
    L.ico(0.2, tuple(c * 0.45 for c in lead), swatch="rebuilt_l", subdiv=0)  # its knuckle
    strut(L, (lead[0] * 0.06, lead[1] * 0.06, lead[2] * 0.06 + 0.1), (lead[0] * 0.86, lead[1] * 0.86, lead[2] * 0.86 + 0.1), 0.07, "strain", w=0.1)
    strut(L, lead, (lead[0] * 1.05, lead[1] + 0.3, lead[2] - 0.12), 0.1, "rebuilt_l")  # the claw
    L.ico(0.24, root, swatch="rebuilt_d", subdiv=0)


def kite_tail(L):
    pts = ((0, 0, 0), (0, 0.7, -0.1), (0, 1.4, -0.32), (0, 2.0, -0.66))
    for (p, q), (t, w) in zip(zip(pts, pts[1:]), ((0.16, 0.26), (0.13, 0.2), (0.1, 0.14))):
        strut(L, p, q, t, "rebuilt_d", w=w)
    L.box((0.4, 0.56, 0.05), (0.06, 1.5, -0.46), swatch="warning_orange", rot=(-20, 0, 12))  # hi-vis, caught
    L.box((0.42, 0.12, 0.06), (0.06, 1.5, -0.46), swatch="gun_l", rot=(-20, 0, 12))


# ------------------------------------------------------------------ Growth
# The rail worker rooted where he fell: a mound. The mat steps up in three terraces to three
# strain sacs; strain veins run out from under the host to its edge. The host is bent double at
# the front, face in the mat, arms sunk to the elbow, hi-vis still on; his back is split along
# the spine and the ribs stand up out of it. Two root cables leave the mound for a wall or rail.
MAT_R = (4.1, 3.6, 4.2, 3.5, 3.9, 4.3, 3.6, 4.0, 3.4, 4.1, 3.7)  # the outline, every 360/11 degrees
MAT_LAYERS = ((1.0, 0.0, 0.0, 0.16, "rebuilt_d"), (0.72, 0.3, 0.16, 0.44, "rebuilt"), (0.42, 1.0, 0.44, 0.78, "rebuilt"))  # scale, y, z0, z1
HOST_AT = (0.0, -1.5, 0.4)
HOST_PITCH = 102
SACS = ((-1.2, 0.9, 0.74, 1.0, 20), (1.0, 1.2, 0.74, 1.2, -30), (-0.1, 2.3, 0.6, 0.85, 160))  # x, y, z, scale, turn
ROOTS = ((0.5, -1.2, 1.5, 0, False), (-0.5, -1.0, 1.5, 0, True))  # x, y, z, turn, mirrored


def _mat_r(a):
    """The mat's radius at angle `a` (radians), between its outline points."""
    n = len(MAT_R)
    f = (a % (2 * math.pi)) / (2 * math.pi) * n
    i = int(f) % n
    return MAT_R[i] + (MAT_R[(i + 1) % n] - MAT_R[i]) * (f - int(f))


def growth_mat(L):
    n = len(MAT_R)
    for scale, y, z0, z1, sw in MAT_LAYERS:
        pts = [(MAT_R[i] * scale * math.cos(2 * math.pi * i / n), y + MAT_R[i] * scale * math.sin(2 * math.pi * i / n), (z0 + z1) / 2) for i in range(n)]
        plate(L, pts, z1 - z0, sw, side="rebuilt_d")
    hub = (0.0, -0.9)
    for deg in (200, 236, 300, 335, 20, 150):  # strain veins, out from under the host
        a = math.radians(deg)
        d = (math.cos(a), math.sin(a))
        r = _mat_r(a)
        p0 = (hub[0] + d[0] * 0.5, hub[1] + d[1] * 0.5, 0.47)
        p1 = (d[0] * r * 0.68, 0.3 + d[1] * r * 0.68, 0.47)
        p2 = (d[0] * r * 0.95, d[1] * r * 0.95, 0.17)
        strut(L, p0, p1, 0.08, "strain_d", w=0.2)
        strut(L, p1, p2, 0.08, "strain_d", w=0.16)
    V2.growth(L, 0.42, (2.7, -1.5, 0.3), n=(0.3, -0.3, 0.9))
    V2.growth(L, 0.3, (-3.0, 0.4, 0.3), n=(-0.4, 0, 0.9))
    V2.growth(L, 0.34, (-2.0, -2.3, 0.26), n=(-0.2, -0.4, 0.9))


def growth_host(L):
    """Origin: under his hips, on the mat. He faces -Y."""
    tr = TROUSERS
    L.box((1.8, 1.7, 0.42), (0, 0.5, 0.2), swatch=tr)  # kneeling: shins flat on the mat
    L.box((1.7, 0.5, 0.44), (0, 1.3, 0.22), swatch="dark")  # boots
    L.box((1.9, 1.0, 0.8), (0, 0.3, 0.75), swatch=tr)  # hips, up in the air
    sub = BA.Builder()
    T = type(L)(sub)
    T.box((1.94, 1.0, 1.7), (0, 0, 0.85), swatch="warning_orange")  # the hi-vis jacket
    for z in (0.5, 1.15):
        T.box((2.0, 1.06, 0.16), (0, 0, z), swatch="gun_l")  # its reflective bands
    T.box((0.56, 0.12, 1.5), (0, 0.5, 0.85), swatch="wound")  # the back split along the spine
    for z in (0.3, 0.72, 1.14):
        T.box((0.26, 0.24, 0.22), (0, 0.56, z + 0.16), swatch="rebuilt_l")
        for s in (-1, 1):  # ribs standing up out of it
            strut(T, (s * 0.2, 0.5, z), (s * 0.85, 1.12, z + 0.12), 0.13, "rebuilt_l")
    V2.growth(T, 0.3, (0.74, 0.4, 1.56), n=(0.4, 0.8, 0.4))
    T.box((0.7, 0.7, 0.4), (0, 0, 1.8), swatch="pallor")  # neck
    T.box((1.1, 1.1, 1.0), (0, -0.2, 2.3), swatch="pallor_l")  # the head, face down
    T.box((1.16, 0.6, 0.5), (0, 0.3, 2.56), swatch="dark")  # hair: the back of his head
    for s in (-1, 1):
        T.box((0.56, 1.5, 0.56), (s * 1.24, -0.6, 1.4), swatch="warning_orange")  # arms, sunk to the elbow
        T.box((0.6, 0.16, 0.6), (s * 1.24, -0.6, 1.4), swatch="gun_l")
    sub.rotate_all((HOST_PITCH, 0, 0))
    sub.shift_all((0, 0.3, 1.0))
    L.b.merge(sub)


def growth_sac(L):
    """Origin: bottom centre. The slit faces -Y."""
    L.oct(0.66, 0.36, (0, 0, 0.18), swatch="rebuilt_d", r_top=0.56)  # the collar it sits in
    L.ico(0.75, (0, 0, 0.84), swatch="strain", subdiv=1)
    L.box((0.16, 0.5, 0.62), (0, -0.5, 1.12), swatch="strain_d", rot=(38, 0, 0))  # where it opens
    L.box((0.22, 0.1, 0.2), (0.34, -0.56, 1.1), swatch="strain_l")
    for a in (0, 120, 240):  # skin still holding it shut
        r = math.radians(a + 60)
        strut(L, (0.56 * math.cos(r), 0.56 * math.sin(r), 0.3), (0.6 * math.cos(r), 0.6 * math.sin(r), 1.1), 0.1, "rebuilt", w=0.3)


def growth_root(L):
    """Origin: where it leaves the host. Runs out along +X and down to the ground."""
    pts = ((0, 0, 0), (0.9, 0.2, 0.25), (2.4, 0.4, -0.35), (4.0, 0.3, -0.95), (5.3, 0.1, -1.38))
    for (p, q), t in zip(zip(pts, pts[1:]), (0.32, 0.28, 0.24, 0.2)):
        strut(L, p, q, t, "rebuilt_d")
    for p, r in zip(pts[1:3], (0.28, 0.24)):
        L.ico(r, p, swatch="rebuilt", subdiv=0)


PARTS = {
    "kite": {
        "body": (kite_body, "center"),
        "wing_l": (lambda L: kite_wing(L, "l"), "center"),
        "wing_r": (lambda L: kite_wing(L, "r"), "center"),
        "tail": (kite_tail, "center"),
    },
    "growth": {
        "mat": (growth_mat, "bottom"),
        "host": (growth_host, "bottom"),
        "sac": (growth_sac, "bottom"),
        "root": (growth_root, "center"),
    },
}
ROSTER = ("bloat", "shedder", "crawler", "kite", "growth")


# ------------------------------------------------------------------ registration
def _bind(ba):
    global BA
    BA = ba
    return V2._bind(ba)


def _place(b, RLimb, fn, at=(0, 0, 0), turn=0.0, scale=1.0, mirror=False):
    import bmesh
    from mathutils import Matrix, Vector

    sub = BA.Builder()
    fn(RLimb(sub))
    verts = list(sub.bm.verts)
    if mirror:
        bmesh.ops.scale(sub.bm, vec=Vector((-1, 1, 1)), verts=verts)
        bmesh.ops.reverse_faces(sub.bm, faces=list(sub.bm.faces))
    if scale != 1.0:
        bmesh.ops.scale(sub.bm, vec=Vector((scale, scale, scale)), verts=verts)
    if turn:
        bmesh.ops.rotate(sub.bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(turn), 3, "Z"), verts=verts)
    bmesh.ops.translate(sub.bm, vec=Vector(at), verts=verts)
    b.merge(sub)


def _figure(RLimb, form, b):
    """The assembled body, for previews only."""
    if form in FORMS:
        build, sided = FORMS[form], SIDED[form]
        for limb, (x, y, z) in BA.R15_POSE.items():
            for s in (1,) if x == 0 else (-1, 1):
                side = ("r" if s > 0 else "l") if limb in sided else None
                _place(b, RLimb, lambda L, limb_=limb, side_=side: build(L, limb_, side_), at=(s * x, y, z))
        if form == "bloat":
            _navel(b)
    elif form == "kite":
        _place(b, RLimb, kite_body)
        for s, side in ((1, "r"), (-1, "l")):
            _place(b, RLimb, lambda L, side_=side: kite_wing(L, side_), at=(s * KITE_WING_AT[0], KITE_WING_AT[1], KITE_WING_AT[2]))
        _place(b, RLimb, kite_tail, at=KITE_TAIL_AT)
    elif form == "growth":
        _place(b, RLimb, growth_mat)
        _place(b, RLimb, growth_host, at=HOST_AT)
        for x, y, z, scale, turn in SACS:
            _place(b, RLimb, growth_sac, at=(x, y, z), scale=scale, turn=turn)
        for x, y, z, turn, mirror in ROOTS:
            _place(b, RLimb, growth_root, at=(x, y, z), turn=turn, mirror=mirror)


def register(ba):
    """Adds every roster mesh and the five assembled figures to build_assets' ASSETS table."""
    RLimb = _bind(ba)
    for form, build in FORMS.items():
        for limb in ba.R15_LIMB:
            for side in ("l", "r") if limb in SIDED[form] else (None,):

                def fn(b, build_=build, limb_=limb, side_=side):
                    build_(RLimb(b), limb_, side_)

                ba.ASSETS[f"inf_v2_{form}_{limb}" + (f"_{side}" if side else "")] = (fn, "Infected", "center")
    for form, parts in PARTS.items():
        for part, (build, pivot) in parts.items():

            def fn(b, build_=build):
                build_(RLimb(b))

            ba.ASSETS[f"inf_v2_{form}_{part}"] = (fn, "Infected", pivot)
    for form in ROSTER:

        def preview(b, form_=form):
            _figure(RLimb, form_, b)

        ba.ASSETS[f"ref_inf_v2_{form}"] = (preview, "_Reference", "bottom")


# ------------------------------------------------------------------ previews
def _clear(col):
    import bpy

    for o in list(col.objects):
        me = o.data
        bpy.data.objects.remove(o)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


def build_figures(ba, collection_name="InfectedRoster"):
    """Builds `roster_<form>` for all nine forms (the four v2 bodies from infected_v2, the five
    here) and `roster_ref` (the 5-stud figure), each at its game scale with its feet on the
    ground at the origin, into one collection. Prints the five new bodies' triangles."""
    RLimb = _bind(ba)
    col = ba.get_collection(collection_name)
    _clear(col)
    mat = V2._palette_material(ba)
    figs = {}
    for form in tuple(V2.FORMS) + ROSTER:
        b = ba.Builder()
        if form in V2.FORMS:
            V2._figure(ba, RLimb, form, b, sac=form == "hocker")
        else:
            _figure(RLimb, form, b)
        obj = b.finish(f"roster_{form}", col, mat)
        obj.scale = (SCALE[form],) * 3
        figs[form] = obj
        if form in ROSTER:
            extra = 82 if form == "bloat" else 0  # the navel sphere is a Part in game
            tris, cap = obj["tri_count"] - extra, TRI_CAP[form]
            print(f"body inf_v2_{form}: {tris} tris (cap {cap}){'  OVER CAP' if tris > cap else ''}")
    b = ba.Builder()
    ba.ASSETS["ref_human_5st"][0](b)
    figs["ref"] = b.finish("roster_ref", col, mat)
    return col, figs


def _stand(figs, col, names, gap=1.6, labels=True):
    """Stands the named figures in a row along X; returns every object to show."""
    import bpy

    bpy.context.view_layer.update()
    shown, x = [], 0.0
    for name in names:
        obj = figs[name]
        w = max(obj.dimensions.x, 1.0)
        x += w / 2
        obj.location = (x, 0, KITE_HOVER if name == "kite" else 0)
        obj.rotation_euler = (0, 0, 0)
        shown.append(obj)
        if labels:
            shown.append(V2._label("5 STUDS" if name == "ref" else name.upper(), (x, -3.2, -1.2), 0.9, col))
        x += w / 2 + gap
    return shown


def _turnaround(figs, col, form):
    """The reference figure, then the form from the front, its bad (right) side and the back."""
    import bpy

    bpy.context.view_layer.update()
    src = figs[form]
    w = max(src.dimensions.x, src.dimensions.y, 5.0) + 1.2  # a wide row: the frame is cut to the picture's height
    ref = figs["ref"]
    ref.location, ref.rotation_euler = (0, 0, 0), (0, 0, 0)
    shown = [ref, V2._label("5 STUDS", (0, -1.6, -0.9), 0.6, col)]
    x = 1.0 + 1.0 + w / 2
    for i, (label, turn) in enumerate((("FRONT", 0.0), ("BAD SIDE", -math.pi / 2), ("BACK", math.pi))):
        obj = src
        if i:
            obj = src.copy()  # same mesh, turned
            obj.name = f"{src.name}_view{i}"
            col.objects.link(obj)
        obj.location = (x, 0, KITE_HOVER if form == "kite" else 0)
        obj.rotation_euler = (0, 0, turn)
        shown += [obj, V2._label(label, (x, -1.6, -0.9), 0.6, col)]
        x += w
    return shown


def _reset(figs, col):
    import bpy

    for o in list(col.objects):
        if o.name.startswith("label_") or "_view" in o.name:
            me = o.data
            bpy.data.objects.remove(o)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    for o in figs.values():
        o.location, o.rotation_euler = (0, 0, 0), (0, 0, 0)


LINEUP = ("ref", "walker", "runner", "brute", "hocker", "bloat", "shedder", "crawler", "kite", "growth")


def render_previews(ba, scene, cam, col, figs):
    for form in ROSTER:
        shown = _turnaround(figs, col, form)
        ba.frame_and_render(scene, cam, shown, os.path.join(ba.PREVIEWS, f"infected_v2_{form}.png"), size=(1800, 800), direction=(0.3, -1.0, 0.32))
        _reset(figs, col)
    shown = _stand(figs, col, LINEUP)
    ba.frame_and_render(scene, cam, shown, os.path.join(ba.PREVIEWS, "lineup_infected_roster.png"), size=(2600, 760), direction=(0.16, -1.0, 0.3))
    _reset(figs, col)


def live():
    """In the open Blender: stand all nine forms and the reference figure in the scene
    (collection InfectedRoster). Call again after editing this file (it reloads itself)."""
    import importlib

    mod = importlib.reload(sys.modules[__name__])
    ba = V2._load_ba()
    col, figs = mod.build_figures(ba)
    mod._stand(figs, col, LINEUP)
    return figs


def main():
    ba = V2._load_ba()
    os.makedirs(ba.PREVIEWS, exist_ok=True)
    scene = ba.reset_scene()
    cam = ba.setup_render(scene)
    cam.data.lens = 110  # a long lens, as the v2 previews
    scene.display.shading.show_specular_highlight = False  # as the v2 previews: no sheen in game
    col, figs = build_figures(ba)
    render_previews(ba, scene, cam, col, figs)


if __name__ == "__main__":
    main()
