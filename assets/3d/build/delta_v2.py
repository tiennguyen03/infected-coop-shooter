"""Checkpoint Delta v2 in Blender: a PROPOSAL the owner looks at before anything goes in the game.

Owner, 2026-11-11: "it kind of just feels like an open field with stuff. I think it still lacks
verticality, like the buildings are all one story... some of the car models are simple, but some
of them were more complex." Nothing here is loaded by the game. docs/sprints/DELTA_V2.md has the
diagnosis, the layout table and the step list.

The place: an army checkpoint on the highway out of the city. South to north along the highway
(x = 0): the outer barricade and the city, the Approach (the jam, the Screening Lot and the Pens
west, the Bus Park east), the Gate (a wall across the whole map, the Gatehouse over the road),
the Yard, then the base: Barracks, Command Post and the Mast west; the Motor Pool deck, the
Depot stacks, the Shed and the generator yard east; the helicopter apron north-west; a service
bridge over the highway joining the two halves at level 12; a drainage channel (level -6) down
the east side.

Shape: Python tables in Roblox coordinates (x east, y up, z north), like mile14_v2.py. Buildings
and ground are plain Parts (`PARTS`, written by the small kit in "the Part kit" below: walls with
door and window openings, slabs with stair holes, 33-degree flights), everything else is a kit
mesh placed as a linked instance (`DRESSING`). In this file `yaw` is counter-clockwise seen on the
map and a mesh's local +X points along it (vehicles: `V()` takes the way the nose points).

Live Blender (the owner's way: look at it), in a scene of its own named Delta_v2:
    exec(open(r"assets/3d/build/delta_v2.py").read()); build(); build_today()
Headless (writes assets/3d/delta_v2.blend and build/previews/delta_v2_*.png):
    blender --background --python assets/3d/build/delta_v2.py
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_assets as ba  # noqa: E402
import delta_kit  # noqa: E402
import delta_map as dm  # noqa: E402

delta_kit.register(ba)

BLEND = os.path.join(dm.ROOT, "assets", "3d", "delta_v2.blend")
PREVIEWS = os.path.join(dm.ROOT, "assets", "3d", "build", "previews")
SCENE = "Delta_v2"
HALF = 300.0  # the play frame is 600 x 600, the same as today
EYE = 5.0
T33 = math.tan(math.radians(33))  # the kit's stair and ramp angle
GATE_Z = -112.0  # the Gate line
DECK = 12.0  # the Gatehouse walk, the service bridge and the Motor Pool deck share one level
CH_X0, CH_X1, CH_Y = 262.0, 278.0, -6.0  # the drainage channel
TOP = 9.55  # a container's roof

# ------------------------------------------------------------------ what the objectives need
# (docs/PROGRESSION.md "Objective pools"): the same names as today, moved. (x, y, z).
SITES = {
    "Site 1: the Compound": ((-104, 0, 26), (46, 46)),
    "Site 2: the Pens": ((-214, 0, -204), (46, 46)),
    "Site 3: the Overlook": ((104, DECK, 20), (28, 28)),
}
PADS = {"Main pad (insert, extract)": (-190, 0, 200), "Alt pad (Light the Pad)": (150, 0, 216)}
POINTS = {  # objective props and story spots
    "Open the Route: Gate lane": (0, 0, GATE_Z),
    "Warden spawn": (10, 0, -292),
    "Siren (Silence the Alarm)": (23, 21, -106),
    "Bus 7 (Sealed Bus)": (-11, 0, -166),
    "Generator (Lights On)": (84, 0, 92),
    "Comm mast (Restore Comms, Record B)": (-80, 9, 112),
    "Record A / Recover Logs: Screening Block": (-78, 9, -226),
    "Sanitize: three tents": (-236, 0, -204),
    "Confirm Casualties: the stacks": (202, 0, -40),
    "Stores 1": (182, 0, -30), "Stores 2": (-208, 0, -50), "Stores 3": (200, 0, 100), "Stores 4": (-23, 0, -96),
    "Misdrop SW": (-270, 0, -276), "Misdrop SE": (240, 0, -270), "Misdrop NE": (250, 0, 250),
}
ENTRIES = {  # where the Infected come in
    "E1 city road": (0, -296), "E2 south-west wall": (-292, -230), "E3 culvert": (270, -268),
    "E4 north gate": (0, 292), "E5 west breach": (-292, 104), "E6 east breach": (292, 176),
}
LABELS = {  # names for the top-down (x, z)
    "THE GATE": (0, -96), "The Approach": (-4, -262), "Screening Lot": (-84, -150), "The Pens": (-214, -252),
    "Screening Block": (-78, -246), "The Rows": (-128, -272), "Bus Park": (84, -272), "Inspection Bay": (176, -136),
    "Impound": (190, -262), "The Yard": (0, -40), "Barracks": (-208, -98), "Command Post": (-80, 86),
    "The Mast": (-80, 132), "Flight Ops": (-119, 141), "LZ apron": (-190, 250), "Service bridge": (0, 36),
    "Tent Lines": (-210, 121), "Parade square": (-206, 42), "Casualty point": (-62, 244), "Fuel point": (62, 246),
    "Burn pit": (268, 254), "Workshop": (112, -40),
    "Motor Pool deck": (104, 54), "The Stacks": (204, -22), "The Shed": (201, 126), "Loading dock": (201, 52),
    "Generator yard": (84, 136), "Depot apron": (150, 250), "Channel (-6)": (270, 10), "North gate": (0, 276),
    "Armoury": (-124, -84), "CITY v": (120, -330), "to Mile 14 ^": (60, 330),
}

# ------------------------------------------------------------------ the Part kit
PARTS = []  # (group, kind, "box" | "wedge", (x0, x1, y0, y1, z0, z1), up)


def B(g, kind, x0, x1, y0, y1, z0, z1):
    if x1 - x0 > 0.01 and y1 - y0 > 0.01 and z1 - z0 > 0.01:
        PARTS.append((g, kind, "box", (x0, x1, y0, y1, z0, z1), None))


def W(g, kind, x0, x1, y0, y1, z0, z1, up):
    """A WedgePart filling the box, its top rising toward `up` (+x, -x, +z, -z)."""
    PARTS.append((g, kind, "wedge", (x0, x1, y0, y1, z0, z1), up))


def wall(g, kind, axis, at, a0, a1, y0, y1, t=1.0, openings=()):
    """A wall along `axis` ("x": at z = `at`; "z": at x = `at`) from a0 to a1, with openings
    (centre, width, sill, head): heights above y0, head None = open to the top."""

    def seg(u0, u1, v0, v1):
        if axis == "x":
            B(g, kind, u0, u1, v0, v1, at - t / 2, at + t / 2)
        else:
            B(g, kind, at - t / 2, at + t / 2, v0, v1, u0, u1)

    cur = a0
    for c, w, sill, head in sorted(openings):
        o0, o1 = max(a0, c - w / 2), min(a1, c + w / 2)
        seg(cur, o0, y0, y1)
        if sill > 0:
            seg(o0, o1, y0, y0 + sill)
        if head is not None and y0 + head < y1:
            seg(o0, o1, y0 + head, y1)
        cur = o1
    seg(cur, a1, y0, y1)


def slab(g, kind, x0, x1, z0, z1, y0, y1, hole=None):
    if hole is None:
        return B(g, kind, x0, x1, y0, y1, z0, z1)
    hx0, hx1, hz0, hz1 = hole
    B(g, kind, x0, x1, y0, y1, z0, hz0)
    B(g, kind, x0, x1, y0, y1, hz1, z1)
    B(g, kind, x0, hx0, y0, y1, hz0, hz1)
    B(g, kind, hx1, x1, y0, y1, hz0, hz1)


BUILDINGS = {}  # name -> (x0, x1, z0, z1, levels): for the doc and the overview


def building(g, x0, x1, z0, z1, heights, kind="block", base=0.0, doors=(), stairs=(), win=True, blank=(), t=1.0, parapet=1.2):
    """A kit building (docs/LEVELS.md B1): storeys of `heights`, a window every ~9 studs (5 wide,
    sill 3.2, head 8.6), doors (side, storey, centre along the wall, width, height), inside
    flights (storey, wall it hugs, low end along the wall, +1 | -1) each cutting its hole in the
    slab above, a roof with a parapet. `blank` = {(side, storey)} with no windows."""
    floors = [base]
    for h in heights:
        floors.append(floors[-1] + h)
    BUILDINGS[g] = (x0, x1, z0, z1, floors)
    sides = {"S": ("x", z0 + t / 2, x0, x1), "N": ("x", z1 - t / 2, x0, x1), "W": ("z", x0 + t / 2, z0 + t, z1 - t), "E": ("z", x1 - t / 2, z0 + t, z1 - t)}
    for k, h in enumerate(heights):
        for side, (axis, at, a0, a1) in sides.items():
            ops = [(c, w, 0.0, hh) for (s, kk, c, w, hh) in doors if s == side and kk == k]
            if win and (side, k) not in blank:
                n = max(1, int((a1 - a0 - 4) // 9))
                for i in range(n):
                    c = a0 + (i + 0.5) * (a1 - a0) / n
                    if all(abs(c - o[0]) > (o[1] + 5) / 2 + 1.0 for o in ops):
                        ops.append((c, 5.0, 3.2, min(8.6, h - 1.2)))
            wall(g, kind, axis, at, a0, a1, floors[k], floors[k + 1], t, ops)
    holes = {}
    for k, hug, low, sgn in stairs:
        h = heights[k]
        run = h / T33
        a0, a1 = sorted((low, low + sgn * run))
        hole0, hole1 = sorted((low + sgn * 4.0, low + sgn * run))
        up = ("+" if sgn > 0 else "-") + ("x" if hug in "NS" else "z")
        if hug in "NS":
            zz = (z1 - t - 5.0, z1 - t) if hug == "N" else (z0 + t, z0 + t + 5.0)
            W(g, "stair", a0, a1, floors[k], floors[k + 1], zz[0], zz[1], up)
            holes[k + 1] = (hole0, hole1, zz[0], zz[1])
        else:
            xx = (x1 - t - 5.0, x1 - t) if hug == "E" else (x0 + t, x0 + t + 5.0)
            W(g, "stair", xx[0], xx[1], floors[k], floors[k + 1], a0, a1, up)
            holes[k + 1] = (xx[0], xx[1], hole0, hole1)
    for k in range(1, len(floors)):
        top = k == len(floors) - 1
        e = 0.4 if top else -t  # the roof overhangs as eaves, a floor stops inside the walls
        slab(g, "roof" if top else "slab", x0 - e, x1 + e, z0 - e, z1 + e, floors[k] - 0.6, floors[k], holes.get(k))
    y = floors[-1]
    if parapet:
        B(g, kind, x0, x1, y, y + parapet, z0, z0 + 0.6)
        B(g, kind, x0, x1, y, y + parapet, z1 - 0.6, z1)
        B(g, kind, x0, x0 + 0.6, y, y + parapet, z0 + 0.6, z1 - 0.6)
        B(g, kind, x1 - 0.6, x1, y, y + parapet, z0 + 0.6, z1 - 0.6)
    return floors


def ladder(g, x, z, y0, y1, axis="x"):
    """A ladder (TrussPart in game: the squad climbs, the Infected do not)."""
    if axis == "x":
        B(g, "steel", x - 1.0, x + 1.0, y0, y1, z - 0.2, z + 0.2)
    else:
        B(g, "steel", x - 0.2, x + 0.2, y0, y1, z - 1.0, z + 1.0)


# ------------------------------------------------------------------ instances
DRESSING = []  # {"name", "x", "z", "yaw", "y", "roll", "scale", "layer"}


def D(name, x, z, yaw=0.0, y=0.0, roll=0.0, scale=None, layer="play"):
    DRESSING.append({"name": name, "x": x, "z": z, "yaw": yaw, "y": y, "roll": roll, "scale": scale, "layer": layer})


def V(name, x, z, heading, y=0.0, layer="play"):
    """A vehicle whose nose points along `heading` (0 east, 90 north)."""
    D(name, x, z, heading + 180.0, y, layer=layer)


def row(name, x, z, n, step, axis="x", yaw=None, y=0.0, layer="play"):
    """n pieces centred on (x, z), `step` apart along `axis`."""
    for i in range(n):
        o = (i - (n - 1) / 2) * step
        D(name, x + (o if axis == "x" else 0), z + (o if axis == "z" else 0), (0.0 if axis == "x" else 90.0) if yaw is None else yaw, y, layer=layer)


# ------------------------------------------------------------------ the layout
HOLES = (  # cut out of the ground slab (x0, x1, z0, z1): the low ground
    (CH_X0, CH_X1, -262, 136),  # the drainage channel and its north ramp
    (CH_X0 - 18, CH_X0, -200, -182),  # side ramp: Bus Park
    (CH_X0 - 18, CH_X0, -10, 8),  # side ramp: the Stacks
    (184, 218, 44, 84),  # the Shed's loading dock and the ramp into it
)


def ground_slab(g, kind, x0, x1, z0, z1, y0, y1, holes):
    """A slab with rectangular holes, as the fewest boxes a grid cut gives."""
    xs = sorted({x0, x1} | {v for h in holes for v in h[:2]})
    zs = sorted({z0, z1} | {v for h in holes for v in h[2:]})
    for i in range(len(xs) - 1):
        start = None
        for j in range(len(zs)):
            solid = j < len(zs) - 1 and not any(
                h[0] < (xs[i] + xs[i + 1]) / 2 < h[1] and h[2] < (zs[j] + zs[j + 1]) / 2 < h[3] for h in holes
            )
            if solid and start is None:
                start = zs[j]
            if not solid and start is not None:
                B(g, kind, xs[i], xs[i + 1], y0, y1, start, zs[j])
                start = None


def _ground():
    g = "Ground"
    far = 2600.0
    ground_slab(g, "dust", -far, far, -far, far, -8, 0, HOLES)  # 8 thick: the cuts show its own sides
    # the drainage channel: floor at -6, three ramps a Walker can use, a culvert (E3)
    B(g, "concrete_d", CH_X0, CH_X1, CH_Y - 1, CH_Y, -262, 118)
    W(g, "concrete_d", CH_X0, CH_X1, CH_Y, 0, 118, 136, "+z")  # north ramp
    for z0 in (-200, -10):  # two side ramps up to the west (the Bus Park, the Stacks)
        W(g, "concrete_d", CH_X0 - 18, CH_X0, CH_Y, 0, z0, z0 + 18, "-x")
    B(g, "dark", CH_X0 + 3, CH_X1 - 3, CH_Y, -1.0, -262, -261.8)  # the culvert mouth
    B(g, "concrete", CH_X0, CH_X1, -1.0, 0.0, GATE_Z - 5, GATE_Z + 5)  # the Gate wall crosses on a slab (5 clear under)
    B(g, "concrete_d", 184, 218, -5, -4, 58, 84)  # the loading dock: a pit at -4
    W(g, "concrete_d", 184, 218, -4, 0, 44, 58, "-z")  # the ramp into it
    for z in (-56, 64):  # two foot bridges over the channel
        B(g, "plank", CH_X0 - 1, CH_X1 + 1, -0.4, 0.05, z - 3, z + 3)

    g = "Roads"
    B(g, "road", -18, 18, 0, 0.2, -900, 1000)  # the highway: the spine
    for x in (-17.2, 17.2):
        B(g, "line", x - 0.3, x + 0.3, 0.2, 0.26, -300, 300)
    B(g, "line", -0.9, -0.4, 0.2, 0.26, -300, 300)
    B(g, "line", 0.4, 0.9, 0.2, 0.26, -300, 300)
    for z in range(-290, 300, 20):
        if abs(z - GATE_Z) > 16:
            for x in (-10, 10):
                B(g, "line", x - 0.25, x + 0.25, 0.2, 0.26, z, z + 8)
    for k in range(4):  # STOP bars at the Gate
        B(g, "line", -17, 17, 0.2, 0.26, GATE_Z - 30 - 3 * k, GATE_Z - 29 - 3 * k)
    # the Approach
    B(g, "concrete", -152, -19, 0, 0.12, -284, -122)  # Screening Lot
    B(g, "mud", -264, -160, 0, 0.08, -262, -146)  # the Pens: trodden earth
    B(g, "road", 19, 250, 0, 0.1, -284, -122)  # Bus Park and Impound
    for x in range(50, 112, 18):
        B(g, "line", x - 9.2, x - 8.8, 0.1, 0.16, -272, -178)  # coach bays
    for x in range(132, 240, 11):
        for z0 in (-272, -232):
            B(g, "line", x - 0.2, x + 0.2, 0.1, 0.16, z0, z0 + 18)  # car bays
    # inside the Gate
    B(g, "concrete", -72, 72, 0, 0.14, GATE_Z + 4, -18)  # the Yard
    B(g, "concrete", -250, -166, 0, 0.1, -86, -14)  # Barracks court
    B(g, "concrete", -132, -50, 0, 0.12, 4, 132)  # Command Post pad
    B(g, "road", -72, -19, 0, 0.1, 12, 30)  # the bridge's west run-out
    B(g, "concrete", -264, -104, 0, 0.16, 136, 264)  # LZ apron
    B(g, "pad", -210, -170, 0.16, 0.4, 180, 220)  # the main pad
    B(g, "road", 40, 154, 0, 0.12, -24, 66)  # Motor Pool, under and round the deck
    B(g, "concrete", 158, 250, 0, 0.12, -100, 44)  # the Stacks
    B(g, "concrete", 166, 236, 0, 0.12, 124, 132)  # the Shed's back apron
    B(g, "concrete", 44, 124, 0, 0.12, 78, 138)  # generator yard
    B(g, "concrete", 96, 204, 0, 0.16, 176, 262)  # Depot apron
    B(g, "pad", 130, 170, 0.16, 0.4, 196, 236)  # the alt pad
    for (px, pz) in ((-190, 200), (150, 216)):  # the painted H and the box
        B(g, "line", px - 5.5, px - 3.5, 0.4, 0.46, pz - 7, pz + 7)
        B(g, "line", px + 3.5, px + 5.5, 0.4, 0.46, pz - 7, pz + 7)
        B(g, "line", px - 3.5, px + 3.5, 0.4, 0.46, pz - 1, pz + 1)
        for s in (-1, 1):
            B(g, "line", px - 18, px + 18, 0.4, 0.46, pz + s * 17.5 - 0.5, pz + s * 17.5 + 0.5)
            B(g, "line", px + s * 17.5 - 0.5, px + s * 17.5 + 0.5, 0.4, 0.46, pz - 17, pz + 17)
    # the ring road inside the wall: the edge has a job, and it is the loop round the base
    B(g, "road", -284, 284, 0, 0.08, 268, 282)
    B(g, "road", -284, -270, 0, 0.08, GATE_Z + 6, 268)
    B(g, "road", 240, 254, 0, 0.08, 44, 268)
    B(g, "road", 19, 250, 0, 0.09, 138, 152)  # the cross street: highway to the Shed
    B(g, "road", -264, -19, 0, 0.09, -8, 4)  # the west cross street: highway to the Barracks


def _perimeter():
    # North, west and east: the wall, 24 studs a mesh. Breaches are missing panels with one fallen.
    for x in range(-276, 277, 24):
        if abs(x) > 30:
            D("env_wall_panel_24", x, 292, 0)
            D("env_wall_panel_24", x, -292, 180)
    for z in range(-276, 277, 24):
        if not (92 < z < 116 or -240 < z < -216):  # E5, E2
            D("env_wall_panel_24", -292, z, 90)
        if not (164 < z < 188):  # E6
            D("env_wall_panel_24", 292, z, -90)
    D("env_wall_panel_24", -285, 104, 90, y=0.5, roll=-80)  # the fallen panels
    D("env_wall_panel_24", 285, 176, -90, y=0.5, roll=-80)
    D("env_wall_panel_24", -292, -228, 90, y=0, roll=-16)  # E2: leaning, climbed over
    for x, z in ((-280, 280), (280, 280), (-280, -280), (280, -280), (-96, 280), (110, 280), (-280, 40), (-280, 150), (280, 30), (280, 120)):
        D("env_guard_tower", x, z, 90 if z > 0 else -90)
    # The Gate line: T-walls across the map. Gaps: the Gatehouse, the foot gate (west), the bus
    # breach (east); one Scrape (prone, players only) at x -200.
    for x in range(-284, 285, 8):
        if abs(x) < 34 or abs(x + 112) < 6 or 82 < x < 110:
            continue
        D("env_twall", x, GATE_Z, 0, y=2.8 if x == -196 else 0)
    for s in (-1, 1):
        D("env_crib_stack", -196 + s * 3.2, GATE_Z, 0)
    D("env_twall", 92, GATE_Z + 9, 20, y=0.6, roll=84)  # knocked flat by the bus
    D("env_twall", 103, GATE_Z + 11, -30, y=0.6, roll=84)
    D("env_guard_tower", -64, GATE_Z + 14, 90)
    D("env_guard_tower", 64, GATE_Z + 14, 90)
    # the north gate: shut with what was to hand
    for x in (-20, -12, 12, 20):
        D("env_twall", x, 290, 0)
    V("prop_cargo_truck", 0, 284, 0)
    row("env_barrier_jersey", 0, 274, 5, 6.4)
    D("prop_light_tower", -26, 276, 0)
    D("prop_light_tower", 26, 276, 180)
    # the outer barricade, city side: jerseys, wire, two trucks nose to nose, the gap he walks through
    row("env_barrier_jersey", -13, -286, 4, 6.4)
    D("env_barrier_jersey", 21.4, -286, 0)
    D("prop_concertina", -13, -283, 0)
    V("prop_humvee_burnt", -31.5, -281, 5)
    V("prop_humvee", 30, -276, 170)
    D("env_guard_tower", -52, -280, -90)
    D("env_guard_tower", 46, -280, -90)
    D("prop_light_tower", -34, -270, 90)
    D("prop_light_tower", 36, -270, 90)


def _gatehouse():
    g = "Gatehouse"
    for s in (-1, 1):
        x0, x1 = (-32, -14) if s < 0 else (14, 32)
        inner = "E" if s < 0 else "W"
        outer = "W" if s < 0 else "E"
        building(
            g + ("W" if s < 0 else "E"), x0, x1, GATE_Z - 11, GATE_Z + 11, (DECK, 9.0),
            doors=(("N", 0, s * 21, 5, 8), ("S", 0, s * 21, 5, 8), (inner, 1, GATE_Z, 5, 8)),
            stairs=((0, outer, GATE_Z - 9.6, 1),), blank={(inner, 0), (outer, 0)},
        )
        ladder(g, s * 23, GATE_Z + 11.3, DECK, 21.0)  # the roof, from the walk's level (north face)
        D("env_checkpoint", s * 22, GATE_Z - 28, 0 if s < 0 else 180)
    B(g, "slab", -14, 14, DECK - 0.8, DECK, GATE_Z - 6, GATE_Z + 6)  # the walk over the road
    for dz in (-6, 5.4):
        wall(g, "block", "x", GATE_Z + dz + 0.3, -14, 14, DECK, DECK + 3.6, 0.6, [(-7, 3, 2.0, None), (7, 3, 2.0, None)])
    B(g, "sign", -5, 5, DECK + 0.2, DECK + 3.4, GATE_Z - 6.3, GATE_Z - 6.0)  # CHECKPOINT DELTA, on the parapet
    B(g, "red", -5, 5, DECK + 2.6, DECK + 3.4, GATE_Z - 6.36, GATE_Z - 6.3)
    for s in (-1, 1):  # hazard bands on the lane faces, a floodlight bar under the walk
        for k in range(3):
            B(g, "red" if k % 2 == 0 else "sign", s * 13.7 - 0.25, s * 13.7 + 0.25, 1.0 + 2.0 * k, 3.0 + 2.0 * k, GATE_Z - 11, GATE_Z - 7)
        B(g, "steel", s * 9 - 2, s * 9 + 2, DECK - 1.4, DECK - 0.8, GATE_Z - 6.6, GATE_Z - 6.0)
        x0, x1 = (-32, -14) if s < 0 else (14, 32)  # a string course at the walk's level, a lamp box on each roof
        B(g, "slab", x0 - 0.3, x1 + 0.3, DECK - 0.6, DECK, GATE_Z - 11.3, GATE_Z - 11)
        B(g, "slab", x0 - 0.3, x1 + 0.3, DECK - 0.6, DECK, GATE_Z + 11, GATE_Z + 11.3)
        B(g, "slab", min(s * 32, s * 32.3), max(s * 32, s * 32.3), DECK - 0.6, DECK, GATE_Z - 11, GATE_Z + 11)
        B(g, "steel", s * 16 - 1.2, s * 16 + 1.2, 22.2, 24.2, GATE_Z - 10, GATE_Z - 8)
    B(g, "steel", 22, 23, 21, 26, GATE_Z + 5, GATE_Z + 6)  # the siren on its mast
    B(g, "red", 21, 24, 26, 27.6, GATE_Z + 4, GATE_Z + 7)
    row("env_barrier_jersey", 0, GATE_Z - 2, 4, 6.6)  # Open the Route: the chained lane
    for x in (-9.9, -3.3, 3.3):
        B(g, "red", x + 2.8, x + 3.8, 2.6, 3.6, GATE_Z - 2.6, GATE_Z - 1.4)  # the three locks


def _approach():
    # the median: a jersey line with two crossings
    for z in range(-282, -140, 6):
        if not (-256 < z < -244 or -206 < z < -194):
            D("env_barrier_jersey", 0, z + 3, 90)
    D("env_sign_gantry", 0, -236, 0)
    # West carriageway: the jam, two lanes, noses north. The east carriageway was the army's
    # lane and is clear: the Warden's road (16 wide, nothing within 6 of it).
    rng = random.Random(41)
    cars = ["prop_car_sedan", "prop_car_hatch", "prop_car_suv", "prop_car_pickup", "prop_car_van"]
    for lane in (-6.0, -14.0):
        z = -272.0 + rng.uniform(0, 6)
        while z < -196:
            if -262 < z < -238 or -212 < z < -188:
                z += 8
                continue
            name = cars[rng.randrange(len(cars))]
            V(name, lane + rng.uniform(-0.8, 0.8), z, 90 + rng.uniform(-7, 7))
            z += rng.uniform(21, 27)
    V("prop_bus", -11, -166, 90)  # Bus 7, first at the boom
    V("prop_car_sedan", -27, -176, 60)  # the ones that pulled out of the queue
    V("prop_car_hatch", -25, -224, 112)
    V("prop_car_suv", 25, -212, 100)
    V("prop_ambulance", 29, -252, 84)
    V("prop_car_pickup", 24, -160, 75)
    for z in (-268, -218, -168):
        D("prop_warning_sign", -21.5, z, 180)
    D("prop_warning_sign", 21.5, -196, 0)

    # --- Screening Lot (west): tents, tables, the decon line to the foot gate
    for x in (-52, -90):
        D("env_screening_tent", x, -166, 0)
        for k, dx in enumerate((-9, 0, 9)):
            D("prop_table_flipped" if (k + (x < -60)) % 2 else "prop_table_folding", x + dx, -167 + 2 * k, 10 * k)
    D("env_decon_tent", -112, -146, 90)
    D("env_decon_tent", -128, -146, 90)
    row("env_barrier_jersey", -118.5, -126, 3, 6.4, axis="z")  # the funnel to the foot gate
    row("env_barrier_jersey", -105.5, -126, 3, 6.4, axis="z")
    D("prop_luggage", -66, -186, 0)
    D("prop_luggage", -40, -190, 70)
    D("prop_luggage", -104, -180, 200)
    D("prop_luggage", -30, -140, 30)
    D("prop_light_tower", -36, -198, 0)
    D("prop_light_tower", -140, -160, 180)
    D("prop_warning_sign", -100, -128, 180)
    row("prop_portable_toilet", -144, -200, 4, 5.2, axis="z", yaw=0)
    # the Screening Block: two storeys over the lot, outside stair west, inside flight, roof
    building(
        "ScreeningBlock", -100, -56, -236, -216, (9.0, 9.0),
        doors=(("N", 0, -66, 5, 8), ("S", 0, -95, 5, 8), ("E", 0, -226, 5, 8), ("W", 1, -226, 5, 8)),
        stairs=((0, "S", -88, 1),),
    )
    D("env_stair_steel_9", -119.9, -226, 0)  # up to the first-floor west door
    B("ScreeningBlock", "steel", -106, -100, 8.6, 9.0, -229.5, -222.5)
    ladder("ScreeningBlock", -60, -215.7, 0.0, 18.0)
    D("env_sat_dish", -64, -222, 0, y=18)
    # the Rows: body bags laid out south of the block, the ambulances that brought them
    for i in range(3):
        row("prop_body_bag", -124 + 0.4 * i, -270 + 8 * i, 7, 3.4, yaw=90 + 4 * i)
    V("prop_ambulance", -92, -268, 180)
    V("prop_ambulance", -64, -262, 150)
    D("prop_light_tower", -146, -252, 0)
    row("prop_pallet_stack", -44, -268, 3, 4.6)
    D("prop_dumpster", -34, -256, 90)

    # --- the Pens (Site 2): a hesco ring with three mouths, chainlink runs inside, three tents
    for x in (-250, -226, -178):
        D("env_hesco_row_24", x, -148, 0)
        D("env_hesco_row_24", x, -260, 0)
    for z in (-248, -224, -170):
        D("env_hesco_row_24", -164, z, 90)
    for z in (-248, -224, -200, -176):
        D("env_hesco_row_24", -264, z, 90)
    for z in (-234, -204, -174):
        D("env_tent", -240, z, 0)
    for z in (-219, -189):
        row("prop_chainlink_panel", -234, z, 3, 12)
    row("prop_chainlink_panel", -198, -236, 2, 12, axis="z")
    row("prop_chainlink_panel", -198, -172, 2, 12, axis="z")
    for x, z, yaw in ((-190, -226, 0), (-184, -182, 30), (-206, -208, -20), (-214, -196, 80)):
        D("prop_cot", x, z, yaw)
    row("prop_body_bag", -182, -250, 4, 3.2, yaw=90)
    D("prop_light_tower", -170, -184, 180)
    D("prop_luggage", -176, -166, 40)
    D("prop_warning_sign", -158, -204, 0)
    D("env_container_olive", -262, -276, 0)  # the south-west corner store (Misdrop)
    row("prop_pallet_stack", -238, -276, 2, 4.6)
    D("prop_generator", -222, -276, 0)

    # --- Bus Park and Impound (east)
    for x, z in ((60, -250), (60, -202), (78, -250), (78, -202), (96, -250)):
        V("prop_bus", x, z, 90)
    V("prop_bus", 99, GATE_Z - 10, 104)  # the one that ran the wall: nose through the Gate line
    D("prop_luggage", 68, -226, 10)
    D("prop_luggage", 88, -182, 100)
    D("prop_luggage", 44, -150, 0)
    kinds = ["prop_car_sedan", "prop_car_suv", "prop_car_hatch", "prop_car_van", "prop_car_pickup", "prop_car_sedan", "prop_car_hatch"]
    for i, x in enumerate(range(137, 236, 22)):
        V(kinds[i % 7], x + 0.5, -263, 90 + (i * 37 % 11 - 5))
        if i != 2:
            V(kinds[(i + 3) % 7], x + 11.5, -223, -90 + (i * 53 % 9 - 4))
    V("prop_car_van", 122, -150, 200)
    V("prop_humvee", 190, -196, 20)
    D("prop_light_tower", 118, -236, 0)
    D("prop_light_tower", 226, -196, 180)
    D("prop_warning_sign", 40, -128, 180)
    row("env_barrier_jersey", 60, -130, 4, 6.4)
    # Inspection Bay: a canopy you can stand on (12), stair each end, a truck under it
    g = "InspectionBay"
    B(g, "panel", 148, 204, 11.2, DECK, -176, -150)
    for x in (150, 176, 202):
        for z in (-174, -152):
            B(g, "steel", x - 0.8, x + 0.8, 0, 11.2, z - 0.8, z + 0.8)
    for z in (-176, -150.5):
        wall(g, "steel", "x", z + 0.25, 148, 204, DECK + 3.0, DECK + 3.4, 0.3)
        wall(g, "steel", "x", z + 0.25, 148, 204, DECK + 1.4, DECK + 1.7, 0.2)
    D("env_stair_steel_12", 148 - 12.0 / T33, -163, 0)
    V("prop_cargo_truck", 176, -163, 180)
    D("prop_table_folding", 160, -146, 0)
    D("prop_table_flipped", 192, -144, 40)
    row("prop_drum", 236, -142, 3, 3.0)
    # the Customs House: a 12-clear ground floor, an office over it level with the canopy, roof 21
    building(
        "CustomsHouse", 228, 250, -176, -150, (DECK, 9.0),
        doors=(("N", 0, 239, 5, 8), ("S", 0, 239, 5, 8), ("W", 0, -158, 8, 10), ("W", 1, -171, 5, 8)),
        stairs=((0, "E", -174, 1), (1, "W", -152, -1)), blank={("E", 0)},
    )
    row("env_catwalk_12", 216, -171, 2, 12, y=DECK - 0.4)
    B(g, "steel", 215.5, 216.5, 0, DECK - 0.4, -171.5, -170.5)


def _yard():
    # The Yard: the boss ground. Open by choice; two hesco search bays 60 apart break the line.
    D("env_hesco_row_24", -44, -70, 90)
    D("env_hesco_row_24", -32, -56, 0)
    D("env_hesco_row_24", 46, -52, 90)
    D("env_hesco_row_24", 34, -66, 0)
    V("prop_humvee", -46, -90, 15)
    V("prop_humvee_burnt", 58, -34, 250)
    V("prop_cargo_truck", 50, -84, 90)
    D("prop_light_tower", -66, -40, 0)
    D("prop_light_tower", 68, -72, 180)
    row("env_barrier_jersey", -26, -84, 3, 6.4, axis="z")
    row("env_barrier_jersey", 26, -40, 3, 6.4, axis="z")
    D("prop_generator", -62, -26, 0)
    row("prop_pallet_stack", 76, -60, 2, 4.6)
    # the Workshop, east of the Yard: a frame tent, a truck with its bonnet up, drums
    D("env_screening_tent", 112, -62, 0)
    V("prop_humvee", 108, -62, 0)
    V("prop_cargo_truck", 122, -84, 10)
    row("prop_drum", 128, -52, 3, 3.0, axis="z")
    row("prop_pallet_stack", 96, -50, 2, 4.6)
    D("prop_generator", 132, -70, 90)
    D("prop_light_tower", 92, -74, 0)
    D("prop_luggage", 88, -92, 0)  # off the bus
    row("prop_body_bag", 38, -24, 3, 3.2, yaw=80)
    D("prop_concertina", -82, -100, 0)
    D("prop_concertina", 44, -102, 0)
    for z in range(-84, 262, 48):  # street lights: the spine reads from anywhere
        if abs(z - 21) > 14:
            D("env_lamp_post", -21.5, z, 0)
            D("env_lamp_post", 21.5, z + 24, 180)
    for z in (-226, -180):
        D("env_lamp_post", 21.5, z, 180)


def _west():
    # --- Barracks: two 2-storey blocks, a court between, a steel gallery at 9 on each inner face
    for name, z0, z1, inner in (("BarracksA", -84, -66, "N"), ("BarracksB", -34, -16, "S")):
        gz = z1 + 3 if inner == "N" else z0 - 3
        building(
            name, -244, -172, z0, z1, (9.0, 9.0),
            doors=((inner, 0, -226, 5, 8), (inner, 0, -190, 5, 8), ("E", 0, (z0 + z1) / 2, 5, 8), ("W", 0, (z0 + z1) / 2, 5, 8), (inner, 1, -232, 5, 8), (inner, 1, -184, 5, 8)),
            stairs=((0, "S" if inner == "N" else "N", -236, 1),),
        )
        row("env_catwalk_12", -208, gz, 6, 12, y=8.6)
        for x in range(-244, -170, 12):
            B(name, "steel", x - 0.3, x + 0.3, 0, 8.6, gz + (2.7 if inner == "N" else -2.7) - 0.3, gz + (2.7 if inner == "N" else -2.7) + 0.3)
        ladder(name, -176, (z1 + 0.3) if inner == "N" else (z0 - 0.3), 9.0, 18.0)
    D("env_stair_steel_9", -172 + 9.0 / T33, -63, 180)  # gallery A, east end
    D("env_stair_steel_9", -244 - 9.0 / T33, -37, 0)  # gallery B, west end
    row("env_catwalk_12", -208, -50, 2, 10, axis="z", y=8.6)  # the bridge between the galleries
    for x, z, yaw in ((-200, -50, 0), (-226, -46, 90), (-186, -54, 20)):
        D("prop_cot", x, z, yaw)
    row("prop_pallet_stack", -234, -56, 2, 4.6)
    row("prop_portable_toilet", -160, -74, 3, 5.2, axis="z", yaw=180)
    D("prop_generator", -160, -24, 90)
    D("prop_light_tower", -166, -12, 0)
    # between the Barracks and the Yard: the Armoury (one storey, roof by ladder), the mess tents
    building("Armoury", -134, -114, -76, -62, (9.0,), kind="bunker", doors=(("S", 0, -124, 5, 8), ("E", 0, -69, 4, 8)), win=False)
    ladder("Armoury", -124, -61.7, 0, 9.0)
    row("prop_pallet_stack", -108, -80, 2, 4.6, axis="z")
    for x in (-146, -124, -102):
        D("env_tent", x, -36, 90)
    row("prop_table_folding", -124, -22, 3, 8)
    D("prop_dumpster", -92, -24, 0)
    V("prop_humvee", -100, -92, 180)
    V("prop_car_suv", -142, -98, 170)

    # --- Command Post: three storeys, inside flights on alternate walls, an outside stair in two
    # flights on the west face, east windows over the highway and the Yard
    building(
        "CommandPost", -100, -60, 52, 82, (9.0, 9.0, 9.0),
        doors=(("E", 0, 67, 5, 8), ("S", 0, -80, 5, 8), ("W", 0, 60, 5, 8), ("N", 1, -80, 5, 8), ("W", 1, 74, 5, 8), ("W", 2, 60, 5, 8)),
        stairs=((0, "N", -96, 1), (1, "S", -64, -1), (2, "N", -96, 1)),
    )
    D("env_stair_steel_9", -103, 74 - 9.0 / T33 - 3, 90)  # ground to the first floor
    B("CommandPost", "steel", -112, -100, 8.6, 9.0, 71, 77.5)  # the landing at the first-floor door
    D("env_stair_steel_9", -109, 57 + 9.0 / T33 + 3.5, -90, y=9.0)  # first to the second floor
    B("CommandPost", "steel", -112, -100, 17.6, 18.0, 56.5, 63.5)
    D("env_sat_dish", -66, 58, 0, y=27)
    D("env_sat_dish", -72, 76, 120, y=27)
    B("CommandPost", "steel", -92.3, -91.7, 27, 41, 77.7, 78.3)  # whip mast
    # --- the Mast: the comm tower on a 9-stud plinth: catwalk from the CP, earth ramp west, steel stair east
    g = "Mast"
    B(g, "concrete", -98, -62, 0, 9.0, 94, 128)
    W(g, "dust", -116, -98, 0, 9.0, 104, 118, "+x")
    D("env_stair_steel_9", -62 + 9.0 / T33, 104, 180)
    D("env_catwalk_12", -80, 88, 90, y=8.6)
    D("env_comm_tower", -80, 112, 0, y=9.0)
    D("env_hesco_row_24", -80, 125.6, 0, y=9.0)
    D("prop_generator", -90, 100, 0, y=9.0)
    row("prop_pallet_stack", -70, 98, 2, 4.6, y=9.0)
    # the Compound's ground (Site 1): the CP forecourt south of it
    D("env_hesco_row_24", -104, 6, 0)
    D("env_hesco_row_24", -128.5, 26, 90)
    V("prop_humvee", -116, 44, 10)
    D("env_sandbag_bunker", -92, 38, 180)
    D("prop_light_tower", -56, 46, 180)
    row("prop_pallet_stack", -122, 12, 2, 4.6)

    # --- the Tent Lines: where the companies slept. Three rows, lanes 10 wide; the west breach (E5) opens onto them.
    B("Roads", "mud", -260, -160, 0, 0.06, 46, 116)
    for i, z in enumerate((58, 80, 102)):
        for j, x in enumerate((-246, -222, -198, -174)):
            if (i, j) in ((2, 0), (1, 2)):
                D("prop_cot", x - 3, z, 30)  # a tent gone: what was in it
                D("prop_cot", x + 4, z + 2, -50)
                row("prop_body_bag", x + 1, z - 7, 2, 3.2, yaw=80)
            else:
                D("env_tent", x, z, 0)
    D("prop_light_tower", -160, 70, 180)
    D("prop_generator", -160, 96, 90)
    row("prop_portable_toilet", -256, 124, 3, 5.2, yaw=90)
    # the parade square: open by choice, a flagpole and the vehicles nobody drove away
    B("Roads", "concrete", -262, -150, 0, 0.1, 10, 40)
    B("Barracks", "steel", -206.3, -205.7, 0, 26, 24.7, 25.3)
    B("Barracks", "concrete", -208, -204, 0, 0.8, 23, 27)
    V("prop_cargo_truck", -240, 18, 0)
    V("prop_humvee", -168, 30, 200)
    row("prop_pallet_stack", -184, 14, 2, 4.6)
    # the casualty point between the LZ and the highway: two tents, cots, what was not flown out
    for z in (178, 208):
        D("env_screening_tent", -62, z, 0)
        for k, dx in enumerate((-8, 0, 8)):
            D("prop_cot", -62 + dx, z + (2 if k % 2 else -2), 90)
    row("prop_body_bag", -62, 228, 8, 3.2, yaw=90)
    V("prop_ambulance", -38, 244, 200)
    D("prop_light_tower", -34, 192, 180)
    D("prop_luggage", -86, 194, 0)
    D("prop_warning_sign", -30, 164, 0)

    # --- LZ apron: open by choice. Flight Ops (two storeys and a roof cab) on its south-east corner.
    building(
        "FlightOps", -128, -110, 150, 168, (9.0, 9.0),
        doors=(("W", 0, 159, 5, 8), ("S", 0, -119, 5, 8), ("N", 1, -119, 5, 8)),
        stairs=((0, "E", 152, 1), (1, "W", 166, -1)),
    )
    D("env_stair_steel_9", -119, 168 + 9.0 / T33 + 0.1, -90)  # the outside stair, north face
    g = "FlightOps"
    building(g + "Cab", -120, -112, 153, 165, (7.0,), base=18.0, kind="panel", doors=(("W", 0, 159, 4, 6.4),), parapet=0)
    ladder(g, -109.7, 156, 0.0, 18.0, axis="z")
    for x, z, yaw in ((-258, 142, 45), (-258, 258, -45), (-112, 258, -135), (-150, 142, 135)):
        D("prop_light_tower", x, z, yaw)
    D("prop_fuel_bladder", -246, 168, 90)
    D("prop_fuel_bladder", -246, 186, 90)
    row("prop_drum", -246, 204, 4, 3.0, axis="z")
    V("prop_cargo_truck", -236, 240, 0)
    V("prop_humvee", -140, 232, 250)
    row("prop_pallet_stack", -150, 190, 2, 4.6, axis="z")
    row("prop_body_bag", -146, 212, 4, 3.2, axis="z", yaw=0)
    D("env_hesco_row_24", -232, 144, 0)
    D("env_hesco_row_24", -180, 144, 0)
    D("env_sandbag_bunker", -206, 250, 0)
    D("prop_warning_sign", -136, 144, 180)


def _east():
    # --- the service bridge (12): earth ramp west, over the highway, onto the Motor Pool deck
    g = "ServiceBridge"
    W(g, "road", -78, -42, 0, DECK, 14, 28, "+x")
    B(g, "slab", -42, 66, DECK - 1.0, DECK, 14, 28)
    for x in (-24, 24, 46):
        B(g, "concrete", x - 1.5, x + 1.5, 0, DECK - 1.0, 15, 27)
    for z in (14, 27.4):
        W(g, "concrete", -85.8, -42, 0.0, DECK + 2.6, z, z + 0.6, "+x")  # ramp kerbs: 2.6 above the slope
        wall(g, "concrete", "x", z + 0.3, -42, 66, DECK, DECK + 2.6, 0.6)
    V("prop_car_pickup", 6, 19.6, 4, y=DECK)
    V("prop_humvee_burnt", 40, 22.2, 183, y=DECK)
    # --- Motor Pool deck, "the Overlook" (Site 3): parking deck at 12 on columns, bays under it
    g = "MotorPool"
    X0, X1, Z0, Z1 = 66, 146, -6, 48
    B(g, "slab", X0, X1, DECK - 1.0, DECK, Z0, Z1)
    for x in range(X0 + 4, X1, 18):
        for z in (Z0 + 3, 21, Z1 - 3):
            B(g, "concrete", x - 1.2, x + 1.2, 0, DECK - 1.0, z - 1.2, z + 1.2)
    PH = 3.2  # the deck's parapet: stand to see over it, crouch to hide
    wall(g, "concrete", "x", Z0 + 0.4, X0, X1, DECK, DECK + PH, 0.8, [(111.5, 6.0, 0.0, None)])  # S: the stair gap
    wall(g, "concrete", "x", Z1 - 0.4, X0, X1, DECK, DECK + PH, 0.8, [(103, 14, 0.0, None)])  # N: the ramp mouth
    wall(g, "concrete", "z", X0 + 0.4, Z0 + 0.8, Z1 - 0.8, DECK, DECK + PH, 0.8, [(21, 14, 0.0, None)])  # W: the bridge
    wall(g, "concrete", "z", X1 - 0.4, Z0 + 0.8, Z1 - 0.8, DECK, DECK + PH, 0.8, [(0, 6, 0.0, None)])  # E: the catwalk to the Stacks
    W(g, "road", 110, 146, 0, DECK, 48, 62, "-x")  # the vehicle ramp, along the north face
    B(g, "road", 96, 110, DECK - 1.0, DECK, 48, 62)  # its landing
    B(g, "concrete", 96, 110, 0, DECK - 1.0, 60, 62)
    W(g, "concrete", 110, 153.8, 0.0, DECK + 2.6, 62, 62.6, "-x")  # the ramp's outer kerb
    wall(g, "concrete", "x", 62.3, 96, 110, DECK, DECK + 2.6, 0.6)
    D("env_stair_steel_12", 108.5 - 12.0 / T33, Z0 - 2.6, 0)  # south face
    B(g, "steel", 108.5, 114.5, DECK - 0.4, DECK, Z0 - 5.2, Z0)  # its landing
    building("Dispatch", 128, 144, 34, 46, (9.0,), base=DECK, kind="panel", doors=(("W", 0, 40, 4, 8),))
    ladder("Dispatch", 127.7, 37, DECK, DECK + 9, axis="z")
    V("prop_humvee", 80, 4, 90, y=DECK)
    V("prop_cargo_truck", 122, 12, 180, y=DECK)
    V("prop_humvee_burnt", 92, 38, 20, y=DECK)
    D("env_hesco_row_24", 104, 30, 0, y=DECK)
    row("env_barrier_jersey", 100, 8, 2, 6.4, y=DECK)
    row("prop_pallet_stack", 138, 24, 2, 4.6, axis="z", y=DECK)
    for x, hd in ((78, 90), (96, 90), (114, 270), (132, 90)):  # parked under the deck
        V("prop_humvee" if x != 114 else "prop_cargo_truck", x, 30 if x != 114 else 32, hd)
    V("prop_ambulance", 84, 6, 0)
    V("prop_cargo_truck", 122, 6, 180)
    row("prop_drum", 60, 40, 3, 3.0, axis="z")
    D("prop_light_tower", 52, -12, 0)
    row("env_barrier_jersey", 50, 4, 3, 6.4, axis="z")

    # --- the Stacks (Depot): container columns 20 apart, two cross containers on top (18.9),
    # catwalks over the aisles, two ramps up, a catwalk to the Motor Pool deck
    cols = (172, 192, 212, 232)
    for i, x in enumerate(cols):
        for z in (-80, -56):
            D("env_container_rust" if (i + (z > -70)) % 2 else "env_container_olive", x, z, -90 if (x, z) == (172, -56) else 90)
        if x < 232:
            for z in (-18, 6):
                D("env_container_olive" if (i + (z > -10)) % 2 else "env_container_rust", x, z, -90 if (x, z) == (212, 6) else 90)
    D("env_container_rust", 202, -80, 0, y=TOP)
    D("env_container_olive", 202, 6, 0, y=TOP)
    g = "Stacks"
    W(g, "plank", 169, 175, 0, TOP, -45.2, -45.2 + TOP / T33, "-z")  # ramp 1: north end of column 172's south pair
    W(g, "plank", 229, 235, 0, TOP, -90.8 - TOP / T33, -90.8, "+z")  # ramp 2: south end of column 232
    W(g, "plank", 209, 215, 0, TOP, 16.8, 16.8 + TOP / T33, "-z")  # ramp 3: north end of column 212's north pair
    for x, z in ((182, -62), (222, -62), (222, -78), (202, -56), (182, 10), (202, -14)):
        D("env_catwalk_12", x, z, 0, y=TOP)  # each end rests on a container roof
    D("env_catwalk_12", 152, 0, 0, y=DECK - 0.4)  # deck -> the Stacks: two bays, then a 2.45 step down
    D("env_catwalk_12", 164, 0, 0, y=DECK - 0.4)
    B(g, "steel", 157.5, 158.5, 0, DECK - 0.4, -0.5, 0.5)
    row("prop_pallet_stack", 196, -36, 3, 4.6)
    row("prop_pallet_stack", 240, -30, 2, 4.6, axis="z")
    D("prop_fuel_bladder", 236, 26, 0)
    D("prop_dumpster", 164, -94, 0)
    D("prop_light_tower", 160, -40, 0)
    D("prop_light_tower", 250, -84, 180)
    V("prop_cargo_truck", 244, -52, 90)
    row("prop_chainlink_panel", 204, 40, 5, 12)

    # --- the Shed: a 13-clear warehouse on a dock; the loading dock is a pit (-4) with a ramp in
    g = "Shed"
    building(
        g, 176, 226, 84, 122, (13.0,), kind="sheet",
        doors=(("S", 0, 192, 12, 10), ("S", 0, 211, 12, 10), ("N", 0, 190, 5, 8), ("N", 0, 214, 5, 8), ("E", 0, 103, 5, 8)), win=False,
    )
    B(g, "slab", 177, 196, 5.9, 6.5, 100, 121)  # the mezzanine, west end
    W(g, "stair", 196, 196 + 6.5 / T33, 0, 6.5, 115, 120, "-x")
    D("env_container_rust", 170, 100, -90)  # the Walker step to the roof: 9.55, then 4.05
    W(g, "plank", 167, 173, 0, TOP, 110.8, 110.8 + TOP / T33, "-z")
    D("env_stair_steel_12", 229, 122 - 12.0 / T33 - 6, 90)  # east face: up to a landing at 12, 1.6 under the parapet
    B(g, "steel", 226, 232, 11.6, 12.0, 116, 123)
    for x in (192, 211):
        V("prop_cargo_truck", x, 71.5, -90, y=-4.0)  # backed onto the dock
    D("prop_dumpster", 222, 76, 90)
    row("prop_pallet_stack", 186, 92, 3, 4.6, axis="z")
    row("prop_pallet_stack", 216, 110, 2, 4.6, axis="z")
    row("prop_drum", 222, 92, 3, 3.0, axis="z")

    # --- generator yard: three sets behind a blast screen, two bulk tanks
    for x in (52, 60, 68, 76, 84, 92, 100, 108, 116):
        D("env_twall", x, 82, 0)
    for z in (88, 96):
        D("env_twall", 46.5, z, 90)
    for x in (64, 84, 104):
        D("prop_generator", x, 92, 90)
    D("env_fuel_tank", 64, 122, 0)
    D("env_fuel_tank", 100, 122, 0)
    row("prop_drum", 82, 110, 4, 3.0)
    D("prop_light_tower", 118, 106, 180)
    D("prop_warning_sign", 46, 110, 90)
    # --- Depot apron: the alt pad, open by choice
    for x, z, yaw in ((100, 180, 45), (200, 180, 135), (200, 258, -135), (100, 258, -45)):
        D("prop_light_tower", x, z, yaw)
    D("env_hesco_row_24", 150, 180, 0)
    D("env_container_olive", 216, 222, 90)
    D("env_container_rust", 226, 222, 90)
    V("prop_humvee", 106, 240, 300)
    row("prop_pallet_stack", 196, 244, 2, 4.6, axis="z")
    D("env_sandbag_bunker", 116, 200, 90)
    # the convoy that tried the north gate, stopped nose to tail on the army lane
    for x, z, name in ((10, 254, "prop_cargo_truck"), (11, 232, "prop_car_suv"), (9, 212, "prop_humvee"), (10, 188, "prop_cargo_truck"), (12, 163, "prop_humvee_burnt")):
        V(name, x, z, 90 + (x * z) % 7 - 3)
    # the fuel point: bladders behind a hesco berm
    for z in (176, 196, 216):
        D("prop_fuel_bladder", 62, z, 0)
    D("env_hesco_row_24", 40, 186, 90)
    D("env_hesco_row_24", 40, 212, 90)
    D("env_hesco_row_24", 60, 232, 0)
    row("prop_drum", 78, 236, 5, 3.0)
    D("prop_warning_sign", 36, 162, 180)
    V("prop_cargo_truck", 84, 196, 90)
    # the burn pit in the north-east corner
    B("Roads", "mud", 258, 284, 0, 0.06, 214, 246)
    for i in range(2):
        row("prop_body_bag", 270, 222 + 8 * i, 6, 3.2, yaw=90 + 6 * i)
    row("prop_drum", 262, 244, 3, 3.0)
    D("prop_dumpster", 276, 206, 90)
    D("prop_light_tower", 258, 200, 180)
    # the channel: what washed down it
    V("prop_car_sedan", 270, -150, 80, y=CH_Y)
    D("prop_dumpster", 268, -40, 20, y=CH_Y)
    row("prop_pallet_stack", 272, 40, 2, 4.6, axis="z", y=CH_Y)
    D("prop_luggage", 270, -230, 0, y=CH_Y)


def _backdrop():
    # The city south (where they came from), the highway and pines north, pines and hills east
    # and west. No collision, nothing the squad can reach.
    rng = random.Random(7)
    for sx in (-1, 1):
        k = 0
        for z in range(-270, 290, 44):
            D("env_pine_stand", sx * (318 + 9 * (k % 2)), z, 90, layer="edge")
            k += 1
    for x in range(-290, 300, 44):
        if abs(x) > 40:
            D("env_pine_stand", x, 318 + 9 * ((x // 44) % 2), 0, layer="edge")
    for x, z, sx, sy, sz, yaw in (
        (-900, 60, 900, 110, 320, 84), (-820, -420, 620, 70, 260, 100), (-960, 640, 800, 140, 340, 60),
        (900, 160, 960, 120, 330, 96), (840, -360, 600, 76, 250, 74), (980, 700, 780, 130, 320, 112),
        (-420, 1100, 900, 120, 300, 8), (460, 1160, 1000, 150, 320, -6), (0, 1400, 900, 100, 280, 0),
    ):
        D("env_far_hill", x, z, yaw, scale=(sx / 2, sz / 2, sy), layer="edge")
    D("env_sign_gantry", 0, 420, 180, layer="edge")
    cars = ["prop_car_sedan", "prop_car_hatch", "prop_car_suv", "prop_car_van", "prop_car_pickup", "prop_cargo_truck"]
    for z in (-330, -366, -410, -470, -540, -620):  # the jam runs back to the city
        for lane in (-14, -6, 6, 14):
            if rng.random() < 0.7:
                V("prop_bus" if rng.random() < 0.15 else rng.choice(cars), lane + rng.uniform(-1, 1), z + rng.uniform(-10, 10), 90 + rng.uniform(-6, 6), layer="edge")
    for z in (340, 420, 520):  # a few that got through, north
        V(rng.choice(cars), 8 + rng.uniform(-2, 2), z, 90 + rng.uniform(-20, 20), layer="edge")


def _skyline():
    """The city, south: three arcs about the Gate, 130 degrees wide. (kind, x, z, scale, yaw, burning)."""
    rng = random.Random(1911)
    kinds = ("office", "residential", "deco", "glass", "ruined", "midrise")
    out = []
    for i, (radius, s0, s1, n) in enumerate(((620, 0.9, 1.25, 13), (800, 1.2, 1.7, 11), (1020, 1.6, 2.3, 9))):
        for k in range(n):
            a = -66 + 132 * (k + 0.5) / n + rng.uniform(-3, 3)  # degrees off due south
            r = radius + rng.uniform(-40, 40)
            mid = 1.0 - 0.5 * abs(a) / 66
            out.append({
                "kind": kinds[(k * 5 + i) % 6] if rng.random() < 0.7 else rng.choice(kinds),
                "x": round(r * math.sin(math.radians(a))), "z": round(GATE_Z - r * math.cos(math.radians(a))),
                "scale": round(rng.uniform(s0, s1) * mid, 2), "yaw": rng.choice((0, 8, -12, 15, 45, 90, 180)),
                "burning": rng.random() < 0.25,
            })
    return out


SKYLINE = []


def layout():
    """Fills PARTS, DRESSING, SKYLINE from scratch."""
    del PARTS[:], DRESSING[:], SKYLINE[:]
    BUILDINGS.clear()
    _ground()
    _perimeter()
    _gatehouse()
    _approach()
    _yard()
    _west()
    _east()
    _backdrop()
    SKYLINE.extend(_skyline())


# ------------------------------------------------------------------ scene
KINDS = {
    "dust": (0.30, 0.27, 0.22, 1),
    "mud": (0.19, 0.155, 0.12, 1),
    "road": (0.115, 0.12, 0.13, 1),
    "line": (0.62, 0.62, 0.58, 1),
    "concrete": (0.40, 0.395, 0.375, 1),
    "concrete_d": (0.27, 0.265, 0.25, 1),
    "pad": (0.47, 0.455, 0.41, 1),
    "block": (0.50, 0.50, 0.45, 1),  # cinder block
    "bunker": (0.36, 0.355, 0.33, 1),
    "panel": (0.60, 0.60, 0.575, 1),  # painted panel
    "sheet": (0.24, 0.26, 0.27, 1),  # the Shed's sheet steel
    "slab": (0.34, 0.335, 0.32, 1),
    "roof": (0.22, 0.215, 0.205, 1),
    "stair": (0.42, 0.40, 0.37, 1),
    "steel": (0.16, 0.17, 0.18, 1),
    "plank": (0.36, 0.27, 0.17, 1),
    "sign": (0.80, 0.80, 0.78, 1),
    "red": (0.50, 0.08, 0.07, 1),
    "dark": (0.02, 0.02, 0.025, 1),
    "zone": (0.95, 0.74, 0.25, 1),
    "mark": (1.0, 1.0, 1.0, 1),
    "entry": (1.0, 0.25, 0.2, 1),
}
HAZE = (0.42, 0.30, 0.24)  # the smoke-stained evening (docs/STYLES.md §7)
MARK_Y = 120.0


def scene():
    sc = bpy.data.scenes.get(SCENE)
    if sc is None:
        sc = bpy.data.scenes.new(SCENE)
    sc.unit_settings.scale_length = 0.28
    if bpy.context.window is not None:
        bpy.context.window.scene = sc
    return sc


def col(name, parent=None, sc=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        (parent or (sc or scene()).collection).children.link(c)
    return c


def _mat(name, rgba, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.95
    if emit:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = rgba
    return m


def materials():
    mats = {k: _mat("dv2_" + k, rgba, emit=1.0 if k in ("zone", "mark", "entry") else 0.0) for k, rgba in KINDS.items()}
    mats["lit"] = _mat("dv2_lit", (1.0, 0.62, 0.25, 1), emit=3.0)
    mats["fire"] = _mat("dv2_fire", (1.0, 0.32, 0.08, 1), emit=5.0)
    return mats


def palette():
    m = bpy.data.materials.get("dv2_palette")
    if m is None:
        m = ba.build_palette_material(ba.build_palette_image())
        m.name = "dv2_palette"
        m.diffuse_color = (0.5, 0.5, 0.48, 1)
    return m


def hazed(palette_mat, amount=0.62):
    m = bpy.data.materials.get("dv2_tower")
    if m is not None:
        return m
    m = palette_mat.copy()
    m.name = "dv2_tower"
    tree = m.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    sock = {i.identifier: i for i in mix.inputs}
    sock["Factor_Float"].default_value = amount
    sock["B_Color"].default_value = HAZE + (1,)
    tree.links.new(tex.outputs["Color"], sock["A_Color"])
    tree.links.new(next(o for o in mix.outputs if o.identifier == "Result_Color"), bsdf.inputs["Base Color"])
    m.diffuse_color = (0.3, 0.24, 0.21, 1)
    return m


def clear(root_name):
    root = bpy.data.collections.get(root_name)
    if root is None:
        return
    for c in list(root.children_recursive) + [root]:
        for o in list(c.objects):
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0:
                if isinstance(data, bpy.types.Mesh):
                    bpy.data.meshes.remove(data)
                elif isinstance(data, bpy.types.Curve):
                    bpy.data.curves.remove(data)
    for c in list(root.children_recursive):
        bpy.data.collections.remove(c)
    bpy.data.collections.remove(root)


def parts_to_meshes(parts, parent, mats, prefix):
    """One mesh object per group, a material slot per kind."""
    groups = {}
    for p in parts:
        groups.setdefault(p[0], []).append(p)
    for g, items in groups.items():
        bm = bmesh.new()
        kinds = []
        for _, kind, shape, (x0, x1, y0, y1, z0, z1), up in items:
            if kind not in kinds:
                kinds.append(kind)
            mi = kinds.index(kind)
            if shape == "box":
                pts = [(x, z, y) for x in (x0, x1) for z in (z0, z1) for y in (y0, y1)]
                quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
                tris = []
            else:
                # low edge on the side away from `up`, full height on the `up` side
                if up == "+x":
                    lo, hi = [(x0, z0), (x0, z1)], [(x1, z0), (x1, z1)]
                elif up == "-x":
                    lo, hi = [(x1, z1), (x1, z0)], [(x0, z1), (x0, z0)]
                elif up == "+z":
                    lo, hi = [(x1, z0), (x0, z0)], [(x1, z1), (x0, z1)]
                else:
                    lo, hi = [(x0, z1), (x1, z1)], [(x0, z0), (x1, z0)]
                pts = [(lo[0][0], lo[0][1], y0), (lo[1][0], lo[1][1], y0), (hi[0][0], hi[0][1], y0), (hi[1][0], hi[1][1], y0), (hi[0][0], hi[0][1], y1), (hi[1][0], hi[1][1], y1)]
                quads = [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1)]
                tris = [(0, 2, 4), (1, 5, 3)]
            vs = [bm.verts.new(p) for p in pts]
            for f in quads + tris:
                face = bm.faces.new([vs[i] for i in f])
                face.material_index = mi
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(prefix + g)
        bm.to_mesh(me)
        bm.free()
        for k in kinds:
            me.materials.append(mats[k])
        obj = bpy.data.objects.new(prefix + g, me)
        obj.color = mats[kinds[0]].diffuse_color
        parent.objects.link(obj)


def build_kit(names, palette_mat, lib_name):
    """One mesh per kit piece, from build_assets' builders, in a hidden library collection."""
    lib = col(lib_name)
    lib.hide_render = True
    lib.hide_viewport = True
    meshes = {}
    for name in sorted(names):
        key = "dv2lib_" + name
        me = bpy.data.meshes.get(key)
        if me is None:
            fn, col_name, pivot = ba.ASSETS[name]
            b = ba.Builder()
            fn(b)
            obj = _finish(b, name, lib, palette_mat, pivot, col_name)
            me = obj.data
            me.name = key
        meshes[name] = me
    return meshes


class _Named:
    def __init__(self, name, real):
        self.name, self.objects = name, real.objects


def _finish(b, name, holder, palette_mat, pivot, col_name):
    """Builder.finish, with the collection name the asset is registered under (so the z-fight
    pass runs exactly as in a real build) but linked into our library."""
    return b.finish(name, _Named(col_name, holder), palette_mat, pivot=pivot)


def drop_kit(*names):
    """Forget built kit meshes so the next build makes them again (after editing a builder).
    No names = the whole Delta v2 kit."""
    for name in names or delta_kit.NAMES:
        me = bpy.data.meshes.get("dv2lib_" + name)
        if me is None:
            continue
        for o in [o for o in bpy.data.objects if o.data is me]:
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(me)


def tris(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def place(e, mesh, parent):
    obj = bpy.data.objects.new(e["name"], mesh)
    parent.objects.link(obj)
    obj.location = (e["x"], e["z"], e.get("y") or 0.0)
    obj.rotation_euler = (math.radians(e.get("roll") or 0.0), 0.0, math.radians(e.get("yaw") or 0.0))
    if e.get("scale"):
        obj.scale = e["scale"]
    return obj


def _frame(parent, name, c, size, mat, t=2.4):
    for dx, dz, sx, sz in ((0, 1, size[0], t), (0, -1, size[0], t), (1, 0, t, size[1]), (-1, 0, t, size[1])):
        bar = dm.box(name, parent, "warn", (c[0] + dx * size[0] / 2, MARK_Y, c[2] + dz * size[1] / 2), (sx, 0.2, sz))
        bar.data.materials.append(mat)
        bar.visible_shadow = False


def _label(parent, text, x, z, mat, size=11.0):
    curve = bpy.data.curves.new("label_" + text, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new("label_" + text, curve)
    parent.objects.link(obj)
    obj.location = (x, z, MARK_Y)
    curve.materials.append(mat)
    obj.visible_shadow = False
    if size > 4:  # a dark twin under it so the name reads on pale ground
        under = bpy.data.objects.new("under_" + text, curve.copy())
        parent.objects.link(under)
        under.location = (x + size * 0.07, z - size * 0.07, MARK_Y - 1.0)
        under.data.materials.clear()
        under.data.materials.append(bpy.data.materials["dv2_dark"])
        under.visible_shadow = False
    return obj


def report(meshes):
    layers = {}
    per = {}
    for e in DRESSING:
        n, t = layers.get(e["layer"], (0, 0))
        layers[e["layer"]] = (n + 1, t + tris(meshes[e["name"]]))
        if e["layer"] == "play":
            c = per.get(e["name"], 0)
            per[e["name"]] = c + 1
    sky = sum(tris(meshes["env_city_" + t["kind"]]) + tris(meshes["env_city_" + t["kind"] + "_lit"]) for t in SKYLINE)
    play_parts = [p for p in PARTS]
    part_tris = sum(12 if p[2] == "box" else 8 for p in play_parts)
    used = {e["name"] for e in DRESSING}
    worst = max(used, key=lambda n: tris(meshes[n]))
    print("Delta v2: frame %d x %d" % (2 * HALF, 2 * HALF))
    for key in ("play", "edge"):
        n, t = layers.get(key, (0, 0))
        print("  %-8s %4d mesh instances %7d tris" % (key, n, t))
    print("  skyline  %4d mesh instances %7d tris" % (2 * len(SKYLINE), sky))
    print("  Parts    %4d (%d tris): buildings, ground, roads, paint" % (len(play_parts), part_tris))
    print("  in play total: %d tris; %d distinct meshes; largest %s (%d tris)" % (layers["play"][1] + part_tris, len(used), worst, tris(meshes[worst])))
    for name in sorted(per, key=lambda n: -per[n] * tris(meshes[n])):
        print("    %-24s x%-3d %5d tris each %7d" % (name, per[name], tris(meshes[name]), per[name] * tris(meshes[name])))
    for name in delta_kit.NAMES:
        cls, cap = delta_kit.CAPS[name]
        if name in meshes:
            print("    kit %-22s %5d tris (%s cap %d)%s" % (name, tris(meshes[name]), cls, cap, "" if tris(meshes[name]) <= cap else "  OVER"))
    return layers, part_tris


SOLID = {"block", "bunker", "panel", "sheet", "slab", "roof", "stair", "steel", "plank", "concrete", "sign", "red"}


def _rect(e, mesh):
    """World footprint of an instance: 4 corners (x, z) and its y range."""
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    sc = e.get("scale") or (1, 1, 1)
    a = math.radians(e.get("yaw") or 0.0)
    c, s_ = math.cos(a), math.sin(a)
    pts = [(e["x"] + (lx * c - ly * s_) * sc[0], e["z"] + (lx * s_ + ly * c) * sc[1]) for lx, ly in ((min(xs), min(ys)), (max(xs), min(ys)), (max(xs), max(ys)), (min(xs), max(ys)))]
    y = e.get("y") or 0.0
    return pts, y + min(zs) * sc[2], y + max(zs) * sc[2]


def _sat(pa, pb, tol):
    for poly in (pa, pb):
        for i in range(4):
            ex, ez = poly[(i + 1) % 4][0] - poly[i][0], poly[(i + 1) % 4][1] - poly[i][1]
            n = math.hypot(ex, ez) or 1.0
            ax, az = -ez / n, ex / n
            a = [p[0] * ax + p[1] * az for p in pa]
            b = [p[0] * ax + p[1] * az for p in pb]
            if min(max(a), max(b)) - max(min(a), min(b)) < tol:
                return False
    return True


# Meant contacts: a piece that stands on, hangs off or passes through another by design.
MEANT = {
    frozenset(("env_guard_tower", "env_wall_panel_24")), frozenset(("env_twall", "env_crib_stack")),
    frozenset(("env_catwalk_12",)), frozenset(("env_twall",)), frozenset(("env_wall_panel_24",)), frozenset(("env_hesco_row_24",)),
    frozenset(("prop_chainlink_panel",)), frozenset(("env_barrier_jersey",)), frozenset(("prop_body_bag",)),
    frozenset(("env_screening_tent", "prop_table_folding")), frozenset(("env_screening_tent", "prop_table_flipped")),
    frozenset(("env_screening_tent", "prop_cot")), frozenset(("env_screening_tent", "prop_humvee")),  # an open frame tent: what stands under it
}


def check(meshes, tol=0.3):
    """The owner's rule: no piece inside another. Every play instance against every other and
    against every solid Part (footprints as rotated boxes, heights as ranges). Rolled pieces
    (fallen walls) are skipped. Prints what it finds; the list should be empty or explained."""
    items = []
    for e in DRESSING:
        if e["layer"] != "play" or e.get("roll") or e["name"] == "env_sign_gantry":  # the gantry spans the road
            continue
        pts, y0, y1 = _rect(e, meshes[e["name"]])
        items.append((e, pts, y0, y1))
    found = []
    for i in range(len(items)):
        ea, pa, a0, a1 = items[i]
        for j in range(i + 1, len(items)):
            eb, pb, b0, b1 = items[j]
            if min(a1, b1) - max(a0, b0) < tol or frozenset((ea["name"], eb["name"])) in MEANT:
                continue
            if abs(ea["x"] - eb["x"]) > 60 or abs(ea["z"] - eb["z"]) > 60:
                continue
            if _sat(pa, pb, tol):
                found.append("%s (%.0f, %.0f) in %s (%.0f, %.0f)" % (ea["name"], ea["x"], ea["z"], eb["name"], eb["x"], eb["z"]))
    for g, kind, shape, (x0, x1, y0, y1, z0, z1), up in PARTS:
        if kind not in SOLID or g in ("Ground", "Roads"):
            continue
        pb = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        for e, pa, a0, a1 in items:
            if e["name"] in ("env_stair_steel_9", "env_stair_steel_12", "env_catwalk_12") and kind == "steel":
                continue  # a landing or a post under its own stair or walk
            if min(a1, y1) - max(a0, y0) < tol:
                continue
            if shape == "wedge" and a0 >= y0 + (y1 - y0) * 0.0 and e.get("y", 0) >= y1 - 0.01:
                continue
            if _sat(pa, pb, tol):
                found.append("%s (%.0f, %.0f, y %.1f) in Part %s/%s x %.0f..%.0f z %.0f..%.0f y %.1f..%.1f" % (e["name"], e["x"], e["z"], a0, g, kind, x0, x1, z0, z1, y0, y1))
    print("overlap check: %d" % len(found))
    for line in found:
        print("  " + line)
    return found


ROOT = "Dv2"


def build():
    """The proposal, in collection Dv2 of scene Delta_v2."""
    sc = scene()
    clear(ROOT)
    layout()
    mats = materials()
    pal = palette()
    root = col(ROOT, sc=sc)
    c_parts = col("Dv2_Parts", root)
    c_dress = col("Dv2_Dressing", root)
    c_edge = col("Dv2_Edge", root)
    c_sky = col("Dv2_Skyline", root)
    c_marks = col("Dv2_Marks", root)
    c_marks.hide_render = True
    c_marks.hide_viewport = True
    parts_to_meshes(PARTS, c_parts, mats, "dv2_")
    names = {e["name"] for e in DRESSING} | set(delta_kit.NAMES)
    for t in SKYLINE:
        names |= {"env_city_" + t["kind"], "env_city_" + t["kind"] + "_lit"}
    meshes = build_kit(names, pal, "Dv2_Kit")
    tower = hazed(pal)
    for e in DRESSING:
        obj = place(e, meshes[e["name"]], c_dress if e["layer"] == "play" else c_edge)
        if e["name"] == "env_far_hill":  # the game's Atmosphere fades anything this far out
            obj.material_slots[0].link = "OBJECT"
            obj.material_slots[0].material = tower
    for t in SKYLINE:
        for suffix in ("", "_lit"):
            obj = place({"name": "sky_" + t["kind"] + suffix, "x": t["x"], "z": t["z"], "yaw": t["yaw"], "scale": (t["scale"],) * 3}, meshes["env_city_" + t["kind"] + suffix], c_sky)
            obj.material_slots[0].link = "OBJECT"
            obj.material_slots[0].material = tower if not suffix else (mats["fire"] if t["burning"] else mats["lit"])
    for name, (c, size) in SITES.items():
        _frame(c_marks, "Zone " + name, c, size, mats["zone"])
        _label(c_marks, name, c[0], c[2] - size[1] / 2 - 13, mats["zone"])
    for name, c in PADS.items():
        _label(c_marks, name, c[0], c[2] - 30, mats["mark"])
    for name, (x, z) in LABELS.items():
        _label(c_marks, name, x, z, mats["mark"], size=13.0 if name.isupper() else 10.0)
    for name, (x, z) in ENTRIES.items():
        _label(c_marks, name, max(-262, min(262, x)), max(-284, min(280, z)) + (10 if z < 0 else -14), mats["entry"], size=9.0)
        _frame(c_marks, "Entry " + name, (x, 0, z), (14, 14), mats["entry"], t=3.0)
    report(meshes)
    return meshes


# ------------------------------------------------------------------ today's Delta, as a true "before"
TODAY = "Dv2_Today"


def build_today():
    """Today's Checkpoint Delta from the game's own tables (Missions/Delta.luau through
    delta_map), in collection Dv2_Today of the same scene, hidden until a "before" is rendered.
    Buildings are boxes of the right size (the game builds them from Parts with doors, windows
    and stairs); every mesh is the real one."""
    sc = scene()
    clear(TODAY)
    mats = materials()
    pal = palette()
    root = col(TODAY, sc=sc)
    lay = dm.load_layout()
    real = dm.collection
    dm.collection = lambda name, parent=None: col("Today_" + name, root)
    try:
        dm.build_terrain(lay)
    finally:
        dm.collection = real
    by_color = {}
    kind_of = {tuple(round(c, 3) for c in v): k for k, v in dm.KIND_COLORS.items()}
    remap = {"hill": "dust", "slope": "mud", "road": "road", "concrete": "concrete", "building": "block", "ramp": "plank", "steel": "steel", "patch": "mud", "wall": "concrete"}
    for c in root.children_recursive:
        for o in c.objects:
            k = remap.get(kind_of.get(tuple(round(v, 3) for v in o.color), "hill"), "dust")
            o.data.materials.append(mats[k])
    entries = lay["dressing"] + lay["props"] + lay["generated"] + lay["perimeter"]
    names = {e["name"] for e in entries}
    kinds = ("office", "residential", "deco", "glass", "ruined", "midrise")
    names |= {"env_city_" + k + s for k in kinds for s in ("", "_lit")}
    meshes = build_kit({n for n in names if n in ba.ASSETS}, pal, "Dv2_Kit")
    c_dress = col("Today_Meshes", root)
    count, total, per = 0, 0, {}
    for e in entries:
        me = meshes.get(e["name"])
        if me is None:
            continue
        floor = e.get("floor")
        gy = floor if floor is not None else dm.ground_height(lay["hills"], e["x"], e["z"])
        obj = bpy.data.objects.new(e["name"], me)
        c_dress.objects.link(obj)
        obj.location = (e["x"], e["z"], gy + (e.get("lift") or 0))
        obj.rotation_euler = (0, 0, math.radians(-(e.get("yaw") or 0)))
        if not e.get("decor"):
            count += 1
            total += tris(me)
            per[e["name"]] = per.get(e["name"], 0) + 1
    # the perimeter fence: one chain-link panel and one wire coil every 12 studs (ArenaService.FENCE)
    fence = 0
    for k in range(50):
        along = -294 + 12 * k
        for x, z, yaw in ((along, 299.6, 0), (along, -299.6, 0), (299.6, along, 90), (-299.6, along, 90)):
            if yaw == 90 and -73 < along < -17:
                continue
            fence += 1
    fence_tris = fence * (tris(meshes["prop_chainlink_panel"]) + tris(meshes["prop_concertina"]))
    # the skyline (SkyService.SKYLINE): 23 towers all round
    text = open(os.path.join(dm.ROOT, "src", "server", "SkyService.luau"), encoding="utf-8").read()
    sky, *_ = dm.read_table(text, "SKYLINE")
    tower = hazed(pal)
    c_sky = col("Today_Skyline", root)
    sky_tris = 0
    for i, t in enumerate(sky):
        a = math.radians(t["a"])
        for suffix in ("", "_lit"):
            me = meshes["env_city_" + t["kind"] + suffix]
            sky_tris += tris(me)
            obj = place({"name": "sky", "x": math.cos(a) * t["d"], "z": math.sin(a) * t["d"], "yaw": math.degrees(math.atan2(-math.sin(a), -math.cos(a))) + 90, "scale": (t["s"],) * 3}, me, c_sky)
            obj.material_slots[0].link = "OBJECT"
            obj.material_slots[0].material = tower if not suffix else (mats["fire"] if t.get("smoke") else mats["lit"])
    blockout = sum(len(c.objects) for c in root.children_recursive if c.name not in ("Today_Meshes", "Today_Skyline"))
    worst = max(per, key=lambda n: tris(meshes[n]))
    print("Delta today: frame 600 x 600")
    print("  play     %4d mesh instances %7d tris (+ fence %d panels and coils, %d tris)" % (count, total, fence, fence_tris))
    print("  skyline  %4d mesh instances %7d tris" % (2 * len(sky), sky_tris))
    print("  blockout Parts here: %d (the game's own Part count is higher: its buildings are walls, slabs and stairs)" % blockout)
    print("  in play total (meshes + fence): %d tris; %d distinct meshes; largest %s (%d tris)" % (total + fence_tris, len(per), worst, tris(meshes[worst])))
    for name in sorted(per, key=lambda n: -per[n] * tris(meshes[n]))[:14]:
        print("    %-24s x%-3d %5d tris each %7d" % (name, per[name], tris(meshes[name]), per[name] * tris(meshes[name])))
    return meshes


def show(which="v2"):
    """Which map the viewport and the renders show: "v2" or "today"."""
    for name, on in ((ROOT, which == "v2"), (TODAY, which == "today")):
        c = bpy.data.collections.get(name)
        if c is not None:
            c.hide_viewport = not on
            c.hide_render = not on


# ------------------------------------------------------------------ previews
# name: (eye, look-at, lens). Eye-level shots stand EYE above the floor there.
VIEWS = {
    "delta_v2_oblique": ((-250, 230, -420), (0, 0, -30), 26),
    "delta_v2_oblique_ne": ((330, 190, 380), (20, 0, 0), 26),
    "delta_v2_gate_approach": ((10, EYE, -262), (2, 12, GATE_Z), 24),  # the Warden's road, looking at the Gate
    "delta_v2_gate_walk": ((-4, DECK + EYE, GATE_Z), (20, 4, -260), 20),  # on the Gatehouse walk, looking at the city
    "delta_v2_gate_inside": ((6, EYE, -24), (0, 10, GATE_Z), 24),  # the Yard, looking back at the Gate
    "delta_v2_screening": ((-30, EYE, -200), (-110, 6, -176), 20),  # the Screening Lot from the queue
    "delta_v2_pens": ((-170, EYE, -204), (-240, 4, -204), 20),  # the Pens from its east mouth
    "delta_v2_buspark": ((34, EYE, -224), (110, 6, -190), 20),
    "delta_v2_yard_north": ((0, EYE, -96), (-10, 12, 60), 22),  # through the Gate, the base ahead
    "delta_v2_barracks": ((-160, EYE, -50), (-230, 8, -50), 20),  # the court between the blocks
    "delta_v2_command": ((-26, EYE, 134), (-86, 14, 78), 20),  # Command Post and the Mast from the highway
    "delta_v2_mast": ((-66, 9 + EYE, 97), (60, 4, 30), 20),  # on the Mast plinth, looking over the Yard
    "delta_v2_lz": ((-190, EYE, 200), (-90, 14, 110), 20),  # standing on the main pad
    "delta_v2_bridge": ((-36, DECK + EYE, 21), (100, DECK + 4, 21), 20),  # on the service bridge, east
    "delta_v2_overlook": ((136, DECK + EYE, 22), (204, 6, -50), 20),  # the Motor Pool deck over the Stacks
    "delta_v2_stacks": ((182, EYE, -36), (204, 10, -80), 20),  # an aisle in the Stacks
    "delta_v2_shed": ((201, EYE, 40), (201, 6, 100), 20),  # the loading dock ramp
    "delta_v2_channel": ((270, CH_Y + EYE, 90), (270, CH_Y + 4, -120), 20),  # in the channel
    "delta_v2_altpad": ((150, EYE, 216), (60, 12, 60), 20),  # standing on the alt pad
    "delta_v2_cp_window": ((-59.4, 18 + EYE, 60), (10, 0, -70), 18),  # CP second floor, east window: the Warden walk
}
# Before / after from the same camera, and the same job seen in each map.
PAIRS = {
    "oblique": ((-250, 230, -420), (0, 0, -30), 26),
    "oblique_ne": ((330, 190, 380), (20, 0, 0), 26),
}
TODAY_VIEWS = {  # the same jobs in today's map (docs/LEVELS.md A2)
    "pad": ((-90, 0.6 + EYE, -90), (20, 10, 20), 20),  # standing on the LZ
    "gate": ((-30, EYE, -200), (-30, 10, -274), 24),  # the main road, looking at the Gate
    "depot": ((150, EYE, 30), (230, 8, 40), 20),  # the Depot from its west edge
    "pens": ((-200, 6 + EYE, 120), (-260, 8, 120), 20),  # the Pens from its east mouth
    "comm": ((0, EYE, 0), (94, 30, 94), 20),  # the comm tower from the Apron
    "mainstreet": ((-30, EYE, -100), (-30, 8, 60), 22),  # the main road north from the Inner Gate
}
V2_JOBS = {  # the after of each: the same job in v2
    "pad": "delta_v2_lz", "gate": "delta_v2_gate_approach", "depot": "delta_v2_overlook", "pens": "delta_v2_pens",
    "comm": "delta_v2_command", "mainstreet": "delta_v2_yard_north",
}


def _look_at(cam, eye, target):
    cam.location = (eye[0], eye[2], eye[1])
    cam.rotation_euler = (Vector((target[0], target[2], target[1])) - cam.location).to_track_quat("-Z", "Y").to_euler()


def setup_look(sc):
    """The mission's evening: a low sun through smoke (docs/STYLES.md §7), for judging shapes."""
    world = bpy.data.worlds.get("dv2_evening") or bpy.data.worlds.new("dv2_evening")
    sc.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = HAZE + (1,)
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.get("dv2_sun")
    if sun is None:
        sun = bpy.data.objects.new("dv2_sun", bpy.data.lights.new("dv2_sun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 3.0
    sun.data.color = (1.0, 0.80, 0.62)
    sun.rotation_euler = (math.radians(58), 0, math.radians(-128))
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    return sun


def camera(sc):
    cam = bpy.data.objects.get("dv2_cam")
    if cam is None:
        cam = bpy.data.objects.new("dv2_cam", bpy.data.cameras.new("dv2_cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.clip_start = 0.5
    cam.data.clip_end = 8000
    return cam


def aim(name=None, eye=None, target=None, lens=22, size=(1600, 900)):
    """Point the scene camera (for `look` in live Blender): a VIEWS name or an eye and a target."""
    sc = scene()
    setup_look(sc)
    cam = camera(sc)
    if name is not None:
        eye, target, lens = VIEWS[name]
    cam.data.type = "PERSP"
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = size
    _look_at(cam, eye, target)
    return cam


def aim_top(center=(0, 0), span=660, size=(1600, 1600)):
    sc = scene()
    setup_look(sc)
    cam = camera(sc)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span
    cam.location = (center[0], center[1], 900)
    cam.rotation_euler = (0, 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = size
    return cam


def _shot(sc, name):
    sc.render.filepath = os.path.join(PREVIEWS, name + ".png")
    bpy.ops.render.render(write_still=True, scene=sc.name)


def render_some(names, folder, size=(960, 540)):
    """Quick looks while designing: VIEWS by name into `folder`."""
    sc = scene()
    for name in names:
        aim(name, size=size)
        sc.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True, scene=sc.name)


def render_previews():
    os.makedirs(PREVIEWS, exist_ok=True)
    sc = scene()
    marks = bpy.data.collections.get("Dv2_Marks")
    show("v2")
    for name in VIEWS:
        aim(name)
        _shot(sc, name)
    aim_top()
    marks.hide_render = False
    _shot(sc, "delta_v2_topdown")
    marks.hide_render = True
    _shot(sc, "delta_v2_topdown_clean")
    if bpy.data.collections.get(TODAY) is not None:
        for key, (eye, target, lens) in PAIRS.items():
            for which in ("today", "v2"):
                show(which)
                aim(eye=eye, target=target, lens=lens)
                _shot(sc, "delta_v2_pair_%s_%s" % (key, "before" if which == "today" else "after"))
        for which in ("today", "v2"):
            show(which)
            aim_top()
            _shot(sc, "delta_v2_pair_topdown_%s" % ("before" if which == "today" else "after"))
        show("today")
        for key, (eye, target, lens) in TODAY_VIEWS.items():
            aim(eye=eye, target=target, lens=lens)
            _shot(sc, "delta_v2_pair_%s_before" % key)
        show("v2")
        for key, view in V2_JOBS.items():
            aim(view)
            _shot(sc, "delta_v2_pair_%s_after" % key)
    show("v2")
    vehicle_sheet()
    aim("delta_v2_oblique")


SHEET = (  # (old, new) left to right; None = no old one
    ("env_wreck_humvee", "prop_humvee_burnt"), (None, "prop_humvee"), ("env_bus", "prop_bus"),
    (None, "prop_ambulance"), (None, "prop_car_suv"), ("prop_car_sedan", None), ("prop_car_hatch", None),
    ("prop_car_pickup", None), ("prop_car_van", None), ("prop_cargo_truck", None),
)


def vehicle_sheet(render=True):
    """Old against new, with the 5-stud figure: back row = today's, front row = this proposal's
    (kept pieces stand in the front row alone)."""
    sc = scene()
    clear("Dv2_Sheet")
    mats = materials()
    pal = palette()
    c = col("Dv2_Sheet", sc=sc)
    names = {n for pair in SHEET for n in pair if n}
    meshes = build_kit(names, pal, "Dv2_Kit")
    ox, oz = 0.0, 3000.0  # far from the map
    width = 0.0
    for r, slots in enumerate((SHEET[:5], SHEET[5:])):  # back row: rebuilt and new; front row: kept
        x = 0.0
        z0 = 62.0 if r == 0 else 0.0
        for old, new in slots:
            w = 46.0 if "bus" in (new or old) else 30.0
            for name, zz in (((old, 24.0), (new, 0.0)) if old and new else (((new or old), 0.0),)):
                place({"name": name, "x": ox + x + w / 2, "z": oz + z0 + zz, "yaw": 0}, meshes[name], c)
                tag = "today" if (name == old and new) else ("kept" if name == old else "new")
                lab = _label(c, "%s  %d tris  (%s)" % (name, tris(meshes[name]), tag), ox + x + w / 2, oz + z0 + zz - 8.0, mats["mark"], size=1.9)
                lab.location.z = 0.05
            fig = dm.box("ref_5_stud", c, "warn", (ox + x + 2.0, 2.5, oz + z0 - 2), (2, 5, 1))
            fig.data.materials.append(mats["zone"])
            x += w
        width = max(width, x)
    x = width
    floor = dm.box("sheet_floor", c, "road", (ox + x / 2, -0.5, oz + 40), (x + 200, 1, 400))
    floor.data.materials.append(mats["concrete_d"])
    for name in ("Dv2", TODAY):
        cc = bpy.data.collections.get(name)
        if cc is not None:
            cc.hide_render = True
    setup_look(sc)
    cam = camera(sc)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = x + 10
    sc.render.resolution_x, sc.render.resolution_y = 2400, 1500
    _look_at(cam, (ox + x / 2, 150, oz - 170), (ox + x / 2, 3, oz + 40))
    if render:
        _shot(sc, "delta_v2_vehicles")
    c.hide_render = True
    show("v2")
    return meshes


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if bpy.app.background:
        bpy.ops.wm.read_homefile(use_empty=True)
    build()
    build_today()
    if "--no-render" not in argv:
        render_previews()
    show("v2")
    if bpy.app.background:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
        print("saved", BLEND)
