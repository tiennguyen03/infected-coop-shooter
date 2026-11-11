"""The Checkpoint Delta v2 kit: a PROPOSAL (owner, 2026-11-11: "some of the car models are
simple, but some of them were more complex. There's a lot of inconsistencies like that").
Nothing here is loaded by the game: no MeshAssets rows, no uploads.

Two jobs:

1. One vehicle set at one detail level. The four cars and the cargo truck in props.py are the
   standard (side silhouette extruded with wheel arches, separate glass, 850-970 tris, true to
   the 5-stud figure). The two outliers are rebuilt to it: `env_wreck_humvee` (392 tris of
   boxes) -> `prop_humvee` / `prop_humvee_burnt`, `env_bus` (712 tris of boxes, 42 x 10 x 12.5:
   a third too big beside the cars) -> `prop_bus`. Two shapes the checkpoint needs are added
   the same way: `prop_car_suv`, `prop_ambulance`.
2. The checkpoint's own pieces, each a repeated instance: perimeter wall, hesco row, screening
   and decon tents, tables, luggage, signs, the sign gantry, steel stairs, catwalk, fuel tank,
   drum, dish, and the backdrop (pine stand, far hill).

Registered by `register(ba)` like props.py. build_assets.py only calls it with `--delta-v2`
(the proposal flag), so a normal build writes no FBX for these:

    blender --background --python assets/3d/build/build_assets.py -- --delta-v2 --only prop_bus

`delta_v2.py` registers the kit itself to build the map proposal.
"""

import math

import props as P

# name -> (class in docs/STYLES.md §6 "Budgets", triangle cap)
CAPS = {}


# ------------------------------------------------------------------ vehicles
def car_suv(b):
    # Two-box SUV 15.0 x 6.2, roof 5.8; faded navy; a duffel and a case on the roof bars, the
    # spare on the tailgate. Roof is CLIMB (5.8): a Walker cannot follow.
    L, W, r, sill = 15.0, 6.2, 1.2, 0.9
    wx = (-4.6, 4.5)
    body = P.body_outline(L, sill, [(7.5, 3.0), (7.3, 3.5), (-3.4, 3.5), (-7.0, 3.2), (-7.5, 2.6)], wx, r)
    P.profile(b, body, W, "paint_navy")
    gw = W - 0.7
    P.profile(b, [(-3.4, 3.45), (7.2, 3.45), (6.8, 5.8), (-1.8, 5.8)], gw, "paint_navy")
    P.profile(b, P.panel((-3.4, 3.5), (-1.8, 5.8)), gw - 0.3, "glass")
    P.profile(b, P.panel((6.8, 5.75), (7.2, 3.6)), gw - 0.3, "glass")
    P.profile(b, P.panel((-3.2, 5.7), (-1.95, 5.76), thick=0.05, out=0.03), gw - 0.6, "glass_l")
    for sy in (-1, 1):
        y = sy * (gw / 2 + 0.03)
        P.profile(b, [(-2.9, 3.7), (0.6, 3.7), (0.6, 5.5), (-1.7, 5.5)], 0.06, "glass", y=y)
        P.profile(b, [(1.0, 3.7), (3.8, 3.7), (3.8, 5.5), (1.0, 5.5)], 0.06, "glass", y=y)
        P.profile(b, [(4.2, 3.7), (6.75, 3.7), (6.45, 5.5), (4.2, 5.5)], 0.06, "glass", y=y)
        b.box((7.6, 0.14, 0.14), (2.6, sy * 2.2, 5.95), swatch="gun_d")  # roof bars
        b.box((1.2, 0.12, 0.5), (-5.6, sy * (W / 2 + 0.02), 2.2), swatch="rust")  # stone chips gone to rust
    for x in (-0.6, 5.8):
        b.box((0.14, 4.5, 0.14), (x, 0, 5.95), swatch="gun_d")
    b.box((3.0, 2.0, 0.9), (1.2, -0.6, 6.5), rot=(0, 0, 8), swatch="olive_d")  # duffel
    b.box((1.8, 1.2, 0.7), (4.2, 0.9, 6.4), swatch="tan_d")  # case
    b.cyl(1.15, 0.7, (7.95, 0.4, 3.2), segs=10, rot=(0, 90, 0), swatch="dark_d")  # spare
    b.cyl(0.5, 0.74, (7.97, 0.4, 3.2), segs=6, rot=(0, 90, 0), swatch="gun")
    P.seams(b, W, (-3.2, 0.8, 4.0), sill + 0.4, 3.45)
    P.car_details(b, L, W, sill, 2.7, wx, r, "paint_navy", rear_lamp_z=3.1)


def _humvee(b, paint, trim, top, glass, burnt):
    # Army utility truck (an original shape: flat bonnet, upright two-pane screen, slant back),
    # 16.5 x 7.6, bonnet = chest-high cover (4.0), roof 6.6. Nose toward -X.
    L, W, r, sill = 16.5, 7.6, 1.5, 1.4
    wx = (-5.2, 5.0)
    body = P.body_outline(L, sill, [(8.25, 3.6), (8.0, 4.0), (-8.0, 4.0), (-8.25, 3.4)], wx, r)
    P.profile(b, body, W, paint)
    gw = W - 0.6
    P.profile(b, [(-3.0, 3.95), (7.9, 3.95), (4.4, 6.6), (-2.3, 6.6)], gw, paint)  # cab and slant back
    P.profile(b, P.panel((-3.0, 4.2), (-2.3, 6.5), inset=0.1), gw - 0.5, glass)
    b.box((0.2, 0.3, 2.3), (-2.78, 0, 5.3), rot=(0, -17, 0), swatch=trim)  # screen centre post
    for sy in (-1, 1):
        y = sy * (gw / 2 + 0.03)
        P.profile(b, [(-1.9, 4.5), (0.7, 4.5), (0.7, 6.2), (-1.75, 6.2)], 0.06, glass, y=y)
        P.profile(b, [(1.2, 4.5), (3.7, 4.5), (3.7, 6.2), (1.2, 6.2)], 0.06, glass, y=y)
        for x in (-1.0, 2.2):  # X-braced doors
            b.box((2.6, 0.08, 0.16), (x, sy * (W / 2 + 0.02), 3.0), rot=(0, 22, 0), swatch=trim)
            b.box((2.6, 0.08, 0.16), (x, sy * (W / 2 + 0.03), 3.0), rot=(0, -22, 0), swatch=trim)
        b.box((0.5, 0.5, 0.6), (-8.3, sy * 2.7, 3.2), swatch=trim)  # lamp pods
        b.box((0.1, 0.9, 0.5), (-8.58, sy * 2.7, 3.2), swatch="dark_d" if burnt else "white_l")
        b.box((0.12, 0.7, 0.4), (8.3, sy * 2.9, 3.2), swatch="rust_d" if burnt else "red")
        b.box((0.3, 0.12, 0.9), (-3.3, sy * (W / 2 + 0.3), 5.2), swatch=trim)  # mirrors
        b.box((0.9, 0.7, 0.5), (-8.5, sy * 1.6, 1.5), swatch=trim)  # tow shackles
    P.seams(b, W, (-2.4, 0.9, 4.0), sill + 0.5, 3.95)
    b.box((3.4, 3.2, 0.14), (-5.6, 0, 4.06), swatch=trim)  # bonnet louvre plate
    for k in range(4):
        b.box((0.2, 2.6, 0.12), (-6.7 + 0.7 * k, 0, 4.16), swatch=top)
    b.box((0.5, W + 0.3, 0.8), (-8.55, 0, 2.1), swatch=trim)  # bumper
    for sy in (-1, 1):  # brush guard
        b.box((0.3, 0.3, 2.4), (-8.9, sy * 1.9, 2.9), swatch=trim)
    b.box((0.3, 4.1, 0.3), (-8.9, 0, 3.9), swatch=trim)
    b.box((0.3, 4.1, 0.3), (-8.9, 0, 2.9), swatch=trim)
    b.box((0.5, W + 0.3, 0.7), (8.4, 0, 2.0), swatch=trim)  # rear bumper
    b.cyl(1.5, 0.35, (1.0, 0, 6.78), segs=10, swatch=trim)  # hatch ring
    b.box((1.6, 1.6, 0.2), (1.0, 0, 7.0), swatch=top)
    b.box((0.12, 0.12, 4.5), (6.6, -3.2, 6.0), swatch=trim)  # whip aerial
    b.box((2.2, 2.6, 1.1), (6.3, 0.6, 4.5), rot=(0, 0, 6), swatch="rust_d" if burnt else "olive_d")  # kit on the back deck
    for i, cx in enumerate(wx):
        for sy in (-1, 1):
            P.wheel(b, cx, sy * (W / 2 - 0.45), r, flat=burnt and (i + sy) % 2 == 0)
            b.box((2 * r + 0.7, 0.14, 0.2), (cx, sy * (W / 2 + 0.03), sill + r + 0.6), swatch=trim)
    if burnt:
        for x, z, w in ((-4.0, 2.6, 2.6), (3.0, 2.3, 3.2), (6.0, 3.0, 1.6)):
            for sy in (-1, 1):
                b.box((w, 0.1, 0.9), (x, sy * (W / 2 + 0.05), z), swatch="rust")
        b.box((1.6, 2.2, 0.12), (-6.0, 1.6, 4.2), swatch="rust")
        b.rotate_all((2.0, 0, 0))  # sat down on its burst tyres


def humvee(b):
    _humvee(b, "tan", "tan_d", "dark", "glass", False)


def humvee_burnt(b):
    _humvee(b, "dark", "dark_d", "dark_l", "dark_d", True)


def bus(b):
    # Evacuation coach 38 x 8.4, roof 10.5, cooler pod to 11.3 (still WALL class: over 10.5, a
    # Hocker shadow). Same build as the cars: silhouette with arches, separate glass per
    # window, the front door folded open on a dark step well, one window out, a hand smear.
    L, W, r, sill = 38.0, 8.4, 1.7, 1.3
    wx = (-12.5, 11.0)
    body = P.body_outline(L, sill, [(19.0, 9.9), (18.6, 10.5), (-17.6, 10.5), (-18.6, 9.5), (-19.0, 4.0)], wx, r)
    P.profile(b, body, W, "white_d")
    P.profile(b, P.panel((-19.0, 4.7), (-18.63, 9.25), inset=0.0), W - 1.0, "glass")  # windscreen
    b.box((0.1, 5.2, 0.9), (-18.3, 0, 9.95), rot=(0, -20, 0), swatch="dark")  # destination board
    b.box((0.06, 2.8, 0.4), (-18.36, 0, 9.95), rot=(0, -20, 0), swatch="brass")
    b.box((0.1, W - 2.4, 2.4), (19.02, 0, 8.0), swatch="glass")  # rear window
    b.box((0.12, W - 1.6, 2.2), (19.03, 0, 4.2), swatch="gun_d")  # engine door
    for sy in (-1, 1):
        y = sy * (W / 2 + 0.03)
        for i in range(8):  # eight windows a side
            x = -11.3 + i * 3.75
            if sy > 0 and i == 0:
                continue  # the door is here
            sw = "dark_d" if (sy < 0 and i == 5) else "glass"  # one blown out
            b.box((3.3, 0.06, 2.7), (x, y, 7.75), swatch=sw)
        b.box((L - 3.0, 0.05, 0.8), (0.4, sy * (W / 2 + 0.02), 5.2), swatch="paint_navy")  # livery band
        b.box((L - 7.4, 0.05, 0.22), (0.4, sy * (W / 2 + 0.02), 4.5), swatch="gun_l")
        b.box((0.3, 0.14, 1.5), (-17.9, sy * (W / 2 + 0.55), 8.4), swatch="dark")  # mirrors
        b.box((0.14, 0.5, 0.14), (-17.9, sy * (W / 2 + 0.25), 9.0), swatch="dark")
        b.box((0.12, 1.1, 0.6), (-19.0, sy * 3.0, 3.0), swatch="white_l")  # headlights
        b.box((0.12, 0.8, 1.1), (19.04, sy * 3.4, 5.6), swatch="red")  # tail lights
        for cx in wx:
            b.box((2 * r + 0.7, 0.12, 0.2), (cx, sy * (W / 2 + 0.03), sill + r + 0.62), swatch="dark")
        for cx in wx:
            P.wheel(b, cx, sy * (W / 2 - 0.5), r, flat=(cx > 0 and sy < 0))
    # the front door (+Y side): step well and two leaves folded in
    b.box((3.3, 0.08, 7.6), (-15.2, W / 2 + 0.04, 5.2), swatch="dark_d")
    for x in (-16.7, -13.7):
        b.box((0.14, 1.5, 7.2), (x, W / 2 + 0.7, 5.2), swatch="white_d")
        b.box((0.16, 1.1, 2.6), (x, W / 2 + 0.7, 7.4), swatch="glass")
    b.box((3.0, 0.9, 0.3), (-15.2, W / 2 + 0.4, 1.5), swatch="gun_d")  # step
    b.box((3.3, 0.08, 6.4), (2.2, W / 2 + 0.04, 4.9), swatch="gun_d")  # the shut middle door
    b.box((0.1, 0.1, 6.4), (2.2, W / 2 + 0.07, 4.9), swatch="dark_d")
    for sx in (-1, 1):
        b.box((0.5, W + 0.1, 1.0), (sx * (L / 2 + 0.12), 0, 1.9), swatch="dark")  # bumpers
    b.box((7.0, 4.6, 0.8), (6.0, 0, 10.9), swatch="white")  # cooler pod
    b.box((6.4, 4.0, 0.1), (6.0, 0, 11.32), swatch="gun_d")
    for x in (-10.0, -2.0):
        b.box((2.2, 2.2, 0.25), (x, 0, 10.62), swatch="white")  # roof hatches
    b.box((5.0, 0.07, 1.6), (9.0, -(W / 2 + 0.05), 3.4), swatch="rust")  # scorch and rust
    b.box((2.6, 0.07, 1.0), (-7.0, W / 2 + 0.05, 2.9), swatch="rust")
    b.box((0.9, 0.05, 1.3), (3.2, -(W / 2 + 0.08), 7.6), rot=(0, 12, 0), swatch="wound_d")  # the smear
    b.box((0.5, 0.05, 2.0), (3.0, -(W / 2 + 0.07), 5.9), swatch="wound_d")
    b.rotate_all((-0.9, 0, 0))  # leans on the flat rear tyre


def ambulance(b):
    # Box ambulance 19 x 7.6, cab roof 6.4, box top 9.3 (CLIMB): white with one red band, the
    # rear doors thrown open and a stretcher half out. No emblem: the band and the beacons say it.
    L, W, r, sill = 19.0, 7.2, 1.25, 0.9
    wx = (-6.2, 5.6)
    belt = [(9.5, 2.6), (-2.7, 2.6), (-2.7, 6.4), (-5.6, 6.4), (-6.9, 4.6), (-9.2, 3.7), (-9.5, 2.9)]
    P.profile(b, P.body_outline(L, sill, belt, wx, r), W, "white")
    P.profile(b, P.panel((-6.9, 4.6), (-5.6, 6.4)), W - 0.7, "glass")
    for sy in (-1, 1):
        P.profile(b, [(-6.4, 4.7), (-3.2, 4.7), (-3.2, 6.0), (-5.5, 6.0)], 0.06, "glass", y=sy * (W / 2 + 0.03))
    bw = W + 0.4
    b.box((12.0, bw, 6.7), (3.5, 0, 2.6 + 3.35), swatch="white_l")  # the box
    for sy in (-1, 1):
        y = sy * (bw / 2 + 0.03)
        b.box((12.0, 0.06, 0.9), (3.5, y, 4.6), swatch="red")
        b.box((12.0, 0.06, 0.25), (3.5, y, 5.5), swatch="warning_orange")
        b.box((2.4, 0.06, 1.6), (0.2, y, 7.4), swatch="glass")
        b.box((1.0, 0.07, 1.3), (6.0, y, 3.6), swatch="rust")
        # rear doors swung right round against the sides
        b.box((0.16, bw / 2 - 0.3, 6.0), (9.9, sy * (bw / 2 + 1.6), 5.9), rot=(0, 0, sy * 70), swatch="white_l")
    b.box((0.08, bw - 0.8, 6.0), (9.46, 0, 5.9), swatch="dark_d")  # the open back
    b.box((0.9, bw, 0.3), (9.9, 0, 2.45), swatch="gun_d")  # step
    b.box((5.6, 2.0, 0.25), (11.0, -0.8, 2.9), rot=(0, 7, 0), swatch="white")  # stretcher, half out
    b.box((5.4, 1.8, 0.3), (11.0, -0.8, 3.15), rot=(0, 7, 0), swatch="wound_d")
    for x in (9.4, 12.8):
        b.box((0.15, 1.9, 2.4), (x, -0.8, 1.6), swatch="gun")
    b.box((0.5, 4.4, 0.45), (-4.2, 0, 6.65), swatch="dark")  # light bar
    for sy in (-1, 1):
        b.box((0.52, 1.5, 0.47), (-4.2, sy * 1.3, 6.66), swatch="red" if sy < 0 else "friendly_blue")
    for x in (0.0, 7.0):
        b.box((1.4, 1.4, 0.35), (x, 0, 9.45), swatch="white")  # roof vents
    P.seams(b, W, (-6.6, -3.0), sill + 0.4, 4.5)
    P.car_details(b, L, W, sill, 2.9, wx, r, "white", rear_lamp_z=2.2)


VEHICLES = {
    "prop_car_suv": car_suv,
    "prop_humvee": humvee,
    "prop_humvee_burnt": humvee_burnt,
    "prop_bus": bus,
    "prop_ambulance": ambulance,
}


# ------------------------------------------------------------------ the checkpoint's own pieces
def wall_panel_24(b):
    # Perimeter wall, one mesh per 24 studs: three precast panels between posts, 12.5 tall
    # (WALL: nobody climbs it, it stops spit), outriggers and two wire strands to 14.6.
    b.box((24.0, 2.4, 0.8), (0, 0, 0.4), swatch="concrete_d")
    b.box((24.0, 0.9, 11.4), (0, 0, 0.8 + 5.7), swatch="concrete")
    for x in (-12.0, -4.0, 4.0, 12.0):
        if abs(x) < 12:
            b.box((1.0, 1.5, 12.5), (x, 0, 6.25), swatch="concrete_l")
    b.box((24.0, 1.2, 0.35), (0, 0, 12.35), swatch="concrete_l")
    for x in (-8.0, 0.0, 8.0):
        b.box((0.2, 0.2, 2.4), (x, -0.5, 13.5), rot=(-24, 0, 0), swatch="gun_d")
    for k, (y, z) in enumerate(((-0.75, 13.9), (-1.0, 14.5))):
        b.box((24.0, 0.1, 0.1), (0, y, z), swatch="gun_l")
    b.box((2.6, 0.06, 4.2), (-7.2, -0.49, 8.6), swatch="concrete_d")  # water stains
    b.box((1.6, 0.06, 2.8), (5.0, -0.49, 9.6), swatch="rust_d")
    b.box((4.6, 0.06, 1.1), (1.0, -0.49, 4.2), swatch="warning_orange")  # stencil band
    b.box((3.8, 0.05, 0.6), (1.0, -0.53, 4.2), swatch="dark_d")


def hesco_row_24(b):
    # Four gabions as one mesh, 24 x 4.4 x 4.4 (VAULT / Walker climb, same as env_hesco, which
    # costs 240 tris a cell; this is 300 for four).
    H = 4.4
    b.box((24.0, 4.4, H), (0, 0, H / 2), swatch="tan")
    b.box((23.4, 3.8, 0.2), (0, 0, H + 0.08), swatch="tan_l")
    for k in range(5):
        x = -12.0 + 6.0 * k
        x = max(-11.94, min(11.94, x))
        for sy in (-1, 1):
            b.box((0.14, 0.14, H), (x, sy * 2.25, H / 2), swatch="dark_l")
        b.box((0.14, 4.5, 0.14), (x, 0, H + 0.02), swatch="dark_l")
    for z in (1.5, 3.0):
        for sy in (-1, 1):
            b.box((24.1, 0.12, 0.12), (0, sy * 2.25, z), swatch="dark_l")
    b.box((3.0, 0.5, 1.2), (-5.0, -2.3, 0.6), rot=(0, 0, 4), swatch="tan_d")  # a split cell spilling
    b.box((2.2, 0.8, 0.6), (-5.2, -2.6, 0.3), swatch="tan_l")


def screening_tent(b):
    # Frame tent 28 x 16, eaves 7, ridge 10.5: open ends and open lower sides so the fight
    # carries on through it. White canvas gone grey, a red band on the valance.
    L, W, E, R = 28.0, 16.0, 7.0, 10.5
    run = math.hypot(W / 2, R - E)
    ang = math.degrees(math.atan2(R - E, W / 2))
    for sy in (-1, 1):
        b.box((L + 1.0, run + 0.5, 0.25), (0, sy * W / 4, (E + R) / 2), rot=(-sy * ang, 0, 0), swatch="white_d")
        b.box((L, 0.2, 2.2), (0, sy * W / 2, E - 1.1), swatch="white_d")  # valance
        b.box((L, 0.06, 0.5), (0, sy * (W / 2 + 0.14), E - 0.6), swatch="red_d")
        for k in range(4):
            b.box((0.4, 0.4, E), (-L / 2 + 0.3 + k * (L - 0.6) / 3, sy * (W / 2 - 0.2), E / 2), swatch="gun")
    for sx in (-1, 1):  # gable infill above the eaves
        b.box((0.2, W * 0.5, (R - E) * 0.5), (sx * L / 2, 0, E + (R - E) * 0.25), swatch="white_d")
        b.box((0.3, W, 0.3), (sx * L / 2, 0, E), swatch="gun")
    b.box((L, 0.35, 0.35), (0, 0, R - 0.1), swatch="gun")
    b.box((6.0, 0.25, 4.6), (-6.0, -W / 2 + 0.05, 2.4), rot=(8, 0, 0), swatch="white_d")  # one side wall still tied down
    b.box((2.4, 2.0, 0.1), (5.0, 3.0, 0.05), rot=(0, 0, 20), swatch="wound_d")  # what happened on the floor


def decon_tent(b):
    # Decontamination tunnel 14 x 10 x 9: three orange hoops, skin panels, a spray rail, a
    # catch tray. Walk through it end to end.
    L, W, H = 14.0, 10.0, 9.0
    for x in (-L / 2 + 0.4, 0.0, L / 2 - 0.4):
        for sy in (-1, 1):
            b.box((0.7, 0.7, H - 2.0), (x, sy * (W / 2 - 0.35), (H - 2.0) / 2), swatch="warning_orange")
            b.box((0.7, 3.0, 0.7), (x, sy * (W / 2 - 1.5), H - 1.3), rot=(sy * 42, 0, 0), swatch="warning_orange")
        b.box((0.7, W - 4.4, 0.7), (x, 0, H - 0.35), swatch="warning_orange")
    for sy in (-1, 1):
        b.box((L - 1.4, 0.15, H - 2.6), (0, sy * (W / 2 - 0.35), (H - 2.6) / 2 + 0.3), swatch="white_d")
        b.box((L - 1.4, 2.9, 0.15), (0, sy * (W / 2 - 1.5), H - 1.3), rot=(sy * 42, 0, 0), swatch="white")
    b.box((L - 1.4, W - 4.6, 0.15), (0, 0, H - 0.3), swatch="white")
    b.box((L, W - 1.6, 0.3), (0, 0, 0.15), swatch="dark")  # catch tray
    b.box((L - 2.0, 0.2, 0.2), (0, 0, H - 1.2), swatch="gun_l")  # spray rail
    for x in (-4.0, 0.0, 4.0):
        b.box((0.3, 0.3, 0.5), (x, 0, H - 1.5), swatch="gun")
    b.cyl(1.0, 2.6, (L / 2 - 1.6, W / 2 + 1.3, 1.3), segs=8, swatch="friendly_blue")  # water drum
    b.box((0.2, 0.2, 5.0), (L / 2 - 1.6, W / 2 + 0.4, 5.0), swatch="gun_d")  # its riser


def table_folding(b):
    # Screening table 6 x 2.6, top at 2.9 (VAULT), a clipboard and a scanner box left on it.
    b.box((6.0, 2.6, 0.2), (0, 0, 2.8), swatch="white_d")
    for sx in (-1, 1):
        b.box((0.16, 2.2, 2.7), (sx * 2.4, 0, 1.35), swatch="gun_d")
        b.box((0.2, 2.4, 0.16), (sx * 2.4, 0, 0.08), swatch="gun_d")
    b.box((1.0, 0.8, 0.08), (-1.4, 0.2, 2.94), rot=(0, 0, 18), swatch="tan")
    b.box((1.2, 0.9, 0.7), (1.5, -0.3, 3.25), swatch="gun")


def table_flipped(b):
    # The same table thrown on its side, papers across the ground: overturned in the rush.
    b.box((6.0, 0.2, 2.6), (0, 0, 1.3), rot=(12, 0, 0), swatch="white_d")
    for sx in (-1, 1):
        b.box((0.16, 2.7, 2.2), (sx * 2.4, 1.4, 1.5), rot=(12, 0, 0), swatch="gun_d")
    for x, y, a in ((-1.6, -1.6, 20), (0.2, -2.3, -35), (1.9, -1.4, 60), (0.9, -3.4, 5)):
        b.box((0.9, 1.1, 0.04), (x, y, 0.02), rot=(0, 0, a), swatch="white_l")
    b.box((1.0, 0.8, 0.5), (2.6, -2.6, 0.25), rot=(0, 0, 30), swatch="gun")


def luggage(b):
    # What they were told to leave: suitcases, duffels, a pushchair frame. 6 x 5 x 3.
    for size, loc, rot, sw in (
        ((2.4, 0.9, 1.7), (-1.6, 0.4, 0.85), (0, 0, 12), "paint_navy"),
        ((2.0, 0.8, 1.5), (0.6, 1.2, 0.75), (0, 0, -20), "paint_maroon"),
        ((2.6, 1.1, 0.9), (0.3, -0.9, 0.45), (0, 0, 35), "olive_d"),
        ((2.2, 1.6, 0.7), (-0.4, 0.2, 2.05), (0, 8, -8), "tan"),
        ((1.6, 1.0, 1.2), (2.3, -0.2, 0.6), (0, 0, 70), "dark_l"),
        ((1.4, 0.7, 1.0), (-2.6, -1.3, 0.5), (0, 0, -40), "tan_d"),
        ((1.2, 1.0, 0.5), (1.6, 1.9, 0.25), (0, 0, 15), "white_d"),
    ):
        b.box(size, loc, rot=rot, swatch=sw)
    for dx in (-0.5, 0.5):
        b.box((0.1, 0.1, 2.6), (-2.7 + dx, 1.5, 1.3), rot=(0, 20, 0), swatch="gun")
    b.box((1.3, 1.2, 0.12), (-2.7, 1.5, 1.4), swatch="dark")
    b.box((0.5, 0.3, 0.2), (2.6, -1.6, 0.1), rot=(0, 0, 50), swatch="red_d")  # one shoe


def warning_sign(b):
    # Quarantine board on two posts, 4.4 x 7.2: red head band, three black text bars, an arrow.
    for sx in (-1, 1):
        b.box((0.25, 0.25, 7.2), (sx * 1.8, 0, 3.6), swatch="gun_d")
    b.box((4.4, 0.16, 3.8), (0, -0.1, 5.2), swatch="white_l")
    b.box((4.4, 0.06, 1.0), (0, -0.2, 6.6), swatch="red")
    for k, w in enumerate((3.4, 2.8, 3.1)):
        b.box((w, 0.05, 0.36), (-(3.6 - w) / 2, -0.2, 5.6 - 0.7 * k), swatch="dark_d")
    b.box((1.6, 0.05, 0.4), (0.9, -0.2, 3.7), swatch="warning_orange")


def sign_gantry(b):
    # Sign bridge over the approach, 42 wide, clear 15 under the beam: two legs, a box truss,
    # two boards (ALL TRAFFIC STOP / lane arrows) and two dead lamps.
    S, H = 42.0, 17.0
    for sx in (-1, 1):
        b.box((1.4, 1.4, H), (sx * S / 2, 0, H / 2), swatch="gun_d")
        b.box((3.0, 3.0, 1.0), (sx * S / 2, 0, 0.5), swatch="concrete")
    for z in (H - 0.4, H - 2.6):
        b.box((S, 0.5, 0.5), (0, 0, z), swatch="gun")
    for k in range(9):
        x = -S / 2 + 2.6 + k * (S - 5.2) / 8
        b.box((0.3, 0.3, 2.2), (x, 0, H - 1.5), rot=(0, 30 if k % 2 else -30, 0), swatch="gun")
    for x, sw in ((-10.0, "white_l"), (10.0, "white_l")):
        b.box((15.0, 0.25, 6.0), (x, -0.5, H - 2.4), swatch=sw)
        b.box((15.0, 0.06, 1.5), (x, -0.66, H + 0.0), swatch="red")
        for k, w in enumerate((11.0, 8.0)):
            b.box((w, 0.05, 0.7), (x, -0.66, H - 2.2 - 1.3 * k), swatch="dark_d")
        b.box((3.0, 0.05, 0.9), (x, -0.66, H - 4.8), swatch="warning_orange")
    for x in (-19.0, 19.0):
        b.box((1.4, 1.0, 0.7), (x, -0.9, H + 0.6), swatch="dark")


def _stair(b, rise):
    # Steel stair flight at the kit's 33 degrees, 5 wide: rises toward +X from the origin.
    run = rise / math.tan(math.radians(33))
    slope = math.hypot(run, rise)
    for sy in (-1, 1):
        b.box((slope, 0.3, 0.9), (run / 2, sy * 2.5, rise / 2 - 0.3), rot=(0, -33, 0), swatch="gun_d")  # stringers
        b.box((slope, 0.14, 0.14), (run / 2, sy * 2.5, rise / 2 + 3.4), rot=(0, -33, 0), swatch="gun")  # handrail
        for t in (0.02, 0.5, 0.98):
            b.box((0.16, 0.16, 3.6), (run * t, sy * 2.5, rise * t + 1.7), swatch="gun")
    n = max(4, int(round(rise / 1.0)))
    for k in range(n):
        t = (k + 0.5) / n
        b.box((run / n + 0.25, 4.8, 0.2), (run * t, 0, rise * (k + 1) / n - 0.1), swatch="gun_l" if k % 2 else "gun")


def stair_steel_9(b):
    _stair(b, 9.0)


def stair_steel_12(b):
    _stair(b, 12.0)


def catwalk_12(b):
    # Steel walkway bay 12 x 6, deck top at z 0.4 (place it with its top at the floor), rails 3.6.
    b.box((12.0, 6.0, 0.4), (0, 0, 0.2), swatch="gun_d")
    for k in range(4):
        b.box((0.3, 5.6, 0.06), (-4.5 + 3.0 * k, 0, 0.42), swatch="gun")
    for sy in (-1, 1):
        b.box((12.0, 0.16, 0.16), (0, sy * 2.9, 4.0), swatch="gun")
        b.box((12.0, 0.12, 0.12), (0, sy * 2.9, 2.2), swatch="gun")
        for x in (-5.9, 0.0, 5.9):
            b.box((0.18, 0.18, 3.7), (x, sy * 2.9, 2.2), swatch="gun")
        b.box((12.0, 0.1, 0.5), (0, sy * 2.95, 0.65), swatch="gun_d")  # kick plate


def fuel_tank(b):
    # Bulk fuel tank 18 x 7 x 8.6 on two saddles: a Hocker shadow in the generator yard.
    b.cyl(3.3, 16.0, (0, 0, 5.0), segs=12, rot=(0, 90, 0), swatch="white_d")
    for sx in (-1, 1):
        b.cyl(3.3, 1.0, (sx * 8.5, 0, 5.0), segs=12, r2=2.2, rot=(0, sx * 90, 0), swatch="white_d")
        b.box((1.6, 6.2, 3.2), (sx * 5.0, 0, 1.6), swatch="concrete")
    b.box((16.0, 0.1, 1.2), (0, -3.22, 5.0), swatch="red")
    b.box((2.0, 0.08, 2.0), (-4.0, -3.3, 5.0), rot=(45, 0, 0), swatch="warning_orange")
    b.cyl(0.6, 0.8, (2.0, 0, 8.5), segs=8, swatch="gun_d")  # manhole
    b.box((0.2, 1.4, 6.6), (6.0, -3.4, 3.3), swatch="gun")  # ladder
    for k in range(5):
        b.box((0.24, 1.5, 0.12), (6.0, -3.45, 1.0 + 1.3 * k), swatch="gun_l")
    b.box((6.0, 0.3, 0.3), (-6.0, 3.0, 0.9), swatch="gun_d")  # pipe run
    b.box((0.3, 0.3, 4.0), (-3.2, 3.0, 2.9), swatch="gun_d")
    b.box((3.0, 0.07, 1.6), (-1.0, -3.2, 2.9), swatch="rust")


def drum(b):
    # 200-litre drum 2.4 x 3.6: fuel yard rows and burn barrels.
    b.cyl(1.2, 3.6, (0, 0, 1.8), segs=8, swatch="olive_d")
    for z in (1.2, 2.4):
        b.cyl(1.27, 0.14, (0, 0, z), segs=8, swatch="olive")
    b.cyl(1.05, 0.06, (0, 0, 3.62), segs=8, swatch="rust_d")


def sat_dish(b):
    # Roof dish 5 x 5 x 6 on a tripod: the command post's silhouette.
    b.cyl(2.5, 0.9, (0, -0.6, 4.0), segs=10, r2=0.5, rot=(62, 0, 0), swatch="white_d")
    b.cyl(0.12, 2.2, (0, -1.5, 4.6), segs=4, rot=(62, 0, 0), swatch="gun")
    b.cyl(0.25, 3.4, (0, 0.2, 1.7), segs=6, swatch="gun_d")
    b.box((2.4, 2.4, 0.3), (0, 0.2, 0.15), swatch="gun_d")


def pallet_stack(b):
    # Four pallets stacked, 4 x 4 x 2.28 (VAULT), as one mesh: prop_pallet is 228 tris and the
    # level rule is "stacks of four", so a stack of singles costs 912.
    for k in range(4):
        z0 = 0.57 * k
        b.box((4.0, 4.0, 0.14), (0, 0, z0 + 0.5), swatch="tan" if k % 2 else "tan_l")
        for y in (-1.7, 0.0, 1.7):
            b.box((4.0, 0.5, 0.36), (0, y, z0 + 0.18), swatch="tan_d")


def pine_stand(b):
    # Backdrop only (no collision, past the wall): five dark pines over 40 studs, 24-34 tall.
    for x, y, h, r in ((-17, 1.5, 28, 5.0), (-8, -2.0, 34, 5.6), (0, 2.0, 25, 4.6), (9, -1.0, 31, 5.4), (17, 1.0, 27, 4.8)):
        b.cyl(0.7, h * 0.3, (x, y, h * 0.15), segs=5, swatch="tan_d")
        b.cyl(r, h * 0.5, (x, y, h * 0.45), segs=6, r2=r * 0.35, swatch="foliage_d")
        b.cyl(r * 0.7, h * 0.42, (x, y, h * 0.79), segs=6, r2=0.05, swatch="foliage_d")


def far_hill(b):
    # Backdrop only: a faceted ridge 2 x 1 x 1 units; placed scaled (300-700 long, 40-90 tall).
    b.cyl(1.0, 0.5, (0, 0, 0.25), segs=7, r2=0.62, swatch="foliage_d")
    b.cyl(0.62, 0.34, (0.06, 0.03, 0.67), segs=7, r2=0.26, swatch="foliage_d")
    b.cyl(0.26, 0.16, (0.1, 0.04, 0.92), segs=7, r2=0.04, swatch="foliage_d")


PIECES = {
    "env_wall_panel_24": (wall_panel_24, "Environment", "prop"),
    "env_hesco_row_24": (hesco_row_24, "Environment", "prop"),
    "env_screening_tent": (screening_tent, "Environment", "prop"),
    "env_decon_tent": (decon_tent, "Environment", "prop"),
    "env_sign_gantry": (sign_gantry, "Environment", "prop"),
    "env_stair_steel_9": (stair_steel_9, "Environment", "prop"),
    "env_stair_steel_12": (stair_steel_12, "Environment", "prop"),
    "env_catwalk_12": (catwalk_12, "Environment", "prop"),
    "env_fuel_tank": (fuel_tank, "Environment", "prop"),
    "env_sat_dish": (sat_dish, "Environment", "prop"),
    "env_pine_stand": (pine_stand, "Environment", "prop"),
    "env_far_hill": (far_hill, "Environment", "clutter"),
    "prop_table_folding": (table_folding, "Props", "clutter"),
    "prop_table_flipped": (table_flipped, "Props", "clutter"),
    "prop_luggage": (luggage, "Props", "clutter"),
    "prop_warning_sign": (warning_sign, "Props", "clutter"),
    "prop_drum": (drum, "Props", "clutter"),
    "prop_pallet_stack": (pallet_stack, "Props", "clutter"),
}
CLASS_CAP = {"clutter": 200, "prop": 500, "vehicle": 5000}

NAMES = tuple(VEHICLES) + tuple(PIECES)


def register(ba):
    """Adds the Delta v2 kit to build_assets' ASSETS table (idempotent)."""
    for name, fn in VEHICLES.items():
        ba.ASSETS[name] = (fn, "Props", "bottom")
        CAPS[name] = ("vehicle", CLASS_CAP["vehicle"])
    for name, (fn, col, cls) in PIECES.items():
        ba.ASSETS[name] = (fn, col, "bottom")
        CAPS[name] = (cls, CLASS_CAP[cls])
