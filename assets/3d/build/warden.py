"""The Warden, Delta's Index host (docs/CHARACTERS.md B, docs/sprints/SPRINT_19_WARDEN.md).

One file per singular asset (owner, 2026-11-07): this module holds every Warden mesh and is
registered into build_assets.py's ASSETS table by `register(ba)` (ba = the build_assets
module, which supplies Builder / Limb / the R15 tables). Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only <names>

v2 silhouette (designed live in Blender with the owner, 2026-11-07): upright and tall where
the Brute is hunched (no bone shelf; a chest that narrows to the waist); the head sunk into a
riot gorget so helmet, collar and the left shoulder dome read as one armoured mass; the left
side armoured (lamed sleeve, vambrace grown into a convex three-panel riot shield), the right
side the bare man (swollen bruise arm, the white MP brassard, bone spurs, an oversized fist,
a small strapped shoulder pad); slim olive trousers under a thigh guard, knee cup and a
knee-to-boot greave so each leg reads as one column; duty belt with the gas canisters on the
right hip and a baton on the left; radio pack with a whip antenna on the back plate.

Canon kept: fused riot helmet with the cracked face shield, chest plate with the grown-in
handset and coiled cord, the shield grown into the left forearm, six breakable plates (helmet,
chest, back, shoulder_l, shoulder_r, shield) as separate meshes IndexService welds on, scale
1.9 in game, `bruise` skin with `strain_l` seams under every plate. 5,000-tri boss cap.

Meshes: `inf_warden_<limb>` (arms and hands side-specific: `_l` / `_r`),
`inf_warden_plate_<which>`, and the assembled `ref_inf_warden` preview figure.
"""

SKIN = "bruise"

# Plates on the assembled preview: (plate, limb it welds to, side sign).
PLATES = (
    ("helmet", "head", 0),
    ("chest", "upper_torso", 0),
    ("back", "upper_torso", 0),
    ("shoulder_l", "upper_arm", -1),
    ("shoulder_r", "upper_arm", 1),
    ("shield", "lower_arm", -1),
)
SIDED = ("upper_arm", "lower_arm", "hand")


def warden_limb(L, limb, side=None):
    W, D, H = L.R15_LIMB[limb]
    skin = SKIN
    if limb == "head":
        # Under the shell: a rebuilt skull on a bruised jaw, sunk low (the collar hides the chin).
        L.box((0.9, 0.9, 0.5), (0, 0, -0.3), swatch=skin)  # jaw
        L.oct(0.5, 0.72, (0, 0, 0.26), swatch="rebuilt", r_top=0.42)  # plated skull
        L.box((0.08, 1.0, 0.06), (0.16, 0, 0.62), swatch="strain_l")  # the seam the helmet hides
        L.box((1.0, 0.2, 0.16), (0, -0.5, 0.1), swatch="rebuilt_d")  # brow
        for x in (-0.24, 0.24):  # eyes lit strain behind the visor
            L.box((0.28, 0.08, 0.18), (x, -0.5, -0.06), swatch="dark_d")
            L.box((0.18, 0.1, 0.1), (x, -0.51, -0.06), swatch="strain_l")
        L.box((0.6, 0.1, 0.08), (0, -0.52, -0.26), swatch="dark_d")  # mouth
        L.box((0.92, 0.06, 0.1), (0, -0.48, -0.46), swatch="dark")  # chin strap
        L.lesion(0.26, 0.26, (0.46, 0.02, -0.3), face="right")
    elif limb == "upper_torso":
        # Upright: a chest that narrows to the waist (no bone shelf), a riot gorget the head sinks into.
        L.box((1.94, 1.0, 1.0), (0, 0, 0.3), swatch="olive")  # chest
        L.box((1.62, 0.86, 0.8), (0, 0, -0.45), swatch="olive")  # waist
        L.box((1.94, 0.2, 0.12), (0, -0.45, 0.72), swatch="olive_d")  # yoke seam
        # the gorget: a dark ring the head sits down in, hollow-read with a dark_d core
        L.oct(0.8, 0.46, (0, 0, 1.04), swatch="dark", r_top=0.74)
        L.oct(0.62, 0.5, (0, 0, 1.05), swatch="dark_d")
        L.oct(0.82, 0.08, (0, 0, 1.28), swatch="dark_l")  # rim
        # the raised collar on the shield side: shelters the head, one mass with the dome
        L.box((0.6, 0.96, 0.3), (-0.62, 0, 1.3), swatch="dark")
        L.wedge((0.6, 0.96, 0.3), (-0.62, 0, 1.6), swatch="dark")  # rises and rolls outward
        L.box((0.62, 1.0, 0.06), (-0.62, 0, 1.47), swatch="dark_l")
        # right shoulder bare: the shirt torn away over the swollen arm (the bare man)
        L.box((0.62, 0.96, 0.3), (0.66, 0, 0.95), swatch=skin)
        L.lesion(0.3, 0.26, (0.7, -0.5, 0.95))
        # what the chest plate hides: ribs through the shirt, a strain seam under each
        for z in (0.3, -0.1):
            L.box((1.2, 0.06, 0.08), (0, -0.52, z), swatch="rebuilt")
            L.box((1.1, 0.05, 0.04), (0, -0.53, z - 0.1), swatch="strain_l")
        L.box((0.4, 0.06, 1.2), (0, 0.52, -0.1), swatch="rebuilt")  # spine ridge (back plate hides it)
        L.box((0.08, 0.05, 1.2), (-0.26, 0.53, -0.1), swatch="strain_l")
        L.box((0.36, 0.06, 1.3), (-0.25, -0.52, -0.1), swatch="olive_d")  # rig straps
        L.box((0.36, 0.06, 1.3), (0.25, -0.52, -0.1), swatch="olive_d")
    elif limb == "lower_torso":
        L.box((1.66, 0.88, 0.4), swatch="olive")
        L.box((1.74, 0.96, 0.18), (0, 0, 0.08), swatch="dark")  # duty belt
        L.box((0.28, 0.14, 0.12), (0, -0.5, 0.08), swatch="brass")  # buckle
        L.box((1.3, 0.14, 0.3), (0, -0.5, -0.12), swatch="dark")  # groin lame
        L.box((1.34, 0.06, 0.06), (0, -0.58, -0.02), swatch="dark_l")
        for y in (-0.22, 0.14):  # gas canisters on the right hip (the phase-2 lob)
            L.cyl(0.15, 0.5, (0.96, y, -0.12), swatch="gun_d")
            L.cyl(0.07, 0.08, (0.96, y, 0.17), swatch="gun_l")
        L.box((0.14, 0.14, 0.26), (-0.92, -0.2, 0.02), swatch="dark_d")  # baton ring
        L.cyl(0.06, 0.9, (-1.08, -0.2, -0.46), swatch="dark_d", segs=6)  # baton hanging
        L.box((0.26, 0.26, 0.26), (-0.9, 0.22, 0.0), swatch="dark")  # cuff pouch
    elif limb == "upper_arm":
        L.oct(0.47, 0.05, (0, 0, 0.3), swatch="strain_l")  # seam ring under the plate edge
        if side == "l":  # armoured: padded dark sleeve in lames
            L.cap(0.46, (0, 0, 0.16), swatch="dark_d")
            L.oct(0.44, 0.74, (0, 0, -0.28), swatch="dark_d", r_top=0.46)
            for z in (0.0, -0.24, -0.48):
                L.oct(0.5, 0.1, (0, 0, z), swatch="dark")  # lames
        else:  # bare: the swollen arm, the white MP brassard
            L.cap(0.46, (0, 0, 0.16), swatch=skin)
            L.oct(0.4, 0.76, (0, 0, -0.3), swatch=skin, r_top=0.48)
            L.oct(0.44, 0.3, (0, 0, -0.2), swatch="white")
            for y in (-0.12, 0.12):  # two abstract bars (no text)
                L.box((0.06, 0.12, 0.2), (0.44, y, -0.2), swatch="dark_d")
            L.lesion(0.26, 0.3, (0.1, 0.42, -0.55), face="back")
    elif limb == "lower_arm":
        if side == "l":  # vambrace fused to the shield's grips
            L.cap(0.5, (0, 0, 0.08), swatch="dark_d")  # elbow cup
            L.oct(0.46, 0.74, (0, 0, -0.26), swatch="dark", r_top=0.5)
            L.oct(0.52, 0.08, (0, 0, -0.1), swatch="dark_l")
            # the wrist grown into the shield's handle (the shield plate sits past the fist)
            L.oct(0.5, 0.22, (0, 0, -0.52), swatch="rebuilt")
            L.oct(0.52, 0.05, (0, 0, -0.42), swatch="strain_l")  # seam where the growth starts
        else:  # the striking arm: swollen, spurred
            L.cap(0.54, (0, 0, 0.02), swatch=skin)
            L.oct(0.5, 0.66, (0, 0, -0.28), swatch=skin, r_top=0.56)
            for z in (0.3, 0.0, -0.3):
                L.box((0.24, 0.2, 0.3), (0.5, 0.1, z), rot=(0, 30, 0), swatch="rebuilt")  # ulna spurs
            L.blotch(0.4, 0.5, (0, -0.5, -0.16), swatch="bruise_d")
            L.boil(0.1, (0.3, -0.44, -0.1), n=(0.4, -0.9, 0))
    elif limb == "hand":
        if side == "l":
            L.box((0.9, 0.7, 0.36), (0, 0.1, 0.0), swatch="dark_d")  # gauntlet, behind the shield
        else:
            L.box((1.1, 0.84, 0.44), (0, 0.1, 0.0), swatch=skin)  # swollen fist
            L.box((1.0, 0.34, 0.24), (0, -0.42, 0.1), swatch="rebuilt_l")  # knuckles through
            for x in (-0.26, 0.0, 0.26):
                L.box((0.05, 0.4, 0.3), (x, -0.4, -0.06), swatch="bruise_d")
    elif limb == "upper_leg":
        # slim trouser, a strapped riot thigh guard, knee cup
        L.hip_inset(0.44, "olive", h=0.36)
        L.oct(0.42, 0.9, (0, 0, 0.05), swatch="olive")
        L.oct(0.4, 0.4, (0, 0, -0.5), swatch="olive", r_top=0.42)
        L.box((0.54, 0.16, 0.8), (0, -0.44, -0.06), swatch="dark")  # thigh guard
        for z in (0.2, -0.1):
            L.box((0.56, 0.06, 0.06), (0, -0.53, z), swatch="dark_l")
        L.oct(0.46, 0.08, (0, 0, 0.3), swatch="olive_d")  # strap
        L.box((0.72, 0.36, 0.34), (0, -0.4, -0.58), swatch="dark_d")  # knee cup
    elif limb == "lower_leg":
        # the greave: knee to boot, so the leg reads as one armoured column
        L.cap(0.4, (0, 0, 0.25), swatch="olive")
        L.oct(0.36, 0.8, (0, 0, -0.15), swatch="olive", r_top=0.4)
        L.box((0.6, 0.3, 1.04), (0, -0.4, 0.02), swatch="dark")  # shin plate
        for z in (0.35, 0.05, -0.25):
            L.box((0.64, 0.08, 0.08), (0, -0.54, z), swatch="dark_l")  # ribs
        L.box((0.86, 0.86, 0.4), (0, 0, -0.45), swatch="dark_d")  # boot shaft
    elif limb == "foot":
        L.box((1.05, 1.06, 0.1), (0, 0, -0.1), swatch="dark_d")  # heavy sole
        L.box((0.98, 1.0, 0.22), (0, 0, 0.06), swatch="dark_d")
        L.box((0.9, 0.3, 0.26), (0, -0.4, 0.06), swatch="dark")  # toe cap


# Each plate is built in the frame of the limb it welds to (helmet on Head, chest and back on
# UpperTorso, shoulder_l / shoulder_r on their UpperArm, shield on LeftLowerArm, facing front
# when the arm hangs). IndexService gives each its own health.
def warden_plate(L, which):
    if which == "helmet":
        # rounded riot crown sitting low, full face shield down into the collar, neck lame behind
        L.oct(0.74, 0.4, (0, 0, 0.26), swatch="dark", r_top=0.64)  # crown
        L.oct(0.64, 0.34, (0, 0, 0.62), swatch="dark", r_top=0.3)  # dome
        L.oct(0.76, 0.08, (0, 0, 0.08), swatch="dark_l")  # brow band
        for x in (-0.64, 0.64):
            L.box((0.12, 1.0, 0.8), (x, 0.06, -0.26), swatch="dark")  # cheek guards down into the collar
        L.box((1.36, 0.3, 0.08), (0, -0.7, 0.14), swatch="dark")  # peak
        L.box((1.2, 0.08, 0.82), (0, -0.66, -0.18), swatch="gun_l")  # face shield
        L.box((0.05, 0.1, 0.7), (0.2, -0.68, -0.18), rot=(0, 18, 0), swatch="dark_d")  # the crack across it
        L.box((1.2, 0.08, 0.1), (0, -0.66, -0.62), swatch="dark")  # the shield's lower rail
        L.wedge((1.3, 0.5, 0.5), (0, 0.7, -0.3), rot=(0, 0, 90), swatch="dark")  # neck lame flaring back
        L.box((0.16, 0.2, 0.2), (0.66, -0.3, 0.34), swatch="dark_d")  # helmet strobe mount
    elif which == "chest":
        # narrower than the torso so the olive undersuit shows round it (a carrier, not a slab)
        L.box((1.5, 0.28, 1.5), (0, -0.6, -0.02), swatch="dark")
        L.box((1.56, 0.1, 0.18), (0, -0.76, 0.68), swatch="dark_l")  # top edge
        for z in (0.26, -0.2):
            L.box((1.56, 0.08, 0.06), (0, -0.76, z), swatch="dark_l")  # lame breaks
        L.box((1.56, 0.1, 0.14), (0, -0.76, -0.72), swatch="dark_l")
        L.box((0.36, 0.26, 0.56), (0.58, -0.88, 0.4), swatch="gun_d")  # the handset, grown in
        L.box((0.26, 0.04, 0.3), (0.58, -1.02, 0.48), swatch="dark_d")  # speaker grille
        L.box((0.08, 0.06, 0.08), (0.7, -1.02, 0.18), swatch="red")  # TX lamp
        for x, z in ((0.34, 0.08), (0.2, -0.1), (0.08, -0.28)):  # the coiled cord, three turns
            L.cyl(0.06, 0.12, (x, -0.82, z), rot=(90, 0, 0), segs=6, swatch="gun_d")
    elif which == "back":
        L.box((1.5, 0.28, 1.5), (0, 0.6, -0.02), swatch="dark")
        L.box((1.56, 0.1, 0.18), (0, 0.76, 0.68), swatch="dark_l")
        L.box((1.3, 0.06, 0.32), (0, 0.78, 0.1), swatch="white")  # the MP band, abstract
        L.box((1.0, 0.06, 0.06), (0, 0.82, 0.1), swatch="dark_d")
        L.box((0.5, 0.34, 0.7), (-0.56, 0.86, -0.3), swatch="olive_d")  # radio pack
        L.cyl(0.03, 2.0, (-0.72, 0.92, 0.9), swatch="gun_d", segs=6)  # whip antenna, above the collar
        L.ico(0.05, (-0.72, 0.92, 1.9), swatch="red", subdiv=0)
    elif which == "shoulder_l":
        # the big dome on the shield side: one mass with the helmet and collar from the front
        L.oct(0.86, 0.5, (0, 0, 0.56), swatch="dark", r_top=0.62)
        L.oct(0.88, 0.08, (0, 0, 0.32), swatch="dark_l")  # rim
        L.oct(0.9, 0.14, (0, 0, 0.2), swatch="dark")  # second lame under the rim
        L.box((0.16, 0.9, 0.5), (-0.7, 0, 0.0), swatch="dark")  # outer lame hanging off the dome
    elif which == "shoulder_r":
        # a strapped pad over the bare arm
        L.oct(0.58, 0.26, (0, 0, 0.5), swatch="dark", r_top=0.48)
        L.oct(0.6, 0.06, (0, 0, 0.37), swatch="dark_l")
        L.box((0.12, 1.02, 0.14), (0, 0, 0.4), swatch="olive_d")  # strap over
    elif which == "shield":
        # Convex riot shield strapped along the OUTER forearm (limb -X), the way Mixamo's
        # sword-and-shield clips carry a shield: in the idle and the guard the forearm lies
        # horizontal across the chest with its outer side forward (measured in game
        # 2026-11-07: limb -X = forward, limb +Z = down), so the plate's tall axis runs
        # along the limb's Z (Blender Y) and its face points -X. Door-sized at scale 1.9:
        # eye level to shin when he guards. Hanging straight it lies flat at the thigh,
        # which only the death clip shows.
        cx = -0.78  # just outside the vambrace
        cy, cz = 0.3, -0.2  # a little low (limb +Z is down in the guard), toward the hand
        L.box((0.14, 4.0, 1.1), (cx, cy, cz), swatch="dark_l")  # centre panel
        for s in (-1, 1):  # side panels folded back toward the arm
            L.box((0.14, 4.0, 0.62), (cx + 0.13, cy, cz + s * 0.83), rot=(0, s * 25, 0), swatch="dark_l")
        L.box((0.1, 0.16, 1.1), (cx - 0.02, cy - 2.06, cz), swatch="dark")  # top edge
        L.box((0.1, 0.16, 1.1), (cx - 0.02, cy + 2.06, cz), swatch="dark")  # bottom edge
        L.box((0.06, 0.9, 0.9), (cx - 0.1, cy - 1.1, cz), swatch="gun_l")  # window, up by the visor
        L.box((0.06, 0.3, 1.0), (cx - 0.1, cy + 0.9, cz), swatch="white_d")  # the band where the lettering was
        L.box((0.3, 0.56, 0.56), (cx + 0.2, cy, cz), swatch="rebuilt")  # the strap, grown to the forearm


def register(ba):
    """Adds every Warden mesh to build_assets' ASSETS table (ba = the build_assets module)."""
    import bmesh
    from mathutils import Vector

    class WardenLimb(ba.Limb):
        R15_LIMB = ba.R15_LIMB

    for limb in ba.R15_LIMB:
        if limb in SIDED:
            for side in ("l", "r"):

                def fn(b, limb_name=limb, side_=side):
                    warden_limb(WardenLimb(b), limb_name, side_)

                ba.ASSETS[f"inf_warden_{limb}_{side}"] = (fn, "Infected", "center")
        else:

            def fn(b, limb_name=limb):
                warden_limb(WardenLimb(b), limb_name)

            ba.ASSETS[f"inf_warden_{limb}"] = (fn, "Infected", "center")

    for which, _, _ in PLATES:

        def plate(b, w=which):
            warden_plate(WardenLimb(b), w)

        ba.ASSETS[f"inf_warden_plate_{which}"] = (plate, "Infected", "center")

    def preview(b):
        # Assembled figure at R15 offsets (hip at z=0) with the plates on, for the lineup only.
        def place(sub, x, y, z):
            bmesh.ops.translate(sub.bm, vec=Vector((x, y, z)), verts=list(sub.bm.verts))
            b.merge(sub)

        for limb, (x, y, z) in ba.R15_POSE.items():
            for s in (1,) if x == 0 else (-1, 1):
                sub = ba.Builder()
                warden_limb(WardenLimb(sub), limb, ("r" if s > 0 else "l") if limb in SIDED else None)
                place(sub, s * x, y, z)
        for which, limb, s in PLATES:
            x, y, z = ba.R15_POSE[limb]
            sub = ba.Builder()
            warden_plate(WardenLimb(sub), which)
            place(sub, s * x, y, z)

    ba.ASSETS["ref_inf_warden"] = (preview, "_Reference", "bottom")
