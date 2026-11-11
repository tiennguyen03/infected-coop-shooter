"""The Driver, Mile 14's Index host (docs/CHARACTERS.md B; art director sheet 2026-11-09).

One file per singular asset (owner, 2026-11-07): every Driver mesh lives here and registers into
build_assets.py's ASSETS table with `register(ba)`, the warden.py pattern. Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only <names>

The lead-bus driver of the Harlan convoy, four days belted into his seat. The outline is an "h":
the torn-off driver's seat towers behind him (welded to the LowerTorso so it stays upright while
he folds away from it), a low teardrop belly hangs between bowed knees, pinched in two by the lap
belt, and a small capped head juts forward between them. Mass low and in front, one flat top:
nothing like the Brute's high horns or the common Bloat's upright ball. Scale 1.6 in game.

Meshes: `inf_driver_<limb>` (upper arm, lower arm, hand, upper leg, lower leg and foot sided
`_l` / `_r`), the attached parts `inf_driver_part_seat` / `_belly` / `_buckle` (welded on the
way IndexService welds the Warden's plates; the belly swells 1.15x over the 0.8 s vent tell, the
buckle flies off at death), and the assembled `ref_inf_driver` preview.
"""

import math

SKIN = "flesh"
TROUSERS = "paint_navy"  # transit uniform: navy + the grey shirt says "bus driver" at a glance

DRIVER_FOLD = 35  # upper torso pitched forward about the waist
DRIVER_ARM_FWD = -0.80  # the arms follow the folded shoulders (1.4 sin 35)
DRIVER_ARM_DOWN = -0.5  # below the folded chest top, so the shoulders never stand up like the Brute's horns
DRIVER_ARM_OUT = 0.40  # outboard of the belly
DRIVER_REACH = 0.75  # the hands hang at the knees
DRIVER_LEG_OUT = 0.30  # wide stance
DRIVER_BOW = 10  # knees bowed out: thigh out about the hip, shin back in about the ankle

SEAT_LEAN = 12  # degrees the seat back leans toward him, so it looms
SEAT_BACK_FOOT = (2.0, -0.3)  # (y, z) of the seat back's foot, behind the cushion

SIDED = ("upper_arm", "lower_arm", "hand", "upper_leg", "lower_leg", "foot")
# Attached parts: (part, the limb it welds to).
PARTS = (("seat", "lower_torso"), ("belly", "upper_torso"), ("buckle", "lower_torso"))


def driver_limb(L, limb, side=None):
    ba = L.ba
    sx = 1 if side == "r" else -1
    arm_shift = (sx * DRIVER_ARM_OUT, DRIVER_ARM_FWD, DRIVER_ARM_DOWN)
    if limb == "head":
        L.box((0.98, 0.98, 1.0), swatch=SKIN)  # face
        for s in (-1, 1):
            L.box((0.24, 0.5, 0.4), (s * 0.5, -0.1, -0.32), swatch=SKIN)  # jowls: a pear-shaped head
        L.eyes(z=0.02, y=-0.51, dx=0.22, size=(0.16, 0.1, 0.08))  # puffy, milky
        L.box((0.2, 0.16, 0.24), (0, -0.56, -0.08), swatch=SKIN)  # nose
        L.box((0.4, 0.08, 0.06), (0, -0.52, -0.32), swatch="dark_d")  # mouth: the retch slot
        L.lesion(0.26, 0.24, (0.66, -0.1, -0.3), face="right")
        for s in (-1, 1):
            L.box((0.5, 1.06, 0.3), (s * 0.28, 0, 0.62), swatch="tan_d")  # company cap, split in two
        L.box((1.08, 1.08, 0.08), (0, 0, 0.46), swatch="dark")  # hatband
        L.box((1.0, 0.4, 0.08), (0, -0.68, 0.48), swatch="tan_d")  # peak
        L.box((0.2, 0.06, 0.16), (0, -0.56, 0.62), swatch="brass")  # cap badge
        L.wedge((0.3, 0.3, 0.4), (0, 0.46, 0.58), swatch="rebuilt_l")  # the swelling through the split
        L.b.rotate_all((10, 0, 0), cent=(0, 0, ba.R15_NECK_DOWN))  # hung down...
        L.b.shift_all((0, -1.15, -0.42))  # ...onto the folded torso, pushed forward by the headrest
    elif limb == "upper_torso":
        L.box((1.94, 1.0, 1.1), (0, 0, 0.3), swatch="gun_l")  # transit shirt
        L.box((1.7, 0.9, 0.6), (0, 0, -0.5), swatch="gun_l")  # shirt to the waist
        L.box((0.5, 0.06, 0.5), (-0.55, -0.53, 0.4), swatch="gun")  # pocket
        L.box((0.34, 0.06, 0.12), (-0.55, -0.57, 0.6), swatch="brass")  # name badge
        L.oct(0.56, 0.12, (0, 0, 0.88), swatch="gun_l")  # collar
        L.oct(0.62, 0.3, (0, -0.05, 1.04), swatch=SKIN)  # neck roll over the collar
        L.box((0.9, 0.08, 0.6), (0, 0.53, 0.35), swatch="pus_d")  # sweat soak
        L.box((0.26, 0.08, 1.5), (-0.05, -0.55, 0.1), rot=(0, -40, 0), swatch="dark")  # shoulder belt
        L.box((0.26, 0.08, 0.12), (-0.62, -0.55, 0.78), swatch="dark_l")  # torn at the shoulder
        L.b.rotate_all((DRIVER_FOLD, 0, 0), cent=(0, 0, ba.R15_WAIST_DOWN))  # folded forward
        # hanging straight down from the folded chest
        L.box((2.0, 1.0, 0.55), (0, -1.0, -0.85), swatch=SKIN)  # upper belly roll
        for s in (-1, 1):
            L.box((0.06, 0.8, 0.45), (s * 1.03, -1.0, -0.85), swatch="rebuilt_l")
        L.box((1.7, 0.85, 0.22), (0, -1.0, -1.22), swatch="flesh_d")  # the lap-belt groove
        L.box((1.76, 0.06, 0.16), (0, -1.45, -1.22), swatch="dark")  # the strap in it
        for s in (-1, 1):
            L.box((0.06, 0.85, 0.16), (s * 0.88, -1.0, -1.22), swatch="dark")
        L.box((0.9, 0.06, 0.22), (0.45, -1.53, -0.95), rot=(0, -30, 0), swatch="dark")  # diagonal to the hip
        for x, r in ((-0.6, 10), (0.0, -8), (0.6, 10)):
            L.box((0.4, 0.08, 0.3), (x, -1.53, -0.62), rot=(0, r, 0), swatch="gun_l")  # shirt tatters
    elif limb == "lower_torso":
        L.box((2.5, 1.1, 0.5), swatch=TROUSERS)  # wide to cover the shifted legs
        L.box((2.56, 1.14, 0.12), (0, 0, 0.14), swatch="dark")  # belt
    elif limb == "upper_arm":
        L.oct(0.5, 0.3, (0, 0, 0.2), swatch="gun_l", r_top=0.36)  # sloped shoulder: no knob standing up
        L.oct(0.46, 0.5, (0, 0, -0.05), swatch="gun_l", r_top=0.5)  # short sleeve
        L.oct(0.5, 0.08, (0, 0, -0.32), swatch="gun")  # hem
        L.oct(0.4, 0.4, (0, 0, -0.5), swatch=SKIN, r_top=0.44)
        L.b.shift_all(arm_shift)
    elif limb == "lower_arm":
        L.cap(0.42, (0, 0, 0.14), swatch=SKIN)
        L.oct(0.38, 1.42, (0, 0, -0.55), swatch=SKIN, r_top=0.44)  # long: the hands hang at the knees
        if side == "r":
            L.oct(0.42, 0.2, (0, 0, -1.16), swatch="tan_d")  # glove cuff
        else:
            for z in (-1.1, -1.18, -1.26):
                L.oct(0.42, 0.05, (0, 0, z), swatch="dark")  # the key lanyard, coiled round the wrist
        L.lesion(0.3, 0.4, (sx * 0.4, 0, -0.4), face="right" if side == "r" else "left")
        L.b.shift_all(arm_shift)
    elif limb == "hand":
        sw = "tan_d" if side == "r" else SKIN
        L.box((0.9, 0.8, 0.36), swatch=sw)
        for x in (-0.3, -0.1, 0.1, 0.3):
            L.box((0.18, 0.2, 0.4), (x, -0.2, -0.36), swatch=sw)  # fingers hanging
        if side == "l":  # the bus keys: he never let go
            L.box((0.05, 0.05, 0.5), (-0.5, 0, -0.35), swatch="dark")
            L.ico(0.08, (-0.5, 0, -0.62), swatch="gun_l", subdiv=0)
            for i, r in enumerate((-20, 0, 20)):
                L.box((0.06, 0.18, 0.3), (-0.5, -0.12 + i * 0.12, -0.8), rot=(r, 0, 0), swatch="gun_l")
            L.box((0.18, 0.08, 0.24), (-0.5, 0.14, -0.72), swatch="dark_l")  # fob
        L.b.shift_all((arm_shift[0], arm_shift[1], arm_shift[2] - DRIVER_REACH))
    elif limb == "upper_leg":
        L.hip_inset(0.48, TROUSERS)
        L.oct(0.46, 1.0, (0, 0, -0.18), swatch=TROUSERS, r_top=0.5)
        L.box((0.08, 0.36, 0.7), (sx * 0.47, -0.05, -0.2), swatch=SKIN)  # split up the outer thigh
        for y in (-0.2, 0.2):
            L.box((0.08, 0.06, 0.72), (sx * 0.48, y - 0.05, -0.2), swatch="dark")
        L.b.rotate_all((0, -sx * DRIVER_BOW, 0), cent=(0, 0, ba.R15_HIP_UP))
        L.b.shift_all((sx * DRIVER_LEG_OUT, 0, 0))
    elif limb == "lower_leg":
        L.cap(0.44, (0, 0, 0.23), swatch=TROUSERS)
        L.oct(0.4, 0.88, (0, 0, -0.21), swatch=TROUSERS, r_top=0.44)
        L.box((1.04, 1.0, 0.3), (0, 0, -0.5), swatch="dark")  # shoe top
        knee_out = 0.921 * math.sin(math.radians(DRIVER_BOW))
        L.b.rotate_all((0, sx * math.degrees(math.asin(knee_out / 1.009)), 0), cent=(0, 0, ba.R15_ANKLE_DOWN))
        L.b.shift_all((sx * DRIVER_LEG_OUT, 0, 0))
    elif limb == "foot":
        L.box((1.1, 1.06, 0.23), (0, -0.03, 0.04), swatch="dark")  # work shoe
        L.box((1.1, 1.06, 0.08), (0, -0.03, -0.115), swatch="dark_d")
        L.b.shift_all((sx * DRIVER_LEG_OUT, 0, 0))


def driver_part(L, which):
    """Attached parts, built in the frame of the limb they weld to (PARTS)."""
    if which == "belly":
        # The lower lobe, stacked blocky steps under the lap belt (UpperTorso frame, after the fold).
        y = -1.15
        L.box((2.1, 1.1, 0.6), (0, y, -1.6), swatch=SKIN)
        L.box((1.8, 0.95, 0.5), (0, y, -2.05), swatch=SKIN)
        L.box((1.2, 0.7, 0.3), (0, y, -2.4), swatch="flesh_d")
        for w, z in ((2.1, -1.6), (1.8, -2.05)):
            for s in (-1, 1):
                L.box((0.06, 0.8, 0.4), (s * (w / 2 + 0.02), y, z), swatch="rebuilt_l")
        front = y - 0.55
        for x in (-0.7, -0.35, 0.05, 0.4, 0.75):  # veins, thickest at the belt
            L.box((0.12, 0.05, 0.3), (x, front - 0.03, -1.45), swatch="strain_d")
            L.box((0.07, 0.05, 0.35), (x * 0.9, front - 0.03, -1.75), rot=(0, 10 if x > 0 else -10, 0), swatch="strain_d")
        for s in (-1, 1):  # vent seams: the gas leaves here when the belt squeezes
            L.box((0.4, 0.06, 0.08), (s * 0.6, front - 0.04, -1.42), swatch="strain")
            for dz in (-0.07, 0.07):
                L.box((0.46, 0.05, 0.04), (s * 0.6, front - 0.05, -1.42 + dz), swatch="rebuilt_l")
    elif which == "seat":
        # The driver's seat, torn off its post (LowerTorso frame): stays upright behind him.
        L.box((2.0, 1.3, 0.4), (0, 1.35, -0.45), swatch="dark")  # cushion behind the butt
        L.box((2.0, 0.2, 0.44), (0, 0.78, -0.45), swatch="dark_l")  # front bolster
        lean = SEAT_LEAN
        a = math.radians(lean)

        def up(h, dy=0.0):  # a point h up the leaning back from its foot, dy behind its face
            return (0, SEAT_BACK_FOOT[0] - h * math.sin(a) + dy * math.cos(a), SEAT_BACK_FOOT[1] + h * math.cos(a) + dy * math.sin(a))

        L.box((1.9, 0.45, 3.2), up(1.6), rot=(lean, 0, 0), swatch="dark")  # seat back, leaning over him
        for s in (-1, 1):
            x, y, z = up(1.4, 0.02)
            L.box((0.2, 0.5, 2.6), (s * 1.0, y, z), rot=(lean, 0, 0), swatch="dark_l")  # side bolsters
        L.box((1.86, 0.08, 2.9), up(1.6, 0.27), rot=(lean, 0, 0), swatch="dark_d")  # rear shell
        for s in (-1, 1):
            x, y, z = up(3.35)
            L.cyl(0.06, 0.35, (s * 0.35, y, z), rot=(lean, 0, 0), swatch="gun_d", segs=6)  # headrest posts
        L.box((1.1, 0.5, 0.7), up(3.85), rot=(lean, 0, 0), swatch="dark")  # headrest: a head taller than him
        L.box((0.4, 0.08, 0.3), up(1.2, -0.25), rot=(lean, 0, 0), swatch="tan_l")  # foam at a rip
        L.box((0.4, 0.3, 0.08), (-0.4, 1.5, -0.22), swatch="tan_l")
        L.box((1.6, 1.0, 0.12), (0, 1.4, -0.72), swatch="gun_d")  # mount frame
        L.cyl(0.18, 0.7, (0, 1.6, -0.95), rot=(50, 0, 0), swatch="gun_d", segs=8)  # post stub, angled back
        L.box((0.5, 0.06, 0.3), (0, 1.86, -1.18), rot=(50, 0, 0), swatch="gun_l")  # torn flange
        for x in (-0.7, 0.7):
            for y in (0.95, 1.85):
                L.ico(0.06, (x, y, -0.66), swatch="gun_l", subdiv=0)  # bolts
        for s in (-1, 1):
            L.box((0.08, 1.25, 0.18), (s * 1.31, 0.1, -0.2), swatch="dark")  # lap belt along the hips
        x, y, z = up(2.6, -0.26)
        L.box((0.24, 0.06, 0.8), (-0.75, y, z), rot=(lean, 0, 0), swatch="dark")  # torn shoulder belt stub
        x, y, z = up(2.15, -0.26)
        L.box((0.24, 0.06, 0.12), (-0.75, y, z), rot=(lean, 0, 0), swatch="dark_l")  # its frayed end
    elif which == "buckle":
        L.box((0.5, 0.14, 0.34), (0.95, -0.62, -0.05), swatch="gun_l")
        L.box((0.24, 0.08, 0.3), (0.8, -0.71, -0.05), swatch="gun")  # tongue


def register(ba):
    """Adds every Driver mesh to build_assets' ASSETS table (ba = the build_assets module)."""
    import bmesh
    from mathutils import Vector

    class DriverLimb(ba.Limb):
        pass

    DriverLimb.ba = ba

    for limb in ba.R15_LIMB:
        for side in ("l", "r") if limb in SIDED else (None,):

            def fn(b, limb_name=limb, side_=side):
                driver_limb(DriverLimb(b), limb_name, side_)

            name = f"inf_driver_{limb}" + (f"_{side}" if side else "")
            ba.ASSETS[name] = (fn, "Infected", "center")

    for which, _ in PARTS:

        def part(b, w=which):
            driver_part(DriverLimb(b), w)

        ba.ASSETS[f"inf_driver_part_{which}"] = (part, "Infected", "center")

    def preview(b):
        # Assembled figure at R15 offsets (hip at z=0) with the parts on, for the lineup only.
        def place(sub, x, y, z):
            bmesh.ops.translate(sub.bm, vec=Vector((x, y, z)), verts=list(sub.bm.verts))
            b.merge(sub)

        for limb, (x, y, z) in ba.R15_POSE.items():
            for s in (1,) if x == 0 else (-1, 1):
                sub = ba.Builder()
                driver_limb(DriverLimb(sub), limb, ("r" if s > 0 else "l") if limb in SIDED else None)
                place(sub, s * x, y, z)
        for which, limb in PARTS:
            x, y, z = ba.R15_POSE[limb]
            sub = ba.Builder()
            driver_part(DriverLimb(sub), which)
            place(sub, x, y, z)

    ba.ASSETS["ref_inf_driver"] = (preview, "_Reference", "bottom")
