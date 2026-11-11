"""Infected v2: the remade Walker, Runner, Brute and Hocker. What the game loads since
2026-11-11 (owner: "I like the new zombies").

Rebuilt for the read at game distance (docs/STYLES.md §7 "Infected v2"). The first bodies in
build_assets.py (`INFECTED_TYPES`) stay built and uploaded as the fallback set
(`Config.Enemies.BodyVersion = 1`). The Warden is not touched.

What changed, on every form: the infection is a few big shapes, not many small ones. One
large open wound per body with pale bone in it, growths that break the outline (chunky pus
domes), a readable face (dark sockets, milky eyes, an open jaw), and one bad side so no body
is a mirror of itself. Same rules as before: blocky R15 limb sets in the stock limb boxes,
palette swatches only, no green skin (strain green only inside the Hocker's throat and sac),
costumes from docs/CHARACTERS.md, under the caps in `BODY_TRI_CAP`.

Meshes: `inf_v2_<form>_<limb>` (`_l` / `_r` where the sides differ, `SIDED`), collection
`Infected`, plus the assembled `ref_inf_v2_<form>` figures. `register(ba)` adds them to
build_assets' ASSETS table on every build. Every `inf_v2_*` FBX is written mirrored in X
(`build_assets.MIRROR_X_PREFIXES`): Roblox mirrors an imported mesh, and each body has one bad
side. Previews and the printed `offset` stay in design coordinates (+X is the body's right).

The side-by-side previews (current next to v2, front and back; no FBX, no .blend):

    blender --background --python assets/3d/build/infected_v2.py

writes `previews/infected_v2_<form>.png` and `previews/lineup_infected_v2.png`.
In live Blender: `import infected_v2; infected_v2.live()` stands the same figures in the scene.

To change a form: edit its builder, rebuild, upload the changed limbs, update the ids, sizes
and offsets in `MeshAssets` and `ASSET_IDS.md`.
"""

import math
import os
import sys

BA = None  # the build_assets module, bound by register() / _bind()

# Forms whose limbs differ by side export `_l` / `_r` meshes (MeshAssets.limbMeshName finds them).
ARMS = ("upper_arm", "lower_arm", "hand")
LEGS = ("upper_leg", "lower_leg", "foot")
SIDED = {
    "walker": ARMS + LEGS,  # the right side is the bad side: bare arm, bare leg
    "runner": (),
    "brute": ARMS,
    "hocker": (),
}
# The Hocker's throat sac is an attached Part in game (EnemyService SAC_OFFSET / SAC_SIZE);
# the previews mount it on both the current and the v2 figure.
SAC_AT = (0.0, -0.5, 0.95)  # from the upper torso centre
SAC_R = 0.45


# ------------------------------------------------------------------ shared shapes
def _unit(n):
    d = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1.0
    return (n[0] / d, n[1] / d, n[2] / d)


def growth(L, r, loc, n=(0, -1, 0), swatch="pus", head="pus_l"):
    """A chunky pustule: a 20-face dome with a paler head pushed out along `n`. Bigger and
    cheaper than `Limb.boil`, so a few of them can break the outline."""
    L.ico(r, loc, swatch=swatch, subdiv=0)
    if head:
        n = _unit(n)
        k = r * 0.72
        L.ico(r * 0.42, (loc[0] + n[0] * k, loc[1] + n[1] * k, loc[2] + n[2] * k), swatch=head, subdiv=0)


def knob(L, r, loc, swatch):
    """A bare joint knob (elbow, knee, shoulder) on the v2 limbs."""
    L.ico(r, loc, swatch=swatch, subdiv=0)


def gash(L, w, h, loc, face="front", ribs=0, bone="rebuilt_l"):
    """An open wound on one face of a limb: an inflamed rim, a raw core, a dark slit, and
    `ribs` pale bone bars across it. The big red shape each v2 body is read by."""
    size, n = L._flat(w, h, 0.08, face)
    L.box(size, loc, swatch="flesh_d")

    def out(k):
        return (loc[0] + n[0] * k, loc[1] + n[1] * k, loc[2] + n[2] * k)

    core, _ = L._flat(w * 0.74, h * 0.8, 0.08, face)
    L.box(core, out(0.035), swatch="wound")
    slit, _ = L._flat(w * 0.3, h * 0.56, 0.08, face)
    L.box(slit, out(0.07), swatch="wound_d")
    if ribs and not n[2]:
        bar, _ = L._flat(w * 0.86, 0.08, 0.08, face)
        for i in range(ribs):
            z = loc[2] + h * 0.8 * ((i + 0.5) / ribs - 0.5)
            p = out(0.1)
            L.box(bar, (p[0], p[1], z), swatch=bone)


def sockets(L, z, y, dx=0.26, rim="bruise_d", w=0.3, h=0.24, eye=(0.16, 0.1)):
    """Sunken eye sockets with a small milky eye in each (never green)."""
    for x in (-dx, dx):
        L.box((w, 0.08, h), (x, y, z), swatch=rim)
        L.box((eye[0], 0.08, eye[1]), (x, y - 0.035, z), swatch="pus_l")


# ------------------------------------------------------------------ Walker
# The civilian from the pens, coming apart on one side. Left side: still a person (tan jacket,
# sleeve, the screening band, trousers, a shoe). Right side (+X, the dropped shoulder): the
# jacket and trouser leg torn away, bare pallor skin, the chest open over re-set ribs, a clump
# of pustules on the shoulder, a swollen arm hanging lower, a bare foot. Head down, tilted to
# the bad side, the jaw hanging open.
WALKER_DROP = 0.26  # the right shoulder hangs this much lower
WALKER_REACH = 0.2  # the right forearm is longer by this
WALKER_TROUSERS = "concrete_d"


def walker_limb(L, limb, side=None):
    W, D, H = L.R15_LIMB[limb]
    skin = "pallor_l" if limb in ("head", "upper_torso") else "pallor"  # corpse-pale where the wounds are
    tr = WALKER_TROUSERS
    bad = side == "r"
    if limb == "head":
        L.box((W, D, 0.84), (0, 0, 0.17), swatch=skin)  # cranium and upper face
        L.box((0.74, 0.7, 0.44), (0, 0.16, -0.4), swatch="pallor_d")  # throat behind the jaw
        L.box((0.8, 0.5, 0.3), (0, -0.32, -0.36), swatch="dark_d")  # the open mouth
        L.box((0.62, 0.08, 0.1), (0, -0.56, -0.28), swatch="white_d")  # upper teeth
        L.box((0.92, 0.86, 0.2), (0.08, -0.2, -0.62), swatch="pallor", rot=(14, 0, -6))  # jaw hanging, slewed
        L.box((1.22, 0.56, 0.8), (0, 0.34, 0.26), swatch="dark")  # hair: the back of the head
        L.box((0.62, 0.74, 0.14), (-0.3, -0.2, 0.63), swatch="dark")  # what is left on top
        L.box((1.02, 0.12, 0.12), (0, -0.57, 0.36), swatch="pallor_d")  # brow
        sockets(L, z=0.2, y=-0.585)
        L.box((0.16, 0.14, 0.26), (0, -0.62, 0.04), swatch=skin)  # nose
        gash(L, 0.42, 0.46, (0.37, -0.575, -0.02))  # the cheek open to the jaw...
        L.lesion(0.62, 0.46, (0.575, -0.22, -0.02), face="right")  # ...and round the side of the head
        L.lesion(0.42, 0.42, (0.3, -0.1, 0.59), face="top")  # bare scalp, a lesion
        growth(L, 0.22, (0.52, -0.3, -0.44), n=(0.6, -0.6, -0.3))  # pustules under the jaw
        growth(L, 0.15, (0.56, 0.1, -0.4), n=(1, 0, -0.2))
        L.blotch(0.5, 0.34, (-0.585, -0.1, -0.02), face="left", swatch="bruise")
        L.box((0.1, 0.1, 0.42), (-0.34, -0.58, -0.02), swatch="rebuilt")  # the seam that closed too well
        L.b.rotate_all((16, 9, 0), cent=(0, 0, BA.R15_NECK_DOWN))  # down, and over to the bad side
        L.b.shift_all((0.04, -0.16, -0.08))
    elif limb == "upper_torso":
        L.box((1.0, D, H), (-0.47, 0, 0), swatch="tan")  # the jacket: left half only
        L.box((0.26, 0.1, 1.3), (-0.5, -0.53, -0.15), swatch="tan_d")  # its lapel
        L.box((0.56, 0.1, 1.4), (-0.12, -0.5, -0.1), swatch="white_d")  # shirt
        L.box((0.4, 0.06, 0.5), (-0.1, -0.54, 0.34), swatch="pus_d")  # stained under the jaw
        for z, w in ((0.42, 0.2), (-0.2, 0.32)):  # the torn edge, ragged
            L.box((w, D + 0.06, 0.34), (0.1 + w / 2, 0, z), swatch="tan_d")
        # the bad side: bare, dropped, open
        L.box((0.94, 0.96, 1.42), (0.5, 0, -0.14), swatch=skin)
        L.wedge((0.94, 0.96, 0.3), (0.5, 0, 0.72), swatch=skin)  # the slope down to the dropped shoulder
        gash(L, 0.7, 1.0, (0.58, -0.49, -0.04), ribs=3)  # the chest open over the re-set ribs
        L.blotch(0.5, 0.9, (0.975, -0.05, -0.1), face="right", swatch="bruise")
        L.lesion(0.5, 0.56, (0.52, 0.49, 0.0), face="back")
        L.box((0.6, 0.84, 0.2), (0.62, 0.02, 0.6), swatch="flesh")  # swollen under the growths
        growth(L, 0.36, (0.76, -0.14, 0.76), n=(0.3, -0.5, 0.8))  # the clump on the shoulder
        growth(L, 0.27, (0.44, 0.24, 0.9), n=(-0.1, 0.4, 0.9))
        growth(L, 0.22, (0.9, 0.3, 0.6), n=(0.7, 0.5, 0.5))
        L.box((2.0, 1.08, 0.3), (0, 0, -0.7), swatch="foliage")  # the pens blanket, knotted at the waist
        L.box((1.9, 0.2, 0.5), (0, 0.5, -0.6), swatch="foliage_d")
    elif limb == "lower_torso":
        BA.walker_limb(L, limb)  # trousers, the wrap, the blanket to mid-thigh at the back
    elif limb == "upper_arm":
        if not bad:
            BA.walker_limb(L, limb, "l")  # the sleeve
            return
        d = WALKER_DROP
        L.oct(0.5, 0.16, (0, 0, 0.28 - d), swatch="tan_d")  # what is left of the sleeve
        knob(L, 0.46, (0, 0, 0.1 - d), skin)
        L.oct(0.38, 0.74, (0, 0, -0.25), swatch=skin, r_top=0.44)
        L.lesion(0.4, 0.46, (0.36, 0.0, -0.22), face="right")
        growth(L, 0.17, (0.3, -0.22, 0.16 - d), n=(0.7, -0.5, 0.5))
    elif limb == "lower_arm":
        if not bad:
            BA.walker_limb(L, limb)  # the screening band
            return
        r = WALKER_REACH
        knob(L, 0.44, (0, 0, 0.14), skin)
        L.oct(0.4, 0.4, (0, 0, 0.0), swatch=skin, r_top=0.42)
        L.oct(0.48, 0.5 + r, (0, 0, -0.44 - r / 2), swatch="flesh", r_top=0.4)  # swelling toward the hand
        gash(L, 0.34, 0.6, (0, -0.41, -0.4 - r / 2))
        L.box((0.1, 0.08, 0.5), (0, -0.5, -0.4 - r / 2), swatch="rebuilt_l")  # the bone in it
    elif limb == "hand":
        if not bad:
            BA.walker_limb(L, limb)
            return
        L.box((1.06, 1.03, 0.42), (0, 0, -0.04), swatch="flesh")  # swollen past the box
        L.box((0.98, 0.46, 0.44), (0, -0.3, -0.2), swatch="flesh")  # fingers curled under
        for x in (-0.16, 0.16):
            L.box((0.05, 0.48, 0.46), (x, -0.3, -0.2), swatch="flesh_d")
        L.blotch(0.6, 0.5, (0.1, 0.1, 0.17), face="top", swatch="bruise")
        L.b.shift_all((0, 0, -WALKER_REACH))
    elif limb == "upper_leg":
        if not bad:
            BA.walker_limb(L, limb)
            return
        L.hip_inset(0.48, tr)
        L.oct(0.5, 0.56, (0, 0, 0.17), swatch=tr, r_top=0.48)  # the trouser leg, torn off at the thigh
        L.oct(0.4, 0.62, (0, 0, -0.38), swatch=skin, r_top=0.44)
        L.lesion(0.4, 0.44, (-0.04, -0.4, -0.3))
        knob(L, 0.24, (0.1, -0.36, -0.56), "rebuilt")  # knee knot
    elif limb == "lower_leg":
        if not bad:
            BA.walker_limb(L, limb)
            return
        knob(L, 0.44, (0, 0, 0.23), skin)
        L.oct(0.34, 1.06, (0, 0, -0.12), swatch=skin, r_top=0.42)  # bare to the ankle
        L.blotch(0.4, 0.5, (0, -0.36, -0.1), swatch="bruise")
        L.lesion(0.34, 0.36, (0.36, 0.02, -0.3), face="right")
    elif limb == "foot":
        if not bad:
            BA.walker_limb(L, limb)
            return
        L.box((0.84, 0.98, 0.24), (0, 0, 0.0), swatch="pallor_d")  # the shoe is gone
        L.box((0.86, 0.22, 0.16), (0, -0.42, -0.03), swatch="flesh")  # toes


# ------------------------------------------------------------------ Runner
# The garrison soldier, flayed. v1 read as one dark red mass; v2 is three values: `flesh`
# muscle where the light lands, `wound` where it is deep, and pale bone you can count from
# across the yard: a rib cage over a starved waist, a bare jaw hanging open, shoulder blades
# and a stepped spine. The black T-shirt is down to a collar and one strip. Same lean, same
# long arms; the fingers end in bone.
RUNNER_LEAN = 20
RUNNER_ARM_FWD = -0.45
RUNNER_REACH = 0.55


def runner_limb(L, limb, side=None):
    W, D, H = L.R15_LIMB[limb]
    skin, lit, bone = "wound", "flesh", "rebuilt_l"
    if limb == "head":
        L.box((W, D, 0.78), (0, 0, 0.2), swatch=skin)  # cranium, no skin left
        L.blotch(0.7, 0.7, (0.1, 0.06, 0.585), face="top", swatch="wound_d")  # torn scalp
        L.box((0.8, 0.6, 0.5), (0, 0.22, -0.4), swatch=skin)  # neck
        L.box((1.04, 0.16, 0.18), (0, -0.57, 0.36), swatch=bone)  # brow, bare bone
        sockets(L, z=0.16, y=-0.585, rim="wound_d")
        L.box((0.24, 0.1, 0.24), (0, -0.6, -0.0), swatch="rebuilt")  # the nose gone to bone
        L.box((0.1, 0.08, 0.12), (0, -0.63, -0.02), swatch="dark_d")
        for x in (-0.4, 0.4):
            L.box((0.28, 0.12, 0.14), (x, -0.58, -0.02), swatch=bone)  # cheekbones
            L.box((0.1, 0.12, 0.5), (x * 1.2, -0.5, -0.36), swatch=bone)  # the tendons holding the jaw on
        L.box((0.76, 0.1, 0.12), (0, -0.57, -0.19), swatch="white")  # upper teeth
        L.box((0.8, 0.6, 0.36), (0, -0.29, -0.42), swatch="dark_d")  # the mouth
        L.box((0.94, 0.9, 0.18), (0, -0.2, -0.7), swatch="rebuilt", rot=(18, 0, 0))  # bare jaw, open
        L.box((0.72, 0.1, 0.12), (0, -0.6, -0.7), swatch="white", rot=(18, 0, 0))  # lower teeth
        L.box((0.34, 0.12, 0.4), (0, 0.5, -0.3), swatch=bone)  # tendon at the nape
        L.blotch(0.5, 0.5, (0.585, 0.1, 0.14), face="right", swatch=lit)
        L.blotch(0.5, 0.5, (-0.585, 0.1, 0.14), face="left", swatch="wound_d")
        L.b.rotate_all((-10, 0, 0))  # chin up: the hunched head still looks ahead
        L.b.shift_all((0, -0.55, -0.32))  # jutting off the leaning chest, sunk between the shoulders
    elif limb == "upper_torso":
        L.box((W, D, 0.96), (0, 0, 0.37), swatch=skin)  # chest
        L.box((1.36, 0.78, 0.8), (0, 0.02, -0.45), swatch="wound_d")  # starved waist
        for x in (-0.47, 0.47):
            L.box((0.8, 0.14, 0.5), (x, -0.5, 0.52), swatch=lit)  # pecs catching the light
        L.box((0.2, 0.12, 1.0), (0, -0.54, 0.2), swatch=bone)  # sternum
        for i, z in enumerate((0.16, -0.06, -0.28, -0.5, -0.72)):  # the rib cage, counted
            w = 0.74 - 0.06 * i
            for s in (-1, 1):
                L.box((w, 0.12, 0.11), (s * (0.08 + w / 2), -0.47 + 0.03 * i, z), swatch=bone, rot=(0, s * 10, 0))
                if i < 4:
                    L.box((0.12, 0.74, 0.11), (s * (0.74 - 0.05 * i), 0.0, z - 0.04), swatch=bone)  # round the side
        L.box((0.84, 0.1, 0.56), (-0.5, -0.58, 0.5), swatch="gun_d")  # all that is left of the T-shirt: a rag
        L.box((0.06, 0.1, 0.56), (-0.05, -0.59, 0.5), swatch="red")  # fresh at its torn edge
        L.box((0.5, 0.08, 0.9), (-0.52, 0.52, 0.3), swatch="gun_d")  # and one strip down the back
        L.box((0.06, 0.1, 0.9), (-0.25, 0.52, 0.3), swatch="red")  # fresh at the tear
        for s in (-1, 1):
            L.box((0.46, 0.84, 0.62), (s * 0.76, 0.04, 0.98), swatch=lit)  # shoulders up to the jaw: no neck
            L.ico(0.22, (s * 0.82, 0.06, 1.3), swatch=bone, subdiv=0)  # the bone through the top
            L.box((0.3, 0.3, 0.12), (s * 0.6, -0.3, 1.32), swatch="dark")  # carrier strap stubs
        L.box((0.5, 0.14, 0.62), (0.5, 0.52, 0.38), swatch="rebuilt", rot=(0, 12, 0))  # shoulder blade
        for i, z in enumerate((0.72, 0.38, 0.04, -0.3, -0.64)):  # the spine: five stepped blocks
            d = 0.5 - 0.05 * i
            L.box((0.4 - 0.03 * i, d, 0.26), (0, 0.44 + d / 2, z), swatch=bone)
        L.b.rotate_all((RUNNER_LEAN, 0, 0), cent=(0, 0, BA.R15_WAIST_DOWN))  # the lean, from the hips
        L.box((0.04, 0.04, 0.5), (0, -1.08, 0.3), swatch="dark")  # tag cord, hanging plumb
        L.box((0.18, 0.05, 0.26), (0.04, -1.1, 0.06), swatch="gun_l")  # dog tags
        L.box((0.18, 0.05, 0.26), (-0.06, -1.12, 0.0), swatch="gun_l")
    elif limb == "lower_torso":
        L.box((W, D, H), swatch="olive")
        L.box((W + 0.04, D + 0.04, 0.14), (0, 0, 0.1), swatch="dark")  # belt
        L.box((0.26, 0.1, 0.16), (0, -0.53, 0.1), swatch="gun")  # buckle
        L.box((0.5, 0.14, 0.22), (0.62, -0.52, 0.2), swatch=bone)  # hip bone over the belt
    elif limb == "upper_arm":
        L.cap(0.46, (0, 0, 0.14), swatch=lit)  # bare shoulder
        L.oct(0.40, 0.36, (0, 0, -0.04), swatch=lit, r_top=0.46)  # banded muscle: lit above...
        L.oct(0.44, 0.07, (0, 0, -0.22), swatch=bone)
        L.oct(0.34, 0.34, (0, 0, -0.42), swatch=skin, r_top=0.40)  # ...deep below
        L.oct(0.37, 0.07, (0, 0, -0.56), swatch=bone)
        L.box((0.1, 0.16, 0.66), (0, 0.36, -0.28), swatch=bone)  # tendon down the back
        L.box((0.08, 0.16, 0.6), (0.1, -0.38, -0.3), swatch="pus_d")  # weep down the front
        L.b.shift_all((0, RUNNER_ARM_FWD, 0))
    elif limb == "lower_arm":
        r = RUNNER_REACH
        L.cap(0.4, (0, 0, 0.16), swatch=bone)  # elbow knob
        L.oct(0.3, 0.72 + r, (0, 0, -0.2 - r / 2), swatch=skin, r_top=0.40)  # long, hard taper
        L.box((0.16, 0.14, 0.8 + r), (0.0, 0.28, -0.2 - r / 2), swatch=bone)  # the forearm bone, bare down the back
        L.box((0.08, 0.14, 0.6 + r), (-0.08, -0.3, -0.22 - r / 2), swatch="pus_d")
        L.oct(0.36, 0.1, (0, 0, -0.52 - r), swatch="rebuilt")  # wrist
        L.b.shift_all((0, RUNNER_ARM_FWD, 0))
    elif limb == "hand":
        L.box((0.86, 0.6, 0.36), (0, 0.04, 0), swatch=skin)  # palm
        for x in (-0.33, -0.11, 0.11, 0.33):
            L.box((0.16, 0.2, 0.4), (x, -0.14, -0.36), swatch=skin)  # long fingers hanging open
            L.box((0.13, 0.17, 0.3), (x, -0.14, -0.68), swatch=bone)  # ending in bone
        L.box((0.9, 0.24, 0.1), (0, -0.14, -0.18), swatch=bone)  # knuckles
        L.b.shift_all((0, RUNNER_ARM_FWD, -RUNNER_REACH - 0.05))
    elif limb == "upper_leg":
        L.hip_inset(0.5, "olive")
        L.oct(0.46, 0.6, (0, 0, 0.15), swatch="olive", r_top=0.5)  # trouser to the torn edge
        L.oct(0.5, 0.08, (0, 0, -0.16), swatch="olive_d")
        L.oct(0.38, 0.5, (0, 0, -0.43), swatch=lit, r_top=0.44)  # blown knee
        L.ico(0.24, (0, -0.4, -0.5), swatch=bone)  # knee knob
        L.box((0.08, 0.16, 0.4), (0.12, -0.36, -0.36), swatch="pus_d")
    elif limb == "lower_leg":
        L.cap(0.4, (0, 0, 0.25), swatch=bone)
        L.oct(0.34, 0.5, (0, 0, 0.0), swatch=skin, r_top=0.40)  # calf
        L.box((0.14, 0.14, 0.5), (0, -0.33, 0.0), swatch=bone)  # shin bone
        L.box((0.92, 0.92, 0.62), (0, 0, -0.34), swatch="dark")  # boot shaft
        L.box((0.96, 0.96, 0.08), (0, 0, -0.08), swatch="dark_l")  # boot collar
    elif limb == "foot":
        BA.runner_limb(L, limb)  # boot, the lace trailing


# ------------------------------------------------------------------ Brute
# The soldier rebuilt around his breaks. v1 was a dark block under two crates. v2: the bone
# shelf is one yoke, two tilted slabs with horn-like spurs rising past the crown on the left,
# broken short on the right where a tumour of pustules took the shoulder. The chest is split
# top to bottom, ribs standing in it like teeth. The skin steps up one tone on the chest
# (`bruise_l`) so the body is not one dark mass. The right forearm and fist are a bone club;
# the left is the swollen arm it had. Legs and hips stay as built.
BRUTE_WIDE = 2.6
BRUTE_DEEP = 1.2
BRUTE_ARM_OUT = 0.42
BRUTE_REACH = 1.0
BRUTE_SINK = 0.45


def brute_limb(L, limb, side=None):
    W, D, H = L.R15_LIMB[limb]
    skin = "bruise"
    sx = 1 if side == "r" else -1  # the arm's outer side
    club = side == "r"
    TW, TD = BRUTE_WIDE, BRUTE_DEEP
    if limb == "head":
        L.box((W, D, 0.5), (0, 0.04, -0.3), swatch=skin)  # neck and back of the jaw
        L.box((1.3, 0.9, 0.44), (0, -0.2, -0.4), swatch="bruise_l")  # the jaw: wider than the skull
        L.box((0.9, 0.1, 0.12), (0, -0.66, -0.22), swatch="white_d")  # lower teeth, underbite
        L.box((W, D, 0.72), (0, 0, 0.23), swatch="rebuilt")  # plated skull
        for x in (-0.37, 0.37):
            L.box((0.5, 1.24, 0.44), (x, 0, 0.42), swatch="olive_d")  # the helmet, split in two
        L.box((0.22, 1.2, 0.56), (0, 0, 0.42), swatch="rebuilt_l")  # bone crest between the halves
        L.box((1.2, 0.26, 0.22), (0, -0.56, 0.12), swatch="rebuilt_d")  # brow overhang
        sockets(L, z=-0.04, y=-0.585, dx=0.27, rim="dark_d", w=0.36, h=0.2, eye=(0.22, 0.12))
        L.box((1.34, 0.08, 0.1), (0, -0.3, -0.56), swatch="dark")  # chin strap
        gash(L, 0.5, 0.36, (0.655, -0.2, -0.4), face="right")
        L.b.shift_all((0, -0.08, -BRUTE_SINK))
    elif limb == "upper_torso":
        L.box((TW, TD, 0.8), (0, 0, -0.45), swatch=skin)  # belly
        L.box((TW + 0.1, TD + 0.06, 0.94), (0, 0, 0.4), swatch="bruise_l")  # chest, a tone up
        # the yoke: left side whole (two tilted slabs and two spurs past the crown)
        L.box((1.0, TD + 0.16, 0.56), (-1.0, 0, 1.1), swatch="rebuilt")
        L.box((0.8, 1.06, 0.6), (-1.12, 0.04, 1.6), swatch="rebuilt_l", rot=(0, 14, 0))
        L.cyl(0.28, 0.6, (-1.34, -0.2, 2.1), swatch="rebuilt_l", rot=(0, -16, 0), segs=4, r2=0.1)  # broken ends
        L.cyl(0.22, 0.4, (-0.98, 0.3, 2.0), swatch="rebuilt", rot=(0, -8, 0), segs=4, r2=0.1)
        # right side: the slab broken short, a tumour grown over the break
        L.box((0.9, TD + 0.16, 0.5), (1.0, 0, 1.06), swatch="rebuilt")
        L.box((0.5, 0.7, 0.3), (0.82, 0.2, 1.42), swatch="rebuilt_d", rot=(0, -10, 0))  # the stump of it
        L.box((0.9, 1.1, 0.36), (1.1, -0.06, 1.36), swatch="flesh")
        growth(L, 0.44, (1.2, -0.26, 1.56), n=(0.3, -0.5, 0.8))
        growth(L, 0.34, (0.86, 0.3, 1.66), n=(-0.2, 0.4, 0.9))
        growth(L, 0.3, (1.42, 0.3, 1.36), n=(0.8, 0.4, 0.4))
        growth(L, 0.24, (1.3, -0.62, 1.2), n=(0.4, -0.9, 0.1))
        growth(L, 0.3, (1.0, 0.66, 1.2), n=(0.2, 0.9, 0.3))  # and down the back
        L.box((1.3, 0.3, 0.7), (0, 0.62, 1.16), swatch="rebuilt")  # the trench's back wall, behind the head
        # the chest split top to bottom, ribs standing in it
        L.box((1.16, 0.1, 1.6), (0.2, -0.62, -0.0), swatch="flesh_d")
        L.box((0.9, 0.1, 1.46), (0.2, -0.66, -0.0), swatch="wound")
        L.box((0.34, 0.1, 1.26), (0.2, -0.7, -0.0), swatch="wound_d")
        for z in (0.52, 0.18, -0.16, -0.5):
            for s in (-1, 1):
                L.box((0.46, 0.18, 0.16), (0.2 + s * 0.48, -0.72, z), swatch="rebuilt_l", rot=(0, s * 18, 0))
        L.box((0.8, 0.18, 1.2), (-0.86, -0.66, -0.05), swatch="olive_d")  # the carrier hangs open
        L.box((0.06, 0.04, 0.9), (-0.8, -0.77, 0.0), swatch="dark_d")  # cracked plate
        L.box((0.16, 0.36, 1.0), (-1.3, -0.46, 0.1), swatch="dark")  # its strap
        for s in (-1, 1):  # shoulder blades grown out through the back, above the pack
            L.box((0.8, 0.16, 0.5), (s * 0.82, 0.62, 0.56), swatch="rebuilt", rot=(0, s * 14, 0))
        # the assault pack split down the middle, both halves sagging open off the back
        L.box((0.66, 0.4, 1.1), (-0.42, 0.82, -0.05), rot=(0, -9, 0), swatch="olive")
        L.box((0.62, 0.4, 0.96), (0.44, 0.82, -0.16), rot=(0, 12, 0), swatch="olive")
        L.box((0.36, 0.2, 0.9), (0.02, 0.72, -0.1), swatch="dark_d")
        L.box((0.5, 0.34, 0.44), (0.52, 0.88, -0.72), rot=(0, 12, 0), swatch="olive_d")
        L.box((0.14, 0.4, 1.3), (-0.82, 0.52, 0.15), swatch="dark")
    elif limb == "lower_torso":
        BA.brute_limb(L, limb)
    elif limb == "upper_arm":
        L.cap(0.48, (0, 0, 0.16), swatch="olive" if not club else "flesh")  # sleeve stub; the tumour side is bare
        L.oct(0.44, 0.1, (0, 0, -0.02), swatch="olive_d" if not club else "flesh_d")
        L.oct(0.38, 0.6, (0, 0, -0.32), swatch=skin, r_top=0.44)  # thinner than the forearm
        L.blotch(0.3, 0.3, (0.0, -0.38, -0.3), swatch="bruise_d")
        if club:
            growth(L, 0.2, (0.3, -0.2, 0.0), n=(0.7, -0.6, 0.2))
            gash(L, 0.36, 0.36, (0.38, 0.06, -0.36), face="right")
        L.b.shift_all((sx * BRUTE_ARM_OUT, 0, 0))
    elif limb == "lower_arm":
        r = BRUTE_REACH
        L.cap(0.54, (0, 0, 0.02), swatch=skin)
        if club:
            L.oct(0.62, 0.6 + r, (0, 0, -0.26 - r / 2), swatch=skin, r_top=0.54)  # swelling to the fist
            L.box((0.7, 0.5, 1.2), (0.16, 0.34, -0.6), swatch="rebuilt")  # bone grown down the back of it
            L.box((0.74, 0.14, 0.14), (0.16, 0.6, -0.2), swatch="rebuilt_l")
            L.box((0.74, 0.14, 0.14), (0.16, 0.6, -0.9), swatch="rebuilt_l")
            for z in (0.1, -0.4, -0.9):
                L.cyl(0.2, 0.5, (0.66, 0.2, z), swatch="rebuilt_l", rot=(0, 110, 0), segs=4, r2=0.03)  # spurs
            gash(L, 0.5, 0.8, (-0.04, -0.56, -0.7))
        else:
            L.oct(0.5, 0.6 + r, (0, 0, -0.26 - r / 2), swatch=skin, r_top=0.54)
            for z in (0.3, -0.1, -0.5, -0.9):
                L.box((0.24, 0.2, 0.34), (sx * 0.5, 0.1, z), rot=(0, sx * 30, 0), swatch="rebuilt")  # ulna spurs
            L.blotch(0.42, 0.7, (0, -0.48, -0.4), swatch="bruise_d")
            growth(L, 0.16, (0.3, -0.4, -0.2), n=(0.4, -0.9, 0))
        L.b.shift_all((sx * BRUTE_ARM_OUT, 0, 0))
    elif limb == "hand":
        if club:
            L.box((1.3, 1.06, 0.7), (0, 0.06, -0.1), swatch="bruise_d")  # the fist
            L.box((1.36, 0.5, 0.46), (0, -0.4, -0.06), swatch="rebuilt_l")  # cased in bone across the knuckles
            L.box((1.1, 0.7, 0.12), (0, -0.2, -0.5), swatch="rebuilt")  # worn flat underneath
            for x in (-0.34, 0.0, 0.34):
                L.box((0.06, 0.52, 0.5), (x, -0.42, -0.06), swatch="rebuilt_d")
        else:
            L.box((W, 0.74, 0.44), (0, 0.12, 0.0), swatch=skin)
            L.box((0.9, 0.32, 0.24), (0, -0.4, 0.06), swatch="rebuilt_l")  # knuckle plates
            L.box((0.9, 0.5, 0.1), (0, -0.2, -0.26), swatch="rebuilt_l")
            for x in (-0.22, 0.0, 0.22):
                L.box((0.05, 0.4, 0.3), (x, -0.36, -0.06), swatch="dark_d")
        L.b.shift_all((sx * BRUTE_ARM_OUT, 0, -BRUTE_REACH - 0.1))
    else:
        BA.brute_limb(L, limb)  # legs and feet as built


# ------------------------------------------------------------------ Hocker
# The Walker a day further on; the throat is a pump. v1 was a Walker with its head back. v2
# is built round the neck: a swollen fevered collar of big pustules for the sac to sit in,
# the jaw split wide into a V over the open throat, the jacket front soaked to the waist, a
# hump between the shoulders so head, hump and caved chest make an S in profile. Thin arms,
# hooked hands, the Walker's legs with the knees bent.
HOCKER_HEAD_BACK = 26
HOCKER_KNEE = 18


def hocker_limb(L, limb, side=None):
    W, D, H = L.R15_LIMB[limb]
    skin = "pallor_l" if limb == "head" else "pallor"
    if limb == "head":
        L.box((W, D, 0.8), (0, 0, 0.19), swatch=skin)  # upper face
        L.box((1.22, 0.6, 0.84), (0, 0.32, 0.24), swatch="dark")  # lank hair, the back only
        L.box((1.0, 0.7, 0.12), (0, -0.1, 0.62), swatch="pallor_d")  # bare crown
        sockets(L, z=0.42, y=-0.585, rim="wound", h=0.18, eye=(0.2, 0.08))  # eyes rolled up under the brow
        L.box((0.3, 0.12, 0.12), (0, -0.6, 0.27), swatch="rebuilt")  # the nose gone
        L.box((0.9, 0.1, 0.56), (0, -0.57, -0.06), swatch="wound")  # no lips: the mouth is a raw hole...
        L.box((0.66, 0.1, 0.42), (0, -0.6, -0.08), swatch="dark_d")  # ...straight down the throat
        L.box((0.3, 0.1, 0.16), (0, -0.63, -0.2), swatch="strain_d")  # the strain at the bottom of it
        L.box((0.6, 0.1, 0.08), (0, -0.64, 0.13), swatch="rebuilt_l")  # upper teeth
        L.box((0.96, 0.7, 0.3), (0, -0.26, -0.4), swatch="strain_d")  # the open throat
        for s in (-1, 1):  # the jaw split at the chin, the halves spread wide
            L.box((0.4, 0.84, 0.4), (s * 0.5, -0.36, -0.52), rot=(0, s * -14, s * 30), swatch=skin)
            L.box((0.1, 0.5, 0.1), (s * 0.34, -0.5, -0.3), rot=(0, 0, s * 30), swatch="rebuilt_l")  # teeth along it
        L.box((W, 0.6, 0.34), (0, 0.24, -0.4), swatch="flesh")  # fevered under the jaw
        L.blotch(0.6, 0.3, (0.585, -0.06, -0.12), face="right", swatch="flesh_d")
        L.blotch(0.6, 0.3, (-0.585, -0.06, -0.12), face="left", swatch="flesh_d")
        L.b.rotate_all((-HOCKER_HEAD_BACK, 0, 0), cent=(0, 0, -0.4))  # head thrown back
        L.b.shift_all((0, 0.1, 0))
    elif limb == "upper_torso":
        for x in (-0.68, 0.68):
            L.box((0.58, D, H), (x, 0, 0), swatch="tan")  # jacket sides
        L.box((0.8, 0.56, H), (0, 0.22, 0), swatch="pus_d")  # the caved chest, soaked through
        for x in (-0.33, 0.33):
            L.box((0.14, 0.26, H), (x, -0.2, 0), swatch="tan_d")  # the step down into it
            L.box((0.36, 0.1, 1.5), (x * 1.75, -0.53, -0.05), swatch="pus_d")  # the lapels soaked too
        for z in (0.2, -0.08, -0.36):
            L.box((0.56, 0.06, 0.09), (0, -0.09, z), swatch="rebuilt_l")  # ribs through the shirt
        L.box((0.5, 0.06, 0.5), (0.02, -0.09, 0.5), swatch="pus")  # wet under the sac
        # the collar: a fevered swelling with a ring of big pustules, the sac in the gap at the front
        L.box((1.5, 1.04, 0.44), (0, -0.04, 0.9), swatch="flesh")
        L.box((1.2, 0.8, 0.2), (0, 0.0, 1.16), swatch="flesh_d")
        for s in (-1, 1):  # the glands either side of the sac, swollen past the jacket
            L.ico(0.4, (s * 0.72, -0.3, 0.98), swatch="flesh", subdiv=1)
            growth(L, 0.2, (s * 0.9, -0.52, 1.1), n=(s * 0.6, -0.7, 0.4))
        growth(L, 0.26, (-0.78, 0.2, 1.04), n=(-0.9, 0.3, 0.3))
        growth(L, 0.24, (0.76, 0.24, 1.02), n=(0.9, 0.3, 0.3))
        growth(L, 0.22, (-0.3, 0.5, 1.06), n=(-0.3, 0.9, 0.3))
        growth(L, 0.26, (0.3, 0.52, 1.02), n=(0.3, 0.9, 0.3))
        L.box((1.3, 0.14, 0.34), (0, -0.5, 0.36), swatch="white_l")  # the surgical mask, pulled down
        for x in (-0.66, 0.66):
            L.box((0.06, 0.12, 0.4), (x, -0.5, 0.66), swatch="white_d")  # its ties
        L.box((1.5, 0.34, 0.9), (0, 0.6, 0.36), swatch="tan")  # the hump between the shoulders
        L.box((1.1, 0.2, 0.5), (0, 0.8, 0.4), swatch="tan_d")
        L.box((1.9, 0.2, 0.5), (0, 0.5, -0.6), swatch="foliage_d")  # blanket back
        L.box((2.0, 1.08, 0.3), (0, 0, -0.7), swatch="foliage")
    elif limb == "upper_arm":
        L.cap(0.45, (0, 0, 0.15), swatch="tan")
        L.oct(0.36, 0.74, (0, 0, -0.25), swatch="tan", r_top=0.45)
        L.oct(0.41, 0.16, (0, 0, -0.55), swatch="pus_d")  # soaked cuff
    elif limb == "lower_arm":
        L.cap(0.38, (0, 0, 0.16), swatch=skin)
        L.oct(0.3, 0.72, (0, 0, -0.2), swatch=skin, r_top=0.38)  # thin
        L.oct(0.36, 0.2, (0, 0, -0.42), swatch="rebuilt")  # rebuilt wrist
        L.blotch(0.3, 0.36, (0, -0.33, -0.1), swatch="flesh_d")
    elif limb == "hand":
        L.box((0.9, 0.66, H), (0, 0.16, 0), swatch=skin)
        for x in (-0.33, -0.11, 0.11, 0.33):
            L.box((0.16, 0.3, 0.5), (x, -0.4, -0.14), rot=(40, 0, 0), swatch="flesh")  # hooked fingers
        L.box((0.9, 0.12, 0.1), (0, -0.2, 0.12), swatch="rebuilt_l")  # knuckles
    elif limb == "upper_leg":
        BA.walker_limb(L, limb)
        L.b.rotate_all((-HOCKER_KNEE, 0, 0), cent=(0, 0, BA.R15_HIP_UP))  # knee forward
    elif limb == "lower_leg":
        BA.walker_limb(L, limb)
        knee_fwd = 0.921 * math.sin(math.radians(HOCKER_KNEE))  # hip-to-knee 0.921
        shin = math.degrees(math.asin(knee_fwd / 1.009))  # knee-to-ankle 1.009: shin back to the foot
        L.b.rotate_all((shin, 0, 0), cent=(0, 0, BA.R15_ANKLE_DOWN))
    else:
        BA.walker_limb(L, limb)  # hips and the blanket, shoes


FORMS = {"walker": walker_limb, "runner": runner_limb, "brute": brute_limb, "hocker": hocker_limb}


# ------------------------------------------------------------------ registration
def _bind(ba):
    global BA
    BA = ba

    class V2Limb(ba.Limb):
        R15_LIMB = ba.R15_LIMB

    return V2Limb


def _figure(ba, V2Limb, form, b, sac=False):
    """The 15 limbs assembled at the R15 offsets (hip at z=0), for previews only."""
    import bmesh
    from mathutils import Vector

    build, sided = FORMS[form], SIDED[form]
    for limb, (x, y, z) in ba.R15_POSE.items():
        for s in (1,) if x == 0 else (-1, 1):
            sub = ba.Builder()
            build(V2Limb(sub), limb, ("r" if s > 0 else "l") if limb in sided else None)
            bmesh.ops.translate(sub.bm, vec=Vector((s * x, y, z)), verts=list(sub.bm.verts))
            b.merge(sub)
    if sac:
        _sac(ba, b)


def _sac(ba, b):
    x, y, z = ba.R15_POSE["upper_torso"]
    at = (x + SAC_AT[0], y + SAC_AT[1], z + SAC_AT[2])
    b.ico(SAC_R, at, swatch="strain", subdiv=1)
    b.box((0.2, 0.08, 0.16), (at[0] + 0.12, at[1] - SAC_R * 0.94, at[2] + 0.12), swatch="strain_l")


def register(ba):
    """Adds every v2 limb mesh and the four assembled figures to build_assets' ASSETS table."""
    V2Limb = _bind(ba)
    for form, build in FORMS.items():
        for limb in ba.R15_LIMB:
            for side in ("l", "r") if limb in SIDED[form] else (None,):

                def fn(b, build_=build, limb_=limb, side_=side):
                    build_(V2Limb(b), limb_, side_)

                ba.ASSETS[f"inf_v2_{form}_{limb}" + (f"_{side}" if side else "")] = (fn, "Infected", "center")

        def preview(b, form_=form):
            _figure(ba, V2Limb, form_, b, sac=form_ == "hocker")

        ba.ASSETS[f"ref_inf_v2_{form}"] = (preview, "_Reference", "bottom")


# ------------------------------------------------------------------ previews (current next to v2)
def _load_ba():
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    import build_assets

    return build_assets


def _palette_material(ba):
    """The palette as an in-memory image (build_assets' own writes palette.png; this must not)."""
    import bpy

    mat = bpy.data.materials.get("PaletteV2Preview")
    if mat is not None:
        return mat
    size = ba.GRID * ba.CELL
    img = bpy.data.images.new("palette_v2_preview", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, (_, h) in enumerate(ba.PALETTE):
        r, g, bl = ba.hex_rgb(h)
        col, row = i % ba.GRID, i // ba.GRID
        for y in range(ba.CELL):
            py = size - 1 - (row * ba.CELL + y)
            for x in range(ba.CELL):
                p = (py * size + col * ba.CELL + x) * 4
                px[p : p + 4] = [r, g, bl, 1.0]
    img.pixels = px  # (setting the colour space after this would reload the buffer and blank it)
    img.pack()
    mat = ba.build_palette_material(img)
    mat.name = "PaletteV2Preview"
    return mat


def _label(text, loc, size, collection):
    """A text mesh standing on the ground, facing the camera (a mesh, so frame_and_render can
    show or hide it)."""
    import bpy

    curve = bpy.data.curves.new("label", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.extrude = 0.03  # a little depth: flat glyphs lose strokes in the Workbench render
    tmp = bpy.data.objects.new("label_tmp", curve)
    collection.objects.link(tmp)
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(curve)
    uv = mesh.uv_layers.new(name="UVMap")  # painted like everything else: one palette swatch
    for loop in uv.data:
        loop.uv = BA.swatch_uv("white_l")
    mesh.materials.append(_palette_material(BA))
    obj = bpy.data.objects.new("label_" + text.lower().replace(" ", "_"), mesh)
    obj.location = loc
    obj.rotation_euler = (math.pi / 2, 0, 0)
    collection.objects.link(obj)
    return obj


def build_figures(ba, collection_name="InfectedV2"):
    """Builds `cur_<form>` and `v2_<form>` (feet on the ground, at the origin) into one
    collection, replacing what an earlier call left there. Prints each body's triangles."""
    import bpy

    V2Limb = _bind(ba)
    col = ba.get_collection(collection_name)
    for o in list(col.objects):
        me = o.data
        bpy.data.objects.remove(o)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)
    mat = _palette_material(ba)
    figs = {}
    for form in FORMS:
        cur = ba.Builder()
        ba.ASSETS[f"ref_inf_{form}"][0](cur)
        if form == "hocker":
            _sac(ba, cur)
        new = ba.Builder()
        _figure(ba, V2Limb, form, new, sac=form == "hocker")
        figs[form] = (cur.finish(f"cur_{form}", col, mat), new.finish(f"v2_{form}", col, mat))
        sac_tris = 32 if form == "hocker" else 0  # the sac is a Part in game, not a limb mesh
        tris, cap = figs[form][1]["tri_count"] - sac_tris, ba.BODY_TRI_CAP[form]
        print(f"body inf_v2_{form}: {tris} tris (cap {cap}; current {figs[form][0]['tri_count'] - sac_tris}){'  OVER CAP' if tris > cap else ''}")
    return col, figs


def _row(figs, col, forms, gap, pair_gap, backs):
    """Stands current and v2 side by side per form along X (with `backs`, the same pair again
    turned round); returns every object to show."""
    shown, x = [], 0.0
    for form in forms:
        cur, new = figs[form]
        w = max(cur.dimensions.x, new.dimensions.x)
        group = [(cur, 0.0, "CURRENT"), (new, 0.0, "V2")]
        if backs:
            for src, label in ((cur, "CURRENT"), (new, "V2")):
                twin = src.copy()  # same mesh, turned round
                twin.name = src.name + "_back"
                col.objects.link(twin)
                group.append((twin, math.pi, label + " BACK"))
        x0 = x
        for i, (obj, turn, label) in enumerate(group):
            x += w / 2
            obj.location = (x, 0, 0)
            obj.rotation_euler = (0, 0, turn)
            shown.append(obj)
            shown.append(_label(label, (x, -1.6, -0.9), 0.6, col))
            x += w / 2 + (pair_gap if i % 2 == 0 else gap)
        if not backs:
            shown.append(_label(form.upper(), ((x0 + x - gap) / 2, -1.6, -2.0), 0.9, col))
    return shown


def render_previews(ba, scene, cam, col, figs):
    import bpy

    def reset():
        for o in list(col.objects):
            if o.name.startswith("label_") or o.name.endswith("_back"):
                me = o.data
                bpy.data.objects.remove(o)
                if me.users == 0:
                    bpy.data.meshes.remove(me)
        for cur, new in figs.values():
            for o in (cur, new):
                o.location, o.rotation_euler = (0, 0, 0), (0, 0, 0)

    for form in FORMS:
        shown = _row(figs, col, [form], gap=1.4, pair_gap=0.7, backs=True)
        ba.frame_and_render(scene, cam, shown, os.path.join(ba.PREVIEWS, f"infected_v2_{form}.png"), size=(1800, 700), direction=(0.3, -1.0, 0.3))
        reset()
    shown = _row(figs, col, list(FORMS), gap=1.8, pair_gap=0.6, backs=False)
    ba.frame_and_render(scene, cam, shown, os.path.join(ba.PREVIEWS, "lineup_infected_v2.png"), size=(2400, 640), direction=(0.2, -1.0, 0.3))
    reset()


def live():
    """In the open Blender: stand current and v2 figures in the scene (collection InfectedV2),
    one pair per form, to look at. Call again after editing this file (it reloads itself)."""
    import importlib

    return importlib.reload(sys.modules[__name__])._stand(_load_ba())


def _stand(ba):
    col, figs = build_figures(ba)
    _row(figs, col, list(FORMS), gap=1.8, pair_gap=0.6, backs=False)
    return figs


def main():
    ba = _load_ba()
    os.makedirs(ba.PREVIEWS, exist_ok=True)
    scene = ba.reset_scene()
    cam = ba.setup_render(scene)
    cam.data.lens = 110  # a long lens: a row of figures without the wide-angle lean at the ends
    # Workbench's specular sheen turns a dark facet that faces the light grey (an open mouth
    # reads as a pale slab); the game has no such sheen, so these comparisons render without it.
    scene.display.shading.show_specular_highlight = False
    col, figs = build_figures(ba)
    render_previews(ba, scene, cam, col, figs)


if __name__ == "__main__":
    main()
