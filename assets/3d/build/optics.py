"""The M16A4 with each optic on its rail (Config.Optics rows' `Fit`; Nova, 2026-11-18).

The optics are not built from primitives: they are free models (CC BY 4.0, notcplkerry on
Sketchfab; assets/3d/ASSET_IDS.md > Optics), downloaded as .blend files and kept out of git.
`prepare` cuts each optic out of them once, drops the glass (so first person sees through),
scales it to studs and writes a small committed source mesh (`assets/3d/source/opt_<id>.obj`,
its material names kept for painting). The build loads that mesh onto the rifle.

One mesh per rifle and optic (`wpn_m16_<optic>`): guns.m16 without its flip-up backup sight
(a real M16A4 runs an optic without the carry-handle irons), the optic's mount on the rail.
The red dot (the RMR on its rail mount) sits on a riser so the dot is REDDOT_LIFT above where
the irons were (a lower-third co-witness: the front post sits low in the glass, under the dot). Origin = the grip, barrel along -Y, up +Z, like guns.py; MUZZLE is the rifle's.

Frame of a prepared optic: origin under the middle of its mount's foot (x 0, y the foot's
middle, z the rail contact), front along -Y, up +Z, in studs.

Re-cut (only when the downloads change; the blend files are opened with scripts disabled):

    blender --background --factory-startup --disable-autoexec --python assets/3d/build/optics.py -- \
        --prepare <Trijicon_TA01M4A1.blend> <Aimpoint_comp_M2.blend>
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "source")

# Studs per metre: the M16A4 (1.003 m) is 3.08 studs long in game (guns.py).
SCALE = 3.07
# Faces never kept: the glass (first person looks through the optic).
GLASS = {"lens", "reflector"}
# The source materials painted with palette swatches (build_assets palette.md).
SWATCH = {
    "plastic": "dark",
    "finish": "dark_d",
    "plastic_bright": "gun_l",
    "rubber": "dark_d",
    "dark": "dark_d",
}

# The rifle's flat-top rail: where a mount's foot sits (guns.m16: rail top 0.51, slots to 0.525).
RAIL_TOP = 0.525
# Where each optic's origin goes on the rail (y from the grip; the rail runs y -0.58..0.14).
AT = {"acog": -0.20, "compm2": -0.16, "reddot": -0.08}
# The irons' line (guns.SIGHT wpn_m16): the red dot's riser lifts the dot above it.
IRONS_Z = 0.615
# How far above the irons' line the dot sits (studs). Nova, 2026-11-20: level with the front
# post (absolute co-witness), the post "does get in the way"; this drops it to the glass's
# lower part, under the dot. Config.Optics.reddot.Fit's Sight is on this line.
REDDOT_LIFT = 0.1
# The dot above the RMR mount's foot, printed by prepare (studs).
REDDOT_DOT_Z = 0.071


# ------------------------------------------------------------------ prepare (once)
def _collect(names, rotate_half=False, moves=None):
    """The named objects' faces (world space, metres), glass dropped: (verts, faces, mats)."""
    import bpy
    from mathutils import Matrix, Vector

    moves = moves or {}
    verts, faces, mats = [], [], []
    turn = Matrix.Rotation(3.14159265, 4, "Z") if rotate_half else Matrix.Identity(4)
    for name in names:
        ob = bpy.data.objects[name]
        mw = turn @ Matrix.Translation(Vector(moves.get(name, (0, 0, 0)))) @ ob.matrix_world
        me = ob.data
        base = len(verts)
        verts.extend(mw @ v.co for v in me.vertices)
        for poly in me.polygons:
            mat = me.materials[poly.material_index] if me.materials else None
            mname = mat.name if mat else "plastic"
            if mname in GLASS:
                continue
            faces.append([base + i for i in poly.vertices])
            mats.append(mname)
    return verts, faces, mats


def _write(name, verts, faces, mats, foot_z_band=0.004):
    """Moves the piece to its frame (origin under the foot's middle, x 0), scales to studs, writes
    assets/3d/source/opt_<name>.obj (+ .mtl). Returns the origin (metres) for the numbers."""
    import bpy

    zmin = min(v.z for v in verts)
    foot = [v for v in verts if v.z < zmin + foot_z_band]
    ox = 0.0  # every optic is modelled centred on x = 0 (its foot is not: clamp knobs)
    oy = (min(v.y for v in foot) + max(v.y for v in foot)) / 2
    origin = (ox, oy, zmin)
    co = [((v.x - ox) * SCALE, (v.y - oy) * SCALE, (v.z - zmin) * SCALE) for v in verts]
    used = sorted({i for f in faces for i in f})
    remap = {old: new for new, old in enumerate(used)}
    me = bpy.data.meshes.new(f"opt_{name}")
    me.from_pydata([co[i] for i in used], [], [[remap[i] for i in f] for f in faces])
    names = sorted(set(mats))
    for m in names:
        me.materials.append(bpy.data.materials.get(m) or bpy.data.materials.new(m))
    for poly, m in zip(me.polygons, mats):
        poly.material_index = names.index(m)
    me.update()
    ob = bpy.data.objects.new(f"opt_{name}", me)
    bpy.context.scene.collection.objects.link(ob)
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_add(type="TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier="Triangulate")
    os.makedirs(SOURCE, exist_ok=True)
    path = os.path.join(SOURCE, f"opt_{name}.obj")
    bpy.ops.wm.obj_export(
        # Forward Y, up Z on both sides (here and _load): an exact round trip of the data.
        filepath=path, export_selected_objects=True, forward_axis="Y", up_axis="Z",
        export_uv=False, export_normals=False, export_materials=True, apply_modifiers=True,
    )
    print(f"OPTIC {name}: {len(ob.data.polygons)} tris -> {os.path.relpath(path, HERE)}")
    return origin


def _studs(p, origin):
    return tuple(round((p[i] - origin[i]) * SCALE, 3) for i in range(3))


def prepare(acog_blend, compm2_blend):
    import bpy

    # Both downloads face +Y; every optic is turned half round to face -Y like the rifle.
    # The ACOG pack: the TA01 with its mount; the RMR set down on its own rail mount.
    bpy.ops.wm.open_mainfile(filepath=acog_blend, load_ui=False, use_scripts=False)
    o = bpy.data.objects
    acog = _collect(["ACOG", "rearsight"], rotate_half=True)
    origin = _write("acog", *acog)
    # Its axis: the eyepiece lens's middle (z), from the eyepiece end to the objective end (y,
    # turned half round).
    body = [o["ACOG"].matrix_world @ v.co for v in o["ACOG"].data.vertices]
    ys = [-p.y for p in body]
    lens_z = (0.0235 + 0.0431) / 2  # the eyepiece's face centres (measured)
    print(f"OPTIC acog axis: rear {_studs((0, max(ys), lens_z), origin)} front {_studs((0, min(ys), lens_z), origin)}")

    rmr, mount = o["RMR"], o["RMR_mount_rail"]
    rmr_lo = min((rmr.matrix_world @ v.co).z for v in rmr.data.vertices)
    mount_hi = max((mount.matrix_world @ v.co).z for v in mount.data.vertices)
    rmr_y = [(rmr.matrix_world @ v.co).y for v in rmr.data.vertices]
    mount_y = [(mount.matrix_world @ v.co).y for v in mount.data.vertices]
    dy = (min(mount_y) + max(mount_y)) / 2 - (min(rmr_y) + max(rmr_y)) / 2
    dz = mount_hi - rmr_lo
    reddot = _collect(["RMR_mount_rail", "RMR"], rotate_half=True, moves={"RMR": (0, dy, dz)})
    origin = _write("reddot", *reddot)
    window = o["RMR_reflector"]
    wz = [(window.matrix_world @ v.co).z + dz for v in window.data.vertices]
    ry = [-(y + dy) for y in rmr_y]
    dot_z = (min(wz) + max(wz)) / 2
    print(f"OPTIC reddot axis: rear {_studs((0, max(ry), dot_z), origin)} front {_studs((0, min(ry), dot_z), origin)}")

    # The CompM2: tube, mount and its two flip caps.
    bpy.ops.wm.open_mainfile(filepath=compm2_blend, load_ui=False, use_scripts=False)
    o = bpy.data.objects
    comp = _collect(["mount", "scope", "cover_front", "cover_rear"], rotate_half=True)
    origin = _write("compm2", *comp)
    tube = [o["scope"].matrix_world @ v.co for v in o["scope"].data.vertices]
    ty = [-p.y for p in tube]  # turned half round
    tube_z = o["scope"].matrix_world.translation.z
    print(f"OPTIC compm2 axis: rear {_studs((0, max(ty), tube_z), origin)} front {_studs((0, min(ty), tube_z), origin)}")


# ------------------------------------------------------------------ build (every run)
def _load(b, name, at):
    """Appends opt_<name> at `at` (Blender x, y, z), painted by its source materials."""
    import bpy
    from mathutils import Matrix

    bpy.ops.wm.obj_import(filepath=os.path.join(SOURCE, f"opt_{name}.obj"), forward_axis="Y", up_axis="Z")
    ob = bpy.context.selected_objects[0]
    me = ob.data
    me.transform(Matrix.Translation(at))
    names = [m.name.split(".")[0] if m else "plastic" for m in me.materials]
    swatches = [SWATCH.get(names[p.material_index] if names else "plastic", "dark") for p in me.polygons]
    before = len(b.bm.faces)
    b.bm.from_mesh(me)
    b.bm.faces.ensure_lookup_table()
    for i, swatch in enumerate(swatches):
        b._paint_faces([b.bm.faces[before + i]], swatch)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)


def _variant(name):
    def build(b):
        import guns  # build_assets puts build/ on the path before calling

        guns.m16(b, rear_sight=False)
        y = AT[name]
        z = RAIL_TOP
        if name == "reddot":
            # A riser on the rail lifts the RMR's dot REDDOT_LIFT above the irons' line.
            rise = IRONS_Z + REDDOT_LIFT - RAIL_TOP - REDDOT_DOT_Z
            b.box((0.1, 0.16, rise), (0, y, RAIL_TOP + rise / 2), swatch="dark")
            z = RAIL_TOP + rise
        _load(b, name, (0, y, z))

    return build


VARIANTS = {f"wpn_m16_{name}": _variant(name) for name in ("acog", "compm2", "reddot")}


def register(ba):
    """Adds the rifle-with-optic meshes to build_assets' ASSETS table (Weapons, origin = the grip;
    the optics' small facets overlap by design, so the z-fight pass skips them)."""
    for name, fn in VARIANTS.items():
        ba.ASSETS[name] = (fn, "Weapons", "center")
        ba.ZFIGHT_SKIP.add(name)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--prepare" in argv:
        i = argv.index("--prepare")
        prepare(os.path.abspath(argv[i + 1]), os.path.abspath(argv[i + 2]))
