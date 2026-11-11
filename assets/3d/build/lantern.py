"""Lantern, the lift bird (docs/LORE.md > Lantern; build sheet in
docs/sprints/LOBBY_V1_FALLOW.md > Lantern).

One file per singular asset (owner, 2026-11-07). A reserve-fleet medium utility helo: one main
rotor, a tail rotor, skids, a boxy cabin and a long thin boom with a tall fin. The starboard
door is slid back and stays open (the dark rectangle that reads from 40 studs); no door gun,
the empty pintle swung inboard and tied off; faded paint with HRD over the painted-out unit
marks; a bleached decon tide line on the skids and lower cabin; soot behind the exhausts; and
the crew chief's grease-pencil tally inside the door (strokes out, crosses home).

Helo frame (the same mapping as fallow.py: Blender X = X, Blender Y = Roblox Z, Blender Z =
Roblox Y): origin on the deck at the rotor mast's foot, +Z nose, +X starboard (the door), +Y
up. Body and trim print their `offset` in that frame; the rotors are built about their hubs
(LaunchService places them at `HUB` / `TAIL_HUB`). The lamp, the stencilled numbers, the HRD
lettering, the blur discs and every collider are Parts (LaunchService). Glass is opaque
(STYLES §6), so the cockpit has no pilots modelled. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only veh_lantern_body ...
"""

import math

HUB = (0.0, 11.9, 0.0)  # main rotor hub (Roblox x, y, z in the helo frame)
TAIL_HUB = (-0.6, 11.5, -26.6)  # tail rotor hub, port side of the fin; spins about X

SHELL = "olive"  # drawn as Metal (104,110,80) through MeshAssets `surface`


def rb(b, a, c, sw, rot=None):
    """Box between Roblox corners a and c (x, y, z)."""
    size = (abs(c[0] - a[0]), abs(c[2] - a[2]), abs(c[1] - a[1]))
    loc = ((a[0] + c[0]) / 2, (a[2] + c[2]) / 2, (a[1] + c[1]) / 2)
    b.box(size, loc, rot=rot, swatch=sw)


def cyl_up(b, x, y0, y1, z, r, sw, segs=8):
    b.cyl(r, y1 - y0, (x, z, (y0 + y1) / 2), segs=segs, swatch=sw)


def cyl_z(b, x, y, z0, z1, r, sw, segs=8, r_aft=None):
    """Cylinder along Roblox Z; `r` at the nose end (z1), `r_aft` at z0."""
    b.cyl(r, z1 - z0, (x, (z0 + z1) / 2, y), segs=segs, r2=r_aft, rot=(90, 0, 0), swatch=sw)


def cyl_x(b, x0, x1, y, z, r, sw, segs=8):
    b.cyl(r, x1 - x0, ((x0 + x1) / 2, z, y), segs=segs, rot=(0, 90, 0), swatch=sw)


def nose_wedge(b, z0, z1, y0, y1, width, sw, x=0.0):
    """A slope high at the aft end (z0) falling to y0 at the nose end (z1)."""
    b.wedge((z1 - z0, width, y1 - y0), (x, (z0 + z1) / 2, (y0 + y1) / 2), rot=(0, 0, 90), swatch=sw)


# ------------------------------------------------------------------ body (shell)
def body(b):
    s = SHELL
    rb(b, (-3.75, 1.8, -7), (3.75, 2.4, 6), s)  # belly / cabin floor
    rb(b, (-3.75, 8.6, -7), (3.75, 9.2, 6), s)  # roof
    rb(b, (-3.75, 2.4, -7), (-3.45, 8.6, 6), s)  # port wall
    rb(b, (-3.45, 2.4, -7), (3.45, 8.6, -6.7), s)  # aft bulkhead
    # Starboard side: the door opening Z -2..5.5, Y 2.6..8.0 is the dark rectangle.
    rb(b, (3.45, 2.4, -7), (3.75, 8.6, -2), s)  # aft of the door
    rb(b, (3.45, 2.4, 5.5), (3.75, 8.6, 6), s)  # fore post
    rb(b, (3.45, 8.0, -2), (3.75, 8.6, 5.5), s)  # header
    rb(b, (3.45, 2.4, -2), (3.75, 2.6, 5.5), s)  # sill
    rb(b, (-3.5, 1.8, 6), (3.5, 8.4, 9.5), s)  # cockpit
    nose_wedge(b, 9.5, 13, 4.8, 8.4, 7.0, s)  # windscreen slope
    rb(b, (-3.2, 2.2, 9.5), (3.2, 4.8, 13), s)  # lower nose
    rb(b, (-2.2, 9.2, -6.5), (2.2, 10.8, 2.5), s)  # engine housing
    nose_wedge(b, 2.5, 4.5, 9.2, 10.8, 4.4, s)  # its fore fairing
    cyl_z(b, 0, 6.6, -11, -7, 2.4, s, r_aft=1.0)  # tail cone
    cyl_z(b, 0, 6.6, -24, -11, 1.0, s, r_aft=0.6)  # boom: thin against the cabin
    rb(b, (-0.25, 6.0, -27.0), (0.25, 13.0, -24.0), s, rot=(20, 0, 0))  # fin, raked aft
    rb(b, (-3.0, 6.68, -20.7), (3.0, 6.93, -19.3), s)  # horizontal stabiliser
    rb(b, (-0.15, 4.6, -25.3), (0.15, 6.2, -24.7), s)  # tail skid, under the fin's foot


# ------------------------------------------------------------------ trim (palette)
def trim(b):
    # Interior, kept dark so the open door reads from 40 studs.
    rb(b, (-3.45, 2.6, -6.65), (-3.4, 8.55, 5.95), "dark")  # port liner
    rb(b, (-3.4, 2.6, -6.7), (3.4, 8.55, -6.65), "dark")  # aft bulkhead liner
    rb(b, (-3.45, 2.6, 5.95), (3.45, 8.55, 6.0), "dark")  # cockpit bulkhead liner
    rb(b, (3.4, 2.6, -6.65), (3.45, 8.55, -2.0), "dark")  # starboard liner aft of the door
    rb(b, (-3.45, 2.4, -6.7), (3.45, 2.45, 6.0), "dark_d")  # floor
    rb(b, (-3.45, 8.55, -6.7), (3.45, 8.6, 6.0), "dark_d")  # ceiling
    # Canvas bench on the port wall, facing the door; the back straps above it.
    rb(b, (-3.4, 3.5, -5.0), (-2.0, 3.7, 5.0), "tan_d")
    for z in (-4.6, -1.5, 1.5, 4.6):
        cyl_up(b, -2.2, 2.45, 3.5, z, 0.08, "gun_d", segs=6)
    for z in (-4.0, -2.0, 0.0, 2.0, 4.0):
        rb(b, (-3.4, 3.7, z - 0.15), (-3.35, 6.2, z + 0.15), "tan_d")
    # Bundles at their feet, a speedball among them.
    for x, z, sw in ((0.6, -5.0, "olive"), (1.6, -4.6, "olive_d"), (0.5, -3.4, "olive_d")):
        rb(b, (x - 0.6, 2.45, z - 0.7), (x + 0.6, 3.25, z + 0.7), sw)
    b.ico(0.55, (1.8, -3.2, 3.0), subdiv=1, swatch="tan")
    # The door, slid fully aft on its rails, and the kick rail along the sill.
    rb(b, (3.9, 2.6, -9.8), (4.0, 8.2, -2.2), "olive_d")
    for y0, y1 in ((8.2, 8.4), (2.4, 2.6)):
        rb(b, (3.75, y0, -10.0), (4.05, y1, 5.5), "gun_d")
    cyl_z(b, 3.6, 2.8, -1.8, 5.3, 0.08, "gun", segs=6)
    for z in (-1.4, 1.8, 5.0):
        rb(b, (3.52, 2.6, z - 0.06), (3.68, 2.8, z + 0.06), "gun_d")
    rb(b, (3.45, 2.6, -2.0), (3.8, 8.0, -1.8), "olive_d")  # aft door post
    rb(b, (3.45, 2.6, 5.3), (3.8, 8.0, 5.5), "olive_d")  # fore door post
    # The empty pintle on the fore post, its arm swung inboard and lashed: no door gun.
    cyl_up(b, 3.5, 4.7, 5.75, 5.15, 0.2, "gun_d", segs=6)
    rb(b, (1.9, 5.55, 5.05), (3.5, 5.75, 5.25), "gun_d")
    rb(b, (1.9, 5.45, 4.95), (2.2, 5.85, 5.35), "tan")
    # The crew chief's monkey strap from the ceiling hard point.
    rb(b, (2.0, 6.2, -1.1), (2.1, 8.55, -0.9), "tan_d")
    # The tally on the inboard face aft of the door, at the crew chief's shoulder:
    # 12 strokes for seats taken out, 9 crosses for seats brought home.
    for i in range(12):
        z = -2.3 - i * 0.12
        rb(b, (3.35, 6.55, z - 0.03), (3.4, 7.0, z + 0.03), "white")
    for i in range(9):
        z = -2.3 - i * 0.16
        for tilt in (30, -30):
            rb(b, (3.35, 6.0, z - 0.03), (3.4, 6.45, z + 0.03), "white", rot=(tilt, 0, 0))
    # Cockpit glass (opaque), the windscreen as a skin over the shell's slope.
    nose_wedge(b, 9.48, 13.03, 4.78, 8.43, 7.06, "glass")
    for s in (-1, 1):
        x0, x1 = sorted((s * 3.5, s * 3.55))
        rb(b, (x0, 5.2, 7.0), (x1, 7.8, 9.3), "glass")
        rb(b, (x0, 7.8, 7.0), (x1, 8.1, 9.3), "glass_l")
    rb(b, (-2.6, 2.6, 13.0), (2.6, 4.4, 13.05), "glass")  # chin windows
    # The decon tide line: bleached below, a tan line at the high-water mark.
    for s in (-1, 1):
        for x_in, z0, z1 in ((3.75, -7.0, 6.0), (3.5, 6.0, 9.5), (3.2, 9.5, 13.0)):
            x0, x1 = sorted((s * x_in, s * (x_in + 0.05)))
            rb(b, (x0, 1.8, z0), (x1, 2.6, z1), "olive_l")
            rb(b, (x0, 2.6, z0), (x1, 2.75, z1), "tan_d")
        # Skids with upturned toes, struts bleached to the line.
        cyl_z(b, s * 3.7, 0.22, -6.0, 7.0, 0.22, "olive_l", segs=6)
        b.cyl(0.22, 1.4, (s * 3.7, 7.5, 0.6), segs=6, rot=(-60, 0, 0), swatch="olive_l")
        for z in (4.0, -3.5):
            cyl_up(b, s * 3.2, 0.22, 1.0, z, 0.15, "olive_l", segs=6)
            cyl_up(b, s * 3.2, 1.0, 1.8, z, 0.15, "olive_d", segs=6)
        cyl_z(b, s * 1.2, 10.0, -7.0, -5.5, 0.5, "dark_d")  # exhausts
    # Soot on the tail cone and boom behind the exhausts.
    rb(b, (-0.5, 7.55, -13.0), (0.5, 7.65, -11.0), "dark_l")  # a streak along the boom's top
    cyl_z(b, 0, 6.6, -12.4, -11.0, 1.04, "dark_l", r_aft=1.0)
    # HRD patches over the painted-out unit marks (the lettering is a Part).
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.9, s * 0.95))
        rb(b, (x0, 6.0, -17.0), (x1, 7.2, -13.0), "olive_d")
    rb(b, (-3.8, 4.5, -5.0), (-3.75, 7.5, -1.0), "olive_d")
    # Mast and the lamp's pedestal (the lamp is a Part: lit while the rotor turns).
    cyl_up(b, 0, 10.8, 11.65, 0, 0.45, "gun_d")
    rb(b, (-0.45, 10.8, -2.65), (0.45, 11.0, -1.75), "gun_d")


# ------------------------------------------------------------------ rotors
def rotor(b):
    """Main rotor about its hub: four blades drooped 2.5 degrees (tip 0.8 low) at rest."""
    cyl_up(b, 0, -0.25, 0.25, 0, 0.75, "gun_d")
    for k in range(4):
        a = math.radians(k * 90)
        for r0, r1, sw in ((0.8, 18.0, "dark"), (18.0, 19.0, "white_d")):
            mid = (r0 + r1) / 2
            drop = -0.8 * mid / 19.0
            b.box((r1 - r0, 1.0, 0.18), (mid * math.cos(a), mid * math.sin(a), drop), rot=(0, 2.5, k * 90), swatch=sw)
        b.box((1.2, 0.5, 0.35), (1.1 * math.cos(a), 1.1 * math.sin(a), 0), rot=(0, 0, k * 90), swatch="gun_d")


def tail_rotor(b):
    """Tail rotor about its hub; spins about X. Two blades, 5.2 across."""
    cyl_x(b, -0.2, 0.2, 0, 0, 0.3, "gun_d")
    rb(b, (-0.06, -2.1, -0.25), (0.06, 2.1, 0.25), "dark")
    for y in (-2.6, 2.1):
        rb(b, (-0.06, y, -0.25), (0.06, y + 0.5, 0.25), "white_d")


LANTERN = {
    "veh_lantern_body": (body, "ship"),
    "veh_lantern_trim": (trim, "ship"),
    "veh_lantern_rotor": (rotor, "hub"),
    "veh_lantern_tail_rotor": (tail_rotor, "hub"),
}


def register(ba):
    """Adds Lantern's meshes to build_assets' ASSETS table (no bottom shift: offsets are in
    the helo frame, the rotors' from their hubs)."""
    for name, (fn, pivot) in LANTERN.items():
        ba.ASSETS[name] = (fn, "Vehicles", pivot)
