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
    "wpn_m16": (0.0, -2.02, 0.36),
    "wpn_mp5": (0.0, -1.49, 0.32),
    "wpn_m249": (0.0, -1.89, 0.38),
    "wpn_mossberg": (0.0, -1.8, 0.42),
    "wpn_m110": (0.0, -2.45, 0.4),
    "wpn_m17": (0.0, -0.485, 0.32),
}

# The iron sights' line, Blender (x, y, z) from the grip: the centre of the rear aperture (the
# front post's tip sits at the same height). MeshAssets takes it in Roblox order (x, z, y) as
# `sight`; first person looks through it down the sights.
SIGHT = {
    "wpn_m16": (0.0, 0.04, 0.615),
    "wpn_m17": (0.0, 0.11, 0.45),  # the rear sight's tops, level with the front post's
    "wpn_revolver": (0.0, -0.02, 0.45),
    "wpn_mp5": (0.0, 0.05, 0.585),
    "wpn_m249": (0.0, 0.03, 0.68),
    "wpn_mossberg": (0.0, 0.1, 0.5),  # along the receiver's top channel to the bead
    # Scopes: on the tube's axis, 0.85 ahead of the eyepiece, so first person (which puts the
    # eye Config.Camera.FirstPerson.SightEye behind this point) ends just behind it.
    "wpn_m110": (0.0, 0.17 - 0.85, 0.64),
    "wpn_sniper": (0.0, 0.23 - 0.85, 0.62),
    "wpn_goose": (-0.3, -0.23 - 0.85, 0.54),
}


def ring(b, x, y, z, r, t, swatch="dark"):
    # A thin ring round the Y axis (eight flat segments): a scope bezel, a front sight hood.
    for i in range(8):
        a = 2 * math.pi * i / 8
        b.box((t, 0.02, 0.83 * r + t), (x + r * math.cos(a), y, z + r * math.sin(a)),
              rot=(0, -math.degrees(a), 0), swatch=swatch)


def look_through_scope(b, x, z, y_obj, y_tube0, y_tube1, y_eye, r_tube, r_obj, r_eye):
    # A riflescope you can look through: open tube and bells (no lens to block the view), a
    # bezel at the eyepiece, the objective's rim, and a crosshair reticle inside the objective.
    def tube(r, y0, y1, r2=None):
        b.cyl(r, y1 - y0, (x, (y0 + y1) / 2, z), segs=12, r2=r2, rot=(90, 0, 0), swatch="dark", cap=False)
    tube(r_obj, y_obj, y_tube0, r_tube)  # objective bell
    tube(r_tube, y_tube0, y_tube1)  # main tube
    tube(r_tube, y_tube1, y_eye, r_eye)  # eyepiece
    ring(b, x, y_eye, z, r_eye, 0.025)  # eyepiece bezel
    ring(b, x, y_obj, z, r_obj, 0.02)  # objective rim
    yr = y_obj + 0.06
    b.box((0.006, 0.006, 2 * r_obj), (x, yr, z), swatch="dark_d")  # reticle, vertical
    b.box((2 * r_obj, 0.006, 0.006), (x, yr, z), swatch="dark_d")  # and horizontal
    b.box((0.014, 0.008, 0.014), (x, yr, z), swatch="red")  # a red centre dot


def peep(b, y, h, top, w=0.072, hole=0.026, swatch="dark"):
    # An aperture leaf: a square frame round a small peep centred on the sight line h,
    # standing from its base at top.
    b.box((w, 0.018, h - hole / 2 - top), (0, y, (top + h - hole / 2) / 2), swatch=swatch)
    b.box((w, 0.018, 0.02), (0, y, h + hole / 2 + 0.01), swatch=swatch)
    for x in (-1, 1):
        b.box(((w - hole) / 2, 0.018, hole), (x * (hole / 2 + (w - hole) / 4), y, h), swatch=swatch)
SIGHT_H = 0.615  # the M16's sight line above the grip


def m4_rear_sight(b, y=0.04, base_z=0.51):
    # A flip-up rear sight on the flat-top rail (the M4's backup irons): a clamp on the rail, two
    # protective ears, and between them the aperture leaf, a square frame round a small peep
    # whose centre is the sight line; a windage knob on the right.
    h = SIGHT_H
    b.box((0.1, 0.14, 0.035), (0, y, base_z + 0.0175), swatch="dark")  # rail clamp
    b.box((0.12, 0.05, 0.03), (0, y + 0.05, base_z + 0.015), swatch="dark_d")  # clamp bar
    for x in (-0.046, 0.046):
        b.box((0.02, 0.11, 0.12), (x, y, base_z + 0.035 + 0.06), swatch="dark")  # ears
    top = base_z + 0.035
    hole = 0.026  # the peep
    b.box((0.072, 0.018, h - hole / 2 - top), (0, y, (top + h - hole / 2) / 2), swatch="dark")  # leaf below
    b.box((0.072, 0.018, 0.02), (0, y, h + hole / 2 + 0.01), swatch="dark")  # leaf above
    for x in (-1, 1):
        b.box((0.023, 0.018, hole), (x * (hole / 2 + 0.0115), y, h), swatch="dark")  # leaf sides
    b.cyl(0.022, 0.03, (0.07, y, base_z + 0.06), segs=8, rot=(0, 90, 0), swatch="gun_d")  # windage


def m4_front_sight(b, y=-1.4, barrel_z=0.36):
    # The A2 "triangle" front sight base on the barrel: a collar round the barrel with the
    # bayonet lug under it, the triangle rising to a crossbar, two protective wings, and the
    # square post between them, its tip on the sight line.
    h = SIGHT_H
    b.box((0.12, 0.11, 0.11), (0, y, barrel_z), swatch="dark")  # collar on the barrel
    b.box((0.04, 0.06, 0.07), (0, y + 0.01, barrel_z - 0.09), swatch="dark")  # bayonet lug
    # The triangle: flat on the collar, its back face upright (+Y, toward the shooter), sloping
    # down to the muzzle as on a real AR.
    rise = 0.13
    b.wedge((0.15, 0.07, rise), (0, y + 0.01, barrel_z + 0.055 + rise / 2), rot=(0, 0, -90), swatch="dark")
    bar_z = barrel_z + 0.055 + rise  # top of the triangle
    back = y + 0.055  # the wings and post stand over the upright back face
    b.box((0.11, 0.06, 0.03), (0, back, bar_z + 0.015), swatch="dark")  # crossbar
    for x in (-0.046, 0.046):
        b.box((0.018, 0.06, h + 0.035 - bar_z), (x, back, (bar_z + h + 0.035) / 2), swatch="dark")  # wings
    b.box((0.022, 0.022, h - bar_z), (0, back, (bar_z + h) / 2), swatch="dark_d")  # post


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
    # Irons: a square-notch rear sight on the topstrap, a ramp front blade on the rib with the
    # red insert facing the shooter; the blade's top level with the rear's tops (SIGHT).
    b.box((0.08, 0.06, 0.03), (0, -0.02, 0.385), swatch="dark")  # rear sight base
    for x in (-0.026, 0.026):
        b.box((0.026, 0.05, 0.05), (x, -0.02, 0.425), swatch="dark")  # either side of the notch
    b.wedge((0.07, 0.022, 0.025), (0, -0.72, 0.4375), rot=(0, 0, -90), swatch="gun_l")  # ramp
    b.box((0.024, 0.012, 0.02), (0, -0.689, 0.438), swatch="red")  # red insert
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
    look_through_scope(b, 0, 0.62, -0.97, -0.75, 0.05, 0.23, 0.07, 0.11, 0.09)  # the scope
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
    # The 3x telescopic sight on the left, looked through (a short open tube, reticle inside).
    look_through_scope(b, -0.3, tube_z + 0.12, -0.6, -0.56, -0.28, -0.23, 0.06, 0.07, 0.065)
    b.box((0.16, 0.1, 0.06), (-0.2, -0.4, tube_z + 0.04), swatch="dark_d")  # sight mount
    b.box((0.06, 0.16, 0.16), (0.2, 0.95, tube_z), swatch="dark_d")  # venturi lock lever
    b.box((0.4, 0.06, 0.04), (0, 0.2, tube_z + 0.21), swatch="dark_d")  # carry sling bar


# ------------------------------------------------------------------ the six original guns
# (owner 2026-11-09: "just make them"): until now every one wore wpn_rifle.


def trigger_group(b, y=-0.1, swatch="gun"):
    # A real loop under the receiver: bottom bar, front post, and the trigger inside it.
    b.box((0.035, 0.26, 0.035), (0, y, 0.055), swatch=swatch)  # guard bottom
    b.box((0.035, 0.035, 0.13), (0, y - 0.13, 0.11), swatch=swatch)  # guard front
    b.box((0.03, 0.04, 0.1), (0, y + 0.01, 0.13), rot=(18, 0, 0), swatch="dark_d")  # trigger


def curved_mag(b, top, size, rakes, swatch="dark_d"):
    # A magazine as segments stacked down from `top` (y, z), each raked further forward, so it
    # bends like the real thing instead of hanging as one brick.
    w, d, h = size
    y, z = top
    for i, a in enumerate(rakes):
        r = math.radians(a)
        dy, dz = -math.sin(r) * h, -math.cos(r) * h  # forward (-Y) and down
        b.box((w, d, h + 0.02), (0, y + dy / 2, z + dz / 2), rot=(-a, 0, 0), swatch=swatch)
        y, z = y + dy, z + dz
    b.box((w + 0.02, d + 0.03, 0.04), (0, y, z), rot=(-rakes[-1], 0, 0), swatch="dark")  # floor plate


def tapered_stock(b, y0, y1, ztop, h_front, h_back, w, swatch="dark", pad="dark_d"):
    # A stock whose top line runs straight back and whose belly drops toward the butt (the A2 /
    # shotgun profile): a level box as tall as the front, a wedge under it that grows to the
    # back's height, and the butt plate.
    length, mid = y1 - y0, (y0 + y1) / 2
    b.box((w, length, h_front), (0, mid, ztop - h_front / 2), swatch=swatch)
    drop = h_back - h_front
    # The builder's wedge is full height at -X with a flat bottom; flipped and turned it is
    # flat on top and full height at +Y (the butt).
    b.wedge((length, w, drop), (0, mid, ztop - h_front - drop / 2), rot=(0, 180, 90), swatch=swatch)
    b.box((w + 0.02, 0.06, h_back + 0.02), (0, y1 + 0.03, ztop - h_back / 2), swatch=pad)  # butt


def m16(b):
    # M16A4: black, fixed A2 stock, flat-top upper with a round ribbed handguard, M4-style iron
    # sights (a flip-up peep on the rail, the triangle front sight with its post between two
    # wings; Nova 2026-11-10: "should look like a real m4's iron sights"), a curved 30-round
    # magazine. 3.1 long.
    grip(b, (0.15, 0.24, 0.44), (0, 0.02, -0.02))
    b.box((0.17, 0.6, 0.18), (0, -0.2, 0.2), swatch="dark")  # lower receiver
    b.box((0.19, 0.24, 0.16), (0, -0.42, 0.07), swatch="dark")  # flared magwell
    curved_mag(b, (-0.42, 0.0), (0.13, 0.22, 0.15), (6, 14, 22))
    b.box((0.16, 0.72, 0.18), (0, -0.22, 0.37), swatch="dark")  # upper receiver
    b.box((0.09, 0.72, 0.05), (0, -0.22, 0.485), swatch="gun_d")  # flat-top rail
    for i in range(7):
        b.box((0.11, 0.03, 0.02), (0, 0.1 - i * 0.1, 0.515), swatch="dark_d")  # rail slots
    m4_rear_sight(b)
    b.box((0.12, 0.06, 0.04), (0, 0.12, 0.46), swatch="gun_d")  # charging handle
    b.box((0.02, 0.2, 0.1), (0.09, -0.2, 0.37), swatch="gun")  # ejection port cover
    b.cyl(0.03, 0.08, (0.1, -0.02, 0.36), segs=6, rot=(0, 90, 0), swatch="gun_d")  # forward assist
    b.cyl(0.03, 0.04, (0, -0.6, 0.36), segs=8, rot=(90, 0, 0), swatch="gun_d")  # delta ring
    b.cyl(0.11, 0.72, (0, -0.97, 0.36), segs=8, rot=(90, 0, 0), swatch="dark")  # round handguard
    for i in range(6):
        b.cyl(0.115, 0.03, (0, -0.7 - i * 0.11, 0.36), segs=8, rot=(90, 0, 0), swatch="dark_d")  # ribs
    m4_front_sight(b)
    b.cyl(0.03, 0.66, (0, -1.65, 0.36), segs=8, rot=(90, 0, 0), swatch="gun_d")  # barrel
    b.cyl(0.045, 0.12, (0, -1.96, 0.36), segs=8, rot=(90, 0, 0), swatch="dark")  # flash hider
    tapered_stock(b, 0.18, 1.0, 0.44, 0.18, 0.4, 0.15)
    trigger_group(b)


def mp5(b):
    # MP5A3: short, black, the slim tapered handguard, drum rear sight, cocking tube on top, a
    # strongly curved magazine, retractable stock on two rails. 2.2 long.
    grip(b, (0.14, 0.22, 0.42), (0, 0.02, -0.02))
    b.box((0.15, 0.9, 0.2), (0, -0.35, 0.33), swatch="dark")  # receiver
    b.cyl(0.075, 1.0, (0, -0.37, 0.45), segs=8, rot=(90, 0, 0), swatch="dark")  # cocking tube
    # HK irons: the rotary drum rear (a disc turning on the bore's axis, its peep on top,
    # guarded by two ears) and the hooded front post; post tip level with the peep (SIGHT).
    h = SIGHT["wpn_mp5"][2]
    b.box((0.09, 0.08, 0.04), (0, 0.05, 0.54), swatch="dark")  # drum housing on the tube
    b.cyl(0.05, 0.05, (0, 0.05, 0.53), segs=10, rot=(90, 0, 0), swatch="dark_d")  # the drum
    peep(b, 0.05, h, 0.56, w=0.06, hole=0.022)
    for x in (-0.042, 0.042):
        b.box((0.016, 0.08, 0.08), (x, 0.05, 0.6), swatch="dark")  # ears
    b.box((0.08, 0.07, 0.05), (0, -0.85, 0.52), swatch="dark")  # front sight base on the tube
    ring(b, 0, -0.85, h, 0.05, 0.014)  # the hood
    b.box((0.016, 0.02, h - 0.545), (0, -0.85, (0.545 + h) / 2), swatch="dark_d")  # the post
    b.box((0.13, 0.22, 0.12), (0, -0.42, 0.18), swatch="dark")  # magwell
    curved_mag(b, (-0.42, 0.13), (0.11, 0.17, 0.14), (12, 24, 36))
    b.cyl(0.1, 0.42, (0, -0.98, 0.3), segs=8, r2=0.085, rot=(90, 0, 0), swatch="dark")  # handguard
    b.cyl(0.03, 0.26, (0, -1.32, 0.34), segs=8, rot=(90, 0, 0), swatch="gun_d")  # barrel
    b.cyl(0.042, 0.06, (0, -1.46, 0.34), segs=8, rot=(90, 0, 0), swatch="dark")  # muzzle
    b.box((0.08, 0.03, 0.03), (-0.1, -0.85, 0.45), swatch="gun")  # cocking handle
    for x in (-0.06, 0.06):
        b.box((0.03, 0.56, 0.03), (x, 0.38, 0.36), swatch="gun")  # stock rails
    b.box((0.16, 0.06, 0.3), (0, 0.68, 0.32), swatch="dark")  # butt pad
    trigger_group(b)


def m249(b):
    # M249 SAW: a big black receiver with the ridged feed cover, an olive soft ammo pouch with
    # the brass belt going in, carry handle, heat shield, folded bipod, the skeleton stock.
    grip(b, (0.16, 0.24, 0.44), (0, 0.02, -0.02))
    b.box((0.24, 0.9, 0.3), (0, -0.2, 0.36), swatch="dark")  # receiver
    b.box((0.22, 0.5, 0.06), (0, -0.2, 0.54), swatch="gun_d")  # feed tray cover
    for i in range(4):
        b.box((0.23, 0.03, 0.03), (0, -0.02 - i * 0.12, 0.58), swatch="dark_d")  # cover ribs
    b.box((0.3, 0.36, 0.38), (-0.05, -0.36, 0.0), swatch="olive")  # soft ammo pouch
    b.box((0.31, 0.05, 0.36), (-0.05, -0.55, 0.0), swatch="olive_d")  # its flap seam
    b.box((0.06, 0.12, 0.18), (-0.15, -0.36, 0.24), swatch="brass")  # belt into the feed
    for i in range(3):
        b.box((0.07, 0.035, 0.05), (-0.15, -0.32 - i * 0.04, 0.34), swatch="brass")  # rounds
    # The carrying handle sits on the left of the barrel, clear of the sight line.
    b.box((0.04, 0.4, 0.04), (-0.12, -0.92, 0.6), swatch="gun_d")  # carry handle
    for y in (-0.75, -1.08):
        b.box((0.04, 0.04, 0.12), (-0.1, y, 0.54), swatch="gun_d")
    # Irons: a folding leaf rear sight on the feed cover's back, a front post between two ears
    # near the muzzle; post tip level with the peep (SIGHT).
    h = SIGHT["wpn_m249"][2]
    b.box((0.12, 0.08, 0.03), (0, 0.03, 0.61), swatch="dark")  # rear sight base
    peep(b, 0.03, h, 0.625)
    b.cyl(0.02, 0.03, (0.07, 0.03, 0.64), segs=8, rot=(0, 90, 0), swatch="gun_d")  # elevation knob
    b.box((0.13, 0.5, 0.1), (0, -1.0, 0.48), swatch="gun_d")  # heat shield
    for i in range(4):
        b.box((0.135, 0.05, 0.02), (0, -0.82 - i * 0.12, 0.535), swatch="dark_d")  # its vents
    b.cyl(0.045, 1.1, (0, -1.2, 0.38), segs=8, rot=(90, 0, 0), swatch="gun_d")  # barrel
    b.cyl(0.06, 0.14, (0, -1.82, 0.38), segs=8, rot=(90, 0, 0), swatch="dark")  # flash hider
    b.box((0.08, 0.06, 0.14), (0, -1.68, 0.49), swatch="dark")  # front sight block
    for x in (-0.04, 0.04):
        b.box((0.016, 0.05, h + 0.025 - 0.56), (x, -1.68, (0.56 + h + 0.025) / 2), swatch="dark")  # ears
    b.box((0.02, 0.02, h - 0.56), (0, -1.68, (0.56 + h) / 2), swatch="dark_d")  # the post
    for x in (-0.08, 0.08):
        b.box((0.04, 0.6, 0.04), (x, -1.2, 0.26), swatch="gun_d")  # bipod, folded
    # Skeleton stock: a top tube, a strut sloping down to the butt, the pad.
    b.cyl(0.045, 0.75, (0, 0.6, 0.42), segs=8, rot=(90, 0, 0), swatch="dark")
    b.box((0.06, 0.82, 0.06), (0, 0.6, 0.24), rot=(-12, 0, 0), swatch="dark")
    b.box((0.16, 0.08, 0.42), (0, 0.98, 0.3), swatch="dark")
    b.box((0.18, 0.04, 0.4), (0, 1.03, 0.3), swatch="dark_d")
    trigger_group(b)


def mossberg(b):
    # Mossberg 590: black, barrel over a long magazine tube, the round grooved pump, a brass
    # bead, a side saddle of red shells on the left, the dropped shotgun stock.
    grip(b, (0.15, 0.24, 0.44), (0, 0.02, -0.02))
    b.box((0.17, 0.6, 0.26), (0, -0.2, 0.34), swatch="dark")  # receiver
    b.box((0.02, 0.22, 0.1), (0.09, -0.24, 0.38), swatch="dark_d")  # ejection port
    b.cyl(0.045, 1.3, (0, -1.15, 0.42), segs=8, rot=(90, 0, 0), swatch="gun_d")  # barrel
    b.cyl(0.05, 1.0, (0, -1.0, 0.3), segs=8, rot=(90, 0, 0), swatch="gun_d")  # magazine tube
    b.cyl(0.1, 0.42, (0, -0.85, 0.3), segs=8, rot=(90, 0, 0), swatch="dark")  # round pump
    for y in (-0.7, -0.78, -0.86, -0.94, -1.02):
        b.cyl(0.105, 0.03, (0, y, 0.3), segs=8, rot=(90, 0, 0), swatch="dark_d")  # grooves
    b.box((0.1, 0.05, 0.18), (0, -1.7, 0.36), swatch="dark")  # barrel clamp
    # A brass bead on a short base at the muzzle, sighted down the grooved channel along the
    # receiver's top (the 590's sights; SIGHT is the channel's line, level with the bead).
    b.box((0.03, 0.05, 0.03), (0, -1.79, 0.475), swatch="dark")  # bead base
    b.ico(0.03, (0, -1.79, 0.5), subdiv=1, swatch="brass")  # the bead
    for x in (-0.035, 0.035):
        b.box((0.02, 0.5, 0.025), (x, -0.2, 0.4825), swatch="dark_d")  # channel ridges
    b.box((0.03, 0.32, 0.16), (-0.1, -0.22, 0.34), swatch="dark_d")  # side saddle
    for i in range(4):
        y = -0.33 + i * 0.075
        b.box((0.05, 0.06, 0.13), (-0.13, y, 0.34), swatch="red")  # shells
        b.box((0.052, 0.062, 0.03), (-0.13, y, 0.27), swatch="brass")  # their bases
    tapered_stock(b, 0.12, 0.98, 0.46, 0.16, 0.42, 0.15, pad="dark_l")
    trigger_group(b)


def m110(b):
    # M110 SASS: an AR-10, black receiver, long flat dark earth handguard, straight 20-round
    # magazine, a scope and a suppressor; crane stock on a buffer tube. 3.25 long.
    grip(b, (0.16, 0.24, 0.46), (0, 0.02, -0.02))
    b.box((0.18, 0.64, 0.2), (0, -0.2, 0.2), swatch="dark")  # lower receiver
    b.box((0.18, 0.74, 0.2), (0, -0.22, 0.39), swatch="dark")  # upper receiver
    b.box((0.2, 0.26, 0.14), (0, -0.42, 0.06), swatch="dark")  # flared magwell
    curved_mag(b, (-0.42, -0.0), (0.14, 0.24, 0.16), (4, 6))
    b.cyl(0.115, 0.95, (0, -1.06, 0.4), segs=8, rot=(90, 0, 0), swatch="tan")  # handguard
    for i in range(5):
        b.box((0.235, 0.08, 0.04), (0, -0.7 - i * 0.18, 0.4), swatch="tan_d")  # slots
    b.cyl(0.04, 0.45, (0, -1.75, 0.4), segs=8, rot=(90, 0, 0), swatch="dark")  # barrel
    b.cyl(0.085, 0.5, (0, -2.2, 0.4), segs=8, rot=(90, 0, 0), swatch="gun_d")  # suppressor
    b.cyl(0.07, 0.03, (0, -2.45, 0.4), segs=8, rot=(90, 0, 0), swatch="dark_d")  # its end cap
    b.cyl(0.055, 0.4, (0, 0.36, 0.4), segs=8, rot=(90, 0, 0), swatch="dark")  # buffer tube
    tapered_stock(b, 0.3, 0.74, 0.47, 0.14, 0.3, 0.15, swatch="tan", pad="dark")  # crane stock
    look_through_scope(b, 0, 0.64, -0.79, -0.61, 0.03, 0.17, 0.065, 0.095, 0.085)  # the scope
    b.cyl(0.04, 0.08, (0, -0.3, 0.72), segs=6, swatch="dark_d")  # turret
    for y in (-0.5, -0.1):
        b.box((0.14, 0.08, 0.14), (0, y, 0.54), swatch="gun_d")  # rings
    trigger_group(b)


def m17(b):
    # M17 (P320): coyote tan frame and grip, black slide with rear serrations, notch-and-post
    # irons with a white front dot.
    # 0.7 long: a touch over scale so it reads in the hand.
    tan = "tan"
    b.box((0.14, 0.2, 0.4), (0, 0.04, -0.06), rot=(15, 0, 0), swatch=tan)  # grip
    b.box((0.12, 0.16, 0.04), (0, 0.1, -0.27), rot=(15, 0, 0), swatch="dark")  # magazine base
    b.box((0.14, 0.5, 0.1), (0, -0.14, 0.2), swatch=tan)  # frame
    b.box((0.13, 0.62, 0.15), (0, -0.16, 0.32), swatch="dark")  # slide
    for y in (0.06, 0.1, 0.14):
        b.box((0.135, 0.02, 0.12), (0, y, 0.32), swatch="dark_d")  # serrations
    b.box((0.06, 0.02, 0.06), (0, -0.475, 0.32), swatch="dark_d")  # the muzzle
    # Irons: a square-notch rear sight and a front post with a white dot facing the shooter; the
    # post's top is level with the rear sight's tops (the sight line, SIGHT).
    b.box((0.1, 0.04, 0.02), (0, 0.11, 0.405), swatch="dark_d")  # rear sight base
    for x in (-0.0325, 0.0325):
        b.box((0.035, 0.04, 0.035), (x, 0.11, 0.4325), swatch="dark_d")  # either side of the notch
    b.box((0.03, 0.03, 0.055), (0, -0.43, 0.4225), swatch="dark_d")  # front post
    b.box((0.016, 0.006, 0.016), (0, -0.4135, 0.435), swatch="white_l")  # its dot
    b.box((0.03, 0.18, 0.03), (0, -0.1, 0.06), swatch=tan)  # trigger guard
    b.box((0.03, 0.03, 0.12), (0, -0.19, 0.11), swatch=tan)
    b.box((0.03, 0.04, 0.1), (0, -0.08, 0.13), rot=(15, 0, 0), swatch="dark")  # trigger


GUN_PIECES = {
    "wpn_revolver": revolver,
    "wpn_sniper": sniper,
    "wpn_goose": goose,
    "wpn_m16": m16,
    "wpn_mp5": mp5,
    "wpn_m249": m249,
    "wpn_mossberg": mossberg,
    "wpn_m110": m110,
    "wpn_m17": m17,
}


def register(ba):
    """Adds every held gun in this file to build_assets' ASSETS table (origin = the grip)."""
    for name, fn in GUN_PIECES.items():
        ba.ASSETS[name] = (fn, "Weapons", "center")  # "center" leaves the design origin (the grip) alone, like wpn_rifle
