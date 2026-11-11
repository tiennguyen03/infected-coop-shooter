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
    # M16A4: black, fixed A2 stock, flat-top upper with a round ribbed handguard, the triangle
    # front sight, a curved 30-round magazine. 3.1 long.
    grip(b, (0.15, 0.24, 0.44), (0, 0.02, -0.02))
    b.box((0.17, 0.6, 0.18), (0, -0.2, 0.2), swatch="dark")  # lower receiver
    b.box((0.19, 0.24, 0.16), (0, -0.42, 0.07), swatch="dark")  # flared magwell
    curved_mag(b, (-0.42, 0.0), (0.13, 0.22, 0.15), (6, 14, 22))
    b.box((0.16, 0.72, 0.18), (0, -0.22, 0.37), swatch="dark")  # upper receiver
    b.box((0.09, 0.72, 0.05), (0, -0.22, 0.485), swatch="gun_d")  # flat-top rail
    for i in range(7):
        b.box((0.11, 0.03, 0.02), (0, 0.1 - i * 0.1, 0.515), swatch="dark_d")  # rail slots
    b.box((0.06, 0.12, 0.12), (0, 0.05, 0.57), swatch="dark")  # rear sight
    b.box((0.12, 0.06, 0.04), (0, 0.12, 0.46), swatch="gun_d")  # charging handle
    b.box((0.02, 0.2, 0.1), (0.09, -0.2, 0.37), swatch="gun")  # ejection port cover
    b.cyl(0.03, 0.08, (0.1, -0.02, 0.36), segs=6, rot=(0, 90, 0), swatch="gun_d")  # forward assist
    b.cyl(0.03, 0.04, (0, -0.6, 0.36), segs=8, rot=(90, 0, 0), swatch="gun_d")  # delta ring
    b.cyl(0.11, 0.72, (0, -0.97, 0.36), segs=8, rot=(90, 0, 0), swatch="dark")  # round handguard
    for i in range(6):
        b.cyl(0.115, 0.03, (0, -0.7 - i * 0.11, 0.36), segs=8, rot=(90, 0, 0), swatch="dark_d")  # ribs
    b.box((0.1, 0.1, 0.12), (0, -1.38, 0.38), swatch="dark")  # front sight base
    b.box((0.05, 0.07, 0.22), (0, -1.38, 0.52), rot=(-12, 0, 0), swatch="dark")  # sight post
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
    b.cyl(0.06, 0.1, (0, 0.05, 0.56), segs=8, rot=(0, 90, 0), swatch="dark_d")  # drum rear sight
    b.box((0.05, 0.08, 0.06), (0, 0.05, 0.5), swatch="dark")  # its post
    b.box((0.1, 0.06, 0.14), (0, -0.85, 0.54), swatch="dark")  # front sight hood
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
    b.box((0.04, 0.4, 0.04), (0, -0.92, 0.66), swatch="gun_d")  # carry handle
    for y in (-0.75, -1.08):
        b.box((0.04, 0.04, 0.16), (0, y, 0.58), swatch="gun_d")
    b.box((0.13, 0.5, 0.1), (0, -1.0, 0.48), swatch="gun_d")  # heat shield
    for i in range(4):
        b.box((0.135, 0.05, 0.02), (0, -0.82 - i * 0.12, 0.535), swatch="dark_d")  # its vents
    b.cyl(0.045, 1.1, (0, -1.2, 0.38), segs=8, rot=(90, 0, 0), swatch="gun_d")  # barrel
    b.cyl(0.06, 0.14, (0, -1.82, 0.38), segs=8, rot=(90, 0, 0), swatch="dark")  # flash hider
    b.box((0.05, 0.05, 0.16), (0, -1.68, 0.5), swatch="dark")  # front sight
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
    b.ico(0.025, (0, -1.79, 0.48), subdiv=0, swatch="brass")  # bead sight
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
    b.cyl(0.065, 0.7, (0, -0.3, 0.64), segs=8, rot=(90, 0, 0), swatch="dark")  # scope tube
    b.cyl(0.095, 0.18, (0, -0.7, 0.64), segs=8, rot=(90, 0, 0), swatch="dark")  # objective
    b.cyl(0.085, 0.14, (0, 0.1, 0.64), segs=8, rot=(90, 0, 0), swatch="dark")  # eyepiece
    b.cyl(0.07, 0.02, (0, -0.8, 0.64), segs=8, rot=(90, 0, 0), swatch="glass_l")  # lens
    b.cyl(0.04, 0.08, (0, -0.3, 0.72), segs=6, swatch="dark_d")  # turret
    for y in (-0.5, -0.1):
        b.box((0.14, 0.08, 0.14), (0, y, 0.54), swatch="gun_d")  # rings
    trigger_group(b)


def m17(b):
    # M17 (P320): coyote tan frame and grip, black slide with rear serrations, white front dot.
    # 0.7 long: a touch over scale so it reads in the hand.
    tan = "tan"
    b.box((0.14, 0.2, 0.4), (0, 0.04, -0.06), rot=(15, 0, 0), swatch=tan)  # grip
    b.box((0.12, 0.16, 0.04), (0, 0.1, -0.27), rot=(15, 0, 0), swatch="dark")  # magazine base
    b.box((0.14, 0.5, 0.1), (0, -0.14, 0.2), swatch=tan)  # frame
    b.box((0.13, 0.62, 0.15), (0, -0.16, 0.32), swatch="dark")  # slide
    for y in (0.06, 0.1, 0.14):
        b.box((0.135, 0.02, 0.12), (0, y, 0.32), swatch="dark_d")  # serrations
    b.box((0.06, 0.02, 0.06), (0, -0.475, 0.32), swatch="dark_d")  # the muzzle
    b.box((0.03, 0.03, 0.04), (0, -0.43, 0.415), swatch="white_l")  # front dot
    b.box((0.1, 0.04, 0.05), (0, 0.11, 0.42), swatch="dark_d")  # rear sight
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
