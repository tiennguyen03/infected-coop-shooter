"""The Fallow, the lobby ship (docs/LORE.md > The Fallow, docs/sprints/LOBBY_V1_FALLOW.md).

One file per singular asset (owner, 2026-11-07). The art director's build sheet (2026-11-09,
recorded in docs/sprints/LOBBY_V1_FALLOW.md > Ship art), blocked out live in Blender with the
owner first: a carrier reads as a carrier because the deck overhangs the hull (sponsons,
catwalks and safety nets outboard), the bow tapers and flares under a square deck end, and the
island steps up to a bridge, a glassed Pri-Fly over the spots, two funnels and a mast.

Every mesh is built in **ship coordinates**, the Roblox frame of `FallowLayout` (+X starboard,
+Y up, +Z bow; deck surface y 40, sea y 0), so FallowBuilder places each MeshPart at its printed
`offset` with no rotation. Blender X = Roblox X, Blender Y = Roblox Z, Blender Z = Roblox Y (the
same mapping the build's `offset` print uses). The radar and the catwalk bays are the
exceptions: built about their own pivot and placed by FallowBuilder.

Each hull section is a pair: a **shell** (one swatch; drawn in game as Metal through
MeshAssets `surface`) and a **trim** mesh (palette). The deck slabs, ramp, hangar, Plot, spot
markings, the HRD patches and every collider stay Parts in FallowBuilder. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only env_fallow_bow ...
"""

import math

DECK = 40.0  # flight deck surface
LIP = 39.6  # the deck-edge lip stops below the deck top (no shared plane at y 40)

# Bow stations: Z, then (half-beam, height) from the deck down to the keel. The 165 -> 185
# band above the knuckle (y 17..38) is one plane, so the painted-out hull number Part lies flat
# on it (FallowBuilder `bowPatch`): 34.5 - 31 == 30 - 26.5.
BOW = (
    (140, ((35.3, 38), (34.5, 17), (34.5, 0), (34.5, -8))),
    (165, ((34.5, 38), (31.0, 17), (28.0, 0), (24.0, -8))),
    (185, ((30.0, 38), (26.5, 17), (16.0, 0), (10.0, -6))),
    (196, ((22.0, 38), (14.0, 17), (1.5, 2), (0.5, 0))),
    (207, ((10.0, 38), (3.0, 34), (0.6, 31), (0.3, 30.5))),
)

# Sponsons (X0, X1, Z0, Z1, y0, y1) and the gun tubs on them (canvas-covered; lore flag).
SPONSONS = {
    "bow": ((-42, -35.3, 150, 168, 32, 38), (35.3, 42, 145, 160, 32, 38)),
    "stern": ((-42, -34.5, -165, -145, 32, 38), (34.5, 40, -175, -136, 32, 38)),
}
TUBS = {"bow": ((-38.5, 159), (38.5, 152.5)), "stern": ((-38.5, -155),)}


# ------------------------------------------------------------------ helpers (Roblox frame)
def rb(b, a, c, sw, rot=None):
    """Box between Roblox corners a and c (x, y, z)."""
    size = (abs(c[0] - a[0]), abs(c[2] - a[2]), abs(c[1] - a[1]))
    loc = ((a[0] + c[0]) / 2, (a[2] + c[2]) / 2, (a[1] + c[1]) / 2)
    b.box(size, loc, rot=rot, swatch=sw)


def rbc(b, centre, size, sw, rot=None):
    """Box by Roblox centre and Roblox size (x, y, z). rot in Blender axes (X, Y=Roblox Z, Z=up)."""
    b.box((size[0], size[2], size[1]), (centre[0], centre[2], centre[1]), rot=rot, swatch=sw)


def cyl_up(b, x, y0, y1, z, r, sw, segs=8, r2=None):
    """Vertical cylinder from Roblox height y0 to y1."""
    b.cyl(r, y1 - y0, (x, z, (y0 + y1) / 2), segs=segs, r2=r2, swatch=sw)


def cyl_z(b, x, y, z0, z1, r, sw, segs=8):
    """Cylinder along Roblox Z (fore-aft)."""
    b.cyl(r, z1 - z0, (x, (z0 + z1) / 2, y), segs=segs, rot=(90, 0, 0), swatch=sw)


def whip(b, x, y, z, side, length=14.0, lean=60):
    """A whip antenna folded out `lean` degrees from upright, toward `side` (+1 / -1)."""
    a = math.radians(lean)
    cx = x + side * math.sin(a) * length / 2
    cy = y + math.cos(a) * length / 2
    b.cyl(0.15, length, (cx, z, cy), segs=6, rot=(0, side * lean, 0), swatch="gun_l")


# ------------------------------------------------------------------ hull
def bow(b):
    """The raked, flared bow under the deck overhang (Z 140..207), plus the fore sponsons."""
    rings = []
    for z, pts in BOW:
        left = [(-hw, z, y) for hw, y in pts]
        right = [(hw, z, y) for hw, y in reversed(pts)]
        rings.append([b.bm.verts.new(p) for p in left + right])
    faces = []
    n = len(rings[0])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n - 1):  # the top edge (deck to deck) stays open: the deck covers it
            faces.append(b.bm.faces.new((r0[k], r0[k + 1], r1[k + 1], r1[k])))
    faces.append(b.bm.faces.new(tuple(reversed(rings[-1]))))
    b._paint_faces(faces, "gun")
    for x0, x1, z0, z1, y0, y1 in SPONSONS["bow"]:
        rb(b, (x0, y0, z0), (x1, y1, z1), "gun")


def bow_trim(b):
    for side in (-1, 1):
        # Hawse pipe on the flare above the knuckle, anchor crown block, rust falling from it.
        rbc(b, (side * 28.6, 27, 186), (1.0, 2.4, 2.4), "dark_d")
        rbc(b, (side * 29.1, 27, 186), (0.4, 1.2, 1.2), "gun_d")
        rbc(b, (side * 27.6, 21.5, 186), (0.15, 9.0, 0.6), "rust_d", rot=(0, side * 9.5, 0))
    for x, z in TUBS["bow"]:
        cyl_up(b, x, 38, 40.5, z, 3.5, "tan_d")
        cyl_up(b, x, 40.5, 40.9, z, 2.6, "tan")
    whip(b, -42, 38, 152, -1)
    whip(b, 42, 38, 147, 1)


def mid(b, side):
    """Midbody shell Z -100..140 on one side: hull side to the knuckle, hangar plating, lip."""
    s = side
    x = lambda a, c: (min(s * a, s * c), max(s * a, s * c))  # noqa: E731
    xa, xc = x(34.3, 34.7)
    rb(b, (xa, -8, -100), (xc, 17, 140), "gun")
    xa, xc = x(35.1, 35.5)
    if s < 0:  # the side lift opening Z -40..0 (hangar floor to deck)
        rb(b, (xa, 17.9, -100), (xc, 38, -40), "gun")
        rb(b, (xa, 17.9, 0), (xc, 38, 140), "gun")
        rb(b, (xa, 17.9, -40), (xc, 19.8, 0), "gun")  # sill under the opening
    else:
        rb(b, (xa, 17.9, -100), (xc, 38, 140), "gun")
        # The island sponson and its two knee braces.
        rb(b, (35.5, 31, -14), (41, LIP, 54), "gun")
        for z in (-6, 46):
            b.wedge((5.5, 1.0, 7.0), (38.25, z, 27.5), rot=(180, 0, 0), swatch="gun")
    xa, xc = x(35.3, 35.7)
    rb(b, (xa, 37.6, -100), (xc, LIP, 140), "gun")


def mid_trim(b):
    for s in (-1, 1):
        x = lambda a, c: (min(s * a, s * c), max(s * a, s * c))  # noqa: E731
        xa, xc = x(34.5, 35.2)
        rb(b, (xa, 17.1, -100), (xc, 17.9, 140), "gun_d")  # rub strake (the knuckle line)
        xa, xc = x(34.7, 34.8)
        rb(b, (xa, -1, -100), (xc, 3, 140), "dark_d")  # boot-top
        for i in range(8):  # scuppers with rust under them
            z = -90 + i * 29
            if s < 0 and -42 < z < 2:
                continue
            xa, xc = x(35.5, 35.6)
            rb(b, (xa, 29.5, z), (xc, 30.0, z + 1), "dark_d")
            rb(b, (xa, 24.0, z + 0.3), (xc, 29.5, z + 0.7), "rust_d")
    # The lift opening's frame (port).
    for z in (-40, 0):
        rb(b, (-35.9, 19.8, z - 0.4), (-35.1, 38, z + 0.4), "dark_d")
    rb(b, (-35.9, 37.2, -40), (-35.1, 38, 0), "dark_d")
    # The lift platform lowered to hangar level as a balcony (owner 2026-11-09, decision 2a):
    # its deck and rails are Parts (FallowArt), so it is walkable before the upload; the mesh
    # carries the two elevator guide frames it rides in.
    for z in (-36, -4):
        rb(b, (-45, 6, z - 1), (-37, 19.6, z + 1), "gun_d")
    # Whip antennas off the island sponson's corners.
    whip(b, 41, LIP, -12, 1)
    whip(b, 41, LIP, 52, 1)


def stern(b):
    rb(b, (-34.5, -8, -180.6), (34.5, 38, -180.2), "gun")  # transom
    for s in (-1, 1):
        x0, x1 = sorted((s * 34.1, s * 34.5))
        rb(b, (x0, -8, -180.2), (x1, 38, -100), "gun")  # hull sides aft of the hangar
        x0, x1 = sorted((s * 34.5, s * 35.5))
        rb(b, (x0, 37.6, -180.2), (x1, LIP, -100), "gun")  # lip
    for x0, x1, z0, z1, y0, y1 in SPONSONS["stern"]:
        rb(b, (x0, y0, z0), (x1, y1, z1), "gun")


def stern_trim(b):
    rb(b, (-30, 34, -183.5), (30, 35, -180.6), "gun_d")  # stern gallery
    for y in (36.2, 37.4):
        rb(b, (-30, y, -183.6), (30, y + 0.15, -183.4), "gun")
    for x in (-30, -15, 0, 15, 30):
        rb(b, (x - 0.1, 35, -183.6), (x + 0.1, 37.6, -183.4), "gun")
    rb(b, (-17, 2, -180.8), (17, 20, -180.65), "gun_d")  # stern gate frame
    rb(b, (-16, 3, -180.95), (16, 19, -180.8), "dark_d")  # stern gate
    rb(b, (-34.8, -1, -180.75), (34.8, 3, -180.6), "dark_d")  # boot-top
    for s in (-1, 1):
        x0, x1 = sorted((s * 34.5, s * 34.6))
        rb(b, (x0, -1, -180.2), (x1, 3, -100), "dark_d")
    cyl_up(b, 0, 35, 45, -182.5, 0.15, "gun_l", segs=6)  # flagstaff
    # The quarantine flag: plain yellow, everything aboard came from the corridor (LORE.md).
    rb(b, (0.15, 42.2, -182.55), (4.15, 44.8, -182.45), "objective_yellow")
    # Her old name painted out on the transom; the raised weld letters show through the paint
    # as shapes nobody can read (LORE.md > The Fallow).
    rb(b, (-15, 25.5, -180.75), (15, 32.5, -180.6), "gun")
    for i, (w, h) in enumerate(((2.2, 4.0), (2.6, 4.0), (1.0, 4.0), (2.4, 3.0), (2.6, 4.0), (2.2, 4.0), (2.4, 3.6))):
        x = -12 + i * 4
        rb(b, (x - w / 2, 27 + (4 - h) / 2, -180.85), (x + w / 2, 27 + (4 + h) / 2, -180.75), "gun")
    for x, z in TUBS["stern"]:
        cyl_up(b, x, 38, 40.5, z, 3.5, "tan_d")
        cyl_up(b, x, 40.5, 40.9, z, 2.6, "tan")
    # The screening lane's plumbing on its sponson: a decon tank and a hose reel.
    cyl_z(b, 37.5, 39.7, -170, -160, 1.6, "white_d")
    for z in (-170.2, -159.8):
        cyl_z(b, 37.5, 39.7, z - 0.2, z + 0.2, 1.7, "gun_d")
    b.cyl(1.2, 1.0, (37.5, -150, 39.4), segs=8, rot=(0, 90, 0), swatch="red")
    whip(b, -42, 38, -147, -1)


# ------------------------------------------------------------------ island
def island(b):
    """Shell: base O1-O3, the O4 level stepped back, Pri-Fly, bridge and wings, two funnels."""
    y0 = DECK + 0.02
    rb(b, (22, y0, -10), (41, 58, 50), "gun")  # base
    rb(b, (23, 58, -6), (40.5, 65, 46), "gun")  # O4
    rb(b, (20.5, 60, -9), (27, 66, 3), "gun")  # Pri-Fly, overlooking the spots
    rb(b, (22.5, 65, 34), (40, 73, 48), "gun")  # bridge
    rb(b, (40, 65, 36), (44, 66, 46), "gun")  # bridge wing (outboard)
    rb(b, (27, 65, 18), (38, 86, 32), "gun")  # fore funnel
    rb(b, (27, 65, 2), (37, 82, 12), "gun")  # aft funnel


def island_trim(b):
    # Window bands: glass with a sky strip over it (opaque; STYLES §6 bans transparency).
    rb(b, (22.3, 68, 35), (22.5, 71.6, 47), "glass")
    rb(b, (22.3, 71.6, 35), (22.5, 72.0, 47), "glass_l")
    rb(b, (22.5, 68, 48.0), (39.5, 71.6, 48.2), "glass")
    rb(b, (22.5, 71.6, 48.0), (39.5, 72.0, 48.2), "glass_l")
    rb(b, (20.3, 62, -8), (20.5, 65.2, 2), "glass")
    rb(b, (20.3, 65.2, -8), (20.5, 65.6, 2), "glass_l")
    rb(b, (20.5, 62, -9.2), (26.5, 65.2, -9.0), "glass")
    # Funnel caps and soot, rust under each cap lip.
    for x0, x1, z0, z1, top in ((27, 38, 18, 32, 86), (27, 37, 2, 12, 82)):
        rb(b, (x0 - 0.3, top, z0 - 0.3), (x1 + 0.3, top + 1.5, z1 + 0.3), "dark_d")
        rb(b, (x0 + 1, top + 1.5, z0 + 1), (x1 - 1, top + 1.7, z1 - 1), "dark")
        for z in (z0 + 3, z1 - 3):
            rb(b, (x0 - 0.15, top - 6, z - 0.3), (x0 - 0.05, top, z + 0.3), "rust_d")
    # Ladders on the aft face.
    for x in (30, 36):
        rb(b, (x - 0.6, DECK + 0.1, -10.3), (x - 0.45, 58, -10.1), "gun_d")
        rb(b, (x + 0.45, DECK + 0.1, -10.3), (x + 0.6, 58, -10.1), "gun_d")
        for y in range(42, 58, 2):
            rb(b, (x - 0.6, y, -10.3), (x + 0.6, y + 0.15, -10.15), "gun_d")
    # Raft rack on the outboard face, a fire-hose station by the deck door.
    rb(b, (41, 50, 4), (42, 50.4, 30), "gun_d")
    for z in range(6, 30, 5):
        cyl_z(b, 42.0, 51.4, z, z + 3.2, 0.9, "white_l")
    rb(b, (21.85, 44, 2), (22.0, 46, 3), "red")
    # Mast: pole, two raked legs, platform with rails, yard, two domes, whip.
    cyl_up(b, 31, 73, 112, 40, 0.6, "gun")
    for z in (36.5, 43.5):
        b.cyl(0.35, 20, (31, z, 82.5), segs=6, rot=(math.copysign(10, z - 40), 0, 0), swatch="gun")
    rb(b, (28, 91.6, 37), (34, 92.0, 47), "gun_d")
    for y in (92.8, 93.6):
        rb(b, (28, y, 46.85), (34, y + 0.12, 47), "gun")
        rb(b, (33.85, y, 37), (34, y + 0.12, 47), "gun")
        rb(b, (28, y, 37), (28.15, y + 0.12, 47), "gun")
    rb(b, (25, 103.7, 39.7), (37, 104.3, 40.3), "gun")
    for x in (26, 36):
        b.ico(0.8, (x, 40, 105.1), subdiv=1, swatch="white")
    cyl_up(b, 31, 112, 116, 40, 0.1, "gun_l", segs=6)


def radar(b):
    """Air-search array on a pedestal; pivot (origin) on the rotation axis at the pedestal's
    foot. FallowBuilder stands it on the mast platform, the client turns it."""
    cyl_up(b, 0, 0, 2.0, 0, 0.6, "gun_d")
    rbc(b, (0, 2.3, 0), (2.0, 0.6, 1.2), "gun_d")
    rbc(b, (0, 4.6, 0), (7, 5, 0.6), "gun_l", rot=(15, 0, 0))
    rbc(b, (0, 4.6, -0.35), (7.3, 5.3, 0.3), "gun_d", rot=(15, 0, 0))


# ------------------------------------------------------------------ catwalk bays (instanced)
def catwalk(b, rafts=False):
    """One 24-stud bay off the starboard side; pivot at the hull face, deck height, bay centre.
    Port bays are the same mesh turned 180 degrees about Y."""
    y = -3.6  # grating top, below the deck
    rb(b, (0.6, y - 0.3, -11.6), (4.0, y, 11.6), "gun_d")  # grating
    for z in (-11.5, -5.75, 0, 5.75, 11.5):
        cyl_up(b, 3.85, y, y + 2.6, z, 0.1, "gun", segs=6)  # stanchions
        # Safety-net arm, from the grating's edge up and out to the outer rail.
        dx, dy = 2.5, 3.9
        ln = math.hypot(dx, dy)
        ang = math.degrees(math.atan2(dy, dx))
        b.box((ln, 0.25, 0.25), (4.0 + dx / 2, z, y + dy / 2), rot=(0, -ang, 0), swatch="gun")
    for h in (1.2, 2.4):
        rb(b, (3.75, y + h, -11.6), (3.95, y + h + 0.15, 11.6), "gun")  # rail bars
    rb(b, (6.35, 0.15, -11.6), (6.65, 0.45, 11.6), "gun")  # the net's outer rail
    for t in (0.25, 0.5, 0.75):  # net wires
        cx, cy = 4.0 + 2.5 * t, y + 3.9 * t
        rb(b, (cx - 0.06, cy - 0.06, -11.6), (cx + 0.06, cy + 0.06, 11.6), "dark_l")
    if rafts:
        rb(b, (0.8, y, -11), (2.6, y + 0.3, 11), "gun_d")  # cradle
        for z in (-8.4, -2.8, 2.8, 8.4):
            cyl_z(b, 1.7, y + 1.25, z - 1.6, z + 1.6, 0.9, "white_l")
            for e in (z - 1.6, z + 1.45):
                cyl_z(b, 1.7, y + 1.25, e, e + 0.15, 0.93, "white_d")


# ------------------------------------------------------------------ registration
FALLOW = {
    "env_fallow_bow": bow,
    "env_fallow_bow_trim": bow_trim,
    "env_fallow_mid_port": lambda b: mid(b, -1),
    "env_fallow_mid_stbd": lambda b: mid(b, 1),
    "env_fallow_mid_trim": mid_trim,
    "env_fallow_stern": stern,
    "env_fallow_stern_trim": stern_trim,
    "env_fallow_island": island,
    "env_fallow_island_trim": island_trim,
    "env_fallow_radar": radar,
    "env_fallow_catwalk": catwalk,
    "env_fallow_catwalk_rafts": lambda b: catwalk(b, rafts=True),
}


def register(ba):
    """Adds the Fallow's meshes to build_assets' ASSETS table. Pivot "ship": no bottom shift,
    so the printed `offset` is the bounds centre in ship coordinates."""
    for name, fn in FALLOW.items():
        ba.ASSETS[name] = (fn, "Fallow", "ship")
