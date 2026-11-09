"""Small set pieces for Infected Co-op Shooter: vehicles, gates, barriers and the `prop_*`
dressing (owner, 2026-11-08: "a separate file for the little things like cars, gates").

Registered into build_assets.py's ASSETS table by `register(ba)` (ba = the build_assets
module: Builder, the palette, `asset`), like warden.py. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only prop_car_sedan

Cars (art direction 2026-11-08, docs/STYLES.md §6): built to the 5-stud character, not to
metres (a sedan roof at 4.4 is chest height, so it vaults side-on). Nose toward -X, pivot at
bottom centre, every tyre on z = 0. Bodies are side silhouettes extruded across the car
(`profile`), with the wheel arches notched out and a narrower greenhouse on top; glass is its
own `glass` swatch, never tyre black. Tail lights are the one saturated accent. 1,000-1,600
tris each. Placed only on flat road or pad (the straddle check), never lifted.
"""

import math

from mathutils import Vector

ROAD = 0.0  # tyres touch z = 0


# ------------------------------------------------------------------ geometry helpers
def profile(b, pts_xz, width, swatch, y=0.0):
    """Extrudes the closed side silhouette `pts_xz` [(x, z), ...] (counter-clockwise seen
    from -Y) across `width` (centred on `y`); the two caps are ear-clipped n-gons."""
    import bmesh

    bm = b.bm
    hw = width / 2
    front = [bm.verts.new((x, y - hw, z)) for x, z in pts_xz]
    back = [bm.verts.new((x, y + hw, z)) for x, z in pts_xz]
    n = len(pts_xz)
    faces = [bm.faces.new((front[k], front[(k + 1) % n], back[(k + 1) % n], back[k])) for k in range(n)]
    caps = [bm.faces.new(tuple(reversed(front))), bm.faces.new(tuple(back))]
    tri = bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="EAR_CLIP")
    b._paint_faces(faces + tri["faces"], swatch)
    return front + back


def arch_notch(cx, r, z_base, segs=4):
    """Points of a half-octagon wheel arch cut up into a body bottom at `z_base`, front to
    back (the bottom edge runs toward +X)."""
    pts = [(cx - r, z_base)]
    cz = z_base  # arch springs from the sill line
    for i in range(segs + 1):
        a = math.pi - math.pi * i / segs
        pts.append((cx + r * math.cos(a), cz + r * math.sin(a) + 0.35))
    pts.append((cx + r, z_base))
    return pts


def panel(a, b_, thick=0.06, inset=0.15, out=0.04):
    """A thin slab along the edge a -> b (XZ), pushed `out` along the edge's outward normal
    (the normal on the left of a -> b: list a windscreen bottom-front to top-back and a rear
    screen top to bottom-back), ends inset by `inset`."""
    dx, dz = b_[0] - a[0], b_[1] - a[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    nx, nz = -uz, ux
    a2 = (a[0] + ux * inset + nx * out, a[1] + uz * inset + nz * out)
    b2 = (b_[0] - ux * inset + nx * out, b_[1] - uz * inset + nz * out)
    return [a2, b2, (b2[0] + nx * thick, b2[1] + nz * thick), (a2[0] + nx * thick, a2[1] + nz * thick)]


def wheel(b, x, y, r, flat=False):
    """Tyre (12 segments), rim (8) and hubcap (6) on the Y axis. A flat tyre is squashed."""
    depth = 0.85
    zc = r * (0.68 if flat else 1.0)
    verts = b.cyl(r, depth, (x, y, zc), segs=12, rot=(90, 0, 0), swatch="dark_d")
    if flat:
        for v in verts:
            v.co.z = zc + (v.co.z - zc) * 0.7 if v.co.z > zc else max(0.0, zc + (v.co.z - zc) * 0.68)
    side = 1 if y > 0 else -1
    b.cyl(r * 0.58, 0.12, (x, y + side * (depth / 2 + 0.02), zc), segs=8, rot=(90, 0, 0), swatch="gun")
    b.cyl(r * 0.26, 0.16, (x, y + side * (depth / 2 + 0.06), zc), segs=6, rot=(90, 0, 0), swatch="gun_l")


def body_outline(L, sill, belt_pts, wheels_x, r):
    """Lower body: the bottom edge (sill) with two arch notches, then `belt_pts` back to
    front along the top (each an (x, z) above the sill). Counter-clockwise from -Y."""
    half = L / 2
    pts = [(-half, sill)]
    for cx in sorted(wheels_x):
        pts += arch_notch(cx, r + 0.2, sill)
    pts.append((half, sill))
    pts += belt_pts
    return pts


def car_details(b, L, W, sill, lamp_z, wheels_x, r, paint, rear_lamp_z=None, flat=None):
    """Shared kit: wheels, arch lips, bumpers, lights, grille, plates, mirrors, door seams."""
    half = L / 2
    for i, cx in enumerate(wheels_x):
        for sy in (-1, 1):
            wheel(b, cx, sy * (W / 2 - 0.45), r, flat=(flat == (i, sy)))
            b.box((2 * r + 0.6, 0.12, 0.18), (cx, sy * (W / 2 + 0.02), sill + r + 0.5), swatch="dark")  # arch lip
            b.box((1.6, 0.1, 0.35), (cx + (r + 0.9) * (1 if cx < 0 else -1), sy * (W / 2 + 0.03), sill + 0.15), swatch="rust_d")  # sill rust
    for sx in (-1, 1):  # bumpers: a box with a chamfered top edge
        b.box((0.55, W + 0.1, 0.7), (sx * (half + 0.1), 0, sill + 0.45), swatch="dark")
        b.wedge((0.3, W + 0.1, 0.25), (sx * (half + 0.08), 0, sill + 0.92), rot=(0, 0, 0 if sx < 0 else 180), swatch="dark")
    for sy in (-1, 1):
        b.box((0.12, 1.1, 0.45), (-half - 0.02, sy * (W / 2 - 0.9), lamp_z), swatch="white_l")  # headlights
        b.box((0.12, 1.0, 0.5), (half + 0.02, sy * (W / 2 - 0.85), rear_lamp_z or lamp_z), swatch="red")  # tail lights
        b.box((0.5, 0.1, 0.35), (-L * 0.2, sy * (W / 2 + 0.25), lamp_z + 1.5), swatch="dark")  # mirror
        b.box((0.1, 0.25, 0.08), (-L * 0.2, sy * (W / 2 + 0.1), lamp_z + 1.45), swatch="dark")  # stalk
    b.box((0.1, W - 2.6, 0.4), (-half - 0.02, 0, lamp_z), swatch="dark_d")  # grille
    for sx in (-1, 1):
        b.box((0.08, 1.3, 0.4), (sx * (half + 0.4), 0, sill + 0.5), swatch="white")  # plates


def seams(b, W, xs, z0, z1):
    for x in xs:
        for sy in (-1, 1):
            b.box((0.05, 0.04, z1 - z0), (x, sy * (W / 2 + 0.01), (z0 + z1) / 2), swatch="dark_d")


# ------------------------------------------------------------------ cars
def car_sedan(b):
    # Three-box sedan 14.0 x 6.0, roof 4.4; silver; rear-right tyre flat, body tipped toward it.
    L, W, r, sill = 14.0, 6.0, 1.05, 0.7
    wx = (-4.3, 4.3)
    body = body_outline(L, sill, [(7.0, 2.5), (6.8, 3.05), (-3.0, 3.05), (-6.6, 2.75), (-7.0, 2.3)], wx, r)
    profile(b, body, W, "white_d")
    profile(b, [(-3.0, 3.0), (4.4, 3.0), (2.2, 4.4), (-1.4, 4.4)], W - 0.8, "white_d")  # greenhouse
    gw = W - 0.8
    profile(b, panel((-3.0, 3.05), (-1.4, 4.4)), gw - 0.3, "glass")  # windscreen
    profile(b, panel((2.2, 4.4), (4.4, 3.15)), gw - 0.3, "glass")  # rear screen
    profile(b, panel((-2.85, 4.32), (-1.55, 4.36), thick=0.05, out=0.03), gw - 0.6, "glass_l")  # screen top strip
    for sy in (-1, 1):  # side glass, B-pillar left in paint
        y = sy * (gw / 2 + 0.03)
        profile(b, [(-2.55, 3.2), (0.35, 3.2), (0.35, 4.2), (-1.3, 4.2)], 0.06, "glass", y=y)
        profile(b, [(0.75, 3.2), (3.9, 3.2), (2.1, 4.2), (0.75, 4.2)], 0.06, "glass", y=y)
    seams(b, W, (-2.9, 0.55, 3.9), sill + 0.4, 3.0)
    car_details(b, L, W, sill, 2.25, wx, r, "white_d", flat=(1, 1))
    b.box((3.0, 0.1, 0.9), (2.0, -(W / 2 + 0.02), 1.6), swatch="rust")  # scorch on the flank
    b.rotate_all((1.5, 0, 0))  # settles toward the flat rear-right tyre


def car_hatch(b):
    # Two-box hatchback 12.0 x 5.8, roof 4.6; maroon; driver window smashed, door open 35°,
    # roof rack with a tarp bundle and a suitcase: they were leaving.
    L, W, r, sill = 12.0, 5.8, 1.0, 0.7
    wx = (-3.8, 3.6)
    body = body_outline(L, sill, [(6.0, 2.6), (5.8, 3.0), (-2.8, 3.0), (-5.6, 2.7), (-6.0, 2.2)], wx, r)
    profile(b, body, W, "paint_maroon")
    gw = W - 0.8
    profile(b, [(-2.8, 2.95), (5.7, 2.95), (5.4, 4.6), (-0.9, 4.6)], gw, "paint_maroon")
    profile(b, panel((-2.8, 3.0), (-0.9, 4.6)), gw - 0.3, "glass")
    profile(b, panel((5.4, 4.55), (5.7, 3.05)), gw - 0.3, "glass")
    # Passenger side glass (+Y); the driver side (-Y) front window is an empty opening.
    profile(b, [(-2.3, 3.15), (1.1, 3.15), (1.1, 4.4), (-0.9, 4.4)], 0.06, "glass", y=gw / 2 + 0.03)
    for sy in (-1, 1):
        profile(b, [(1.5, 3.15), (5.0, 3.15), (4.8, 4.4), (1.5, 4.4)], 0.06, "glass", y=sy * (gw / 2 + 0.03))
    profile(b, [(-2.3, 3.15), (1.1, 3.15), (1.1, 4.4), (-0.9, 4.4)], 0.06, "dark_d", y=-(gw / 2 - 0.02))  # the hole
    b.box((0.6, 1.6, 1.2), (0.4, -1.1, 3.4), swatch="dark_l")  # seat backs seen through it
    b.box((0.6, 1.6, 1.2), (0.4, 1.1, 3.4), swatch="dark_l")
    # Driver door open 35° on its front hinge (-Y side): a slab swung out.
    hinge = (-2.6, -W / 2)
    door_len = 3.6
    ang = math.radians(35)
    dx, dy = math.cos(ang) * door_len, -math.sin(ang) * door_len
    b.box((door_len, 0.18, 2.2), (hinge[0] + dx / 2, hinge[1] + dy / 2, 2.0), rot=(0, 0, -35), swatch="paint_maroon")
    b.box((door_len - 0.6, 0.06, 1.0), (hinge[0] + dx / 2, hinge[1] + dy / 2 - 0.05, 3.55), rot=(0, 0, -35), swatch="dark_d")
    seams(b, W, (1.3, 5.2), sill + 0.4, 2.95)
    car_details(b, L, W, sill, 2.2, wx, r, "paint_maroon")
    # Roof rack, tarp bundle, suitcase.
    for sy in (-1, 1):
        b.box((4.6, 0.15, 0.15), (2.2, sy * 1.7, 4.75), swatch="gun_d")
    for x in (0.4, 4.0):
        b.box((0.15, 3.6, 0.15), (x, 0, 4.75), swatch="gun_d")
    b.box((2.4, 2.6, 0.8), (1.4, 0, 5.2), rot=(0, 0, 6), swatch="tan")
    b.box((1.4, 1.0, 0.7), (3.6, 0.5, 5.15), swatch="tan_d")


def car_pickup(b):
    # Pickup 16.5 x 6.4: tall cab (roof 5.4), open 7-long bed (rail 3.6), tailgate down;
    # champagne under heavy rust; mattress and a crate in the bed; front-left tyre flat.
    L, W, r, sill = 16.5, 6.4, 1.3, 0.9
    wx = (-5.3, 4.6)
    # The body stops at the bed floor (2.4) behind the cab, so the bed is open.
    body = body_outline(L, sill, [(8.25, 2.4), (-1.6, 2.4), (-1.6, 3.4), (-6.0, 3.3), (-8.0, 3.0), (-8.25, 2.4)], wx, r)
    profile(b, body, W, "tan")
    gw = W - 0.6
    profile(b, [(-4.4, 3.3), (-1.6, 3.3), (-1.6, 5.4), (-2.6, 5.4)], gw, "tan")  # cab
    profile(b, panel((-4.4, 3.35), (-2.6, 5.4)), gw - 0.3, "glass")
    profile(b, [(-1.68, 3.9), (-1.6, 3.9), (-1.6, 5.0), (-1.68, 5.0)], gw - 1.0, "glass")  # rear window
    for sy in (-1, 1):
        profile(b, [(-3.9, 3.6), (-1.9, 3.6), (-1.9, 5.1), (-2.75, 5.1)], 0.06, "glass", y=sy * (gw / 2 + 0.03))
    # The bed: floor, two side rails, the front wall; the tailgate dropped flat.
    b.box((9.6, W - 0.6, 0.2), (3.3, 0, 2.5), swatch="rust_d")  # bed floor
    for sy in (-1, 1):
        b.box((9.85, 0.3, 1.2), (3.3, sy * (W / 2 - 0.15), 3.0), swatch="tan")  # rails
        b.box((9.85, 0.34, 0.12), (3.3, sy * (W / 2 - 0.15), 3.62), swatch="rust")  # rail cap
    b.box((0.3, W - 0.3, 1.2), (-1.45, 0, 3.0), swatch="tan")  # bed front wall
    b.box((1.2, W - 0.4, 0.2), (8.85, 0, 2.45), swatch="tan")  # tailgate, dropped flat
    b.box((5.6, 3.6, 0.5), (3.0, -0.7, 2.85), rot=(0, 0, 8), swatch="white_d")  # mattress
    b.box((1.6, 1.6, 1.3), (6.4, 1.6, 3.25), swatch="olive_d")  # crate
    for x in (-1.0, 1.5, 4.0):  # rust bloom on the flanks
        b.box((1.4, 0.1, 0.8), (x, -(W / 2 + 0.02), 2.0), swatch="rust")
    seams(b, W, (-1.7,), sill + 0.4, 3.3)
    car_details(b, L, W, sill, 2.6, wx, r, "tan", rear_lamp_z=2.8, flat=(0, -1))


def car_van(b):
    # Panel van 16.0 x 6.6 x 7.2, short nose; white with rust streaks; sliding side door open
    # on a dark interior, one rear door ajar. Climb only: a Walker cannot reach the roof.
    L, W, r, sill = 16.0, 6.6, 1.15, 0.8
    wx = (-5.0, 5.0)
    body = body_outline(L, sill, [(8.0, 7.0), (7.8, 7.2), (-4.6, 7.2), (-5.9, 5.0), (-7.8, 3.6), (-8.0, 2.8)], wx, r)
    profile(b, body, W, "white")
    profile(b, panel((-5.9, 5.0), (-4.6, 7.2)), W - 0.6, "glass")
    for sy in (-1, 1):
        profile(b, [(-5.6, 4.2), (-3.4, 4.2), (-3.4, 6.4), (-4.5, 6.4)], 0.06, "glass", y=sy * (W / 2 + 0.03))
    # Sliding door open (+Y): the opening shows the dark interior, the door slid back.
    profile(b, [(-2.6, 1.3), (1.4, 1.3), (1.4, 6.5), (-2.6, 6.5)], 0.06, "dark_d", y=W / 2 + 0.02)
    b.box((4.0, 0.15, 5.2), (3.6, W / 2 + 0.2, 3.9), swatch="white")
    b.box((0.25, 0.25, 0.25), (1.5, W / 2 + 0.15, 6.7), swatch="gun_d")  # door rail stop
    # Rear doors: one shut, one ajar 25°.
    b.box((0.15, W / 2 - 0.2, 5.6), (8.05, -W / 4, 3.9), swatch="white")
    b.box((0.15, W / 2 - 0.2, 5.6), (8.05 + 0.6, W / 4 + 0.2, 3.9), rot=(0, 0, 25), swatch="white")
    b.box((0.06, W / 2 - 0.4, 5.2), (8.0, W / 4, 3.9), swatch="dark_d")  # gap behind it
    for x, h in ((-1.0, 2.4), (2.5, 3.2), (6.0, 1.8)):  # rust streaks
        for sy in (-1, 1):
            b.box((0.35, 0.1, h), (x, sy * (W / 2 + 0.02), 7.0 - h / 2), swatch="rust_d")
    seams(b, W, (-3.4, -2.6), sill + 0.4, 6.9)
    car_details(b, L, W, sill, 2.6, wx, r, "white", rear_lamp_z=3.2)


def cargo_truck(b):
    # Army cargo truck 22 x 9 (docs/LEVELS.md D1): cab roof 8 (CLIMB), bed deck 2.9..3.7 with
    # 2-stud sides (CLIMB at 5.7), open between the axles so a prone body crawls under the bed
    # (clearance 2.9). Olive drab, canvas bows bare, a rear tyre flat. Collision is five
    # boxes in MeshAssets (cab, deck, two sides, front axle, rear axle).
    L, W = 22.0, 9.0
    deck0, deck1 = 2.9, 3.7
    r = 1.45
    # Chassis rails under the deck (thin: they do not close the crawl gap).
    for sy in (-1, 1):
        b.box((L - 2.0, 0.5, 0.5), (0.5, sy * 2.6, deck0 - 0.25), swatch="dark")
    # Cab: front of the truck (-X), 6 long, roof 8, a sloped bonnet.
    cab_x0, cab_x1 = -L / 2, -L / 2 + 6.5
    profile(b, [(cab_x0, 1.2), (cab_x1, 1.2), (cab_x1, 8.0), (cab_x0 + 2.2, 8.0), (cab_x0 + 1.6, 5.0), (cab_x0, 4.6)], W - 0.6, "olive")
    profile(b, panel((cab_x0 + 1.6, 5.05), (cab_x0 + 2.2, 7.95), inset=0.2), W - 1.4, "glass")
    for sy in (-1, 1):
        profile(b, [(cab_x0 + 2.4, 5.3), (cab_x1 - 1.0, 5.3), (cab_x1 - 1.0, 7.5), (cab_x0 + 2.4, 7.5)], 0.06, "glass", y=sy * ((W - 0.6) / 2 + 0.03))
        b.box((2.6, 0.1, 2.6), (cab_x0 + 4.4, sy * ((W - 0.6) / 2 + 0.04), 3.6), swatch="olive_d")  # door panel
        b.box((0.4, 0.15, 0.9), (cab_x0 + 2.2, sy * (W / 2 + 0.3), 6.8), swatch="dark")  # mirror
        b.box((0.3, 1.2, 0.5), (cab_x0 - 0.05, sy * 3.0, 3.4), swatch="white_l")  # headlight
        b.box((1.6, 0.6, 1.0), (cab_x0 + 4.0, sy * (W / 2 - 0.2), 1.8), swatch="dark")  # step
    b.box((0.4, W - 2.6, 1.4), (cab_x0 - 0.1, 0, 3.0), swatch="dark_d")  # grille
    b.box((0.7, W + 0.2, 0.8), (cab_x0 - 0.3, 0, 1.6), swatch="dark")  # bumper
    b.box((0.1, 1.4, 0.45), (cab_x0 - 0.7, 0, 1.6), swatch="white")  # plate
    # Bed: the deck slab, low sides (2 above the deck), the front wall, a dropped tailgate.
    bed_x0, bed_x1 = cab_x1 + 0.4, L / 2
    bx = (bed_x0 + bed_x1) / 2
    bl = bed_x1 - bed_x0
    b.box((bl, W, deck1 - deck0), (bx, 0, (deck0 + deck1) / 2), swatch="olive_d")
    for sy in (-1, 1):
        b.box((bl, 0.35, 2.0), (bx, sy * (W / 2 - 0.175), deck1 + 1.0), swatch="olive")
        for k in range(4):  # canvas bows, the canvas gone
            x = bed_x0 + 1.5 + k * (bl - 3.0) / 3
            b.box((0.25, 0.25, 4.0), (x, sy * (W / 2 - 0.2), deck1 + 4.0), swatch="gun_d")
    for k in range(4):
        x = bed_x0 + 1.5 + k * (bl - 3.0) / 3
        b.box((0.25, W - 0.4, 0.25), (x, 0, deck1 + 6.0), swatch="gun_d")
    b.box((0.35, W, 2.0), (bed_x0 + 0.175, 0, deck1 + 1.0), swatch="olive")  # front wall
    b.box((1.9, W - 0.6, 0.25), (bed_x1 + 0.95, 0, deck0 - 0.6), rot=(0, -60, 0), swatch="olive")  # tailgate down
    for sy in (-1, 1):
        b.box((0.15, 1.0, 0.5), (bed_x1 + 0.05, sy * (W / 2 - 1.0), deck0 - 0.3), swatch="red")  # tail light
    b.box((3.0, 2.4, 1.8), (bx - 2.0, 1.4, deck1 + 0.9), swatch="tan")  # crates left in the bed
    b.box((2.0, 2.0, 1.4), (bx + 2.5, -1.8, deck1 + 0.7), swatch="olive_l")
    # Axles: one full-width wheel box each (the crawl gap is between them), wheels outside.
    for ax in (cab_x0 + 3.0, bed_x1 - 3.4):
        b.box((1.2, W - 2.0, 1.6), (ax, 0, 1.7), swatch="dark_d")  # axle housing
        for sy in (-1, 1):
            wheel(b, ax, sy * (W / 2 - 0.55), r, flat=(ax > 0 and sy > 0))


CARS = {
    "prop_car_sedan": car_sedan,
    "prop_car_hatch": car_hatch,
    "prop_car_pickup": car_pickup,
    "prop_car_van": car_van,
    "prop_cargo_truck": cargo_truck,
}


# ------------------------------------------------------------------ set pieces (moved from build_assets.py)
# Mesh names are unchanged, so these export the same FBX as before the move.
# Map pieces and props for the enterable Delta (docs/LEVELS.md section A). Every piece is built
# against the 5-stud character; sizes come from the level sheet's prop catalogue (S = solid,
# D = decoration, T = see-through). Collision: Box unless MeshAssets lists colliders.
CORNERS = ((1, 1), (-1, 1), (1, -1), (-1, -1))
SHARED_FROM_BA = ("COVER_H", "SILL", "HEAD")  # bound from build_assets in register()
COVER_H = SILL = HEAD = 0.0


def _container(b, body, rib, door):
    # ISO shipping container, real proportions at stud scale: 21.5 long (X), 8.7 wide, 9.3
    # tall (almost two characters). Doors on the +X end.
    L, Wd, H = 21.5, 8.7, 9.3
    b.box((L, Wd, H), (0, 0, H / 2), swatch=body)
    for sy in (-1, 1):  # corrugation ribs on the long sides
        for i in range(11):
            b.box((0.9, 0.3, H - 1.0), (-L / 2 + 1.9 + i * 1.77, sy * (Wd / 2 + 0.1), H / 2), swatch=rib)
    for sx, sy in CORNERS:
        b.box((0.5, 0.5, H + 0.2), (sx * (L / 2 - 0.2), sy * (Wd / 2 - 0.2), H / 2 + 0.1), swatch=rib)
    for sy in (-1, 1):  # door leaves + lock bars
        b.box((0.3, Wd / 2 - 0.5, H - 0.6), (L / 2 + 0.1, sy * (Wd / 4), H / 2), swatch=door)
        for k in (-1, 1):
            b.box((0.4, 0.3, H - 1.4), (L / 2 + 0.35, sy * (Wd / 4) + k * 1.1, H / 2), swatch="gun_d")
    b.box((L - 0.4, Wd - 0.4, 0.3), (0, 0, H + 0.1), swatch=rib)  # roof lip


def barrier_jersey(b):
    # Concrete traffic barrier, 6 studs long, 2.4 tall. Stepped jersey profile.
    b.box((6.0, 2.0, 0.5), (0, 0, 0.25), swatch="concrete")
    b.box((6.0, 1.3, 0.7), (0, 0, 0.85), swatch="concrete")
    b.box((6.0, 0.7, 1.2), (0, 0, 1.8), swatch="concrete")
    b.box((1.2, 0.72, 0.5), (-1.8, 0, 1.9), swatch="warning_orange")  # hazard stripes
    b.box((1.2, 0.72, 0.5), (1.8, 0, 1.9), swatch="warning_orange")
    b.box((0.3, 0.3, 0.5), (0, 0, 2.5), swatch="rust")  # lifting eye / rebar


def container_olive(b):
    _container(b, "olive", "olive_d", "olive_l")


def container_rust(b):
    _container(b, "rust", "tan_d", "red_d")


def wreck_humvee(b):
    # Burnt-out armoured truck: 16.5 long (X, nose toward -X), 7.8 wide, 6.5 tall; the hood is
    # chest-high cover. Blackened body, rust patches, turret ring on the cab roof.
    L, Wd = 16.5, 7.8
    b.box((L, Wd - 0.6, 2.4), (0, 0, 2.2), swatch="dark")  # hull
    b.box((5.6, Wd, 0.7), (-L / 2 + 2.8, 0, COVER_H - 0.35), swatch="dark_l")  # hood (top = COVER_H)
    b.box((7.0, Wd - 1.0, 3.1), (1.0, 0, 3.4 + 1.55), swatch="dark")  # cab
    b.box((0.2, Wd - 2.0, 1.8), (-2.55, 0, 5.3), swatch="dark_d")  # windscreen
    for sy in (-1, 1):
        b.box((2.4, 0.2, 1.6), (0.0, sy * (Wd / 2 - 0.45), 5.3), swatch="dark_d")  # side windows
        b.box((2.0, 0.2, 1.6), (3.0, sy * (Wd / 2 - 0.45), 5.3), swatch="dark_d")
    b.box((3.6, Wd - 0.8, 1.4), (L / 2 - 2.2, 0, 3.4 + 0.7), swatch="dark_l")  # rear bed
    b.cyl(1.7, 0.4, (1.0, 0, 6.7), segs=8, swatch="gun_d")  # turret ring
    b.cyl(0.12, 2.6, (2.2, 0, 7.0), segs=5, rot=(0, 90, 0), swatch="gun")  # gun barrel (along +X)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(1.5, 1.2, (sx * 5.2, sy * (Wd / 2 - 0.5), 1.5), segs=8, rot=(90, 0, 0), swatch="dark_d")
            b.cyl(0.6, 1.3, (sx * 5.2, sy * (Wd / 2 - 0.5), 1.5), segs=6, rot=(90, 0, 0), swatch="gun")
    b.box((0.6, Wd, 1.0), (-L / 2 - 0.2, 0, 2.0), swatch="gun_d")  # bumper
    b.box((2.4, 0.15, 1.2), (-3.0, -(Wd / 2 - 0.2), 2.4), swatch="rust")  # rust / scorch patches
    b.box((3.0, 0.15, 0.9), (4.0, (Wd / 2 - 0.2), 2.0), swatch="rust")
    b.box((1.4, 2.0, 0.15), (-5.0, 1.5, COVER_H + 0.02), swatch="rust")


def twall(b):
    # Concrete blast wall (T-wall): 8 long, 12 tall (well over two characters, blocks sight),
    # 1 thick on a 2.6-wide foot. Chain them along a plateau edge or a road.
    b.box((8.0, 2.6, 1.0), (0, 0, 0.5), swatch="concrete")
    b.box((8.0, 1.0, 11.0), (0, 0, 1.0 + 5.5), swatch="concrete")
    b.box((8.0, 1.1, 0.4), (0, 0, 12.0 - 0.2), swatch="white_d")  # cap
    for x in (-2.4, 2.4):
        b.cyl(0.08, 0.6, (x, 0, 12.2), segs=4, swatch="rust")  # lifting loops
    b.box((3.0, 0.08, 0.9), (-1.5, -0.55, 3.2), swatch="warning_orange")  # stencil band
    b.box((2.4, 0.06, 0.5), (-1.5, -0.6, 3.2), swatch="dark_d")


def hesco(b):
    # Hesco gabion: 6 x 4.5 x 4.4 (a real 1.4 m unit), wire-mesh lines over the sand fill.
    H = 4.4
    b.box((6.0, 4.5, H), (0, 0, H / 2), swatch="tan")
    b.box((5.6, 4.1, 0.2), (0, 0, H + 0.08), swatch="tan_l")  # fill showing on top
    for x in (-2.0, 0.0, 2.0):
        for sy in (-1, 1):
            b.box((0.12, 0.12, H), (x, sy * 2.3, H / 2), swatch="dark_l")
    for sx in (-1, 1):
        for y in (-1.5, 1.5):
            b.box((0.12, 0.12, H), (sx * 3.05, y, H / 2), swatch="dark_l")
    for z in (1.5, 3.0):
        for sy in (-1, 1):
            b.box((6.1, 0.12, 0.12), (0, sy * 2.3, z), swatch="dark_l")
        for sx in (-1, 1):
            b.box((0.12, 4.6, 0.12), (sx * 3.05, 0, z), swatch="dark_l")


def checkpoint(b):
    # Guard booth (6 x 6, 9.5 tall, counter window at SILL..HEAD) with a 14-stud striped boom
    # arm reaching along +X across a road. Booth faces -Y; solid in game.
    S = 6.0
    b.box((S, S, SILL), (0, 0, SILL / 2), swatch="concrete")
    for sx, sy in CORNERS:
        b.box((0.6, 0.6, HEAD - SILL), (sx * (S / 2 - 0.3), sy * (S / 2 - 0.3), (SILL + HEAD) / 2), swatch="white_d")
    b.box((S, 0.3, HEAD - SILL), (0, S / 2 - 0.15, (SILL + HEAD) / 2), swatch="white_d")  # solid back wall
    b.box((S, S, 9.0 - HEAD), (0, 0, (HEAD + 9.0) / 2), swatch="white_d")  # head band
    b.box((S + 1.4, S + 1.4, 0.5), (0, 0, 9.25), swatch="asphalt")  # roof
    b.box((1.8, 0.1, 0.9), (0, -S / 2 - 0.06, 8.3), swatch="red")  # STOP sign strip
    b.box((0.8, 0.8, COVER_H), (S / 2 + 1.2, -2.0, COVER_H / 2), swatch="gun_d")  # boom post
    b.box((0.9, 0.9, 0.9), (S / 2 + 1.2, -2.0, COVER_H + 0.2), swatch="gun")  # hinge box
    for i in range(4):  # striped arm, 14 long
        b.box((3.5, 0.45, 0.45), (S / 2 + 1.2 + 1.75 + i * 3.5, -2.0, COVER_H + 0.2), swatch="red" if i % 2 else "white")
    b.box((0.3, 0.3, COVER_H - 0.6), (S / 2 + 1.2 + 14.0, -2.0, (COVER_H - 0.6) / 2), swatch="gun_d")  # rest post


def bus(b):
    # Transit bus (docs/LEVELS.md B): 42 long (X, nose toward -X), 10 wide, 12.5 tall. Tall
    # enough to stop a Hocker's lob and a lane wide when parked across a road: the Delta bus
    # line and the Mile 14 jam. Box collision in game.
    L, Wd, H = 42.0, 10.0, 12.5
    FLOOR = 2.6
    b.box((L, Wd, H - FLOOR - 0.4), (0, 0, FLOOR + (H - FLOOR - 0.4) / 2), swatch="white_d")  # body
    b.box((L - 0.6, Wd - 0.6, 0.4), (0, 0, H - 0.2), swatch="white")  # roof
    b.box((3.0, 3.0, 0.3), (5.0, 0, H + 0.1), swatch="white_d")  # roof hatch
    for sy in (-1, 1):
        b.box((L - 6.0, 0.2, 3.2), (1.0, sy * (Wd / 2 + 0.08), 9.2), swatch="dark_d")  # window band
        for i in range(8):  # window pillars
            b.box((0.3, 0.26, 3.2), (-L / 2 + 5.0 + i * 4.5, sy * (Wd / 2 + 0.1), 9.2), swatch="white_d")
        b.box((L - 2.0, 0.2, 0.9), (0.5, sy * (Wd / 2 + 0.06), 5.6), swatch="gun")  # livery stripe
        b.box((L - 2.0, 0.2, 1.4), (0.5, sy * (Wd / 2 + 0.06), FLOOR + 0.7), swatch="gun_d")  # skirt
    b.box((3.0, 0.24, 7.0), (-L / 2 + 6.0, Wd / 2 + 0.1, FLOOR + 3.5), swatch="dark_d")  # door (right side)
    b.box((0.12, 0.3, 7.0), (-L / 2 + 6.0, Wd / 2 + 0.12, FLOOR + 3.5), swatch="gun_l")  # door split
    b.box((0.2, Wd - 1.2, 4.6), (-L / 2 - 0.08, 0, 8.4), swatch="dark_d")  # windscreen
    b.box((0.14, 6.0, 1.2), (-L / 2 - 0.14, 0, 11.4), swatch="dark")  # destination sign
    b.box((0.06, 3.2, 0.5), (-L / 2 - 0.24, 0, 11.4), swatch="brass")  # its lit text
    b.box((0.2, Wd - 2.0, 2.8), (L / 2 + 0.08, 0, 9.4), swatch="dark_d")  # rear window
    for sx in (-1, 1):
        b.box((0.5, Wd, 1.2), (sx * (L / 2 + 0.2), 0, 3.0), swatch="gun_d")  # bumpers
        for sy in (-1, 1):
            b.cyl(2.0, 1.4, (sx * 14.0, sy * (Wd / 2 - 0.7), 2.0), segs=10, rot=(90, 0, 0), swatch="dark_d")  # tyres
            b.cyl(0.9, 1.5, (sx * 14.0, sy * (Wd / 2 - 0.7), 2.0), segs=8, rot=(90, 0, 0), swatch="gun")  # hubs
    for sy in (-1, 1):
        b.box((0.4, 0.5, 1.6), (-L / 2 + 1.0, sy * (Wd / 2 + 0.2), 9.0), swatch="dark")  # mirrors
    b.box((6.0, 0.16, 2.0), (10.0, -(Wd / 2 + 0.1), 4.6), swatch="rust")  # scorch and rust
    b.box((4.0, 0.16, 1.4), (-8.0, (Wd / 2 + 0.1), 7.2), swatch="rust")
    b.box((2.4, 0.12, 0.9), (-L / 2 + 12.0, -(Wd / 2 + 0.14), 9.0), swatch="dark_d")  # one window blown out


def hesco_tall(b):
    # Two stacked hesco units with a joint band, 8.7 tall: a Walker (ClimbHeight 5) can't take
    # it, a Runner and a player can mantle it. Fabric surface in game (one material).
    H = 4.35
    for k in range(2):
        z0 = k * H
        b.box((6.0, 4.5, H), (0, 0, z0 + H / 2), swatch="tan")
    b.box((6.2, 4.7, 0.3), (0, 0, H), swatch="tan_d")  # joint band
    b.box((5.6, 4.1, 0.2), (0, 0, 2 * H + 0.08), swatch="tan_l")  # fill showing on top
    for x in (-2.0, 0.0, 2.0):  # wire lines proud of the fabric
        for sy in (-1, 1):
            b.box((0.12, 0.12, 2 * H), (x, sy * 2.3, H), swatch="dark_l")
    for sx in (-1, 1):
        for y in (-1.5, 1.5):
            b.box((0.12, 0.12, 2 * H), (sx * 3.05, y, H), swatch="dark_l")
    for z in (1.5, 3.0, 5.85, 7.35):
        for sy in (-1, 1):
            b.box((6.1, 0.12, 0.12), (0, sy * 2.3, z), swatch="dark_l")
        for sx in (-1, 1):
            b.box((0.12, 4.6, 0.12), (sx * 3.05, 0, z), swatch="dark_l")


def crib_stack(b):
    # Concrete cribbing a T-wall is lifted onto: 1.2 wide (X), 2.6 deep, 2.8 tall. Two under
    # one T-wall leave a 5.6 x 2.8 crawl slot (the Gate "Scrapes"). Concrete surface in game.
    for k in range(7):
        z = k * 0.4 + 0.2
        sw = "concrete" if k % 2 == 0 else "asphalt"
        if k % 2 == 0:
            for x in (-0.4, 0.4):
                b.box((0.4, 2.6, 0.4), (x, 0, z), swatch=sw)
        else:
            for y in (-1.1, 1.1):
                b.box((1.2, 0.4, 0.4), (0, y, z), swatch=sw)


def deck_plate(b):
    # Steel road plate laid between roofs: 12 x 5 x 0.3 with raised cleats. DiamondPlate in game.
    b.box((12.0, 5.0, 0.25), (0, 0, 0.125), swatch="gun")
    for x in (-4.5, -2.7, -0.9, 0.9, 2.7, 4.5):
        b.box((0.3, 4.6, 0.08), (x, 0, 0.29), swatch="gun_l")


def cot(b):
    # Field cot 6.5 x 3 x 2.2 (S, vaultable): legs, rails, canvas, blanket, pillow. ~110 tris.
    for sx, sy in CORNERS:
        b.box((0.25, 0.25, 1.6), (sx * 3.0, sy * 1.3, 0.8), swatch="dark_l")
    for sy in (-1, 1):
        b.box((6.5, 0.25, 0.25), (0, sy * 1.35, 1.6), swatch="dark_l")
    b.box((6.3, 2.7, 0.15), (0, 0, 1.68), swatch="olive_d")  # canvas
    b.box((3.2, 2.6, 0.3), (0.9, 0, 1.9), swatch="foliage")  # blanket
    b.box((1.2, 2.0, 0.35), (-2.4, 0, 1.92), swatch="white_d")  # pillow


def generator(b):
    # Towed generator 8 x 4.5 x 5 (S): skid, housing, exhaust stack, control panel. ~150 tris.
    b.box((8.0, 4.5, 0.4), (0, 0, 0.2), swatch="dark")
    b.box((7.0, 4.0, 3.6), (0, 0, 0.4 + 1.8), swatch="gun_d")
    b.box((7.2, 0.1, 1.2), (0, -2.02, 2.4), swatch="gun")  # louvre band
    for x in (-2.4, -1.2, 0.0, 1.2, 2.4):
        b.box((0.3, 0.12, 1.0), (x, -2.08, 2.4), swatch="dark_d")  # louvres
    b.box((0.12, 1.6, 1.2), (3.56, 0.6, 2.6), swatch="dark_d")  # control panel
    b.box((0.08, 0.3, 0.3), (3.62, 0.3, 2.9), swatch="warning_orange")  # its one lamp
    b.cyl(0.4, 1.2, (-2.4, 1.0, 4.6), segs=6, swatch="dark_d")  # exhaust stack
    b.cyl(0.25, 0.4, (-2.4, 1.0, 4.9), segs=6, swatch="rust")
    b.box((1.0, 1.0, 0.2), (2.2, -1.2, 4.1), swatch="rust")  # fuel cap plate


def light_tower(b):
    # Trailer light tower 4 x 4 x 18 (S): trailer, generator box, three-stage mast, four heads.
    b.box((4.0, 3.0, 0.5), (0, 0, 1.0), swatch="dark")  # trailer bed
    for sy in (-1, 1):
        b.cyl(0.8, 0.5, (0.6, sy * 1.7, 0.8), segs=8, rot=(90, 0, 0), swatch="dark_d")  # wheels
    b.box((0.4, 0.4, 0.8), (-1.6, 0, 0.4), swatch="gun_d")  # jack leg
    b.box((2.2, 2.0, 1.8), (-0.6, 0, 2.15), swatch="olive_d")  # generator box
    b.cyl(0.32, 6.0, (1.2, 0, 4.0), segs=6, swatch="gun_d")  # mast stages
    b.cyl(0.26, 6.0, (1.2, 0, 9.6), segs=6, swatch="gun")
    b.cyl(0.2, 5.6, (1.2, 0, 15.0), segs=6, swatch="gun_l")
    b.box((3.0, 0.3, 0.3), (1.2, 0, 17.6), swatch="gun_d")  # crossbar
    for x in (-0.9, 0.9):
        for sy in (-1, 1):
            b.box((0.9, 0.5, 0.7), (1.2 + x, sy * 0.45, 17.6), swatch="dark")  # lamp housings
            b.box((0.8, 0.06, 0.6), (1.2 + x, sy * 0.72, 17.6), swatch="brass_l")  # lenses


def fuel_bladder(b):
    # Collapsible fuel bladder 12 x 8 x 2.9 (S, vaultable): pillow tank, top panel, valve.
    b.box((11.0, 7.0, 2.1), (0, 0, 1.05), swatch="olive_d")
    b.box((9.0, 5.0, 0.5), (0, 0, 2.3), swatch="olive")
    for x in (-3.5, 0.0, 3.5):
        b.box((0.3, 7.4, 2.2), (x, 0, 1.1), swatch="dark")  # tie-down straps
    b.cyl(0.4, 0.5, (4.0, 2.0, 2.75), segs=6, swatch="gun")  # filler valve
    b.box((0.5, 0.5, 0.15), (4.0, 2.0, 2.95), swatch="red")  # its cap


def pallet(b):
    # Wooden pallet 4 x 4 x 0.6 (S): three runners, seven top boards. ~160 tris.
    for y in (-1.7, 0.0, 1.7):
        b.box((4.0, 0.5, 0.2), (0, y, 0.1), swatch="tan_d")
    for y in (-1.7, 0.0, 1.7):
        for x in (-1.6, 0.0, 1.6):
            b.box((0.5, 0.5, 0.25), (x, y, 0.32), swatch="tan_d")  # blocks
    for i in range(7):
        b.box((0.45, 4.0, 0.12), (-1.8 + i * 0.6, 0, 0.51), swatch="tan")


def body_bag(b):
    # Body bag 6.5 x 2.4 x 1 (D, no collision): dark bag, zip strip, tag.
    b.box((5.4, 2.2, 0.9), (-0.5, 0, 0.45), swatch="dark")
    b.wedge((1.2, 2.2, 0.9), (2.8, 0, 0.45), swatch="dark")  # tapered foot
    b.box((5.8, 0.1, 0.06), (-0.3, 0, 0.92), swatch="gun_l")  # zip
    b.box((0.5, 0.4, 0.05), (-2.6, 0.6, 0.92), swatch="white")  # tag


def dumpster(b):
    # Steel dumpster 7 x 4 x 4.4 (S): a Walker's step onto a 9-stud roof. ~130 tris.
    b.box((7.0, 4.0, 3.6), (0, 0, 0.5 + 1.8), swatch="olive_d")
    for sx, sy in CORNERS:
        b.cyl(0.25, 0.5, (sx * 2.9, sy * 1.6, 0.25), segs=6, swatch="dark_d")  # castors
    for sx in (-1, 1):
        b.box((3.4, 4.1, 0.3), (sx * 1.75, 0, 4.25), swatch="dark_l")  # lid halves
        b.box((0.3, 0.6, 1.2), (sx * 3.6, 0, 1.6), swatch="gun_d")  # fork pockets
    b.box((2.0, 0.12, 0.8), (-1.2, -2.06, 2.4), swatch="rust")  # rust patch
    b.box((1.4, 0.12, 0.5), (1.8, 2.06, 2.0), swatch="white_d")  # stencil


def plank(b):
    # Scaffold plank 10 x 2 x 0.4 (S): bridges roof to roof. ~50 tris.
    for y in (-0.5, 0.5):
        b.box((10.0, 0.9, 0.3), (0, y, 0.15), swatch="tan_d")
    for x in (-4.0, 4.0):
        b.box((0.3, 2.0, 0.4), (x, 0, 0.2), swatch="dark_l")  # cleats


def portable_toilet(b):
    # Portable toilet 4 x 4 x 8 (S, climbable): blue cabin, door, vent, white roof.
    b.box((4.2, 4.2, 0.4), (0, 0, 0.2), swatch="dark")
    b.box((4.0, 4.0, 7.2), (0, 0, 0.4 + 3.6), swatch="shield_blue")
    b.box((2.4, 0.12, 6.4), (0, -2.04, 3.8), swatch="dark_l")  # door
    b.box((1.6, 0.1, 0.5), (0, -2.1, 6.4), swatch="white_d")  # vent
    b.box((0.2, 0.2, 0.5), (0.9, -2.14, 3.6), swatch="gun")  # handle
    b.box((4.3, 4.3, 0.4), (0, 0, 7.8), swatch="white_d")  # roof
    b.cyl(0.3, 0.5, (1.2, 1.2, 8.2), segs=6, swatch="white")  # roof vent


def chainlink_panel(b):
    # Chain-link fence panel 12 x 7 (T: solid, see-through, bullets pass). Two posts, two rails,
    # a wire grid of thin boxes. ~270 tris.
    for sx in (-1, 1):
        b.cyl(0.15, 7.0, (sx * 5.9, 0, 3.5), segs=6, swatch="gun_d")
    for z in (0.3, 6.9):
        b.box((12.0, 0.12, 0.12), (0, 0, z), swatch="gun_d")
    for i in range(11):
        b.box((0.05, 0.05, 6.6), (-5.0 + i * 1.0, 0, 3.6), swatch="gun_l")
    for z in (1.3, 2.3, 3.3, 4.3, 5.3, 6.3):
        b.box((12.0, 0.05, 0.05), (0, 0, z), swatch="gun_l")


def concertina(b):
    # Concertina wire coil 12 x 3 x 3 (T): a helix of 24 thin segments along X. ~290 tris.
    r = 1.4
    turns, segs = 3, 24
    pts = []
    for i in range(segs + 1):
        t = i / segs
        ang = t * turns * 2 * math.pi
        pts.append(Vector((-6.0 + 12.0 * t, math.cos(ang) * r, math.sin(ang) * r + 1.5)))
    for p0, p1 in zip(pts[:-1], pts[1:]):
        d = p1 - p0
        length = d.length
        pitch = -math.degrees(math.asin(d.z / length))
        yaw = math.degrees(math.atan2(d.y, d.x))
        b.box((length, 0.1, 0.1), ((p0 + p1) / 2), rot=(0, pitch, yaw), swatch="gun_l")


SET_PIECES = {
    "env_barrier_jersey": (barrier_jersey, "Environment", "bottom"),
    "env_container_olive": (container_olive, "Environment", "bottom"),
    "env_container_rust": (container_rust, "Environment", "bottom"),
    "env_wreck_humvee": (wreck_humvee, "Environment", "bottom"),
    "env_twall": (twall, "Environment", "bottom"),
    "env_hesco": (hesco, "Environment", "bottom"),
    "env_checkpoint": (checkpoint, "Environment", "bottom"),
    "env_bus": (bus, "Environment", "bottom"),
    "env_hesco_tall": (hesco_tall, "Environment", "bottom"),
    "env_crib_stack": (crib_stack, "Environment", "bottom"),
    "env_deck_plate": (deck_plate, "Environment", "bottom"),
    "prop_cot": (cot, "Props", "bottom"),
    "prop_generator": (generator, "Props", "bottom"),
    "prop_light_tower": (light_tower, "Props", "bottom"),
    "prop_fuel_bladder": (fuel_bladder, "Props", "bottom"),
    "prop_pallet": (pallet, "Props", "bottom"),
    "prop_body_bag": (body_bag, "Props", "bottom"),
    "prop_dumpster": (dumpster, "Props", "bottom"),
    "prop_plank": (plank, "Props", "bottom"),
    "prop_portable_toilet": (portable_toilet, "Props", "bottom"),
    "prop_chainlink_panel": (chainlink_panel, "Props", "bottom"),
    "prop_concertina": (concertina, "Props", "bottom"),
}


def register(ba):
    """Adds every set piece in this file to build_assets' ASSETS table."""
    # Shared heights stay defined once, in build_assets (cover, the window band).
    for shared in SHARED_FROM_BA:
        globals()[shared] = getattr(ba, shared)
    for name, entry in SET_PIECES.items():
        ba.ASSETS[name] = entry
    for name, fn in CARS.items():
        ba.ASSETS[name] = (fn, "Props", "bottom")
