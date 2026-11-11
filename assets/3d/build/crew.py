"""The Carrier's crew body (Nova, 2026-11-10: "all the npcs to have r15 models like the player
instead of just being regular blocks").

One R15 limb set, `npc_crew_<limb>`, built like the Chosen's (same limb boxes, tapered
forearms and shins, elbow and knee caps) but in plain working dress: a shirt with a collar,
a placket and breast pockets; trousers with a front pocket; a bare head with a nose and ears;
fists; boots with a shaft. The game wears it UNTEXTURED: NpcBody sets each limb's Color to
the figure's shirt, trousers, skin or gloves, so one upload dresses every desk, walker and
crew chief. Every swatch here is "white" so the preview shows the shapes only.

Faces, hair and headgear (Nova, 2026-11-11: the block eyes "dont look right" on the R15 crew):
`npc_gear_*` pieces built around the HEAD's own origin, so NpcBody welds each one exactly where
it was designed (MeshAssets offsets it like a limb), each one colour: the face (eyes, mouth),
four hair styles with their brows, a cap, a combat helmet, a flight helmet and its visor, ear
defenders, a one-ear headset and glasses. Exported pre-mirrored (MIRROR_X_PREFIXES): Roblox
mirrors a mesh left-right, and the headset and the parted hair have a side.
"""

W_ = "white"


def _limb(ba, b, limb, o=(0, 0, 0)):
    L = ba.Limb(b, o)
    W, D, H = ba.R15_LIMB[limb]
    if limb == "head":
        # A face with planes: the cranium, a narrower jaw, cheekbones, a brow ridge the eyes
        # sit under, a nose with a bridge and a tip, the chin; the ears. Face front at y -0.53.
        L.box((1.12, 1.1, 0.84), (0, 0.02, 0.17), swatch=W_)  # cranium, brow to crown
        L.box((0.98, 1.0, 0.38), (0, 0.04, -0.4), swatch=W_)  # jaw
        for x in (-0.3, 0.3):
            L.box((0.3, 0.1, 0.2), (x, -0.5, -0.12), swatch=W_)  # cheekbones
        L.box((0.96, 0.1, 0.1), (0, -0.56, 0.2), swatch=W_)  # brow ridge
        L.box((0.13, 0.1, 0.24), (0, -0.57, 0.02), swatch=W_)  # nose bridge
        L.box((0.2, 0.13, 0.12), (0, -0.6, -0.12), swatch=W_)  # nose tip
        L.box((0.42, 0.1, 0.18), (0, -0.5, -0.5), swatch=W_)  # chin
        for x in (-0.58, 0.58):
            L.box((0.1, 0.22, 0.3), (x, 0.04, 0.0), swatch=W_)  # ears
    elif limb == "upper_torso":
        L.box((W, D, H), swatch=W_)
        L.box((1.0, 0.86, 0.14), (0, 0.04, 0.78), swatch=W_)  # collar
        L.box((0.12, 0.06, 1.5), (0, -0.52, 0.0), swatch=W_)  # placket
        for x in (-0.48, 0.48):
            L.box((0.46, 0.08, 0.4), (x, -0.53, 0.28), swatch=W_)  # breast pockets
            L.box((0.5, 0.1, 0.1), (x, -0.55, 0.47), swatch=W_)  # their flaps
    elif limb == "lower_torso":
        L.box((W, D, H), swatch=W_)
    elif limb == "upper_arm":
        L.box((W, D, H), swatch=W_)
        L.box((1.04, 1.04, 0.24), (0, 0, 0.48), swatch=W_)  # shoulder seam
        elbow = ba.R15_JOINTS["elbow"][2] - ba.R15_POSE["upper_arm"][2]
        L.pad(ba.CAP_R, 0.94, (0, 0, elbow), swatch=W_)
    elif limb == "lower_arm":
        L.taper((W, D, H), bottom=ba.PC_TAPER_AT, swatch=W_)  # sleeve narrows to the wrist
        L.box((0.8, 0.8, 0.16), (0, 0, -0.46), swatch=W_)  # cuff
    elif limb == "hand":
        L.box((0.82, 0.86, 0.32), swatch=W_)
    elif limb == "upper_leg":
        L.box((W, D, H), swatch=W_)
        L.box((0.42, 0.1, 0.44), (0, -0.5, 0.15), swatch=W_)  # front pocket
        knee = ba.R15_JOINTS["knee"][2] - ba.R15_POSE["upper_leg"][2]
        L.pad(ba.CAP_R, 0.94, (0, 0, knee), swatch=W_)
    elif limb == "lower_leg":
        L.taper((W, D, H), bottom=0.8, swatch=W_)  # shin narrows to the boot
    elif limb == "foot":
        L.shoe(W_)
        L.taper((0.84, 0.84, 0.4), (0, 0, 0.35), bottom=0.96, swatch=W_, sides=4)  # boot shaft


# --- Faces, hair, headgear: head space (X right, -Y front, Z up), one colour each.
def _brows(L):
    for x in (-0.25, 0.25):
        L.box((0.26, 0.05, 0.06), (x, -0.615, 0.24), swatch=W_)


def _gear(ba, b, name):
    L = ba.Limb(b)
    if name == "face":
        for x in (-0.24, 0.24):
            L.box((0.17, 0.03, 0.08), (x, -0.545, 0.08), swatch=W_)  # eyes, under the brow ridge
        L.box((0.32, 0.03, 0.035), (0, -0.465, -0.3), swatch=W_)  # mouth
    elif name.startswith("hair_"):
        style = name[5:]
        _brows(L)
        if style == "buzz":  # clipped close: a thin shell
            L.box((1.14, 1.12, 0.06), (0, 0.02, 0.62), swatch=W_)
            for x in (-0.575, 0.575):
                L.box((0.03, 0.8, 0.32), (x, 0.06, 0.4), swatch=W_)
            L.box((1.12, 0.03, 0.5), (0, 0.585, 0.34), swatch=W_)
        else:  # crop, parted, bun: short on top, the sides above the ears, the back to the nape
            top = 0.12 if style == "bun" else 0.16
            L.box((1.16, 1.14, top), (0, 0.02, 0.59 + top / 2), swatch=W_)
            for x in (-0.585, 0.585):
                L.box((0.05, 0.86, 0.4), (x, 0.06, 0.38), swatch=W_)
            L.box((1.14, 0.05, 0.62), (0, 0.6, 0.3), swatch=W_)
            L.box((1.06, 0.06, 0.1), (0, -0.55, 0.55), swatch=W_)  # hairline over the forehead
            if style == "parted":  # swept from a left parting over to the right
                L.box((0.62, 1.12, 0.08), (0.22, 0.02, 0.79), swatch=W_)
                L.box((0.5, 0.08, 0.12), (0.2, -0.56, 0.6), swatch=W_)
            elif style == "bun":  # tied back
                L.cyl(0.2, 0.24, (0, 0.72, 0.36), rot=(90, 0, 0), swatch=W_, segs=10)
    elif name == "cap":  # a ship's ball cap
        L.prism([(-0.17, 0.6, 0.59), (0.04, 0.6, 0.59), (0.17, 0.46, 0.45)], swatch=W_, loc=(0, 0.03, 0.66), sides=10)
        L.box((1.0, 0.46, 0.05), (0, -0.74, 0.5), rot=(-6, 0, 0), swatch=W_)  # brim
        L.box((0.14, 0.14, 0.05), (0, 0.03, 0.85), swatch=W_)  # button
    elif name == "helmet_combat":
        L.prism([(-0.28, 0.68, 0.7), (0.06, 0.68, 0.7), (0.28, 0.5, 0.52)], swatch=W_, loc=(0, 0.04, 0.48), sides=10)
        L.box((1.4, 1.44, 0.08), (0, 0.04, 0.22), swatch=W_)  # rim
        for x in (-0.66, 0.66):
            L.box((0.1, 0.9, 0.36), (x, 0.12, 0.06), swatch=W_)  # over the ears
        L.box((1.2, 0.05, 0.06), (0, -0.46, -0.5), swatch=W_)  # chin strap
    elif name == "helmet_flight":
        L.prism([(-0.31, 0.67, 0.68), (0.08, 0.67, 0.68), (0.31, 0.5, 0.5)], swatch=W_, loc=(0, 0.04, 0.38), sides=10)
        for x in (-0.66, 0.66):
            L.box((0.12, 1.1, 0.64), (x, 0.06, -0.02), swatch=W_)  # sides down past the ears
        L.box((1.3, 0.1, 0.6), (0, 0.66, 0.0), swatch=W_)  # back of the neck
        L.box((0.5, 0.16, 0.18), (0, -0.64, 0.66), swatch=W_)  # visor housing
    elif name == "visor":  # the flight helmet's visor, down over the eyes
        L.box((1.0, 0.05, 0.4), (0, -0.7, 0.12), swatch=W_)
        for x in (-0.55, 0.55):
            L.box((0.05, 0.26, 0.4), (x, -0.6, 0.12), rot=(0, 0, 30 if x < 0 else -30), swatch=W_)
    elif name == "ear_defenders":
        L.box((1.32, 0.1, 0.12), (0, 0.02, 0.66), swatch=W_)  # band over the crown
        for x in (-0.64, 0.64):
            L.box((0.06, 0.1, 0.5), (x, 0.02, 0.38), swatch=W_)
            L.cyl(0.27, 0.2, (x * 1.04, 0.02, 0.0), rot=(0, 90, 0), swatch=W_, segs=12)  # cups
    elif name == "headset_one_ear":  # on the left ear, the right cup pushed back off the ear
        L.box((1.3, 0.1, 0.12), (0, 0.06, 0.66), swatch=W_)
        L.cyl(0.24, 0.16, (-0.66, 0.04, 0.0), rot=(0, 90, 0), swatch=W_, segs=12)
        L.cyl(0.22, 0.14, (0.66, 0.36, 0.22), rot=(0, 90, 0), swatch=W_, segs=12)
        L.box((0.04, 0.5, 0.04), (-0.62, -0.26, -0.22), rot=(-20, 0, 0), swatch=W_)  # mic boom
        L.box((0.08, 0.08, 0.08), (-0.56, -0.52, -0.3), swatch=W_)  # mic
    elif name == "glasses":  # reading glasses: rims, bridge, arms to the ears
        for x in (-0.24, 0.24):
            L.box((0.3, 0.03, 0.04), (x, -0.6, 0.18), swatch=W_)  # top rim
            L.box((0.3, 0.03, 0.03), (x, -0.6, -0.01), swatch=W_)  # bottom rim
            for e in (-0.14, 0.14):
                L.box((0.03, 0.03, 0.2), (x + e, -0.6, 0.085), swatch=W_)  # side rims
            L.box((0.03, 0.56, 0.03), (x * 2.4, -0.33, 0.16), swatch=W_)  # arms
        L.box((0.18, 0.03, 0.03), (0, -0.61, 0.14), swatch=W_)  # bridge


GEAR = ("face", "hair_crop", "hair_buzz", "hair_parted", "hair_bun", "cap", "helmet_combat",
        "helmet_flight", "visor", "ear_defenders", "headset_one_ear", "glasses")


def register(ba):
    """Adds the crew limb set and its preview figure to build_assets' ASSETS table."""
    for limb in ba.R15_LIMB:
        def fn(b, limb_name=limb):
            _limb(ba, b, limb_name)
        ba.ASSETS[f"npc_crew_{limb}"] = (fn, "Crew", "center")

    def preview(b):
        for limb, (x, y, z) in ba.R15_POSE.items():
            for s in ((1,) if x == 0 else (-1, 1)):
                _limb(ba, b, limb, (s * x, y, z))
    ba.ASSETS["ref_npc_crew"] = (preview, "_Reference", "bottom")

    for name in GEAR:
        def gear(b, gear_name=name):
            _gear(ba, b, gear_name)
        ba.ASSETS[f"npc_gear_{name}"] = (gear, "Crew", "center")
