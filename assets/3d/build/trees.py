"""Trees and brush for Mile 14's woods (Nova, 2026-11-11: "mainly a highway but i also want some
wooded areas in it"; "use blender to make some trees"). The corridor's forest is conifer with
some broadleaf (the State Forest and High Ridge on the Plot's map, docs/lore/world_map.md), seen
at night, so the greens are the palette's dark ones (foliage, foliage_d, olive_d) on a dark bark.

Registered into build_assets.py's ASSETS table by `register(ba)` (like props.py). Build with:

    blender --background --python assets/3d/build/build_assets.py -- --only env_pine_tall env_pine_small env_tree_leafy env_shrub

Built to the 5-stud character (docs/STYLES.md §6): pivot at the bottom centre, the trunk on
z = 0. In game only the trunk collides (MeshAssets `colliders`), so a soldier walks under the
boughs; the shrub collides with nothing but stops sight (MeshAssets `hides`): cover to crouch in.
Each piece's shape is jittered from a fixed seed, so a rebuild gives the same mesh.
"""

import math
import random

BARK = "rust_d"
NEEDLES = ("foliage_d", "olive_d")  # alternating tiers: a pine reads as layers in the dark
LEAVES = ("foliage", "foliage_d")


def cone(b, radius, height, z, swatch, tilt=0.0, turn=0.0, segs=8):
    """A pine tier: a cone (its base `radius` at `z`) closing to a point `height` above."""
    b.cyl(radius, height, (0, 0, z + height / 2), segs=segs, r2=0.08, rot=(tilt, 0, turn), swatch=swatch)


def pine(b, tiers, trunk_h, trunk_r, seed):
    """A conifer: a tapered trunk and `tiers` [(radius, height, base z), ...] of cones."""
    rng = random.Random(seed)
    b.cyl(trunk_r, trunk_h, (0, 0, trunk_h / 2), segs=6, r2=trunk_r * 0.45, swatch=BARK)
    b.box((trunk_r * 3, trunk_r * 3, 0.4), (0, 0, 0.2), rot=(0, 0, rng.uniform(0, 90)), swatch="dark_d")  # root flare
    for k, (radius, height, z) in enumerate(tiers):
        cone(
            b,
            radius * rng.uniform(0.92, 1.06),
            height,
            z,
            NEEDLES[k % 2],
            tilt=rng.uniform(-4, 4),
            turn=rng.uniform(0, 45),
        )


def env_pine_tall(b):
    # 24 tall (about five characters): the woods' main tree. Five tiers, the lowest boughs at
    # 4.5 so a soldier passes under them.
    pine(
        b,
        [(5.6, 7.0, 4.5), (4.7, 6.2, 8.5), (3.8, 5.4, 12.0), (2.8, 4.6, 15.2), (1.8, 4.6, 18.2)],
        trunk_h=12.0,
        trunk_r=0.6,
        seed=14,
    )
    cone(b, 0.6, 1.8, 22.4, "foliage_d", segs=6)  # leader


def env_pine_small(b):
    # 13 tall: young pines between the tall ones and along the tree line.
    pine(b, [(3.4, 5.0, 2.6), (2.6, 4.2, 5.4), (1.7, 3.8, 8.0)], trunk_h=6.0, trunk_r=0.38, seed=7)
    cone(b, 0.4, 1.4, 11.6, "foliage_d", segs=6)


def env_tree_leafy(b):
    # 15 tall broadleaf: a forked trunk under a lumpy crown of five blobs.
    rng = random.Random(23)
    b.cyl(0.62, 8.0, (0, 0, 4.0), segs=7, r2=0.36, swatch=BARK)
    b.box((1.9, 1.9, 0.4), (0, 0, 0.2), rot=(0, 0, 30), swatch="dark_d")
    for phi, psi, ln in ((32, 40, 4.2), (36, 200, 3.8), (24, 300, 3.4)):
        p, s = math.radians(phi), math.radians(psi)
        d = (math.sin(p) * math.sin(s), -math.sin(p) * math.cos(s), math.cos(p))
        c = (d[0] * ln / 2, d[1] * ln / 2, 6.8 + d[2] * ln / 2)
        b.cyl(0.26, ln, c, segs=5, r2=0.12, rot=(phi, 0, psi), swatch=BARK)
    for k, (x, y, z, r) in enumerate(
        ((0, 0, 11.6, 3.4), (2.6, 0.8, 10.2, 2.7), (-2.4, 1.4, 10.4, 2.6), (0.6, -2.6, 10.0, 2.6), (-0.8, 0.4, 13.4, 2.4))
    ):
        b.ico(r * rng.uniform(0.94, 1.06), (x, y, z), subdiv=1, swatch=LEAVES[k % 2])


def env_shrub(b):
    # 3.5 tall, about 6 across: brush to crouch in (sight stops at it, bodies pass through).
    rng = random.Random(31)
    for k, (x, y, r) in enumerate(((0, 0, 1.8), (1.6, 0.6, 1.4), (-1.5, 0.4, 1.5), (0.3, -1.5, 1.3), (-0.6, 1.5, 1.2))):
        b.ico(r * rng.uniform(0.92, 1.08), (x, y, r * 0.85), subdiv=1, swatch=("foliage", "foliage_d")[k % 2])


TREES = {
    "env_pine_tall": env_pine_tall,
    "env_pine_small": env_pine_small,
    "env_tree_leafy": env_tree_leafy,
    "env_shrub": env_shrub,
}


def register(ba):
    """Adds the trees and the shrub to build_assets' ASSETS table (the Environment collection)."""
    for name, fn in TREES.items():
        ba.ASSETS[name] = (fn, "Environment", "bottom")
