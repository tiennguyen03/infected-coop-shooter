"""The Doorman, the tripod sentry machine gun call-in (owner 2026-11-11: "the actual Doorman
turret needs a new 3d model, it looks ugly"). SentryService builds it; the switch is
Config.CallIns.Doorman.Model (2 = these meshes, 1 = the old Part tripod).

One file per singular asset (owner, 2026-11-07), registered into build_assets.py's ASSETS
table by `register(ba)`. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only dep_doorman_base dep_doorman_cradle dep_doorman_gun ref_doorman ref_doorman_aimed ref_doorman_v1 ref_human_5st

A belt-fed medium machine gun (M240 in the mould, original) on a squat tripod, run by a sensor
head instead of a gunner. Built at its in-game size in studs. Assembly frame: origin on the
ground under the traverse axis, muzzle toward -Y (Roblox -Z, a part's LookVector), +X the
gun's right (the sensor side; the ammo can hangs on the left), +Z up. Three meshes, so the
game can turn them:

- `dep_doorman_base`   static: tripod with spade feet and ground spikes, two sandbags, the
                       traverse bar, the battery / control box and its cable. Origin = the
                       assembly origin (ground centre).
- `dep_doorman_cradle` yaws about +Z through YAW_PIVOT: turntable, yoke, elevation arc, servo.
                       Origin = YAW_PIVOT.
- `dep_doorman_gun`    pitches about X through PITCH_PIVOT (the trunnion, on the traverse axis
                       and the bore line): gun, heat shield, flash hider, sensor head, ammo can
                       and belt (they ride the gun so the belt never tears when it elevates).
                       Origin = PITCH_PIVOT.

The collection `Deployables` is exported pre-mirrored in X (build_assets.MIRROR_X_COLLECTIONS:
with -Y as Roblox -Z an FBX lands left-right mirrored, and this gun is not symmetric).
`ref_doorman` (assembled), `ref_doorman_aimed` (traversed and elevated, the pivot proof) and
`ref_doorman_v1` (the old Part body) are preview-only; `render_previews` draws the views in
previews/doorman_v2_*.png.
"""

import math

# Blender (x, y, z) in the assembly frame; Roblox order is (x, z, y).
YAW_PIVOT = (0.0, 0.0, 1.9)  # top of the tripod head: the cradle turns here
PITCH_PIVOT = (0.0, 0.0, 2.6)  # the trunnion: the gun elevates here
MUZZLE = (0.0, -3.52, 2.6)  # the flash hider's mouth, on the bore line through the trunnion
BORE_Z = PITCH_PIVOT[2]

# Tripod: one leg forward, two aft (hinge on the head -> foot on the ground).
LEGS = (
    ((0.0, -0.3, 1.58), (0.0, -2.0, 0.12)),
    ((0.27, 0.2, 1.58), (1.6, 1.4, 0.12)),
    ((-0.27, 0.2, 1.58), (-1.6, 1.4, 0.12)),
)


# ------------------------------------------------------------------ helpers
def _lerp(p0, p1, t):
    return tuple(a + (c - a) * t for a, c in zip(p0, p1))


def _beam(b, p0, p1, w, h, sw):
    """A box-section bar from p0 to p1 (w across, h deep)."""
    dx, dy, dz = (c - a for a, c in zip(p0, p1))
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rot = (math.degrees(math.asin(dz / length)), 0, math.degrees(math.atan2(-dx, dy)))
    b.box((w, length, h), _lerp(p0, p1, 0.5), rot=rot, swatch=sw)


def _rod(b, p0, p1, r, sw, segs=6, r2=None):
    """A round bar from p0 (radius r) to p1 (radius r2 or r)."""
    dx, dy, dz = (c - a for a, c in zip(p0, p1))
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    rot = (math.degrees(math.acos(dz / length)), 0, math.degrees(math.atan2(dx, -dy)))
    b.cyl(r, length, _lerp(p0, p1, 0.5), segs=segs, r2=r2, rot=rot, swatch=sw)


def _tube_y(b, y0, y1, r, sw, x=0.0, z=BORE_Z, r_front=None, segs=8):
    """A cylinder along Y from y0 (aft) to y1 (fore, toward the muzzle)."""
    b.cyl(r, y0 - y1, (x, (y0 + y1) / 2, z), segs=segs, r2=r_front, rot=(90, 0, 0), swatch=sw)


def _octa_y(b, y0, y1, r, sw, x=0.0, z=BORE_Z):
    """An octagonal jacket along Y whose flats face up, down and to the sides."""
    s = type(b)()
    s.prism([(0, r, r), (y0 - y1, r, r)], swatch=sw, chamfer=0.414)
    s.rotate_all((90, 0, 0))
    s.shift_all((x, y0, z))
    b.merge(s)


def _sandbag(b, loc, yaw, sw="tan", size=(1.15, 0.62, 0.34)):
    """A filled bag slumped on the ground: a pillow with a tied seam at each end."""
    lx, ly, lz = size
    s = type(b)()
    s.prism(
        [(0, lx * 0.44, ly * 0.42), (lz * 0.3, lx * 0.5, ly * 0.5), (lz * 0.72, lx * 0.47, ly * 0.45), (lz, lx * 0.34, ly * 0.28)],
        swatch=[sw + "_d", sw, sw],
    )
    for e in (-1, 1):
        s.box((0.05, ly * 0.6, lz * 0.3), (e * (lx * 0.5 + 0.01), 0, lz * 0.38), swatch=sw + "_d")  # tied end
    s.rotate_all((0, 0, yaw))
    s.shift_all(loc)
    b.merge(s)


# ------------------------------------------------------------------ static base
def _base(b):
    od, o, dk, g = "olive_d", "olive", "dark", "gun"
    # Tripod head: a block the legs hinge on, the bearing race the cradle turns on.
    b.cyl(0.36, 0.5, (0, 0, 1.6), segs=8, swatch="gun")
    b.cyl(0.44, 0.1, (0, 0, 1.85), segs=8, swatch=dk)
    for hinge, foot in LEGS:
        az = math.degrees(math.atan2(-(foot[0] - hinge[0]), foot[1] - hinge[1]))
        knee = _lerp(hinge, foot, 0.56)
        _beam(b, _lerp(hinge, foot, -0.06), knee, 0.22, 0.2, o)  # upper leg (sleeve)
        _beam(b, _lerp(hinge, foot, 0.5), foot, 0.13, 0.12, g)  # lower leg (slides out of it)
        _beam(b, _lerp(hinge, foot, 0.52), _lerp(hinge, foot, 0.6), 0.3, 0.27, dk)  # leg clamp
        b.box((0.34, 0.2, 0.26), _lerp(hinge, foot, 0.0), rot=(0, 0, az), swatch=dk)  # hinge lug
        # Spade foot: a plate flat on the ground, the spade's lip turned up at the toe, and a
        # ground spike driven through it (a T-headed stake).
        fx, fy = foot[0], foot[1]
        b.box((0.56, 0.5, 0.08), (fx, fy, 0.04), rot=(0, 0, az), swatch="gun_d")
        toe = _lerp(hinge, foot, 1.13)
        b.box((0.56, 0.08, 0.3), (toe[0], toe[1], 0.15), rot=(-18, 0, az), swatch="gun_d")
        b.box((0.5, 0.03, 0.08), (toe[0], toe[1], 0.31), rot=(-18, 0, az), swatch="rust")  # worn lip
        heel = _lerp(hinge, foot, 0.93)
        b.cyl(0.05, 0.4, (heel[0] + 0.16 * math.cos(math.radians(az)), heel[1] + 0.16 * math.sin(math.radians(az)), 0.2), segs=6, swatch="gun_l")
        b.box((0.22, 0.07, 0.06), (heel[0] + 0.16 * math.cos(math.radians(az)), heel[1] + 0.16 * math.sin(math.radians(az)), 0.42), rot=(0, 0, az), swatch="gun_l")
    # Traverse bar between the aft legs.
    left, right = _lerp(*LEGS[2], 0.42), _lerp(*LEGS[1], 0.42)
    _beam(b, left, right, 0.1, 0.18, o)
    for p in (left, right):
        b.box((0.2, 0.2, 0.26), p, swatch=dk)
    # Sandbags over the aft legs, just inboard of the feet.
    _sandbag(b, (1.22, 1.06, 0.0), -42)
    _sandbag(b, (-1.22, 1.06, 0.0), 42)
    # Battery / control box on the ground inside the right aft leg, its panel facing aft (the
    # soldier who set it down), and the cable up that leg to the head.
    bx, by = 0.42, 0.98
    b.box((0.78, 0.5, 0.56), (bx, by, 0.3), swatch=o)
    b.box((0.82, 0.54, 0.1), (bx, by, 0.6), swatch=od)  # lid
    b.box((0.84, 0.56, 0.06), (bx, by, 0.05), swatch=od)  # skid
    b.box((0.3, 0.05, 0.05), (bx, by, 0.72), swatch=dk)  # carry handle
    for s in (-1, 1):
        b.box((0.05, 0.05, 0.1), (bx + s * 0.14, by, 0.68), swatch=dk)
    b.box((0.44, 0.04, 0.26), (bx - 0.08, by + 0.26, 0.32), swatch=dk)  # control panel
    b.box((0.07, 0.04, 0.07), (bx - 0.2, by + 0.285, 0.38), swatch="friendly_blue")  # power light
    b.box((0.07, 0.04, 0.07), (bx - 0.06, by + 0.285, 0.38), swatch="warning_orange")
    b.box((0.16, 0.05, 0.06), (bx - 0.02, by + 0.285, 0.26), swatch="gun_l")  # switch guard
    b.box((0.1, 0.04, 0.16), (bx + 0.27, by + 0.27, 0.34), swatch="objective_yellow")  # hazard plate
    b.cyl(0.03, 0.9, (bx + 0.3, by - 0.14, 1.1), segs=5, swatch="dark_d")  # whip antenna
    b.cyl(0.05, 0.1, (bx + 0.3, by - 0.14, 0.7), segs=6, swatch=dk)
    cable = [(bx - 0.26, by - 0.12, 0.66), (bx - 0.2, by - 0.3, 0.9), _lerp(*LEGS[1], 0.3), _lerp(*LEGS[1], 0.08), (0.16, 0.12, 1.86)]
    cable[2] = (cable[2][0] - 0.02, cable[2][1] - 0.04, cable[2][2] + 0.16)
    cable[3] = (cable[3][0], cable[3][1], cable[3][2] + 0.17)
    for p0, p1 in zip(cable, cable[1:]):
        _rod(b, p0, p1, 0.035, "dark_d", segs=5)
    b.cyl(0.07, 0.08, cable[0], segs=6, swatch="gun_l")  # plug


# ------------------------------------------------------------------ cradle (yaw)
def _cradle(b):
    z0 = YAW_PIVOT[2]
    tz = PITCH_PIVOT[2]
    b.cyl(0.4, 0.12, (0, 0, z0 + 0.06), segs=8, swatch="gun_l")  # turntable
    b.cyl(0.22, 0.16, (0, 0, z0 + 0.19), segs=8, swatch="gun_d")  # pintle
    b.box((0.96, 0.52, 0.14), (0, 0, z0 + 0.32), swatch="olive")  # yoke bed
    for s in (-1, 1):
        b.box((0.1, 0.42, 0.56), (s * 0.43, 0, z0 + 0.6), swatch="olive")  # yoke cheek
        b.box((0.1, 0.3, 0.16), (s * 0.43, 0, tz + 0.16), swatch="olive")  # its rounded top
        b.cyl(0.13, 0.08, (s * 0.5, 0, tz), segs=8, rot=(0, 90, 0), swatch="gun")  # trunnion cap
        b.wedge((0.2, 0.08, 0.3), (s * 0.43, 0.3, z0 + 0.53), rot=(0, 0, -90), swatch="dark")  # gusset
    # Elevation arc on the right cheek: a toothed rack centred on the trunnion.
    for i in range(4):
        a = math.radians(205 + i * 17)
        b.box((0.05, 0.24, 0.1), (0.515, -0.66 * math.cos(a), tz + 0.66 * math.sin(a)), rot=(90 - math.degrees(a), 0, 0), swatch="gun")
    # Traverse and elevation servo on the left cheek, a cable down to the bed.
    b.box((0.24, 0.34, 0.3), (-0.6, 0.18, z0 + 0.5), swatch="dark")
    b.cyl(0.1, 0.12, (-0.76, 0.18, z0 + 0.5), segs=6, rot=(0, 90, 0), swatch="gun_d")
    b.box((0.2, 0.3, 0.05), (-0.6, 0.18, z0 + 0.68), swatch="olive")  # its cover plate
    b.box((0.3, 0.1, 0.1), (0, 0.3, z0 + 0.3), swatch="dark")  # traverse lock
    b.box((0.08, 0.05, 0.16), (0.2, 0.345, z0 + 0.34), swatch="red")  # lock lever


# ------------------------------------------------------------------ gun (pitch)
def _gun(b):
    z = BORE_Z
    g, gd, gl, dk, dd, o, od = "gun", "gun_d", "gun_l", "dark", "dark_d", "olive", "olive_d"
    # Receiver and the feed cover on top of it.
    b.box((0.44, 2.3, 0.56), (0, 0.25, z + 0.02), swatch=g)
    b.box((0.46, 0.5, 0.2), (0, 1.1, z - 0.2), swatch=gd)  # trigger housing, no grip on it
    b.box((0.42, 1.06, 0.14), (0, -0.33, z + 0.37), swatch=gl)  # feed cover
    b.box((0.44, 0.1, 0.18), (0, 0.24, z + 0.38), swatch=dk)  # its hinge
    for i in range(4):
        b.box((0.43, 0.04, 0.04), (0, -0.74 + i * 0.2, z + 0.46), swatch=gd)  # cover ribs
    b.box((0.16, 0.86, 0.06), (0, 0.84, z + 0.33), swatch=gd)  # top rail
    for s in (-1, 1):
        b.box((0.15, 0.3, 0.3), (s * 0.295, 0, z), swatch=gd)  # trunnion blocks in the yoke
    b.box((0.05, 0.36, 0.18), (0.24, -0.4, z + 0.06), swatch=dd)  # ejection port
    b.box((0.1, 0.4, 0.05), (0.27, -0.4, z - 0.07), rot=(0, 25, 0), swatch=gl)  # case deflector
    b.box((0.06, 0.14, 0.08), (0.25, 0.62, z + 0.12), swatch=gl)  # charging handle
    b.box((0.03, 0.7, 0.04), (0.235, 0.3, z + 0.12), swatch=dd)  # its slot
    # Back plate and the fire-control unit where the spade grips would be.
    b.box((0.5, 0.1, 0.62), (0, 1.45, z + 0.02), swatch=gd)
    b.box((0.4, 0.46, 0.42), (0, 1.73, z + 0.02), swatch=o)
    b.box((0.42, 0.06, 0.3), (0, 1.97, z + 0.02), swatch=dk)  # its aft panel
    b.box((0.08, 0.04, 0.08), (-0.1, 2.0, z + 0.08), swatch="red_l")  # armed light
    b.box((0.12, 0.04, 0.05), (0.08, 2.0, z - 0.04), swatch=gl)
    b.box((0.3, 0.3, 0.05), (0, 1.73, z + 0.25), swatch=od)  # cover plate
    # Barrel: trunnion block, gas tube, heat shield with vent slots, flash hider.
    b.box((0.38, 0.32, 0.44), (0, -1.04, z), swatch=gd)
    _tube_y(b, -1.2, -3.12, 0.11, gl)
    _octa_y(b, -1.24, -2.5, 0.2, o)
    for i in range(4):
        y = -1.45 - i * 0.28
        b.box((0.08, 0.19, 0.03), (0, y, z + 0.2), swatch=dd)  # top vents
        for s in (-1, 1):
            b.box((0.03, 0.19, 0.08), (s * 0.2, y, z), swatch=dd)  # side vents
    b.box((0.44, 0.06, 0.44), (0, -1.24, z), swatch=dk)  # shield's aft collar
    b.box((0.3, 0.05, 0.3), (0, -2.5, z), swatch=dk)  # and fore collar
    _tube_y(b, -1.1, -2.72, 0.06, gd, z=z - 0.27, segs=6)  # gas tube
    b.box((0.16, 0.16, 0.36), (0, -2.74, z - 0.12), swatch=dk)  # gas block
    b.box((0.05, 0.05, 0.2), (0, -2.9, z + 0.18), swatch=dk)  # front sight post
    b.box((0.16, 0.12, 0.05), (0, -2.9, z + 0.09), swatch=dk)
    _octa_y(b, -3.1, -3.5, 0.15, g)  # flash hider: a slotted cage
    for s in (-1, 1):
        b.box((0.03, 0.26, 0.06), (s * 0.15, -3.3, z), swatch=dd)
        b.box((0.06, 0.26, 0.03), (0, -3.3, z + s * 0.15), swatch=dd)
    b.box((0.14, 0.03, 0.14), (0, -3.505, z), swatch=dd)  # its mouth
    b.box((0.26, 0.06, 0.26), (0, -3.1, z), swatch=dk)  # lock ring
    # Carry handle folded over the shield's left.
    b.box((0.05, 0.5, 0.05), (-0.2, -1.5, z + 0.34), swatch=gd)
    for y in (-1.28, -1.72):
        b.box((0.05, 0.05, 0.2), (-0.17, y, z + 0.26), rot=(0, 20, 0), swatch=gd)
    # Ammo can hung on the left, lid open at the gun side, the belt up into the feed tray.
    cx, cy, cz = -0.82, -0.62, z - 0.3
    b.box((0.44, 0.94, 0.62), (cx, cy, cz), swatch=o)
    b.box((0.47, 0.97, 0.08), (cx, cy, cz - 0.28), swatch=od)  # base rim
    b.box((0.3, 0.98, 0.07), (cx - 0.09, cy, cz + 0.34), swatch=od)  # lid, slid back off the belt
    b.box((0.03, 0.5, 0.14), (cx - 0.235, cy, cz + 0.08), swatch="objective_yellow")  # stencil band
    b.box((0.04, 0.14, 0.2), (cx - 0.24, cy + 0.36, cz + 0.2), swatch=gl)  # latch
    b.box((0.03, 0.22, 0.1), (cx - 0.235, cy - 0.3, cz - 0.16), swatch="olive_l")  # scuffed paint
    b.box((0.2, 0.03, 0.12), (cx + 0.02, cy - 0.485, cz - 0.1), swatch="olive_l")
    b.box((0.05, 0.36, 0.05), (cx - 0.1, cy, cz + 0.42), swatch=dk)  # folded handle
    b.box((0.4, 0.1, 0.1), (-0.42, -0.72, z - 0.2), swatch=dk)  # hanger arm to the receiver
    b.box((0.06, 0.6, 0.4), (cx + 0.25, cy, cz - 0.04), swatch=dk)  # hanger plate
    b.box((0.22, 0.44, 0.07), (-0.32, -0.4, z + 0.27), swatch=gl)  # feed tray lip
    b.box((0.3, 0.12, 0.3), (-0.6, -0.36, z + 0.12), rot=(0, -40, 0), swatch="brass_d")  # the belt's links, under the rounds
    belt = [(-0.72, z + 0.06), (-0.68, z + 0.17), (-0.62, z + 0.27), (-0.54, z + 0.34), (-0.45, z + 0.355), (-0.36, z + 0.34)]
    for i, (x, bz) in enumerate(belt):
        tilt = (-62, -48, -32, -14, 0, 8)[i]
        b.box((0.085, 0.4, 0.07), (x, -0.4, bz), rot=(0, tilt, 0), swatch="brass" if i % 2 else "brass_l")  # cartridges
    # Sensor head on the right, above the receiver: lens and rangefinder forward, a status
    # light fore and aft, a sun shade, the cable back to the fire-control unit.
    sx, sy, sz = 0.56, 0.42, z + 0.62
    b.box((0.08, 0.4, 0.42), (0.27, sy, z + 0.26), swatch=dk)  # bracket up the receiver's side
    b.box((0.3, 0.3, 0.08), (0.42, sy, z + 0.4), swatch=dk)  # shelf
    b.box((0.5, 0.82, 0.46), (sx, sy, sz), swatch=o)
    b.box((0.52, 0.2, 0.48), (sx, sy + 0.36, sz), swatch=od)  # aft cap
    b.box((0.03, 0.24, 0.1), (sx + 0.265, sy - 0.1, sz - 0.12), swatch="olive_l")  # scuffed paint
    b.box((0.56, 0.5, 0.04), (sx, sy - 0.3, sz + 0.25), swatch=od)  # sun shade
    b.box((0.46, 0.04, 0.42), (sx, sy - 0.42, sz), swatch=dk)  # face plate
    b.cyl(0.16, 0.12, (sx - 0.06, sy - 0.47, sz + 0.02), segs=8, rot=(90, 0, 0), swatch=dd)  # lens hood
    b.cyl(0.12, 0.02, (sx - 0.06, sy - 0.535, sz + 0.02), segs=8, rot=(90, 0, 0), swatch="glass")
    b.box((0.07, 0.02, 0.04), (sx - 0.02, sy - 0.55, sz + 0.07), swatch="glass_l")  # glint
    b.cyl(0.06, 0.08, (sx + 0.16, sy - 0.46, sz - 0.1), segs=6, rot=(90, 0, 0), swatch=dd)  # rangefinder
    b.box((0.08, 0.05, 0.08), (sx + 0.16, sy - 0.45, sz + 0.13), swatch="friendly_blue")  # status light
    b.box((0.1, 0.04, 0.1), (sx, sy + 0.47, sz + 0.08), swatch="friendly_blue")  # and aft
    b.box((0.24, 0.04, 0.06), (sx, sy + 0.47, sz - 0.1), swatch=dk)  # aft vent
    _rod(b, (sx, sy + 0.46, sz - 0.18), (0.3, 1.3, z + 0.4), 0.035, dd, segs=5)  # cable
    _rod(b, (0.3, 1.3, z + 0.4), (0.12, 1.62, z + 0.26), 0.035, dd, segs=5)


def _shifted(fn, pivot):
    def build(b):
        fn(b)
        b.shift_all(tuple(-c for c in pivot))

    return build


def base(b):
    _base(b)


cradle = _shifted(_cradle, YAW_PIVOT)
gun = _shifted(_gun, PITCH_PIVOT)


# ------------------------------------------------------------------ preview figures
def assembled(b, yaw=0.0, pitch=0.0):
    """The whole Doorman; `yaw` degrees to its left, `pitch` degrees up, about the pivots."""
    _base(b)
    top = type(b)()
    _gun(top)
    top.rotate_all((-pitch, 0, 0), cent=PITCH_PIVOT)
    _cradle(top)
    top.rotate_all((0, 0, -yaw), cent=YAW_PIVOT)
    b.merge(top)


def aimed(b):
    assembled(b, yaw=38, pitch=14)


def doorman_v1(b):
    """The Part body SentryService built before 2026-11-11 (Config Model = 1), for comparison."""
    for i in range(3):
        a = i * 2 * math.pi / 3
        _beam(b, (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.0), (0, 0, 2.6), 0.2, 0.2, "dark")
    b.box((0.6, 0.6, 0.5), (0, 0, 2.75), swatch="dark")
    b.box((0.5, 3.4, 0.55), (0, 0, 3.2), swatch="dark")
    b.box((0.5, 0.6, 0.5), (0.5, 0.2, 3.1), swatch="olive")


PIECES = {
    "dep_doorman_base": base,
    "dep_doorman_cradle": cradle,
    "dep_doorman_gun": gun,
}
FIGURES = {
    "ref_doorman": assembled,
    "ref_doorman_aimed": aimed,
    "ref_doorman_v1": doorman_v1,
}


def register(ba):
    """Adds the three meshes (pivot center: each keeps its own origin) and the preview figures."""
    for name, fn in PIECES.items():
        ba.ASSETS[name] = (fn, "Deployables", "center")
    for name, fn in FIGURES.items():
        ba.ASSETS[name] = (fn, "_Reference", "bottom")


def render_previews(ba, scene, cam, built, previews):
    """previews/doorman_v2_*.png: front, side, back, three-quarter, traversed, at gameplay
    distance beside the 5-stud figure (whole screen and its middle), and beside the old body. Needs the FIGURES built."""
    import os

    import bpy

    new, old, ref, turned = (built.get(n) for n in ("ref_doorman", "ref_doorman_v1", "ref_human_5st", "ref_doorman_aimed"))
    if new is None:
        return
    out = lambda view: os.path.join(previews, f"doorman_v2_{view}.png")  # noqa: E731
    for o in (old, ref, turned):
        if o is not None:
            o.location = (40, 0, 0)  # out of frame until its own picture
    lens = cam.data.lens
    cam.data.lens = 50
    shot = ba.frame_and_render

    def close(objs, path, size, direction, zoom=1.35):
        # frame_and_render fits the bounding sphere with room to spare; crop in by `zoom`.
        cam.data.lens = 50
        shot(scene, cam, objs, path, size=size, direction=direction)  # places the camera
        cam.data.lens = 50 * zoom
        bpy.ops.render.render(write_still=True)
        cam.data.lens = 50

    close([new], out("three_quarter"), (960, 960), (1.0, -1.3, 0.7))
    close([new], out("front"), (960, 960), (0.0, -1.0, 0.12))
    close([new], out("side"), (960, 960), (1.0, 0.0, 0.1))
    close([new], out("left"), (960, 960), (-1.0, -0.25, 0.3))
    close([new], out("back"), (960, 960), (-0.55, 1.3, 0.6))
    if turned is not None:
        new.location = (40, 0, 0)
        turned.location = (0, 0, 0)
        close([turned], out("aimed"), (960, 960), (1.0, -1.3, 0.7))
        turned.location = (40, 0, 0)
        new.location = (0, 0, 0)
    if ref is not None:
        # Third person: the camera 25 studs behind and above, Roblox's 70 degree field of view,
        # the soldier 3 studs to the gun's left, on a ground plane.
        ref.location = (-3.2, 1.0, 0)
        ground = bpy.data.meshes.new("_doorman_ground")
        ground.from_pydata([(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)], [], [(0, 1, 2, 3)])
        ground.uv_layers.new()
        u, v = ba.swatch_uv("concrete_l")
        for loop in ground.uv_layers.active.data:
            loop.uv = (u, v)
        ground.materials.append(new.data.materials[0])
        plane = bpy.data.objects.new("_doorman_ground", ground)
        scene.collection.objects.link(plane)
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = o not in (new, ref, plane)
        fit = cam.data.sensor_fit
        cam.data.sensor_fit = "VERTICAL"
        # `gameplay` is the whole screen; the `_crop` pictures are its middle, 2.5x.
        for view, eye, crop in (
            ("gameplay", (6.0, 23.0, 8.0), 1.0),
            ("gameplay_crop", (6.0, 23.0, 8.0), 2.5),
            ("gameplay_front_crop", (-9.0, -22.0, 7.0), 2.5),
        ):
            cam.data.angle_y = 2 * math.atan(math.tan(math.radians(35)) / crop)
            cam.location = eye
            from mathutils import Vector

            target = Vector((-1.0, 0.0, 2.2))
            cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
            scene.render.filepath = out(view)
            bpy.ops.render.render(write_still=True)
        cam.data.sensor_fit, cam.data.lens = fit, lens
        bpy.data.objects.remove(plane)
        if old is not None:
            old.location = (-5.2, 0, 0)
            ref.location = (-2.7, 0.6, 0)
            close([new, old, ref], out("vs_v1"), (1400, 800), (0.5, -1.3, 0.5), zoom=1.0)
    cam.data.lens = lens
    for o in (old, ref, turned):
        if o is not None:
            o.location = (0, 0, 0)
