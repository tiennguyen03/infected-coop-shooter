"""The Carrier v2 in Blender: a PROPOSAL the owner looks at before anything goes in the game.

Owner, 2026-11-16: "revamp the lobby map in Blender. Don't completely change it, just revamp it.
Make it feel more like a ship... right now the Carrier seems too plain... on the shore it should
show a destroyed city with burning skyscrapers... little Easter eggs on the ship." Nothing here is
loaded by the game. docs/sprints/CARRIER_V2.md has the diagnosis, the design notes, the Easter egg
list and the step list.

Two ships in one scene (`Carrier_v2`), from the same tables:
  * `today()`  the lobby as the code builds it now (src/lobby/server/FallowLayout, FallowBuilder,
    FallowArt, DeskService, LaunchService, with fallow.py's and lantern.py's meshes): the "before".
  * `v2()`     the same hull, deck, island, ramp, desks and helicopter spots, dressed as a working
    warship, with the burning city on the shore off the side away from the island.

Coordinates are the game's (FallowLayout): x toward the island side, y up, z toward the bow; deck
y 40, hangar floor y 20, sea y 0. Blender X = x, Blender Y = z, Blender Z = y (as fallow.py), so
these pictures are the mirror image of the game left to right, like every earlier ship preview.
Plain boxes are Parts (`B`), repeated detail is a kit mesh placed as a linked instance (`D`),
lettering is a text object (a SurfaceGui in game).

Live Blender (the owner's way: look at it):
    import carrier_v2; carrier_v2.build_all()
Headless (writes assets/3d/carrier_v2.blend and build/previews/carrier_v2_*.png):
    blender --background --python assets/3d/build/carrier_v2.py
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
import carrier_kit  # noqa: E402
import lantern  # noqa: E402

carrier_kit.register(ba, npcs=True)

ROOT_DIR = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BLEND = os.path.join(ROOT_DIR, "assets", "3d", "carrier_v2.blend")
PREVIEWS = os.path.join(HERE, "previews")
SCENE = "Carrier_v2"
EYE = 5.0

# ------------------------------------------------------------------ FallowLayout, copied
W, L = 35.0, 180.0
DECK, DB = 40.0, 38.0  # flight deck top and underside
HY = 20.0  # hangar floor
HA, HF = -100.0, 140.0  # hangar bulkheads
WELL = (-30.0, -10.0, 20.0, 80.0)  # x0, x1, z0 (ramp top), z1 (ramp foot)
RAMP_SPLIT = 44.0  # v2: the ramp is a solid wedge from here to the foot, a plate above (the hidden nook)
ISLAND = (22.0, 34.0, -10.0, 50.0)
PLOT = (4.0, 33.0, -10.0, 30.0, 6.0, 14.0)  # x0, x1, z0, z1, door z0, door z1
LANE = (19.0, 29.0, -172.0, -136.0)
BALCONY = (-47.0, -35.0, -39.6, -0.4)
SPOTS = [(-12.0, -150.0 + i * 45.0) for i in range(4)]  # spot 1..4, helo centre (x, z)
BIRDS = (22, 24, 21, 23)  # Config.Lobby.Lantern.BirdNumbers
SPAWN = (0.0, 125.0)
DESKS = {  # id: (feet x, z, facing x, z)
    "arms_room": (-26, 124, 1, 0),
    "engineers": (27, 105, -1, 0),
    "loadmaster": (-2, 88, 0, 1),
    "fires": (1, 18, -1, 0),
    "plot": (26.8, -3, -1, 0),
}
CATWALKS = (
    (1, -124, 0), (1, -100, 1), (1, -76, 0), (1, -52, 0), (1, -28, 1), (1, 66, 0), (1, 90, 0), (1, 114, 1),
    (-1, -133, 0), (-1, -109, 1), (-1, -85, 0), (-1, -61, 0), (-1, 12, 1), (-1, 36, 0), (-1, 60, 0),
    (-1, 84, 1), (-1, 108, 0), (-1, 132, 0),
)
COAST_Z = 900.0
BURN_SITES = (-900, -560, -230, 120, 450, 820)
CITY_X = -560.0  # v2: the city's quay, off the side away from the island

# ------------------------------------------------------------------ colours (sRGB 0-255, emit)
KINDS = {
    "hull": ((70, 74, 78), 0), "deck": ((50, 52, 55), 0), "floor": ((64, 66, 68), 0),
    "wall": ((96, 100, 102), 0), "wall_lo": ((62, 68, 72), 0), "wall_hi": ((146, 152, 154), 0),
    "steel": ((104, 110, 114), 0), "plot": ((40, 40, 42), 0), "paint": ((214, 214, 208), 0),
    "yellow": ((230, 189, 96), 0), "black": ((26, 28, 30), 0), "red": ((185, 52, 52), 0),
    "concrete": ((122, 120, 114), 0), "crate": ((90, 96, 62), 0), "counter": ((72, 66, 56), 0),
    "wood": ((158, 131, 90), 0), "felt": ((40, 62, 48), 0), "gunmetal": ((36, 38, 42), 0),
    "mat": ((38, 40, 42), 0), "paper": ((208, 200, 176), 0), "lamp": ((200, 198, 186), 0),
    "sea": ((30, 46, 52), 0), "sand": ((150, 138, 110), 0), "grass": ((74, 86, 60), 0),
    "rock": ((88, 86, 82), 0), "burnt": ((30, 27, 26), 0), "quay": ((66, 64, 60), 0),
    "glass": ((120, 150, 160), 0), "wire": ((120, 124, 126), 0),
    "sodium": ((255, 204, 150), 3.0), "flood": ((255, 226, 190), 3.0), "redlamp": ((255, 60, 50), 4.0),
    "fire": ((255, 96, 24), 1.6), "glow": ((255, 110, 40), 0.9), "glow2": ((200, 90, 56), 0.6), "glow3": ((150, 84, 70), 0.5), "ember": ((255, 60, 18), 2.5), "chem": ((120, 255, 150), 4.0),
    "scope": ((90, 230, 120), 2.5), "board": ((70, 100, 112), 0.5), "window": ((255, 214, 150), 5.0),
    "label": ((255, 236, 150), 2.0), "label_d": ((10, 10, 10), 0),
    # each vendor corner's own light (docs/sprints/CARRIER_V2.md > Vendor corners)
    "tungsten": ((255, 178, 102), 3.0), "amber": ((255, 140, 50), 3.0), "cabin": ((110, 170, 255), 3.0),
    "worklamp": ((236, 244, 255), 3.0), "cold": ((170, 214, 226), 3.0), "card": ((236, 196, 120), 0.0),
    "sky": ((120, 170, 210), 0.0), "cage": ((52, 56, 58), 0.0),
}
ALPHA = {"glass": 0.35, "wire": 0.45, "cage": 0.32, "glow": 0.6, "glow2": 0.34, "glow3": 0.16}
HAZE = (0.33, 0.36, 0.40)


# ------------------------------------------------------------------ a set: one version of the lobby
class Set:
    def __init__(self, name):
        self.name = name
        self.parts = []  # (group, kind, shape, dims)
        self.dress = []  # kit instances
        self.texts = []
        self.lights = []
        self.labels = []  # (text, x, z, level)

    def B(self, g, kind, x0, x1, y0, y1, z0, z1):
        if x1 - x0 > 0.005 and y1 - y0 > 0.005 and z1 - z0 > 0.005:
            self.parts.append((g, kind, "box", (x0, x1, y0, y1, z0, z1)))

    def ramp(self, g, kind, x0, x1, y0, y1, z0, z1):
        """A WedgePart: full height at z0, down to nothing at z1."""
        self.parts.append((g, kind, "ramp", (x0, x1, y0, y1, z0, z1)))

    def bar(self, g, kind, p0, p1, w, h):
        """A Part turned to lie between two points (a sloped rail)."""
        self.parts.append((g, kind, "bar", (p0, p1, w, h)))

    def disc(self, g, kind, x, z, r, y0, y1, r_in=0.0):
        """A Cylinder Part on its flat (a painted circle); r_in > 0 draws the ring only."""
        self.parts.append((g, kind, "disc", (x, z, r, y0, y1, r_in)))

    def T(self, g, text, pos, size, face="up", kind="paint", yaw=0.0):
        self.texts.append((g, text, pos, size, face, kind, yaw))

    def D(self, name, x, y, z, yaw=0.0, scale=None, layer="ship", mat=None, tilt=0.0, export=True):
        self.dress.append({"name": name, "x": x, "y": y, "z": z, "yaw": yaw, "scale": scale, "layer": layer, "mat": mat, "tilt": tilt, "export": export})

    def light(self, x, y, z, kind, power, spot=False):
        self.lights.append((x, y, z, kind, power, spot))

    def stripes(self, g, x0, x1, y0, y1, z0, z1, n, axis="x"):
        """Hazard paint: n alternating yellow and black bands along x or z. One piece (in game one
        flat palette mesh a run, two triangles a band; not n Parts)."""
        self.parts.append((g, "yellow", "stripes", (x0, x1, y0, y1, z0, z1, n, axis)))

    def wall_x(self, g, kind, x0, x1, y0, y1, z0, z1, openings=()):
        """A wall running along z (thickness x0..x1) with openings (z0, z1, sill, head)."""
        cur = z0
        for o0, o1, sill, head in sorted(openings):
            self.B(g, kind, x0, x1, y0, y1, cur, o0)
            self.B(g, kind, x0, x1, y0, sill, o0, o1)
            self.B(g, kind, x0, x1, head, y1, o0, o1)
            cur = o1
        self.B(g, kind, x0, x1, y0, y1, cur, z1)


# ------------------------------------------------------------------ what both ships share
def figure(s, x, y, z):
    s.D("ref_human_5st", x, y, z, layer="crew")


def birds(s, tie=False):
    for i, (x, z) in enumerate(SPOTS):
        for name in ("veh_lantern_body", "veh_lantern_trim"):
            s.D(name, x, DECK, z)
        s.D("veh_lantern_rotor", x + lantern.HUB[0], DECK + lantern.HUB[1], z + lantern.HUB[2], yaw=20 + i * 37)
        s.D("veh_lantern_tail_rotor", x + lantern.TAIL_HUB[0], DECK + lantern.TAIL_HUB[1], z + lantern.TAIL_HUB[2])
        s.T("spots", str(BIRDS[i]), (x + 4.0, DECK + 6.3, z + 8.6), 1.3, "+x", "paint")
        figure(s, x + 4.6, DECK + 2.0, z - 3.0)  # the crew chief in the door
        if tie:
            for sx in (-1, 1):
                for dz in (-5.5, 3.5):
                    s.D("env_carrier_tiedown", x + sx * 6.4, DECK, z + dz, yaw=180 if sx > 0 else 0)
            s.D("env_carrier_chock", x + 3.2, DECK, z + 6.5, yaw=90)
            s.D("env_carrier_chock", x - 3.2, DECK, z + 6.5, yaw=90)


def hull_art(s):
    for name in ("bow", "bow_trim", "mid_port", "mid_stbd", "mid_trim", "stern", "stern_trim", "island", "island_trim"):
        s.D("env_fallow_" + name, 0, 0, 0)
    s.D("env_fallow_radar", 31, 92, 44.5, yaw=25)
    for side, z, rafts in CATWALKS:
        s.D("env_fallow_catwalk_rafts" if rafts else "env_fallow_catwalk", side * 35.0, DECK, z, yaw=0 if side > 0 else 180)


def deck_slabs(s, hollow=False):
    x0, x1, z0, z1 = WELL
    s.B("deck", "deck", -W, W, DB, DECK, -L, z0)
    s.B("deck", "deck", -W, x0, DB, DECK, z0, z1)
    s.B("deck", "deck", x1, W, DB, DECK, z0, z1)
    s.B("deck", "deck", -W, W, DB, DECK, z1, L + 30)
    if hollow:  # v2: a plate over the top third, the hidden nook under it (hangar_life_v2)
        yc = HY + (DECK - HY) * (z1 - RAMP_SPLIT) / (z1 - z0)
        s.ramp("deck", "floor", x0, x1, HY, yc, RAMP_SPLIT, z1)
        xm = (x0 + x1) / 2
        s.bar("deck", "floor", (xm, DECK - 0.32, z0), (xm, yc - 0.32, RAMP_SPLIT), x1 - x0, 0.6)
    else:
        s.ramp("deck", "floor", x0, x1, HY, DECK, z0, z1)
    s.B("hangar", "floor", -W + 2, W - 2, HY - 0.2, HY, HA, HF)
    s.B("hangar", "hull", -W + 2, W - 2, HY, DB, HA - 1, HA)  # aft bulkhead (AftSpaces' face)
    s.B("hangar", "hull", -W + 2, W - 2, HY, DB, HF, HF + 1)  # fore bulkhead
    b = BALCONY
    s.B("balcony", "floor", b[0], b[1], HY - 0.6, HY, b[2], b[3])
    # deck-edge lines and the painted-out deck number at the bow (FallowArt)
    lane, isl = LANE, ISLAND
    s.B("marks_v1", "paint", -W + 0.9, -W + 1.5, DECK, DECK + 0.05, -180, 210)
    for a, c in ((-180, lane[2]), (lane[3], isl[2]), (isl[3], 210)):
        s.B("marks_v1", "paint", W - 1.5, W - 0.9, DECK, DECK + 0.05, a, c)
    s.B("marks_v1", "black", -14, 14, DECK, DECK + 0.03, 186, 204)
    s.T("marks_v1", "HARLAN", (0, DECK + 0.06, 195), 9.0, "up", "paint", yaw=180)
    s.B("marks_v1", "steel", 21.8, 22.0, DECK + 5, DECK + 17, 6, 34)
    s.T("marks_v1", "HARLAN", (21.75, DECK + 11, 20), 6.5, "-x", "paint")
    # the screening lane (scenery)
    for x in (lane[0], lane[1]):
        s.B("lane", "concrete", x - 0.6, x + 0.6, DECK, DECK + 2.5, lane[2], lane[3])
    az = (lane[2] + lane[3]) / 2
    for x in (lane[0] + 1, lane[1] - 1):
        s.B("lane", "hull", x - 0.4, x + 0.4, DECK, DECK + 9, az - 0.4, az + 0.4)
    s.B("lane", "black", lane[0], lane[1], DECK + 8, DECK + 10, az - 0.2, az + 0.2)
    s.T("lane", "SCREENING", ((lane[0] + lane[1]) / 2, DECK + 9, az + 0.25), 1.5, "+z", "yellow")


def plot_room(s, v2):
    x0, x1, z0, z1, d0, d1 = PLOT
    if not v2:  # v2: no walls (owner 2026-11-17: "too awkward to walk in and out of... cramped")
        s.wall_x("plot", "plot", x0, x0 + 1, HY, DB, z0, d0)
        s.B("plot", "plot", x0, x0 + 1, HY, DB, d1, z1)
        s.B("plot", "plot", x0, x0 + 1, HY + 10, DB, d0, d1)
        s.B("plot", "plot", x0 + 1, x1, HY, DB, z0, z0 + 1)
        s.B("plot", "plot", x0 + 1, x1, HY, DB, z1 - 1, z1)
    # the map table (WorldMap: 9.8 x 14 of paper on an 11.4 x 15.6 table) and the board
    s.B("plot", "counter", 13.3, 24.7, HY + 2.6, HY + 3.1, -7.8, 7.8)
    for x in (13.8, 24.2):
        for z in (-7.3, 7.3):
            s.B("plot", "counter", x - 0.25, x + 0.25, HY, HY + 2.6, z - 0.25, z + 0.25)
    s.B("plot", "paper", 14.1, 23.9, HY + 3.1, HY + 3.14, -7.0, 7.0)
    for a, c, k in ((16, 16.3, "red"), (19, 19.2, "black"), (21.5, 21.7, "glass")):
        s.B("plot", k, a, c, HY + 3.14, HY + 3.17, -6.2, 6.0)
    s.B("plot", "board", 29.3, 29.7, HY + 2, HY + 12, -6, 26)
    for i in range(5):
        s.B("plot", "black", 29.2, 29.3, HY + 2, HY + 12, -6 + i * 6.4 + 6.2, -6 + i * 6.4 + 6.4)
    if not v2:
        figure(s, 26.8, HY, -3)
    s.B("plot", "redlamp", (x0 + x1) / 2 - 1, (x0 + x1) / 2 + 1, DB - 0.7, DB - 0.3, 9, 11)
    s.B("plot", "lamp", 17.5, 20.5, DB - 0.2, DB - 0.02, -1.5, 1.5)
    s.light((x0 + x1) / 2, DB - 2, 10, "redlamp", 2600)
    s.light(19, DB - 3, 0, "flood", 1500, spot=True)


def sea_and_north(s, north=True):
    s.B("sea", "sea", -2560, 2560, -2, 0, -2560, COAST_Z if north else 2560)
    if not north:  # v2: the city stands where the hills were (shore_v2)
        return
    s.B("north", "sand", -2560, 2560, -2, 2.5, COAST_Z - 30, COAST_Z)
    s.B("north", "grass", -2560, 2560, -2, 9, COAST_Z, COAST_Z + 800)
    for x in BURN_SITES:
        s.B("north", "burnt", x - 90, x + 90, 9, 9.4, COAST_Z + 8, COAST_Z + 70)
        s.B("north", "fire", x - 60, x + 60, 9.4, 24, COAST_Z + 24, COAST_Z + 30)
        s.D("fx_smoke", x, 20, COAST_Z + 30, scale=(1.6, 1.6, 1.6), layer="fx")
    rnd = random.Random(7)
    for i in range(40):
        r = rnd.uniform(45, 110)
        x = -2560 + (i + 0.5) * 128 + rnd.uniform(-38, 38)
        s.D("fx_hill_rock" if rnd.random() < 0.3 else "fx_hill", x, rnd.uniform(-r * 0.55, -r * 0.2) + 8, COAST_Z + 60 + r + rnd.uniform(0, 120), scale=(r, r, r), layer="fx")


# ------------------------------------------------------------------ today (the "before")
def today():
    s = Set("today")
    deck_slabs(s)
    hull_art(s)
    birds(s)
    plot_room(s, False)
    sea_and_north(s)
    x0, x1, z0, z1 = WELL
    # hangar sides, one colour floor to deckhead
    s.B("hangar", "wall", W - 2, W, HY - 0.2, DB, HA, HF)
    s.B("hangar", "wall", -W, -W + 2, HY - 0.2, DB, HA, -40)
    s.B("hangar", "wall", -W, -W + 2, HY - 0.2, DB, 0, HF)
    s.B("hangar", "yellow", -W, -W + 2, HY - 0.2, HY, -40, 0)
    for x, z in ((0, 106), (-8, 62), (0, 10)):
        s.B("hangar", "flood", x - 2, x + 2, DB - 1.3, DB - 0.7, z - 0.6, z + 0.6)
        s.light(x, DB - 2.5, z, "flood", 16000)
    s.T("hangar", "HANGAR BAY 1", (0, HY + 11, HA + 0.1), 3.4, "+z", "yellow")
    s.T("plot", "THE PLOT", (3.9, HY + 14, 10), 2.4, "-x", "paint")
    # ramp rails, well rails: solid yellow slabs
    for x in (x0 + 0.3, x1 - 0.3):
        s.bar("deck", "yellow", (x, HY + 1.5, z1), (x, DECK + 1.5, z0), 0.4, 3.0)
    s.B("deck", "yellow", x0, x1, DECK, DECK + 3, z1, z1 + 0.4)
    for x in (x0, x1):
        s.B("deck", "yellow", x - 0.2, x + 0.2, DECK, DECK + 3, z0, z1)
    # the centre line down the spots, two flood poles
    z = -L + 6
    while z <= z0 - 6:
        if not any(z + 6 > sz - 15 and z < sz + 15 for _, sz in SPOTS):
            s.B("marks_v1", "paint", -12.3, -11.7, DECK, DECK + 0.05, z, z + 6)  # FallowBuilder CentreLine
        z += 12
    for z in (-125, -25):
        s.B("deck", "hull", -W + 0.5, -W + 1.5, DECK, DECK + 12, z - 0.5, z + 0.5)
        s.B("deck", "lamp", -W + 0.3, -W + 1.7, DECK + 12, DECK + 13, z - 0.7, z + 0.7)
    # spots: a ring, a number, the boarding box beside the door
    for i, (x, z) in enumerate(SPOTS):
        s.disc("spots", "yellow", x, z, 14.0, DECK + 0.02, DECK + 0.1, r_in=13.2)
        s.B("spots", "yellow", 1 - 6, 1 + 6, DECK + 0.25, DECK + 0.35, z - 6, z + 6)
        s.T("spots", str(i + 1), (x, DECK + 0.3, z + 18), 6.0, "up", "paint", yaw=180)
    # the balcony's solid rails
    b = BALCONY
    s.B("balcony", "yellow", b[0], b[0] + 0.4, HY, HY + 3, b[2], b[3])
    for z in (b[2], b[3] - 0.4):
        s.B("balcony", "yellow", b[0] + 0.4, b[1] - 0.2, HY, HY + 3, z, z + 0.4)
    # desks (DeskService): a figure, a counter, their props
    for did, (fx, fz, dx, dz) in DESKS.items():
        if did != "plot":
            figure(s, fx, HY, fz)
        if did in ("arms_room", "plot"):
            continue
        cx, cz = fx + dx * 2.4, fz + dz * 2.4
        hx, hz = (0.7, 3.5) if dx else (3.5, 0.7)
        s.B("desks", "counter", cx - hx, cx + hx, HY, HY + 3.4, cz - hz, cz + hz)
    for dx_, y, dz_ in ((-5, 0, 5), (-5, 3, 5), (5, 0, 6)):  # the Loadmaster's cases (his frame faces +z)
        s.B("desks", "crate", -2 - dx_ - 2, -2 - dx_ + 2, HY + y, HY + y + 3, 88 - dz_ - 1.5, 88 - dz_ + 1.5)
    for i, off in enumerate((-4.5, -2, 4)):  # the Engineers' wire spools
        s.B("desks", "steel", 27 + 3 + (i + 1) % 2, 27 + 6 + (i + 1) % 2, HY, HY + 3, 105 + off - 1.1, 105 + off + 1.1)
    s.B("desks", "crate", 1 + 1.4, 1 + 2.6, HY + 3.4, HY + 5.0, 18 - 1.2, 18 + 1.2)  # Fires' radio set
    for did, title in (("engineers", "ENGINEERS"), ("loadmaster", "LOADMASTER"), ("fires", "FIRES")):
        fx, fz, dx, dz = DESKS[did]
        s.T("desks", title, (fx + dx * 2.4, HY + 9, fz + dz * 2.4), 1.3, "-x" if dx < 0 else "+z", "yellow")
    s.T("desks", "ARMS ROOM", (-22.2, HY + 9, 124), 1.3, "+x", "yellow")
    arms_room(s, False)
    return s


def arms_room(s, v2):
    """The Quartermaster's corner (ArmsRack): glass counter, the long-gun wall, the wire."""
    s.B("arms", "counter", -24.8, -22.4, HY, HY + 2.2, 116, 132)
    s.B("arms", "felt", -24.6, -22.6, HY + 2.2, HY + 2.5, 116.2, 131.8)
    s.B("arms", "glass", -24.8, -22.4, HY + 2.5, HY + 3.4, 116, 132)
    for i in range(8):
        s.B("arms", "gunmetal", -24.2, -23.0, HY + 2.5, HY + 2.75, 117 + i * 1.8, 118.1 + i * 1.8)
    s.B("arms", "counter", -33.0, -32.75, HY + 1, HY + 10.6, 112.5, 138.5)
    used = 16 if v2 else 7
    for i in range(used):
        r, c = divmod(i, 4)
        y = HY + 9.4 - r * 1.2
        zc = 112.5 + (c + 0.5) * 6.5
        s.B("arms", "gunmetal", -32.75, -32.45, y - 0.25, y + 0.3, zc - 2.3 + (i % 3) * 0.3, zc + 2.3 - (i % 2) * 0.6)
        s.B("arms", "wood" if i % 4 == 1 else "gunmetal", -32.75, -32.5, y - 0.7, y - 0.25, zc - 2.3 + (i % 3) * 0.3, zc - 1.2)
    s.B("arms", "flood", -32.2, -31.6, HY + 11, HY + 11.3, 114, 137)
    top = DB if v2 else HY + 9
    s.B("arms", "wire", -33, -23.6, HY, top, 111 - 0.08, 111 + 0.08)
    for a, c in ((111, 116), (132, 140)):
        s.B("arms", "wire", -23.68, -23.52, HY, top, a, c)
    if v2:
        s.B("arms", "wire", -23.68, -23.52, HY + 10, top, 116, 132)


# ------------------------------------------------------------------ v2
def hangar_v2(s):
    x0, x1, z0, z1 = WELL
    # sides in three coats: dark below, a yellow line, pale above (a real hangar's paint scheme)
    for a, c in ((HA, -40), (0, HF)):
        s.B("hangar", "wall_lo", -W, -W + 2, HY - 0.2, HY + 4.6, a, c)
        s.B("hangar", "yellow", -W, -W + 2, HY + 4.6, HY + 5.0, a, c)
        s.B("hangar", "wall_hi", -W, -W + 2, HY + 5.0, DB, a, c)
    s.B("hangar", "wall_lo", W - 2, W, HY - 0.2, HY + 4.6, HA, HF)
    s.B("hangar", "yellow", W - 2, W, HY + 4.6, HY + 5.0, HA, HF)
    s.B("hangar", "wall_hi", W - 2, W, HY + 5.0, DB, HA, HF)
    s.stripes("hangar", -W, -W + 2, HY - 0.2, HY, -40, 0, 20, axis="z")  # the lift sill
    for z, k in ((HA + 0.0, 1), (HF - 0.0, -1)):  # bulkheads get the same dado
        zz = (z, z + 0.12) if k > 0 else (z - 0.12, z)
        s.B("hangar", "wall_lo", -W + 2, W - 2, HY, HY + 4.6, *zz)
        s.B("hangar", "yellow", -W + 2, W - 2, HY + 4.6, HY + 5.0, *zz)
        s.B("hangar", "wall_hi", -W + 2, W - 2, HY + 5.0, DB, *zz)
    # frames every 12 studs: a rib on each side, a beam under the deck between them
    k = 0
    for z in range(int(HA), int(HF) + 1, 12):
        k += 1
        if HA < z < HF:
            if not (-40 <= z <= 0 or z > 110):
                s.D("env_carrier_rib", -W + 2, HY, z)
            s.D("env_carrier_rib", W - 2, HY, z, yaw=180)
            cuts = []
            if z0 - 1 < z < z1 + 1:
                cuts.append((-W + 2, x1 + 0.3))
            a = -W + 2 + 4.4
            for c0, c1 in sorted(cuts):
                s.B("beams", "steel", a, c0, DB - 1.5, DB, z - 0.35, z + 0.35)
                a = max(a, c1)
            s.B("beams", "steel", a, W - 2 - 4.4, DB - 1.5, DB, z - 0.35, z + 0.35)
    s.B("beams", "steel", 11.6, 12.4, DB - 2.2, DB - 1.5, HA + 0.2, HF - 0.2)  # one fore-and-aft girder
    # services between the frames
    for z in range(int(HA) + 6, int(HF), 12):
        if not (PLOT[2] < z < PLOT[3]):
            s.D("env_carrier_pipes", W - 2, HY, z, yaw=180)
        if not (-42 < z < 2 or z > 108):
            s.D("env_carrier_pipes", -W + 2, HY, z)
    # sodium lamps under the beams; eight of them are real lights in game, the rest Neon
    n = 0
    for z in range(int(HA) + 12, int(HF), 24):
        for x in (-16, 16):
            if x < 0 and z0 - 2 < z < z1 + 2:
                continue
            if x > 0 and PLOT[2] < z < PLOT[3]:
                continue
            s.B("lamps", "black", x - 1.4, x + 1.4, DB - 2.2, DB - 1.9, z - 0.7, z + 0.7)
            s.B("lamps", "sodium", x - 1.2, x + 1.2, DB - 2.45, DB - 2.2, z - 0.5, z + 0.5)
            n += 1
            if n % 2 == 1:
                s.light(x, DB - 4.5, z, "sodium", 8000)
    # doors, fire stations
    s.D("env_carrier_door", 15.5, HY, HF, yaw=-90)
    s.D("env_carrier_door", -28.5, HY, HF, yaw=-90)  # the arms vault, behind the Quartermaster
    s.D("env_carrier_door", -6, HY, HA, yaw=90)
    s.D("env_carrier_door", 28, HY, HA, yaw=90)
    s.D("env_carrier_door", -W + 2, HY, -70, yaw=0)
    s.D("env_carrier_door", W - 2, HY, 60, yaw=180)
    for x, z, yaw in ((W - 2, 84, 180), (W - 2, -18, 180), (-W + 2, -52, 0), (-W + 2, 96, 0), (W - 2, -80, 180)):
        s.D("env_carrier_firestation", x, HY, z + 3, yaw=yaw)
    s.T("hangar", "HANGAR BAY 1", (10, HY + 14, HA + 0.2), 3.0, "+z", "yellow")
    s.T("hangar", "FR 100", (W - 2.2, HY + 8.2, 98), 0.8, "-x", "black")
    # paint on the floor: the way from the spawn to the ramp and on to the map room
    for x in (-7, 7):
        s.B("floorpaint", "yellow", x - 0.2, x + 0.2, HY, HY + 0.04, 92, 132)
    s.B("floorpaint", "yellow", -7, 7, HY, HY + 0.04, 132, 132.4)
    for x in (-3.5, 2.6):
        s.B("floorpaint", "yellow", x - 0.2, x + 0.2, HY, HY + 0.04, 16, 80)
    s.T("floorpaint", "FLIGHT DECK", (-20, HY + 0.05, 86.5), 2.0, "up", "yellow", yaw=180)
    s.T("floorpaint", "< RAMP", (-12, HY + 0.05, 91.5), 1.6, "up", "yellow", yaw=180)
    s.T("floorpaint", "MAP ROOM", (-0.5, HY + 0.05, 50), 1.5, "up", "yellow", yaw=90)
    s.T("floorpaint", "ARMS ROOM >", (-13.5, HY + 0.05, 121), 1.5, "up", "yellow", yaw=180)
    s.T("floorpaint", "< CALL-INS", (12, HY + 0.05, 121), 1.5, "up", "yellow", yaw=180)
    s.stripes("floorpaint", x0, x1, HY, HY + 0.05, z1 + 0.4, z1 + 2.0, 10)
    s.stripes("floorpaint", -W + 2, -W + 3.4, HY, HY + 0.05, -40, 0, 20, axis="z")
    # the ramp: kerbs, pipe rails and cleats instead of two yellow slabs
    s.D("env_carrier_ramp_trim", (x0 + x1) / 2, HY, z1)
    s.light(-20, DB - 2, 70, "sodium", 5000)


def flight_deck_v2(s):
    x0, x1, z0, z1 = WELL
    # the well: hazard paint round it, chain stanchions instead of slabs
    s.stripes("marks", x0 - 1.0, x1 + 1.0, DECK, DECK + 0.05, z1 + 0.6, z1 + 1.6, 11)
    for x in (x0 - 1.0, x1 + 0.2):
        s.stripes("marks", x, x + 0.8, DECK, DECK + 0.05, z0, z1 + 0.6, 30, axis="z")
    for z in range(25, 80, 10):
        s.D("env_carrier_deck_rail", x0 - 0.1, DECK, z)
        s.D("env_carrier_deck_rail", x1 + 0.1, DECK, z)
    for x in (-25, -15):
        s.D("env_carrier_deck_rail", x, DECK, z1 + 0.2, yaw=90)
    for z in range(-35, 0, 10):  # the lowered lift's edge
        s.D("env_carrier_deck_rail", -W + 0.4, DECK, z)
    s.stripes("marks", -W + 1.6, -W + 2.6, DECK, DECK + 0.05, -40, 0, 20, axis="z")
    # lines: the white tramline down the spots, the red and white foul line the crew keep behind
    z = -L + 6
    while z <= z0 - 6:
        if not any(z + 6 > sz - 15.5 and z < sz + 15.5 for _, sz in SPOTS):
            s.B("marks_v1", "paint", -12.3, -11.7, DECK, DECK + 0.05, z, z + 6)  # FallowBuilder CentreLine
        z += 12
    s.B("marks", "red", 5.6, 6.2, DECK, DECK + 0.04, -176, 16)
    for i in range(16):
        z = -176 + i * 12 + 4
        s.B("marks", "paint", 5.55, 6.25, DECK, DECK + 0.06, z, z + 4)
    # spots: the yellow circle round each helicopter is where you board
    for i, (x, z) in enumerate(SPOTS):
        s.disc("spots", "yellow", x, z, 15.0, DECK + 0.02, DECK + 0.1, r_in=13.4)
        s.disc("spots", "paint", x, z, 12.6, DECK + 0.02, DECK + 0.08, r_in=12.3)
        s.T("spots", str(i + 1), (x + 9.5, DECK + 0.3, z + 17.5), 6.5, "up", "paint", yaw=180)
        s.T("spots", "BOARD HERE", (x + 10.3, DECK + 0.14, z), 1.3, "up", "black", yaw=90)
    # flood masts down the open edge, lit; lights on the island face
    for z in (-125, -70, -25, 100, 160):
        s.D("env_carrier_floodmast", -W + 1.0, DECK, z)
        s.B("lamps", "sodium", -W + 2.6, -W + 4.0, DECK + 13.0, DECK + 13.25, z - 2.6, z + 2.6)
    for z in (-125, -25):
        s.light(-W + 6, DECK + 11, z, "sodium", 22000, spot=True)
    s.light(16, DECK + 14, 20, "sodium", 16000, spot=True)
    # the island's dress, the ship's crane, a boat under the sponson, the wash-down frame
    s.D("env_carrier_island_kit", 0, 0, 0)
    s.B("lamps", "redlamp", 19.42, 19.5, 67.0, 68.6, -4.8, -3.8)
    for z in (4, 20, 36):
        s.B("lamps", "sodium", 21.4, 21.9, 57.0, 57.4, z - 1, z + 1)
    s.D("env_carrier_door", 22.0, DECK, -4, yaw=180)
    s.D("env_carrier_ship_crane", 30.5, DECK, -19, yaw=180)
    s.D("env_carrier_boat", 41.0, 26.5, 20)
    s.D("env_carrier_decon", 24, DECK, -150, yaw=0)
    # the deck park aft of the island: crash crane, tractor, pallets (clear of every crew walk)
    s.D("veh_carrier_crash_crane", 27, DECK, -64, yaw=180)
    s.D("veh_carrier_tractor", 27, DECK, -92, yaw=8)
    s.D("prop_carrier_pallet_net", 28, DECK, -108)
    s.D("prop_carrier_pallet_net", 28, DECK, -117, yaw=90)
    s.D("prop_carrier_drums", 29, DECK, -126)
    s.stripes("marks", 20.0, 20.6, DECK, DECK + 0.05, -130, -52, 26, axis="z")
    s.T("marks", "DECK GEAR", (22.6, DECK + 0.06, -80), 1.6, "up", "yellow", yaw=-90)
    # forward of the ramp: the drop zone, lashed stores
    for a, c in ((-16, -15.3), (15.3, 16)):
        s.B("marks", "yellow", a, c, DECK, DECK + 0.05, 112, 144)
    for a, c in ((112, 112.7), (143.3, 144)):
        s.B("marks", "yellow", -15.3, 15.3, DECK, DECK + 0.05, a, c)
    s.T("marks", "STORES DROP", (0, DECK + 0.06, 125), 3.2, "up", "paint")
    s.T("marks", "KEEP CLEAR", (0, DECK + 0.06, 133), 2.2, "up", "paint")
    s.D("env_container_olive", 26, DECK, 78, yaw=90)
    s.D("env_container_rust", 26, DECK, 104, yaw=90)
    s.D("prop_carrier_pallet_net", 25, DECK, 121)
    s.D("prop_carrier_crates", 26, DECK, 132, yaw=90)
    s.D("veh_carrier_tractor", 20, DECK, 150, yaw=160)
    # the balcony: pipe rails
    b = BALCONY
    for z in range(-35, 0, 10):
        s.D("env_carrier_deck_rail", b[0] + 0.3, HY, z)
    for z in (b[2] + 0.2, b[3] - 0.2):
        s.D("env_carrier_deck_rail", b[0] + 5.6, HY, z, yaw=90)
    s.B("balcony", "yellow", b[0], b[0] + 1.0, HY, HY + 0.05, b[2], b[3])


def desks_v2(s):
    # ---- the Quartermaster: the main seller, his whole corner a cage to the deckhead. He sits on
    # his stool leaning on the glass, under his reading lamp (vendor corners, owner 2026-11-17)
    s.D("npc_carrier_quartermaster", -26.6, HY, 124, layer="crew")
    s.D("prop_vendor_quartermaster", -26.6, HY, 124)
    s.T("dress", "RING ONCE", (-23.0, HY + 3.42, 126.4), 0.22, "up", "black", yaw=-90)
    s.light(-23.6, HY + 4.4, 122.9, "tungsten", 220)
    arms_room(s, True)
    s.B("arms", "black", -24.4, -22.9, HY + 10, HY + 12.2, 111, 140)
    s.T("arms", "ARMS ROOM", (-22.85, HY + 11.1, 125.5), 1.5, "+x", "yellow")
    s.T("arms", "GUNS  GRENADES  KIT", (-22.85, HY + 10.35, 125.5), 0.5, "+x", "paint")
    s.D("prop_carrier_kitshelf", -28.2, HY, 139.6, yaw=180)
    s.D("prop_carrier_ammo_stack", -30.6, HY, 134.5, yaw=90)
    s.D("prop_carrier_ammo_stack", -20.5, HY, 113.6, yaw=0)
    s.D("egg_carrier_notissue", -28.4, HY, 111.12, yaw=90)
    s.T("dress", "NOT ON ISSUE", (-28.4, HY + 4.6, 113.2), 0.42, "+z", "paint")
    s.light(-27, DB - 4, 125, "flood", 5000)
    # ---- call-ins: one seller, his kit stood out on the deck like the gun wall
    # no counter: he sits on a mortar-bomb crate among his kit, smoking, his crate-table at his
    # right hand (vendor corners, owner 2026-11-17)
    fx, fz = 27, 105
    s.D("npc_carrier_sapper", fx, HY, fz, yaw=180, layer="crew")
    s.D("prop_vendor_callins", fx, HY, fz, yaw=180)
    s.T("dress", "MIND THE", (fx - 3.05, HY + 1.75, fz + 3.8), 0.36, "-x", "red")
    s.T("dress", "COILS", (fx - 3.05, HY + 1.2, fz + 3.8), 0.42, "-x", "red")
    s.light(fx - 0.6, HY + 6.5, fz + 0.8, "amber", 420)
    s.B("callins", "black", 23.2, 23.5, HY + 10, HY + 12.2, 96, 114)
    s.B("callins", "steel", 23.25, 23.45, HY + 12.2, DB - 1.5, 97, 97.3)
    s.B("callins", "steel", 23.25, 23.45, HY + 12.2, DB - 1.5, 112.7, 113)
    s.T("callins", "CALL-INS", (23.15, HY + 11.2, 105), 1.5, "-x", "yellow")
    s.T("callins", "FIRE SUPPORT  SENTRY GUNS  SUPPLY", (23.15, HY + 10.4, 105), 0.42, "-x", "paint")
    shows = (  # name, kit, x, z, yaw, placard z, designation
        ("DOORMAN", "ref_doorman", 20.5, 134.0, 150, "SENTRY GUN"),
        ("TRIPLINE", "prop_callin_tripline", 21.5, 125.0, 0, "MINEFIELD"),
        ("HAMMER", "prop_callin_hammer", 19.5, 116.0, 0, "81 MM MORTAR"),
        ("SPEEDBALL  AID BAG", "prop_callin_supply", 21.0, 96.5, 0, "SUPPLY DROPS"),
        ("SHRIKE", "prop_callin_shrike", 29.5, 134.0, 0, "GUN RUN"),
        ("ANVIL", "prop_callin_anvil", 29.6, 119.0, 90, "105 MM BATTERY"),
        ("CONCERTINA", "prop_callin_concertina", 28.6, 92.2, 0, "WIRE"),
    )
    for name, kit, x, z, yaw, sub in shows:
        s.D(kit, x, HY + (0.04 if kit != "ref_doorman" else 0.04), z, yaw=yaw)
    for z0, z1 in ((90, 100.5), (109.5, 138.6)):  # the show floor: a dark mat edged in yellow
        s.B("callins", "mat", 17.2, 32.9, HY, HY + 0.04, z0, z1)
        s.B("callins", "yellow", 16.8, 17.2, HY, HY + 0.05, z0, z1)
    for name, kit, x, z, yaw, sub in shows:
        wall = x > 25
        px, pz = (25.6, z + (5.5 if name == "ANVIL" else 0)) if wall else (17.9, z)
        if name == "CONCERTINA":
            px, pz = 25.2, 99.2
        s.D("prop_carrier_placard", px, HY + 0.04, pz, yaw=180)
        s.T("callins", name, (px - 0.2, HY + 3.5, pz), 0.5 if len(name) < 12 else 0.3, "-x", "yellow")
        s.T("callins", sub, (px - 0.25, HY + 2.9, pz), 0.3, "-x", "paint")
    s.D("egg_carrier_cat", 26.6, HY + 0.04, 112.2, yaw=90)
    s.T("callins", "DO NOT LOAD THE CAT", (25.55, HY + 0.7, 112.2), 0.26, "-x", "paint")
    # the tallies stencilled on the hull over the show floor: one mark a mission
    for i, (name, n) in enumerate((("HAMMER", 23), ("ANVIL", 9), ("SHRIKE", 14), ("DOORMAN", 31))):
        zc = (133.6, 121.6)[i % 2]
        y = HY + (9.0 if i < 2 else 6.3)
        s.T("dress", name, (W - 2.1, y + 0.9, zc + 2.6), 0.7, "-x", "black")
        s.T("dress", " ".join(["IIII"] * (n // 5) + ["I" * (n % 5)]), (W - 2.1, y - 0.1, zc), 0.62, "-x", "black")
    s.light(24, DB - 4, 122, "flood", 6000)
    # ---- the Loadmaster at the ramp's foot: no counter; his hammock between two stanchions, the
    # rigging rail and slung cases behind (vendor corners, owner 2026-11-17)
    s.D("npc_carrier_loadmaster", -2, HY, 88, yaw=90, layer="crew")
    s.D("prop_vendor_loadmaster", -2, HY, 88, yaw=90)
    for i, line in enumerate(("IIII IIII IIII IIII", "IIII IIII IIII II")):
        s.T("dress", line, (2.8, HY + 2.3 - i * 0.55, 89.3), 0.3, "+z", "paint")
    s.T("dress", "FLOWN BACK", (2.8, HY + 2.85, 89.25), 0.26, "+z", "yellow")
    s.light(3.2, HY + 6.4, 89.4, "cabin", 320)
    s.D("prop_carrier_hoist", 3.5, HY, 84.0, yaw=0)
    s.D("prop_carrier_scale_cases", -7.5, HY, 84.5, yaw=180)
    s.B("loadout", "black", -6, 2, HY + 10, HY + 12.2, 90.3, 90.6)
    s.B("loadout", "steel", -5.6, -5.4, HY + 12.2, DB - 1.5, 90.35, 90.55)
    s.B("loadout", "steel", 1.4, 1.6, HY + 12.2, DB - 1.5, 90.35, 90.55)
    s.T("loadout", "LOADOUT", (-2, HY + 11.1, 90.65), 1.5, "+z", "yellow")
    s.T("loadout", "SIGN FOR IT HERE", (-2, HY + 10.4, 90.65), 0.42, "+z", "paint")
    s.B("dress", "black", 7.2, 7.5, HY + 1.6, HY + 6.4, 84, 90)  # the lift board
    for x in (7.35,):
        for z in (84.3, 89.7):
            s.B("dress", "steel", x - 0.15, x + 0.15, HY, HY + 1.6, z - 0.15, z + 0.15)
    s.T("dress", "TODAY'S LIFTS", (7.15, HY + 5.8, 87), 0.45, "-x", "paint")
    for i, n in enumerate(BIRDS):
        s.T("dress", "HELO %d   SPOT %d   %s" % (sorted(BIRDS)[i], BIRDS.index(sorted(BIRDS)[i]) + 1, ("TURNING", "READY", "READY", "FUEL")[i]), (7.15, HY + 5.0 - i * 0.7, 87), 0.34, "-x", "paint")
    s.T("dress", "ATV   MOTOR POOL   ASK HER", (7.15, HY + 2.2, 87), 0.34, "-x", "red")
    # ---- the map room (was "THE PLOT"): mission choice stays here. Open floor, no walls (owner
    # 2026-11-17): a painted deck and a border line say where it is; walk in from any side.
    x0, x1, z0, z1, d0, d1 = PLOT
    s.B("maproom", "plot", x0, x1, HY, HY + 0.03, z0, z1)
    for a, c, e, f in ((x0, x0 + 0.3, z0, z1), (x0, x1, z0, z0 + 0.3), (x0, x1, z1 - 0.3, z1)):
        s.B("maproom", "yellow", a, c, HY + 0.03, HY + 0.05, e, f)
    s.T("floorpaint", "MAP ROOM", (x0 + 2.2, HY + 0.06, 10), 1.6, "up", "yellow", yaw=-90)
    for z in (5.0, 15.0):  # the sign hangs from the deckhead on the room's walk-side edge
        s.B("maproom", "steel", x0 - 0.05, x0 + 0.15, HY + 12.6, DB - 1.5, z - 0.1, z + 0.1)
    s.B("maproom", "black", x0 - 0.15, x0 + 0.25, HY + 10.2, HY + 12.6, 4.5, 15.5)
    for face, xx in (("-x", x0 - 0.2), ("+x", x0 + 0.3)):
        s.T("maproom", "MAP ROOM", (xx, HY + 11.6, 10), 1.4, face, "yellow")
        s.T("maproom", "PICK YOUR MISSION", (xx, HY + 10.7, 10), 0.45, face, "paint")
    for x, z, yaw in ((8, z0 + 2.2, 0), (20, z0 + 2.2, 0), (12, z1 - 2.2, 180), (20, z1 - 2.2, 180)):
        s.D("prop_carrier_console", x, HY, z, yaw=yaw)
    # Control's watch officer, tipped back with her boots on the table's end (vendor corners)
    s.D("npc_carrier_watch_officer", 26.8, HY, -3, yaw=180, layer="crew")
    s.D("prop_vendor_watch", 26.8, HY, -3, yaw=180)
    s.B("maproom", "card", 29.1, 29.2, HY + 7.2, HY + 8.0, -5.5, -4.4)  # the postcard of her street
    s.B("maproom", "sky", 29.08, 29.1, HY + 7.62, HY + 7.95, -5.45, -4.45)
    s.light(26.4, HY + 3.4, -0.3, "tungsten", 120)
    # the board now shows where the Infected are: the city in districts, red where they are thick
    for a, c, y0, y1, k in ((-3, 0.5, 6.5, 9.5, "red"), (5, 7.5, 4.5, 6.5, "red"), (11, 15, 7.5, 10.5, "ember"), (19, 21, 4, 6, "red"), (14.5, 17, 3.5, 5, "scope")):
        s.B("plot", k, 29.22, 29.3, HY + y0, HY + y1, a, c)
    for y in (5.0, 8.0):
        s.B("plot", "paint", 29.24, 29.3, HY + y, HY + y + 0.08, -5.6, 25.6)
    s.B("maproom", "redlamp", 8, 10, DB - 0.7, DB - 0.3, -3, -1)
    s.B("maproom", "redlamp", 26, 28, DB - 0.7, DB - 0.3, 21, 23)
    s.D("egg_carrier_clocks", W - 2, HY + 14.5, 14, yaw=180)  # on the hull over the board
    s.T("maproom", "CITY", (W - 2.12, HY + 14.95, 12.4), 0.3, "-x", "black")
    s.T("maproom", "SHIP", (W - 2.12, HY + 14.95, 15.6), 0.3, "-x", "black")
    s.light(30, HY + 15, 14, "redlamp", 200)
    # where the Fires desk stood: the districts' tally board, free-standing on two posts
    for z in (17.0, 27.0):
        s.B("maproom", "steel", x0, x0 + 0.4, HY, HY + 11.2, z - 0.2, z + 0.2)
        s.B("maproom", "steel", x0 - 0.6, x0 + 1.0, HY, HY + 0.2, z - 0.5, z + 0.5)
    s.D("egg_carrier_scoreboard", x0, HY + 2.6, 22, yaw=180)
    s.T("maproom", "MISSIONS HOME", (x0 - 0.3, HY + 10.2, 22), 0.6, "-x", "paint")
    for r, name in enumerate(("DELTA", "MILE 14", "KESTREL", "THE YARD", "RESERVOIR")):
        s.T("maproom", name, (x0 - 0.3, HY + 8.55 - r * 1.25, 24.6), 0.5, "-x", "paint")


def hangar_life_v2(s):
    # ---- the crew's corner behind the spawn
    s.D("prop_carrier_crew_corner", -3, HY, HF - 0.14, yaw=-90)
    s.D("egg_carrier_arcade", -14.5, HY, 137.4, yaw=180)
    s.T("eggs", "OUT OF", (-14.6, HY + 4.95, 136.7), 0.3, "-z", "black")
    s.T("eggs", "ORDER", (-14.6, HY + 4.55, 136.7), 0.3, "-z", "black")
    for x, y, text in ((-2, 9.2, "HARLAN  14"), (8.5, 12.8, "CHECKPOINT DELTA")):
        s.D("egg_carrier_roadsign", x, HY + y, HF - 0.14, yaw=-90, tilt=-4 if x < 0 else 3)
        s.T("eggs", text, (x, HY + y + 1.6, HF - 0.34), 0.9 if len(text) < 12 else 0.62, "-z", "paint")
    # ---- the aft hangar: Nova's motor pool (FallowLayout.MotorPool, 2026-11-17) took helicopter
    # 20's floor; the motor sergeant's corner at its front, the net, the hoop
    for x0b, x1b in ((-20, -8), (-6, 6), (12, 24)):  # three painted bays
        for a, c, e, f in ((x0b, x0b + 0.3, -78, -52), (x1b - 0.3, x1b, -78, -52), (x0b, x1b, -78, -77.7)):
            s.B("motorpool", "yellow", a, c, HY, HY + 0.04, e, f)
    s.D("ref_carrier_atv", 0, HY, -64, yaw=90, layer="crew")  # the game's own ATV (VehicleBody)
    s.T("motorpool", "ATV", (0, HY + 0.05, -74.5), 1.6, "up", "yellow", yaw=90)
    for z in (-56, -60):
        s.D("prop_carrier_toolchest", 9, HY, z, yaw=-90, export=False)  # MotorPool builds these
    s.D("prop_carrier_engine_stand", 18, HY, -66, yaw=90)  # bay 3: an engine out for the next one
    s.D("prop_carrier_drums", -28, HY, -90, export=False)  # the fuel point
    s.D("prop_carrier_blade_rack", W - 2, HY, -89, yaw=180, export=False)  # tyre rack stand-in along the hull
    s.D("npc_carrier_motor_sergeant", 9, HY, -48, yaw=90, layer="crew")
    s.D("prop_vendor_motor_pool", 9, HY, -48, yaw=90)
    s.light(7.2, HY + 5.0, -47.5, "worklamp", 380)
    s.B("motor", "black", 3, 15, HY + 10, HY + 12.2, -46.6, -46.3)
    for x in (3.4, 14.6):
        s.B("motor", "steel", x - 0.1, x + 0.1, HY + 12.2, DB - 1.5, -46.55, -46.35)
    s.T("motor", "VEHICLES", (9, HY + 11.1, -46.25), 1.5, "+z", "yellow")
    s.T("motor", "MOTOR POOL", (9, HY + 10.4, -46.25), 0.42, "+z", "paint")
    s.D("veh_carrier_tractor", 24, HY, -26, yaw=75)
    # ---- FUTURE, hidden (owner 2026-11-17: "hidden in like the corner of the ship"): the
    # experimental-weapons visitor's nook UNDER THE RAMP's high end. The ramp's top third is a
    # plate on the wedge (deck_slabs hollow), so a room 20 wide, 24 deep and 12-20 tall opens
    # under it, walled at both sides, its aft face hung with a tarp except an 7.5-stud gap at the
    # port end: found by walking down the port side behind the ramp toward the lift. No sign.
    x0w, x1w, zt, zc = WELL[0], WELL[1], WELL[2], RAMP_SPLIT
    yc = HY + (DECK - HY) * (WELL[3] - zc) / (WELL[3] - zt)
    for a, c in ((x0w, x0w + 0.5), (x1w - 0.5, x1w)):  # side walls under the plate
        s.B("hidden", "wall_lo", a, c, HY, yc, zt, zc)
        s.ramp("hidden", "wall_lo", a, c, yc, DECK - 0.7, zt, zc)
    gap = x0w + 0.5 + 7.5
    s.B("hidden", "crate", gap, x1w - 0.5, HY + 1.2, DB, zt - 0.4, zt - 0.2)  # the tarp
    for x in (gap + 2.5, gap + 6.0, gap + 9.5):
        s.B("hidden", "black", x - 0.08, x + 0.08, HY + 1.2, DB, zt - 0.45, zt - 0.4)  # its folds
    s.D("prop_vendor_restricted", -23.5, HY, zt + 1.5, yaw=-90)
    s.D("npc_carrier_contractor", -25.5, HY, zt + 1.2, yaw=-90, layer="crew")
    s.light(-23, HY + 8, zt + 4, "cold", 140)
    s.D("egg_carrier_memorial", -22, HY + 1.0, HA + 0.14, yaw=90)
    for i, (dx, y) in enumerate(((-6.4, 4.2), (-2.9, 7.9), (0.8, 5.6), (4.6, 9.8), (6.9, 3.6))):
        s.B("eggs", "chem", -22 + dx - 0.1, -22 + dx + 0.1, HY + 1 + y, HY + 1 + y + 0.9, HA + 0.5, HA + 0.7)
    s.light(-22, HY + 7, HA + 4, "chem", 500)
    s.T("eggs", "STILL ON THE LIST", (-22, HY + 14.4, HA + 0.3), 0.9, "+z", "paint")
    s.D("egg_carrier_hoop", 17, HY, HA + 0.14, yaw=90)
    for a, c in ((10.8, 11.0), (23.0, 23.2)):
        s.B("floorpaint", "paint", a, c, HY, HY + 0.04, HA + 0.3, HA + 14)
    s.B("floorpaint", "paint", 10.8, 23.2, HY, HY + 0.04, HA + 14, HA + 14.2)
    s.disc("floorpaint", "paint", 17, HA + 14.2, 5.0, HY + 0.0, HY + 0.035, r_in=4.8)
    # ---- stores along the island-side wall between the map room and the call-ins
    s.D("prop_carrier_pallet_net", 28.5, HY, 38)
    s.D("prop_carrier_crates", 28.5, HY, 47, yaw=90)
    s.D("prop_carrier_pallet_net", 28.5, HY, 70, yaw=90)
    s.D("prop_carrier_drums", 29.5, HY, 78)
    s.D("prop_carrier_toolchest", 30.5, HY, 54, yaw=-90)
    s.D("prop_carrier_crates", -27, HY, 100, yaw=0)
    s.D("prop_carrier_pallet_net", -16, HY, 12)  # in front of the tarp over the hidden nook
    s.stripes("floorpaint", 23.6, 24.0, HY, HY + 0.04, 33, 82, 24, axis="z")


def eggs_deck_v2(s):
    # the lookout's post at the bow, glasses on the city
    s.D("egg_carrier_lookout", -24, DECK, 204, yaw=90)  # at the bow, glasses on the city ahead
    s.T("eggs", "STILL STANDING", (-20.8, DECK + 4.65, 204.55), 0.26, "-z", "black")
    # the count board where teams come off the helicopter
    s.D("egg_carrier_dayssign", 24, DECK, -133.2, yaw=90)
    s.T("eggs", "DAYS SINCE ONE GOT ABOARD", (24, DECK + 6.75, -133.0), 0.36, "+z", "paint")
    for i, ch in enumerate("214"):
        s.T("eggs", ch, (25.5 - i * 1.5, DECK + 3.9, -132.9), 1.3, "+z", "paint")
    s.T("eggs", "KEEP IT THAT WAY", (24, DECK + 5.45, -133.0), 0.4, "+z", "black")


TOWER_H = {"office": 178, "residential": 126, "deco": 253, "glass": 202, "ruined": 133, "midrise": 85}
TOWER_W = {"office": (66, 46), "residential": (52, 37), "deco": (58, 58), "glass": (51, 51), "ruined": (56, 38), "midrise": (93, 43)}
TOWERS = (  # kind, x, z, yaw off the quay line, scale, burning, tilt
    ("office", -650, -330, 0, 2.3, True, 0), ("glass", -690, -205, 0, 2.5, False, 0),
    ("ruined", -640, -100, 6, 2.4, False, -9), ("deco", -700, -10, 0, 2.8, True, 0),
    ("residential", -655, 85, -12, 2.2, False, 0), ("glass", -720, 170, 0, 3.0, True, 0),
    ("ruined", -665, 250, -20, 2.5, False, 0), ("office", -700, 345, 4, 2.6, False, 14),
    ("midrise", -640, 450, 0, 2.6, True, 0), ("deco", -710, 560, -6, 2.4, False, 0),
    ("residential", -660, 660, 0, 2.5, True, 0), ("glass", -705, 760, 0, 2.2, False, -11),
    ("midrise", -640, -470, 12, 2.4, False, 0), ("office", -720, -600, 0, 2.4, True, 0),
    ("ruined", -645, -700, 15, 2.2, False, 8),
)


def shore_v2(s):
    """The city STRAIGHT AHEAD, off the bow where the hills were (owner 2026-11-17). Laid out as
    if off the port side (`_city_port`, x out to sea) and turned a quarter round onto the bow:
    game (x, z) -> (z, -x), yaw - 90."""
    t = Set("city")
    _city_port(t)
    for g, kind, shape, d in t.parts:
        x0, x1, y0, y1, z0, z1 = d
        s.parts.append((g, kind, shape, (z0, z1, y0, y1, -x1, -x0)))
    for e in t.dress:
        e = dict(e)
        e["x"], e["z"], e["yaw"] = e["z"], -e["x"], e["yaw"] - 90
        s.dress.append(e)


def _city_port(s):
    """The city, off the side away from the island: quay and waterfront, a row of real towers
    (the match's skyline meshes, already uploaded), then flat skyline strips fading into the
    smoke, a glow behind it all. Fire, smoke and beams are particles and Beams in game."""
    s.B("city", "quay", -1700, CITY_X, -2, 6, -1000, COAST_Z)
    for i, z in enumerate((-640, -330, -20, 290, 600)):
        s.D("env_shore_waterfront", CITY_X, 0, z, scale=(1, -1 if i % 2 else 1, 1), layer="shore", mat="haze1")
    for n, (kind, x, z, yaw, sc, burning, tilt) in enumerate(TOWERS):
        sc *= 0.62
        s.D("env_city_" + kind, x, 6, z, yaw=90 + yaw, scale=(sc, sc, sc), layer="shore", mat="haze1", tilt=tilt)
        if burning:
            top = 6 + TOWER_H[kind] * sc
            face = x + TOWER_W[kind][1] / 2 * sc
            half = TOWER_W[kind][0] / 2 * sc
            for f0, f1, a, c in ((0.52, 0.6, -0.8, 0.1), (0.66, 0.71, -0.2, 0.85), (0.3, 0.34, 0.2, 0.9))[: 2 + n % 2]:
                s.B("city", "fire", face + 0.5, face + 1.5, top * f0, top * f1, z + half * a, z + half * c)
                s.B("city", "burnt", face + 0.3, face + 1.0, top * f1, min(top, top * (f1 + 0.16)), z + half * (a + 0.08), z + half * (c - 0.1))
            s.D("fx_fire", x, top - 6, z, scale=(2.2, 2.2, 2.4), layer="fx")
            s.D("fx_fire", face + 4, top * 0.6, z - half * 0.3, scale=(1.0, 1.0, 1.3), layer="fx")
            s.D("fx_smoke", x, top + 20, z, scale=(1.5, 1.5, 1.5), layer="fx")
    names = ("a", "b", "c")
    for layer, x, sy in (("haze2", -860, 1.5), ("haze3", -1040, 2.1)):
        for i in range(5):
            s.D("env_shore_card_" + names[(i + (0 if layer == "haze2" else 1)) % 3], x, 6, -720 + i * 400 + (0 if layer == "haze2" else 130), scale=(1, 1, sy), layer="shore", mat=layer)
    for x, z in ((-880, -420), (-900, 60), (-870, 520), (-1060, -160), (-1060, 330)):
        s.D("fx_fire", x + 6, 90, z, scale=(3.0, 3.0, 2.6), layer="fx")
        s.D("fx_smoke", x, 140, z, scale=(2.2, 2.2, 1.8), layer="fx")
    s.B("city", "glow", -1160, -1158, 0, 120, -1000, COAST_Z)  # the fire behind the skyline, on the smoke
    s.B("city", "glow2", -1164, -1162, 120, 330, -1000, COAST_Z)
    s.B("city", "glow3", -1168, -1166, 330, 560, -1000, COAST_Z)
    # searchlights still sweeping from the waterfront, and one tower signalling
    for x, z, lean, yaw in ((-600, -250, 28, 20), (-590, 250, -22, -40), (-610, 560, 35, 70)):
        s.D("fx_beam", x, 30, z, yaw=yaw, tilt=lean, layer="fx")
    kx, kz = -690 + 51 / 2 * 2.5 * 0.62 + 0.5, -205  # the glass tower's seaward face: three short, three long, three short
    pat = (3, 3, 3, 8, 8, 8, 3, 3, 3)
    for i, w in enumerate(pat):
        zz = kz - 30 + (sum(pat[:i]) + i * 3.0) * 0.75
        s.B("city", "window", kx, kx + 1, 262, 266, zz, zz + w * 0.75)


def v2():
    s = Set("v2")
    deck_slabs(s, hollow=True)
    hull_art(s)
    birds(s, tie=True)
    plot_room(s, True)
    sea_and_north(s, north=False)
    hangar_v2(s)
    flight_deck_v2(s)
    desks_v2(s)
    hangar_life_v2(s)
    eggs_deck_v2(s)
    shore_v2(s)
    s.labels = [
        ("SPAWN", 0, 125, "h"), ("ARMS ROOM: Quartermaster on his stool", -29.5, 106, "h"),
        ("CALL-INS: sapper on his crate, tea", 30.5, 98, "h"), ("LOADOUT: Loadmaster in his hammock", 10.5, 80, "h"),
        ("RAMP up to the flight deck", -20, 50, "h"), ("MAP ROOM: open floor, watch officer", 18, 34, "h"),
        ("Crew corner, arcade", -10.5, 126, "h"), ("Tally board", -3, 22, "h"),
        ("VEHICLES: motor sergeant, her dog", 9, -38, "h"), ("Motor pool: 3 bays, the ATV", 0, -82, "h"),
        ("HIDDEN nook under the ramp", -20, 4, "h"),
        ("The net", -22, -92, "h"), ("Hoop", 17, -82, "h"), ("Lift balcony", -41, -20, "h"), ("Stores", 28, 58, "h"),
        ("SPOT 1", -12, -150, "d"), ("SPOT 2", -12, -105, "d"), ("SPOT 3", -12, -60, "d"), ("SPOT 4", -12, -15, "d"),
        ("Board inside the yellow circle", 10.5, -105, "d"), ("RAMP", -20, 50, "d"), ("ISLAND", 28, 20, "d"),
        ("Deck gear", 27, -90, "d"), ("Screening lane", 24, -160, "d"), ("Count board", 24, -128, "d"),
        ("Stores drop", 0, 150, "d"), ("Lookout", -24, 196, "d"), ("Lift (down)", -41, -20, "d"), ("Ship's crane", 30, -30, "d"),
        ("THE CITY IS DEAD AHEAD", 0, 232, "d"),
    ]
    return s


# ------------------------------------------------------------------ Blender plumbing
def lin(c):
    return tuple(((v / 255.0 + 0.055) / 1.055) ** 2.4 if v / 255.0 > 0.04045 else v / 255.0 / 12.92 for v in c)


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


def _mat(name, rgb, emit=0.0, alpha=1.0, rough=0.9):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgba = lin(rgb) + (1.0,)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
            except (AttributeError, TypeError):
                pass
    m.diffuse_color = rgba[:3] + (alpha,)
    return m


def materials():
    mats = {k: _mat("cv2_" + k, rgb, emit, ALPHA.get(k, 1.0)) for k, (rgb, emit) in KINDS.items()}
    mats["sea"] = _mat("cv2_sea", KINDS["sea"][0], rough=0.7)
    mats["smoke"] = _mat("cv2_smoke", (26, 24, 25), alpha=0.6)
    mats["beam"] = _mat("cv2_beam", (220, 230, 240), emit=1.2, alpha=0.07)
    pal = bpy.data.materials.get("cv2_palette")
    if pal is None:
        pal = ba.build_palette_material(ba.build_palette_image())
        pal.name = "cv2_palette"
        pal.diffuse_color = (0.5, 0.5, 0.48, 1)
    mats["palette"] = pal
    for name, amount in (("haze1", 0.42), ("haze2", 0.68), ("haze3", 0.84)):
        mats[name] = hazed(pal, name, amount)
    mats["hill"] = _mat("cv2_hill", (70, 80, 62))
    mats["hill_rock"] = _mat("cv2_hill_rock", (86, 86, 84))
    return mats


def hazed(pal, name, amount):
    """The palette seen through `amount` of smoke (the game's Atmosphere does this by distance)."""
    m = bpy.data.materials.get("cv2_" + name)
    if m is not None:
        return m
    m = pal.copy()
    m.name = "cv2_" + name
    tree = m.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in tree.nodes if n.type == "TEX_IMAGE")
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    sock = {i.identifier: i for i in mix.inputs}
    sock["Factor_Float"].default_value = amount
    sock["B_Color"].default_value = lin(tuple(int(v * 255) for v in HAZE)) + (1,)
    tree.links.new(tex.outputs["Color"], sock["A_Color"])
    tree.links.new(next(o for o in mix.outputs if o.identifier == "Result_Color"), bsdf.inputs["Base Color"])
    return m


def clear(root_name):
    root = bpy.data.collections.get(root_name)
    if root is None:
        return
    for c in list(root.children_recursive) + [root]:
        for o in list(c.objects):
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0 and not data.name.startswith("cv2lib_"):
                kind = {bpy.types.Mesh: bpy.data.meshes, bpy.types.Curve: bpy.data.curves, bpy.types.TextCurve: bpy.data.curves}
                for t, store in kind.items():
                    if isinstance(data, t):
                        store.remove(data)
                        break
                else:
                    if isinstance(data, bpy.types.Light):
                        bpy.data.lights.remove(data)
    for c in list(root.children_recursive):
        bpy.data.collections.remove(c)
    bpy.data.collections.remove(root)


def _add_box(bm, c, mi):
    x0, x1, y0, y1, z0, z1 = c
    vs = [bm.verts.new((x, z, y)) for x in (x0, x1) for z in (z0, z1) for y in (y0, y1)]
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in f]).material_index = mi


def parts_to_meshes(parts, parent, mats, prefix):
    """One mesh object per group, a material slot per kind."""
    groups = {}
    for p in parts:
        groups.setdefault(p[0], []).append(p)
    for g, items in groups.items():
        bm = bmesh.new()
        kinds = []
        for _, kind, shape, d in items:
            if kind not in kinds:
                kinds.append(kind)
            mi = kinds.index(kind)
            if shape == "box":
                _add_box(bm, d, mi)
            elif shape == "ramp":
                x0, x1, y0, y1, z0, z1 = d
                pts = [(x0, z0, y0), (x1, z0, y0), (x0, z1, y0), (x1, z1, y0), (x0, z0, y1), (x1, z0, y1)]
                vs = [bm.verts.new(p) for p in pts]
                for f in ((0, 1, 3, 2), (0, 1, 5, 4), (4, 5, 3, 2), (0, 2, 4), (1, 5, 3)):
                    bm.faces.new([vs[i] for i in f]).material_index = mi
            elif shape == "bar":
                p0, p1, w, h = d
                a = Vector((p0[0], p0[2], p0[1]))
                c = Vector((p1[0], p1[2], p1[1]))
                dv = c - a
                side = Vector((1, 0, 0)) * (w / 2)
                up = dv.cross(Vector((1, 0, 0))).normalized() * (h / 2)
                vs = [bm.verts.new(q + sx * side + sy * up) for q in (a, c) for sx in (-1, 1) for sy in (-1, 1)]
                for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
                    bm.faces.new([vs[i] for i in f]).material_index = mi
            elif shape == "stripes":
                x0, x1, y0, y1, z0, z1, n, axis = d
                for k2 in ("yellow", "black"):
                    if k2 not in kinds:
                        kinds.append(k2)
                for i in range(n):
                    a, c = i / n, (i + 1) / n
                    box = (x0 + (x1 - x0) * a, x0 + (x1 - x0) * c, y0, y1, z0, z1) if axis == "x" else (x0, x1, y0, y1, z0 + (z1 - z0) * a, z0 + (z1 - z0) * c)
                    _add_box(bm, box, kinds.index("yellow" if i % 2 == 0 else "black"))
            elif shape == "disc":
                x, z, r, y0, y1, r_in = d
                n = 32
                ring = lambda rr, y: [bm.verts.new((x + math.cos(i * 2 * math.pi / n) * rr, z + math.sin(i * 2 * math.pi / n) * rr, y)) for i in range(n)]  # noqa: E731
                if r_in > 0:
                    o, inn = ring(r, y1), ring(r_in, y1)
                    for i in range(n):
                        bm.faces.new((o[i], o[(i + 1) % n], inn[(i + 1) % n], inn[i])).material_index = mi
                else:
                    bm.faces.new(ring(r, y1)).material_index = mi
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(prefix + g)
        bm.to_mesh(me)
        bm.free()
        for k in kinds:
            me.materials.append(mats[k])
        obj = bpy.data.objects.new(prefix + g, me)
        parent.objects.link(obj)
        if g in ("marks", "floorpaint", "spots", "lamps", "sea", "city"):
            obj.visible_shadow = False


class _Named:
    def __init__(self, name, real):
        self.name, self.objects = name, real.objects


def _fx_mesh(name):
    """Stand-ins for what the game draws with particles, beams and terrain (not counted)."""
    bm = bmesh.new()
    if name == "fx_smoke":
        rnd = random.Random(5)
        for i in range(16):
            r = 14 + i * 4.2
            vs = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)["verts"]
            bmesh.ops.translate(bm, vec=(rnd.uniform(-9, 9), i * i * 1.3 + rnd.uniform(-6, 6), i * 19.0), verts=vs)
    elif name == "fx_fire":
        rnd = random.Random(9)
        for i in range(7):
            h = rnd.uniform(18, 42)
            vs = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=rnd.uniform(5, 9), radius2=0.3, depth=h)["verts"]
            bmesh.ops.translate(bm, vec=(rnd.uniform(-12, 12), rnd.uniform(-16, 16), h / 2), verts=vs)
    elif name == "fx_beam":
        bmesh.ops.create_cone(bm, cap_ends=False, segments=8, radius1=1.5, radius2=22.0, depth=520.0)
        bmesh.ops.translate(bm, vec=(0, 0, 260), verts=bm.verts)
    else:
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    me = bpy.data.meshes.new("cv2lib_" + name)
    bm.to_mesh(me)
    bm.free()
    return me


def build_kit(names, mats):
    lib = col("Cv2_Kit")
    lib.hide_render = True
    lib.hide_viewport = True
    meshes = {}
    for name in sorted(names):
        key = "cv2lib_" + name
        me = bpy.data.meshes.get(key)
        if me is None:
            if name.startswith("fx_"):
                me = _fx_mesh(name)
                me.materials.append(mats[{"fx_beam": "beam", "fx_smoke": "smoke", "fx_fire": "fire"}.get(name, name[3:])])
            else:
                fn, col_name, pivot = ba.ASSETS[name]
                b = ba.Builder()
                fn(b)
                obj = b.finish(name, _Named(col_name, lib), mats["palette"], pivot=pivot)
                me = obj.data
                me.name = key
        meshes[name] = me
    return meshes


def drop_kit(*names):
    """Forget built kit meshes so the next build makes them again (after editing a builder)."""
    for me in [m for m in bpy.data.meshes if m.name.startswith("cv2lib_")]:
        if names and me.name[7:] not in names:
            continue
        for o in [o for o in bpy.data.objects if o.data is me]:
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(me)


FACES = {"up": (0, 0, 0), "-z": (90, 0, 0), "+x": (90, 0, 90), "+z": (90, 0, 180), "-x": (90, 0, -90)}


def add_text(parent, text, pos, size, face, mat, yaw=0.0):
    cu = bpy.data.curves.new("t_" + text[:20], "FONT")
    cu.body = text
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.materials.append(mat)
    obj = bpy.data.objects.new("t_" + text[:20], cu)
    parent.objects.link(obj)
    obj.location = (pos[0], pos[2], pos[1])
    rx, ry, rz = FACES[face]
    obj.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz + yaw))
    obj.visible_shadow = False
    return obj


def tris(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def build_set(s, root_name, hidden=False):
    sc = scene()
    clear(root_name)
    mats = materials()
    root = col(root_name, sc=sc)
    c_parts, c_dress, c_text, c_lights, c_shore, c_marks = (col(root_name + "_" + n, root) for n in ("Parts", "Dressing", "Text", "Lights", "Shore", "Marks"))
    parts_to_meshes(s.parts, c_parts, mats, root_name + "_")
    meshes = build_kit({e["name"] for e in s.dress}, mats)
    for e in s.dress:
        obj = bpy.data.objects.new(e["name"], meshes[e["name"]])
        (c_shore if e["layer"] in ("shore", "fx") else c_dress).objects.link(obj)
        obj.location = (e["x"], e["z"], e["y"])
        obj.rotation_euler = (math.radians(e["tilt"]), 0.0, math.radians(e["yaw"]))
        if e["scale"]:
            obj.scale = e["scale"]
        if e["mat"]:
            obj.material_slots[0].link = "OBJECT"
            obj.material_slots[0].material = mats[e["mat"]]
        if e["layer"] == "fx":
            obj.visible_shadow = False
    for g, text, pos, size, face, kind, yaw in s.texts:
        add_text(c_text, text, pos, size, face, mats[kind], yaw)
    for i, (x, y, z, kind, power, spot) in enumerate(s.lights):
        ld = bpy.data.lights.new("%s_light_%d" % (root_name, i), "SPOT" if spot else "POINT")
        ld.energy = power
        ld.color = lin(KINDS[kind][0])
        ld.shadow_soft_size = 1.0
        if spot:
            ld.spot_size = math.radians(110)
            ld.spot_blend = 0.6
        ob = bpy.data.objects.new(ld.name, ld)
        ob.location = (x, z, y)
        c_lights.objects.link(ob)
    for text, x, z, level in s.labels:
        for dark in (True, False):
            o = add_text(c_marks, text, (x + (0.25 if dark else 0), (DB - 2.6 if level == "h" else 118) - (0.3 if dark else 0), z - (0.25 if dark else 0)), 3.2 if level == "h" else 5.0, "up", mats["label_d" if dark else "label"], yaw=-90)
            o["level"] = level
    c_marks.hide_render = True
    c_marks.hide_viewport = True
    if hidden:
        root.hide_render = True
        root.hide_viewport = True
    return report(s, meshes)


def report(s, meshes):
    """Counts as the game would carry them: Parts, mesh instances, triangles (fx stand-ins and
    lettering are particles, beams, terrain and SurfaceGuis in game: not counted)."""
    out = {"parts": len(s.parts), "texts": len(s.texts), "lights": len(s.lights)}
    for layer in ("ship", "shore"):
        es = [e for e in s.dress if (e["layer"] == "shore") == (layer == "shore") and e["layer"] not in ("fx", "crew")]
        out[layer + "_instances"] = len(es)
        out[layer + "_meshes"] = len({e["name"] for e in es})
        out[layer + "_tris"] = sum(tris(meshes[e["name"]]) for e in es)
        out[layer + "_unique_tris"] = sum(tris(meshes[n]) for n in {e["name"] for e in es})
    out["stripe_runs"] = sum(1 for p in s.parts if p[2] == "stripes")
    out["part_tris"] = sum(2 * p[3][6] if p[2] == "stripes" else 12 for p in s.parts)
    print("carrier_v2 %-6s %s" % (s.name, out))
    return out


def build(which="v2"):
    return build_set(v2() if which == "v2" else today(), "Cv2" if which == "v2" else "Cv2_Today", hidden=which != "v2")


def build_all():
    r0 = build("today")
    r1 = build("v2")
    show("v2")
    setup_look(scene())
    aim("oblique")
    return r0, r1


def show(which="v2"):
    for name, on in (("Cv2", which == "v2"), ("Cv2_Today", which == "today")):
        c = bpy.data.collections.get(name)
        if c is not None:
            c.hide_viewport = not on
            c.hide_render = not on


def kit_sheet_counts():
    """Triangles of every new kit piece (for the doc)."""
    mats = materials()
    meshes = build_kit(set(carrier_kit.NAMES), mats)
    return {n: tris(meshes[n]) for n in carrier_kit.NAMES}


# ------------------------------------------------------------------ previews
# name: (eye, look-at, lens). Eye-level shots stand EYE above the floor there.
H, D = HY + EYE, DECK + EYE
VIEWS = {
    "oblique": ((-250, 190, -330), (0, 30, 10), 30),
    "oblique_island": ((230, 150, 330), (0, 30, 0), 30),
    "spawn": ((0, H, 126), (-4, H + 1, 80), 16),  # the first thing a player sees
    "arms_room": ((-12, H, 124), (-30, H, 125), 16),
    "callins": ((9, H, 118), (30, H - 1, 118), 15),
    "callins_wall": ((14, H, 138), (30, H, 112), 16),
    "loadout": ((-1, H, 104), (-1, H, 84), 18),
    "ramp_foot": ((-20, H, 96), (-20, HY + 14, 40), 18),
    "map_room_door": ((-10, H, 30), (10, H + 1, 8), 16),
    "map_room": ((8, H, 12), (26, H - 1, -2), 14),
    "hangar_aft": ((0, H, -8), (-4, H, -90), 16),
    "lift_view": ((-14, H, -14), (-300, H + 18, -60), 20),  # through the lift opening, the sea to port
    "ramp_top": ((-20, D, 24), (-12, D - 2, -60), 16),  # coming up onto the flight deck
    "flight_deck": ((8, D, -34), (-30, D + 2, -150), 18),
    "spot": ((4, D, -52), (-14, D, -62), 18),  # boarding: the circle and the open door
    "island": ((-22, D, 64), (30, D + 22, 16), 16),
    "deck_gear": ((4, D, -44), (30, D + 3, -84), 18),
    "shore": ((-10, D, 120), (0, 100, 700), 26),  # the city dead ahead, from the forward deck
    "shore_wide": ((8, D + 1, -30), (-60, 110, 700), 16),
    "fore_deck": ((-10, D, 84), (8, D, 170), 16),
}
EGGS = {
    "egg_01_cat": ((23.4, HY + 3.0, 108.6), (26.6, HY + 1.3, 112.0), 26),
    "egg_02_net": ((-18, H, -84), (-22, HY + 8, -100), 20),
    "egg_03_tally_board": ((-7, H, 20), (4, HY + 7, 22), 22),
    "egg_04_count_board": ((23, D, -120), (24, DECK + 4.6, -133), 24),
    "egg_05_arcade": ((-9, H, 128.5), (-14.5, HY + 4.2, 137.4), 22),
    "egg_06_callin_tallies": ((20, H, 127), (33, HY + 10, 128), 18),
    "egg_08_road_signs": ((3, H, 118), (3, HY + 9.5, 140), 20),
    "egg_09_not_on_issue": ((-28.0, H + 1.0, 118.5), (-28.4, HY + 5.2, 111.1), 20),
    "egg_10_lookout": ((-14, D, 196), (-24, DECK + 3.6, 204.5), 22),
    "egg_11_hoop": ((14, H, -74), (17, HY + 8, -100), 18),
    "egg_12_stopped_clock": ((20, H + 2, 14), (33, HY + 16, 14), 24),
    "egg_10b_signal_tower": ((0, D, 150), (-205, 250, 652), 150),
}
VENDORS = {  # vendor corners (owner 2026-11-17): render_vendors() writes vendor_<name>.png
    "quartermaster": ((-16, H + 0.5, 118), (-27, HY + 3, 125), 20),
    "callins": ((12, H + 0.5, 100), (26, HY + 2.5, 106), 20),
    "callins_close": ((18.5, HY + 4.0, 106), (26, HY + 2.6, 105.5), 24),
    "loadmaster": ((-3, H + 0.5, 101), (-1, HY + 2.2, 88), 20),
    "motor_pool": ((4, H + 1.0, -35), (7, HY + 2.0, -52), 18),
    "motor_pool_close": ((5, H + 0.5, -40), (8, HY + 2.5, -48.5), 22),
    "map_room": ((15, HY + 10.5, 13), (26.5, HY + 2.3, -3.5), 22),
    "map_room_open": ((-8, H + 3.0, 8), (20, HY + 2, 2), 16),
    "restricted": ((-27, H + 0.5, 9), (-23, HY + 3, 24), 22),
    "restricted_find": ((-30, H, -14), (-22, HY + 6, 20), 18),
    "hangar_walk": ((-2, HY + 14, 136), (2, HY + 2, 40), 16),
}
PAIRS = ("oblique", "oblique_island", "spawn", "arms_room", "callins", "loadout", "map_room_door", "hangar_aft", "lift_view", "ramp_top", "flight_deck", "island", "shore")


def _look_at(cam, eye, target):
    cam.location = (eye[0], eye[2], eye[1])
    cam.rotation_euler = (Vector((target[0], target[2], target[1])) - cam.location).to_track_quat("-Z", "Y").to_euler()


def setup_look(sc):
    """The Carrier's sky (docs/STYLES.md): an overcast late afternoon, cold, the fires the warm note."""
    world = bpy.data.worlds.get("cv2_overcast") or bpy.data.worlds.new("cv2_overcast")
    sc.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin(tuple(int(v * 255) for v in HAZE)) + (1,)
    bg.inputs["Strength"].default_value = 1.0
    # Roblox's Ambient lights every surface, indoors too: two shadowless fills stand in for it
    # (the same for both ships, so the hangar "before" is not unfairly dark).
    suns = (
        ("cv2_sun", 2.4, (1.0, 0.86, 0.74), (68, 0, 78), True), ("cv2_skylight", 1.4, (0.72, 0.8, 0.92), (8, 0, 0), True),
        ("cv2_ambient_a", 0.42, (0.8, 0.86, 0.95), (50, 0, 40), False), ("cv2_ambient_b", 0.42, (0.8, 0.86, 0.95), (50, 0, 220), False),
    )
    for name, energy, colour, rot, shadow in suns:
        sun = bpy.data.objects.get(name)
        if sun is None:
            sun = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
            sc.collection.objects.link(sun)
        sun.data.energy = energy
        sun.data.color = colour
        sun.data.angle = math.radians(12)
        sun.data.use_shadow = shadow
        sun.rotation_euler = tuple(math.radians(v) for v in rot)
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


def camera(sc):
    cam = bpy.data.objects.get("cv2_cam")
    if cam is None:
        cam = bpy.data.objects.new("cv2_cam", bpy.data.cameras.new("cv2_cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.clip_start = 0.3
    cam.data.clip_end = 9000
    return cam


def aim(name=None, eye=None, target=None, lens=22, size=(1600, 900)):
    """Point the scene camera (for `look` in live Blender): a VIEWS / EGGS name, or an eye and a target."""
    sc = scene()
    cam = camera(sc)
    if name is not None:
        eye, target, lens = (VIEWS.get(name) or EGGS[name])
    cam.data.type = "PERSP"
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = size
    _look_at(cam, eye, target)
    return cam


def aim_top(level="d", size=(2600, 760)):
    """Straight down, bow to the right: "d" the flight deck, "h" the hangar deck (the camera sits
    under the deck beams, so the deck is not in the way)."""
    sc = scene()
    cam = camera(sc)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 420 if level == "d" else 276
    cam.location = (0, 15 if level == "d" else 20, 400 if level == "d" else DB - 2.5)
    cam.rotation_euler = (0, 0, math.radians(-90))
    cam.data.clip_start = 0.05
    sc.render.resolution_x, sc.render.resolution_y = size
    return cam


def _shot(sc, name):
    sc.render.filepath = os.path.join(PREVIEWS, "carrier_v2_" + name + ".png")
    bpy.ops.render.render(write_still=True, scene=sc.name)


def _labels(level):
    marks = bpy.data.collections.get("Cv2_Marks")
    marks.hide_render = level is None
    for o in marks.objects:
        o.hide_render = level is not None and o.get("level") != level


def render_previews():
    os.makedirs(PREVIEWS, exist_ok=True)
    sc = scene()
    setup_look(sc)
    show("v2")
    _labels(None)
    for name in list(VIEWS) + list(EGGS):
        aim(name)
        _shot(sc, name)
    for level, tag in (("d", "flight_deck"), ("h", "hangar")):
        aim_top(level)
        _labels(level)
        _shot(sc, "topdown_" + tag)
        _labels(None)
    if bpy.data.collections.get("Cv2_Today") is not None:
        for name in PAIRS:
            for which in ("today", "v2"):
                show(which)
                aim(name)
                _shot(sc, "pair_%s_%s" % (name, "before" if which == "today" else "after"))
        for level, tag in (("d", "flight_deck"), ("h", "hangar")):
            show("today")
            aim_top(level)
            _shot(sc, "pair_topdown_%s_before" % tag)
    show("v2")
    aim("oblique")


def render_vendors(out_dir=None):
    """The vendor corners' pictures: vendor_<view>.png and vendor_overview.png (the hangar from
    above, labelled), into build/previews or `out_dir`."""
    out_dir = out_dir or PREVIEWS
    os.makedirs(out_dir, exist_ok=True)
    sc = scene()
    setup_look(sc)
    show("v2")
    _labels(None)
    for name in VENDORS:
        aim(eye=VENDORS[name][0], target=VENDORS[name][1], lens=VENDORS[name][2])
        sc.render.filepath = os.path.join(out_dir, "vendor_" + name + ".png")
        bpy.ops.render.render(write_still=True, scene=sc.name)
    aim_top("h")
    _labels("h")
    sc.render.filepath = os.path.join(out_dir, "vendor_overview.png")
    bpy.ops.render.render(write_still=True, scene=sc.name)
    _labels(None)
    aim("oblique")


# ------------------------------------------------------------------ into the lobby (Luau data)
# What the game already builds stays the game's (FallowBuilder, FallowArt, ArmsRack, DeskService
# signs, CallInDisplay, MotorPool, LanternBird, WorldMap, ContainmentBoard): those groups and
# meshes are left out; everything else v2 adds is written to src/lobby/server/CarrierV2Data.luau
# and placed by CarrierV2.luau. Kit meshes' sizes, offsets and uploaded model ids go to
# src/shared/CarrierKitMeshes.luau (ids from build/carrier_uploaded.json, upload_models.js).
#   blender --background --python assets/3d/build/carrier_v2.py -- --export-luau
SKIP_GROUPS = {"arms", "balcony", "callins", "deck", "hangar", "lane", "loadout", "marks_v1", "motor", "motorpool", "plot", "sea", "north", "spots"}
SKIP_MESHES = ("env_fallow_", "veh_lantern_", "ref_", "npc_", "fx_", "prop_callin_")
SKIP_NAMES = {"prop_carrier_placard", "env_carrier_ramp_trim", "env_container_olive", "env_container_rust"}
# Floor props a soldier bumps into (a box collider; the rest is overhead, on a wall or flat).
SOLID_MESHES = {"veh_carrier_tractor", "veh_carrier_crash_crane", "prop_carrier_pallet_net", "prop_carrier_drums", "prop_carrier_crates", "prop_carrier_toolchest", "prop_carrier_engine_stand", "prop_carrier_scale_cases", "prop_carrier_console", "prop_carrier_crew_corner", "egg_carrier_arcade"}
GAME_LIGHTS = {"tungsten", "amber", "cabin", "worklamp", "cold", "chem"}
NEON = {"sodium", "flood", "redlamp", "fire", "glow", "glow2", "glow3", "ember", "chem", "scope", "window", "label"}
UPLOADED_JSON = os.path.join(HERE, "carrier_uploaded.json")


def _n(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _exported(e):
    n = e["name"]
    if not e["export"] or e["layer"] not in ("ship", "shore"):
        return False
    if n.startswith("env_city_"):
        return True  # the match's skyline meshes, already uploaded
    return not n.startswith(SKIP_MESHES) and n not in SKIP_NAMES


def game_meshes(s=None):
    """The kit meshes the lobby places that need an upload (names, sorted)."""
    s = s or v2()
    return sorted({e["name"] for e in s.dress if _exported(e) and not e["name"].startswith("env_city_")})


def _box_rows(s):
    rows = []
    for g, kind, shape, d in s.parts:
        if g in SKIP_GROUPS:
            continue
        if shape == "box":
            rows.append(("box", kind, d))
        elif shape == "ramp":
            rows.append(("wedge", kind, d))
        elif shape == "stripes":  # one Part a band
            x0, x1, y0, y1, z0, z1, n, axis = d
            for i in range(n):
                k = "yellow" if i % 2 == 0 else "black"
                if axis == "x":
                    a, c = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
                    rows.append(("box", k, (a, c, y0, y1, z0, z1)))
                else:
                    a, c = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
                    rows.append(("box", k, (x0, x1, y0, y1, a, c)))
    return rows


def export_luau(data_path=None, kit_path=None):
    """Writes CarrierV2Data.luau (placements) and CarrierKitMeshes.luau (mesh defs)."""
    import json

    s = v2()
    data_path = data_path or os.path.join(ROOT_DIR, "src", "lobby", "server", "CarrierV2Data.luau")
    kit_path = kit_path or os.path.join(ROOT_DIR, "src", "shared", "CarrierKitMeshes.luau")
    head = ["--!strict", "-- GENERATED by assets/3d/build/carrier_v2.py export_luau(): do not edit by hand."]
    rows = _box_rows(s)
    used = sorted({k for _, k, _ in rows} | {t[5] for t in s.texts if t[0] not in SKIP_GROUPS})
    out = head + ["-- Carrier v2's dressing for the lobby (docs/sprints/CARRIER_V2.md); CarrierV2.luau builds it.", "", "return {"]
    out.append("\tparts = { -- box: x0, x1, y0, y1, z0, z1 (a wedge is full height at z0)")
    for shape, kind, d in rows:
        out.append('\t\t{ shape = "%s", kind = "%s", box = { %s } },' % (shape, kind, ", ".join(_n(v) for v in d)))
    out.append("\t},")
    out.append("\tkinds = {")
    for k in used:
        rgb = KINDS[k][0]
        out.append("\t\t%s = { color = Color3.fromRGB(%d, %d, %d), neon = %s, transparency = %s }," % (k, rgb[0], rgb[1], rgb[2], "true" if k in NEON else "false", _n(1 - ALPHA[k]) if k in ALPHA else "0"))
    out.append("\t},")
    out.append("\tmeshes = { -- at: x, y, z, yaw, tilt (degrees, Blender sense), sx, sy, sz (game axes)")
    for e in s.dress:
        if _exported(e):
            sc = e["scale"] or (1, 1, 1)
            out.append('\t\t{ name = "%s", at = { %s } },' % (e["name"], ", ".join(_n(v) for v in (e["x"], e["y"], e["z"], e["yaw"], e["tilt"], sc[0], sc[2], sc[1]))))
    out.append("\t},")
    out.append("\ttexts = { -- at: x, y, z, height, yaw")
    for g, text, pos, size, face, kind, yaw in s.texts:
        if g not in SKIP_GROUPS:
            out.append('\t\t{ text = %s, face = "%s", kind = "%s", at = { %s } },' % (json.dumps(text), face, kind, ", ".join(_n(v) for v in (pos[0], pos[1], pos[2], size, yaw))))
    out.append("\t},")
    out.append("\tlights = { -- at: x, y, z, range")
    for x, y, z, kind, power, spot in s.lights:
        if kind in GAME_LIGHTS:
            rgb = KINDS[kind][0]
            out.append("\t\t{ color = Color3.fromRGB(%d, %d, %d), at = { %s, %s, %s, %d } }," % (rgb[0], rgb[1], rgb[2], _n(x), _n(y), _n(z), 14 if power < 1000 else 24))
    out.append("\t},")
    out.append("\tfx = { -- at: x, y, z, scale")
    for e in s.dress:
        if e["name"] in ("fx_fire", "fx_smoke"):
            out.append('\t\t{ kind = "%s", at = { %s } },' % (e["name"][3:], ", ".join(_n(v) for v in (e["x"], e["y"], e["z"], (e["scale"] or (1, 1, 1))[0]))))
    out.append("\t},")
    out.append("}")
    with open(data_path, "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    ids = {}
    if os.path.exists(UPLOADED_JSON):
        with open(UPLOADED_JSON) as f:
            ids = json.load(f)
    names = game_meshes(s)
    meshes = build_kit(set(names), materials())
    k = head + ["-- Carrier v2's kit meshes (assets/3d/build/carrier_kit.py) for the lobby: the uploaded model",
                "-- asset (group Boomin Dev Studios), the in-game size and the bounds centre from the design",
                "-- origin. MeshAssets.register adds them; modelId 0 = not uploaded yet (skipped).", "",
                "return {"]
    for n in names:
        vs = [v.co for v in meshes[n].vertices]
        lo = [min(v[i] for v in vs) for i in range(3)]
        hi = [max(v[i] for v in vs) for i in range(3)]
        size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])
        off = ((hi[0] + lo[0]) / 2, (hi[2] + lo[2]) / 2, (hi[1] + lo[1]) / 2)
        k.append("\t%s = { modelId = %s, size = Vector3.new(%s), offset = Vector3.new(%s), solid = %s }," % (
            n, ids.get(n, {}).get("modelId", 0), ", ".join(_n(v) for v in size), ", ".join(_n(v) for v in off),
            "true" if n in SOLID_MESHES else "false"))
    k.append("}")
    with open(kit_path, "w", newline="\n") as f:
        f.write("\n".join(k) + "\n")
    print("export_luau", len(rows), "parts", len(names), "meshes:", " ".join(names))
    return names


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if bpy.app.background:
        bpy.ops.wm.read_homefile(use_empty=True)
    if "--export-luau" in argv:
        export_luau()
        sys.exit(0)
    build_all()
    if "--no-render" not in argv:
        render_previews()
        render_vendors()
    if bpy.app.background:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
        print("saved", BLEND)
