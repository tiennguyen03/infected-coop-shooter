"""The Carrier's crew body (Nova, 2026-11-10: "all the npcs to have r15 models like the player
instead of just being regular blocks").

One R15 limb set, `npc_crew_<limb>`, built like the Chosen's (same limb boxes, tapered
forearms and shins, elbow and knee caps) but in plain working dress: a shirt with a collar,
a placket and breast pockets; trousers with a front pocket; a bare head with a nose and ears;
fists; boots with a shaft. The game wears it UNTEXTURED: NpcBody sets each limb's Color to
the figure's shirt, trousers, skin or gloves, so one upload dresses every desk, walker and
crew chief. Faces, hair, headgear and kit are small parts NpcBody welds on. Every swatch here
is "white" so the preview shows the shapes only.
"""

W_ = "white"


def _limb(ba, b, limb, o=(0, 0, 0)):
    L = ba.Limb(b, o)
    W, D, H = ba.R15_LIMB[limb]
    if limb == "head":
        L.box((W * 0.96, D * 0.96, H), swatch=W_)
        L.box((0.16, 0.12, 0.22), (0, -0.6, -0.06), swatch=W_)  # nose
        for x in (-0.58, 0.58):
            L.box((0.1, 0.24, 0.3), (x, 0.02, 0.0), swatch=W_)  # ears
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
