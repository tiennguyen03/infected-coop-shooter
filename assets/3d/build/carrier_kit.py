"""The Carrier v2 kit (a PROPOSAL: docs/sprints/CARRIER_V2.md). Nothing here is loaded by the game.

Ship fittings, deck vehicles, the call-in displays, the Easter eggs and the shore pieces that
carrier_v2.py places on the lobby ship. Registered in build_assets only when asked for
(`-- --carrier-v2`), so a normal build exports nothing new.

Every piece is built in the Roblox frame, like fallow.py (x right, y up, z forward; Blender X =
x, Blender Y = z, Blender Z = y), about its own origin on the floor (pivot "ship": no re-seat).
Wall pieces have their origin on the wall face at the floor, +x out of the wall into the room.
One detail level: boxes and 6-8 sided cylinders, palette swatches, no texture.
"""

import math

import bmesh
from mathutils import Matrix, Vector

from fallow import cyl_up, cyl_z, rb, rbc


def R(b, x0, x1, y0, y1, z0, z1, sw):
    rb(b, (x0, y0, z0), (x1, y1, z1), sw)


def cyl_x(b, x0, x1, y, z, r, sw, segs=8):
    b.cyl(r, x1 - x0, ((x0 + x1) / 2, z, y), segs=segs, rot=(0, 90, 0), swatch=sw)


def rod(b, p0, p1, w, sw, h=None):
    """A square bar between two Roblox points (x, y, z)."""
    a = Vector((p0[0], p0[2], p0[1]))
    c = Vector((p1[0], p1[2], p1[1]))
    d = c - a
    verts = bmesh.ops.create_cube(b.bm, size=1.0)["verts"]
    bmesh.ops.scale(b.bm, vec=Vector((w, h or w, d.length)), verts=verts)
    m = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(b.bm, matrix=Matrix.Translation((a + c) / 2) @ m, verts=verts)
    b._paint(verts, sw)


def wheel(b, x, y, z, r, w, sw="dark_d"):
    cyl_x(b, x - w / 2, x + w / 2, y, z, r, sw, segs=8)


def rail(b, z0, z1, x=0.0, y=0.0, h=3.0, sw="objective_yellow", step=5.0):
    """Pipe handrail along z: stanchions and two bars."""
    n = max(1, round((z1 - z0) / step))
    for i in range(n + 1):
        z = z0 + (z1 - z0) * i / n
        R(b, x - 0.12, x + 0.12, y, y + h, z - 0.12, z + 0.12, sw)
    for yy in (y + h * 0.5, y + h - 0.1):
        R(b, x - 0.1, x + 0.1, yy - 0.1, yy + 0.1, z0, z1, sw)


# ------------------------------------------------------------------ ship structure
def rib(b):
    """A hangar web frame on the hull side: column, flange, knee bracket under the deckhead."""
    R(b, 0, 1.3, 0, 18, -0.2, 0.2, "gun_l")  # web
    R(b, 1.3, 1.5, 0, 16.4, -0.6, 0.6, "gun")  # flange
    rod(b, (1.4, 14.0, 0), (4.2, 17.6, 0), 0.4, "gun", h=1.2)  # knee
    R(b, 0, 4.4, 17.3, 18, -0.6, 0.6, "gun")
    R(b, 1.5, 1.56, 5.2, 6.4, -0.5, 0.5, "objective_yellow")  # frame number plate
    R(b, 0, 1.6, 0, 0.5, -0.7, 0.7, "dark_d")  # foot


def pipes(b):
    """One 12-stud bay of wall services: three pipes (square in section at this size), a cable
    tray, brackets, a valve wheel."""
    for y, x, r, sw in ((13.2, 0.7, 0.42, "white_d"), (12.1, 0.55, 0.28, "red"), (11.3, 0.45, 0.2, "gun_l")):
        R(b, x - r, x + r, y - r, y + r, -6, 6, sw)
    R(b, 0.1, 1.3, 14.6, 14.75, -6, 6, "dark_l")  # cable tray
    R(b, 0.3, 1.0, 14.75, 15.0, -6, 6, "dark_d")  # cables
    for z in (-4, 4):
        R(b, 0, 1.3, 10.9, 14.6, z - 0.1, z + 0.1, "gun_d")  # bracket
    b.cyl(0.55, 0.12, (1.25, -2, 13.2), segs=6, rot=(0, 90, 0), swatch="red_d")  # valve wheel


def door(b):
    """A watertight door in its coaming: dogs round the edge, a handwheel, a label plate."""
    R(b, 0, 0.5, 0, 8.2, -2.4, 2.4, "gun_d")  # coaming
    R(b, 0.5, 0.75, 0.8, 7.8, -1.9, 1.9, "gun_l")  # leaf
    R(b, 0.75, 0.82, 1.3, 7.3, -1.5, 1.5, "gun")
    for y in (1.6, 4.3, 7.0):
        for z in (-1.75, 1.75):
            R(b, 0.75, 1.0, y - 0.12, y + 0.12, z - 0.35, z + 0.35, "dark_d")  # dogs
    b.cyl(0.6, 0.14, (1.0, 0, 4.4), segs=8, rot=(0, 90, 0), swatch="dark_d")
    R(b, 0.82, 0.95, 4.3, 4.5, -0.6, 0.6, "gun_d")
    R(b, 0.82, 0.86, 5.9, 6.7, -1.1, 1.1, "objective_yellow")
    R(b, 0, 0.9, 0, 0.8, -2.4, 2.4, "objective_yellow")  # sill, painted to be stepped over
    R(b, 0.5, 0.9, 8.3, 8.9, -0.5, 0.5, "red")  # battle lantern over the door


def firestation(b):
    """Hose reel, foam can, extinguisher and a red board, against a wall."""
    R(b, 0, 0.15, 1.0, 8.0, -2.2, 2.2, "red_d")
    b.cyl(1.5, 0.8, (0.6, -0.8, 5.2), segs=8, rot=(0, 90, 0), swatch="red")
    b.cyl(0.9, 0.9, (0.65, -0.8, 5.2), segs=8, rot=(0, 90, 0), swatch="tan_l")
    cyl_up(b, 0.8, 0, 3.2, 1.3, 0.55, "red")
    cyl_up(b, 0.8, 3.2, 3.7, 1.3, 0.2, "dark_d", segs=6)
    R(b, 0.15, 0.6, 6.9, 7.8, 0.4, 2.0, "white")
    rod(b, (0.5, 3.6, -1.9), (0.5, 0.3, -2.0), 0.18, "tan_l")  # hose end hanging
    R(b, 0.2, 1.6, 0, 2.2, -2.2, -1.2, "red")  # foam drum box


def ramp_trim(b):
    """The hangar ramp's dress (20 wide, 60 run, 20 rise; origin at the foot's centre, the ramp
    rises toward -z): kerbs, pipe handrails on stanchions, anti-slip cleats, edge paint."""
    run, rise = 60.0, 20.0
    k = rise / run
    for s in (-1, 1):
        x = s * 9.7
        rod(b, (x, 0.35, 0), (x, rise + 0.35, -run), 0.6, "dark_d", h=0.7)  # kerb
        for i in range(7):
            z = -run * i / 6
            R(b, x - 0.12, x + 0.12, -z * k, -z * k + 3.4, z - 0.12, z + 0.12, "objective_yellow")
        for h in (1.9, 3.4):
            rod(b, (x, h, 0), (x, rise + h, -run), 0.2, "objective_yellow")
        rod(b, (s * 9.0, 0.06, 0), (s * 9.0, rise + 0.06, -run), 0.5, "objective_yellow", h=0.06)
    for i in range(1, 15):  # cleats
        z = -run * i / 15
        rod(b, (-8.4, -z * k + 0.08, z), (8.4, -z * k + 0.08, z), 0.3, "gun_d", h=0.12)


def deck_rail(b):
    """A 10-stud run of removable deck stanchions with two chains (well and lift edges)."""
    for z in (-5, 0, 5):
        R(b, -0.12, 0.12, 0, 3.2, z - 0.12, z + 0.12, "white_d")
        R(b, -0.3, 0.3, 0, 0.15, z - 0.3, z + 0.3, "dark_d")
    for y in (1.7, 3.0):
        R(b, -0.07, 0.07, y - 0.07, y + 0.07, -5, 5, "objective_yellow")


def floodmast(b):
    """A deck-edge floodlight mast: pole, crossarm, three lamp heads tipped at the deck."""
    R(b, -0.35, 0.35, 0, 15, -0.35, 0.35, "gun_d")
    R(b, -0.6, 0.6, 0, 0.6, -0.6, 0.6, "dark_d")
    R(b, -0.2, 2.2, 14.2, 14.6, -2.6, 2.6, "gun_d")
    for z in (-2, 0, 2):
        rbc(b, (2.0, 13.8, z), (1.3, 1.0, 1.5), "dark_d", rot=(0, -30, 0))
        rbc(b, (2.35, 13.25, z), (0.9, 0.12, 1.2), "brass_l", rot=(0, -30, 0))
    for y in range(2, 14, 2):
        R(b, -0.7, -0.35, y, y + 0.12, -0.3, 0.3, "gun_d")  # rungs


def tiedown(b):
    """One tie-down chain from the deck (origin) up 3.2 and in 3.0 along +x, with its pad-eye."""
    rod(b, (0, 0.1, 0), (3.0, 3.2, 0), 0.16, "gun_l")
    rod(b, (1.2, 1.38, 0), (1.8, 2.02, 0), 0.34, "objective_yellow")  # tensioner
    for a in (0, 90):
        rbc(b, (0, 0.04, 0), (1.3, 0.06, 0.2), "dark_d", rot=(0, 0, a))  # the star pad-eye


def chock(b):
    b.wedge((1.2, 2.2, 0.9), (0.7, 0, 0.45), swatch="objective_yellow")
    b.wedge((1.2, 2.2, 0.9), (-0.7, 0, 0.45), rot=(0, 0, 180), swatch="objective_yellow")


def tractor(b):
    """A deck tow tractor: low, flat, yellow, nose to +z."""
    R(b, -2.6, 2.6, 0.8, 2.6, -4.2, 4.2, "objective_yellow")
    R(b, -2.6, 2.6, 2.6, 2.8, -4.2, 4.2, "brass")
    R(b, -2.8, 2.8, 0.7, 1.2, -4.4, 4.4, "dark_d")  # bumper strake
    for x in (-2.5, 2.5):
        for z in (-2.6, 2.6):
            wheel(b, x, 1.1, z, 1.1, 0.9)
    R(b, -1.9, -0.3, 2.8, 3.5, -1.4, 0.2, "dark")  # seat
    R(b, -1.9, -0.3, 3.5, 4.8, -1.6, -1.2, "dark")
    rod(b, (-1.1, 2.8, 1.2), (-1.1, 4.3, 0.6), 0.16, "dark_d")  # column
    b.cyl(0.55, 0.12, (-1.1, 0.55, 4.35), segs=8, rot=(-22, 0, 0), swatch="dark_d")
    R(b, 0.4, 2.2, 2.8, 3.6, -3.6, 0.6, "brass")  # engine cover
    R(b, 0.7, 1.9, 3.6, 3.7, -3.2, 0.2, "dark_d")
    cyl_up(b, 2.2, 2.8, 5.4, -3.8, 0.12, "dark_d", segs=6)  # beacon mast
    R(b, 2.0, 2.4, 5.4, 5.8, -4.0, -3.6, "warning_orange")
    rod(b, (0, 1.0, 4.2), (0, 1.0, 9.6), 0.3, "dark_d")  # tow bar
    R(b, -0.9, 0.9, 0.85, 1.15, 9.4, 9.8, "dark_d")
    for z in (-4.25, 4.25):
        R(b, -2.0, 2.0, 1.4, 2.2, z - 0.03, z + 0.03, "dark_d")  # hazard plate
        for i in range(4):
            R(b, -2.0 + i, -1.5 + i, 1.4, 2.2, z - 0.06, z + 0.06, "objective_yellow")


def crash_crane(b):
    """The deck crash crane: a yellow mobile crane, boom up over its nose (+z)."""
    R(b, -3.6, 3.6, 1.6, 4.2, -8.5, 8.5, "objective_yellow")
    R(b, -3.8, 3.8, 1.4, 2.0, -8.8, 8.8, "dark_d")
    for x in (-3.5, 3.5):
        for z in (-5.6, 0, 5.6):
            wheel(b, x, 1.6, z, 1.6, 1.2)
    R(b, -3.4, -0.6, 4.2, 8.0, 3.2, 7.4, "objective_yellow")  # cab
    R(b, -3.45, -0.55, 5.6, 7.5, 3.6, 7.45, "glass")
    R(b, -3.45, -0.55, 7.5, 7.7, 3.6, 7.45, "glass_l")
    R(b, -2.8, 2.8, 4.2, 7.4, -8.2, -3.4, "brass")  # engine house / counterweight
    R(b, -3.0, 3.0, 4.2, 5.0, -8.6, -7.6, "dark_d")
    cyl_up(b, 2.2, 7.4, 9.0, -6.6, 0.25, "dark_d", segs=6)  # exhaust
    R(b, 0.2, 2.6, 4.2, 6.2, -2.6, 2.4, "brass")  # boom foot
    p0, p1 = (1.4, 5.8, -1.6), (1.4, 21.0, 15.0)
    rod(b, p0, p1, 1.5, "objective_yellow", h=1.9)  # boom
    rod(b, (1.4, 6.3, 1.6), (1.4, 12.4, 5.4), 0.6, "gun_l")  # ram
    for t in (0.3, 0.5, 0.7, 0.9):  # black bands, so the boom reads at range
        c = [p0[i] + (p1[i] - p0[i]) * t for i in range(3)]
        rbc(b, c, (1.62, 2.0, 0.7), "dark_d", rot=(-42.8, 0, 0))
    R(b, 1.3, 1.5, 14.0, 20.6, 14.9, 15.1, "dark_d")  # fall
    R(b, 0.9, 1.9, 12.6, 14.0, 14.5, 15.5, "red")  # hook block
    R(b, -3.62, 3.62, 2.6, 3.4, -2.0, 2.0, "dark_d")
    R(b, 2.0, 2.6, 8.0, 8.4, 4.6, 5.2, "warning_orange")  # beacon


def ship_crane(b):
    """The ship's own boat crane on the deck edge: pedestal, cab, a lattice jib raised over the
    side (+x), fall and hook."""
    cyl_up(b, 0, 0, 7, 0, 1.8, "gun", segs=8)
    cyl_up(b, 0, 7, 7.6, 0, 2.6, "gun_d", segs=8)
    R(b, -2.2, 2.2, 7.6, 11.6, -2.6, 2.2, "gun_l")  # house
    R(b, 0.4, 2.25, 9.4, 11.0, 0.6, 2.25, "glass")
    R(b, -1.8, 1.8, 11.6, 12.0, -2.2, 1.8, "gun_d")
    R(b, -1.6, 1.6, 7.6, 10.4, -4.4, -2.6, "gun_d")  # counterweight
    a0, a1 = (0, 9.0, 2.0), (0, 30.0, 30.0)
    for dx, dy in ((-0.9, 0), (0.9, 0), (0, 1.6)):
        rod(b, (a0[0] + dx, a0[1] + dy, a0[2]), (a1[0] + dx * 0.3, a1[1] + dy * 0.3, a1[2]), 0.3, "gun_l")
    n = 8
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        w0, w1 = 0.9 * (1 - 0.7 * t0), 0.9 * (1 - 0.7 * t1)
        q0 = [a0[k] + (a1[k] - a0[k]) * t0 for k in range(3)]
        q1 = [a0[k] + (a1[k] - a0[k]) * t1 for k in range(3)]
        s = 1 if i % 2 else -1
        rod(b, (q0[0] - s * w0, q0[1], q0[2]), (q1[0] + s * w1, q1[1], q1[2]), 0.16, "gun")
        rod(b, (q0[0] + s * w0, q0[1], q0[2]), (q1[0], q1[1] + 1.6 * (1 - 0.7 * t1), q1[2]), 0.16, "gun")
    rod(b, (0, 12.0, -1.0), (0, 30.6, 30.0), 0.12, "dark_d")  # topping wire
    R(b, -0.08, 0.08, 14.0, 30.0, 29.9, 30.1, "dark_d")
    R(b, -0.5, 0.5, 12.6, 14.0, 29.5, 30.5, "objective_yellow")
    for y in (8.2, 9.0):
        for t in range(8):
            ang = t * math.pi / 4
            rod(b, (2.6 * math.cos(ang), y, 2.6 * math.sin(ang)), (2.6 * math.cos(ang + math.pi / 4), y, 2.6 * math.sin(ang + math.pi / 4)), 0.1, "gun_d")


def boat(b):
    """A rigid boat griped in under two davits; origin on the hull face, +x outboard."""
    for z in (-7, 7):
        R(b, 0, 0.6, -1, 9, z - 0.4, z + 0.4, "gun_d")
        rod(b, (0.3, 9, z), (4.2, 11.4, z), 0.5, "gun_d")
        R(b, 4.0, 4.2, 6.2, 11.2, z - 0.06, z + 0.06, "dark_d")
    R(b, 1.6, 6.0, 3.6, 6.2, -8.5, 8.5, "warning_orange")  # hull
    rbc(b, (3.8, 4.9, 10.2), (4.4, 2.6, 3.4), "warning_orange", rot=(0, 0, 0))
    R(b, 2.0, 5.6, 2.9, 3.6, -8.0, 9.4, "dark_d")  # keel band
    R(b, 2.2, 5.4, 6.2, 6.5, -8.0, 8.0, "gun_d")
    R(b, 2.8, 4.8, 6.5, 8.4, -5.0, -1.0, "white")  # console
    R(b, 2.75, 4.85, 7.4, 8.2, -1.05, -0.95, "glass")
    cyl_z(b, 3.8, 5.6, -9.6, -8.5, 0.9, "dark_d", segs=6)  # outboard


def island_kit(b):
    """Extra dress for the island, in ship coordinates (fallow.py's island is unchanged under
    it): rails on the stepped levels, the deck-status lights, loudspeakers, searchlights on the
    bridge wing, a flag hoist with the yellow flag, a navigation radar bar, vents, life rings."""
    def rail_x(x0, x1, y, z):
        for h in (1.2, 2.4):
            R(b, x0, x1, y + h, y + h + 0.12, z - 0.06, z + 0.06, "gun_l")
        for i in range(int((x1 - x0) // 4) + 1):
            x = x0 + i * (x1 - x0) / max(1, (x1 - x0) // 4)
            R(b, x - 0.06, x + 0.06, y, y + 2.5, z - 0.06, z + 0.06, "gun_l")

    def rail_z(z0, z1, y, x):
        for h in (1.2, 2.4):
            R(b, x - 0.06, x + 0.06, y + h, y + h + 0.12, z0, z1, "gun_l")
        for i in range(int((z1 - z0) // 4) + 1):
            z = z0 + i * (z1 - z0) / max(1, (z1 - z0) // 4)
            R(b, x - 0.06, x + 0.06, y, y + 2.5, z - 0.06, z + 0.06, "gun_l")

    rail_z(-9.6, 49.6, 58, 22.3)  # the base's roof edge, over the deck
    rail_x(22.3, 40.6, 58, 49.7)
    rail_z(-5.6, 33.6, 65, 23.3)  # O4 roof
    rail_x(22.8, 39.8, 73, 47.8)  # bridge roof
    rail_z(34.2, 47.8, 73, 22.8)
    rail_z(36.2, 45.8, 66, 43.8)  # bridge wing
    # Deck-status lights over Pri-Fly: red, amber, green in a black box (red is lit: Part).
    R(b, 19.6, 20.4, 66.2, 69.4, -5.2, -0.8, "dark_d")
    for i, sw in enumerate(("red_d", "brass_d", "olive_d")):
        R(b, 19.5, 19.6, 67.0, 68.6, -4.8 + i * 1.4, -3.8 + i * 1.4, sw)
    # Loudspeakers on the deck face.
    for z in (8, 24):
        rbc(b, (21.5, 56.5, z), (1.2, 1.2, 1.6), "gun_d", rot=(0, 20, 0))
        rbc(b, (21.0, 56.3, z), (0.2, 1.5, 2.0), "white_d", rot=(0, 20, 0))
    # Searchlights on the bridge wing and the bridge roof.
    for x, y, z in ((43, 66, 37), (43, 66, 45), (24, 73, 36)):
        cyl_up(b, x, y, y + 1.4, z, 0.2, "gun_d", segs=6)
        cyl_x(b, x - 0.9, x + 0.5, y + 2.0, z, 0.8, "dark_d")
        cyl_x(b, x - 1.0, x - 0.9, y + 2.0, z, 0.7, "white_l")
    # Navigation radar bar and a second small dome on the bridge roof.
    cyl_up(b, 31, 73, 76, 44, 0.3, "gun_d", segs=6)
    R(b, 27.5, 34.5, 76, 76.5, 43.7, 44.3, "white")
    b.ico(1.6, (36, 38, 74.4), subdiv=1, swatch="white")
    # Flag hoist: halyards from the yard to the O4 rail, the yellow flag and three signal flags.
    rod(b, (26, 103.6, 40), (23.6, 67.5, 30), 0.08, "dark_d")
    rod(b, (36, 103.6, 40), (40.2, 67.5, 30), 0.08, "dark_d")
    R(b, 23.9, 24.0, 86, 90, 31.2, 37.2, "objective_yellow")
    for i, sw in enumerate(("red", "white", "friendly_blue")):
        R(b, 38.4, 38.5, 78 + i * 5, 81.5 + i * 5, 30.5, 34.5, sw)
    # Vent louvres and a ventilator cowl aft, life rings by the deck door, cable runs.
    for z in (14, 26, 40):
        R(b, 21.86, 22.0, 49, 53, z - 2, z + 2, "gun_d")
        for y in (49.6, 50.6, 51.6, 52.4):
            R(b, 21.8, 21.9, y, y + 0.25, z - 1.8, z + 1.8, "dark_d")
    for z in (0.5, 12):
        b.cyl(1.1, 0.3, (21.85, z, 45), segs=8, rot=(0, 90, 0), swatch="warning_orange")
        b.cyl(0.6, 0.34, (21.85, z, 45), segs=8, rot=(0, 90, 0), swatch="gun")
    for y in (47.5, 55):
        R(b, 21.86, 22.0, y, y + 0.3, -9.5, 49.5, "dark_l")
    R(b, 21.86, 22.0, 40.1, 47.5, 30, 30.3, "dark_l")
    cyl_up(b, 39, 65, 70, 28, 1.3, "gun_d")
    rbc(b, (39, 70.6, 27), (2.6, 2.2, 3.2), "gun_d", rot=(25, 0, 0))


# ------------------------------------------------------------------ hangar gear
def toolchest(b):
    R(b, -1.6, 1.6, 0.5, 4.2, -0.9, 0.9, "red")
    for y in (1.2, 2.0, 2.8, 3.6):
        R(b, -1.4, 1.4, y, y + 0.08, 0.9, 0.96, "white_d")
    R(b, -1.7, 1.7, 4.2, 4.4, -1.0, 1.0, "dark_d")
    for x in (-1.3, 1.3):
        cyl_x(b, x - 0.1, x + 0.1, 0.25, 0.6, 0.25, "dark_d", segs=6)
        cyl_x(b, x - 0.1, x + 0.1, 0.25, -0.6, 0.25, "dark_d", segs=6)
    R(b, -0.8, 0.2, 4.4, 4.9, -0.4, 0.3, "gun_l")  # a part left on top


def pallet_net(b):
    """A pallet of cases under a cargo net, lashed to the deck."""
    R(b, -3, 3, 0, 0.5, -3, 3, "tan_d")
    R(b, -2.7, 2.7, 0.5, 3.4, -2.7, 2.7, "olive")
    R(b, -2.7, 0.4, 3.4, 5.6, -2.7, 1.0, "olive_d")
    R(b, 0.6, 2.6, 3.4, 4.8, -2.5, 2.5, "tan")
    for x in (-1.6, 0, 1.6):
        R(b, x - 0.08, x + 0.08, 0.5, 3.46, -2.76, 2.76, "tan_l")
    for y in (1.4, 2.6):
        R(b, -2.76, 2.76, y - 0.08, y + 0.08, -2.76, 2.76, "tan_l")
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        rod(b, (sx * 2.7, 3.4, sz * 2.7), (sx * 4.0, 0.05, sz * 4.0), 0.12, "objective_yellow")


def crates(b):
    """A lashed stack of stores cases."""
    R(b, -3.5, 0, 0, 3, -2, 2, "olive")
    R(b, 0.2, 3.6, 0, 3, -2, 2, "olive_d")
    R(b, -2.6, 1.2, 3, 6, -1.9, 1.9, "olive")
    R(b, 1.4, 3.4, 3, 4.6, -1.5, 1.5, "tan")
    for x in (-1.7, 1.9):
        R(b, x - 0.1, x + 0.1, 0, 6.06 if x < 0 else 3.06, -2.06, 2.06, "dark_d")
    R(b, -3.3, -1.9, 1.0, 2.0, 2.0, 2.04, "white_d")
    R(b, 0.6, 2.0, 1.0, 2.0, 2.0, 2.04, "objective_yellow")


def drums(b):
    for x, z, sw in ((-1.3, -1.2, "red"), (1.3, -1.2, "red"), (0, 1.1, "friendly_blue"), (-2.6, 1.1, "red")):
        cyl_up(b, x, 0, 3.4, z, 1.15, sw)
        cyl_up(b, x, 1.1, 1.3, z, 1.22, "dark_d")
        cyl_up(b, x, 2.3, 2.5, z, 1.22, "dark_d")
    R(b, -4.0, 2.7, 0, 0.3, -2.6, 2.5, "tan_d")


def engine_stand(b):
    """A helicopter engine out on its stand, a drip tray under it."""
    for z in (-2.4, 2.4):
        R(b, -1.6, 1.6, 0, 0.4, z - 0.2, z + 0.2, "objective_yellow")
        for x in (-1.3, 1.3):
            rod(b, (x, 0.4, z), (0, 3.0, z), 0.25, "objective_yellow")
    cyl_z(b, 0, 3.4, -3.0, 2.6, 1.1, "gun_l")
    cyl_z(b, 0, 3.4, 2.6, 3.4, 0.7, "dark_d")
    cyl_z(b, 0, 3.4, -3.4, -3.0, 1.25, "gun_d")
    R(b, -0.5, 0.5, 4.3, 4.9, -1.6, 0.6, "gun_d")
    cyl_z(b, 0.9, 3.9, -2.0, 1.6, 0.18, "brass", segs=6)
    R(b, -1.5, 1.5, 0, 0.15, -1.8, 1.8, "dark_d")


def blade_rack(b):
    """Spare rotor blades in a wall rack; origin on the wall, blades along z."""
    for z in (-7, 7):
        R(b, 0, 2.0, 0, 7.5, z - 0.2, z + 0.2, "gun_d")
    for i in range(4):
        y = 1.2 + i * 1.7
        R(b, 0.3, 1.9, y, y + 0.22, -9.5, 9.5, "dark")
        R(b, 0.3, 1.9, y, y + 0.24, 8.3, 9.5, "white_l")


def jack(b):
    """An aircraft jack stand."""
    for a in range(3):
        ang = a * 2 * math.pi / 3
        rod(b, (math.cos(ang) * 1.4, 0, math.sin(ang) * 1.4), (0, 2.6, 0), 0.22, "objective_yellow")
    cyl_up(b, 0, 0, 3.4, 0, 0.22, "gun_l", segs=6)
    R(b, -0.4, 0.4, 3.4, 3.6, -0.4, 0.4, "dark_d")


def hoist(b):
    """The Loadmaster's rigging rail: a beam on two posts, a chain hoist, a slung case."""
    for x in (-5, 5):
        R(b, x - 0.25, x + 0.25, 0, 11, -0.25, 0.25, "objective_yellow")
        R(b, x - 0.9, x + 0.9, 0, 0.3, -0.9, 0.9, "dark_d")
    R(b, -5.4, 5.4, 11, 11.7, -0.3, 0.3, "objective_yellow")
    R(b, 1.2, 2.2, 10.2, 11.0, -0.4, 0.4, "dark_d")
    R(b, 1.64, 1.76, 6.6, 10.2, -0.06, 0.06, "gun_l")
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        rod(b, (1.7, 6.6, 0), (1.7 + sx * 1.8, 4.9, sz * 1.3), 0.1, "tan_l")
    R(b, -0.3, 3.7, 2.2, 4.9, -1.5, 1.5, "olive")
    R(b, -0.34, 3.74, 3.3, 3.6, -1.54, 1.54, "tan_l")
    R(b, 0.6, 2.8, 2.9, 4.2, 1.5, 1.54, "white_d")


def scale_cases(b):
    """Slung cases waiting at the Loadmaster's: a platform scale with a bundle on it, a stack."""
    R(b, -2, 2, 0, 0.5, -2, 2, "gun_d")
    R(b, -1.5, 1.5, 0.5, 2.6, -1.3, 1.3, "tan")
    R(b, -1.54, 1.54, 1.3, 1.6, -1.34, 1.34, "tan_d")
    R(b, 2.0, 2.4, 0, 4.4, 1.2, 1.6, "gun_d")
    R(b, 1.7, 2.7, 4.4, 5.4, 1.1, 1.7, "white")
    R(b, 4, 8, 0, 3, -1.5, 1.5, "olive")
    R(b, 4.3, 7.7, 3, 6, -1.4, 1.4, "olive_d")
    R(b, 5.2, 6.8, 6, 6.9, -0.8, 0.8, "tan")


def console(b):
    """A map-room console: a desk, a sloped panel, one round scope and a screen."""
    R(b, -3, 3, 0, 2.8, -1.0, 1.0, "gun_d")
    R(b, -3, 3, 2.8, 3.0, -1.2, 1.2, "dark")
    rbc(b, (0, 4.3, -0.5), (6, 2.8, 0.5), "gun_d", rot=(-18, 0, 0))
    b.cyl(0.95, 0.12, (-1.5, -0.2, 4.4), segs=8, rot=(72, 0, 0), swatch="olive_d")
    b.cyl(0.8, 0.14, (-1.5, -0.2, 4.4), segs=8, rot=(72, 0, 0), swatch="dark_d")
    rbc(b, (1.3, 4.45, -0.18), (2.4, 1.6, 0.1), "glass", rot=(-18, 0, 0))
    for i in range(5):
        R(b, -2.6 + i * 0.5, -2.3 + i * 0.5, 3.0, 3.12, 0.3, 0.6, "brass_l" if i % 2 else "red")
    R(b, 1.0, 2.6, 3.0, 3.5, 0.2, 0.9, "dark_d")  # handset cradle


def kitshelf(b):
    """Stores shelving for the Quartermaster: helmets, plates, packs and grenade cases."""
    for x in (-4, 0, 4):
        R(b, x - 0.12, x + 0.12, 0, 9, 0, 1.6, "gun_d")
    for y in (0.4, 3.2, 6.0, 8.8):
        R(b, -4, 4, y, y + 0.2, 0, 1.6, "gun")
    for i in range(4):
        b.ico(0.75, (-3.2 + i * 0.95 * 1.9 / 1.9 * 1.0, 0.8, 6.9), subdiv=1, swatch="olive_d" if i % 2 else "dark")
    for i in range(3):
        R(b, 0.5 + i * 1.1, 1.4 + i * 1.1, 6.2, 7.8, 0.3, 0.6, "dark")  # plates
    for i in range(3):
        R(b, -3.6 + i * 1.3, -2.5 + i * 1.3, 3.4, 5.2, 0.2, 1.3, "olive")  # packs
    for i in range(3):
        R(b, 0.4 + i * 1.2, 1.4 + i * 1.2, 3.4, 4.3, 0.2, 1.4, "tan_d")
        R(b, 0.4 + i * 1.2, 1.4 + i * 1.2, 4.3, 4.4, 0.2, 1.4, "objective_yellow")
    R(b, -3.8, -0.2, 0.6, 2.6, 0.1, 1.5, "olive_d")
    R(b, 0.2, 3.8, 0.6, 2.2, 0.1, 1.5, "tan")


def ammo_stack(b):
    R(b, -2.4, 2.4, 0, 1.6, -1.2, 1.2, "olive_d")
    R(b, -2.4, 2.4, 1.6, 3.2, -1.2, 1.2, "olive")
    R(b, -1.2, 2.2, 3.2, 4.8, -1.1, 1.1, "olive_d")
    for y in (0.6, 2.2, 3.8):
        R(b, -1.0, 1.0, y, y + 0.5, 1.2, 1.24, "objective_yellow")
    R(b, 2.6, 3.6, 0, 1.4, -0.5, 0.5, "olive")
    R(b, 2.6, 3.6, 1.4, 1.55, -0.5, 0.5, "dark_d")


def crew_corner(b):
    """The crew's corner: a bench of old helicopter seats, a cable-drum table with cards and
    mugs, a coffee urn on a case. Origin on the bulkhead, +x into the room, pieces along z."""
    for z in (-3, -0.6, 1.8):
        R(b, 0.4, 2.4, 1.4, 1.8, z, z + 2.2, "tan_d")
        R(b, 0.3, 0.7, 1.8, 4.6, z, z + 2.2, "tan_d")
        R(b, 0.72, 0.76, 2.0, 4.4, z + 0.9, z + 1.3, "tan_l")
    for z in (-3, 4):
        R(b, 0.4, 2.4, 0, 1.4, z - 0.1, z + 0.1, "gun_d")
    cyl_up(b, 5.2, 0, 2.2, 0.4, 1.9, "tan", segs=8)
    cyl_up(b, 5.2, 2.2, 2.4, 0.4, 2.3, "tan_d", segs=8)
    R(b, 4.6, 5.2, 2.4, 2.46, 0.0, 0.8, "white_l")
    R(b, 5.4, 5.8, 2.4, 2.46, -0.3, 0.3, "white_l")
    cyl_up(b, 6.1, 2.4, 2.9, 1.2, 0.2, "white", segs=6)
    cyl_up(b, 4.4, 2.4, 2.9, -0.6, 0.2, "red", segs=6)
    R(b, 0.3, 2.3, 0, 2.6, 6.0, 8.6, "olive_d")  # the urn's case
    cyl_up(b, 1.3, 2.6, 5.0, 7.0, 0.8, "gun_l")
    cyl_up(b, 1.3, 5.0, 5.3, 7.0, 0.5, "dark_d", segs=6)
    cyl_up(b, 1.3, 2.6, 3.1, 8.1, 0.2, "white", segs=6)


# ------------------------------------------------------------------ call-in displays
def placard(b):
    """A display placard on a stand (the name is lettering in carrier_v2 / a SurfaceGui in game)."""
    R(b, -0.1, 0.1, 0, 2.6, -0.1, 0.1, "gun_d")
    R(b, -0.5, 0.5, 0, 0.12, -0.5, 0.5, "dark_d")
    rbc(b, (0, 3.2, 0), (0.12, 1.7, 3.2), "dark_d", rot=(0, 18, 0))


def callin_hammer(b):
    """Hammer: an 81 mm mortar on its baseplate and bipod, an open crate of bombs, three stood up."""
    cyl_up(b, 0, 0, 0.25, 0, 1.3, "dark_d")
    rod(b, (0, 0.2, 0), (0, 4.3, 2.0), 0.5, "olive_d")
    rod(b, (0, 4.3, 2.0), (0, 4.5, 2.1), 0.62, "dark_d")
    for s in (-1, 1):
        rod(b, (0, 3.0, 1.4), (s * 1.4, 0, 2.8), 0.14, "gun_d")
    rod(b, (-1.0, 0.9, 2.4), (1.0, 0.9, 2.4), 0.08, "gun_d")
    R(b, 2.0, 5.6, 0, 1.3, -1.2, 1.2, "olive")  # crate
    R(b, 2.15, 5.45, 1.0, 1.32, -1.05, 1.05, "tan_d")
    rbc(b, (3.8, 1.5, -1.9), (3.6, 0.15, 2.4), "olive_d", rot=(55, 0, 0))  # lid, propped open
    for i in range(3):
        for j in range(2):
            x, z = 2.7 + i * 1.1, -0.5 + j * 1.0
            cyl_up(b, x, 1.2, 1.7, z, 0.3, "olive_d", segs=6)
            cyl_up(b, x, 1.7, 1.9, z, 0.2, "brass", segs=6)
    for i in range(3):
        x = 2.4 + i * 1.0
        cyl_up(b, x, 0.5, 2.0, 2.6, 0.32, "olive_d", segs=6)
        b.cyl(0.32, 0.6, (x, 2.6, 2.3), segs=6, r2=0.08, swatch="brass")
        cyl_up(b, x, 0, 0.5, 2.6, 0.14, "gun_d", segs=6)
        for a in (0, 90):
            rbc(b, (x, 0.3, 2.6), (0.7, 0.5, 0.06), "gun_d", rot=(0, 0, a))


def callin_anvil(b):
    """Anvil: observer's binoculars on a tripod, a map board with pins and a pencilled line, two
    105 mm rounds stood on end and a field telephone."""
    for a in range(3):
        ang = a * 2 * math.pi / 3 + 0.5
        rod(b, (math.cos(ang) * 1.5, 0, math.sin(ang) * 1.5), (0, 4.1, 0), 0.14, "tan_d")
    R(b, -0.3, 0.3, 4.1, 4.4, -0.3, 0.3, "dark_d")
    for s in (-1, 1):
        cyl_z(b, s * 0.38, 4.8, -0.9, 0.9, 0.32, "olive_d", segs=6)
        cyl_z(b, s * 0.38, 4.8, 0.9, 1.0, 0.36, "glass_l", segs=6)
    R(b, -0.2, 0.2, 4.6, 5.0, -0.3, 0.3, "dark_d")
    for x in (2.6, 6.2):  # easel
        rod(b, (x, 0, 0.9), (x, 6.4, -0.6), 0.16, "tan_d")
    rod(b, (4.4, 0, -2.2), (4.4, 5.6, -0.5), 0.16, "tan_d")
    rbc(b, (4.4, 4.2, -0.02), (4.6, 3.4, 0.12), "tan_l", rot=(14, 0, 0))
    rbc(b, (4.4, 4.2, 0.07), (4.2, 3.0, 0.04), "white_l", rot=(14, 0, 0))
    rbc(b, (4.0, 4.3, 0.1), (0.1, 2.6, 0.04), "friendly_blue", rot=(14, 0, 22))  # the river
    rbc(b, (4.9, 4.1, 0.1), (2.2, 0.1, 0.04), "red", rot=(14, 0, 30))  # the gun-target line
    for x, y in ((3.2, 4.9), (5.6, 3.5), (5.2, 5.0)):
        rbc(b, (x, y, 0.2 - (y - 4.2) * 0.25), (0.2, 0.2, 0.2), "red_l")
    for x in (8.0, 9.2):
        cyl_up(b, x, 0, 2.6, -0.4, 0.45, "brass")
        b.cyl(0.45, 1.5, (x, -0.4, 3.35), segs=8, r2=0.1, swatch="olive_d")
        cyl_up(b, x, 2.5, 2.7, -0.4, 0.47, "brass_d")
    R(b, 7.6, 9.0, 0, 0.9, 1.0, 1.8, "olive_d")  # field telephone
    R(b, 7.7, 8.9, 0.9, 1.15, 1.2, 1.5, "dark_d")


def callin_shrike(b):
    """Shrike: a helicopter rocket pod on a loading cradle, two rockets and a belt box."""
    for z in (-1.6, 1.6):
        R(b, -1.2, 1.2, 0, 0.3, z - 0.15, z + 0.15, "objective_yellow")
        R(b, -0.15, 0.15, 0.3, 1.7, z - 0.15, z + 0.15, "objective_yellow")
        R(b, -1.0, 1.0, 1.7, 1.9, z - 0.2, z + 0.2, "objective_yellow")
    cyl_z(b, 0, 2.8, -3.0, 3.0, 1.0, "olive_d")
    cyl_z(b, 0, 2.8, 3.0, 3.1, 0.92, "dark_d")
    for a in range(6):
        ang = a * math.pi / 3
        cyl_z(b, math.cos(ang) * 0.55, 2.8 + math.sin(ang) * 0.55, 3.1, 3.16, 0.2, "red_d", segs=6)
    b.cyl(1.0, 1.2, (0, -3.6, 2.8), segs=8, r2=0.4, rot=(90, 0, 0), swatch="olive_d")
    R(b, -0.3, 0.3, 3.8, 4.1, -1.2, 1.2, "gun_d")  # lugs
    for x in (2.2, 3.0):
        cyl_z(b, x, 0.35, -2.4, 2.0, 0.24, "white_d", segs=6)
        b.cyl(0.24, 0.9, (x, 2.45, 0.35), segs=6, r2=0.05, rot=(-90, 0, 0), swatch="red")
        R(b, x - 0.35, x + 0.35, 0, 0.12, -2.0, 1.6, "tan_d")
    R(b, -3.4, -2.0, 0, 1.2, -1.0, 1.0, "olive")
    R(b, -3.3, -2.1, 1.2, 1.4, -0.9, 0.9, "brass")


def callin_tripline(b):
    """Tripline: mines laid out in rows on a tarp, a wire reel, stakes and two warning markers."""
    R(b, -3.2, 3.2, 0, 0.08, -2.6, 2.6, "tan_d")
    for i in range(3):
        for j in range(2):
            x, z = -2.0 + i * 2.0, -1.2 + j * 2.4
            cyl_up(b, x, 0.08, 0.5, z, 0.75, "olive_d")
            cyl_up(b, x, 0.5, 0.62, z, 0.3, "dark_d", segs=6)
            R(b, x - 0.9, x + 0.9, 0.2, 0.3, z - 0.06, z + 0.06, "olive")
    b.cyl(0.9, 0.9, (4.6, -1.2, 0.9), segs=8, rot=(0, 90, 0), swatch="gun_d")
    b.cyl(0.6, 1.0, (4.6, -1.2, 0.9), segs=8, rot=(0, 90, 0), swatch="brass")
    for i in range(4):
        R(b, 4.1 + i * 0.3, 4.25 + i * 0.3, 0, 0.15, 0.6, 2.6, "tan")
    for x in (-3.9, 3.9):
        R(b, x - 0.05, x + 0.05, 0, 2.2, 2.5, 2.6, "gun_d")
        rbc(b, (x, 2.6, 2.55), (1.2, 1.2, 0.08), "red", rot=(0, 0, 45))
    rod(b, (-3.9, 1.2, 2.55), (3.9, 1.2, 2.55), 0.04, "white_l")  # the tripwire, shown strung


def callin_concertina(b):
    """Concertina: a stretched run of wire between two pickets, coils stacked, gloves on top."""
    for x in (-4.2, 4.2):
        R(b, x - 0.08, x + 0.08, 0, 4.2, -0.08, 0.08, "gun_d")
    for i in range(9):
        x = -3.8 + i * 0.95
        b.cyl(1.5, 0.08, (x, 0, 1.6), segs=8, rot=(0, 90 + (12 if i % 2 else -12), 0), swatch="gun_l", cap=False)
    for y in (0.35, 1.05, 1.75):
        b.cyl(1.5, 0.7, (0, 4.2, y), segs=8, swatch="gun_l", cap=False)
        b.cyl(1.2, 0.7, (0, 4.2, y), segs=8, swatch="gun", cap=False)
    R(b, -0.5, 0.5, 2.1, 2.3, 3.7, 4.7, "tan")
    for i in range(5):
        R(b, 2.6 + i * 0.3, 2.75 + i * 0.3, 0, 0.15, 2.6, 6.4, "gun_d")  # spare pickets


def callin_supply(b):
    """Speedball and Aid Bag: an ammunition bundle rigged to kick out of the door, and the
    medical bag with spare plates, side by side on a pallet."""
    R(b, -3.4, 3.4, 0, 0.5, -2.2, 2.2, "tan_d")
    R(b, -3.0, -0.4, 0.5, 2.5, -1.4, 1.4, "olive_d")  # the speedball
    for z in (-0.7, 0.7):
        R(b, -3.04, -0.36, 0.5, 2.54, z - 0.12, z + 0.12, "tan_l")
    R(b, -2.2, -1.2, 2.5, 2.9, -0.3, 0.3, "tan_l")
    R(b, -2.9, -2.1, 0.5, 1.4, 1.5, 2.1, "olive")  # ammo cans
    R(b, -1.9, -1.1, 0.5, 1.4, 1.5, 2.1, "olive")
    R(b, 0.6, 3.0, 0.5, 2.1, -1.2, 0.6, "tan")  # the aid bag
    R(b, 0.56, 3.04, 1.1, 1.5, -1.24, 0.64, "red")
    R(b, 1.4, 2.2, 2.1, 2.4, -0.6, 0.0, "tan_d")
    for i in range(3):
        rbc(b, (1.0 + i * 0.75, 1.3, 1.5), (0.18, 1.6, 1.2), "dark", rot=(0, 0, 0))  # plates


# ------------------------------------------------------------------ Easter eggs
def egg_cat(b):
    """The ship's cat asleep in an empty mortar-bomb crate, her bowl beside it."""
    R(b, -1.6, 1.6, 0, 1.2, -1.0, 1.0, "olive")
    R(b, -1.45, 1.45, 0.9, 1.22, -0.85, 0.85, "tan")  # a folded blanket
    R(b, -0.9, 0.7, 1.2, 1.75, -0.5, 0.5, "rust_l")  # the cat, curled
    R(b, -1.45, -0.75, 1.2, 1.95, -0.1, 0.7, "rust_l")  # head, chin on the blanket
    R(b, -1.5, -1.45, 1.25, 1.55, 0.1, 0.5, "white_l")  # muzzle
    for z in (0.05, 0.55):
        R(b, -1.4, -1.2, 1.95, 2.25, z - 0.12, z + 0.12, "rust")  # ears
        R(b, -1.5, -1.45, 1.66, 1.72, z - 0.1, z + 0.1, "dark_d")  # eyes, shut
    R(b, 0.6, 1.2, 1.2, 1.4, -0.75, 0.3, "rust")  # tail round her
    R(b, -0.2, 0.3, 1.74, 1.78, -0.5, 0.5, "rust")  # tabby bars
    R(b, 0.35, 0.55, 1.74, 1.78, -0.5, 0.5, "white_l")  # the white screening band, as a collar
    cyl_up(b, 2.4, 0, 0.3, 0.2, 0.5, "red", segs=8)
    cyl_up(b, 2.4, 0.3, 0.32, 0.2, 0.38, "tan_l", segs=8)


def egg_arcade(b):
    """An old arcade cabinet somebody carried aboard: dead screen, cracked glass, a paper sign."""
    R(b, -1.4, 1.4, 0, 3.0, -1.3, 1.3, "dark_d")
    R(b, -1.4, 1.4, 3.0, 6.6, -1.3, 0.3, "dark_d")
    rbc(b, (0, 3.3, 0.8), (2.8, 0.3, 1.4), "dark", rot=(-12, 0, 0))  # control panel
    cyl_up(b, -0.6, 3.4, 3.9, 0.9, 0.08, "gun_l", segs=6)
    b.ico(0.2, (-0.6, 0.9, 4.0), subdiv=1, swatch="red")
    for x in (0.3, 0.8):
        cyl_up(b, x, 3.3, 3.5, 0.9, 0.14, "objective_yellow", segs=6)
    rbc(b, (0, 4.9, 0.36), (2.3, 2.0, 0.1), "glass", rot=(-8, 0, 0))  # the screen
    rbc(b, (0.3, 4.9, 0.42), (0.05, 2.0, 0.04), "glass_l", rot=(-8, 0, 28))  # the crack
    rbc(b, (-0.2, 5.2, 0.42), (0.05, 1.2, 0.04), "glass_l", rot=(-8, 0, -40))
    R(b, -1.4, 1.4, 6.6, 7.6, -1.3, 0.6, "dark_d")  # marquee
    R(b, -1.2, 1.2, 6.75, 7.45, 0.6, 0.66, "paint_maroon")
    R(b, -0.9, 0.9, 6.95, 7.25, 0.66, 0.7, "objective_yellow")
    for s in (-1, 1):
        R(b, s * 1.4 - 0.03, s * 1.4 + 0.03, 0.6, 6.0, -0.9, 0.0, "paint_navy")  # side art
        R(b, s * 1.43 - 0.03, s * 1.43 + 0.03, 2.2, 3.0, -0.9, 0.0, "warning_orange")
    rbc(b, (0.1, 4.7, 0.52), (1.6, 0.9, 0.03), "white_l", rot=(-8, 0, 6))  # OUT OF ORDER
    R(b, -0.3, 0.3, 1.2, 1.6, 1.3, 1.34, "gun_d")  # coin door
    R(b, 1.6, 2.6, 0, 1.2, -0.6, 0.4, "tan_d")  # a stool-crate, with a coin jar
    cyl_up(b, 2.1, 1.2, 1.9, -0.1, 0.3, "glass_l", segs=6)


def egg_memorial(b):
    """The net: a cargo net on the bulkhead hung with the wrist bands, helmets and tags of seats
    that did not come home (chemlights are Parts). Origin on the wall, 16 wide along z."""
    for i in range(9):
        z = -8 + i * 2
        R(b, 0.1, 0.22, 2.0, 12.0, z - 0.06, z + 0.06, "tan_l")
    for j in range(6):
        y = 2.0 + j * 2
        R(b, 0.1, 0.22, y - 0.06, y + 0.06, -8, 8, "tan_l")
    R(b, 0, 0.5, 12.0, 12.4, -8.4, 8.4, "gun_d")
    k = 0
    for j in range(5):
        for i in range(8):
            k += 1
            if (k * 7) % 5 == 0:
                continue
            z, y = -7 + i * 2 + ((j % 2) * 0.5 - 0.25), 3.0 + j * 2
            R(b, 0.22, 0.34, y - 0.5, y, z - 0.22, z + 0.22, "white_l")  # a band
            if k % 3 == 0:
                R(b, 0.34, 0.37, y - 0.33, y - 0.2, z - 0.22, z + 0.22, "objective_yellow")
            if k % 4 == 0:
                R(b, 0.22, 0.3, y - 1.1, y - 0.5, z - 0.1, z + 0.1, "gun_l")  # a tag under it
    for z, y in ((-5, 11.0), (1, 11.0), (6, 9.0)):
        b.ico(0.75, (0.8, z, y), subdiv=1, swatch="dark")
        R(b, 0.2, 0.9, y + 0.5, y + 0.62, z - 0.05, z + 0.05, "gun_d")  # its hook
    R(b, 0, 1.4, 0, 0.9, -5, 5, "gun_d")  # a shelf: a boot, a mug
    R(b, 0.3, 1.2, 0.9, 1.9, 2.0, 2.6, "dark")
    cyl_up(b, 0.8, 0.9, 1.4, -2.4, 0.22, "white", segs=6)


def egg_scoreboard(b):
    """The districts' tally board: a painted steel sheet, five rows, chalk strokes in fives.
    (Row names are lettering in carrier_v2 / a SurfaceGui in game.) Origin on the wall."""
    R(b, 0, 0.2, 0, 8.4, -5.6, 5.6, "dark_d")
    R(b, 0.2, 0.26, 7.0, 7.1, -5.3, 5.3, "white_d")
    counts = (11, 6, 4, 2, 0)
    for r, n in enumerate(counts):
        y = 5.9 - r * 1.25
        R(b, 0.2, 0.24, y - 0.42, y - 0.38, -5.3, 5.3, "dark_l")
        for i in range(n):
            g, m = divmod(i, 5)
            z = 0.2 + g * 1.5 + m * 0.24
            if m == 4:
                rbc(b, (0.23, y + 0.15, 0.2 + g * 1.5 + 0.4), (0.04, 0.9, 0.08), "white_l", rot=(60, 0, 0))
            else:
                R(b, 0.2, 0.25, y - 0.2, y + 0.5, z - 0.04, z + 0.04, "white_l")
    R(b, 0.2, 1.0, 0.0, 0.2, -5.6, 5.6, "gun_d")  # chalk ledge
    R(b, 0.4, 0.8, 0.2, 0.35, -1.0, -0.2, "white_l")


def egg_hoop(b):
    """A basketball hoop welded to the bulkhead, the ball in a net bag lashed beside it."""
    R(b, 0, 0.5, 10.4, 11.0, -0.2, 0.2, "gun_d")
    R(b, 0.5, 0.7, 9.0, 12.6, -3.0, 3.0, "white")
    R(b, 0.7, 0.74, 9.6, 11.2, -1.0, 1.0, "red")
    R(b, 0.74, 0.78, 9.8, 11.0, -0.8, 0.8, "white")
    b.cyl(0.95, 0.12, (1.75, 0, 9.7), segs=8, swatch="warning_orange", cap=False)
    b.cyl(0.9, 1.3, (1.75, 0, 9.0), segs=8, r2=0.6, swatch="white_l", cap=False)
    b.ico(0.6, (0.9, 4.2, 4.2), subdiv=1, swatch="warning_orange")
    R(b, 0, 0.3, 4.8, 5.4, 4.1, 4.3, "gun_d")
    R(b, 0.5, 0.6, 4.6, 5.0, 4.15, 4.25, "tan_l")


def egg_lookout(b):
    """The lookout's post: big deck binoculars on a pedestal (looking along +x), a folding chair,
    a flask, and the log board where the towers are crossed off as they go."""
    cyl_up(b, 0, 0, 4.0, 0, 0.35, "gun_d")
    cyl_up(b, 0, 0, 0.3, 0, 0.9, "dark_d")
    R(b, -0.4, 0.4, 4.0, 4.5, -0.9, 0.9, "gun_d")
    for z in (-0.5, 0.5):
        cyl_x(b, -1.2, 2.0, 5.0, z, 0.42, "gun")
        cyl_x(b, 2.0, 2.2, 5.0, z, 0.5, "glass_l")
        cyl_x(b, -1.5, -1.2, 5.0, z, 0.25, "dark_d", segs=6)
    R(b, -0.3, 0.3, 4.5, 5.0, -0.2, 0.2, "gun_d")
    # the chair
    for x in (-3.6, -2.2):
        for z in (1.6, 2.8):
            R(b, x - 0.06, x + 0.06, 0, 1.7, z - 0.06, z + 0.06, "gun_l")
    R(b, -3.7, -2.1, 1.7, 1.85, 1.5, 2.9, "olive_d")
    R(b, -3.75, -3.6, 1.85, 3.6, 1.5, 2.9, "olive_d")
    cyl_up(b, -1.6, 0, 1.1, 2.6, 0.25, "olive", segs=6)  # the flask
    cyl_up(b, -1.6, 1.1, 1.3, 2.6, 0.18, "white_d", segs=6)
    # the log board on an easel, facing the chair (-x): a drawn skyline, towers crossed off
    for z in (-4.6, -1.8):
        rod(b, (0.2, 0, z), (0.9, 5.2, z), 0.14, "tan_d")
    rbc(b, (0.5, 3.6, -3.2), (0.12, 2.8, 3.6), "white_l", rot=(0, -8, 0))
    hs = (0.9, 1.5, 0.7, 1.9, 1.2, 0.6, 1.6, 1.0)
    for i, h in enumerate(hs):
        z = -4.7 + i * 0.4
        y0 = 2.5
        x = 0.38 + (y0 + h / 2 - 3.6) * 0.14
        R(b, x - 0.05, x - 0.01, y0, y0 + h, z, z + 0.3, "dark")
        if i in (1, 3, 6):  # gone: crossed through in red
            rbc(b, (x - 0.07, y0 + h / 2, z + 0.15), (0.03, h * 1.1, 0.07), "red", rot=(25, 0, 0))
            rbc(b, (x - 0.07, y0 + h / 2, z + 0.15), (0.03, h * 1.1, 0.07), "red", rot=(-25, 0, 0))
    R(b, 0.3, 0.36, 4.55, 4.75, -4.6, -2.0, "dark")  # a line of writing


def egg_roadsign(b):
    """A highway distance sign taken off its posts and bolted to the bulkhead; origin on the wall."""
    R(b, 0, 0.12, 0, 3.2, -4.2, 4.2, "olive_d")
    for y in (0.15, 3.0):
        R(b, 0.12, 0.15, y, y + 0.08, -4.0, 4.0, "white_l")
    for z in (-4.05, 3.97):
        R(b, 0.12, 0.15, 0.15, 3.08, z, z + 0.08, "white_l")
    for z in (-3.6, 3.6):
        for y in (0.5, 2.7):
            R(b, 0.12, 0.2, y - 0.1, y + 0.1, z - 0.1, z + 0.1, "gun_l")
    R(b, 0.12, 0.14, 0.2, 0.9, 1.6, 3.4, "rust")  # a dent and a scrape of rust


def egg_notissue(b):
    """NOT ON ISSUE: the shelf of things soldiers brought back and may not sign for: a bat with
    nails, a crossbow, a chainsaw. Origin on the wall (the cage's mesh side), +x into the cage."""
    R(b, 0, 2.0, 5.0, 5.2, -4, 4, "gun_d")
    for z in (-3.8, 3.8):
        rod(b, (0, 3.6, z), (1.9, 5.0, z), 0.14, "gun_d")
    rbc(b, (1.0, 5.45, -2.6), (0.3, 0.3, 2.6), "tan", rot=(0, 0, 8))  # bat
    for i in range(4):
        rbc(b, (1.0, 5.5, -1.8 + i * 0.22 - 0.3), (0.7, 0.05, 0.05), "gun_l", rot=(0, i * 40, 0))
    R(b, 0.4, 1.6, 5.2, 5.5, 0.9, 1.1, "tan_d")  # crossbow stock
    R(b, 0.9, 1.1, 5.2, 5.45, -0.2, 2.2, "dark")
    rbc(b, (1.0, 5.45, 2.1), (2.2, 0.12, 0.12), "gun_d", rot=(0, 0, 0))
    R(b, 0.5, 1.5, 5.2, 6.0, 2.9, 3.7, "warning_orange")  # chainsaw
    R(b, 0.9, 1.1, 5.35, 5.75, 3.7, 5.3, "gun_l")
    R(b, 0.7, 1.3, 6.0, 6.2, 3.0, 3.6, "dark_d")
    R(b, 2.0, 2.06, 4.2, 5.0, -1.6, 1.6, "red")  # the tag board hung off the shelf's lip


def egg_clocks(b):
    """Two clocks on the map room wall: SHIP runs; the other stopped the night the city fell."""
    for z, hands in ((-1.6, ((0.7, 40), (0.5, 150))), (1.6, ((0.7, -62), (0.5, 96)))):
        b.cyl(1.1, 0.25, (0.12, z, 2.0), segs=8, rot=(0, 90, 0), swatch="gun_d")
        b.cyl(0.95, 0.27, (0.13, z, 2.0), segs=8, rot=(0, 90, 0), swatch="white_l")
        for ln, ang in hands:
            a = math.radians(ang)
            rod(b, (0.3, 2.0, z), (0.3, 2.0 + math.cos(a) * ln, z + math.sin(a) * ln), 0.07, "dark_d")
    R(b, 0.02, 0.1, 0.2, 0.7, -2.5, -0.7, "white")
    R(b, 0.02, 0.1, 0.2, 0.7, 0.7, 2.5, "white")
    rbc(b, (0.3, 2.0, 1.6), (0.04, 0.08, 2.0), "red_d", rot=(40, 0, 0))  # tape across the stopped one


def egg_dayssign(b):
    """The count board by the screening lane: a safety-sign frame with three number tiles on
    hooks (lettering in carrier_v2 / SurfaceGui in game). Free-standing, faces +x."""
    for z in (-3.6, 3.6):
        R(b, -0.15, 0.15, 0, 7.6, z - 0.15, z + 0.15, "gun_d")
        R(b, -0.7, 0.7, 0, 0.2, z - 0.4, z + 0.4, "dark_d")
    R(b, -0.1, 0.1, 2.6, 7.4, -3.6, 3.6, "white_l")
    R(b, 0.1, 0.14, 6.3, 7.3, -3.5, 3.5, "olive_d")
    for i in range(3):
        z = -1.5 + i * 1.5
        R(b, 0.1, 0.2, 3.0, 4.8, z - 0.6, z + 0.6, "dark_d")
        R(b, 0.2, 0.26, 4.8, 4.95, z - 0.1, z + 0.1, "gun_l")


def egg_queen_marks(b):
    """What the hangar queen brought back, in the helicopter's own frame: hand marks dragged along
    the tail boom at shoulder height and a dented skid; a red DO NOT ROB tag on the nose."""
    for i in range(7):
        z = -9.0 - i * 1.5
        y = 6.6 + (i % 3) * 0.25
        for k in range(3):
            rbc(b, (0.72, y - k * 0.14, z - k * 0.1), (0.05, 0.07, 1.1 - k * 0.2), "rust_d", rot=(-6, 0, 0))
    R(b, 2.9, 3.3, 0.5, 0.8, -1.4, 0.4, "rust")
    R(b, -0.6, 0.6, 3.6, 4.6, 9.9, 9.96, "red")


def decon(b):
    """The screening lane's wash-down frame and its bins (stern, deck edge)."""
    for x in (-3.4, 3.4):
        R(b, x - 0.12, x + 0.12, 0, 8, -0.12, 0.12, "gun_l")
    R(b, -3.4, 3.4, 7.9, 8.1, -0.12, 0.12, "gun_l")
    for x in (-2, 0, 2):
        cyl_up(b, x, 7.3, 7.9, 0, 0.25, "white_d", segs=6)
    R(b, -3.5, -3.3, 0, 7, 0.2, 5.0, "white")  # canvas screen
    for x, sw in ((5.0, "objective_yellow"), (7.0, "objective_yellow"), (9.0, "red")):
        cyl_up(b, x, 0, 2.8, 2.0, 0.9, sw)
        cyl_up(b, x, 2.8, 3.0, 2.0, 0.95, "dark_d")


# ------------------------------------------------------------------ the shore
def shore_card(b, seed=1, width=420.0, low=40.0, high=190.0, broken=0.35):
    """A flat strip of far skyline: tower outlines side by side, some snapped off at an angle.
    One-sided, facing +x; origin at the shoreline, the strip along z. ~2 tris a tower."""
    import random

    rnd = random.Random(seed)
    z = -width / 2
    while z < width / 2:
        w = rnd.uniform(14, 34)
        h = rnd.uniform(low, high) * (1.0 if rnd.random() < 0.3 else 0.55)
        z1 = min(z + w, width / 2)
        if rnd.random() < broken:
            cut = rnd.uniform(0.55, 0.85) * h
            vs = [b.bm.verts.new(p) for p in ((0, z, 0), (0, z1, 0), (0, z1, cut), (0, z, h))]
            if rnd.random() < 0.5:
                vs[2].co.z, vs[3].co.z = h, cut
        else:
            vs = [b.bm.verts.new(p) for p in ((0, z, 0), (0, z1, 0), (0, z1, h), (0, z, h))]
            if w > 24 and rnd.random() < 0.6:  # a setback top
                m0, m1 = z + w * 0.25, z + w * 0.7
                ts = [b.bm.verts.new(p) for p in ((0, m0, h), (0, m1, h), (0, m1, h * 1.22), (0, m0, h * 1.22))]
                b._paint_faces([b.bm.faces.new(ts)], "dark")
        b._paint_faces([b.bm.faces.new(vs)], "dark")
        z = z1 + (rnd.uniform(1, 9) if rnd.random() < 0.6 else 0)


def waterfront(b):
    """A 300-stud run of the city's waterfront, facing +x (the sea): the quay wall, sheds, a
    gantry crane standing and one down across the quay, a pier, a ferry aground and listing."""
    R(b, -80, 0, -6, 6, -150, 150, "concrete_d")  # quay
    R(b, 0, 0.6, 2.5, 5.2, -150, 150, "dark_d")  # fender line
    for z0, z1, h, d, sw in ((-140, -86, 22, 44, "concrete"), (-70, -22, 30, 50, "rust_d"), (30, 74, 18, 40, "concrete_d"), (92, 146, 26, 46, "tan_d")):
        R(b, -14 - d, -14, 6, 6 + h, z0, z1, sw)
        b.wedge((d, z1 - z0, 7), (-14 - d / 2, (z0 + z1) / 2, 6 + h + 3.5), swatch="dark")  # shed roof
        for i in range(int((z1 - z0) // 12)):
            R(b, -14, -13.8, 8, 6 + h * 0.6, z0 + 4 + i * 12, z0 + 10 + i * 12, "dark_d")  # doors
    # the standing gantry crane
    for x in (-10, -30):
        for z in (-12, 12):
            R(b, x - 1.2, x + 1.2, 6, 62, z - 1.2, z + 1.2, "rust")
    R(b, -32, -8, 60, 66, -14, 14, "rust")
    R(b, -44, 46, 66, 71, -3, 3, "rust")  # boom out over the water
    rod(b, (-20, 96, 0), (40, 71, 0), 0.8, "dark_d")
    rod(b, (-20, 96, 0), (-44, 71, 0), 0.8, "dark_d")
    R(b, -21.5, -18.5, 66, 96, -1.5, 1.5, "rust")
    R(b, 28, 31, 40, 66, -0.4, 0.4, "dark_d")
    # the fallen one, across the quay
    rbc(b, (-34, 12, 100), (5, 5, 96), "rust_d", rot=(0, 8, 24))
    rbc(b, (-20, 9, 72), (26, 6, 6), "rust_d", rot=(0, -6, 24))
    # a pier, half burnt through
    R(b, 0, 60, 2, 4, -112, -100, "concrete_d")
    R(b, 74, 96, 1.5, 3.5, -113, -99, "dark_d")
    for x in (10, 30, 50, 84):
        R(b, x - 1, x + 1, -6, 2, -107, -105, "dark_d")
    # the ferry, aground by the stern, listing
    rbc(b, (44, 9, 96), (26, 18, 110), "paint_navy", rot=(0, 9, -11))
    rbc(b, (41, 21, 92), (20, 9, 78), "white", rot=(0, 9, -11))
    rbc(b, (39, 28, 84), (14, 6, 30), "white_d", rot=(0, 9, -11))
    rbc(b, (38, 35, 74), (6, 9, 8), "red_d", rot=(0, 9, -11))  # funnel
    rbc(b, (47.5, 2, 96), (26.4, 6, 110.4), "dark_d", rot=(0, 9, -11))  # boot-top and soot
    rbc(b, (52, 21, 110), (0.6, 7, 40), "dark_d", rot=(0, 9, -11))  # burnt-out window band


# ------------------------------------------------------------------ registration
KIT = {
    "env_carrier_rib": rib,
    "env_carrier_pipes": pipes,
    "env_carrier_door": door,
    "env_carrier_firestation": firestation,
    "env_carrier_ramp_trim": ramp_trim,
    "env_carrier_deck_rail": deck_rail,
    "env_carrier_floodmast": floodmast,
    "env_carrier_tiedown": tiedown,
    "env_carrier_chock": chock,
    "env_carrier_island_kit": island_kit,
    "env_carrier_ship_crane": ship_crane,
    "env_carrier_boat": boat,
    "env_carrier_decon": decon,
    "veh_carrier_tractor": tractor,
    "veh_carrier_crash_crane": crash_crane,
    "prop_carrier_toolchest": toolchest,
    "prop_carrier_pallet_net": pallet_net,
    "prop_carrier_crates": crates,
    "prop_carrier_drums": drums,
    "prop_carrier_engine_stand": engine_stand,
    "prop_carrier_blade_rack": blade_rack,
    "prop_carrier_jack": jack,
    "prop_carrier_hoist": hoist,
    "prop_carrier_scale_cases": scale_cases,
    "prop_carrier_console": console,
    "prop_carrier_kitshelf": kitshelf,
    "prop_carrier_ammo_stack": ammo_stack,
    "prop_carrier_crew_corner": crew_corner,
    "prop_carrier_placard": placard,
    "prop_callin_hammer": callin_hammer,
    "prop_callin_anvil": callin_anvil,
    "prop_callin_shrike": callin_shrike,
    "prop_callin_tripline": callin_tripline,
    "prop_callin_concertina": callin_concertina,
    "prop_callin_supply": callin_supply,
    "egg_carrier_cat": egg_cat,
    "egg_carrier_arcade": egg_arcade,
    "egg_carrier_memorial": egg_memorial,
    "egg_carrier_scoreboard": egg_scoreboard,
    "egg_carrier_hoop": egg_hoop,
    "egg_carrier_lookout": egg_lookout,
    "egg_carrier_roadsign": egg_roadsign,
    "egg_carrier_notissue": egg_notissue,
    "egg_carrier_clocks": egg_clocks,
    "egg_carrier_dayssign": egg_dayssign,
    "egg_carrier_queen_marks": egg_queen_marks,
    "env_shore_card_a": lambda b: shore_card(b, seed=3),
    "env_shore_card_b": lambda b: shore_card(b, seed=11, low=60, high=240, broken=0.45),
    "env_shore_card_c": lambda b: shore_card(b, seed=29, low=30, high=150, broken=0.25),
    "env_shore_waterfront": waterfront,
}
NAMES = tuple(KIT)


def register(ba):
    """Adds the kit to build_assets' ASSETS table (collection "Fallow": the z-fight pass and the
    export mirror apply, as for the ship's other meshes). Pivot "ship": no re-seat."""
    for name, fn in KIT.items():
        ba.ASSETS[name] = (fn, "Fallow", "ship")
