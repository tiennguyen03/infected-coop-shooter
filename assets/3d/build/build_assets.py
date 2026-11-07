"""Low-poly asset builder for Infected Co-op Shooter.

Builds every game mesh procedurally with bmesh, paints faces with a shared palette texture
(one material for all assets), saves the Blender project, exports one FBX per asset and
renders preview PNGs (one per asset, plus `lineup_chars.png` for the bodies and hand-held
things and `lineup_env.png` for the environment). Style rules: docs/STYLES.md section 6.

    blender --background --python assets/3d/build/build_assets.py            # everything
    blender --background --python assets/3d/build/build_assets.py -- --only prop_ammo_crate

Units: 1 Blender unit = 1 Roblox stud (scene unit scale 0.28 m). Import FBX in Roblox with
the 3D Importer's Scale Unit set to "Studs". Z is up here; FBX export converts to Y-up.
Pivots: props at bottom center, weapon at the grip, hovering things at their center.
Skinned bodies (RIGGED, pc_assault_skinned): one mesh + an R15 armature, origin at the
HumanoidRootPart centre, exported three ways (rigged, mesh-only, 15-part) for Studio's
Avatar Setup / 3D Importer; steps in assets/3d/README.md "Skinned Weller".
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_3D = os.path.join(ROOT, "assets", "3d")
EXPORT = os.path.join(OUT_3D, "export")
PREVIEWS = os.path.join(OUT_3D, "build", "previews")
BLEND = os.path.join(OUT_3D, "arena_survivor.blend")
PALETTE_PNG = os.path.join(OUT_3D, "palette.png")
PALETTE_MD = os.path.join(OUT_3D, "palette.md")

# ------------------------------------------------------------------ palette (docs/STYLES.md)
# One swatch per material. 3D lighting supplies the l/m/d facets, so each material is its
# mid tone, with explicit light/dark swatches where a model needs a painted contrast.
# The order is the UV layout of every mesh ever exported: never reorder or remove a row.
# Retired rows are replaced in place (inf_skin/inf_runner/inf_brute became pallor/flesh/bruise,
# skin v2 2026-11-07) and new rows are appended; 57 of the 64 cells are used.
PALETTE = [
    ("gun", "#636d77"), ("gun_l", "#9aa4ae"), ("gun_d", "#3d454d"),
    ("dark", "#30353b"), ("dark_l", "#4b5159"), ("dark_d", "#1f2327"),
    ("olive", "#636e42"), ("olive_l", "#8e9862"), ("olive_d", "#41492b"),
    ("tan", "#9e835a"), ("tan_l", "#c9ac7c"), ("tan_d", "#6e5a3c"),
    ("brass", "#bf9136"), ("brass_l", "#e6bd60"), ("brass_d", "#845f20"),
    ("white", "#c9ced4"), ("white_l", "#f2f4f6"), ("white_d", "#99a1a9"),
    ("red", "#b93434"), ("red_l", "#e85a5a"), ("red_d", "#7e2020"),
    ("concrete", "#7c7a74"), ("asphalt", "#3e4044"), ("rust", "#7a4328"),
    ("foliage", "#596232"), ("pallor", "#8f8786"), ("flesh", "#b27b73"), ("bruise", "#65506b"),
    ("foliage_d", "#3a4120"),
    ("rust_l", "#a8603c"), ("rust_d", "#4d2a18"),
    ("rebuilt", "#b09686"), ("rebuilt_l", "#dccbbb"), ("rebuilt_d", "#73584e"),
    ("strain", "#bed73c"), ("strain_l", "#d2e276"), ("strain_d", "#768525"),
    ("friendly_blue", "#3fa7d6"), ("warning_orange", "#e87828"), ("objective_yellow", "#e6bd60"),
    ("infected_green", "#78aa46"), ("shield_blue", "#4e84c4"), ("heal_pink", "#d28282"),
    # skin v2 (docs/STYLES.md §2 "Infected skin"): pale bruised skin, exposed flesh, deep
    # bruise, raw wound, pus; concrete's own l/d for the building kit
    ("pallor_l", "#bdb5b2"), ("pallor_d", "#5e5759"),
    ("flesh_l", "#dba89e"), ("flesh_d", "#7b4f50"),
    ("bruise_l", "#8e7a8f"), ("bruise_d", "#3f3046"),
    ("wound", "#8e2630"), ("wound_l", "#c4464a"), ("wound_d", "#561620"),
    ("pus", "#d2bd6c"), ("pus_l", "#efe2a8"), ("pus_d", "#977f3c"),
    ("concrete_l", "#a9a7a0"), ("concrete_d", "#54524d"),
]
assert len(PALETTE) <= 64, "palette.png is an 8x8 grid"
GRID = 8  # 8x8 cells
CELL = 16  # px per cell -> 128x128 texture
SWATCH = {name: i for i, (name, _) in enumerate(PALETTE)}


def hex_rgb(h):
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (1, 3, 5))


def swatch_uv(name):
    i = SWATCH[name]
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def build_palette_image():
    size = GRID * CELL
    img = bpy.data.images.new("palette", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, (_, h) in enumerate(PALETTE):
        r, g, b = hex_rgb(h)
        col, row = i % GRID, i // GRID
        for y in range(CELL):
            for x in range(CELL):
                # image rows start at the bottom
                py = size - 1 - (row * CELL + y)
                p = (py * size + col * CELL + x) * 4
                px[p : p + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = PALETTE_PNG
    img.file_format = "PNG"
    img.save()
    img.colorspace_settings.name = "sRGB"
    with open(PALETTE_MD, "w", encoding="utf-8") as f:
        f.write("# palette.png swatch map\n\n128x128, 8x8 cells of 16 px. Row-major from the top-left.\n")
        f.write("Every mesh face's UVs collapse to its swatch center. Generated by build/build_assets.py.\n\n")
        f.write("| # | name | hex | cell (col,row) |\n|---|---|---|---|\n")
        for i, (n, h) in enumerate(PALETTE):
            f.write(f"| {i} | {n} | `{h}` | ({i % GRID},{i // GRID}) |\n")
    return img


def build_palette_material(img):
    mat = bpy.data.materials.new("Palette")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.location = (-400, 300)
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.1
    return mat


# ------------------------------------------------------------------ bmesh helpers
class Builder:
    """Accumulates primitives into one bmesh; each primitive is painted with a swatch."""

    def __init__(self, skinned=False):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        # Skinned bodies only: vertex-group (bone) names in deform-layer index order. The
        # deform layer must exist before the first vertex (adding it later invalidates them).
        self.groups = []
        self.deform = self.bm.verts.layers.deform.verify() if skinned else None

    def _paint(self, verts, swatch):
        u, v = swatch_uv(swatch)
        faces = {f for vert in verts for f in vert.link_faces}
        self._paint_faces(faces, swatch)
        return verts

    def _paint_faces(self, faces, swatch):
        u, v = swatch_uv(swatch)
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = (u, v)

    # --- skinning (one deform layer; vertex groups are created from `groups` at finish)
    def weight(self, verts, weights):
        """Skins `verts` to bones: weights = {bone_name: w}, replacing any earlier weights."""
        if self.deform is None:
            raise RuntimeError("weight() needs Builder(skinned=True)")
        for name in weights:
            if name not in self.groups:
                self.groups.append(name)
        for v in verts:
            dv = v[self.deform]
            dv.clear()
            for name, w in weights.items():
                dv[self.groups.index(name)] = w
        return verts

    def weight_split(self, verts, zj, upper, lower, band=0.03):
        """Skins a piece that straddles a joint at height `zj`: verts above it to `upper`,
        below to `lower`, verts on the joint 50/50 (the bridge loop rule)."""
        for v in verts:
            if v.co.z > zj + band:
                self.weight([v], {upper: 1.0})
            elif v.co.z < zj - band:
                self.weight([v], {lower: 1.0})
            else:
                self.weight([v], {upper: 0.5, lower: 0.5})
        return verts

    def prism(self, rings, swatch="gun", loc=(0, 0, 0), sides=8, chamfer=0.78, cap_bottom=True, cap_top=True):
        """A tube through `rings` = [(z, rx, ry), ...] listed bottom to top; each ring is an
        octagon (sides=8: a chamfered box whose corners sit at `chamfer` of the half-size, the
        tapered-limb profile) or a box (sides=4). `swatch` is one name for the whole tube or
        one per band (len(rings) - 1); the caps take the first and last band's swatch. Returns
        one vert list per ring, bottom to top, so a caller can skin each loop."""
        bm = self.bm
        ring_verts = []
        for z, rx, ry in rings:
            if sides == 4:
                pts = ((-rx, -ry), (rx, -ry), (rx, ry), (-rx, ry))
            else:
                c = chamfer
                pts = ((-rx * c, -ry), (rx * c, -ry), (rx, -ry * c), (rx, ry * c), (rx * c, ry), (-rx * c, ry), (-rx, ry * c), (-rx, -ry * c))
            ring_verts.append([bm.verts.new((loc[0] + px, loc[1] + py, loc[2] + z)) for px, py in pts])
        n = len(ring_verts[0])
        bands = [swatch] * (len(rings) - 1) if isinstance(swatch, str) else list(swatch)
        for i, (lo, hi) in enumerate(zip(ring_verts, ring_verts[1:])):
            faces = [bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k])) for k in range(n)]
            self._paint_faces(faces, bands[i])
        if cap_bottom:
            self._paint_faces([bm.faces.new(tuple(reversed(ring_verts[0])))], bands[0])
        if cap_top:
            self._paint_faces([bm.faces.new(tuple(ring_verts[-1]))], bands[-1])
        return ring_verts

    def _xform(self, verts, size=None, rot=None, loc=None):
        if size is not None:
            bmesh.ops.scale(self.bm, vec=Vector(size), verts=verts)
        if rot is not None:
            # rot = (x_deg, y_deg, z_deg), applied X then Y then Z
            for axis, deg in zip("XYZ", rot):
                if deg:
                    bmesh.ops.rotate(self.bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(deg), 3, axis), verts=verts)
        if loc is not None:
            bmesh.ops.translate(self.bm, vec=Vector(loc), verts=verts)
        return verts

    def box(self, size, loc=(0, 0, 0), rot=None, swatch="gun"):
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        self._xform(verts, size=size, rot=rot, loc=loc)
        return self._paint(verts, swatch)

    def cyl(self, r, depth, loc=(0, 0, 0), segs=8, r2=None, rot=None, swatch="gun"):
        verts = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth
        )["verts"]
        self._xform(verts, rot=rot, loc=loc)
        return self._paint(verts, swatch)

    def ico(self, r, loc=(0, 0, 0), subdiv=1, swatch="gun"):
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r)["verts"]
        self._xform(verts, loc=loc)
        return self._paint(verts, swatch)

    def wedge(self, size, loc=(0, 0, 0), rot=None, swatch="gun"):
        """Triangular prism: a box with its +X top edge collapsed (ramp rising toward -X)."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            if v.co.x > 0 and v.co.z > 0:
                v.co.z = -0.5
        bmesh.ops.remove_doubles(self.bm, verts=verts, dist=1e-4)
        verts = [v for v in verts if v.is_valid]
        self._xform(verts, size=size, rot=rot, loc=loc)
        return self._paint(verts, swatch)

    def rotate_all(self, rot):
        """Rotate everything built so far about the origin (a tilted head, a leaning torso)."""
        self._xform(list(self.bm.verts), rot=rot)

    def merge(self, other):
        """Absorb another Builder's geometry (frees it)."""
        me = bpy.data.meshes.new("_merge_tmp")
        other.bm.to_mesh(me)
        other.bm.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def finish(self, name, collection, material, pivot="bottom"):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if pivot == "bottom":
            zmin = min(v.co.z for v in bm.verts)
            bmesh.ops.translate(bm, vec=(0, 0, -zmin), verts=bm.verts)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material)
        for p in me.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name, me)
        collection.objects.link(obj)
        obj["tri_count"] = sum(len(p.vertices) - 2 for p in me.polygons)
        for group in self.groups:  # same order as the deform-layer indices
            obj.vertex_groups.new(name=group)
        return obj


# ------------------------------------------------------------------ assets
ASSETS = {}


def asset(name, collection, pivot="bottom"):
    def deco(fn):
        ASSETS[name] = (fn, collection, pivot)
        return fn

    return deco


@asset("prop_ammo_crate", "Props")
def ammo_crate(b):
    # matches AmmoCacheService placeholder 2.6 x 1.6 x 1.8 (x, height, depth)
    b.box((2.6, 1.8, 1.3), (0, 0, 0.65), swatch="olive")
    b.box((2.7, 1.9, 0.3), (0, 0, 1.45), swatch="olive_d")  # lid
    b.box((2.5, 1.7, 0.08), (0, 0, 1.64), swatch="olive_l")  # lid top panel
    for x in (-1.25, 1.25):  # rope handles
        b.box((0.16, 0.9, 0.18), (x * 1.08, 0, 0.9), swatch="dark")
    b.box((0.9, 0.04, 0.5), (0, -0.92, 0.75), swatch="white")  # stencil plate
    b.box((0.5, 0.05, 0.08), (0, -0.93, 0.62), swatch="olive_d")  # stencil bar
    b.box((0.3, 0.06, 0.3), (0, -0.93, 1.42), swatch="gun")  # latch
    b.box((0.3, 0.06, 0.3), (0, 0.93, 1.42), swatch="gun")


@asset("prop_repulsor_mine", "Props")
def repulsor_mine(b):
    # MineService placeholder: disc 2 studs across, 0.4 tall
    b.cyl(1.0, 0.3, (0, 0, 0.15), segs=10, swatch="gun_d")
    b.cyl(0.85, 0.12, (0, 0, 0.36), segs=10, swatch="gun")
    b.cyl(0.42, 0.14, (0, 0, 0.49), segs=8, swatch="shield_blue")  # pressure cap
    b.cyl(0.18, 0.06, (0, 0, 0.59), segs=6, swatch="white_l")  # indicator
    for ang in (90, 210, 330):  # prongs
        a = math.radians(ang)
        b.cyl(0.04, 0.5, (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.72), segs=5, rot=(math.cos(a) * -18, math.sin(a) * 18, 0), swatch="dark_l")


@asset("prop_drone", "Props", pivot="center")
def drone(b):
    # DroneService placeholder 1.1 x 0.35 x 1.1
    b.box((0.7, 0.7, 0.3), (0, 0, 0), swatch="dark")
    b.box((0.5, 0.5, 0.1), (0, 0, 0.2), swatch="dark_l")  # top hatch
    b.box((0.26, 0.12, 0.1), (0, -0.4, 0.02), swatch="friendly_blue")  # front lamp
    b.cyl(0.12, 0.18, (0, 0, -0.2), segs=6, swatch="gun_d")  # camera gimbal
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ang = math.degrees(math.atan2(sy, sx))
        b.box((0.7, 0.1, 0.08), (sx * 0.5, sy * 0.5, 0.05), rot=(0, 0, ang), swatch="dark_d")  # arm
        b.cyl(0.1, 0.14, (sx * 0.78, sy * 0.78, 0.1), segs=6, swatch="gun")  # motor
        b.box((0.9, 0.08, 0.02), (sx * 0.78, sy * 0.78, 0.19), rot=(0, 0, ang + 25), swatch="gun_l")  # prop
        b.box((0.9, 0.08, 0.02), (sx * 0.78, sy * 0.78, 0.19), rot=(0, 0, ang + 115), swatch="gun_l")


@asset("prop_drone_beacon", "Props")
def drone_beacon(b):
    for ang in (90, 210, 330):  # tripod
        a = math.radians(ang)
        b.cyl(0.05, 1.6, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.78), segs=5, rot=(math.sin(a) * 22, -math.cos(a) * 22, 0), swatch="dark")
    b.cyl(0.42, 1.2, (0, 0, 2.0), segs=10, swatch="gun")  # body
    b.cyl(0.46, 0.12, (0, 0, 1.75), segs=10, swatch="dark_d")  # band
    b.box((0.6, 0.6, 0.18), (0, 0, 2.7), swatch="dark")  # lamp housing
    b.cyl(0.3, 0.45, (0, 0, 3.0), segs=8, r2=0.05, swatch="friendly_blue")  # lamp cone
    b.box((0.08, 0.26, 0.14), (0.43, 0, 2.2), swatch="friendly_blue")  # status light


@asset("wpn_rifle", "Weapons", pivot="center")
def rifle(b):
    # Scaled to the PlayerSetup placeholder (receiver 0.34 x 0.46 x 1.5). Barrel points -Y.
    # Origin = grip (where the hand holds it).
    b.box((0.3, 1.5, 0.4), (0, -0.35, 0.42), swatch="gun_d")  # receiver
    b.box((0.26, 0.5, 0.12), (0, -0.4, 0.68), swatch="dark_d")  # top rail
    b.box((0.28, 1.0, 0.3), (0, -1.45, 0.4), swatch="dark")  # handguard
    b.cyl(0.06, 1.0, (0, -2.4, 0.46), segs=8, rot=(90, 0, 0), swatch="gun")  # barrel
    b.cyl(0.09, 0.22, (0, -2.95, 0.46), segs=8, swatch="gun_d", rot=(90, 0, 0))  # muzzle
    b.box((0.08, 0.1, 0.24), (0, -1.9, 0.66), swatch="dark_d")  # front sight
    b.box((0.2, 0.18, 0.16), (0, -0.05, 0.78), swatch="dark_d")  # rear sight block
    b.box((0.24, 0.06, 0.1), (0, -0.06, 0.88), swatch="shield_blue")  # optic lens strip
    b.box((0.2, 0.3, 0.5), (0, 0.0, 0.0), rot=(18, 0, 0), swatch="dark")  # pistol grip
    b.box((0.24, 0.9, 0.3), (0, 0.85, 0.42), swatch="dark_l")  # stock
    b.box((0.26, 0.16, 0.44), (0, 1.32, 0.36), swatch="dark")  # butt pad
    b.box((0.16, 0.36, 0.55), (0, -0.75, 0.0), rot=(12, 0, 0), swatch="gun_d")  # magazine
    b.box((0.14, 0.3, 0.1), (0, -0.78, -0.28), rot=(12, 0, 0), swatch="brass")  # mag base tape


@asset("pick_xp_orb", "Pickups", pivot="center")
def xp_orb(b):
    # XPOrbService scales the part per XP value; 80 tris. Color can also be overridden by
    # MeshPart.Color if the texture is dropped for this one.
    b.ico(0.5, subdiv=2, swatch="friendly_blue")


@asset("ref_human_5st", "_Reference")
def ref_human(b):
    b.box((2, 1, 5), (0, 0, 2.5), swatch="white_d")
    b.box((1, 1, 1), (0, 0, 5.5), swatch="white")



@asset("prop_plague_rat", "Props")
def plague_rat(b):
    # PlagueRatService rat (old Parts: body 0.6 x 0.5 x 1.2 + head + tail). Faces -Y.
    b.box((0.6, 0.85, 0.44), (0, 0.05, 0.36), swatch="dark_l")  # body
    b.box((0.66, 0.5, 0.5), (0, 0.42, 0.37), swatch="dark")  # rump
    b.box((0.44, 0.42, 0.36), (0, -0.52, 0.4), swatch="dark")  # head
    b.box((0.24, 0.32, 0.2), (0, -0.84, 0.36), swatch="dark_l")  # snout
    b.box((0.1, 0.08, 0.1), (0, -1.0, 0.38), swatch="heal_pink")  # nose
    for sx in (-1, 1):
        b.cyl(0.11, 0.05, (sx * 0.17, -0.42, 0.63), segs=6, rot=(90, 0, 0), swatch="heal_pink")  # ear
        b.box((0.09, 0.06, 0.09), (sx * 0.15, -0.74, 0.47), swatch="red_l")  # eye
        b.box((0.13, 0.16, 0.24), (sx * 0.23, -0.32, 0.12), swatch="dark_d")  # front leg
        b.box((0.15, 0.2, 0.26), (sx * 0.26, 0.38, 0.13), swatch="dark_d")  # hind leg
    b.cyl(0.055, 0.55, (0, 0.92, 0.3), segs=5, rot=(90, 0, 0), swatch="rust")  # tail base
    b.cyl(0.04, 0.5, (0, 1.4, 0.2), segs=5, rot=(78, 0, 0), swatch="rust")  # tail tip


@asset("env_barrier_jersey", "Environment")
def barrier_jersey(b):
    # Concrete traffic barrier, 6 studs long, 2.4 tall. Stepped jersey profile.
    b.box((6.0, 2.0, 0.5), (0, 0, 0.25), swatch="concrete")
    b.box((6.0, 1.3, 0.7), (0, 0, 0.85), swatch="concrete")
    b.box((6.0, 0.7, 1.2), (0, 0, 1.8), swatch="concrete")
    b.box((1.2, 0.72, 0.5), (-1.8, 0, 1.9), swatch="warning_orange")  # hazard stripes
    b.box((1.2, 0.72, 0.5), (1.8, 0, 1.9), swatch="warning_orange")
    b.box((0.3, 0.3, 0.5), (0, 0, 2.5), swatch="rust")  # lifting eye / rebar


# ------------------------------------------------------------------ scale reference
# 1 BU = 1 stud = 0.28 m. Every Environment asset is built against the 5-stud R15 character
# (docs/STYLES.md §6): doors you walk through, cover you shoot over, storeys you look up at.
# Use these constants, never eyeballed numbers.
CHAR_H = 5.0
DOOR_H, DOOR_W = 7.2, 3.6
STOREY = 10.5  # floor-to-floor
SILL, HEAD = 3.2, 7.6  # window band: chest height to just above head room
COVER_H = 4.0  # chest-high cover: sandbags, hesco, vehicle hoods
# Ruin v2 (2026-11-07): storey 10.0 (slab top 10.0 = the mantle height), door 4 x 8, ground
# floor windows sill 4 / head 9.4 (the 5-stud vault headroom clears a 9.4 head).
RUIN_STOREY = 10.0
RUIN_DOOR_W, RUIN_DOOR_H = 4.0, 8.0
RUIN_SILL, RUIN_HEAD = 4.0, 9.4
CORNERS = ((1, 1), (-1, 1), (1, -1), (-1, -1))


@asset("env_sandbag_bunker", "Environment")
def sandbag_bunker(b):
    # U-shaped sandbag emplacement open toward +Y: 12 x 10 footprint, walls COVER_H tall so a
    # character shoots over them. Lower courses are one block, the top two are loose bags.
    bag = (1.6, 0.8, 0.7)
    base_h = COVER_H - 2 * bag[2]

    def wall(x0, y0, x1, y1):
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        ang = math.degrees(math.atan2(dy, dx))
        b.box((length, bag[1], base_h), ((x0 + x1) / 2, (y0 + y1) / 2, base_h / 2), rot=(0, 0, ang), swatch="tan_d")
        for r in range(2):
            off = bag[0] / 2 if r else 0.0
            sw = "tan" if r == 0 else "tan_l"
            for i in range(int(length / bag[0]) + 1):
                t = (i * bag[0] + off + bag[0] / 2) / length
                if t > 0.97:
                    continue
                b.box(bag, (x0 + dx * t, y0 + dy * t, base_h + bag[2] * (r + 0.5)), rot=(0, 0, ang), swatch=sw)

    wall(-6.0, 5.0, -6.0, -5.0)
    wall(-6.0, -5.0, 6.0, -5.0)
    wall(6.0, -5.0, 6.0, 5.0)
    b.box((2.8, 1.0, 1.6), (0, -4.0, 0.8), swatch="olive_d")  # ammo stack
    b.box((1.2, 0.8, 0.5), (2.6, -3.8, 0.25), swatch="olive")  # crate
    for sx in (-1, 1):
        b.box((0.25, 0.25, 6.0), (sx * 5.6, 4.6, 3.0), swatch="tan_d")  # camo-net posts
    b.box((11.5, 0.1, 0.6), (0, 4.6, 6.0), swatch="olive")  # net rail


@asset("env_guard_tower", "Environment")
def guard_tower(b):
    # Timber watchtower: 10 x 10 footprint, deck at 14 (almost three characters up), chest-high
    # plank rail, roof slab at 22, ~27 overall with the antenna. Ladder on the +Y side.
    L = 3.6  # leg half-spacing
    DECK = 14.0
    for sx, sy in CORNERS:
        b.box((0.7, 0.7, DECK), (sx * L, sy * L, DECK / 2), swatch="tan_d")
    span = 2 * L
    for z0, z1 in ((0.8, 6.6), (7.2, 13.0)):  # one X brace per side per bay
        length = math.hypot(span, z1 - z0)
        tilt = math.degrees(math.atan2(z1 - z0, span))
        for side in range(4):
            a = math.radians(side * 90)
            lx, ly = -math.sin(a) * L, math.cos(a) * L
            for sgn in (1, -1):
                b.box((length, 0.22, 0.22), (lx, ly, (z0 + z1) / 2), rot=(0, sgn * tilt, side * 90), swatch="tan_d")
    b.box((9.0, 9.0, 0.5), (0, 0, DECK + 0.25), swatch="tan")  # deck
    for side in range(4):  # chest-high plank rail; the ladder side (+Y) has a 2.4-wide gate gap
        a = math.radians(side * 90)
        cx, cy = -math.sin(a) * 4.4, math.cos(a) * 4.4
        if side == 0:
            for sx in (-1, 1):
                b.box((3.3, 0.25, COVER_H), (sx * 2.85, cy, DECK + 0.5 + COVER_H / 2), swatch="olive_d")
        else:
            b.box((9.0, 0.25, COVER_H), (cx, cy, DECK + 0.5 + COVER_H / 2), rot=(0, 0, side * 90), swatch="olive_d")
    post_h = 7.7
    for sx, sy in CORNERS:
        b.box((0.4, 0.4, post_h), (sx * 4.3, sy * 4.3, DECK + 0.5 + post_h / 2), swatch="tan_d")
    b.box((11.0, 11.0, 0.4), (0, 0, DECK + 8.4), swatch="asphalt")  # roof slab
    b.box((10.4, 10.4, 0.25), (0, 0, DECK + 8.7), swatch="dark")
    b.box((0.6, 0.6, 1.2), (0, 0, DECK + 9.4), swatch="gun_d")  # antenna base
    b.cyl(0.06, 3.0, (0, 0, DECK + 11.5), segs=5, swatch="gun_l")
    b.cyl(0.3, 0.3, (0, 0, DECK + 13.1), segs=6, swatch="red_l")  # beacon
    for i in range(int(DECK / 1.3)):  # ladder
        b.box((1.4, 0.14, 0.14), (0, L + 0.45, 0.9 + i * 1.3), swatch="tan_l")
    for sx in (-1, 1):
        b.box((0.16, 0.16, DECK + 0.5), (sx * 0.7, L + 0.45, (DECK + 0.5) / 2), swatch="tan_d")


@asset("env_ruin_building", "Environment")
def ruin_building(b):
    # Bombed-out two-storey concrete block, v2 (2026-11-07): 30 x 20 footprint on RUIN_STOREY
    # (10.0) floors, slab top at 10.0, a 4 x 8 doorway in the front (-Y) wall, windows at sill
    # 4 / head 9.4 (vaultable with the 5-stud headroom rule), the back wall down to one storey
    # with a 6-wide breach at x +7 (the Infected's way in; the wall top is the mantle route to
    # the first floor). Collision comes from invisible Parts (MeshAssets colliders), so the
    # openings are real: enterable ground floor, climbable first floor, no roof.
    T = 1.0
    W, D = 30.0, 20.0
    hx, hy = W / 2, D / 2
    S = RUIN_STOREY
    DW, DH = RUIN_DOOR_W, RUIN_DOOR_H
    SILL2, HEAD2 = RUIN_SILL, RUIN_HEAD

    def wall(axis, pos, storeys, door=False, breach=None):
        length = W if axis == "x" else D
        bays = 4 if axis == "x" else 3
        pitch = length / bays

        def box(l, h, zc, c=0.0, swatch="concrete"):
            if axis == "x":
                b.box((l, T, h), (c, pos, zc), swatch=swatch)
            else:
                b.box((T, l, h), (pos, c, zc), swatch=swatch)

        for s_ in range(storeys):
            z0 = s_ * S
            sill = SILL2 if s_ == 0 else SILL
            head = HEAD2 if s_ == 0 else HEAD
            sw = "concrete" if s_ == 0 else "white_d"
            has_door = door and s_ == 0
            if breach and s_ == 0:
                bx, bw = breach
                left_w = bx - bw / 2 + length / 2
                box(left_w, S, S / 2, -length / 2 + left_w / 2, sw)  # solid left of the breach
                right_w = length / 2 - (bx + bw / 2)
                box(right_w, S, S / 2, length / 2 - right_w / 2, sw)  # solid right of it
                box(bw + 0.4, S - DH, (DH + S) / 2, bx, "asphalt")  # lintel over the breach
                continue
            if has_door:
                side = (length - DW) / 2
                box(side, sill, z0 + sill / 2, -(DW + side) / 2, sw)
                box(side, sill, z0 + sill / 2, (DW + side) / 2, sw)
                box(DW + 2.4, head - DH, z0 + (DH + head) / 2, 0.0, "asphalt")  # lintel
            else:
                box(length, sill, z0 + sill / 2, 0.0, sw)
            box(length, S - head, z0 + (head + S) / 2, 0.0, sw)  # head band
            for i in range(bays + 1):  # pillars between windows
                c = -length / 2 + i * pitch
                pw = 2.2 if 0 < i < bays else 2.8
                c = max(-length / 2 + pw / 2, min(length / 2 - pw / 2, c))
                if has_door and abs(c) < 0.1:
                    for sgn in (-1, 1):  # door jambs instead of the centre pillar
                        box(1.2, DH, z0 + DH / 2, sgn * (DW / 2 + 0.6), sw)
                    continue
                box(pw, head - sill, z0 + (sill + head) / 2, c, sw)

    wall("x", -hy + T / 2, 2, door=True)  # front (faces -Y)
    wall("x", hy - T / 2, 1, breach=(7.0, 6.0))  # back, one storey, breached
    wall("y", -hx + T / 2, 2)
    wall("y", hx - T / 2, 2)
    b.box((W, D, 0.3), (0, 0, 0.15), swatch="asphalt")  # ground slab
    b.box((W, D, 0.6), (0, 0, S - 0.3), swatch="asphalt")  # first-floor slab, top at 10.0
    b.box((W + 0.4, 1.4, 0.4), (0, -hy + 0.5, 2 * S + 0.2), swatch="asphalt")  # front parapet
    for x in (-5.0, 5.0):  # interior pillars under the slab
        b.box((1.0, 1.0, S - 0.6), (x, 0, (S - 0.6) / 2), swatch="concrete")
    b.box((W - 2 * T, 0.3, 3.0), (0, -hy + T + 0.15, 1.5), swatch="white_d")  # interior liner (front)
    b.box((4.0, 2.0, 0.3), (-9.0, 3.0, 2.85), swatch="tan_d")  # desk top (Recover Logs)
    for x in (-10.8, -7.2):
        b.box((0.3, 1.8, 2.7), (x, 3.0, 1.35), swatch="tan_d")  # desk sides
    for x, h in ((-11, 3.6), (-4, 1.8), (12, 2.6)):  # broken stubs on the back wall
        b.box((3.0, T, h), (x, hy - T / 2, S + h / 2), swatch="white_d")
    for y, h in ((-6, 2.8), (2, 1.4), (7, 3.6)):  # and on the right wall top
        b.box((T, 3.0, h), (hx - T / 2, y, 2 * S + h / 2), swatch="white_d")
    for x, y in ((-7, hy + 0.7), (3, hy + 1.1), (12, hy + 0.5)):  # rebar
        b.cyl(0.07, 3.6, (x, y, S + 1.2), segs=4, rot=(30, 0, 0), swatch="rust")
    for x, y, sz in ((-13, -hy - 1.6, 2.0), (-10, -hy - 1.0, 1.2), (12, -hy - 1.8, 2.4), (hx + 1.0, 4, 1.6), (hx + 0.8, -5, 1.0)):
        b.box((sz, sz * 0.8, sz * 0.6), (x, y, sz * 0.3), rot=(0, 0, x * 7), swatch="concrete")  # rubble
    b.box((2.6, 0.12, 0.8), (-9, -hy - 0.5, 4.6), swatch="warning_orange")  # hazard sign at eye height
    b.box((2.2, 0.1, 0.6), (-9, -hy - 0.56, 4.6), swatch="dark_d")


def _container(b, body, rib, door):
    # ISO shipping container, real proportions at stud scale: 21.5 long (X), 8.7 wide, 9.3
    # tall (almost two characters). Doors on the +X end.
    L, Wd, H = 21.5, 8.7, 9.3
    b.box((L, Wd, H), (0, 0, H / 2), swatch=body)
    for sy in (-1, 1):  # corrugation ribs on the long sides
        for i in range(11):
            b.box((0.9, 0.3, H - 1.0), (-L / 2 + 1.9 + i * 1.77, sy * (Wd / 2 + 0.1), H / 2), swatch=rib)
    for sx, sy in CORNERS:
        b.box((0.5, 0.5, H + 0.2), (sx * (L / 2 - 0.2), sy * (Wd / 2 - 0.2), H / 2 + 0.1), swatch=rib)
    for sy in (-1, 1):  # door leaves + lock bars
        b.box((0.3, Wd / 2 - 0.5, H - 0.6), (L / 2 + 0.1, sy * (Wd / 4), H / 2), swatch=door)
        for k in (-1, 1):
            b.box((0.4, 0.3, H - 1.4), (L / 2 + 0.35, sy * (Wd / 4) + k * 1.1, H / 2), swatch="gun_d")
    b.box((L - 0.4, Wd - 0.4, 0.3), (0, 0, H + 0.1), swatch=rib)  # roof lip


@asset("env_container_olive", "Environment")
def container_olive(b):
    _container(b, "olive", "olive_d", "olive_l")


@asset("env_container_rust", "Environment")
def container_rust(b):
    _container(b, "rust", "tan_d", "red_d")


@asset("env_wreck_humvee", "Environment")
def wreck_humvee(b):
    # Burnt-out armoured truck: 16.5 long (X, nose toward -X), 7.8 wide, 6.5 tall; the hood is
    # chest-high cover. Blackened body, rust patches, turret ring on the cab roof.
    L, Wd = 16.5, 7.8
    b.box((L, Wd - 0.6, 2.4), (0, 0, 2.2), swatch="dark")  # hull
    b.box((5.6, Wd, 0.7), (-L / 2 + 2.8, 0, COVER_H - 0.35), swatch="dark_l")  # hood (top = COVER_H)
    b.box((7.0, Wd - 1.0, 3.1), (1.0, 0, 3.4 + 1.55), swatch="dark")  # cab
    b.box((0.2, Wd - 2.0, 1.8), (-2.55, 0, 5.3), swatch="dark_d")  # windscreen
    for sy in (-1, 1):
        b.box((2.4, 0.2, 1.6), (0.0, sy * (Wd / 2 - 0.45), 5.3), swatch="dark_d")  # side windows
        b.box((2.0, 0.2, 1.6), (3.0, sy * (Wd / 2 - 0.45), 5.3), swatch="dark_d")
    b.box((3.6, Wd - 0.8, 1.4), (L / 2 - 2.2, 0, 3.4 + 0.7), swatch="dark_l")  # rear bed
    b.cyl(1.7, 0.4, (1.0, 0, 6.7), segs=8, swatch="gun_d")  # turret ring
    b.cyl(0.12, 2.6, (2.2, 0, 7.0), segs=5, rot=(0, 90, 0), swatch="gun")  # gun barrel (along +X)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(1.5, 1.2, (sx * 5.2, sy * (Wd / 2 - 0.5), 1.5), segs=8, rot=(90, 0, 0), swatch="dark_d")
            b.cyl(0.6, 1.3, (sx * 5.2, sy * (Wd / 2 - 0.5), 1.5), segs=6, rot=(90, 0, 0), swatch="gun")
    b.box((0.6, Wd, 1.0), (-L / 2 - 0.2, 0, 2.0), swatch="gun_d")  # bumper
    b.box((2.4, 0.15, 1.2), (-3.0, -(Wd / 2 - 0.2), 2.4), swatch="rust")  # rust / scorch patches
    b.box((3.0, 0.15, 0.9), (4.0, (Wd / 2 - 0.2), 2.0), swatch="rust")
    b.box((1.4, 2.0, 0.15), (-5.0, 1.5, COVER_H + 0.02), swatch="rust")


@asset("env_twall", "Environment")
def twall(b):
    # Concrete blast wall (T-wall): 8 long, 12 tall (well over two characters, blocks sight),
    # 1 thick on a 2.6-wide foot. Chain them along a plateau edge or a road.
    b.box((8.0, 2.6, 1.0), (0, 0, 0.5), swatch="concrete")
    b.box((8.0, 1.0, 11.0), (0, 0, 1.0 + 5.5), swatch="concrete")
    b.box((8.0, 1.1, 0.4), (0, 0, 12.0 - 0.2), swatch="white_d")  # cap
    for x in (-2.4, 2.4):
        b.cyl(0.08, 0.6, (x, 0, 12.2), segs=4, swatch="rust")  # lifting loops
    b.box((3.0, 0.08, 0.9), (-1.5, -0.55, 3.2), swatch="warning_orange")  # stencil band
    b.box((2.4, 0.06, 0.5), (-1.5, -0.6, 3.2), swatch="dark_d")


@asset("env_hesco", "Environment")
def hesco(b):
    # Hesco gabion: 6 x 4.5 x 4.4 (a real 1.4 m unit), wire-mesh lines over the sand fill.
    H = 4.4
    b.box((6.0, 4.5, H), (0, 0, H / 2), swatch="tan")
    b.box((5.6, 4.1, 0.2), (0, 0, H + 0.08), swatch="tan_l")  # fill showing on top
    for x in (-2.0, 0.0, 2.0):
        for sy in (-1, 1):
            b.box((0.12, 0.12, H), (x, sy * 2.3, H / 2), swatch="dark_l")
    for sx in (-1, 1):
        for y in (-1.5, 1.5):
            b.box((0.12, 0.12, H), (sx * 3.05, y, H / 2), swatch="dark_l")
    for z in (1.5, 3.0):
        for sy in (-1, 1):
            b.box((6.1, 0.12, 0.12), (0, sy * 2.3, z), swatch="dark_l")
        for sx in (-1, 1):
            b.box((0.12, 4.6, 0.12), (sx * 3.05, 0, z), swatch="dark_l")


@asset("env_comm_tower", "Environment")
def comm_tower(b):
    # Lattice radio mast: 8 x 8 concrete base, 40 tall (eight characters), dish at 28, red
    # beacon on top. The Stage 1 landmark, visible from anywhere in the arena.
    H = 40.0
    Z0 = 1.5
    b.box((8.0, 8.0, Z0), (0, 0, Z0 / 2), swatch="concrete")
    bh, th = 2.6, 1.0  # leg half-spacing at base / top

    def half(z):
        return bh + (th - bh) * (z - Z0) / (H - Z0)

    leg_len = math.hypot(H - Z0, (bh - th) * math.sqrt(2))
    for sx, sy in CORNERS:
        tilt = math.degrees(math.atan2(bh - th, H - Z0))
        rx = sy * tilt  # rotation about X tips +Z toward -Y, so +Y legs lean toward -Y
        ry = -sx * tilt  # rotation about Y tips +Z toward +X
        b.box((0.4, 0.4, leg_len), (sx * (bh + th) / 2, sy * (bh + th) / 2, (H + Z0) / 2), rot=(rx, ry, 0), swatch="gun_d")
    for z in (6.0, 11.0, 16.0, 21.0, 26.0, 31.0, 36.0):
        h = half(z)
        b.box((2 * h + 0.4, 0.2, 0.2), (0, h, z), swatch="gun")
        b.box((2 * h + 0.4, 0.2, 0.2), (0, -h, z), swatch="gun")
        b.box((0.2, 2 * h + 0.4, 0.2), (h, 0, z), swatch="gun")
        b.box((0.2, 2 * h + 0.4, 0.2), (-h, 0, z), swatch="gun")
    b.box((4.4, 4.4, 0.3), (0, 0, 30.0), swatch="gun_d")  # service platform
    b.cyl(2.4, 0.35, (half(28.0) + 1.6, 0, 28.0), segs=10, rot=(0, 70, 0), swatch="white")  # dish, facing +X
    b.box((0.3, 0.3, 2.2), (half(28.0) + 0.6, 0, 28.0), rot=(0, 70, 0), swatch="gun_d")  # dish arm
    b.box((2.2, 2.2, 0.4), (0, 0, H + 0.2), swatch="gun_d")  # cap
    b.cyl(0.08, 4.0, (0, 0, H + 2.4), segs=5, swatch="gun_l")  # whip antenna
    b.cyl(0.35, 0.4, (0, 0, H + 4.5), segs=6, swatch="red_l")  # beacon
    b.box((1.6, 1.0, 1.2), (3.2, -3.0, Z0 + 0.6), swatch="olive_d")  # generator box
    b.box((1.2, 0.6, 1.0), (-3.0, 3.0, Z0 + 0.5), swatch="gun")  # junction box


@asset("env_tent", "Environment")
def tent(b):
    # GP-medium style olive tent: 16 long (X) x 12 wide, 4.5-stud walls, ridge at 8. Door flap
    # on the -X end at DOOR_H. Solid in game.
    L, Wd, WALL, RIDGE = 16.0, 12.0, 4.5, 8.0
    b.box((L, Wd, WALL), (0, 0, WALL / 2), swatch="olive")
    rise = RIDGE - WALL
    # Builder.wedge collapses its +X top edge, so after a +90 yaw the collapsed edge is at +Y
    # and the roof rises toward the ridge at y = 0.
    b.wedge((Wd / 2, L, rise), (0, Wd / 4, WALL + rise / 2), rot=(0, 0, 90), swatch="olive_d")
    b.wedge((Wd / 2, L, rise), (0, -Wd / 4, WALL + rise / 2), rot=(0, 0, -90), swatch="olive_d")
    b.box((L + 0.6, 0.3, 0.3), (0, 0, RIDGE), swatch="tan_d")  # ridge pole
    for sx in (-1, 1):
        b.box((0.3, 0.3, RIDGE + 0.6), (sx * (L / 2 + 0.1), 0, (RIDGE + 0.6) / 2), swatch="tan_d")  # end poles
    b.box((0.2, DOOR_W, DOOR_H - 0.8), (-L / 2 - 0.05, 0, (DOOR_H - 0.8) / 2), swatch="dark_d")  # door flap
    for y in (-4.5, 4.5):  # guy-rope stakes
        for sx in (-1, 1):
            b.box((0.2, 0.2, 0.6), (sx * (L / 2 + 1.5), y, 0.3), swatch="tan_d")


@asset("env_checkpoint", "Environment")
def checkpoint(b):
    # Guard booth (6 x 6, 9.5 tall, counter window at SILL..HEAD) with a 14-stud striped boom
    # arm reaching along +X across a road. Booth faces -Y; solid in game.
    S = 6.0
    b.box((S, S, SILL), (0, 0, SILL / 2), swatch="concrete")
    for sx, sy in CORNERS:
        b.box((0.6, 0.6, HEAD - SILL), (sx * (S / 2 - 0.3), sy * (S / 2 - 0.3), (SILL + HEAD) / 2), swatch="white_d")
    b.box((S, 0.3, HEAD - SILL), (0, S / 2 - 0.15, (SILL + HEAD) / 2), swatch="white_d")  # solid back wall
    b.box((S, S, 9.0 - HEAD), (0, 0, (HEAD + 9.0) / 2), swatch="white_d")  # head band
    b.box((S + 1.4, S + 1.4, 0.5), (0, 0, 9.25), swatch="asphalt")  # roof
    b.box((1.8, 0.1, 0.9), (0, -S / 2 - 0.06, 8.3), swatch="red")  # STOP sign strip
    b.box((0.8, 0.8, COVER_H), (S / 2 + 1.2, -2.0, COVER_H / 2), swatch="gun_d")  # boom post
    b.box((0.9, 0.9, 0.9), (S / 2 + 1.2, -2.0, COVER_H + 0.2), swatch="gun")  # hinge box
    for i in range(4):  # striped arm, 14 long
        b.box((3.5, 0.45, 0.45), (S / 2 + 1.2 + 1.75 + i * 3.5, -2.0, COVER_H + 0.2), swatch="red" if i % 2 else "white")
    b.box((0.3, 0.3, COVER_H - 0.6), (S / 2 + 1.2 + 14.0, -2.0, (COVER_H - 0.6) / 2), swatch="gun_d")  # rest post


@asset("env_dead_tree", "Environment")
def dead_tree(b):
    # Dead leafless tree, 14 tall (about three characters): tapering trunk, four bare limbs.
    b.cyl(0.75, 10.0, (0, 0, 5.0), segs=6, r2=0.4, swatch="dark_l")
    b.box((2.4, 2.4, 0.5), (0, 0, 0.25), rot=(0, 0, 20), swatch="dark")  # root mound
    for z, phi, psi, ln in ((6.5, 55, 20, 5.5), (8.0, 45, 140, 5.0), (9.3, 35, 260, 4.5), (9.9, 15, 60, 4.2)):
        # branch direction after rot (phi about X, then psi about Z): (sinφ sinψ, -sinφ cosψ, cosφ)
        p, s = math.radians(phi), math.radians(psi)
        d = (math.sin(p) * math.sin(s), -math.sin(p) * math.cos(s), math.cos(p))
        c = (d[0] * ln / 2, d[1] * ln / 2, z + d[2] * ln / 2)
        b.cyl(0.32, ln, c, segs=5, r2=0.1, rot=(phi, 0, psi), swatch="dark_l")


@asset("env_lamp_post", "Environment")
def lamp_post(b):
    # Street light: 13 tall pole on a concrete footing, arm reaching 3 studs over the road,
    # dead lamp head. Lines the main road.
    b.box((1.2, 1.2, 0.5), (0, 0, 0.25), swatch="concrete")
    b.cyl(0.25, 12.5, (0, 0, 0.5 + 6.25), segs=6, swatch="gun_d")
    b.cyl(0.18, 3.4, (1.6, 0, 12.6), segs=6, rot=(0, 90, 0), swatch="gun_d")  # arm along +X
    b.box((2.2, 0.9, 0.5), (3.2, 0, 12.5), swatch="gun")
    b.box((1.8, 0.6, 0.1), (3.2, 0, 12.2), swatch="white_d")  # dead lens


@asset("env_bus", "Environment")
def bus(b):
    # Transit bus (docs/LEVELS.md B): 42 long (X, nose toward -X), 10 wide, 12.5 tall. Tall
    # enough to stop a Hocker's lob and a lane wide when parked across a road: the Delta bus
    # line and the Mile 14 jam. Box collision in game.
    L, Wd, H = 42.0, 10.0, 12.5
    FLOOR = 2.6
    b.box((L, Wd, H - FLOOR - 0.4), (0, 0, FLOOR + (H - FLOOR - 0.4) / 2), swatch="white_d")  # body
    b.box((L - 0.6, Wd - 0.6, 0.4), (0, 0, H - 0.2), swatch="white")  # roof
    b.box((3.0, 3.0, 0.3), (5.0, 0, H + 0.1), swatch="white_d")  # roof hatch
    for sy in (-1, 1):
        b.box((L - 6.0, 0.2, 3.2), (1.0, sy * (Wd / 2 + 0.08), 9.2), swatch="dark_d")  # window band
        for i in range(8):  # window pillars
            b.box((0.3, 0.26, 3.2), (-L / 2 + 5.0 + i * 4.5, sy * (Wd / 2 + 0.1), 9.2), swatch="white_d")
        b.box((L - 2.0, 0.2, 0.9), (0.5, sy * (Wd / 2 + 0.06), 5.6), swatch="gun")  # livery stripe
        b.box((L - 2.0, 0.2, 1.4), (0.5, sy * (Wd / 2 + 0.06), FLOOR + 0.7), swatch="gun_d")  # skirt
    b.box((3.0, 0.24, 7.0), (-L / 2 + 6.0, Wd / 2 + 0.1, FLOOR + 3.5), swatch="dark_d")  # door (right side)
    b.box((0.12, 0.3, 7.0), (-L / 2 + 6.0, Wd / 2 + 0.12, FLOOR + 3.5), swatch="gun_l")  # door split
    b.box((0.2, Wd - 1.2, 4.6), (-L / 2 - 0.08, 0, 8.4), swatch="dark_d")  # windscreen
    b.box((0.14, 6.0, 1.2), (-L / 2 - 0.14, 0, 11.4), swatch="dark")  # destination sign
    b.box((0.06, 3.2, 0.5), (-L / 2 - 0.24, 0, 11.4), swatch="brass")  # its lit text
    b.box((0.2, Wd - 2.0, 2.8), (L / 2 + 0.08, 0, 9.4), swatch="dark_d")  # rear window
    for sx in (-1, 1):
        b.box((0.5, Wd, 1.2), (sx * (L / 2 + 0.2), 0, 3.0), swatch="gun_d")  # bumpers
        for sy in (-1, 1):
            b.cyl(2.0, 1.4, (sx * 14.0, sy * (Wd / 2 - 0.7), 2.0), segs=10, rot=(90, 0, 0), swatch="dark_d")  # tyres
            b.cyl(0.9, 1.5, (sx * 14.0, sy * (Wd / 2 - 0.7), 2.0), segs=8, rot=(90, 0, 0), swatch="gun")  # hubs
    for sy in (-1, 1):
        b.box((0.4, 0.5, 1.6), (-L / 2 + 1.0, sy * (Wd / 2 + 0.2), 9.0), swatch="dark")  # mirrors
    b.box((6.0, 0.16, 2.0), (10.0, -(Wd / 2 + 0.1), 4.6), swatch="rust")  # scorch and rust
    b.box((4.0, 0.16, 1.4), (-8.0, (Wd / 2 + 0.1), 7.2), swatch="rust")
    b.box((2.4, 0.12, 0.9), (-L / 2 + 12.0, -(Wd / 2 + 0.14), 9.0), swatch="dark_d")  # one window blown out


# ------------------------------------------------------------------ Delta rework pieces
# Map pieces and props for the enterable Delta (docs/LEVELS.md section A, 2026-11-07). Every
# piece is built against CHAR_H; sizes come from the level sheet's prop catalogue (S = solid,
# D = decoration, T = see-through). Collision: Box unless MeshAssets lists colliders.


@asset("env_hesco_tall", "Environment")
def hesco_tall(b):
    # Two stacked hesco units with a joint band, 8.7 tall: a Walker (ClimbHeight 5) can't take
    # it, a Runner and a player can mantle it. Fabric surface in game (one material).
    H = 4.35
    for k in range(2):
        z0 = k * H
        b.box((6.0, 4.5, H), (0, 0, z0 + H / 2), swatch="tan")
    b.box((6.2, 4.7, 0.3), (0, 0, H), swatch="tan_d")  # joint band
    b.box((5.6, 4.1, 0.2), (0, 0, 2 * H + 0.08), swatch="tan_l")  # fill showing on top
    for x in (-2.0, 0.0, 2.0):  # wire lines proud of the fabric
        for sy in (-1, 1):
            b.box((0.12, 0.12, 2 * H), (x, sy * 2.3, H), swatch="dark_l")
    for sx in (-1, 1):
        for y in (-1.5, 1.5):
            b.box((0.12, 0.12, 2 * H), (sx * 3.05, y, H), swatch="dark_l")
    for z in (1.5, 3.0, 5.85, 7.35):
        for sy in (-1, 1):
            b.box((6.1, 0.12, 0.12), (0, sy * 2.3, z), swatch="dark_l")
        for sx in (-1, 1):
            b.box((0.12, 4.6, 0.12), (sx * 3.05, 0, z), swatch="dark_l")


@asset("env_crib_stack", "Environment")
def crib_stack(b):
    # Concrete cribbing a T-wall is lifted onto: 1.2 wide (X), 2.6 deep, 2.8 tall. Two under
    # one T-wall leave a 5.6 x 2.8 crawl slot (the Gate "Scrapes"). Concrete surface in game.
    for k in range(7):
        z = k * 0.4 + 0.2
        sw = "concrete" if k % 2 == 0 else "asphalt"
        if k % 2 == 0:
            for x in (-0.4, 0.4):
                b.box((0.4, 2.6, 0.4), (x, 0, z), swatch=sw)
        else:
            for y in (-1.1, 1.1):
                b.box((1.2, 0.4, 0.4), (0, y, z), swatch=sw)


@asset("env_deck_plate", "Environment")
def deck_plate(b):
    # Steel road plate laid between roofs: 12 x 5 x 0.3 with raised cleats. DiamondPlate in game.
    b.box((12.0, 5.0, 0.25), (0, 0, 0.125), swatch="gun")
    for x in (-4.5, -2.7, -0.9, 0.9, 2.7, 4.5):
        b.box((0.3, 4.6, 0.08), (x, 0, 0.29), swatch="gun_l")


@asset("prop_cot", "Props")
def cot(b):
    # Field cot 6.5 x 3 x 2.2 (S, vaultable): legs, rails, canvas, blanket, pillow. ~110 tris.
    for sx, sy in CORNERS:
        b.box((0.25, 0.25, 1.6), (sx * 3.0, sy * 1.3, 0.8), swatch="dark_l")
    for sy in (-1, 1):
        b.box((6.5, 0.25, 0.25), (0, sy * 1.35, 1.6), swatch="dark_l")
    b.box((6.3, 2.7, 0.15), (0, 0, 1.68), swatch="olive_d")  # canvas
    b.box((3.2, 2.6, 0.3), (0.9, 0, 1.9), swatch="foliage")  # blanket
    b.box((1.2, 2.0, 0.35), (-2.4, 0, 1.92), swatch="white_d")  # pillow


@asset("prop_generator", "Props")
def generator(b):
    # Towed generator 8 x 4.5 x 5 (S): skid, housing, exhaust stack, control panel. ~150 tris.
    b.box((8.0, 4.5, 0.4), (0, 0, 0.2), swatch="dark")
    b.box((7.0, 4.0, 3.6), (0, 0, 0.4 + 1.8), swatch="gun_d")
    b.box((7.2, 0.1, 1.2), (0, -2.02, 2.4), swatch="gun")  # louvre band
    for x in (-2.4, -1.2, 0.0, 1.2, 2.4):
        b.box((0.3, 0.12, 1.0), (x, -2.08, 2.4), swatch="dark_d")  # louvres
    b.box((0.12, 1.6, 1.2), (3.56, 0.6, 2.6), swatch="dark_d")  # control panel
    b.box((0.08, 0.3, 0.3), (3.62, 0.3, 2.9), swatch="warning_orange")  # its one lamp
    b.cyl(0.4, 1.2, (-2.4, 1.0, 4.6), segs=6, swatch="dark_d")  # exhaust stack
    b.cyl(0.25, 0.4, (-2.4, 1.0, 4.9), segs=6, swatch="rust")
    b.box((1.0, 1.0, 0.2), (2.2, -1.2, 4.1), swatch="rust")  # fuel cap plate


@asset("prop_light_tower", "Props")
def light_tower(b):
    # Trailer light tower 4 x 4 x 18 (S): trailer, generator box, three-stage mast, four heads.
    b.box((4.0, 3.0, 0.5), (0, 0, 1.0), swatch="dark")  # trailer bed
    for sy in (-1, 1):
        b.cyl(0.8, 0.5, (0.6, sy * 1.7, 0.8), segs=8, rot=(90, 0, 0), swatch="dark_d")  # wheels
    b.box((0.4, 0.4, 0.8), (-1.6, 0, 0.4), swatch="gun_d")  # jack leg
    b.box((2.2, 2.0, 1.8), (-0.6, 0, 2.15), swatch="olive_d")  # generator box
    b.cyl(0.32, 6.0, (1.2, 0, 4.0), segs=6, swatch="gun_d")  # mast stages
    b.cyl(0.26, 6.0, (1.2, 0, 9.6), segs=6, swatch="gun")
    b.cyl(0.2, 5.6, (1.2, 0, 15.0), segs=6, swatch="gun_l")
    b.box((3.0, 0.3, 0.3), (1.2, 0, 17.6), swatch="gun_d")  # crossbar
    for x in (-0.9, 0.9):
        for sy in (-1, 1):
            b.box((0.9, 0.5, 0.7), (1.2 + x, sy * 0.45, 17.6), swatch="dark")  # lamp housings
            b.box((0.8, 0.06, 0.6), (1.2 + x, sy * 0.72, 17.6), swatch="brass_l")  # lenses


@asset("prop_fuel_bladder", "Props")
def fuel_bladder(b):
    # Collapsible fuel bladder 12 x 8 x 2.9 (S, vaultable): pillow tank, top panel, valve.
    b.box((11.0, 7.0, 2.1), (0, 0, 1.05), swatch="olive_d")
    b.box((9.0, 5.0, 0.5), (0, 0, 2.3), swatch="olive")
    for x in (-3.5, 0.0, 3.5):
        b.box((0.3, 7.4, 2.2), (x, 0, 1.1), swatch="dark")  # tie-down straps
    b.cyl(0.4, 0.5, (4.0, 2.0, 2.75), segs=6, swatch="gun")  # filler valve
    b.box((0.5, 0.5, 0.15), (4.0, 2.0, 2.95), swatch="red")  # its cap


@asset("prop_pallet", "Props")
def pallet(b):
    # Wooden pallet 4 x 4 x 0.6 (S): three runners, seven top boards. ~160 tris.
    for y in (-1.7, 0.0, 1.7):
        b.box((4.0, 0.5, 0.2), (0, y, 0.1), swatch="tan_d")
    for y in (-1.7, 0.0, 1.7):
        for x in (-1.6, 0.0, 1.6):
            b.box((0.5, 0.5, 0.25), (x, y, 0.32), swatch="tan_d")  # blocks
    for i in range(7):
        b.box((0.45, 4.0, 0.12), (-1.8 + i * 0.6, 0, 0.51), swatch="tan")


@asset("prop_body_bag", "Props")
def body_bag(b):
    # Body bag 6.5 x 2.4 x 1 (D, no collision): dark bag, zip strip, tag.
    b.box((5.4, 2.2, 0.9), (-0.5, 0, 0.45), swatch="dark")
    b.wedge((1.2, 2.2, 0.9), (2.8, 0, 0.45), swatch="dark")  # tapered foot
    b.box((5.8, 0.1, 0.06), (-0.3, 0, 0.92), swatch="gun_l")  # zip
    b.box((0.5, 0.4, 0.05), (-2.6, 0.6, 0.92), swatch="white")  # tag


@asset("prop_dumpster", "Props")
def dumpster(b):
    # Steel dumpster 7 x 4 x 4.4 (S): a Walker's step onto a 9-stud roof. ~130 tris.
    b.box((7.0, 4.0, 3.6), (0, 0, 0.5 + 1.8), swatch="olive_d")
    for sx, sy in CORNERS:
        b.cyl(0.25, 0.5, (sx * 2.9, sy * 1.6, 0.25), segs=6, swatch="dark_d")  # castors
    for sx in (-1, 1):
        b.box((3.4, 4.1, 0.3), (sx * 1.75, 0, 4.25), swatch="dark_l")  # lid halves
        b.box((0.3, 0.6, 1.2), (sx * 3.6, 0, 1.6), swatch="gun_d")  # fork pockets
    b.box((2.0, 0.12, 0.8), (-1.2, -2.06, 2.4), swatch="rust")  # rust patch
    b.box((1.4, 0.12, 0.5), (1.8, 2.06, 2.0), swatch="white_d")  # stencil


@asset("prop_plank", "Props")
def plank(b):
    # Scaffold plank 10 x 2 x 0.4 (S): bridges roof to roof. ~50 tris.
    for y in (-0.5, 0.5):
        b.box((10.0, 0.9, 0.3), (0, y, 0.15), swatch="tan_d")
    for x in (-4.0, 4.0):
        b.box((0.3, 2.0, 0.4), (x, 0, 0.2), swatch="dark_l")  # cleats


@asset("prop_civilian_car", "Props")
def civilian_car(b):
    # Abandoned sedan 15 x 7 x 4.8 (S), nose toward -X: body, cabin, glass, wheels, lights.
    L, Wd = 15.0, 6.6
    b.box((L, Wd, 1.8), (0, 0, 1.9), swatch="white_d")  # body
    b.box((7.5, 6.0, 2.0), (-0.3, 0, 3.8), swatch="white_d")  # cabin
    b.box((0.2, 5.2, 1.6), (-4.1, 0, 3.8), rot=(0, -25, 0), swatch="dark_d")  # windscreen
    b.box((0.2, 5.2, 1.5), (3.5, 0, 3.8), rot=(0, 20, 0), swatch="dark_d")  # rear glass
    for sy in (-1, 1):
        b.box((6.8, 0.2, 1.4), (-0.3, sy * 3.05, 3.8), swatch="dark_d")  # side glass
        b.box((0.4, 0.5, 0.4), (-3.6, sy * 3.5, 3.4), swatch="dark")  # mirrors
        for sx in (-1, 1):
            b.cyl(1.1, 0.9, (sx * 4.8, sy * (Wd / 2 - 0.3), 1.1), segs=8, rot=(90, 0, 0), swatch="dark_d")
            b.cyl(0.5, 1.0, (sx * 4.8, sy * (Wd / 2 - 0.3), 1.1), segs=6, rot=(90, 0, 0), swatch="gun_l")
        b.box((0.3, 1.2, 0.5), (-L / 2 - 0.05, sy * 2.2, 2.2), swatch="white_l")  # headlights
        b.box((0.3, 1.2, 0.5), (L / 2 + 0.05, sy * 2.2, 2.2), swatch="red")  # tail lights
    for sx in (-1, 1):
        b.box((0.5, Wd + 0.2, 0.6), (sx * (L / 2 + 0.1), 0, 1.4), swatch="dark")  # bumpers
    b.box((4.6, 0.2, 0.9), (2.0, -(Wd / 2 + 0.05), 2.0), swatch="rust")  # rust / scorch
    b.box((1.6, 0.16, 0.6), (-4.0, (Wd / 2 + 0.05), 2.3), swatch="dark_d")  # dent


@asset("prop_portable_toilet", "Props")
def portable_toilet(b):
    # Portable toilet 4 x 4 x 8 (S, climbable): blue cabin, door, vent, white roof.
    b.box((4.2, 4.2, 0.4), (0, 0, 0.2), swatch="dark")
    b.box((4.0, 4.0, 7.2), (0, 0, 0.4 + 3.6), swatch="shield_blue")
    b.box((2.4, 0.12, 6.4), (0, -2.04, 3.8), swatch="dark_l")  # door
    b.box((1.6, 0.1, 0.5), (0, -2.1, 6.4), swatch="white_d")  # vent
    b.box((0.2, 0.2, 0.5), (0.9, -2.14, 3.6), swatch="gun")  # handle
    b.box((4.3, 4.3, 0.4), (0, 0, 7.8), swatch="white_d")  # roof
    b.cyl(0.3, 0.5, (1.2, 1.2, 8.2), segs=6, swatch="white")  # roof vent


@asset("prop_chainlink_panel", "Props")
def chainlink_panel(b):
    # Chain-link fence panel 12 x 7 (T: solid, see-through, bullets pass). Two posts, two rails,
    # a wire grid of thin boxes. ~270 tris.
    for sx in (-1, 1):
        b.cyl(0.15, 7.0, (sx * 5.9, 0, 3.5), segs=6, swatch="gun_d")
    for z in (0.3, 6.9):
        b.box((12.0, 0.12, 0.12), (0, 0, z), swatch="gun_d")
    for i in range(11):
        b.box((0.05, 0.05, 6.6), (-5.0 + i * 1.0, 0, 3.6), swatch="gun_l")
    for z in (1.3, 2.3, 3.3, 4.3, 5.3, 6.3):
        b.box((12.0, 0.05, 0.05), (0, 0, z), swatch="gun_l")


@asset("prop_concertina", "Props")
def concertina(b):
    # Concertina wire coil 12 x 3 x 3 (T): a helix of 24 thin segments along X. ~290 tris.
    r = 1.4
    turns, segs = 3, 24
    pts = []
    for i in range(segs + 1):
        t = i / segs
        ang = t * turns * 2 * math.pi
        pts.append(Vector((-6.0 + 12.0 * t, math.cos(ang) * r, math.sin(ang) * r + 1.5)))
    for p0, p1 in zip(pts[:-1], pts[1:]):
        d = p1 - p0
        length = d.length
        pitch = -math.degrees(math.asin(d.z / length))
        yaw = math.degrees(math.atan2(d.y, d.x))
        b.box((length, 0.1, 0.1), ((p0 + p1) / 2), rot=(0, pitch, yaw), swatch="gun_l")


# ------------------------------------------------------------------ Infected limb sets
# One mesh per R15 limb (left/right share a mesh), per Infected type. EnemyService swaps the
# default R15 limb MeshParts for these at template build (same Name/Size/CFrame, attachments
# moved over, so the default walk animation keeps working). Each limb's bounds equal the R15
# limb size (Blender X width, Y depth, Z height; centred at the origin) so the MeshPart Size
# fit is distortion-free; small front/top details may protrude ~0.1 (0.2 on the Brute).
# Sheets: docs/CHARACTERS.md (2026-11-07). Skin v2 (art director, 2026-11-07): skin is the
# pallor / flesh / bruise / wound / pus rows, never green; `rebuilt` (pale scar tissue, bone)
# and `strain` (caustic fluid) stay the strain's two colours, strain only on open seams and
# the Hocker's throat; eyes are milky `pus_l` set in a `wound` rim (`Limb.eyes`).
# Limb geometry v2: healthy limbs are octagonal tapered segments (70-80% of the box) under a
# rounded joint cap, so a bent joint swings clean through the limb above it; swollen limbs
# fill the box. Pustules, clusters, lesions and blotches are `Limb` helpers.
R15_LIMB = {
    "head": (1.16, 1.16, 1.18),
    "upper_torso": (1.94, 1.0, 1.70),
    "lower_torso": (1.99, 1.0, 0.40),
    "upper_arm": (1.0, 1.0, 1.24),
    "lower_arm": (1.0, 1.0, 1.12),
    "hand": (0.98, 1.03, 0.32),
    "upper_leg": (0.99, 0.97, 1.36),
    "lower_leg": (0.99, 0.97, 1.30),
    "foot": (1.01, 1.0, 0.31),
}

# R15 limb centres (HumanoidRootPart centre at z=0, ground at -3.19) for the assembled
# preview figures and the skinned body's detail pieces. Measured on a stock R15 rig in
# Studio (2026-11-07, same snippet as R15_JOINTS below): the limbs overlap at the joints.
R15_POSE = {
    "head": (0, 0, 1.674), "upper_torso": (0, 0, 0.25), "lower_torso": (0, 0, -0.80),
    "upper_arm": (1.47, 0, 0.428), "lower_arm": (1.47, 0, -0.22), "hand": (1.47, 0, -0.85),
    "upper_leg": (0.5, 0, -1.471), "lower_leg": (0.5, 0, -2.334), "foot": (0.5, 0, -3.036),
}

# Whole-body triangle caps (15 limbs, both sides), art director v2. The build prints each body.
BODY_TRI_CAP = {"walker": 1600, "runner": 2000, "brute": 2400, "hocker": 2200, "warden": 5000}

OCT = (0, 0, 22.5)  # octagon flats face the limb box sides
FACE_NORMAL = {
    "front": (0, -1, 0), "back": (0, 1, 0), "left": (-1, 0, 0), "right": (1, 0, 0),
    "top": (0, 0, 1), "bottom": (0, 0, -1),
}


class Limb:
    """Primitive helpers offset to one limb's origin. With `bone` set (skinned bodies) every
    primitive it builds is skinned 100% to that bone."""

    def __init__(self, b, o=(0, 0, 0), bone=None):
        self.b, self.o, self.bone = b, o, bone

    def _at(self, loc):
        return (self.o[0] + loc[0], self.o[1] + loc[1], self.o[2] + loc[2])

    def _skin(self, verts):
        if self.bone:
            self.b.weight(verts, {self.bone: 1.0})
        return verts

    def box(self, size, loc=(0, 0, 0), swatch="gun", rot=None):
        return self._skin(self.b.box(size, self._at(loc), rot=rot, swatch=swatch))

    def cyl(self, r, depth, loc=(0, 0, 0), swatch="gun", rot=None, segs=8, r2=None):
        return self._skin(self.b.cyl(r, depth, self._at(loc), segs=segs, r2=r2, rot=rot, swatch=swatch))

    def ico(self, r, loc=(0, 0, 0), swatch="gun", subdiv=1):
        return self._skin(self.b.ico(r, self._at(loc), subdiv=subdiv, swatch=swatch))

    def prism(self, rings, swatch="gun", loc=(0, 0, 0), **kw):
        rings_verts = self.b.prism(rings, swatch=swatch, loc=self._at(loc), **kw)
        for ring in rings_verts:
            self._skin(ring)
        return rings_verts

    def taper(self, size, loc=(0, 0, 0), bottom=0.75, swatch="gun", sides=8):
        """A limb segment that narrows to `bottom` of its width at the bottom: the tapered
        forearm/shin of the art sheet (70-80%), octagonal so the corners never swing out."""
        W, D, H = size
        return self.prism([(-H / 2, W / 2 * bottom, D / 2 * bottom), (H / 2, W / 2, D / 2)], swatch=swatch, loc=loc, sides=sides)

    def pad(self, r, depth, loc=(0, 0, 0), swatch="gun"):
        """A joint cap: a short cylinder across the limb (axis X) at the joint, so the round
        end stays filled when the next limb bends away (the Chosen's elbow/knee pad)."""
        return self.cyl(r, depth, loc, rot=(0, 90, 0), segs=8, swatch=swatch)

    # --- limb shapes (geometry v2)
    def oct(self, r, h, loc=(0, 0, 0), swatch="gun", r_top=None):
        """Octagonal limb segment along Z: radius `r` at the bottom, `r_top` at the top (a
        taper). Flats face the box sides; r 0.54 fills a 1.0 box, 0.36-0.42 is a healthy limb."""
        self.cyl(r, h, loc, swatch=swatch, segs=8, r2=r_top, rot=OCT)

    def cap(self, r, loc=(0, 0, 0), swatch="rebuilt"):
        """Joint cap: a knob at the top of a lower limb, or a rounded shoulder on an upper arm,
        so the joint swings clean through the limb above it instead of a box corner."""
        self.ico(r, loc, swatch=swatch, subdiv=1)

    def hip_inset(self, r_leg, swatch, r_hip=0.36, z_top=0.68, h=0.46):
        """Narrow collar at the top of an upper leg so the thigh clears the pelvis when it swings."""
        self.oct(r_leg, h, (0, 0, z_top - h / 2), swatch=swatch, r_top=r_hip)

    # --- skin damage
    def _flat(self, w, h, t, face):
        n = FACE_NORMAL[face]
        if n[1]:
            return (w, t, h), n
        if n[0]:
            return (t, w, h), n
        return (w, h, t), n

    def blotch(self, w, h, loc, face="front", swatch="bruise"):
        """A flat discolouration on one face of a limb (a bruise, a flush)."""
        size, _ = self._flat(w, h, 0.06, face)
        self.box(size, loc, swatch=swatch)

    def lesion(self, w, h, loc, face="front", rim="flesh_d", core="wound"):
        """An open lesion: an inflamed rim round a raw red core, flat on one face of a limb."""
        size, n = self._flat(w, h, 0.08, face)
        self.box(size, loc, swatch=rim)
        core_size, _ = self._flat(w * 0.55, h * 0.55, 0.08, face)
        self.box(core_size, (loc[0] + n[0] * 0.03, loc[1] + n[1] * 0.03, loc[2] + n[2] * 0.03), swatch=core)

    def boil(self, r, loc, n=(0, -1, 0), swatch="pus", head=True):
        """A pustule: a pus dome with a paler head pushed out along `n` (the surface normal)."""
        self.ico(r, loc, swatch=swatch, subdiv=1 if r >= 0.18 else 0)
        if head:
            k = r * 0.7
            self.ico(r * 0.45, (loc[0] + n[0] * k, loc[1] + n[1] * k, loc[2] + n[2] * k), swatch="pus_l", subdiv=0)

    def cluster(self, count, r, loc, n=(0, -1, 0), spread=0.25, swatch="pus"):
        """`count` boils packed round `loc` on the face whose normal is `n` (a fixed spiral)."""
        nx, ny, nz = n
        u = (ny, -nx, 0.0) if abs(nz) < 0.9 else (1.0, 0.0, 0.0)  # cross(n, z) or x
        ul = math.sqrt(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
        u = (u[0] / ul, u[1] / ul, u[2] / ul)
        v = (ny * u[2] - nz * u[1], nz * u[0] - nx * u[2], nx * u[1] - ny * u[0])  # cross(n, u)
        for i in range(count):
            a = i * 2.3999632  # golden angle: no two boils line up
            d = spread * math.sqrt((i + 0.5) / count)
            ri = r * (1.0 - 0.3 * (i % 3) / 2)
            c, s = math.cos(a) * d, math.sin(a) * d
            self.boil(ri, (loc[0] + u[0] * c + v[0] * s, loc[1] + u[1] * c + v[1] * s, loc[2] + u[2] * c + v[2] * s), n, swatch)

    def eyes(self, z=0.04, y=-0.61, dx=0.25, size=(0.2, 0.1, 0.14), rim="wound"):
        """Milky eyes: a `pus_l` facet set in a `wound` rim (canon 2026-11-07; never green).
        A wound-red face passes a darker rim so the eyes still read."""
        for x in (-dx, dx):
            self.box((size[0] + 0.1, size[1] - 0.02, size[2] + 0.1), (x, y + 0.01, z), swatch=rim)
            self.box(size, (x, y, z), swatch="pus_l")

    def shoe(self, swatch="dark"):
        W, D, H = R15_LIMB["foot"]
        self.box((W, D, 0.23), (0, 0, 0.04), swatch=swatch)
        self.box((W, D, 0.08), (0, 0, -0.115), swatch="dark_d")


# --- Walker: a civilian from the pens, the strain's first day. Pale bruised skin (pallor), a
# cheek lesion, a boil cluster under the jaw, swollen flushed hands; tan jacket over a white
# shirt torn open on the dropped (right, +X) shoulder over a rebuilt rib slab; a foliage blanket
# tied round the waist like a shawl; Delta screening band on the wrist; closed seams, no blood.
def walker_limb(L, limb, skin="pallor"):
    W, D, H = R15_LIMB[limb]
    if limb == "head":
        L.box((W, D, H), swatch=skin)
        L.box((1.2, 1.2, 0.26), (0, 0.02, 0.5), swatch="dark")  # hair cap
        L.box((0.3, 1.1, 0.5), (-0.46, 0.06, 0.2), swatch="dark")  # long on one side only
        L.box((1.0, 0.1, 0.1), (0, -0.6, 0.26), swatch="dark_d")  # brow
        L.eyes()
        L.box((0.16, 0.14, 0.26), (0, -0.62, -0.08), swatch=skin)  # nose
        L.box((0.5, 0.1, 0.06), (0, -0.6, -0.32), swatch="dark_d")  # closed mouth
        L.box((0.1, 0.1, 0.5), (0.3, -0.58, -0.34), swatch="rebuilt")  # jaw seam
        L.box((0.04, 0.12, 0.42), (0.3, -0.58, -0.34), swatch="strain_d")  # the seam weeps
        L.box((0.14, 0.1, 0.14), (0.3, -0.6, -0.1), swatch="rebuilt_l")  # seam knot
        L.lesion(0.28, 0.24, (-0.34, -0.58, -0.17))  # cheek lesion
        L.blotch(0.56, 0.36, (0.58, -0.1, 0.0), face="right", swatch="bruise")  # bruise, temple to cheekbone
        L.cluster(4, 0.08, (0.1, -0.57, -0.47), spread=0.15)  # boil cluster along the jaw
    elif limb == "upper_torso":
        L.box((W, D, 1.55), (0, 0, -0.075), swatch="tan")  # jacket, right shoulder dropped
        L.box((0.8, D, 0.3), (-0.57, 0, 0.75), swatch="tan")  # left shoulder stays up
        L.box((0.7, 0.12, 1.4), (0, -0.5, -0.1), swatch="white_d")  # shirt in the open front
        for x in (-0.45, 0.45):
            L.box((0.26, 0.1, 1.3), (x, -0.53, -0.1), swatch="tan_d")  # lapels
        L.box((0.12, 0.06, 0.12), (0, -0.57, -0.5), swatch="brass")  # one button left
        L.box((0.5, D + 0.02, 1.0), (0.72, 0, -0.2), swatch=skin)  # torn side: bare skin
        L.blotch(0.46, 0.84, (0.72, -0.515, -0.2), swatch="flesh")  # inflamed round the slab (front -0.545, behind the slab)
        L.box((0.36, 0.12, 0.62), (0.72, -0.5, -0.1), swatch="rebuilt")  # re-set rib slab
        for z in (0.1, -0.1, -0.3):
            L.box((0.3, 0.06, 0.06), (0.72, -0.56, z), swatch="rebuilt_l")  # ribs
        L.box((0.1, 0.1, 0.3), (0.3, -0.5, 0.72), swatch="rebuilt")  # neck seam
        L.box((2.0, 1.08, 0.3), (0, 0, -0.7), swatch="foliage")  # blanket knotted at the waist
        L.box((1.9, 0.2, 0.5), (0, 0.5, -0.6), swatch="foliage_d")  # blanket back
    elif limb == "lower_torso":
        L.box((W, D, H), swatch="asphalt")
        L.box((W + 0.06, D + 0.06, 0.42), swatch="foliage")  # shawl wrap
        L.box((1.9, 0.18, 0.42), (0, 0.55, 0), swatch="foliage_d")  # hanging back
        L.ico(0.2, (0.35, -0.56, 0.02), swatch="foliage")  # knot
    elif limb == "upper_arm":
        L.cap(0.5, (0, 0, 0.12), swatch="tan")  # rounded shoulder
        L.oct(0.42, 0.74, (0, 0, -0.25), swatch="tan", r_top=0.5)  # sleeve to the elbow
        L.oct(0.45, 0.12, (0, 0, -0.56), swatch="tan_d")  # cuff
    elif limb == "lower_arm":
        L.cap(0.42, (0, 0, 0.14), swatch=skin)  # elbow
        L.oct(0.37, 0.7, (0, 0, -0.21), swatch=skin, r_top=0.42)  # forearm tapers to the wrist
        L.oct(0.41, 0.18, (0, 0, -0.38), swatch="white")  # Delta screening band
        L.oct(0.42, 0.05, (0, 0, -0.38), swatch="red")  # its one red stripe
    elif limb == "hand":
        L.box((W, D, H), swatch="flesh")  # swollen: fills the box, flushed
        L.box((0.9, 0.42, 0.3), (0, -0.3, -0.08), swatch="flesh")  # fingers curled under
        for x in (-0.22, 0.0, 0.22):
            L.box((0.05, 0.44, 0.32), (x, -0.3, -0.08), swatch="flesh_d")  # finger gaps
        L.blotch(0.5, 0.4, (0.15, 0.12, 0.165), face="top", swatch="bruise")
        L.boil(0.09, (-0.22, 0.14, 0.14), n=(0, 0, 1))  # pustule on the back of the hand
    elif limb == "upper_leg":
        L.hip_inset(0.48, "asphalt")
        L.oct(0.44, 1.0, (0, 0, -0.18), swatch="asphalt", r_top=0.48)  # thigh
        L.box((1.0, 0.16, 0.9), (0, 0.5, 0.2), swatch="foliage_d")  # blanket hangs to the thigh
        L.ico(0.22, (0.1, -0.36, -0.5), swatch="rebuilt")  # knee knot, just proud of the box
    elif limb == "lower_leg":
        L.cap(0.42, (0, 0, 0.23), swatch="asphalt")  # knee under the trouser
        L.oct(0.36, 0.88, (0, 0, -0.21), swatch="asphalt", r_top=0.42)  # shin
        L.box((W, D, 0.3), (0, 0, -0.5), swatch="dark")  # shoe top
    elif limb == "foot":
        L.shoe("dark")


# --- Runner: a Delta garrison soldier the agent did its job on. Flayed: wound-red muscle
# under pale rebuilt tendon cables, pus weeping in strips down every limb, hard taper to the
# joints (every one a bone knob). Plate carrier torn off, T-shirt split by the chest growth,
# dog tags, fatigue trousers blown at the knees, boots. Fresh red at the tears.
def runner_limb(L, limb):
    W, D, H = R15_LIMB[limb]
    skin = "wound"
    if limb == "head":
        L.box((W, D, H), swatch=skin)  # no skin left on the face
        L.box((0.9, 0.14, 0.16), (0, -0.6, 0.2), swatch="rebuilt")  # brow ridge, bone like the nose
        L.eyes(z=0.04, y=-0.6, rim="wound_d")
        L.box((0.2, 0.12, 0.2), (0, -0.62, -0.1), swatch="rebuilt")  # nose gone to bone
        L.box((0.66, 0.1, 0.2), (0, -0.6, -0.32), swatch="dark_d")  # clenched jaw
        L.box((0.54, 0.08, 0.1), (0, -0.62, -0.32), swatch="white_d")  # teeth
        for x in (-0.4, 0.4):
            L.box((0.06, 0.1, 0.5), (x, -0.59, -0.14), swatch="rebuilt_l")  # cheek tendons
        L.box((0.34, 0.12, 0.34), (0, 0.5, -0.3), swatch="rebuilt_l")  # tendon at the nape
        L.blotch(0.5, 0.5, (0.58, 0.1, 0.1), face="right", swatch="wound_d")  # darker torn patch
        L.box((0.06, 0.6, 0.06), (-0.58, -0.1, -0.1), swatch="pus_d")  # weep down the cheek
        L.box((0.06, 0.06, 0.5), (-0.2, -0.59, -0.08), swatch="pus_d")  # weep down the face
    elif limb == "upper_torso":
        L.box((W, D, H), swatch=skin)  # muscle
        for x in (-0.6, 0.6):
            L.box((0.72, D + 0.02, 1.5), (x, 0, -0.05), swatch="gun_d")  # T-shirt halves
        L.box((1.94, 0.3, 1.5), (0, 0.36, -0.05), swatch="gun_d")  # shirt back
        for x in (-0.37, 0.37):
            L.box((0.06, 0.12, 1.4), (x, -0.52, -0.05), swatch="red")  # fresh tear edges
        for x in (-0.3, 0.3):
            L.box((0.46, 0.24, 0.5), (x, -0.5, 0.25), swatch=skin)  # pecs
            L.box((0.06, 0.12, 0.9), (x * 0.5, -0.56, -0.1), swatch="rebuilt_l")  # tendons
            L.box((0.08, 0.1, 0.4), (x * 0.9, -0.59, -0.2), swatch="pus_d")  # weeping under the pecs
        L.box((0.5, 0.1, 0.06), (0, -0.56, 0.5), swatch="rebuilt_l")  # collarbone cable
        L.box((0.05, 0.08, 0.8), (0.0, -0.57, -0.25), swatch="pus_d")  # weep down the sternum
        for z in (0.72, 0.42, 0.12, -0.18, -0.48):
            L.box((0.28, 0.22, 0.22), (0, 0.5, z), swatch="rebuilt_l")  # spine ridge
        for x in (-0.66, 0.66):
            L.box((0.56, 0.8, 0.3), (x, 0, 0.8), swatch=skin)  # traps: no neck
            L.box((0.26, 0.3, 0.12), (x, -0.36, 0.9), swatch="dark")  # carrier strap stubs
        L.box((0.04, 0.04, 0.5), (0, -0.57, 0.45), swatch="dark")  # tag cord
        L.box((0.14, 0.04, 0.22), (0.03, -0.59, 0.15), swatch="gun_l")  # dog tags
        L.box((0.14, 0.04, 0.22), (-0.04, -0.6, 0.11), swatch="gun_l")
    elif limb == "lower_torso":
        L.box((W, D, H), swatch="olive")
        L.box((W + 0.02, D + 0.02, 0.14), (0, 0, 0.1), swatch="dark")  # belt
        L.box((0.26, 0.1, 0.16), (0, -0.53, 0.1), swatch="gun")  # buckle
    elif limb == "upper_arm":
        L.cap(0.5, (0, 0, 0.12), swatch="gun_d")  # sleeve stub over a rounded shoulder
        L.oct(0.40, 0.36, (0, 0, -0.04), swatch=skin, r_top=0.46)  # banded muscle
        L.oct(0.44, 0.06, (0, 0, -0.22), swatch="rebuilt_l")  # tendon band
        L.oct(0.34, 0.34, (0, 0, -0.42), swatch=skin, r_top=0.40)
        L.oct(0.37, 0.06, (0, 0, -0.56), swatch="rebuilt_l")
        L.box((0.06, 0.16, 0.7), (0.1, -0.38, -0.25), swatch="pus_d")  # weep strip down the front
        L.box((0.06, 0.16, 0.6), (0, 0.36, -0.3), swatch="rebuilt_l")  # tendon down the back
    elif limb == "lower_arm":
        L.cap(0.4, (0, 0, 0.16), swatch="rebuilt_l")  # elbow knob
        L.oct(0.32, 0.72, (0, 0, -0.2), swatch=skin, r_top=0.40)  # hard taper
        L.oct(0.38, 0.06, (0, 0, -0.14), swatch="rebuilt_l")  # tendon ring
        L.oct(0.35, 0.1, (0, 0, -0.5), swatch="rebuilt")  # wrist
        L.box((0.06, 0.16, 0.6), (-0.08, -0.31, -0.22), swatch="pus_d")  # weep
        L.box((0.06, 0.16, 0.64), (0.06, 0.3, -0.2), swatch="rebuilt_l")  # tendon down the back
    elif limb == "hand":
        L.box((W, 0.7, H), (0, 0.16, 0), swatch=skin)
        L.box((0.9, 0.14, 0.16), (0, -0.2, 0.1), swatch="rebuilt_l")  # knuckles
        for x in (-0.36, -0.12, 0.12, 0.36):
            L.box((0.16, 0.5, 0.18), (x, -0.42, -0.02), swatch=skin)  # long splayed fingers
    elif limb == "upper_leg":
        L.hip_inset(0.5, "olive")
        L.oct(0.46, 0.6, (0, 0, 0.15), swatch="olive", r_top=0.5)  # trouser to the torn edge
        L.oct(0.5, 0.08, (0, 0, -0.16), swatch="olive_d")  # torn edge
        L.oct(0.38, 0.5, (0, 0, -0.43), swatch=skin, r_top=0.44)  # blown knee
        L.ico(0.22, (0, -0.4, -0.5), swatch="rebuilt_l")  # knee knob
        L.box((0.06, 0.16, 0.4), (0.1, -0.36, -0.4), swatch="pus_d")  # weep
    elif limb == "lower_leg":
        L.cap(0.4, (0, 0, 0.25), swatch="rebuilt_l")  # knee knob
        L.oct(0.34, 0.5, (0, 0, 0.0), swatch=skin, r_top=0.40)  # calf bands
        L.oct(0.37, 0.06, (0, 0, -0.06), swatch="rebuilt_l")
        L.oct(0.33, 0.26, (0, 0, -0.26), swatch=skin, r_top=0.35)
        L.box((0.92, 0.92, 0.62), (0, 0, -0.34), swatch="dark")  # boot shaft
        L.box((0.96, 0.96, 0.08), (0, 0, -0.08), swatch="dark_l")  # boot collar
        L.box((0.06, 0.16, 0.36), (-0.1, -0.3, 0.0), swatch="pus_d")  # weep into the boot
    elif limb == "foot":
        L.shoe("dark")
        L.box((0.08, 0.5, 0.06), (0.3, 0.4, 0.14), swatch="tan_d")  # lace trailing off the heel


# --- Brute: a Delta soldier rebuilt around his breaks with bone. Deep-bruise skin, a bone
# shelf over both shoulders, plated skull under a split helmet, ribs showing, three boil
# clusters under the shelf, a goitre on the neck, carrier hanging open on one side, a burst
# assault pack, swollen striking forearms with spurs, knuckle plates, thigh lesions, shins
# plated, boots split at the toe.
def brute_limb(L, limb):
    W, D, H = R15_LIMB[limb]
    skin = "bruise"
    if limb == "head":
        L.box((W, D, 0.5), (0, 0, -0.34), swatch=skin)  # jaw
        L.box((W, D, 0.72), (0, 0, 0.23), swatch="rebuilt")  # plated skull
        for x in (-0.37, 0.37):
            L.box((0.5, 1.24, 0.44), (x, 0, 0.42), swatch="olive_d")  # helmet halves
        L.box((0.22, 1.2, 0.5), (0, 0, 0.4), swatch="rebuilt_l")  # bone crest between them
        L.box((1.16, 0.24, 0.2), (0, -0.56, 0.12), swatch="rebuilt_d")  # brow overhang
        L.eyes(z=-0.04, y=-0.56, dx=0.26, size=(0.2, 0.1, 0.1))
        L.box((1.2, 0.06, 0.08), (0, -0.56, -0.4), swatch="dark")  # chin strap
        L.box((0.7, 0.1, 0.08), (0, -0.6, -0.26), swatch="dark_d")  # mouth
        L.lesion(0.3, 0.3, (0.58, 0.02, -0.34), face="right")  # jaw lesion
        L.blotch(0.4, 0.3, (-0.58, -0.06, -0.34), face="left", swatch="bruise_d")
    elif limb == "upper_torso":
        L.box((W, D, H), swatch=skin)
        for y in (-0.42, 0.42):
            L.box((2.1, 0.3, 0.5), (0, y, 0.7), swatch="rebuilt")  # the bone shelf
            for x in (-0.7, 0.0, 0.7):
                L.ico(0.18, (x, y, 0.92), swatch="rebuilt_l")  # knobs along it
        L.box((W + 0.06, 0.5, 0.2), (0, 0, 0.84), swatch="rebuilt")  # shelf bridges over the neck
        L.ico(0.28, (0.34, -0.42, 0.66), swatch="flesh", subdiv=1)  # neck goitre
        L.boil(0.1, (0.46, -0.6, 0.72), n=(0.4, -0.9, 0.2))  # weeping at its tip
        for z in (0.35, 0.1, -0.15, -0.4):
            L.box((1.1, 0.08, 0.1), (0, -0.52, z), swatch="rebuilt")  # ribs
        L.box((0.5, 0.06, 0.12), (0.3, -0.57, 0.5), swatch="red")  # fresh under the shelf
        L.cluster(3, 0.1, (0.1, -0.56, 0.3), spread=0.16)  # boil clusters under the shelf
        L.cluster(3, 0.1, (0.55, -0.56, 0.36), spread=0.16)
        L.cluster(3, 0.09, (0.88, -0.5, 0.18), n=(0.5, -0.86, 0), spread=0.15)
        L.box((0.8, 0.16, 1.2), (-0.55, -0.56, -0.05), swatch="olive_d")  # carrier hangs open
        L.box((0.06, 0.04, 0.9), (-0.5, -0.66, 0.0), swatch="dark_d")  # cracked plate
        L.box((0.16, 0.34, 1.0), (-0.9, -0.36, 0.2), swatch="dark")  # its strap
        L.box((1.3, 0.3, 1.0), (0.1, 0.56, -0.1), swatch="olive")  # burst assault pack
        L.box((0.5, 0.34, 0.5), (0.3, 0.6, -0.4), swatch="olive_d")  # pack flap hanging
        L.box((0.14, 0.4, 1.2), (0.6, 0.4, 0.1), swatch="dark")  # one strap left
    elif limb == "lower_torso":
        L.box((W, D, H), swatch="olive")
        L.box((W + 0.02, D + 0.02, 0.14), (0, 0, 0.08), swatch="dark")  # belt
        L.box((0.6, 0.12, 0.2), (0.4, -0.52, 0.02), swatch="rebuilt")  # hip bone through
    elif limb == "upper_arm":
        L.cap(0.46, (0, 0, 0.16), swatch="olive")  # sleeve stub over a rounded shoulder
        L.oct(0.42, 0.1, (0, 0, -0.02), swatch="olive_d")
        L.oct(0.36, 0.6, (0, 0, -0.32), swatch=skin, r_top=0.42)  # thinner than the forearm
        L.blotch(0.3, 0.3, (0.0, -0.36, -0.3), swatch="bruise_d")
    elif limb == "lower_arm":
        L.cap(0.54, (0, 0, 0.02), swatch=skin)  # swollen elbow fills the box
        L.oct(0.5, 0.6, (0, 0, -0.26), swatch=skin, r_top=0.54)  # swollen striking forearm
        for z in (0.32, 0.0, -0.32):
            L.box((0.24, 0.2, 0.34), (0.5, 0.1, z), rot=(0, 30, 0), swatch="rebuilt")  # ulna spurs
        L.blotch(0.42, 0.56, (0, -0.48, -0.16), swatch="bruise_d")  # the bruise where it strikes
        L.boil(0.11, (-0.3, -0.4, -0.08), n=(-0.4, -0.9, 0))
    elif limb == "hand":
        L.box((W, 0.74, 0.4), (0, 0.12, 0.0), swatch=skin)  # fist
        L.box((0.9, 0.32, 0.22), (0, -0.4, 0.08), swatch="rebuilt_l")  # knuckle plates
        for x in (-0.22, 0.0, 0.22):
            L.box((0.05, 0.4, 0.3), (x, -0.36, -0.06), swatch="dark_d")  # finger gaps
    elif limb == "upper_leg":
        L.hip_inset(0.5, "olive", h=0.36)
        L.oct(0.5, 0.3, (0, 0, 0.35), swatch="olive")  # trousers torn to the thigh
        L.oct(0.53, 0.08, (0, 0, 0.2), swatch="olive_d")
        L.oct(0.46, 0.84, (0, 0, -0.26), swatch=skin, r_top=0.5)
        L.lesion(0.3, 0.34, (-0.08, -0.45, -0.24))  # thigh lesions
        L.lesion(0.26, 0.28, (0.46, 0.08, -0.12), face="right")
        L.ico(0.26, (0, -0.42, -0.55), swatch="rebuilt")  # knee knob
    elif limb == "lower_leg":
        L.cap(0.42, (0, 0, 0.23), swatch=skin)
        L.oct(0.42, 0.78, (0, 0, -0.16), swatch=skin, r_top=0.46)
        L.box((0.7, 0.2, 0.9), (0, -0.44, 0.15), swatch="rebuilt")  # shin plate
        L.box((W, D, 0.5), (0, 0, -0.4), swatch="dark_d")  # boot shaft
    elif limb == "foot":
        L.shoe("dark_d")
        L.box((0.4, 0.3, 0.26), (0.1, -0.42, 0.08), swatch="rebuilt")  # bone through the toe


# --- Hocker: a Walker a day further on; the throat is a pump. Head thrown back on a split jaw
# over a fevered flushed throat, nose and lips gone to rebuilt tissue, eyes rolled up, the
# jacket soaked with pus down the front from the collar, chest hollow, a surgical mask round
# the neck under where the sac sits with a ring of pustules round it, hands hooked up at the
# collar. Legs are the Walker's. The sac itself stays an attached part (strain, the one place
# the green still lives).
def hocker_limb(L, limb):
    W, D, H = R15_LIMB[limb]
    skin = "pallor"
    if limb == "head":
        L.box((W, D, 0.8), (0, 0, 0.19), swatch=skin)  # upper face
        L.box((1.2, 1.2, 0.26), (0, 0.02, 0.5), swatch="dark")  # hair cap
        L.box((0.3, 1.1, 0.5), (-0.46, 0.06, 0.2), swatch="dark")
        L.eyes(z=0.2, y=-0.6, dx=0.25, size=(0.2, 0.1, 0.12))  # eyes rolled up under the hairline
        L.box((0.5, 0.14, 0.36), (0, -0.6, -0.06), swatch="rebuilt")  # nose and lips gone
        L.box((0.9, 0.56, 0.3), (0, -0.3, -0.42), swatch="strain_d")  # the open throat
        for s in (-1, 1):
            L.box((0.44, 0.64, 0.36), (s * 0.34, -0.3, -0.52), rot=(0, 0, s * 22), swatch=skin)  # jaw halves
        L.box((W, D, 0.3), (0, 0.1, -0.44), swatch="flesh")  # fevered throat under the jaw
        L.blotch(0.5, 0.26, (0.58, 0.0, -0.2), face="right", swatch="flesh_d")
        L.blotch(0.5, 0.26, (-0.58, 0.0, -0.2), face="left", swatch="flesh_d")
        L.b.rotate_all((-20, 0, 0))  # head thrown back
    elif limb == "upper_torso":
        for x in (-0.67, 0.67):
            L.box((0.6, D, H), (x, 0, 0), swatch="tan")  # jacket sides
        L.box((0.74, 0.8, H), (0, 0.1, 0), swatch="white_d")  # chest caved in: recessed shirt
        for x in (-0.42, 0.42):
            L.box((0.2, 0.12, 1.4), (x, -0.5, -0.1), swatch="tan_d")  # lapels
        L.box((0.5, 0.06, 1.2), (0, -0.33, 0.05), swatch="pus_d")  # soaked down the front
        for x in (-0.18, 0.2):
            L.box((0.1, 0.06, 0.5), (x, -0.33, -0.5), swatch="pus_d")  # drips
        for z in (0.3, 0.05, -0.2):
            L.box((0.6, 0.04, 0.06), (0, -0.34, z), swatch="rebuilt_l")  # ribs under the shirt
        L.box((1.0, 0.36, 0.3), (0, -0.36, 0.7), swatch="white")  # surgical mask round the neck
        L.box((1.2, 0.3, 0.05), (0, -0.36, 0.84), swatch="dark_d")  # mask tie
        L.box((0.9, 0.5, 0.2), (0, -0.1, 0.78), swatch="flesh")  # fevered throat base
        for x, y, nx, ny in ((-0.74, -0.22, -0.7, -0.5), (0.74, -0.22, 0.7, -0.5), (-0.5, -0.5, -0.4, -0.8), (0.5, -0.5, 0.4, -0.8), (-0.76, 0.2, -0.9, 0.2), (0.76, 0.2, 0.9, 0.2)):
            L.boil(0.1, (x, y, 0.8), n=(nx, ny, 0.5))  # pustule ring round the sac
        L.box((1.9, 0.2, 0.5), (0, 0.5, -0.6), swatch="foliage_d")  # blanket back
        L.box((2.0, 1.08, 0.3), (0, 0, -0.7), swatch="foliage")  # blanket knot
    elif limb == "lower_torso":
        walker_limb(L, limb)
    elif limb == "upper_arm":
        L.cap(0.47, (0, 0, 0.15), swatch="tan")  # rounded shoulder
        L.oct(0.4, 0.74, (0, 0, -0.25), swatch="tan", r_top=0.47)
        L.oct(0.44, 0.14, (0, 0, -0.55), swatch="pus_d")  # soaked cuff
    elif limb == "lower_arm":
        L.cap(0.4, (0, 0, 0.16), swatch=skin)
        L.oct(0.36, 0.72, (0, 0, -0.2), swatch=skin, r_top=0.4)
        L.oct(0.4, 0.2, (0, 0, -0.4), swatch="rebuilt")  # rebuilt wrist
    elif limb == "hand":
        L.box((W, 0.7, H), (0, 0.16, 0), swatch=skin)
        for x in (-0.33, -0.11, 0.11, 0.33):
            L.box((0.16, 0.3, 0.4), (x, -0.4, -0.1), rot=(40, 0, 0), swatch=skin)  # hooked fingers
        L.box((0.9, 0.12, 0.1), (0, -0.2, 0.12), swatch="rebuilt_l")  # knuckles
    else:
        walker_limb(L, limb)


# --- The Warden (Delta's Index host; docs/CHARACTERS.md B): the MP sergeant who ran the Gate,
# bitten through the shield sleeve, his riot kit grown into him. Built on the Brute's bone shelf
# in MP olive with a dark duty belt and gas canisters on the right hip; the arms are side
# specific (the brassard on the right upper arm, the shield's bone grips on the left forearm).
# Everything the plates hide is already here: rebuilt bone with `strain_l` seams, so a plate
# coming off reveals the strain working (CHARACTERS: the seams are the one green on him).
# The six plates are separate meshes (`_warden_plate`) welded on by IndexService with their own
# health; scale 1.9 in game (10.1 studs, under the 10.5 bridge deck).
def warden_limb(L, limb, side=None):
    W, D, H = R15_LIMB[limb]
    skin = "bruise"
    sx = 1 if side == "r" else -1  # the arm's outer face
    if limb == "head":
        L.box((W, D, 0.5), (0, 0, -0.34), swatch=skin)  # jaw
        L.box((W - 0.1, D - 0.1, 0.72), (0, 0, 0.23), swatch="rebuilt")  # plated skull under the shell
        L.box((0.08, 1.0, 0.06), (0.2, 0, 0.6), swatch="strain_l")  # the seam the helmet hides
        L.box((1.16, 0.24, 0.18), (0, -0.56, 0.1), swatch="rebuilt_d")  # brow
        for x in (-0.26, 0.26):  # eyes lit strain behind the visor (art director: strain_l, not green)
            L.box((0.3, 0.08, 0.2), (x, -0.57, -0.06), swatch="dark_d")
            L.box((0.2, 0.1, 0.1), (x, -0.58, -0.06), swatch="strain_l")
        L.box((0.7, 0.1, 0.08), (0, -0.6, -0.26), swatch="dark_d")  # mouth
        L.box((W, 0.06, 0.1), (0, -0.56, -0.5), swatch="dark")  # chin strap
        L.lesion(0.3, 0.3, (0.58, 0.02, -0.34), face="right")
        L.blotch(0.4, 0.3, (-0.58, -0.06, -0.34), face="left", swatch="bruise_d")
    elif limb == "upper_torso":
        L.box((W, D, H), swatch="olive")  # MP shirt
        L.box((W, D, 0.5), (0, 0, 0.6), swatch=skin)  # bare shoulders over the collar
        for y in (-0.42, 0.42):
            L.box((2.1, 0.3, 0.44), (0, y, 0.72), swatch="rebuilt")  # the Brute's bone shelf
            for x in (-0.7, 0.0, 0.7):
                L.ico(0.16, (x, y, 0.92), swatch="rebuilt_l")
        L.box((W + 0.06, 0.5, 0.2), (0, 0, 0.84), swatch="rebuilt")
        for z in (0.3, -0.1, -0.5):  # ribs through the shirt, a seam under each (chest plate hides them)
            L.box((1.3, 0.06, 0.08), (0, -0.52, z), swatch="rebuilt")
            L.box((1.2, 0.05, 0.04), (0, -0.53, z - 0.1), swatch="strain_l")
        L.box((0.5, 0.06, 1.3), (0, 0.52, -0.1), swatch="rebuilt")  # spine ridge (back plate hides it)
        L.box((0.08, 0.05, 1.3), (-0.3, 0.53, -0.1), swatch="strain_l")
        L.blotch(0.4, 0.4, (0.55, -0.52, 0.2), swatch="bruise_d")
        L.cluster(3, 0.09, (-0.6, -0.56, -0.3), spread=0.15)
    elif limb == "lower_torso":
        L.box((W, D, H), swatch="olive")
        L.box((W + 0.02, D + 0.02, 0.16), (0, 0, 0.1), swatch="dark")  # duty belt
        L.box((0.3, 0.2, 0.1), (0, -0.52, 0.1), swatch="brass")  # buckle
        for y in (-0.25, 0.1):  # gas canisters on the right hip
            L.cyl(0.14, 0.42, (1.08, y, -0.08), swatch="gun_d")
            L.cyl(0.06, 0.08, (1.08, y, 0.17), swatch="gun_l")
        L.box((0.2, 0.16, 0.3), (-1.04, 0, 0.0), swatch="dark")  # cuff pouch on the left
        L.box((0.6, 0.12, 0.2), (0.4, -0.52, -0.1), swatch="rebuilt")  # hip bone through
    elif limb == "upper_arm":
        L.cap(0.46, (0, 0, 0.16), swatch=skin)  # bare shoulder (the shoulder plate sits over it)
        L.oct(0.47, 0.05, (0, 0, 0.3), swatch="strain_l")  # seam ring under the plate edge
        L.oct(0.44, 0.1, (0, 0, -0.02), swatch="olive_d")  # rolled sleeve edge
        L.oct(0.36, 0.6, (0, 0, -0.32), swatch=skin, r_top=0.44)
        if side == "r":  # the white MP brassard, two abstract bars (no text)
            L.oct(0.41, 0.3, (0, 0, -0.3), swatch="white")
            for y in (-0.12, 0.12):
                L.box((0.06, 0.12, 0.2), (0.42, y, -0.3), swatch="dark_d")
        else:
            L.lesion(0.26, 0.3, (-0.4, 0, -0.3), face="left")
    elif limb == "lower_arm":
        L.cap(0.52, (0, 0, 0.02), swatch=skin)
        L.oct(0.48, 0.6, (0, 0, -0.26), swatch=skin, r_top=0.52)  # swollen striking forearm
        for z in (0.3, 0.0, -0.3):
            L.box((0.24, 0.2, 0.3), (sx * 0.5, 0.1, z), rot=(0, sx * 30, 0), swatch="rebuilt")  # ulna spurs
        L.blotch(0.4, 0.5, (0, -0.48, -0.16), swatch="bruise_d")
        if side == "l":  # bone grown out to the shield's grips (the shield plate welds over these)
            for z in (0.25, -0.35):
                L.box((0.5, 0.3, 0.22), (-0.55, -0.3, z), swatch="rebuilt")
            L.box((0.06, 0.4, 0.7), (-0.5, -0.2, -0.05), swatch="strain_l")  # seam where the shield meets the arm
        else:
            L.boil(0.1, (0.3, -0.42, -0.1), n=(0.4, -0.9, 0))
    elif limb == "hand":
        L.box((W, 0.74, 0.4), (0, 0.12, 0.0), swatch="dark")  # gloved fist
        L.box((0.9, 0.32, 0.22), (0, -0.4, 0.08), swatch="rebuilt_l")  # knuckles through the glove
        for x in (-0.22, 0.0, 0.22):
            L.box((0.05, 0.4, 0.3), (x, -0.36, -0.06), swatch="dark_d")
    elif limb == "upper_leg":
        L.hip_inset(0.5, "olive", h=0.36)
        L.oct(0.5, 0.9, (0, 0, 0.05), swatch="olive")
        L.oct(0.52, 0.08, (0, 0, 0.2), swatch="olive_d")  # cargo seam
        L.oct(0.46, 0.4, (0, 0, -0.5), swatch="olive", r_top=0.5)
        L.box((0.8, 0.36, 0.36), (0, -0.42, -0.5), swatch="dark_d")  # knee cup
        L.box((0.5, 0.06, 0.34), (-0.15, -0.5, 0.35), swatch=skin)  # torn trouser
        L.lesion(0.22, 0.2, (-0.15, -0.52, 0.35))
    elif limb == "lower_leg":
        L.cap(0.42, (0, 0, 0.23), swatch="olive")
        L.oct(0.42, 0.78, (0, 0, -0.16), swatch="olive", r_top=0.46)
        L.box((0.8, 0.28, 0.95), (0, -0.44, 0.1), swatch="dark_d")  # shin guard
        for z in (0.4, 0.1, -0.2):
            L.box((0.84, 0.08, 0.1), (0, -0.56, z), swatch="dark_l")  # guard ribs
        L.box((W, D, 0.5), (0, 0, -0.4), swatch="dark_d")  # boot shaft
    elif limb == "foot":
        L.shoe("dark_d")
        L.box((0.9, 0.3, 0.26), (0, -0.4, 0.06), swatch="dark")  # toe cap


# The Warden's six plates, each built in the frame of the limb it welds to (same offset rule as
# the Chosen's gear): helmet on Head, chest and back on UpperTorso, shoulder on either UpperArm
# (symmetric in x, one mesh for both), shield on LeftLowerArm (faces front when the arm hangs).
# IndexService gives each its own health; the shield blocks frontal chest shots by being in front.
WARDEN_PLATES = {"helmet": "head", "chest": "upper_torso", "back": "upper_torso", "shoulder": "upper_arm", "shield": "lower_arm"}


def _warden_plate(L, which):
    if which == "helmet":
        L.oct(0.74, 0.56, (0, 0, 0.44), swatch="dark", r_top=0.5)  # riot shell: a tapered crown (art director: not the Brute's box)
        for x in (-0.68, 0.68):
            L.box((0.1, 1.0, 0.5), (x, 0.05, -0.12), swatch="dark")  # ear guards wrap the shell to the jaw
        L.box((1.4, 0.3, 0.1), (0, -0.74, 0.22), swatch="dark")  # peak
        L.box((1.24, 0.08, 0.56), (0, -0.68, -0.12), swatch="gun_l")  # visor
        L.box((0.05, 0.1, 0.5), (0.22, -0.7, -0.12), rot=(0, 18, 0), swatch="dark_d")  # the crack across it
        L.box((1.24, 0.2, 0.46), (0, 0.66, -0.1), swatch="dark")  # neck guard
        L.box((0.16, 0.2, 0.2), (0.7, -0.3, 0.3), swatch="dark_d")  # helmet strobe mount
    elif which == "chest":
        L.box((1.86, 0.3, 1.4), (0, -0.62, 0.0), swatch="dark")  # chest plate
        L.box((1.9, 0.08, 0.2), (0, -0.78, 0.56), swatch="dark_l")  # top edge
        L.box((1.9, 0.08, 0.16), (0, -0.78, -0.64), swatch="dark_l")  # bottom edge
        for x in (-0.5, 0.5):
            L.box((0.1, 0.1, 1.2), (x, -0.79, 0.0), swatch="dark_l")  # ribs
        L.box((0.36, 0.26, 0.56), (0.6, -0.9, 0.42), swatch="gun_d")  # the radio handset, grown in (gun_d so it reads on the dark plate)
        L.box((0.26, 0.04, 0.3), (0.6, -1.04, 0.5), swatch="dark_d")  # speaker grille
        L.box((0.08, 0.06, 0.08), (0.72, -1.04, 0.2), swatch="red")  # TX lamp
        for x, z in ((0.36, 0.1), (0.22, -0.08), (0.1, -0.26)):  # the coiled cord, three turns
            L.cyl(0.06, 0.12, (x, -0.84, z), rot=(90, 0, 0), segs=6, swatch="gun_d")
    elif which == "back":
        L.box((1.86, 0.3, 1.4), (0, 0.62, 0.0), swatch="dark")
        L.box((1.9, 0.08, 0.2), (0, 0.78, 0.56), swatch="dark_l")
        L.box((1.3, 0.06, 0.32), (0, 0.8, 0.05), swatch="white")  # the MP band, abstract
        L.box((1.0, 0.06, 0.06), (0, 0.84, 0.05), swatch="dark_d")
        L.box((0.4, 0.3, 0.6), (-0.6, 0.85, -0.3), swatch="olive_d")  # radio pack
    elif which == "shoulder":
        L.oct(0.7, 0.34, (0, 0, 0.5), swatch="dark", r_top=0.62)
        L.oct(0.72, 0.08, (0, 0, 0.3), swatch="dark_l")  # rim
        L.box((0.3, 1.2, 0.1), (0, 0, 0.72), swatch="dark_d")  # top ridge
    elif which == "shield":
        cx, cy = -0.6, -0.72  # outboard of the left forearm, ahead of it
        L.box((2.0, 0.16, 3.8), (cx, cy, -0.3), swatch="dark_l")  # the shield, door-sized at scale 1.9
        L.box((2.08, 0.1, 0.16), (cx, cy - 0.02, 1.62), swatch="dark")  # top edge
        L.box((2.08, 0.1, 0.16), (cx, cy - 0.02, -2.22), swatch="dark")  # bottom edge
        for x in (cx - 0.96, cx + 0.96):
            L.box((0.16, 0.1, 3.8), (x, cy - 0.02, -0.3), swatch="dark")  # side rails
        L.box((1.2, 0.06, 0.9), (cx, cy - 0.1, 0.7), swatch="gun_l")  # window
        L.box((1.4, 0.06, 0.3), (cx, cy - 0.1, -0.4), swatch="white_d")  # the band where the lettering was (white_d: the brassard stays his one true white)
        for z in (0.25, -0.35):  # grips: bone grown from the forearm to the shield's back
            L.box((0.5, 0.5, 0.26), (cx + 0.5, cy + 0.3, z), swatch="rebuilt")


INFECTED_TYPES = {
    "walker": walker_limb,
    "runner": runner_limb,
    "brute": brute_limb,
    "hocker": hocker_limb,
    "warden": warden_limb,
}
# Forms whose arms differ by side: these limbs export as `_l` / `_r` meshes (MeshAssets.dressModel
# looks the side up before the shared name).
INFECTED_SIDED = {"warden": ("upper_arm", "lower_arm")}
# Plates on the assembled Warden preview: (plate, limb, side sign).
WARDEN_PREVIEW_PLATES = (
    ("helmet", "head", 0), ("chest", "upper_torso", 0), ("back", "upper_torso", 0),
    ("shoulder", "upper_arm", -1), ("shoulder", "upper_arm", 1), ("shield", "lower_arm", -1),
)


def _register_infected():
    for tname, build in INFECTED_TYPES.items():
        sided = INFECTED_SIDED.get(tname, ())
        for limb in R15_LIMB:
            if limb in sided:
                for side in ("l", "r"):
                    def fn(b, limb_name=limb, build_=build, side_=side):
                        build_(Limb(b), limb_name, side_)
                    ASSETS[f"inf_{tname}_{limb}_{side}"] = (fn, "Infected", "center")
            else:
                def fn(b, limb_name=limb, build_=build):
                    build_(Limb(b), limb_name)
                ASSETS[f"inf_{tname}_{limb}"] = (fn, "Infected", "center")

        def preview(b, build_=build, sided_=sided, tname_=tname):
            # Assembled figure at R15 offsets (hip at z=0), for the lineup/preview only.
            def place(sub, x, y, z):
                verts = list(sub.bm.verts)
                bmesh.ops.translate(sub.bm, vec=Vector((x, y, z)), verts=verts)
                b.merge(sub)
            for limb, (x, y, z) in R15_POSE.items():
                sides = (1,) if x == 0 else (-1, 1)
                for s in sides:
                    sub = Builder()
                    if limb in sided_:
                        build_(Limb(sub), limb, "r" if s > 0 else "l")
                    else:
                        build_(Limb(sub), limb)
                    place(sub, s * x, y, z)
            if tname_ == "warden":
                for which, limb, s in WARDEN_PREVIEW_PLATES:
                    x, y, z = R15_POSE[limb]
                    sub = Builder()
                    _warden_plate(Limb(sub), which)
                    place(sub, s * x, y, z)
        ASSETS[f"ref_inf_{tname}"] = (preview, "_Reference", "bottom")

    for which in WARDEN_PLATES:
        def plate(b, w=which):
            _warden_plate(Limb(b), w)
        ASSETS[f"inf_warden_plate_{which}"] = (plate, "Infected", "center")


_register_infected()


# ------------------------------------------------------------------ The Chosen (player bodies)
# Same limb-swap build as the Infected: one mesh per R15 limb inside the stock limb box.
# docs/CHARACTERS.md §C: every Chosen wears the same `dark` Pike carrier with a white PIKE tab
# on the left shoulder strap and one square patch on the left shoulder and the top of the back
# panel in their own colour; grey `gun` trousers (no Infected wears grey); faces kept simple.
PC_CLASSES = {
    # SSgt Isaac Weller, Assault (the body worn in game): grey fatigues, dark ballistic helmet
    # with an NVG mount, two tourniquets staged on the straps. Friendly blue.
    "assault": dict(skin="tan", top="gun", top_d="gun_d", trousers="gun", boot="dark", glove="dark",
                    head="helmet", accent="friendly_blue", border=None, knee="dark", rolled=False),
    # Mason Cole, K-9 handler: olive blouse (the one olive top), patrol cap, leash on the hip. Tan.
    "k9": dict(skin="tan", top="olive", top_d="olive_d", trousers="gun", boot="dark", glove="dark",
               head="cap", accent="tan_l", border=None, knee="dark", rolled=True),
    # Dr. Elena Reyes, epidemiologist: white field jacket, hood up, respirator, goggles,
    # nitrile gloves. White.
    "epi": dict(skin="tan_l", top="white", top_d="white_d", trousers="gun", boot="dark", glove="white_d",
                head="mask", accent="white_l", border=None, knee="white_d", rolled=False),
    # Ava Cross, recon: dark smock, hood under a boonie brim, face wrap, whip antenna, no knee
    # pads, name tape blacked out. Black square with a grey border.
    "recon": dict(skin="tan", top="dark_l", top_d="dark", trousers="gun", boot="dark_d", glove="dark",
                  head="hood", accent="dark_d", border="gun_l", knee=None, rolled=False),
    # Victor Kane, field engineer: light-olive coveralls, orange hard hat, tool pack with a pry
    # bar, work gloves and boots. Orange.
    "engineer": dict(skin="tan_l", top="olive_l", top_d="olive", trousers="olive_l", boot="rust_d", glove="tan_d",
                     head="hardhat", accent="warning_orange", border=None, knee="olive_d", rolled=True),
}

LEFT = -0.62  # the carrier's left shoulder strap (x); the patch side

# Fallback body (2026-11-07, art v2 §B): the rigid per-limb Chosen get tapered octagonal
# forearms and shins (PC_TAPER_AT of the width at wrist/ankle) and a round joint cap at the
# bottom of each upper arm / upper leg, so a bent elbow or knee shows a pad instead of a box
# corner. False rebuilds the 2026-11-07 full-box limbs that are uploaded today. The skinned
# Weller (below) always tapers.
PC_TAPER = True
PC_TAPER_AT = 0.75
CAP_R = 0.46  # joint cap radius: just inside the tapered limb's top so it hides at rest


def _pc_face(L, sw, brow="tan_d"):
    W, D, H = R15_LIMB["head"]
    L.box((W, D, H), swatch=sw["skin"])
    for x in (-0.24, 0.24):
        L.box((0.18, 0.08, 0.1), (x, -0.6, 0.08), swatch="dark_d")  # eyes
    L.box((0.9, 0.1, 0.08), (0, -0.59, 0.24), swatch=brow)  # brow line
    L.box((0.16, 0.12, 0.22), (0, -0.62, -0.06), swatch=sw["skin"])  # nose
    L.box((0.4, 0.08, 0.05), (0, -0.6, -0.28), swatch="dark_d")  # mouth


def _pc_headgear(L, sw, cname):
    """Everything on the head that is not the head: helmet, cap, hood, hard hat, respirator.
    Separate from the face so the skinned body can wear it as a rigid accessory."""
    head = sw["head"]
    if head == "helmet":
        L.box((1.3, 1.3, 0.46), (0, 0, 0.4), swatch="dark")  # ballistic helmet
        L.box((1.34, 0.26, 0.1), (0, -0.7, 0.2), swatch="dark")  # brim
        L.box((0.36, 0.3, 0.26), (0, -0.62, 0.52), swatch="dark_d")  # NVG mount
        L.box((0.3, 0.1, 0.14), (0, 0.66, 0.5), swatch="gun_l")  # IR strobe
        L.box((1.2, 0.06, 0.08), (0, -0.5, -0.42), swatch="dark")  # chin strap
    elif head == "cap":
        L.box((1.24, 1.2, 0.3), (0, 0.02, 0.46), swatch="tan")  # patrol cap
        L.box((1.0, 0.42, 0.06), (0, -0.78, 0.33), swatch="tan")  # flat brim
    elif head == "mask":
        L.box((1.28, 1.28, 0.5), (0, 0.04, 0.4), swatch="white")  # hood up
        L.box((1.28, 0.3, 0.9), (0, 0.5, -0.1), swatch="white")
        for x in (-0.6, 0.6):
            L.box((0.16, 1.1, 0.9), (x, 0.08, -0.1), swatch="white")
        L.box((1.0, 0.22, 0.42), (0, -0.62, -0.24), swatch="gun_d")  # half-face respirator
        for x in (-0.36, 0.36):
            L.box((0.26, 0.2, 0.26), (x, -0.64, -0.32), swatch="gun")  # filters
        L.box((1.2, 0.12, 0.16), (0, 0, 0.1), swatch="dark")  # goggle strap
        for x in (-0.24, 0.24):
            L.box((0.3, 0.1, 0.22), (x, -0.63, 0.1), swatch="gun_l")  # goggle lenses
    elif head == "hood":
        L.box((1.28, 1.28, 0.5), (0, 0.04, 0.4), swatch="dark")  # hood
        L.box((1.28, 0.3, 0.9), (0, 0.5, -0.1), swatch="dark")
        for x in (-0.6, 0.6):
            L.box((0.16, 1.1, 0.9), (x, 0.08, -0.1), swatch="dark")
        L.box((1.5, 1.5, 0.06), (0, 0, 0.4), swatch="dark")  # boonie brim
        L.box((1.0, 0.12, 0.38), (0, -0.6, -0.32), swatch="dark_d")  # face wrap to the nose
    else:  # hardhat
        L.box((1.26, 1.26, 0.4), (0, 0, 0.44), swatch="warning_orange")
        L.box((1.5, 1.5, 0.08), (0, 0, 0.26), swatch="warning_orange")  # brim
        L.box((0.5, 0.3, 0.12), (0, -0.56, 0.44), swatch="dark")  # headlamp
        L.box((0.5, 0.06, 0.1), (0, -0.66, 0.56), swatch="dark_d")  # KANE in marker


def _pc_head(L, sw, cname, gear=True):
    """The head itself: face, hair, beard; headgear on top when `gear`."""
    head = sw["head"]
    if head == "helmet":
        _pc_face(L, sw)
        for x in (-0.58, 0.58):
            L.box((0.08, 1.0, 0.3), (x, 0, 0.1), swatch="dark_d")  # short hair at the sides
        L.box((0.7, 0.08, 0.1), (0, -0.6, -0.44), swatch="dark_d")  # beard line
    elif head == "cap":
        _pc_face(L, sw)
        for x in (-0.59, 0.59):
            L.box((0.08, 0.6, 0.3), (x, 0, 0.14), swatch="gun_l")  # grey at the temples
    elif head == "mask":
        W, D, H = R15_LIMB["head"]
        L.box((W, D, H), swatch=sw["skin"])
        L.box((0.9, 0.12, 0.12), (0, -0.56, 0.3), swatch="dark_d")  # hair under the hood
    elif head == "hood":
        _pc_face(L, sw, brow="dark")
        L.box((0.08, 0.5, 0.08), (0.62, -0.1, 0.2), swatch="tan_d")  # pencil behind the ear
    else:  # hardhat
        _pc_face(L, sw)
        L.box((0.44, 0.08, 0.08), (0, -0.62, -0.18), swatch="tan_d")  # moustache
    if gear:
        _pc_headgear(L, sw, cname)


def _pc_carrier(L, sw, cname):
    """The Pike carrier on the upper torso, identical on all five."""
    L.box((1.4, 0.2, 1.3), (0, -0.56, 0.05), swatch="dark")  # front panel
    L.box((1.4, 0.2, 1.3), (0, 0.56, 0.05), swatch="dark")  # back panel
    for x in (-0.62, 0.62):
        L.box((0.24, 1.1, 0.24), (x, 0, 0.72), swatch="dark")  # shoulder straps
    L.box((0.22, 0.08, 0.12), (LEFT, -0.6, 0.48), swatch="white")  # PIKE tab
    # the identifying square: left shoulder strap top and the top of the back panel
    for loc in ((LEFT, -0.58, 0.66), (LEFT, 0.68, 0.6)):
        if sw["border"]:
            L.box((0.4, 0.07, 0.26), loc, swatch=sw["border"])
        L.box((0.34, 0.1, 0.2), loc, swatch=sw["accent"])
    L.box((0.5, 0.06, 0.1), (0.45, -0.68, 0.52), swatch="dark_d" if cname == "recon" else "white")  # name tape


def _pc_torso_gear(L, sw, cname):
    """Carrier plus the class's pouches and kit on the upper torso (a rigid accessory on the
    skinned body)."""
    _pc_carrier(L, sw, cname)
    if cname == "assault":
        for x in (-0.4, 0.0, 0.4):
            L.box((0.3, 0.16, 0.42), (x, -0.7, -0.35), swatch="gun_d")  # mag pouches
        L.box((0.6, 0.16, 0.16), (-0.1, -0.68, 0.2), swatch="dark")  # radio
        for x in (-0.62, 0.62):
            L.box((0.12, 0.2, 0.5), (x, -0.6, 0.02), swatch="red_d")  # two tourniquets
    elif cname == "k9":
        for x in (-0.3, 0.3):
            L.box((0.3, 0.16, 0.42), (x, -0.7, -0.35), swatch="gun_d")
        L.box((0.4, 0.3, 0.5), (0.78, -0.3, -0.45), swatch="tan_d")  # tug pouch, right side
        L.box((0.1, 0.14, 0.3), (0.78, -0.42, -0.75), swatch="tan_l")  # chewed tug toy hanging
        L.box((0.14, 0.04, 0.2), (0.08, -0.6, 0.2), swatch="gun_l")  # Kilo's spare tag
    elif cname == "epi":
        L.box((0.6, 0.2, 0.5), (0.4, -0.7, -0.25), swatch="white_d")  # sample pouch
        for x in (0.24, 0.4, 0.56):
            L.box((0.08, 0.1, 0.3), (x, -0.78, -0.2), swatch="white_l")  # vials
            L.box((0.08, 0.1, 0.06), (x, -0.78, -0.02), swatch="red_d")  # caps
        L.box((0.06, 0.1, 0.3), (-0.4, -0.68, 0.1), swatch="white")  # sharpie
        L.box((0.2, 0.06, 0.26), (-0.1, -0.7, -0.55), swatch="white")  # hospital ID badge
        L.box((0.04, 0.1, 0.5), (-0.1, -0.68, -0.2), swatch="gun_l")  # on its lanyard
    elif cname == "recon":
        L.box((0.5, 0.2, 0.4), (0.5, 0.68, 0.3), swatch="dark")  # radio on the back panel
        L.box((0.06, 0.06, 1.2), (0.5, 0.72, 0.5), swatch="gun_d")  # whip antenna
        L.box((0.36, 0.1, 0.3), (-0.4, -0.68, -0.1), swatch="dark_d")  # notebook
        L.box((0.1, 0.14, 0.6), (LEFT, -0.6, -0.1), swatch="dark")  # sheathed knife
    else:  # engineer
        L.box((1.0, 0.3, 0.9), (0, 0.66, -0.1), swatch="gun")  # tool pack
        L.box((0.12, 0.1, 1.9), (0, 0.72, 0.05), rot=(0, 35, 0), swatch="rust_l")  # pry bar across it
        L.box((0.3, 0.16, 0.42), (-0.4, -0.7, -0.35), swatch=sw["top_d"])  # one pouch


def _pc_pad(sw):
    return sw["knee"] or sw["top_d"]


def _pc_limb(b, limb, sw, cname, o=(0, 0, 0), gear=True):
    L = Limb(b, o)
    W, D, H = R15_LIMB[limb]
    if limb == "head":
        _pc_head(L, sw, cname, gear)
    elif limb == "upper_torso":
        L.box((W, D, H), swatch=sw["top"])
        L.box((1.0, 0.86, 0.14), (0, 0.04, 0.78), swatch=sw["top_d"])  # collar
        if gear:
            _pc_torso_gear(L, sw, cname)
    elif limb == "lower_torso":
        L.box((W, D, H), swatch=sw["trousers"])
        L.box((W + 0.02, D + 0.02, 0.16), (0, 0, 0.06), swatch="dark")  # belt
        L.box((0.3, 0.12, 0.18), (0, -0.53, 0.06), swatch="brass")  # buckle
        if cname == "k9":
            L.cyl(0.22, 0.2, (-0.72, -0.4, 0), rot=(90, 0, 0), swatch="tan")  # the leash, coiled
            L.box((0.1, 0.1, 0.16), (-0.72, -0.5, -0.1), swatch="gun")  # its clip
            L.box((0.4, 0.3, 0.4), (0.76, -0.3, 0), swatch="tan_d")  # dump pouch
        elif cname == "engineer":
            L.box((0.08, 0.1, 0.5), (0.6, -0.54, -0.04), swatch="gun_l")  # wrench
            L.cyl(0.16, 0.14, (-0.5, -0.56, 0), rot=(90, 0, 0), swatch="tan")  # tape roll
            L.box((0.1, 0.08, 0.2), (0.2, -0.55, -0.02), swatch="brass")  # carabiner
        else:
            for x in (-0.6, 0.6):
                L.box((0.3, 0.22, 0.3), (x, -0.5, -0.04), swatch="dark")  # belt pouches
    elif limb == "upper_arm":
        if sw["rolled"]:
            L.box((W, D, 0.7), (0, 0, 0.27), swatch=sw["top"])  # sleeve rolled to the elbow
            L.box((1.04, 1.04, 0.14), (0, 0, -0.06), swatch=sw["top_d"])  # the roll
            L.box((0.9, 0.9, 0.54), (0, 0, -0.35), swatch=sw["skin"])
        else:
            L.box((W, D, H), swatch=sw["top"])
        L.box((1.04, 1.04, 0.24), (0, 0, 0.48), swatch=sw["top_d"])  # shoulder seam
        if sw["border"]:
            L.box((0.4, 0.07, 0.26), (0, -0.53, 0.2), swatch=sw["border"])
        L.box((0.34, 0.1, 0.2), (0, -0.53, 0.2), swatch=sw["accent"])  # sleeve square
        if PC_TAPER:
            L.pad(CAP_R, 0.94, (0, 0, R15_JOINTS["elbow"][2] - R15_POSE["upper_arm"][2]), swatch=sw["skin"] if sw["rolled"] else _pc_pad(sw))  # elbow pad (bare elbow under a rolled sleeve)
    elif limb == "lower_arm":
        skin = sw["skin"] if sw["rolled"] else sw["top"]
        if PC_TAPER:
            L.taper((W, D, H), bottom=PC_TAPER_AT, swatch=skin)  # forearm narrows to the wrist
        else:
            L.box((W, D, H), swatch=skin)
        L.box((0.84, 0.84, 0.24), (0, 0, -0.44), swatch=sw["glove"])  # glove cuff
        if cname == "engineer":
            L.box((1.06, 1.06, 0.1), (0, 0, -0.26), swatch="warning_orange")  # marking tape on the wrist
    elif limb == "hand":
        L.box((0.82, 0.86, 0.32), swatch=sw["glove"])  # a fist, not a boxing glove
        for x in (-0.2, 0.2):
            L.box((0.06, 0.5, 0.33), (x, -0.2, 0), swatch="dark_d")  # finger gaps
    elif limb == "upper_leg":
        L.box((W, D, H), swatch=sw["trousers"])
        if sw["knee"]:
            L.box((0.8, 0.2, 0.46), (0, -0.5, -0.4), swatch=sw["knee"])  # knee pad
        if cname == "k9":
            L.box((0.5, 0.26, 0.5), (0.4, -0.42, 0.1), swatch="tan_d")  # stuffed cargo pocket
        elif cname != "engineer":
            L.box((0.36, 0.22, 0.4), (0.4, -0.45, 0.2), swatch=sw["top_d"])  # thigh pouch
        if PC_TAPER:
            L.pad(CAP_R, 0.94, (0, 0, R15_JOINTS["knee"][2] - R15_POSE["upper_leg"][2]), swatch=sw["knee"] or sw["trousers"])  # knee cap
    elif limb == "lower_leg":
        if PC_TAPER:
            L.taper((W, D, 0.8), (0, 0, 0.25), bottom=0.8, swatch=sw["trousers"])  # shin narrows to the boot
            L.taper((W + 0.02, D + 0.02, 0.5), (0, 0, -0.4), bottom=0.86, swatch=sw["boot"], sides=4)  # boot shaft
        else:
            L.box((W, D, 0.8), (0, 0, 0.25), swatch=sw["trousers"])
            L.box((W + 0.02, D + 0.02, 0.5), (0, 0, -0.4), swatch=sw["boot"])  # boot shaft
    elif limb == "foot":
        L.shoe(sw["boot"])
        if cname == "engineer":
            L.box((0.6, 0.3, 0.26), (0, -0.4, 0.04), swatch="gun_l")  # steel toe cap


def _register_chosen():
    for cname, sw in PC_CLASSES.items():
        for limb in R15_LIMB:
            def fn(b, limb_name=limb, sw_=sw, c=cname):
                _pc_limb(b, limb_name, sw_, c)
            ASSETS[f"pc_{cname}_{limb}"] = (fn, "Chosen", "center")

        def preview(b, _sw=sw, c=cname):
            for limb, (x, y, z) in R15_POSE.items():
                for s in ((1,) if x == 0 else (-1, 1)):
                    _pc_limb(b, limb, _sw, c, (s * x, y, z))
        ASSETS[f"ref_pc_{cname}"] = (preview, "_Reference", "bottom")

    # Weller's gear as rigid accessories for the skinned body (same origin as the limb they
    # sit on: head / upper torso centre), so they weld with the same offset rule as a limb.
    sw = PC_CLASSES["assault"]
    ASSETS["pc_assault_gear_helmet"] = (lambda b: _pc_headgear(Limb(b), sw, "assault"), "Chosen", "center")
    ASSETS["pc_assault_gear_carrier"] = (lambda b: _pc_torso_gear(Limb(b), sw, "assault"), "Chosen", "center")


# R15 joint positions (Blender axes: x right, -y forward, z up; HumanoidRootPart centre at
# the origin, so the ground is at z -3.19: stock HipHeight 2.19 under a 2-stud HRP). These
# are the stock rig's RigAttachment positions, MEASURED in Studio on a fresh
# Players:CreateHumanoidModelFromDescription rig (2026-11-07), not estimated from the limb
# boxes: the root joint pivots at the HRP bottom (hip height), the shoulder sits 0.85 up
# and inside the torso edge, elbow/knee/ankle in the overlap of the two limbs. Right-side
# values; the left mirrors x. They place the skinned Weller's bones and `_Att` points
# (which the importer turns into the Motor6D pivots, so the R15 clips bend where the stock
# rig bends) and the rigid fallback's joint caps. Re-measure before editing, in the Studio
# command bar with a stock rig selected:
#   local c = game.Selection:Get()[1] for _, a in c:GetDescendants() do if a:IsA("Attachment") and a.Name:match("RigAttachment$") then print(a.Parent.Name, a.Name, a.WorldPosition - c.HumanoidRootPart.Position) end end
# (`root` is the HRP centre itself: the HumanoidRootNode bone the importer makes the HRP from.)
R15_JOINTS = {
    "root": (0.0, 0.0, 0.0),
    "root_rig": (0.0, 0.0, -1.0),
    "waist": (0.0, 0.0, -0.6),
    "neck": (0.0, 0.0, 1.099),
    "head_top": (0.0, 0.0, 2.264),
    "shoulder": (0.972, 0.0, 0.847),
    "elbow": (1.47, 0.0, 0.073),
    "wrist": (1.47, 0.0, -0.734),
    "hand_end": (1.47, 0.0, -1.023),
    "hip": (0.498, 0.0, -1.0),
    "knee": (0.498, 0.0, -1.921),
    "ankle": (0.498, 0.0, -2.930),
    "foot_end": (0.498, -0.5, -3.19),
}

# The R15 skeleton with Roblox's exact bone names: (bone, parent, head joint, tail joint).
# Side bones are listed once and mirrored. HumanoidRootNode is the root (Studio turns it
# into the HumanoidRootPart); every other bone becomes the limb MeshPart of that name.
R15_BONES = [
    ("HumanoidRootNode", None, "root", (0.0, 0.0, 0.3)),
    ("LowerTorso", "HumanoidRootNode", "root_rig", "waist"),
    ("UpperTorso", "LowerTorso", "waist", "neck"),
    ("Head", "UpperTorso", "neck", "head_top"),
    ("{S}UpperArm", "UpperTorso", "shoulder", "elbow"),
    ("{S}LowerArm", "{S}UpperArm", "elbow", "wrist"),
    ("{S}Hand", "{S}LowerArm", "wrist", "hand_end"),
    ("{S}UpperLeg", "LowerTorso", "hip", "knee"),
    ("{S}LowerLeg", "{S}UpperLeg", "knee", "ankle"),
    ("{S}Foot", "{S}LowerLeg", "ankle", "foot_end"),
]


def r15_bones():
    """Expands R15_BONES into [(name, parent, head_xyz, tail_xyz)] for both sides."""
    joints = R15_JOINTS

    def at(j, s):
        p = joints[j] if isinstance(j, str) else j
        return (p[0] * s, p[1], p[2])

    out = []
    for name, parent, head, tail in R15_BONES:
        if "{S}" in name:
            for side, s in (("Left", -1), ("Right", 1)):
                out.append((name.format(S=side), parent.format(S=side) if parent else None, at(head, s), at(tail, s)))
        else:
            out.append((name, parent, at(head, 1), at(tail, 1)))
    return out


# ------------------------------------------------------------------ skinned Weller
# One mesh for the whole body (art v2 §B hybrid decision): each limb chain is a tube with a
# vertex loop at every joint; those loops are skinned 50/50 to the two bones that meet there
# (the bridge), everything else 100% to its limb, so a bent elbow stretches a band of skin
# instead of swinging a box corner through the next limb. Detail pieces (belt, pads, cuffs,
# face) are the rigid Chosen's boxes skinned to their limb. Helmet and carrier are NOT in
# this mesh: they stay rigid (pc_assault_gear_*) and weld on in game, as the rifle does.
OCT_CHAMFER = 0.8  # chamfer of the limb octagons (1.0 = box)


def _pc_skin_body(b, sw, cname):
    J = R15_JOINTS
    top, trousers, skin, glove, boot = sw["top"], sw["trousers"], sw["skin"], sw["glove"], sw["boot"]
    W, D, H = R15_LIMB["upper_torso"]

    # torso: one tube from the hips to the shoulders, waist loop 50/50
    rings = b.prism(
        [(J["hip"][2], 0.97, 0.49), (J["waist"][2], 0.995, 0.5), (-0.2, 0.97, 0.5), (0.75, 0.97, 0.5), (1.1, 0.8, 0.42)],
        swatch=[trousers, top, top, top], chamfer=OCT_CHAMFER,
    )
    b.weight(rings[0], {"LowerTorso": 1.0})
    b.weight(rings[1], {"LowerTorso": 0.5, "UpperTorso": 0.5})
    for r in rings[2:]:
        b.weight(r, {"UpperTorso": 1.0})
    # neck: hidden inside the torso cap and the head, shows only when the head turns
    rings = b.prism([(0.95, 0.36, 0.33), (J["neck"][2], 0.36, 0.33), (1.25, 0.36, 0.33)], swatch=skin, cap_bottom=False, cap_top=False, chamfer=OCT_CHAMFER)
    b.weight(rings[0], {"UpperTorso": 1.0})
    b.weight(rings[1], {"UpperTorso": 0.5, "Head": 0.5})
    b.weight(rings[2], {"Head": 1.0})

    LT = Limb(b, R15_POSE["lower_torso"], bone="LowerTorso")
    W2, D2, _ = R15_LIMB["lower_torso"]
    LT.box((W2 + 0.02, D2 + 0.02, 0.16), (0, 0, 0.06), swatch="dark")  # belt
    LT.box((0.3, 0.12, 0.18), (0, -0.53, 0.06), swatch="brass")  # buckle
    for x in (-0.6, 0.6):
        LT.box((0.3, 0.22, 0.3), (x, -0.5, -0.04), swatch="dark")  # belt pouches
    UT = Limb(b, R15_POSE["upper_torso"], bone="UpperTorso")
    UT.box((1.0, 0.86, 0.14), (0, 0.04, 0.78), swatch=sw["top_d"])  # collar
    _pc_head(Limb(b, R15_POSE["head"], bone="Head"), sw, cname, gear=False)

    for side, s in (("Left", -1), ("Right", 1)):
        ua, la, ha = f"{side}UpperArm", f"{side}LowerArm", f"{side}Hand"
        x = s * R15_POSE["upper_arm"][0]
        sleeve = skin if sw["rolled"] else top
        # arm: rounded shoulder, elbow loop, forearm tapering to the wrist loop, glove
        rings = b.prism(
            [(J["hand_end"][2], 0.40, 0.42), (-0.77, 0.40, 0.42), (J["wrist"][2], 0.5 * PC_TAPER_AT, 0.5 * PC_TAPER_AT),
             (-0.33, 0.46, 0.46), (J["elbow"][2], 0.5, 0.5), (0.9, 0.5, 0.5), (1.04, 0.42, 0.42)],
            swatch=[glove, glove, sleeve, sleeve, top, top], loc=(x, 0, 0), chamfer=OCT_CHAMFER,
        )
        b.weight(rings[0] + rings[1], {ha: 1.0})
        b.weight(rings[2], {la: 0.5, ha: 0.5})
        b.weight(rings[3], {la: 1.0})
        b.weight(rings[4], {ua: 0.5, la: 0.5})
        b.weight(rings[5] + rings[6], {ua: 1.0})
        UA = Limb(b, (x, 0, R15_POSE["upper_arm"][2]), bone=ua)
        UA.box((1.04, 1.04, 0.24), (0, 0, 0.48), swatch=sw["top_d"])  # shoulder seam
        if s < 0:  # the square is on the LEFT sleeve only (one mesh: no mirrored patch)
            if sw["border"]:
                UA.box((0.4, 0.07, 0.26), (0, -0.53, 0.2), swatch=sw["border"])
            UA.box((0.34, 0.1, 0.2), (0, -0.53, 0.2), swatch=sw["accent"])
        pad = b.box((0.56, 0.24, 0.5), (x, 0.44, J["elbow"][2]), swatch=_pc_pad(sw))  # elbow pad, behind the joint
        b.weight_split(pad, J["elbow"][2], ua, la)
        LA = Limb(b, (x, 0, R15_POSE["lower_arm"][2]), bone=la)
        LA.box((0.84, 0.84, 0.24), (0, 0, -0.44), swatch=glove)  # glove cuff
        HA = Limb(b, (x, 0, R15_POSE["hand"][2]), bone=ha)
        for fx in (-0.2, 0.2):
            HA.box((0.06, 0.5, 0.33), (fx, -0.2, 0), swatch="dark_d")  # finger gaps

        ul, ll, ft = f"{side}UpperLeg", f"{side}LowerLeg", f"{side}Foot"
        x = s * R15_POSE["upper_leg"][0]
        # leg: thigh, knee loop, shin tapering, boot shaft step, ankle loop, foot
        rings = b.prism(
            [(J["foot_end"][2], 0.505, 0.5), (-3.05, 0.505, 0.5), (J["ankle"][2], 0.5, 0.49), (-2.49, 0.5, 0.49), (-2.43, 0.4, 0.39),
             (J["knee"][2], 0.47, 0.46), (-1.25, 0.495, 0.485), (-0.79, 0.495, 0.485)],
            swatch=[boot, boot, boot, boot, trousers, trousers, trousers], loc=(x, 0, 0), chamfer=OCT_CHAMFER,
        )
        b.weight(rings[0] + rings[1], {ft: 1.0})
        b.weight(rings[2], {ll: 0.5, ft: 0.5})
        b.weight(rings[3] + rings[4], {ll: 1.0})
        b.weight(rings[5], {ul: 0.5, ll: 0.5})
        b.weight(rings[6] + rings[7], {ul: 1.0})
        UL = Limb(b, (x, 0, R15_POSE["upper_leg"][2]), bone=ul)
        if sw["knee"]:
            pad = b.box((0.8, 0.2, 0.46), (x, -0.5, J["knee"][2] + 0.03), swatch=sw["knee"])  # knee pad
            b.weight_split(pad, J["knee"][2], ul, ll)
        if cname != "engineer":
            UL.box((0.36, 0.22, 0.4), (s * 0.35, -0.45, 0.2), swatch=sw["top_d"])  # thigh pouch, outer side
        FT = Limb(b, (x, 0, R15_POSE["foot"][2]), bone=ft)
        FT.box((1.01, 1.0, 0.08), (0, 0, -0.115), swatch="dark_d")  # sole


RIGGED = {}


def rigged(name, collection, deps=()):
    def deco(fn):
        RIGGED[name] = (fn, collection, tuple(deps))
        return fn

    return deco


@rigged("pc_assault_skinned", "Chosen", deps=("pc_assault_gear_helmet", "pc_assault_gear_carrier"))
def weller_skinned(b):
    _pc_skin_body(b, PC_CLASSES["assault"], "assault")
    return r15_bones()


_register_chosen()


# ------------------------------------------------------------------ scene plumbing
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 0.28  # 1 BU = 1 stud = 0.28 m
    scene.unit_settings.length_unit = "METERS"
    return scene


def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def export_fbx(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=False,
        apply_scale_options="FBX_SCALE_NONE",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        object_types={"MESH"},
        mesh_smooth_type="OFF",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
        embed_textures=False,
    )


def export_fbx_rigged(mesh_obj, arm_obj, path):
    """FBX with the armature: same units/axes as export_fbx, deform bones only, no leaf bones
    (Roblox would read them as extra joints), no animation. Modifiers other than the
    armature are applied; the skin binds to the rest pose."""
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=False,
        apply_scale_options="FBX_SCALE_NONE",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        object_types={"MESH", "ARMATURE"},
        mesh_smooth_type="OFF",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        armature_nodetype="NULL",
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        use_armature_deform_only=True,
        bake_anim=False,
        path_mode="STRIP",
        embed_textures=False,
    )


def make_armature(name, bones, collection):
    """An armature from [(bone, parent, head, tail)] in rest pose, bones named exactly."""
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for bone, parent, head, tail in bones:
        eb = arm_data.edit_bones.new(bone)
        eb.head, eb.tail = Vector(head), Vector(tail)
        eb.use_deform = True
        if parent:
            eb.parent = edit[parent]
        edit[bone] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


def build_rigged(name, fn, col_name, mat):
    """Builds a skinned body: mesh with vertex groups + armature, mesh parented to it with an
    Armature modifier. The mesh keeps the HumanoidRootPart-centred origin of the bones."""
    b = Builder(skinned=True)
    bones = fn(b)
    col = get_collection(col_name)
    obj = b.finish(name, col, mat, pivot="center")
    bone_names = {bone for bone, _, _, _ in bones}
    missing = [g for g in b.groups if g not in bone_names]
    if missing:
        raise RuntimeError(f"{name}: vertex groups without a bone: {missing}")
    unweighted = sum(1 for v in obj.data.vertices if not v.groups or abs(sum(g.weight for g in v.groups) - 1.0) > 1e-4)
    if unweighted:
        raise RuntimeError(f"{name}: {unweighted} vertices are not fully skinned")
    arm = make_armature(name + "_rig", bones, col)
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    print(f"built {name}: {obj['tri_count']} tris, {len(bones)} bones, {len(b.groups)} groups")
    return obj, arm


def pose_bones(arm, pose):
    """pose = {bone: (x_deg, y_deg, z_deg)} in each bone's local axes; {} resets to rest."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = tuple(math.radians(d) for d in pose.get(pb.name, (0, 0, 0)))
    bpy.context.view_layer.update()


def hang_on_bone(obj, arm, bone):
    """Keeps `obj` where it is in rest pose but following `bone` (an accessory on a limb)."""
    con = obj.constraints.new("CHILD_OF")
    con.target, con.subtarget = arm, bone
    bpy.context.view_layer.update()
    con.inverse_matrix = (arm.matrix_world @ arm.pose.bones[bone].matrix).inverted()
    return con


# R15 attachment points for the 15-part variant of a skinned body (`<name>_Att` empties
# under the part's mesh, the Roblox custom-body FBX convention). Rig attachments sit on the
# joints of R15_JOINTS (the measured stock pivots); the rest sit on the limb centres.
# Right-side values; the left mirrors x.
def r15_attachments():
    J = R15_JOINTS
    P = R15_POSE
    common = {
        "Head": [("NeckRigAttachment", J["neck"]), ("FaceCenterAttachment", P["head"]), ("FaceFrontAttachment", (0, -0.58, P["head"][2])),
                 ("HairAttachment", J["head_top"]), ("HatAttachment", J["head_top"])],
        "UpperTorso": [("NeckRigAttachment", J["neck"]), ("NeckAttachment", J["neck"]), ("WaistRigAttachment", J["waist"]),
                       ("LeftShoulderRigAttachment", (-J["shoulder"][0], 0, J["shoulder"][2])), ("RightShoulderRigAttachment", J["shoulder"]),
                       ("LeftCollarAttachment", (-1.0, 0, 1.0)), ("RightCollarAttachment", (1.0, 0, 1.0)),
                       ("BodyFrontAttachment", (0, -0.5, P["upper_torso"][2])), ("BodyBackAttachment", (0, 0.5, P["upper_torso"][2]))],
        "LowerTorso": [("RootRigAttachment", J["root_rig"]), ("WaistRigAttachment", J["waist"]),
                       ("LeftHipRigAttachment", (-J["hip"][0], 0, J["hip"][2])), ("RightHipRigAttachment", J["hip"]),
                       ("WaistCenterAttachment", P["lower_torso"]), ("WaistFrontAttachment", (0, -0.5, P["lower_torso"][2])),
                       ("WaistBackAttachment", (0, 0.5, P["lower_torso"][2]))],
    }
    sided = {
        "{S}UpperArm": [("{S}ShoulderRigAttachment", J["shoulder"]), ("{S}ElbowRigAttachment", J["elbow"]), ("{S}ShoulderAttachment", (P["upper_arm"][0], 0, 0.99))],
        "{S}LowerArm": [("{S}ElbowRigAttachment", J["elbow"]), ("{S}WristRigAttachment", J["wrist"])],
        "{S}Hand": [("{S}WristRigAttachment", J["wrist"]), ("{S}GripAttachment", P["hand"])],
        "{S}UpperLeg": [("{S}HipRigAttachment", J["hip"]), ("{S}KneeRigAttachment", J["knee"])],
        "{S}LowerLeg": [("{S}KneeRigAttachment", J["knee"]), ("{S}AnkleRigAttachment", J["ankle"])],
        "{S}Foot": [("{S}AnkleRigAttachment", J["ankle"]), ("{S}FootAttachment", (P["foot"][0], 0, J["foot_end"][2]))],
    }
    out = dict(common)
    for part, atts in sided.items():
        for side, sgn in (("Left", -1), ("Right", 1)):
            out[part.format(S=side)] = [(a.format(S=side), (p[0] * sgn, p[1], p[2])) for a, p in atts]
    return out


def split_rigged(obj, arm, name, collection):
    """The 15-part variant: one mesh object per R15 part holding the faces whose summed
    weights favour that bone (bridge faces keep their 50/50 verts), each skinned to the same
    armature, with the part's `_Att` attachment empties. Returns [objects, empties]."""
    me = obj.data
    group_names = [g.name for g in obj.vertex_groups]
    parts, empties = [], []
    for part, atts in r15_attachments().items():
        gi = group_names.index(part)
        bm = bmesh.new()
        bm.from_mesh(me)
        dl = bm.verts.layers.deform.verify()
        drop = []
        for f in bm.faces:
            scores = {}
            for v in f.verts:
                for k, w in v[dl].items():
                    scores[k] = scores.get(k, 0.0) + w
            if max(scores, key=scores.get) != gi:
                drop.append(f)
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        part_me = bpy.data.meshes.new(f"{name}_{part}")
        bm.to_mesh(part_me)
        bm.free()
        part_me.materials.append(me.materials[0])
        for p in part_me.polygons:
            p.use_smooth = False
        pobj = bpy.data.objects.new(part, part_me)
        collection.objects.link(pobj)
        for g in group_names:
            pobj.vertex_groups.new(name=g)
        pobj.parent = arm
        pobj.modifiers.new("Armature", "ARMATURE").object = arm
        parts.append(pobj)
        for att, pos in atts:
            e = bpy.data.objects.new(att + "_Att", None)
            e.empty_display_size = 0.1
            e.location = pos
            e.parent = pobj
            collection.objects.link(e)
            empties.append(e)
    return parts, empties


def export_fbx_parts(parts, empties, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts + empties + [arm]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, apply_unit_scale=False, apply_scale_options="FBX_SCALE_NONE", global_scale=1.0,
        axis_forward="-Z", axis_up="Y", object_types={"MESH", "ARMATURE", "EMPTY"}, mesh_smooth_type="OFF",
        use_mesh_modifiers=True, add_leaf_bones=False, armature_nodetype="NULL", primary_bone_axis="Y",
        secondary_bone_axis="X", use_armature_deform_only=True, bake_anim=False, path_mode="STRIP", embed_textures=False,
    )


# A quick bend to prove the weights: elbow, knee, waist and neck each move one bridge loop.
PROOF_POSE = {
    "LeftLowerArm": (-70, 0, 0),
    "LeftUpperArm": (-35, 0, 0),
    "RightUpperLeg": (-45, 0, 0),
    "RightLowerLeg": (60, 0, 0),
    "UpperTorso": (15, 0, 10),
    "Head": (0, 0, -30),
}


def setup_render(scene):
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_shadows = True
    shading.shadow_intensity = 0.4
    shading.show_cavity = False
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.16, 0.18, 0.21)
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.display_settings.display_device = "sRGB"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame_and_render(scene, cam, objs, path, size=(640, 640), direction=(1.0, -1.2, 0.8)):
    # bounding box of the objects to show
    pts = []
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    bpy.context.view_layer.update()  # matrix_world is stale until the depsgraph runs
    for o in objs:
        pts.extend(o.matrix_world @ Vector(c) for c in o.bound_box)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)
    fov = cam.data.angle
    dist = radius / math.tan(fov / 2) * 1.15
    d = Vector(direction).normalized()
    cam.location = center + d * dist
    cam.data.clip_end = max(cam.data.clip_end, dist + radius * 4)  # the lineup is hundreds of studs long
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    only = None
    if "--only" in argv:
        only = argv[argv.index("--only") + 1 :]
    os.makedirs(EXPORT, exist_ok=True)
    os.makedirs(PREVIEWS, exist_ok=True)

    scene = reset_scene()
    img = build_palette_image()
    mat = build_palette_material(img)
    cam = setup_render(scene)

    if only:  # a skinned body's previews need its gear
        for name, (_, _, deps) in RIGGED.items():
            if name in only:
                only = list(only) + [d for d in deps if d not in only]

    built = {}
    for name, (fn, col_name, pivot) in ASSETS.items():
        if only and name not in only:
            continue
        b = Builder()
        fn(b)
        obj = b.finish(name, get_collection(col_name), mat, pivot=pivot)
        built[name] = obj
        print(f"built {name}: {obj['tri_count']} tris")

    # lay out for the lineup render (x spacing), export + preview each asset at the origin first
    ref = built.get("ref_human_5st")
    for name, obj in built.items():
        if not name.startswith("ref_"):
            export_fbx(obj, os.path.join(EXPORT, name + ".fbx"))
        d = obj.dimensions
        print(f"dims {name}: roblox Size = Vector3.new({d.x:.2f}, {d.z:.2f}, {d.y:.2f})")
        # Bounds centre relative to the design origin, Roblox axis order: the `offset` of
        # a MeshAssets entry (limbs: the R15 limb centre; env pieces: the floor centre, so
        # collider boxes can be written in build coordinates).
        c = [(min(v[i] for v in obj.bound_box) + max(v[i] for v in obj.bound_box)) / 2 for i in range(3)]
        print(f"offset {name}: Vector3.new({c[0]:.3f}, {c[2]:.3f}, {c[1]:.3f})")
        objs = [obj]
        if ref is not None and ref is not obj and name.startswith("env_"):
            # environment pieces are judged against the character: stand the reference beside them
            ref.location = (max(c[0] for c in obj.bound_box) + 1.5, min(c[1] for c in obj.bound_box), 0)
            objs.append(ref)
        frame_and_render(scene, cam, objs, os.path.join(PREVIEWS, name + ".png"))
        if ref is not None:
            ref.location = (0, 0, 0)

    # skinned bodies: mesh + armature, exported together; previews in rest pose with the
    # rigid gear sitting on its limbs, then bent (PROOF_POSE) with the gear following the bones
    rigs = {}
    gear_on = {"pc_assault_gear_helmet": ("Head", R15_POSE["head"]), "pc_assault_gear_carrier": ("UpperTorso", R15_POSE["upper_torso"])}
    for name, (fn, col_name, deps) in RIGGED.items():
        if only and name not in only:
            continue
        obj, arm = build_rigged(name, fn, col_name, mat)
        built[name] = obj
        rigs[name] = arm
        export_fbx_rigged(obj, arm, os.path.join(EXPORT, name + ".fbx"))
        export_fbx(obj, os.path.join(EXPORT, name + "_mesh.fbx"))  # the same body unrigged, for Avatar Auto Setup
        parts, empties = split_rigged(obj, arm, name, get_collection("_Reference"))
        export_fbx_parts(parts, empties, arm, os.path.join(EXPORT, name + "_parts.fbx"))
        print(f"split {name}: " + ", ".join(f"{p.name} {sum(len(f.vertices) - 2 for f in p.data.polygons)}" for p in parts))
        for o in parts + empties:  # the split is export-only; the one-mesh body is the asset
            bpy.data.objects.remove(o)
        d = obj.dimensions
        print(f"dims {name}: roblox Size = Vector3.new({d.x:.2f}, {d.z:.2f}, {d.y:.2f}); feet at z {min(v[2] for v in obj.bound_box):.2f}")
        gear = [built[g] for g in deps if g in built]
        for g in gear:
            g.location = gear_on[g.name][1]
        frame_and_render(scene, cam, [obj] + gear, os.path.join(PREVIEWS, name + ".png"), direction=(1.0, -1.4, 0.5))
        cons = [hang_on_bone(g, arm, gear_on[g.name][0]) for g in gear]
        pose_bones(arm, PROOF_POSE)
        frame_and_render(scene, cam, [obj] + gear, os.path.join(PREVIEWS, name + "_posed.png"), direction=(1.0, -1.4, 0.5))
        frame_and_render(scene, cam, [obj] + gear, os.path.join(PREVIEWS, name + "_posed_side.png"), direction=(-1.6, -0.5, 0.3))
        pose_bones(arm, {})
        for g, con in zip(gear, cons):
            g.constraints.remove(con)
            g.location = (0, 0, 0)


    # whole-body triangle counts (the assembled preview figure is exactly the 15 limbs)
    for tname, cap in BODY_TRI_CAP.items():
        fig = built.get(f"ref_inf_{tname}")
        if fig is not None:
            tris = fig["tri_count"]
            print(f"body inf_{tname}: {tris} tris (cap {cap}){'  OVER CAP' if tris > cap else ''}")

    # Two lineups: the bodies and hand-held things at a readable scale, and the environment
    # against the 5-stud reference. Individual limb meshes are left out (the figures show them).
    def lineup(names, path, size, direction):
        x = 0.0
        objs = []
        for name in names:
            obj = built[name]
            width = max(obj.dimensions.x, obj.dimensions.y, 1.0)
            x += width / 2 + 0.8
            if name in rigs:  # the mesh follows its armature; stand it on the ground
                rigs[name].location = (x, 0, -min(v[2] for v in obj.bound_box))
            else:
                obj.location.x = x
                obj.location.z = obj.dimensions.z / 2 if ASSETS[name][2] == "center" else 0.0
            x += width / 2 + 0.8
            objs.append(obj)
        if objs:
            frame_and_render(scene, cam, objs, path, size=size, direction=direction)

    chars = [n for n in built if n.startswith(("ref_inf_", "ref_pc_", "prop_", "wpn_", "pick_"))]
    env = [n for n in built if n.startswith("env_")] + (["ref_human_5st"] if ref is not None else [])
    lineup(chars, os.path.join(PREVIEWS, "lineup_chars.png"), (1800, 700), (0.35, -1.0, 0.55))
    lineup(env, os.path.join(PREVIEWS, "lineup_env.png"), (1800, 700), (0.35, -1.0, 0.55))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    total = sum(o["tri_count"] for o in built.values())
    print(f"saved {BLEND}; {len(built)} assets, {total} tris total")


if __name__ == "__main__":
    main()
