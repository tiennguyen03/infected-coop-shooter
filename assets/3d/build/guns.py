"""Held guns beyond the rifle: the sample guns of 2026-11-09 (owner: "make the models yourselves
in Blender; it might be a placeholder, I just want a model").

A set of related pieces shares one file (owner, 2026-11-08), registered into build_assets.py's
ASSETS table by `register(ba)`, the props.py pattern. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only wpn_revolver

Unlike `wpn_rifle` (built at 1/0.65 and scaled in game), these are built at their in-game size
in studs (the M16 is 2.9 long next to the 5-stud soldier). Origin = the grip (where the hand
holds it), barrel along -Y, up +Z; the build keeps that origin, so the build's printed `offset`
is the bounds centre from the grip and goes straight into MeshAssets with the `muzzle` below.
The gun row names its mesh in Config.Weapons.<id>.Model.
"""

import math

# Barrel tip from the grip, Blender (x, y, z); MeshAssets takes it in Roblox order (x, z, y).
MUZZLE = {
    "wpn_revolver": (0.0, -0.76, 0.34),
    "wpn_sniper": (0.0, -2.62, 0.34),
    "wpn_goose": (0.0, -1.58, 0.42),
}


def grip(b, size=(0.16, 0.24, 0.46), loc=(0, 0.02, -0.02), swatch="dark"):
    # A pistol grip raked back like the rifle's (18 degrees).
    b.box(size, loc, rot=(18, 0, 0), swatch=swatch)


def revolver(b):
    # S&W 686: stainless frame and a full-underlug 4" barrel, fluted six-shot cylinder, black
    # rubber grip. 0.95 long: a touch over scale so it reads in the hand.
    grip(b, (0.15, 0.24, 0.44), (0, 0.06, -0.04))
    b.box((0.16, 0.06, 0.3), (0, 0.17, -0.02), rot=(18, 0, 0), swatch="dark_d")  # grip backstrap
    b.box((0.14, 0.42, 0.2), (0, -0.1, 0.27), swatch="gun_l")  # frame
    b.cyl(0.13, 0.24, (0, -0.2, 0.3), segs=6, rot=(90, 0, 0), swatch="white_d")  # cylinder
    for i in range(6):  # flutes
        a = math.radians(30 + 60 * i)
        b.box((0.03, 0.2, 0.03), (math.cos(a) * 0.125, -0.2, 0.3 + math.sin(a) * 0.125), swatch="gun")
    b.box((0.1, 0.44, 0.11), (0, -0.54, 0.34), swatch="gun_l")  # barrel
    b.box((0.09, 0.44, 0.08), (0, -0.54, 0.25), swatch="white_d")  # full underlug
    b.box((0.06, 0.44, 0.03), (0, -0.54, 0.41), swatch="gun")  # top rib
    b.box((0.03, 0.05, 0.07), (0, -0.72, 0.44), swatch="red")  # red ramp front sight
    b.box((0.08, 0.05, 0.05), (0, -0.02, 0.4), swatch="dark")  # rear sight
    b.box((0.05, 0.08, 0.1), (0, 0.1, 0.4), rot=(-30, 0, 0), swatch="gun_d")  # hammer spur
    b.box((0.03, 0.2, 0.03), (0, -0.14, 0.12), swatch="gun")  # trigger guard bottom
    b.box((0.03, 0.03, 0.12), (0, -0.23, 0.17), swatch="gun")  # guard front
    b.box((0.03, 0.04, 0.12), (0, -0.1, 0.18), rot=(15, 0, 0), swatch="gun_d")  # trigger
    b.box((0.04, 0.06, 0.04), (0.08, -0.04, 0.3), swatch="gun_d")  # cylinder release


def sniper(b):
    # M2010 ESR: flat dark earth chassis and stock, black barrel and suppressor, scope on rings,
    # bolt handle on the right, a folded bipod under the forend. 3.6 long with the can.
    tan, blk = "tan_d", "dark"
    grip(b, (0.17, 0.26, 0.48), (0, 0.04, -0.02), swatch=blk)
    b.box((0.22, 1.1, 0.26), (0, -0.35, 0.32), swatch=tan)  # receiver / chassis
    b.box((0.2, 0.8, 0.22), (0, -1.1, 0.32), swatch=tan)  # forend
    for x in (-0.105, 0.105):
        for i in range(4):
            b.box((0.02, 0.1, 0.06), (x, -0.85 - i * 0.18, 0.34), swatch="dark_d")  # forend slots
    b.cyl(0.05, 0.62, (0, -1.8, 0.34), segs=8, rot=(90, 0, 0), swatch=blk)  # barrel
    b.cyl(0.09, 0.52, (0, -2.36, 0.34), segs=8, rot=(90, 0, 0), swatch="gun_d")  # suppressor
    b.cyl(0.07, 0.04, (0, -2.6, 0.34), segs=8, rot=(90, 0, 0), swatch="dark_d")  # its end cap
    b.box((0.14, 0.32, 0.3), (0, -0.38, 0.06), swatch=blk)  # magazine
    b.box((0.03, 0.22, 0.03), (0, -0.07, 0.11), swatch="gun")  # trigger guard
    b.box((0.2, 0.72, 0.22), (0, 0.6, 0.3), swatch=tan)  # stock
    b.box((0.15, 0.4, 0.1), (0, 0.55, 0.46), swatch=blk)  # cheek riser
    b.box((0.22, 0.1, 0.46), (0, 0.98, 0.24), swatch=blk)  # butt pad
    b.box((0.14, 0.5, 0.1), (0, 0.62, 0.08), swatch=tan)  # lower stock strut
    b.box((0.12, 0.12, 0.14), (0, 0.84, 0.06), swatch=blk)  # monopod nub
    b.cyl(0.035, 0.24, (0.16, 0.02, 0.38), segs=6, rot=(0, 90, 0), swatch=blk)  # bolt handle
    b.ico(0.065, (0.29, 0.04, 0.36), subdiv=1, swatch=blk)  # bolt knob
    b.cyl(0.07, 0.9, (0, -0.35, 0.62), segs=8, rot=(90, 0, 0), swatch=blk)  # scope tube
    b.cyl(0.11, 0.22, (0, -0.86, 0.62), segs=8, rot=(90, 0, 0), swatch=blk)  # objective bell
    b.cyl(0.09, 0.18, (0, 0.14, 0.62), segs=8, rot=(90, 0, 0), swatch=blk)  # eyepiece
    b.cyl(0.08, 0.02, (0, -0.98, 0.62), segs=8, rot=(90, 0, 0), swatch="glass_l")  # objective lens
    b.cyl(0.05, 0.1, (0, -0.35, 0.73), segs=6, swatch="dark_d")  # elevation turret
    b.cyl(0.05, 0.1, (0.11, -0.35, 0.62), segs=6, rot=(0, 90, 0), swatch="dark_d")  # windage turret
    for y in (-0.6, -0.1):
        b.box((0.15, 0.08, 0.17), (0, y, 0.5), swatch="gun_d")  # scope rings
    for x in (-0.06, 0.06):
        b.box((0.04, 0.5, 0.04), (x, -1.15, 0.18), swatch="gun_d")  # bipod legs, folded


def goose(b):
    # M3 recoilless rifle (84 mm, the "Goose"): olive drab tube over the hand, flared venturi at
    # the back, pistol grip and front grip under it, shoulder rest, the sight on the left.
    tube_z = 0.42
    b.cyl(0.2, 2.6, (0, -0.2, tube_z), segs=10, rot=(90, 0, 0), swatch="olive")  # tube
    b.cyl(0.25, 0.36, (0, 1.24, tube_z), segs=10, r2=0.19, rot=(90, 0, 0), swatch="dark")  # venturi
    b.cyl(0.17, 0.02, (0, 1.43, tube_z), segs=10, rot=(90, 0, 0), swatch="dark_d")  # venturi mouth
    b.cyl(0.22, 0.12, (0, -1.52, tube_z), segs=10, rot=(90, 0, 0), swatch="olive_d")  # muzzle ring
    b.cyl(0.16, 0.02, (0, -1.585, tube_z), segs=10, rot=(90, 0, 0), swatch="dark_d")  # the bore
    for y in (-0.9, 0.55):
        b.cyl(0.215, 0.08, (0, y, tube_z), segs=10, rot=(90, 0, 0), swatch="olive_d")  # bands
    b.box((0.02, 0.5, 0.12), (0.2, -0.3, tube_z), swatch="brass")  # stencil band on the right
    grip(b, (0.16, 0.24, 0.44), (0, 0.02, -0.02))
    b.box((0.14, 0.32, 0.14), (0, -0.05, 0.22), swatch="dark")  # trigger housing
    b.box((0.03, 0.2, 0.03), (0, -0.08, 0.08), swatch="gun")  # trigger guard
    b.box((0.14, 0.18, 0.4), (0, -0.78, 0.1), swatch="dark")  # front grip
    b.box((0.16, 0.5, 0.14), (0, 0.6, 0.18), swatch="dark")  # shoulder rest
    b.box((0.2, 0.12, 0.3), (0, 0.86, 0.14), swatch="dark_l")  # its pad
    b.box((0.12, 0.34, 0.2), (-0.3, -0.4, tube_z + 0.12), swatch="dark")  # sight on the left
    b.box((0.1, 0.06, 0.14), (-0.3, -0.58, tube_z + 0.12), swatch="glass_l")  # sight lens
    b.box((0.16, 0.1, 0.06), (-0.2, -0.4, tube_z + 0.04), swatch="dark_d")  # sight mount
    b.box((0.06, 0.16, 0.16), (0.2, 0.95, tube_z), swatch="dark_d")  # venturi lock lever
    b.box((0.4, 0.06, 0.04), (0, 0.2, tube_z + 0.21), swatch="dark_d")  # carry sling bar


GUN_PIECES = {
    "wpn_revolver": revolver,
    "wpn_sniper": sniper,
    "wpn_goose": goose,
}


def register(ba):
    """Adds every held gun in this file to build_assets' ASSETS table (origin = the grip)."""
    for name, fn in GUN_PIECES.items():
        ba.ASSETS[name] = (fn, "Weapons", "center")  # "center" leaves the design origin (the grip) alone, like wpn_rifle
