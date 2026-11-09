"""Checkpoint Delta in Blender: the layout the game builds, visible.

The map itself stays plain Parts built by `src/server/ArenaService.luau` (exact collision,
built-in materials, streaming, the building kit). This script reads the layout tables out of
that file (HILLS, DRESSING, PROPS, RAMPS, PATCHES, BUILDINGS, the generated Gate line, the
Pens ring and the perches), rebuilds the same geometry in a fresh Blender scene with the
real environment meshes (`assets/3d/export/*.fbx`) standing on the same ground the game's
raycast finds, and reports every placement rule the layout breaks (a piece straddling a
hill slope, a piece in the Warden lane, in the LZ pad, inside a building footprint).

    blender --background --python assets/3d/build/delta_map.py            # build + renders
    blender --background --python assets/3d/build/delta_map.py -- --no-render

Outputs: `assets/3d/delta_map.blend`, `assets/3d/build/previews/map_*.png` (top-down of the
whole map and each district) and the problem list on stdout.

Round trip (move things in Blender, write the numbers back): every static table entry is
an object carrying `arena_table` / `arena_index`; after moving it in the viewport run
`write_back()` from this module in the live Blender (the MCP: `exec(open(path).read());
write_back()`), which rewrites that entry's x / z / yaw in ArenaService.luau in place.
Entries the Luau generates in loops (the Gate T-walls, the Pens ring, the perch containers)
are read-only here (`arena_locked`).

Axes: Roblox (x, y, z) = Blender (x, z, y); Roblox yaw about +Y = Blender rotation -yaw
about +Z (the swap mirrors handedness).
"""

import math
import os
import re
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
ARENA_LUAU = os.path.join(ROOT, "src", "server", "ArenaService.luau")
MESH_LUAU = os.path.join(ROOT, "src", "shared", "MeshAssets.luau")
EXPORT = os.path.join(ROOT, "assets", "3d", "export")
BLEND = os.path.join(ROOT, "assets", "3d", "delta_map.blend")
PREVIEWS = os.path.join(ROOT, "assets", "3d", "build", "previews")

HALF = 300
STRADDLE_TOLERANCE = 0.35  # studs of ground-height difference across a footprint
WARDEN_LANE = (-41.0, -19.0, -292.0, 2.0)  # x0, x1, z0, z1 (lamp posts sit on the -42 edge)
LZ_PAD = (-110.0, -70.0, -110.0, -70.0)

# ------------------------------------------------------------------ a Luau literal reader


class LuauTable:
    """The subset of Luau table literals the layout tables use: strings, numbers, booleans,
    nested tables, `Vector3.new(...)` / `Vector2.new(...)`, `if a then b else c` (dropped to
    None), and `-- comments`. Records the character span of every entry of the top-level
    array so a caller can rewrite one entry in place."""

    def __init__(self, text, start):
        self.text = text
        self.i = start
        self.spans = []

    def skip(self):
        t = self.text
        while self.i < len(t):
            c = t[self.i]
            if c in " \t\r\n,":
                self.i += 1
            elif t.startswith("--", self.i):
                j = t.find("\n", self.i)
                self.i = len(t) if j < 0 else j + 1
            else:
                break

    def parse_table(self, record=False):
        assert self.text[self.i] == "{", self.text[self.i : self.i + 40]
        self.i += 1
        items, dict_ = [], {}
        while True:
            self.skip()
            if self.text[self.i] == "}":
                self.i += 1
                return dict_ if dict_ and not items else (items if items else dict_)
            start = self.i
            m = re.match(r"([A-Za-z_]\w*)\s*=", self.text[self.i :])
            if m and not self.text.startswith("if ", self.i):
                key = m.group(1)
                self.i += m.end()
                self.skip()
                dict_[key] = self.parse_value()
            else:
                items.append(self.parse_value())
                if record:
                    self.spans.append((start, self.i))

    def parse_value(self):
        t = self.text
        self.skip()
        c = t[self.i]
        if c == "{":
            return self.parse_table()
        if c == '"':
            j = t.index('"', self.i + 1)
            s = t[self.i + 1 : j]
            self.i = j + 1
            return s
        m = re.match(r"[A-Za-z_][\w.]*\(", t[self.i :])  # Vector3.new(...), Color3.fromRGB(...)
        if m:
            self.i += m.end()
            vals = []
            while True:
                self.skip()
                if t[self.i] == ")":
                    self.i += 1
                    return tuple(vals)
                vals.append(self.parse_value())
        m = re.match(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", t[self.i :])
        if m:
            self.i += m.end()
            v = float(m.group(0))
            return v
        for word, val in (("true", True), ("false", False), ("nil", None)):
            if t.startswith(word, self.i):
                self.i += len(word)
                return val
        if t.startswith("if ", self.i):
            # `if cond then a else b` on one line: not a layout number, keep None
            j = t.find("\n", self.i)
            self.i = j
            return None
        m = re.match(r"[A-Za-z_][\w.]*", t[self.i :])  # an identifier (Enum.Material.X ...)
        if m:
            self.i += m.end()
            return m.group(0)
        raise ValueError("unparsed at %d: %r" % (self.i, t[self.i : self.i + 40]))


def read_table(text, name, record=False):
    """Returns (value, literal_start, literal_end, spans) of `local NAME... = {`."""
    m = re.search(r"^local %s\b[^\n=]*=\s*\{" % re.escape(name), text, re.M)
    assert m, name
    p = LuauTable(text, m.end() - 1)
    value = p.parse_table(record=record)
    return value, m.end() - 1, p.i, p.spans


def load_layout():
    text = open(ARENA_LUAU, encoding="utf-8").read()
    hills, *_ = read_table(text, "HILLS")
    dressing, d0, d1, dspans = read_table(text, "DRESSING", record=True)
    props, p0, p1, pspans = read_table(text, "PROPS", record=True)
    ramps, *_ = read_table(text, "RAMPS")
    patches, *_ = read_table(text, "PATCHES")
    buildings, *_ = read_table(text, "BUILDINGS")
    perimeter, *_ = read_table(text, "PERIMETER")
    # The entries ArenaService adds in code after the literal (mirror of the Luau loops).
    generated = []
    for k in range(0, 74):
        if k < 32 or k > 34:
            generated.append(
                {"name": "env_twall", "x": -294 + 8 * k, "z": -274, "yaw": 0, "lift": 2.8 if k in (18, 51) else None}
            )
    for x in (-295.5, -289.6, -283, -276.4, -269.8, -263.2, -238.3, -231.7, -225.1, -218.5):
        generated.append({"name": "env_hesco_tall", "x": x, "z": 146, "yaw": 0})
        generated.append({"name": "env_hesco_tall", "x": x, "z": 94, "yaw": 0})
    for z in (100, 106.5, 133.5, 140):
        generated.append({"name": "env_hesco_tall", "x": -219, "z": z, "yaw": 90})
    generated += [
        {"name": "env_container_olive", "x": -124, "z": -82, "yaw": 0},
        {"name": "env_container_rust", "x": -130, "z": -45, "yaw": 0},
        {"name": "env_container_rust", "x": -10, "z": -10, "yaw": 90},
        {"name": "env_container_rust", "x": 250, "z": 32, "yaw": 90, "lift": 9.55},
        {"name": "env_container_olive", "x": 56, "z": -45, "yaw": 0},
    ]
    mesh_text = open(MESH_LUAU, encoding="utf-8").read()
    meshes, *_ = read_table(mesh_text, "MESHES")
    return {
        "hills": hills,
        "dressing": dressing,
        "props": props,
        "generated": generated,
        "ramps": ramps,
        "patches": patches,
        "buildings": buildings,
        "perimeter": perimeter,
        "meshes": meshes,
        "spans": {"DRESSING": dspans, "PROPS": pspans},
    }


# ------------------------------------------------------------------ the ground the raycast finds


def ground_height(hills, x, z):
    """What ArenaService's placement raycast returns at (x, z): the highest hill surface
    (top, wedge slope or solid corner block) or the floor at 0. Roads / pads (0.2-0.3) are
    ignored."""
    best = 0.0
    for h in hills:
        top = h["top"]
        hx, hz = top[0] / 2, top[1] / 2
        height = h["height"]
        base = h.get("base") or 0
        slope = height * 1.2
        open_ = h.get("open") or {}
        dx, dz = x - h["x"], z - h["z"]
        if abs(dx) <= hx and abs(dz) <= hz:
            best = max(best, base + height)
            continue
        inside_x, inside_z = abs(dx) <= hx, abs(dz) <= hz
        if inside_x and hz < abs(dz) <= hz + slope:
            side = "north" if dz > 0 else "south"
            if not open_.get(side):
                t = 1 - (abs(dz) - hz) / slope
                best = max(best, base + height * t)
        elif inside_z and hx < abs(dx) <= hx + slope:
            side = "east" if dx > 0 else "west"
            if not open_.get(side):
                t = 1 - (abs(dx) - hx) / slope
                best = max(best, base + height * t)
        elif hx < abs(dx) <= hx + slope and hz < abs(dz) <= hz + slope:
            xs = "east" if dx > 0 else "west"
            zs = "north" if dz > 0 else "south"
            if not open_.get(xs) and not open_.get(zs):
                best = max(best, base + height)
    return best


def footprint_corners(x, z, sx, sz, yaw):
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    out = []
    for ux, uz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = ux * sx / 2, uz * sz / 2
        # Roblox CFrame.Angles(0, yaw, 0): x' = x cos + z sin, z' = -x sin + z cos
        out.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return out


# ------------------------------------------------------------------ Blender scene


def rb(x, y, z):
    """Roblox (x, y, z) -> Blender location."""
    return Vector((x, z, y))


KIND_COLORS = {
    "hill": (0.40, 0.376, 0.306, 1),
    "slope": (0.32, 0.29, 0.235, 1),
    "road": (0.227, 0.235, 0.25, 1),
    "concrete": (0.478, 0.47, 0.447, 1),
    "wall": (0.408, 0.392, 0.36, 1),
    "building": (0.57, 0.58, 0.53, 1),
    "mesh": (0.62, 0.6, 0.56, 1),
    "prop": (0.72, 0.62, 0.45, 1),
    "ramp": (0.43, 0.345, 0.235, 1),
    "steel": (0.25, 0.26, 0.275, 1),
    "patch": (0.27, 0.235, 0.19, 1),
    "problem": (0.95, 0.12, 0.1, 1),
    "warn": (0.95, 0.6, 0.1, 1),
}


def collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(col)
    return col


def new_object(name, mesh, col, kind):
    obj = bpy.data.objects.new(name, mesh)
    obj.color = KIND_COLORS[kind]
    col.objects.link(obj)
    return obj


def box(name, col, kind, center, size, yaw=0.0):
    """An axis box from Roblox centre + size (x, y, z), yawed about up."""
    mesh = bpy.data.meshes.new(name)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    verts = [(ux * sx, uz * sz, uy * sy) for ux in (-1, 1) for uz in (-1, 1) for uy in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = new_object(name, mesh, col, kind)
    obj.location = rb(*center)
    obj.rotation_euler = (0, 0, math.radians(-yaw))
    return obj


def wedge(name, col, kind, center, size, yaw=0.0):
    """A Roblox WedgePart: rises from its -Z edge (thin) to its +Z face (full height), the
    same frame as `box` so the Luau's CFrame goes straight in."""
    mesh = bpy.data.meshes.new(name)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    # Blender local: X = Roblox x, Y = Roblox z, Z = Roblox y
    verts = [
        (-sx, -sz, -sy), (sx, -sz, -sy),  # thin edge at -Z, floor
        (sx, sz, -sy), (-sx, sz, -sy),  # +Z face, floor
        (sx, sz, sy), (-sx, sz, sy),  # +Z face, top
    ]
    faces = [(0, 1, 2, 3), (3, 2, 4, 5), (0, 5, 4, 1), (0, 3, 5), (1, 4, 2)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = new_object(name, mesh, col, kind)
    obj.location = rb(*center)
    obj.rotation_euler = (0, 0, math.radians(-yaw))
    return obj


def build_hill(h, col):
    top = h["top"]
    height, base = h["height"], h.get("base") or 0
    cy = base + height / 2
    slope = height * 1.2
    open_ = h.get("open") or {}
    hx, hz = top[0] / 2, top[1] / 2
    box(h["name"], col, "hill", (h["x"], cy, h["z"]), (top[0], height, top[1]))
    sides = {
        "south": (0, -(hz + slope / 2), 0, top[0]),
        "north": (0, hz + slope / 2, 180, top[0]),
        "east": (hx + slope / 2, 0, -90, top[1]),
        "west": (-(hx + slope / 2), 0, 90, top[1]),
    }
    for side, (ox, oz, yaw, w) in sides.items():
        if open_.get(side):
            continue
        wedge(h["name"] + "_" + side, col, "slope", (h["x"] + ox, cy, h["z"] + oz), (w, height, slope), yaw)
    for sx in (-1, 1):
        for sz in (-1, 1):
            if open_.get("east" if sx > 0 else "west") or open_.get("north" if sz > 0 else "south"):
                continue
            box(
                h["name"] + "_corner",
                col,
                "slope",
                (h["x"] + sx * (hx + slope / 2), cy, h["z"] + sz * (hz + slope / 2)),
                (slope, height, slope),
            )


def build_terrain(layout):
    col = collection("Terrain")
    box("Floor", col, "hill", (0, -0.5, 0), (600, 1, 600))
    for h in layout["hills"]:
        build_hill(h, col)
    # The perimeter (docs/LEVELS.md A15): no walls since 2026-11-07. The fence line, the
    # ground past it, the west berm and the highway's run-on, as ArenaService builds them.
    outer = collection("Perimeter")
    box("OuterGroundN", outer, "hill", (0, -0.5, 500), (1400, 1, 400))
    box("OuterGroundS", outer, "hill", (0, -0.5, -500), (1400, 1, 400))
    box("OuterGroundE", outer, "hill", (500, -0.5, 0), (400, 1, 600))
    box("OuterGroundW", outer, "hill", (-500, -0.5, 0), (400, 1, 600))
    box("CityRoad", outer, "road", (-30, 0.1, -500), (24, 0.2, 400))
    for z0, z1 in ((-30, 300), (-300, -60)):
        length, zc = z1 - z0, (z0 + z1) / 2
        wedge("BermFace", outer, "slope", (-314, 5, zc), (length, 10, 20), 90)
        box("BermCrest", outer, "hill", (-327, 5, zc), (6, 10, length))
        wedge("BermBack", outer, "slope", (-340, 5, zc), (length, 10, 20), -90)
    box("PensFill", outer, "hill", (-306, 3, 120), (12, 6, 74))
    for sx in (-1, 1):
        box("HighwayRunOn", outer, "hill", (sx * 350, 6, -45), (100, 12, 18))
        wedge("HighwayRunOnSlopeS", outer, "slope", (sx * 350, 6, -61.2), (100, 12, 14.4), 0)
        wedge("HighwayRunOnSlopeN", outer, "slope", (sx * 350, 6, -28.8), (100, 12, 14.4), 180)
    for k in range(50):
        along = -294 + 12 * k
        for x, z, yaw in ((along, 299.6, 0), (along, -299.6, 0), (299.6, along, 90), (-299.6, along, 90)):
            if yaw == 90 and -73 < along < -17:
                continue
            gy = min(ground_height(layout["hills"], x + dx, z + dz) for dx, dz in (
                (-6 * (yaw == 0), -6 * (yaw == 90)), (0, 0), (6 * (yaw == 0), 6 * (yaw == 90))))
            box("Fence", outer, "steel", (x, gy + 4.95, z), (12.06, 9.9, 0.3), yaw)
    roads = collection("Roads")
    box("MainRoad", roads, "road", (-30, 0.1, 0), (16, 0.2, 600))
    box("NorthRoad", roads, "road", (0, 0.1, 200), (600, 0.2, 16))
    box("Apron", roads, "concrete", (0, 0.15, 0), (44, 0.3, 44))
    box("DepotPad", roads, "concrete", (220, 0.15, 50), (130, 0.3, 110))
    box("ParadePad", roads, "concrete", (-250, 6.15, 120), (56, 0.3, 46))
    box("HelipadLZ", roads, "concrete", (-90, 0.2, -90), (40, 0.4, 40))
    box("HelipadAlt", roads, "concrete", (255, 0.2, 85), (40, 0.4, 40))
    # highway deck surface + bridge
    box("HighwayRoad", roads, "road", (0, 12.1, -45), (600, 0.2, 14))
    box("BridgeDeck", roads, "concrete", (-30, 11.25, -45), (32, 1.5, 18))
    for sz in (-1, 1):
        box("BridgeParapet", roads, "concrete", (-30, 13.25, -45 + sz * 8.7), (32, 2.5, 0.6))
    for sx in (-1, 1):
        box("BridgePier", roads, "concrete", (-30 + sx * 11, 5.25, -45), (2, 10.5, 14))
    patches = collection("GroundPatches")
    for p in layout["patches"]:
        box("Patch_" + p["kind"], patches, "patch", (p["x"], 0.0, p["z"]), (p["w"], 0.24, p["d"]), p.get("yaw") or 0)
    perches = collection("Perches")
    tan_stair = math.tan(math.radians(33))
    for r in layout["ramps"]:
        length = r.get("length") or r["rise"] / tan_stair
        wedge("PalletRamp", perches, "ramp", (r["x"], r["base"] + r["rise"] / 2, r["z"]), (6, r["rise"], length), r["yaw"])
    box("Shelf", perches, "concrete", (78, 11, 52), (8, 6, 8))
    for x in (-150, 114):
        for sx in (-1, 1):
            box("Crib", perches, "ramp", (x + sx * 3.2, 1.4, -274), (1.2, 2.8, 2.6))
    gantry = collection("DeckGantry")
    floor_y = 23.5
    box("GantryFloor", gantry, "steel", (40, floor_y - 0.3, -45), (10, 0.6, 20))
    for sx in (-1, 1):
        for sz in (-1, 1):
            box("GantryLeg", gantry, "steel", (40 + sx * 4.4, (floor_y + 12) / 2, -45 + sz * 9.4), (1.2, floor_y - 12, 1.2))
    box("GantryLadder", gantry, "steel", (34, 19, -45), (2, 14, 2))
    bcol = collection("Buildings")
    for b in layout["buildings"]:
        sh = b.get("storeyHeight") or 9
        height = b["storeys"] * sh + 1.2
        box(b["name"], bcol, "building", (b["x"], height / 2, b["z"]), (b["width"], height, b["depth"]), b.get("yaw") or 0)


# ------------------------------------------------------------------ meshes


def import_fbx(path):
    before = set(bpy.data.objects)
    if hasattr(bpy.ops.wm, "fbx_import"):
        bpy.ops.wm.fbx_import(filepath=path)
    else:
        bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    return new


def load_mesh_library(names, meshes):
    """One source object per asset, in a hidden `_Library` collection, scaled to the size
    MeshAssets expects (the FBX importer may apply unit scaling)."""
    lib = collection("_Library")
    sources = {}
    for name in sorted(names):
        path = os.path.join(EXPORT, name + ".fbx")
        if not os.path.exists(path):
            print("missing fbx:", name)
            continue
        objs = import_fbx(path)
        if not objs:
            continue
        obj = objs[0]
        for extra in objs[1:]:
            bpy.data.objects.remove(extra)
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        lib.objects.link(obj)
        obj.name = "lib_" + name
        obj.rotation_euler = (0, 0, 0)
        obj.scale = (1, 1, 1)
        bpy.context.view_layer.update()
        dims = obj.dimensions
        spec = meshes.get(name) or {}
        want = spec.get("size")
        if want and dims.z > 0:
            # Blender dims (x, y, z) = Roblox (x, z, y)
            ratio = want[1] / dims.z
            if abs(ratio - 1) > 0.02:
                obj.scale = (ratio, ratio, ratio)
                bpy.context.view_layer.update()
        obj.hide_viewport = True
        obj.hide_render = True
        sources[name] = obj
    lib.hide_viewport = True
    lib.hide_render = True
    return sources


def place_instances(layout, sources):
    hills = layout["hills"]
    meshes = layout["meshes"]
    dcol = collection("Dressing")
    pcol = collection("Props")
    gcol = collection("Generated")
    problems = []
    entries = (
        [("DRESSING", i, e) for i, e in enumerate(layout["dressing"])]
        + [("PROPS", i, e) for i, e in enumerate(layout["props"])]
        + [("GENERATED", None, e) for e in layout["generated"]]
        + [("PERIMETER", None, e) for e in layout["perimeter"]]
    )
    for table, index, e in entries:
        name = e["name"]
        src = sources.get(name)
        spec = meshes.get(name) or {}
        size = spec.get("size") or (4, 4, 4)
        x, z, yaw = e["x"], e["z"], e.get("yaw") or 0
        lift = e.get("lift") or 0
        floor = e.get("floor")
        gy = floor if floor is not None else ground_height(hills, x, z)
        col = {"DRESSING": dcol, "PROPS": pcol}.get(table, gcol)
        if src is not None:
            obj = bpy.data.objects.new(name, src.data)
            obj.scale = src.scale
            col.objects.link(obj)
            obj.color = KIND_COLORS["prop" if name.startswith("prop_") else "mesh"]
            # the FBX pivot is the bottom centre: stand it on the ground
            obj.location = rb(x, gy + lift, z)
        else:
            obj = box(name, col, "mesh", (x, gy + lift + size[1] / 2, z), size, yaw)
        obj.rotation_euler = (0, 0, math.radians(-yaw))
        obj["arena_table"] = table
        obj["arena_index"] = -1 if index is None else index
        obj["arena_locked"] = index is None
        obj["arena_x"], obj["arena_z"], obj["arena_yaw"] = float(x), float(z), float(yaw)
        # --- rules
        issues = []
        if e.get("decor"):
            continue  # scenery past the fence: no placement rules
        corners = footprint_corners(x, z, size[0], size[2], yaw)
        if floor is None and not e.get("perch"):  # a perch's own ramp runs under it
            hs = [ground_height(hills, cx, cz) for cx, cz in corners] + [gy]
            spread = max(hs) - min(hs)
            if spread > STRADDLE_TOLERANCE:
                issues.append("straddles a slope (ground %.1f..%.1f)" % (min(hs), max(hs)))
        ax0, ax1 = min(c[0] for c in corners), max(c[0] for c in corners)
        az0, az1 = min(c[1] for c in corners), max(c[1] for c in corners)
        x0, x1, z0, z1 = WARDEN_LANE
        if ax0 < x1 and ax1 > x0 and az0 < z1 and az1 > z0 and name != "env_lamp_post":
            issues.append("in the Warden lane")
        x0, x1, z0, z1 = LZ_PAD
        if ax0 < x1 and ax1 > x0 and az0 < z1 and az1 > z0:
            issues.append("on the LZ pad")
        if floor is None:
            for b in layout["buildings"]:
                if abs(x - b["x"]) < b["width"] / 2 + 1 and abs(z - b["z"]) < b["depth"] / 2 + 1:
                    issues.append("inside %s's footprint" % b["name"])
        if issues:
            obj.color = KIND_COLORS["problem"]
            problems.append((table, index, name, x, z, "; ".join(issues)))
    return problems


# ------------------------------------------------------------------ renders


DISTRICTS = {
    "whole": ((0, 0), 620),
    "core": ((0, 0), 320),
    "lz_gate": ((-60, -190), 260),
    "suburb": ((0, 230), 300),
    "depot": ((210, 30), 220),
    "barracks": ((-230, 70), 220),
    "scrapyard": ((0, -220), 300),
}


def render_views():
    os.makedirs(PREVIEWS, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError as err:
        print("engine:", err)
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "OBJECT"
    shading.show_shadows = True
    shading.show_cavity = True
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("MapCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("MapCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    cam.rotation_euler = (0, 0, 0)
    for key, ((x, z), scale) in DISTRICTS.items():
        cam.location = rb(x, 400, z)
        cam_data.ortho_scale = scale
        cam_data.clip_end = 1000
        scene.render.filepath = os.path.join(PREVIEWS, "map_%s.png" % key)
        bpy.ops.render.render(write_still=True)
    # one oblique of the core from the south-west
    cam_data.type = "PERSP"
    cam_data.lens = 35
    cam.location = rb(-260, 190, -330)
    direction = rb(10, 0, 10) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(PREVIEWS, "map_oblique.png")
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ write back


def write_back(tolerance=0.05):
    """Rewrites x / z / yaw of every static entry whose object moved in the scene."""
    text = open(ARENA_LUAU, encoding="utf-8").read()
    _, _, _, dspans = read_table(text, "DRESSING", record=True)
    _, _, _, pspans = read_table(text, "PROPS", record=True)
    spans = {"DRESSING": dspans, "PROPS": pspans}
    edits = []
    for obj in bpy.data.objects:
        table = obj.get("arena_table")
        if table not in spans or obj.get("arena_locked"):
            continue
        x, z = obj.location.x, obj.location.y
        yaw = -math.degrees(obj.rotation_euler.z)
        if (
            abs(x - obj["arena_x"]) < tolerance
            and abs(z - obj["arena_z"]) < tolerance
            and abs(((yaw - obj["arena_yaw"]) + 180) % 360 - 180) < 0.5
        ):
            continue
        edits.append((spans[table][int(obj["arena_index"])], x, z, yaw, obj.name))
    edits.sort(key=lambda e: e[0][0], reverse=True)
    for (a, b), x, z, yaw, name in edits:
        entry = text[a:b]

        def num(v):
            return ("%.2f" % v).rstrip("0").rstrip(".") if abs(v - round(v)) > 1e-6 else str(int(round(v)))

        entry = re.sub(r"\bx = -?[\d.]+", "x = " + num(x), entry, count=1)
        entry = re.sub(r"\bz = -?[\d.]+", "z = " + num(z), entry, count=1)
        entry = re.sub(r"\byaw = -?[\d.]+", "yaw = " + num(((yaw + 180) % 360) - 180), entry, count=1)
        text = text[:a] + entry + text[b:]
        print("moved", name, "->", num(x), num(z), num(yaw))
    if edits:
        open(ARENA_LUAU, "w", encoding="utf-8", newline="\n").write(text)
    print("write_back: %d entries" % len(edits))
    return len(edits)


# ------------------------------------------------------------------ main


def build(render=True, save=True):
    bpy.ops.wm.read_homefile(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.scale_length = 0.28
    layout = load_layout()
    build_terrain(layout)
    names = {e["name"] for e in layout["dressing"] + layout["props"] + layout["generated"]}
    sources = load_mesh_library(names, layout["meshes"])
    problems = place_instances(layout, sources)
    print("\n=== placement problems: %d ===" % len(problems))
    for table, index, name, x, z, why in problems:
        print("%-9s %-4s %-22s (%7.1f, %7.1f)  %s" % (table, "" if index is None else index, name, x, z, why))
    if render:
        render_views()
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
        print("saved", BLEND)
    return problems


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    build(render="--no-render" not in argv)
