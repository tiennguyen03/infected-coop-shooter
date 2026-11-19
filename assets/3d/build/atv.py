"""The ATV (docs/PROGRESSION.md > The ATV; VehicleBody `atv`), from the owner's own model.

One file per singular asset (owner, 2026-11-07). The body is not built from primitives: it is
the owner's sculpted model (`assets/3d/atvrbx.obj`, 1.7M triangles, no UVs, kept out of git),
cut and reduced once by `prepare` into a small source mesh that is committed
(`assets/3d/source/atv_body.obj`). The build loads it and paints it by region (`body_swatch`,
to the owner's colour reference), so a paint change never needs the original. The wheel is
built from primitives at the model's measured tyre size (`wheel`): cut from the model it was
an open shell. Budget: owner, 2026-11-17, ~12k triangles for the body and four wheels, over the
5,000 vehicle cap (docs/STYLES.md section 6).

Frame (Roblox axes, as VehicleBody): origin at the chassis centre, forward -Z, up +Y; written
to Blender as (x, z, y) like every other asset (lantern.py). The body is placed so that the
wheel centres sit WHEEL_Y under the chassis centre at rest, where VehiclePhysics' springs
hold them. The wheel is built about its hub as a right-side wheel, the outer face at +X;
VehicleBody turns it half round for the left side.

Re-cut the body (only when the model changes; prints the hub and seat numbers):

    blender --background --python assets/3d/build/atv.py -- --prepare assets/3d/atvrbx.obj
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "source")
BODY_OBJ = os.path.join(SOURCE, "atv_body.obj")

BODY_TRIS = 8000  # owner budget ~12k: the body plus four wheels
# Where the springs hold a wheel's centre under the chassis centre at rest (VehiclePhysics:
# mount 0.3 up, travel 1, compression g / stiffness = 196.2 / 420).
WHEEL_Y = 0.3 - 1.0 + 196.2 / 420.0


# ------------------------------------------------------------------ prepare (once)
def prepare(raw_path):
    import bpy
    import numpy as np

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=raw_path)
    src = bpy.context.selected_objects[0].data
    nv, nf = len(src.vertices), len(src.polygons)
    co = np.empty(nv * 3)
    src.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)  # the file's own axes: x along (front is -x), y up, z across
    loops = np.empty(len(src.loops), dtype=np.int64)
    src.loops.foreach_get("vertex_index", loops)
    assert len(loops) == nf * 3, "expects a triangulated model"
    tris = loops.reshape(-1, 3)
    cen = co[tris].mean(axis=1)

    X, Y, Z = co[:, 0], co[:, 1], co[:, 2]
    mid_x = (X.min() + X.max()) / 2
    mid_z = (Z.min() + Z.max()) / 2
    # Each tyre from its outer slab under the tyre tops (clear of fenders, racks and arms):
    # the radius from its length, the centre a radius above its lowest point.
    low = Y < Y.min() + 0.45
    wheels = []
    for front in (True, False):
        for right in (True, False):  # game right (+X) is the file's -z
            side = ((X < mid_x - 0.15) if front else (X > mid_x + 0.15)) & low
            lat = (mid_z - Z) if right else (Z - mid_z)
            slab = co[side & (lat > 0.45)]  # the rear-left footboard reaches 0.44
            r = (slab[:, 0].max() - slab[:, 0].min()) / 2
            cx = (slab[:, 0].min() + slab[:, 0].max()) / 2
            cy = slab[:, 1].min() + r
            band = co[side & (lat > 0.25)]
            outer = band[:, 2].min() if right else band[:, 2].max()
            wheels.append({"front": front, "right": right, "c": (cx, cy), "r": r, "outer": outer})
    r_wheel = float(np.mean([w["r"] for w in wheels]))
    scale = 1.0 / r_wheel  # a tyre radius of 1 stud
    axle_x = (np.mean([w["c"][0] for w in wheels if w["front"]]) + np.mean([w["c"][0] for w in wheels if not w["front"]])) / 2
    axle_y = float(np.mean([w["c"][1] for w in wheels]))
    centre_z = float(np.mean([w["outer"] for w in wheels]))  # the two outer faces' middle

    def to_game(p):
        """File axes -> Roblox chassis frame (x right, y up, z back)."""
        return np.stack(
            [-(p[..., 2] - centre_z) * scale, (p[..., 1] - axle_y) * scale + WHEEL_Y, (p[..., 0] - axle_x) * scale],
            axis=-1,
        )

    # A face belongs to a wheel when its centre is inside that tyre's cylinder.
    in_wheel = np.zeros(nf, dtype=bool)
    front_right = None
    for w in wheels:
        cx, cy = w["c"]
        radial = np.hypot(cen[:, 0] - cx, cen[:, 1] - cy)
        lat = (centre_z - cen[:, 2]) if w["right"] else (cen[:, 2] - centre_z)
        mask = (radial <= w["r"] + 0.008) & (lat > 0.30)
        in_wheel |= mask
        if w["front"] and w["right"]:
            front_right = mask

    g = to_game(co)
    fr = [w for w in wheels if w["front"] and w["right"]][0]
    hub = to_game(np.array([fr["c"][0], fr["c"][1], (centre_z - 0.30 + fr["outer"]) / 2]))
    hub[0] = 0.0  # placed below from the tyre's own bounds
    wheel_v = g[np.unique(tris[front_right])]
    hub[0] = (wheel_v[:, 0].min() + wheel_v[:, 0].max()) / 2
    hub[1] = (wheel_v[:, 1].min() + wheel_v[:, 1].max()) / 2
    hub[2] = (wheel_v[:, 2].min() + wheel_v[:, 2].max()) / 2

    def write(name, faces, origin, target):
        used, inverse = np.unique(tris[faces], return_inverse=True)
        verts = g[used] - origin
        me = bpy.data.meshes.new(name)
        # Blender (x, y, z) = Roblox (x, z, y), the convention of every asset in build/.
        me.from_pydata(verts[:, [0, 2, 1]].tolist(), [], inverse.reshape(-1, 3).tolist())
        me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for o in bpy.context.selected_objects:
            o.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob

        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.object.mode_set(mode="OBJECT")
        mod = ob.modifiers.new("reduce", "DECIMATE")
        mod.ratio = min(1.0, target / len(me.polygons))
        bpy.ops.object.modifier_apply(modifier="reduce")
        bpy.ops.object.modifier_add(type="TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier="Triangulate")
        os.makedirs(SOURCE, exist_ok=True)
        path = BODY_OBJ
        bpy.ops.wm.obj_export(
            filepath=path, export_selected_objects=True, forward_axis="Y", up_axis="Z",
            export_uv=False, export_normals=False, export_materials=False, apply_modifiers=True,
        )
        print(f"ATV {name}: {len(ob.data.polygons)} tris -> {os.path.relpath(path, HERE)}")
        return ob

    write("atv_body", ~in_wheel, np.zeros(3), BODY_TRIS)

    # The numbers VehicleBody.Bodies.atv needs, in the chassis frame.
    body_v = g[np.unique(tris[~in_wheel])]
    print(f"ATV scale {scale:.4f} studs per unit; tyre radius {r_wheel * scale:.3f}")
    print(f"ATV hub (front right) {hub.round(3).tolist()}")
    for w in wheels:
        c = to_game(np.array([w["c"][0], w["c"][1], centre_z]))
        print(f"ATV wheel front={w['front']} right={w['right']} z={c[2]:.3f} y={c[1]:.3f} r={w['r'] * scale:.3f}")
    print(f"ATV bounds min {body_v.min(0).round(3).tolist()} max {body_v.max(0).round(3).tolist()}")
    # The top of the body along the centre line (seats, rack).
    for z0 in np.arange(-4.0, 4.0, 0.25):
        s = body_v[(np.abs(body_v[:, 0]) < 0.35) & (body_v[:, 2] >= z0) & (body_v[:, 2] < z0 + 0.25)]
        if len(s):
            print(f"ATV top z {z0:+.2f}: y {s[:, 1].max():.3f}")
    # The fender undersides over each wheel: the lowest body point above the tyre's top.
    for w in wheels:
        c = to_game(np.array([w["c"][0], w["c"][1], centre_z]))
        x0 = 1 if w["right"] else -1
        s = body_v[
            (np.abs(body_v[:, 2] - c[2]) < 0.4)
            & (body_v[:, 0] * x0 > 1.0)
            & (body_v[:, 1] > c[1] + 0.9)
        ]
        print(f"ATV fender over front={w['front']} right={w['right']}: underside y {s[:, 1].min():.3f}")


# ------------------------------------------------------------------ build (every run)
def _load(b, path):
    import bpy

    bpy.ops.wm.obj_import(filepath=path, forward_axis="Y", up_axis="Z")
    ob = bpy.context.selected_objects[0]
    b.bm.from_mesh(ob.data)
    me = ob.data
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    b.uv = b.bm.loops.layers.uv.verify()


def body(b):
    _load(b, BODY_OBJ)
    paint_body(b)


def wheel(b):
    """One wheel about its hub, the axle along x, built as the right side's (outer face +x):
    the measured tyre (radius 1, 0.89 wide) as a closed solid. Cut from the model it came out
    an open shell Roblox showed through (owner, 2026-11-17), so it is built like every other
    asset: a dark tyre with a ring of chunky lugs staggered across the tread, a dark rim
    with a steel lip, a hub cap and its bolts on the outer face, a plain disc on the inner."""
    import math

    width, r_core, lug_h = 0.89, 0.86, 0.14
    half = width / 2
    b.cyl(r_core, width, (0, 0, 0), segs=16, rot=(0, 90, 0), swatch="dark_d")
    lugs = 18
    for k in range(lugs):
        a = 360.0 * k / lugs
        t = math.radians(a)
        x = 0.2 if k % 2 == 0 else -0.2
        r = r_core + lug_h / 2 - 0.02  # sunk 0.02 into the core
        # Blender (x, y, z) = Roblox (x, z, y): around the x axle in Blender y-z.
        b.box((0.42, lug_h + 0.02, 0.24), (x, r * math.cos(t), r * math.sin(t)), rot=(a, 0, 0), swatch="dark_d")
    # The outer face: a steel lip ring, the dark dished rim inside it, the hub, eight bolts.
    b.cyl(0.6, 0.04, (half + 0.02, 0, 0), segs=16, rot=(0, 90, 0), swatch="gun")
    b.cyl(0.52, 0.04, (half + 0.06, 0, 0), segs=16, rot=(0, 90, 0), swatch="dark")
    b.cyl(0.17, 0.08, (half + 0.12, 0, 0), segs=8, rot=(0, 90, 0), swatch="gun_l")
    for k in range(8):
        t = math.radians(45 * k + 22.5)
        b.box((0.05, 0.07, 0.07), (half + 0.105, 0.36 * math.cos(t), 0.36 * math.sin(t)), swatch="gun_l")
    # The inner face, toward the axle: a plain dark disc.
    b.cyl(0.5, 0.04, (-half - 0.02, 0, 0), segs=12, rot=(0, 90, 0), swatch="dark")


def body_swatch(x, y, z, ny):
    """The swatch of a body face from its centre (chassis frame, Roblox axes: x right, y up,
    z back) and how far its normal points up. The owner's reference (2026-11-17): olive only
    on the upper panels (the cowl over the front axle and the rear fenders' tops), the rest
    near-black: the lower body, the frame through the middle, the grille, the seat; steel
    bars (handlebar, bumper, rack rail). No markings. Regions measured on the cut model:
    the saddle at y ~0.95 for z 0..0.5, the raised back at z 1.25, the rack's deck at y 1.55
    for z 1.75..3 inside its rail (top y 1.83 at z 3.25)."""
    ax = abs(x)
    if y < -0.45:
        return "dark_d"  # frame, arms and belly pan
    if z < -3.45:
        return "gun_d"  # the front bumper and its guard
    if z > 3.15 or (z > 1.6 and y > 1.62):
        return "gun_d"  # the rack's rail and the tail
    if -1.3 < z < -0.55 and y > 1.75:
        return "gun_d"  # handlebar, grips, mirrors
    if ax < 0.8 and -0.55 < z < 1.65 and y > 0.75 and ny > 0.35:
        return "dark_d"  # the saddle and the raised back's top
    if ax < 0.95 and 1.65 < z < 3.15 and 1.3 < y < 1.62 and ny > 0.5:
        return "dark"  # the rack's deck
    if -0.9 < z < 1.3:
        return "dark"  # the middle: frame, tank sides, footboards
    if z < -3.0 and y < 1.15:
        return "dark"  # the grille under the cowl's nose
    if y < 0.55:
        return "dark"  # the lower body under the panels
    # olive_d, not olive: the reference's panels are a muddy grey-olive, and Roblox's sun
    # lifted `olive` to lime (seen in Studio, 2026-11-17).
    return "olive_d"


def paint_body(b):
    import bmesh

    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)
    for f in b.bm.faces:
        c = f.calc_center_median()
        # Blender (x, y, z) = Roblox (x, z, y).
        b._paint_faces([f], body_swatch(c.x, c.z, c.y, f.normal.z))


# Where the wheel mesh hangs (its hub, chassis frame, Roblox axes) for the front right; the
# others mirror it. Printed by prepare; VehicleBody.Bodies.atv holds the same numbers.
HUB = (1.64, WHEEL_Y, -2.405)


def render_previews(ba, scene, cam, built, previews):
    """previews/veh_atv_<view>.png: the body with its four wheels, as VehicleBody hangs them."""
    import math

    import bpy

    body_obj, wheel_obj = built.get("veh_atv_body"), built.get("veh_atv_wheel")
    if body_obj is None or wheel_obj is None:
        return
    saved = (body_obj.location.copy(), wheel_obj.location.copy())
    body_obj.location = (0, 0, 0)
    wheels = [wheel_obj] + [wheel_obj.copy() for _ in range(3)]
    for i, w in enumerate(wheels):
        if i:
            scene.collection.objects.link(w)
        sx = 1 if i % 2 == 0 else -1
        sz = 1 if i < 2 else -1
        # Blender (x, y, z) = Roblox (x, z, y); the left wheels turn half round.
        w.location = (sx * HUB[0], sz * HUB[2], HUB[1])
        w.rotation_euler = (0, 0, 0 if sx > 0 else math.pi)
    objs = [body_obj] + wheels
    for view, d in {
        "three_quarter": (1.0, -1.2, 0.7),
        "side": (1.0, 0.0, 0.1),
        "back": (-0.8, 1.2, 0.8),
        "top": (0.0, 0.01, 1.0),
    }.items():
        ba.frame_and_render(scene, cam, objs, os.path.join(previews, f"veh_atv_{view}.png"), size=(900, 700), direction=d)
    for w in wheels[1:]:
        bpy.data.objects.remove(w)
    wheel_obj.rotation_euler = (0, 0, 0)
    body_obj.location, wheel_obj.location = saved


ATV = {
    "veh_atv_body": body,
    "veh_atv_wheel": wheel,
}


def register(ba):
    """Adds the ATV's meshes to build_assets' ASSETS table (Vehicles: exported pre-mirrored;
    no bottom shift: the body is in the chassis frame, the wheel about its hub). The sculpted
    body is all near-coplanar facets, so the z-fight pass skips it."""
    for name, fn in ATV.items():
        ba.ASSETS[name] = (fn, "Vehicles", "chassis")
    ba.ZFIGHT_SKIP.add("veh_atv_body")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--prepare" in argv:
        prepare(os.path.abspath(argv[argv.index("--prepare") + 1]))
